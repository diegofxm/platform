# Arquitectura de la plataforma

## Contexto

El objetivo es alojar múltiples productos (Go, y potencialmente otros lenguajes) sobre un único VPS de Hetzner, administrables de forma mayormente visual, con despliegue automático desde GitHub, y con la posibilidad de reconstruir toda la infraestructura desde cero si el servidor falla.

No hay un equipo de plataforma dedicado — es un desarrollador construyendo varios productos en paralelo. Esa restricción es la que más pesa en las decisiones de abajo: **menos piezas que mantener a mano es más profesional que más control manual**, si nadie tiene el tiempo de sostener ese control a largo plazo.

## Decisión: Coolify como orquestador único

Se evaluaron tres enfoques:

1. **IaC puro** — Traefik configurado a mano, Portainer solo como dashboard, despliegues vía GitHub Actions + SSH o Watchtower. Máxima transparencia (todo en Git), pero cada pieza (proxy, CI/CD, secrets por repo) es responsabilidad manual y acumula deuda operativa con el tiempo.
2. **Híbrido (Portainer + Dokploy + Traefik manual)** — la primera propuesta evaluada. Se descartó: Dokploy administra su propio Traefik y guarda estado de despliegue en su base de datos interna, lo que entra en conflicto con un Traefik configurado a mano y rompe la promesa de "todo reproducible desde Git" (parte del estado queda fuera del repo, sin versionar).
3. **PaaS-first con Coolify** — un solo sistema administra proxy, SSL, despliegues desde GitHub y bases de datos por proyecto, todo desde una UI web. Elegido.

### Por qué Coolify y no la Opción 1 (IaC puro)

- Un solo modelo mental en vez de cuatro piezas independientes (Traefik + Portainer + CI/CD por repo + herramienta de auto-update) que hay que mantener sincronizadas indefinidamente.
- Uso diario 100% visual (prioridad explícita del proyecto), no solo para monitoreo sino también para desplegar y depurar.
- Es open source, self-hosted, y solo orquesta contenedores Docker estándar por debajo — si el día de mañana se abandona Coolify, los contenedores y sus imágenes siguen siendo Docker normal, inspeccionable y migrable.
- El costo real (que el estado de los despliegues vive en la base de datos interna de Coolify, no 100% en este repo) se mitiga con backups automáticos y versionados de esa base de datos (ver [`backups.md`](backups.md)), y no es fundamentalmente distinto de manejar secretos `.env`, que tampoco viven en Git en ningún enfoque.

### Qué NO administra Coolify (y por eso vive en este repo)

- **Hardening del VPS** — firewall, SSH, fail2ban, actualizaciones de seguridad. Ver [`security.md`](security.md) y `scripts/bootstrap.sh`.
- **Backups fuera del servidor** — Coolify no envía sus backups a un storage externo por defecto. Ver [`backups.md`](backups.md) y `scripts/backup.sh`.
- **Runbook de recuperación ante desastres** — qué hacer si el VPS muere. Ver [`disaster-recovery.md`](disaster-recovery.md).
- **Documentación de dominios** — cómo se reparten los subdominios entre proyectos. Ver [`domains.md`](domains.md).

## Diagrama

```
                        Internet
                            |
                        Coolify Proxy (Traefik interno, gestionado por Coolify)
                            |
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
  cofacture-api          novaerp           smart-trash
  (repo independiente)  (repo independiente) (repo independiente)
        |                   |                   |
        └─────────── Postgres / Redis / MinIO por proyecto (via Coolify) ──┘

VPS (Ubuntu 24.04, Hetzner)
 ├── Docker Engine
 ├── Coolify            ← due­ño de: proxy, SSL, deploys, DBs por proyecto
 └── Este repo (platform) ← due­ño de: bootstrap, hardening, backups, runbooks, docs
```

## Qué NO incluye este repo (a propósito)

A diferencia de la propuesta inicial evaluada, este repo **no** incluye `compose.yaml` de Traefik, Portainer, Postgres, Redis, MinIO ni Grafana/Prometheus/Loki escritos a mano — esos servicios, cuando aplican, se crean y administran desde la UI de Coolify o (monitoreo) se añaden en una fase posterior con una herramienta liviana (Uptime Kuma) en vez de un stack completo de observabilidad desde el día uno.

## Repositorios relacionados

```
github.com/diegofxm/platform      ← este repo (infraestructura)
github.com/diegofxm/cofacture-api ← aplicación (Go)
github.com/diegofxm/novaerp       ← aplicación (Go)
github.com/diegofxm/ubl21-dian    ← librería (Go)
github.com/diegofxm/smart-trash   ← aplicación (Go)
```

Cada aplicación trae su propio `Dockerfile` y se conecta a Coolify para su despliegue — este repo no necesita saber que existen.
