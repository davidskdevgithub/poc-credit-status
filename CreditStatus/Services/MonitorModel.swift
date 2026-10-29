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
            // Dos consultas: /credits (saldo) y analytics (gasto). El "gasto
            // del día" sale de la misma serie horaria (buckets desde la
            // medianoche local) — ver decisión #10 del plan.
            async let credits = client.fetchCredits()
            async let spend = client.fetchHourlySpend(hoursBack: 24)
            self.credits = try await credits
            self.spend = try await spend
            self.lastUpdated = Date()
            self.error = nil
        } catch let error as OpenRouterError {
            self.error = error
        } catch {
            self.error = .network(underlying: error)
        }
    }
}
