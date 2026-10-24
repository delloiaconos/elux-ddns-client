# sftdyn client

Minimal client for periodically updating a DNS record managed by sftdyn.

```sh
make id
```

Copy the UUID and ask the DNS administrator to associate it with the desired hostname in `/etc/sftdyn/clientlist`.

```sh
make job
```

Installs an update every 5 minutes in the current user's crontab. The default endpoint is `https://ns1-elux.ing.unibs.it:4443`; override it with the `ENDPOINT` environment variable:

```sh
ENDPOINT=https://dns.example.it:4443 make job
```

`make id` saves the UUID in `.host_uuid`. `make job` generates `dyn-update.sh` with the endpoint and UUID embedded in the script; both files are local to the client.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).
