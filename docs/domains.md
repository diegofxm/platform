# Dominios y DNS

## Situación actual

Existe un único dominio propio, `cofacture.co`, registrado para el producto Cofacture. No hay (todavía) un dominio dedicado exclusivamente a la infraestructura/administración de la plataforma.

## Cómo se organiza mientras tanto

Se usan subdominios de `cofacture.co` apuntando (registro DNS tipo `A`, gestionado en Namecheap → Advanced DNS) a la IP pública del VPS (`167.233.192.38`):

| Subdominio | Uso | Estado |
|---|---|---|
| `coolify.cofacture.co` | Panel de administración de Coolify | ✅ Configurado — DNS propagado, HTTPS válido (Let's Encrypt) |
| `app.cofacture.co` / `api.cofacture.co` | Producto Cofacture (aplicación real) | Pendiente (Fase 5) |
| `status.cofacture.co` | Dashboard de monitoreo (Uptime Kuma, Fase 4) | Pendiente (Fase 4) |

Para `coolify.cofacture.co`, además del registro DNS, hubo que configurar el dominio dentro del propio Coolify: **Settings → Configuration → General → URL** (`https://coolify.cofacture.co`) y guardar. Coolify reconfigura su proxy interno y emite el certificado automáticamente — no requiere tocar Traefik ni archivos a mano.

Cada nuevo proyecto (NovaERP, Smart Trash, etc.) puede:

- Usar su propio dominio si ya lo tiene (`novaerp.com` → misma IP del VPS), o
- Usar temporalmente `proyecto.cofacture.co` mientras se valida el producto.

Coolify emite certificados SSL automáticamente (Let's Encrypt) por cada dominio/subdominio que se le asigne a una aplicación — no requiere configuración manual de certificados en este repo.

## Recomendación a futuro (no bloqueante)

Registrar un dominio propio y neutral para las herramientas *internas* (Coolify, monitoreo) que no dependa del dominio de ningún producto — así, si algún día se vende o migra `cofacture.co`, el panel de administración de la plataforma no se ve afectado. Costo aproximado: 10-15 USD/año. No es necesario para arrancar.

## DNS: se quedó en Namecheap

Se evaluó mover la gestión DNS de `cofacture.co` a Cloudflare (protección DDoS, cambiar la IP del VPS en un solo lugar si se migra de servidor), pero no es necesario para operar — Namecheap resuelve igual de bien los registros `A` que necesita este setup. Queda como mejora opcional a futuro, no bloqueante. Si se activa en algún momento, revisar el modo del proxy naranja de Cloudflare (afecta cómo Coolify valida los certificados Let's Encrypt: HTTP-01 requiere dejarlo en modo "solo DNS"/nube gris, o cambiar a validación DNS-01).

## Pasos para agregar un subdominio nuevo (ej. al desplegar una app)

1. En Namecheap → Domain List → `cofacture.co` → **Manage** → **Advanced DNS** → **Add New Record**: tipo `A`, host = el subdominio (ej. `api`), value = `167.233.192.38`.
2. Esperar propagación (5-30 min típico).
3. En Coolify, asignar ese dominio a la aplicación/servicio correspondiente.
4. Verificar que el certificado SSL se emitió correctamente (Coolify lo indica en su UI).
