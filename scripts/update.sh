#!/usr/bin/env bash
# =============================================================================
#  update.sh — Actualiza SRM-3 desde GitHub y reinicia los servicios
# =============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_DIR
# shellcheck disable=SC1091
source "$PROJECT_DIR/config/defaults.conf"
# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/lib_common.sh"

LOG_FILE="$LOG_DIR/update-$(date +%Y%m%d-%H%M%S).log"
log_init
require_root

step "Actualizando SRM-3 en $INSTALL_DIR"
[ -d "$INSTALL_DIR/.git" ] || die "$INSTALL_DIR no es un repositorio git. ¿Está instalado SRM-3?"

run sudo -u "$SRM_USER" git -C "$INSTALL_DIR" pull --ff-only || die "git pull falló."

step "Actualizando dependencias del backend"
run sudo -u "$SRM_USER" "$INSTALL_DIR/backend/venv/bin/pip" install -r "$INSTALL_DIR/backend/requirements.txt" \
  || die "pip install falló."

step "Reconstruyendo el frontend"
run sudo -u "$SRM_USER" bash -lc "cd '$INSTALL_DIR/frontend' && yarn install --frozen-lockfile" \
  || run sudo -u "$SRM_USER" bash -lc "cd '$INSTALL_DIR/frontend' && yarn install" \
  || die "yarn install falló."
run sudo -u "$SRM_USER" bash -lc "cd '$INSTALL_DIR/frontend' && NODE_OPTIONS=--max-old-space-size=1024 GENERATE_SOURCEMAP=false yarn build" \
  || die "yarn build falló."

step "Reiniciando servicios"
run systemctl restart "$SERVICE_NAME" || die "No se pudo reiniciar $SERVICE_NAME."
run systemctl reload nginx || warn "No se pudo recargar Nginx."

ok "SRM-3 actualizado correctamente."
