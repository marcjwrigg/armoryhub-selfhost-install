#!/bin/bash
# bootstrap-debian.sh — one-shot setup for a fresh Debian VM that will run
# ArmoryHub. Takes a brand-new install from "just finished the Debian
# installer" to "ready for install.sh" in a single run: system update, sudo,
# SSH, Docker Engine and the Compose plugin, and both group memberships.
#
# This exists because the single most common install failure is not ArmoryHub
# at all — it is `docker ps` refusing to run without sudo because the user was
# never added to the docker group, and the group not taking effect because
# nobody logged out. Doing it by hand means finding four separate sets of
# instructions and getting the order right.
#
# Must be run as root: a fresh Debian install has no sudo yet, which is part of
# what this fixes. Get to root with `su -` first, then run it.
#
# Usage:
#   ./bootstrap-debian.sh <username>
#
# Safe to re-run: every step here is idempotent.
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: this script must be run as root."
  echo "Run 'su -' first (enter the root password), then re-run this script."
  exit 1
fi

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <username>"
  echo "       the everyday account you log in as — not root."
  exit 1
fi

TARGET_USER="$1"

# apt-get rather than a Debian version check: this works unmodified on Ubuntu
# and the other Debian derivatives people run on a home server, and the thing
# that actually matters is whether the package manager below exists.
if ! command -v apt-get >/dev/null 2>&1; then
  echo "Error: this script is for Debian and Ubuntu systems (no apt-get found)."
  echo "For other distributions see https://docs.docker.com/engine/install/"
  exit 1
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "Error: user '$TARGET_USER' does not exist on this system."
  echo
  echo "Create it first, then re-run this script:"
  echo "  adduser $TARGET_USER"
  exit 1
fi

if [ "$TARGET_USER" = "root" ]; then
  echo "Error: pass your everyday user account, not root."
  echo "Running ArmoryHub as root is unnecessary and this script will not set it up."
  exit 1
fi

# Non-interactive, and keep existing config files on conflict. Without this an
# upgrade on a fresh VM can stop dead on a purple full-screen prompt about a
# modified config file or a services-to-restart list, which is bewildering when
# you were told this was one command.
export DEBIAN_FRONTEND=noninteractive
APT_OPTS="-y -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef"

echo "==> Updating package index"
apt-get update

echo "==> Upgrading existing packages"
# shellcheck disable=SC2086
apt-get upgrade $APT_OPTS

echo "==> Installing sudo, curl, ca-certificates, openssh-server"
# shellcheck disable=SC2086
apt-get install $APT_OPTS sudo curl ca-certificates openssh-server

echo "==> Enabling and starting SSH"
if command -v systemctl >/dev/null 2>&1; then
  systemctl enable --now ssh
else
  echo "    no systemd here — skipping, start SSH however this system does it"
fi

echo "==> Adding '$TARGET_USER' to the sudo group"
usermod -aG sudo "$TARGET_USER"

echo "==> Installing Docker (official convenience script)"
# get.docker.com rather than the manual apt repository steps: it is Docker's
# own script, it picks the right repository for the distribution and
# architecture, and it installs the Compose plugin. It detects an existing
# install and exits cleanly, so re-running this is fine.
if command -v docker >/dev/null 2>&1; then
  echo "    Docker is already installed — skipping"
else
  curl -fsSL https://get.docker.com | sh
fi

echo "==> Adding '$TARGET_USER' to the docker group"
usermod -aG docker "$TARGET_USER"

echo ""
echo "Done. Installed: sudo, curl, ca-certificates, openssh-server, Docker Engine + Compose plugin."
echo "'$TARGET_USER' was added to both the sudo and docker groups."
echo ""
echo "-------------------------------------------------------------------------"
echo "The group changes are NOT active yet. Do not skip step 1."
echo "-------------------------------------------------------------------------"
echo ""
echo "Only a NEW login session picks up group membership. Typing 'exit' to leave"
echo "this root shell is not enough on its own: the session underneath it was"
echo "started before '$TARGET_USER' joined the groups, so it does not have them"
echo "either. Docker will still refuse to run, and it will look like this script"
echo "did not work."
echo ""
echo "  1. Log out completely."
echo "     'exit' out of this root shell, then log out of '$TARGET_USER' as well."
echo "     Over SSH that means closing the connection; at the console, log out."
echo ""
echo "  2. Log back in as '$TARGET_USER' and check it took:"
echo ""
echo "       docker run hello-world"
echo ""
echo "     A permission error on /var/run/docker.sock means you are still in the"
echo "     old session. Log out again, properly this time."
echo ""
echo "  3. Only once that works, install ArmoryHub — as '$TARGET_USER', not root:"
echo ""
echo "       curl -fsSL https://armoryhub.app/install.sh | sh"
