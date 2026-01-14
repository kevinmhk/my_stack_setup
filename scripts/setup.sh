#!/usr/bin/env bash
set -euo pipefail

# Non-interactive by default
export NONINTERACTIVE=1

DOTFILES_REPO_URL="https://github.com/kevinmhk/dotfiles"
OS_NAME="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-${SCRIPT_DIR}/../logs}"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/setup_$(date +%Y%m%d_%H%M%S).log}"

setup_logging() {
  mkdir -p "$LOG_DIR"
  exec > >(tee -a "$LOG_FILE") 2>&1
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

run() {
  log "+ $*"
  "$@"
}

abort() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

install_homebrew() {
  if command_exists brew; then
    return 0
  fi

  log "Installing Homebrew..."

  if command_exists curl; then
    run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  elif command_exists wget; then
    run /bin/bash -c "$(wget -qO- https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    abort "Neither curl nor wget is available to install Homebrew."
  fi

  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  else
    abort "Homebrew was installed but brew binary was not found on expected paths."
  fi
}

ensure_brew_shellenv() {
  if command_exists brew; then
    return 0
  fi

  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
}

brew_install_if_missing() {
  local pkg="$1"

  if brew list --versions "$pkg" >/dev/null 2>&1; then
    return 0
  fi

  log "Installing ${pkg} via Homebrew..."
  run brew install "$pkg"
}

brew_cask_install_if_missing() {
  local cask="$1"

  if brew list --cask --versions "$cask" >/dev/null 2>&1; then
    return 0
  fi

  log "Installing ${cask} via Homebrew cask..."
  run brew install --cask "$cask"
}

install_brew_formulae() {
  local formulae=(
    bat
    chezmoi
    fd
    fzf
    gh
    git-delta
    glow
    lazygit
    neovim
    opencode
    qwen-code
    ripgrep
    sqlite
    tmux
    uv
    yazi
    zellij
  )

  local pkg
  for pkg in "${formulae[@]}"; do
    brew_install_if_missing "$pkg"
  done
}

install_brew_casks() {
  if [ "$OS_NAME" != "Darwin" ]; then
    log "Skipping Homebrew casks on non-macOS."
    return 0
  fi

  run brew tap homebrew/cask-fonts

  local casks=(
    1password-cli
    codex
    dockdoor
    font-hack-nerd-font
    font-0xproto-nerd-font
    warp
  )

  local cask
  for cask in "${casks[@]}"; do
    brew_cask_install_if_missing "$cask"
  done
}

install_nvm_and_node() {
  brew_install_if_missing nvm

  export NVM_DIR="$HOME/.nvm"
  mkdir -p "$NVM_DIR"

  local nvm_sh
  nvm_sh="$(brew --prefix nvm)/nvm.sh"
  if [ ! -s "$nvm_sh" ]; then
    abort "nvm.sh not found at ${nvm_sh}"
  fi

  local had_nounset=0
  if set -o | grep -q 'nounset[[:space:]]*on'; then
    had_nounset=1
    set +u
  fi

  # shellcheck source=/dev/null
  . "$nvm_sh"

  if ! command_exists nvm; then
    if [ "$had_nounset" -eq 1 ]; then
      set -u
    fi
    abort "nvm is not available after installation."
  fi

  log "Installing latest LTS Node.js via nvm..."
  run nvm install --lts
  run nvm use --lts

  if ! command_exists npm; then
    if [ "$had_nounset" -eq 1 ]; then
      set -u
    fi
    abort "npm is not available after installing Node.js."
  fi

  if [ "$had_nounset" -eq 1 ]; then
    set -u
  fi
}

install_npm_globals() {
  local npm_packages=(
    @google/gemini-cli
    bun
    firebase-tools
  )

  if [ "$OS_NAME" != "Darwin" ]; then
    npm_packages+=(@openai/codex)
  fi

  local pkg
  for pkg in "${npm_packages[@]}"; do
    if npm list -g --depth=0 "$pkg" >/dev/null 2>&1; then
      continue
    fi

    log "Installing ${pkg} via npm..."
    run npm install -g "$pkg"
  done
}

install_chezmoi_and_apply() {
  brew_install_if_missing chezmoi

  if [ -d "$HOME/.local/share/chezmoi" ]; then
    log "Chezmoi already initialized; applying latest state..."
    run chezmoi apply
    return 0
  fi

  log "Initializing chezmoi from ${DOTFILES_REPO_URL}..."
  run chezmoi init --apply "$DOTFILES_REPO_URL"
}

main() {
  setup_logging
  ensure_brew_shellenv
  install_homebrew

  if ! command_exists brew; then
    abort "Homebrew is required but not available."
  fi

  run brew update

  install_brew_formulae
  install_brew_casks
  install_nvm_and_node
  install_npm_globals
  install_chezmoi_and_apply

  log "Base setup complete."
}

main "$@"
