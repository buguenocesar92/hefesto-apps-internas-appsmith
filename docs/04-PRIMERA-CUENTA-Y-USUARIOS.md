# 04 — Primera cuenta y usuarios

Este es el punto más delicado de toda la instalación. Un error aquí deja una
instancia abierta a cualquiera que encuentre la URL.

## El orden correcto

```
1. Levantar la instancia con APPSMITH_SIGNUP_DISABLED=false
2. Crear la cuenta de administrador
3. Verificar que la cuenta existe y tiene permisos de administrador
4. Cambiar APPSMITH_SIGNUP_DISABLED=true
5. Crear el resto de las cuentas, una por una
6. Verificar que /signup quedó cerrado
```

**No hay que saltarse el paso 1.** Con el registro cerrado no hay forma de
crear la primera cuenta.

## Por qué no se puede crear el administrador por variables de entorno

Mucha gente busca `APPSMITH_ADMIN_EMAIL` y `APPSMITH_ADMIN_PASSWORD`, porque
en versiones antiguas de otras herramientas esos nombres existían. En la
versión fijada por este kit (`v2.5.0`):

- La variable que existe es **`APPSMITH_ADMIN_EMAILS`**, en plural.
- **No existe ninguna variable de contraseña de administrador.**

Hefesto verificó esto en el código de la imagen: ni `entrypoint.sh` ni la
plantilla de configuración de la imagen mencionan una variable
`APPSMITH_ADMIN_PASSWORD` ni una de correo en singular.

Consecuencia: **la contraseña la elige una persona en un navegador**. Hefesto
no puede fijarla por adelantado, y tampoco puede crearse la cuenta por línea
de comandos. Lo único que se controla desde la configuración es **qué correos
tienen derecho a ser administradores**.

## Crear la cuenta

1. Con el servicio arriba, abrir `https://apps.ejemplo.cl`.
2. Aparecerá el formulario de creación de cuenta. La guía oficial de Docker
   dice: *"Complete sus datos para crear una cuenta de administrador"*.
3. Usar **un correo corporativo real** de la persona que va a administrar la
   instancia. No un genérico: la cuenta es personal y cada persona de Hefesto
   debería tener la suya, con su propia clave.
4. Elegir una contraseña larga y única.
5. Enviar y confirmar.

Fuente: <https://appsmith.com/docs/getting-started/setup/installation-guides/docker>

> **Por qué el correo importa tanto.** `APPSMITH_ADMIN_EMAILS` es la lista que
> define quién puede administrar. Si Hefesto pone ahí un correo que no le
> pertenece a nadie en el cliente, ese correo queda con permisos de
> administrador para siempre, y el día que alguien con acceso a ese buzón se
> vaya de la empresa, el acceso se queda con esa persona.

## Verificar que la cuenta quedó bien

Antes de cerrar el registro:

1. Entrar con la cuenta nueva.
2. Ir a `Settings` → *General*. Debe aparecer el nombre de la instancia y las
   opciones de administración.
3. Confirmar que aparece listada entre los administradores de la instancia.

## Cerrar el registro

En `.env` (o en las variables de Coolify):

```bash
APPSMITH_SIGNUP_DISABLED=true
```

Reiniciar y comprobar:

1. Abrir `https://apps.ejemplo.cl/#signup` en una ventana incógnito.
2. Debe aparecer un error o el formulario no debe admitir el registro.
3. **Intentar registrarse con un correo nuevo** y confirmar que falla.

> Si el paso 3 no se hace, el cierre no está probado. Es exactamente el tipo de
> verificación que se anota en `07-PRUEBAS-DE-ACEPTACION.md`.

## Crear las cuentas de los usuarios

**Una por una**, desde la interfaz, en `Settings` → *Users* → *Invite New
User*. No hay forma de crear usuarios en bloque.

Para cada persona:

| Campo | Recomendación |
|---|---|
| Correo | El correo corporativo real |
| Rol | El rol asignado abajo, **nunca** administrador |

Para el cliente Pyme, una proposta de roles razonable:

| Rol | Puede | No puede |
|---|---|---|
| Administrador de instancia | Todo, incluidas configuraciones, usuarios y bases de datos | — |
| Editor | Crear y modificar aplicaciones | Administrar la instancia |
| Viewer | Ver y usar aplicaciones, sin editar | Crear ni modificar nada |

Y **siempre** un rol a la medida, limitado a una app o a un conjunto de
widgets, en vez de dar acceso a todo. Un rol por app es más trabajo al inicio
y mucho menos riesgo después.

## Autenticación: qué se puede y qué no se puede hacer gratis

| Método | ¿Community Edition? | Nota |
|---|---|---|
| Correo y contraseña | Sí | Funciona bien; es la base de todo lo demás |
| Login con Google | Sí | Variables presentes en la imagen de la Community Edition |
| Login con GitHub | Sí | Ídem |
| **SAML SSO** | **No** | Requiere edición Enterprise |
| **OIDC SSO** | **No** | Requiere edición Enterprise |

Este es un límite real que hay que decir **antes** de firmar. Si el cliente
tiene Microsoft Entra ID, Okta, Google Workspace corporativo u otro proveedor
SSO, la Community Edition **no lo soporta**. Ver
`08-SERVICIOS-COMERCIALES.md`.

> **Contraseña del administrador: cómo fuertes tienen que ser.** Con el
> registro abierto durante la instalación, cualquiera que encuentre la URL
> puede crear la cuenta. Por eso el procedimiento es corto: levantar, crear la
> cuenta, cerrar. Si alguien alcanzara a registrarse primero, esa persona
> queda como administradora de la instancia y habría que contactar al soporte
> de Appsmith para recuperar el control. No hay self-service.

> **Restablecer la contraseña.** La opción *Forgot password* envía un correo
> al correo de la cuenta. Por eso hace falta configurar SMTP **antes** de que
> a alguien se le olvide la contraseña. Configurar el correo no es opcional en
> un servicio de pago: ver la nota sobre los nombres de las variables en
> `03-VARIABLES-Y-COMO-OBTENERLAS.md`.

## Prueba de aceptación mínima de esta etapa

- [ ] La cuenta de administrador se creó y puede entrar.
- [ ] Tiene permisos de administrador de instancia.
- [ ] El registro está cerrado y un correo nuevo **no** puede registrarse.
- [ ] Existe al menos un rol específico para los usuarios finales, y ese rol
      **no** tiene permiso de edición sobre las bases de datos.
- [ ] SMTP funciona: se puede usar *Forgot password*.
- [ ] Los correos de los administradores son todos corporativos y reales.

---

Ver también: [`02-INSTALACION-COOLIFY.md`](02-INSTALACION-COOLIFY.md) ·
[`08-SERVICIOS-COMERCIALES.md`](08-SERVICIOS-COMERCIALES.md) ·
[`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md)