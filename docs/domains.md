# Dominios y DNS

## Situación actual

Existe un único dominio propio, `cofacture.co`, registrado para el producto Cofacture. No hay (todavía) un dominio dedicado exclusivamente a la infraestructura/administración de la plataforma.

## Cómo se organiza mientras tanto

Se usan subdominios de `cofacture.co` apuntando (registro DNS tipo `A`) a la IP pública del VPS:

| Subdominio | Uso |
|---|---|
| `app.cofacture.co` / `api.cofacture.co` | Producto Cofacture (aplicación real) |
| `coolify.cofacture.co` | Panel de administración de Coolify |
| `status.cofacture.co` | Dashboard de monitoreo (Uptime Kuma, Fase 4) |

Cada nuevo proyecto (NovaERP, Smart Trash, etc.) puede:

- Usar su propio dominio si ya lo tiene (`novaerp.com` → misma IP del VPS), o
- Usar temporalmente `proyecto.cofacture.co` mientras se valida el producto.

Coolify emite certificados SSL automáticamente (Let's Encrypt) por cada dominio/subdominio que se le asigne a una aplicación — no requiere configuración manual de certificados en este repo.

## Recomendación a futuro (no bloqueante)

Registrar un dominio propio y neutral para las herramientas *internas* (Coolify, monitoreo) que no dependa del dominio de ningún producto — así, si algún día se vende o migra `cofacture.co`, el panel de administración de la plataforma no se ve afectado. Costo aproximado: 10-15 USD/año. No es necesario para arrancar.

## DNS recomendado: Cloudflare

Se recomienda mover la gestión DNS de `cofacture.co` a Cloudflare (plan gratuito):

- Cambiar la IP del VPS en un solo lugar si se migra de servidor (relevante para [`disaster-recovery.md`](disaster-recovery.md)).
- Protección básica DDoS incluida.
- Si se activa el proxy naranja de Cloudflare (oculta la IP real del VPS), Coolify debe configurarse para validación de certificados vía DNS-01, o dejar el registro en modo "solo DNS" (nube gris) para simplificar la emisión de certificados Let's Encrypt vía HTTP-01. Se documentará el modo elegido en el momento de configurar Coolify (Fase 2/3).

## Pasos cuando el VPS ya tenga IP fija

1. En Cloudflare (o el proveedor DNS actual), crear registros `A` para cada subdominio de la tabla de arriba apuntando a la IP del VPS.
2. En Coolify, asignar el dominio correspondiente a cada aplicación/servicio.
3. Verificar que el certificado SSL se emitió correctamente (Coolify lo indica en su UI).
