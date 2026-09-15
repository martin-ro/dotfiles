#!/usr/bin/env bash
# Guarantee this box never suspends/hibernates — it's an always-on server reached
# remotely over Tailscale, so a suspend would drop it off the network with no way
# to wake it remotely. Masking the sleep targets makes any suspend attempt fail
# (persists across reboots). Idempotent; auto-elevates. macOS: no-op.
#
#   sudo bash ~/dotfiles/scripts/disable-sleep.sh
set -euo pipefail

[ "$(uname)" = "Darwin" ] && { echo "disable-sleep: Linux/box only — skipping on macOS"; exit 0; }
[ "$(id -u)" = 0 ] || exec sudo bash "$0" "$@"

systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null

echo "==> sleep targets now (want: masked):"
for t in sleep suspend hibernate hybrid-sleep; do
  printf "   %-18s %s\n" "$t.target" "$(systemctl is-enabled "$t.target" 2>&1)"
done
echo "✓ suspend/hibernate are disabled — the box cannot sleep."
