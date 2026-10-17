-- =============================================================================
-- Hefesto Studio - Kit Appsmith Apps internas
-- EJEMPLO 1 DE 2 - PANEL DE PEDIDOS - CONSULTAS PARA APPSMITH
-- -----------------------------------------------------------------------------
-- *** DEMOSTRACION. Todas las consultas son de SOLO LECTURA. ***
--
-- COMO USAR ESTE ARCHIVO EN APPSMITH
--   1. Crear la fuente de datos en Appsmith: Data > Connections > PostgreSQL
--   2. Pegar cada consulta como un Query nuevo dentro de esa conexion.
--   3. Los marcadores {{ }} son variables de Appsmith. Se reemplazan en
--      tiempo de ejecucion y van entre comillas simples o numericos segun
--      corresponda.
--
-- NOTA CRITICA DE SEGURIDAD
--   Cada consulta lleva su propio COMMENT ON al final, con el texto
--   "Solo lectura: SELECT". Appsmith usa esa marca para decidir si la conexion
--   puede correr la consulta con permisos reducidos.
--   Ver docs/07-PRUEBAS-DE-ACEPTACION.md, items V16 y R3.
--
-- Licencia MIT (Hefesto Studio)
-- =============================================================================


-- =============================================================================
-- Q1 - Indicadores de la cabecera
-- Devuelve una sola fila con los KPI del panel.
-- Las variables de fecha son obligatorias para no traer toda la historia.
-- =============================================================================
SELECT
    COUNT(*)                                                      AS total_pedidos,
    COALESCE(SUM(total_real), 0)                                  AS monto_total,
    COUNT(*) FILTER (WHERE estado = 'pendiente')                  AS pendientes,
    COUNT(*) FILTER (WHERE estado IN ('pagado','preparando','enviado')) AS en_proceso,
    COUNT(*) FILTER (WHERE estado = 'cancelado')                  AS cancelados,
    COALESCE(ROUND(AVG(total_real)), 0)                           AS ticket_promedio
FROM v_pedidos_detallado
WHERE creado_en BETWEEN {{desde}}::timestamptz AND {{hasta}}::timestamptz;
-- Solo lectura: SELECT


-- =============================================================================
-- Q2 - Resumen por dia para el grafico
-- Una fila por dia y estado. El widget Chart de Appsmith consume esto directo.
-- =============================================================================
SELECT
    dia,
    estado,
    COUNT(*)       AS pedidos,
    SUM(monto)     AS monto
FROM v_ventas_diarias
WHERE dia BETWEEN {{desde}}::date AND {{hasta}}::date
GROUP BY dia, estado
ORDER BY dia ASC;
-- Solo lectura: SELECT


-- =============================================================================
-- Q3 - Tabla de pedidos con filtros
-- Es la consulta principal del panel. Se combina con los filtros de la UI.
-- Los parametros {{texto_busqueda}} y {{estado}} llegan siempre informed.
-- =============================================================================
SELECT
    pedido_id,
    cliente,
    region,
    estado,
    canal,
    creado_en,
    unidades,
    total_real,
    EXTRACT(EPOCH FROM (NOW() - creado_en)) / 3600      AS horas_transcurridas
FROM v_pedidos_detallado
WHERE creado_en BETWEEN {{desde}}::timestamptz AND {{hasta}}::timestamptz
  AND ( {{estado}} = '' OR estado = {{estado}} )
  AND ( {{texto_busqueda}} = ''
        OR cliente ILIKE '%' || {{texto_busqueda}} || '%'
        OR pedido_id::text = {{texto_busqueda}} )
ORDER BY creado_en DESC
LIMIT {{limite_registros}};
-- Solo lectura: SELECT


-- =============================================================================
-- Q4 - Detalle de un pedido
-- Se dispara al hacer clic en una fila de la tabla Q3.
-- OJO con el limite: siempre acotar. Un detalle sin filtro puede traer miles de
-- filas y tumbar el panel.
-- =============================================================================
SELECT
    i.id            AS linea_id,
    pr.sku,
    pr.nombre       AS producto,
    pr.categoria,
    i.cantidad,
    i.precio_unitario,
    (i.cantidad * i.precio_unitario) AS subtotal
FROM pedido_item i
JOIN producto pr ON pr.id = i.producto_id
WHERE i.pedido_id = {{id_pedido}}::bigint
ORDER BY i.id ASC
LIMIT 500;
-- Solo lectura: SELECT


-- =============================================================================
-- Q5 - Top de productos
-- Sirve para el widget de ranking. Top 10 fijo a proposito.
-- =============================================================================
SELECT
    pr.nombre AS producto,
    pr.categoria,
    SUM(i.cantidad)                    AS unidades_vendidas,
    SUM(i.cantidad * i.precio_unitario) AS monto
FROM pedido_item i
JOIN producto pr ON pr.id = i.producto_id
JOIN pedido p      ON p.id = i.pedido_id
WHERE p.creado_en BETWEEN {{desde}}::timestamptz AND {{hasta}}::timestamptz
  AND p.estado <> 'cancelado'
GROUP BY pr.nombre, pr.categoria
ORDER BY unidades_vendidas DESC
LIMIT 10;
-- Solo lectura: SELECT


-- =============================================================================
-- Q6 - Pedidos que llevan mas tiempo del esperado (ejemplo de alerta)
-- Marca los pedidos pagados que llevan mas de 48 horas sin pasar a enviado.
-- Sirve para enchufar un badge de alerta en el panel.
-- =============================================================================
SELECT
    pedido_id,
    cliente,
    estado,
    creado_en,
    ROUND(EXTRACT(EPOCH FROM (NOW() - creado_en)) / 3600, 1) AS horas_en_estado
FROM v_pedidos_detallado
WHERE estado = 'pagado'
  AND creado_en < NOW() - INTERVAL '48 hours'
ORDER BY creado_en ASC
LIMIT 50;
-- Solo lectura: SELECT