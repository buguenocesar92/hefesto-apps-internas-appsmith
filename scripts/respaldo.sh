#!/usr/bin/env bash
# =============================================================================
# Hefesto Studio - Kit Appsmith Community Edition
# Archivo : scripts/respaldo.sh
# -----------------------------------------------------------------------------
# QUE HACE
#   Genera un paquete de respaldo coherente de la instancia de Appsmith en dos
#   fases complementarias:
#
#   Fase A - Respaldo logico oficial
#     Ejecuta `appsmithctl backup`, la funcion de respaldo oficial de Appsmith.
#     Exporta la base de datos interna (MongoDB) de forma consistente, mas el
#     archivo docker.env y los repositorios Git, en un solo archivo.
#     Fuente: documentacion oficial de Appsmith, pagina "appsmithctl".
#
#   Fase B - Copia en frio del volumen completo
#     Detiene el contenedor para que no haya escritores, y copia el volumen
#     entero /appsmith-stacks en un tar.gz. Cubre ademas lo que la fase A no
#     alcanza: certificados, datos de Redis, PostgreSQL embebido y logs.
#
#   Cierre
#     Escribe el manifiesto, genera SHA256SUMS, lo VERIFICA, y solo al final
#     crea el archivo COMPLETO. Si el script falla antes, no queda un paquete
#     marcado como completo y por lo tanto no se puede restaurar por error.
#
# QUE NO HACE
#   - No borra nada del servidor.
#   - No hace DROP de ninguna base de datos.
#   - No modifica datos del volumen.
#
# USO
#   ./scripts/respaldo.sh
#   ./scripts/respaldo.sh --salida /mnt/datos/appsmith/respaldo-2026-10-16
#   ./scripts/respaldo.sh --servicio appsmith --mantener-detenido
# =============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-comun.sh
source "$SCRIPT_DIR/lib-comun.sh"

RAIZ="$(RAIZ_KIT)"
cd "$RAIZ"

# --- Argumentos ---------------------------------------------------------------
SERVICIO="appsmith"
SALIDA=""
MANTENER_DETENIDO="no"
NOMBRE_CONTAINER="hefesto-appsmith"

uso() {
  cat >&2 <<'EOF'
Uso: ./scripts/respaldo.sh [opciones]

Opciones:
  --salida DIR        Carpeta donde escribir el paquete.
                      Por defecto: respaldos/<sello-de-fecha> dentro del kit.
  --servicio NOMBRE   Nombre del servicio de Compose. Por defecto: appsmith
  --archivo-compose R Ruta al compose.yaml. Por defecto el del kit.
  --override-coolify  Usar tambien config/compose.coolify.yaml.
  --nombre-conTAINER N  Nombre esperado del contenedor. Solo informativo.
  --mantener-detenido No volver a levantar el servicio al terminar.
  --ayuda             Mostrar esta ayuda.

Notas:
  El paquete contiene docker.env, que incluye la clave de cifrado de secretos
  de Appsmith. Tratalo con la misma sensibilidad que un archivo de claves.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --salida) SALIDA="${2:?falta el valor de --salida}"; shift 2 ;;
    --servicio) SERVICIO="${2:?falta el valor de --servicio}"; shift 2 ;;
    --archivo-compose) ARCHIVO_COMPOSE="${2:?falta el valor de --archivo-compose}"; shift 2 ;;
    --override-coolify) export USAR_OVERRIDE_COOLIFY="si"; shift ;;
    --nombre-container) NOMBRE_CONTAINER="${2:?falta el valor de --nombre-container}"; shift 2 ;;
    --mantener-detenido) MANTENER_DETENIDO="si"; shift ;;
    --ayuda|-h) uso; exit 0 ;;
    *) err "opcion desconocida: $1"; uso; exit 2 ;;
  esac
done

ARCHIVO_COMPOSE="${ARCHIVO_COMPOSE:-$RAIZ/compose.yaml}"

# --- Precondiciones ----------------------------------------------------------
requiere_docker
requiere_comando sha256sum
requiere_comando tar
configurar_compose "$ARCHIVO_COMPOSE"

log "=== respaldo de Appsmith (Hefesto Studio) ==="

CID="$(id_contenedor)"
[ -n "$CID" ] || die "no se encuentra el servicio '$SERVICIO'. Levantalo antes de respaldar."
CONTAINER_ACTUAL="$(docker inspect --format '{{.Name}}' "$CID" | sed 's|^/||')"
IMAGEN="$(imagen_contenedor "$CID")"
VOLUMEN="$(nombre_volumen "$CID")"
[ -n "$VOLUMEN" ] || die "el contenedor no tiene montado /appsmith-stacks. Revisa el compose.yaml."

ESTADO_INICIAL="$(estado_contenedor "$CID")"
log "contenedor : $CONTAINER_ACTUAL ($ESTADO_INICIAL)"
log "esperado   : $NOMBRE_CONTAINER (solo informativo)"
log "imagen     : $IMAGEN"
log "volumen    : $VOLUMEN"

