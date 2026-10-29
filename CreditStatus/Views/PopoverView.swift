import SwiftUI

/// Popover principal: saldo, gasto del día y últimas 24 h.
/// Estados: sin key / error (con datos stale visibles) / datos.
struct PopoverView: View {
    @State private var model = MonitorModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let error = model.error {
                ErrorBanner(error: error) {
                    Task { await model.refresh() }
                }
            }

            switch (KeyStore.apiKey, model.credits, model.spend) {
            case (.none, _, _):
                NoKeyState()
            case (_, .some(let credits), .some(let spend)):
                MetricsView(credits: credits, spend: spend)
            default:
                // Con key pero aún sin datos: primer load en curso (o fallido
                // y no hay nada stale que mostrar).
                LoadingState()
            }

            footer
        }
        .padding(14)
        .frame(width: 300)
        .task { await model.refresh() }
    }

    // MARK: - Secciones

    private var header: some View {
        Label("Credit Status", systemImage: "waveform.path.ecg")
            .font(.headline)
    }

    private var footer: some View {
        HStack {
            if let updated = model.lastUpdated {
                Text("Actualizado")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(updated, format: Date.FormatStyle(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await model.refresh() }
            } label: {
                if model.isLoading {
                    ProgressControl()
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .disabled(model.isLoading)
            .buttonStyle(.plain)
            .help("Refrescar")
        }
    }
}

// MARK: - Métricas

private struct MetricsView: View {
    let credits: CreditsInfo
    let spend: SpendSeries

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MetricRow(
                label: "Saldo disponible",
                value: credits.available,
                detail: "de \(format(credits.totalCredits)) · gastado \(format(credits.totalUsage))",
                emphasize: true
            )
            Divider()
            MetricRow(
                label: "Gasto de hoy",
                value: todaySpend,
                detail: "desde las 00:00 (hora local) · de toda la cuenta"
            )
            MetricRow(
                label: "Últimas 24 h",
                value: spend.total,
                detail: detailForSpend
            )
        }
    }

    /// Suma de buckets desde la medianoche local. La medianoche local cae
    /// adentro de un bucket UTC (GMT-3 → 03:00 UTC): el bucket que contiene la
    /// medianoche suma completo, así que "hoy" queda levemente sobreestimado
    /// (incluye hasta 3 h de ayer). Aceptable para la PoC; refinable con
    /// granularity minute si hiciera falta.
    private var todaySpend: Double {
        spend.spend(since: Calendar.current.startOfDay(for: Date()))
    }

    private var detailForSpend: String {
        var parts = ["\(spend.hoursWithSpend) \(spend.hoursWithSpend == 1 ? "hora" : "horas") con consumo"]
        if let peak = spend.peak, peak.usd > 0 {
            parts.append("pico \(format(peak.usd)) a las \(peak.hourStart.formatted(date: .omitted, time: .shortened))")
        }
        return parts.joined(separator: " · ")
    }
}

private struct MetricRow: View {
    let label: String
    let value: Double
    let detail: String
    var emphasize = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(format(value))
                .font(.system(.title2, design: .rounded, weight: emphasize ? .semibold : .regular))
                .monospacedDigit()
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Estados

private struct NoKeyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sin API key", systemImage: "key")
                .font(.subheadline)
            Text("Cargá tu management key por terminal:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("defaults write \(KeyStore.defaultsDomain) \(KeyStore.defaultsKey) 'sk-or-...'")
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .padding(6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LoadingState: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressControl()
            Text("Consultando OpenRouter…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

private struct ErrorBanner: View {
    let error: OpenRouterError
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 4) {
                Text(error.errorDescription ?? String(describing: error))
                    .font(.caption)
                    .textSelection(.enabled)
                Button("Reintentar", action: retry)
                    .font(.caption)
                    .buttonStyle(.link)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ProgressControl: View {
    var body: some View {
        ProgressView()
            .controlSize(.small)
    }
}

// MARK: - Formato

private func format(_ value: Double) -> String {
    "$" + String(format: "%.2f", value)
}
