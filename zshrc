# ~/.zshrc — managed by dotfiles repo
# Local machine-specific overrides live in ~/.zshrc.local (sourced at the end)

# ---------------------------------------------------------------------------
# oh-my-zsh
# ---------------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"

# Theme: https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="pure"

# Plugins: https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins
plugins=(
  git
  gh
  z
  colored-man-pages
  command-not-found
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
HISTSIZE=50000
SAVEHIST=50000
HISTFILE="$HOME/.zsh_history"
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
export EDITOR="vim"
export VISUAL="$EDITOR"
export LANG="en_US.UTF-8"

export PATH="$HOME/.bin:$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias ll="ls -lahG"
alias la="ls -laG"
alias ..="cd .."
alias ...="cd ../.."
alias grep="grep --color=auto"
alias gs="git status"
alias gd="git diff"
alias gco="git checkout"
alias gc="git commit"

# ---------------------------------------------------------------------------
# Extra config (e.g. OS-specific files installed by install.sh)
# ---------------------------------------------------------------------------
if [[ -d "$HOME/.zshrc-config" ]]; then
  for f in "$HOME/.zshrc-config"/*.zsh(N); do
    source "$f"
  done
fi

# ---------------------------------------------------------------------------
# Local overrides (not tracked in dotfiles repo)
# ---------------------------------------------------------------------------
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
