# Ejemplos — material de demostración

> ## ⚠️ TODO LO QUE HAY EN ESTA CARPETA ES DEMOSTRACIÓN
> Ninguno de estos archivos es un producto entregable. Sirven para mostrar al
> cliente qué se puede construir, para practicar y para Capacitar al equipo
> interno de Hefesto.

## Qué hay aquí

| Carpeta | Qué demuestra | Base de datos de ejemplo |
|---|---|---|
| `01-panel-de-pedidos/` | Panel de ventas: KPI, gráfico y tablas filtrables | `demo_pedidos` |
| `02-consola-de-soporte/` | Mesa de ayuda: cola con SLA, conversación por ticket | `demo_soporte` |
| `postgres/rol-solo-lectura.sql` | Rol de PostgreSQL que **no puede escribir** en la base | — |

## Por qué no hay un `.json` importable de las apps

Cada ejemplo trae su **esquema SQL**, su **carga de datos falsos** y sus
**consultas**, más un README con la receta de construcción paso a paso.

No se incluye un archivo de exportación de Appsmith importable con un clic, y
es deliberado: el formato de exportación de aplicaciones (el DSL) cambia entre
versiones y **no se pudo verificar** en este entorno, que no tiene Docker ni
una instancia corriendo. Entregar un `.json` que nadie ha abierto y que
probablemente no importe limpio en la versión fijada sería peor que no
entregarlo. La receta, en cambio, sirve aunque el formato cambie.

## Cómo usar estos ejemplos

1. Levantar la base de datos de demostración (comandos en el README de cada
   ejemplo).
2. Crear el rol de solo lectura con `postgres/rol-solo-lectura.sql`.
3. Conectar Appsmith a esa base con **Connection Mode: Read Only**.
4. Seguir la receta del README de cada ejemplo.

## Datos

- **Todos los datos son inventados.**
- Los correos usan `@ejemplo.cl`, dominio reservado por la RFC 2606 para
  documentación. Nunca deben aparecer datos reales en un kit que se reparte.
- Los nombres de personas, empresas, agentes y clientes son ficticios.
- Las conversaciones de tickets son genéricas y no corresponden a casos reales.
- No hay datos personales, financieros ni de salud.

## Aviso sobre escritura

Los dos ejemplos son de **solo lectura**, a propósito. Un panel interno que
también *crea o modifica* registros exige abrir la conexión en modo
lectura-escritura, lo que cambia por completo el análisis de riesgo: el
constructor visual pasa a poder ejecutar cualquier sentencia SQL contra la
base. Ese escenario está documentado en `docs/07-PRUEBAS-DE-ACEPTACION.md` y no se
demuestra aquí a propósito.

---

**Licencia:** MIT (Hefesto Studio).