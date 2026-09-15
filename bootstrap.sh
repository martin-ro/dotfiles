#!/usr/bin/env bash
# Bootstrap these dotfiles on a fresh Debian/Ubuntu machine.
# Run from the repo root:  ./bootstrap.sh
set -euo pipefail

DF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DF"

echo "==> System packages (apt)"
sudo apt-get update -y
sudo apt-get install -y stow git build-essential curl unzip git-delta git-lfs redis-server bat btop htop

echo "==> Neovim (latest release to ~/.local; apt's 0.9/0.10 is too old for the nvim config)"
export PATH="$HOME/.local/bin:$PATH"   # so the headless Lazy sync below finds this nvim
mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
if curl -fsSL -o /tmp/nvim.tar.gz \
    "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"; then
  rm -rf "$HOME/.local/opt/nvim" "$HOME/.local/opt/nvim-linux-x86_64"
  tar -xzf /tmp/nvim.tar.gz -C "$HOME/.local/opt"
  mv "$HOME/.local/opt/nvim-linux-x86_64" "$HOME/.local/opt/nvim"
  ln -sf "$HOME/.local/opt/nvim/bin/nvim" "$HOME/.local/bin/nvim"
  rm -f /tmp/nvim.tar.gz && nvim --version | head -1
else
  echo "   nvim download failed; falling back to apt"; sudo apt-get install -y neovim
fi

