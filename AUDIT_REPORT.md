# Vecinus v1 Audit Report

**Contexto**
- Repo: `c:\Users\LENOVO\Documents\GitHub\vecinus-v1`
- Stack: Flutter (Dart) app movil + PHP API (PostgreSQL)
- Entrypoints: `lib/main.dart`, `php/login.php`, `php/mis_inmuebles.php`
- Dev segun README: `flutter pub get`, `flutter run`
- Build/preview: no comando encontrado en el repo
- Alcance: movil + backend PHP (no hay web UI)

**Resumen Ejecutivo**
- El riesgo mas alto es seguridad: credenciales de DB en repo y backdoor de password.
- El login registra payload crudo (email y contrasena) en un archivo local.
- Los tokens no validan expiracion en servidor y se extienden en cada request.
- El token se guarda en SharedPreferences (almacenamiento no seguro).
- Hay textos con mojibake en UI y errores (impacto directo en confianza/claridad).
- La guia UX declara tipografia/estilo diferente a lo implementado en el tema.
- Iconografia mezcla estilos (rounded/outlined/filled) y afecta consistencia visual.
- Accesibilidad: targets pequenos y falta de Semantics en controles solo icono.
- Performance: listas no totalmente lazy y cache de inmuebles deshabilitado.
- Dependencias y lints desactualizados; un paquete transitive esta discontinuado.
- Pruebas pasan, pero cobertura es corta y no hay E2E ni tests backend.
- Observabilidad es minima (solo logs en archivos PHP).
- Assets de iconos y logos parecen placeholders o incompletos.

**Scorecard (0-100)**
- UI/Visual: 72
- UX/Flujos: 68
- Accesibilidad: 60
- Performance: 63
- Seguridad: 35
- Calidad de codigo: 62
- Pruebas: 55
- Observabilidad: 40
- Compatibilidad: 70

