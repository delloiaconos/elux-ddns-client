ENDPOINT ?= https://ns1-elux.ing.unibs.it:4443
UUID_FILE ?= .host_uuid
SCRIPT ?= dyn-update.sh
SCRIPT_PATH := $(abspath $(SCRIPT))
CRON_MARKER := sftdyn-client

.PHONY: id job test

id:
	@cat /proc/sys/kernel/random/uuid | tee "$(UUID_FILE)"
	@chmod 600 "$(UUID_FILE)"

job:
	@test -s "$(UUID_FILE)" || { echo "Esegui prima 'make id'." >&2; exit 1; }
	@uuid=$$(cat "$(UUID_FILE)"); \
	url="$(ENDPOINT)/$$uuid"; \
	printf '#!/bin/sh\n\nwget -q --no-check-certificate "%s" -O /dev/null\n' "$$url" > "$(SCRIPT)"
	@chmod 700 "$(SCRIPT)"
	@(crontab -l 2>/dev/null | grep -vF '$(CRON_MARKER)' || true; \
	  echo '*/5 * * * * $(SCRIPT_PATH) # $(CRON_MARKER)') | crontab -
	@echo "Job installato: ogni 5 minuti"

test:
	@command -v crontab >/dev/null 2>&1 || { echo "FAIL: crontab non installato" >&2; exit 1; }
	@if command -v systemctl >/dev/null 2>&1 && \
	  { systemctl is-active --quiet cron.service || systemctl is-active --quiet crond.service; }; then \
	  echo "PASS: crontab installato e servizio cron attivo"; \
	else \
	  echo "FAIL: servizio cron/crond non attivo (o systemd non disponibile)" >&2; exit 1; \
	fi
