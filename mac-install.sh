#!/usr/bin/env bash
#
# mac-install.sh — macOS-specific setup (Homebrew, casks)
# Called from install.sh on Darwin; safe to run standalone.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if [[ ! -d /opt/homebrew/bin ]]; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$(/opt/homebrew/bin/brew shellenv)"

if ! brew list --cask claude-code &>/dev/null; then
  info "Installing claude-code..."
  brew install --cask claude-code
else
  info "Upgrading claude-code..."
  brew upgrade --cask claude-code
fi

if ! brew list git-recent &>/dev/null; then
  info "Installing git-recent..."
  brew install git-recent
else
  info "Upgrading git-recent..."
  brew upgrade git-recent
fi
