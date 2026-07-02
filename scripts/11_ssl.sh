#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables compartidas entre scripts (source)
# =============================================================================
#  11_ssl.sh — Emisión del certificado HTTPS con Let's Encrypt (Certbot)
# =============================================================================

setup_ssl() {
  step "Configuración de HTTPS (Let's Encrypt)"

  if [ "$USE_HTTPS" != "true" ]; then
    warn "HTTPS omitido: el DNS no validó o se eligió continuar en HTTP."
    warn "Podrás emitir el certificado más tarde con: certbot --nginx -d $DOMAIN"
    return 0
  fi

  if run certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos \
        -m "$ADMIN_EMAIL" --redirect; then
    run systemctl enable certbot.timer 2>/dev/null || true
    ok "Certificado HTTPS emitido y renovación automática habilitada."
    return 0
  fi

  # --- Auto-reparación: revertir a HTTP y reconstruir el frontend ---
  warn "Certbot falló (revisa el log). Se revierte a HTTP y se reconstruye el frontend."
  PROTOCOL="http"; USE_HTTPS="false"
  write_backend_env
  write_frontend_env
  build_frontend
  warn "Instalación continuará en HTTP. Corrige el DNS y ejecuta 'certbot --nginx -d $DOMAIN' para activar HTTPS."
}
