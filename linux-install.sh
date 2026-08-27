#!/usr/bin/env bash
#
# linux-install.sh — Linux-specific setup (installs zsh if missing, sets it as default shell)
# Called from install.sh on Linux; safe to run standalone.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

ENVIRONMENT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENVIRONMENT="${2:-}"
      shift 2
      ;;
    work|personal|personal-headless)
      ENVIRONMENT="$1"
      shift
      ;;
    *) shift ;;
  esac
done

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

# install.sh uses jq to merge Claude Code settings. Packaged as "jq" everywhere,
# so no special-casing like gh needs below.
if command -v jq &>/dev/null; then
  info "jq already installed, skipping"
else
  info "Installing jq..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update && sudo apt-get install -y jq
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y jq
  elif command -v pacman &>/dev/null; then
    sudo pacman -Sy --noconfirm jq
  elif command -v zypper &>/dev/null; then
    sudo zypper install -y jq
  elif command -v apk &>/dev/null; then
    sudo apk add jq
  else
    echo "error: no supported package manager found (apt-get, dnf, pacman, zypper, apk)" >&2
    exit 1
  fi
fi

if [[ "$ENVIRONMENT" == "personal-headless" ]]; then
  info "personal-headless environment, skipping gh (nothing on these hosts uses it)"
elif command -v gh &>/dev/null; then
  info "gh already installed, skipping"
else
  info "Installing gh..."
  if command -v apt-get &>/dev/null; then
    # Ubuntu/Debian only ship gh in newer releases, so use GitHub's own apt repo.
    # It publishes amd64/arm64/armhf, which covers 64- and 32-bit Raspberry Pi OS.
    if ! command -v curl &>/dev/null; then
      sudo apt-get update && sudo apt-get install -y curl
    fi
    keyring="$(mktemp)"
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "$keyring"
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo install -m 0644 "$keyring" /etc/apt/keyrings/githubcli-archive-keyring.gpg
    rm -f "$keyring"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update && sudo apt-get install -y gh
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y gh
  elif command -v pacman &>/dev/null; then
    sudo pacman -Sy --noconfirm github-cli
  elif command -v zypper &>/dev/null; then
    sudo zypper install -y gh
  elif command -v apk &>/dev/null; then
    sudo apk add github-cli
  else
    echo "error: no supported package manager found (apt-get, dnf, pacman, zypper, apk)" >&2
    exit 1
  fi
fi
