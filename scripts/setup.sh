#!/usr/bin/env bash
set -euo pipefail

# Non-interactive by default
export NONINTERACTIVE=1

DOTFILES_REPO_URL="https://github.com/kevinmhk/dotfiles.git"
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

is_container() {
  if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    return 0
  fi
  return 1
}

REMINDERS=()

add_reminder() {
  REMINDERS+=("$1")
}

print_reminders() {
  if [ "${#REMINDERS[@]}" -eq 0 ]; then
    return 0
  fi

  local message
  for message in "${REMINDERS[@]}"; do
    if [ -t 1 ]; then
      printf '\033[31m%s\033[0m\n' "$message"
    else
      printf '%s\n' "$message"
    fi
  done
}

ensure_xcode_cli_tools() {
  if [ "$OS_NAME" != "Darwin" ]; then
    return 0
  fi

  if xcode-select -p >/dev/null 2>&1; then
    log "Xcode Command Line Tools already installed."
    return 0
  fi

  log "Installing Xcode Command Line Tools..."
  if ! xcode-select --install >/dev/null 2>&1; then
    log "xcode-select --install returned non-zero; installation may already be in progress."
  fi
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

formula_command_name() {
  case "$1" in
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
    *) printf '%s\n' "$1" ;;
  esac
}

brew_install_if_missing() {
  local pkg="$1"
  local cmd
  cmd="$(formula_command_name "$pkg")"

  if brew list --versions "$pkg" >/dev/null 2>&1; then
    return 0
  fi

  if [ -n "$cmd" ] && command_exists "$cmd"; then
    log "Skipping ${pkg}: command already available (${cmd})."
    return 0
  fi

  log "Installing ${pkg} via Homebrew..."
  run brew install "$pkg"
}

brew_cask_install_if_missing() {
  local cask="$1"
  local cmd
  cmd="$(cask_command_name "$cask")"

  if brew list --cask --versions "$cask" >/dev/null 2>&1; then
    return 0
  fi

  if [ -n "$cmd" ] && command_exists "$cmd"; then
    log "Skipping ${cask}: command already available (${cmd})."
    return 0
  fi

  log "Installing ${cask} via Homebrew cask..."
  run brew install --cask "$cask"
}

install_brew_formulae() {
  local formulae=(
    age
    bat
    chezmoi
    fd
    fzf
    gh
    git
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
    brew_install_if_missing "$pkg"
  done
}

install_oh_my_zsh() {
  local omz_dir="$HOME/.oh-my-zsh"

  if [ -d "$omz_dir" ]; then
    log "oh-my-zsh already installed."
    return 0
  fi

  if ! command_exists zsh; then
    brew_install_if_missing zsh
  fi

  log "Installing oh-my-zsh..."
  if command_exists curl; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      run sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  elif command_exists wget; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      run sh -c "$(wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    abort "Neither curl nor wget is available to install oh-my-zsh."
  fi
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
    droid
    font-hack-nerd-font
    font-0xproto-nerd-font
    ghostty
    warp
  )

  local cask
  for cask in "${casks[@]}"; do
    brew_cask_install_if_missing "$cask"
  done
}

install_nvm_and_node() {
  export NVM_DIR="$HOME/.nvm"
  mkdir -p "$NVM_DIR"

  local nvm_sh
  nvm_sh="${NVM_DIR}/nvm.sh"
  if [ ! -s "$nvm_sh" ]; then
    log "Installing nvm..."
    if command_exists curl; then
      run bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
    elif command_exists wget; then
      run bash -c "wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
    else
      abort "Neither curl nor wget is available to install nvm."
    fi
  fi

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
    agent-browser
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

install_agent_browser_runtime() {
  if ! command_exists agent-browser; then
    abort "agent-browser is not available after installation."
  fi

  log "Installing agent-browser runtime dependencies..."
  if ! printf 'y\n' | agent-browser install; then
    abort "agent-browser install failed."
  fi
}

install_or_notify_tailscale() {
  if [ "$OS_NAME" = "Darwin" ]; then
    log "Tailscale is not installed by this script on macOS."
    add_reminder "Reminder: Download and install Tailscale for macOS."
    return 0
  fi

  if [ "$OS_NAME" = "Linux" ]; then
    if command_exists tailscale; then
      log "Tailscale already installed."
      return 0
    fi

    if is_container; then
      log "Skipping Tailscale install in container environment."
      return 0
    fi

    log "Installing Tailscale..."
    if command_exists curl; then
      run sh -c "curl -fsSL https://tailscale.com/install.sh | sh"
    else
      abort "curl is required to install Tailscale."
    fi
  fi
}

install_vim_plug() {
  local plug_path="${HOME}/.vim/autoload/plug.vim"
  if [ -f "$plug_path" ]; then
    log "vim-plug already installed."
    return 0
  fi

  if ! command_exists curl; then
    abort "curl is required to install vim-plug."
  fi

  log "Installing vim-plug..."
  run curl -fLo "$plug_path" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
}

install_nvchad() {
  local nvim_dir="${HOME}/.config/nvim"

  if [ -d "$nvim_dir" ]; then
    log "NvChad already installed at ${nvim_dir}."
    return 0
  fi

  if ! command_exists git; then
    abort "git is required to install NvChad."
  fi

  log "Installing NvChad starter config..."
  run mkdir -p "${HOME}/.config"
  run git clone https://github.com/NvChad/starter "$nvim_dir"
}

remind_vim_plug_install() {
  add_reminder "Reminder: Run :PlugInstall in Vim after opening it."
}

remind_mason_install_all() {
  add_reminder "Reminder: Run :MasonInstallAll in Neovim after opening it."
}

remind_env_onboarding() {
  add_reminder "Reminder: Manually onboard your .env file to ${HOME}."
}

remind_gemini_extensions_install() {
  add_reminder "Reminder: After signing in to gemini-cli, run scripts/install-gemini-extensions.sh."
}

ensure_workspaces_dir() {
  local workspace_dir="${HOME}/workspaces"
  if [ -d "$workspace_dir" ]; then
    log "Workspace directory exists: ${workspace_dir}"
    return 0
  fi

  log "Creating workspace directory: ${workspace_dir}"
  run mkdir -p "$workspace_dir"
}

ensure_chezmoi_config() {
  local config_dir="${HOME}/.config"
  local config_file="${config_dir}/chezmoi.toml"

  if [ -f "$config_file" ]; then
    log "Chezmoi config already exists: ${config_file}"
    return 0
  fi

  log "Creating Chezmoi config: ${config_file}"
  run mkdir -p "$config_dir"
  cat <<'EOF' > "$config_file"
[git]
    autoCommit = true
    autoPush = true
EOF
}

main() {
  setup_logging
  ensure_xcode_cli_tools
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
  install_oh_my_zsh
  install_chezmoi_and_apply
  install_agent_browser_runtime
  install_or_notify_tailscale
  install_vim_plug
  install_nvchad
  ensure_workspaces_dir
  ensure_chezmoi_config
  remind_vim_plug_install
  remind_mason_install_all
  remind_env_onboarding
  remind_gemini_extensions_install
  log "Base setup complete."
  print_reminders
}

main "$@"
