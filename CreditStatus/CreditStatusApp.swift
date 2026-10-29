import SwiftUI

@main
struct CreditStatusApp: App {
    var body: some Scene {
        MenuBarExtra("Credit Status", systemImage: "activity") {
            PopoverView()
        }
        .menuBarExtraStyle(.window)
    }
}
