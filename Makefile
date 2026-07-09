include .env
export

SSH      = ssh -p $(VPS_SSH_PORT) $(DEPLOY_USER)@$(VPS_HOST)
SSH_ROOT = ssh -p $(VPS_SSH_PORT) root@$(VPS_HOST)
SCP      = scp -P $(VPS_SSH_PORT)

.PHONY: bootstrap backup restore healthcheck

## Aprovisiona un VPS nuevo (correr una sola vez, requiere acceso root).
bootstrap:
	$(SCP) scripts/bootstrap.sh root@$(VPS_HOST):/root/bootstrap.sh
	$(SSH_ROOT) "DEPLOY_USER='$(DEPLOY_USER)' DEPLOY_SSH_PUBLIC_KEY='$(DEPLOY_SSH_PUBLIC_KEY)' TIMEZONE='$(TIMEZONE)' bash /root/bootstrap.sh"

## Respalda /data/coolify (y lo definido en BACKUP_PATHS) hacia Cloudflare R2.
backup:
	$(SCP) scripts/backup.sh $(DEPLOY_USER)@$(VPS_HOST):/tmp/backup.sh
	$(SSH) "RESTIC_REPOSITORY='$(RESTIC_REPOSITORY)' RESTIC_PASSWORD='$(RESTIC_PASSWORD)' AWS_ACCESS_KEY_ID='$(AWS_ACCESS_KEY_ID)' AWS_SECRET_ACCESS_KEY='$(AWS_SECRET_ACCESS_KEY)' BACKUP_PATHS='$(BACKUP_PATHS)' sudo -E bash /tmp/backup.sh"

## Restaura el snapshot más reciente (o SNAPSHOT=<id>) hacia RESTORE_TARGET.
restore:
	$(SCP) scripts/restore.sh $(DEPLOY_USER)@$(VPS_HOST):/tmp/restore.sh
	$(SSH) "RESTIC_REPOSITORY='$(RESTIC_REPOSITORY)' RESTIC_PASSWORD='$(RESTIC_PASSWORD)' AWS_ACCESS_KEY_ID='$(AWS_ACCESS_KEY_ID)' AWS_SECRET_ACCESS_KEY='$(AWS_SECRET_ACCESS_KEY)' RESTORE_TARGET='$(RESTORE_TARGET)' sudo -E bash /tmp/restore.sh $(SNAPSHOT)"

## Verifica que los servicios core del VPS estén respondiendo.
healthcheck:
	$(SCP) scripts/healthcheck.sh $(DEPLOY_USER)@$(VPS_HOST):/tmp/healthcheck.sh
	$(SSH) "COOLIFY_URL='$(COOLIFY_URL)' bash /tmp/healthcheck.sh"
