#!/usr/bin/env bash
# =============================================================================
#  12_systemd.sh — Servicio systemd del backend (SIN supervisor)
# =============================================================================

setup_systemd() {
  step "Creación del servicio systemd ($SERVICE_NAME)"

  local unit="/etc/systemd/system/${SERVICE_NAME}.service"

  render_tpl "$PROJECT_DIR/systemd/srm-backend.service.tpl" "$unit" \
    "USER=$SRM_USER" \
    "WORKDIR=$INSTALL_DIR/backend" \
    "ENVFILE=$INSTALL_DIR/backend/.env" \
    "VENV=$INSTALL_DIR/backend/venv" \
    "BACKEND_PORT=$BACKEND_PORT" \
    "WORKERS=$BACKEND_WORKERS"

  run systemctl daemon-reload || die "Fallo en systemctl daemon-reload."
  run systemctl enable --now "$SERVICE_NAME" || die "No se pudo habilitar/iniciar $SERVICE_NAME."
  sleep 3

  if ensure_active "$SERVICE_NAME"; then
    ok "Servicio $SERVICE_NAME activo y habilitado en el arranque."
  else
    warn "El servicio $SERVICE_NAME no está activo; se revisará en las validaciones."
  fi
}
