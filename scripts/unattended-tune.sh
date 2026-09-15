#!/usr/bin/env bash
# Tune unattended-upgrades on top of the package default (50unattended-upgrades):
#   - auto-remove superseded kernels + unused deps (keeps the small /boot tidy)
#   - pin Automatic-Reboot OFF: this box runs long-lived agents, so we reboot by
#     hand and rely on Ubuntu Pro livepatch for no-reboot kernel security patches.
# Writes a drop-in so the package's own 50unattended-upgrades is never edited.
# Idempotent. Needs root (auto-elevates via sudo). macOS: no-op.
set -euo pipefail

[ "$(uname)" = "Darwin" ] && { echo "unattended-tune: Linux only — skipping on macOS"; exit 0; }
[ "$(id -u)" = 0 ] || exec sudo bash "$0" "$@"
command -v unattended-upgrade >/dev/null 2>&1 || { echo "unattended-upgrades not installed; skipping"; exit 0; }

DROPIN=/etc/apt/apt.conf.d/52unattended-local
cat > "$DROPIN" <<'CONF'
// Managed by dotfiles (scripts/unattended-tune.sh). Local overrides layered on top
// of the package default 50unattended-upgrades (which already applies -security).
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
CONF
chmod 644 "$DROPIN"
echo "✓ wrote $DROPIN"

echo "==> effective values now:"
apt-config dump 2>/dev/null \
  | grep -iE "Unattended-Upgrade::(Remove-Unused-Kernel-Packages|Remove-Unused-Dependencies|Automatic-Reboot) " \
  | sed 's/^/   /'
echo "==> config parses cleanly:"
unattended-upgrade --dry-run >/dev/null 2>&1 && echo "   ok" || echo "   (dry-run reported an issue — check $DROPIN)"
