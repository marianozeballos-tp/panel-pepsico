# Panel PepsiCo

Copia de sólo lectura del Panel PepsiCo de Tienda Perfecta: https://marianozeballos-tp.github.io/panel-pepsico/

Tiene tres pestañas:

- **Pedido sugerido:** bultos a pedir para tener 14 días de stock en el depósito local (0), según la venta promedio de los últimos 28 días.
- **Objetivo de compra:** toneladas recibidas de PepsiCo en el mes (remitos REMI-I) contra el objetivo del mes.
- **Disponibilidad:** porcentaje de los artículos activos del mes que ya se compraron. Ver [disponibilidad-pepsico.md](disponibilidad-pepsico.md).

Los datos son una foto: están en `datos/` y se actualizan con `publicar-github.ps1`. El objetivo y la lista de artículos activos se cargan desde el panel original en claude.ai.

## Archivos

| Archivo | Qué es |
|---|---|
| `index.html` | La página publicada: `panel-pepsico.html` más `claude-shim.js`. |
| `panel-pepsico.html` | El panel original de claude.ai. |
| `claude-shim.js` | Hace que el panel lea `datos/*.json` en vez de Base Gescom y la base del panel. |
| `datos/` | Fotos de pedido, objetivos, recibido y artículos activos. |
| `recibido-pepsico.ps1` | Baja de Gescom los remitos de ingreso de PepsiCo por mes y artículo. |
| `pedido-pepsico.sql` | Consulta del pedido sugerido en Base Gescom (14 días, entrega en el día). |
| `guardar-pedido.ps1` | Guarda la respuesta de esa consulta como foto del pedido. |
| `publicar-github.ps1` | Arma `index.html` y `datos/` y los sube a este repo. |

La tarea programada `recibido-pepsico` (lunes a sábado, 8:00 y 14:00) actualiza los remitos, la foto del pedido, el objetivo y la lista de activos, y vuelve a publicar.
