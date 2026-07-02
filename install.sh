#!/usr/bin/env bash
# shellcheck disable=SC2034  # flags leídos por scripts cargados vía source
# =============================================================================
#  SRM-3-Installer — Instalador oficial de SRM-3 para Ubuntu Server 24.04 LTS
# -----------------------------------------------------------------------------
#  Instala de forma totalmente automática MongoDB, backend FastAPI, frontend
#  React, Nginx, HTTPS (Let's Encrypt), UFW, Fail2Ban, Logrotate y systemd.
#
#  Uso:
#     sudo bash install.sh                 # instalación interactiva
#     sudo bash install.sh -y              # asume "sí" en las confirmaciones
#     sudo -E bash install.sh --non-interactive   # modo desatendido (vía env)
#
#  Modo desatendido (exporta estas variables antes de ejecutar):
#     SRM_DOMAIN, SRM_ADMIN_EMAIL, SRM_ADMIN_PASSWORD,
#     SRM_CHEF_EMAIL, SRM_CHEF_PASSWORD, SRM_JWT_SECRET (opcional)
# =============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_DIR

# --- Carga de configuración y librerías --------------------------------------
# shellcheck disable=SC1091
source "$PROJECT_DIR/config/defaults.conf"
# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/lib_common.sh"

# Carga de todas las fases (00..99)
for _f in "$PROJECT_DIR"/scripts/[0-9]*.sh; do
  # shellcheck disable=SC1090
  source "$_f"
done

# --- Flags --------------------------------------------------------------------
NONINTERACTIVE=false
ASSUME_YES=false
SKIP_UPDATE=false

usage() {
  cat <<EOF
SRM-3-Installer — instalador oficial de SRM-3

Uso: sudo bash install.sh [opciones]

Opciones:
  -y, --yes                 Asume "sí" en todas las confirmaciones
      --non-interactive     Modo desatendido (requiere variables SRM_* exportadas)
      --skip-system-update  No ejecutar apt upgrade del sistema
  -h, --help                Muestra esta ayuda

Variables para modo desatendido:
  SRM_DOMAIN, SRM_ADMIN_EMAIL, SRM_ADMIN_PASSWORD,
  SRM_CHEF_EMAIL, SRM_CHEF_PASSWORD, SRM_JWT_SECRET (opcional)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes)            ASSUME_YES=true ;;
    --non-interactive)   NONINTERACTIVE=true; ASSUME_YES=true ;;
    --skip-system-update) SKIP_UPDATE=true ;;
    -h|--help)           usage; exit 0 ;;
    *)                   echo "Opción desconocida: $1"; usage; exit 1 ;;
  esac
  shift
done

# --- Banner -------------------------------------------------------------------
banner() {
  printf '%s' "$C_CYAN$C_BOLD"
  cat <<'EOF'

   ███████╗██████╗ ███╗   ███╗       ██████╗
   ██╔════╝██╔══██╗████╗ ████║       ╚════██╗
   ███████╗██████╔╝██╔████╔██║        █████╔╝
   ╚════██║██╔══██╗██║╚██╔╝██║        ╚═══██╗
   ███████║██║  ██║██║ ╚═╝ ██║       ██████╔╝
   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝       ╚═════╝
        Instalador oficial · Ubuntu Server 24.04 LTS
EOF
  printf '%s\n' "$C_RESET"
}

confirm_choices() {
  echo
  echo "  Resumen de la configuración:"
  echo "    Dominio        : $DOMAIN"
  echo "    Protocolo      : $PROTOCOL $( [ "$USE_HTTPS" = true ] && echo '(HTTPS Let'\''s Encrypt)' || echo '(sin HTTPS)')"
  echo "    Administrador  : $ADMIN_EMAIL"
  echo "    Chef           : $CHEF_EMAIL"
  echo "    Instalación en : $INSTALL_DIR (usuario '$SRM_USER')"
  echo "    Base de datos  : $DB_NAME"
  echo "    Repositorio    : $SRM_REPO_URL"
  echo
  confirm "¿Iniciar la instalación con estos datos?" || die "Instalación cancelada por el usuario."
}

# --- Pipeline principal -------------------------------------------------------
main() {
  local start_ts; start_ts=$(date +%s)
  log_init
  banner

  preflight
  collect_input
  dns_check
  confirm_choices

  system_update
  install_base_deps
  install_node
  install_mongodb
  install_web_stack
  clone_srm
  setup_backend
  setup_frontend
  configure_nginx
  setup_ssl
  setup_systemd
  setup_security

  # Validaciones con un reintento global (auto-reparación ya integrada)
  if ! run_validations; then
    warn "Algunas validaciones fallaron. Reintentando tras 5s..."
    sleep 5
    run_validations || true
  fi

  print_summary

  local end_ts; end_ts=$(date +%s)
  info "Tiempo total: $(( (end_ts - start_ts) / 60 ))m $(( (end_ts - start_ts) % 60 ))s"

  if [ "${VALIDATION_FAILS:-0}" -gt 0 ]; then
    err "La instalación finalizó con comprobaciones fallidas. Revisa el resumen y el log:"
    err "  $LOG_FILE"
    exit 1
  fi
  ok "Instalación completada con éxito."
}

main "$@"
