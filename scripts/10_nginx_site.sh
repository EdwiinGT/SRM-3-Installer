#!/usr/bin/env bash
# =============================================================================
#  10_nginx_site.sh — Configuración del sitio Nginx (reverse proxy + SPA)
# =============================================================================

configure_nginx() {
  step "Configuración de Nginx (reverse proxy + estáticos)"

  local site_avail="/etc/nginx/sites-available/srm"
  local site_enabled="/etc/nginx/sites-enabled/srm"
  local build_dir="$INSTALL_DIR/frontend/build"

  render_tpl "$PROJECT_DIR/nginx/srm.conf.tpl" "$site_avail" \
    "DOMAIN=$DOMAIN" \
    "BUILD_DIR=$build_dir" \
    "BACKEND_PORT=$BACKEND_PORT"

  ln -sf "$site_avail" "$site_enabled"
  rm -f /etc/nginx/sites-enabled/default

  run nginx -t || die "La configuración de Nginx no es válida (nginx -t)."
  run systemctl reload nginx || die "No se pudo recargar Nginx."
  ok "Sitio Nginx activo para $DOMAIN."
}
