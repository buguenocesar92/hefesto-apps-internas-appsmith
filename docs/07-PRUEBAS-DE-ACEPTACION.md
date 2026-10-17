# 07 — Pruebas de aceptación

> ## Estado del kit: **PREPARADO**
>
> Este kit **no se ejecutó en un servidor real**. El entorno donde se construyó
> no tenía Docker, ni Coolify, ni una instancia de Appsmith, ni una base
> PostgreSQL.
>
> En consecuencia: **ninguna prueba de runtime de esta página tiene resultado.**
> Todo lo que está marcado abajo como `PENDIENTE` está pendiente de verdad.
> No hay resultados simulados, ni capturas, ni tiempos inventados.

---

## 1. Lo que SÍ se verificó, y cómo

Estas verificaciones se hicieron de verdad, contra las fuentes oficiales,
desde este entorno. Son verificaciones **de documentación y de archivos**, no de
ejecución.

| # | Qué se verificó | Cómo | Resultado |
|---|---|---|---|
| V1 | Versión más reciente de la imagen | Consulta a la API de Docker Hub, 2026-10-16 | `v2.5.0`, publicada 2026-10-09, digest `sha256:5b6133ab…` |
| V2 | Licencia del núcleo | Lectura de `LICENSE`, rama `release` | Apache License 2.0 |
| V3 | Ruta del volumen | Guía oficial de Docker y `entrypoint.sh` | `/appsmith-stacks` |
| V4 | Existence y contenido del healthcheck | `Dockerfile`, rama `release` | `HEALTHCHECK ... CMD "/opt/appsmith/healthcheck.sh"` |
| V5 | MongoDB como almacén interno | Docs de variables de entorno + `mongodb.conf` | Sí, embebido, `--bind_ip localhost` |
| V6 | Ubicación de los datos de MongoDB | `mongodb.conf` | `/appsmith-stacks/data/mongodb` |
| V7 | Redis embebido | `entrypoint.sh` | `/appsmith-stacks/data/redis` |
| V8 | Variables `APPSMITH_ENCRYPTION_PASSWORD` y `SALT` | Plantilla `docker.env.sh` de la imagen | Son las que existen; no hay `_KEY` |
| V9 | **Inexistencia de `APPSMITH_ADMIN_PASSWORD`** | `entrypoint.sh` completo | **No existe.** El admin se crea en la web |
| V10 | Nombre real de la variable de admin | `entrypoint.sh` y docs | `APPSMITH_ADMIN_EMAILS`, en plural |
| V11 | Autogeneración de claves | `entrypoint.sh` | Si no se fijan, se generan y se guardan en `docker.env` |
| V12 | Funciones oficiales de respaldo | Página `appsmithctl` de las docs | `backup`, `restore`, `export_db`, `import_db` |
| V13 | Comportamiento de `APPSMITH_CUSTOM_DOMAIN` | `caddy-reconfigure.mjs` | Intenta emitir Let's Encrypt y servir en 443 |
| V14 | Recursos recomendados | Página oficial de dimensionamiento y de errores de rendimiento | 2 vCPU / 8 GB; `t3.large` como mínimo en AWS |
| V15 | Modo de conexión a PostgreSQL | Página oficial de consultas a PostgreSQL | Connection Mode: Read Only / Read Write |
| V16 | Modo de solo lectura | Página oficial de conexión a PostgreSQL | Marcador `-- Solo lectura: SELECT` al final |
| V17 | Prepared statements | Página oficial de conexión a PostgreSQL | Activas por defecto; el cliente las usa |
| V18 | Row Level Security | Página oficial de conexión a PostgreSQL | Disponible |
| V19 | Registro abierto/cerrado | Plantilla `docker.env.sh` | `APPSMITH_SIGNUP_DISABLED` |
| V20 | **Audit Logs = edición de pago** | Página oficial de audit logs | Requiere Business |
| V21 | **SAML SSO = edición de pago** | Página oficial de SAML | Requiere Enterprise |
| V22 | **OIDC SSO = edición de pago** | Página oficial de OIDC | Requiere Enterprise |
| V23 | Validación de URLs con `APPSMITH_BASE_URL` | Página oficial de variables | Recomendación del proveedor |
| V24 | Límite de peticiones | Página oficial de variables | 100/s por defecto |
| V25 | Sintaxis de los tres scripts Bash | `bash -n` con Git Bash | Los tres parsean sin errores |
| V26 | Sintaxis de `compose.yaml` y del override | Parser YAML | Ambos parsean; estructura correcta |
| V27 | Equilibrio de comillas en los `.sql` | Verificación automática | Sin comillas desbalanceadas en los 7 archivos |
| V28 | Caracteres no latinos no deseados | Verificación automática | 0 hallazgos en todo el kit |

