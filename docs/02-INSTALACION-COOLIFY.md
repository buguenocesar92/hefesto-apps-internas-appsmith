# 02 — Instalación con Coolify

> **Estado: kit preparado.** Hefesto no ejecutó Coolify en este entorno. Los
> pasos de la interfaz de Coolify están descritos según su documentación, pero
> **el comportamiento de red entre el proxy de Coolify y un servicio Compose
> hay que confirmarlo en el servidor del cliente**. Está anotado en
> `07-PRUEBAS-DE-ACEPTACION.md`.

## Qué es Coolify en este contexto

Coolify es una plataforma que despliega aplicaciones y manages el proxy inverso
con Traefik y los certificados TLS. Para este kit se usa el tipo de recurso
**Docker Compose**: Coolify toma el `compose.yaml` del repositorio, lo levanta
y enruta el dominio hacia el contenedor.

## Antes de empezar

| Requisito | Detalle |
|---|---|
| Coolify instalado | Con Docker y proxy funcionando |
| Repositorio git | Con el contenido de este kit |
| Dominio apuntando al servidor | Por ejemplo `apps.ejemplo.cl` |
| 2 vCPU / 8 GB libres | En el mismo servidor donde corre Coolify |

> Si Coolify ya está instalado en ese VPS, el consumo se suma. Un VPS con 8 GB
> corriendo Coolify **y** Appsmith es justo. Para una Pyme conviene un VPS
> dedicado para Appsmith, o un servidor con 16 GB.

## Procedimiento

### 1. Crear el recurso

En Coolify: **New Resource → Docker Compose → Git Repository**.

| Campo | Valor |
|---|---|
| Repository | El repositorio con el kit |
| Branch | La rama donde está el kit |
| Compose Location | `/` (la raíz del repositorio) |
| Docker Compose Location | `compose.yaml` |

### 2. Generar las claves

Antes de dar cualquier valor en la interfaz, generar las dos claves
obligatorias:

```bash
openssl rand -hex 32
openssl rand -hex 32
```

Guardarlas en un gestor de contraseñas de Hefesto. **Si se pierden, las
credenciales de las fuentes de datos de todas las apps quedan indescifrables.**

### 3. Cargar las variables de entorno

En Coolify, sección *Environment Variables*, agregar:

| Clave | Valor |
|---|---|
| `APPSMITH_ENCRYPTION_PASSWORD` | La primera clave generada |
| `APPSMITH_ENCRYPTION_SALT` | La segunda clave generada |
| `APPSMITH_BASE_URL` | `https://apps.ejemplo.cl` |
| `APPSMITH_ADMIN_EMAILS` | `admin@ejemplo.cl` |
| `APPSMITH_SIGNUP_DISABLED` | `false` **durante la instalación** |

> **Sobre `APPSMITH_SIGNUP_DISABLED`.** Este kit la deja en `true` por
> defecto, que es lo correcto para producción. Pero **durante el primer
> arranque hay que ponerla en `false`**, porque es la única forma de crear la
> cuenta de administrador: el registro tiene que estar abierto una vez. En
> cuanto la cuenta exista, se vuelve a `true` y se redeploya.
>
> En la práctica: dejar `false` en el primer despliegue, crear el
> administrador siguiendo `04-PRIMERA-CUENTA-Y-USUARIOS.md`, y recién ahí
> cambiar a `true`.

### 4. Configurar el dominio

En la pestaña *Configuration* del recurso:

| Campo | Valor |
|---|---|
| Dominio | `apps.ejemplo.cl` |
| Puerto del contenedor | `80` |
| HTTPS | Activado (Let's Encrypt de Coolify) |

### 5. La diferencia de red, en detalle

`compose.yaml` pública el puerto así:

```yaml
ports:
  - "127.0.0.1:8080:80"
```

Eso es correcto cuando hay un reverse proxy **en el mismo host**. El puerto
queda atado a la interfaz local: nadie desde internet lo alcanza.

El proxy de Coolify, en cambio, corre **dentro de Docker, en otro contenedor**.
Un servicio atado a `127.0.0.1` del host no es alcanzable desde ahí. Por eso
existe `config/compose.coolify.yaml`, que cambia el mapeo a `8080:80`.

**Punto a confirmar en el servidor** (no verificado por Hefesto):

- **Variante A** — el proxy de Coolify llega al contenedor por un puerto del
  host. Entonces el override con `ports: ["8080:80"]` es lo correcto.
- **Variante B** — el proxy enruta directamente por la red de Docker, sin
  puertos publicados. Entonces se pueden quitar los `ports` y unir el servicio a
  la red del proxy.

El archivo `config/compose.coolify.yaml` trae las dos variantes, la A activa y
la B comentada. Probar la A, verificar en el navegador, y si no funciona
cambiar a la B. Borrar de ese archivo la variante que no se usó, para que no
quede ambigüedad.

### 6. Desplegar

Botón *Deploy*. Revisar los logs hasta ver el arranque completo. Después,
abrir `https://apps.ejemplo.cl`.

### 7. Cerrar el registro y ajustar

Inmediatamente después de crear la cuenta de administrador:

1. Cambiar `APPSMITH_SIGNUP_DISABLED` a `true`.
2. Redesplegar.
3. Confirmar que `/signup` ya no permite crear cuentas.

### 8. Volumen y respaldos

El volumen se llama `appsmith-stacks` y es nombrado. **No hay que cambiarlo.**

Comprobar que persiste entre despliegues:

```bash
docker volume ls | grep appsmith-stacks
docker run --rm -v appsmith-stacks:/v alpine ls -la /v
```

Para respaldar desde Coolify, se usa el mismo camino que en cualquier Docker:

```bash
cd /ruta/del/kit
./scripts/respaldo.sh --override-coolify
```

Ver `05-RESPALDOS-Y-RESTAURACION.md`.

## Sobre el dominio y el certificado

**No definir `APPSMITH_CUSTOM_DOMAIN` en un despliegue con Coolify.**

Cuando esa variable está definida, el Caddy interno del contenedor intenta
emitir su **propio** certificado Let's Encrypt y servir HTTPS en el puerto 443
por su cuenta. Con Coolify ya hay un proxy emitiendo el certificado, y que los
dos intenten obtener entradas ACME al mismo tiempo produce conflictos y
certificados que se renuevan de forma errática.

El certificado lo emite Coolify. El de Appsmith no debe tocarlo.

Fuente del comportamiento: `caddy-reconfigure.mjs` en
`deploy/docker/fs/` del repositorio de Appsmith.

## Problemas frecuentes

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| Error de puerto ocupado | Coolify ya usa 80/443 | Cambiar el puerto del host en el override a 8080 |
| `502` desde el dominio | El proxy no alcanza al contenedor | Activar la variante B en el override |
| Certificado inválido | El proxy no emitió el certificado | Revisar *Logs* → *Traefik* en Coolify |
| Los datos desaparecen | Se redeployó con otro volumen | Verificar el nombre del volumen antes de desplegar |
| El registro abierto | `APPSMITH_SIGNUP_DISABLED=false` | Poner en `true` y redesplegar |

---

Ver también: [`01-INSTALACION-DOCKER.md`](01-INSTALACION-DOCKER.md) ·
[`04-PRIMERA-CUENTA-Y-USUARIOS.md`](04-PRIMERA-CUENTA-Y-USUARIOS.md) ·
[`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md)