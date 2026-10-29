import Foundation

/// Errores de la API de OpenRouter, mapeados a mensajes accionables.
/// La distinción key inválida vs. expirada viene de la doc de management keys:
/// una key vencida responde 401 con mensaje `API key expired`.
enum OpenRouterError: LocalizedError, Sendable {
    /// 401 con key inválida.
    case keyInvalid
    /// 401 "API key expired": la management key venció.
    case keyExpired
    /// 403: la key no tiene permiso para el endpoint (p. ej. key de inferencia).
    case forbidden(String)
    case rateLimited
    case http(status: Int, message: String?)
    case network(underlying: Error)
    case decoding(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .keyInvalid:
            "La API key no es válida. Cargá una management key con:\n defaults write \(KeyStore.defaultsDomain) \(KeyStore.defaultsKey) 'sk-or-...'"
        case .keyExpired:
            "La management key expiró. Creá una nueva en openrouter.ai/settings/management-keys y actualizala con:\n defaults write \(KeyStore.defaultsDomain) \(KeyStore.defaultsKey) 'sk-or-...'"
        case .forbidden(let message):
            "Acceso denegado por la API: \(message)\nEstos endpoints requieren una management key (openrouter.ai/settings/management-keys)."
        case .rateLimited:
            "La API está limitando las consultas (429). Probá de nuevo en unos minutos."
        case .http(let status, let message):
            "Error HTTP \(status)\(message.map { ": \($0)" } ?? "")"
        case .network(let error):
            "Error de red: \(error.localizedDescription)"
        case .decoding:
            "La respuesta de la API no se pudo interpretar (¿cambió el schema?)."
        }
    }
}

/// Cuerpo de error de la API: `{"error":{"message":"...","code":401}}`
struct ErrorResponse: Decodable {
    struct Detail: Decodable {
        let message: String?
    }

    let error: Detail?

    static func message(from data: Data) -> String? {
        guard let parsed = try? JSONDecoder().decode(ErrorResponse.self, from: data) else {
            return nil
        }
        return parsed.error?.message
    }
}
