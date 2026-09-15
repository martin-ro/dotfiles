#!/usr/bin/env bash
# Share /data over SMB so the Mac can mount it (Finder: smb://<beelink>/data).
# Access is restricted to the TAILNET (Tailscale 100.64.0.0/10 + its IPv6 ULA) and
# loopback via `hosts allow`/`hosts deny`, so it is never reachable from the home LAN
# and there is no interface-binding boot race. Idempotent; auto-elevates. macOS: no-op.
#
#   sudo bash ~/dotfiles/scripts/samba-data-share.sh
# then set your SMB password once (separate from your login password):
#   sudo smbpasswd -a <you>
set -euo pipefail

[ "$(uname)" = "Darwin" ] && { echo "samba-data-share: Linux/box only — skipping on macOS"; exit 0; }
[ "$(id -u)" = 0 ] || exec sudo bash "$0" "$@"

SHARE_USER="${SUDO_USER:-martin}"
SHARE_PATH="/data"
[ -d "$SHARE_PATH" ] || { echo "$SHARE_PATH is not mounted — aborting" >&2; exit 1; }

echo "==> installing samba"
DEBIAN_FRONTEND=noninteractive apt-get install -y samba >/dev/null

SMBCONF=/etc/samba/smb.conf
[ -f "$SMBCONF.orig" ] || cp "$SMBCONF" "$SMBCONF.orig"

echo "==> [global]: restrict every share to the tailnet + loopback"
if ! grep -q 'data-share-managed' "$SMBCONF"; then
  sed -i "/^\[global\]/a\\   # data-share-managed (tailnet-only)\n   hosts allow = 100.64.0.0/10 fd7a:115c:a1e0::/48 127.0.0.1 ::1\n   hosts deny = 0.0.0.0/0" "$SMBCONF"
fi

echo "==> [data] share -> $SHARE_PATH (read/write as $SHARE_USER)"
if ! grep -q '^\[data\]' "$SMBCONF"; then
  cat >> "$SMBCONF" <<EOF

[data]
   path = $SHARE_PATH
   browseable = yes
   read only = no
   valid users = $SHARE_USER
   force user = $SHARE_USER
   create mask = 0644
   directory mask = 0755
EOF
fi

echo "==> validating config"
testparm -s >/dev/null

echo "==> enable + (re)start smbd"
systemctl enable --now smbd >/dev/null 2>&1 || true
systemctl restart smbd

echo
echo "✓ Samba is serving /data to the tailnet only."
echo "  1) set your SMB password once:   sudo smbpasswd -a $SHARE_USER"
echo "  2) on the Mac, Finder → ⌘K →      smb://beelink.tail16f7fc.ts.net/data   (user: $SHARE_USER)"
