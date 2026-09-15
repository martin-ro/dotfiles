#!/usr/bin/env bash
# Install Meilisearch (search engine) on the box as a per-user systemd service
# (reboot-safe via linger), loopback-bound, fronted by Caddy at
# https://meili.localhost:9443. Idempotent; no sudo. macOS: no-op.
# Mirrors scripts/minio-setup.sh.
#
#   bash ~/dotfiles/scripts/meilisearch-setup.sh
#
# Master key defaults to `masterKey` — dev convention (box is loopback-bound +
# tailnet-only, same spirit as MinIO minioadmin / MySQL root-empty) and it matches
# camlovin's MEILISEARCH_KEY. Override via MEILI_MASTER_KEY. Only camlovin uses this.
set -euo pipefail

[ "$(uname)" = "Darwin" ] && { echo "meilisearch-setup: Linux/box only — skipping on macOS"; exit 0; }
if [ "$(id -u)" = 0 ]; then echo "Run as your user, not sudo (breaks systemctl --user + writes to /root): bash ~/dotfiles/scripts/meilisearch-setup.sh" >&2; exit 1; fi

: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"; export XDG_RUNTIME_DIR   # so systemctl --user works over ssh too
BIN="$HOME/.local/bin"
DATA="$HOME/meilisearch/data"
ENVF="$HOME/.config/meilisearch/meilisearch.env"
UNIT="$HOME/.config/systemd/user/meilisearch.service"
ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
case "$ARCH" in arm64) MARCH=aarch64 ;; *) MARCH=amd64 ;; esac
MKEY="${MEILI_MASTER_KEY:-masterKey}"

mkdir -p "$BIN" "$DATA" "$(dirname "$ENVF")" "$(dirname "$UNIT")" "$HOME/.config/caddy/sites"

echo "==> meilisearch binary (linux-$MARCH)"
# Release assets are un-versioned (meilisearch-linux-amd64), so the direct latest URL works.
[ -x "$BIN/meilisearch" ] || { curl -fsSL "https://github.com/meilisearch/meilisearch/releases/latest/download/meilisearch-linux-$MARCH" -o "$BIN/meilisearch" && chmod +x "$BIN/meilisearch"; }
"$BIN/meilisearch" --version 2>/dev/null | head -1 | sed 's/^/  /' || true

echo "==> master key + service env ($ENVF)"
( umask 077; cat > "$ENVF" <<EOF
MEILI_MASTER_KEY=$MKEY
MEILI_ENV=development
MEILI_HTTP_ADDR=127.0.0.1:7700
MEILI_DB_PATH=$DATA
MEILI_NO_ANALYTICS=true
EOF
)

echo "==> systemd --user service"
cat > "$UNIT" <<EOF
[Unit]
Description=Meilisearch (search engine)
After=default.target

[Service]
Type=simple
EnvironmentFile=%h/.config/meilisearch/meilisearch.env
ExecStart=%h/.local/bin/meilisearch
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now meilisearch.service
echo "  enabled=$(systemctl --user is-enabled meilisearch.service 2>/dev/null) active=$(systemctl --user is-active meilisearch.service 2>/dev/null)"

echo "==> waiting for Meilisearch to accept connections"
for _ in $(seq 1 30); do
  curl -fsS -o /dev/null "http://127.0.0.1:7700/health" 2>/dev/null && { echo "  ready"; break; }
  sleep 1
done

echo "==> Caddy proxy site (meili.localhost; reached via the existing tunnel)"
cat > "$HOME/.config/caddy/sites/meilisearch.caddy" <<'EOF'
http://meili.localhost:9080, https://meili.localhost:9443 {
	reverse_proxy 127.0.0.1:7700
}
EOF
caddy reload --address localhost:2019 --config "$HOME/.config/caddy/Caddyfile" --force >/dev/null 2>&1 \
  && echo "  caddy reloaded" || echo "  warn: caddy reload failed (is the caddy user service up?)"

echo
echo "✓ Meilisearch ready — 127.0.0.1:7700  (master key: $MKEY)"
echo "  Mac (via tunnel):  https://meili.localhost:9443   (dev search-preview UI + /health)"
echo "  used by camlovin (SCOUT_DRIVER=meilisearch); populate: cd ~/code/camlovin && php artisan scout:import \"App\\Models\\Cam\""
