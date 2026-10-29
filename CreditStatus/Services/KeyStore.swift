import Foundation

/// Storage de la management key para la PoC: UserDefaults.
/// Cargarla por CLI (no hay pantalla de configuración en el MVP):
///
///     defaults write com.davidsekielyk.CreditStatus managementKey 'sk-or-v1-...'
///
/// Fase 2: Keychain (ver plan.md, roadmap).
enum KeyStore {
    static let defaultsDomain = "com.davidsekielyk.CreditStatus"
    static let defaultsKey = "managementKey"

    static var apiKey: String? {
        UserDefaults.standard.string(forKey: defaultsKey)
    }
}
