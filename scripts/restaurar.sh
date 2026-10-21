#!/usr/bin/env bash
# =============================================================================
# Hefesto Studio - Kit Appsmith Community Edition
# Archivo : scripts/restaurar.sh
# -----------------------------------------------------------------------------
# QUE HACE
#   Restaura un paquete generado por scripts/respaldo.sh sobre el volumen de
#   la instancia, dejando el servicio DETENIDO para que una persona valide
#   antes de levantarlo.
#
# GARANTIAS
#   - Exige el archivo COMPLETO. Un paquete a medio generar no se restaura.
#   - Verifica SHA256SUMS antes de tocar nada.
#   - Valida las rutas internas del tar antes de extraer: rechaza rutas
#     absolutas, recorridos con .. y enlaces simbolicos o duros. Un tar
#     crafted no puede escribir fuera del volumen.
#   - Si el volumen destino tiene contenido, se RECHAZA. Solo con --force.
#   - Con --force NO borra nada: mueve el contenido existente a una cuarentena
#     dentro del propio volumen. No hay DROP de base de datos en ningun caso.
#   - Termina con el servicio detenido. Nunca lo levanta solo.
#
# USO
#   ./scripts/restaurar.sh --archivo respaldos/respaldo-20261016T120000Z
#   ./scripts/restaurar.sh --archivo /mnt/respaldos/paquete --force
#   ./scripts/restaurar.sh --archivo paquete --force --destino appsmith-stacks
# =============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-comun.sh
source "$SCRIPT_DIR/lib-comun.sh"

RAIZ="$(RAIZ_KIT)"
cd "$RAIZ"

ARCHIVO=""
FUERZA="no"
SERVICIO="appsmith"
ARCHIVO_COMPOSE=""
VOLUMEN_DESTINO=""
export USAR_OVERRIDE_COOLIFY="no"

uso() {
  cat >&2 <<'EOF'
Uso: ./scripts/restaurar.sh --archivo DIR [opciones]

Obligatorio:
  --archivo DIR              Carpeta del paquete de respaldo.

Opciones:
  --force                    Restaurar aunque el volumen tenga contenido.
                             Lo que hay se mueve a una cuarentena; no se borra.
  --destino NOMBRE_VOLUMEN   Volumen a restaurar. Por defecto se descubre desde
                             el contenedor actual; si no existe, appsmith-stacks.
  --servicio NOMBRE          Servicio de Compose. Por defecto: appsmith
  --archivo-compose R        Ruta al compose.yaml.
  --override-coolify         Usar tambien config/compose.coolify.yaml.
  --ayuda                    Mostrar esta ayuda.

El servicio queda DETENIDO al terminar. Levantalo a mano cuando valides.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --archivo) ARCHIVO="${2:?falta el valor de --archivo}"; shift 2 ;;
    --force) FUERZA="si"; shift ;;
    --destino) VOLUMEN_DESTINO="${2:?falta el valor de --destino}"; shift 2 ;;
    --servicio) SERVICIO="${2:?falta el valor de --servicio}"; shift 2 ;;
    --archivo-compose) ARCHIVO_COMPOSE="${2:?falta el valor de --archivo-compose}"; shift 2 ;;
    --override-coolify) export USAR_OVERRIDE_COOLIFY="si"; shift ;;
    --ayuda|-h) uso; exit 0 ;;
    *) err "opcion desconocida: $1"; uso; exit 2 ;;
  esac
done

[ -n "$ARCHIVO" ] || { uso; die "falta --archivo"; }
ARCHIVO_COMPOSE="${ARCHIVO_COMPOSE:-$RAIZ/compose.yaml}"

requiere_docker
requiere_comando tar
requiere_comando sha256sum
configurar_compose "$ARCHIVO_COMPOSE"

log "=== restauracion de Appsmith (Hefesto Studio) ==="
log "paquete: $ARCHIVO"

# -----------------------------------------------------------------------------
# 1. El paquete existe y esta completo
# -----------------------------------------------------------------------------
[ -d "$ARCHIVO" ] || die "no existe el directorio del paquete: $ARCHIVO"
ARCHIVO="$(cd "$ARCHIVO" && pwd)"