> Sobre V28: Hefesto hizo varias pasadas de revisión manual porque durante la
> redacción se colaron algunos caracteres fuera del español. El escaneo
> automático es la red de seguridad, no el método principal.

---

## 2. Lo que NO se verificó — PENDIENTE

Nada de esta lista tiene resultado. Cada punto necesita un servidor real.

### 2.1 Despliegue

| # | Prueba | Cómo se verifica | Resultado |
|---|---|---|---|
| P1 | La imagen arranca en un VPS de 2 vCPU / 8 GB | `docker compose up -d` | **PENDIENTE** |
| P2 | `docker compose config` falla con un mensaje claro si falta una obligatoria | Borrar una variable y ejecutar | **PENDIENTE** |
| P3 | El servicio llega a `healthy` | `docker compose ps` | **PENDIENTE** |
| P4 | El healthcheck falla de verdad cuando algo está roto | Matar un proceso interno | **PENDIENTE** |
| P5 | El volumen persiste entre `down` y `up` | Crear un usuario, `down`, `up` | **PENDIENTE** |
| P6 | Tiempo de arranque en frío | Cronometrar | **PENDIENTE** |
| P7 | Consumo real de RAM con 8 GB | `docker stats` con carga | **PENDIENTE** |

### 2.2 Coolify

| # | Prueba | Resultado |
|---|---|---|
| P8 | Coolify despliega el compose desde el repositorio | **PENDIENTE** |
| P9 | La variante A del override funciona (proxy por puerto del host) | **PENDIENTE** |
| P10 | La variante B del override funciona (proxy por red de Docker) | **PENDIENTE** |
| P11 | Coolify emite el certificado y no hay conflicto con el de Appsmith | **PENDIENTE** |
| P12 | El dominio responde por HTTPS sin errores | **PENDIENTE** |
| P13 | Un redeploy no borra el volumen | **PENDIENTE** |

### 2.3 Cuentas y permisos

| # | Prueba | Resultado |
|---|---|---|
| P14 | El formulario de registro crea la primera cuenta como administradora | **PENDIENTE** |
| P15 | `APPSMITH_SIGNUP_DISABLED=true` cierra el registro de verdad | **PENDIENTE** |
| P16 | Un correo nuevo **no** puede registrarse con el registro cerrado | **PENDIENTE** |
| P17 | Los correos de `APPSMITH_ADMIN_EMAILS` obtienen permisos de administrador | **PENDIENTE** |
| P18 | Los roles limitan el acceso como se espera | **PENDIENTE** |
| P19 | SMTP funciona y *Forgot password* envía el correo | **PENDIENTE** |

### 2.4 Datos

