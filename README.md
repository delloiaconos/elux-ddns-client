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

The script is saved in `/usr/local/bin` by default. This directory must be writable; use `make SCRIPT_PATH=/path/to/bin cron-job` to choose another location.

The default endpoint is `https://dns.example.it:4443`. To use a different server:

```sh
ENDPOINT=https://ns1-elux.ing.unibs.it:4443 make cron-job
```

Run `make test` for a PASS/FAIL report on dependencies and scheduling. Checks for the unused scheduling method may report FAIL; the command always exits successfully.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).
