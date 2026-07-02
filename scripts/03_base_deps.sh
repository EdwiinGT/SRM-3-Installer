#!/usr/bin/env bash
# =============================================================================
#  03_base_deps.sh — Dependencias base del sistema
# =============================================================================

install_base_deps() {
  step "Instalación de dependencias base (Git, Curl, Python, etc.)"
  export DEBIAN_FRONTEND=noninteractive
  run apt-get install -y \
      git curl wget \
      build-essential \
      python3 python3-venv python3-pip python3-dev \
      gnupg ca-certificates apt-transport-https software-properties-common \
      lsb-release ufw dnsutils jq openssl \
    || die "Fallo al instalar las dependencias base."

  info "Versiones instaladas:"
  python3 --version 2>&1 | sed 's/^/    /'
  git --version 2>&1 | sed 's/^/    /'
  ok "Dependencias base instaladas."
}