**Hallazgos**
- A-001 | P0 | Sec | Evidencia: `php/config/conexion.php:12` | Impacto: credenciales DB expuestas en repo, riesgo de acceso total | Repro: abrir archivo y ver user/pass | Causa: secretos hardcodeados | Fix: mover a variables de entorno + rotar credenciales | Esfuerzo: M (riesgo medio)
- A-002 | P0 | Sec | Evidencia: `php/login.php:47` | Impacto: backdoor de login con password universal | Repro: hacer login con cualquier email valido y password `12345` | Causa: bypass intencional en codigo | Fix: eliminar master password y migrar hashes | Esfuerzo: M (riesgo medio)
- A-003 | P1 | Sec | Evidencia: `php/login.php:14` | Impacto: filtracion de credenciales en `debug.txt` | Repro: revisar archivo generado en servidor despues de login | Causa: logging de payload crudo | Fix: remover logging o sanitizar en modo debug | Esfuerzo: S (riesgo bajo)
- A-004 | P1 | Sec | Evidencia: `php/login.php:47` | Impacto: hashes SHA1 debiles, susceptible a cracking offline | Repro: inspeccionar codigo y DB | Causa: uso de SHA1 sin salt | Fix: `password_hash`/`password_verify` con migracion progresiva | Esfuerzo: M (riesgo medio)
- A-005 | P1 | Sec | Evidencia: `php/helpers.php:58` | Impacto: tokens nunca expiran en servidor | Repro: usar token viejo y aun funciona | Causa: no se valida `expires_at` y se renueva siempre | Fix: validar expiracion antes de refrescar | Esfuerzo: S (riesgo bajo)
- A-006 | P1 | Sec | Evidencia: `lib/services/auth_service.dart:10` | Impacto: token en almacenamiento no seguro (riesgo en dispositivos rooteados/backups) | Repro: inspeccionar SharedPreferences | Causa: uso de `shared_preferences` para secretos | Fix: mover token/user a `flutter_secure_storage` | Esfuerzo: S (riesgo bajo)
- A-007 | P2 | Sec | Evidencia: `php/login.php:7` | Impacto: exposicion de errores en produccion | Repro: provocar error y ver respuesta | Causa: `display_errors` activo | Fix: habilitar solo en local | Esfuerzo: S (riesgo bajo)
- A-008 | P2 | Sec | Evidencia: `php/login.php:3`, `php/mis_inmuebles.php:3` | Impacto: CORS abierto para endpoints sensibles | Repro: request cross-origin desde un sitio tercero | Causa: `Access-Control-Allow-Origin: *` | Fix: restringir origenes permitidos | Esfuerzo: S (riesgo bajo)
- A-009 | P2 | Sec | Evidencia: `php/helpers.php:32` | Impacto: subida base64 sin limites, posible DoS o storage abuse | Repro: enviar payload grande a avatar | Causa: no hay validacion de size/type | Fix: validar tamano, MIME real y limites | Esfuerzo: M (riesgo medio)
- A-010 | P2 | UX/UI | Evidencia: `lib/screens/login_screen.dart:164`, `lib/services/api_service.dart:250` | Impacto: textos rotos (mojibake) y baja credibilidad | Repro: abrir login y ver caracteres corruptos | Causa: encoding incorrecto en archivos | Fix: normalizar a UTF-8 y corregir strings | Esfuerzo: S (riesgo bajo)
- A-011 | P2 | UX | Evidencia: `lib/screens/login_screen.dart:24` | Impacto: soporte sin canales reales; flujo de ayuda muerto | Repro: abrir ayuda y ver que no hay acciones | Causa: constantes vacias | Fix: configurar canales o ocultar CTA | Esfuerzo: S (riesgo bajo)
- A-012 | P2 | UI | Evidencia: `lib/screens/main_shell.dart:235` | Impacto: inconsistencia visual por mezcla de estilos de iconos | Repro: revisar bottom nav | Causa: mezcla de `rounded` y `outlined` | Fix: elegir una familia y unificar | Esfuerzo: S (riesgo bajo)
- A-013 | P2 | A11y | Evidencia: `lib/screens/login_screen.dart:630` | Impacto: target touch menor a 44x44, friccion para usuarios mayores | Repro: intentar tap en link de recuperacion | Causa: `tapTargetSize.shrinkWrap` + min size 0 | Fix: restablecer target minimo | Esfuerzo: S (riesgo bajo)
- A-014 | P2 | A11y | Evidencia: `lib/screens/main_shell.dart:269`, `lib/screens/user_screen.dart:446` | Impacto: lectores de pantalla no anuncian acciones icon-only | Repro: activar TalkBack/VoiceOver | Causa: falta Semantics/Tooltip en GestureDetector | Fix: envolver en `Semantics` y usar `InkResponse` | Esfuerzo: S (riesgo bajo)
- A-015 | P2 | Perf | Evidencia: `lib/screens/payments_screen.dart:137` | Impacto: construccion eager de listas grandes | Repro: cuenta con muchos inmuebles | Causa: `SliverChildListDelegate` con lista completa | Fix: usar `SliverChildBuilderDelegate` | Esfuerzo: S (riesgo bajo)
- A-016 | P2 | Perf/UX | Evidencia: `lib/screens/main_shell.dart:48`, `lib/screens/main_shell.dart:74` | Impacto: mas llamadas de red y mala experiencia offline | Repro: navegar entre tabs o reabrir app | Causa: cache de inmuebles deshabilitado | Fix: habilitar cache con TTL | Esfuerzo: M (riesgo medio)
- A-017 | P3 | Code | Evidencia: `lib/screens/dashboard_screen.dart:520`, `lib/screens/dashboard_screen.dart:1061` | Impacto: warnings de analyzer y codigo muerto | Repro: `flutter analyze` | Causa: elementos no usados | Fix: eliminar o usar widgets/params | Esfuerzo: S (riesgo bajo)
- A-018 | P3 | Test | Evidencia: `test/widget_test.dart:16` | Impacto: deprecations futuras en tests | Repro: `flutter analyze` | Causa: APIs `window` obsoletas | Fix: usar `tester.view` y `tester.platformDispatcher` | Esfuerzo: S (riesgo bajo)
- A-019 | P3 | Deps | Evidencia: salida `flutter pub outdated` | Impacto: riesgo de bugs y seguridad por deps viejas | Repro: `flutter pub outdated` | Causa: constraints desactualizadas | Fix: plan de upgrades controlados | Esfuerzo: M (riesgo medio)
- A-020 | P3 | Compat/UI | Evidencia: `assets/icons/.gitkeep`, `assets/images/logo_1x.png` (95 bytes) | Impacto: assets incompletos o placeholders | Repro: listar assets | Causa: faltan exportes 1x/2x/3x reales | Fix: reemplazar assets y validar densidades | Esfuerzo: S (riesgo bajo)

**Quick Wins (max 15)**
- QW-01: remover logging de payload en `php/login.php` y desactivar `display_errors` fuera de local.
- QW-02: eliminar master password y migrar hashes a `password_hash` con fallback SHA1 temporal.
- QW-03: validar `expires_at` en `resolve_user_id_from_token`.
- QW-04: mover token/user a `flutter_secure_storage`.
- QW-05: corregir strings con mojibake (UTF-8) en Flutter y PHP.
- QW-06: agregar Semantics/Tooltips a controles solo icono (bottom nav, avatar).
- QW-07: restaurar target minimo del link de recuperacion de password.
- QW-08: convertir `SliverChildListDelegate` a builder cuando haya listas grandes.
- QW-09: habilitar cache de inmuebles con TTL basico.
- QW-10: limpiar warnings (`_statusPill`, params no usados) y actualizar tests.
- QW-11: unificar familia de iconos en bottom nav.
- QW-12: completar canales de soporte o esconder CTA.

**Riesgos de regresion y mitigacion**
- Cambios de auth (hashes, expiracion, secure storage) pueden forzar re-login: mitigacion con migracion progresiva y comunicacion in-app.
- Cambios en listas pueden afectar layout: mitigar con golden tests y pruebas manuales en 2-3 cuentas.
- Unificacion de iconos puede afectar brand: mitigar con validacion UX rapida.
- Ajustes de tap targets pueden mover layout: mitigar con snapshots y QA en 2 tamanos de pantalla.
