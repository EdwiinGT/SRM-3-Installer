#!/usr/bin/env bash
# =============================================================================
#  04_node.sh — Instalación de Node.js (LTS) y Yarn
# =============================================================================

install_node() {
  step "Instalación de Node.js ${NODE_MAJOR} LTS y Yarn"
  export DEBIAN_FRONTEND=noninteractive

  if command_exists node && [ "$(node -v | sed 's/v\([0-9]*\).*/\1/')" -ge "$NODE_MAJOR" ] 2>/dev/null; then
    info "Node.js ya instalado: $(node -v)"
  else
    run bash -c "curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -" \
      || die "Fallo al añadir el repositorio de NodeSource."
    run apt-get install -y nodejs || die "Fallo al instalar Node.js."
  fi

  # Yarn 1.x (clásico) — el proyecto usa yarn, NO npm.
  if command_exists yarn; then
    info "Yarn ya instalado: $(yarn -v)"
  else
    run npm install -g yarn || die "Fallo al instalar Yarn."
  fi

  info "Node: $(node -v)  |  npm: $(npm -v)  |  yarn: $(yarn -v)"
  ok "Node.js y Yarn instalados."
}
