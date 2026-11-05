# Disponibilidad PepsiCo — indicador del Panel PepsiCo

Panel: https://claude.ai/artifact/6Bj8RK7GNP9QsBmsdu4ud7 (pestaña **Disponibilidad**)

PepsiCo exige una disponibilidad de productos del **100%**. La disponibilidad cuenta con la compra dentro del mes.

## Cómo se calcula

Disponibilidad = artículos activos del mes con al menos un remito de ingreso de PepsiCo (REMI-I) con fecha dentro del mes ÷ total de artículos activos del mes.

Llega al 100% cuando se compraron todos los artículos activos.

## Qué muestra la pestaña

- **Indicadores:** disponibilidad en %, artículos comprados, artículos que faltan comprar y días que quedan del mes.
- **Por unidad de negocio (BDU):** el mismo cálculo para GLOBAL, PEHUAMAR, CRACKERS y CEREALS.
- **Lista de artículos:** estado de cada uno (Comprado / Falta), con las fechas de compra. Trae de la pestaña de pedido el stock de hoy y los bultos sugeridos.
- **Copiar faltantes:** copia lo que falta comprar, para armar el pedido.

El mes se elige arriba y es el mismo que el de la pestaña **Objetivo de compra**.

## Carga de la lista mensual

1. Elegir el mes en la pestaña.
2. Subir el Excel de artículos activos de PepsiCo (por ejemplo, `Disponible de pepsico nov 26.xlsx`).
3. Confirmar.

La página toma la columna **"Material SAP"** como código de artículo y sólo los artículos con **Vigencia = 1**. La lista sólo la pueden cambiar el dueño del panel y quienes tengan acceso de editor.

## Estado al 05/11/2026

- La lista de noviembre ya está cargada: **99 artículos**.
- **Noviembre da 0%**, porque todavía no entró ningún remito de PepsiCo en el mes.
- **Referencia:** con la lista de noviembre, en octubre se compraron 96 de los 99 (**97%**). Faltaron:

| Código | Artículo |
|---|---|
| 300065477 | DORITOS QUESO 20GX6X10 TIR |
| 300065313 | LAYS CLASICAS 230GX13X1 |
| 300064854 | MANI PELADO TUBULAR 40GX100X1 |

## Pendientes y observaciones

- **Tarea diaria trabada.** La tarea programada *recibido-pepsico* (lunes a sábado, 8:00 y 14:00) arrancó el 05/11 a las 10:21 y está esperando la aprobación de un permiso. Hay que abrir esa ejecución en Programadas (o usar *Ejecutar ahora*) y aprobar lo que pida. Hasta entonces los remitos nuevos no llegan al panel. Los remitos de agosto a octubre ya están cargados.
- **Artículo 300060663 (CHEETOS QUESO 229GX12X1):** está en la lista de PepsiCo pero no en el catálogo de Gescom que lee el panel, así que no muestra stock. Si se compra, igual cuenta para la disponibilidad.
- La pestaña nueva todavía no se revisó visualmente.

## Datos técnicos

- Lista de activos: base del panel, colección `activos/<AAAA-MM>`.
- Compras recibidas: colección `recibido/<AAAA-MM>`. La escribe la tarea programada con `recibido-pepsico.ps1`, que toma de Gescom los REMI-I del proveedor 100 por fecha de comprobante (las FAC-A repiten los renglones y no se cuentan).
- Fuente del panel: `panel-pepsico.html`, en esta misma carpeta.
