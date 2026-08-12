#!/usr/bin/env bash
#
# install.sh — setup the local environment
#
# * oh-my-zsh
# * mac-specific installs
#
# After installing dependencies, this
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ZSHRC="$SCRIPT_DIR/zshrc"
DEST_ZSHRC="$HOME/.zshrc"
LOCAL_ZSHRC="$HOME/.zshrc.local"
ZSHRC_CONFIG_DIR="$HOME/.zshrc-config"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
OMZ_TEMPLATE="${ZSH:-$HOME/.oh-my-zsh}/templates/zshrc.zsh-template"

source "$SCRIPT_DIR/lib.sh"

usage() {
  echo "usage: $0 --env <work|personal|personal-headless>" >&2
  exit 1
}

ENVIRONMENT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENVIRONMENT="${2:-}"
      shift 2
      ;;
    *) echo "unknown flag: $1" >&2; usage ;;
  esac
done

case "$ENVIRONMENT" in
  work|personal|personal-headless) ;;
  "") echo "error: --env is required" >&2; usage ;;
  *) echo "error: invalid --env value: $ENVIRONMENT" >&2; usage ;;
esac

if [[ ! -f "$SRC_ZSHRC" ]]; then
  echo "error: $SRC_ZSHRC not found" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Linux specific install (must run before oh-my-zsh, which requires zsh)
# ---------------------------------------------------------------------------
if [[ "$(uname -s)" == "Linux" ]]; then
  info "Running linux-install.sh"
  "$SCRIPT_DIR/linux-install.sh"
fi

# ---------------------------------------------------------------------------
# Install oh-my-zsh if missing
# ---------------------------------------------------------------------------
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  info "oh-my-zsh already installed, skipping"
else
  info "Installing oh-my-zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

if [[ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]]; then
  info "zsh-autosuggestions already installed, skipping"
else
  info "Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
fi

if [[ -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]]; then
  info "zsh-syntax-highlighting already installed, skipping"
else
  info "Installing zsh-syntax-highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
fi

cp "$SCRIPT_DIR/pure.zsh-theme" "$ZSH_CUSTOM/themes/pure.zsh-theme"

# ---------------------------------------------------------------------------
# Mac specific install
# ---------------------------------------------------------------------------
if [[ "$(uname -s)" == "Darwin" ]]; then
  info "Running mac-install.sh"
  "$SCRIPT_DIR/mac-install.sh"

  mkdir -p "$ZSHRC_CONFIG_DIR"
  info "Copying zshrc.darwin to $ZSHRC_CONFIG_DIR/darwin.zsh"
  cp "$SCRIPT_DIR/zshrc.darwin" "$ZSHRC_CONFIG_DIR/darwin.zsh"
fi

# ---------------------------------------------------------------------------
# Back up the existing ~/.zshrc to ~/.zshrc.local
# ---------------------------------------------------------------------------
if [[ -f "$DEST_ZSHRC" || -L "$DEST_ZSHRC" ]]; then
  if cmp -s "$DEST_ZSHRC" "$SRC_ZSHRC" 2>/dev/null; then
    info "~/.zshrc already matches this repo's zshrc, nothing to back up"
  elif cmp -s "$DEST_ZSHRC" "$OMZ_TEMPLATE" 2>/dev/null; then
    # oh-my-zsh's installer writes its stock template whenever no ~/.zshrc exists
    # -- KEEP_ZSHRC=yes only protects a file that is already there. Preserving
    # that template as ~/.zshrc.local is actively harmful: this repo's zshrc
    # sources ~/.zshrc.local last, and the template resets ZSH_THEME to
    # robbyrussell and re-sources oh-my-zsh.sh, silently clobbering the theme.
    # It is byte-identical to the stock template, so it holds nothing of ours.
    info "~/.zshrc is oh-my-zsh's stock template, discarding rather than backing up"
    rm -f "$DEST_ZSHRC"
  elif [[ -e "$LOCAL_ZSHRC" ]]; then
    warn "~/.zshrc.local already exists, leaving existing ~/.zshrc in place at $DEST_ZSHRC.bak"
    mv "$DEST_ZSHRC" "$DEST_ZSHRC.bak"
  else
    info "Backing up current ~/.zshrc to ~/.zshrc.local"
    mv "$DEST_ZSHRC" "$LOCAL_ZSHRC"
  fi
fi

# ---------------------------------------------------------------------------
# Install this repo's zshrc
# ---------------------------------------------------------------------------
info "Copying $SRC_ZSHRC to $DEST_ZSHRC"
cp "$SRC_ZSHRC" "$DEST_ZSHRC"

# ---------------------------------------------------------------------------
# Git setup
# ---------------------------------------------------------------------------
info "Setting up git aliases"
git config set --global alias.co checkout
git config set --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --"

info "Setting up git pull behaviour"
git config set --global pull.rebase true

if [[ "$ENVIRONMENT" == "work" ]]; then
  info "Setting up work git config"
  git config --global user.name "Gabriel Revells"

  if git config --global user.email &>/dev/null; then
    info "git user.email already set, leaving it alone"
  else
    read -r -p "Enter work git email: " WORK_EMAIL
    git config --global user.email "$WORK_EMAIL"
  fi
else
  info "Setting up personal git config"
  git config --global user.name "Skyler Revells"
  git config --global user.email "wowza7125@icloud.com"
fi

info "Done. Restart your shell or run: source ~/.zshrc"