echo "==> PHP (ondrej PPA) + direnv + per-project shims"
sudo apt-get install -y software-properties-common
if ls /etc/apt/sources.list.d/*ondrej*php* >/dev/null 2>&1; then
  echo "   ondrej PHP PPA already present"
else
  sudo add-apt-repository -y ppa:ondrej/php \
    || echo "   PPA add failed (Launchpad timeout?); continuing with existing PHP"
fi
sudo apt-get update -y
for v in 8.2 8.3 8.4 8.5; do
  sudo apt-get install -y \
    php"$v"-cli php"$v"-fpm php"$v"-common php"$v"-mysql php"$v"-sqlite3 php"$v"-mbstring \
    php"$v"-xml php"$v"-curl php"$v"-zip php"$v"-bcmath php"$v"-gd php"$v"-intl php"$v"-redis \
    php"$v"-imagick
  mkdir -p "$HOME/.php-shims/$v"
  ln -sf "/usr/bin/php$v" "$HOME/.php-shims/$v/php"
done
sudo apt-get install -y direnv
sudo update-alternatives --set php /usr/bin/php8.4

echo "==> Xdebug for each PHP (coverage for 'composer test'; default mode=off)"
bash "$DF/scripts/php-xdebug.sh" || echo "   (run scripts/php-xdebug.sh with sudo later)"

echo "==> Composer (to ~/.local/bin)"
mkdir -p "$HOME/.local/bin"
if [ ! -x "$HOME/.local/bin/composer" ]; then
  php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
  php /tmp/composer-setup.php --quiet --install-dir="$HOME/.local/bin" --filename=composer
  rm -f /tmp/composer-setup.php
fi
"$HOME/.local/bin/composer" --version

echo "==> Node (fnm) + Bun + tree-sitter CLI"
curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env)"
fnm install --lts
fnm default lts-latest
npm install -g tree-sitter-cli      # nvim-treesitter (main branch) builds parsers via this
curl -fsSL https://bun.sh/install | bash

echo "==> herdr (agent orchestration)"
curl -fsSL https://herdr.dev/install.sh | sh

echo "==> mydumper (fast parallel DB clone for worktree setup; apt's is too old for --optimize-keys)"
curl -fsSL -o /tmp/mydumper.deb \
  https://github.com/mydumper/mydumper/releases/download/v1.0.3-1/mydumper_1.0.3-1.noble_amd64.deb \
  && sudo apt-get install -y /tmp/mydumper.deb && rm -f /tmp/mydumper.deb

echo "==> GitHub CLI (gh, to ~/.local/bin; assets are versioned so resolve latest via API)"
if [ ! -x "$HOME/.local/bin/gh" ]; then
  GH_VER="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | grep -oP '"tag_name":\s*"v?\K[0-9.]+' | head -1)"
  if [ -n "$GH_VER" ] && curl -fsSL -o /tmp/gh.tar.gz \
       "https://github.com/cli/cli/releases/download/v${GH_VER}/gh_${GH_VER}_linux_amd64.tar.gz"; then
    tar -xzf /tmp/gh.tar.gz -C /tmp
    install -m 755 "/tmp/gh_${GH_VER}_linux_amd64/bin/gh" "$HOME/.local/bin/gh"
    rm -rf /tmp/gh.tar.gz "/tmp/gh_${GH_VER}_linux_amd64"
  else
    echo "   gh download failed; run 'gh auth login' after installing it manually later"
  fi
fi
command -v gh >/dev/null && gh --version | head -1

echo "==> lazygit (to ~/.local/bin; assets are versioned so resolve latest via API)"
if [ ! -x "$HOME/.local/bin/lazygit" ]; then
  LG_VER="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -oP '"tag_name":\s*"v?\K[0-9.]+' | head -1)"
  if [ -n "$LG_VER" ] && curl -fsSL -o /tmp/lazygit.tar.gz \
       "https://github.com/jesseduffield/lazygit/releases/download/v${LG_VER}/lazygit_${LG_VER}_Linux_x86_64.tar.gz"; then
    tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit
    install -m 755 /tmp/lazygit "$HOME/.local/bin/lazygit"
    rm -f /tmp/lazygit.tar.gz /tmp/lazygit
  else
    echo "   lazygit download failed; install it manually later"
  fi
fi
command -v lazygit >/dev/null && lazygit --version 2>/dev/null | grep -oE 'version=[0-9.]+'

echo "==> Claude Code (native installer -> ~/.local/bin/claude; ~/.claude data/creds untouched)"
if [ ! -x "$HOME/.local/bin/claude" ]; then
  curl -fsSL https://claude.ai/install.sh | bash \
    || echo "   claude install failed; see https://code.claude.com/docs/en/setup"
fi
command -v claude >/dev/null && claude --version | head -1 || true

echo "==> Backing up & removing any non-symlink files that would block stow"
BK="$HOME/dotfiles_backup_$(date +%Y%m%d%H%M%S)"
mkdir -p "$BK"
for f in .bash_aliases .gitconfig .gitignore_global; do
  if [ -e "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; then mv "$HOME/$f" "$BK/"; fi
done
if [ -e "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then mv "$HOME/.config/nvim" "$BK/nvim"; fi
if [ -e "$HOME/.config/herdr/config.toml" ] && [ ! -L "$HOME/.config/herdr/config.toml" ]; then
  mkdir -p "$BK/.config/herdr"; mv "$HOME/.config/herdr/config.toml" "$BK/.config/herdr/"
fi
if [ -e "$HOME/.claude/CLAUDE.md" ] && [ ! -L "$HOME/.claude/CLAUDE.md" ]; then
  mkdir -p "$BK/.claude"; mv "$HOME/.claude/CLAUDE.md" "$BK/.claude/"
fi
for f in AGENTS.md; do
  if [ -e "$HOME/.codex/$f" ] && [ ! -L "$HOME/.codex/$f" ]; then
    mkdir -p "$BK/.codex"; mv "$HOME/.codex/$f" "$BK/.codex/"
  fi
done
for f in AGENTS.md settings.json pi-fff.json; do
  if [ -e "$HOME/.pi/agent/$f" ] && [ ! -L "$HOME/.pi/agent/$f" ]; then
    mkdir -p "$BK/.pi/agent"; mv "$HOME/.pi/agent/$f" "$BK/.pi/agent/"
  fi
done

echo "==> herdr sound asset at an OS-neutral path (/opt/herdr)"
# herdr [ui.sound] doesn't expand ~ and is validated against the local filesystem,
# so the shared config points at /opt/herdr/ding.mp3 — a symlink to the tracked
# asset, identical on the Mac and the boxes.
sudo mkdir -p /opt/herdr
sudo ln -sf "$DF/herdr/.config/herdr/sound/ding.mp3" /opt/herdr/ding.mp3

echo "==> Stowing packages"
# Real dirs so stow links only the tracked files (not folding a dir that also holds
# runtime state: herdr sockets/logs, picker-plus jump-back state, lazygit state.yml,
# ~/.local/bin binaries, ~/.claude sessions/credentials).
mkdir -p "$HOME/.config/herdr" "$HOME/.config/herdr/plugins/config/herdr-picker-plus" "$HOME/.config/lazygit" "$HOME/.local/bin" "$HOME/.config/caddy/sites" "$HOME/.claude" "$HOME/.codex" "$HOME/.pi/agent" "$HOME/.agents" "$HOME/.grok/rules"
if ! command -v starship >/dev/null 2>&1; then
  echo "==> Starship (same prompt as Omarchy)"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
fi

stow -v -t "$HOME" bash nvim git herdr lazygit bin caddy claude codex yazi pi agents grok starship

# yazi: terminal file manager, not packaged for Ubuntu; install the prebuilt
# release into ~/.local/bin. Idempotent: skips when yazi is already present,
# so upgrade by deleting ~/.local/bin/yazi and rerunning.
if ! command -v yazi >/dev/null 2>&1; then
  echo "==> Installing yazi"
  YAZI_TMP="$(mktemp -d)"
  curl -sL -o "$YAZI_TMP/yazi.zip" \
    "https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip"
  unzip -o -q "$YAZI_TMP/yazi.zip" -d "$YAZI_TMP"
  install -m 755 "$YAZI_TMP"/yazi-*/yazi "$YAZI_TMP"/yazi-*/ya "$HOME/.local/bin/"
  rm -rf "$YAZI_TMP"
