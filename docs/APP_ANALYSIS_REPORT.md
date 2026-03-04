# App Analysis Report - Vecinus v1

## Contexto
- Stack: Flutter mobile app (Android/iOS). API base URL en `lib/services/api_service.dart`.
- Auth: token + expiry en secure storage; biometria y PIN via `SecurityService`.
- Cache: inmuebles en SharedPreferences con TTL de 10 min.

## Checks ejecutados
- `flutter analyze` -> OK
- `flutter test` -> OK
- `flutter pub outdated` -> dependencias directas y transitive desactualizadas

## Fortalezas
- UI consistente en pantallas core (Inicio, Pagos, Alertas, Perfil) con tokens de AppTheme.
- Cache de inmuebles con TTL reduce llamadas y mejora percepcion (MainShell).
- Soporte de biometria y PIN listo para flujo de acceso rapido.
- Flujos de pagos y reportes estructurados por pasos (mejor comprension).

## Debilidades y riesgos (con evidencia)
- A-001 (P0, Compat/iOS): No existe `ios/Podfile`, requisito para CocoaPods y plugins.
  - Evidencia: `ios/Podfile` (archivo ausente)
  - Impacto: build iOS falla o integra plugins incompletos (local_auth, secure_storage).
  - Recom: regenerar Podfile (`flutter create .`) y correr `pod install`.

- A-002 (P1, UX/UI): Posible overflow en Splash por texto largo sin wrap/flex.
  - Evidencia: `lib/screens/splash_screen.dart:232` y `lib/screens/splash_screen.dart:301`
  - Impacto: warning visual (RenderFlex overflow) en pantallas pequenas.
  - Recom: usar `Flexible` o `FittedBox` en la fila inferior y limitar a 1 linea.

- A-003 (P1, UX/Auth): Sesion expira por defecto a 2h si backend no envia expiry.
  - Evidencia: `lib/screens/login_screen.dart:88-91`, `lib/services/auth_service.dart:63-69`
  - Impacto: re-login frecuente, rompe objetivo de acceso rapido.
  - Recom: refresh token + renovacion silenciosa, o backend siempre envia expiry real.

- A-004 (P2, DX/Sec): Base URL hardcodeado en cliente.
  - Evidencia: `lib/services/api_service.dart:19-23`
  - Impacto: sin separacion dev/staging/prod; cambios requieren rebuild.
  - Recom: usar config por entorno (dart-define / .env).

- A-005 (P2, Perf/Resiliencia): Requests sin timeout.
  - Evidencia: `lib/services/api_service.dart` (http.post sin `.timeout`)
  - Impacto: spinners indefinidos en redes lentas o cortes.
  - Recom: timeout + error controlado (ej 15s) y reintento opcional.

- A-006 (P2, UI/Consistencia): Login screen usa colores hardcodeados fuera de AppTheme.
  - Evidencia: `lib/screens/login_screen.dart:10-20`
  - Impacto: inconsistencia visual, dark mode menos confiable.
  - Recom: migrar a AppColors/AppTheme.

- A-007 (P2, Perf): BackdropFilter + sombras pesadas en header/nav.
  - Evidencia: `lib/screens/dashboard_screen.dart:898`, `lib/screens/main_shell.dart:274`
  - Impacto: posible jank en dispositivos de gama baja.
  - Recom: reducir blur, usar sombras mas ligeras, o desactivar blur en low-end.

- A-008 (P2, Mantenimiento): Dependencias con versions antiguas y un paquete discontinuado.
  - Evidencia: `flutter pub outdated` (local_auth 3.x, intl 0.20.x, flutter_secure_storage 10.x, js discontinued)
  - Impacto: riesgo de compatibilidad futura y seguridad.
  - Recom: plan de upgrade por tandas.

- A-009 (P3, Observabilidad): No hay tracking de errores ni analytics.
  - Evidencia: ausencia de Sentry/Crashlytics en `lib/` (busqueda sin matches)
  - Impacto: poca visibilidad de crashes o embudos.
  - Recom: integrar Sentry o Crashlytics + eventos basicos.

## Compatibilidad Apple (estado actual)
- OK: `NSFaceIDUsageDescription` y permisos de camara/galeria en `ios/Runner/Info.plist`.
- Riesgo: falta `ios/Podfile` bloquea build y plugins iOS.
- Requiere validacion real en dispositivo: safe areas, biometria, permisos.

## Login y acceso rapido (analisis)
- Flujo actual: email/pass -> token + expiry -> Splash valida -> biometria/PIN opcional.
- Problema: expiry corto (2h) sin refresh provoca re-login, contradice acceso rapido.
- Oportunidad: ya existe PIN y biometria, falta un flujo guiado y refresh token.

## Para llegar a nivel Meta/Google (gap)
- Auth: refresh token + unlock screen dedicado (Face ID / PIN) + fallback a password.
- Perf: timeouts, uso de blur/shadows mas ligero, lista virtualizada cuando aplique.
- Calidad: tests E2E para login/pagos, golden tests para UI critica.
- Observabilidad: crash reporting + analytics de funnels.
- Seguridad: config por entorno y hardening de red (timeouts, retries, headers).
