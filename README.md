# Install self-hosted ArmoryHub

Configuration only — the application itself is a container image. No account, no
credentials, and no build step required to install.

## Contents

- [What you need](#what-you-need)
- [Install (one command)](#install-one-command)
- [Install-time options](#install-time-options)
- [HTTPS is required, not optional](#https-is-required-not-optional)
- [The armoryhub command](#the-armoryhub-command)
- [Updating](#updating)
- [Backups](#backups)
- [Uninstalling](#uninstalling)
- [Your password, PIN and passphrase](#your-password-pin-and-passphrase)
- [Installing it as an app on your phone and computer](#installing-it-as-an-app-on-your-phone-and-computer)
- [Running under CasaOS, Portainer or Dockge](#running-under-casaos-portainer-or-dockge)
- [Moving an existing hosted account across](#moving-an-existing-hosted-account-across)

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

**Docker, with the Compose plugin.** Both of these must work **as your normal user**,
without `sudo`:

```bash
docker ps
docker compose version
```

If `docker ps` gives you a permission error on `/var/run/docker.sock`, your user is not
in the `docker` group yet. That catches most people on a fresh server:

```bash
sudo usermod -aG docker $USER
```

Then log out and back in — the group change does not apply to your current session.

Compose **v2.23 or newer** is required. Older versions cannot read the setup scripts
embedded in `docker-compose.yml` and fail with a confusing error about `configs`.
If Docker is not installed yet, follow
<https://docs.docker.com/engine/install/>.

**A free Tailscale account**, at <https://tailscale.com>.

If you have not used Tailscale before: it is a private network that links your own
devices together, wherever they are. ArmoryHub uses it for two things — reaching your
instance from your phone or laptop without exposing anything to the internet, and
getting a real HTTPS certificate for it. HTTPS is not optional here, and this is by
far the easiest way to get it. You can use your own reverse proxy and certificates
instead if you prefer.

**You will also need the Tailscale app on every device you want to use ArmoryHub
from** — your phone, your laptop, anything else — signed in to the same account. Your
instance lives on that private network, so its address only resolves on devices that
have joined it. Nothing loads without it, which surprises people who set the server up
and then try to open it on a phone that is not connected yet.

See [Installing it as an app on your phone and
computer](#installing-it-as-an-app-on-your-phone-and-computer) for the per-device
steps.

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

## Install-time options

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

### Last step: use the HTTPS address, and bookmark it

Once Tailscale is approved, your instance lives at:

```
https://armoryhub.<your-tailnet>.ts.net
```

**Bookmark that.** It is the address to use from every device.

If you run a dashboard like CasaOS, its "open app" button will point at
`http://<server-ip>:8477` instead — the one address the app cannot work on. You will be
able to sign in and then fail to set or enter your PIN, because browsers withhold Web
Crypto from insecure origins. No dashboard can detect the right address for you: the app
binds to `127.0.0.1` deliberately, so there is nothing on your LAN to find, and the
Tailscale hostname does not exist when the compose file is first read.

**On CasaOS, do not fix this by editing the app's Web UI setting.** Saving that form
rewrites your compose file and deletes the `tailscale`, `restore` and `caddy` services —
see the CasaOS section below. Ignore the button and use your bookmark. If you would
rather have a working tile and accept the rewrite, the workaround is documented there
too.

### If it loads on your phone but not your computer

**Check whether another VPN is running on that device.** A second VPN client will
happily route around Tailscale, and the way it fails is genuinely misleading: Tailscale
itself keeps working, so

```bash
tailscale ping armoryhub
```

still gets replies and everything looks reachable — while connections to port 443 quietly
fail. It reads as a broken certificate or a server problem, and you can lose an evening
to it.

The quickest way to identify it: try the same address from your phone on mobile data. If
the phone works and the desktop does not, the problem is on the desktop, not the server.

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

### The dashboard app icon

Nothing to do here — this is just so the behaviour is not surprising.

The compose file ships with a small icon embedded directly in it, because at the time
it is published nobody knows what your machine will be called. Once Tailscale
registers, the installer replaces that with the full-size icon your own instance
serves:

```yaml
  icon: https://armory.your-tailnet.ts.net/apple-touch-icon.png
```

Either way the image comes from your own network and nothing is fetched from us or
from GitHub — a linked icon would break on an air-gapped network and would tell a third
party that this machine runs ArmoryHub.

Two consequences worth knowing:

- **Re-downloading `docker-compose.yml` resets it** to the embedded copy. Harmless, and
  the next install run puts it back.
- **Changing your Tailscale hostname breaks it**, because the URL is baked in. Edit that
  one line, or replace it with the embedded copy from a fresh download.

If you use your own reverse proxy rather than Tailscale, the embedded icon is kept and
needs no address at all.

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

## The armoryhub command

The installer sets up an `armoryhub` command. Use it in preference to `docker compose`:
it reads Docker directly, so it keeps working even if a dashboard has rewritten your
compose file.

```bash
armoryhub doctor            # check everything and say what is wrong
armoryhub status            # what is running
armoryhub logs [service]    # follow logs, default: app
armoryhub url               # the address to open
armoryhub backup list       # what backups exist
armoryhub backup now        # take one immediately
armoryhub backup verify latest
armoryhub restore <stamp>   # asks for confirmation, stops and restarts the app
armoryhub password          # reset the account password
armoryhub update            # pull and restart
```

**`armoryhub doctor` is the one to run when something is wrong.** It checks the
containers, whether the app answers, whether HTTPS actually works end to end, whether
your compose file has been rewritten, whether the database is on storage that will
corrupt it, free space, and backup age — and tells you what to do about each.

If `armoryhub` says "command not found", the installer could not write to
`/usr/local/bin` — it needs sudo, which it will not use unattended. The helper is in
your install directory instead, so either run it from there:

```bash
~/armoryhub/armoryhub doctor
```

or put it on your PATH once:

```bash
sudo install -m 755 ~/armoryhub/armoryhub /usr/local/bin/armoryhub
```

After that, `armoryhub` works from any directory.

### Doing it with docker compose instead

These work too, from your install directory (`~/armoryhub` unless you changed it).
Anything with `--profile` will fail if a dashboard has rewritten the file.

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

## Updating

```bash
armoryhub update
```

That pulls the new image, restarts everything, and updates the `armoryhub` command
itself. A backup is taken before any database changes are applied, and the upgrade
aborts if that backup fails.

Check afterwards with `armoryhub doctor`.

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

## Backups

A nightly backup runs automatically and keeps 7 daily plus 4 weekly copies.

```bash
armoryhub backup list
armoryhub backup now
armoryhub backup verify latest
```

To restore — this replaces your current data, and asks you to confirm first:

```bash
armoryhub restore <stamp>
```

**Test a restore before you rely on one.** Backups are written to `./data/backups` as
ordinary files, so copy them off this machine periodically — a backup on the same disk
does not survive that disk failing. Their contents are already encrypted, so cloud
storage is low-risk.

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

## Your password, PIN and passphrase

| | Protects | Required? | Recoverable? |
|---|---|---|---|
| **Password** | signing in | yes | **Yes** |
| **PIN** | decrypting your data | always | **No. Never.** |
| **Passphrase** | the copy of your key held on this server | optional | **No. Never.** |

Reset a forgotten password:

```bash
armoryhub password
```

**Your PIN decrypts your data, and nobody can reset or recover it — including us.** It
never leaves your device in a usable form, which is what makes the encryption
meaningful. Forget it and your records are permanently unreadable.

**A passphrase is optional, and it is not a backup for the PIN.** What it does is raise
the entropy of the key material this server holds. Without one, the copy stored here is
protected by a six-digit PIN, which is weak against anyone who obtains the database.
With one, the server holds a copy protected by something far stronger.

If you set a passphrase, it is also required — **together with your PIN** — to set up
ArmoryHub on another device. That follows from where the key is protected; it is not
the reason for having one.

So: write your PIN down, write your passphrase down if you set one, and keep both
somewhere safe and offline.
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

### Working around it without a fight

If you want to keep CasaOS managing the app, keep a second, pristine copy of the
compose file under a name CasaOS does not touch, and use it for anything involving
profiles:

```bash
cd ~/armoryhub
curl -fsSL https://raw.githubusercontent.com/marcjwrigg/armoryhub-selfhost-install/main/docker-compose.yml   -o compose-full.yml

docker compose -f compose-full.yml --profile tools run --rm --no-deps restore list
docker compose -f compose-full.yml --profile tailscale up -d
```

The project name comes from the directory, so this attaches to the same containers,
network and data as usual — it is the same stack, just described by a file CasaOS has
not edited. `--no-deps` stops Compose recreating your database because the two files
disagree.

Symptom that tells you CasaOS has rewritten the file: `no such service: restore` or
`no such service: tailscale`, while the containers are visibly running.


## Moving an existing hosted account across

Your data comes over as a single encrypted archive. Nothing is re-encrypted, and no
key ever travels in a form anyone could use.

**1. On hosted:** Settings → Data Management → Export Data. You get a `.zip`.

**2. On your instance:** Settings → Data Management → Import Data, and select that file.

Before it changes anything, it shows you which account the archive came from, when it
was exported, how many records and files it contains, whether the account had a
passphrase, and how many records a replace would remove. You have to tick a box
acknowledging that before it will proceed.

**3. Unlock with the secret from your HOSTED account** — not the PIN you just set up
here. The app reloads and asks for it.

### Which secret you need, and why

This is worth reading before you start, because the answer differs depending on how
your hosted account was set up.

The archive carries your master key **wrapped**, along with the salts needed to derive
the key that unwraps it. The plaintext key is never in the file, and neither is your
PIN or passphrase. That is why your existing secret still works on a completely
different server: the new instance is not given your key, it is given something only
your secret can open.

| Your hosted account | What you need after importing |
|---|---|
| PIN only | your **hosted PIN** |
| PIN **and** a passphrase | your **passphrase**, then your **hosted PIN** |

The second row surprises people. Enabling a passphrase deliberately removes the
PIN-wrapped copy of your key from the server, so that the only copy we ever hold is
protected by something far stronger than six digits. That copy is what ends up in your
export — so the passphrase is the only thing that can open it.

**If you set a passphrase on hosted and no longer have it, do not export and wipe
anything.** Your records cannot be decrypted without it, on either instance. Check that
you have it before you start.

### After it finishes

The PIN you created during self-hosted setup is gone — it belonged to the empty account
the import replaced. From then on you unlock with the secret that came across, and you
can change it in Security settings once you are in.

Your hosted account is untouched by any of this. Keep it until you are satisfied the
migration worked, and compare a few records before you rely on the new instance.

---

Version: `0.1.6`
