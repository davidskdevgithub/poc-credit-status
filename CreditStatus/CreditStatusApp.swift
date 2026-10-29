import SwiftUI

@main
struct CreditStatusApp: App {
    private let model = MonitorModel()

    init() {
        // El polling arranca con la app, no con el popover: así hay datos
        // frescos ni bien abrís el menú.
        model.startPolling()
    }

    var body: some Scene {
        // "activity" no existe en SF Symbols; el equivalente visual es el pulso ECG.
        MenuBarExtra("Credit Status", systemImage: "waveform.path.ecg") {
            PopoverView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
