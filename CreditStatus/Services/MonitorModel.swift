import Foundation
import Observation

/// Estado del monitor: única fuente de datos del popover.
/// Iteración 2: refresco manual (`.task` al abrir + botón).
/// Iteración 3: refresco automático por timer.
@Observable
@MainActor
final class MonitorModel {
    private(set) var credits: CreditsInfo?
    private(set) var keyInfo: KeyInfo?
    private(set) var spend: SpendSeries?
    private(set) var lastUpdated: Date?

    private(set) var isLoading = false
    private(set) var error: OpenRouterError?

    /// Mantiene los datos viejos cuando un refresh falla: la UI muestra el
    /// error arriba y los datos con su última actualización, no en blanco.
    func refresh() async {
        guard !isLoading else { return }
        guard let apiKey = KeyStore.apiKey else {
            error = nil
            return // la UI maneja el estado "sin key"
        }

        isLoading = true
        defer { isLoading = false }

        let client = OpenRouterClient(apiKey: apiKey)
        do {
            let credits = try await client.fetchCredits()
            let keyInfo = try await client.fetchKey()
            let spend = try await client.fetchHourlySpend(hoursBack: 24)
            self.credits = credits
            self.keyInfo = keyInfo
            self.spend = spend
            self.lastUpdated = Date()
            self.error = nil
        } catch let error as OpenRouterError {
            self.error = error
        } catch {
            self.error = .network(underlying: error)
        }
    }
}
