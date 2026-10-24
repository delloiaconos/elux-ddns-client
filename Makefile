ENDPOINT ?= https://dns.example.it:4443

SERVICE_NAME := elux-ddns
SCRIPT_NAME := $(SERVICE_NAME)-update.sh
SCRIPT_PATH := /usr/local/bin
SYSTEMD_UNIT_DIR := /etc/systemd/system
UUID_FILE ?= .host_uuid
TEMP_DIR ?= temp

GENERATED_FILES := $(TEMP_DIR)/$(SCRIPT_NAME) \
	$(TEMP_DIR)/$(SERVICE_NAME).service \
	$(TEMP_DIR)/$(SERVICE_NAME).timer
TEMPLATE_FILES := elux-ddns-update.sh.in elux-ddns.service.in elux-ddns.timer.in

export SERVICE_NAME SCRIPT_PATH SCRIPT_NAME ENDPOINT

.PHONY: id cron-job system-job update uninstall clean test

id:
	@cat /proc/sys/kernel/random/uuid | tee "$(UUID_FILE)"
	@chmod 600 "$(UUID_FILE)"

update: $(GENERATED_FILES)

$(GENERATED_FILES) &: $(TEMPLATE_FILES) $(UUID_FILE)
	@test -s "$(UUID_FILE)" || { echo "Run 'make id' first." >&2; exit 1; }
	@mkdir -p "$(TEMP_DIR)"
	@UUID=$$(cat "$(UUID_FILE)") envsubst '$${ENDPOINT} $${UUID}' < elux-ddns-update.sh.in > "$(TEMP_DIR)/$(SCRIPT_NAME)"
	@chmod 700 "$(TEMP_DIR)/$(SCRIPT_NAME)"
	@envsubst '$${SCRIPT_PATH} $${SCRIPT_NAME}' < elux-ddns.service.in > "$(TEMP_DIR)/$(SERVICE_NAME).service"
	@envsubst '$${SERVICE_NAME}' < elux-ddns.timer.in > "$(TEMP_DIR)/$(SERVICE_NAME).timer"
	@chmod 644 "$(TEMP_DIR)/$(SERVICE_NAME).service" "$(TEMP_DIR)/$(SERVICE_NAME).timer"

cron-job: update
	@mkdir -p "$(SCRIPT_PATH)"
	@mv -- "$(TEMP_DIR)/$(SCRIPT_NAME)" "$(SCRIPT_PATH)/$(SCRIPT_NAME)"
	@(crontab -l 2>/dev/null | grep -vF '$(SERVICE_NAME)' || true; \
	  echo '*/5 * * * * "$(SCRIPT_PATH)/$(SCRIPT_NAME)" # $(SERVICE_NAME)') | crontab -
	@echo "Cron job installed: every 5 minutes"

system-job: update
	@sudo mkdir -p "$(SCRIPT_PATH)" "$(SYSTEMD_UNIT_DIR)"
	@sudo mv -- "$(TEMP_DIR)/$(SCRIPT_NAME)" "$(SCRIPT_PATH)/$(SCRIPT_NAME)"
	@sudo mv -- "$(TEMP_DIR)/$(SERVICE_NAME).service" "$(SYSTEMD_UNIT_DIR)/$(SERVICE_NAME).service"
	@sudo mv -- "$(TEMP_DIR)/$(SERVICE_NAME).timer" "$(SYSTEMD_UNIT_DIR)/$(SERVICE_NAME).timer"
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
	@rm -f -- "$(TEMP_DIR)/$(SCRIPT_NAME)" "$(TEMP_DIR)/$(SERVICE_NAME).service" "$(TEMP_DIR)/$(SERVICE_NAME).timer" 2>/dev/null || true
	@echo "Uninstall completed"

clean:
	@rm -f -- "$(TEMP_DIR)/$(SCRIPT_NAME)" "$(TEMP_DIR)/$(SERVICE_NAME).service" "$(TEMP_DIR)/$(SERVICE_NAME).timer"
	@rmdir -- "$(TEMP_DIR)" 2>/dev/null || true
	@echo "Local generated files removed"

test:
	@echo "$$(command -v envsubst >/dev/null 2>&1 && echo PASS || echo FAIL): envsubst installed"
	@echo "$$(command -v crontab >/dev/null 2>&1 && echo PASS || echo FAIL): crontab installed"
	@echo "$$(command -v sudo >/dev/null 2>&1 && echo PASS || echo FAIL): sudo installed"
	@echo "$$(systemctl show --property=Version --value >/dev/null 2>&1 && echo PASS || echo FAIL): systemd reachable through systemctl"
	@echo "$$( { systemctl is-active --quiet cron.service || systemctl is-active --quiet crond.service; } >/dev/null 2>&1 && echo PASS || echo FAIL): cron/crond service active"
	@echo "$$(systemctl is-enabled --quiet "$(SERVICE_NAME).timer" >/dev/null 2>&1 && echo PASS || echo FAIL): timer $(SERVICE_NAME).timer enabled"
	@echo "$$(systemctl is-active --quiet "$(SERVICE_NAME).timer" >/dev/null 2>&1 && echo PASS || echo FAIL): timer $(SERVICE_NAME).timer active"
