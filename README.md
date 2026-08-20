# Install self-hosted ArmoryHub

Configuration only — the application itself is a container image. No account, no
credentials, and no build step required to install.

## What you need

**A machine that stays on, running Linux.** A NAS, a mini PC, or an old laptop is
plenty. Both 64-bit Intel/AMD (`amd64`) and 64-bit ARM (`arm64`) are supported, so
a Raspberry Pi 4 or 5 works.

| | Minimum | Comfortable |
|---|---|---|
| Memory | 1 GB free | 2 GB free |
| Disk | 3 GB, plus room for your photos | 10 GB+ |
| CPU | any 64-bit dual core | — |

The install itself downloads roughly 150 MB. Photos are the only thing that grows
much over time — budget for the size of your existing photo library, plus room for
backups, which keep 7 daily and 4 weekly copies.

**Docker, with the Compose plugin.** If this prints a version, you are ready:

```bash
docker compose version
```

Compose **v2.23 or newer** is required. Older versions cannot read the setup scripts
embedded in `docker-compose.yml` and fail with a confusing error about `configs`.
If you need to install Docker, follow
<https://docs.docker.com/engine/install/> and then
<https://docs.docker.com/engine/install/linux-postinstall/> so you can use Docker
without `sudo`.

**A free Tailscale account**, at <https://tailscale.com>. This is how you get HTTPS,
which is not optional — see below.

**You do not need** a domain name, a static IP, port forwarding, any firewall
changes, or root access beyond installing Docker itself. Nothing is exposed to the
internet.

## Install (one command)

```bash
curl -fsSL https://armoryhub.app/install.sh | sh
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

### Last step: point your dashboard at the HTTPS address

**If you installed through CasaOS, Portainer, Dockge or anything else with an "open
app" button, you must update that address by hand once Tailscale is approved.** Set
the app's **Web UI** / URL setting to your full Tailscale address:

```
https://armoryhub.<your-tailnet>.ts.net
```

Until you do, the button opens `http://<server-ip>:8477` — the one address the app
cannot work on. You will be able to sign in and then fail to set or enter your PIN,
because browsers withhold Web Crypto from insecure origins.

No dashboard can fill this in for you, for two reasons: the app binds to
`127.0.0.1` deliberately, so it is not reachable over your LAN and there is nothing
for the dashboard to detect; and the Tailscale hostname does not exist yet at the
moment the compose file is first parsed.

### Using your own reverse proxy instead of Tailscale

If you already run nginx, Caddy, Traefik or similar and want to use your own
certificates, you don't need Tailscale at all.

**1. Let your proxy reach the app.** Which option applies depends on where the proxy
runs:

| Your proxy | What to do |
|---|---|
| Same host, host network mode | Nothing — `http://127.0.0.1:8477` already works |
| Docker bridge network, or another machine | Set `APP_BIND=0.0.0.0` in `.env` |
| Attached to this stack's network | Target `app:3000` and publish nothing at all |

The app binds to `127.0.0.1` by default on purpose, so it is not reachable from your
LAN. `APP_BIND=0.0.0.0` removes that protection and serves an unencrypted login page
to your whole network — only set it with a TLS-terminating proxy in front.

**2. Set your address:** `APP_URL=https://armory.example.com` in `.env`.

**3. Turn off the Tailscale sidecar**, or it will keep starting unused:

```bash
sed -i 's/^COMPOSE_PROFILES=.*/COMPOSE_PROFILES=/' .env
```

**4. Terminate TLS at the proxy.** Browsers only allow the encryption ArmoryHub needs
over HTTPS or on `localhost`, so reaching it by plain `http://` at a LAN address will
let you sign in and then fail to unlock your data.

### Where to install it — important on NAS hardware

The database lives in `./data/postgres`, next to the compose file. **Put it on
ordinary local storage.**

Do not put it on a FUSE mount or a network share. On Unraid, that means installing to
a cache-backed path rather than a user share: `/mnt/user/...` goes through shfs
(FUSE), and Postgres on FUSE risks locking errors and database corruption. The same
applies to NFS, SMB and similar.

```bash
curl -fsSL https://armoryhub.app/install.sh | ARMORYHUB_DIR=/mnt/cache/appdata/armoryhub sh
```

Note the variable goes **after** the pipe, so it applies to the shell running the
script rather than to `curl`.

## Installing it as an app on your phone and computer

ArmoryHub installs to your home screen or dock and then behaves like any other app —
its own icon, its own window, no browser chrome. There is nothing to download from an
app store.

**First, on each device you want to use it from:** install Tailscale from your app
store, sign in to the same account, and make sure it is connected. Your instance
lives on your private network, so the address only resolves while Tailscale is on. If
the page will not load, that is almost always the reason.

Then open `https://armoryhub.<your-tailnet>.ts.net` and:

**iPhone or iPad** — use **Safari**. Tap the Share button (the square with an arrow
pointing up), scroll down, tap **Add to Home Screen**, then **Add**. Other browsers
on iOS can make a shortcut, but only Safari installs it as a real app.

**Android** — use **Chrome**. Tap the three-dot menu, then **Install app** (some
versions say *Add to Home screen*), then confirm.

**Windows or Linux desktop** — in **Chrome** or **Edge**, click the install icon at
the right-hand end of the address bar, then **Install**. If you do not see it, the
three-dot menu has the same option.

**Mac** — in **Safari**, choose **File → Add to Dock**. In Chrome or Edge, use the
install icon in the address bar as above.

Launch it from your home screen or dock afterwards. It keeps you signed in, so you
only need your PIN. Remember that Tailscale has to be connected for it to load —
worth knowing before you rely on it at a range with no signal.

## Running under CasaOS, Portainer or Dockge

