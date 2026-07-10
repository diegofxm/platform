#!/usr/bin/env bash
# Instala scripts/backup.sh de forma permanente en el VPS y programa un cron
# diario. A diferencia de `make backup` (que copia el script a /tmp y lo
# corre bajo demanda desde la máquina del operador), esto deja todo lo
# necesario viviendo en el propio servidor para que el backup corra solo,
# sin depender de que alguien tenga la laptop prendida.
#
# Se ejecuta como root. Ver docs/backups.md.

set -euo pipefail

: "${RESTIC_REPOSITORY:?"Falta RESTIC_REPOSITORY"}"
: "${RESTIC_PASSWORD:?"Falta RESTIC_PASSWORD"}"
: "${AWS_ACCESS_KEY_ID:?"Falta AWS_ACCESS_KEY_ID"}"
: "${AWS_SECRET_ACCESS_KEY:?"Falta AWS_SECRET_ACCESS_KEY"}"

BACKUP_PATHS="${BACKUP_PATHS:-/data/coolify}"
KEEP_DAILY="${BACKUP_KEEP_DAILY:-7}"
KEEP_WEEKLY="${BACKUP_KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${BACKUP_KEEP_MONTHLY:-6}"
CRON_SCHEDULE="${BACKUP_CRON_SCHEDULE:-0 3 * * *}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Este script debe correr como root." >&2
  exit 1
fi

INSTALL_DIR=/opt/platform

echo "==> Instalando backup.sh en $INSTALL_DIR"
install -d -m 700 "$INSTALL_DIR"
install -m 700 "$(dirname "$0")/backup.sh" "$INSTALL_DIR/backup.sh"

echo "==> Escribiendo variables de entorno del backup ($INSTALL_DIR/backup.env)"
cat >"$INSTALL_DIR/backup.env" <<EOF
RESTIC_REPOSITORY=$RESTIC_REPOSITORY
RESTIC_PASSWORD=$RESTIC_PASSWORD
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
AWS_DEFAULT_REGION=auto
BACKUP_PATHS=$BACKUP_PATHS
BACKUP_KEEP_DAILY=$KEEP_DAILY
BACKUP_KEEP_WEEKLY=$KEEP_WEEKLY
BACKUP_KEEP_MONTHLY=$KEEP_MONTHLY
EOF
chmod 600 "$INSTALL_DIR/backup.env"

echo "==> Escribiendo wrapper de cron ($INSTALL_DIR/run-backup.sh)"
cat >"$INSTALL_DIR/run-backup.sh" <<EOF
#!/usr/bin/env bash
set -a
source $INSTALL_DIR/backup.env
set +a
exec $INSTALL_DIR/backup.sh
EOF
chmod 700 "$INSTALL_DIR/run-backup.sh"

echo "==> Programando cron diario ($CRON_SCHEDULE, hora del servidor)"
cat >/etc/cron.d/platform-backup <<EOF
$CRON_SCHEDULE root $INSTALL_DIR/run-backup.sh >> /var/log/platform-backup.log 2>&1
EOF
chmod 644 /etc/cron.d/platform-backup

touch /var/log/platform-backup.log
chmod 600 /var/log/platform-backup.log

echo "==> Listo. Backup diario programado ($CRON_SCHEDULE). Log en /var/log/platform-backup.log."
