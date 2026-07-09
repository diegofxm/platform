# Backups

## Herramienta: restic + Cloudflare R2

Se usa [restic](https://restic.net/) (backups incrementales, deduplicados y cifrados) con destino en **Cloudflare R2** (compatible con la API de S3):

- Capa gratuita: 10 GB de almacenamiento, sin costo de egreso (sacar datos para restaurar no genera cargo, a diferencia de AWS S3).
- El repositorio de restic queda cifrado con una passphrase propia — ni Cloudflare ni nadie con acceso al bucket puede leer el contenido sin ella.

## Qué se respalda

En esta fase, lo crítico es `/data/coolify` en el VPS: ahí vive toda la configuración de Coolify (proyectos, variables de entorno cifradas, definiciones de despliegue, certificados). Es el equivalente a "todo el estado que no está en Git".

Las bases de datos de cada aplicación (Postgres, etc.) se administran dentro de sus propios contenedores vía Coolify; a medida que se desplieguen aplicaciones reales, se agregan sus rutas de datos a `BACKUP_PATHS` en `.env` para que `scripts/backup.sh` las incluya también.

## Configuración (cuando se active, Fase 3)

1. Crear una cuenta de Cloudflare (gratis) y un bucket R2.
2. Generar un API token de R2 con permisos de lectura/escritura sobre ese bucket.
3. Completar en `.env`:
   - `RESTIC_REPOSITORY` (endpoint S3 del bucket R2)
   - `RESTIC_PASSWORD` (passphrase de cifrado — guardarla también en un gestor de contraseñas, si se pierde no hay forma de leer los backups)
   - `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (credenciales del token de R2, restic las usa vía protocolo S3)
4. `scripts/backup.sh` corre `restic init` automáticamente la primera vez si el repositorio remoto no existe.

## Programación

Una vez validado manualmente (`make backup`), se agrega una tarea cron en el VPS para correr `scripts/backup.sh` diariamente. Se documentará el cron exacto al completar la Fase 3.

## Retención

Política inicial (ajustable en `scripts/backup.sh`): conservar los últimos 7 backups diarios, 4 semanales y 6 mensuales (`restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune`).

## Importante: un backup que nunca se restauró no es un backup

La Fase 6 incluye una restauración real de prueba (`scripts/restore.sh` contra un VPS o directorio temporal distinto al de producción) para confirmar que el proceso funciona antes de necesitarlo de verdad. Ver [`disaster-recovery.md`](disaster-recovery.md).
