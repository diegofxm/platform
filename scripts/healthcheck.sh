#!/usr/bin/env bash
# Verifica que los servicios core del VPS estén respondiendo.
# Pensado para correr por cron y alimentar alertas en una fase posterior
# (Uptime Kuma, Fase 4), o para correrse a mano tras un despliegue/restore.

set -uo pipefail

COOLIFY_URL="${COOLIFY_URL:-}"
FAILED=0

check() {
  local name="$1"
  local cmd="$2"
  if eval "$cmd" &>/dev/null; then
    echo "OK   - $name"
  else
    echo "FAIL - $name"
    FAILED=1
  fi
}

check "Docker daemon activo" "docker info"
check "Al menos un contenedor corriendo" "[ \"\$(docker ps -q | wc -l)\" -gt 0 ]"

if [[ -n "$COOLIFY_URL" ]]; then
  check "Panel de Coolify responde ($COOLIFY_URL)" "curl -fsS -o /dev/null '$COOLIFY_URL'"
else
  echo "SKIP - Panel de Coolify (define COOLIFY_URL en .env para incluir este chequeo)"
fi

if [[ "$FAILED" -eq 1 ]]; then
  echo
  echo "Uno o más chequeos fallaron."
  exit 1
fi

echo
echo "Todos los chequeos pasaron."
