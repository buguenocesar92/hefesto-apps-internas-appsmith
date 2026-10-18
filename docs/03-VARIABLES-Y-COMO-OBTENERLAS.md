# 03 — Variables y cómo obtenerlas

Este documento es la referencia de configuración del kit. Todas las variables
de acá salen de la documentación oficial de Appsmith (página de variables de
entorno y página de instalación con Docker), salvo las que se marcan
expresamente como recomendación de Hefesto.

## La regla que más importa

> **Las variables de entorno tienen prioridad sobre lo guardado en la
> interfaz (Admin Settings).**

Consecuencia práctica: si defines `APPSMITH_EMAIL_ENABLED` en el `.env`, el
valor que se ponga en la interfaz **no va a tener efecto**. Por eso este kit
deja las variables de correo comentadas en `.env.example` y recomienda
configurarlas desde la interfaz.

Fuente: <https://appsmith.com/docs/getting-started/setup/installation-guides/docker>

---

## Obligatorias

### `APPSMITH_ENCRYPTION_PASSWORD`

**Qué es.** La clave con la que Appsmith cifra las credenciales de las fuentes
de datos.

**Por qué es obligatoria.** Si la pierdes, todas las contraseñas de PostgreSQL,
MySQL, Redis y API guardadas en Appsmith quedan indescifrables. No hay
respaldo ni recuperación: hay que volver a ingressar cada credencial a mano.

**Qué pasa si la omites.** La imagen la genera al azar y la escribe dentro del
volumen, en `/appsmith-stacks/configuration/docker.env`. Funciona, pero el
valor queda en un archivo dentro del VPS. Si ese archivo se pierde, se pierden
las credenciales. Además, si más tarde alguien copia ese `docker.env` a otra
instancia, allí no va a funcionar.

**Cómo obtenerla.**

```bash
openssl rand -hex 32
```

**Dónde guardarla.** En el gestor de contraseñas de Hefesto y en el gestor del
cliente. En el `.env` del servidor, con `chmod 600`.

### `APPSMITH_ENCRYPTION_SALT`

**Qué es.** La sal que acompaña a la clave de cifrado.

**Por qué es obligatoria.** Junto con la anterior, determina el cifrado. El
valor por defecto documentado es `22NYJW9pT`, que **no se debe usar**: es
público y está en la documentación, o sea que cualquiera que lo conozca
puede descifrar.

**Cómo obtenerla.**

```bash
openssl rand -hex 32
```

---

## Seguridad y cuentas

### `APPSMITH_BASE_URL`

**Qué hace.** Define la URL pública de la instancia. Appsmith la usa para
activar la **validación del encabezado `Origin`** en las acciones de cuenta,
lo que evita ataques de toma de cuenta (un atacante que aloja un origen falso
e induce al administrador a cambiar su contraseña contra el destino
equivocado).

**Valor.** `https://apps.ejemplo.cl`, con esquema, sin barra final.

**Recomendación de Hefesto.** **Definirla siempre**, incluso con una sola
instancia y sin SSO. Es de las poucas medidas de seguridad gratuitas que
existen y activarla cuesta treinta segundos.

### `APPSMITH_ADMIN_EMAILS`

**Qué hace.** Los correos que reciben permisos de administrador de la
instancia.

**OJO, esto confunde a mucha gente:** la variable es **en plural** y **no
existe ninguna variable `APPSMITH_ADMIN_PASSWORD`**. Se verificó en el código
de la imagen: ninguna variable de administrador con contraseña aparece ni en el
`entrypoint.sh` ni en la plantilla de configuración de la versión fijada.

Consecuencias:

- No se puede crear el administrador por línea de comandos.
- La cuenta se crea mediante el **formulario web**.
- La contraseña la elige la persona, en el navegador.
- Lo único que controla Hefesto es **qué correos pueden obtener permisos de
  administrador**. Por eso hay que usar correos corporativos reales y no
  algo como `admin@ejemplo.cl`.

Detalle en `04-PRIMERA-CUENTA-Y-USUARIOS.md`.

### `APPSMITH_SIGNUP_DISABLED`

