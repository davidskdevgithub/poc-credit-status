import Foundation
import Observation

/// Estado del monitor: única fuente de datos del popover.
/// Iteración 2: refresco manual (`.task` al abrir + botón).
/// Iteración 3: refresco automático por timer.
@Observable
@MainActor
final class MonitorModel {
    private(set) var credits: CreditsInfo?
    private(set) var spend: SpendSeries?
    private(set) var lastHour: SpendSeries?
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
            // Tres consultas en paralelo: /credits (saldo) y analytics para
            // las dos ventanas móviles (24 h por hora, 1 h por minuto).
            async let credits = client.fetchCredits()
            async let hourly = client.fetchSpend(granularity: "hour", minutesBack: 24 * 60)
            async let lastHour = client.fetchSpend(granularity: "minute", minutesBack: 60)
            self.credits = try await credits
            self.spend = try await hourly
            self.lastHour = try await lastHour
            self.lastUpdated = Date()
            self.error = nil
        } catch let error as OpenRouterError {
            self.error = error
        } catch {
            self.error = .network(underlying: error)
        }
    }
}
