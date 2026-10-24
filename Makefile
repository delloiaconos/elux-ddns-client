ENDPOINT ?= https://ns1-elux.ing.unibs.it:4443
UUID_FILE ?= .host_uuid
ENVSUBST ?= envsubst

SERVICE_NAME := elux-ddns
SCRIPT_NAME := $(SERVICE_NAME)-update.sh
SCRIPT_PATH := /usr/local/bin
SYSTEMD_UNIT_DIR := /etc/systemd/system
export SERVICE_NAME SCRIPT_PATH SCRIPT_NAME ENDPOINT

.PHONY: id cron-job system-job update update-script update-units test

id:
	@cat /proc/sys/kernel/random/uuid | tee "$(UUID_FILE)"
	@chmod 600 "$(UUID_FILE)"

update: update-script update-units

update-script: elux-ddns-update.sh.in
	@test -s "$(UUID_FILE)" || { echo "Esegui prima 'make id'." >&2; exit 1; }
	@mkdir -p "$(SCRIPT_PATH)"
	@UUID=$$(cat "$(UUID_FILE)") \
	$(ENVSUBST) '$${ENDPOINT} $${UUID}' < "$<" > "$(SCRIPT_PATH)/$(SCRIPT_NAME)"
	@chmod 700 "$(SCRIPT_PATH)/$(SCRIPT_NAME)"

update-units: elux-ddns.service.in elux-ddns.timer.in
	@$(ENVSUBST) '$${SCRIPT_PATH} $${SCRIPT_NAME}' < elux-ddns.service.in > "$(SERVICE_NAME).service"
	@$(ENVSUBST) '$${SERVICE_NAME}' < elux-ddns.timer.in > "$(SERVICE_NAME).timer"

cron-job: update-script
	@(crontab -l 2>/dev/null | grep -vF '$(SERVICE_NAME)' || true; \
	  echo '*/5 * * * * "$(SCRIPT_PATH)/$(SCRIPT_NAME)" # $(SERVICE_NAME)') | crontab -
	@echo "Cron job installato: ogni 5 minuti"

system-job: update
	@command -v systemctl >/dev/null 2>&1 || { echo "FAIL: systemd/systemctl non disponibile" >&2; exit 1; }
	@command -v sudo >/dev/null 2>&1 || { echo "FAIL: sudo non disponibile" >&2; exit 1; }
	@sudo install -m 644 "$(SERVICE_NAME).service" "$(SYSTEMD_UNIT_DIR)/$(SERVICE_NAME).service"
	@sudo install -m 644 "$(SERVICE_NAME).timer" "$(SYSTEMD_UNIT_DIR)/$(SERVICE_NAME).timer"
	@sudo systemctl daemon-reload
	@sudo systemctl enable --now "$(SERVICE_NAME).timer"
	@echo "Systemd timer installato e attivato: ogni 5 minuti"

test:
	@command -v "$(ENVSUBST)" >/dev/null 2>&1 || { echo "FAIL: envsubst non installato" >&2; exit 1; }
	@command -v crontab >/dev/null 2>&1 || { echo "FAIL: crontab non installato" >&2; exit 1; }
	@if command -v systemctl >/dev/null 2>&1 && \
	  { systemctl is-active --quiet cron.service || systemctl is-active --quiet crond.service; }; then \
	  echo "PASS: crontab installato e servizio cron attivo"; \
	else \
	  echo "FAIL: servizio cron/crond non attivo (o systemd non disponibile)" >&2; exit 1; \
	fi
