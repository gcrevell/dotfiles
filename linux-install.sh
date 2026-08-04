#!/usr/bin/env bash
#
# linux-install.sh — Linux-specific setup (installs zsh if missing)
# Called from install.sh on Linux; safe to run standalone.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if command -v zsh &>/dev/null; then
  info "zsh already installed, skipping"
  exit 0
fi

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
