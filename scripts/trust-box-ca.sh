#!/usr/bin/env bash
# Trust herdr-box's Caddy local CA on THIS Mac, so the box's
# https://<slug>.localhost:9443 dev sites get a green padlock — same idea as
# Herd/Valet trusting their own local CA.
#
# Run once:  bash ~/dotfiles/scripts/trust-box-ca.sh
# Re-run if the box's Caddy root ever rotates (rare; default validity is years).
# Prompts for admin auth to add the root to the System keychain.
set -euo pipefail

HOST="${1:-beelink}"
ROOT_ON_BOX=".local/share/caddy/pki/authorities/local/root.crt"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT

echo "==> fetching Caddy root CA from $HOST"
scp "$HOST:$ROOT_ON_BOX" "$TMP" \
  || { echo "couldn't fetch $ROOT_ON_BOX — has the box served an https site yet (serve up …)?" >&2; exit 1; }

echo "==> trusting it (System keychain; you'll be prompted for admin auth)"
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$TMP"

echo "✓ trusted. Fully quit & reopen the browser if a site still warns."
