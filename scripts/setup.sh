#!/usr/bin/env bash
set -euo pipefail

# Interactive by default
NONINTERACTIVE=0
CHEZMOI_APPLY_CHOICE=""
CHEZMOI_PURGE_CHOICE=""
OPENCLAW_INSTALL_CHOICE=""

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

run_sudo() {
	local missing_sudo_message="$1"
	shift

	if ! command_exists sudo; then
		abort "$missing_sudo_message"
	fi

	if [ "$NONINTERACTIVE" -eq 1 ]; then
		run sudo -n "$@"
	else
		run sudo "$@"
	fi
}

print_usage() {
	cat <<'EOF'
Usage: scripts/setup.sh [--non-interactive --chezmoi-apply=y|n --chezmoi-purge=y|n --openclaw-install=y|n] [--help]

Options:
  --non-interactive       Run without prompts.
  --chezmoi-apply=y|n     Required with --non-interactive; controls chezmoi apply/init --apply.
  --chezmoi-purge=y|n     Required with --non-interactive; controls post-apply chezmoi purge.
  --openclaw-install=y|n  Required with --non-interactive; controls optional openclaw npm install.
  --help, -h              Show this help message.
EOF
}

parse_args() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
		--non-interactive)
			NONINTERACTIVE=1
			;;
		--chezmoi-apply=*)
			CHEZMOI_APPLY_CHOICE="${1#*=}"
			;;
		--chezmoi-apply)
			shift || abort "Missing value for --chezmoi-apply. Use y or n."
			CHEZMOI_APPLY_CHOICE="$1"
			;;
		--chezmoi-purge=*)
			CHEZMOI_PURGE_CHOICE="${1#*=}"
			;;
		--chezmoi-purge)
			shift || abort "Missing value for --chezmoi-purge. Use y or n."
			CHEZMOI_PURGE_CHOICE="$1"
			;;
		--openclaw-install=*)
			OPENCLAW_INSTALL_CHOICE="${1#*=}"
			;;
		--openclaw-install)
			shift || abort "Missing value for --openclaw-install. Use y or n."
			OPENCLAW_INSTALL_CHOICE="$1"
			;;
		--help | -h)
			print_usage
			exit 0
			;;
		*)
			abort "Unknown option: $1. Use --help for usage."
			;;
		esac
		shift
	done

	case "$CHEZMOI_APPLY_CHOICE" in
	"" | y | Y | n | N) ;;
	*)
		abort "Invalid value for --chezmoi-apply: ${CHEZMOI_APPLY_CHOICE}. Use y or n."
		;;
	esac

	case "$CHEZMOI_PURGE_CHOICE" in
	"" | y | Y | n | N) ;;
	*)
		abort "Invalid value for --chezmoi-purge: ${CHEZMOI_PURGE_CHOICE}. Use y or n."
		;;
	esac

	case "$OPENCLAW_INSTALL_CHOICE" in
	"" | y | Y | n | N) ;;
	*)
		abort "Invalid value for --openclaw-install: ${OPENCLAW_INSTALL_CHOICE}. Use y or n."
		;;
	esac

	if [ "$NONINTERACTIVE" -eq 1 ]; then
		if [ -z "$CHEZMOI_APPLY_CHOICE" ]; then
			abort "--chezmoi-apply=y|n is required when --non-interactive is set."
		fi

		if [ -z "$CHEZMOI_PURGE_CHOICE" ]; then
			abort "--chezmoi-purge=y|n is required when --non-interactive is set."
		fi

		if [ -z "$OPENCLAW_INSTALL_CHOICE" ]; then
			abort "--openclaw-install=y|n is required when --non-interactive is set."
		fi
	fi

	if [ "$NONINTERACTIVE" -eq 0 ] && [ -n "$CHEZMOI_APPLY_CHOICE" ]; then
		abort "--chezmoi-apply is only valid with --non-interactive."
	fi

	if [ "$NONINTERACTIVE" -eq 0 ] && [ -n "$CHEZMOI_PURGE_CHOICE" ]; then
		abort "--chezmoi-purge is only valid with --non-interactive."
	fi

	if [ "$NONINTERACTIVE" -eq 0 ] && [ -n "$OPENCLAW_INSTALL_CHOICE" ]; then
		abort "--openclaw-install is only valid with --non-interactive."
	fi

	if [ "$NONINTERACTIVE" -eq 1 ]; then
		export NONINTERACTIVE=1
	else
		export -n NONINTERACTIVE 2>/dev/null || true
	fi
}

