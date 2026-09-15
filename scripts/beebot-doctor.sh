#!/usr/bin/env bash
# Verify the BeeBot GitHub App credential is present and working on this box.
#
# The bee-bot secret (App private key + config) is deliberately NOT tracked in
# dotfiles — so a freshly bootstrapped box has the `gh-app` wrapper but no key,
# and any `bot`-mode push silently breaks mid-flow. This is the safeguard that
# surfaces that gap loudly at bootstrap instead, with the exact fix.
#
# Exit 0 = configured & working. Exit 1 = needs setup (prints how). Never fatal
# to bootstrap (callers use `|| true`): a box can be perfectly usable without it.
#
#   bash ~/dotfiles/scripts/beebot-doctor.sh
set -euo pipefail

CONFIG="${BEEBOT_CONFIG:-$HOME/.config/beebot/config}"

if ! command -v gh-app >/dev/null 2>&1; then
  echo "beebot: gh-app wrapper not on PATH — commit attribution still works, but bot pushes won't."
  echo "        (the wrapper ships from ~/code/bee-bot; run its bin/install.sh)"
  exit 1
fi

if [ ! -f "$CONFIG" ]; then
  cat <<EOF
beebot: NOT configured on this box — bot-mode commits are fine (authored as
        beecodebot[bot] and correct on GitHub), but pushing/opening PRs *as the
        App* will fail until you add the private key. This box's dotfiles do not
        carry the secret by design.

        To restore (needs a desktop — the key can't be downloaded on a phone):
          • copy an existing working config over:  scp -r <host>:~/.config/beebot ~/.config/
          • or generate a fresh key on the GitHub App page, then:  gh-app setup

        Config expected at: $CONFIG
EOF
  exit 1
fi

# Config present — prove it actually mints a token.
if ! gh-app whoami >/dev/null 2>&1; then
  echo "beebot: config exists at $CONFIG but 'gh-app whoami' failed — key may be"
  echo "        wrong/revoked or the App isn't installed. Re-run: gh-app setup"
  exit 1
fi

# Key works. Now prove installation coverage: gh-app resolves the App
# installation per repo owner, so every local bot-mode repo's origin owner
# needs its own installation. whoami cannot see this gap; a push hits it.
installed="$(gh-app installations 2>/dev/null | cut -f2 | tr '[:upper:]' '[:lower:]' | tr '\n' ' ' | sed 's/ $//')"
missing=""
for repo in "$HOME"/code/*/; do
  [ "$(git -C "$repo" config --get author.mode 2>/dev/null || true)" = "bot" ] || continue
  url="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"
  [ -n "$url" ] || continue
  owner="$(printf '%s' "$url" \
    | sed -E 's#^(git@github\.com:|ssh://git@github\.com/|https://([^@/]+@)?github\.com/)##; s#/.*$##' \
    | tr '[:upper:]' '[:lower:]')"
  [ -n "$owner" ] || continue
  case " $installed $missing " in *" $owner "*) continue ;; esac
  missing="$missing $owner"
done
missing="${missing# }"

if [ -n "$missing" ]; then
  echo "beebot: key works, but the App has NO installation for: $missing"
  echo "        Bot pushes/PRs in repos under those accounts will fail."
  echo "        Install it there: https://github.com/apps/beecodebot/installations/new"
  echo "        (installed on: $installed)"
  exit 1
fi

echo "✓ beebot: configured and working — $(gh-app whoami 2>/dev/null | head -1)"
[ -n "$installed" ] && echo "✓ beebot: installations cover all local bot-mode repos ($(printf '%s' "$installed" | sed 's/ /, /g'))"
exit 0
