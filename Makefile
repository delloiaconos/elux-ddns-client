ENDPOINT ?= https://dns.example.it:4443
UUID_FILE ?= .host_uuid
ENVSUBST ?= envsubst

SERVICE_NAME := elux-ddns
SCRIPT_NAME := $(SERVICE_NAME)-update.sh
SCRIPT_PATH := /usr/local/bin
SYSTEMD_UNIT_DIR := /etc/systemd/system
export SERVICE_NAME SCRIPT_PATH SCRIPT_NAME ENDPOINT

.PHONY: id cron-job system-job update update-script update-units uninstall clean test

id:
	@cat /proc/sys/kernel/random/uuid | tee "$(UUID_FILE)"
	@chmod 600 "$(UUID_FILE)"

update: update-script update-units

update-script: elux-ddns-update.sh.in
	@test -s "$(UUID_FILE)" || { echo "Run 'make id' first." >&2; exit 1; }
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
	@echo "Cron job installed: every 5 minutes"

system-job: update
	@sudo install -m 644 "$(SERVICE_NAME).service" "$(SYSTEMD_UNIT_DIR)/$(SERVICE_NAME).service"
	@sudo install -m 644 "$(SERVICE_NAME).timer" "$(SYSTEMD_UNIT_DIR)/$(SERVICE_NAME).timer"
	@sudo systemctl daemon-reload
	@sudo systemctl enable --now "$(SERVICE_NAME).timer"
	@echo "Systemd timer installed and activated: every 5 minutes"

uninstall:
	@entries=$$(crontab -l 2>/dev/null) && \
	  printf '%s\n' "$$entries" | \
	    awk -v marker='# $(SERVICE_NAME)' 'substr($$0, length($$0) - length(marker) + 1) != marker' | \
	    crontab - || true
	@sudo systemctl disable --now "$(SERVICE_NAME).timer" 2>/dev/null || true
	@sudo systemctl stop "$(SERVICE_NAME).service" 2>/dev/null || true
	@sudo rm -f -- "$(SYSTEMD_UNIT_DIR)/$(SERVICE_NAME).service" \
	  "$(SYSTEMD_UNIT_DIR)/$(SERVICE_NAME).timer" 2>/dev/null || true
	@sudo systemctl daemon-reload 2>/dev/null || true
	@rm -f -- "$(SCRIPT_PATH)/$(SCRIPT_NAME)" 2>/dev/null || \
	  sudo rm -f -- "$(SCRIPT_PATH)/$(SCRIPT_NAME)" 2>/dev/null || true
	@rm -f -- "$(SERVICE_NAME).service" "$(SERVICE_NAME).timer" 2>/dev/null || true
	@echo "Uninstall completed"

clean:
	@rm -f -- "$(SCRIPT_NAME)" "$(SERVICE_NAME).service" "$(SERVICE_NAME).timer"
	@echo "Local generated files removed"

test:
	@echo "$$(command -v "$(ENVSUBST)" >/dev/null 2>&1 && echo PASS || echo FAIL): envsubst installed"
	@echo "$$(command -v crontab >/dev/null 2>&1 && echo PASS || echo FAIL): crontab installed"
	@echo "$$(command -v sudo >/dev/null 2>&1 && echo PASS || echo FAIL): sudo installed"
	@echo "$$(systemctl show --property=Version --value >/dev/null 2>&1 && echo PASS || echo FAIL): systemd reachable through systemctl"
	@echo "$$( { systemctl is-active --quiet cron.service || systemctl is-active --quiet crond.service; } >/dev/null 2>&1 && echo PASS || echo FAIL): cron/crond service active"
	@echo "$$(systemctl is-enabled --quiet "$(SERVICE_NAME).timer" >/dev/null 2>&1 && echo PASS || echo FAIL): timer $(SERVICE_NAME).timer enabled"
	@echo "$$(systemctl is-active --quiet "$(SERVICE_NAME).timer" >/dev/null 2>&1 && echo PASS || echo FAIL): timer $(SERVICE_NAME).timer active"
