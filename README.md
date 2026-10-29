# PoC: widget de barra de menú para monitorear OpenRouter en macOS

Una app nativa de macOS que vive en la **barra de menú** y permite ver de un vistazo **cuánto crédito queda en OpenRouter y cuánto se está gastando**, sin abrir el dashboard web. Las opciones existentes no convencen en UI/UX, así que esta PoC busca validar una interfaz más limpia y nativa.

## Cómo obtiene los datos

La app consulta la API de OpenRouter con una **management key** cargada manualmente. No guarda snapshots ni calcula deltas: **cada métrica sale de un endpoint del servidor**.

| Endpoint | Métrica | Nota |
|---|---|---|
| `GET /api/v1/credits` | Saldo disponible (`total_credits - total_usage`) | Verificado con management key |
| `GET /api/v1/key` | Gasto del día (`usage_daily`), semanal, mensual | Verificado en doc oficial (acepta key normal) |
| `POST /api/v1/analytics/query` | Gasto por hora real, con granularidad `minute`/`hour`/`day` | Verificado en doc oficial: requiere management key |

> **Por qué management key:** los endpoints de saldo y analytics la exigen (una key de inferencia recibe 403). Es un permiso amplio — puede administrar las keys de la cuenta, no solo leer gastos — así que la UI debe comunicarlo claramente al cargarla. Recomendaciones de OpenRouter: crear una key dedicada para la app, con fecha de expiración y rotación programada; la app debe manejar el 401 de key expirada con un mensaje accionable.

> **Pendiente de prueba:** si `/api/v1/key` y la Analytics API también aceptan una key de inferencia normal (la doc sugiere que no), la app podría funcionar sin management key; se revisaría el alcance de permisos.

## Scope de la PoC

**Incluye:**

- Ícono en la barra de menú (SF Symbol tipo "activity") + popover.
- Saldo disponible, gasto del día y gasto de las últimas horas (dato real del servidor vía analytics, sin snapshots).
- Refresco manual y automático cada 2–5 minutos.
- Manejo de errores de autenticación (401/403) con mensaje accionable.
- Persistencia mínima: solo la management key (JSON/UserDefaults para la PoC).

**Excluye por ahora:**

- Pantalla de configuración, Keychain, gráfico de consumo, alertas, desglose por modelo, soporte para otros proveedores y widget de escritorio.

## Stack

SwiftUI + `MenuBarExtra` (macOS 15 Sequoia, Xcode 16). Networking con `URLSession`, parseo con `Codable`. Sin estado local más allá del cache de la última respuesta y la key.

## Criterio de éxito

Validar que esta vista resumida alcanza para controlar el consumo en el día a día y que **los datos que muestra la app coinciden con lo que muestra el dashboard de OpenRouter** (incluida la frescura: los datos de analytics traen un `cachedAt` y podrían tener delay respecto al dashboard).

## Roadmap (si la PoC aporta valor)

1. Keychain para la management key, mini gráfico de consumo (Swift Charts), alertas por saldo bajo o gasto diario alto.
2. Desglose por modelo: es casi gratuito, la Analytics API lo expone con `"dimensions": ["model"]` en la misma query.
3. Soporte para otros proveedores.

## Documentación detallada

- *(por definir)* `docs/api.md` — endpoints, schemas y ejemplos.
- *(por definir)* `docs/architecture.md` — estructura de la app en SwiftUI.