confirm() {
	local prompt="$1"
	local default="${2:-n}"
	local prompt_suffix='[y/N]'
	local reply

	case "$default" in
	y | Y)
		prompt_suffix='[Y/n]'
		;;
	n | N)
		prompt_suffix='[y/N]'
		;;
	*)
		abort "Invalid default for confirm: ${default}. Use y or n."
		;;
	esac

	if [ -t 0 ]; then
		printf '%s %s: ' "$prompt" "$prompt_suffix"
		read -r reply
	else
		reply="$default"
	fi

	if [ -z "$reply" ]; then
		reply="$default"
	fi

	case "$reply" in
	[Yy]*)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

confirm_linux_user_requirements() {
	if [ "$OS_NAME" != "Linux" ] || [ "$NONINTERACTIVE" -eq 1 ]; then
		return 0
	fi

	if ! [ -t 0 ]; then
		abort "Interactive mode requires a TTY for the Linux startup confirmation."
	fi

	if confirm "Linux setup should be run by a non-root user with sudo permission. Continue?" y; then
		return 0
	fi

	log "Exiting setup at user request."
	exit 0
}

should_install_linux_vps_gui_packages() {
	local prompt="$1"

	if [ "$OS_NAME" != "Linux" ]; then
		return 1
	fi

	if [ "$NONINTERACTIVE" -eq 1 ]; then
		return 1
	fi

	if ! [ -t 0 ]; then
		abort "Interactive mode requires a TTY for the Linux VPS GUI package prompt."
	fi

	confirm "$prompt" y
}

should_setup_vps_gui_start_scripts() {
	local prompt="$1"

	if [ "$OS_NAME" != "Linux" ]; then
		return 1
	fi

	if [ "$NONINTERACTIVE" -eq 1 ]; then
		return 1
	fi

	if ! [ -t 0 ]; then
		abort "Interactive mode requires a TTY for the VPS GUI start script prompt."
	fi

	confirm "$prompt" y
}

should_apply_chezmoi() {
	local prompt="$1"

	if [ "$NONINTERACTIVE" -eq 1 ]; then
		case "$CHEZMOI_APPLY_CHOICE" in
		y | Y) return 0 ;;
		n | N) return 1 ;;
		*)
			abort "Invalid non-interactive chezmoi choice. Use --chezmoi-apply=y|n."
			;;
		esac
	fi

	if ! [ -t 0 ]; then
		abort "Interactive mode requires a TTY for chezmoi prompt. Use --non-interactive --chezmoi-apply=y|n."
	fi

	confirm "$prompt"
}

should_purge_chezmoi() {
	local prompt="$1"

	if [ "$NONINTERACTIVE" -eq 1 ]; then
		case "$CHEZMOI_PURGE_CHOICE" in
		y | Y) return 0 ;;
		n | N) return 1 ;;
		*)
			abort "Invalid non-interactive chezmoi purge choice. Use --chezmoi-purge=y|n."
			;;
		esac
	fi

	if ! [ -t 0 ]; then
		abort "Interactive mode requires a TTY for chezmoi purge prompt. Use --non-interactive --chezmoi-purge=y|n."
	fi

	confirm "$prompt"
}

setup_vps_gui_start_scripts_if_requested() {
	local workspace_dir="${HOME}/workspaces"
	local repo_dir="${workspace_dir}/vps-gui-scripts"
	local deploy_dir="${repo_dir}/scripts"
	local deploy_script="${deploy_dir}/deploy.sh"

	if ! should_setup_vps_gui_start_scripts "Set up the start scripts for the VPS GUI and Openbox session now?"; then
		log "Skipping VPS GUI and Openbox start script setup."
		return 0
	fi

	ensure_workspaces_dir
	brew_install_if_missing git

	if [ -d "$repo_dir" ]; then
		log "VPS GUI scripts repo already exists at ${repo_dir}."
	else
		log "Cloning VPS GUI scripts into ${workspace_dir}..."
		(
			cd "$workspace_dir"
			run git clone https://github.com/kevinmhk/vps-gui-scripts.git
		)
	fi

	if [ ! -f "$deploy_script" ]; then
		abort "Expected deploy script not found at ${deploy_script}"
	fi

	log "Running VPS GUI start script deploy.sh..."
	(
		cd "$deploy_dir"
		run bash ./deploy.sh
	)
}

