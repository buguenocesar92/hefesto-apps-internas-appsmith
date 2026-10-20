# LICENCIAS.md

Este documento responde una sola pregunta: **¿puede Hefesto Studio revender un
despliegue de Appsmith Community Edition a una Pyme como servicio?**

Respuesta corta: **sí, y la licencia es la razón principal por la que se eligió
Appsmith en lugar de ToolJet.**

## 1. La aplicación que se instala

| Elemento | Valor |
|---|---|
| Componente | Appsmith Community Edition |
| Imagen | `appsmith/appsmith-ce` |
| Versión fijada en este kit | `v2.5.0` |
| Licencia del nucleo | **Apache License 2.0** |
| Fuente de la licencia | `LICENSE` en la rama `release` de `github.com/appsmithorg/appsmith` |
| Modelo de distribucion | Imagen oficial de Docker Hub, publicada por Appsmith Inc. |

Texto verificado (inicio del archivo `LICENSE` del repositorio, 2026-10-16):

```
Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION
```

### Que permite Apache-2.0 en la práctica comercial

- **Uso comercial:** permitido, sin pagar regalías a nadie.
- **Distribucion y reventa:** permitida.
- **Modificacion:** permitida.
- **Patentado:** hay clausula dePatentado en la seccion 3.
- **Copyleft:** **ninguno.** No hay obligacion de publicar el código fuente de
  la aplicación ni de las apps construidas sobre ella.
- **Atribucion:** hay que mantener los avisos de licencia de los archivos de
  licencia originales al redistribuir.

En terminos practicalos: Hefesto puede cobrar por instalar, configurar,
personalizar y mantener la instancia, y el código del cliente queda en el
cliente. No hay que abrir el código de las apps internas.

## 2. Por que Appsmith y no ToolJet

| Criterio | Appsmith CE | ToolJet |
|---|---|---|
| Licencia del nucleo | **Apache-2.0**, sin copyleft | **AGPL-3.0** |
| Consecuencia legal de AGPL | — | Si se ofrece el software como servicio accesible por red, la AGPL obliga a ofrecer el código fuente correspondiente a los usuarios. Es una exposicion real para una Pyme que contrata un servicio y no quiere publicar su código. |
| Topologia de despliegue | **Un solo contenedor**: Appsmith, MongoDB, Redis, PostgreSQL embebido, Caddy y supervisord en una imagen | Varios servicios que hay que operar y monitorizar por separado |
| Costo de operación para una Pyme | Un VPS | Varios contenedores, varios puntos de falla |

**Conclusion comercial:** ToolJet es AGPL-3.0. Bajo AGPL, un despliegue
autohospedado que se ofrece por red puede obligar a compartir el código fuente
del servicio. Para una Pyme que paga por un panel interno, esa es una
conversacion que Hefesto quiere evitar por completo. Appsmith es Apache-2.0:
se instala, se configura, se vende y no arrastra ninguna obligacion de
divulgacion.

Ademas Appsmith ofrece editions que se pueden contratar por separado
(Business y Enterprise) sin cambiar la licencia del nucleo. Ver
`docs/08-SERVICIOS-COMERCIALES.md`.

## 3. Dependencias embebidas en la imagen

La imagen `appsmith-ce` trae dentro componentes de terceros. No se instalan a
mano ni se compilan, pero se anotan por transparencia:

| Componente | Rol dentro del contenedor | Licencia |
|---|---|---|
| MongoDB | Base de datos interna de Appsmith | SSPL (server-side public license) en el Community Edition de MongoDB |
| Redis | Cache y sesiones | BSD / RSALv2 / SSPL (triple licencia en versiones modernas) |
| PostgreSQL | Base embebida auxiliar | PostgreSQL License (permisiva) |
| Caddy | Servidor HTTP/HTTPS interno | Apache-2.0 |
| Nginx | Termino TLS opcional en modo proxy | BSD-2-Clause |
| Java / OpenJDK | Runtime del backend | GPLv2 con excepción de enlazado (Classpath Exception) |
| Node.js | Runtime del editor y del control CLI | MIT |

### Observacion honesta sobre MongoDB

Appsmith **no es PostgreSQL**. Su almacén interno es **MongoDB**, ejecutado
embebido dentro del propio contenedor desde `/appsmith-stacks/data/mongodb`, con
Redis embebido también. Esto esta confirmado por la documentacion oficial de
Appsmith, que describe MongoDB como base de datos del sistema, y por el
archivo `deploy/docker/fs/opt/appsmith/templates/supervisord/mongodb.conf` del
repositorio, que la arranca con `mongod --port 27017 --dbpath .` y
`--bind_ip localhost`.

Consecuencia comercial que hay que decir de frente:

- **No se puede ofrecer Supabase ni ningun PostgreSQL como la base interna de
  Appsmith.** La base interna es MongoDB y no es negociable en Community Edition.
- Si el cliente quiere Postgres, ese Postgres es para las **fuentes de datos de
  las apps**, no para el almacenamiento de Appsmith. Ver `docs/10`.
- La licencia SSPL de MongoDB afecta a quien **redistribuye** MongoDB, no al
  cliente que usa una app web. Hefesto no redistribuye MongoDB: se descarga
  desde Docker Hub al desplegar. Aun así, conviene que el cliente lo sepa.

## 4. Lo que este kit contiene

| Archivo | Licencia del contenido |
|---|---|
| `compose.yaml` | MIT (Hefesto Studio) |
| `.env.example`, `.gitignore` | MIT (Hefesto Studio) |
| `VERSION.md`, `LICENCIAS.md`, `README.md`, `docs/*` | MIT (Hefesto Studio) |
| `scripts/*` | MIT (Hefesto Studio) |
| `ejemplos/*` | MIT (Hefesto Studio) — datos de demostracion inventados |
| `config/*` | MIT (Hefesto Studio) |

El contenido de este kit es MIT. Los archivos de Hefesto no arrastran la
licencia de Appsmith ni al reves: son originales. La aplicación instalada
arrastra Apache-2.0 y las licencias de sus dependencias, que se enumeran mas
arriba.

## 5. Avisos que hay que conservar

Al entregar el despliegue a un cliente:

1. Mencionar en la propuesta que la aplicación es **Apache-2.0**.
2. Conservar el `LICENSE` de Appsmith accesible. La forma simple y suficiente es
   dejar en el kit un archivo `LICENSE-APPSMITH.txt` con el texto de Apache-2.0.
3. No quitar los avisos de licencia de la interfaz ni de la imagen.

## 6. Verificación

| Hecho | Como se verifico | Fecha |
|---|---|---|
| Licencia Apache-2.0 del nucleo | Lectura de `LICENSE` en `github.com/appsmithorg/appsmith`, rama `release` | 2026-10-16 |
| Imagen oficial `appsmith-ce` | Pagina oficial de instalación con Docker en la documentacion de Appsmith | 2026-10-16 |
| MongoDB como almacen interno | Pagina de variables de entorno de la documentacion oficial, que describe MongoDB como base de datos del sistema, mas `mongodb.conf` en el repositorio | 2026-10-16 |
| ToolJet es AGPL-3.0 | Declarado por el proveedor en su propio repositorio. **No fue verificado por Hefesto contra el repositorio de ToolJet en esta sesión.** Confirmarlo antes de usar esta tabla en una propuesta comercial. | — |