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

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

WORK_MODE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --work) WORK_MODE=true; shift ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -f "$SRC_ZSHRC" ]]; then
  echo "error: $SRC_ZSHRC not found" >&2
  exit 1
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
info "Setting up 'git co' as an alias for 'git checkout'"
git config --global alias.co checkout

if $WORK_MODE; then
  info "Setting up work git config"
  git config --global user.name "Gabe Revells"

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
