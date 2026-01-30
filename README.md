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
- Installs nvm and latest LTS Node.js
- Installs npm global packages
- Installs oh-my-zsh
- Installs chezmoi and applies dotfiles from `https://github.com/kevinmhk/dotfiles`
- Ensures `~/workspaces` exists
- Creates `~/.config/chezmoi.toml` with auto-commit and auto-push enabled
- Installs Tailscale on Linux; reminds to install on macOS
- Installs vim-plug for Vim plugin management
- Installs NvChad starter config for Neovim
- Installs Harlequin via uv
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
- chezmoi
- difftastic
- fd
- fzf
- gh
- helix
- git
- git-delta
- glow
- lazysql
- lazygit
- neovim
- opencode
- qwen-code
- ripgrep
- sqlite
- tmux
- uv
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

## Usage

Run the script from the repository root:

```bash
scripts/setup.sh
```

## Contributor Guide

See `AGENTS.md` for repository conventions, scripts, and testing workflow.

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
