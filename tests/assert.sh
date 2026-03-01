#!/usr/bin/env bash
set -uo pipefail

OS_NAME="$(uname -s)"
BREW_ENV_LOADED=0
NVM_ENV_LOADED=0
FAILURES=()
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${LOG_DIR:-${REPO_ROOT}/logs}"
SUMMARY_FILE="${SUMMARY_FILE:-${LOG_DIR}/assert_summary_$(date +%Y%m%d_%H%M%S).log}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

record_failure() {
  FAILURES+=("$*")
  printf 'ASSERTION FAILED: %s\n' "$*" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

is_container() {
  if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    return 0
  fi
  return 1
}

ensure_brew() {
  if command_exists brew; then
    BREW_ENV_LOADED=1
    return 0
  fi

  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi

  if command_exists brew; then
    BREW_ENV_LOADED=1
    return 0
  fi

  record_failure "Homebrew is not available in PATH."
  return 1
}

assert_command() {
  local cmd="$1"

  if ! command_exists "$cmd"; then
    record_failure "Command not found: ${cmd}"
    return 1
  fi
}

formula_command_name() {
  case "$1" in
    steipete/tap/codexbar) printf '%s\n' "codexbar" ;;
    difftastic) printf '%s\n' "difft" ;;
    git-delta) printf '%s\n' "delta" ;;
    ripgrep) printf '%s\n' "rg" ;;
    neovim) printf '%s\n' "nvim" ;;
    sqlite) printf '%s\n' "sqlite3" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

cask_command_name() {
  case "$1" in
    1password-cli) printf '%s\n' "op" ;;
    dbeaver-community) printf '%s\n' "dbeaver" ;;
    steipete/tap/codexbar) printf '%s\n' "codexbar" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

assert_brew_formula() {
  local pkg="$1"

  if ! brew list --versions "$pkg" >/dev/null 2>&1; then
    record_failure "Homebrew formula missing: ${pkg}"
    return 1
  fi
}

assert_brew_formula_or_command() {
  local pkg="$1"
  local cmd
  cmd="$(formula_command_name "$pkg")"

  if brew list --versions "$pkg" >/dev/null 2>&1; then
    return 0
  fi

  if [ -n "$cmd" ] && command_exists "$cmd"; then
    return 0
  fi

  record_failure "Homebrew formula or command missing: ${pkg} (${cmd})"
  return 1
}

assert_brew_cask() {
  local cask="$1"

  if ! brew list --cask --versions "$cask" >/dev/null 2>&1; then
    record_failure "Homebrew cask missing: ${cask}"
    return 1
  fi
}

assert_brew_cask_or_command() {
  local cask="$1"
  local cmd
  cmd="$(cask_command_name "$cask")"

  if brew list --cask --versions "$cask" >/dev/null 2>&1; then
    return 0
  fi

  if [ -n "$cmd" ] && command_exists "$cmd"; then
    return 0
  fi

  record_failure "Homebrew cask or command missing: ${cask} (${cmd})"
  return 1
}

assert_npm_global() {
  local pkg="$1"

  if ! npm list -g --depth=0 "$pkg" >/dev/null 2>&1; then
    record_failure "npm global missing: ${pkg}"
    return 1
  fi
}

ensure_nvm() {
  if command_exists nvm; then
    NVM_ENV_LOADED=1
    return 0
  fi

  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

  local nvm_sh
  nvm_sh="${NVM_DIR}/nvm.sh"
  if [ ! -s "$nvm_sh" ]; then
    record_failure "nvm.sh not found at ${nvm_sh}"
    return 1
  fi

  local had_nounset=0
  if set -o | grep -q 'nounset[[:space:]]*on'; then
    had_nounset=1
    set +u
  fi

  # shellcheck source=/dev/null
  . "$nvm_sh"

  if [ "$had_nounset" -eq 1 ]; then
    set -u
  fi

  if ! command_exists nvm; then
    record_failure "nvm is not available after sourcing."
    return 1
  fi

  NVM_ENV_LOADED=1
}

