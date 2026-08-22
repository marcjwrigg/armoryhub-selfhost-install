# Install self-hosted ArmoryHub

Configuration only — the application itself is a container image. No account, no
credentials, and no build step required to install.

**Pick your starting point.** These three are alternatives, not steps — do one:

| If this is you | Start at |
|---|---|
| Docker already runs here, `docker ps` works without `sudo`, and Tailscale suits you | [This isn't my first rodeo](#this-isnt-my-first-rodeo) |
| New to Docker or Tailscale, or starting from a bare machine | [Full installation guide](#full-installation-guide) |
| You already run nginx, Caddy, Traefik or Nginx Proxy Manager and want your own certificates | [Advanced: your own reverse proxy](#advanced-your-own-reverse-proxy) |

Everything after those is reference: day-to-day commands, backups, updating, putting it
on your phone, and moving an account across from hosted.

## Contents

- [This isn't my first rodeo](#this-isnt-my-first-rodeo)
- [Full installation guide](#full-installation-guide)
- [Advanced: your own reverse proxy](#advanced-your-own-reverse-proxy)
- [The armoryhub command](#the-armoryhub-command)
- [Updating](#updating)
- [Backups](#backups)
- [Troubleshooting](#troubleshooting)
- [Your password, PIN and passphrase](#your-password-pin-and-passphrase)
- [Installing it as an app on your phone and computer](#installing-it-as-an-app-on-your-phone-and-computer)
- [Running under CasaOS, Portainer or Dockge](#running-under-casaos-portainer-or-dockge)
- [Moving an existing hosted account across](#moving-an-existing-hosted-account-across)
- [Uninstalling](#uninstalling)

## This isn't my first rodeo

What has to be true first:

- **Docker with the Compose plugin, v2.23 or newer**, and `docker ps` working as your
  normal user without `sudo`. Older Compose cannot read the setup scripts embedded in
  `docker-compose.yml` and fails with a confusing error about `configs`.
- **`curl`** — Debian does not ship it.
- **A Tailscale account with MagicDNS *and* HTTPS Certificates enabled**, at
  <https://login.tailscale.com/admin/dns>. Both are free, and **both are off by
  default**. Without them the install completes and then fails at the last step with
  `your Tailscale account does not support getting TLS certs`.
- **The Tailscale app on whatever device you will use ArmoryHub from**, signed in to
  the same account.

```bash
curl -fsSL https://armoryhub.app/install.sh | sh
```

Click the approval link it prints, then open the `https://...ts.net` address and create
your account. That is the whole install: Postgres, the app, nightly backups, Tailscale
and a real auto-renewing certificate, configured and running.

It generates every secret, so there is nothing to edit and no keys to make. Read it
first if you would rather not pipe a script to a shell — it is short and does what it
says.

### Install-time options

Environment variables go **after** the pipe, so they reach the shell running the script
rather than `curl`:

```bash
# Install somewhere other than ~/armoryhub
curl -fsSL https://armoryhub.app/install.sh | ARMORYHUB_DIR=/mnt/cache/appdata/armoryhub sh

# Choose the name on your tailnet (default: armoryhub)
curl -fsSL https://armoryhub.app/install.sh | ARMORYHUB_TS_HOSTNAME=armory sh
```

**Put the database on ordinary local storage** — this is the one that bites on NAS
hardware. It lives in `./data/postgres` beside the compose file, and Postgres on a FUSE
mount or a network share risks locking errors and corruption. On Unraid that means
installing to a cache-backed path: `/mnt/user/...` goes through shfs, which is FUSE. The
same applies to NFS and SMB. `ARMORYHUB_DIR` is how you move it.

**Tailscale certificates are rate-limited per hostname** — five a week. If you have
reinstalled several times and HTTPS has stopped working, a fresh
`ARMORYHUB_TS_HOSTNAME` sidesteps a limit you have already hit.

**For an unattended install**, put a reusable, non-ephemeral `TS_AUTHKEY` in `.env`
before running, and it registers without waiting for anyone to click a link.

### Or set it up by hand

```bash
mkdir armoryhub && cd armoryhub
curl -fsSL https://raw.githubusercontent.com/marcjwrigg/armoryhub-selfhost-install/main/docker-compose.yml -o docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/marcjwrigg/armoryhub-selfhost-install/main/env.example -o .env
chmod 600 .env
# replace every CHANGE_ME — openssl rand -base64 32 (and 48 for AUTH_JWT_SECRET)
docker compose up -d
```

Watch it come up with `docker compose logs -f app`. It applies the database schema and
checks its own configuration before serving anything, and refuses to start rather than
start wrong — so any failure is explained in that log.

Next: [the armoryhub command](#the-armoryhub-command) for everyday use, or
[installing it as an app](#installing-it-as-an-app-on-your-phone-and-computer) on your
phone and laptop.

## Full installation guide

Nothing below assumes you have done any of this before. If you have, the
[quick version](#this-isnt-my-first-rodeo) is four lines.

### 1. A machine to run it on

**Something that stays on, running Linux.** A NAS, a mini PC, an old laptop or a VM is
plenty. Both 64-bit Intel/AMD (`amd64`) and 64-bit ARM (`arm64`) are supported, so a
Raspberry Pi 4 or 5 works.

| | Minimum | Comfortable |
|---|---|---|
| Memory | 1 GB free | 2 GB free |
| Disk | 3 GB, plus room for your photos | 10 GB+ |
| CPU | any 64-bit dual core | — |

The install downloads roughly 150 MB. Photos are the only thing that grows much over
time — budget for your existing photo library, plus room for backups, which keep 7
daily and 4 weekly copies.

**You do not need** a domain name, a static IP, port forwarding, any firewall changes,
or root access beyond installing Docker. Nothing is exposed to the internet.

### 2. If it is a virtual machine, set the CPU type to `host`

Proxmox, and most other hypervisors, default to a generic emulated CPU — `kvm64` or
`qemu64` — which hides the real processor's AES-NI and AVX2 instructions from the
guest. Those are exactly the instructions HTTPS and password hashing use, so the
default quietly forces both onto slow software fallbacks and makes signing in and
loading pages sluggish for no benefit at all.

- **Proxmox:** *Hardware → Processors → Type: `host`*
- **libvirt / virt-manager:** tick *Copy host CPU configuration*, or set
  `<cpu mode='host-passthrough'/>` in the domain XML
- **VMware, Hyper-V, UTM:** usually called CPU pass-through or "expose host features"

You can change this on a VM you have already built: shut it down, change the type,
start it again. Nothing inside ArmoryHub needs touching. The only thing pass-through
costs you is live-migrating that VM to a machine with a different CPU, which is not
something a single home instance does.

### 3. Docker, and the group that trips everyone up

You need Docker with the Compose plugin, and both must work **as your normal user**,
without `sudo`:

```bash
docker ps
docker compose version
```

If `docker ps` gives a permission error on `/var/run/docker.sock`, your user is not in
the `docker` group. This is the single most common way a self-host install stalls.

**Starting from a bare Debian or Ubuntu machine?** There is an optional script that
does the whole lot in one run: system update, `sudo`, `curl`, `ca-certificates` and
SSH, Docker Engine with the Compose plugin, and both group memberships. See
[the bootstrap script](#the-bootstrap-script-for-a-bare-debian-or-ubuntu-machine)
below, then come back here.

**Doing it yourself?** Install Docker from <https://docs.docker.com/engine/install/>,
then:

```bash
sudo usermod -aG docker $USER
```

**Then log out and back in.** Group membership only applies to new login sessions, so
until you do, `docker` keeps failing and it looks like the install did not work. Check
it took:

```bash
docker run hello-world
```

You also need `curl`, which Debian does not install by default:

```bash
sudo apt-get update && sudo apt-get install -y curl
```

### The bootstrap script, for a bare Debian or Ubuntu machine

If you have just clicked through the Debian or Ubuntu installer and have nothing else
set up, this takes you from there to ready-for-ArmoryHub in one run — including the
`docker` group step above, and the log-out that makes it take effect.

**It is optional, and nothing runs it for you.** Installing ArmoryHub never invokes it.
It is a convenience for people who would rather not assemble the steps themselves, and
skipping it is a perfectly normal way to install.

It must run as **root**, which is also exactly why you should read it first:
**[bootstrap-debian.sh](bootstrap-debian.sh)** is in this repo, about a hundred lines,
and every step is commented. Read it there, or download it and read it locally — do not
take our word for what it does.

**Becoming root is the one place Debian and Ubuntu differ.** Debian sets a root
password during installation, so `su -` works. Ubuntu locks the root account, so `su -`
there rejects your password no matter what you type — use `sudo -i` instead.

```bash
su -                                         # Debian: the root password you set
sudo -i                                      # Ubuntu: your own password
```

Then, identically on both:

```bash
apt-get update && apt-get install -y curl    # Debian does not ship curl
curl -fsSL https://raw.githubusercontent.com/marcjwrigg/armoryhub-selfhost-install/main/bootstrap-debian.sh -o bootstrap-debian.sh
less bootstrap-debian.sh                     # or cat — read it before running it
bash bootstrap-debian.sh <your-username>
```

Pass your everyday login name, not `root` — that is the account that gets the group
memberships, and the account you should install ArmoryHub as.

That `apt-get install curl` line is not a mistake: **Debian does not include `curl` in
a default install**, so the download fails with `curl: command not found` on exactly
the fresh machine this section is about. Ubuntu Server generally does ship it, so there
the line is a no-op. Use `wget` instead if you prefer.

The script is downloaded and read, then run as a separate deliberate step —
deliberately not a `curl ... | sh` one-liner. Piping a root-privileged script straight
from the internet into a shell means running something you never saw.

**When it finishes, log out completely and back in.** `exit` on its own is not enough:
you got to root with `su -` or `sudo -i`, and the session underneath that root shell
started before your user joined the groups, so it has not got them either. Leave the
root shell *and* log out of your own session — over SSH, close the connection — then
log back in and check with `docker run hello-world`.

It is safe to re-run, and it skips Docker if Docker is already installed. It works
unchanged on Ubuntu and the other Debian derivatives: it keys off `apt-get` rather than
checking for a particular distribution, the `sudo` and `docker` group names are the
same on both, and anything already installed is left alone. On anything else, install
Docker via <https://docs.docker.com/engine/install/> and add yourself to the `docker`
group by hand.

### 4. Tailscale, and why HTTPS is not optional

**Browsers only allow the encryption ArmoryHub depends on over HTTPS, or on
`localhost`.** Reach the app by IP over plain `http://` and you will be able to sign in
and then fail to unlock your data — everything looks fine until the moment it doesn't.
So the instance needs a real certificate, and Tailscale is by far the easiest way to
get one.

If you have not used it before: Tailscale is a private network that links your own
devices together, wherever they are. ArmoryHub uses it for two things — reaching your
instance from your phone or laptop without exposing anything to the internet, and
getting a real HTTPS certificate for it. It is free for personal use.

**Create an account** at <https://tailscale.com>, then **turn on two toggles** that are
free on every plan and off by default:

1. Go to <https://login.tailscale.com/admin/dns>
2. Enable **MagicDNS** if it is not already on
3. Enable **HTTPS Certificates**

Miss these and everything installs correctly, then fails at the last step with `your
Tailscale account does not support getting TLS certs` — which looks far worse than it
is.

**Install the Tailscale app on every device you want to use ArmoryHub from** — your
phone, your laptop, anything else — signed in to the same account. Your instance lives
on that private network, so its address only resolves on devices that have joined it.
Nothing loads without it, which catches people who set the server up and then try to
open it on a phone that is not connected yet.

Prefer your own certificates and reverse proxy? You can skip Tailscale entirely —
see [Advanced](#advanced-your-own-reverse-proxy).

### 5. Run the installer

On the server, as your normal user — not root:

```bash
curl -fsSL https://armoryhub.app/install.sh | sh
```

It checks Docker, generates every secret for you, pulls the image, starts everything
including HTTPS, and finishes by printing a link to approve the machine on your
Tailscale network. Nothing to edit and no keys to generate.

See [install-time options](#install-time-options) if you need to install somewhere
other than `~/armoryhub` — which you probably do on a NAS.

### 6. Approve the machine

Click the link it prints and sign in. That adds this machine to your tailnet, and the
certificate is issued automatically.

If the link expires before you use it, get a fresh one:

```bash
docker compose exec tailscale tailscale status
```

### 7. Open your instance and create your account

Your instance now lives at:

```
https://armoryhub.<your-tailnet>.ts.net
```

**Bookmark that.** It is the address to use from every device, and the only one the app
can work on.

Open it, and follow first-run setup. You will set a password to sign in, and then a PIN
to decrypt your data — two different things, and the difference matters. Read
[your password, PIN and passphrase](#your-password-pin-and-passphrase) before you
choose them.

**If you run a dashboard like CasaOS**, its "open app" button will point at
`http://<server-ip>:8477` instead — the one address the app cannot work on. Ignore the
button and use your bookmark. Do not try to fix it by editing the app's Web UI setting;
saving that form rewrites your compose file and deletes services. See
[Running under CasaOS, Portainer or Dockge](#running-under-casaos-portainer-or-dockge).

## Advanced: your own reverse proxy

If you already run nginx, Caddy, Traefik or Nginx Proxy Manager and want to use your
own certificates, you do not need Tailscale at all.

**1. Let your proxy reach the app.** Which option applies depends on where the proxy
runs:

| Your proxy | What to do |
|---|---|
| Same host, host network mode | Nothing — `http://127.0.0.1:8477` already works |
| Docker bridge network, or another machine | Set `APP_BIND=0.0.0.0` in `.env` |
| Attached to this stack's network | Target `app:3000` and publish nothing at all |

The app binds to `127.0.0.1` by default on purpose, so it is not reachable from your
LAN. `APP_BIND=0.0.0.0` removes that protection and serves an unencrypted login page to
your whole network — only set it with a TLS-terminating proxy in front.

**2. Set your address:** `APP_URL=https://armory.example.com` in `.env`.

**3. Turn off the Tailscale sidecar**, or it will keep starting unused:

```bash
sed -i 's/^COMPOSE_PROFILES=.*/COMPOSE_PROFILES=/' .env
```

**4. Terminate TLS at the proxy.** Browsers only allow the encryption ArmoryHub needs
over HTTPS or on `localhost`, so reaching it by plain `http://` at a LAN address will
let you sign in and then fail to unlock your data.

Then restart: `docker compose up -d`.

### Or use the built-in Caddy, with your own domain

If you own a domain and want a public URL without running your own proxy, the compose
file ships a Caddy profile that gets a Let's Encrypt certificate for you. Set
`CADDY_SITE_ADDRESS` and `CADDY_ACME_EMAIL` in `.env`, set
`COMPOSE_PROFILES=caddy`, and point a DNS record at the machine. That needs ports 80
and 443 reachable from the internet — unlike the Tailscale route, this does put the
login page on the public internet.

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

## Troubleshooting

**Start with `armoryhub doctor`.** It diagnoses most of what follows and tells you what
to do about it.

**The page is blank, or the certificate looks wrong.** Ask Tailscale directly — it
prints the real error where the browser shows you nothing:

```bash
docker compose exec tailscale tailscale cert <your-full-domain>
```

**Your HTTPS address stopped working after an upgrade.** Check `docker compose ps`
includes **tailscale**. If it does not, that is why: the address resolves to nothing,
which in a browser looks like a blank page with an empty console rather than an error.

Tailscale is an optional service, so it only starts when Compose is told to include it.
Once it has stopped for any reason, a plain `up -d` leaves it down:

```bash
grep COMPOSE_PROFILES .env || echo 'COMPOSE_PROFILES=tailscale' >> .env
docker compose up -d
```

That line makes every future `up -d` include it. Installs created by `install.sh` have
it already. Set it to `caddy` instead if you use a public domain.

**It loads on your phone but not your computer.** Check whether another VPN is running
on that device. A second VPN client will happily route around Tailscale, and the way it
fails is genuinely misleading: Tailscale itself keeps working, so

```bash
tailscale ping armoryhub
```

still gets replies and everything looks reachable — while connections to port 443
quietly fail. It reads as a broken certificate or a server problem, and you can lose an
evening to it. Quickest way to identify it: try the same address from your phone on
mobile data. If the phone works and the desktop does not, the problem is the desktop.

**You can sign in, but cannot set or enter your PIN.** You are reaching the app over
plain `http://` — almost always by IP address, or via a dashboard's "open app" button.
Browsers withhold the cryptography the app needs from insecure origins. Use your
`https://...ts.net` bookmark.

**`no such service: tailscale` or `no such service: restore`**, while the containers
are visibly running. A dashboard has rewritten your compose file — see
[Running under CasaOS, Portainer or Dockge](#running-under-casaos-portainer-or-dockge).

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
store, sign in to the same account, and make sure it is connected. Your instance lives
on your private network, so the address only resolves while Tailscale is on. If the
page will not load, that is almost always the reason.

Then open `https://armoryhub.<your-tailnet>.ts.net` and:

**iPhone or iPad** — use **Safari**. Tap the Share button (the square with an arrow
pointing up), scroll down, tap **Add to Home Screen**, then **Add**. Other browsers on
iOS can make a shortcut, but only Safari installs it as a real app.

**Android** — use **Chrome**. Tap the three-dot menu, then **Install app** (some
versions say *Add to Home screen*), then confirm.

**Windows or Linux desktop** — in **Chrome** or **Edge**, click the install icon at the
right-hand end of the address bar, then **Install**. If you do not see it, the
three-dot menu has the same option.

**Mac** — in **Safari**, choose **File → Add to Dock**. In Chrome or Edge, use the
install icon in the address bar as above.

Launch it from your home screen or dock afterwards. It keeps you signed in, so you only
need your PIN. Remember that Tailscale has to be connected for it to load — worth
knowing before you rely on it at a range with no signal.

## Running under CasaOS, Portainer or Dockge

The compose file works in any of them, but **CasaOS rewrites it when you save anything
through its settings form**, including when you set the Web UI address. Measured on a
real install, saving once:

- **removes the `tailscale`, `restore` and `caddy` services**, because CasaOS does not
  understand Compose profiles and drops what it cannot model. Containers already
  running keep running, so nothing appears wrong — but `docker compose` can no longer
  start or restart Tailscale, and reports `no such service: tailscale`.
- **converts `$$` to `$`**, so the embedded database setup would run with an empty
  username on a fresh install.
- **copies your passwords out of `.env` into the compose file**, which is
  world-readable, while `.env` is not.

None of that breaks a running instance, which is why it goes unnoticed. It bites later,
when something needs restarting.

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
curl -fsSL https://raw.githubusercontent.com/marcjwrigg/armoryhub-selfhost-install/main/docker-compose.yml \
  -o compose-full.yml

docker compose -f compose-full.yml --profile tools run --rm --no-deps restore list
docker compose -f compose-full.yml --profile tailscale up -d
```

The project name comes from the directory, so this attaches to the same containers,
network and data as usual — it is the same stack, just described by a file CasaOS has
not edited. `--no-deps` stops Compose recreating your database because the two files
disagree.

## Moving an existing hosted account across

Your data comes over as a single encrypted archive. Nothing is re-encrypted, and no key
ever travels in a form anyone could use.

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

## Uninstalling

```bash
# Sign out of Tailscale FIRST, or a future reinstall appears as armoryhub-1
docker compose exec tailscale tailscale logout

docker compose --profile tailscale --profile tools down
```

That stops and removes the containers. **Your data is still there**, in the `data`
directory next to `docker-compose.yml`, and `docker compose up -d` brings it all back.

To delete your data as well, remove that directory yourself:

```bash
rm -rf ./data
```

There is no undo, and that includes your backups. Copy anything you want to keep off
the machine first.

---

Version: `0.1.7`