| # | Prueba | Resultado |
|---|---|---|
| P20 | Los dos esquemas SQL se aplican sin error en PostgreSQL | **PENDIENTE** |
| P21 | Las cargas de demostración se aplican y las comprobaciones devuelven lo esperado | **PENDIENTE** |
| P22 | Appsmith se conecta con el rol de solo lectura | **PENDIENTE** |
| P23 | El marcador `-- Solo lectura: SELECT` hace que la consulta corra en modo reducido | **PENDIENTE** |
| P24 | `DELETE`/`UPDATE` fallan con el rol de solo lectura | **PENDIENTE** |
| P25 | Las consultas de los ejemplos devuelven datos en Appsmith | **PENDIENTE** |
| P26 | La variable `{{limite_registros}}` evita que el panel se cuelgue | **PENDIENTE** |
| P27 | La validación de `Origin` bloquea un origen falso | **PENDIENTE** |

### 2.5 Respaldos

| # | Prueba | Resultado |
|---|---|---|
| P28 | `respaldo.sh` completa en una instancia real | **PENDIENTE** |
| P29 | `appsmithctl backup` genera el archivo en la ruta esperada | **PENDIENTE** |
| P30 | La fase en frío copia el volumen completo | **PENDIENTE** |
| P31 | `SHA256SUMS` verifica correctamente | **PENDIENTE** |
| P32 | Se crea `COMPLETO` solo al final | **PENDIENTE** |
| P33 | Un respaldo restaurado deja las apps y los usuarios intactos | **PENDIENTE** |
| P34 | `restaurar.sh` rechaza un paquete sin `COMPLETO` | **PENDIENTE** |
| P35 | `restaurar.sh` rechaza un archivo alterado | **PENDIENTE** |
| P36 | `restaurar.sh` rechaza un `tar` con `..` en las rutas | **PENDIENTE** |
| P37 | `restaurar.sh` rechaza un `tar` con enlaces simbólicos | **PENDIENTE** |
| P38 | `restaurar.sh` rechaza restaurar sobre un volumen ocupado sin `--force` | **PENDIENTE** |
| P39 | Con `--force`, lo anterior queda en la cuarentena | **PENDIENTE** |
| P40 | Tras restaurar, el servicio queda detenido | **PENDIENTE** |
| P41 | Tiempo y tamaño de un respaldo con datos reales | **PENDIENTE** |
| P42 | La restauración de solo base con `appsmithctl restore --force` | **PENDIENTE** |

### 2.6 Actualizaciones

| # | Prueba | Resultado |
|---|---|---|
| P43 | Actualizar de `v2.5.0` a una versión posterior | **PENDIENTE** |
| P44 | La migración de la base interna corre sin error | **PENDIENTE** |
| P45 | La reversión por restauración funciona | **PENDIENTE** |
| P46 | Appsmith publica avisos de seguridad en un canal identificable | **PENDIENTE** |

### 2.7 Otros pendientes

| # | Prueba | Resultado |
|---|---|---|
| P47 | El valor por defecto de `APPSMITH_JAVA_HEAP_ARG` y su efecto con 8 GB | **PENDIENTE** |
| P48 | Si un `.json` exportado desde esta versión se puede reimportar limpio | **PENDIENTE** |
| P49 | Cómo se comportan las variables `APPSMITH_EMAIL_*` vs `APPSMITH_MAIL_*` en `v2.5.0` | **PENDIENTE** |
| P50 | Que la ToolJet sea efectivamente AGPL-3.0, contra su repositorio | **PENDIENTE** |

---

## 3. Riesgos abiertos

Ordenados por lo que duele más si sale mal.

### R1 — Pérdida de las claves de cifrado · ALTO

Si se pierde `APPSMITH_ENCRYPTION_PASSWORD` o `APPSMITH_ENCRYPTION_SALT` junto
con el `docker.env`, **todas las credenciales de las fuentes de datos quedan
indescifrables para siempre**. No hay recuperación.

*Mitigación:* las dos claves se fijan en el `.env`, se guardan en el gestor de
contraseñas de Hefesto **y** en el del cliente, y el `docker.env` va incluido
en cada respaldo.

### R2 — Registro abierto en el primer despliegue · ALTO