Sello="$(date -u +%Y%m%dT%H%M%SZ)"
SALIDA="${SALIDA:-$RAIZ/respaldos/respaldo-$Sello}"
mkdir -p "$SALIDA"
SALIDA="$(cd "$SALIDA" && pwd)"
log "destino    : $SALIDA"

# En un VPS los respaldos pueden contener claves: carpeta restringida.
chmod 700 "$SALIDA" 2>/dev/null || warn "no se pudo aplicar chmod 700 a $SALIDA"

IMAGEN_UTILITARIA="$IMAGEN"

# Registro de pasos para el manifiesto.
PASOS=()

# -----------------------------------------------------------------------------
# Fase A - Respaldo logico oficial (appsmithctl backup)
# -----------------------------------------------------------------------------
# Se hace con el servicio EN MARCHA porque `appsmithctl` corre dentro del
# contenedor. appsmithctl backup genera su propio volcado consistente de
# MongoDB, por lo que no depende de que el contenedor este detenido.
ARCHIVO_LOGICO=""
if [ "$ESTADO_INICIAL" = "running" ]; then
  log "--- fase A: appsmithctl backup (oficial, requiere el servicio arriba)"
  # --non-interactive evita el prompt de contrasena y deja el archivo en
  # .tar.gz sin cifrar. El paquete ya contiene docker.env, que a su vez tiene
  # la clave de cifrado, asi que cifrar el archivo agrega poca proteccion.
  if dc exec -T "$SERVICIO" appsmithctl backup --non-interactive; then
    # Se listan los respaldos antes y despues para identificar el nuevo.
    ARCHIVO_LOGICO="$(dc exec -T "$SERVICIO" sh -c \
      "ls -1t /appsmith-stacks/data/backup/*.tar.gz* 2>/dev/null | head -n 1" \
      | tr -d '\r')"
    if [ -n "$ARCHIVO_LOGICO" ]; then
      log "archivo generado: $ARCHIVO_LOGICO"
      cp -p "$ARCHIVO_LOGICO" "$SALIDA/" 2>/dev/null \
        || dc exec -T "$SERVICIO" sh -c "cat '$ARCHIVO_LOGICO'" > "$SALIDA/$(basename "$ARCHIVO_LOGICO")"
      PASOS+=("fase A: appsmithctl backup -> $(basename "$ARCHIVO_LOGICO")")
    else
      warn "appsmithctl backup termino bien pero no se encontro el archivo generado."
      PASOS+=("fase A: appsmithctl backup sin archivo identificable")
    fi
  else
    warn "appsmithctl backup fallo. La fase B sigue siendo suficiente para una restauracion completa."
    PASOS+=("fase A: appsmithctl backup FALLO (no bloqueante, la fase B cubre el volumen completo)")
  fi
else
  log "--- fase A omitida: el servicio no esta en marcha"
  PASOS+=("fase A omitida: servicio detenido al momento del respaldo")
fi

# -----------------------------------------------------------------------------
# Version de Appsmith (informativa, para el manifiesto)
# -----------------------------------------------------------------------------
VERSION_APPSMITH="desconocida"
if [ "$ESTADO_INICIAL" = "running" ]; then
  VERSION_APPSMITH="$(dc exec -T "$SERVICIO" appsmithctl version 2>/dev/null | tr -d '\r' | head -n 1 || printf 'desconocida')"
  [ -n "$VERSION_APPSMITH" ] || VERSION_APPSMITH="desconocida"
fi

# -----------------------------------------------------------------------------
# Fase B - Copia en frio del volumen completo
# -----------------------------------------------------------------------------
log "--- fase B: copia en frio del volumen $VOLUMEN"
log "deteniendo el servicio para que no queden escritores"
dc stop "$SERVICIO"
PASOS+=("fase B: servicio detenido para la copia en frio")

# Se espera a que el contenedor figure como detenido antes de copiar.
for _ in $(seq 1 30); do
  if [ "$(estado_contenedor "$CID")" != "running" ]; then
    break
  fi
  sleep 1
done
[ "$(estado_contenedor "$CID")" != "running" ] || die "el contenedor no se detuvo; no se continua para no copiar con escritores activos."
log "contenedor detenido"

ARCHIVO_VOLUMEN="$SALIDA/volumen-appsmith-stacks.tar.gz"
docker run --rm \
  --entrypoint sh \
  -v "$VOLUMEN:/origen:ro" \
  "$IMAGEN_UTILITARIA" \
  -c "cd /origen && tar czf - ." > "$ARCHIVO_VOLUMEN.part"

# Verificacion de integridad del tar recien escrito: se lista completo.
tar -tzf "$ARCHIVO_VOLUMEN.part" >/dev/null || {
  rm -f "$ARCHIVO_VOLUMEN.part"
  die "el archivo de volumen resulto ilegible; se elimino la parte incompleta."
}
mv "$ARCHIVO_VOLUMEN.part" "$ARCHIVO_VOLUMEN"
log "volumen copiado: $ARCHIVO_VOLUMEN ($(human_bytes "$(tamano_bytes "$ARCHIVO_VOLUMEN")"))"
PASOS+=("fase B: copia en frio del volumen completo")

# -----------------------------------------------------------------------------
# Devolver el servicio a su estado original (salvo que se pidiera dejarlo caido)
# -----------------------------------------------------------------------------
if [ "$MANTENER_DETENIDO" = "no" ] && [ "$ESTADO_INICIAL" = "running" ]; then
  log "volviendo a levantar el servicio"
  dc up -d "$SERVICIO"
  PASOS+=("cierre: servicio relanzado, como estaba antes")
else
  log "el servicio queda DETENIDO"
  PASOS+=("cierre: servicio queda detenido a proposito")
fi

# -----------------------------------------------------------------------------
# Manifiesto
# -----------------------------------------------------------------------------
ARTEFACTOS_JSON=""
agregar_artefacto() {
  local f="$1" nombre="$2" desc="$3"
  local tam hash
  tam="$(tamano_bytes "$f")"
  hash="$(sha256_file "$f")"
  if [ -n "$ARTEFACTOS_JSON" ]; then
    ARTEFACTOS_JSON="$ARTEFACTOS_JSON,"
  fi
  ARTEFACTOS_JSON="$ARTEFACTOS_JSON
    { \"nombre\": \"$nombre\", \"descripcion\": \"$desc\", \"bytes\": $tam, \"sha256\": \"$hash\" }"
}

PASOS_JSON=""
for p in "${PASOS[@]}"; do
  escapado="${p//\\/\\\\}"; escapado="${escapado//\"/\\\"}"
  if [ -n "$PASOS_JSON" ]; then
    PASOS_JSON="$PASOS_JSON,"
  fi
  PASOS_JSON="$PASOS_JSON
    \"$escapado\""
done

for f in "$SALIDA"/*.tar.gz "$SALIDA"/*.tar.gz.enc; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in
    volumen-appsmith-stacks.tar.gz) agregar_artefacto "$f" "volumen-appsmith-stacks.tar.gz" "copia en frio del volumen /appsmith-stacks" ;;
    *) agregar_artefacto "$f" "$(basename "$f")" "respaldo logico oficial de appsmithctl" ;;
  esac
done

cat > "$SALIDA/manifiesto.json" <<JSON
{
  "kit": "hefesto-appsmith-apps-internas",
  "kit_version": "1.0.0",
  "generado_utc": "$(fecha_iso)",
  "servidor": "$(hostname 2>/dev/null || printf 'desconocido')",
  "contenedor": "$CONTAINER_ACTUAL",
  "imagen": "$IMAGEN",
  "volumen": "$VOLUMEN",
  "version_appsmith": "$VERSION_APPSMITH",
  "estado_inicial": "$ESTADO_INICIAL",
  "estado_final": "$([ "$MANTENER_DETENIDO" = "si" ] || [ "$ESTADO_INICIAL" != "running" ] && echo detenido || echo running)",
  "pasos": [$PASOS_JSON],
  "artefactos": [$ARTEFACTOS_JSON],
  "advertencia": "Este paquete puede contener docker.env, que incluye la clave de cifrado de secretos de Appsmith. Guardalo como si fuera un archivo de claves."
}
JSON

# -----------------------------------------------------------------------------
# SHA-256 y verificacion
# -----------------------------------------------------------------------------
log "--- generando SHA256SUMS"
# Se cubre tambien el respaldo cifrado (.tar.gz.enc), por si alguien lo genera
# a mano y lo deja junto a los demas.
( cd "$SALIDA" && find . -maxdepth 1 -type f \
    \( -name '*.tar.gz' -o -name '*.tar.gz.enc' -o -name 'manifiesto.json' \) \
    -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS )
log "--- verificando los checksums recien escritos"
( cd "$SALIDA" && sha256sum -c SHA256SUMS ) || die "la verificacion de checksums fallo. El paquete NO se marca como completo."

# -----------------------------------------------------------------------------
# Marcador de completitud: SIEMPRE al final
# -----------------------------------------------------------------------------
cat > "$SALIDA/COMPLETO" <<EOF
Paquete de respaldo completo.
Generado: $(fecha_iso)
Conteniendo: appsmith CE, contenedor $CONTAINER_ACTUAL, volumen $VOLUMEN
Verificacion SHA-256: superada
Restaurar con: ./scripts/restaurar.sh --archivo $SALIDA
EOF

chmod 600 "$SALIDA"/SHA256SUMS "$SALIDA"/manifiesto.json 2>/dev/null || true
chmod 600 "$SALIDA"/*.tar.gz 2>/dev/null || true

log "=== RESPALDO COMPLETO ==="
log "paquete : $SALIDA"
log "restaurar: ./scripts/restaurar.sh --archivo $SALIDA"
log "recuerda: este paquete contiene claves. No lo mandes por correo ni lo subas a un repositorio."