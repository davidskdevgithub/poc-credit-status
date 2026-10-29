import Foundation

/// `GET /api/v1/credits` — saldo total de la cuenta.
/// Requiere management key. Respuesta de ejemplo (valores ilustrativos):
/// `{"data":{"total_credits":60,"total_usage":56.7}}`
struct CreditsResponse: Decodable {
    let data: CreditsInfo
}

struct CreditsInfo: Codable, Sendable, Equatable {
    let totalCredits: Double
    let totalUsage: Double

    var available: Double { totalCredits - totalUsage }

    enum CodingKeys: String, CodingKey {
        case totalCredits = "total_credits"
        case totalUsage = "total_usage"
    }
}
