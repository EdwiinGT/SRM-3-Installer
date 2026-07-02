#!/usr/bin/env bash
# =============================================================================
#  09_frontend.sh — .env del frontend, instalación de dependencias y build
# =============================================================================

write_frontend_env() {
  local env_file="$INSTALL_DIR/frontend/.env"
  printf 'REACT_APP_BACKEND_URL=%s\n' "${PROTOCOL}://${DOMAIN}" > "$env_file"
  chown "$SRM_USER:$SRM_USER" "$env_file"
  log_file_only "frontend/.env → REACT_APP_BACKEND_URL=${PROTOCOL}://${DOMAIN}"
}

build_frontend() {
  local fdir="$INSTALL_DIR/frontend"
  # yarn install (con lockfile si es posible, si no, normal)
  if ! run sudo -u "$SRM_USER" bash -lc "cd '$fdir' && yarn install --frozen-lockfile"; then
    warn "yarn install --frozen-lockfile falló; reintentando sin lockfile congelado."
    run sudo -u "$SRM_USER" bash -lc "cd '$fdir' && yarn install" || die "Fallo en 'yarn install'."
  fi
  # Build de producción (limitamos memoria para VPS pequeños)
  run sudo -u "$SRM_USER" bash -lc "cd '$fdir' && NODE_OPTIONS=--max-old-space-size=1024 GENERATE_SOURCEMAP=false yarn build" \
    || die "Fallo en 'yarn build'."
  [ -f "$fdir/build/index.html" ] || die "El build no generó index.html."
}

setup_frontend() {
  step "Configuración del Frontend (React + build de producción)"
  write_frontend_env
  build_frontend
  ok "Frontend construido en $INSTALL_DIR/frontend/build."
}