should_install_openclaw() {
	local prompt="$1"

	if [ "$NONINTERACTIVE" -eq 1 ]; then
		case "$OPENCLAW_INSTALL_CHOICE" in
		y | Y) return 0 ;;
		n | N) return 1 ;;
		*)
			abort "Invalid non-interactive openclaw choice. Use --openclaw-install=y|n."
			;;
		esac
	fi

	if ! [ -t 0 ]; then
		abort "Interactive mode requires a TTY for openclaw prompt. Use --non-interactive --openclaw-install=y|n."
	fi

	confirm "$prompt"
}

purge_chezmoi_if_requested() {
	if should_purge_chezmoi "Purge chezmoi now with 'chezmoi purge --force'?"; then
		log "Purging chezmoi..."
		run chezmoi purge --force
	else
		log "Skipping chezmoi purge."
	fi
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
	claude-code) printf '%s\n' "claude" ;;
	dbeaver-community) printf '%s\n' "dbeaver" ;;
	steipete/tap/codexbar) printf '%s\n' "codexbar" ;;
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
		lazysql
		lazygit
		llama.cpp
		micro
		mtr
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
		starship
		tmux
		uv
		xan
		yazi
		zellij
	)

	if [ "$OS_NAME" = "Darwin" ]; then
		formulae+=(mole)
	else
		formulae+=(steipete/tap/codexbar)
	fi

	local pkg
	for pkg in "${formulae[@]}"; do
		brew_install_if_missing "$pkg"
	done
}

install_linux_zsh() {
	if [ "$OS_NAME" != "Linux" ]; then
		return 0
	fi

	if command_exists zsh; then
		log "zsh already installed."
		return 0
	fi

	if command_exists apt-get; then
		if ! command_exists sudo; then
			abort "sudo is required to install zsh."
		fi

		log "Installing zsh via apt-get..."
		run_sudo "sudo is required to update apt package metadata." apt-get update
		run_sudo "sudo is required to install zsh." apt-get install -y zsh
		return 0
	fi

	if command_exists dnf; then
		log "Installing zsh via dnf..."
		run_sudo "sudo is required to install zsh." dnf -y install zsh
		return 0
	fi

	if command_exists yum; then
		log "Installing zsh via yum..."
		run_sudo "sudo is required to install zsh." yum -y install zsh
		return 0
	fi

	abort "Neither apt-get, dnf, nor yum is available to install zsh."
}

