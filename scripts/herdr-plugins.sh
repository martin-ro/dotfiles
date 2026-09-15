#!/usr/bin/env bash
# Clone + link the herdr plugins that shape new workspaces on this box:
#   treeupdown             — per-project worktree setup/teardown (DB clone, serve, bucket)
#   herdr-workspace-layout — the standard tab/pane layout (opens/names/sizes panes)
# Idempotent. Run as your user (uses systemctl --user + your GitHub SSH key), not sudo.
# macOS: no-op. Called from bootstrap.sh after herdr-service.sh.
set -euo pipefail

[ "$(uname)" = "Darwin" ] && { echo "herdr-plugins: Linux/box only — skipping on macOS"; exit 0; }
if [ "$(id -u)" = 0 ]; then echo "Run as your user, not sudo: bash ~/dotfiles/scripts/herdr-plugins.sh" >&2; exit 1; fi
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"; export XDG_RUNTIME_DIR
HERDR="$HOME/.local/bin/herdr"
command -v "$HERDR" >/dev/null 2>&1 || { echo "herdr not installed yet — skipping plugin link"; exit 0; }

# name  git-remote  (cloned into ~/code, then `herdr plugin link`ed)
PLUGINS=(
  "treeupdown             git@github.com:martin-ro/treeupdown.git"
  "herdr-workspace-layout git@github.com:martin-ro/herdr-workspace-layout.git"
)

echo "==> herdr plugin repos (~/code)"
mkdir -p "$HOME/code"
for p in "${PLUGINS[@]}"; do
  read -r name url <<<"$p"; dir="$HOME/code/$name"
  if [ -d "$dir/.git" ]; then echo "   $name: present"
  elif git clone -q "$url" "$dir"; then echo "   $name: cloned"
  else echo "   $name: clone FAILED (is your GitHub SSH key set up?)"; fi
done

# `herdr plugin link` talks to the running server, so make sure it's up.
systemctl --user start herdr.service 2>/dev/null || true
for _ in $(seq 1 10); do "$HERDR" status server >/dev/null 2>&1 && break; sleep 1; done

echo "==> linking plugins"
for p in "${PLUGINS[@]}"; do
  read -r name url <<<"$p"; dir="$HOME/code/$name"
  [ -f "$dir/herdr-plugin.toml" ] || { echo "   $name: no herdr-plugin.toml, skipped"; continue; }
  "$HERDR" plugin link "$dir" >/dev/null 2>&1 && echo "   $name: linked" || echo "   $name: link failed (is herdr running?)"
done
"$HERDR" plugin list 2>/dev/null | grep -iE 'enabled' | sed 's/^/   /' || true
