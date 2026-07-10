# Backups

## Herramienta: restic + Cloudflare R2

Se usa [restic](https://restic.net/) (backups incrementales, deduplicados y cifrados) con destino en **Cloudflare R2** (compatible con la API de S3):

- Capa gratuita: 10 GB de almacenamiento, sin costo de egreso (sacar datos para restaurar no genera cargo, a diferencia de AWS S3).
- El repositorio de restic queda cifrado con una passphrase propia — ni Cloudflare ni nadie con acceso al bucket puede leer el contenido sin ella.

## Qué se respalda

En esta fase, lo crítico es `/data/coolify` en el VPS: ahí vive toda la configuración de Coolify (proyectos, variables de entorno cifradas, definiciones de despliegue, certificados). Es el equivalente a "todo el estado que no está en Git".

Las bases de datos de cada aplicación (Postgres, etc.) se administran dentro de sus propios contenedores vía Coolify; a medida que se desplieguen aplicaciones reales, se agregan sus rutas de datos a `BACKUP_PATHS` en `.env` para que `scripts/backup.sh` las incluya también.

## Configuración

1. Crear una cuenta de Cloudflare (gratis) y un bucket R2 (usado: `platform-backups`).
2. Generar un **Account API Token** de R2 (Cloudflare → R2 → Manage R2 API Tokens) con permiso **Object Read & Write**, scoped a ese bucket específico (no "Admin", no "all buckets" — el mínimo necesario).
3. Completar en `.env`:
   - `RESTIC_REPOSITORY` — formato `s3:https://<account-id>.r2.cloudflarestorage.com/<bucket>`
   - `RESTIC_PASSWORD` — passphrase de cifrado, generada con `openssl rand -base64 32`. Guardarla también en un gestor de contraseñas — si se pierde, no hay forma de leer los backups.
   - `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — credenciales del token de R2, restic las usa vía protocolo S3.
4. `scripts/backup.sh` corre `restic init` automáticamente la primera vez si el repositorio remoto no existe.

### Nota real de troubleshooting: no usar "Client IP Address Filtering" en el token de R2

Cloudflare permite restringir un token de R2 a una IP específica. Se intentó restringirlo a la IP del VPS y **falló con "Access Denied"**, porque `restic` (binario en Go) usa su propio resolver de red y por defecto prefiere conectarse por **IPv6** — una IP que no estaba en la lista blanca — aunque el VPS también tiene IPv4. A diferencia de herramientas basadas en glibc (como `curl`), el resolver de Go **no respeta `/etc/gai.conf`**, así que forzar IPv4 a nivel de sistema no lo arregla. La solución aplicada fue quitar el filtro de IP del token y confiar en el Access Key/Secret (ya suficientemente fuertes) más el scope del token (solo ese bucket, solo lectura/escritura de objetos) como límite de seguridad. Alternativa no aplicada, más invasiva: deshabilitar IPv6 en todo el VPS (`/etc/sysctl.d`) para que coincida con el filtro de IP.

## Programación

El backup corre automáticamente vía cron en el propio VPS — no depende de que la laptop del operador esté prendida (a diferencia de `make backup`, que es para correrlo bajo demanda desde la máquina del operador).

`scripts/install-backup-cron.sh` (ejecutado una vez vía `make install-backup-cron`) deja instalado:

- `/opt/platform/backup.sh` — copia permanente del script.
- `/opt/platform/backup.env` (permisos 600, solo root) — credenciales de R2 y configuración de retención.
- `/opt/platform/run-backup.sh` — wrapper que carga `backup.env` y ejecuta `backup.sh`.
- `/etc/cron.d/platform-backup` — corre `run-backup.sh` diariamente a las 3am (hora del servidor), log en `/var/log/platform-backup.log`.

Para cambiar el horario, ajustar `BACKUP_CRON_SCHEDULE` en `.env` (formato cron estándar) y volver a correr `make install-backup-cron`.

## Retención

Política inicial (ajustable en `scripts/backup.sh`): conservar los últimos 7 backups diarios, 4 semanales y 6 mensuales (`restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune`).

## Importante: un backup que nunca se restauró no es un backup

La Fase 6 incluye una restauración real de prueba (`scripts/restore.sh` contra un VPS o directorio temporal distinto al de producción) para confirmar que el proceso funciona antes de necesitarlo de verdad. Ver [`disaster-recovery.md`](disaster-recovery.md).
