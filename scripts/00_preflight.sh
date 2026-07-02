#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables compartidas entre scripts (source)
# =============================================================================
#  00_preflight.sh — Comprobaciones previas a la instalación
# =============================================================================

preflight() {
  require_root
  step "Comprobaciones previas (preflight)"

  export DEBIAN_FRONTEND=noninteractive

  # --- Detección del sistema operativo ---
  local os_id="" os_ver="" os_codename="" os_pretty=""
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    os_id="${ID:-}"; os_ver="${VERSION_ID:-}"
    os_codename="${VERSION_CODENAME:-}"; os_pretty="${PRETTY_NAME:-}"
  fi
  info "Sistema detectado: ${os_pretty:-desconocido}"

  if [ "$os_id" != "ubuntu" ]; then
    warn "El SO no es Ubuntu. Este instalador está diseñado para Ubuntu Server 24.04 LTS."
    confirm "¿Deseas continuar de todas formas?" || die "Instalación cancelada por el usuario."
  elif [ "$os_ver" != "$UBUNTU_VERSION_EXPECTED" ]; then
    warn "Ubuntu $os_ver detectado. El instalador está probado en $UBUNTU_VERSION_EXPECTED ($UBUNTU_CODENAME_EXPECTED)."
    confirm "¿Continuar igualmente?" || die "Instalación cancelada por el usuario."
  fi

  # Codename efectivo para el repositorio de MongoDB
  UBUNTU_CODENAME="${os_codename:-$UBUNTU_CODENAME_EXPECTED}"

  # --- Arquitectura ---
  local arch; arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
  info "Arquitectura: $arch"
  case "$arch" in amd64|arm64) ;; *) warn "Arquitectura '$arch' no verificada oficialmente." ;; esac

  # --- Utilidades mínimas para las comprobaciones ---
  run apt-get update -qq || die "No se pudo actualizar el índice de apt. Verifica la conexión a Internet."
  run apt-get install -y -qq curl dnsutils ca-certificates jq openssl || die "No se pudieron instalar utilidades base."

  # --- Conectividad ---
  if ! curl -fsS -m 15 https://github.com >/dev/null 2>&1; then
    warn "No se pudo alcanzar github.com. La clonación del repositorio podría fallar."
  fi

  ok "Preflight completado."
}
