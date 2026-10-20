# 10 — Licencias y fuentes

Todo lo que este kit afirma sobre Appsmith viene de una de estas fuentes. Las
fuentes se pueden consultar; ninguna afirmación de este kit es de memoria.

Fecha de verificación de todo este documento: **2026-10-16**.

---

## 1. Licencias

### La aplicación instalada

| Elemento | Valor |
|---|---|
| Componente | Appsmith Community Edition |
| Imagen | `appsmith/appsmith-ce` |
| Versión fijada | `v2.5.0` |
| Licencia del núcleo | **Apache License 2.0** |
| Ubicación de la licencia | `LICENSE`, rama `release` de `github.com/appsmithorg/appsmith` |

Texto verificado:

```
Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION
```

**Qué significa para Hefesto:** Apache-2.0 no tiene copyleft. Se puede usar,
modificar, redistribuir y vender sin obligación de publicar el código fuente,
ni el de Appsmith ni el de las apps que el cliente construya sobre él. Hay que
mantener los avisos de licencia originales.

Detalle completo en [`LICENCIAS.md`](../LICENCIAS.md).

### El contenido de este kit

Los archivos propios de Hefesto (`compose.yaml`, scripts, ejemplos, documentos)
son MIT. No arrastran la licencia de Appsmith, y Appsmith no les impone nada.

### Componentes embebidos en la imagen

| Componente | Licencia | Nota |
|---|---|---|
| MongoDB | SSPL | Afecta a quien lo **redistribuye**, no a quien lo usa en un servicio web. Hefesto lo descarga desde Docker Hub, no lo redistribuye |
| Redis | BSD / RSALv2 / SSPL | Triple licencia |
| PostgreSQL | PostgreSQL License | Permisiva |
| Caddy | Apache-2.0 | |
| Nginx | BSD-2-Clause | Solo en modo proxy |
| OpenJDK | GPLv2 + excepción de enlazado | La excepción permite el uso en servidor |
| Node.js | MIT | |

> **Licencias de terceros: pendientes.** La lista anterior es la que se observa
> leyendo los archivos de configuración del despliegue oficial. **No se hizo un
> barrido completo de los licencias dentro de la imagen.** Para una entrega
> formal que exija inventario de licencias, hay que revisar la imagen ya
> construida con una herramienta como `license-finder` o equivalente. Anotado
> en `07-PRUEBAS-DE-ACEPTACION.md`.

---

## 2. Fuentes consultadas

Todas consultadas el 2026-10-16.

### Documentación oficial de Appsmith

| Tema | URL |
|---|---|
| Instalación con Docker | <https://appsmith.com/docs/getting-started/setup/installation-guides/docker> |
| Variables de entorno | <https://appsmith.com/docs/getting-started/setup/environment-vars> |
| Dimensionamiento de infraestructura | <https://appsmith.com/docs/getting-started/setup/infrastructure-sizing> |
| Errores de rendimiento y recursos | <https://appsmith.com/docs/help-and-support/troubleshooting-guide/performance-resource-errors> |
| `appsmithctl` (respaldo y restauración) | <https://appsmith.com/docs/getting-started/setup/instance-management/appsmithctl> |
| Configuración de autenticación | <https://appsmith.com/docs/getting-started/setup/instance-configuration/authentication/> |
| SAML SSO | <https://appsmith.com/docs/getting-started/setup/instance-configuration/authentication/security-assertion-markup-language-saml/> |
| OIDC SSO | <https://appsmith.com/docs/getting-started/setup/instance-configuration/authentication/openid-connect-oidc/> |
| Audit Logs | <https://appsmith.com/docs/advanced-concepts/audit-logs> |
| Conexión a PostgreSQL | <https://appsmith.com/docs/connect-data/reference/connection-postgres> |
| Consultas a PostgreSQL | <https://appsmith.com/docs/connect-data/reference/querying-postgres> |
| Importar y exportar entidades | <https://appsmith.com/docs/build-apps/how-to-guides/import-export-app-entities> |
| Control de versiones con Git | <https://appsmith.com/docs/advanced-concepts/version-control-with-git/> |
| Importación por API | <https://appsmith.com/docs/connect-data/reference/curl-import> |

### Código fuente de Appsmith

Todas desde la rama `release` de `github.com/appsmithorg/appsmith`:

| Archivo | Para qué se leyó |
|---|---|
| `LICENSE` | Confirmar Apache-2.0 |
| `Dockerfile` | El `HEALTHCHECK` oficial y los `EXPOSE` |
| `deploy/docker/docker-compose.yml` | El compose de referencia de la imagen |
| `deploy/docker/README.md` | Volumen `/appsmith-stacks`, puertos, creación del administrador |
| `deploy/docker/fs/opt/appsmith/entrypoint.sh` | Variables reales, generación de claves, rutas de datos |
| `deploy/docker/fs/opt/appsmith/healthcheck.sh` | Qué comprueba el healthcheck |
| `deploy/docker/fs/opt/appsmith/load-env.sh` | Cómo se carga la configuración |
| `deploy/docker/fs/opt/appsmith/templates/docker.env.sh` | Plantilla de configuración que escribe la imagen |
| `deploy/docker/fs/opt/appsmith/caddy-reconfigure.mjs` | Comportamiento de `APPSMITH_CUSTOM_DOMAIN` y TLS |
| `deploy/docker/fs/opt/appsmith/templates/supervisord/mongodb.conf` | Ruta de datos de MongoDB y `--bind_ip localhost` |
| `deploy/docker/fs/opt/bin/ctl` | El ejecutor de `appsmithctl` |

