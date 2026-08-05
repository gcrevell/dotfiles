# dotfiles

Personal dotfiles for setting up a zsh environment on macOS and Linux.

## Install

```bash
git clone <this-repo> ~/src/dotfiles
cd ~/src/dotfiles
./install.sh          # personal git config
./install.sh --work    # work git config instead
```

Restart your shell (or run `source ~/.zshrc`) afterwards.

Re-running `install.sh` is safe — it skips anything already installed and won't overwrite `~/.zshrc.local`.

## What it sets up

- **zsh** as the shell, installed via the system package manager on Linux (apt/dnf/pacman/zypper/apk) and set as the default shell (macOS ships with zsh already).
- **oh-my-zsh**, installed unattended, with the `pure` theme and these plugins: `git`, `gh`, `z`, `colored-man-pages`, `command-not-found`, `zsh-autosuggestions`, `zsh-syntax-highlighting`.
- **On macOS**: Homebrew (if missing) and the `claude-code` cask.
- **direnv**, installed via Homebrew on macOS or the system package manager on Linux, and hooked into `~/.zshrc`.
- **`~/.zshrc`**: history settings, `EDITOR`/`VISUAL`/`LANG`, `PATH` additions (`~/.bin`, `~/.local/bin`), aliases (`ll`, `la`, `..`, `...`, `grep`, `gs`, `gd`, `gco`, `gc`), and the `direnv` shell hook.
- **OS-specific zsh config** under `~/.zshrc-config/`, sourced automatically from `~/.zshrc` (e.g. `zshrc.darwin` becomes `~/.zshrc-config/darwin.zsh`, adding Homebrew's shellenv and Mac-only aliases like `flushdns`, `showfiles`, `hidefiles`, `vsc`).
- **Git aliases**: `co` (checkout), `lg` (pretty log graph).
- **Git identity**: `--work` sets `user.name` to "Gabriel Revells" and prompts for a work email (only if `user.email` isn't already set); without `--work` it sets the personal identity ("Skyler Revells" / iCloud email).

Your existing `~/.zshrc` (if different from this repo's) is backed up to `~/.zshrc.local`, which is sourced at the end of the installed `~/.zshrc` for untracked, machine-specific overrides.