main() {
  ensure_brew || true
  assert_command brew || true
  ensure_nvm || true
  assert_command nvm || true
  assert_command npm || true

  local formulae=(
    age
    bat
    bats-assert
    bats-core
    bats-file
    bats-support
    chezmoi
    csvkit
    difftastic
    duckdb
    fd
    fzf
    gh
    helix
    git
    git-delta
    glow
    jq
    llama.cpp
    lazysql
    lazygit
    micro
    neovim
    ngrok
    nmap
    opencode
    qwen-code
    qsv
    pytest
    ripgrep
    shellcheck
    shellspec
    shfmt
    sqlite
    tmux
    uv
    xan
    yazi
    zellij
    zsh
  )

  if [ "$OS_NAME" = "Darwin" ]; then
    formulae+=(mole)
  else
    formulae+=(steipete/tap/codexbar)
  fi

  local pkg
  for pkg in "${formulae[@]}"; do
    assert_brew_formula_or_command "$pkg" || true
  done

  if [ "$OS_NAME" = "Darwin" ]; then
    local casks=(
      1password-cli
      claude-code
      codex
      dbeaver-community
      dockdoor
      droid
      font-hack-nerd-font
      font-0xproto-nerd-font
      ghostty
      thaw
      steipete/tap/codexbar
      warp
    )

    local cask
    for cask in "${casks[@]}"; do
      assert_brew_cask_or_command "$cask" || true
    done
  fi

  local npm_packages=(
    @google/gemini-cli
    agent-browser
    @playwright/cli
    @mariozechner/pi-coding-agent
    @mermaid-js/mermaid-cli
    bun
    firebase-tools
    openclaw
  )

  if [ "$OS_NAME" != "Darwin" ]; then
    npm_packages+=(@openai/codex)
  fi

  for pkg in "${npm_packages[@]}"; do
    assert_npm_global "$pkg" || true
  done

  assert_command chezmoi || true
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    record_failure "oh-my-zsh not installed at ${HOME}/.oh-my-zsh"
  fi
  if [ ! -d "$HOME/workspaces" ]; then
    record_failure "Workspace directory missing at ${HOME}/workspaces"
  fi
  if [ ! -f "$HOME/.config/chezmoi/chezmoi.toml" ]; then
    record_failure "Chezmoi config missing at ${HOME}/.config/chezmoi/chezmoi.toml"
  fi
  if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
    record_failure "vim-plug missing at ${HOME}/.vim/autoload/plug.vim"
  fi
  if [ ! -d "$HOME/.config/nvim" ]; then
    record_failure "NvChad missing at ${HOME}/.config/nvim"
  fi
  if [ ! -x "$HOME/.local/bin/harlequin" ]; then
    record_failure "Harlequin binary missing at ${HOME}/.local/bin/harlequin"
  fi
  if [ ! -x "$HOME/.local/bin/ruff" ]; then
    record_failure "ruff binary missing at ${HOME}/.local/bin/ruff"
  fi
  if [ ! -x "$HOME/.local/bin/ty" ]; then
    record_failure "ty binary missing at ${HOME}/.local/bin/ty"
  fi
  if [ "$OS_NAME" = "Linux" ]; then
    assert_command espeak-ng || true
    if is_container; then
      log "Container detected: skipping Tailscale assertion."
    else
      assert_command tailscale || true
    fi
  fi

  if [ "${#FAILURES[@]}" -gt 0 ]; then
    mkdir -p "$LOG_DIR"
    printf '\nAssertion summary (%d failures):\n' "${#FAILURES[@]}" | tee -a "$SUMMARY_FILE" >&2
    local failure
    for failure in "${FAILURES[@]}"; do
      printf ' - %s\n' "$failure" | tee -a "$SUMMARY_FILE" >&2
    done
    printf 'Summary written to %s\n' "$SUMMARY_FILE" | tee -a "$SUMMARY_FILE" >&2
    exit 1
  fi

  log "All assertions passed."
}

main "$@"
