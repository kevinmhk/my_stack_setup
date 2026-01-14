# My Stack Setup

A non-interactive setup script for macOS and Linux that installs Homebrew, core CLI tools, Node (via nvm), global npm packages, and applies dotfiles with chezmoi.

## Requirements

- macOS or Linux (Debian-based or RedHat-based)
- A POSIX shell environment
- Network access
- Sudo privileges may be required by Homebrew on Linux

## What It Does

- Installs Homebrew if missing
- Installs Homebrew formulae
- Installs Homebrew casks on macOS only
- Installs nvm and latest LTS Node.js
- Installs npm global packages
- Installs oh-my-zsh
- Installs chezmoi and applies dotfiles from `https://github.com/kevinmhk/dotfiles`
- Logs to stdout and to a timestamped file in `logs/`

## Installed Packages

Homebrew formulae:
- age
- bat
- chezmoi
- fd
- fzf
- gh
- git-delta
- glow
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

Homebrew casks (macOS only):
- 1password-cli
- codex
- dockdoor
- droid
- font-hack-nerd-font
- font-0xproto-nerd-font
- ghostty
- warp

npm globals:
- @google/gemini-cli
- agent-browser
- bun
- firebase-tools
- @openai/codex (Linux only)

## Usage

Run the script from the repository root:

```bash
scripts/setup.sh
```

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
scripts/test-containers.sh
```

Before running container tests, start Docker Desktop.

## Notes

- The script is non-interactive and is designed to be re-run safely.
- On Linux, Homebrew is installed under `/home/linuxbrew/.linuxbrew` by default.
