# sftdyn client

Minimal client for periodically updating a DNS record managed by sftdyn.

```sh
make id
```

Copy the UUID and ask the DNS administrator to associate it with the desired hostname in `/etc/sftdyn/clientlist`.

Choose one of the scheduling methods. The default endpoint is `https://ns1-elux.ing.unibs.it:4443`; override it with the `ENDPOINT` environment variable.

Install a cron job in the current user's crontab:

```sh
ENDPOINT=https://dns.example.it:4443 make cron-job
```

Or install and enable the system-wide systemd timer (requires `sudo`):

```sh
ENDPOINT=https://dns.example.it:4443 make system-job
```

Both modes save the update script in `$(SCRIPT_PATH)/$(SCRIPT_NAME)` (by default `/usr/local/bin/elux-ddns-update.sh`). The script directory must be writable by the user running make; override it with `make SCRIPT_PATH=/path/to/bin` if needed. The systemd mode also installs the service and timer units in `/etc/systemd/system`.

Both methods run every 5 minutes. `make id` saves the UUID in `.host_uuid`; the generated update script embeds the selected endpoint and UUID. Generating files requires `envsubst` (GNU gettext).

`make update` renders the script and the `.service` and `.timer` units from the `.in` templates using `envsubst`. The Makefile exports the template variables to the environment and reads `UUID` from `UUID_FILE` for the script. Only the explicitly listed variables are substituted, preserving any other shell variables in the templates. The script is saved in `$(SCRIPT_PATH)/$(SCRIPT_NAME)` and the units in the current directory. `cron-job` generates the script; `system-job` generates all three files before installing the units.

For cron mode, run `make test` to verify that the `envsubst` and `crontab` commands are installed and the `cron` or `crond` systemd service is active. It does not modify the crontab.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).
