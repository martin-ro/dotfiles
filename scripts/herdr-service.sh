#!/usr/bin/env bash
# Install/refresh a systemd --user service so the herdr server auto-starts on boot
# and restarts on failure — i.e. survives box reboots. Idempotent. macOS: no-op.
#
#   bash ~/dotfiles/scripts/herdr-service.sh            # install + enable (no restart)
#   bash ~/dotfiles/scripts/herdr-service.sh --start     # also start now (stops any manual server)
#
# Relies on linger (so the user manager starts at boot without a login) — already
# enabled by scripts/serve-setup.sh; this re-checks and only escalates if missing.
set -euo pipefail

[ "$(uname)" = "Darwin" ] && { echo "herdr-service: Linux/box only — skipping on macOS"; exit 0; }
if [ "$(id -u)" = 0 ]; then echo "Run as your user, not sudo (breaks systemctl --user): bash ~/dotfiles/scripts/herdr-service.sh" >&2; exit 1; fi

UNIT_DIR="$HOME/.config/systemd/user"
UNIT="$UNIT_DIR/herdr.service"
HERDR="$HOME/.local/bin/herdr"
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"; export XDG_RUNTIME_DIR   # so systemctl --user works over ssh too

[ -x "$HERDR" ] || { echo "herdr not found at $HERDR" >&2; exit 1; }

mkdir -p "$UNIT_DIR"
cat > "$UNIT" <<'EOF'
[Unit]
Description=herdr (headless agent-orchestration server)
After=default.target

[Service]
Type=simple
ExecStart=%h/.local/bin/herdr server
ExecStop=%h/.local/bin/herdr server stop
Environment=PATH=%h/.local/bin:%h/.local/share/fnm:/usr/local/bin:/usr/bin:/bin
Environment=SHELL=/usr/bin/bash
Environment=DISABLE_AUTOUPDATER=1
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF

# Linger so the service starts at boot without an interactive login.
if ! loginctl show-user "$USER" -p Linger 2>/dev/null | grep -q 'Linger=yes'; then
  sudo loginctl enable-linger "$USER" 2>/dev/null || echo "  (note: enable linger: sudo loginctl enable-linger $USER)"
fi

systemctl --user daemon-reload          # surfaces a malformed unit now, not at boot
systemctl --user enable herdr.service
echo "✓ herdr.service installed + enabled — autostarts on boot"

if [ "${1:-}" = "--start" ]; then
  "$HERDR" server stop 2>/dev/null || true
  systemctl --user start herdr.service
  echo "✓ started under systemd"
fi

echo "  enabled: $(systemctl --user is-enabled herdr.service 2>/dev/null)"
echo "  manage:  systemctl --user status|start|stop herdr.service"
