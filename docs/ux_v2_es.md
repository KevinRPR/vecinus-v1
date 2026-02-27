# Vecinus UX V2 - Mini design system, pantallas clave y mapa de flujo

Objetivo: renovar la imagen con un tono institucional humano, ordenado y pensado para espacios compartidos. Modo claro por defecto; modo oscuro opt-in.

## 1) Mini design system (v2)

### Paleta (basada en el logo)
- Primario: #539091
- Secundario: #0A5D9B
- Acento humano: #F3B176
- Oscuros (hover/press): #477C7B, #084B7A, #E59B5E

Neutrales (claro por defecto)
- Bg: #F7F6F2
- Surface: #FFFFFF
- Surface alt: #F1F2F4
- Border: #E3E6EA
- Text strong: #1F2937
- Text body: #334155
- Text muted: #667085

Estados
- Success: #2F8F5B
- Warning: #B7791F
- Error: #C53030
- Info: #0C6DA8

Modo oscuro (opt-in)
- Bg: #0E141B
- Surface: #141B24
- Surface alt: #182132
- Border: #2A3441
- Text strong: #E6E8EB
- Text body: #CBD5E1
- Text muted: #94A3B8

### Tipografia
- Titulos: "Source Serif 4" (600-700)
- Cuerpo: "Source Sans 3" (400-600)
- Numeros: tabular lining (alinear montos)

Escala sugerida (px)
- Display 28/34, Title 22/28, Subtitle 18/24
- Body 16/24, Small 13/18, Caption 12/16

### Espaciado y layout
- Escala: 4, 8, 12, 16, 20, 24, 32, 40
- Padding de pagina: 20 (mobile), 24-28 (tablet)
- Secciones: 24 de separacion vertical
- Filas de lista: 12-16 de separacion

### Radio y elevacion
- Card: 14
- Input: 10
- Chip: 16-20
- Shadow suave en claro (0,6,16,0.08); en oscuro usar bordes en vez de sombra

### Componentes clave
- App bar: titulo claro, subtitulo contextual (condominio/unidad)
- Card: borde fino + sombra minima
- List item: icono lineal + titulo + meta + monto a la derecha
- Chip de estado: fondo tintado + texto fuerte (12-13 px)
- Button primario: filled brand blue, 14-16 px, alto 48
- Button secundario: outline teal
- Link: brand blue 600 con underline en hover
- Inputs: label arriba, helper abajo, error visible en rojo

## 2) Pantallas clave (aplicacion del sistema)

### A) Detalle de pago (redisenado)
Objetivo: dar claridad, orden y confianza. Mostrar el estado y el siguiente paso.

Estructura (orden):
1. App bar
   - Titulo: "Detalle de pago"
   - Subtitulo: condominio + unidad (en barra secundaria o debajo del titulo)
2. Card "Estado de cuenta"
   - Estado (chip): "Pendiente / Atrasado / Sin deuda / En proceso"
   - Monto principal en grande
   - Linea de contexto: "Proximo pago: fecha"
   - Mensaje de cobertura si existe (pago parcial o total)
   - CTA primario: "Reportar pago"
3. Seccion "Desglose de la deuda"
   - Lista tipo ledger: concepto, fecha, estado chip, monto, action "Documento"
   - Total al final en linea destacada
4. Seccion "Pagos reportados"
   - Cards por reporte con: id, fecha, monto, estado, "Ver comprobante"
   - Mensaje de estado si esta en proceso o rechazado
5. Acceso a "Historial de pagos" como link secundario

Estados y vacios:
- Sin deuda: card principal en verde suave + CTA oculta o secundaria "Ver historial"
- Sin documentos: deshabilitar "Documento" con texto "No disponible"
- Sin pagos reportados: bloque vacio con icono y copy humano
- Error de carga: bloque con CTA "Reintentar" y texto breve

### B) Reportar pago (redisenado)
Objetivo: reducir friccion y dar seguridad paso a paso.

Stepper (4 pasos) + resumen pegajoso:
1. Monto
   - Deuda total visible
   - Toggle "Pago total / Personalizado"
   - Input monto USD con helper de moneda
   - CTA: "Elegir metodo de pago"
2. Metodo de pago
   - Lista de bancos en cards
   - Muestra tasa y monto en moneda local cuando aplica
   - Link "Cambiar monto"
3. Datos bancarios
   - Tabla con filas copiables
   - Resumen de conversion y tasa
   - CTA: "Ya realice el pago"
4. Registrar pago
   - Referencia (obligatoria)
   - Fecha de pago
   - Adjuntar comprobante
   - Observaciones (opcional)
   - CTA: "Enviar reporte"

Pantalla de exito:
- Icono + mensaje institucional humano
- Info: "Conciliando tu pago"
- CTA: "Volver a detalle"

Estados y vacios:
- Sin bancos: card vacio + CTA "Contactar administracion"
- Sin deudas: "No hay deuda pendiente" + CTA "Ver historial"
- Error de envio: mensaje corto + CTA "Reintentar"
- Comprobante faltante: inline error bajo el campo

## 3) Mapa de flujo completo (con estados y vacios)

Inicio y autenticacion
- Splash/AnimatedSplash -> Login
- Login ok -> MainShell (tabs)
- Login error -> mensaje + reintentar

Tab Inicio (Dashboard)
- Estado general (cards de inmuebles)
- Empty: "Aun no hay inmuebles asignados"
- Error: "No se pudo cargar"
- Acceso a Inmueble detail

Tab Pagos
- Lista de inmuebles con saldo
- Empty: "No hay deudas"
- Error: "No se pudo cargar"
- Navega a Detalle de pago

Detalle de pago
- Ver desglose, documentos, pagos reportados
- Accion: Reportar pago (flujo)
- Accion: Historial pagado
- Empty en secciones: "Sin deuda / Sin reportes"
- Error: "No se pudieron cargar reportes"

Reportar pago (stepper)
- Paso 1 Monto -> Paso 2 Banco -> Paso 3 Datos -> Paso 4 Form -> Exito
- Empty: sin bancos, sin deuda
- Error: validaciones locales + error de envio

Historial de pagadas
- Lista de pagos confirmados
- Empty: "Aun no hay pagos registrados"

Tab Alertas (Notificaciones)
- Lista de notificaciones
- Empty: "No hay alertas"
- Error: "No se pudo cargar"
- Accion: abrir detalle o documento externo

Tab Perfil (Usuario)
- Ver y editar datos
- Preferencias: idioma, tema (modo oscuro opt-in)
- Error: validacion / guardado

Estados globales
- Loading: skeleton o spinner con texto breve
- Offline: banner sutil con CTA "Reintentar"
- Sin permisos: mensaje institucional con guia de soporte
