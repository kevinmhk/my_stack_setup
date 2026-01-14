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

assert_brew_formula() {
  local pkg="$1"

  if ! brew list --versions "$pkg" >/dev/null 2>&1; then
    record_failure "Homebrew formula missing: ${pkg}"
    return 1
  fi
}

assert_brew_cask() {
  local cask="$1"

  if ! brew list --cask --versions "$cask" >/dev/null 2>&1; then
    record_failure "Homebrew cask missing: ${cask}"
    return 1
  fi
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

  if ! command_exists brew; then
    record_failure "Homebrew is required to locate nvm."
    return 1
  fi

  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

  local nvm_sh
  nvm_sh="$(brew --prefix nvm)/nvm.sh"
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
    zsh
  )

  local pkg
  for pkg in "${formulae[@]}"; do
    assert_brew_formula "$pkg" || true
  done

  if [ "$OS_NAME" = "Darwin" ]; then
    local casks=(
      1password-cli
      codex
      dockdoor
      droid
      font-hack-nerd-font
      font-0xproto-nerd-font
      ghostty
      warp
    )

    local cask
    for cask in "${casks[@]}"; do
      assert_brew_cask "$cask" || true
    done
  fi

  local npm_packages=(
    @google/gemini-cli
    bun
    firebase-tools
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
