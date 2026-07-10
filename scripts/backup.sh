#!/usr/bin/env bash
# Respalda las rutas listadas en BACKUP_PATHS hacia el repositorio restic remoto
# (Cloudflare R2 por defecto). Ver docs/backups.md.
#
# Requiere: restic instalado en el VPS, y las variables RESTIC_REPOSITORY,
# RESTIC_PASSWORD, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY definidas (.env).

set -euo pipefail

: "${RESTIC_REPOSITORY:?"Falta RESTIC_REPOSITORY (endpoint S3 del bucket de backups)"}"
: "${RESTIC_PASSWORD:?"Falta RESTIC_PASSWORD (passphrase de cifrado del repositorio restic)"}"
: "${AWS_ACCESS_KEY_ID:?"Falta AWS_ACCESS_KEY_ID"}"
: "${AWS_SECRET_ACCESS_KEY:?"Falta AWS_SECRET_ACCESS_KEY"}"

export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"

BACKUP_PATHS="${BACKUP_PATHS:-/data/coolify}"
KEEP_DAILY="${BACKUP_KEEP_DAILY:-7}"
KEEP_WEEKLY="${BACKUP_KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${BACKUP_KEEP_MONTHLY:-6}"

if ! command -v restic &>/dev/null; then
  echo "restic no está instalado. Instálalo con: apt-get install -y restic" >&2
  exit 1
fi

echo "==> Verificando repositorio restic remoto"
if ! restic snapshots &>/dev/null; then
  echo "==> Repositorio no inicializado, corriendo 'restic init'"
  restic init
fi

echo "==> Respaldando: $BACKUP_PATHS"
# shellcheck disable=SC2086
restic backup $BACKUP_PATHS \
  --tag platform-backup \
  --exclude-caches

echo "==> Aplicando política de retención (daily=$KEEP_DAILY weekly=$KEEP_WEEKLY monthly=$KEEP_MONTHLY)"
restic forget \
  --keep-daily "$KEEP_DAILY" \
  --keep-weekly "$KEEP_WEEKLY" \
  --keep-monthly "$KEEP_MONTHLY" \
  --prune

echo "==> Backup completado. Snapshots actuales:"
restic snapshots --compact
