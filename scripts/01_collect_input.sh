#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables compartidas entre scripts (source)
# =============================================================================
#  01_collect_input.sh — Recolección de datos y validación DNS
#  ÚNICOS datos solicitados: Dominio, Admin (email+pass), Chef (email+pass),
#  JWT_SECRET (autogenerado si queda vacío).
# =============================================================================

collect_input() {
  step "Configuración inicial (solo se solicitan los datos imprescindibles)"

  # Precarga desde variables de entorno (permite modo desatendido)
  DOMAIN="${DOMAIN:-${SRM_DOMAIN:-}}"
  ADMIN_EMAIL="${ADMIN_EMAIL:-${SRM_ADMIN_EMAIL:-}}"
  ADMIN_PASSWORD="${ADMIN_PASSWORD:-${SRM_ADMIN_PASSWORD:-}}"
  CHEF_EMAIL="${CHEF_EMAIL:-${SRM_CHEF_EMAIL:-}}"
  CHEF_PASSWORD="${CHEF_PASSWORD:-${SRM_CHEF_PASSWORD:-}}"
  JWT_SECRET="${JWT_SECRET:-${SRM_JWT_SECRET:-}}"

  # --- Dominio ---
  while true; do
    ask DOMAIN "Dominio del panel (ej: srm.mirestaurante.com)"
    DOMAIN="${DOMAIN,,}"; DOMAIN="${DOMAIN#http://}"; DOMAIN="${DOMAIN#https://}"; DOMAIN="${DOMAIN%%/*}"
    if valid_domain "$DOMAIN"; then break; fi
    warn "Dominio inválido. Ejemplo válido: srm.mirestaurante.com"
    [ "${NONINTERACTIVE:-false}" = "true" ] && die "Dominio inválido en modo desatendido."
  done

  # --- Administrador ---
  while true; do
    ask ADMIN_EMAIL "Correo del Administrador" "admin@srm.com"
    ADMIN_EMAIL="${ADMIN_EMAIL,,}"
    valid_email "$ADMIN_EMAIL" && break
    warn "Correo inválido."
    [ "${NONINTERACTIVE:-false}" = "true" ] && die "Correo de admin inválido en modo desatendido."
  done
  if [ -z "$ADMIN_PASSWORD" ]; then ask_secret ADMIN_PASSWORD "Contraseña del Administrador"; fi
  [ -n "$ADMIN_PASSWORD" ] || die "La contraseña del Administrador es obligatoria."

  # --- Chef ---
  while true; do
    ask CHEF_EMAIL "Correo del Chef" "chef@srm.com"
    CHEF_EMAIL="${CHEF_EMAIL,,}"
    valid_email "$CHEF_EMAIL" && break
    warn "Correo inválido."
    [ "${NONINTERACTIVE:-false}" = "true" ] && die "Correo de chef inválido en modo desatendido."
  done
  if [ -z "$CHEF_PASSWORD" ]; then ask_secret CHEF_PASSWORD "Contraseña del Chef"; fi
  [ -n "$CHEF_PASSWORD" ] || die "La contraseña del Chef es obligatoria."

  # --- JWT_SECRET ---
  if [ "${NONINTERACTIVE:-false}" != "true" ] && [ -z "$JWT_SECRET" ]; then
    read -r -p "JWT_SECRET (deja vacío para generarlo automáticamente): " JWT_SECRET || true
  fi
  if [ -z "$JWT_SECRET" ]; then
    JWT_SECRET="$(gen_secret)"
    info "JWT_SECRET generado automáticamente (criptográficamente seguro)."
  fi

  # Protocolo por defecto (se ajusta en dns_check)
  PROTOCOL="https"
  USE_HTTPS="true"
}

# --- Validación de DNS: ¿el dominio apunta a la IP de este VPS? ---------------
dns_check() {
  step "Validación de DNS para HTTPS"

  local server_ip domain_ip
  server_ip="$(curl -fsS -m 15 https://api.ipify.org 2>/dev/null || true)"
  [ -z "$server_ip" ] && server_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  domain_ip="$(dig +short A "$DOMAIN" 2>/dev/null | tail -n1)"
  [ -z "$domain_ip" ] && domain_ip="$(getent hosts "$DOMAIN" 2>/dev/null | awk '{print $1}' | tail -n1)"

  info "IP pública del VPS : ${server_ip:-desconocida}"
  info "IP del dominio     : ${domain_ip:-sin resolución}"

  if [ -n "$server_ip" ] && [ -n "$domain_ip" ] && [ "$server_ip" = "$domain_ip" ]; then
    USE_HTTPS="true"; PROTOCOL="https"
    ok "El dominio '$DOMAIN' apunta correctamente a este servidor. Se emitirá HTTPS."
    return 0
  fi

  # --- Validación fallida ---
  warn "El dominio '$DOMAIN' NO apunta a la IP de este VPS (${server_ip:-?})."
  if [ -z "$domain_ip" ]; then
    warn "Motivo: el dominio no resuelve a ninguna IP (registro A inexistente o DNS no propagado)."
  else
    warn "Motivo: el registro A apunta a '$domain_ip' en lugar de '${server_ip:-?}'."
  fi

  if [ "${SRM_REQUIRE_HTTPS}" = "true" ]; then
    die "SRM_REQUIRE_HTTPS=true y la validación DNS falló. Instalación cancelada."
  fi

  if [ "${NONINTERACTIVE:-false}" = "true" ]; then
    warn "Modo desatendido: se continúa SIN HTTPS (solo HTTP)."
    USE_HTTPS="false"; PROTOCOL="http"; return 0
  fi

  echo
  echo "  ¿Qué deseas hacer?"
  echo "    1) Continuar SIN HTTPS (el sitio quedará en HTTP; puedes emitir el certificado luego)"
  echo "    2) Cancelar la instalación (corrige el DNS y vuelve a ejecutar)"
  local choice
  read -r -p "  Selecciona [1/2]: " choice || true
  case "$choice" in
    1) USE_HTTPS="false"; PROTOCOL="http"; warn "Continuando sin HTTPS." ;;
    *) die "Instalación cancelada. Apunta el registro A de '$DOMAIN' a ${server_ip:-la IP del VPS} y reintenta." ;;
  esac
}
