#!/usr/bin/env bash
# =============================================================================
#  99_summary.sh — Resumen final de la instalación
# =============================================================================

_status_icon() {
  case "$1" in
    OK)   printf '%sOK%s'   "$C_GREEN"  "$C_RESET" ;;
    SKIP) printf '%sN/A%s'  "$C_YELLOW" "$C_RESET" ;;
    *)    printf '%sFALLO%s' "$C_RED"   "$C_RESET" ;;
  esac
}

print_summary() {
  local url="${PROTOCOL}://${DOMAIN}"
  echo
  echo "=========================================="
  if [ "${VALIDATION_FAILS:-0}" -eq 0 ]; then
    printf '%s  SRM-3 instalado correctamente.%s\n' "$C_GREEN$C_BOLD" "$C_RESET"
  else
    printf '%s  SRM-3 instalado con %s comprobación(es) fallida(s).%s\n' \
      "$C_YELLOW$C_BOLD" "${VALIDATION_FAILS}" "$C_RESET"
  fi
  echo "=========================================="
  echo
  echo "  Panel:"
  echo "    $url"
  echo
  echo "  Administrador:"
  echo "    $ADMIN_EMAIL"
  echo
  echo "  Chef:"
  echo "    $CHEF_EMAIL"
  echo
  echo "  ------------------------------------------"
  local i pad
  for i in "${!VAL_NAME[@]}"; do
    pad="$(printf '%-14s' "${VAL_NAME[$i]}" | tr ' ' '.')"
    printf '  %s %s\n' "$pad" "$(_status_icon "${VAL_STATUS[$i]}")"
  done
  echo "  ------------------------------------------"
  echo
  echo "  Log de instalación : $LOG_FILE"
  echo "  Directorio         : $INSTALL_DIR"
  echo "  Servicio backend   : systemctl status $SERVICE_NAME"
  echo "  Base de datos      : $DB_NAME (mongodb://localhost:27017)"
  if [ "$USE_HTTPS" != "true" ]; then
    echo
    printf '  %sNOTA:%s HTTPS no está activo. Corrige el DNS y ejecuta:\n' "$C_YELLOW" "$C_RESET"
    echo "        certbot --nginx -d $DOMAIN"
  fi
  echo
  printf '  %sImportante:%s cambia las contraseñas por defecto tras el primer acceso.\n' "$C_BOLD" "$C_RESET"
  echo "=========================================="
}
