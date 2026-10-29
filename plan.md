# Plan — PoC Credit Status

Primer PoC nativa de macOS (las anteriores, [`poc-jugadas-3d`](../poc-jugadas-3d),
[`poc-ds-multiplatform`](../poc-ds-multiplatform) y [`poc-login`](../poc-login),
fueron web/mobile). Objeto: validar que un widget de barra de menú alcanza para
controlar el consumo de OpenRouter en el día a día.

Estructura del repo y convenciones tomadas de las PoCs anteriores: `plan.md` al
estilo poc-login (este archivo), README como visión, `docs/` para detalles. El
pipeline de docs por feature de jugadas-3d queda descartado: los gaps abiertos
se documentan acá, como secciones.

## Objetivo

Una app que vive en la **barra de menú** y muestra, de un vistazo:

- **Saldo disponible** en OpenRouter.
- **Gasto del día.**
- **Gasto por hora real** (últimas N horas), consultado al servidor — sin
  snapshots locales ni deltas calculados.

## Decisiones tomadas (del debate)

| # | Tema | Decisión | Evidencia / porqué |
|---|------|----------|--------------------|
| 1 | Auth | **Management key** dedicada, cargada manualmente, con expiración y rotación (la del usuario expira Nov 2026) | `/credits` y la Analytics API exigen management key (403 con key de inferencia). Probado: `{"total_credits":60,"total_usage":56.72}` |
| 2 | Gasto horario | **Analytics API** (`POST /api/v1/analytics/query`, `granularity: "hour"`), no snapshots locales | La doc decía "no hay consumo por hora vía API"; quedó desactualizada. Con analytics el dato es real, histórico, y el mecanismo de `{timestamp, usage}` + deltas se descarta junto con su limitación ("solo hay datos desde que la app corre") |
| 3 | Gasto del día | `GET /api/v1/key` → `usage_daily` | Doc oficial de limits |
| 4 | Saldo | `GET /api/v1/credits` → `total_credits - total_usage` | Verificado con management key |
| 5 | Persistencia | **Ninguna** más allá de la key (UserDefaults para la PoC, Keychain en fase 2) | El estado por-snapshot ya no es necesario |
| 6 | Seguridad | La UI comunica que es una **management key** (permiso amplio: administra keys de la cuenta), no una key de inferencia cualquiera | Riesgo explícito de la decisión 1 |
| 7 | Stack | SwiftUI + `MenuBarExtra`, macOS 15 / Xcode 16, `URLSession` + `Codable` | Nativo, sin dependencias |
| 8 | Estructura del código | `Models/ Services/ Views/`; `OpenRouterClient` como única fuente de datos (análogo al store de jugadas-3d: dueño del estado que todo consume) | Mapeo del espíritu "features" a una app de un solo popover |
| 9 | Verificación de éxito | Los datos de la app deben **coincidir con el dashboard de OpenRouter**, incluida la frescura | Meta original de la PoC, ajustada: ya no se validan deltas locales sino la data horaria de analytics |

## MVP

1. Ícono en la barra (SF Symbol tipo "activity") + popover con saldo, gasto del
   día y gasto por hora (últimas horas de hoy).
2. Refresco manual + automático cada 2–5 min.
3. Manejo de errores: 401 (key inválida) y 401 "API key expired" (expirada) con
   mensajes accionables diferenciados; 403 con explicación.
4. Key persistida en UserDefaults entre launches.

### Fuera de alcance (roadmap, no MVP)

- Pantalla de configuración, Keychain, gráfico (Swift Charts), alertas,
  desglose por modelo, widget de escritorio, otros proveedores.
- El desglose por modelo es casi gratuito con analytics
  (`"dimensions": ["model"]`) pero queda para fase 2 para no inflar el MVP.

## Preguntas abiertas (a responder con evidencia, no en el plan)

