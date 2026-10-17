-- =============================================================================
-- Hefesto Studio - Kit Appsmith Apps internas
-- EJEMPLO 2 DE 2 - CONSOLA DE SOPORTE  *** DATOS DE DEMOSTRACION ***
-- -----------------------------------------------------------------------------
-- QUE ES
--   Base de datos PostgreSQL de ejemplo para construir una consola de soporte
--   (mesa de ayuda) en Appsmith: cola de tickets, tiempos de respuesta y
--   comentarios.
--
-- ADVERTENCIA
--   *** ESTO ES DEMOSTRACION. NO ES UN ESQUEMA DE PRODUCCION. ***
--   Nombres, correos y conversaciones son inventados. El dominio de correo es
--   ejemplo.cl, reservado para documentacion. No hay datos reales.
--   Sin datos personales de clientes, sin entradas reales de casos de soporte.
--
-- QUE HACE Y QUE NO HACE
--   Hace     : mostrar la cola de tickets, priorizar por antiguedad, ver el
--               historial de cada caso y medir tiempos de respuesta.
--   NO hace  : enviar correos, integrar con correo entrante, escalar a un
--               sistema externo de ticketing, ni medir satisfaccion.
--
-- Requiere PostgreSQL 10 o superior por el uso de columnas IDENTITY.
-- Licencia MIT (Hefesto Studio)
-- =============================================================================

BEGIN;

DROP TABLE IF EXISTS ticket_comentario CASCADE;
DROP TABLE IF EXISTS ticket           CASCADE;
DROP TABLE IF EXISTS agente           CASCADE;
DROP TABLE IF EXISTS categoria        CASCADE;
DROP VIEW  IF EXISTS v_cola_operativa CASCADE;
DROP VIEW  IF EXISTS v_sla            CASCADE;

-- -----------------------------------------------------------------------------
-- Tablas
-- -----------------------------------------------------------------------------
CREATE TABLE categoria (
    id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre  TEXT NOT NULL,
    CONSTRAINT categoria_nombre_unico UNIQUE (nombre)
);

CREATE TABLE agente (
    id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre  TEXT NOT NULL,
    correo  TEXT NOT NULL,
    activo  BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT agente_correo_unico UNIQUE (correo)
);

CREATE TABLE ticket (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo          TEXT NOT NULL,
    cliente         TEXT NOT NULL,
    correo_cliente  TEXT NOT NULL,
    categoria_id    BIGINT REFERENCES categoria(id),
    agente_id       BIGINT REFERENCES agente(id),
    prioridad       TEXT NOT NULL DEFAULT 'normal',
    estado          TEXT NOT NULL DEFAULT 'abierto',
    asunto          TEXT NOT NULL,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    primera_respuesta_en TIMESTAMPTZ,
    cerrado_en      TIMESTAMPTZ,
    CONSTRAINT ticket_codigo_unico   UNIQUE (codigo),
    CONSTRAINT ticket_prioridad_ok   CHECK (prioridad IN ('baja','normal','alta','urgente')),
    CONSTRAINT ticket_estado_ok      CHECK (estado IN ('abierto','en_curso','esperando_cliente','resuelto','cerrado')),
    -- No se puede cerrar un ticket sin fecha de cierre, ni cerrarlo antes de
    -- que se haya creado. Estas reglas las impone la base, no la app.
    CONSTRAINT ticket_cierre_coherente CHECK (
        (estado IN ('resuelto','cerrado') AND cerrado_en IS NOT NULL)
        OR (estado NOT IN ('resuelto','cerrado') AND cerrado_en IS NULL)
    ),
    CONSTRAINT ticket_respuesta_coherente CHECK (
        primera_respuesta_en IS NULL OR primera_respuesta_en >= creado_en
    )
);

CREATE TABLE ticket_comentario (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id   BIGINT NOT NULL REFERENCES ticket(id) ON DELETE CASCADE,
    autor       TEXT NOT NULL,
    interno     BOOLEAN NOT NULL DEFAULT FALSE,
    cuerpo      TEXT NOT NULL,
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_ticket_estado    ON ticket (estado);
CREATE INDEX idx_ticket_fecha     ON ticket (creado_en DESC);
CREATE INDEX idx_ticket_agente    ON ticket (agente_id);
CREATE INDEX idx_comentario_ticket ON ticket_comentario (ticket_id);

-- -----------------------------------------------------------------------------
-- Vistas de apoyo
-- -----------------------------------------------------------------------------

-- Cola de trabajo: solo tickets que exigen accion ahora.
CREATE VIEW v_cola_operativa AS
SELECT
    t.id,
    t.codigo,
    t.cliente,
    t.asunto,
    t.prioridad,
    t.estado,
    cat.nombre AS categoria,
    ag.nombre  AS agente,
    t.creado_en,
    EXTRACT(EPOCH FROM (NOW() - t.creado_en)) / 3600 AS horas_abierto
FROM ticket t
LEFT JOIN categoria cat ON cat.id = t.categoria_id
LEFT JOIN agente    ag  ON ag.id  = t.agente_id;

-- Cumplimiento de SLA con una regla simple y explicita: segun prioridad,
-- un ticket abierto sin respuesta excede estas horas.
CREATE VIEW v_sla AS
SELECT
    v.*,
    CASE v.prioridad
        WHEN 'urgente' THEN 2
        WHEN 'alta'    THEN 8
        WHEN 'normal'  THEN 24
        ELSE                72
    END AS sla_horas,
    CASE WHEN t.primera_respuesta_en IS NULL
              AND EXTRACT(EPOCH FROM (NOW() - t.creado_en)) / 3600 >
                  CASE v.prioridad
                      WHEN 'urgente' THEN 2
                      WHEN 'alta'    THEN 8
                      WHEN 'normal'  THEN 24
                      ELSE                72
                  END
         THEN TRUE ELSE FALSE END AS sla_vencido
FROM v_cola_operativa v
JOIN ticket t ON t.id = v.id;

COMMIT;