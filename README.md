# dotfiles

One stow tree for the Omarchy laptop, the Beelink box and the Mac (bash and Starship only).

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

Mac (bash and Starship only; `~/dotfiles` there is an older copy of this repo, still used for other configs):

```sh
brew install bash bash-completion@2 starship eza zoxide fzf bat stow
git clone https://github.com/martin-ro/dotfiles.git ~/Work/dotfiles
cd ~/Work/dotfiles && stow -t ~ bash starship
echo /opt/homebrew/bin/bash | sudo tee -a /etc/shells && chsh -s /opt/homebrew/bin/bash
```

The Mac's `~/.bashrc` sets PATH (Homebrew etc.), then sources `~/Work/dotfiles/bash/.bashrc`; `~/.bash_profile` sources `~/.bashrc`.