fi

# .bashrc / .gitconfig are NOT stowed (tools append to them). Install a thin
# loader that sources the tracked config, so those writes stay machine-local.
for f in .gitconfig; do [ -L "$HOME/$f" ] && rm -f "$HOME/$f"; done
if [ ! -e "$HOME/.bashrc" ]; then
  cp /etc/skel/.bashrc "$HOME/.bashrc"
fi
if ! grep -q 'dotfiles/bash/.bashrc' "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" <<'LOADER'

# Loader: tracked bash config in the repo. Tools may append below.
[ -f "$HOME/dotfiles/bash/.bashrc" ] && . "$HOME/dotfiles/bash/.bashrc"
LOADER
fi
if [ ! -e "$HOME/.gitconfig" ]; then cat > "$HOME/.gitconfig" <<'LOADER'
# Loader: tracked git config is included; tools (gh) may add machine-local config below.
[include]
    path = ~/dotfiles/git/.gitconfig
LOADER
fi

echo "==> MySQL (root / empty password, reachable on 127.0.0.1)"
bash "$DF/scripts/mysql-setup.sh"

echo "==> Local reverse proxy (Caddy + per-user php-fpm pools) for *.localhost dev sites"
bash "$DF/scripts/serve-setup.sh"

echo "==> Caddy w/ Cloudflare DNS plugin (tailnet dev sites at *.dev.martin.ph via 'phone')"
bash "$DF/scripts/caddy-cloudflare.sh" || echo "   (run scripts/caddy-cloudflare.sh later; needs network)"

echo "==> herdr autostart (systemd --user service; survives reboots)"
bash "$DF/scripts/herdr-service.sh" || echo "   (run scripts/herdr-service.sh after herdr is installed)"

echo "==> herdr plugins (treeupdown + workspace-layout; clone into ~/code + link)"
bash "$DF/scripts/herdr-plugins.sh" || echo "   (run scripts/herdr-plugins.sh once your GitHub SSH key is set up)"

echo "==> MinIO (S3 object storage; user service + Caddy proxy)"
bash "$DF/scripts/minio-setup.sh" || echo "   (run scripts/minio-setup.sh to finish MinIO)"

echo "==> Meilisearch (search engine; user service + Caddy proxy)"
bash "$DF/scripts/meilisearch-setup.sh" || echo "   (run scripts/meilisearch-setup.sh to finish Meilisearch)"

echo "==> unattended-upgrades tuning (autoremove old kernels/deps; no auto-reboot)"
bash "$DF/scripts/unattended-tune.sh" || echo "   (run scripts/unattended-tune.sh with sudo later)"

echo "==> disable sleep/suspend (always-on server; reached remotely over Tailscale)"
bash "$DF/scripts/disable-sleep.sh" || echo "   (run scripts/disable-sleep.sh with sudo later)"

echo "==> wired ethernet (enp2s0 DHCP, preferred over WiFi; WiFi stays as failover)"
bash "$DF/scripts/wired-ethernet.sh" || echo "   (run scripts/wired-ethernet.sh with sudo later)"

echo "==> Seeding ~/.bashrc.local if absent"
if [ ! -e "$HOME/.bashrc.local" ]; then
  cat > "$HOME/.bashrc.local" <<'EOF'
# Machine-specific bash config for this host (untracked).
export PATH="$HOME/.local/bin:$PATH"
EOF
fi

echo "==> Checking BeeBot (gh-app) credential — bot-mode pushes need it (secret not in dotfiles)"
bash "$DF/scripts/beebot-doctor.sh" || true

echo "==> Installing nvim plugins (headless; pinned by lazy-lock.json)"
nvim --headless "+Lazy! restore" +qa 2>/dev/null || echo "   (nvim plugin sync will finish on first launch)"

echo
echo "==> Setting bash as the login shell and removing zsh"
BASH_BIN="$(command -v bash)"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$BASH_BIN" ]; then
  sudo chsh -s "$BASH_BIN" "$USER" && echo "   login shell -> bash"
else
  echo "   already bash"
fi
sudo apt-get remove --purge -y zsh zsh-common 2>/dev/null || true
rm -rf "$HOME/.oh-my-zsh" "$HOME/.config/zsh"
rm -f "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.zsh_aliases" "$HOME/.p10k.zsh" \
      "$HOME/.zshrc.local" "$HOME/.zsh_aliases.local" "$HOME/.zsh_history"
echo
echo "Done. Log out and back in (or 'exec bash') to land in bash with the aliases + prompt."
