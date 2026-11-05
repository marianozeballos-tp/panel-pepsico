WITH ref AS (SELECT MAX(fecha_pedido) AS f FROM ventas WHERE borrada = 0),
foto AS (SELECT substr(actualizado, 1, 10) AS f, datos FROM respuestas WHERE ruta = 'cmd/inventario/api/v1/get-stock'),
art AS (SELECT json_extract(datos, '$.codigo') AS codigo, json_extract(datos, '$.descripcion') AS articulo, json_extract(datos, '$.tags') AS tags, json_extract(datos, '$.unidadesPorBulto') AS upb, json_extract(datos, '$.precioCosto') AS costo_bulto, json_extract(datos, '$.factorPeso') AS gramos, json_extract(datos, '$.bloqueado') AS bloqueado
  FROM catalogo WHERE tipo = 'articulos' AND vigente = 1 AND clave LIKE '%|1' AND json_extract(datos, '$.codigoProveedor') = '100' AND json_extract(datos, '$.codigoRubro') <> 'pepsico-1'),
st AS (SELECT json_extract(e.value, '$.codigoItem') AS codigo,
  SUM(CASE WHEN json_extract(s.value, '$.codigoDeposito') = '0' THEN json_extract(s.value, '$.cantidad') ELSE 0 END) AS dep0
  FROM foto, json_each(foto.datos) e, json_each(e.value, '$.stock') s GROUP BY 1),
ve AS (SELECT l.codigo_item AS codigo, SUM(l.cantidad * COALESCE(l.unidad_factor, 1)) AS u28,
  SUM(CASE WHEN l.fecha_pedido < date(ref.f, '-21 days') THEN l.cantidad * COALESCE(l.unidad_factor, 1) ELSE 0 END) AS sem1,
  SUM(CASE WHEN l.fecha_pedido >= date(ref.f, '-21 days') AND l.fecha_pedido < date(ref.f, '-14 days') THEN l.cantidad * COALESCE(l.unidad_factor, 1) ELSE 0 END) AS sem2,
  SUM(CASE WHEN l.fecha_pedido >= date(ref.f, '-14 days') AND l.fecha_pedido < date(ref.f, '-7 days') THEN l.cantidad * COALESCE(l.unidad_factor, 1) ELSE 0 END) AS sem3,
  SUM(CASE WHEN l.fecha_pedido >= date(ref.f, '-7 days') THEN l.cantidad * COALESCE(l.unidad_factor, 1) ELSE 0 END) AS sem4
  FROM venta_lineas l, ref WHERE l.codigo_tipo_venta = 'VEN' AND l.fecha_pedido >= date(ref.f, '-28 days') AND l.fecha_pedido < ref.f AND l.codigo_item IN (SELECT codigo FROM art) GROUP BY 1),
base AS (SELECT a.*, COALESCE(st.dep0, 0) AS dep0, COALESCE(ve.u28, 0) AS venta_28d, COALESCE(ve.sem1, 0) AS sem1, COALESCE(ve.sem2, 0) AS sem2, COALESCE(ve.sem3, 0) AS sem3, COALESCE(ve.sem4, 0) AS sem4,
  COALESCE(ve.u28, 0) / 28.0 AS diario, (SELECT f FROM foto) AS fecha_stock, date((SELECT f FROM ref), '-28 days') AS ventas_desde, date((SELECT f FROM ref), '-1 day') AS ventas_hasta,
  MAX(0, CAST(julianday(date('now', '-3 hours')) - julianday((SELECT f FROM foto)) AS INTEGER)) AS dias_desde_foto
  FROM art a LEFT JOIN st ON st.codigo = a.codigo LEFT JOIN ve ON ve.codigo = a.codigo),
hoy AS (SELECT *, dep0 AS stock_foto FROM base WHERE venta_28d > 0 OR dep0 > 0),
calc AS (SELECT *, MAX(0, stock_foto - CASE WHEN 1 THEN diario * dias_desde_foto ELSE 0 END) AS stock_hoy, diario * (14 + 0) AS objetivo FROM hoy),
ped AS (SELECT *, MAX(0, objetivo - stock_hoy) AS faltante FROM calc),
fin AS (SELECT *, CASE WHEN faltante <= 0 THEN 0 ELSE CAST(faltante / upb AS INTEGER) + (faltante / upb > CAST(faltante / upb AS INTEGER)) END AS bultos FROM ped)
SELECT codigo, articulo, CASE WHEN tags LIKE '%*P01%' THEN 'P01' WHEN tags LIKE '%*P02%' THEN 'P02' ELSE '' END AS portafolio, upb, bloqueado,
  ROUND(diario, 1) AS venta_diaria, venta_28d, sem1, sem2, sem3, sem4, dep0, stock_foto, ROUND(stock_hoy) AS stock_hoy,
  CASE WHEN diario > 0 THEN ROUND(stock_hoy / diario, 1) END AS dias_cobertura,
  ROUND(objetivo) AS stock_objetivo, bultos,
  ROUND(bultos * upb * gramos / 1000.0, 1) AS kg_pedido,
  ROUND(costo_bulto, 2) AS costo_bulto, ROUND(bultos * costo_bulto) AS costo_pedido,
  CASE WHEN diario = 0 THEN 'Sin venta' WHEN stock_hoy / diario < 3 THEN 'Quiebre' WHEN stock_hoy / diario < 14 THEN 'Pedir' WHEN stock_hoy / diario > 2 * 14 THEN 'Exceso' ELSE 'OK' END AS estado,
  fecha_stock, dias_desde_foto, ventas_desde, ventas_hasta
FROM fin ORDER BY bultos * costo_bulto DESC, venta_28d DESC