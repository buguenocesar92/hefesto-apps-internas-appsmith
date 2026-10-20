# 06 — Actualizaciones y reversión

> **Estado: kit preparado.** No se ejecutó ninguna actualización en un servidor
> real. Los procedimientos de abajo están construidos sobre la documentación
> oficial y sobre el comportamiento del kit, y deben probarse en un ambiente de
> prueba antes de tocar la instancia de un cliente.

## La regla de oro

> **Ninguna actualización de una instancia de cliente sin un respaldo
> verificado de esa misma instancia, hecho ese mismo día.**

Y una segunda regla, igual de importante: **probar la actualización en una copia
antes de hacerla en producción**. La forma barata de tener esa copia es
restaurar el respaldo en un segundo contenedor (más abajo está el procedimiento).

## Antes de actualizar

```bash
# 1. ¿Cómo está el servicio ahora?
docker compose ps
docker compose logs --tail=50 appsmith

# 2. Respaldar
./scripts/respaldo.sh

# 3. Verificar que el respaldo quedó completo
ls respaldos/respaldo-<marca>/COMPLETO
cd respaldos/respaldo-<marca> && sha256sum -c SHA256SUMS
```

Si el paso 3 falla, **no actualizar**. Un respaldo no verificado no es un
respaldo.

## Probar en una copia antes

Vale la pena montar una segunda instancia con los mismos datos:

```bash
# Copia del volumen actual
docker run --rm \
  -v appsmith-stacks:/origen:ro \
  -v appsmith-pruebas:/destino \
  --entrypoint sh appsmith/appsmith-ce:v2.5.0 \
  -c 'cd /origen && tar cf - . | (cd /destino && tar xf -)'

# Copia del compose con otro nombre de volumen y otro puerto
sed -e 's/127.0.0.1:8080:80/127.0.0.1:8090:80/' \
    -e 's/appsmith-stacks/appsmith-pruebas/' \
    compose.yaml > compose.pruebas.yaml
```

Levantar esa copia, entrar y verificar a mano lo importante: que las apps
abren, que las consultas devuelven datos, que los usuarios pueden entrar.

> Si la copia usa un dominio o una URL distintos, hay que ajustar
> `APPSMITH_BASE_URL`, porque la validación de `Origin` compara contra esa
> lista. Con `http://127.0.0.1:8090` la validación va a rechazar el origen.
> Para la prueba conviene levantar la copia en `http://localhost:8090` y poner
> `APPSMITH_BASE_URL=http://localhost:8090` en su `.env.pruebas`.

## Actualizar

### 1. Ver qué hay disponible

```bash
curl -s 'https://hub.docker.com/v2/repositories/appsmith/appsmith-ce/tags?page_size=25&ordering=last_updated'
```

Buscar la etiqueta de versión semántica más reciente (`vX.Y.Z`). **Ignorar
`latest` y `release`**: son etiquetas móviles.

> Al momento de preparar este kit, la etiqueta `release` apuntaba a un digest
> **distinto** del de `v2.5.0`, o sea a una compilación más nueva que todavía
> no tenía etiqueta semantica. Exactamente por eso el kit fija la versión.

### 2. Cambiar la versión

En `compose.yaml`:

```yaml
image: appsmith/appsmith-ce:v2.5.0   # -> appsmith/appsmith-ce:v2.6.0
```

Actualizar también el comentario del digest y la tabla de `VERSION.md`.

### 3. Levantar

```bash
docker compose pull
docker compose up -d
docker compose logs -f --tail=100 appsmith
```

La migración de la base interna ocurre en el arranque. **No interrumpir**: si se
corta a mitad de la migración, el estado queda inconsistente y la única salida
es restaurar.

### 4. Verificar

- [ ] `docker compose ps` muestra `healthy`.
- [ ] La interfaz carga en el navegador.
- [ ] Un usuario puede entrar.
- [ ] Una app con consultas abre y devuelve datos.
- [ ] Los logs no muestran errores de migración.

## Volver atrás

Si la actualización falla, la reversión es: restaurar el respaldo.

```bash
docker compose down
./scripts/restaurar.sh --archivo respaldos/respaldo-<marca-anterior> --force
docker compose up -d
```

Después de la reversión:

1. Confirmar que el volumen quedó limpio y que la cuarentena con lo anterior
   se puede borrar.
2. **Fijar `compose.yaml` de vuelta a la versión anterior** antes del siguiente
   despliegue. Si no, Coolify va a volver a subir la versión mala.

> La reversión por digest es una alternativa más limpia: fijar
> `image: appsmith/appsmith-ce@sha256:<digest>` hace que la imagen anterior se
   conserve en el servidor aunque se quite la etiqueta. Aun así, si la migración
   de la base ya corrió, **volver la imagen no basta**: hay que restaurar.

## Actualizaciones de seguridad

Appsmith pública correcciones de seguridad. Para una instancia de cliente:

1. Revisar la sección *Security* del repositorio de Appsmith, donde publican
   los avisos.
2. Si hay una corrección relevante, seguir el procedimiento normal.
3. Si es urgente y la versión corregida tiene problemas de arranque, restaurar
   el respaldo y volver a levantar.

> **Hefesto no verificó el proceso oficial de avisos de seguridad de Appsmith
> en esta sesión.** Antes de decirle a un cliente que Hefesto lo va a avisar
   cuando haya una actualización de seguridad, hay que confirmar que existe ese
   canal y subscribed de verdad. Sin eso, es una promesa que no se puede
   cumplir. Anotado en `07-PRUEBAS-DE-ACEPTACION.md`.

## Calendario sugerido para una Pyme

| Tarea | Frecuencia |
|---|---|
| Revisar si hay versión nueva | Trimestral |
| Actualizar | Semestral, o antes si hay corrección de seguridad |
| Respaldar | Diaria (cron) |
| **Probar una restauración completa desde cero** | **Trimestral** |

> La última fila es la importante. Un respaldo que nunca se restauró es una
> hipótesis, no un respaldo. Una vez por trimestre, levantar una instancia
> vacía, meter el último respaldo y confirmar que las apps aparecen.

## Tabla de versiones aplicadas

Llevar este registro por instancia. Es la primera pregunta que hace un cliente
cuando algo falla.

| Instancia | Versión actual | Fecha de actualización | Responsable | Resultado | Volver a versión |
|---|---|---|---|---|---|
| | | | | | |

---

Ver también: [`05-RESPALDOS-Y-RESTAURACION.md`](05-RESPALDOS-Y-RESTAURACION.md) ·
[`VERSION.md`](../VERSIÓN.md) ·
[`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md)