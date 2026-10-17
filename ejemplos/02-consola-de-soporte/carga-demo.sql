-- =============================================================================
-- Hefesto Studio - Kit Appsmith Apps internas
-- EJEMPLO 2 DE 2 - CONSOLA DE SOPORTE - CARGA DE DEMOSTRACION
-- -----------------------------------------------------------------------------
-- *** DATOS INVENTADOS. Uso unicamente demostrativo. ***
--
-- Correos con el dominio reservado ejemplo.cl (RFC 2606). Los nombres de
-- clientes y el contenido de los comentarios son ficticios y no corresponden
-- a personas ni a empresas reales. Los tickets describen fallas genericas de
-- productos inventados.
--
-- Licencia MIT (Hefesto Studio)
-- =============================================================================

BEGIN;

INSERT INTO categoria (nombre) VALUES
  ('Acceso y cuentas'),
  ('Problemas de conexion'),
  ('Facturacion'),
  ('Reportes'),
  ('Solicitud de funcionalidad');

INSERT INTO agente (nombre, correo) VALUES
  ('Agente Demo Uno',   'agente1@ejemplo.cl'),
  ('Agente Demo Dos',   'agente2@ejemplo.cl'),
  ('Agente Demo Tres',  'agente3@ejemplo.cl');

-- -----------------------------------------------------------------------------
-- Tickets
-- Nota sobre los tiempos: los tickets urgentes y los de prioridad alta se crean
-- con horas de antiguedad superiores a su SLA para que el panel muestre alertas
-- desde el primer arranque.
-- -----------------------------------------------------------------------------
INSERT INTO ticket
  (codigo, cliente, correo_cliente, categoria_id, agente_id, prioridad, estado, asunto, creado_en, primera_respuesta_en, cerrado_en) VALUES
  ('DEMO-1001','Distribuidora Andes SpA','soporte1@ejemplo.cl',1,1,'urgente','en_curso',
   'No pueden ingresar al panel de pedidos',
   NOW() - INTERVAL '6 hours', NOW() - INTERVAL '5 hours', NULL),

  ('DEMO-1002','Comercial Rio Ltda','contacto@ejemplo.cl',2,NULL,'alta','abierto',
   'La app muestra error de conexion intermitente',
   NOW() - INTERVAL '30 hours', NULL, NULL),

  ('DEMO-1003','Agricola Valle Verde SpA','operaciones@ejemplo.cl',3,2,'normal','en_curso',
   'Consulta sobre documento de venta duplicado',
   NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days' + INTERVAL '2 hours', NULL),

  ('DEMO-1004','Servicios Norte Ltda','soporte2@ejemplo.cl',1,NULL,'alta','abierto',
   'Usuario bloqueado tras varios intentos fallidos',
   NOW() - INTERVAL '10 hours', NULL, NULL),

  ('DEMO-1005','Importadora Pacifico SpA','soporte3@ejemplo.cl',4,3,'baja','esperando_cliente',
   'Reporte mensual sale en blanco',
   NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days' + INTERVAL '5 hours', NULL),

  ('DEMO-1006','Ferreteria Sur Ltda','admin@ejemplo.cl',5,1,'normal','resuelto',
   'Solicitan agregar campo al formulario de pedido',
   NOW() - INTERVAL '8 days', NOW() - INTERVAL '8 days' + INTERVAL '3 hours',
   NOW() - INTERVAL '6 days'),

  ('DEMO-1007','Bodega Central SpA','operaciones@ejemplo.cl',2,3,'normal','cerrado',
   'Base de datos de prueba no estaba disponible',
   NOW() - INTERVAL '12 days', NOW() - INTERVAL '12 days' + INTERVAL '1 hour',
   NOW() - INTERVAL '11 days'),

  ('DEMO-1008','Transportes Rapidos Ltda','soporte@ejemplo.cl',3,NULL,'normal','abierto',
   'Pregunta por forma de facturacion',
   NOW() - INTERVAL '2 hours', NULL, NULL),

  ('DEMO-1009','Comercial Rio Ltda','contacto@ejemplo.cl',1,2,'baja','cerrado',
   'Solicita reinstatement de cuenta desactivada',
   NOW() - INTERVAL '20 days', NOW() - INTERVAL '20 days' + INTERVAL '4 hours',
   NOW() - INTERVAL '18 days'),

  ('DEMO-1010','Importadora Pacifico SpA','soporte3@ejemplo.cl',4,NULL,'urgente','abierto',
   'Reporte critico no carga para ningun usuario',
   NOW() - INTERVAL '9 hours', NULL, NULL);

-- -----------------------------------------------------------------------------
-- Conversaciones
-- -----------------------------------------------------------------------------
INSERT INTO ticket_comentario (ticket_id, autor, interno, cuerpo, creado_en) VALUES
  (1,'Agente Demo Uno',FALSE,'Buenas, estamos revisando el tema. Puede confirmar si el error aparece para todos los usuarios?', NOW() - INTERVAL '5 hours'),
  (1,'Soporte Distribuidora Andes',FALSE,'Si, aparece para los cuatro usuarios del local.', NOW() - INTERVAL '4 hours'),
  (1,'Agente Demo Uno',TRUE,'Nota interna: revisar la lista de usuarios suspendidos del fin de semana.', NOW() - INTERVAL '3 hours'),
  (3,'Agente Demo Dos',FALSE,'Podemos revisar el documento duplicado, enviarnos el numero por favor.', NOW() - INTERVAL '3 days' + INTERVAL '2 hours'),
  (6,'Agente Demo Uno',FALSE,'Anotado, lo levantamos como solicitud de funcionalidad.', NOW() - INTERVAL '8 days' + INTERVAL '3 hours'),
  (7,'Agente Demo Tres',FALSE,'Se restauro la base de prueba desde el respaldo de la semana pasada.', NOW() - INTERVAL '12 days' + INTERVAL '1 hour');

COMMIT;

-- -----------------------------------------------------------------------------
-- Comprobacion
-- -----------------------------------------------------------------------------
-- La consola debe mostrar tickets con SLA vencido: DEMO-1002, DEMO-1004 y
-- DEMO-1010, que son urgente (2 h), alta (8 h) y urgente (2 h) respectivamente.
SELECT codigo, prioridad, estado, ROUND(horas_abierto::numeric, 1) AS horas_abierto, sla_horas, sla_vencido
FROM v_sla
WHERE sla_vencido
ORDER BY horas_abierto DESC;