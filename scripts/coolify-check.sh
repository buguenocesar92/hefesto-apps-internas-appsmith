#!/usr/bin/env bash
# =============================================================================
# Hefesto Studio - pre-check para Coolify (kit Appsmith CE)
# Archivo    : scripts/coolify-check.sh
# Que hace   : Verifica que los compose files del kit cumplen el contrato que
#              necesita Coolify para servirlos detras de Traefik sin saltos
#              de seguridad ni toma sobre el host.
#
# Contrato (resumen; la fuente es .superpowers/minimax/coolify/plan.md):
#   1. Servicios SIN profiles: nada que salte a Traefik ni de poder sobre el
#      host. Prohibido: ports, container_name, privileged, cap_add, devices,
#      network_mode: host, pid: host, ipc: host, security_opt unconfined,
#      binds fuera del repo y docker.sock.
#   2. Sin `name:` fijo a nivel raiz del compose; redes y volumenes sin
#      `name:` fijo.
#   3. Apps `bd: supabase-pg`: DB_NAME y DB_SSLMODE parametrizables. (No
#      aplica a este kit: Appsmith usa Mongo embebido.)
#
# Salida: exit 0 si pasa todos los compose; exit 1 con motivos si alguno falla.
#         Cada motivo se imprime como  "<servicio>: <motivo>"  para que sea
#         facil de grep.
# =============================================================================
set -euo pipefail

readonly R=$'\033[31m'
readonly G=$'\033[32m'
readonly Y=$'\033[33m'
readonly N=$'\033[0m'

pass() { printf '%sOK   %s %s\n' "$G" "$N" "$*"; }
fail() { printf '%sFAIL %s %s\n' "$R" "$N" "$*"; FAILED=1; }
info() { printf '%sINFO %s %s\n' "$Y" "$N" "$*"; }

command -v docker >/dev/null 2>&1 || { echo "docker no esta instalado" >&2; exit 2; }
command -v jq     >/dev/null 2>&1 || { echo "jq no esta instalado" >&2; exit 2; }
docker compose version >/dev/null 2>&1 || { echo "docker compose v2 no disponible" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly REPO_ROOT

cd "$REPO_ROOT"

# --- Composites a chequear -----------------------------------------------
# formato: "ruta_relativa_al_repo|app_slug"
# Appsmith CE: una sola app en la raiz. Si en el futuro se agrega otra,
# sumarla aca y, si usa Postgres compartido, anotarla en SUPABASE_PG.
readonly COMPOSES=(
  "compose.yaml|appsmith"
)

# Composites que hablan con el Postgres compartido. En este kit: ninguno.
readonly SUPABASE_PG=()

# Claves prohibidas en servicios sin profiles (contrato 1).
# Declarada UNA sola vez fuera del for: con dos entradas en COMPOSES la
# segunda vuelta abortaba por set -e con "variable de solo lectura".
readonly PROHIBIDAS=(
  "ports"
  "container_name"
  "privileged"
  "cap_add"
  "devices"
  "network_mode"
  "pid"
  "ipc"
  "security_opt"
)

# True si la ruta absoluta del compose coincide con uno marcado como pg.
es_pg() {
  local c="$1"
  for p in "${SUPABASE_PG[@]:-}"; do
    [ "$p" = "$c" ] && return 0
  done
  return 1
}

# Extrae todas las variables ${VAR} (con o sin :- :-? :-:) del compose.
extraer_vars() {
  local compose="$1"
  # Solo nombres en MAYUSCULAS; los identificadores internos suelen ser
  # MAYUSCULAS_CON_GUIONES; las variables de compose del kit respetan esa
  # convencion.
  grep -oE '\$\{[A-Z_][A-Z0-9_]*(:[-+?]?[^}]*)?\}' "$compose" \
    | sed -E 's/^\$\{([A-Z_][A-Z0-9_]*).*/\1/' \
    | sort -u
}

# Imprime un valor ficticio no secreto para una variable dada.
valor_para_var() {
  local v="$1"
  case "$v" in
    # URLs, dominios, correos -> TLD .invalid (RFC 2606), no resuelve a nada.
    # Orden: de mas especifico a mas amplio (shellcheck SC2221).
    *SIGNUP_ALLOWED*|*URL*|*DOMAIN*|*EMAIL*|*ALLOWED*|*HOST*)
      printf 'https://ejemplo.invalid\n'
      ;;
    *)
      # x + 16 chars hex -> no es un secreto (puro relleno).
      printf 'x1234567890abcdef\n'
      ;;
  esac
}

# Globales para acumular fallos entre checkeos (los subshells no contaminan).
FAILED=0
TMP_ENV=""