The compose file works in any of them, but **CasaOS rewrites it when you save
anything through its settings form**, including when you set the Web UI address.
Measured on a real install, saving once:

- **removes the `tailscale`, `restore` and `caddy` services**, because CasaOS does
  not understand Compose profiles and drops what it cannot model. Containers already
  running keep running, so nothing appears wrong — but `docker compose` can no longer
  start or restart Tailscale, and reports `no such service: tailscale`.
- **converts `$$` to `$`**, so the embedded database setup would run with an empty
  username on a fresh install.
- **copies your passwords out of `.env` into the compose file**, which is
  world-readable, while `.env` is not.

None of that breaks a running instance, which is why it goes unnoticed. It bites
later, when something needs restarting.

**The safest arrangement is to run this from a terminal** and, if you want a tile on
the CasaOS dashboard, add it as an **external link** to your `https://...ts.net`
address rather than importing the compose file. You get the icon and the click-through
with CasaOS having no authority over the configuration.

If you do let CasaOS manage it, keep a copy of the original compose file. CasaOS moves
what it replaces to `docker-compose.yml.bak`, owned by root.

## Updating

```bash
docker compose pull
docker compose down
docker compose up -d
docker compose ps          # expect: app, db, backup, tailscale
```

Use `down` then `up`, **not** `up -d` alone. Some Docker Compose versions replace
a container by renaming the old one and can leave it running, silently continuing
to serve the previous version.

Database changes apply automatically on start. A backup is taken first and the
upgrade aborts if that backup fails.

### If your HTTPS address stops working after an upgrade

Check `docker compose ps` includes **tailscale**. If it does not, that is why: the
address resolves to nothing, which in a browser looks like a blank page with an empty
console rather than an error.

Tailscale is an optional service, so it only starts when Compose is told to include
it. Once it has stopped for any reason, a plain `up -d` leaves it down.

```bash
grep COMPOSE_PROFILES .env || echo 'COMPOSE_PROFILES=tailscale' >> .env
docker compose up -d
```

That line makes every future `up -d` include it. Installs created by `install.sh`
have it already. Set it to `caddy` instead if you use a public domain.

## Uninstalling

```bash
# Sign out of Tailscale FIRST, or a future reinstall appears as armoryhub-1
docker compose exec tailscale tailscale logout

docker compose --profile tailscale --profile tools down
```

That stops and removes the containers. **Your data is still there**, in the `data`
directory next to `docker-compose.yml`, and `docker compose up -d` brings it all
back.

To delete your data as well, remove that directory yourself:

```bash
rm -rf ./data
```

There is no undo, and that includes your backups. Copy anything you want to keep off
the machine first.

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

**Test a restore before you rely on one.** Backups are written to `./data/backups`
as ordinary files, so copy them off this machine periodically — a backup on the same
disk does not survive that disk failing. Their contents are already encrypted, so
cloud storage is low-risk.

## Two different secrets

| | Protects | Recoverable? |
|---|---|---|
| **Password** | signing in | **Yes** |
| **PIN** | your data | **No. Never.** |
| **Passphrase** | your data on a new device | **No. Never.** |

Reset a forgotten password from the server, from any directory:

```bash
docker exec -it $(docker ps -q -f name=armoryhub.*app) node reset-password.js
```

**Your PIN cannot be reset or recovered by anyone, including us, and the passphrase
is not a way around that.** Neither ever leaves your device in a usable form, which
is what makes the encryption meaningful.

The two are not alternatives. The passphrase exists so you can set ArmoryHub up on a
**new device** — you enter the passphrase, then your existing PIN. It is insurance
against losing a device, not against forgetting your PIN.

So: **write your PIN down too**, and keep both somewhere safe and offline. If you
forget your PIN, your records cannot be decrypted, passphrase or not.

## Useful commands

Run these from your install directory (`~/armoryhub` unless you changed it).

**Everyday**

```bash
docker compose ps                      # expect four: app, db, backup, tailscale
docker compose logs -f app             # what the app is doing, live
docker compose restart app             # after an .env change
docker compose images app              # which version is actually running
```

**HTTPS and Tailscale**

```bash
docker compose exec tailscale tailscale status         # is the node connected?
docker compose exec tailscale tailscale serve status   # is it proxying to the app?
docker compose exec tailscale tailscale cert <your-full-domain>   # force a certificate
docker compose logs tailscale | grep -i cert           # why a certificate failed
```

`tailscale cert` is the one to reach for when the page is blank: it prints the real
error, where the browser just shows you nothing.

**Backups**

```bash
docker compose --profile tools run --rm restore list
docker compose --profile tools run --rm restore once
docker compose --profile tools run --rm restore verify latest

docker compose stop app
docker compose --profile tools run --rm restore restore <stamp>
docker compose start app
```

**Diagnosing**

```bash
docker compose config --quiet          # exit 0 means the compose file is valid
sudo du -sh data/*                     # what is using space (sudo: postgres is root-owned)
docker exec -it $(docker ps -q -f name=armoryhub.*app) node reset-password.js
```

**Install-time options**

Both go *after* the pipe, so they apply to the shell running the script rather than to
`curl`:

```bash
# Install somewhere other than ~/armoryhub — use this on a NAS to keep the
# database off a FUSE user share
curl -fsSL https://armoryhub.app/install.sh | ARMORYHUB_DIR=/mnt/cache/appdata/armoryhub sh

# Choose the name on your private network (default: armoryhub)
curl -fsSL https://armoryhub.app/install.sh | ARMORYHUB_TS_HOSTNAME=armory sh
```

Certificates are rate-limited per hostname — five per week — so if you have reinstalled
several times and HTTPS has stopped working, a fresh name gets a certificate
immediately.

---

Version: `0.1.5`
