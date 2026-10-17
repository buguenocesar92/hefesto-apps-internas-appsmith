# 01 — Instalación con Docker

> **Estado: kit preparado.** Nada de este procedimiento se ejecutó en un
> servidor real. Hefesto no tenía Docker en el entorno donde se construyó este
> kit. Cada paso indica en qué se apoya y qué queda por comprobar.

## Requisitos del servidor

| Recurso | Mínimo recomendado | Fuente |
|---|---|---|
| CPU | 2 vCPU | Documentación oficial de Appsmith |
| RAM | 8 GB | Documentación oficial |
| Disco | 20 GB libre, más espacio para respaldos | Recomendación de Hefesto, no oficial |
| SO | Linux con Docker Engine y plugin Compose v2 | — |

**Sobre los 2 vCPU y 8 GB.** Esto **no es una recomendación de terceros**: la
documentación oficial de Appsmith indica que el punto de partida para su
despliegue todo en uno es 2 vCPU con 8 GB de RAM, y la guía de AMI de AWS
usa una `t3.large` como mínimo recomendado. La misma documentación advierte
además que **el número de usuarios no es una métrica confiable** para
dimensionar: lo que pesa es cuántas consultas pesadas y cuántos widgets se
ejecutan al mismo tiempo.

Fuentes:
- <https://appsmith.com/docs/getting-started/setup/infrastructure-sizing>
- <https://appsmith.com/docs/help-and-support/troubleshooting-guide/performance-resource-errors>

**Margen recomendado para Hefesto.** Si el VPS es de 2 GB, el servicio va a
arrancar pero se va a sentir lento y puede quedar sin memoria. Si el presupuesto
no da 8 GB reales, es mejor no vender Appsmith y ofrecer otra alternativa.

## Requisitos de red

- Un dominio apuntando al servidor, por ejemplo `apps.ejemplo.cl`.
- Puertos **80 y 443** abiertos hacia el servidor **solo si** hay un reverse
  proxy en el mismo host o en Coolify. Si no hay proxy, ver la nota sobre
  `APPSMITH_CUSTOM_DOMAIN` en `03-VARIABLES-Y-COMO-OBTENERLAS.md`.

## Procedimiento

### 1. Preparar el directorio

```bash
sudo mkdir -p /opt/hefesto/appsmith
sudo chown "$USER":"$USER" /opt/hefesto/appsmith
cd /opt/hefesto/appsmith

# Copiar aquí el contenido del kit.
cp -r /ruta/del/kit/hefesto-appsmith-apps-internas/* .
```

### 2. Crear el archivo de variables

```bash
cp .env.example .env
```

Generar las dos claves obligatorias:

```bash
openssl rand -hex 32
openssl rand -hex 32
```

Pegar la primera en `APPSMITH_ENCRYPTION_PASSWORD` y la segunda en
`APPSMITH_ENCRYPTION_SALT`. Editar además:

| Variable | Valor |
|---|---|
| `APPSMITH_BASE_URL` | `https://apps.ejemplo.cl` |
| `APPSMITH_ADMIN_EMAILS` | `admin@ejemplo.cl` |

Los detalles de cada variable están en `03-VARIABLES-Y-COMO-OBTENERLAS.md`.

```bash
chmod 600 .env
```

> `.env` contiene la clave con la que Appsmith cifra las credenciales de las
> fuentes de datos. Nadie más debería poder leerlo.

### 3. Revisar la configuración antes de levantar nada

```bash
docker compose config
```

Este comando muestra la configuración final que Docker va a usar, con los
valores ya resueltos. Si falta una variable obligatoria, falla con un mensaje
claro en vez de levantar un servicio a medias.

> **Cuidado:** `docker compose config` muestra los valores reales de los
> secretos en pantalla. No pegar esa salida en un ticket ni en un chat.

### 4. Levantar

```bash
docker compose up -d
docker compose ps
```

El primer arranque es lento: la imagen pesa bastante y hay que inicializar
MongoDB, Redis y PostgreSQL embebidos. La columna de estado debería mostrar
`healthy` en menos de un par de minutos.

Seguir el arranque:

```bash
docker compose logs -f --tail=100 appsmith
```

### 5. Verificar la salud

```bash
docker compose ps
curl -sI http://127.0.0.1:8080/ | head -n 1
```

El healthcheck no es un `curl` inventado: la imagen oficial de Appsmith ya
incluye un `HEALTHCHECK` que invoca `/opt/appsmith/healthcheck.sh`, y ese
script comprueba el estado de los procesos internos (editor, rts, backend) y que
el editor responda por HTTP. `compose.yaml` declara el mismo script con los
mismos parámetros para que el estado se vea en `docker compose ps`.

Fuente: `HEALTHCHECK` en el `Dockerfile` de la rama `release` del repositorio
de Appsmith.

## Crea el primer administrador antes de abrirlo al mundo

Con el servicio levantado, `http://127.0.0.1:8080` muestra el formulario de
registro. Hay que crear **una sola cuenta** antes de poner el dominio público,
porque la primera persona que se registre queda como administrador de la
instancia. El detalle está en `04-PRIMERA-CUENTA-Y-USUARIOS.md`.

## Reverse proxy

Con Coolify o con nginx en el mismo host, lo normal es:

- `compose.yaml` publica `127.0.0.1:8080:80`. El puerto queda accesible solo
  desde el servidor, nunca desde internet.
- El proxy termina TLS y reenvía a `127.0.0.1:8080`.

## Problemas frecuentes

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `falta APPSMITH_ENCRYPTION_PASSWORD` | `.env` no creado o vacío | Repetir el paso 2 |
| El contenedor reinicia en bucle | Variable obligatoria vacía | Revisar `docker compose logs` |
| El servicio queda `starting` y nunca `healthy` | Recursos insuficientes | Confirmar 8 GB libres; ver el log del healthcheck |
| `curl localhost` no responde | Base interna todavía inicializando | Esperar y revisar `docker compose logs` |
| El navegador dice que el origen no está permitido | `APPSMITH_BASE_URL` mal puesto o ausente | Corregir y reiniciar |

## Desinstalar

```bash
docker compose down
```

Esto **conserva el volumen**: los datos siguen ahí. Para borrar todo,
incluido el volumen, hay que agregarlo explícitamente:

```bash
docker compose down -v
```

> `docker compose down -v` elimina la base interna, todas las apps y todos los
> usuarios. **No se ejecuta nunca como parte de una limpieza automática**, ni
> antes de confirmar que existe un respaldo verificado. Para una instancia de
> cliente, perder el volumen es perder el proyecto.

---

Ver también: [`02-INSTALACION-COOLIFY.md`](02-INSTALACION-COOLIFY.md) ·
[`03-VARIABLES-Y-COMO-OBTENERLAS.md`](03-VARIABLES-Y-COMO-OBTENERLAS.md) ·
[`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md)