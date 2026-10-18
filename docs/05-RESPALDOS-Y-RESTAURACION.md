# 05 — Respaldos y restauración

> **Estado: kit preparado.** Los scripts de este kit **no se ejecutaron**
> porque en el entorno donde se construyeron no hay Docker ni una instancia
> Appsmith corriendo. Su sintaxis Bash sí fue verificada
> (`bash -n`). El comportamiento en un servidor real está pendiente de
> prueba. Ver `07-PRUEBAS-DE-ACEPTACION.md`.

## Dónde vive todo

El contenedor no guarda nada importante fuera de **un** volumen. Todo lo que
importa está bajo `/appsmith-stacks`:

| Ruta | Contenido | ¿Crítico? |
|---|---|---|
| `/appsmith-stacks/configuration` | `docker.env`, que **incluye la clave de cifrado de secretos** | **Sí** |
| `/appsmith-stacks/data/mongodb` | La base de datos interna de Appsmith | **Sí** |
| `/appsmith-stacks/data/redis` | Cache y sesiones | Sí |
| `/appsmith-stacks/data/postgres` | PostgreSQL embebido | Sí |
| `/appsmith-stacks/data/backup` | Archivos de respaldo generados por Appsmith | No (se puede regenerar) |
| `/appsmith-stacks/data/restore` | Archivos esperando ser restaurados | No |
| `/appsmith-stacks/logs` | Logs del servicio | No, regenerable |
| `/appsmith-stacks/ssl` | Certificado propio, si se usó | No |

Lo que está **fuera** del volumen y se puede regenerar en cualquier momento:
el código de la aplicación, el runtime, los certificados de Let's Encrypt, y
los procesos en sí.

> **El detalle más importante de toda esta página:**
> `/appsmith-stacks/configuration/docker.env` contiene
> `APPSMITH_ENCRYPTION_PASSWORD` y `APPSMITH_ENCRYPTION_SALT`. Si se pierde
> ese archivo **y** las dos claves, todas las credenciales de las fuentes de
> datos guardadas en Appsmith quedan indescifrables de forma permanente. No
> hay recuperación. Por eso el kit fija esas dos claves en el `.env` en vez de
> dejarlas autogeneradas.

## Las dos funciones oficiales de Appsmith

Appsmith trae su propia herramienta de respaldo. **Sí existe, es oficial y hay
que usarla.** No es necesario inventar nada:

| Comando | Qué hace |
|---|---|
| `appsmithctl backup` | Exporta la base interna, el `docker.env` y los repositorios Git en un solo archivo |
| `appsmithctl restore` | Restaura ese archivo sobre la instancia |
| `appsmithctl export_db` | **Solo** la base de datos, sin configuración ni Git |
| `appsmithctl import_db` | Restaura solo la base de datos |

`appsmithctl backup` es el correcto para una restauración completa. El script
de este kit lo usa como fase A.

Fuente: <https://appsmith.com/docs/getting-started/setup/instance-management/appsmithctl>

### Sobre el cifrado de los respaldos

Un respaldo sin cifrar contiene `docker.env`, que a su vez contiene la clave
de cifrado de los secretos. **Cifrar el archivo protege muy poco**, porque la
llave viaja dentro del propio paquete.

`appsmithctl backup` sin `--non-interactive` pide una contraseña y produce un
archivo `.tar.gz.enc`. El kit usa `--non-interactive` por defecto, para que
funcione sin terminal interactiva, y compensa con:

- carpeta del respaldo restringida a `700`,
- archivos a `600`,
- la advertencia explícita de no mandar el paquete por correo.

Quien prefiera el respaldo cifrado puede ejecutar `appsmithctl backup` a mano
desde una terminal interactiva. Ver el procedimiento al final del documento.

### Lo que **no** incluye el respaldo oficial

Los respaldos automáticos y la sincronización con S3 son funciones de **edición
de pago** (Business). En Community Edition, la automatización hay que
construirla por fuera, por ejemplo con un cron en el servidor que llame al
script de este kit.

## Respaldar

```bash
cd /opt/hefesto/appsmith
chmod +x scripts/*.sh
./scripts/respaldo.sh
```

Opciones:

| Opción | Para qué |
|---|---|
| `--salida DIR` | Guardar en otra carpeta, por ejemplo un disco externo |
| `--override-coolify` | Usar también `config/compose.coolify.yaml` |
| `--mantener-detenido` | Dejar el servicio detenido al terminar |
| `--servicio NOMBRE` | Si el cliente renombró el servicio |

### Qué hace el script

1. Descubre el contenedor y el volumen **en caliente**, sin asumir nombres.
2. **Fase A — respaldo lógico oficial:** ejecuta `appsmithctl backup`, que
   genera su propio volcado consistente de MongoDB con el servicio corriendo.
3. **Fase B — copia en frío:** **detiene el contenedor** para que no queden
   escritores, y copia el volumen completo a un `.tar.gz`. Cubre lo que la
   fase A no alcanza: certificados, Redis, PostgreSQL embebido y logs.
4. Vuelve a levantar el servicio, si es que estaba arriba.
5. Escribe `manifiesto.json` con el detalle de cada artefacto.
6. Genera `SHA256SUMS` y **lo verifica**.
7. **Solo al final** escribe el archivo `COMPLETO`.

> El orden importa: el marcador `COMPLETO` se escribe al final, después de que
> los checksums pasaron. Un paquete a medio generar **no** tiene marcador, y por
> lo tanto `restaurar.sh` se niega a tocar nada con él. Un respaldo que se
> cortó a la mitad no se puede confundir con uno bueno.

### Resultado

