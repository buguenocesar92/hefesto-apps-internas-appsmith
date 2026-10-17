# VERSION.md

## Kit

| Campo | Valor |
|---|---|
| Nombre del kit | `hefesto-appsmith-apps-internas` |
| Version del kit | `1.0.0` |
| Estado | **kit preparado** (no desplegado ni probado en un servidor) |
| Fecha de preparacion | 2026-10-16 |
| Responsable | Hefesto Studio |

## Imagen de la aplicacion

| Campo | Valor |
|---|---|
| Repositorio | `appsmith/appsmith-ce` (Docker Hub oficial) |
| Etiqueta fijada | **`v2.5.0`** |
| Fecha de publicacion de la etiqueta | 2026-10-09 |
| Digest del indice | `sha256:5b6133ab8317b98edf9dc0315a02d12f9861ab2acc89386c0b1f5b7938dfeb90` |
| Plataformas del indice | `linux/amd64`, `linux/arm64` |
| Edicion | Community Edition |
| Licencia del nucleo | Apache-2.0 |

Etiquetas（NUNCA usar en produccion）
- `latest` y `release` son etiquetas moviles: cambian de contenido sin aviso.
  Dejarlas solo en un ambiente de prueba.

### Como se verifico

Consulta al registro de Docker Hub el 2026-10-16:

```
GET https://hub.docker.com/v2/repositories/appsmith/appsmith-ce/tags
    ?page_size=25&ordering=last_updated
```

Etiquetas devueltas, de mas reciente a mas antigua: `release`, `v2.5.0`,
`v2.4.3`, `v2.4.2`, `v2.4.1`, `v2.4`, entre otras.

`v2.5.0` es la etiqueta de version semantica mas reciente. La etiqueta `release`
se publico el 2026-10-16 con un digest distinto al de `v2.5.0`
(`sha256:2bcc973b52f2…`), o sea que apunta a una compilacion mas nueva que
todavia no tiene etiqueta semantica. Por eso el kit fija `v2.5.0` y no
`release`.

### Como fijar por digest (recomendado en produccion)

```bash
docker pull appsmith/appsmith-ce@sha256:5b6133ab8317b98edf9dc0315a02d12f9861ab2acc89386c0b1f5b7938dfeb90
```

Poner el digest en `compose.yaml` garantiza que una recarga reiterada traiga
exactamente los mismos bytes, aunque la etiqueta `v2.5.0` se moviera.
Hefesto dejo la etiqueta por legibilidad; el digest queda anotado en el
comentario de `compose.yaml` para quien prefiera cambiarlo.

## Componentes internos de la imagen

Un solo contenedor. Todos estos procesos corren dentro de `appsmith/appsmith-ce`,
administrados por supervisord:

| Componente | Rol | Puerto | Expuesto a red |
|---|---|---|---|
| `editor` / `rts` / `backend` | Servidor de Appsmith y editor | 80 | Si (unico) |
| `mongodb` | Base de datos interna del sistema | 27017 | No (`--bind_ip localhost`) |
| `redis` | Cache y sesiones | 6379 | No |
| `postgres` | PostgreSQL embebido | local | No |
| `caddy` | Servidor HTTP/HTTPS y termino TLS opcional | 80 / 443 | 80 via Compose |
| `rts` (control) | `appsmithctl` / `ctl` | — | No |

Fuente: `deploy/docker/fs/opt/appsmith/templates/supervisord/*.conf` y
`deploy/docker/fs/opt/appsmith/entrypoint.sh` en el repositorio `release`.

## Historico de versiones del kit

| Version | Fecha | Cambios |
|---|---|---|
| 1.0.0 | 2026-10-16 | Version inicial |

## Procedimiento de cambio de version

1. Consultar Docker Hub y elegir la etiqueta semantica mas reciente.
2. Actualizar `image:` en `compose.yaml` y el digest en el comentario.
3. Actualizar el digest y la fecha en esta tabla.
4. Respaldar ANTES de actualizar (`scripts/respaldo.sh`).
5. Levantar la version nueva en un ambiente de prueba con una copia del
   respaldo antes de tocar produccion.
6. Ver `docs/06-ACTUALIZACIONES-Y-REVERSION.md`.