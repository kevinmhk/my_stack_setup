# My Stack Setup

A non-interactive setup script for macOS and Linux that installs Homebrew, core CLI tools, Node (via nvm), global npm packages, and applies dotfiles with chezmoi.

## Requirements

- macOS or Linux (Debian-based or RedHat-based)
- A POSIX shell environment
- Network access
- Sudo privileges may be required by Homebrew on Linux

## What It Does

- Installs Xcode Command Line Tools on macOS
- Installs Homebrew if missing
- Installs Homebrew formulae
- Installs Homebrew casks on macOS only
- Installs DBeaver on Linux via native package
- Installs espeak-ng on Linux via apt-get or yum
- Installs nvm and latest LTS Node.js
- Installs npm global packages
- Installs oh-my-zsh
- Installs chezmoi and applies dotfiles from `https://github.com/kevinmhk/dotfiles`
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
- lazysql
- lazygit
- micro
- neovim
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
- tmux
- uv
- xan
- yazi
- zellij
- zsh
- steipete/tap/codexbar (Linux only)

Homebrew casks (macOS only):
- 1password-cli
- codex
- dbeaver-community
- dockdoor
- droid
- font-hack-nerd-font
- font-0xproto-nerd-font
- ghostty
- thaw
- steipete/tap/codexbar
- warp

npm globals:
- @google/gemini-cli
- agent-browser
- @playwright/cli@latest
- @mariozechner/pi-coding-agent
- @mermaid-js/mermaid-cli
- bun
- firebase-tools
- @openai/codex (Linux only)

uv tools:
- harlequin
- ruff@latest
- ty@latest

Linux system packages:
- espeak-ng

## Usage

Run the script from the repository root:

```bash
scripts/setup.sh
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

Container tests (Ubuntu + CentOS):

```bash
scripts/test-containers.sh ubuntu
scripts/test-containers.sh centos
scripts/test-containers.sh --all
scripts/test-containers.sh --help
```

Before running container tests, start Docker Desktop.

## Notes

- The script is non-interactive and is designed to be re-run safely.
- On Linux, Homebrew is installed under `/home/linuxbrew/.linuxbrew` by default.
