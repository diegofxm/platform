#!/usr/bin/env bash
# Aprovisiona un VPS Ubuntu 24.04 recién creado: usuario deploy, firewall,
# fail2ban, actualizaciones automáticas, Docker y Coolify.
#
# Se ejecuta UNA VEZ, como root, contra un servidor nuevo. Ver docs/security.md.
#
# IMPORTANTE: este script NO deshabilita el login por contraseña ni el login
# de root — eso es responsabilidad de scripts/harden-ssh.sh, que debe correrse
# por separado, solo DESPUÉS de confirmar que el login con el usuario deploy
# y su llave funciona. Mantener esto en dos pasos evita quedar bloqueado
# fuera del servidor por un typo en la llave pública.
#
# Uso:
#   DEPLOY_USER=deploy DEPLOY_SSH_PUBLIC_KEY="ssh-ed25519 AAAA..." ./bootstrap.sh
# o cargando las variables desde .env (ver .env.example / Makefile).

set -euo pipefail

DEPLOY_USER="${DEPLOY_USER:-deploy}"
DEPLOY_SSH_PUBLIC_KEY="${DEPLOY_SSH_PUBLIC_KEY:?"Falta DEPLOY_SSH_PUBLIC_KEY (la llave pública SSH del usuario deploy)"}"
TIMEZONE="${TIMEZONE:-America/Bogota}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Este script debe correr como root en un VPS recién creado." >&2
  exit 1
fi

echo "==> Actualizando el sistema"
apt-get update -y
apt-get upgrade -y

echo "==> Configurando zona horaria ($TIMEZONE)"
timedatectl set-timezone "$TIMEZONE"

echo "==> Creando usuario '$DEPLOY_USER'"
if ! id "$DEPLOY_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
  usermod -aG sudo "$DEPLOY_USER"
fi

DEPLOY_HOME="/home/$DEPLOY_USER"
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$DEPLOY_HOME/.ssh"
if ! grep -qF "$DEPLOY_SSH_PUBLIC_KEY" "$DEPLOY_HOME/.ssh/authorized_keys" 2>/dev/null; then
  echo "$DEPLOY_SSH_PUBLIC_KEY" >>"$DEPLOY_HOME/.ssh/authorized_keys"
fi
chmod 600 "$DEPLOY_HOME/.ssh/authorized_keys"
chown "$DEPLOY_USER:$DEPLOY_USER" "$DEPLOY_HOME/.ssh/authorized_keys"

echo "==> Instalando fail2ban, ufw, unattended-upgrades"
apt-get install -y fail2ban ufw unattended-upgrades curl ca-certificates gnupg

echo "==> Habilitando actualizaciones de seguridad automáticas"
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "==> Configurando firewall (ufw): solo 22, 80, 443"
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "==> Habilitando fail2ban"
systemctl enable --now fail2ban

echo "==> Instalando Docker Engine"
if ! command -v docker &>/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    >/etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
usermod -aG docker "$DEPLOY_USER"

echo "==> Instalando Coolify"
curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash

cat <<EOF

==> Listo. Provisión base completada (SSH todavía acepta password/root).

Coolify quedó instalado. Accede al panel en:

    http://ESTA_IP:8000

Siguientes pasos manuales:
  1. Desde OTRA terminal, confirmar que el login funciona:
         ssh -i <tu-llave-privada> $DEPLOY_USER@ESTA_IP
     Si falla, revisa la llave pública antes de seguir — NO corras
     harden-ssh.sh hasta confirmar esto.
  2. Solo si el login anterior funcionó, correr:
         scripts/harden-ssh.sh   (deshabilita password auth y root login)
  3. Completar el setup inicial de Coolify (crear el usuario admin).
  4. Apuntar coolify.cofacture.co (o el subdominio elegido) a esta IP — ver docs/domains.md.
  5. Configurar ese dominio dentro de Coolify para servir el panel por HTTPS.

EOF
