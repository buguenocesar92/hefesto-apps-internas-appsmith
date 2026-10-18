# Hefesto Studio — Kit de despliegue Appsmith Community Edition

> ## Estado: **kit preparado**
> Este kit **no se ejecutó en ningún servidor**. Se construyó en un entorno sin
> Docker, sin Coolify y sin instancia de Appsmith. Todo lo que se verificó son
> **documentación y archivos oficiales**. Lo que falta probar está enumerado en
> [`docs/07-PRUEBAS-DE-ACEPTACION.md`](docs/07-PRUEBAS-DE-ACEPTACION.md), con 50
> pruebas marcadas `PENDIENTE` y **ningún resultado simulado**.

---

## Qué es esto

Un kit de despliegue para **Appsmith Community Edition**, la plataforma open
source para construir aplicaciones internas: paneles de administración, listas
con filtros, formularios y tableros sobre datos que la empresa ya tiene.

Un solo contenedor. Un VPS. Listo para Coolify.

| | |
|---|---|
| Imagen | `appsmith/appsmith-ce:v2.5.0` (versión fijada) |
| Licencia | **Apache-2.0** |
| Editar usuarios | Sin límite |
| Costo de licencia | $0 |
| Recursos | 2 vCPU / 8 GB (oficial de Appsmith) |
| Servicios expuestos | 1 (HTTP). MongoDB y Redis **nunca** se publican |

---

## Por qué Appsmith y no ToolJet

Porque la licencia lo cambia todo en una Pyme.

| | Appsmith CE | ToolJet |
|---|---|---|
| Licencia del núcleo | **Apache-2.0** | **AGPL-3.0** |
| Copyleft | Ninguno | Sí |
| Consecuencia para el cliente | El código de sus apps es suyo, no hay que publicarlo | Bajo AGPL, un servicio accesible por red puede obligar a ofrecer el código fuente |
| Despliegue | **Un contenedor** | Varios servicios que hay que operar |

La licencia de ToolJet es AGPL-3.0 **no fue verificada contra su
repositorio en esta sesión**; está anotada en `07-PRUEBAS-DE-ACEPTACION.md`
como P50. Confirmarla antes de usar esa comparación en una propuesta.

Detalles en [`LICENCIAS.md`](LICENCIAS.md) y
[`docs/08-SERVICIOS-COMERCIALES.md`](docs/08-SERVICIOS-COMERCIALES.md).

---

## Qué es una "aplicación interna", explicado para el cliente

> **Una herramienta web que usa el personal de la empresa, con su propia sesión
> y sus propios permisos, para leer o modificar los datos que ya están en otro
> sistema.**

Significa tres cosas:

1. **No reemplaza el ERP.** El ERP sigue siendo el ERP. El panel muestra y
   opera sobre sus datos; no los sustituye ni los migra.
2. **No es para clientes del negocio.** Los usuarios son empleados. No hay
   carrito, ni checkout, ni pasarela de pago.
3. **Se entra con el correo de la empresa**, no con una cuenta de Internet.

Ejemplos del tipo de cosas que sí se pueden hacer:

| App interna | Qué reemplaza | Lo que **no** reemplaza |
|---|---|---|
| Panel de pedidos | La planilla de Excel de 800 filas | El ERP |
| Consola de soporte | El correo con "asunto: URGENTE" | El sistema de tickets |
| Control de stock | El cuaderno de la bodega | El sistema de inventario |
| Tablero de cobranzas | El archivo de carteras | Cuentas por cobrar |
| Reporte para el directorio | La consulta que alguien corría a mano | El sistema de reportes |

---

## Qué NO es Appsmith

Esto hay que decirlo **antes** de que el cliente pregunte:

- **No es un ERP.** No lleva contabilidad, no emite facturas electrónicas, no
  maneja inventario con lotes ni seriales. Para eso, un ERP del mercado y se
  conecta.
- **No es una aplicación móvil.** Es web. Se puede usar desde el celular en el
  navegador y se puede ajustar a pantallas chicas, pero no se instala desde la
  tienda de aplicaciones ni funciona sin conexión.
- **No es multi-tenant.** Ver más abajo. Esto es lo más importante.

### ⚠️ No es multi-tenant — una instancia es para un cliente

**Una instancia es para una sola empresa.** No hay separación de datos entre
organizaciones.

Si dos empresas compartieran una instancia, un constructor de una podría llegar
a ver las fuentes de datos de la otra, y en Community Edition **no hay
registro de auditoría** que permita saber quién hizo qué.

