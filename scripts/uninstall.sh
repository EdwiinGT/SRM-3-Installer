#!/usr/bin/env bash
# =============================================================================
#  uninstall.sh — Desinstala SRM-3
#  Por defecto conserva la base de datos y el usuario de sistema.
#  Con --purge elimina TODO (BD, usuario, directorio).
# =============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_DIR
# shellcheck disable=SC1091
source "$PROJECT_DIR/config/defaults.conf"
# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/lib_common.sh"

PURGE=false
[ "${1:-}" = "--purge" ] && PURGE=true

LOG_FILE="$LOG_DIR/uninstall-$(date +%Y%m%d-%H%M%S).log"
log_init
require_root

warn "Esto detendrá y eliminará el servicio SRM-3, su sitio Nginx y (opcionalmente) sus datos."
if [ "$PURGE" = true ]; then
  warn "MODO --purge: se eliminarán TAMBIÉN la base de datos '$DB_NAME', el usuario '$SRM_USER' y $INSTALL_DIR."
fi
confirm "¿Continuar con la desinstalación?" || die "Desinstalación cancelada."

step "Deteniendo y deshabilitando el servicio"
systemctl stop "$SERVICE_NAME" 2>/dev/null || true
systemctl disable "$SERVICE_NAME" 2>/dev/null || true
rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
systemctl daemon-reload || true

step "Eliminando la configuración de Nginx"
rm -f /etc/nginx/sites-enabled/srm /etc/nginx/sites-available/srm
nginx -t >>"$LOG_FILE" 2>&1 && systemctl reload nginx || true

step "Eliminando configuraciones auxiliares"
rm -f /etc/fail2ban/jail.d/srm.local /etc/logrotate.d/srm
systemctl restart fail2ban 2>/dev/null || true

if [ "$PURGE" = true ]; then
  step "Eliminando base de datos '$DB_NAME'"
  mongosh --quiet "$MONGO_URL/$DB_NAME" --eval 'db.dropDatabase()' >>"$LOG_FILE" 2>&1 || warn "No se pudo eliminar la BD."

  step "Eliminando directorio $INSTALL_DIR"
  rm -rf "$INSTALL_DIR"

  step "Eliminando usuario de sistema '$SRM_USER'"
  if id -u "$SRM_USER" >/dev/null 2>&1; then
    deluser --remove-home "$SRM_USER" >>"$LOG_FILE" 2>&1 || warn "No se pudo eliminar el usuario '$SRM_USER'."
  fi
  ok "SRM-3 desinstalado por completo (purge)."
else
  ok "SRM-3 desinstalado. Se conservan la base de datos, el usuario y $INSTALL_DIR."
  info "Para eliminar todo: sudo bash scripts/uninstall.sh --purge"
fi
