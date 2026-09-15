#!/usr/bin/env bash
# Install + configure MySQL for the dev box: root user with an EMPTY password,
# reachable over 127.0.0.1 (TCP) — matches every project's .env (`mysql -h127.0.0.1
# -uroot`, no password) and the single-user, loopback-only, tailnet-only convention.
# Idempotent. Uses sudo INTERNALLY — run as your user, not with sudo.
set -euo pipefail

[ "$(uname)" = "Darwin" ] && { echo "mysql-setup: Linux/box only — skipping on macOS"; exit 0; }
if [ "$(id -u)" = 0 ]; then echo "Run as your user, not sudo: bash ~/dotfiles/scripts/mysql-setup.sh" >&2; exit 1; fi

echo "==> MySQL server (apt)"
dpkg -s mysql-server >/dev/null 2>&1 || sudo apt-get install -y mysql-server
sudo systemctl enable --now mysql

echo "==> root: empty password + reachable as root@127.0.0.1 (TCP)"
# Fresh install: root@localhost is auth_socket, so `sudo mysql` gets in without a password.
sudo mysql <<'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '';
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED WITH caching_sha2_password BY '';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

echo "==> verify"
if v=$(mysql -h127.0.0.1 -uroot -N -e 'SELECT VERSION();' 2>/dev/null); then
  echo "  ✓ root@127.0.0.1 (empty password) works — MySQL $v"
else
  echo "  ! couldn't connect as root@127.0.0.1 with empty password — check manually" >&2
fi
echo "  (MySQL binds 127.0.0.1 by default on Ubuntu — loopback only)"
