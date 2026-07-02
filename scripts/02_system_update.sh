#!/usr/bin/env bash
# =============================================================================
#  02_system_update.sh — Actualización del sistema y repositorios
# =============================================================================

system_update() {
  step "Actualización del sistema operativo"
  if [ "${SKIP_UPDATE:-false}" = "true" ]; then
    warn "Actualización del sistema omitida (--skip-system-update)."
    return 0
  fi
  export DEBIAN_FRONTEND=noninteractive
  run apt-get update -y || die "Fallo al actualizar repositorios (apt-get update)."
  run apt-get upgrade -y || die "Fallo al actualizar paquetes (apt-get upgrade)."
  ok "Sistema actualizado."
}
