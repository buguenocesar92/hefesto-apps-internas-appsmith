-- =============================================================================
-- Hefesto Studio - Kit Appsmith Apps internas
-- EJEMPLO 2 DE 2 - CONSOLA DE SOPORTE - CONSULTAS PARA APPSMITH
-- -----------------------------------------------------------------------------
-- *** DEMOSTRACION. Todas las consultas son de SOLO LECTURA. ***
--
-- Cada consulta lleva al final el marcador "Solo lectura: SELECT" para que
-- Appsmith la ejecute con permisos reducidos.
-- Ver docs/07-PRUEBAS-DE-ACEPTACION.md, items V16 y R3.
--
-- Licencia MIT (Hefesto Studio)
-- =============================================================================


-- =============================================================================
-- Q1 - Tablero de la cola
-- Devuelve una fila por ticket. Es la consulta central de la consola.
-- =============================================================================
SELECT
    id,
    codigo,
    cliente,
    asunto,
    prioridad,
    estado,
    COALESCE(categoria, 'Sin categoria')  AS categoria,
    COALESCE(agente, 'Sin asignar')        AS agente,
    creado_en,
    ROUND(horas_abierto::numeric, 1)       AS horas_abierto,
    sla_horas,
    sla_vencido
FROM v_sla
WHERE ({{estado}} = '' OR estado = {{estado}})
  AND ({{prioridad}} = '' OR prioridad = {{prioridad}})
  AND ({{agente}} = '' OR agente = {{agente}})
  AND (NOT {{solo_vencidos}} OR sla_vencido)
ORDER BY
    -- Primero lo vencido, luego por antiguedad.
    sla_vencido DESC,
    horas_abierto DESC
LIMIT {{limite_registros}};
-- Solo lectura: SELECT


-- =============================================================================
-- Q2 - Indicadores de la barra superior
-- ============================================================================
SELECT
    COUNT(*) FILTER (WHERE estado IN ('abierto','en_curso'))       AS abiertos,
    COUNT(*) FILTER (WHERE sla_vencido)                            AS fuera_de_sla,
    COUNT(*) FILTER (WHERE estado = 'esperando_cliente')            AS esperando_cliente,
    COUNT(*) FILTER (WHERE estado = 'resuelto'
                       AND cerrado_en > NOW() - INTERVAL '7 days')  AS resueltos_semana,
    ROUND(AVG(EXTRACT(EPOCH FROM (primera_respuesta_en - creado_en)) / 60)
          FILTER (WHERE primera_respuesta_en IS NOT NULL)::numeric, 1) AS minutos_respuesta_promedio
FROM v_sla;
-- Solo lectura: SELECT


-- =============================================================================
-- Q3 - Carga por agente
-- Para ver quien tiene mas tickets abiertos y repartir trabajo.
-- ============================================================================
SELECT
    COALESCE(agente, 'Sin asignar') AS agente,
    COUNT(*)                        AS tickets_abiertos,
    COUNT(*) FILTER (WHERE sla_vencido) AS fuera_de_sla
FROM v_sla
WHERE estado IN ('abierto','en_curso','esperando_cliente')
GROUP BY agente
ORDER BY tickets_abiertos DESC
LIMIT 50;
-- Solo lectura: SELECT


-- =============================================================================
-- Q4 - Conversacion de un ticket
-- Se dispara al seleccionar una fila de la cola (Q1).
-- El limite es indispensable: un ticket largo puede traer cientos de lineas.
-- =============================================================================
SELECT
    id,
    autor,
    interno,
    cuerpo,
    creado_en,
    EXTRACT(EPOCH FROM (creado_en - NOW())) / 60 AS minutos_relativos
FROM ticket_comentario
WHERE ticket_id = {{id_ticket}}::bigint
ORDER BY creado_en ASC
LIMIT 300;
-- Solo lectura: SELECT


-- =============================================================================
-- Q5 - Tickets sin agente asignado
-- Cola de trabajo sin dueño. Es el caso mas comun al comenzar el dia.
-- ============================================================================
SELECT
    id,
    codigo,
    cliente,
    asunto,
    prioridad,
    ROUND(horas_abierto::numeric, 1) AS horas_abierto
FROM v_sla
WHERE agente IS NULL
  AND estado IN ('abierto','en_curso')
ORDER BY horas_abierto DESC
LIMIT 100;
-- Solo lectura: SELECT


-- =============================================================================
-- Q6 - Historial del cliente
-- Al abrir un ticket, muestra los otros casos de ese cliente para contexto.
-- ============================================================================
SELECT
    id,
    codigo,
    asunto,
    prioridad,
    estado,
    creado_en,
    cerrado_en
FROM v_cola_operativa
WHERE cliente = {{cliente}}::text
  AND id <> {{id_ticket}}::bigint
ORDER BY creado_en DESC
LIMIT 20;
-- Solo lectura: SELECT