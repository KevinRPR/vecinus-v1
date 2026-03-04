# Solution Sheet - Vecinus v1

## Objetivo
- Mejorar estabilidad, UX y acceso rapido sin re-arquitectura.

## Quick wins (1-2 semanas)
1) Splash overflow
   - Ajustar fila inferior con `Flexible`/`FittedBox` y maxLines.
   - Resultado: no warnings de overflow en pantallas pequenas.

2) Acceso rapido guiado
   - Post-login: prompt para activar biometria + configurar PIN.
   - Guardar preferencia en `UserPreferences`.

3) Networking resiliente
   - Agregar `.timeout(Duration(seconds: 15))` a `http.post`.
   - Mensaje claro: "No hay conexion, intenta de nuevo".

4) Unificar login UI
   - Mover colores hardcodeados a AppColors/AppTheme.
   - Asegurar consistencia con resto de la app.

## Mediano (2-4 semanas)
1) Refresh token + renovacion silenciosa
   - Backend: endpoint de refresh (token corto + refresh largo).
   - Cliente: renovar en Splash/foreground; si falla, pedir login.

2) Unlock screen dedicado
   - Pantalla de "Desbloquear" con Face ID / Huella + PIN.
   - Fallback: "Usar contrasena".

3) iOS build estable
   - Regenerar `ios/Podfile` y correr `pod install`.
   - Validar permisos, safe areas y biometria en device real.

## Largo (1-2 meses)
1) Observabilidad
   - Sentry/Crashlytics + analytics de funnels.

2) Performance UI
   - Reducir blur y sombras en low-end (flag por dispositivo).
   - Revisar rebuilds con DevTools.

3) Calidad y tests
   - E2E: login, pagos, reportar pago.
   - Golden tests para pantallas clave.

## Criterio de exito (acceso rapido)
- Usuario autentica 1 vez con correo/password.
- Luego entra con biometria o PIN sin re-escribir credenciales.
- Si token expira: refresh silencioso; solo pide login si refresh falla.

