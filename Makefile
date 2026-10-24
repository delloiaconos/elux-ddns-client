ENDPOINT ?= https://ns1-elux.ing.unibs.it:4443
UUID_FILE ?= .host_uuid

SERVICE_NAME := elux-ddns-update

SCRIPT_PATH := /usr/local/bin/
SYSTEMD_UNIT_DIR := /etc/systemd/system
SYSTEMD_SCRIPT_DIR := /usr/local/bin/

.PHONY: id cron-job system-job update-script test

id:
	@cat /proc/sys/kernel/random/uuid | tee "$(UUID_FILE)"
	@chmod 600 "$(UUID_FILE)"

update-script:
	@test -s "$(UUID_FILE)" || { echo "Esegui prima 'make id'." >&2; exit 1; }
	@uuid=$$(cat "$(UUID_FILE)"); \
	url="$(ENDPOINT)/$$uuid"; \
	printf '#!/bin/sh\n\nwget -q --no-check-certificate "%s" -O /dev/null\n' "$$url" > "$(SERVICE_NAME).sh"
	@chmod 700 "$(SERVICE_NAME).sh"

cron-job: update-script
	@(crontab -l 2>/dev/null | grep -vF '$(SERVICE_NAME)' || true; \
	  echo '*/5 * * * * $(SCRIPT_PATH) # $(SERVICE_NAME)') | crontab -
	@echo "Cron job installato: ogni 5 minuti"

system-job: update-script
	@command -v systemctl >/dev/null 2>&1 || { echo "FAIL: systemd/systemctl non disponibile" >&2; exit 1; }
	@command -v sudo >/dev/null 2>&1 || { echo "FAIL: sudo non disponibile" >&2; exit 1; }
	@sudo install -m 700 "$(SERVICE_NAME).sh" "$(SYSTEMD_SCRIPT_DIR)/$(SERVICE_NAME)"
	@sudo install -m 644 "$(SERVICE_NAME).service" "$(SYSTEMD_UNIT_DIR)/$(SERVICE_NAME).service"
	@sudo install -m 644 "$(SERVICE_NAME).timer" "$(SYSTEMD_UNIT_DIR)/$(SERVICE_NAME).timer"
	@sudo systemctl daemon-reload
	@sudo systemctl enable --now "$(SERVICE_NAME).timer"
	@echo "Systemd timer installato e attivato: ogni 5 minuti"

test:
	@command -v crontab >/dev/null 2>&1 || { echo "FAIL: crontab non installato" >&2; exit 1; }
	@if command -v systemctl >/dev/null 2>&1 && \
	  { systemctl is-active --quiet cron.service || systemctl is-active --quiet crond.service; }; then \
	  echo "PASS: crontab installato e servizio cron attivo"; \
	else \
	  echo "FAIL: servizio cron/crond non attivo (o systemd non disponibile)" >&2; exit 1; \
	fi