Cuando Hefesto vende a tres Pymes, son **tres instancias**. Hay que decirlo por
escrito en la propuesta, aunque nadie pregunte.

Excepción, en la que sí tiene sentido una instancia compartida: cuando todos
los usuarios pertenecen a **la misma organización** (por ejemplo, una
consultora que le da herramientas a sus propios empleados). Ahí una sola
instancia con roles bien definidos sí escala.

---

## ⚠️ Sobre Supabase

| Pregunta | Respuesta |
|---|---|
| ¿Puedo usar Supabase como base interna de Appsmith? | **No.** La base interna de Appsmith es **MongoDB**, no PostgreSQL. No es configurable en Community Edition. |
| ¿Puedo usar Supabase como fuente de datos de las apps? | **Sí**, por su conexión PostgreSQL estándar, con TLS y con un rol de solo lectura. |

Appsmith también trae un **PostgreSQL embebido** dentro del contenedor. Se usa
para fines internos del propio Appsmith. **No es la base donde quedan las
apps.** El almacenamiento de las apps, los usuarios y las conexiones es
MongoDB.

Para conectar una app a Supabase:

- Usar el **connection string de PostgreSQL** de Supabase.
- Conectar por **TLS** (`sslmode=require`, ya viene en el string).
- Crear un **rol de solo lectura** con su propia contraseña.
- **No usar** la `service_role` ni la clave de API de Supabase: saltan los
  permisos de PostgreSQL, y con una conexión PostgreSQL normal no hacen falta.

---

## El flujo de datos, en una línea

```
   Navegador  ──HTTPS──▶  Reverse proxy  ──HTTP──▶  Appsmith  ──▶  Tu base de datos
   del usuario              (Coolify / nginx)         (contenedor)      (PostgreSQL, API)
```

**Nunca al revés.** La base de datos nunca está expuesta al navegador. El
navegador habla con Appsmith; Appsmith es el único que habla con la base de
datos.

Por eso:

- La base de datos **no necesita** estar abierta a internet. Con que el
  contenedor Appsmith la alcance por red interna, basta.
- El puerto de Appsmith **sí** va a internet, siempre por HTTPS.
- La contraseña de la base **nunca** viaja al navegador. Appsmith la guarda
  cifrada y la usa desde el servidor.

---

## Qué incluye

```
hefesto-appsmith-apps-internas/
├── README.md                    <- estás acá
├── VERSION.md                   <- versión fijada, digest, historial
├── LICENCIAS.md                 <- licencias y por qué Appsmith
├── compose.yaml                 <- despliegue de un solo servicio
├── .env.example                 <- plantilla, sin secretos
├── .gitignore
├── config/
│   └── compose.coolify.yaml     <- override para Coolify
├── scripts/
│   ├── lib-comun.sh
│   ├── respaldo.sh              <- respaldo en dos fases + manifiesto + SHA-256
│   └── restaurar.sh             <- restauración con validaciones de seguridad
├── ejemplos/                    <- *** DEMOSTRACIÓN ***
│   ├── README.md
│   ├── 01-panel-de-pedidos/
│   ├── 02-consola-de-soporte/
│   └── postgres/rol-solo-lectura.sql
└── docs/
    ├── 01-INSTALACION-DOCKER.md
    ├── 02-INSTALACION-COOLIFY.md
    ├── 03-VARIABLES-Y-COMO-OBTENERLAS.md
    ├── 04-PRIMERA-CUENTA-Y-USUARIOS.md
    ├── 05-RESPALDOS-Y-RESTAURACION.md
    ├── 06-ACTUALIZACIONES-Y-REVERSION.md
    ├── 07-PRUEBAS-DE-ACEPTACION.md   <- qué se verificó y qué falta
    ├── 08-SERVICIOS-COMERCIALES.md
    ├── 09-EXPORTACION-O-TRASPASO.md
    └── 10-LICENCIAS-Y-FUENTES.md     <- todas las fuentes citadas
```

---

## Puesta en marcha, versión corta

```bash
cp .env.example .env
openssl rand -hex 32      # -> APPSMITH_ENCRYPTION_PASSWORD
openssl rand -hex 32      # -> APPSMITH_ENCRYPTION_SALT
# Editar APPSMITH_BASE_URL y APPSMITH_ADMIN_EMAILS
chmod 600 .env

docker compose config      # revisar antes de levantar
docker compose up -d
docker compose ps          # esperar a "healthy"

# Crear el administrador siguiendo docs/04-PRIMERA-CUENTA-Y-USUARIOS.md
# Volver a poner APPSMITH_SIGNUP_DISABLED=true
```

