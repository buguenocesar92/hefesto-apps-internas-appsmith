-- =============================================================================
-- Hefesto Studio - Kit Appsmith Apps internas
-- EJEMPLO 1 DE 2 - PANEL DE PEDIDOS  *** DATOS DE DEMOSTRACION ***
-- -----------------------------------------------------------------------------
-- QUE ES
--   Base de datos PostgreSQL de ejemplo, minima pero real, para construir un
--   panel de control de pedidos en Appsmith.
--
-- ADVERTENCIA
--   *** ESTO ES DEMOSTRACION. NO ES UN ESQUEMA DE PRODUCCION. ***
--   Los nombres de clientes, productos, correos y telefonos son inventados.
--   El dominio de correo es ejemplo.cl, reservado para documentacion.
--   No hay datos reales de ninguna Pyme en este archivo.
--
-- QUE HACE Y QUE NO HACE ESTE ESQUEMA
--   Hace     : mostrar pedidos, filtrar por estado y fecha, resumir ventas.
--   NO hace  : manage stock, emitir facturas, integrar pagos ni calcular
--               impuestos. Para eso estan los ERPs del mercado.
--   El panel LEE de esta base. No es la fuente de verdad de los pedidos: en un
--   proyecto real, esta base se alimenta desde el ERP o desde la API del
--   cliente, o se consulta directamente contra una replica de lectura.
--
-- COMO SE APLICA
--   psql -h HOST -p 5432 -U USUARIO -d NOMBRE_BASE -f esquema.sql
--
-- Requiere PostgreSQL 10 o superior por el uso de columnas IDENTITY.
--
-- Licencia MIT (Hefesto Studio)
-- =============================================================================

BEGIN;

-- Limpieza en orden inverso para que el script se pueda correr mas de una vez.
DROP TABLE IF EXISTS pedido_item CASCADE;
DROP TABLE IF EXISTS pedido      CASCADE;
DROP TABLE IF EXISTS producto    CASCADE;
DROP TABLE IF EXISTS cliente     CASCADE;
DROP VIEW  IF EXISTS v_pedidos_detallado CASCADE;
DROP VIEW  IF EXISTS v_ventas_diarias     CASCADE;

-- -----------------------------------------------------------------------------
-- Tablas
-- -----------------------------------------------------------------------------
CREATE TABLE cliente (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre     TEXT        NOT NULL,
    email      TEXT        NOT NULL,
    region     TEXT        NOT NULL,
    creado_en  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT cliente_email_unico UNIQUE (email)
);

CREATE TABLE producto (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku        TEXT          NOT NULL,
    nombre     TEXT          NOT NULL,
    categoria  TEXT          NOT NULL,
    precio     NUMERIC(12,2) NOT NULL CHECK (precio >= 0),
    CONSTRAINT producto_sku_unico UNIQUE (sku)
);

CREATE TABLE pedido (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente_id BIGINT      NOT NULL REFERENCES cliente(id),
    estado     TEXT        NOT NULL DEFAULT 'pendiente',
    canal      TEXT        NOT NULL DEFAULT 'web',
    total      NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    creado_en  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pedido_estado_valido
        CHECK (estado IN ('pendiente','pagado','preparando','enviado','entregado','cancelado'))
);

CREATE TABLE pedido_item (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pedido_id       BIGINT        NOT NULL REFERENCES pedido(id) ON DELETE CASCADE,
    producto_id     BIGINT        NOT NULL REFERENCES producto(id),
    cantidad        INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario >= 0)
);

-- Indices para los filtros tipicos del panel: por estado y por fecha.
CREATE INDEX idx_pedido_estado ON pedido (estado);
CREATE INDEX idx_pedido_fecha  ON pedido (creado_en DESC);
CREATE INDEX idx_item_pedido   ON pedido_item (pedido_id);

-- -----------------------------------------------------------------------------
-- Vistas de apoyo
-- -----------------------------------------------------------------------------
-- El panel consulta estas vistas y no las tablas sueltas: asi las consultas de
-- Appsmith se mantienen simples y el SQL complejo queda en la base de datos.
CREATE VIEW v_pedidos_detallado AS
SELECT
    p.id                          AS pedido_id,
    p.estado,
    p.canal,
    p.creado_en,
    c.nombre                      AS cliente,
    c.region,
    COUNT(i.id)                   AS lineas,
    COALESCE(SUM(i.cantidad), 0)  AS unidades,
    COALESCE(SUM(i.cantidad * i.precio_unitario), 0) AS total_real
FROM pedido p
JOIN cliente c ON c.id = p.cliente_id
LEFT JOIN pedido_item i ON i.pedido_id = p.id
GROUP BY p.id, p.estado, p.canal, p.creado_en, c.nombre, c.region;

CREATE VIEW v_ventas_diarias AS
SELECT
    date_trunc('day', creado_en)::date AS dia,
    estado,
    COUNT(*)       AS pedidos,
    SUM(total_real) AS monto
FROM v_pedidos_detallado
GROUP BY 1, 2;

COMMIT;