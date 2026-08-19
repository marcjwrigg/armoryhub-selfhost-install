# Install self-hosted ArmoryHub

Configuration only — the application itself is a container image. No account, no
credentials, and no build step required to install.

## Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/marcjwrigg/armoryhub-selfhost-install/main/install.sh | sh
```

It checks Docker, generates every secret for you, pulls the image, starts
everything including HTTPS, and finishes by printing a link to approve the machine
on your Tailscale network. Nothing to edit and no keys to generate.

Read it first if you would rather not pipe a script to a shell — it is short and
does exactly what it says.

### Or manually

```bash
mkdir armoryhub && cd armoryhub
curl -fsSL https://raw.githubusercontent.com/marcjwrigg/armoryhub-selfhost-install/main/docker-compose.yml -o docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/marcjwrigg/armoryhub-selfhost-install/main/env.example -o .env
chmod 600 .env
# replace every CHANGE_ME — openssl rand -base64 32 (and 48 for AUTH_JWT_SECRET)
docker compose up -d
```

Watch it come up with `docker compose logs -f app`. It applies the database
schema and checks its own configuration before serving anything, and refuses to
start rather than start wrong — so any failure is explained in that log.

## HTTPS is required, not optional

Browsers only allow the encryption ArmoryHub depends on over HTTPS or on
`localhost`. If you reach the app by IP over plain `http://` you will be able to
sign in and then fail to unlock your data.

The installer handles this: it starts a Tailscale sidecar and prints a link. Click
it, sign in, approve the machine, and your instance is live at
`https://armoryhub.<your-tailnet>.ts.net` with a real auto-renewing certificate —
no port forwarding, no DNS record, no firewall changes.

If the link expires before you use it, get a fresh one:

```bash
docker compose exec tailscale tailscale status
```

For an unattended install, put a reusable non-ephemeral `TS_AUTHKEY` in `.env`
before running and it will register without prompting.

If you own a domain and want a public URL instead, see the Caddy section in
`env.example`. That needs a DNS record and ports 80 and 443 reachable from the
internet.

## Updating

```bash
docker compose pull
docker compose down
docker compose up -d
```

Use `down` then `up`, **not** `up -d` alone. Some Docker Compose versions replace
a container by renaming the old one and can leave it running, silently continuing
to serve the previous version.

Database changes apply automatically on start. A backup is taken first and the
upgrade aborts if that backup fails.

## Uninstalling

```bash
# deregister the Tailscale node FIRST, or a future reinstall becomes armoryhub-1
docker compose exec tailscale tailscale logout

docker compose --profile tailscale --profile tools down -v
```

`-v` deletes your database, files **and backups**. Copy anything you want to keep
off the machine first.

## Backups

A nightly backup runs automatically and keeps 7 daily plus 4 weekly copies.

```bash
docker compose --profile tools run --rm restore list
docker compose --profile tools run --rm restore once
docker compose --profile tools run --rm restore verify latest
```

To restore, stop the app first:

```bash
docker compose stop app
docker compose --profile tools run --rm restore restore <stamp>
docker compose start app
```

**Test a restore before you rely on one.** Backups live in a Docker volume on this
machine, so they do not survive the disk failing — copy them elsewhere
periodically. Their contents are already encrypted, so a cloud bucket is low-risk.

## Two different secrets

| | Protects | Recoverable? |
|---|---|---|
| **Password** | signing in | **Yes** |
| **PIN / passphrase** | your data | **No. Never.** |

Reset a forgotten password from the server, from any directory:

```bash
docker exec -it $(docker ps -q -f name=armoryhub.*app) node reset-password.js
```

Your PIN and passphrase cannot be reset or recovered by anyone, including us. They
never leave your device in a usable form — that is what makes the encryption
meaningful. If you lose both, your records are permanently unreadable. Set up a
recovery passphrase as soon as you sign in and keep it somewhere safe and offline.

---

Version: `0.1.2`
