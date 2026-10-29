import AppKit
import Foundation
import Observation

/// Estado del monitor: única fuente de datos del popover./// Iteración 3: refresco automático por loop + refresh al despertar del sleep.
@Observable
@MainActor
final class MonitorModel {
    private(set) var credits: CreditsInfo?
    private(set) var spend: SpendSeries?
    private(set) var lastHour: SpendSeries?
    private(set) var lastUpdated: Date?

    private(set) var isLoading = false
    private(set) var error: OpenRouterError?

    private var pollTask: Task<Void, Never>?
    private var wakeObserver: (any NSObjectProtocol)?

    /// Frecuencia del refresco automático (plan: 2–5 min).
    static let refreshInterval: Duration = .seconds(180)

    /// Loop de refresco automático. Lo llama la App al lanzar: no depende del
    /// popover abierto (el contenido de `MenuBarExtra` solo existe mientras
    /// está visible).
    ///
    /// Sleep/background: `Task.sleep` se congela con el sistema y retoma al
    /// despertar — el primer tick post-wake dispara un refresh inmediato.
    /// Además se escucha `didWakeNotification` para refrescar apenas despierta
    /// (duplicado posible con el tick retomado: aceptable, ambos refrescan).
    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

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
