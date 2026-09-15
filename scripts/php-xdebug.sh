#!/usr/bin/env bash
# Install Xdebug for every installed PHP version so `composer test` code coverage
# works (pest/phpunit --coverage needs a driver). Xdebug is defaulted to
# xdebug.mode=off — it's dormant (no slowdown) for normal CLI/FPM, and the test
# scripts flip it on per-run via `XDEBUG_MODE=coverage` (env overrides the ini).
# Idempotent. Auto-elevates (apt + writes /etc). macOS: no-op. Needs ppa:ondrej/php.
set -euo pipefail

[ "$(uname)" = "Darwin" ] && { echo "php-xdebug: Linux only — skipping on macOS"; exit 0; }
[ "$(id -u)" = 0 ] || exec sudo bash "$0" "$@"

shopt -s nullglob
vers=()
for d in /etc/php/*/; do v="$(basename "$d")"; [ -d "/etc/php/$v/cli" ] && vers+=("$v"); done
[ "${#vers[@]}" -gt 0 ] || { echo "no PHP installs under /etc/php — nothing to do"; exit 0; }

for v in "${vers[@]}"; do
  echo "==> php$v: xdebug + default mode=off"
  apt-get install -y "php$v-xdebug" >/dev/null
  # 99- drop-in loads after the package's 20-xdebug.ini, so it wins.
  for sapi in cli fpm; do
    d="/etc/php/$v/$sapi/conf.d"
    [ -d "$d" ] && printf 'xdebug.mode=off\n' > "$d/99-xdebug-off.ini"
  done
  systemctl restart "php$v-fpm" 2>/dev/null || true
  if php"$v" -m 2>/dev/null | grep -qi xdebug; then
    echo "   ✓ loaded (default mode: $(XDEBUG_MODE= php"$v" -r 'echo ini_get("xdebug.mode") ?: "off";' 2>/dev/null))"
  else
    echo "   ✗ xdebug not loaded for php$v"
  fi
done
echo "✓ coverage available on demand — e.g. XDEBUG_MODE=coverage pest --coverage (composer test does this)"
