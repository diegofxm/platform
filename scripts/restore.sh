#!/usr/bin/env bash
# Restaura un snapshot de restic hacia RESTORE_TARGET (por defecto /).
# Por defecto restaura el snapshot más reciente (`latest`); pasar un ID
# de snapshot como primer argumento para restaurar uno específico.
#
# Uso:
#   ./restore.sh                # restaura el snapshot más reciente
#   ./restore.sh <snapshot-id>  # restaura un snapshot específico
#
# Ver docs/disaster-recovery.md.

set -euo pipefail

: "${RESTIC_REPOSITORY:?"Falta RESTIC_REPOSITORY"}"
: "${RESTIC_PASSWORD:?"Falta RESTIC_PASSWORD"}"
: "${AWS_ACCESS_KEY_ID:?"Falta AWS_ACCESS_KEY_ID"}"
: "${AWS_SECRET_ACCESS_KEY:?"Falta AWS_SECRET_ACCESS_KEY"}"

export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"

SNAPSHOT="${1:-latest}"
RESTORE_TARGET="${RESTORE_TARGET:-/}"

if ! command -v restic &>/dev/null; then
  echo "restic no está instalado. Instálalo con: apt-get install -y restic" >&2
  exit 1
fi

echo "==> Snapshots disponibles:"
restic snapshots --compact

echo
echo "==> Restaurando snapshot '$SNAPSHOT' hacia '$RESTORE_TARGET'"
read -r -p "Confirmar (esto puede sobrescribir archivos existentes) [y/N]: " CONFIRM
if [[ "${CONFIRM,,}" != "y" ]]; then
  echo "Cancelado."
  exit 0
fi

restic restore "$SNAPSHOT" --target "$RESTORE_TARGET"

echo "==> Restauración completada. Revisa docs/disaster-recovery.md para los pasos siguientes (reiniciar Coolify, repuntar DNS, healthcheck)."
