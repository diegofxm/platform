# Seguridad

## Qué hace `scripts/bootstrap.sh`

Se ejecuta una única vez, contra un VPS Ubuntu 24.04 recién creado en Hetzner, como `root` (es la única fase del proyecto donde el uso de terminal es obligatorio). Deja el servidor en este estado:

- **Usuario no-root para todo lo demás.** Se crea el usuario definido en `DEPLOY_USER` (por defecto `deploy`), con `sudo`, y se le agrega la llave pública SSH definida en `DEPLOY_SSH_PUBLIC_KEY`.
- **SSH endurecido.** Login por contraseña deshabilitado, login de `root` por SSH deshabilitado. Solo autenticación por llave.
- **Firewall (`ufw`).** Solo se permiten los puertos 22 (SSH), 80 (HTTP) y 443 (HTTPS). Todo lo demás, denegado por defecto.
- **`fail2ban`.** Bloquea IPs con intentos repetidos de login SSH fallido.
- **`unattended-upgrades`.** Actualizaciones de seguridad del sistema operativo se aplican automáticamente.
- **Docker Engine + plugin de compose**, instalados desde el repositorio oficial de Docker.
- **Coolify**, instalado con el script oficial (requiere ejecutarse como root en este paso específico del bootstrap; después de instalado, su administración diaria es 100% vía navegador).

## Antes de cerrar la sesión de root

`bootstrap.sh` deshabilita el login por contraseña y el acceso SSH de `root` **solo si ya se confirmó** que el login con el usuario `deploy` y su llave funciona. El script imprime un recordatorio explícito de probar la conexión con el nuevo usuario en una terminal aparte antes de cerrar la sesión original — no hacerlo puede dejar el servidor inaccesible.

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
