#!/usr/bin/env bash
# =============================================================================
#  08_backend.sh — Entorno virtual, dependencias y .env del backend
# =============================================================================

write_backend_env() {
  local env_file="$INSTALL_DIR/backend/.env"
  local cors="https://${DOMAIN},http://${DOMAIN}"
  local tpl="$PROJECT_DIR/templates/backend.env.tpl"

  # Se genera por sustitución segura desde plantilla; las contraseñas pueden
  # contener caracteres especiales, por eso escribimos con printf, no con sed.
  {
    printf 'MONGO_URL=%s\n'      "$MONGO_URL"
    printf 'DB_NAME=%s\n'        "$DB_NAME"
    printf 'CORS_ORIGINS=%s\n'   "$cors"
    printf 'JWT_SECRET=%s\n'     "$JWT_SECRET"
    printf 'ADMIN_EMAIL=%s\n'    "$ADMIN_EMAIL"
    printf 'ADMIN_PASSWORD=%s\n' "$ADMIN_PASSWORD"
    printf 'CHEF_EMAIL=%s\n'     "$CHEF_EMAIL"
    printf 'CHEF_PASSWORD=%s\n'  "$CHEF_PASSWORD"
    printf 'APP_NAME=%s\n'       "$APP_NAME"
  } > "$env_file"
  chown "$SRM_USER:$SRM_USER" "$env_file"
  chmod 600 "$env_file"
  log_file_only "backend/.env generado (plantilla ref: $tpl)"
}

setup_backend() {
  step "Configuración del Backend (FastAPI + entorno virtual)"
  local bdir="$INSTALL_DIR/backend"

  run sudo -u "$SRM_USER" python3 -m venv "$bdir/venv" || die "No se pudo crear el entorno virtual."
  run sudo -u "$SRM_USER" "$bdir/venv/bin/pip" install --upgrade pip wheel setuptools \
    || die "Fallo al actualizar pip."
  run sudo -u "$SRM_USER" "$bdir/venv/bin/pip" install -r "$bdir/requirements.txt" \
    || die "Fallo al instalar dependencias del backend."

  write_backend_env
  ok "Backend configurado (venv + dependencias + .env)."
}
