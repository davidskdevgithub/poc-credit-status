import Foundation

/// Única fuente de datos de la app (plan.md, decisión 8): los tres endpoints
/// que alimenta el popover. Value-type, sin estado: cada llamada es request →
/// decode. La key se inyecta en el init desde `KeyStore`.
struct OpenRouterClient: Sendable {
    private static let baseURL = URL(string: "https://openrouter.ai/api/v1")!

    let apiKey: String

    // MARK: - Endpoints

    /// Saldo de la cuenta: `total_credits - total_usage`.
    func fetchCredits() async throws -> CreditsInfo {
        let data = try await get("credits")
        return try decode(CreditsResponse.self, from: data).data
    }

    /// Uso **de esta key** (`usage_daily`, `usage_weekly`, `usage_monthly`).
    ///
    /// Hallazgo de la iteración 2: es uso por-key, no de la cuenta — con la
    /// management key (que no hace inferencia) da siempre $0.00. Por eso el
    /// popover no lo usa; el gasto por ventana sale de analytics. Queda para
    /// fase 2: monitorear una key de inferencia específica con su
    /// `limit_remaining`.
    func fetchKey() async throws -> KeyInfo {
        let data = try await get("key")
        return try decode(KeyResponse.self, from: data).data
    }

    /// Gasto por hora (`total_usage` en USD, granularidad `hour`) para las
    /// últimas `hoursBack` horas, en buckets UTC.
    ///
    /// La métrica está hardcodeada (`total_usage`, mismo nombre que el campo
    /// de `/credits`). La mitigación del schema drift — resolver el nombre vía
    /// `GET /analytics/meta` — queda para fase 2; si la API renombra la
    /// métrica, esto fallará visiblemente con `.decoding`/`.http`.
    func fetchHourlySpend(hoursBack: Int = 24, now: Date = Date()) async throws -> SpendSeries {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        // Ventana [inicio de la hora hace `hoursBack`, ahora], en UTC.
        let rawStart = utcCalendar.date(byAdding: .hour, value: -hoursBack, to: now)!
        let start = utcCalendar.dateInterval(of: .hour, for: rawStart)!.start

        let body = AnalyticsQueryRequest(
            metrics: ["total_usage"],
            granularity: "hour",
            timeRange: .init(
                start: Formatters.iso8601.string(from: start),
                end: Formatters.iso8601.string(from: now)
            )
        )

        var request = URLRequest(url: Self.baseURL.appending(path: "analytics/query"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await send(&request)
        let response = try decode(AnalyticsResponse.self, from: data)

        let points = response.data.data.map { row in
            SpendPoint(hourStart: row.bucket ?? .distantPast, usd: row.totalUsage ?? 0)
        }
        let cachedAt = response.data.cachedAt.map { Date(timeIntervalSince1970: $0) }
        return SpendSeries(points: points, cachedAt: cachedAt)
    }

    // MARK: - Transporte

    private func get(_ path: String) async throws -> Data {
        var request = URLRequest(url: Self.baseURL.appending(path: path))
        request.httpMethod = "GET"
        return try await send(&request)
    }

    private func send(_ request: inout URLRequest) async throws -> Data {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw OpenRouterError.network(underlying: URLError(.badServerResponse))
            }

            switch http.statusCode {
            case 200...299:
                return data
            case 401:
                let message = ErrorResponse.message(from: data)
                if let message, message.localizedCaseInsensitiveContains("expired") {
                    throw OpenRouterError.keyExpired
                }
                throw OpenRouterError.keyInvalid
            case 403:
                throw OpenRouterError.forbidden(ErrorResponse.message(from: data) ?? "403")
            case 429:
                throw OpenRouterError.rateLimited
            default:
                throw OpenRouterError.http(status: http.statusCode, message: ErrorResponse.message(from: data))
            }
        } catch let error as OpenRouterError {
            throw error
        } catch {
            throw OpenRouterError.network(underlying: error)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw OpenRouterError.decoding(underlying: error)
        }
    }
}

/// Formatters compartidos. `nonisolated(unsafe)`: `ISO8601DateFormatter` no es
/// `Sendable`, pero parsear/formatar es thread-safe en la práctica y el acceso
/// es de solo lectura.
enum Formatters {
    /// ISO 8601 con segundos, como exige la Analytics API.
    nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
