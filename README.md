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

Your existing `~/.zshrc` (if different from this repo's) is backed up to `~/.zshrc.local`, which is sourced at the end of the installed `~/.zshrc` for untracked, machine-specific overrides.

Because the tracked defaults are re-applied on every run, don't hand-edit `~/.claude/settings.json` for anything you want to keep — put it in `~/.claude-settings.local.json` instead. Same rule as `~/.zshrc` vs `~/.zshrc.local`.
