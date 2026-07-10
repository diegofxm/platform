# Seguridad

## Provisión en dos pasos deliberados

El aprovisionamiento inicial está dividido en dos scripts independientes a propósito, para que deshabilitar el acceso root/password sea una acción verificada, no un paso ciego dentro de un script más largo.

### Paso 1 — `scripts/bootstrap.sh`

Se ejecuta una única vez, contra un VPS Ubuntu 24.04 recién creado en Hetzner, como `root` (es la única fase del proyecto donde el uso de terminal es obligatorio). Deja el servidor en este estado:

- **Usuario no-root para todo lo demás.** Se crea el usuario definido en `DEPLOY_USER` (por defecto `deploy`), con `sudo` sin password (`/etc/sudoers.d/90-deploy-nopasswd`) y se le agrega la llave pública SSH definida en `DEPLOY_SSH_PUBLIC_KEY`. El sudo sin password es necesario para que `scripts/backup.sh` y `scripts/healthcheck.sh` corran de forma no interactiva por SSH, y no añade superficie de ataque real: este usuario ya pertenece al grupo `docker`, que de por sí equivale a acceso root (se puede montar el filesystem del host desde un contenedor privilegiado). El límite de seguridad real de este servidor es la llave privada SSH de `deploy`, no `sudo`.
- **Firewall (`ufw`).** Solo se permiten los puertos 22 (SSH), 80 (HTTP) y 443 (HTTPS). Todo lo demás, denegado por defecto.
- **`fail2ban`.** Bloquea IPs con intentos repetidos de login SSH fallido — configurado con `ignoreip = 10.0.0.0/8` para las redes internas de Docker (ver nota abajo).
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

Solo después de confirmar el paso anterior, se corre este script (root), que deshabilita `PasswordAuthentication` y pone `PermitRootLogin prohibit-password`, y reinicia `sshd`. A partir de aquí, ningún usuario puede entrar por password — solo por llave.

**Nota importante:** el login de `root` **no se deshabilita por completo**, solo se restringe a llave (`prohibit-password`, no `no`). Esto es a propósito: Coolify se autogestiona conectándose por SSH como `root` a `localhost` con una llave dedicada que agrega a `/root/.ssh/authorized_keys` durante su instalación (visible como la entrada etiquetada `coolify`). Si `PermitRootLogin` se pone en `no`, esa auto-gestión se rompe y el servidor "localhost" aparece como "Not reachable" dentro del panel de Coolify — este fue el primer error real encontrado al provisionar el VPS de producción, corregido en este mismo repo.

**Segundo error real encontrado (también corregido):** mientras `PermitRootLogin` estuvo en `no`, el propio contenedor de Coolify (IP interna en la red Docker `coolify`, ej. `10.0.1.5`) intentó repetidamente conectarse por SSH como root y falló las veces suficientes para que `fail2ban` lo baneara — auto-bloqueándose a sí mismo aunque el tráfico venía del propio servidor, no de un atacante externo. Por eso `bootstrap.sh` configura `/etc/fail2ban/jail.local` con `ignoreip = 10.0.0.0/8` (cubre `docker0` y todas las redes que Coolify crea por cada stack) antes de habilitar `fail2ban`. Si esto vuelve a pasar, se soluciona con `fail2ban-client set sshd unbanip <ip>`.

## Manejo de secretos

- Ningún secreto real (contraseñas, tokens de API, llaves privadas) se versiona en este repositorio. `.env` está en `.gitignore`; solo `.env.example` (con valores de ejemplo) se versiona.
- Las variables de entorno de cada aplicación (DB passwords, API keys de terceros, etc.) se administran dentro de la UI de Coolify, por proyecto — Coolify las cifra en su base de datos interna.
- Las credenciales del storage externo de backups (Cloudflare R2) viven únicamente en el `.env` local de quien ejecuta `scripts/backup.sh`, o como variables de entorno en el propio VPS — nunca en Git.

## Acceso administrativo

- El panel de Coolify (`coolify.cofacture.co`) debe protegerse con una contraseña fuerte y, si Coolify lo soporta en la versión instalada, 2FA.
- Se recomienda no exponer el panel de Coolify sin restricción — evaluar en una fase posterior restringir el acceso por IP o detrás de una VPN (ej. Tailscale) si el panel llega a ser un objetivo de ataque relevante.

## Checklist de seguridad (repasar en la Fase 6)

- [x] SSH solo por llave; root restringido a llave (`prohibit-password`, necesario para que Coolify se autogestione).
- [ ] `ufw` activo con solo 22/80/443 abiertos.
- [ ] `fail2ban` activo y probado.
- [ ] Actualizaciones de seguridad automáticas confirmadas.
- [ ] Backups probados con una restauración real (no solo "el script corrió sin error").
- [ ] Panel de Coolify con contraseña fuerte (+ 2FA si aplica).
- [ ] Ningún secreto real presente en el historial de Git.
