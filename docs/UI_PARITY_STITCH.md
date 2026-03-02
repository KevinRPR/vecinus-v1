# UI Parity Stitch

## Reglas base
- Iconos: Material Symbols Rounded (IconsRounded) en AppBar, bottom nav y acciones.
- Colores: solo AppColors / Theme tokens (sin Color(0x...) en screens).
- Touch targets: >= 44x44 en icon-only (luna, ayuda, copiar, adjuntar).
- Texto: sin "null" visible y sin decimales infinitos.

## Pagos
Antes/Despues: header sin subtitulo y tarjetas con detalles extra; ahora header alineado al estilo global, card de resumen Stitch y CTA en flujo del scroll.
Checklist de paridad:
- iconos: rounded en header, cards y bottom nav.
- spacing: padding 16/20 consistente, cards con radius 20.
- tipografia: titulos 20px, labels en mayusculas con letter spacing.
- chips: Pendiente/Pagado/Todos con selected claro.
- CTA: boton inferior deshabilitado si no hay deuda.
- empty states: AppEmptyState para lista vacia.

## Alertas
Antes/Despues: lista sin agrupacion; ahora HOY / ESTA SEMANA con timestamps consistentes y app bar con iconos redondos.
Checklist de paridad:
- iconos: rounded, fondo circular suave.
- spacing: cards con 16px de padding y 12px de gap.
- tipografia: titulo 15px semibold, timestamp 11px.
- chips: n/a.
- CTA: acciones con AppIconButton.
- empty states: AppEmptyState cuando no hay alertas.

## Inicio
Antes/Despues: card con anillo y dot verde; ahora card de estado simple, alertas destacadas y CTA comunitaria.
Checklist de paridad:
- iconos: rounded en header y tarjetas.
- spacing: secciones separadas por 14px.
- tipografia: titulo 20px, subtitulos 12-14px.
- chips: badge "1 Nueva" en alertas.
- CTA: "Ver pagos" y "Participar ahora" visibles.
- empty states: alerta vacia usa AppEmptyState.

## Reportar pago
Antes/Despues: pasos mezclados; ahora stepper 1-3 (MONTO/BANCO/RECIBO) con flujo claro.
Checklist de paridad:
- iconos: rounded en stepper y copiar.
- spacing: cards con 14-16px y separaciones consistentes.
- tipografia: labels en mayusculas 10-11px.
- chips: Pago total / Personalizado coherentes.
- CTA: "Elegir metodo de pago" y "Enviar reporte" con estados.
- empty states: sin bancos muestra card informativa.

## Detalles (Pago + Inmueble)
Antes/Despues: datos con "null" y decimales largos; ahora formatos seguros y secciones claras.
Checklist de paridad:
- iconos: rounded en estado, respaldo y documentos.
- spacing: cards con 14-16px, listas con separadores.
- tipografia: montos en tabular figures.
- chips: estado (AL DIA / PENDIENTE / ATRASADO / EN PROCESO).
- CTA: "Reportar pago" y "Pagar ahora" con estado valido.
- empty states: sin deuda muestra AppEmptyState.

## Perfil
Antes/Despues: perfil sin consistencia; ahora tarjetas con radius 24 y soporte visible.
Checklist de paridad:
- iconos: rounded en settings y acciones.
- spacing: secciones con 18px y padding 20.
- tipografia: nombre 20px, subtitulo 12px.
- chips: n/a.
- CTA: "Contactar soporte" visible.
- empty states: n/a.

## Splash
Antes/Despues: splash basico; ahora logo centrado, tagline y progreso como Stitch.
Checklist de paridad:
- iconos: rounded fallback.
- spacing: vertical rhythm 20-32px.
- tipografia: marca 32px bold.
- chips: n/a.
- CTA: n/a.
- empty states: n/a.

## Generar reporte
Antes/Despues: cards sin iconos; ahora headers con iconos y radios a la derecha.
Checklist de paridad:
- iconos: rounded en headers y acciones.
- spacing: cards con 16px, gap 12-16px.
- tipografia: titulos 14-16px.
- chips: n/a.
- CTA: "Generar reporte" con icono.
- empty states: n/a.