install_oh_my_zsh() {
	local omz_dir="$HOME/.oh-my-zsh"

	if [ -d "$omz_dir" ]; then
		log "oh-my-zsh already installed."
		return 0
	fi

	if ! command_exists zsh; then
		if [ "$OS_NAME" = "Linux" ]; then
			install_linux_zsh
		else
			abort "zsh is required on macOS but was not found."
		fi
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

ensure_linux_zsh_login_shell() {
	local target_shell

	if [ "$OS_NAME" != "Linux" ]; then
		return 0
	fi

	if ! target_shell="$(command -v zsh)"; then
		add_reminder "Reminder: zsh is not available, so the login shell was not changed."
		return 0
	fi

	if [ "${SHELL:-}" = "$target_shell" ]; then
		log "Login shell already set to ${target_shell}."
		return 0
	fi

	if [ -f /etc/shells ] && ! grep -qxF "$target_shell" /etc/shells; then
		log "Adding ${target_shell} to /etc/shells..."
		printf '%s\n' "$target_shell" | run_sudo "sudo is required to update /etc/shells." tee -a /etc/shells >/dev/null
	fi

	if ! command_exists chsh; then
		add_reminder "Reminder: chsh is not available, so the login shell was not changed to ${target_shell}."
		return 0
	fi

	if [ "$NONINTERACTIVE" -eq 1 ]; then
		add_reminder "Reminder: Run 'chsh -s ${target_shell}' to change your login shell on Linux."
		return 0
	fi

	log "Changing login shell to ${target_shell}..."
	run chsh -s "$target_shell"
}

install_brew_casks() {
	if [ "$OS_NAME" != "Darwin" ]; then
		log "Skipping Homebrew casks on non-macOS."
		return 0
	fi

	run brew tap homebrew/cask-fonts

	local casks=(
		1password-cli
		betterdisplay
		cyberduck
		claude-code
		codex
		dbeaver-community
		dockdoor
		droid
		font-hack-nerd-font
		font-0xproto-nerd-font
		ghostty
		steipete/tap/codexbar
		thaw
		tigervnc
		warp
		xquartz
	)

	local cask
	for cask in "${casks[@]}"; do
		brew_cask_install_if_missing "$cask"
	done
}

ensure_linux_build_essential() {
	if [ "$OS_NAME" != "Linux" ]; then
		return 0
	fi

	if command_exists gcc && command_exists make; then
		log "Linux build toolchain already available."
		return 0
	fi

	if command_exists apt-get; then
		if command_exists dpkg-query &&
			dpkg-query -W -f='${Status}' build-essential 2>/dev/null | grep -q '^install ok installed$'; then
			log "build-essential already installed."
			return 0
		fi

		if ! command_exists sudo; then
			abort "sudo is required to install build-essential."
		fi

		log "Installing build-essential via apt-get..."
		run_sudo "sudo is required to install build-essential." apt-get update
		run_sudo "sudo is required to install build-essential." apt-get install -y build-essential
		return 0
	fi

	if command_exists dnf; then
		log "Installing Development Tools via dnf group install..."
		run_sudo "sudo is required to install Development Tools." dnf -y group install "Development Tools"
		return 0
	fi

	if command_exists yum; then
		log "Installing Development Tools via yum groupinstall..."
		run_sudo "sudo is required to install Development Tools." yum -y groupinstall "Development Tools"
		return 0
	fi

	abort "Unable to verify Linux build prerequisites: apt-get, dnf, and yum are unavailable and gcc/make were not found."
}

install_linux_vps_gui_packages() {
	if [ "$OS_NAME" != "Linux" ]; then
		return 0
	fi

	if ! should_install_linux_vps_gui_packages "Install remote GUI packages for a Linux VPS?"; then
		log "Skipping Linux VPS remote GUI package install."
		return 0
	fi

	if ! command_exists sudo; then
		abort "sudo is required to install the Linux VPS remote GUI packages."
	fi

	if ! command_exists wget; then
		abort "wget is required to download Google Chrome for the Linux VPS remote GUI setup."
	fi

	if command_exists apt-get; then
		if ! command_exists dpkg-query; then
			abort "dpkg-query is required to verify the Linux VPS remote GUI packages."
		fi

		local debian_packages=(
			xauth
			x11-apps
			xvfb
			x11vnc
			openbox
			python3-xdg
			menu
			x11-utils
		)
		local missing_debian_packages=()
		local pkg

		for pkg in "${debian_packages[@]}"; do
			if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q '^install ok installed$'; then
				missing_debian_packages+=("$pkg")
			fi
		done

		if [ "${#missing_debian_packages[@]}" -gt 0 ]; then
			log "Installing Linux VPS remote GUI packages via apt-get..."
			run_sudo "sudo is required to update apt package metadata." apt-get update
			run_sudo "sudo is required to install the Linux VPS remote GUI packages." \
				apt-get install -y "${missing_debian_packages[@]}"
		else
			log "Linux VPS remote GUI packages already installed."
		fi

		if command_exists google-chrome || command_exists google-chrome-stable; then
			log "Google Chrome already installed."
			setup_vps_gui_start_scripts_if_requested
			return 0
		fi

		local chrome_deb
		chrome_deb="$(mktemp --suffix=.deb)"

		log "Downloading Google Chrome .deb package..."
		run wget -O "$chrome_deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

		log "Installing Google Chrome via dpkg..."
		if ! run_sudo "sudo is required to install Google Chrome." dpkg -i "$chrome_deb"; then
			log "dpkg reported missing dependencies for Google Chrome; continuing with apt --fix-broken install."
		fi
		log "Fixing Google Chrome package dependencies via apt..."
		run_sudo "sudo is required to fix Google Chrome package dependencies." apt --fix-broken install -y

		run rm -f "$chrome_deb"
		setup_vps_gui_start_scripts_if_requested
		return 0
	fi

	if command_exists dnf || command_exists yum; then
		if command_exists google-chrome || command_exists google-chrome-stable; then
			log "Google Chrome already installed."
			add_reminder "Reminder: The optional Linux VPS remote GUI package bundle is currently only implemented for Debian-based systems. On this RHEL-based system, Google Chrome is already installed."
			setup_vps_gui_start_scripts_if_requested
			return 0
		fi

		local chrome_rpm
		chrome_rpm="$(mktemp --suffix=.rpm)"

		add_reminder "Reminder: The optional Linux VPS remote GUI package bundle is currently only implemented for Debian-based systems. On this RHEL-based system, only Google Chrome was installed."

		log "Downloading Google Chrome .rpm package..."
		run wget -O "$chrome_rpm" https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm

		if command_exists dnf; then
			log "Installing Google Chrome via dnf..."
			run_sudo "sudo is required to install Google Chrome." dnf -y install "$chrome_rpm"
		else
			log "Installing Google Chrome via yum..."
			run_sudo "sudo is required to install Google Chrome." yum -y install "$chrome_rpm"
		fi

		run rm -f "$chrome_rpm"
		setup_vps_gui_start_scripts_if_requested
		return 0
	fi

	abort "Linux VPS remote GUI setup requires apt-get, dnf, or yum."
}

install_dbeaver_linux() {
	if [ "$OS_NAME" != "Linux" ]; then
		return 0
	fi

	if is_container; then
		log "Skipping DBeaver install in container environment."
		return 0
	fi

	if command_exists dbeaver; then
		log "DBeaver already installed."
		return 0
	fi

	if [ ! -f /etc/os-release ]; then
		abort "Cannot detect Linux distribution for DBeaver install."
	fi

	# shellcheck disable=SC1091
	. /etc/os-release

	local arch
	local url
	local tmp_file
	local os_like

	arch="$(uname -m)"
	os_like="${ID_LIKE:-${ID:-}}"

	case "$arch" in
	x86_64 | amd64)
		if printf '%s' "$os_like" | grep -qiE 'debian|ubuntu'; then
			url="https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb"
		elif printf '%s' "$os_like" | grep -qiE 'rhel|fedora|centos|rocky|almalinux'; then
			url="https://dbeaver.io/files/dbeaver-ce-latest-stable.x86_64.rpm"
		else
			abort "Unsupported Linux distribution for DBeaver install: ${os_like}"
		fi
		;;
	aarch64 | arm64)
		if printf '%s' "$os_like" | grep -qiE 'debian|ubuntu'; then
			url="https://dbeaver.io/files/dbeaver-ce_latest_arm64.deb"
		elif printf '%s' "$os_like" | grep -qiE 'rhel|fedora|centos|rocky|almalinux'; then
			url="https://dbeaver.io/files/dbeaver-ce-latest-stable.aarch64.rpm"
		else
			abort "Unsupported Linux distribution for DBeaver install: ${os_like}"
		fi
		;;
	*)
		abort "Unsupported CPU architecture for DBeaver install: ${arch}"
		;;
	esac

	if ! command_exists curl; then
		abort "curl is required to install DBeaver on Linux."
	fi

	if printf '%s' "$url" | grep -qE '\.deb$'; then
		tmp_file="$(mktemp --suffix=.deb)"
	else
		tmp_file="$(mktemp)"
	fi
	log "Downloading DBeaver from ${url}..."
	run curl -fsSL -o "$tmp_file" "$url"

	if printf '%s' "$url" | grep -qE '\.deb$'; then
		run_sudo "sudo is required to install the DBeaver .deb package." apt-get update
		run_sudo "sudo is required to install the DBeaver .deb package." apt-get install -y "$tmp_file"
	else
		if command_exists dnf; then
			run_sudo "sudo is required to install the DBeaver .rpm package." dnf -y install "$tmp_file"
		elif command_exists yum; then
			run_sudo "sudo is required to install the DBeaver .rpm package." yum -y install "$tmp_file"
		else
			abort "Neither dnf nor yum is available to install the DBeaver .rpm package."
		fi
	fi
}

