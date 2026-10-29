import SwiftUI

@main
struct CreditStatusApp: App {
    var body: some Scene {
        // "activity" no existe en SF Symbols; el equivalente visual es el pulso ECG.
        MenuBarExtra("Credit Status", systemImage: "waveform.path.ecg") {
            PopoverView()
        }
        .menuBarExtraStyle(.window)
    }
}
