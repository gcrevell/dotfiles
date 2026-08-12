# dotfiles

Personal dotfiles for setting up a zsh environment on macOS and Linux.

## Install

```bash
git clone <this-repo> ~/src/dotfiles
cd ~/src/dotfiles
./install.sh --env personal            # personal git config
./install.sh --env personal-headless   # personal git config, same flow as above
./install.sh --env work                # work git config instead
```

Restart your shell (or run `source ~/.zshrc`) afterwards.

Re-running `install.sh` is safe — it skips anything already installed and won't overwrite `~/.zshrc.local`.

## What it sets up

- **zsh** as the shell, installed via the system package manager on Linux (apt/dnf/pacman/zypper/apk) and set as the default shell (macOS ships with zsh already).
- **oh-my-zsh**, installed unattended, with the `pure` theme and these plugins: `git`, `gh`, `z`, `colored-man-pages`, `command-not-found`, `zsh-autosuggestions`, `zsh-syntax-highlighting`.
- **On macOS**: Homebrew (if missing), the `claude-code` cask, and `git-recent`.
- **direnv**, installed via Homebrew on macOS or the system package manager on Linux, and hooked into `~/.zshrc`.
- **gh** (GitHub CLI), installed via Homebrew on macOS or the system package manager on Linux. On apt systems it adds GitHub's own apt repo first, since Ubuntu/Debian only ship `gh` in newer releases — that repo covers `arm64`/`armhf`, so Raspberry Pi works.
- **jq**, installed via Homebrew on macOS or the system package manager on Linux. Used to merge the Claude Code settings below.
- **`~/.zshrc`**: history settings, `EDITOR`/`VISUAL`/`LANG`, `PATH` additions (`~/.bin`, `~/.local/bin`), aliases (`ll`, `la`, `..`, `...`, `grep`, `gs`, `gd`, `gco`, `gc`), and the `direnv` shell hook.
- **OS-specific zsh config** under `~/.zshrc-config/`, sourced automatically from `~/.zshrc` (e.g. `zshrc.darwin` becomes `~/.zshrc-config/darwin.zsh`, adding Homebrew's shellenv and Mac-only aliases like `flushdns`, `showfiles`, `hidefiles`, `vsc`).
- **Git aliases**: `co` (checkout), `lg` (pretty log graph).
- **Git identity**: `--env` is required and must be `work`, `personal`, or `personal-headless`. `work` sets `user.name` to "Gabriel Revells" and prompts for a work email (only if `user.email` isn't already set); `personal` and `personal-headless` set the personal identity ("Skyler Revells" / iCloud email) and are otherwise identical.
- **Claude Code settings**: `~/.claude/settings.json` is rebuilt from the tracked `claude-settings.json` (shared defaults, re-applied every run) layered over whatever is already in the file, with `~/.claude-settings.local.json` applied last so per-machine overrides always win.

Your existing `~/.zshrc` (if different from this repo's) is backed up to `~/.zshrc.local`, which is sourced at the end of the installed `~/.zshrc` for untracked, machine-specific overrides.

Because the tracked defaults are re-applied on every run, don't hand-edit `~/.claude/settings.json` for anything you want to keep — put it in `~/.claude-settings.local.json` instead. Same rule as `~/.zshrc` vs `~/.zshrc.local`.