### Docker Hub

| Consulta | URL |
|---|---|
| Etiquetas de `appsmith/appsmith-ce` | <https://hub.docker.com/v2/repositories/appsmith/appsmith-ce/tags> |
| Imagen pública | <https://hub.docker.com/r/appsmith/appsmith-ce> |

Resultado: `v2.5.0` publicada el 2026-10-09, digest
`sha256:5b6133ab8317b98edf9dc0315a02d12f9861ab2acc89386c0b1f5b7938dfeb90`,
plataformas `linux/amd64` y `linux/arm64`.

### Repositorio de documentación

`github.com/appsmithorg/appsmith-docs`, rama `main`. De ahí se leyó el contenido
de las páginas oficiales, para citar la fuente primaria y no una copia.

---

## 3. Hallazgos que contradicen lo que se asumía al empezar

Estos puntos son los que más importan revisar, porque son los que cambian
decisiones.

### 3.1 No existe `APPSMITH_ADMIN_PASSWORD`

Lo esperable, por costumbre de otras herramientas, era encontrar una variable
para fijar la contraseña del administrador inicial. **No existe en `v2.5.0`.**

- La variable que sí existe es `APPSMITH_ADMIN_EMAILS`, **en plural**.
- No hay ninguna variable de contraseña de administrador en el `entrypoint.sh`
  ni en la plantilla de configuración de la imagen.

**Consecuencia:** el administrador se crea en el formulario web, y su
contraseña la elige una persona en el navegador. El único control por
configuración es qué correos pueden ser administradores.

### 3.2 Las claves de cifrado se autogeneran si no se fijan

El entrypoint genera la contraseña de cifrado, la sal, la contraseña de MongoDB
y la de Redis, y las escribe en `docker.env` dentro del volumen. Funciona, pero
significa que **el valor existe solo dentro del VPS**. Si ese archivo se pierde,
las credenciales guardadas quedan indescifrables.

Por eso el kit las fija explícitamente.

### 3.3 2 vCPU / 8 GB sí es recomendación oficial

Venía como recomendación de guías de terceros. La documentación oficial de
Appsmith confirma 2 vCPU con 8 GB como punto de partida para el despliegue todo
en uno, y usa `t3.large` como mínimo en la guía de AWS. **La misma
documentación advierte que el número de usuarios no es una métrica confiable
para dimensionar.**

### 3.4 MongoDB, confirmado

La base interna es MongoDB, embebido, con `--bind_ip localhost`, sobre
`/appsmith-stacks/data/mongodb`. **No hay PostgreSQL como base interna**, y por
eso **Supabase no se puede ofrecer como base interna**, solo como fuente de
datos de las apps por su conexión PostgreSQL.

### 3.5 El healthcheck ya viene en la imagen

La imagen trae `HEALTHCHECK --interval=15s --timeout=15s --start-period=45s CMD
"/opt/appsmith/healthcheck.sh"`. No hace falta inventar un `curl` propio. El
kit declara el mismo script con los mismos parámetros en `compose.yaml`, para
que el estado sea visible en `docker compose ps`.

### 3.6 `appsmithctl backup` sí existe

No hubo que inventar un mecanismo de respaldo: existe una función oficial que
exporta la base interna, el `docker.env` y los repositorios Git.

### 3.7 Audit Logs y SSO son de pago

- Audit Logs: **Business**.
- SAML SSO: **Enterprise**.
- OIDC SSO: **Enterprise**.

En Community Edition no hay ninguno de los tres.

### 3.8 La etiqueta `release` estaba más adelante que la última versión

Al consultar Docker Hub, `release` apuntaba a un digest **distinto** al de
`v2.5.0`, publicado el mismo día de la consulta. Es decir, hay compilaciones que
se despliegan antes de recibir etiqueta semantica. Fijar `release` habría
instalado algo sin número de versión conocido.

---

## 4. Lo que Hefesto NO verificó

Para que la lista sea completa, y porque un kit honesto dice lo que no sabe:

| No verificado | Por qué importa |
|---|---|
| Barrido completo de licencias dentro de la imagen | Puede haber componentes de terceros sin listar |
| Que ToolJet sea efectivamente AGPL-3.0 | La comparación de `LICENCIAS.md` se basa en el dato conocido, sin contrastarlo contra su repositorio en esta sesión |
| Que un `.json` de app exportado desde `v2.5.0` se reimporte limpio | Afecta la estrategia de traspaso |
| El comportamiento exacto de `appsmithctl restore --force` en esta versión | Afecta el plan de recuperación ante desastres |
| Cuáles nombres de variable de correo rigen realmente (`EMAIL_*` vs `MAIL_*`) | Afecta la configuración de SMTP |
| El valor por defecto de `APPSMITH_JAVA_HEAP_ARG` | Afecta el ajuste de memoria |
| El comportamiento de red entre Coolify y el servicio Compose | Afecta la instalación en Coolify |
| El canal oficial de avisos de seguridad de Appsmith | Afecta si Hefesto puede prometer avisos al cliente |

Todo esto está detallado con su número de prueba en
[`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md).

---

Ver también: [`LICENCIAS.md`](../LICENCIAS.md) ·
[`VERSION.md`](../VERSIÓN.md) ·
[`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md)