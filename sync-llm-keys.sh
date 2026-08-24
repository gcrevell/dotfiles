#!/usr/bin/env bash
#
# sync-llm-keys.sh — Export SSH signing and push keys from 1Password to disk.
#
# The keys deliberately land on disk (0600) so non-interactive tooling can sign
# and push while the 1Password desktop app is LOCKED. Run this once while
# 1Password is unlocked; `op` reads through the desktop app integration, so no
# service-account token is created, prompted for, or stored anywhere.
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
VAULT="${OP_VAULT_NAME:-Global Dev}"

# 1Password item IDs, overridable via environment.
SIGNING_KEY_ITEM="${OP_SIGNING_KEY_ID:-qm6ecq2p5hdhwjkz2xuggh5o3m}"
GITHUB_KEY_ITEM="${OP_GITHUB_KEY_ID:-hwvx6rmbmencyidm6vedtm4pyu}"
GITEA_KEY_ITEM="${OP_GITEA_KEY_ID:-6jsiy65kopwquyoi2nlhghqese}"

if ! command -v op &>/dev/null; then
  echo "error: 1password-cli (op) not found on PATH" >&2
  exit 1
fi

# Fail once, with a useful message, rather than three identical per-key errors.
if ! op vault list &>/dev/null; then
  echo "error: 1Password is locked, or 'op' is not signed in." >&2
  echo "       Unlock the 1Password app (Settings > Developer > 'Integrate with" >&2
  echo "       1Password CLI'), then re-run: sync-llm-keys" >&2
  exit 1
fi

mkdir -p "$KEYS_DIR"
chmod 700 "$KEYS_DIR"

info "Syncing keys from 1Password vault '$VAULT' to $KEYS_DIR..."

fetch_key() {
  local item="$1" title="$2" dest="$3"
  local priv

  # Secret references are op://<vault>/<item>/<field> — all three parts are
  # required. The ?ssh-format=openssh modifier matters: without it `op read`
  # hands back a PKCS#8 "BEGIN PRIVATE KEY" blob, which OpenSSH cannot use for
  # ed25519 keys. Try the stable item ID first, then fall back to the title.
  if ! priv="$(op read "op://${VAULT}/${item}/private key?ssh-format=openssh" 2>/dev/null)" \
     && ! priv="$(op read "op://${VAULT}/${title}/private key?ssh-format=openssh" 2>/dev/null)"; then
    warn "Could not read private key for '${title}' (${item}) from vault '${VAULT}'"
    return 1
  fi

  # Subshell umask so the private key is never briefly group/world readable.
  ( umask 077; printf '%s\n' "$priv" > "$dest" )

  # Derive the public key from what we just wrote rather than fetching it
  # separately: it doubles as proof that OpenSSH can actually load the private
  # key, which a stored-public-key copy would happily hide.
  if ! ssh-keygen -y -f "$dest" > "${dest}.pub" 2>/dev/null; then
    warn "Key written for '${title}' is not loadable by OpenSSH — discarding"
    rm -f "$dest" "${dest}.pub"
    return 1
  fi

  chmod 600 "$dest"
  chmod 644 "${dest}.pub"
  info "  synced ${dest##*/}"
  return 0
}

# Collect failures rather than letting `set -e` abort on the first one, so one
# missing item doesn't silently skip the remaining keys. Plain string rather
# than an array: `${#arr[@]}` on an empty array trips `set -u` on bash 3.2,
# which is what macOS still ships as /bin/bash.
failed=""
fetch_key "$SIGNING_KEY_ITEM" "Global Commit signing key" "${KEYS_DIR}/id_signing" \
  || failed="$failed signing"
fetch_key "$GITHUB_KEY_ITEM" "Private GitHub Access Key" "${KEYS_DIR}/id_personal_github" \
  || failed="$failed github"
fetch_key "$GITEA_KEY_ITEM" "Private Gitea Access Token" "${KEYS_DIR}/id_personal_gitea" \
  || failed="$failed gitea"

if [[ -n "${failed// /}" ]]; then
  warn "Failed to sync:${failed}"
  exit 1
fi

info "Synced 3 keys to $KEYS_DIR"
