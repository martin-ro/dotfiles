#!/usr/bin/env bash
# Keep the beelink tunnels up in the background via a launchd agent:
#   - dev reverse proxy   127.0.0.1:9080 + :9443
#   - MySQL               127.0.0.1:13306 -> beelink 3306  (TablePlus etc.; 13306 avoids Herd's 3306)
#   - Meilisearch         127.0.0.1:7700  -> beelink 7700  (so browser search hitting
#     http://127.0.0.1:7700 reaches the box's Meilisearch — same port both ends, no app change).
#     NB: nothing else may hold the Mac's 7700 (e.g. a Takeout Meilisearch) or the tunnel
#     won't bind it (ExitOnForwardFailure). Stop Takeout's meili — you're off it now anyway.
#   - Vite dev server     127.0.0.1:5173  -> beelink 5173  (SEPARATE agent, $LABEL-vite).
#     Laravel's public/hot on the box points browsers at http://127.0.0.1:5173, so this
#     forward makes `bun/npm run dev` on the box hot-reload here with the repo's vite
#     config left stock. Chrome exempts loopback from mixed-content blocking, so the
#     https://<slug>.localhost:9443 page may load these http:// assets (Safari won't).
#     Isolated in its own agent because a Mac-local Vite (e.g. mobile-kit `vp dev`)
#     can legitimately hold 5173 — then only this agent cycles, not the main tunnel.
# Starts at login, restarts on drop/sleep/network change. macOS only.
#
#   bash ~/dotfiles/scripts/tunnel-service.sh            # install + start
#   bash ~/dotfiles/scripts/tunnel-service.sh status
#   bash ~/dotfiles/scripts/tunnel-service.sh uninstall
#
# Requires that `ssh beelink` connects WITHOUT a prompt — Tailscale SSH handles
# that keylessly for tailnet peers, so no key setup is needed.
set -euo pipefail

# macOS-only: this manages a launchd agent on the Mac that tunnels INTO the beelink.
# Running it on the box (Linux) is a mistake — bail with a clear message.
[ "$(uname)" = "Darwin" ] || { echo "tunnel-service.sh is macOS-only — run it on your Mac, not the box (it sets up the Mac→beelink launchd tunnel)." >&2; exit 1; }

LABEL="com.martinro.herdr-tunnel"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/herdr-tunnel.log"
LABEL_VITE="$LABEL-vite"
PLIST_VITE="$HOME/Library/LaunchAgents/$LABEL_VITE.plist"
LOG_VITE="$HOME/Library/Logs/herdr-tunnel-vite.log"
HOST="beelink"
SSH_BIN="$(command -v ssh)"
UID_NUM="$(id -u)"
DOMAIN="gui/$UID_NUM"

usage() { echo "usage: tunnel-service.sh {install|status|uninstall}"; exit 1; }

# Kill any hand-run `ssh -L 9080/9443 … herdr-box` so the agent can bind the ports.
kill_manual() {
  pgrep -fl "ssh .*-L 9080:127.0.0.1:9080" 2>/dev/null \
    | grep -v "$LABEL" | awk '{print $1}' | xargs -r kill 2>/dev/null || true
}

case "${1:-install}" in
  install|reinstall|start)
    mkdir -p "$HOME/Library/LaunchAgents" "$(dirname "$LOG")"
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$SSH_BIN</string>
    <string>-N</string>
    <string>-o</string><string>BatchMode=yes</string>
    <string>-o</string><string>ExitOnForwardFailure=yes</string>
    <string>-o</string><string>ServerAliveInterval=30</string>
    <string>-o</string><string>ServerAliveCountMax=3</string>
    <string>-o</string><string>ConnectTimeout=10</string>
    <string>-o</string><string>StrictHostKeyChecking=accept-new</string>
    <string>-L</string><string>9080:127.0.0.1:9080</string>
    <string>-L</string><string>9443:127.0.0.1:9443</string>
    <string>-L</string><string>13306:127.0.0.1:3306</string>
    <string>-L</string><string>7700:127.0.0.1:7700</string>
    <string>$HOST</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF
    cat > "$PLIST_VITE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL_VITE</string>
  <key>ProgramArguments</key>
  <array>
    <string>$SSH_BIN</string>
    <string>-N</string>
    <string>-o</string><string>BatchMode=yes</string>
    <string>-o</string><string>ExitOnForwardFailure=yes</string>
    <string>-o</string><string>ServerAliveInterval=30</string>
    <string>-o</string><string>ServerAliveCountMax=3</string>
    <string>-o</string><string>ConnectTimeout=10</string>
    <string>-o</string><string>StrictHostKeyChecking=accept-new</string>
    <string>-L</string><string>5173:127.0.0.1:5173</string>
    <string>$HOST</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>StandardOutPath</key><string>$LOG_VITE</string>
  <key>StandardErrorPath</key><string>$LOG_VITE</string>
</dict>
</plist>
EOF
    kill_manual
    for l in "$LABEL" "$LABEL_VITE"; do
      launchctl bootout "$DOMAIN/$l" 2>/dev/null || true
    done
    launchctl bootstrap "$DOMAIN" "$PLIST"
    launchctl enable "$DOMAIN/$LABEL"
    launchctl bootstrap "$DOMAIN" "$PLIST_VITE"
    launchctl enable "$DOMAIN/$LABEL_VITE"
    echo "✓ installed + started: $LABEL (+ $LABEL_VITE for Vite's :5173)"
    echo "  logs: $LOG / $LOG_VITE   (tunnels auto-start at login from now on)"
    ;;
  status)
    for l in "$LABEL" "$LABEL_VITE"; do
      echo "  $l:"
      launchctl print "$DOMAIN/$l" 2>/dev/null | grep -E '^\s*(state|pid) =' | sed 's/^/  /' || echo "    not loaded"
    done
    echo "  listeners:"
    lsof -nP -iTCP:9080 -iTCP:9443 -iTCP:13306 -iTCP:7700 -iTCP:5173 -sTCP:LISTEN 2>/dev/null | awk 'NR>1{print "    "$1, $2, $9}' || echo "    (none)"
    ;;
  uninstall|stop)
    for l in "$LABEL" "$LABEL_VITE"; do
      launchctl bootout "$DOMAIN/$l" 2>/dev/null || true
    done
    rm -f "$PLIST" "$PLIST_VITE"
    echo "✓ uninstalled $LABEL + $LABEL_VITE"
    ;;
  *) usage ;;
esac
