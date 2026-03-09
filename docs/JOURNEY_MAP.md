# Journey Map (Web + Mobile)

## 1) Consultar pagos y estado
- Goal: ver saldo, historial y estado actual del inmueble en segundos.
- Steps:
  1) Abrir app o web.
  2) Seleccionar inmueble (si hay multiples).
  3) Ver resumen y detalle de pagos.
- Success metrics: tiempo a primer valor <= 15s, success >= 99%.
- Friction risks: lista lenta, falta de cache, copy confuso, filtros pobres.
- Premium upgrades: skeletons, cache con TTL, filtros rapidos, empty states utiles.

## 2) Reportar pago
- Goal: reportar pago con confirmacion clara y sin friccion.
- Steps:
  1) Elegir inmueble.
  2) Ver saldo y periodo.
  3) Cargar datos del pago + comprobante.
  4) Enviar y recibir confirmacion.
- Success metrics: success >= 98%, error validacion <= 1%, soporte <= 2%.
- Friction risks: validaciones tardias, carga de archivo lenta, errores de red.
- Premium upgrades: prefill, validacion en tiempo real, progreso, idempotencia,
  recibo descargable y estado visible en historial.

## 3) Novedades y avisos
- Goal: enterarse de anuncios y eventos sin ruido.
- Steps:
  1) Abrir feed.
  2) Leer detalle.
  3) Marcar como leido o guardar.
- Success metrics: apertura >= 60%, lectura completa >= 35%.
- Friction risks: notificaciones tardias, ruido, contenido sin accion.
- Premium upgrades: segmentacion, acciones rapidas, digest semanal, push real.

## Global friction list (v1)
- Estados de red poco claros.
- Inconsistencia visual entre pantallas.
- Falta de cache y offline basico.
- Falta de indicadores de progreso en procesos largos.
