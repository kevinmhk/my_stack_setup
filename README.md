# My Stack Setup

Installer scripts for macOS, Linux, and Windows that bootstrap core CLI tools and machine setup conventions for this repo.

## Requirements

- macOS or Linux (Debian-based or RedHat-based) for `scripts/setup.sh`
- Windows with PowerShell for `scripts/setup-windows.ps1`
- A POSIX shell environment for the macOS/Linux path
- Network access
- Sudo privileges may be required by Homebrew on Linux
- Interactive approval is expected during Windows `vcredist2022` installation

## What It Does

- Installs Xcode Command Line Tools on macOS
- Installs Homebrew if missing
- Installs Homebrew formulae
- Installs Homebrew casks on macOS only
- Installs DBeaver on Linux via native package
- Installs Claude Code on Linux via the official installer script
- Installs Linux build tools via `build-essential` on Debian-based systems or `Development Tools` on RHEL-based systems
- Installs espeak-ng on Linux via apt-get or yum
- Prompts on Linux whether to install optional VPS remote GUI packages and Google Chrome
- Installs nvm and latest LTS Node.js
- Installs npm global packages
- Prompts whether to install `openclaw` via npm
- Installs oh-my-zsh
- Installs `zsh` via native Linux packages when needed
- On Linux, adds the detected `zsh` path to `/etc/shells` when needed and then attempts to change the login shell to that path after zsh setup
- Installs chezmoi and applies dotfiles from `https://github.com/kevinmhk/dotfiles`
- Prompts after a successful chezmoi apply/init flow whether to run `chezmoi purge --force`
- Ensures `~/workspaces` exists
- Creates `~/.config/chezmoi.toml` with auto-commit/auto-push and `delta` as diff pager
- Installs Tailscale on Linux; reminds to install on macOS
- Installs vim-plug for Vim plugin management
- Installs NvChad starter config for Neovim
- Installs Harlequin, ruff, and ty via uv
- Prints a reminder to run `:PlugInstall` in Vim
- Prints a reminder to install Flutter manually
- Prints a reminder to run `:MasonInstallAll` in Neovim
- Prints a reminder to onboard `.env` to `$HOME`
- Prints a reminder to run `scripts/install-gemini-extensions.sh` after signing in to Gemini CLI
- Logs to stdout and to a timestamped file in `logs/`
- Sets PowerShell execution policy to `RemoteSigned` for `CurrentUser` on Windows when needed
- Installs Scoop on Windows if missing
- Adds the Scoop `extras` bucket on Windows
- Installs Windows Scoop packages in sorted groups
- Prints a reminder to update the PowerShell profile on Windows

## Installed Packages

Homebrew formulae:
- age
- bat
- bats-assert
- bats-core
- bats-file
- bats-support
- chezmoi
- csvkit
- difftastic
- duckdb
- fd
- fzf
- gh
- helix
- git
- git-delta
- glow
- jq
- llama.cpp
- lazysql
- lazygit
- micro
- mtr
- mole
- neovim
- ngrok
- nmap
- opencode
- qwen-code
- qsv
- pytest
- ripgrep
- shellcheck
- shellspec
- shfmt
- sqlite
- starship
- tmux
- uv
- xan
- yazi
- zellij
- steipete/tap/codexbar (Linux only)

Homebrew casks (macOS only):
- 1password-cli
- betterdisplay
- cyberduck
- claude-code
- codex
- dbeaver-community
- dockdoor
- droid
- font-hack-nerd-font
- font-0xproto-nerd-font
- ghostty
- steipete/tap/codexbar
- thaw
- tigervnc
- warp
- xquartz

npm globals:
- @google/gemini-cli
- agent-browser
- @playwright/cli@latest
- @mariozechner/pi-coding-agent
- @mermaid-js/mermaid-cli
- bun
- firebase-tools
- openclaw (optional; prompted during setup)
- @openai/codex (Linux only)

uv tools:
- harlequin
- ruff@latest
- ty@latest

Linux native installs:
- Claude Code (via `curl -fsSL https://claude.ai/install.sh | bash`)

