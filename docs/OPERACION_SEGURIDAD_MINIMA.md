# Operacion y Seguridad Minima (Vecinus)

## 1) HTTPS estricto
- Forzar HTTPS en el dominio y subdominio de API.
- Redireccionar `http -> https` en cPanel/Apache.
- Activar HSTS (minimo `max-age=31536000`) cuando ya todo el trafico sea HTTPS.

## 2) CORS por origen real
- Configurar `CORS_ALLOWED_ORIGINS` con dominios reales separados por coma.
- En produccion no usar `*`.
- Ejemplo:
  - `CORS_ALLOWED_ORIGINS=https://mail.rhodiumdev.com,https://rhodiumdev.com`

## 3) Rate limits minimos
- Login: mantener rate limit actual.
- OTP (`2fa_request`):
  - `TWO_FACTOR_RESEND_COOLDOWN_SECONDS=60`
  - `TWO_FACTOR_REQUEST_WINDOW_SECONDS=900`
  - `TWO_FACTOR_REQUEST_MAX_PER_USER=5`
  - `TWO_FACTOR_REQUEST_MAX_PER_IP=20`

## 4) Rotacion de secretos
- Rotar cada 90 dias:
  - `DB_PASS`
  - `SMTP_PASSWORD`
  - cualquier secreto de tokens/servicios.
- Procedimiento recomendado:
  1. Crear secreto nuevo.
  2. Actualizar en servidor (`env.local.php` o variables de entorno).
  3. Reiniciar servicio PHP/FPM si aplica.
  4. Validar login, OTP y reportes.
  5. Revocar secreto anterior.

## 5) Backups y restore test
- Backup diario de base de datos.
- Mantener al menos 7 backups diarios + 4 semanales.
- Prueba de restauracion mensual:
  1. Restaurar backup en entorno de prueba.
  2. Validar tablas `pago_reportado_app` y `menu_login.*`.
  3. Ejecutar consultas de conteo y comparar con produccion.
  4. Documentar fecha, resultado y tiempo de recuperacion.

## 6) Logs basicos y trazabilidad
- Todas las respuestas API incluyen `request_id`.
- Revisar `error_log` para:
  - fallos SMTP/OTP
  - errores en endpoints de reportes
  - bloqueos por CORS/rate limit.
- Para soporte, pedir:
  - `request_id`
  - `client_uuid` del reporte.
