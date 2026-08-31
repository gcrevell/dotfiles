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
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
LOCAL_CLAUDE_SETTINGS="$HOME/.claude-settings.local.json"

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
  "$SCRIPT_DIR/mac-install.sh" "$ENVIRONMENT"

  mkdir -p "$ZSHRC_CONFIG_DIR"
  info "Copying zshrc.darwin to $ZSHRC_CONFIG_DIR/darwin.zsh"
  cp "$SCRIPT_DIR/zshrc.darwin" "$ZSHRC_CONFIG_DIR/darwin.zsh"
fi

# ---------------------------------------------------------------------------
# Back up the existing ~/.zshrc to ~/.zshrc.local
# ---------------------------------------------------------------------------
# The repo's own header line identifies a ~/.zshrc as ours (any revision, not
# just the current one) -- see below.
ZSHRC_HEADER="$(head -n 1 "$SRC_ZSHRC")"

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
  elif [[ "$(head -n 1 "$DEST_ZSHRC" 2>/dev/null)" == "$ZSHRC_HEADER" ]]; then
    # An older revision of this repo's own zshrc isn't byte-identical to the
    # current one (cmp above already ruled that out) but still carries our
    # header, so it holds nothing the repo doesn't already have. Backing it up
    # as ~/.zshrc.local would let it source itself forever, since it too ends
    # with `source ~/.zshrc.local`.
    info "~/.zshrc is an older revision of this repo's own zshrc, discarding rather than backing up"
    rm -f "$DEST_ZSHRC"
  elif [[ -e "$LOCAL_ZSHRC" ]]; then
    warn "~/.zshrc.local already exists, leaving existing ~/.zshrc in place at $DEST_ZSHRC.bak"
    mv "$DEST_ZSHRC" "$DEST_ZSHRC.bak"
  elif grep -qF 'source "$HOME/.zshrc.local"' "$DEST_ZSHRC" 2>/dev/null; then
    # Belt and braces against the same self-sourcing loop by any other means:
    # never write a ~/.zshrc.local that would source itself.
    warn "~/.zshrc sources ~/.zshrc.local itself, stripping that line before backing it up to ~/.zshrc.local"
    grep -vF 'source "$HOME/.zshrc.local"' "$DEST_ZSHRC" > "$LOCAL_ZSHRC"
    rm -f "$DEST_ZSHRC"
  else
    info "Backing up current ~/.zshrc to ~/.zshrc.local"
    mv "$DEST_ZSHRC" "$LOCAL_ZSHRC"
  fi
fi

# On a first install, ~/.zshrc.local won't exist yet unless something genuinely
# foreign was just backed up into it above. Create it empty so it's still a
# clean, obvious place for machine-specific overrides.
if [[ ! -e "$LOCAL_ZSHRC" ]]; then
  info "Creating empty ~/.zshrc.local"
  touch "$LOCAL_ZSHRC"
fi

# ---------------------------------------------------------------------------
# Install this repo's zshrc
# ---------------------------------------------------------------------------
info "Copying $SRC_ZSHRC to $DEST_ZSHRC"
cp "$SRC_ZSHRC" "$DEST_ZSHRC"

# ---------------------------------------------------------------------------
# Git & SSH setup
# ---------------------------------------------------------------------------
info "Setting up git aliases"
git config set --global alias.co checkout
git config set --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --"

info "Setting up git pull behaviour"
git config set --global pull.rebase true

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
SSH_CONFIG="$HOME/.ssh/config"

