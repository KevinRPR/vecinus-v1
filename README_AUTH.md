# Auth Notes (Vecinus v1)

## Sesion y expiracion
- El cliente usa `session_expires_at` (o `expires_at` / `token_expires_at`) si el backend lo envia.
- Si no llega expiracion, el cliente aplica un TTL configurable:
  - `--dart-define=DEFAULT_SESSION_MINUTES=10080` (por defecto 7 dias).
- Esto evita re-login frecuente, pero si el backend invalida el token antes,
  el servidor respondera 401 y la app pedira login.

## Renovacion silenciosa
La app usa `refresh_token.php` para rotar token y extender sesion sin forzar re-login.
- Cliente: `lib/services/token_refresher.dart` (implementacion HTTP real).
- Backend: `php-actual/refresh_token.php`.
- Logout: `php-actual/logout.php` revoca token en servidor.

## Acceso rapido
- Post-login se ofrece activar biometria o configurar PIN (opcional).
- Preferencias guardadas en `SecurityPreferences` y estado del prompt en SharedPreferences.

## TODO backend
- Exponer endpoint de refresh token (por ejemplo: `refresh_token.php`).
- Retornar `expires_at` actualizado en respuestas de login/refresh.

## 2FA OTP (perfil)
La app ya puede activar/desactivar 2FA desde Perfil -> Seguridad.

Variables recomendadas en backend (`php-actual/config/env.local.php` o entorno):
- `TWO_FACTOR_CODE_TTL_MINUTES=5`
- `TWO_FACTOR_MAX_ATTEMPTS=3`
- `TWO_FACTOR_RESEND_COOLDOWN_SECONDS=60`
- `TWO_FACTOR_REQUEST_WINDOW_SECONDS=900`
- `TWO_FACTOR_REQUEST_MAX_PER_USER=5`
- `TWO_FACTOR_REQUEST_MAX_PER_IP=20`
- `TWO_FACTOR_DEBUG_EXPOSE_CODE=0` en produccion

Notas:
- En desarrollo puedes usar `APP_DEBUG=1` o `TWO_FACTOR_DEBUG_EXPOSE_CODE=1`
  para ver `debug_code` en la respuesta y validar el flujo end-to-end.
- En produccion, integra envio real por correo/SMS para reemplazar el codigo de prueba.

## CORS en produccion
- No usar `CORS_ALLOWED_ORIGINS=*` en produccion.
- Configura una lista real de origenes separados por coma, por ejemplo:
  `https://mail.rhodiumdev.com,https://rhodiumdev.com`.

## Metricas de operacion (API)
- Endpoint nuevo: `php-actual/metricas_reportes.php`.
- Entrada: `token`, `from` (`YYYY-MM-DD`), `to` (`YYYY-MM-DD`), `id_condominio` (opcional).
- Salida: `series` por dia, `summary` por estado y `promedio_revision_minutos`.
- SQL base: `php-actual/sql/reportes_metricas.sql`.
