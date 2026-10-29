import Foundation

/// `POST /api/v1/analytics/query` — gasto por hora real del servidor.
/// Doc: https://openrouter.ai/docs/api/api-reference/analytics/query-analytics-data.md
/// El timestamp exige segundos (`minute-precision timestamps are rejected`).
struct AnalyticsQueryRequest: Encodable, Sendable {
    let metrics: [String]
    let granularity: String
    let timeRange: TimeRange

    struct TimeRange: Encodable, Sendable {
        let start: String
        let end: String
    }

    enum CodingKeys: String, CodingKey {
        case metrics
        case granularity
        case timeRange = "time_range"
    }
}

/// Respuesta: `{"data":{"data":[filas],"metadata":{...},"cachedAt":...}}`.
/// Las filas usan claves dinámicas según la granularidad (`date__hour`,
/// `date__day`, ...). Se decodifican en forma defensiva porque la doc declara
/// que el schema "evoluciona" (riesgo #1 del plan).
struct AnalyticsResponse: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        let data: [AnalyticsRow]
        let metadata: Metadata?
        let cachedAt: Double?

        struct Metadata: Decodable, Sendable {
            let rowCount: Int?
            let truncated: Bool?
        }
    }

    let data: Payload
}

struct AnalyticsRow: Sendable, Equatable {
    /// Inicio del bucket temporal (ej. la hora `date__hour`), si pudo parsearse.
    let bucket: Date?
    /// Gasto del bucket en USD (métrica `total_usage`).
    let totalUsage: Double?
}

extension AnalyticsRow: Decodable {
    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        var bucket: Date?
        var usage: Double?

        for key in c.allKeys {
            if key.stringValue.hasPrefix("date__") {
                if let s = try? c.decode(String.self, forKey: key),
                   let d = Formatters.iso8601.date(from: s) {
                    bucket = d
                }
            } else if key.stringValue == "total_usage" {
                // Los spend metrics vienen como number, pero parseamos
                // defensivamente (el cookbook advierte strings en count metrics).
                if let d = try? c.decode(Double.self, forKey: key) {
                    usage = d
                } else if let s = try? c.decode(String.self, forKey: key) {
                    usage = Double(s)
                }
            }
        }

        self.bucket = bucket
        self.totalUsage = usage
    }
}

/// Un punto de la serie: gasto de una hora (en USD).
struct SpendPoint: Sendable, Equatable {
    let bucketStart: Date
    let usd: Double
}

/// Resultado de una query horaria.
struct SpendSeries: Sendable {
    let points: [SpendPoint]
    /// `cachedAt` de la respuesta: referencia para la pregunta abierta #1
    /// del plan (frescura de la data vs. dashboard).
    let cachedAt: Date?
}

extension SpendSeries {
    /// El total de la ventana. Los buckets sin consumo no vienen en la
    /// respuesta (hallazgo de la iteración 1): el total no cambia, pero la
    /// densidad de la serie sí.
    var total: Double { points.reduce(0) { $0 + $1.usd } }

    /// Cantidad de buckets con consumo real (> 0). La unidad depende de la
    /// granularidad de la serie (horas en la de 24 h, minutos en la de 1 h).
    var bucketsWithSpend: Int { points.filter { $0.usd > 0 }.count }

    /// La hora de mayor gasto, si hubo alguna.
    var peak: SpendPoint? { points.max(by: { $0.usd < $1.usd }) }
}
