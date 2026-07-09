# Seguridad

## Provisión en dos pasos deliberados

El aprovisionamiento inicial está dividido en dos scripts independientes a propósito, para que deshabilitar el acceso root/password sea una acción verificada, no un paso ciego dentro de un script más largo.

### Paso 1 — `scripts/bootstrap.sh`

Se ejecuta una única vez, contra un VPS Ubuntu 24.04 recién creado en Hetzner, como `root` (es la única fase del proyecto donde el uso de terminal es obligatorio). Deja el servidor en este estado:

- **Usuario no-root para todo lo demás.** Se crea el usuario definido en `DEPLOY_USER` (por defecto `deploy`), con `sudo` sin password (`/etc/sudoers.d/90-deploy-nopasswd`) y se le agrega la llave pública SSH definida en `DEPLOY_SSH_PUBLIC_KEY`. El sudo sin password es necesario para que `scripts/backup.sh` y `scripts/healthcheck.sh` corran de forma no interactiva por SSH, y no añade superficie de ataque real: este usuario ya pertenece al grupo `docker`, que de por sí equivale a acceso root (se puede montar el filesystem del host desde un contenedor privilegiado). El límite de seguridad real de este servidor es la llave privada SSH de `deploy`, no `sudo`.
- **Firewall (`ufw`).** Solo se permiten los puertos 22 (SSH), 80 (HTTP) y 443 (HTTPS). Todo lo demás, denegado por defecto.
- **`fail2ban`.** Bloquea IPs con intentos repetidos de login SSH fallido.
- **`unattended-upgrades`.** Actualizaciones de seguridad del sistema operativo se aplican automáticamente.
- **Docker Engine + plugin de compose**, instalados desde el repositorio oficial de Docker.
- **Coolify**, instalado con el script oficial (requiere ejecutarse como root en este paso específico del bootstrap; después de instalado, su administración diaria es 100% vía navegador).

Este script **no toca la configuración de SSH** — root y password login siguen habilitados al terminar.

### Verificación manual obligatoria

Antes de continuar, desde una terminal nueva, confirmar que el login con el usuario `deploy` y su llave privada funciona:

```bash
ssh -i <tu-llave-privada> deploy@<ip-del-vps>
```

Si falla, **no continuar** — revisar la llave pública instalada antes de perder acceso al servidor.

### Paso 2 — `scripts/harden-ssh.sh`

Solo después de confirmar el paso anterior, se corre este script (root), que deshabilita `PasswordAuthentication` y `PermitRootLogin`, y reinicia `sshd`. A partir de aquí, el único acceso al servidor es por SSH con llave, como `deploy`.

## Manejo de secretos

- Ningún secreto real (contraseñas, tokens de API, llaves privadas) se versiona en este repositorio. `.env` está en `.gitignore`; solo `.env.example` (con valores de ejemplo) se versiona.
- Las variables de entorno de cada aplicación (DB passwords, API keys de terceros, etc.) se administran dentro de la UI de Coolify, por proyecto — Coolify las cifra en su base de datos interna.
- Las credenciales del storage externo de backups (Cloudflare R2) viven únicamente en el `.env` local de quien ejecuta `scripts/backup.sh`, o como variables de entorno en el propio VPS — nunca en Git.

## Acceso administrativo

- El panel de Coolify (`coolify.cofacture.co`) debe protegerse con una contraseña fuerte y, si Coolify lo soporta en la versión instalada, 2FA.
- Se recomienda no exponer el panel de Coolify sin restricción — evaluar en una fase posterior restringir el acceso por IP o detrás de una VPN (ej. Tailscale) si el panel llega a ser un objetivo de ataque relevante.

## Checklist de seguridad (repasar en la Fase 6)

- [ ] SSH solo por llave, root deshabilitado.
- [ ] `ufw` activo con solo 22/80/443 abiertos.
- [ ] `fail2ban` activo y probado.
- [ ] Actualizaciones de seguridad automáticas confirmadas.
- [ ] Backups probados con una restauración real (no solo "el script corrió sin error").
- [ ] Panel de Coolify con contraseña fuerte (+ 2FA si aplica).
- [ ] Ningún secreto real presente en el historial de Git.