install_espeak_ng() {
	if [ "$OS_NAME" != "Linux" ]; then
		return 0
	fi

	if command_exists espeak-ng; then
		log "espeak-ng already installed."
		return 0
	fi

	if command_exists apt-get; then
		log "Installing espeak-ng via apt-get..."
		run_sudo "sudo is required to install espeak-ng." apt-get update
		run_sudo "sudo is required to install espeak-ng." apt-get install -y espeak-ng
		return 0
	fi

	if command_exists yum; then
		log "Installing espeak-ng via yum..."
		run_sudo "sudo is required to install espeak-ng." yum -y install espeak-ng
		return 0
	fi

	abort "Neither apt-get nor yum is available to install espeak-ng."
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
		@playwright/cli@latest
		@mariozechner/pi-coding-agent
		@mermaid-js/mermaid-cli
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

install_claude_code_linux() {
	if [ "$OS_NAME" != "Linux" ]; then
		return 0
	fi

	if command_exists claude; then
		log "Claude Code already installed."
		return 0
	fi

	if ! command_exists curl; then
		abort "curl is required to install Claude Code on Linux."
	fi

	log "Installing Claude Code via official Linux installer..."
	run bash -c "curl -fsSL https://claude.ai/install.sh | bash"
}

install_openclaw() {
	if npm list -g --depth=0 openclaw >/dev/null 2>&1; then
		log "openclaw already installed."
		return 0
	fi

	if should_install_openclaw "Install openclaw via npm?"; then
		log "Installing openclaw via npm..."
		run npm install -g openclaw
	else
		log "Skipping openclaw install."
	fi
}

install_chezmoi_and_apply() {
	brew_install_if_missing chezmoi

	if [ -d "$HOME/.local/share/chezmoi" ]; then
		log "Chezmoi already initialized."
		if should_apply_chezmoi "Apply chezmoi dotfiles now?"; then
			run chezmoi apply
			purge_chezmoi_if_requested
		else
			log "Skipping chezmoi apply. Run 'chezmoi apply' manually later."
		fi
		return 0
	fi

	if should_apply_chezmoi "Initialize and apply chezmoi from ${DOTFILES_REPO_URL}?"; then
		run chezmoi init --apply "$DOTFILES_REPO_URL"
		purge_chezmoi_if_requested
	else
		log "Skipping chezmoi init. Run 'chezmoi init --apply <repo>' manually later."
	fi
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

install_harlequin() {
	local uv_tools=(
		harlequin
		ruff@latest
		ty@latest
	)

	if ! command_exists uv; then
		abort "uv is required to install uv tools."
	fi

	local tool
	for tool in "${uv_tools[@]}"; do
		local cmd="${tool%%@*}"
		if command_exists "$cmd"; then
			log "${cmd} already installed."
			continue
		fi

		log "Installing ${tool} via uv..."
		run uv tool install "$tool"
	done
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

remind_flutter_install() {
	add_reminder "Reminder: Install Flutter manually."
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
	local config_dir="${HOME}/.config/chezmoi"
	local config_file="${config_dir}/chezmoi.toml"

	if [ -f "$config_file" ]; then
		log "Chezmoi config already exists: ${config_file}"
		return 0
	fi

	log "Creating Chezmoi config: ${config_file}"
	run mkdir -p "$config_dir"
	cat <<'EOF' >"$config_file"
[git]
    autoCommit = true
    autoPush = true

[diff]
    pager = "delta"
EOF
}

main() {
	parse_args "$@"
	confirm_linux_user_requirements
	setup_logging
	ensure_xcode_cli_tools
	ensure_brew_shellenv
	install_homebrew

	if ! command_exists brew; then
		abort "Homebrew is required but not available."
	fi

	run brew tap bats-core/bats-core
	run brew update

	ensure_linux_build_essential
	ensure_workspaces_dir
	install_brew_formulae
	install_linux_zsh
	install_linux_vps_gui_packages
	install_brew_casks
	install_dbeaver_linux
	install_espeak_ng
	install_nvm_and_node
	install_npm_globals
	install_openclaw
	install_oh_my_zsh
	ensure_linux_zsh_login_shell
	install_claude_code_linux
	install_agent_browser_runtime
	install_or_notify_tailscale
	install_vim_plug
	install_nvchad
	install_harlequin
	ensure_chezmoi_config
	install_chezmoi_and_apply
	remind_flutter_install
	remind_vim_plug_install
	remind_mason_install_all
	remind_env_onboarding
	remind_gemini_extensions_install
	log "Base setup complete."
	print_reminders
}

main "$@"
