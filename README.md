# Install self-hosted ArmoryHub

[![CI](https://github.com/marcjwrigg/armoryhub-selfhost-install/actions/workflows/ci.yml/badge.svg)](https://github.com/marcjwrigg/armoryhub-selfhost-install/actions/workflows/ci.yml)

Configuration only — the application itself is a container image. No account, no
credentials, and no build step required to install.

Every script here is linted and the compose file is validated in all four supported
configurations on every change — [see for yourself](../../actions/workflows/ci.yml).
You are about to run a shell script on your own machine; that should be checkable
rather than a claim.

## Contents

- [Beta, and what it costs](#beta-and-what-it-costs)
- ["Not My First Rodeo" — the one-command install](#not-my-first-rodeo--the-one-command-install)
- ["Hold My Hand" — the full guide](#hold-my-hand--the-full-guide)
- ["Hold My Beer" — reverse proxies, custom builds and doing it your way](#hold-my-beer--reverse-proxies-custom-builds-and-doing-it-your-way)
- [The armoryhub command](#the-armoryhub-command)
- [Updating](#updating)
- [Backups](#backups)
- [Managing the server from a browser](#managing-the-server-from-a-browser)
- [Troubleshooting](#troubleshooting)
- [Your password, PIN and passphrase](#your-password-pin-and-passphrase)
- [Installing it as an app on your phone and computer](#installing-it-as-an-app-on-your-phone-and-computer)
- [Running under CasaOS, Portainer or Dockge](#running-under-casaos-portainer-or-dockge)
- [Moving an existing hosted account across](#moving-an-existing-hosted-account-across)
- [Uninstalling](#uninstalling)

## Beta, and what it costs

**Self-hosted ArmoryHub is a beta product.** Same application and the same encryption as
the hosted version, and it is in real use — but it is younger, it runs on hardware we
have never seen, and you should expect rough edges. Read this before you commit your
records to it, and keep a backup you have actually tested.

**It is free during the beta.** There is no licence key, no activation, and nothing in
the instance that phones home to check one.

**Self-hosting will eventually be licensed, and you will be grandfathered.** Any instance
running a version below `1.0` stays free, permanently, and keeps updating. You will not
wake up to a locked instance or a demand for a key. That is the point of installing
during a beta.

If you would rather not use it for nothing, there is a
[pay-what-you-want link](https://armoryhub.app/self-hosted#beta) — you pick the amount.
Nothing about your install depends on it: no tier, no receipt to enter, no feature behind
it. Skipping it is the expected answer.

> ### Already running ArmoryHub? Run this once
>
> Every install made before 0.1.7 has an `armoryhub update` that cannot actually
> change the version. The image tag is pinned in your `docker-compose.yml` when you
> install, and `update` pulled that same pinned tag — so it reported success, updated
> its own helper script, and left the app exactly where it was. If `armoryhub doctor`
> says you are on 0.1.6, this is why.
>
> The fix is in the new helper, which the old one cannot install for itself. Replace it
> by hand, once:
>
> ```bash
> sudo curl -fsSL https://raw.githubusercontent.com/marcjwrigg/armoryhub-selfhost-install/main/armoryhub \
>   -o "$(command -v armoryhub)" && sudo chmod +x "$(command -v armoryhub)"
> armoryhub update
> ```
>
> From then on `armoryhub update` keeps itself current and `armoryhub doctor` reports
> your version and whether it is the latest. New installs need none of this.

# Three ways in

They are alternatives, not steps — pick the one that sounds like you.

**[Not My First Rodeo](#not-my-first-rodeo--the-one-command-install)** — the one-command install

You've run Docker before, you're comfortable in a terminal, and a machine that stays on
already exists somewhere in your house. You have a Tailscale account or don't mind
making one, and you're happy to let it handle HTTPS so you don't have to think about
certificates. One command, one link to click, done in about five minutes.

**[Hold My Hand](#hold-my-hand--the-full-guide)** — the full guide

New to this, or new enough that "install Docker and the Compose plugin" is a sentence
with several unanswered questions in it. This walks the whole thing: picking a machine,
setting up a VM if that's your route, getting Docker on it and into the right group,
creating a Tailscale account and switching on the two toggles that catch everyone.
There's a bootstrap script that does the Docker part for you on a bare Debian or Ubuntu
box. It assumes you have Debian or Ubuntu installed and can log in — everything after
that is covered.

**[Hold My Beer](#hold-my-beer--reverse-proxies-custom-builds-and-doing-it-your-way)** — reverse proxies, custom builds and doing it your way

You already run nginx or Traefik or Nginx Proxy Manager, you have your own
certificates, and you have opinions about where the database lives. Tailscale is
optional and you can skip it entirely. `install.sh` is plain POSIX shell in a public
repo, so clone it, change it, run your own copy. This section covers the flags, the
bind addresses, the built-in Caddy profile with your own domain, and converting an
existing install.

Everything after those three is reference: day-to-day commands, backups, updating,
putting it on your phone, and moving an account across from hosted.

## "Not My First Rodeo" — the one-command install

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

## "Hold My Hand" — the full guide

Nothing below assumes you have done any of this before. If you have, the
[one-command install](#not-my-first-rodeo--the-one-command-install) is four lines.

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
see [Hold My Beer](#hold-my-beer--reverse-proxies-custom-builds-and-doing-it-your-way).

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

## "Hold My Beer" — reverse proxies, custom builds and doing it your way

If you already run nginx, Caddy, Traefik or Nginx Proxy Manager and want to use your
own certificates, you do not need Tailscale at all. Pass your public HTTPS address and
the installer skips the entire Tailscale phase — no sidecar, no machine to approve, no
certificate to wait for:

```bash
curl -fsSL https://armoryhub.app/install.sh | sh -s -- --reverse-proxy https://armory.example.com
```

The `-s --` matters. It is what lets a piped script take arguments at all; without it
the shell treats `--reverse-proxy` as a filename to run. If you would rather not
remember that, the environment form is equivalent:

```bash
curl -fsSL https://armoryhub.app/install.sh | ARMORYHUB_REVERSE_PROXY=https://armory.example.com sh
```

That sets `APP_URL` to your address, sets `APP_BIND=0.0.0.0` so a proxy outside this
host can reach the app, and leaves `COMPOSE_PROFILES` empty so no sidecar starts. Run
`install.sh --help` for every option.

**Then point your proxy at `http://<this-machine>:8477`** and serve it as your HTTPS
address. Terminate TLS at the proxy: browsers only allow the encryption ArmoryHub needs
over HTTPS, so a plain `http://` address lets you sign in and then fails to unlock your
data.

### Which bind address you want

`APP_BIND=0.0.0.0` is the default with `--reverse-proxy` because it is what the common
setups need — but it publishes an unencrypted login page on port 8477 to your whole
network, so it is worth knowing whether you need it:

| Where your proxy runs | What to use |
|---|---|
| Same host, host network mode | `--bind 127.0.0.1` — loopback is enough |
| Docker bridge network, or another machine | the default `0.0.0.0` |
| Attached to this stack's own network | `--bind 127.0.0.1`, and target `app:3000` |

```bash
curl -fsSL https://armoryhub.app/install.sh | sh -s -- \
  --reverse-proxy https://armory.example.com --bind 127.0.0.1
```

Until the proxy is actually in front of it, `0.0.0.0` means anyone on your LAN can
reach that login page. Firewall the port, or use `--bind 127.0.0.1` if you can.

### Converting an existing install

Already installed with Tailscale and want to switch? Nothing needs reinstalling — edit
`.env` in your install directory and restart:

```bash
cd ~/armoryhub
sed -i 's|^APP_URL=.*|APP_URL=https://armory.example.com|' .env
sed -i 's|^APP_BIND=.*|APP_BIND=0.0.0.0|' .env
sed -i 's|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=|' .env
docker compose --profile tailscale down
docker compose up -d
```

Sign out of Tailscale first if you are done with it entirely —
`docker compose exec tailscale tailscale logout` — or a later reinstall shows up as
`armoryhub-1`.

If your install predates `--reverse-proxy` it may have no `APP_BIND` line at all, in
which case add one rather than replacing it:

```bash
grep -q '^APP_BIND=' .env || echo 'APP_BIND=0.0.0.0' >> .env
```

### Or use the built-in Caddy, with your own domain

If you own a domain and want a public URL without running your own proxy, the compose
file ships a Caddy profile that gets a Let's Encrypt certificate for you. In `.env`:

```bash
CADDY_SITE_ADDRESS=armory.example.com
CADDY_ACME_EMAIL=you@example.com
APP_URL=https://armory.example.com     # must match CADDY_SITE_ADDRESS
COMPOSE_PROFILES=caddy
```

**`APP_URL` has to be the same address as `CADDY_SITE_ADDRESS`.** There is no
`--caddy` install flag, so everyone arriving here already has an install whose
`APP_URL` points at a `.ts.net` name. Leave it pointing there and the app keeps
generating links to an address Caddy is not serving.

Then point a DNS record at the machine and `docker compose up -d`. This needs ports 80
and 443 reachable from the internet — unlike the Tailscale route, it does put your
login page on the public internet.

### Changing the installer itself

`install.sh` is a plain POSIX shell script with no dependencies, and this repo is
public. If it does not do what your setup needs, clone it, edit it, and run your copy:

```bash
git clone https://github.com/marcjwrigg/armoryhub-selfhost-install.git
cd armoryhub-selfhost-install
# edit install.sh
sh install.sh --reverse-proxy https://armory.example.com
```

Set `ARMORYHUB_CONFIG_REPO=you/your-fork` if you also want it to pull
`docker-compose.yml` and the `armoryhub` helper from your fork rather than from here.

## The armoryhub command

The installer sets up an `armoryhub` command. Use it in preference to `docker compose`:
it reads Docker directly, so it keeps working even if a dashboard has rewritten your
compose file.

```bash
armoryhub doctor            # check everything and say what is wrong
armoryhub status            # what is running
armoryhub logs [service]    # follow logs, default: app
armoryhub url               # the address to open
armoryhub backup list       # what backups exist, and where they go
armoryhub backup now        # take one immediately
armoryhub backup verify latest
armoryhub backup path   /mnt/disk2/armoryhub-backups   # move where backups go
armoryhub backup mirror /mnt/nas/armoryhub-backups     # keep a second copy
armoryhub restore <stamp>   # asks for confirmation, stops and restarts the app
armoryhub password          # reset the account password
armoryhub update            # pull and restart, or say you are already current
armoryhub portal on|off     # manage this server from the browser
armoryhub compose refresh   # bring docker-compose.yml up to date
```

**`armoryhub doctor` is the one to run when something is wrong.** It checks the
containers, whether the app answers, whether HTTPS actually works end to end, whether
your compose file has been rewritten, whether the database is on storage that will
corrupt it, free space, and backup age — and tells you what to do about each.

### If `armoryhub update` runs but nothing seems to change

Two things did not update themselves in versions up to and including 0.1.11. Both are
fixed from 0.1.12 onward and need nothing from you from then on — but a fix cannot
apply retroactively, because the code that would have delivered it is the code that
was broken. So if you installed before 0.1.12, do each of these once.

**1. The `armoryhub` command itself.** It fetched its own replacement into
`/usr/local/bin`, which is root-owned, so running `armoryhub update` as your own user
could not write the file. The symptom is a command that stays on an old version for
ever: new subcommands simply do not exist, and `update` keeps behaving the way the
old version did.

```bash
# Note the raw.githubusercontent URL: only install.sh has a website rewrite.
sudo curl -fsSL https://raw.githubusercontent.com/marcjwrigg/armoryhub-selfhost-install/main/armoryhub \
  -o /usr/local/bin/armoryhub && sudo chmod +x /usr/local/bin/armoryhub
```

From 0.1.12 the helper ships inside the image and `update` installs it through a
container running as root — so it needs no `sudo`, no password prompt, no terminal
and no network beyond the image pull you were already doing. You will not have to
touch it again.

**2. `docker-compose.yml`.** It is written once, when you install, and `update`
only ever moved the image version in `.env`. That was harmless while releases only
changed the image, but features now live in the compose file too — so an old file
means those features do nothing at all while appearing to be configured. Setting a
backup path, for instance, would write the value, restart, report success, and leave
your backups exactly where they were.

```bash
armoryhub compose refresh    # keeps a timestamped copy of your current file first
armoryhub compose diff       # see what would change, before changing it
```

`armoryhub doctor` now reports both, and `update` refreshes the compose file for you.

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

That checks what the current release is, moves your install to it, restarts everything,
and updates the `armoryhub` command itself. A backup is taken before any database
changes are applied, and the upgrade aborts if that backup fails.

**If you are already on the current release it says so and stops.** Nothing is pulled
and nothing is restarted — an up-to-date instance should not be torn down just to find
that out. It still squares up the version pin in `.env` and updates the `armoryhub`
command, because neither touches your containers and the helper versions separately
from the image.

```bash
armoryhub update            # to the current release, or a no-op if already there
armoryhub update --force    # re-pull and restart even if already current
```

The one exception is a container that is not running. If the version is current but
something is stopped, it starts what is missing without pulling or recreating anything
that is already up.

It prints what it did — `0.1.6 -> 0.1.7`, or `already on 0.1.7 — the current release`
— so you can tell the difference between an upgrade and a no-op. Confirm with
`armoryhub doctor`.

**How the version is pinned**, because it explains what you will see in `.env`. Your
`docker-compose.yml` pins an image tag, fixed at the moment you installed, so that an
install is reproducible and you can always tell what you are running. Updating sets
`ARMORYHUB_VERSION` in `.env`, which the compose file reads in preference to that
pin. Nothing rewrites `docker-compose.yml`, so local edits to it survive.

To move to a specific version, or to go back to one:

```bash
armoryhub update 0.1.6
```

Downgrades are not generally safe once a release has changed the database — check the
release notes before going backwards.

```bash
docker compose pull && docker compose down && docker compose up -d
```

is the equivalent by hand, but on its own it re-pulls the tag already pinned in your
compose file and leaves you exactly where you were. Set `ARMORYHUB_VERSION` in `.env`
first if you are doing it this way.

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

**Test a restore before you rely on one.**

### Where your backups go

By default: `./data/backups`, inside your install directory. That is the same disk as
the database it is protecting, so a single disk failure loses your records **and** every
backup of them.

Two settings move them, and it is worth setting both:

```bash
armoryhub backup path   /mnt/disk2/armoryhub-backups   # the primary copy
armoryhub backup mirror /mnt/nas/armoryhub-backups     # an optional second copy
```

Relocating the only copy trades one problem for another: if the share is unmounted at
03:00 there is no backup at all that night. A mirror degrades instead of failing — the
primary still lands, and the second copy is reported as failing rather than silently
skipped.

Use these commands rather than editing `.env` by hand. They create the directory, give
it to the right user, copy your existing backups across, and write a marker file:

```
/mnt/disk2/armoryhub-backups/.armoryhub-backups
```

**Do not delete that marker.** It guards a failure that otherwise has no symptoms. A
bind mount whose source has gone does not error — Docker creates an empty directory at
that path on the root disk and mounts that instead. Backups then keep succeeding, onto
the very disk you moved them off, and every check passes. The marker lives on the real
destination's filesystem, so it disappears exactly when the destination does, and the
backup sidecar refuses to write without it.

Backups contain only encrypted data, so a NAS, a cloud mount or somebody else's server
is a fine destination. They cannot be read without your PIN — including by us.

```bash
armoryhub backup list          # both paths, and whether the mirror is working
armoryhub backup mirror now    # copy the latest one across, after fixing a mount
armoryhub backup mirror off    # stop mirroring; existing files are left alone
```

## Managing the server from a browser

`armoryhub portal on` adds a **Settings → Server** page to your instance with the
health checks, backups, updates, logs and a configuration editor.

**Read this before turning it on.** It works by mounting the Docker socket into the
ArmoryHub app container, and the Docker socket is root on the host: anything able to
drive it can create a container with `/` mounted and run any command as root. The app
is also the part that faces your network and holds your database credentials.

So it is off by default, and off means the socket mount is not in your compose file at
all rather than merely unused. The command explains the trade and asks you to type
`yes`.

```bash
armoryhub portal on       # adds docker-compose.portal.yml and recreates the app
armoryhub portal status   # is it on, and is the socket actually reachable
armoryhub portal off      # removes the override and the access with it
```

`armoryhub portal on` also adjusts `.env` so the app can read it: the file is mode
600 and owned by you, while the app runs as a different user, so without this the
Config and Updates tabs fail with a permission error. It becomes group-owned by the
app's group with mode 660 — you keep full access, the app gains it, and nobody else
does. `armoryhub portal off` puts it back to 600.

Everything the page does also works from this command line, so leaving it off costs you
convenience rather than capability. Two things stay CLI-only on purpose:

- **`armoryhub doctor`** keeps checks the browser cannot do — the HTTPS certificate
  diagnosis needs a shell on the host — and you need it most when the app is not
  serving, which is exactly when the page will not load.
- **`armoryhub password`** is how you get back into a locked-out account. It has to
  work when you cannot sign in, and exposing it to a signed-in session would turn a
  stolen session into permanent account takeover.

Configuration changes made in the browser are written to your `.env`, and a
timestamped copy of the previous version is kept first — the last 20 of them, under
`data/app/env-backups/` in your install directory. A change that only shows itself on
the next restart is still recoverable.

```bash
cd ~/armoryhub
ls data/app/env-backups                    # newest last
cp data/app/env-backups/env-<stamp> .env
docker compose up -d
```

## Troubleshooting

**Start with `armoryhub doctor`.** It diagnoses most of what follows and tells you what
to do about it.

**`armoryhub portal` says "unknown command".** Your `armoryhub` command is older than
the version you are running — see "If `armoryhub update` runs but nothing seems to
change" above. One `sudo curl` fixes it.

**The portal's Config or Updates tab says "permission denied, open /host/.env".** The
app cannot read your `.env`. Run `armoryhub portal on` again; it sets the ownership
the app needs.

**The portal's Overview says you have no backups, but the Backups tab lists them.**
Your `docker-compose.yml` predates the mount the Overview page reads through. Run
`armoryhub compose refresh`. The Backups tab works either way because it asks the
backup service directly rather than reading the directory itself.

**A backup path you set had no effect.** Same cause: an old `docker-compose.yml` does
not reference `BACKUP_PATH`, so nothing consumed it. `armoryhub compose refresh`,
then set it again and confirm with `armoryhub backup list`.

**Everything looks empty, or you are asked to create an account again.** Almost
certainly the containers are attached to the wrong directories rather than anything
being lost. Versions 0.1.8 to 0.1.13 had a fault in the management portal: saving
configuration, updating or changing a backup path from the browser could recreate the
stack against freshly-created empty directories, leaving your real data orphaned in
place. Postgres then starts an empty database and Tailscale logs itself out, which
together look like total loss.

`armoryhub doctor` detects it and names the stray paths. The fix does not touch your
data:

```bash
cd ~/armoryhub && docker compose down && docker compose up -d
```

Then run `armoryhub doctor` again to confirm, and delete the stray directories it
listed. Fixed in 0.1.14; the CLI was never affected, only the browser portal.

**`APP_URL` still says localhost.** Harmless. Nothing in a self-hosted build reads
it — it is there for `install.sh` and `armoryhub url` to print, and for a dashboard
tile to link to. Use `armoryhub url` to get the address you actually open, which
prefers your Tailscale name. Set `APP_URL` to match if you like tidy config, from
Settings → Server → Config or by editing `.env`, but nothing depends on it.

**The page is blank, or the certificate looks wrong.** Ask Tailscale directly — it
prints the real error where the browser shows you nothing:

```bash
docker compose exec tailscale tailscale cert <your-full-domain>
```

If that comes back with a **500** and `your Tailscale account does not support getting
TLS certs`, nothing is broken and nothing needs reinstalling — HTTPS Certificates were
never switched on for your tailnet. It is one toggle, free on every plan, off by
default. Turn it on as described in
[step 4](#4-tailscale-and-why-https-is-not-optional), then:

```bash
docker compose --profile tailscale restart tailscale
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

Version: `0.1.18`
