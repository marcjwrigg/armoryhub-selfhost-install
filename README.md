# Install self-hosted ArmoryHub

Configuration only. The application itself is a private container image — you will
need the registry credentials supplied with your licence.

## Install

```bash
mkdir armoryhub && cd armoryhub

curl -fsSL https://raw.githubusercontent.com/marcjwrigg/armoryhub-selfhost-install/main/docker-compose.yml -o docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/marcjwrigg/armoryhub-selfhost-install/main/env.example -o .env
chmod 600 .env
```

Edit `.env` and replace every `CHANGE_ME`. Generate each value with:

```bash
openssl rand -base64 32          # passwords
openssl rand -base64 48          # AUTH_JWT_SECRET
```

Then sign in to the registry and start it:

```bash
docker login ghcr.io             # credentials from your licence
docker compose up -d
```

Watch it come up with `docker compose logs -f app`. It applies the database
schema and checks its own configuration before serving anything, and refuses to
start rather than start wrong — so any failure is explained in that log.

## HTTPS is required, not optional

Browsers only allow the encryption ArmoryHub depends on over HTTPS or on
`localhost`. If you reach the app by IP over plain `http://` you will be able to
sign in and then fail to unlock your data.

The simplest route gives ArmoryHub its own name on your private Tailscale network,
with a real certificate, no port forwarding and no DNS setup:

```bash
# add TS_AUTHKEY to .env — https://login.tailscale.com/admin/settings/keys
docker compose --profile tailscale up -d
```

Then open `https://armoryhub.<your-tailnet>.ts.net`.

If you own a domain and want a public URL, see the Caddy section in `env.example`.
That needs a DNS record and ports 80 and 443 reachable from the internet.

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

Version: `0.1.0`