**Qué hace.** `true` cierra el registro de cuentas nuevas. Los usuarios ya
existentes siguen entrando con normalidad.

**Valor por defecto del kit.** `true`.

**Importante para la instalación.** Hay que ponerla en `false` para el primer
arranque, porque es la única forma de crear la cuenta de administrador. Apenas
exista la cuenta, se vuelve a `true`.

### `APPSMITH_SIGNUP_ALLOWED_DOMAINS`

**Qué hace.** Limita el registro a una lista de dominios. Requiere
`APPSMITH_SIGNUP_DISABLED=false`.

**Cuándo usarla.** Cuando la instancia es compartida por varios usuarios de
una misma empresa y se quiere impedir que cualquiera con un correo de otra
parte se registre. Lista separada por comas.

### `APPSMITH_RATE_LIMIT`

**Qué hace.** Peticiones por segundo y por cliente. Por defecto **100**.

**Cuándo bajarla.** Si la instancia está expuesta a internet y se ven
peticiones anormales en los logs.

### `APPSMITH_ALLOWED_FRAME_ANCESTORS`

**Qué hace.** Dominios autorizados a embeber Appsmith en un `iframe`.

**Valor recomendado.** `'self'`, es decir, solo el mismo origen.

**Cuándo cambiarla.** Cuando la app se va a embeber dentro de un portal
interno de la misma empresa. **Nunca** usar `*`: permitiría que cualquier sitio
externo incrustara la instancia.

---

## Privacidad

### `APPSMITH_DISABLE_TELEMETRY`

`true` desactiva el envío de telemetría anonimizada a Appsmith. El kit lo
deja en `true`. Hefesto no ha verificado qué datos exactos se envían en
telemetría; desactivar es la opción conservadora y no cuesta nada.

### `APPSMITH_DISABLE_INTERCOM`

`true` quita el widget de soporte de Intercom de las instancias autoalojadas.
El kit lo deja en `true`. Es una decisión de privacidad y de apariencia: la
instancia del cliente no debería mostrar burbujas de un tercero.

---

## Límites y tiempos

| Variable | Por defecto | Qué hace |
|---|---|---|
| `APPSMITH_CODEC_SIZE` | 200 (MB) | Tamaño máximo de archivo adjunto |
| `APPSMITH_SERVER_TIMEOUT` | 60 (segundos) | Timeout interno del servidor |

---

## Correo

### El problema con los nombres

La documentación oficial usa los nombres `APPSMITH_EMAIL_*`:

```bash
APPSMITH_EMAIL_ENABLED=true
APPSMITH_EMAIL_SERVER_HOST=smtp.ejemplo.cl
APPSMITH_EMAIL_SERVER_PORT=587
APPSMITH_EMAIL_SERVER_USERNAME=
APPSMITH_EMAIL_SERVER_PASSWORD=
APPSMITH_EMAIL_SERVER_TLS=true
APPSMITH_EMAIL_FROM=apps@ejemplo.cl
```

Pero la plantilla de configuración que se escribe dentro de la imagen al primer
arranque sigue generando los nombres antiguos `APPSMITH_MAIL_*`:

```bash
APPSMITH_MAIL_ENABLED=true
APPSMITH_MAIL_HOST=smtp.ejemplo.cl
APPSMITH_MAIL_PORT=587
APPSMITH_MAIL_USERNAME=
APPSMITH_MAIL_PASSWORD=
APPSMITH_MAIL_SSL=true
APPSMITH_REPLY_TO=apps@ejemplo.cl
```

**Hefesto no pudo aclarar esta diferencia.** No hay nota de versión que diga
cuál de los dos conjuntos es el vigente en la versión fijada. Por eso:

> **Recomendación de Hefesto: configurar el correo desde la interfaz**
> (`Admin Settings → Settings → General → SMTP`), con las variables de correo
> **comentadas** en el `.env`.

Ventaja adicional: si más adelante resulta que había que usar el otro nombre,
basta con limpiar la variable del `.env` y la interfaz vuelve a mandar. Con las
variables definidas, la interfaz no tiene arreglo.

### Correo entrante (respuestas a notificaciones de las apps)

