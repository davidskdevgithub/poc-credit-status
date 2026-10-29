import SwiftUI

/// Iteración 1: popover de diagnóstico mínimo.
/// Valida el sizing/estilo de `MenuBarExtra` (pregunta abierta #3) y ejercita
/// el cliente + el mapeo de errores de auth. La UI real llega en la iteración 2.
struct PopoverView: View {
    @State private var status: String = "Scaffold listo"
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Credit Status", systemImage: "waveform.path.ecg")
                .font(.headline)

            Text("Iteración 1 — scaffold + cliente API")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Probar conexión") {
                runConnectionTest()
            }
            .disabled(isLoading)

            Text(status)
                .font(.caption)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(width: 280)
    }

    private func runConnectionTest() {
        guard let apiKey = KeyStore.apiKey else {
            status = "Sin key cargada.\n defaults write \(KeyStore.defaultsDomain) \(KeyStore.defaultsKey) 'sk-or-...'"
            return
        }

        isLoading = true
        status = "Consultando…"
        let client = OpenRouterClient(apiKey: apiKey)

        Task {
            defer { isLoading = false }
            do {
                let credits = try await client.fetchCredits()
                let key = try await client.fetchKey()
                let spend = try await client.fetchHourlySpend(hoursBack: 24)
                let total = spend.points.reduce(0) { $0 + $1.usd }
                status = """
                ✓ Conexión OK
                Saldo: $\(String(format: "%.2f", credits.available)) de $\(String(format: "%.2f", credits.totalCredits))
                Gasto del día: $\(String(format: "%.2f", key.usageDaily ?? -1))
                Últimas 24 h: $\(String(format: "%.2f", total)) en \(spend.points.count) buckets
                """
            } catch let error as OpenRouterError {
                status = "✗ \(error.errorDescription ?? String(describing: error))"
            } catch {
                status = "✗ Error inesperado: \(error)"
            }
        }
    }
}
