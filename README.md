# dotfiles

Personal dotfiles for setting up a zsh environment on macOS and Linux.

## Install

```bash
git clone <this-repo> ~/src/dotfiles
cd ~/src/dotfiles
./install.sh --env personal            # personal git config + LLM headless signing & key sync from 1P
./install.sh --env personal-headless   # minimal personal git config (no 1Password / no prompts)
./install.sh --env work                # work git & SSH config (interactive 1P desktop signing & URL routing)
```

Restart your shell (or run `source ~/.zshrc`) afterwards.

Re-running `install.sh` is safe — it skips anything already installed and won't overwrite `~/.zshrc.local`.

## What it sets up

- **zsh** as the shell, installed via the system package manager on Linux (apt/dnf/pacman/zypper/apk) and set as the default shell (macOS ships with zsh already).
- **oh-my-zsh**, installed unattended, with the `pure` theme and these plugins: `git`, `gh`, `z`, `colored-man-pages`, `command-not-found`, `zsh-autosuggestions`, `zsh-syntax-highlighting`.
- **On macOS**: Homebrew (if missing), `1password-cli` (`personal`/`work`), the `claude-code` cask, and `git-recent`.
- **direnv**, installed via Homebrew on macOS or the system package manager on Linux, and hooked into `~/.zshrc`.
- **gh** (GitHub CLI), installed via Homebrew on macOS or the system package manager on Linux, except under `personal-headless` where it's skipped. On apt systems it adds GitHub's own apt repo first, since Ubuntu/Debian only ship `gh` in newer releases — that repo covers `arm64`/`armhf`, so Raspberry Pi works.
- **jq**, installed via Homebrew on macOS or the system package manager on Linux. Used to merge the Claude Code settings below.
- **`~/.zshrc`**: history settings, `EDITOR`/`VISUAL`/`LANG`, `PATH` additions (`~/.bin`, `~/.local/bin`), aliases (`ll`, `la`, `..`, `...`, `grep`, `gs`, `gd`, `gco`, `gc`), and the `direnv` shell hook.
- **OS-specific zsh config** under `~/.zshrc-config/`, sourced automatically from `~/.zshrc` (e.g. `zshrc.darwin` becomes `~/.zshrc-config/darwin.zsh`, adding Homebrew's shellenv and Mac-only aliases like `flushdns`, `showfiles`, `hidefiles`, `vsc`).
- **Git aliases**: `co` (checkout), `lg` (pretty log graph).
- **Git & SSH identity**: `--env` is required and must be `work`, `personal`, or `personal-headless`:
  - `work`: sets `user.name` to "Gabriel Revells", prompts for work email, work org, and signing key (if not already set), sets up interactive 1Password commit signing (`op-ssh-sign`) and URL rewriting for the work org.
  - `personal`: sets `user.name` to "Skyler Revells" / iCloud email, installs `sync-llm-keys` and runs it to copy the signing and push keys out of the `Global Dev` 1Password vault into `~/.ssh/llm_keys/` (`0600`), then configures non-interactive `ssh-keygen` signing plus push keys `id_personal_github` and `id_personal_gitea` (for `git-server`). Keys live on disk on purpose, so local tooling can commit and push while the 1Password app is locked; syncing them needs 1Password unlocked, but nothing afterwards does. Both SSH entries pin `IdentityAgent none`, which is what makes that true: `IdentitiesOnly` alone still lets ssh hand the signature to an agent holding the same key, so a `Host *` 1Password stanza further down the file would break pushes whenever the app is locked. Re-run `sync-llm-keys` whenever a key is rotated.
  - `personal-headless`: sets minimal personal identity with no 1Password dependencies or prompts.
- **Claude Code settings**: `~/.claude/settings.json` is rebuilt from the tracked `claude-settings.json` (shared defaults, re-applied every run) layered over whatever is already in the file, with `~/.claude-settings.local.json` applied last so per-machine overrides always win.
- **Claude Code token usage → InfluxDB** (macOS + `personal` only): clones [`claude-token-influx`](https://github.com/gcrevell/claude-token-influx) to `~/src/claude-token-influx`, installs `claude-tokens-influx` to `~/.local/bin`, and loads an hourly launchd agent. See below — it needs config before it does anything.

Your existing `~/.zshrc` (if different from this repo's) is backed up to `~/.zshrc.local`, which is sourced at the end of the installed `~/.zshrc` for untracked, machine-specific overrides.

Because the tracked defaults are re-applied on every run, don't hand-edit `~/.claude/settings.json` for anything you want to keep — put it in `~/.claude-settings.local.json` instead. Same rule as `~/.zshrc` vs `~/.zshrc.local`.

## Claude Code token usage

On macOS under `--env personal`, an hourly launchd agent ships per-project,
per-model, per-day Claude Code token counts to InfluxDB.

The work is split across two repos on purpose:

- **[`claude-token-influx`](https://github.com/gcrevell/claude-token-influx)** (public) — walks `~/.claude/projects` and prints influx line protocol. It writes nothing and knows no hostnames, which is what makes it safe to publish.
- **this repo** — `claude-tokens-influx.sh` (the wrapper that runs it and POSTs the result) and `claude-tokens.plist` (the launchd agent).

`install.sh` handles the clone, the wrapper, and loading the agent. What it
cannot do is supply the destination, which is untracked. Create
`~/.config/claude-tokens/config.vars`:

```zsh
CLAUDE_TOKENS_INFLUX_URL="https://influx.example"   # no trailing slash
CLAUDE_TOKENS_INFLUX_TOKEN="..."                    # write-only, single bucket
CLAUDE_TOKENS_INFLUX_ORG="..."
CLAUDE_TOKENS_INFLUX_BUCKET="..."
CLAUDE_TOKENS_HOST="..."                            # stable host tag
CLAUDE_TOKENS_REPO_DIR="..."                        # optional, defaults to ~/src/claude-token-influx
```

Then `launchctl kickstart -k gui/$UID/com.skyler.claude-tokens`.

Only `CLAUDE_TOKENS_REPO_DIR` has a default. This repo is public, so a default
for any of the rest would mean committing a hostname or a bucket name; and for
`CLAUDE_TOKENS_HOST` a wrong default is worse than none, because a drifting
host tag fragments the series silently instead of failing. `install.sh` chmods
the `~/.config/claude-tokens` directory to `700` and the file to `600`, since
it's a dedicated file that holds nothing but this config — not
`~/.zshrc.local`, which is free to carry arbitrary shell logic that has no
business running inside a launchd job.

**The token is deliberately not read from 1Password at run time.** `op` blocks
on a GUI prompt when the vault is locked, and a background launchd job hanging
forever on an invisible dialog is the worst available failure mode.

### Operating it

```bash
tail -f ~/Library/Logs/claude-tokens-influx.log        # one line per run
launchctl kickstart -k gui/$UID/com.skyler.claude-tokens   # run it now
launchctl print gui/$UID/com.skyler.claude-tokens      # is it loaded?
launchctl bootout gui/$UID/com.skyler.claude-tokens    # stop it
```

The wrapper keeps that log trimmed to the last 500 lines itself, which is why
the plist sends launchd's own streams to `/dev/null`.

Some behaviour worth knowing before debugging it:

- **No state, no cursor, no retry.** Every run re-sends the complete history, so a machine that was offline for a week is not "behind" and there is no catch-up path to get wrong. A failed run costs nothing but a gap until the next one. This does require the target bucket to have **infinite retention** — InfluxDB drops points older than retention *at write time*, so a finite one would silently discard most of every run.
- **`StartInterval`, not `StartCalendarInterval`.** An interval job whose window elapsed during sleep fires on wake; cron would just miss it. Hourly rather than every 15 minutes because each run re-reads the whole transcript corpus.
- **Failures are loud, in the log.** Anything other than a successful write exits non-zero: unreachable host, missing checkout, unset variables, and — specifically — a non-2xx response. `curl` exits 0 on a 401, so the wrapper passes `--fail-with-body`; without it a revoked token would report success on every run while writing nothing.
- **Empty output is treated as an error here.** Zero lines is legitimate on a machine that has never run Claude Code, but on this laptop it means something broke, so the wrapper refuses to POST an empty body and call it a success.
- **Counts only.** Seven integers and three tags (`host`, `project`, `model`). No prompt text, paths, or tool output ever leaves the machine.
- **Run it at least monthly.** Claude Code deletes transcripts older than `cleanupPeriodDays` (default 30). Hourly covers this many times over; it only bites a machine left off for over a month.
- **Token rotation:** the value in `~/.config/claude-tokens/config.vars` is the only copy. Losing it means minting a new write-only, single-bucket token, not restoring one.
