import Foundation

/// `GET /api/v1/key` — estado de la API key autenticada.
/// Decodificación parcial: solo los campos que usa la PoC; la API agrega
/// muchos otros (`rate_limit`, `byok_*`, `free_model_daily_requests`, ...).
struct KeyResponse: Decodable {
    let data: KeyInfo
}

struct KeyInfo: Sendable, Equatable {
    let label: String?
    let usage: Double?
    let usageDaily: Double?
    let usageWeekly: Double?
    let usageMonthly: Double?
    let limitRemaining: Double?

    enum CodingKeys: String, CodingKey {
        case label
        case usage
        case usageDaily = "usage_daily"
        case usageWeekly = "usage_weekly"
        case usageMonthly = "usage_monthly"
        case limitRemaining = "limit_remaining"
    }
}

extension KeyInfo: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Los números pueden llegar como number o string; toleramos ambos.
        func flexible(_ key: CodingKeys) throws -> Double? {
            if let d = try? c.decode(Double.self, forKey: key) { return d }
            if let s = try? c.decode(String.self, forKey: key) { return Double(s) }
            return nil
        }
        label = try c.decodeIfPresent(String.self, forKey: .label)
        usage = try flexible(.usage)
        usageDaily = try flexible(.usageDaily)
        usageWeekly = try flexible(.usageWeekly)
        usageMonthly = try flexible(.usageMonthly)
        limitRemaining = try flexible(.limitRemaining)
    }
}
