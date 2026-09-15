#!/usr/bin/env bash
# Set up the box's local reverse proxy so many Laravel apps/worktrees can each be
# served at http://<slug>.localhost:8080 (reached from the Mac via the `tunnel`
# alias). Valet/Herd-style: one Caddy front door + a shared php-fpm per version.
#
# Idempotent — safe to re-run. Needs sudo (apt, php-fpm pools, linger) and a real
# login session (uses `systemctl --user`), so run it yourself on the box:
#     bash ~/dotfiles/scripts/serve-setup.sh
#
# Called automatically near the end of bootstrap.sh on fresh boxes.
set -euo pipefail

# Run as your normal user, NOT with sudo — this script uses sudo INTERNALLY for the
# apt / php-fpm-pool / linger steps. Running the whole thing under sudo makes $USER=root,
# creates root-owned fpm pools (php*-fpm-root.sock), and breaks `systemctl --user`.
if [ "$(id -u)" = 0 ]; then
  echo "Don't run this with sudo. Run as your user — it sudo's internally:" >&2
  echo "    bash ~/dotfiles/scripts/serve-setup.sh" >&2
  exit 1
fi

HTTP_PORT=9080    # 8080/443 are taken by Herd on the Mac
HTTPS_PORT=9443
DF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Caddy config (stow + dirs)"
mkdir -p "$HOME/.config/caddy/sites" "$HOME/.local/state/caddy"
if [ ! -e "$HOME/.config/caddy/Caddyfile" ] && command -v stow >/dev/null 2>&1; then
  stow -d "$DF" -t "$HOME" caddy
fi
# A default landing site guarantees import sites/*.caddy always matches a file and
# gives the bare host a helpful page. Regenerated each run (not tracked).
cat > "$HOME/.config/caddy/sites/000-default.caddy" <<EOF
http://localhost:${HTTP_PORT}, https://localhost:${HTTPS_PORT} {
	respond "herdr-box dev proxy — browse https://<project>.localhost:${HTTPS_PORT} (run 'serve list' on the box)" 200
}
EOF

echo "==> Caddy binary (apt)"
if ! command -v caddy >/dev/null 2>&1; then
  sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y caddy
fi
# We run Caddy as a per-user service (below) so it can reach the per-user fpm
# sockets and reload without sudo; disable the packaged system service.
sudo systemctl disable --now caddy 2>/dev/null || true

echo "==> per-user php-fpm pools (so Caddy reaches them & PHP runs as $USER)"
for fpm_dir in /etc/php/*/fpm; do
  [ -d "$fpm_dir/pool.d" ] || continue
  v="$(basename "$(dirname "$fpm_dir")")"
  sudo tee "$fpm_dir/pool.d/$USER.conf" >/dev/null <<EOF
[$USER]
user = $USER
group = $USER
listen = /run/php/php$v-fpm-$USER.sock
listen.owner = $USER
listen.group = $USER
listen.mode = 0660
pm = ondemand
pm.max_children = 10
pm.process_idle_timeout = 30s
catch_workers_output = yes
; Dev box: generous but BOUNDED. Truly unlimited (memory -1 / exec 0) let a stuck
; or runaway request pin a CPU core forever or eat all RAM and wedge the box.
; request_terminate_timeout is fpm's hard wall-clock kill that reaps a worker no
; matter what it's stuck on (infinite loop, slow query, etc.) — the real backstop.
php_admin_value[memory_limit] = 1G
php_admin_value[max_execution_time] = 120
php_admin_value[max_input_time] = 120
php_admin_value[upload_max_filesize] = 1G
php_admin_value[post_max_size] = 1G
request_terminate_timeout = 300
EOF
  sudo systemctl restart "php$v-fpm" 2>/dev/null || true
  echo "   php$v -> /run/php/php$v-fpm-$USER.sock"
done

echo "==> Caddy user service + linger (auto-starts on boot)"
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/caddy.service" <<EOF
[Unit]
Description=Caddy (per-user reverse proxy for *.localhost dev sites)
After=network.target

[Service]
WorkingDirectory=%h/.config/caddy
ExecStart=$(command -v caddy) run --config %h/.config/caddy/Caddyfile --adapter caddyfile
ExecReload=$(command -v caddy) reload --config %h/.config/caddy/Caddyfile --force
Restart=on-failure

[Install]
WantedBy=default.target
EOF
sudo loginctl enable-linger "$USER" 2>/dev/null || true
systemctl --user daemon-reload
systemctl --user enable --now caddy.service

echo
echo "✓ reverse proxy ready on 127.0.0.1 (http :${HTTP_PORT}, https :${HTTPS_PORT})"
echo "  Box:  serve up ~/code/<project>      (worktrees register automatically)"
echo "  Mac:  run 'tunnel', then open https://<project>.localhost:${HTTPS_PORT}"
echo "  Mac:  trust the box's HTTPS once:  bash ~/dotfiles/scripts/trust-box-ca.sh"
