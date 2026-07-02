#!/usr/bin/env bash
# =============================================================================
#  07_clone_srm.sh — Usuario de sistema + clonado del proyecto SRM-3
#  IMPORTANTE: SRM-3 solo se CLONA. Nunca se modifica su contenido.
# =============================================================================

clone_srm() {
  step "Preparación del usuario de sistema y clonado de SRM-3"

  # --- Usuario de sistema no privilegiado ---
  if id -u "$SRM_USER" >/dev/null 2>&1; then
    info "El usuario '$SRM_USER' ya existe."
  else
    run adduser --disabled-password --gecos "" "$SRM_USER" || die "No se pudo crear el usuario '$SRM_USER'."
  fi

  run mkdir -p "$INSTALL_DIR" || die "No se pudo crear $INSTALL_DIR."
  run chown -R "$SRM_USER:$SRM_USER" "$INSTALL_DIR"

  # --- Clonar o actualizar ---
  if [ -d "$INSTALL_DIR/.git" ]; then
    info "Repositorio ya presente en $INSTALL_DIR. Actualizando (reinstalación)..."
    run sudo -u "$SRM_USER" git -C "$INSTALL_DIR" fetch --all --prune || die "git fetch falló."
    run sudo -u "$SRM_USER" git -C "$INSTALL_DIR" reset --hard "origin/HEAD" 2>/dev/null \
      || run sudo -u "$SRM_USER" git -C "$INSTALL_DIR" pull --ff-only || die "No se pudo actualizar el repositorio."
  else
    if [ -n "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
      die "$INSTALL_DIR no está vacío y no es un repositorio git. Vacíalo o usa scripts/uninstall.sh."
    fi
    if [ -n "$SRM_BRANCH" ]; then
      run sudo -u "$SRM_USER" git clone --branch "$SRM_BRANCH" "$SRM_REPO_URL" "$INSTALL_DIR" \
        || die "Fallo al clonar SRM-3 (rama $SRM_BRANCH)."
    else
      run sudo -u "$SRM_USER" git clone "$SRM_REPO_URL" "$INSTALL_DIR" \
        || die "Fallo al clonar SRM-3 desde $SRM_REPO_URL."
    fi
  fi

  # --- Verificación mínima de estructura esperada ---
  [ -f "$INSTALL_DIR/backend/server.py" ]   || die "Estructura inesperada: falta backend/server.py."
  [ -f "$INSTALL_DIR/backend/requirements.txt" ] || die "Estructura inesperada: falta backend/requirements.txt."
  [ -f "$INSTALL_DIR/frontend/package.json" ] || die "Estructura inesperada: falta frontend/package.json."

  ok "SRM-3 disponible en $INSTALL_DIR."
}
