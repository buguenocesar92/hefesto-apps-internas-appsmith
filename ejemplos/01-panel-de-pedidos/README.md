# EJEMPLO 1 — Panel de pedidos

> ## ⚠️ DEMOSTRACIÓN — NO ES UN PRODUCTO ENTREGABLE
> Todo lo que hay en esta carpeta es **material de muestra**. Sirve para
> mostrar al cliente qué se puede lograr y para practicar, **no** para
> instalar tal cual en una Pyme. Los datos son inventados, los correos usan el
> dominio reservado `ejemplo.cl` y el esquema no tiene control de concurrencia,
> auditoría ni manejo de stock. **Antes de usarlo con datos reales hay que
> revisar y corregir el diseño de la base.**

---

## Qué demuestra este ejemplo

Un panel interno donde el jefe de ventas o el dueño de la Pyme ve, en una sola
pantalla, cómo van los pedidos hoy: cuántos hay, cuánto dinero representan,
cuáles están atascados y qué productos se están vendiendo más.

## Fuente de datos de ejemplo

| Elemento | Valor |
|---|---|
| Motor | PostgreSQL 10 o superior |
| Base | `demo_pedidos` (nombre sugerido) |
| Esquema | `esquema.sql` de esta carpeta |
| Carga de datos falsos | `carga-demo.sql` de esta carpeta |
| Consultas para Appsmith | `consultas.sql` de esta carpeta |
| Tipo de usuario | Solo lectura (ver `../postgres/rol-solo-lectura.sql`) |

### Levantar la base de demostración

```bash
createdb demo_pedidos
psql -h localhost -U postgres -d demo_pedidos -f esquema.sql
psql -h localhost -U postgres -d demo_pedidos -f carga-demo.sql
```

La última consulta de `carga-demo.sql` es una comprobación: debe devolver los
pedidos agrupados por estado.

## Cómo se construye la app en Appsmith

Este kit **no incluye un `.json` importable de la app**. El formato de
exportación de Appsmith (el DSL de aplicación) cambia entre versiones y no se
puede verificar sin una instancia real corriendo. Lo que sí se entrega es la
receta exacta para construirla, que es más útil para el cliente porque
entiende cada decisión.

### Paso 1 — Crear la conexión

`Data` → `Connections` → `+ New` → **PostgreSQL**

| Campo | Valor |
|---|---|
| Host | `localhost` o el host de la base, desde la red del contenedor |
| Puerto | `5432` |
| Nombre de base | `demo_pedidos` |
| Usuario | El rol de solo lectura creado en `rol-solo-lectura.sql` |
| Contraseña | La de ese rol |
| Connection Mode | **Read Only** |
| SSL | Según el servidor. En una base de prueba local se puede desactivar. |

> **De dónde sale la contraseña del usuario de la base.** Se guarda cifrada
> dentro de Appsmith usando `APPSMITH_ENCRYPTION_PASSWORD` y
> `APPSMITH_ENCRYPTION_SALT`. Si esos dos valores cambian después, las
> credenciales guardadas dejan de poder descifrarse.

### Paso 2 — Crear las consultas

En la conexión, `+ New` → `New Query` (no usar el botón *Generate* con IA: los
resultados no se revisan). Pegar cada consulta de `consultas.sql`.

Las variables `{{desde}}`, `{{hasta}}`, `{{estado}}`, `{{texto_busqueda}}`,
`{{limite_registros}}` e `{{id_pedido}}` **no se escriben a mano**: se crean
desde el panel derecho de Appsmith, en *Variables*, como constantes, o se
pasan desde los widgets con `{{Select1.selectedRowValue.estado}}`.

Sugerencia de tipos:

| Variable | Tipo | Valor por defecto |
|---|---|---|
| `desde` | Fecha | Hoy − 7 días |
| `hasta` | Fecha | Hoy + 1 día |
| `estado` | Texto | `""` (todos) |
| `texto_busqueda` | Texto | `""` |
| `limite_registros` | Número | `100` |
| `id_pedido` | Número | `0` |

> **Siempre acotar con `LIMIT`.** Una consulta sin límite puede traer cientos
> de miles de filas, llenar la memoria del contenedor de 8 GB y dejar el panel
> sin responder. El límite va en la consulta, no en el widget.

### Paso 3 — Armar la pantalla

`Page1` con esta disposición:

```
+--------------------------------------------------------------+
| Filtros: [DatePicker desde-hasta] [Select estado] [Input buscar] |
+--------------------------------------------------------------+
| [KPI total]  [KPI monto]  [KPI pendientes]  [KPI ticket prom.] |
+--------------------------------------------------------------+
| [Chart ventas por dia]        |  [Table top productos]       |
+--------------------------------------------------------------+
| [Table pedidos]  (Q3)                                          |
|   al hacer clic en una fila -> setear id_pedido y mostrar       |
|   [Table detalle]  (Q4)  en un modal o un panel lateral        |
+--------------------------------------------------------------+
| [Alert pedidos antiguos]  (Q6)                                |
+--------------------------------------------------------------+
```

Widgets de Appsmith: `Stat widget` para los KPI, `Chart widget` para el
gráfico, `Table widget` para las tablas, `Select widget`, `DatePicker`,
`Input widget`, `Alert widget`.

### Paso 4 — Disparar las consultas al cambiar un filtro

En cada filtro, en *Events* → *onClick* / *onFilterUpdate*, encadenar:

```
{{ ConsultaPedidos.run() }}
```

En `Q3`, en el *Table widget* → *Row Click*:

```
{{ Variables1.setValue("id_pedido", Select1.selectedRowValue.pedido_id) }}
{{ ConsultaDetallePedido.run() }}
{{ MostrarDetalle1.show() }}
```

> **Límite real de este patrón.** `onClick` de una fila no se dispara al hacer
> clic con el dedo en un móvil en todas las versiones. Para soporte táctil hay
> que agregar una columna con un botón o usar la propiedad `selectedRow`. Esto
> **no fue probado por Hefesto** y hay que ajustarlo en la práctica.

### Paso 5 — Permisos

`Settings` → `Roles` → crear un rol *Venta* y asignarle **solo lectura** sobre
esta aplicación. Ver `docs/04-PRIMERA-CUENTA-Y-USUARIOS.md`.

## Qué se aprende con este ejemplo

- Conectar un PostgreSQL externo con una conexión de solo lectura.
- Filtrar con widgets y pasar variables a las consultas.
- Un KPI, un gráfico y dos tablas en una sola pantalla.
- Limitar resultados para que el panel no se caiga.

## Qué NO demuestra

- Escritura. Este ejemplo **solo lee**. Para crear o editar pedidos hay que
  abrir la conexión en modo lectura-escritura, lo que cambia toda la
  evaluación de riesgo (ver `docs/07`).
- Permisos por fila: ver el pedido de una región y no el de otra.
- Autenticación de usuarios finales dentro de Appsmith más allá de los roles.
- Exportar a Excel o PDF. Se puede agregar, pero no se incluyo.

---

**Licencia:** MIT (Hefesto Studio). Datos de demostración inventados.