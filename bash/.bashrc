# Tracked bash config. Sourced from ~/.bashrc. Machine-local extras: ~/.bashrc.local.

export PATH="$HOME/.local/bin:$PATH"
unset LG_CONFIG_FILE

[ -f "$HOME/.bash_aliases" ] && . "$HOME/.bash_aliases"

if command -v nvim >/dev/null 2>&1; then
  export EDITOR=nvim VISUAL=nvim
elif command -v vim >/dev/null 2>&1; then
  export EDITOR=vim VISUAL=vim
fi

[ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

if [ -d "$HOME/.local/share/fnm" ]; then
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env --use-on-cd --shell bash)"
fi

if [ -d "$HOME/.bun" ]; then
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
fi

command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"

if command -v starship >/dev/null 2>&1 && [[ ${TERM:-} != dumb ]]; then
  eval "$(starship init bash)"
elif [ -f /usr/lib/git-core/git-sh-prompt ]; then
  . /usr/lib/git-core/git-sh-prompt
  GIT_PS1_SHOWDIRTYSTATE=1
  GIT_PS1_SHOWUNTRACKEDFILES=1
  PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$(__git_ps1 " (%s)")\$ '
fi

[ -r "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local"
