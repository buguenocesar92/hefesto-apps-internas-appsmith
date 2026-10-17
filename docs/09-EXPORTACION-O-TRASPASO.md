# 09 — Exportación y traspaso

Este documento sirve para dos momentos distintos:

1. **Traspaso del proyecto a otro proveedor o a otra persona.**
2. **Entregar las apps al cliente y que las mantenga él.**

En ambos casos la pregunta es la misma: ¿qué hay que llevarse para no perder
nada?

> **Estado: kit preparado.** Los procedimientos de este documento **no se
> ejecutaron**. En particular, la exportación de apps a JSON y la importación
> por `curl` están documentadas según la documentación oficial, pero **no se
> verificó** que una app exportada desde `v2.5.0` se reimporte limpia. Esa es
> la prueba P48 en `07-PRUEBAS-DE-ACEPTACION.md` y hay que hacerla **antes** de
> prometer que el traspaso va a funcionar.

---

## La respuesta corta

> **Para traspasar una instancia completa, lo que hay que llevarse es el
> volumen completo más las dos claves de cifrado.**

Los tres ingredientes son:

| Ingrediente | Dónde está | Por qué |
|---|---|---|
| El volumen `/appsmith-stacks` | `respaldos/<marca>/volumen-appsmith-stacks.tar.gz` | Apps, usuarios, conexiones, configuración |
| `APPSMITH_ENCRYPTION_PASSWORD` y `SALT` | `.env` del servidor **y** el gestor de contraseñas | Sin ellos, las credenciales guardadas no se pueden descifrar |
| El `.env` | `.env.example` más los valores reales | Configuración del despliegue |

Con esos tres, se levanta una instancia idéntica en otra máquina.

---

## Nivel 1 — Traspaso de la instancia completa

Es el nivel que sirve para migrar de un VPS a otro, o para que el cliente se
lleve todo.

### En la máquina de origen

```bash
cd /opt/hefesto/appsmith
./scripts/respaldo.sh --salida /mnt/medio/traspaso
cd /mnt/medio/traspaso
sha256sum -c SHA256SUMS
```

Copiar la carpeta completa a un medio externo, junto con el `.env`.

```bash
cp /opt/hefesto/appsmith/.env /mnt/medio/traspaso/.env
```

> El `.env` y el paquete de respaldo son **secretos**. Transportarlos en un
> medio cifrado. No mandarlos por correo.

### En la máquina de destino

```bash
mkdir -p /opt/hefesto/appsmith
cd /opt/hefesto/appsmith
cp -r /ruta/del/kit/* .

# El .env con los MISMOS valores de cifrado del origen
cp /ruta/traspaso/.env .env
chmod 600 .env

# Restaurar el volumen
./scripts/restaurar.sh --archivo /ruta/traspaso --force

docker compose up -d
docker compose logs -f --tail=200
```

### Lo que hay que verificar antes de dar el traspaso por bueno

- [ ] La interfaz carga y el dominio responde.
- [ ] Se puede entrar con una cuenta existente.
- [ ] Una app con consultas devuelve los mismos datos.
- [ ] Las fuentes de datos están conectadas y **funcionan**: si el `docker.env`
      restaurado trae el cifrado correcto, las credenciales se descifran solas.
- [ ] Las fuentes de datos siguen siendo alcanzables **desde el servidor
      nuevo**. Si el cliente cambió de red o de firewall, hay que rehacer la
      conexión.
- [ ] El certificado TLS se emite bien en el dominio nuevo.

> **La trampa clásica del traspaso.** Restaurar el volumen copia la URL de la
> instancia anterior. Si `APPSMITH_BASE_URL` sigue apuntando al dominio viejo,
> la validación de `Origin` rechaza el navegador en el nuevo. Hay que ajustar
> `APPSMITH_BASE_URL` y reiniciar.

---

## Nivel 2 — Exportar una aplicación

Útil cuando el cliente quiere el código de una app, o para trabajar sobre una
app sin tocar la instancia.

### Opción A — Git (recomendada)

Appsmith tiene control de versiones con Git integrado, disponible en Community
Edition. Cada app se puede conectar a un repositorio y cada cambio se guarda
como un commit.

