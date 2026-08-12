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

1. On Linux, runs `linux-install.sh` first (installs zsh via whichever package manager is present — apt/dnf/pacman/zypper/apk — and chsh's it as the default shell, then `direnv` and `gh`) **before** oh-my-zsh is installed, since oh-my-zsh requires zsh to exist. `gh` is the one package not available from the stock apt repos on older Ubuntu/Debian, so the apt branch registers GitHub's own repo (`cli.github.com/packages`) before installing.
2. Installs oh-my-zsh itself (unattended) plus the `zsh-autosuggestions` and `zsh-syntax-highlighting` plugins if missing, and copies `pure.zsh-theme` into oh-my-zsh's custom themes dir.
3. On macOS, runs `mac-install.sh` (installs Homebrew, the `claude-code` cask, `git-recent`, `direnv`, `gh`, and `tea` — the Gitea CLI, macOS-only), then copies `zshrc.darwin` into `~/.zshrc-config/darwin.zsh`.
4. Backs up any existing `~/.zshrc` to `~/.zshrc.local` (or to `~/.zshrc.bak` if `.zshrc.local` already exists), then installs this repo's `zshrc` as `~/.zshrc`.
5. Sets up global git aliases (`co`, `lg`), and either personal or work `user.name`/`user.email` depending on the required `--env` flag (`work`, `personal`, or `personal-headless` — the latter two are currently identical).
6. Deep-merges the tracked `claude-settings.json` into `~/.claude/settings.json` (via a small `python3` snippet), recursively overlaying tracked keys onto whatever is already there — so it never clobbers machine-local settings (e.g. `statusLine`, `enabledPlugins`) that aren't tracked in this repo.

Key convention: **OS-specific zsh config is layered in, not hardcoded into `zshrc`.** The tracked `zshrc` sources every `*.zsh` file under `~/.zshrc-config/` (populated by `install.sh` per-OS, e.g. `darwin.zsh` from `zshrc.darwin`) and finally sources `~/.zshrc.local` for untracked, machine-specific overrides. When adding OS-specific shell config, add a new `zshrc.<os>` file and wire its install step into `install.sh`, rather than adding conditionals to `zshrc` directly.

Similarly, **`claude-settings.json` is the single source of truth for shared Claude Code settings across machines.** To add a new global Claude Code setting to every machine, just add a key to `claude-settings.json` — the deep-merge in `install.sh` picks it up automatically without any script changes. Machine-local settings that shouldn't sync (e.g. `statusLine`) belong only in the real `~/.claude/settings.json`, never in the tracked file.
