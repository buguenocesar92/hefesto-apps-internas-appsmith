# 08 — Servicios comerciales

Este documento es para usar **en la venta**, pero también para **no
sobreprometer**. Las restricciones de la edición gratuita son reales y el
cliente tiene que conocerlas antes de firmar.

## Qué es una aplicación interna, en una frase

> **Una herramienta web que usa el personal de la empresa, con su propia
> sesión y sus propios permisos, para leer o modificar los datos que la empresa
> ya tiene en otro sistema.**

Lo que importa de esa definición:

- **No reemplaza al sistema que ya existe.** El ERP sigue siendo el ERP. El
  panel muestra y opera sobre sus datos; no lo sustituye.
- **No es para clientes externos.** Los usuarios son empleados, no clientes del
  negocio.
- **No es una tienda.** No hay carrito, ni checkout, ni pasarela de pago.
- **Se entra con correo y contraseña de la empresa**, o con login de Google.

Ejemplos típicos para una Pyme chilena:

| Aplicación | Qué reemplaza | Qué **no** reemplaza |
|---|---|---|
| Panel de pedidos | La planilla de Excel que se rompe a las 300 filas | El ERP |
| Consola de soporte | El correo con "asunto: URGENTE" | El sistema de tickets |
| Control de stock | El cuaderno en la bodega | El sistema de inventario |
| Tablero de cobranzas | El archivo de carteras | El sistema de cuentas por cobrar |
| Formulario de pedidos | El formulario en PDF que se llena a mano | — |
| Reporte para el directorio | La consulta que alguien corría a mano | El sistema de reportes |

### Qué NO es Appsmith

Esto hay que decirlo antes de que el cliente pregunte, no después:

- **No es un ERP.** No hace inventario con lotes ni seriales, no lleva
  contabilidad, no emite facturas electrónicas. Si eso se necesita, se compra un
  ERP y se conecta.
- **No es una aplicación móvil.** Es una aplicación web. Se puede usar desde el
  celular en el navegador, y se puede ajustar a pantallas chicas, pero no es una
  app nativa que se instale desde la tienda de aplicaciones ni que funcione sin
  conexión.
- **No es multi-tenant.** Ver la sección siguiente, que es la más importante de
  este documento.

## ⚠️ No es multi-tenant. Léase con atención.

> **Una instancia de este kit es para un cliente.**

Si Hefesto vende esta instalación a tres Pymes distintas, son **tres
instancias**, en tres VPS o en tres recursos separados de Coolify.

Una instancia compartida entre dos empresas significaría que:

- Un constructor de la empresa A puede ver las fuentes de datos de la empresa
  B, porque no existe separación de datos entre organizaciones.
- Un usuario de la empresa A podría llegar a una app de la empresa B si se
  asignan mal los permisos.
- Un constructor con permisos puede cambiar cualquier conexión. En Community
  Edition **no hay auditoría de quién hizo qué**.

Por eso **no se ofrece una instancia compartida**. Y hay que decirlo en la
propuesta comercial, por escrito, aunque el cliente no pregunte: es la clase de
supuesto que después genera conflictos.

> **Cuándo sí conviene una instancia compartida.** Cuando todos los usuarios de
> todos los clientes pertenecen a la **misma** organización. Por ejemplo, una
> consultora que le vende herramientas internas a sus **propios** empleados.
> Ahí sí tiene sentido una sola instancia con usuarios de distintas unidades.
> Incluso ahí, con cuidado y con roles bien definidos.

## Supabase: dónde sí y dónde no

**No, Supabase no se puede ofrecer como la base interna de Appsmith.** La base
interna de Appsmith es **MongoDB**, no PostgreSQL. Está verificado: la
documentación oficial describe MongoDB como la base del sistema, y la imagen lo
arranca embebido con `mongod --port 27017` sobre
`/appsmith-stacks/data/mongodb`. No es configurable en la Community Edition.

**Sí, Supabase puede ser una fuente de datos de las apps**, con condiciones:

| Condición | Por qué |
|---|---|
| Usar **el connection string de PostgreSQL** de Supabase, no la API de Supabase | Appsmith tiene un conector nativo de PostgreSQL, que es lo que se verificó |
| Conectar por **TLS** | La cadena de conexión de Supabase ya lo incluye con `sslmode=require` |
| Crear un **rol de solo lectura** en la base, con su propia contraseña | Es el mismo patrón de `ejemplos/postgres/rol-solo-lectura.sql` |
| No usar la `service_role` ni la clave de API de Supabase | Esas claves saltan los permisos de PostgreSQL. Con una conexión PostgreSQL normal no hacen falta |
| No exponer el panel de Supabase a internet sin necesidad | Supabase queda como backend, no como interfaz para el usuario |

En resumen: **Supabase sí, como fuente de datos de la app, por PostgreSQL con
TLS y un rol de solo lectura. No, como la base interna de Appsmith.**

