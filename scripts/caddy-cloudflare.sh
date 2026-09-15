#!/usr/bin/env bash
# Install a Caddy binary that bundles the caddy-dns/cloudflare plugin (needed for the
# *.dev.martin.ph wildcard cert via DNS-01) and run it via a systemd --user drop-in over
# the stock caddy. Lets `phone` publish dev sites on the tailnet. Idempotent; no sudo.
# macOS: no-op.
#
# Two things stay MANUAL (secrets/DNS — documented at the end + in the `phone` script):
#   1. ~/.config/caddy/cf-dns.env  ->  CF_API_TOKEN=<Cloudflare token, Zone:DNS:Edit on martin.ph>
#   2. Cloudflare DNS:  *.dev.martin.ph  A  ->  the box's tailnet IP  (DNS only / grey cloud)
set -euo pipefail

[ "$(uname)" = "Darwin" ] && { echo "caddy-cloudflare: Linux/box only — skipping on macOS"; exit 0; }

BIN="$HOME/.local/bin/caddy"
DROPIN_DIR="$HOME/.config/systemd/user/caddy.service.d"

# 1. ensure ~/.local/bin/caddy has the cloudflare DNS module
if ! "$BIN" list-modules 2>/dev/null | grep -q '^dns\.providers\.cloudflare$'; then
  case "$(uname -m)" in
    x86_64|amd64)  arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "caddy-cloudflare: unsupported arch $(uname -m)" >&2; exit 1 ;;
  esac
  echo "==> downloading caddy + caddy-dns/cloudflare ($arch) ..."
  tmp="$(mktemp)"
  curl -fsSL --retry 4 --retry-delay 3 --max-time 300 \
    -o "$tmp" "https://caddyserver.com/api/download?os=linux&arch=${arch}&p=github.com/caddy-dns/cloudflare"
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$tmp" "$BIN"
  rm -f "$tmp"
  echo "    installed $("$BIN" version | awk '{print $1}') at $BIN"
else
  echo "==> $BIN already has the cloudflare module — ok"
fi

# 2. systemd --user drop-in: run this binary + load the CF token (optional until it exists)
mkdir -p "$DROPIN_DIR"
cat > "$DROPIN_DIR/10-cloudflare.conf" <<'EOF'
[Service]
# Use the Caddy build that includes caddy-dns/cloudflare (for *.dev.martin.ph DNS-01).
ExecStart=
ExecStart=%h/.local/bin/caddy run --config %h/.config/caddy/Caddyfile --adapter caddyfile
ExecReload=
ExecReload=%h/.local/bin/caddy reload --config %h/.config/caddy/Caddyfile --force
# CF_API_TOKEN for the Cloudflare DNS challenge; '-' = optional so caddy still starts before it exists.
EnvironmentFile=-%h/.config/caddy/cf-dns.env
EOF
echo "==> wrote $DROPIN_DIR/10-cloudflare.conf"

# 3. apply if the caddy user service exists
if systemctl --user show caddy >/dev/null 2>&1; then
  systemctl --user daemon-reload
  systemctl --user restart caddy 2>/dev/null || true
  echo "==> reloaded systemd + restarted caddy"
fi

# 4. remind about the manual secret/DNS bits if not yet present
if [ ! -s "$HOME/.config/caddy/cf-dns.env" ]; then
  cat <<'NOTE'

NOTE: tailnet dev sites (*.dev.martin.ph, reachable from your phone) also need,
one-time and manual:
  1. Cloudflare API token (Zone:DNS:Edit on martin.ph):
       umask 077 && printf 'CF_API_TOKEN=%s\n' 'TOKEN' > ~/.config/caddy/cf-dns.env
  2. Cloudflare DNS record:  *.dev.martin.ph  A  ->  the box's tailnet IP  (DNS only)
  then:  systemctl --user restart caddy && phone
NOTE
fi
