set -e

if [[ ! -d /opt/homebrew/bin ]]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$(/opt/homebrew/bin/brew shellenv)"

if ! brew list --cask claude-code &>/dev/null; then
  brew install --cask claude-code
else
  brew upgrade --cask claude-code
fi