Detalle completo en [`docs/01-INSTALACION-DOCKER.md`](docs/01-INSTALACION-DOCKER.md).

---

## Despliegue en Coolify (MVP Hefesto)

Coolify usa el `compose.yaml` de la raíz **tal cual** (sin overrides:
`config/compose.coolify.yaml` queda obsoleto con esta versión). Traefik
termina TLS y enruta el tráfico al puerto 80 del contenedor por la red
interna de Docker, así que el `compose.yaml` ya no publica ningún puerto
al host.

### Requisitos del servidor

- **Recursos:** 2 vCPU y **8 GB de RAM** mínimos (recomendación oficial de
  Appsmith; la base embebida MongoDB es lo que pesa).
- **Imagen fija:** `appsmith/appsmith-ce:v2.5.0`. Coolify la baja; no
  cambiar a `:latest`.
- **Disco:** ~5 GB para `/appsmith-stacks` (config, datos de Mongo, Redis,
  Postgres embebido, respaldos y logs).

### Variables de entorno obligatorias en Coolify

Coolify las pide con el mismo nombre que aparecen en `.env.example`.

| Variable | Qué poner | Notas |
|---|---|---|
| `APPSMITH_ENCRYPTION_PASSWORD` | `openssl rand -hex 32` | **No se recupera si se pierde.** Guardar en el gestor de contraseñas. |
| `APPSMITH_ENCRYPTION_SALT` | `openssl rand -hex 32` | Igual. |
| `APPSMITH_BASE_URL` | `https://apps.tu-dominio.cl` | Sin barra final, con `https`. La usa Appsmith para validar `Origin`. |
| `APPSMITH_ADMIN_EMAILS` | `admin@tu-dominio.cl` | Se puede cambiar en Coolify y re-desplegar; los correos listados quedan como Instance Administrator. |
| `APPSMITH_SIGNUP_DISABLED` | `false` (primer despliegue) → `true` (después) | Ver abajo. |

> `APPSMITH_CUSTOM_DOMAIN` **no se pasa al contenedor a propósito; no
> definirla** en Coolify. Si se llena, el Caddy interno intenta emitir su
> propio TLS y compite con el de Coolify.

### Primer despliegue: ventana de admin

1. Levantar con `APPSMITH_SIGNUP_DISABLED=false` y `APPSMITH_ADMIN_EMAILS`
   puesto en el correo del primer administrador.
2. Iniciar sesión en la URL pública con ese correo. Appsmith promueve al
   usuario a Instance Administrator cuando coincide con
   `APPSMITH_ADMIN_EMAILS`. **No hay variable para fijar la contraseña:**
   la contraseña la pone el usuario en el formulario de registro.
3. Cerrar el registro cambiando `APPSMITH_SIGNUP_DISABLED=true` en Coolify
   y re-desplegar. Verificar en `Admin Settings > Authentication` que el
   toggle quedó cerrado.

### Volumen persistente

Coolify monta un volumen nombrado (sin `name:` fijo en el YAML) en
`/appsmith-stacks`. Contiene configuración, datos de MongoDB/Redis/Postgres
embebido, respaldos y logs. **No es un bind al host**; Coolify lo nombra a
partir del proyecto. Si se pierde ese volumen, se pierden las claves
guardadas y los datos.

### Validación automática

`scripts/coolify-check.sh` corre `docker compose config` con variables
ficticias (no reales) y verifica que el `compose.yaml` cumple el contrato
de Coolify:

- Ningún servicio sin `profiles:` publica puertos, usa `container_name`,
  ni declara `name:` fijo a nivel raíz, en redes o en volúmenes.

Útil como check de CI antes de hacer commit al `compose.yaml`.

```bash
bash scripts/coolify-check.sh
```

---

## Lo más importante que hay que saber

### 1. Las claves de cifrado no se pueden recuperar

`APPSMITH_ENCRYPTION_PASSWORD` y `APPSMITH_ENCRYPTION_SALT` son la clave con la
que Appsmith cifra las credenciales de las fuentes de datos. Si se pierden
**junto con** el archivo `docker.env`, todas las contraseñas guardadas quedan
indescifrables **de forma permanente**. No hay recuperación: hay que volver a
ingresar cada credencial a mano.

Guardarlas en el gestor de contraseñas de Hefesto **y** en el del cliente.

### 2. El primer arranque es una ventana de riesgo

Con el registro abierto (lo cual es necesario para crear la cuenta de
administrador), cualquiera que encuentre la URL puede registrarse y quedar como
administrador. Después hay que cerrar el registro **y comprobar que cerró**.

