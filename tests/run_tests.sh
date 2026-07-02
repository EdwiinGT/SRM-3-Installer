#!/usr/bin/env bash
# =============================================================================
#  run_tests.sh — Validación estática de todos los scripts del instalador
#  - Comprueba sintaxis bash (bash -n)
#  - Ejecuta shellcheck si está disponible
#  - Verifica que existan las plantillas requeridas
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fails=0

echo "== 1) Sintaxis bash (bash -n) =="
while IFS= read -r -d '' f; do
  if bash -n "$f" 2>/tmp/srm_syntax_err; then
    echo "  [OK]  $f"
  else
    echo "  [ERR] $f"; sed 's/^/        /' /tmp/srm_syntax_err; fails=$((fails+1))
  fi
done < <(find "$ROOT" -name '*.sh' -print0)

echo
echo "== 2) shellcheck =="
if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r -d '' f; do
    if shellcheck -x -S warning "$f" >/tmp/srm_sc 2>&1; then
      echo "  [OK]  $f"
    else
      echo "  [WARN] $f"; sed 's/^/        /' /tmp/srm_sc
    fi
  done < <(find "$ROOT" -name '*.sh' -print0)
else
  echo "  shellcheck no instalado (omitido). Instálalo con: apt install shellcheck"
fi

echo
echo "== 3) Plantillas requeridas =="
for t in \
  "config/defaults.conf" \
  "templates/backend.env.tpl" \
  "templates/frontend.env.tpl" \
  "templates/fail2ban-jail.local.tpl" \
  "templates/logrotate.tpl" \
  "nginx/srm.conf.tpl" \
  "systemd/srm-backend.service.tpl"; do
  if [ -f "$ROOT/$t" ]; then echo "  [OK]  $t"; else echo "  [ERR] falta $t"; fails=$((fails+1)); fi
done

echo
if [ "$fails" -eq 0 ]; then
  echo "RESULTADO: TODO OK ✔"
  exit 0
else
  echo "RESULTADO: $fails error(es) ✘"
  exit 1
fi
