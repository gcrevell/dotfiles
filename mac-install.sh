#!/usr/bin/env bash
#
# mac-install.sh — macOS-specific setup (Homebrew, casks)
# Called from install.sh on Darwin; safe to run standalone.

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

if brew list direnv &>/dev/null; then
  info "direnv already installed, skipping"
else
  info "Installing direnv..."
  brew install direnv
fi

if brew list gh &>/dev/null; then
  info "gh already installed, skipping"
else
  info "Installing gh..."
  brew install gh
fi

if brew list tea &>/dev/null; then
  info "tea already installed, skipping"
else
  info "Installing tea..."
  brew install tea
fi

# install.sh uses jq to merge Claude Code settings. macOS 15+ ships /usr/bin/jq,
# older releases don't, so install it rather than relying on the system copy.
if brew list jq &>/dev/null; then
  info "jq already installed, skipping"
else
  info "Installing jq..."
  brew install jq
fi

if [[ "$ENVIRONMENT" == "personal" || "$ENVIRONMENT" == "work" ]]; then
  if brew list 1password-cli &>/dev/null; then
    info "1password-cli already installed, skipping"
  else
    info "Installing 1password-cli..."
    brew install 1password-cli
  fi
fi

# ---------------------------------------------------------------------------
# Claude Code token usage -> InfluxDB (personal only)
#
# Two halves. The collector is a separate public repo, cloned below; it walks
# ~/.claude/projects and prints influx line protocol, and writes nothing. The
# wrapper and launchd agent in *this* repo are what run it on a schedule and
# POST the result.
#
# personal only. The headless Pi fleet ships the same measurement a different
# way (Telegraf's exec input, configured by home-ansible), and running both on
# one machine would write the same series twice.
# ---------------------------------------------------------------------------
if [[ "$ENVIRONMENT" == "personal" ]]; then
  TOKENS_REPO="https://github.com/gcrevell/claude-token-influx.git"
  TOKENS_DIR="$HOME/src/claude-token-influx"
  TOKENS_LABEL="com.skyler.claude-tokens"
  TOKENS_PLIST="$HOME/Library/LaunchAgents/$TOKENS_LABEL.plist"
  TOKENS_CONFIG_DIR="$HOME/.config/claude-tokens"
  TOKENS_CONFIG="$TOKENS_CONFIG_DIR/config.vars"

  if [[ -d "$TOKENS_DIR/.git" ]]; then
    info "Updating claude-token-influx checkout"
    # Only fast-forward. If the checkout has local work or sits on another
    # branch, say so and move on rather than throwing away someone's commits.
    git -C "$TOKENS_DIR" pull --ff-only --quiet \
      || warn "Could not fast-forward $TOKENS_DIR — leaving it as-is"
  else
    info "Cloning claude-token-influx into $TOKENS_DIR"
    mkdir -p "$(dirname "$TOKENS_DIR")"
    git clone --quiet "$TOKENS_REPO" "$TOKENS_DIR"
  fi

  info "Installing claude-tokens-influx to ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  cp "$SCRIPT_DIR/claude-tokens-influx.sh" "$HOME/.local/bin/claude-tokens-influx"
  chmod +x "$HOME/.local/bin/claude-tokens-influx"

  # The token lives in $TOKENS_CONFIG, so tighten the directory and the file
  # (if it's there yet) whether or not it's configured — better to fix the
  # mode before the secret arrives.
  mkdir -p "$TOKENS_CONFIG_DIR"
  chmod 700 "$TOKENS_CONFIG_DIR"
  [[ -e "$TOKENS_CONFIG" ]] && chmod 600 "$TOKENS_CONFIG"

  info "Installing $TOKENS_LABEL launchd agent"
  mkdir -p "$HOME/Library/LaunchAgents"
  sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/claude-tokens.plist" > "$TOKENS_PLIST"

  # bootout before bootstrap so a changed plist actually takes effect; launchd
  # keeps serving the old definition otherwise. A not-yet-loaded agent makes
  # bootout exit non-zero, which is fine and expected on a first install.
  launchctl bootout "gui/$UID/$TOKENS_LABEL" 2>/dev/null || true
  if launchctl bootstrap "gui/$UID" "$TOKENS_PLIST" 2>/dev/null; then
    info "Loaded $TOKENS_LABEL (hourly)"
  else
    warn "Could not load $TOKENS_LABEL — try: launchctl bootstrap gui/$UID $TOKENS_PLIST"
  fi

  # The agent is useless until $TOKENS_CONFIG names a destination, and
  # RunAtLoad means it has already failed once by now. Point at the log rather
  # than letting it fail invisibly every hour.
  if ! grep -q 'CLAUDE_TOKENS_INFLUX_URL' "$TOKENS_CONFIG" 2>/dev/null; then
    warn "claude-tokens is installed but not configured. Create $TOKENS_CONFIG:"
    warn "  CLAUDE_TOKENS_INFLUX_URL=... CLAUDE_TOKENS_INFLUX_TOKEN=..."
    warn "  CLAUDE_TOKENS_INFLUX_ORG=... CLAUDE_TOKENS_INFLUX_BUCKET=..."
    warn "  CLAUDE_TOKENS_HOST=..."
    warn "  CLAUDE_TOKENS_REPO_DIR=...   # optional, defaults to $TOKENS_DIR"
    warn "Then: launchctl kickstart -k gui/$UID/$TOKENS_LABEL"
    warn "Log: ~/Library/Logs/claude-tokens-influx.log"
  fi
fi