if [[ "$ENVIRONMENT" == "work" ]]; then
  info "Setting up work git & SSH config"
  git config --global user.name "Gabriel Revells"

  if git config --global user.email &>/dev/null; then
    info "git user.email already set, leaving it alone"
  else
    read -r -p "Enter work git email: " WORK_EMAIL
    git config --global user.email "$WORK_EMAIL"
  fi

  if git config --global work.org &>/dev/null; then
    WORK_ORG="$(git config --global work.org)"
    info "Work GitHub org already set ($WORK_ORG), skipping prompt"
  else
    read -r -p "Enter work GitHub org name: " WORK_ORG
    if [[ -n "$WORK_ORG" ]]; then
      git config --global work.org "$WORK_ORG"
    fi
  fi

  if git config --global user.signingkey &>/dev/null; then
    info "git user.signingkey already set, skipping prompt"
  else
    WORK_SIGNING_KEY=""
    if command -v op &>/dev/null; then
      WORK_SIGNING_KEY="$(op read "op://qm6ecq2p5hdhwjkz2xuggh5o3m/public key" 2>/dev/null || true)"
    fi
    if [[ -z "$WORK_SIGNING_KEY" ]]; then
      read -r -p "Enter work SSH signing public key: " WORK_SIGNING_KEY
    fi
    if [[ -n "$WORK_SIGNING_KEY" ]]; then
      git config --global user.signingkey "$WORK_SIGNING_KEY"
    fi
  fi

  git config --global commit.gpgsign true
  git config --global gpg.format ssh
  if [[ "$(uname -s)" == "Darwin" && -e "/Applications/1Password.app/Contents/MacOS/op-ssh-sign" ]]; then
    git config --global gpg.ssh.program "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
  fi
  git config --global push.autoSetupRemote true

  # If work org is configured, rewrite URLs so git operations to work org use github.com-work
  WORK_ORG="$(git config --global work.org 2>/dev/null || true)"
  if [[ -n "$WORK_ORG" ]]; then
    git config --global --unset-all "url.git@github.com-work:${WORK_ORG}/.insteadOf" 2>/dev/null || true
    git config --global --add "url.git@github.com-work:${WORK_ORG}/.insteadOf" "git@github.com:${WORK_ORG}/"
    git config --global --add "url.git@github.com-work:${WORK_ORG}/.insteadOf" "https://github.com/${WORK_ORG}/"
  fi

  # Ensure public key pointer files exist for OpenSSH / 1Password agent routing
  # (Note: These contain only public key strings so OpenSSH knows which key to request from 1Password agent)
  if [[ ! -f "$HOME/.ssh/id_work_github.pub" ]]; then
    WORK_PUB=""
    if command -v op &>/dev/null; then
      WORK_PUB="$(op read "op://ggnj4rjhpvkiy6lkhorfwcc5ey/public key" 2>/dev/null || true)"
    fi
    if [[ -z "$WORK_PUB" ]]; then
      WORK_PUB="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBnC+aW2PQg35NieKr5SvpI6SNAQxIBZl5nGvoSmP6Ry"
    fi
    printf '%s\n' "$WORK_PUB" > "$HOME/.ssh/id_work_github.pub"
    chmod 644 "$HOME/.ssh/id_work_github.pub"
  fi

  if [[ ! -f "$HOME/.ssh/id_personal_github.pub" ]]; then
    PERSONAL_PUB=""
    if command -v op &>/dev/null; then
      PERSONAL_PUB="$(op read "op://hwvx6rmbmencyidm6vedtm4pyu/public key" 2>/dev/null || true)"
    fi
    if [[ -z "$PERSONAL_PUB" ]]; then
      PERSONAL_PUB="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDsW6uJm8VbdaJFgycP6Gft1YTGLgDge5iwSIJ0Hj6qK"
    fi
    printf '%s\n' "$PERSONAL_PUB" > "$HOME/.ssh/id_personal_github.pub"
    chmod 644 "$HOME/.ssh/id_personal_github.pub"
  fi

  # Work SSH config: route work repos to work key, personal repos to personal key via 1Password desktop agent
  AGENT_SOCK="~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  TMP_SSH="$(mktemp)"
  cat << EOF > "$TMP_SSH"
Host github.com-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_work_github.pub
    IdentitiesOnly yes
    IdentityAgent "$AGENT_SOCK"

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_personal_github.pub
    IdentitiesOnly yes
    IdentityAgent "$AGENT_SOCK"

Host git-server
    HostName git-server
    User git
    IdentityAgent "$AGENT_SOCK"

Host *
    IdentityAgent "$AGENT_SOCK"
EOF
  mv "$TMP_SSH" "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"

