# Quality Bar (Web + Mobile)

## Scope
- Producto: Vecinus (web + mobile)
- Objetivo: experiencia premium y confiable en los 3 flujos clave.

## Pillars
- Visual polish: tipografia, jerarquia, espaciado consistente, iconos unificados.
- Motion polish: transiciones suaves, feedback de taps, estados claros.
- Speed: carga percibida rapida con skeletons y cache.
- Reliability: errores controlados, retries, estados offline.
- Trust: seguridad de sesiones y datos, mensajes claros.
- Accessibility: targets >= 44dp, contraste AA, labels en icon-only.

## Metrics (v1 targets)
- Crash-free sessions >= 99.8% (mobile).
- ANR-free sessions >= 99.5% (Android).
- API p95 <= 1.5s; timeout a 15s con mensaje humano.
- Cold start <= 2.5s en dispositivo gama media.
- Web LCP p75 <= 2.5s; TTI <= 3.5s.
- Flujo reportar pago: success >= 98%, error de validacion <= 1%.
- Tiempo a primer valor <= 2 min (login -> ver inmuebles).
- Accesibilidad: 100% de icon-only con label/tooltip.

## Release gate (v1)
- No bloqueos visuales (overflow, mojibake).
- 0 errores P0/P1 en flujos clave.
- QA en 3 perfiles de dispositivo + 2 navegadores.
