alias vi='nvim'
alias vim='nvim'
alias nvim='nvim'

alias a='php artisan'
alias am='php artisan migrate'
alias amfs='php artisan migrate:fresh --seed'
alias qc='php artisan queue:clear'
alias ql='php artisan queue:listen'
alias acall='php artisan cache:clear; php artisan config:clear; php artisan route:clear; php artisan view:clear'
alias aoc='php artisan optimize:clear'
alias hoc='php artisan horizon:clear'
alias ho='php artisan horizon'
alias houp='php artisan horizon:clear && php artisan horizon'
alias fio='php artisan filament:optimize && php artisan icons:cache'
fim() {
    php artisan make:filament-"$1"
}

alias c='composer'
alias cr='composer require -vvv'
alias cu='composer update -vvv'
alias ci='composer install -vvv'
alias cda='composer dump-autoload -o'

phpuse() {
  [ -d "$HOME/.php-shims/$1" ] || { echo "no shim for '$1' (have: $(ls "$HOME/.php-shims" 2>/dev/null))"; return 1; }
  echo "PATH_add \"\$HOME/.php-shims/$1\"" > .envrc
  direnv allow && php -v
}

alias g='git'
alias gc='git checkout'
alias gm='git merge'
alias gs='git status'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'
alias gnah='git reset --hard; git clean -df'
alias pull='git pull'
alias push='git push'
alias stash='git stash -u'
alias pop='git stash pop'
alias lg='lazygit'

alias cx='codex'
alias cc='claude'
alias gr='grok'

alias ll='ls -FGlAhp'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

alias pest='./vendor/bin/pest'
alias pestp='./vendor/bin/pest --parallel  --processes=12'
alias pestb='./vendor/bin/pest --bail --processes=12'
alias pestpb='./vendor/bin/pest --parallel --bail --processes=12'
pestg() {
    ./vendor/bin/pest --group="$1"
}

atouch() {
  mkdir -p -- "$(dirname -- "$1")" && touch -- "$1"
}

alias t='tmux'
alias ta='tmux attach -t'
alias tl='tmux ls'
alias tk='tmux kill-session -t'
tn() { tmux new -s "$1" ${2:+-n "$2"}; }

web() { serve open "$@"; }
