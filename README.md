# dotfiles

One stow tree for the Omarchy laptop and the Beelink box.

Machine-local extras: untracked `~/.bashrc.local`.

## Stow

Omarchy (via `omarchy-setup`):

```
agents yazi hyprland bash herdr lazygit nvim starship
```

Optional on Omarchy: `fcitx5`, `bin`, `pi`, `claude`, `codex`, `grok`.

Beelink (`./bootstrap.sh`):

```
bash nvim git herdr lazygit bin caddy claude codex yazi pi agents grok starship
```

Do not stow `hyprland` or `fcitx5` on Beelink.

## Setup

Omarchy: `omarchy-setup` clones/stows this repo.

Beelink:

```sh
git clone git@github.com:martin-ro/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./bootstrap.sh
```
