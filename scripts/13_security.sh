#!/usr/bin/env bash
# =============================================================================
#  13_security.sh — Firewall UFW, Fail2Ban y Logrotate
# =============================================================================

setup_security() {
  step "Endurecimiento: Firewall (UFW), Fail2Ban y Logrotate"
  export DEBIAN_FRONTEND=noninteractive

  # --- UFW ---
  run ufw allow OpenSSH || warn "No se pudo añadir la regla OpenSSH."
  run ufw allow 'Nginx Full' || warn "No se pudo añadir la regla Nginx Full."
  # Habilitar sin prompt interactivo
  yes | ufw enable >>"$LOG_FILE" 2>&1 || true
  ufw --force enable >>"$LOG_FILE" 2>&1 || true
  ok "Firewall UFW habilitado (22, 80, 443). MongoDB y backend NO se exponen."

  # --- Fail2Ban ---
  run apt-get install -y fail2ban || warn "No se pudo instalar Fail2Ban."
  render_tpl "$PROJECT_DIR/templates/fail2ban-jail.local.tpl" "/etc/fail2ban/jail.d/srm.local" \
    "PLACEHOLDER=1" 2>/dev/null || true
  run systemctl enable --now fail2ban || warn "No se pudo habilitar Fail2Ban."
  ok "Fail2Ban activo (protección de SSH y Nginx)."

  # --- Logrotate ---
  render_tpl "$PROJECT_DIR/templates/logrotate.tpl" "/etc/logrotate.d/srm" \
    "INSTALL_DIR=$INSTALL_DIR"
  ok "Logrotate configurado para los logs de SRM."
}
