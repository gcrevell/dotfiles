#!/usr/bin/env bash
#
# linux-install.sh — Linux-specific setup (installs zsh if missing, sets it as default shell)
# Called from install.sh on Linux; safe to run standalone.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if command -v zsh &>/dev/null; then
  info "zsh already installed, skipping"
else
  info "Installing zsh..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y zsh
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y zsh
  elif command -v pacman &>/dev/null; then
    sudo pacman -Sy --noconfirm zsh
  elif command -v zypper &>/dev/null; then
    sudo zypper install -y zsh
  elif command -v apk &>/dev/null; then
    sudo apk add zsh
  else
    echo "error: no supported package manager found (apt-get, dnf, pacman, zypper, apk)" >&2
    exit 1
  fi
fi

ZSH_PATH="$(command -v zsh)"
if [ "$SHELL" != "$ZSH_PATH" ]; then
  info "Setting zsh as default shell..."
  chsh -s "$ZSH_PATH"
else
  info "zsh already the default shell, skipping"
fi

if command -v direnv &>/dev/null; then
  info "direnv already installed, skipping"
else
  info "Installing direnv..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y direnv
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y direnv
  elif command -v pacman &>/dev/null; then
    sudo pacman -Sy --noconfirm direnv
  elif command -v zypper &>/dev/null; then
    sudo zypper install -y direnv
  elif command -v apk &>/dev/null; then
    sudo apk add direnv
  else
    echo "error: no supported package manager found (apt-get, dnf, pacman, zypper, apk)" >&2
    exit 1
  fi
fi
