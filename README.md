# platform

Infraestructura como código para el "cloud privado" que aloja todos los productos de `diegofxm` (Cofacture, NovaERP, UBL21-DIAN, Smart Trash y los que vengan después) sobre un único VPS de Hetzner.

Este repositorio **no contiene código de aplicación**. Contiene todo lo necesario para reconstruir el servidor desde cero: scripts de aprovisionamiento, configuración de backups y la documentación operativa (arquitectura, seguridad, dominios, recuperación ante desastres).

## Filosofía

- **Coolify es el orquestador único.** Administra el proxy reverso, los certificados SSL, los despliegues desde GitHub y las bases de datos por proyecto. No hay Traefik ni Portainer configurados a mano por fuera de Coolify — evita tener dos piezas peleando por el mismo rol. Ver [`docs/architecture.md`](docs/architecture.md) para la justificación completa de esta decisión.
- **El VPS es desechable, este repo no.** Si el servidor muere, un VPS nuevo + este repo + el backup más reciente en el storage externo reconstruyen la plataforma completa. Ver [`docs/disaster-recovery.md`](docs/disaster-recovery.md).
- **Cada aplicación es independiente.** `platform` le da a cada proyecto red, dominio, HTTPS, base de datos y despliegue automático — no le importa en qué lenguaje esté escrita (Go, Node, Python, lo que sea), solo necesita un `Dockerfile`.

## Estructura

```
platform/
├── scripts/
│   ├── bootstrap.sh      # Aprovisiona un VPS Ubuntu 24.04 nuevo: hardening + Docker + Coolify
│   ├── backup.sh         # Respalda el estado de Coolify hacia storage S3-compatible (restic)
│   ├── restore.sh        # Restaura desde el backup más reciente (o uno específico)
│   └── healthcheck.sh    # Verifica que los servicios core estén arriba
├── docs/
│   ├── architecture.md       # Decisión de arquitectura: por qué Coolify y no Traefik/Dokploy manual
│   ├── domains.md            # Cómo se organizan los dominios/subdominios (cofacture.co, Cloudflare)
│   ├── security.md           # Hardening del VPS, política de SSH, manejo de secretos
│   ├── backups.md            # Estrategia de backups: restic + Cloudflare R2
│   └── disaster-recovery.md  # Runbook: qué hacer si el VPS muere
├── .env.example
├── Makefile
└── README.md
```

## Estado del proyecto (roadmap)

- [x] **Fase 1** — Estructura del repo, documentación base, scripts de bootstrap/backup/restore.
- [ ] **Fase 2** — Provisionar el VPS real en Hetzner y correr `bootstrap.sh` (instala Coolify).
- [ ] **Fase 3** — Configurar DNS (Cloudflare) y activar backups automáticos hacia Cloudflare R2.
- [ ] **Fase 4** — Monitoreo con alertas (Uptime Kuma).
- [ ] **Fase 5** — Desplegar la primera aplicación real (`cofacture-api`) vía Coolify.
- [ ] **Fase 6** — Repaso de seguridad end-to-end y prueba real de restauración desde backup.

## Quick start (cuando el VPS ya exista)

```bash
cp .env.example .env
# Editar .env con la IP del VPS, la llave SSH pública del usuario deploy, etc.

make bootstrap   # corre scripts/bootstrap.sh contra el VPS definido en .env
make backup       # respaldo manual (además corre automático por cron una vez configurado)
make healthcheck  # revisa que los servicios core respondan
```

Ver [`docs/architecture.md`](docs/architecture.md) antes que nada — explica el por qué de cada decisión tomada en este repo.
