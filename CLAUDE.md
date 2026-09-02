# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repo for setting up zsh (via oh-my-zsh) on macOS and Linux. Small, all bash/zsh, no build system, no tests, no package manager.

## Running / testing changes

There's no test suite. To validate changes, run the install flow itself:

```bash
./install.sh --env personal            # personal git config + LLM headless signing & key sync from 1P
./install.sh --env personal-headless   # minimal personal git config (no 1Password / no prompts)
./install.sh --env work                # work git & SSH config (interactive 1P desktop signing & URL routing)
```

- `linux-install.sh` and `mac-install.sh` are also safe to run standalone (each `source`s `lib.sh` itself).
- Scripts use `set -euo pipefail` (`install.sh`) / `set -e` (the others) — keep new code compatible with that (no unbound var reads, check command success).
- `lib.sh` only defines `info()`/`warn()` helpers and has no side effects when sourced.

## Architecture

`install.sh` is the entrypoint and orchestrates everything in order:

1. On Linux, runs `linux-install.sh` first (installs zsh via whichever package manager is present — apt/dnf/pacman/zypper/apk — and chsh's it as the default shell, then `direnv`, `jq`, and, outside of `personal-headless`, `gh`) **before** oh-my-zsh is installed, since oh-my-zsh requires zsh to exist. `gh` is the one package not available from the stock apt repos on older Ubuntu/Debian, so the apt branch registers GitHub's own repo (`cli.github.com/packages`) before installing. `personal-headless` skips it entirely — that's the Pi fleet's environment, and nothing there has a GitHub credential to use `gh` with.
2. Installs oh-my-zsh itself (unattended) plus the `zsh-autosuggestions` and `zsh-syntax-highlighting` plugins if missing, and copies `pure.zsh-theme` into oh-my-zsh's custom themes dir.
3. On macOS, runs `mac-install.sh` with the environment flag (installs Homebrew, `1password-cli` for `personal`/`work`, the `claude-code` cask, `git-recent`, `direnv`, `gh`, `jq`, and `tea` — the Gitea CLI, macOS-only), then copies `zshrc.darwin` into `~/.zshrc-config/darwin.zsh`.
4. Backs up any existing `~/.zshrc` to `~/.zshrc.local` (or to `~/.zshrc.bak` if `.zshrc.local` already exists), then installs this repo's `zshrc` as `~/.zshrc`.
5. Sets up global git aliases (`co`, `lg`), and configures Git and SSH per `--env`:
   - `work`: Interactive 1Password setup (`user.name = "Gabriel Revells"`, prompts for work email, work org, and public signing key if not set; configures `op-ssh-sign`, 1P `IdentityAgent`, and URL rewriting for the work org).
   - `personal`: LLM setup (`user.name = "Skyler Revells"`, iCloud email; installs `sync-llm-keys` to `~/.local/bin/sync-llm-keys` and runs it; configures headless signing with `ssh-keygen` and non-interactive push keys `id_personal_github` and `id_personal_gitea` for `git-server`). Writes a marker-delimited managed block at the **top** of `~/.ssh/config` (backing the old file up to `~/.ssh/config.bak`), since ssh takes the first value it obtains for an option and the agent-based entries below it would otherwise win. Re-running replaces that block rather than stacking duplicates.
   - `personal-headless`: Minimal personal setup with no 1Password CLI, no token/org prompts, and no signing overrides.
6. On macOS under `personal` only, sets up Claude Code token-usage shipping: clones `github.com/gcrevell/claude-token-influx` to `~/src/claude-token-influx` (fast-forward only if already present), installs `claude-tokens-influx.sh` to `~/.local/bin/claude-tokens-influx`, renders `claude-tokens.plist` into `~/Library/LaunchAgents/com.skyler.claude-tokens.plist`, and `bootout`s then `bootstrap`s the agent. See below.
7. Rebuilds `~/.claude/settings.json` from three layers with `jq` — the existing file, then the tracked `claude-settings.json`, then `~/.claude-settings.local.json` — each overwriting the one before it. Skipped with a warning if `jq` isn't on `PATH`.

Key convention: **OS-specific zsh config is layered in, not hardcoded into `zshrc`.** The tracked `zshrc` sources every `*.zsh` file under `~/.zshrc-config/` (populated by `install.sh` per-OS, e.g. `darwin.zsh` from `zshrc.darwin`) and finally sources `~/.zshrc.local` for untracked, machine-specific overrides. When adding OS-specific shell config, add a new `zshrc.<os>` file and wire its install step into `install.sh`, rather than adding conditionals to `zshrc` directly.

Similarly, **Claude Code settings are layered in, not hand-maintained per machine.** Claude Code itself has no `~/.claude/settings.local.json` for user-level settings (that path only means something at project scope), so `install.sh` does the layering with `jq`, rebuilding `~/.claude/settings.json` from three layers that each overwrite the one before:

1. **the existing `~/.claude/settings.json`** — the base. Keys nothing else touches (`model`, `statusLine`, `enabledPlugins`, …) survive untouched.
2. **the tracked `claude-settings.json`** — shared defaults, re-applied on *every* run, so changing a default here actually reaches machines that are already set up.
3. **`~/.claude-settings.local.json`** — deliberate per-machine overrides, always wins. It lives in `$HOME` next to `.zshrc.local`, deliberately *not* at `~/.claude/settings.local.json`, since Claude Code doesn't read this file — only `install.sh` does.

**The rule is the same one `~/.zshrc` already follows: don't hand-edit the generated file for anything you want to keep.** Any key managed by `claude-settings.json` gets overwritten on every install; per-machine choices belong in `~/.claude-settings.local.json`.

Three details worth knowing about the merge:

- **Removing a key from `claude-settings.json` doesn't unset it.** It just stops being force-applied — whatever a previous run wrote stays in `~/.claude/settings.json`. Same as content in `~/.zshrc.local` sitting there forever.
- **Arrays are replaced, not merged.** `jq`'s `*` recurses into objects only, so a tracked list-valued key (e.g. `permissions.allow`) would replace the local list wholesale rather than appending to it.
- **`null` in the local file means the literal value `null`**, not "stop applying this default". A `null`-means-unset escape hatch could be added later if a real need shows up.

## Claude Code token usage → InfluxDB

macOS + `--env personal` only. Two halves in two repos, deliberately:

- **`github.com/gcrevell/claude-token-influx`** (public, cloned to `~/src/claude-token-influx`) — the collector. Walks `~/.claude/projects`, prints influx line protocol, writes nothing and knows no hostnames. Public because it has no network detail or credential in it. Note that home-ansible still ships its **own vendored copy** of this script to the Pi fleet (`shared/roles/telegraf/files/claude_tokens.sh`) rather than consuming this repo; the two are duplicates for now, and a fix to one needs applying to both until home-ansible is switched over.
- **this repo** — `claude-tokens-influx.sh` (wrapper: runs the collector, POSTs the result) and `claude-tokens.plist` (hourly launchd agent, `com.skyler.claude-tokens`).

**All configuration is untracked, in `~/.zshrc.local`** — `CLAUDE_TOKENS_INFLUX_URL`, `_TOKEN`, `_ORG`, `_BUCKET`, and `CLAUDE_TOKENS_HOST`. The wrapper is a **zsh** script specifically so it can `source` that file. None of these get defaults: this repo is public, so any default would commit a hostname or bucket name, and a wrong `CLAUDE_TOKENS_HOST` silently fragments the InfluxDB series rather than failing.

Constraints to preserve when touching any of this:

- **Counts only.** The collector reads transcripts containing every prompt and tool result on the machine and emits seven integers plus three tags. Any change that carries a transcript-derived *string* into a field is a data leak into a database with no read-side access control.
- **`--fail-with-body` on the curl is load-bearing.** `curl` exits 0 on a 401. Drop that flag and a revoked token makes every run report success while writing nothing.
- **No state, no retry, by design.** Full history every run; there is no cursor to get wrong, and a failed run is just a gap until the next one. Don't add a last-success file without also revisiting that reasoning.
- **The wrapper owns its log** (`~/Library/Logs/claude-tokens-influx.log`, trimmed to 500 lines). The plist points launchd's own streams at `/dev/null` — pointing them at a file instead would give an unrotated file *and* hold it open while the wrapper rewrites it.
- **Zero collector output is an error here**, though it's a legitimate result in general. On this laptop it means something broke, so the wrapper refuses to POST an empty body.
- **Don't enable this alongside home-ansible's telegraf collector on one host.** Both write the same measurement, and writes are idempotent on the tag set, so they'd clobber rather than sum.
