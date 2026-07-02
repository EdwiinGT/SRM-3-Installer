#!/usr/bin/env bash
# =============================================================================
#  05_mongodb.sh — Instalación y aseguramiento de MongoDB
# =============================================================================

install_mongodb() {
  step "Instalación de MongoDB ${MONGO_VERSION}"
  export DEBIAN_FRONTEND=noninteractive

  local keyring="/usr/share/keyrings/mongodb-server-${MONGO_VERSION}.gpg"
  local listfile="/etc/apt/sources.list.d/mongodb-org-${MONGO_VERSION}.list"

  if command_exists mongod; then
    info "MongoDB ya está instalado: $(mongod --version | head -n1)"
  else
    run bash -c "curl -fsSL https://www.mongodb.org/static/pgp/server-${MONGO_VERSION}.asc | gpg -o '${keyring}' --dearmor --yes" \
      || die "Fallo al importar la clave GPG de MongoDB."

    echo "deb [ arch=amd64,arm64 signed-by=${keyring} ] https://repo.mongodb.org/apt/ubuntu ${UBUNTU_CODENAME}/mongodb-org/${MONGO_VERSION} multiverse" \
      > "$listfile"
    log_file_only "Repo MongoDB → $(cat "$listfile")"

    run apt-get update -y || die "Fallo al actualizar el índice tras añadir el repo de MongoDB."
    run apt-get install -y mongodb-org || die "Fallo al instalar mongodb-org."
  fi

  # Asegurar bindIp = 127.0.0.1 (solo loopback) según arquitectura oficial
  if [ -f /etc/mongod.conf ]; then
    if grep -qE '^\s*bindIp:' /etc/mongod.conf; then
      sed -i -E 's/^(\s*bindIp:).*/\1 127.0.0.1/' /etc/mongod.conf
    fi
    log_file_only "mongod.conf net: $(grep -A2 '^net:' /etc/mongod.conf 2>/dev/null)"
  fi

  run systemctl enable --now mongod || die "No se pudo habilitar/iniciar el servicio mongod."
  sleep 3

  if mongosh --quiet --eval 'db.runCommand({ping:1}).ok' >/dev/null 2>&1; then
    ok "MongoDB activo y respondiendo (ping OK)."
  else
    warn "MongoDB no respondió al ping inicial; se reintentará en las validaciones finales."
  fi
}