**Por qué esa distinción importa en la venta:** muchos clientes Pyme ya tienen
Supabase. Poder conectar Appsmith a Supabase es un argumento de venta fuerte y
legítimo, siempre que se diga **para qué** sirve.

## Límites de la edición gratuita

Esto es lo que el cliente tiene que saber **antes** de contratar. Son
restricciones reales, no advertencias de marketing.

### Funciones de pago

| Función | Edición necesaria | Por qué importa |
|---|---|---|
| **Audit Logs** (registro de auditoría) | **Business** | Saber quién entró, qué cambió y cuándo. **En Community Edition no existe.** |
| **SAML SSO** | **Enterprise** | Ingreso corporativo con Okta, Azure AD, etc. |
| **OIDC SSO** | **Enterprise** | Ingreso corporativo con un proveedor OIDC |
| Respaldos automáticos programados | **Business** | En Community hay que armarlos con un cron |
| Sincronización de respaldos a S3 | **Business** (de pago) | Respaldo fuera del servidor |
| Exportación de auditoría | Función de pago | — |

Fuentes:
- Audit logs: <https://appsmith.com/docs/advanced-concepts/audit-logs>
- SAML: <https://appsmith.com/docs/getting-started/setup/instance-configuration/authentication/security-assertion-markup-language-saml>
- OIDC: <https://appsmith.com/docs/getting-started/setup/instance-configuration/authentication/openid-connect-oidc>

### Qué NO tiene límite

- **Usuarios: sin límite.** La Community Edition no cobra ni limita el número
  de usuarios de la instancia.
- **Aplicaciones: sin límite.**
- **Costo de licencia: cero.**

> **Aviso que hay que hacer al cliente sobre la auditoría.** Es lo que más se
> repite después. Si el cliente tiene una 
> exigencia de compliance o de auditoría sobre quién accedió a qué dato_, la
> Community Edition **no la puede satisfacer**. No es que sea difícil: es que no
> existe. Si ese requisito aparece, o se usa otra herramienta, o se compra la
> edición Business. Decirlo el primer día evita una conversación incómoda más
> adelante.

### Alternativas que sí están en Community Edition

Para que la conversación no sea solo sobre lo que falta:

- **Login con Google y con GitHub.** Las variables están presentes en la imagen
  de la Community Edition. Para una Pyme de 15 personas, el login con Google
  corporativo cubre bien el caso de uso sin pagar.
- **Control de versiones con Git.** Disponible en Community Edition. Permite
versionar las apps en un repositorio y recuperar versiones anteriores.
- **Autenticación de dos factores.** Disponible en la configuración del
  administrador. Activarla siempre.

## Alcance del servicio

Lo que Hefesto entrega y cobra:

| Incluido | Detalle |
|---|---|
| Aprovisionamiento | VPS, Docker, despliegue del kit |
| Configuración | Variables, dominio, TLS, correo |
| Fuente de datos | Una conexión de solo lectura, con el rol configurado |
| Primera aplicación | Una app funcionando, con el cliente revisando los resultados |
| Capacitación | Una sesión con las personas que la van a usar |
| Documentación | Este kit |
| Un respaldo por mes | Y la restauración probada una vez |

### Lo que NO está incluido, y hay que dejarlo por escrito

| No incluye | Por qué |
|---|---|
| Desarrollo de aplicaciones a medida | Es un proyecto aparte, se cotiza aparte |
| Soporte 24/7 | Es un contrato distinto |
| Integración con el ERP del cliente | Cada ERP es distinto y requiere análisis |
| Migración de datos | Requiere conocer el sistema de origen |
| Garantía de que Appsmith no tenga vulnerabilidades | Nadie puede garantir eso |
| Auditoría de accesos | No existe en Community Edition |
| SSO corporativo | No existe en Community Edition |

### Sobre el respaldo mensual incluido

Un respaldo que nunca se restauró no es un respaldo. **La primera restauración
de prueba completa debe occurir dentro del primer mes**, aunque cueste tiempo.
Si no hay tiempo para restaurarlo, hay que decirlo y cobrarlo aparte, no
ofrecerlo gratis y no hacerlo.

## Cómo presentar la decisión Appsmith

Argumento para una Pyme, en una frase:

> "Le instalo un panel interno sobre los datos que ya tiene, con la licencia de
> Appsmith: sin costo de licencia, sin límite de usuarios, y el código queda
> suyo, porque es Apache-2.0."

Y lo que hay que decir sí o sí antes de firmar:

1. **Una instancia es para usted.** No se comparte entre clientes.
2. **Comunidad Edition.** Hay funciones de pago: auditoría de accesos y SSO
   corporativo no están.
3. **El panel lee sus datos.** Lo conecto en solo lectura; si quiere que también
   escriba, es un análisis aparte.
4. **El respaldo mensual incluye restaurar una vez.** La segunda va aparte.

---

Ver también: [`LICENCIAS.md`](../LICENCIAS.md) ·
[`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md) ·
[`README.md`](../README.md)