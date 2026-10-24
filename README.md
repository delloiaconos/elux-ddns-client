# Elux Dynamic DNS Client Scripts

Minimal client that updates a DNS record managed by sftdyn every 5 minutes, using cron or a systemd timer.

Requires `make`, `wget`, and `envsubst` (GNU gettext), plus cron or systemd for scheduling.

Generate a host identifier:

```sh
make id
```

Send the UUID to the DNS administrator to associate it with the desired hostname.

Choose one scheduling method. Install a cron job for the current user:

```sh
make cron-job
```

Or install and enable the system-wide systemd timer (requires `sudo`):

```sh
make system-job
```

`make update` generates the script and systemd units in `temp/`. Both scheduling commands run this step automatically, then move the required files into place. The script destination is `/usr/local/bin` by default; use `SCRIPT_PATH=/path/to/bin` to change it. For cron installation, this directory must be writable by the current user.

The default endpoint is `https://dns.example.it:4443`. To use a different server:

```sh
ENDPOINT=https://ns1-elux.ing.unibs.it:4443 make cron-job
```

Run `make test` for a PASS/FAIL report on dependencies and scheduling. Checks for the unused scheduling method may report FAIL; the command always exits successfully.

Run `make uninstall` to remove the cron job, systemd units, and update script. Use the same path and name overrides as during installation. The host UUID is preserved.

Run `make clean` to remove generated files from `temp/`, preserving installed files, templates, and the host UUID.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).