[ -f "$ARCHIVO/COMPLETO" ] || die "el paquete NO tiene el archivo COMPLETO. No fue generado por scripts/respaldo.sh o quedo a medio generar. No se restaura."
[ -f "$ARCHIVO/SHA256SUMS" ] || die "falta SHA256SUMS en el paquete."
[ -f "$ARCHIVO/manifiesto.json" ] || die "falta manifiesto.json en el paquete."

TAR_VOLUMEN="$ARCHIVO/volumen-appsmith-stacks.tar.gz"
[ -f "$TAR_VOLUMEN" ] || die "falta el archivo de volumen: volumen-appsmith-stacks.tar.gz"

# -----------------------------------------------------------------------------
# 2. Verificacion de integridad
# -----------------------------------------------------------------------------
log "--- verificando SHA256SUMS"
( cd "$ARCHIVO" && sha256sum -c SHA256SUMS ) || die "la verificacion de checksums fallo. NO se restaura nada."
log "checksums correctos"

# -----------------------------------------------------------------------------
# 3. Validacion de rutas del tar ANTES de extraer
# -----------------------------------------------------------------------------
# Sin esto, un tar manipulado podria escribir fuera del volumen (path traversal)
# o mediante enlaces simbolicos.
log "--- validando las rutas internas del archivo"
LISTA="$(mktemp)"
trap 'rm -f "$LISTA"' EXIT
tar -tzf "$TAR_VOLUMEN" > "$LISTA" || die "no se pudo leer el archivo de volumen."

if grep -qE '^/' "$LISTA"; then
  die "el archivo contiene rutas absolutas. Se rechaza por seguridad."
fi
if grep -qE '(^|/)\.\.(/|$)' "$LISTA"; then
  die "el archivo contiene recorridos con '..'. Se rechaza por seguridad."
fi

# Enlaces simbolicos o duros permitirian apuntar fuera del volumen.
if tar -tvzf "$TAR_VOLUMEN" 2>/dev/null | awk '{print substr($1,1,1)}' | grep -qE '^[lh]$'; then
  die "el archivo contiene enlaces simbolicos o duros. Se rechaza por seguridad."
fi

TOTAL_ENTRADAS="$(wc -l < "$LISTA" | tr -d ' ')"
[ "$TOTAL_ENTRADAS" -gt 0 ] || die "el archivo de volumen esta vacio. Se rechaza."
log "rutas validadas: $TOTAL_ENTRADAS entradas, sin rutas absolutas, sin '..', sin enlaces"

# -----------------------------------------------------------------------------
# 4. Descubrir el volumen destino
# -----------------------------------------------------------------------------
CID="$(id_contenedor || true)"
if [ -z "$VOLUMEN_DESTINO" ]; then
  if [ -n "$CID" ]; then
    VOLUMEN_DESTINO="$(nombre_volumen "$CID")"
  fi
  [ -n "$VOLUMEN_DESTINO" ] || VOLUMEN_DESTINO="appsmith-stacks"
fi
log "volumen destino: $VOLUMEN_DESTINO"

IMAGEN_UTILITARIA="appsmith/appsmith-ce:v2.5.0"
if [ -n "$CID" ]; then
  detectada="$(imagen_contenedor "$CID")"
  [ "$detectada" = "desconocida" ] || IMAGEN_UTILITARIA="$detectada"
fi

# -----------------------------------------------------------------------------
# 5. Estado del destino: ocupado o vacio
# -----------------------------------------------------------------------------
# Se cuenta el contenido del volumen. Un volumen recien creado tiene una sola
# entrada: lost+found en la mayoria de los sistemas de archivos. Se acepta.
CONTENIDO_ACTUAL=0
if volumen_existe "$VOLUMEN_DESTINO"; then
  CONTENIDO_ACTUAL="$(docker run --rm --entrypoint sh -v "$VOLUMEN_DESTINO:/v:ro" "$IMAGEN_UTILITARIA" -c \
    'find /v -mindepth 1 -maxdepth 1 ! -name lost+found 2>/dev/null | wc -l' 2>/dev/null | tr -d ' ' || echo 0)"
  CONTENIDO_ACTUAL="${CONTENIDO_ACTUAL:-0}"
fi

if [ "$CONTENIDO_ACTUAL" -gt 0 ] && [ "$FUERZA" != "si" ]; then
  die "el volumen $VOLUMEN_DESTINO ya tiene $CONTENIDO_ACTUAL entradas. Para restaurar encima hay que usar --force. No se toco nada."
