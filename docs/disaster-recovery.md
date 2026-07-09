# Recuperación ante desastres

Runbook para el escenario "el VPS murió, fue destruido, o hay que migrar a otro proveedor".

## Objetivo de tiempo de recuperación

Estimado: 30-60 minutos desde que se crea el VPS nuevo hasta que Coolify y las aplicaciones vuelven a estar operativas, asumiendo que el backup más reciente en Cloudflare R2 es válido.

## Pasos

1. **Crear un VPS nuevo** en Hetzner (u otro proveedor compatible con Ubuntu 24.04). Anotar la nueva IP pública.
2. **Clonar este repositorio** en una máquina con acceso SSH al VPS nuevo:
   ```bash
   git clone https://github.com/diegofxm/platform
   cd platform
   cp .env.example .env
   # completar .env: IP del VPS nuevo, llave SSH, credenciales de R2
   ```
3. **Correr el bootstrap:**
   ```bash
   make bootstrap
   ```
   Esto deja el VPS con el mismo hardening y Coolify instalado, tal como en el servidor original.
4. **Restaurar el estado de Coolify desde el backup más reciente:**
   ```bash
   make restore
   ```
   Esto trae de vuelta `/data/coolify` con todos los proyectos, variables de entorno y configuración de despliegue.
5. **Reiniciar Coolify** para que tome el estado restaurado (el paso exacto se documenta al completar la Fase 2, depende de la versión de Coolify instalada).
6. **Repuntar el DNS** (Cloudflare) de cada subdominio (`coolify.cofacture.co`, `app.cofacture.co`, etc.) a la IP del VPS nuevo. Ver [`domains.md`](domains.md).
7. **Verificar** con `make healthcheck` que los servicios core respondan, y entrar al panel de Coolify para confirmar que los proyectos y sus despliegues están intactos.
8. **Forzar un redeploy** de cada aplicación desde Coolify si alguna no levanta automáticamente (puede pasar si la IP cambió y algún healthcheck interno quedó cacheado).

## Qué NO se recupera automáticamente

- Si el backup más reciente tiene más de 24h (frecuencia diaria planeada), se pierden como máximo las últimas 24h de cambios de configuración/datos hechos en Coolify. Para aplicaciones con datos transaccionales críticos (ej. una base de datos de facturación), evaluar una frecuencia de backup más agresiva específica para esa aplicación cuando se despliegue.
- Los DNS records deben repuntarse manualmente (paso 6) — no son parte del backup del VPS, viven en Cloudflare.

## Prueba de este runbook

Este procedimiento debe probarse al menos una vez de forma controlada (no esperar a una emergencia real para descubrir que un paso está mal documentado) — planeado como parte de la Fase 6.