Ventajas: historial completo, diffs, se puede volver a una versión anterior, y
los archivos de la app quedan en texto legible.

Configuración: `APPSMITH_GIT_ROOT` debe estar dentro del volumen persistente
(`/appsmith-stacks/data/git`). Después, en la app: *Settings* → *Deploy* →
*Git*.

### Opción B — Exportar a JSON

En el editor de apps, `Apps` → el menú de la aplicación → *Export* descarga un
`.json` con la definición de la app, las páginas, los widgets y las consultas.

```bash
# Importar en otra instancia
# Se hace desde la interfaz: Apps -> + New -> Import
```

> **Advertencia honesta y importante.** El formato de exportación de Appsmith es
> interno y **cambia entre versiones**. Un `.json` exportado desde `v2.5.0`
> puede no importarse limpio en una versión distinta. Además, el `.json` de una
> app **no contiene las credenciales de la fuente de datos** (eso se guarda por
> aparte, cifrado), así que al importar hay que volver a configurar la
> conexión.
>
> Por eso el **Nivel 1 es el único traspaso confiable**. Git es más robusto que
> JSON para este propósito, porque el historial es recuperable aunque el
> formato cambie.

### Opción C — Exportar las fuentes de datos por API

Las fuentes de datos (las conexiones) se pueden exportar por API, usando el
token de sesión. Existe un endpoint de importación documentado por Appsmith para
este caso.

> **No se incluye aquí el comando exacto.** La documentación de importación por
> `curl` usa un **token de sesión del navegador**, y escribir ese comando sin
> haberlo ejecutado contra una instancia real es justo el tipo de instrucción
> que no funciona y hace perder tiempo.
>
> La alternativa segura y suficiente: **recrear las conexiones a mano** en la
> instancia nueva.Toma unos minutos por conexión y no requiere copiar
> credenciales de un lado a otro.

Fuentes:
- <https://appsmith.com/docs/build-apps/how-to-guides/import-export-app-entities>
- <https://appsmith.com/docs/advanced-concepts/version-control-with-git>
- <https://appsmith.com/docs/connect-data/reference/curl-import>

---

## Nivel 3 — Traspaso al cliente

Si la relación comercial termina o el cliente quiere operar su propia
instancia, el traspaso mínimo indispensable es:

| Elemento | Cómo se entrega |
|---|---|
| El `.env` con las claves de cifrado | Por un canal seguro, con instrucción de guardarlo en su gestor de contraseñas |
| El último respaldo verificado | Copia del directorio de respaldos |
| Acceso al servidor | Traspaso de credenciales del VPS, o traspaso del dominio al servidor del cliente |
| Acceso a Coolify | Correo de invitación como administrador, si aplica |
| Documentación de las apps | Un documento por app: qué hace, qué consulta, qué rol necesita |
| Las consultas SQL que usan | Para que el cliente sepa qué datos se están leyendo |

Lo que **no** se entrega: la propiedad de Appsmith. Es software libre; el
cliente paga la licencia de su VPS, no la de Appsmith.

---

## Lista de comprobación de traspaso

- [ ] Respaldo generado y `sha256sum -c` pasó.
- [ ] El `.env` con las claves de cifrado va incluido, en un canal seguro.
- [ ] Instancia nueva levantada y restaurada.
- [ ] Se puede entrar con una cuenta de administrador.
- [ ] Una app con consultas devuelve los mismos datos.
- [ ] Las fuentes de datos desde el servidor nuevo.
- [ ] `APPSMITH_BASE_URL` apunta al dominio nuevo.
- [ ] TLS emitido y válido.
- [ ] Documentación de cada app entregada.
- [ ] Respaldo de la instancia nueva, generado y verificado.

---

Ver también: [`05-RESPALDOS-Y-RESTAURACION.md`](05-RESPALDOS-Y-RESTAURACION.md) ·
[`07-PRUEBAS-DE-ACEPTACION.md`](07-PRUEBAS-DE-ACEPTACION.md) ·
[`LICENCIAS.md`](../LICENCIAS.md)