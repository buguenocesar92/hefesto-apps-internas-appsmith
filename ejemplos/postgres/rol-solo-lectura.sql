-- =============================================================================
-- Hefesto Studio - Kit Appsmith Apps internas
-- EJEMPLOS - Rol de PostgreSQL de SOLO LECTURA
-- -----------------------------------------------------------------------------
-- POR QUE EXISTE ESTE ARCHIVO
--   Appsmith es un constructor visual: cualquiera con permiso de edicion de
--   una app puede escribir una consulta SQL. Si esa conexion usa un rol con
--   permisos de escritura sobre la base de PRODUCCION, una consulta mal
--   escrita —o un descuido de un constructor— puede modificar o borrar datos
--   reales.
--
--   La mitigacion mas simple y mas efectiva es que el rol de la app NO pueda
--   escribir. Este archivo crea ese rol.
--
-- ADVERTENCIA
--   *** DEMOSTRACION. Revisar y ajustar los nombres antes de usar en
--   produccion. Hefesto no ejecuto este script contra un PostgreSQL real. ***
--
-- Licencia MIT (Hefesto Studio)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Crear el rol
-- -----------------------------------------------------------------------------
-- IMPORTANTE: reemplazar CONTRASENA_DE_DEMOSTRACION por una contraseña real
-- generada al azar. Este texto NO debe quedar en el archivo final.
--
-- El rol NO tiene LOGIN: se crea con NOLOGIN y se le asigna a un usuario de
-- login. Asi el rol es solo un conjunto de permisos.
-- -----------------------------------------------------------------------------
CREATE ROLE appsmith_lectura
    WITH NOLOGIN
    PASSWORD 'CONTRASENA_DE_DEMOSTRACION_CAMBIAR';

-- -----------------------------------------------------------------------------
-- 2. Permisos
-- -----------------------------------------------------------------------------
-- CONNECT: poder abrir la conexion a la base. Es lo minimo indispensable.
-- USAGE sobre el esquema: poder ver los objetos.
-- SELECT sobre las tablas y vistas: leer, nada mas.
--
-- NO se otorga INSERT, UPDATE, DELETE ni TRUNCATE en ningun objeto. Tampoco
-- CREATE, porque un constructor no necesita crear objetos.
--
-- Nombres de esquema de ejemplo: hay que ajustarlos a los reales.
-- -----------------------------------------------------------------------------
GRANT CONNECT ON DATABASE demo_pedidos TO appsmith_lectura;
GRANT USAGE  ON SCHEMA public          TO appsmith_lectura;
GRANT SELECT ON ALL TABLES    IN SCHEMA public TO appsmith_lectura;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO appsmith_lectura;

-- Para que las tablas nuevas queden cubiertas automaticamente, en vez de tener
-- que repetir el GRANT cada vez que el equipo de datos agrega una tabla.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO appsmith_lectura;

-- -----------------------------------------------------------------------------
-- 3. Usuario de login
-- -----------------------------------------------------------------------------
-- El usuario real, con la contraseña real. Este es el que se configura en la
-- conexion de Appsmith.
-- -----------------------------------------------------------------------------
CREATE USER appsmith_app WITH PASSWORD 'CONTRASENA_REAL_AQUI';
GRANT appsmith_lectura TO appsmith_app;

-- -----------------------------------------------------------------------------
-- 4. Comprobacion
-- -----------------------------------------------------------------------------
-- Conectarse con appsmith_app y verificar que lo de abajo falla.
--
--   SELECT * FROM pedido LIMIT 1;   -- debe funcionar
--   DELETE FROM pedido WHERE 1=1;  -- debe fallar con "permiso denegado"
--   UPDATE pedido SET estado='x';   -- debe fallar
--
-- Si esos comandos de escritura NO fallan, la conexión NO está en solo
-- lectura y hay que detener el proyecto hasta corregirla.
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- 5. Para revertir (revisar antes de ejecutar)
-- -----------------------------------------------------------------------------
-- DROP OWNED BY appsmith_app;
-- DROP ROLE appsmith_app;
-- DROP ROLE appsmith_lectura;
--
-- Ojo: DROP OWNED BY borra los objetos propiedad de esos roles. Como no se le
-- dio propiedad de nada, en este caso no deberia borrar nada. Aun asi, nunca
-- ejecutar un DROP sin confirmar contra que base de datos se esta conectado.
-- -----------------------------------------------------------------------------