Detalle en [`docs/04-PRIMERA-CUENTA-Y-USUARIOS.md`](docs/04-PRIMERA-CUENTA-Y-USUARIOS.md).

### 3. Conectar un constructor visual a la base tiene riesgo real

Appsmith es un constructor: cualquiera con permiso de editar una app puede
escribir SQL. Si la conexión puede escribir, un error —o un descuido— puede
modificar o borrar datos de producción.

Por eso el kit insiste: **conexión en Read Only y rol de PostgreSQL sin
permisos de escritura**. Cuando el cliente pida "y un botón para editar el
pedido", eso es un proyecto distinto, con su propio análisis de riesgo.

### 4. La edición gratuita tiene límites de gobernanza

| Función | ¿Community Edition? |
|---|---|
| Usuarios sin límite | **Sí** |
| Aplicaciones sin límite | **Sí** |
| Costo de licencia | **$0** |
| **Registro de auditoría** (quién hizo qué) | **No** — es edición Business |
| **SSO SAML** | **No** — es edición Enterprise |
| **SSO OIDC** | **No** — es edición Enterprise |
| Respaldos automáticos programados | **No** — hay que armarlos con cron |

Si el cliente tiene una exigencia de auditoría o de SSO corporativo, eso
significa **otra edición u otra herramienta**, y hay que decirlo el primer día.

Detalle en [`docs/08-SERVICIOS-COMERCIALES.md`](docs/08-SERVICIOS-COMERCIALES.md).

---

## Ejemplos

Dos plantillas marcadas como **demostración**, con su propia base de datos de
ejemplo y datos inventados:

| Ejemplo | Qué demuestra | Base |
|---|---|---|
| `ejemplos/01-panel-de-pedidos/` | KPI, gráfico y tablas con filtros | `demo_pedidos` |
| `ejemplos/02-consola-de-soporte/` | Cola con SLA y conversación por ticket | `demo_soporte` |
| `ejemplos/postgres/rol-solo-lectura.sql` | Rol que no puede escribir en la base | — |

**No incluyen un `.json` importable de la app**, y es deliberado: el formato de
exportación de Appsmith cambia entre versiones y no se pudo verificar sin una
instancia corriendo. Entregar un archivo que nadie abrió sería peor que
entregar la receta de construcción paso a paso, que además el cliente
entiende y puede modificar.

---

## Seguridad en la conexión a la base

En orden de preferencia:

1. **Una réplica de lectura**, no la base de producción. Es lo más seguro y
   casi siempre alcanza para un panel.
2. **Un rol de solo lectura** sobre la base de producción. Hay plantilla en
   `ejemplos/postgres/rol-solo-lectura.sql`.
3. **Un esquema restringido** con vistas y permisos, si hace falta algo que el
   rol directo no permite.
4. La base de producción con permisos de escritura: **solo con un análisis de
   riesgo escrito y acordado por escrito**. No por defecto.

La conexión nunca va al navegador. Ver el flujo de datos más arriba.

---

## Honestidad sobre el estado

Este kit fue escrito con acceso a la documentación oficial y al código fuente
público de Appsmith. Eso permitió verificar muchas cosas de verdad:

- La versión más reciente y su digest.
- La licencia.
- Las variables de entorno reales, leídas del código de la imagen.
- Que **no existe** `APPSMITH_ADMIN_PASSWORD`.
- Que el healthcheck viene en la propia imagen.
- Que `appsmithctl backup` existe y qué incluye.
- Los límites de edición de auditoría y SSO.
- Que 2 vCPU / 8 GB es recomendación **oficial**, no de terceros.

Lo que **no** se pudo verificar, porque no hay servidor en este entorno:

- Que la imagen arranque y llegue a `healthy`.
- El comportamiento real de Coolify.
- Que los scripts de respaldo funcionen de punta a punta.
- Que los esquemas SQL se apliquen sin error.
- Que un `.json` de app se reimporte limpio.

**Hay 50 pruebas pendientes** y están todas anotadas con cómo verificarlas en
[`docs/07-PRUEBAS-DE-ACEPTACION.md`](docs/07-PRUEBAS-DE-ACEPTACION.md). Ninguna
tiene resultado inventado.

---

## Licencia del kit

Contenido de Hefesto Studio: **MIT**.
Aplicación instalada: **Apache-2.0**, con dependencias embebidas detalladas en
[`LICENCIAS.md`](LICENCIAS.md).

Las variables de cifrado: **no se comparten con nadie**. Ni por correo, ni por
chat, ni en un ticket. En un canal cifrado, o por un medio físico.