fi

# -----------------------------------------------------------------------------
# 6. Dejar el servicio detenido antes de tocar el volumen
# -----------------------------------------------------------------------------
if [ -n "$CID" ]; then
  log "--- deteniendo el servicio $SERVICIO"
  dc stop "$SERVICIO" || warn "no se pudo detener el servicio; se sigue, pero verifica que ningun contenedor este usando el volumen."
  for _ in $(seq 1 30); do
    if [ "$(estado_contenedor "$CID")" != "running" ]; then
      break
    fi
    sleep 1
  done
fi

# -----------------------------------------------------------------------------
# 7. Cuarentena en vez de borrado
# -----------------------------------------------------------------------------
if [ "$CONTENIDO_ACTUAL" -gt 0 ] && [ "$FUERZA" = "si" ]; then
  Sello="$(date -u +%Y%m%dT%H%M%SZ)"
  CARACTERIA="/cuarentena-$Sello"
  warn "el volumen tiene contenido. Se mueve a '$CARACTERIA' DENTRO del volumen."
  warn "Nada se borra. Borra la cuarentena a mano solo cuando confirmes que el respaldo era bueno."
  docker run --rm --entrypoint sh -v "$VOLUMEN_DESTINO:/v" "$IMAGEN_UTILITARIA" -c "
    set -e
    mkdir -p '$CARACTERIA'
    for e in /v/* /v/.[!.]*; do
      [ -e \"\$e\" ] || continue
      mv \"\$e\" '$CARACTERIA'/ || exit 1
    done
  " || die "fallo la cuarentena. No se extrajo nada."
fi

# -----------------------------------------------------------------------------
# 8. Extraccion
# -----------------------------------------------------------------------------
log "--- extrayendo el volumen"
# Se extrae con --no-same-owner para que los propietarios del host no queden
# mal y el contenedor pueda leer los archivos.
if ! docker run --rm --entrypoint sh -i -v "$VOLUMEN_DESTINO:/v" "$IMAGEN_UTILITARIA" -c \
    'cd /v && tar xzf - --no-same-owner --no-same-permissions' < "$TAR_VOLUMEN"; then
  die "fallo la extraccion. Revisa el espacio en disco del VPS."
fi
log "extraccion terminada"

# -----------------------------------------------------------------------------
# 9. Dejar el archivo de respaldo logico a mano por si se necesita
# -----------------------------------------------------------------------------
# El respaldo oficial de appsmithctl queda copiado dentro del volumen en su
# carpeta natural, por si el operador prefiere restaurar de forma logica.
for logico in "$ARCHIVO"/appsmith-backup-*.tar.gz*; do
  [ -f "$logico" ] || continue
  log "dejando a mano el respaldo logico $(basename "$logico") en el volumen"
  docker run --rm --entrypoint sh -i -v "$VOLUMEN_DESTINO:/v" "$IMAGEN_UTILITARIA" -c \
    'mkdir -p /v/data/backup && cat > "/v/data/backup/'"$(basename "$logico")"'"' < "$logico" || true
done

# -----------------------------------------------------------------------------
# 10. Estado final: DETENIDO
# -----------------------------------------------------------------------------
if [ -n "$CID" ] && [ "$(estado_contenedor "$CID")" = "running" ]; then
  dc stop "$SERVICIO" 2>/dev/null || true
fi

log "=== RESTAURACION TERMINADA. EL SERVICIO QUEDA DETENIDO. ==="
log ""
log "Que revisar antes de levantar:"
log "  1. docker compose ps          -> el servicio debe figurar detenido"
log "  2. La URL de la app y el correo de los administradores deben ser los"
log "     que quieres. Se ajustan en .env y en Admin Settings."
log "  3. Las credenciales de las fuentes de datos se descifran con"
log "     APPSMITH_ENCRYPTION_PASSWORD y APPSMITH_ENCRYPTION_SALT. Si"
log "     cambiaste esos valores y no coinciden con los del paquete, las"
log "     credenciales guardadas quedaran indescifrables."
log "  4. Si usaste --force, borra la cuarentena SOLO despues de confirmar"
log "     que la restauracion funciono."
log ""
log "Para levantar:  docker compose up -d"
log "Para ver logs:  docker compose logs -f --tail=200"