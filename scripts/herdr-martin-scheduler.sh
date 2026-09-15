#!/usr/bin/env bash
# Run the hosted herdr.martin scheduler as a systemd --user service, so scheduled
# commands (e.g. `herdr:notify-attention` ->everyMinute) actually fire. Laravel's
# scheduler only runs when a process invokes it every minute; `schedule:work` is a
# long-running process that does exactly that (no crontab needed). Reboot-safe via
# the user's linger. Idempotent; no sudo. macOS: no-op.
#
# Companion to scripts/herdr-martin-queue.sh — that runs the queue *worker* (jobs);
# this runs the *scheduler* (timed commands). Both are needed.
set -euo pipefail

[ "$(uname)" = "Darwin" ] && { echo "herdr-martin-scheduler: Linux/box only — skipping on macOS"; exit 0; }

APP="$HOME/sites/herdr.martin"
PHP="$(command -v php8.4 || command -v php)"
UNIT="$HOME/.config/systemd/user/herdr-martin-scheduler.service"

[ -d "$APP" ] || { echo "herdr-martin-scheduler: $APP not found — is the deploy checkout present?" >&2; exit 1; }
[ -n "$PHP" ]  || { echo "herdr-martin-scheduler: no php on PATH" >&2; exit 1; }

mkdir -p "$(dirname "$UNIT")"
cat > "$UNIT" <<EOF
[Unit]
Description=herdr.martin scheduler (php artisan schedule:work)
After=network.target

[Service]
Type=simple
WorkingDirectory=${APP}
ExecStart=${PHP} artisan schedule:work
Restart=always
RestartSec=5
TimeoutStopSec=40

[Install]
WantedBy=default.target
EOF
echo "==> wrote $UNIT (php: $PHP)"

systemctl --user daemon-reload
systemctl --user enable --now herdr-martin-scheduler.service
sleep 2

echo "==> status:"
systemctl --user --no-pager status herdr-martin-scheduler.service 2>&1 \
  | grep -iE 'Loaded:|Active:|Main PID:' | sed 's/^/   /'