Linux system packages:
- zsh
- espeak-ng
- xauth (optional Linux VPS remote GUI prompt)
- x11-apps (optional Linux VPS remote GUI prompt)
- xvfb (optional Linux VPS remote GUI prompt)
- x11vnc (optional Linux VPS remote GUI prompt)
- openbox (optional Linux VPS remote GUI prompt)
- python3-xdg (optional Linux VPS remote GUI prompt)
- menu (optional Linux VPS remote GUI prompt)
- x11-utils (optional Linux VPS remote GUI prompt)

Linux optional downloads:
- Google Chrome via `wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb` followed by `dpkg -i` and `apt --fix-broken install -y`
- Google Chrome on RHEL-based systems via `wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm` followed by `dnf install` or `yum install`

Windows Scoop packages:
- bat
- fd
- fzf
- lazygit
- neovim
- ripgrep
- starship
- vcredist2022

## Usage

Run the script from the repository root:

```bash
scripts/setup.sh
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1
```

Non-interactive mode requires explicit choices for chezmoi apply, chezmoi purge, and `openclaw`:

```bash
scripts/setup.sh --non-interactive --chezmoi-apply=y --chezmoi-purge=n --openclaw-install=y
scripts/setup.sh --non-interactive --chezmoi-apply=n --chezmoi-purge=n --openclaw-install=n
```

## Contributor Guide

See `AGENTS.md` for repository conventions, scripts, and testing workflow.

## Local Skills

Repo-level Codex skills live under `.agents/skills/`:
- `.agents/skills/add-cli-package`: add CLI tools with setup, tests, and README updates
- `.agents/skills/add-package-manager`: add package managers with guards and reminders
- `.agents/skills/add-reminder`: add or regroup setup reminder messages and docs
- `.agents/skills/add-cask-app`: add macOS Homebrew casks and docs updates

## Logging

- Default log directory: `logs/`
- Default log file: `logs/setup_YYYYmmdd_HHMMSS.log`
- Override with environment variables:
  - `LOG_DIR`
  - `LOG_FILE`

## Testing

Assertions:

```bash
tests/assert.sh
```

Windows assertions:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\assert-windows.ps1
```

Setup CLI smoke tests:

```bash
bats tests/setup-args-smoke.bats
```

Container tests (Ubuntu + CentOS):

```bash
scripts/test-containers.sh ubuntu
scripts/test-containers.sh centos
scripts/test-containers.sh --all
scripts/test-containers.sh --help
```

Before running container tests, start Docker Desktop.

## Notes

- On Linux in default interactive mode, the script first asks you to confirm that you are running it as a non-root user with sudo permission; `Y`, `y`, or pressing Enter continues, while `N` or `n` exits immediately.
- On Linux, build tool bootstrap uses `apt-get install -y build-essential` on Debian-based systems and `dnf group install "Development Tools"` or `yum groupinstall "Development Tools"` on RHEL-based systems when `gcc` and `make` are not already present.
- After the Linux build tool step finishes in default interactive mode, the script asks whether to install optional VPS remote GUI packages. On Debian-based systems, `Y`, `y`, or pressing Enter installs `xauth`, `x11-apps`, `xvfb`, `x11vnc`, `openbox`, `python3-xdg`, `menu`, `x11-utils`, and Google Chrome. On RHEL-based systems, that flow currently installs only Google Chrome and prints a reminder that the GUI package bundle is not implemented yet.
- On Linux, privileged package installs use `sudo` in default interactive mode and `sudo -n` in `--non-interactive` mode.
- On Linux, the script installs `zsh` via `apt-get`, `dnf`, or `yum` when needed, then adds the detected `zsh` path to `/etc/shells` when needed and attempts `chsh -s <detected-zsh-path>`; in `--non-interactive` mode it prints a reminder instead of prompting.
- After a successful `chezmoi apply` or `chezmoi init --apply`, the script prompts whether to run `chezmoi purge --force`.
- The script prompts for chezmoi apply/init decisions in default interactive mode.
- The script also prompts whether to install `openclaw` in default interactive mode.
- Use `--non-interactive` only with `--chezmoi-apply=y|n`, `--chezmoi-purge=y|n`, and `--openclaw-install=y|n`.
- On Linux, Homebrew is installed under `/home/linuxbrew/.linuxbrew` by default.
- On Windows, `vcredist2022` may trigger a Windows confirmation dialog during `scoop install`.
- The Windows script does not edit the PowerShell profile; it prints a reminder instead.
