#!/usr/bin/env bash
# Open the box's OpenSSH on port 2222 (IPv4 AND IPv6) for the CI auto-deploy.
# Tailscale SSH owns :22, so the GitHub Actions runner must reach the box's real
# OpenSSH on :2222 (with the locked-down deploy key). Ubuntu socket-activates ssh,
# so the port lives in ssh.socket, NOT sshd_config — and a bare `ListenStream=2222`
# comes up IPv6-only, which refuses the runner's IPv4 connection. Bind both stacks
# explicitly. Idempotent; auto-elevates. macOS: no-op.
#
#   sudo bash ~/dotfiles/scripts/deploy-ssh-port.sh
set -euo pipefail

[ "$(uname)" = "Darwin" ] && { echo "deploy-ssh-port: Linux/box only — skipping on macOS"; exit 0; }
[ "$(id -u)" = 0 ] || exec sudo bash "$0" "$@"

mkdir -p /etc/systemd/system/ssh.socket.d
cat > /etc/systemd/system/ssh.socket.d/10-deploy-port.conf <<'EOF'
[Socket]
ListenStream=0.0.0.0:2222
ListenStream=[::]:2222
EOF
systemctl daemon-reload
systemctl restart ssh.socket

echo "==> :2222 listeners (want both 0.0.0.0:2222 and [::]:2222):"
ss -tlnH 2>/dev/null | awk '$4 ~ /:2222$/ {print "   "$4}' || true
