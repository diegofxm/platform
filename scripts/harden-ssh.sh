#!/usr/bin/env bash
# Deshabilita el login SSH por contraseña. El login de root se restringe a
# "solo con llave" (PermitRootLogin prohibit-password), NO se deshabilita
# por completo: Coolify se autogestiona conectándose por SSH como root a
# localhost con una llave dedicada que agrega a /root/.ssh/authorized_keys
# durante su instalación (ver scripts/bootstrap.sh). Poner "PermitRootLogin
# no" rompe esa auto-gestión y el servidor "localhost" queda marcado como
# "Not reachable" dentro de Coolify.
#
# Correr SOLO DESPUÉS de confirmar, desde una sesión separada, que el login
# con el usuario deploy y su llave privada funciona. Si esto se corre antes
# de esa verificación y la llave pública instalada estaba mal, el servidor
# queda inaccesible por password (aunque el acceso root por llave se
# mantiene como red de seguridad).
#
# Se ejecuta como root, después de scripts/bootstrap.sh. Ver docs/security.md.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Este script debe correr como root." >&2
  exit 1
fi

echo "==> Deshabilitando password auth (root y deploy solo por llave)"
sed -i \
  -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
  -e 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' \
  /etc/ssh/sshd_config

sshd -t

systemctl restart ssh

echo "==> Listo. SSH ahora solo acepta login por llave. Root sigue accesible solo por llave (lo necesita Coolify para gestionar 'localhost'); ningún usuario puede entrar por password."
