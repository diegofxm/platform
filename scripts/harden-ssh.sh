#!/usr/bin/env bash
# Deshabilita el login SSH por contraseña y el login de root.
#
# Correr SOLO DESPUÉS de confirmar, desde una sesión separada, que el login
# con el usuario deploy y su llave privada funciona. Si esto se corre antes
# de esa verificación y la llave pública instalada estaba mal, el servidor
# queda inaccesible por SSH.
#
# Se ejecuta como root, después de scripts/bootstrap.sh. Ver docs/security.md.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Este script debe correr como root." >&2
  exit 1
fi

echo "==> Deshabilitando password auth y login root en SSH"
sed -i \
  -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
  -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
  /etc/ssh/sshd_config

sshd -t

systemctl restart ssh

echo "==> Listo. SSH ahora solo acepta login por llave, y root ya no puede entrar por SSH."