| # | Pregunta | Cómo se responde |
|---|----------|------------------|
| 1 | ¿Qué tan fresca es la data de analytics? (la respuesta trae `cachedAt`) | Comparar el valor horario de la app contra el dashboard Activity a la misma hora |
| 2 | ¿Hay rate limits prácticos en polling cada 2–5 min? | Observar durante uso real; la doc no documenta límites para estos endpoints |
| 3 | ¿`MenuBarExtra` permite el popover de este tamaño/estilo sin hacks? | Scaffold + primera prueba de UI |

## Riesgos anticipados

- **Schema drift**: OpenRouter declara que métricas/dimensiones "evolucionan".
  Mitigación: leer `GET /analytics/meta` al boot en vez de hardcodear nombres.
- **Key expirada**: la management key expira por diseño. La app debe
  distinguirlo de una key inválida (mensaje distinto) — decisión 3 del MVP.
- **Timer en background**: comportamiento del refresh automático cuando el Mac
  duerme o la app no está activa; a validar en la iteración de refresco.

## Iteraciones

Cada iteración = un commit atómico (convención de poc-login).

### 1. Scaffold + cliente API ✅ *(2026-10-29)*

Proyecto Xcode con `MenuBarExtra`, models `Codable` para los tres endpoints,
`OpenRouterClient` y el manejo de errores de auth.

#### Decisiones tomadas durante la iteración

- **El `.xcodeproj` se genera con `xcodegen`** (instalado vía brew) desde
  `project.yml`, y va gitignoreado: regenerable con `xcodegen generate`. Evita
  versionar un pbxproj de ruido y mantiene el scaffold reproducible.
- **Swift 6 en modo estricto** (default de Xcode 16). Un gotcha de
  concurrencia: `ISO8601DateFormatter` estático no es `Sendable` →
  `nonisolated(unsafe)` en el enum `Formatters`.
- **LSUIElement: true** en el Info.plist (via `project.yml`): sin ícono en el
  Dock, solo barra de menú.
- La key se carga por CLI (`defaults write`, ver `KeyStore.swift`) — no hay
  pantalla de configuración y el MVP lo requiere.
- El popover de iteración 1 incluye un botón "Probar conexión" que ejercita los
  tres endpoints y los errores de auth antes de diseñar la UI real.

#### Implementado

- `project.yml` + `.gitignore` (xcodegen)
- `Models/`: `CreditsInfo` (verificado contra la respuesta real), `KeyInfo`
  (decodificación parcial + tolerante a number/string), `AnalyticsRow` con
  claves dinámicas defensivas (`date__*`), `OpenRouterError` con mensajes
  accionables que distinguen key inválida / expirada / 403
- `Services/`: `KeyStore` (UserDefaults), `OpenRouterClient` con los tres
  endpoints (async/await, `URLSession`)
- `CreditStatusApp` con `MenuBarExtra(.window)` y `PopoverView` de diagnóstico
- Build verificado: `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` → SUCCESS

### 2. Popover con datos *(pendiente)*

UI del popover con los tres datos, estado de error y estado inicial (sin key).

### 3. Refresco automático *(pendiente)*

Timer de refresco, manejo de sleep/background, indicador de última actualización.

## Registro de ejecución

### Iteración 1 — Scaffold + cliente API ✅ (2026-10-29)

#### Gotchas de la iteración 1

- Swift 6 estricto rechaza `static let` de `ISO8601DateFormatter`
  (no-`Sendable`); resuelto con `nonisolated(unsafe)` + comentario.
- La fila de analytics usa claves dinámicas (`date__hour` según granularidad);
  se decodifica buscando prefijo `date__` para no acoplarse al schema.
- Build con `CODE_SIGNING_ALLOWED=NO` (ad-hoc) para verificar sin firma real.

#### Estado del repo

- Compila: `xcodegen generate && xcodebuild build` ✅
- Pendiente de prueba manual: correr desde Xcode, cargar la key con
  `defaults write` y ejecutar "Probar conexión" (valida preguntas abiertas #1
  y #3 con datos reales).
