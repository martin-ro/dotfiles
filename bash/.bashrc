# Tracked bash config. Sourced from ~/.bashrc. Machine-local extras: ~/.bashrc.local.

export PATH="$HOME/.local/bin:$PATH"
export SHELL="$BASH" # the bash running this: /usr/bin/bash on Linux, Homebrew's on the mac

if [ -f "$HOME/.config/lazygit/theme.yml" ]; then
  export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/theme.yml"
elif [ -f "$HOME/.local/state/omarchy/current/theme/lazygit.yml" ]; then
  export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml,$HOME/.local/state/omarchy/current/theme/lazygit.yml"
fi

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

# Omarchy's history, completion, ls, cd and fzf, for the machines without Omarchy (Beelink, the
# Mac). The Omarchy laptop's ~/.bashrc loads Omarchy's own. Copied from
# /usr/share/omarchy/default/bash (shell, aliases, init, inputrc) on 2026-11-05.
if [[ ! -r /usr/share/omarchy/default/bash/rc ]]; then
  shopt -s histappend
  HISTCONTROL=ignoreboth
  HISTSIZE=32768
  HISTFILESIZE="${HISTSIZE}"

  if [[ -z ${BASH_COMPLETION_VERSINFO-} ]]; then
    for f in /usr/share/bash-completion/bash_completion "${HOMEBREW_PREFIX:-/opt/homebrew}/etc/profile.d/bash_completion.sh"; do
      [[ -r $f ]] && { . "$f"; break; }
    done
  fi

  if command -v eza &>/dev/null; then
    alias ls='eza -lh --group-directories-first --icons=auto'
    alias lsa='ls -a'
    alias lt='eza --tree --level=2 --long --icons --git'
    alias lta='lt -a'
  fi

  if command -v fzf &>/dev/null; then
    eval "$(fzf --bash 2>/dev/null)" # key bindings (fzf 0.48 or newer)
    alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
    alias eff='$EDITOR "$(ff)"'
  fi

  if command -v zoxide &>/dev/null; then
    eval "$(zoxide init bash)"
    alias cd="zd"
    zd() {
      if (( $# == 0 )); then
        builtin cd ~ || return
      elif [[ -d $1 ]]; then
        builtin cd "$1" || return
      else
        if ! z "$@"; then
          echo "Error: Directory not found"
          return 1
        fi
        printf "\U000F17A9 "
        pwd
      fi
      # fnm's --use-on-cd (Beelink) hooks cd too, and this alias replaces its own.
      if declare -F __fnm_use_if_file_found >/dev/null; then __fnm_use_if_file_found; fi
    }
  fi

  [[ $- == *i* ]] && bind \
    'set meta-flag on' 'set input-meta on' 'set output-meta on' 'set convert-meta off' \
    'set completion-ignore-case on' 'set completion-prefix-display-length 2' \
    'set show-all-if-ambiguous on' 'set show-all-if-unmodified on' \
    '"\e[A": history-search-backward' '"\e[B": history-search-forward' \
    '"\e[C": forward-char' '"\e[D": backward-char' \
    'set mark-symlinked-directories on' 'set match-hidden-files off' 'set page-completions off' \
    'set completion-query-items 200' 'set visible-stats on' 'set skip-completed-text on' \
    'set colored-stats on' 'TAB: menu-complete' '"\e[Z": menu-complete-backward' \
    'set menu-complete-display-prefix on'
fi

[ -r "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local"