```bash
APPSMITH_MAIL_INBOUND_DOMAIN=apps.ejemplo.cl
APPSMITH_MAIL_INBOUND_SECRET=
```

Requiere configurar el registro MX del dominio. **Solo si** las apps van a
enviar notificaciones por correo.

---

## Integración con Git

### `APPSMITH_GIT_ROOT`

Raíz donde se clonean los repositorios. **Debe quedar dentro del volumen
persistente.** Si se deja fuera, todos los repos se pierden en cada
reinicio del contenedor.

```bash
APPSMITH_GIT_ROOT=/appsmith-stacks/data/git
```

En el kit está comentado en `compose.yaml` porque la mayoría de los proyectos
de Pyme no la usan. Es la base de la función de control de versiones de las
apps, que sí está en Community Edition.

---

## Ajuste avanzado

### `APPSMITH_JAVA_HEAP_ARG`

Limita la memoria de la JVM del backend. Es una variable de despliegue: se fija
por el entorno del contenedor (Compose o Helm), no por `docker.env`.

```yaml
# APPSMITH_JAVA_HEAP_ARG: "-Xmx4g"
```

**No se recomienda tocarla en este kit.** Hefesto **no verificó** cuál es el
valor por defecto que usa la imagen ni cómo se comporta la JVM con distintos
límites en una instancia de 8 GB. Ajustarlo a ciegas es más probable que
empeore el servicio que que lo mejore. Queda disponible pero comentado, y
anotado en `07-PRUEBAS-DE-ACEPTACION.md` como pendiente de medición.

---

## Variables que existen pero no se exponen

Estas sí las usa la imagen internamente, y `compose.yaml` **no** las pública:

| Variable | Para qué |
|---|---|
| `APPSMITH_DB_URL` / `APPSMITH_MONGODB_URI` | Apuntar a un MongoDB externo en vez del embebido |
| `APPSMITH_REDIS_URL` | Apuntar a un Redis externo |
| `APPSMITH_ENABLE_EMBEDDED_DB` | Poner en `0` para usar bases externas |
| `APPSMITH_MONITORING` | Telemetría de monitoreo a un servicio externo |
| `APPSMITH_OAUTH2_GOOGLE_*` / `APPSMITH_OAUTH2_GITHUB_*` | Login con Google o GitHub |

Este kit se queda con todo embebido: una sola instancia, un contenedor, menos
piezas que operar. Externalizar MongoDB y Redis solo tiene sentido a escala.

**Sobre Google y GitHub como login:** la plantilla de configuración de la
propia imagen Community Edition incluye esas variables, o sea que el login con
Google funciona **sin pagar**. Es una alternativa real al SSO corporativo de
pago para una Pyme de 10 a 30 personas. Ver `08-SERVICIOS-COMERCIALES.md`.

---

## Resumen: qué cambiar sí o sí

| Prioridad | Variable | Motivo |
|---|---|---|
| **Imprescindible** | `APPSMITH_ENCRYPTION_PASSWORD` | Sin esto se pierden credenciales |
| **Imprescindible** | `APPSMITH_ENCRYPTION_SALT` | Igual que la anterior |
| **Alta** | `APPSMITH_BASE_URL` | Activación de validación de `Origin` |
| **Alta** | `APPSMITH_ADMIN_EMAILS` | Define quién puede administrar |
| **Alta** | `APPSMITH_SIGNUP_DISABLED` | Cerrar el registro tras la instalación |
| Media | `APPSMITH_DISABLE_TELEMETRY` | Privacidad |
| Media | `APPSMITH_DISABLE_INTERCOM` | Privacidad y apariencia |
| Opcional | `APPSMITH_RATE_LIMIT` | Solo si hay presión |
| Opcional | `APPSMITH_GIT_ROOT` | Solo con control de versiones |

---

Ver también: [`01-INSTALACION-DOCKER.md`](01-INSTALACION-DOCKER.md) ·
[`08-SERVICIOS-COMERCIALES.md`](08-SERVICIOS-COMERCIALES.md) ·
[`10-LICENCIAS-Y-FUENTES.md`](10-LICENCIAS-Y-FUENTES.md)