# shellcheck disable=SC2317  # cleanup corre solo desde el trap; shellcheck no lo ve.
cleanup() {
  # El trap reemplaza el exit code del script: si cleanup termina con un
  # comando que falla ([ -n "" ] cuando TMP_ENV ya esta vacio), el script
  # aparece como rojo aunque hubiera impreso "OK". Forzamos retorno 0
  # explicitamente.
  rm -f "${TMP_ENV:-}" 2>/dev/null || true
  return 0
}
trap cleanup EXIT

# --- Loop principal ------------------------------------------------------
total=${#COMPOSES[@]}
ok=0

for entry in "${COMPOSES[@]}"; do
  IFS='|' read -r compose_rel app_slug <<<"$entry"
  compose_abs="$REPO_ROOT/$compose_rel"

  info "comprobando $app_slug -> $compose_rel"

  if [ ! -f "$compose_abs" ]; then
    fail "$app_slug: compose no existe ($compose_rel)"
    continue
  fi

  # .env temporal -------------------------------------------------------
  TMP_ENV="$(mktemp -t coolify-env.XXXXXX)"
  if es_pg "$compose_abs"; then
    printf 'DB_SSLMODE=disable\n' >> "$TMP_ENV"
    printf 'DB_NAME=mvp_prueba\n' >> "$TMP_ENV"
  fi
  while IFS= read -r v; do
    [ -z "$v" ] && continue
    if ! grep -qE "^${v}=" "$TMP_ENV"; then
      printf '%s=%s\n' "$v" "$(valor_para_var "$v")" >> "$TMP_ENV"
    fi
  done < <(extraer_vars "$compose_abs")

  # Render --------------------------------------------------------------
  # Pasada A: nombre de proyecto neutro para detectar si `name:` esta
  # DECLARADO en el YAML (los nombres derivados del project-name cambian
  # al cambiar --project-name; los declarados no).
  if ! render_a="$(docker compose \
        --project-directory "$REPO_ROOT" \
        --project-name="probe-aaaa" \
        -f "$compose_abs" \
        --env-file "$TMP_ENV" \
        config --format json 2>/dev/null)"; then
    fail "$app_slug: docker compose config fallo (revisa que las variables obligatorias del compose tengan valor)"
    rm -f "$TMP_ENV"
    TMP_ENV=""
    continue
  fi
  # Pasada B: mismo compose con otro project-name, para comparar.
  if ! render_b="$(docker compose \
        --project-directory "$REPO_ROOT" \
        --project-name="probe-bbbb" \
        -f "$compose_abs" \
        --env-file "$TMP_ENV" \
        config --format json 2>/dev/null)"; then
    fail "$app_slug: docker compose config fallo en la segunda pasada (revisa el archivo compose)"
    rm -f "$TMP_ENV"
    TMP_ENV=""
    continue
  fi
  # Pasada C: SIN --project-name y con COMPOSE_PROJECT_NAME vacio, para
  # obtener el nombre REAL que Coolify sacaria. Si el YAML tiene `name:`
  # raiz declarado, ese nombre se usa y reemplaza al derivado del directorio.
  # Por eso comparar con basename(REPO_ROOT) es lo que detecta la regresion.
  if ! render_c="$(env -u COMPOSE_PROJECT_NAME docker compose \
        --project-directory "$REPO_ROOT" \
        -f "$compose_abs" \
        --env-file "$TMP_ENV" \
        config --format json 2>/dev/null)"; then
    fail "$app_slug: docker compose config fallo en la pasada sin project-name (revisa el archivo compose)"
    rm -f "$TMP_ENV"
    TMP_ENV=""
    continue
  fi
  render_json="$render_a"
  rm -f "$TMP_ENV"
  TMP_ENV=""

  # --- Contrato 1: poderes prohibidos en servicios sin profiles --------
  info "  [1/2] chequeando poderes prohibidos en servicios sin profiles..."

  # Servicios sin profiles (los que Coolify levanta por defecto).
  servicios="$(echo "$render_json" \
    | jq -r '.services | to_entries[] | select((.value.profiles // []) | length == 0) | .key')"

  fallo_p1=0
  for s in $servicios; do
    for k in "${PROHIBIDAS[@]}"; do
      if echo "$render_json" \
          | jq -e --arg s "$s" --arg k "$k" \
            'has("services") and (.services[$s] | has($k))' \
          >/dev/null; then
        val="$(echo "$render_json" \
          | jq -c --arg s "$s" --arg k "$k" '.services[$s][$k]')"
        fail "$app_slug.$s: clave prohibida '$k' presente: $val"
        fallo_p1=1
      fi
    done

    # Volumes con source absoluta fuera del repo o docker.sock.
    bind_riesgosos="$(echo "$render_json" \
      | jq -r --arg s "$s" '.services[$s].volumes // [] | .[]? | select(.source != null) | .source')"
    while IFS= read -r src; do
      [ -z "$src" ] && continue
      case "$src" in
        *docker.sock*)
          fail "$app_slug.$s: bind prohibido (docker.sock): $src"
          fallo_p1=1
          ;;
        /*)
          # path absoluto: solo permitido si cae dentro del repo.
          case "$src" in
            "$REPO_ROOT"/*|"$REPO_ROOT")
              ;;
            *)
              fail "$app_slug.$s: bind fuera del repo: $src"
              fallo_p1=1
              ;;
          esac
          ;;
      esac
    done <<<"$bind_riesgosos"
  done

  if [ "$fallo_p1" -eq 0 ]; then
    pass "$app_slug: sin poderes prohibidos"
  fi

  # --- Contrato 2: sin name: fijo (raiz, redes y volumenes) ------------
  # La raiz se valida contra lo que Coolify sacaria realmente (pasada C,
  # sin --project-name): el nombre que devuelve debe coincidir con
  # basename(REPO_ROOT) saneado a [a-z0-9_-]. Si NO coincide, el YAML tiene
  # un `name:` raiz HARDCODEADO y Coolify no va a poder nombrarlo.
  # Redes y volumenes: A vs B (los nombres derivados cambian con
  # --project-name; los declarados NO).
  info "  [2/2] chequeando nombres sin forzar..."

  # Capturamos el estado de FAILED antes de este contrato para saber si
  # esta vuelta introdujo fallos nuevos (el contador ok ya no depende
  # solo de fallo_p1).
  antes_p2=$FAILED

  # -- raiz --
  name_c="$(echo "$render_c" | jq -r '.name // empty')"
  expected_basename="$(basename "$REPO_ROOT" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_-]/_/g')"
  if [ -z "$name_c" ]; then
    fail "$app_slug: el render sin project-name no devolvio .name (revisa el compose)"
  elif [ "$name_c" = "$expected_basename" ]; then
    pass "$app_slug: name raiz derivado del directorio (no declarado en YAML)"
  else
    fail "$app_slug: compose tiene 'name:' raiz HARDCODEADO: '$name_c' (esperado derivado del directorio '$expected_basename'; Coolify debe poder nombrarlo)"
  fi

  # -- redes --
  redes_con_name_fijo=""
  for net in $(echo "$render_a" | jq -r '(.networks // {}) | keys[]'); do
    a="$(echo "$render_a" | jq -r --arg k "$net" '.networks[$k].name // empty')"
    b="$(echo "$render_b" | jq -r --arg k "$net" '.networks[$k].name // empty')"
    if [ -n "$a" ] && [ "$a" = "$b" ]; then
      redes_con_name_fijo="${redes_con_name_fijo}${net}=${a} "
    fi
  done
  if [ -n "$redes_con_name_fijo" ]; then
    fail "$app_slug: redes con 'name:' HARDCODEADO: $redes_con_name_fijo"
  else
    pass "$app_slug: redes sin name declarado en YAML"
  fi

  # -- volumenes --
  volumenes_con_name_fijo=""
  for vol in $(echo "$render_a" | jq -r '(.volumes // {}) | keys[]'); do
    a="$(echo "$render_a" | jq -r --arg k "$vol" '.volumes[$k].name // empty')"
    b="$(echo "$render_b" | jq -r --arg k "$vol" '.volumes[$k].name // empty')"
    if [ -n "$a" ] && [ "$a" = "$b" ]; then
      volumenes_con_name_fijo="${volumenes_con_name_fijo}${vol}=${a} "
    fi
  done
  if [ -n "$volumenes_con_name_fijo" ]; then
    fail "$app_slug: volumenes con 'name:' HARDCODEADO: $volumenes_con_name_fijo"
  else
    pass "$app_slug: volumenes sin name declarado en YAML"
  fi

  # --- Contrato 3/4: supabase-pg ---------------------------------------
  if es_pg "$compose_abs"; then
    info "  [3/3] chequeando DB_NAME/DB_SSLMODE (kit supabase-pg)..."
    if ! echo "$render_json" | grep -q 'mvp_prueba'; then
      fail "$app_slug: DB_NAME=mvp_prueba no aparece en el render"
    fi
    if ! echo "$render_json" | grep -q 'disable'; then
      fail "$app_slug: DB_SSLMODE=disable no aparece en el render"
    fi
  fi

  # Contamos como OK solo si en esta iteracion NO hubo ningun fail con
  # $app_slug. Antes solo miraba fallo_p1, lo que ocultaba fallos del 2
  # (redes/volumenes/raiz). Comparamos FAILED antes y despues del Contrato 2.
  if [ "$antes_p2" = "$FAILED" ]; then
    ok=$((ok + 1))
  fi
done

echo
if [ "$FAILED" -eq 0 ]; then
  pass "Todos los compose cumplen el contrato ($ok/$total)"
  exit 0
else
  fail "uno o mas compose NO cumplen el contrato"
  exit 1
fi
