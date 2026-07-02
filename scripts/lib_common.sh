#!/usr/bin/env bash
# =============================================================================
#  lib_common.sh — Utilidades compartidas por todos los scripts del instalador
#  (logging, colores, ejecución segura, prompts, validaciones de formato)
# =============================================================================

# ---- Colores (solo si la salida es una terminal) ----------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'; C_GRAY=$'\033[90m'
else
  C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""
  C_BLUE=""; C_CYAN=""; C_GRAY=""
fi

# ---- Log file ----------------------------------------------------------------
LOG_DIR="${LOG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/logs}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log}"

log_init() {
  mkdir -p "$LOG_DIR"
  : > "$LOG_FILE"
  log_file_only "==== SRM-3-Installer — inicio $(date -Iseconds) ===="
}

_ts() { date '+%Y-%m-%d %H:%M:%S'; }
log_file_only() { printf '[%s] %s\n' "$(_ts)" "$*" >> "$LOG_FILE" 2>/dev/null || true; }

info()  { printf '%s[·]%s %s\n' "$C_CYAN"  "$C_RESET" "$*"; log_file_only "INFO  $*"; }
ok()    { printf '%s[✓]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; log_file_only "OK    $*"; }
warn()  { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; log_file_only "WARN  $*"; }
err()   { printf '%s[✗]%s %s\n' "$C_RED"   "$C_RESET" "$*" >&2; log_file_only "ERROR $*"; }

step() {
  printf '\n%s%s▶ %s%s\n' "$C_BOLD" "$C_BLUE" "$*" "$C_RESET"
  log_file_only "STEP  $*"
}

die() {
  err "$*"
  printf '%s    Consulta el log completo en: %s%s\n' "$C_GRAY" "$LOG_FILE" "$C_RESET" >&2
  exit 1
}

# ---- Ejecución de comandos con log -------------------------------------------
# Uso:  run <comando...> || die "mensaje"
run() {
  log_file_only "\$ $*"
  "$@" 2>&1 | tee -a "$LOG_FILE"
  local rc=${PIPESTATUS[0]}
  if [ "$rc" -ne 0 ]; then
    err "Comando falló (rc=$rc): $*"
    return "$rc"
  fi
  return 0
}

# Igual que run pero silencioso en consola (solo al log). Para comandos ruidosos.
run_quiet() {
  log_file_only "\$ $*"
  if ! "$@" >> "$LOG_FILE" 2>&1; then
    err "Comando falló: $*"
    return 1
  fi
  return 0
}

# ---- Requisitos --------------------------------------------------------------
require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "Este script debe ejecutarse como root (usa: sudo bash install.sh)."
  fi
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ---- Prompts -----------------------------------------------------------------
# ask VAR "Pregunta" "valor_por_defecto"
ask() {
  local __var="$1" __prompt="$2" __default="${3:-}" __cur __input
  __cur="${!__var:-$__default}"
  if [ "${NONINTERACTIVE:-false}" = "true" ]; then
    printf -v "$__var" '%s' "$__cur"
    return 0
  fi
  if [ -n "$__cur" ]; then
    read -r -p "$__prompt [$__cur]: " __input || true
    __input="${__input:-$__cur}"
  else
    read -r -p "$__prompt: " __input || true
  fi
  printf -v "$__var" '%s' "$__input"
}

# ask_secret VAR "Pregunta"  (lectura silenciosa + confirmación)
ask_secret() {
  local __var="$1" __prompt="$2" __a __b
  if [ "${NONINTERACTIVE:-false}" = "true" ]; then
    return 0
  fi
  while true; do
    read -r -s -p "$__prompt: " __a; echo
    read -r -s -p "Confirmar contraseña: " __b; echo
    if [ "$__a" != "$__b" ]; then
      warn "Las contraseñas no coinciden. Intenta de nuevo."
      continue
    fi
    if [ "${#__a}" -lt 6 ]; then
      warn "La contraseña debe tener al menos 6 caracteres."
      continue
    fi
    printf -v "$__var" '%s' "$__a"
    break
  done
}

# confirm "Pregunta"  → 0 si sí
confirm() {
  local prompt="$1" ans
  if [ "${ASSUME_YES:-false}" = "true" ] || [ "${NONINTERACTIVE:-false}" = "true" ]; then
    return 0
  fi
  read -r -p "$prompt [s/N]: " ans || true
  case "${ans,,}" in s|si|sí|y|yes) return 0;; *) return 1;; esac
}

# ---- Validaciones de formato -------------------------------------------------
valid_email()  { [[ "$1" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; }
valid_domain() { [[ "$1" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}$ ]]; }

gen_secret() {
  if command_exists openssl; then
    openssl rand -hex 48
  else
    head -c 48 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

# ---- Render de plantillas ({{CLAVE}} → valor) --------------------------------
# render_tpl <src> <dest> CLAVE=valor [CLAVE2=valor2 ...]
render_tpl() {
  local src="$1" dest="$2"; shift 2
  [ -f "$src" ] || die "Plantilla no encontrada: $src"
  local tmp; tmp="$(mktemp)"
  cp "$src" "$tmp"
  local pair k v
  for pair in "$@"; do
    k="${pair%%=*}"; v="${pair#*=}"
    v="${v//\\/\\\\}"; v="${v//&/\\&}"; v="${v//|/\\|}"
    sed -i "s|{{${k}}}|${v}|g" "$tmp"
  done
  mv "$tmp" "$dest"
}

# ---- Registro de resultados de validación ------------------------------------
declare -a VAL_NAME VAL_STATUS VAL_DETAIL
val_add() { VAL_NAME+=("$1"); VAL_STATUS+=("$2"); VAL_DETAIL+=("${3:-}"); }

# Comprueba/repara un servicio systemd. Devuelve 0 si queda activo.
ensure_active() {
  local unit="$1" tries="${2:-2}" i
  for ((i=1; i<=tries; i++)); do
    if systemctl is-active --quiet "$unit"; then return 0; fi
    warn "Servicio '$unit' inactivo. Intento de reparación $i/$tries..."
    systemctl restart "$unit" >>"$LOG_FILE" 2>&1 || true
    sleep 3
  done
  systemctl is-active --quiet "$unit"
}

# Login contra la API. api_login <email> <pass> <base_url>
api_login() {
  local email="$1" pass="$2" base="$3" payload resp
  payload="$(jq -n --arg e "$email" --arg p "$pass" '{email:$e,password:$p}')"
  resp="$(curl -fsS -k -m 20 -X POST "$base/api/auth/login" \
          -H 'Content-Type: application/json' -d "$payload" 2>>"$LOG_FILE")" || return 1
  echo "$resp" | jq -e '.token' >/dev/null 2>&1
}
