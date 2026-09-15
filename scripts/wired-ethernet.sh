#!/usr/bin/env bash
# Configure the wired port (enp2s0) for DHCP so the box uses the cable when it's plugged
# in. The port had NO netplan entry, so systemd-networkd left it administratively DOWN and
# cables never linked (it was never the cable). `optional: true` keeps boot from waiting on
# it when no cable is present; a low route-metric makes wired win over WiFi when both are up.
# Idempotent; auto-elevates. macOS: no-op.
#
#   sudo bash ~/dotfiles/scripts/wired-ethernet.sh
set -euo pipefail

[ "$(uname)" = "Darwin" ] && { echo "wired-ethernet: Linux/box only — skipping on macOS"; exit 0; }
[ "$(id -u)" = 0 ] || exec sudo bash "$0" "$@"

IFACE="${WIRED_IFACE:-enp2s0}"
CONF="/etc/netplan/60-wired.yaml"

cat > "$CONF" <<EOF
network:
  version: 2
  ethernets:
    ${IFACE}:
      dhcp4: true
      optional: true
      dhcp4-overrides:
        route-metric: 100
EOF
chmod 600 "$CONF"
echo "==> wrote $CONF"

netplan generate
netplan apply
sleep 3

echo "==> ${IFACE} state (want UP + an IP if the cable is linked):"
ip -br addr show "$IFACE" 2>/dev/null | sed 's/^/   /'
echo "==> carrier: $(cat "/sys/class/net/${IFACE}/carrier" 2>&1)   (1 = cable linked, 0 = no link -> check cable/port)"
echo "==> default route (want it via ${IFACE} once linked):"
ip route show default 2>/dev/null | sed 's/^/   /'
