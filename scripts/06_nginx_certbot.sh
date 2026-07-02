#!/usr/bin/env bash
# =============================================================================
#  06_nginx_certbot.sh — Instalación de Nginx y Certbot
# =============================================================================

install_web_stack() {
  step "Instalación de Nginx y Certbot"
  export DEBIAN_FRONTEND=noninteractive
  run apt-get install -y nginx certbot python3-certbot-nginx \
    || die "Fallo al instalar Nginx / Certbot."
  run systemctl enable --now nginx || die "No se pudo habilitar/iniciar Nginx."
  ok "Nginx y Certbot instalados."
}
