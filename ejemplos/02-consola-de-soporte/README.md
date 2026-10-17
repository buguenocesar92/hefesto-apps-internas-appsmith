# EJEMPLO 2 — Consola de soporte

> ## ⚠️ DEMOSTRACIÓN — NO ES UN PRODUCTO ENTREGABLE
> Material de muestra para mostrar capacidades y practicar. Datos inventados,
> correos con el dominio reservado `ejemplo.cl`. **No hay datos de personas ni
> de casos reales.** El esquema no tiene auditoría, no envía correos y no
> integra con ningún sistema de ticketing externo.

---

## Qué demuestra este ejemplo

Una mesa de ayuda donde el equipo de soporte abre una pantalla, ve la cola de
tickets ordenada por urgencia real (primero lo que se pasó de SLA, después lo
más antiguo), abre un caso y lee la conversación completa.

A diferencia del ejemplo del panel de pedidos, este **sí tiene un concepto de
cola y de SLA**, que es lo que convierte un listado en una herramienta de
trabajo.

## Fuente de datos de ejemplo

| Elemento | Valor |
|---|---|
| Motor | PostgreSQL 10 o superior |
| Base | `demo_soporte` (nombre sugerido) |
| Esquema | `esquema.sql` de esta carpeta |
| Carga de datos falsos | `carga-demo.sql` de esta carpeta |
| Consultas para Appsmith | `consultas.sql` de esta carpeta |
| Tipo de usuario | Solo lectura (ver `../postgres/rol-solo-lectura.sql`) |

### Levantar la base de demostración

```bash
createdb demo_soporte
psql -h localhost -U postgres -d demo_soporte -f esquema.sql
psql -h localhost -U postgres -d demo_soporte -f carga-demo.sql
```

La comprobación final debe listar `DEMO-1002`, `DEMO-1004` y `DEMO-1010` como
tickets fuera de SLA.

## Cómo se construye la app en Appsmith

Igual que en el ejemplo 1, el kit entrega la receta y las consultas, no un
`.json` importable (ver la explicación en el README del ejemplo 1).

### Paso 1 — Conexión

`Data` → `Connections` → `+ New` → **PostgreSQL**

| Campo | Valor |
|---|---|
| Base | `demo_soporte` |
| Connection Mode | **Read Only** |
| SSL | Según el servidor |

### Paso 2 — Consultas

Pegar desde `consultas.sql`:

| Query | Qué hace | Cuándo corre |
|---|---|---|
| `ConsultarCola` (Q1) | Cola principal con SLA | Al abrir y al cambiar filtros |
| `ConsultarIndicadores` (Q2) | Barra superior de KPI | Al abrir y cada vez que cambia la cola |
| `ConsultarCargaAgentes` (Q3) | Tickets por agente | Al abrir |
| `ConsultarConversacion` (Q4) | Mensajes de un ticket | Al hacer clic en una fila |
| `ConsultarSinAgente` (Q5) | Cola sin dueño | Al abrir |
| `ConsultarHistorialCliente` (Q6) | Otros casos del cliente | Al abrir un ticket |

Variables sugeridas:

| Variable | Tipo | Valor por defecto |
|---|---|---|
| `estado` | Texto | `""` |
| `prioridad` | Texto | `""` |
| `agente` | Texto | `""` |
| `solo_vencidos` | Booleano | `false` |
| `limite_registros` | Número | `50` |
| `id_ticket` | Número | `0` |
| `cliente` | Texto | `""` |

> La cola tiene **muchas menos filas** que el panel de ventas. En una Pyme
> real puede haber entre 5 y 50 tickets abiertos. El `LIMIT` de 50 alcanza
> de sobra, pero déjalo igual: una consulta sin tope es un riesgo, no una
> tedura.

### Paso 3 — Pantalla

```
+------------------------------------------------------------------+
| [KPIs: abiertos] [fuera de SLA] [esperando cliente] [TMR]         |
+------------------------------------------------------------------+
| Filtros: [Select estado] [Select prioridad] [Select agente]        |
|         [Switch solo vencidos]  [Btn recargar]                     |
+----------------------------------+-------------------------------+
| [Table cola]  (Q1)                | [Table carga agentes] (Q3)    |
|  orden: SLA vencido, antiguedad  | [Table sin agente] (Q5)       |
+----------------------------------+-------------------------------+
| Al clic en fila -> modal:                                         |
|   datos del ticket + [Table conversación] (Q4) +                  |
|   [Table historial del cliente] (Q6)                              |
+------------------------------------------------------------------+
```

### Paso 4 — Encadenar la selección

En `Table cola` → *Row Click*:

```
{{ Variables1.setValue("id_ticket", TablaCola1.selectedRow.id) }}
{{ Variables1.setValue("cliente", TablaCola1.selectedRow.cliente) }}
{{ ConsultarConversacion.run() }}
{{ ConsultarHistorialCliente.run() }}
{{ ModalDetalle1.show() }}
```

En el *Switch* `solo vencidos` → *onChange*:

```
{{ ConsultarCola.run() }}
{{ ConsultarIndicadores.run() }}
```

### Paso 5 — Colores por prioridad

Para que la cola se lea de un vistazo, usar estilos condicionales en la
columna `prioridad`:

- `urgente` → fondo rojo claro
- `alta` → fondo naranjo claro
- `normal` → sin color
- `baja` → texto gris

Y en la columna `sla_vencido`, un icono rojo cuando sea `true`.

## Consideraciones de seguridad de este ejemplo

1. **Los comentarios internos no se deben mostrar a todos.** La columna
   `interno` marca las notas internas del equipo. En Appsmith hay que filtrar
   por rol o esconder esa columna en la app; ocultar la columna **no es
   seguridad**, solo Visibility en el widget.

2. **Una consola de soporte es una app de escritura.** En un caso real el
   agente necesita cambiar el estado del ticket y agregar comentarios. Eso
   obliga a abrir la conexión en modo lectura-escritura, que es el escenario
   de riesgo alto descrito en `docs/07-PRUEBAS-DE-ACEPTACION.md`. Este ejemplo se mantiene
   en solo lectura a propósito, y por eso **no** incluye las consultas de
   escritura.

3. **Datos personales.** Un ticket real contiene nombres, correos y a veces
   información de salud o datos bancarios. Antes de poner esto en producción,
   hay que revisar qué datos se muestran y ante quién.

## Qué NO demuestra

- Envío de correos automáticos.
- Integración con correo entrante (el endpoint existe en Appsmith pero requiere
  configurar el dominio MX).
- Asignación automática de agentes.
- Escalamiento por niveles.
- Auditoría de quién tocó qué: en Community Edition eso es una función de pago
  (ver `docs/08-SERVICIOS-COMERCIALES.md`).

---

**Licencia:** MIT (Hefesto Studio). Datos de demostración inventados.