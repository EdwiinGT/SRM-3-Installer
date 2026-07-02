#!/usr/bin/env bash
# =============================================================================
#  status.sh — Estado rápido del sistema SRM-3
# =============================================================================
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_DIR
# shellcheck disable=SC1091
source "$PROJECT_DIR/config/defaults.conf"
# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/lib_common.sh"

_svc() {
  local unit="$1"
  if systemctl is-active --quiet "$unit"; then
    printf '  %-16s %sactivo%s\n' "$unit" "$C_GREEN" "$C_RESET"
  else
    printf '  %-16s %sinactivo%s\n' "$unit" "$C_RED" "$C_RESET"
  fi
}

echo "== Estado de servicios SRM-3 =="
_svc mongod
_svc "$SERVICE_NAME"
_svc nginx
_svc fail2ban

echo
echo "== Firewall (UFW) =="
ufw status 2>/dev/null | sed 's/^/  /' || echo "  UFW no disponible"

echo
echo "== Backend API (local) =="
code="$(curl -s -o /dev/null -w '%{http_code}' -m 10 "http://127.0.0.1:${BACKEND_PORT}/api" 2>/dev/null || echo 000)"
echo "  http://127.0.0.1:${BACKEND_PORT}/api -> HTTP $code"

echo
echo "== Base de datos =="
if mongosh --quiet "$MONGO_URL/$DB_NAME" --eval 'db.getName()' >/dev/null 2>&1; then
  echo "  $DB_NAME -> accesible"
else
  echo "  $DB_NAME -> sin conexión"
fi

echo
echo "== Últimas líneas del backend (journalctl) =="
journalctl -u "$SERVICE_NAME" -n 10 --no-pager 2>/dev/null | sed 's/^/  /' || echo "  (sin acceso a journalctl)"