elif [[ "$ENVIRONMENT" == "personal" ]]; then
  info "Setting up personal git & LLM commit signing config"
  git config --global user.name "Skyler Revells"
  git config --global user.email "wowza7125@icloud.com"

  # Install sync-llm-keys script
  mkdir -p "$HOME/.local/bin"
  cp "$SCRIPT_DIR/sync-llm-keys.sh" "$HOME/.local/bin/sync-llm-keys"
  chmod +x "$HOME/.local/bin/sync-llm-keys"

  # Sync the keys out of 1Password. `op` reads through the desktop app, so this
  # step needs 1Password unlocked *now* — the whole point of putting the keys on
  # disk is that everything afterwards works while it is locked.
  if command -v op &>/dev/null; then
    "$HOME/.local/bin/sync-llm-keys" \
      || warn "Key sync failed — run 'sync-llm-keys' once 1Password is unlocked"
  else
    warn "1password-cli (op) not found; skipping key sync"
  fi

  # Headless Git commit signing with ssh-keygen
  git config --global commit.gpgsign true
  git config --global gpg.format ssh
  git config --global gpg.ssh.program "ssh-keygen"
  git config --global user.signingkey "$HOME/.ssh/llm_keys/id_signing"
  git config --global push.autoSetupRemote true

  # Personal SSH config: non-interactive keys, written as a managed block at the
  # TOP of ~/.ssh/config. ssh takes the first value it obtains for any given
  # option, so this has to sit above the 1Password-agent entries to win.
  #
  # "First value wins" only helps for options this block actually sets, so every
  # entry below pins IdentityAgent none. Without it a `Host *` stanza further
  # down supplies the 1Password socket, and IdentitiesOnly does NOT save you:
  # it restricts *which* identities may be offered, not whether ssh hands the
  # signature to an agent holding the same key. When it does, a locked
  # 1Password fails the connection outright --
  #
  #   sign_and_send_pubkey: signing failed for ED25519 ".../id_personal_github"
  #     from agent: communication with agent failed
  #   git@github.com: Permission denied (publickey).
  #
  # -- which is the exact failure these on-disk keys exist to prevent. Only
  # GitHub hit it, and only because that key is also in the vault; the Gitea
  # one escaped by being a different key from the vault's. That is luck, not
  # design, so both are pinned.
  SSH_BLOCK_START="# >>> dotfiles personal keys (managed by install.sh) >>>"
  SSH_BLOCK_END="# <<< dotfiles personal keys (managed by install.sh) <<<"

  TMP_SSH="$(mktemp)"
  cat << EOF > "$TMP_SSH"
$SSH_BLOCK_START
# Gitea runs its own sshd in a container published on host port 2222, which is a
# different service from the Pi's own sshd on 22. Matching on the \`git\` login
# user keeps plain \`ssh git-server\` (User skyler) pointed at the Pi.
Match host git-server,git-server.lan,192.168.86.25 user git
    Port 2222
    IdentityFile ~/.ssh/llm_keys/id_personal_gitea
    IdentitiesOnly yes
    IdentityAgent none

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/llm_keys/id_personal_github
    IdentitiesOnly yes
    IdentityAgent none
$SSH_BLOCK_END

EOF

  if [[ -f "$SSH_CONFIG" ]]; then
    cp "$SSH_CONFIG" "$SSH_CONFIG.bak"
    # Strip a previously-installed block so re-runs replace it rather than
    # stacking duplicate entries on top of each other.
    awk -v s="$SSH_BLOCK_START" -v e="$SSH_BLOCK_END" '
      $0 == s { skip = 1; next }
      $0 == e { skip = 0; next }
      !skip
    ' "$SSH_CONFIG" >> "$TMP_SSH"
  fi

  mv "$TMP_SSH" "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"

elif [[ "$ENVIRONMENT" == "personal-headless" ]]; then
  info "Setting up personal-headless git config (minimal, no 1Password)"
  git config --global user.name "Skyler Revells"
  git config --global user.email "wowza7125@icloud.com"
fi

# ---------------------------------------------------------------------------
# Claude Code settings
#
# Claude Code has no settings.local.json at user scope (only project scope), so
# the layering is done here instead. Three layers, each overwriting the one
# before it:
#
#   1. whatever is already in ~/.claude/settings.json -- unmanaged, machine-local
#      keys (model, statusLine, enabledPlugins) survive untouched
#   2. this repo's claude-settings.json -- shared defaults, re-applied on every
#      run, so changing a default here actually reaches machines already set up
#   3. ~/.claude-settings.local.json -- deliberate per-machine overrides, always
#      wins. Same rule as ~/.zshrc: don't hand-edit the generated file, put
#      anything you want to keep in the .local one.
# ---------------------------------------------------------------------------
if command -v jq &>/dev/null; then
  info "Merging Claude Code settings into $CLAUDE_SETTINGS"
  mkdir -p "$(dirname "$CLAUDE_SETTINGS")"

  LAYERS=("$SCRIPT_DIR/claude-settings.json")
  if [[ -f "$CLAUDE_SETTINGS" ]]; then
    LAYERS=("$CLAUDE_SETTINGS" "${LAYERS[@]}")
  fi
  if [[ -f "$LOCAL_CLAUDE_SETTINGS" ]]; then
    LAYERS+=("$LOCAL_CLAUDE_SETTINGS")
  fi

  # jq's `*` merges objects recursively with the right-hand side winning; arrays
  # and scalars are replaced wholesale. Merging into a variable first means a
  # parse error in any layer aborts (set -e) before the real settings file is
  # ever truncated.
  MERGED_SETTINGS="$(jq -s 'reduce .[] as $layer ({}; . * $layer)' "${LAYERS[@]}")"
  printf '%s\n' "$MERGED_SETTINGS" > "$CLAUDE_SETTINGS"
else
  warn "jq not found, skipping Claude Code settings merge"
fi

info "Done. Restart your shell or run: source ~/.zshrc"
