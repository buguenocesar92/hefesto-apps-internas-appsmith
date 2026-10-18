#!/usr/bin/env bash
# =============================================================================
# Hefesto Studio - Kit Appsmith Community Edition
# Archivo : scripts/lib-comun.sh
# Uso     : NO se ejecuta directo. Se carga desde respaldo.sh y restaurar.sh.
# -----------------------------------------------------------------------------
# Funciones compartidas. Todas escritas en Bash estricto.
# =============================================================================

set -Eeuo pipefail

# --- Rutas -------------------------------------------------------------------
RAIZ_KIT() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }

# --- Salida ------------------------------------------------------------------
# Se escribe a stderr para que stdout se pueda redirigir sin mezclar.
log()  { printf '[%s] %s\n' "$(fecha_iso)" "$*" >&2; }
warn() { printf '[%s] AVISO: %s\n' "$(fecha_iso)" "$*" >&2; }
err()  { printf '[%s] ERROR: %s\n' "$(fecha_iso)" "$*" >&2; }
die()  { err "$*"; exit 1; }

fecha_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# --- Precondiciones ----------------------------------------------------------
requiere_comando() {
  command -v "$1" >/dev/null 2>&1 || die "falta el comando requerido: $1"
}

requiere_docker() {
  requiere_comando docker
  docker info >/dev/null 2>&1 || die "docker no responde. El usuario debe estar en el grupo docker."
}

# --- Compose -----------------------------------------------------------------
# ARMAS_COMPOSE es un array global con los archivos de Compose a usar.
# Compose no acepta el array como string plano, se pasa "${ARMAS_COMPOSE[@]}".
configurar_compose() {
  local archivo="$1"
  [ -f "$archivo" ] || die "no existe el archivo de Compose: $archivo"
  ARMAS_COMPOSE=(-f "$archivo")

  local override="$RAIZ_KIT/config/compose.coolify.yaml"
  if [ "${USAR_OVERRIDE_COOLIFY:-no}" = "si" ] && [ -f "$override" ]; then
    ARMAS_COMPOSE+=(-f "$override")
  fi
}

dc() { docker compose "${ARMAS_COMPOSE[@]}" "$@"; }

# --- Descubrimiento del contenedor y del volumen ------------------------------
# Se descubre en caliente desde el contenedor real en vez de asumir nombres.
# Asi el kit funciona aunque el cliente renombre el servicio en su Coolify.
id_contenedor() {
  docker compose "${ARMAS_COMPOSE[@]}" ps -q appsmith 2>/dev/null | head -n 1 || true
}

requiere_contenedor() {
  local cid
  cid="$(id_contenedor)"
  [ -n "$cid" ] || die "no se encuentra el servicio 'appsmith'. Levanta el kit con 'docker compose up -d' antes de respaldar."
  printf '%s' "$cid"
}

nombre_volumen() {
  local cid="$1"
  docker inspect --format '{{range .Mounts}}{{if eq .Destination "/appsmith-stacks"}}{{.Name}}{{end}}{{end}}' "$cid" 2>/dev/null \
    | head -n 1 || true
}

volumen_existe() {
  docker volume inspect "$1" >/dev/null 2>&1
}

estado_contenedor() {
  docker inspect --format '{{.State.Status}}' "$1" 2>/dev/null || printf 'desconocido'
}

imagen_contenedor() {
  docker inspect --format '{{.Config.Image}}' "$1" 2>/dev/null || printf 'desconocida'
}

# --- Utilidades de archivos ---------------------------------------------------
tamano_bytes() { wc -c < "$1" | tr -d ' '; }

# sha256_file imprime el hash en formato compatible con sha256sum -c.
sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

# human_bytes imprime un tamaño legible.
human_bytes() {
  local b="${1:-0}"
  if [ "$b" -ge 1048576 ]; then printf '%s MiB' "$((b / 1048576))"
  elif [ "$b" -ge 1024 ]; then printf '%s KiB' "$((b / 1024))"
  else printf '%s B' "$b"; fi
}

# --- Contenedor auxiliar -----------------------------------------------------
# Para leer el volumen se usa la MISMA imagen de Appsmith con el entrypoint
# cambiado a sh. Asi no hay que descargar imagenes adicionales en un VPS chico.
# No publica puertos ni usa la red del host.
#
#   usar_volumen <volumen> <ruta_dentro_del_volumen> <comando_sh>
ejecutar_en_volumen() {
  local vol="$1" dir="$2" comando="$3"
  docker run --rm \
    --entrypoint sh \
    -v "$vol:$dir" \
    "$IMAGEN_UTILITARIA" -c "$comando"
}

construir_imagen_utilitaria() {
  # Se usa la imagen del propio servicio para no sumar descargas al VPS.
  IMAGEN_UTILITARIA="$(imagen_contenedor "$(requiere_contenedor)")"
  [ "$IMAGEN_UTILITARIA" != "desconocida" ] || die "no se pudo determinar la imagen del contenedor para usar como utilitaria."
  log "imagen utilitaria: $IMAGEN_UTILITARIA"
}