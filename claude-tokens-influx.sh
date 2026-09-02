#!/bin/zsh
#
# claude-tokens-influx.sh — run the claude-token-influx collector and POST its
# output to InfluxDB. Driven by a launchd agent; see claude-tokens.plist.
#
# The collector itself lives in its own public repo and writes nothing:
# https://github.com/gcrevell/claude-token-influx
# This script is the half that knows *where* the data goes, which is why it
# lives here and reads every network detail out of an untracked file.
#
# Config comes from ~/.zshrc.local, as plain zsh variables:
#
#   export CLAUDE_TOKENS_INFLUX_URL="https://influx.example"   # no trailing /
#   export CLAUDE_TOKENS_INFLUX_TOKEN="..."                    # write-only!
#   export CLAUDE_TOKENS_INFLUX_ORG="..."
#   export CLAUDE_TOKENS_INFLUX_BUCKET="..."
#   export CLAUDE_TOKENS_HOST="..."                            # stable host tag
#
# None of these have defaults on purpose. This repo is public, so a default
# would mean committing a hostname or bucket name; and a *wrong* default is
# worse than no default, since the host tag in particular silently fragments
# the series rather than failing.
#
# Why ~/.zshrc.local and not 1Password: `op` blocks on a GUI prompt when the
# vault is locked, and a background launchd job hanging forever on an invisible
# dialog is the worst available failure mode.

set -uo pipefail

LABEL="claude-tokens-influx"
LOCAL_ZSHRC="$HOME/.zshrc.local"
REPO_DIR="${CLAUDE_TOKENS_REPO_DIR:-$HOME/src/claude-token-influx}"
COLLECTOR="$REPO_DIR/claude-tokens.sh"
LOG="$HOME/Library/Logs/${LABEL}.log"
LOG_MAX_LINES=500

mkdir -p "${LOG:h}"

log() { print -r -- "$(date '+%Y-%m-%dT%H:%M:%S%z') $*" >> "$LOG"; }

# Trim our own log rather than letting launchd's StandardErrorPath grow without
# bound. The plist sends launchd's own streams to /dev/null precisely so that
# nothing else holds this file open while we rewrite it.
trim_log() {
  [[ -f "$LOG" ]] || return 0
  local lines
  lines=$(wc -l < "$LOG")
  (( lines > LOG_MAX_LINES )) || return 0
  local tmp="${LOG}.tmp"
  tail -n "$LOG_MAX_LINES" "$LOG" > "$tmp" && mv "$tmp" "$LOG"
}

die() { log "ERROR: $*"; trim_log; exit 1; }

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
[[ -r "$LOCAL_ZSHRC" ]] || die "$LOCAL_ZSHRC not readable"

# The token lives in this file, so it should not be world-readable. Warn rather
# than fail: refusing to run would turn a permissions nit into silent data loss.
#
# `stat -f '%A'` is BSD/macOS. On GNU coreutils -f is --file-system, which
# SUCCEEDS and prints a block-size report, so testing the exit status is not
# enough to tell the two apart — only accept output actually shaped like a mode.
zshrc_mode="$(stat -f '%A' "$LOCAL_ZSHRC" 2>/dev/null)"
[[ "$zshrc_mode" =~ '^[0-7]{3,4}$' ]] || zshrc_mode="$(stat -c '%a' "$LOCAL_ZSHRC" 2>/dev/null)"
if [[ "$zshrc_mode" =~ '^[0-7]{3,4}$' && "${zshrc_mode: -3}" != "600" ]]; then
  log "WARNING: $LOCAL_ZSHRC is mode $zshrc_mode, not 600, and holds an InfluxDB token"
fi

# stdout of the source is redirected into the log: a ~/.zshrc.local that echoes
# something must not end up interleaved with anything we parse. Failures here
# are not fatal on their own — the variable check below is the real gate, and
# it gives a far better message than a zsh parse error would.
source "$LOCAL_ZSHRC" >> "$LOG" 2>&1 || log "WARNING: $LOCAL_ZSHRC exited non-zero when sourced"

missing=()
for var in CLAUDE_TOKENS_INFLUX_URL CLAUDE_TOKENS_INFLUX_TOKEN \
           CLAUDE_TOKENS_INFLUX_ORG CLAUDE_TOKENS_INFLUX_BUCKET \
           CLAUDE_TOKENS_HOST; do
  [[ -n "${(P)var:-}" ]] || missing+=("$var")
done
(( ${#missing} == 0 )) || die "unset in $LOCAL_ZSHRC: ${missing[*]}"

# ---------------------------------------------------------------------------
# Collect
# ---------------------------------------------------------------------------
# Fail loudly on a missing or moved checkout. Silently emitting nothing is the
# failure mode this whole script exists to avoid.
[[ -x "$COLLECTOR" ]] || die "collector not found or not executable: $COLLECTOR (is $REPO_DIR cloned?)"

lines="$("$COLLECTOR" "$HOME/.claude/projects" "$HOME/src" "$CLAUDE_TOKENS_HOST")" \
  || die "collector exited non-zero"

# Zero lines is a legitimate result on a machine that has never run Claude Code.
# On *this* machine it means something broke — no jq, a moved projects dir, a
# jq filter that silently stopped matching — so treat it as an error and, more
# importantly, do not POST an empty body and call that a success.
[[ -n "$lines" ]] || die "collector produced no output (no jq? no ~/.claude/projects?)"

count=$(print -r -- "$lines" | wc -l | tr -d ' ')

# ---------------------------------------------------------------------------
# Ship
# ---------------------------------------------------------------------------
# --fail-with-body, not bare curl: curl EXITS 0 ON A 401. Without this a job
# whose token was revoked reports success on every single run while writing
# nothing at all, and the only symptom is a dashboard that quietly stops moving.
#
# The timeouts matter as much: off the home network the write host does not
# resolve, and an hourly job that blocks indefinitely would pile up.
if ! response="$(print -r -- "$lines" | curl -sS --fail-with-body \
      --connect-timeout 5 --max-time 120 \
      -X POST \
      -H "Authorization: Token $CLAUDE_TOKENS_INFLUX_TOKEN" \
      -H 'Content-Type: text/plain; charset=utf-8' \
      --data-binary @- \
      "${CLAUDE_TOKENS_INFLUX_URL}/api/v2/write?org=${CLAUDE_TOKENS_INFLUX_ORG}&bucket=${CLAUDE_TOKENS_INFLUX_BUCKET}&precision=ns" 2>&1)"; then
  # No retry and no backoff, deliberately. Every run re-sends the complete
  # history, so a failed run costs nothing but a gap until the next one.
  die "write failed: ${response:-no response}"
fi

log "wrote $count series to ${CLAUDE_TOKENS_INFLUX_BUCKET}"
trim_log