Entre el despliegue y la creación de la cuenta, cualquiera que encuentre la
URL puede registrarse y quedar como administrador. No hay forma de recuperar
el control por cuenta propia.

*Mitigación:* es exactamente el motivo de `04-PRIMERA-CUENTA-Y-USUARIOS.md`.
Ventana mínima, verificación explícita de que el registro quedó cerrado.

### R3 — Escritura arbitraria desde un constructor visual · ALTO

Appsmith es un constructor: cualquiera con permiso de edición de una app puede
escribir SQL. Contra una conexión de lectura-escritura sobre la base de
producción, eso significa que un error puede modificar o borrar datos reales.

*Mitigación:* conexión en **Read Only** y rol de PostgreSQL sin permisos de
escritura. Es la defensa principal y hay que mantenerla aunque el cliente pida
"y agrego un botón para editar el pedido". Ese botón implica pasar a lectura-
escritura, y eso es una conversación distinta, con su propio análisis de riesgo.

### R4 — Exposición de una base de producción · MEDIO

Al conectar Appsmith a una base de producción, la información de la conexión
queda disponible para todos los que puedan editar apps. Y en las ediciones de
Community Edition no hay auditoría de quién hizo qué.

*Mitigación:* preferir siempre una **réplica de lectura** o un esquema
restringido, en vez de la base de producción. Cuando la auditoría es
imprescindible, es un argumento de venta para la edición Business.

### R5 — Un `tar` manipulado que escriba fuera del volumen · MEDIO

Un paquete de respaldo de origen desconocido podría contener rutas maliciosas.

*Mitigación:* `restaurar.sh` valida las rutas antes de extraer y rechaza rutas
absolutas, `..` y enlaces. **Sin embargo, esas validaciones no se ejecutaron
contra casos reales**: P35, P36 y P37 siguen pendientes.

### R6 — Récord de scripts sin probar · MEDIO

`respaldo.sh` y `restaurar.sh` tienen sintaxis válida, pero **nunca se
ejecutaron**. Puede haber errores de lógica o de interacción con `appsmithctl`
que solo aparezcan en el servidor.

*Mitigación:* **el primer respaldo de la primera instancia de cliente tiene que
ir acompañado de una restauración de prueba completa**, antes de tocar nada de
producción. Sin excepción.

### R7 — Comportamiento de red con Coolify · MEDIO

La variante A y la B del override no se probaron con Coolify real.

*Mitigación:* probar una en un ambiente de prueba y borrar del archivo la que no
se usó.

### R8 — Confianza indebida en los tamaños recomendados · BAJO

Que Appsmith diga 2 vCPU / 8 GB es una recomendación general. Una Pyme con
muchos widgets pesados y consultas costosas puede necesitar más, y una con un
panel chico puede estar sobrada.

*Mitigación:* dimensionar mirando las consultas reales del cliente, no el
número de usuarios. La propia documentación de Appsmith advierte que el número
de usuarios no es una métrica confiable.

### R9 — Prometer avisos de seguridad que Hefesto no puede cumplir · BAJO

Decirle a un cliente que se le avisará de las actualizaciones de seguridad
exige un proceso real detrás.

*Mitigación:* P46. Hasta que esté confirmado, no prometerlo.

---

## 4. Cómo usar esta página en el trabajo diario

- Antes de **instalar en un cliente**: correr la sección 2.1, 2.2 y 2.3, y
  dejar registro del resultado.
- Antes de **entregar**: correr 2.3 y 2.4 completas.
- Antes de **cobrar el primer respaldo**: correr 2.5 entera. Es el momento en
  que Hefesto es responsable de los datos.
- Cuando algo falle: buscar en 2.6 y 2.7, y si no está, **anotarlo aquí** para
  la próxima versión del kit.

---

Ver también: [`README.md`](../README.md) ·
[`VERSION.md`](../VERSION.md) ·
[`LICENCIAS.md`](../LICENCIAS.md)