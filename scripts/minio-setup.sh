#!/usr/bin/env bash
# Install MinIO (S3-compatible object storage) on the box as a per-user systemd
# service (reboot-safe via linger), loopback-bound, fronted by Caddy at
# https://minio.localhost:9443 (console) and https://s3.localhost:9443 (S3 API).
# Idempotent; no sudo. macOS: no-op. Mirrors scripts/serve-setup.sh / herdr-service.sh.
#
#   bash ~/dotfiles/scripts/minio-setup.sh
#
# Credentials default to minioadmin/minioadmin — dev convention (box is loopback-
# bound + tailnet-only, same spirit as MySQL root/empty). Apps use these as
# AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY. Override via MINIO_ROOT_USER/PASSWORD.
set -euo pipefail

[ "$(uname)" = "Darwin" ] && { echo "minio-setup: Linux/box only — skipping on macOS"; exit 0; }
if [ "$(id -u)" = 0 ]; then echo "Run as your user, not sudo (breaks systemctl --user + writes to /root): bash ~/dotfiles/scripts/minio-setup.sh" >&2; exit 1; fi

: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"; export XDG_RUNTIME_DIR   # so systemctl --user works over ssh too
BIN="$HOME/.local/bin"
DATA="$HOME/minio/data"
ENVF="$HOME/.config/minio/minio.env"
UNIT="$HOME/.config/systemd/user/minio.service"
ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
MINIO_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_PASS="${MINIO_ROOT_PASSWORD:-minioadmin}"

mkdir -p "$BIN" "$DATA" "$(dirname "$ENVF")" "$(dirname "$UNIT")" "$HOME/.config/caddy/sites"

echo "==> minio + mc binaries (linux-$ARCH)"
[ -x "$BIN/minio" ] || { curl -fsSL "https://dl.min.io/server/minio/release/linux-$ARCH/minio" -o "$BIN/minio" && chmod +x "$BIN/minio"; }
[ -x "$BIN/mc" ]    || { curl -fsSL "https://dl.min.io/client/mc/release/linux-$ARCH/mc"        -o "$BIN/mc"    && chmod +x "$BIN/mc"; }
"$BIN/minio" --version 2>/dev/null | head -1 | sed 's/^/  /' || true

echo "==> credentials + service env ($ENVF)"
( umask 077; cat > "$ENVF" <<EOF
MINIO_ROOT_USER=$MINIO_USER
MINIO_ROOT_PASSWORD=$MINIO_PASS
MINIO_BROWSER_REDIRECT_URL=https://minio.localhost:9443
EOF
)

echo "==> systemd --user service"
cat > "$UNIT" <<EOF
[Unit]
Description=MinIO (S3-compatible object storage)
After=default.target

[Service]
Type=simple
EnvironmentFile=%h/.config/minio/minio.env
ExecStart=%h/.local/bin/minio server %h/minio/data --address 127.0.0.1:9000 --console-address 127.0.0.1:9001
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now minio.service
echo "  enabled=$(systemctl --user is-enabled minio.service 2>/dev/null) active=$(systemctl --user is-active minio.service 2>/dev/null)"

echo "==> waiting for MinIO to accept connections"
for _ in $(seq 1 30); do
  curl -fsS -o /dev/null "http://127.0.0.1:9000/minio/health/live" 2>/dev/null && { echo "  ready"; break; }
  sleep 1
done

echo "==> mc alias 'local'"
"$BIN/mc" alias set local "http://127.0.0.1:9000" "$MINIO_USER" "$MINIO_PASS" >/dev/null 2>&1 \
  && echo "  alias 'local' -> http://127.0.0.1:9000" || echo "  warn: mc alias set failed"

echo "==> Caddy proxy site (s3.localhost + minio.localhost; reached via the existing tunnel)"
cat > "$HOME/.config/caddy/sites/minio.caddy" <<'EOF'
http://s3.localhost:9080, https://s3.localhost:9443 {
	reverse_proxy 127.0.0.1:9000
}
http://minio.localhost:9080, https://minio.localhost:9443 {
	reverse_proxy 127.0.0.1:9001
}
EOF
caddy reload --address localhost:2019 --config "$HOME/.config/caddy/Caddyfile" --force >/dev/null 2>&1 \
  && echo "  caddy reloaded" || echo "  warn: caddy reload failed (is the caddy user service up?)"

echo
echo "✓ MinIO ready — API 127.0.0.1:9000, console 127.0.0.1:9001"
echo "  Mac (via tunnel):  https://minio.localhost:9443 (console)   https://s3.localhost:9443 (S3)"
echo "  manage: mc ls local   |   creds: $MINIO_USER / $MINIO_PASS"
