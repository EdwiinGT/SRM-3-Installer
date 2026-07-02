#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables compartidas entre scripts (source)
# =============================================================================
#  14_validate.sh — Validaciones finales end-to-end (con auto-reparación)
# =============================================================================

run_validations() {
  step "Validaciones finales del sistema"
  VAL_NAME=(); VAL_STATUS=(); VAL_DETAIL=()

  local local_base="http://127.0.0.1:${BACKEND_PORT}"
  local pub_base="${PROTOCOL}://${DOMAIN}"

  # 1) MongoDB ----------------------------------------------------------------
  if ensure_active mongod && mongosh --quiet --eval 'db.runCommand({ping:1}).ok' >/dev/null 2>&1; then
    val_add "MongoDB" "OK" "servicio activo + ping"
  else
    val_add "MongoDB" "FAIL" "mongod no responde"
  fi

  # 2) systemd (backend habilitado) -------------------------------------------
  if systemctl is-enabled --quiet "$SERVICE_NAME"; then
    val_add "systemd" "OK" "$SERVICE_NAME habilitado"
  else
    val_add "systemd" "FAIL" "$SERVICE_NAME no habilitado"
  fi

  # 3) Backend (servicio + API local) -----------------------------------------
  if ensure_active "$SERVICE_NAME"; then
    if curl -fsS -m 15 "$local_base/api/auth/login" -X POST \
         -H 'Content-Type: application/json' -d '{}' >/dev/null 2>&1 \
       || curl -fsS -m 15 -o /dev/null "$local_base/api" 2>/dev/null \
       || api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "$local_base"; then
      val_add "Backend" "OK" "API responde en :$BACKEND_PORT"
    else
      val_add "Backend" "FAIL" "API no responde en :$BACKEND_PORT"
    fi
  else
    val_add "Backend" "FAIL" "$SERVICE_NAME inactivo"
  fi

  # 4) Frontend (build presente) ----------------------------------------------
  if [ -f "$INSTALL_DIR/frontend/build/index.html" ]; then
    val_add "Frontend" "OK" "build presente"
  else
    val_add "Frontend" "FAIL" "falta build/index.html"
  fi

  # 5) Nginx ------------------------------------------------------------------
  if ensure_active nginx && nginx -t >>"$LOG_FILE" 2>&1; then
    val_add "Nginx" "OK" "activo + config válida"
  else
    val_add "Nginx" "FAIL" "inactivo o config inválida"
  fi

  # 6) Conexión a Base de Datos (desde la app) --------------------------------
  if mongosh --quiet "${MONGO_URL}/${DB_NAME}" --eval 'db.getName()' >/dev/null 2>&1; then
    val_add "Conexión BD" "OK" "$DB_NAME accesible"
  else
    val_add "Conexión BD" "FAIL" "no se pudo acceder a $DB_NAME"
  fi

  # 7) Login Admin (API local) ------------------------------------------------
  if api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "$local_base"; then
    val_add "Login Admin" "OK" "$ADMIN_EMAIL"
  else
    val_add "Login Admin" "FAIL" "token no recibido"
  fi

  # 8) Login Chef (API local) -------------------------------------------------
  if api_login "$CHEF_EMAIL" "$CHEF_PASSWORD" "$local_base"; then
    val_add "Login Chef" "OK" "$CHEF_EMAIL"
  else
    val_add "Login Chef" "FAIL" "token no recibido"
  fi

  # 9) Comunicación Frontend <-> Backend (a través del dominio/Nginx) ---------
  if api_login "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "$pub_base"; then
    val_add "Front<->Back" "OK" "$pub_base/api"
  else
    val_add "Front<->Back" "FAIL" "no hay respuesta vía $pub_base/api"
  fi

  # 10) HTTPS -----------------------------------------------------------------
  if [ "$USE_HTTPS" = "true" ]; then
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' -m 20 "https://${DOMAIN}/" 2>/dev/null || echo 000)"
    if [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ] && [[ "$code" =~ ^(200|301|302|304)$ ]]; then
      val_add "HTTPS" "OK" "certificado activo (HTTP $code)"
    else
      val_add "HTTPS" "FAIL" "certificado/respuesta inválida (HTTP $code)"
    fi
  else
    val_add "HTTPS" "SKIP" "no configurado (HTTP)"
  fi

  # 11) Firewall --------------------------------------------------------------
  if ufw status 2>/dev/null | grep -qi "Status: active"; then
    val_add "Firewall" "OK" "UFW activo"
  else
    val_add "Firewall" "FAIL" "UFW inactivo"
  fi

  # --- Balance ---------------------------------------------------------------
  local i fails=0
  for i in "${!VAL_NAME[@]}"; do
    case "${VAL_STATUS[$i]}" in
      OK)   ok   "${VAL_NAME[$i]} — ${VAL_DETAIL[$i]}" ;;
      SKIP) warn "${VAL_NAME[$i]} — ${VAL_DETAIL[$i]} (omitido)" ;;
      *)    err  "${VAL_NAME[$i]} — ${VAL_DETAIL[$i]}"; fails=$((fails+1)) ;;
    esac
  done

  VALIDATION_FAILS=$fails
  if [ "$fails" -gt 0 ]; then
    return 1
  fi
  return 0
}