```
respaldos/respaldo-20261016T152030Z/
├── COMPLETO                       <- el paquete está verificado
├── SHA256SUMS
├── manifiesto.json
├── volumen-appsmith-stacks.tar.gz <- copia en frío del volumen completo
└── appsmith-backup-20261016...tar.gz <- respaldo lógico oficial de appsmithctl
```

### Automatizar

```bash
crontab -e
# Todos los días a las 03:17
17 3 * * * cd /opt/hefesto/appsmith && ./scripts/respaldo.sh --salida /mnt/respaldos/appsmith >> /var/log/respaldos-appsmith.log 2>&1
```

A las 03:17 y no a las 03:00 a propósito: se evita la hora en la que todo el
mundo programa sus respaldos y el VPS se satura.

**La retención es responsabilidad de Hefesto.** El script no borra respaldos
viejos, y eso es deliberado: borrar respaldos automáticamente es exactamente
la clase de operación que termina en una instancia sin respaldo. Definir una
política de retención explícita y limpieza manual, o con un script aparte que
solo borre directorios con marcador `COMPLETO` válido y con más de N días.

## Restaurar

```bash
./scripts/restaurar.sh --archivo respaldos/respaldo-20261016T152030Z
```

Si el volumen ya tiene contenido:

```
ERROR: el volumen appsmith-stacks ya tiene 214 entradas.
Para restaurar encima hay que usar --force. No se toco nada.
```

Con `--force`:

```bash
./scripts/restaurar.sh --archivo /mnt/respaldos/paquete --force
```

### Qué garantiza el script

| Garantía | Cómo |
|---|---|
| No restaura un paquete a medio generar | Exige el archivo `COMPLETO` |
| No restaura un paquete corrupto | Verifica `SHA256SUMS` antes de tocar nada |
| Un tar manipulado no puede escribir fuera del volumen | Antes de extraer, rechaza rutas absolutas, recorridos con `..` y enlaces simbólicos o duros |
| No pisa datos sin permiso | Rechaza si el volumen tiene contenido, salvo `--force` |
| No borra nada | Con `--force` **mueve** el contenido a una cuarentena dentro del volumen |
| No hace `DROP` de ninguna base de datos | En ningún caso, nunca |
| No levanta el servicio solo | Termina con el servicio **detenido** |

### La cuarentena

Con `--force`, lo que hay en el volumen se mueve a
`/cuarentena-<marca-de-tiempo>/` **dentro del propio volumen**. No se borra
nada. Una vez confirmado que la restauración funcionó, esa carpeta se puede
borrar a mano:

```bash
docker run --rm -v appsmith-stacks:/v --entrypoint sh appsmith/appsmith-ce:v2.5.0 \
  -c 'ls -la /v/cuarentena-* && rm -rf /v/cuarentena-*'
```

> Ese `rm -rf` es la **única** operación destructiva de todo el flujo, y es
> manual y explícita. Nunca la ejecuta ningún script del kit.

### Después de restaurar

El servicio queda **detenido**. Antes de levantarlo:

1. Confirmar que `APPSMITH_ENCRYPTION_PASSWORD` y `APPSMITH_ENCRYPTION_SALT` del
   `.env` son **las mismas** con las que se hizo el respaldo. Si cambiaron, las
   credenciales de las fuentes de datos van a quedar indescifrables.
2. Confirmar que la URL y los correos de administrador son los correctos.
3. Levantar:

```bash
docker compose up -d
docker compose logs -f --tail=200
```

### Restaurar solo la base de datos

Si se quiere recuperar únicamente los datos, sin tocar configuración ni
certificados:

```bash
docker compose exec -T appsmith appsmithctl restore \
  --backup-file /appsmith-stacks/data/backup/appsmith-backup-<marca>.tar.gz
```

Esto **requiere `--force`** para sobreescribir, y `appsmithctl` lo pide de
forma explícita. Para usarla hay que copiar el archivo dentro del volumen en
`data/backup/` primero. `restaurar.sh` deja ahí una copia del respaldo lógico
como comodidad.

> **Limitación honesta.** Hefesto no pudo ejecutar `appsmithctl restore` para
> confirmar el comportamiento exacto de los mensajes interactivos ni de
> `--force` en esta versión. Antes de depender de esa vía en producción,
> probarla en un ambiente de prueba.

## Respaldo cifrado, a mano

Para cuando el paquete no puede quedar en texto plano:

```bash
# Con el servicio arriba
docker compose exec -it appsmith appsmithctl backup
# -> pide una contraseña y produce un .tar.gz.enc

# Copiarlo fuera del volumen
docker compose cp appsmith:/appsmith-stacks/data/backup/<archivo>.enc /mnt/respaldos/
```

## Pruebas de aceptación de esta etapa

- [ ] Un respaldo completo se genera sin errores y crea el archivo `COMPLETO`.
- [ ] `SHA256SUMS` pasa la verificación con `sha256sum -c`.
- [ ] Un respaldo **restaurado** en una instancia limpia deja las apps, los
      usuarios y las fuentes de datos funcionando.
- [ ] `restaurar.sh` **rechaza** un paquete sin `COMPLETO`.
- [ ] `restaurar.sh` **rechaza** un paquete con un archivo alterado.
- [ ] `restaurar.sh` **rechaza** un `tar` con rutas que contienen `..`.
- [ ] `restaurar.sh` **rechaza** restaurar sobre un volumen ocupado sin
      `--force`.
- [ ] Con `--force`, lo que había queda en la cuarentena, no borrado.
- [ ] Tras restaurar, el servicio queda detenido.
- [ ] Se midió cuánto tarda un respaldo y cuánto ocupa.

---

Ver también: [`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md) ·
[`06-ACTUALIZACIONES-Y-REVERSION.md`](06-ACTUALIZACIONES-Y-REVERSION.md)