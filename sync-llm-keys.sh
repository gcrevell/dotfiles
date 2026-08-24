#!/usr/bin/env bash
#
# sync-llm-keys.sh — Export SSH signing and push keys from 1Password Service Account
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib.sh" ]]; then
  source "$SCRIPT_DIR/lib.sh"
else
  info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
  warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }
fi

KEYS_DIR="${HOME}/.ssh/llm_keys"
VAULT="${OP_VAULT_NAME:-LLM-Automation}"

# 1Password Item IDs (defaults from 1P vault, configurable via environment)
SIGNING_KEY_ITEM="${OP_SIGNING_KEY_ID:-qm6ecq2p5hdhwjkz2xuggh5o3m}"
GITHUB_KEY_ITEM="${OP_GITHUB_KEY_ID:-hwvx6rmbmencyidm6vedtm4pyu}"
GITEA_KEY_ITEM="${OP_GITEA_KEY_ID:-6jsiy65kopwquyoi2nlhghqese}"

if ! command -v op &>/dev/null; then
  echo "error: 1password-cli (op) not found on PATH" >&2
  exit 1
fi

if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
  echo "error: OP_SERVICE_ACCOUNT_TOKEN environment variable is not set" >&2
  exit 1
fi

mkdir -p "$KEYS_DIR"
chmod 700 "$KEYS_DIR"

info "Syncing keys from 1Password vault '$VAULT' to $KEYS_DIR..."

fetch_key() {
  local item_id="$1"
  local fallback_title="$2"
  local dest_base="$3"

  # 1. Fetch private key
  local priv_content=""
  if priv_content="$(op read "op://${VAULT}/${item_id}/private key" 2>/dev/null)"; then
    :
  elif priv_content="$(op read "op://${VAULT}/${fallback_title}/private key" 2>/dev/null)"; then
    :
  elif priv_content="$(op read "op://${item_id}/private key" 2>/dev/null)"; then
    :
  else
    warn "Failed to fetch private key for item '${item_id}' (${fallback_title})"
    return 1
  fi

  printf '%s\n' "$priv_content" > "${dest_base}"
  chmod 600 "${dest_base}"

  # 2. Fetch public key (or derive via ssh-keygen)
  local pub_content=""
  if pub_content="$(op read "op://${VAULT}/${item_id}/public key" 2>/dev/null)"; then
    printf '%s\n' "$pub_content" > "${dest_base}.pub"
  elif pub_content="$(op read "op://${VAULT}/${fallback_title}/public key" 2>/dev/null)"; then
    printf '%s\n' "$pub_content" > "${dest_base}.pub"
  elif pub_content="$(op read "op://${item_id}/public key" 2>/dev/null)"; then
    printf '%s\n' "$pub_content" > "${dest_base}.pub"
  else
    # Derive directly from the private key
    ssh-keygen -y -f "${dest_base}" > "${dest_base}.pub" 2>/dev/null || true
  fi

  if [[ -f "${dest_base}.pub" ]]; then
    chmod 644 "${dest_base}.pub"
  fi
}

# 1. Git Signing Key
fetch_key "$SIGNING_KEY_ITEM" "Git Signing Key" "${KEYS_DIR}/id_signing"

# 2. Personal Push Key (GitHub)
fetch_key "$GITHUB_KEY_ITEM" "Personal GitHub Push Key" "${KEYS_DIR}/id_personal_github"

# 3. Personal Push Key (Gitea / git-server)
fetch_key "$GITEA_KEY_ITEM" "Personal Gitea Push Key" "${KEYS_DIR}/id_personal_gitea"

info "Successfully synced keys to $KEYS_DIR"


