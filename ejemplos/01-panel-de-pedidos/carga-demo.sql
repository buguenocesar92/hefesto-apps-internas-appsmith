-- =============================================================================
-- Hefesto Studio - Kit Appsmith Apps internas
-- EJEMPLO 1 DE 2 - PANEL DE PEDIDOS - CARGA DE DEMOSTRACION
-- -----------------------------------------------------------------------------
-- *** DATOS INVENTADOS. Uso unicamente demostrativo. ***
--
-- Correos con dominio ejemplo.cl, reservado por la RFC 2606 para
-- documentacion. No usar datos de clientes reales en un kit que se reparte.
--
-- Las fechas se generan en relacion a CURRENT_DATE para que el panel siempre
-- tenga datos de "hoy" y de los ultimos dias al momento de correrlo.
--
-- Licencia MIT (Hefesto Studio)
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- Clientes
-- -----------------------------------------------------------------------------
INSERT INTO cliente (nombre, email, region) VALUES
  ('Distribuidora Andes SpA',   'compras@ejemplo.cl',       'Metropolitana'),
  ('Comercial Rio Ltda',        'pedidos@ejemplo.cl',       'Valparaiso'),
  ('Agricola Valle Verde SpA',  'abastecimiento@ejemplo.cl','O''Higgins'),
  ('Servicios Norte Ltda',      'administracion@ejemplo.cl','Antofagasta'),
  ('Importadora Pacifico SpA',  'logistica@ejemplo.cl',     'Biobio'),
  ('Ferreteria Sur Ltda',       'ventas@ejemplo.cl',        'La Araucania'),
  ('Bodega Central SpA',        'operaciones@ejemplo.cl',   'Metropolitana'),
  ('Transportes Rapidos Ltda',  'coordinacion@ejemplo.cl',  'Maule');

-- -----------------------------------------------------------------------------
-- Productos
-- -----------------------------------------------------------------------------
INSERT INTO producto (sku, nombre, categoria, precio) VALUES
  ('DEMO-001', 'Caja carton 30x40',        'Embalaje',      450.00),
  ('DEMO-002', 'Film stretch 500mm',        'Embalaje',     3800.00),
  ('DEMO-003', 'Cinta adhesive 48mm',      'Embalaje',      890.00),
  ('DEMO-004', 'Etiqueta termica 10x15',   'Etiquetado',    1200.00),
  ('DEMO-005', 'Guantes de corte talla M', 'Seguridad',     3500.00),
  ('DEMO-006', 'Chaleco reflectante',      'Seguridad',     6900.00),
  ('DEMO-007', 'Pallet plastico 120x100',  'Bodega',       12500.00),
  ('DEMO-008', 'Contenedor 40L',           'Bodega',        8900.00);

-- -----------------------------------------------------------------------------
-- Pedidos y sus lineas
-- -----------------------------------------------------------------------------
-- 12 pedidos repartidos entre los ultimos 7 dias, en todos los estados
-- permitidos por la constraint, para que los filtros del panel se vean
-- poblados desde el primer arranque.
INSERT INTO pedido (cliente_id, estado, canal, total, creado_en) VALUES
  (1, 'entregado',  'web',    9200.00,  CURRENT_DATE - INTERVAL '6 days' - INTERVAL '3 hours'),
  (2, 'enviado',    'web',    15800.00, CURRENT_DATE - INTERVAL '5 days' - INTERVAL '1 hour'),
  (3, 'pagado',     'feria',  24800.00, CURRENT_DATE - INTERVAL '4 days' - INTERVAL '5 hours'),
  (4, 'preparando', 'web',    6900.00,  CURRENT_DATE - INTERVAL '3 days' - INTERVAL '2 hours'),
  (5, 'entregado',  'web',    31500.00, CURRENT_DATE - INTERVAL '2 days' - INTERVAL '4 hours'),
  (6, 'pendiente',  'web',    4300.00,  CURRENT_DATE - INTERVAL '2 days' - INTERVAL '30 minutes'),
  (7, 'pagado',     'feria',  18900.00, CURRENT_DATE - INTERVAL '1 day'  - INTERVAL '6 hours'),
  (1, 'enviado',    'web',    7400.00,  CURRENT_DATE - INTERVAL '1 day'  - INTERVAL '2 hours'),
  (8, 'cancelado',  'web',    1200.00,  CURRENT_DATE - INTERVAL '6 hours'),
  (2, 'pendiente',  'web',    22100.00, CURRENT_DATE - INTERVAL '4 hours'),
  (5, 'pagado',     'feria',  9800.00,  CURRENT_DATE - INTERVAL '2 hours'),
  (3, 'preparando', 'web',    27500.00, CURRENT_DATE - INTERVAL '45 minutes');

INSERT INTO pedido_item (pedido_id, producto_id, cantidad, precio_unitario) VALUES
  (1,  1, 10, 450.00),   (1,  4,  4, 1200.00),  (2,  5,  2, 3500.00),
  (3,  2,  4, 3800.00),  (3,  7,  1, 12500.00), (4,  6,  1, 6900.00),
  (5,  8,  3, 8900.00),  (6,  3,  5, 890.00),   (7,  2,  3, 3800.00),
  (7,  8,  1, 8900.00),  (8,  4,  6, 1200.00),  (9,  3,  1, 890.00),
  (10, 5,  4, 3500.00),  (10, 2,  1, 3800.00),  (11, 6,  1, 6900.00),
  (11, 4,  2, 1200.00),  (12, 8,  2, 8900.00),  (12,  7,  1, 12500.00);

COMMIT;

-- -----------------------------------------------------------------------------
-- Comprobacion
-- -----------------------------------------------------------------------------
-- Debe devolver 12 filas repartidas entre los seis estados.
SELECT estado, COUNT(*) AS pedidos, SUM(total_real) AS monto
FROM v_pedidos_detallado
GROUP BY estado
ORDER BY estado;