#!/usr/bin/env bash
# Run the hosted herdr.martin queue worker as a systemd --user service, so background
# jobs (the app uses QUEUE_CONNECTION=database) actually get processed and the worker
# survives reboots (via the user's existing linger). Idempotent; no sudo. macOS: no-op.
#
# After deploying new code, signal the worker to reload: `php artisan queue:restart`
# (it finishes the current job, exits, and systemd restarts it on the new code).
set -euo pipefail

[ "$(uname)" = "Darwin" ] && { echo "herdr-martin-queue: Linux/box only — skipping on macOS"; exit 0; }

APP="$HOME/sites/herdr.martin"
PHP="$(command -v php8.4 || command -v php)"
UNIT="$HOME/.config/systemd/user/herdr-martin-queue.service"

[ -d "$APP" ] || { echo "herdr-martin-queue: $APP not found — is the deploy checkout present?" >&2; exit 1; }
[ -n "$PHP" ]  || { echo "herdr-martin-queue: no php on PATH" >&2; exit 1; }

mkdir -p "$(dirname "$UNIT")"
cat > "$UNIT" <<EOF
[Unit]
Description=herdr.martin queue worker (php artisan queue:work, database queue)
After=network.target

[Service]
Type=simple
WorkingDirectory=${APP}
ExecStart=${PHP} artisan queue:work --sleep=3 --tries=3 --max-time=3600
Restart=always
RestartSec=5
# queue:work handles SIGTERM gracefully (finishes the in-flight job, then exits)
TimeoutStopSec=40

[Install]
WantedBy=default.target
EOF
echo "==> wrote $UNIT (php: $PHP)"

systemctl --user daemon-reload
systemctl --user enable --now herdr-martin-queue.service
sleep 2

echo "==> status:"
systemctl --user --no-pager status herdr-martin-queue.service 2>&1 \
  | grep -iE 'Loaded:|Active:|Main PID:' | sed 's/^/   /'
