# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repo for setting up zsh (via oh-my-zsh) on macOS and Linux. Small, all bash/zsh, no build system, no tests, no package manager.

## Running / testing changes

There's no test suite. To validate changes, run the install flow itself:

```bash
./install.sh --env personal            # personal git config (Skyler Revells / icloud email)
./install.sh --env personal-headless   # same flow as --env personal
./install.sh --env work                # work git config (Gabriel Revells, prompts for work email if not already set)
```

- `linux-install.sh` and `mac-install.sh` are also safe to run standalone (each `source`s `lib.sh` itself).
- Scripts use `set -euo pipefail` (`install.sh`) / `set -e` (the others) — keep new code compatible with that (no unbound var reads, check command success).
- `lib.sh` only defines `info()`/`warn()` helpers and has no side effects when sourced.

## Architecture

`install.sh` is the entrypoint and orchestrates everything in order:

1. On Linux, runs `linux-install.sh` first (installs zsh via whichever package manager is present — apt/dnf/pacman/zypper/apk — and chsh's it as the default shell, then `direnv`, `jq`, and `gh`) **before** oh-my-zsh is installed, since oh-my-zsh requires zsh to exist. `gh` is the one package not available from the stock apt repos on older Ubuntu/Debian, so the apt branch registers GitHub's own repo (`cli.github.com/packages`) before installing.
2. Installs oh-my-zsh itself (unattended) plus the `zsh-autosuggestions` and `zsh-syntax-highlighting` plugins if missing, and copies `pure.zsh-theme` into oh-my-zsh's custom themes dir.
3. On macOS, runs `mac-install.sh` (installs Homebrew, the `claude-code` cask, `git-recent`, `direnv`, `gh`, `jq`, and `tea` — the Gitea CLI, macOS-only), then copies `zshrc.darwin` into `~/.zshrc-config/darwin.zsh`.
4. Backs up any existing `~/.zshrc` to `~/.zshrc.local` (or to `~/.zshrc.bak` if `.zshrc.local` already exists), then installs this repo's `zshrc` as `~/.zshrc`.
5. Sets up global git aliases (`co`, `lg`), and either personal or work `user.name`/`user.email` depending on the required `--env` flag (`work`, `personal`, or `personal-headless` — the latter two are currently identical).
6. Rebuilds `~/.claude/settings.json` from three layers with `jq` — the existing file, then the tracked `claude-settings.json`, then `~/.claude-settings.local.json` — each overwriting the one before it. Skipped with a warning if `jq` isn't on `PATH`.

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
