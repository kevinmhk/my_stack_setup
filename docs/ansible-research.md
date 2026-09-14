# Ansible Assessment for `scripts/setup.sh`

Last reviewed: 2026-09-15

## Decision

Adopt Ansible for the macOS and Linux path, but keep the first migration small.

This repository bootstraps several Macs and Linux VPSs. Repeating the same workstation and server state across hosts makes Ansible's inventory, host-specific variables, idempotence, check mode, and remote execution worth its small control-plane cost. Use it as the eventual macOS/Linux source of truth, with separate `macos` and `vps` profiles; keep PowerShell/Scoop as the Windows source of truth.

Do not translate `scripts/setup.sh` line by line or maintain two long-lived installers. First move the host state Ansible models well, then retain a short compatibility wrapper only while the migration is tested. Explicitly opt in to user-desktop tasks on VPSs and server-only tasks on Macs.

## What Was Reviewed

- [scripts/setup.sh](../scripts/setup.sh): macOS/Linux bootstrap flow.
- [scripts/setup-windows.ps1](../scripts/setup-windows.ps1): separate Windows path.
- [tests/assert.sh](../tests/assert.sh): installed-state assertions.
- [tests/setup-args-smoke.bats](../tests/setup-args-smoke.bats): non-interactive argument validation.
- [README.md](../README.md): supported platforms, package lists, and runtime behavior.

The repository contains no Ansible inventory, playbook, role, collection lockfile, or Ansible test harness. A migration would therefore be a new configuration-management product, not a refactor.

## Why a Small Ansible Migration Is Justified

### Multiple hosts change the tradeoff

The shell script supports interactive local setup and a non-interactive form for the decisions that can change machine state materially:

```bash
scripts/setup.sh --non-interactive \
  --chezmoi-apply=n \
  --chezmoi-purge=n \
  --hermes-install=n
```

This remains a useful local escape hatch and test target, but it does not provide inventory, a durable record of which host receives which optional state, remote execution, or an idempotent dry run. A few Macs and VPSs are enough to benefit from a small `macos` versus `vps` variable model.

### The setup is not wholly declarative

Several critical steps are per-user and depend on an interactive shell or user-owned configuration:

- `nvm`, Node LTS selection, and global npm tools;
- `oh-my-zsh`, the login shell, Vim/NvChad, and `uv tool` installs;
- `chezmoi init --apply` and optional `chezmoi purge --force`;
- third-party repository clones followed by their own `install.sh` or `deploy.sh`;
- vendor installer scripts for Homebrew, Claude Code, Hermes Agent, and Tailscale.

Ansible can execute these steps, but it does not make them declarative. Keep them as small, opt-in exceptions after the core package/file/Git state is managed. `become` must target the right user, `nvm` must be sourced in the correct shell, and GUI casks must never be included in a VPS profile.

### It must replace, not duplicate, the macOS/Linux state

The current package and feature lists live in `scripts/setup.sh`, with parallel assertions in `tests/assert.sh` and user documentation in `README.md`. Keep that duplication only during migration. Once equivalent profiles and idempotence tests pass, make the Ansible variables the macOS/Linux source of truth and reduce the shell script to a compatibility launcher or retire it.

### Windows remains separate

Windows is supported through `scripts/setup-windows.ps1`. Do not expand this project into Ansible/WinRM merely for uniformity; PowerShell/Scoop remains the lower-cost native path. The Ansible migration is scoped to the macOS and Linux hosts already being managed repeatedly.

## Current Ansible Capabilities

Current upstream documentation confirms that Ansible can cover the shared state. `community.general` is an external collection rather than part of `ansible-core`; the current collection documentation lists version 13.4.0 and support for `ansible-core` 2.18 or later. Pin that collection and its compatible `ansible-core` version.

| Setup area | If a future Ansible migration is justified | Assessment |
| --- | --- | --- |
| Homebrew formulae | `community.general.homebrew` | Good fit after Homebrew exists; the module does not bootstrap Homebrew. Pass package lists directly rather than looping per formula. |
| Homebrew taps and casks | `community.general.homebrew_tap`, `community.general.homebrew_cask` | Good fit on macOS. Third-party taps may require an explicit trust policy. |
| Debian/RHEL packages | `ansible.builtin.apt`, `ansible.builtin.dnf` | Strong fit. Use `dnf` for the RHEL `@Development tools` group and local RPMs; use `apt`'s `deb` parameter for local or remote `.deb` files. |
| Directories, config, downloads | `ansible.builtin.file`, `template` or `copy`, `get_url` | Strong fit for `~/workspaces`, `chezmoi.toml`, and vim-plug. Preserve existing files unless replacing them is an explicit policy. |
| Git checkouts | `ansible.builtin.git` | Strong fit for NvChad and helper repositories. Do not use `force: true`; it discards local changes. |
| Login shell | `ansible.builtin.user` and `lineinfile` | Technically strong fit, but must run as the target user and use privilege escalation only for `/etc/shells`. |
| npm globals | `community.general.npm` | Feasible: it supports global packages and an explicit `npm` executable for version managers. It remains coupled to the chosen `nvm` Node version. |
| `chezmoi`, `agent-browser`, `uv tool`, and vendor installers | `ansible.builtin.command` or `shell` | Keep as isolated, guarded exceptions. Use `command` unless shell features are required; neither module makes a vendor installer declarative. |

## Recommended Migration Scope

Make Ansible the macOS/Linux source of truth; do not maintain shell and Ansible implementations indefinitely. Start with an inventory containing the Macs and VPSs, run Macs locally with `ansible_connection=local` or over SSH, and run VPSs over SSH. Preserve the existing script as a tested compatibility wrapper only during a short migration.

Minimum scope:

1. Declare supported controller and managed-node versions, plus a pinned `community.general` collection in `collections/requirements.yml`.
2. Define `macos` and `vps` inventory groups. Model common, Mac-only, and VPS-only package lists and features as variables; do not reproduce prompts as task logic.
3. Separate system tasks (`become: true`) from user tasks (`become: false`, explicit target user/home).
4. Port common declarative state first: package managers, packages, files, Git checkouts, and `/etc/shells`. Keep Mac casks, Linux GUI packages, and Tailscale in their respective profiles.
5. Leave vendor scripts and shell-bound tools as explicit opt-in tasks with reliable checks and `changed_when` rules.
6. Add `ansible-lint`, syntax checks, and an idempotence test before deleting any shell path.

Do not create a role per current shell function. Three roles are enough initially: `bootstrap` (Homebrew and package-manager prerequisites), `system` (packages and privileged state), and `user` (dotfiles, editors, and developer tools). Use inventory groups, not duplicate roles, for the Mac/VPS distinction.

## Specific Migration Constraints

- Homebrew must be bootstrapped before its Ansible modules can run.
- `community.general` is required for Homebrew and npm modules; `ansible-core` alone is insufficient.
- `nvm` is still an exception. Pin the intended Node LTS major/version and pass the selected `npm` executable rather than relying on Ansible's non-interactive shell PATH.
- Do not translate `curl | sh` blindly. Prefer a native package/repository or a verified pinned artifact when one exists. If the vendor script remains necessary, treat it as an opt-in imperative task.
- `chezmoi purge --force` is destructive. It must default to `false` and never be made an unattended default.
- `ansible.builtin.git` protects modified working trees by default. Retain that behavior for user-owned dotfiles and helper repos.
- Ansible's controller/managed-node Python requirements must be supported on every target. This matters particularly for fresh Linux machines, where package tooling and Python are bootstrapping prerequisites.

## Recommended Next Step

Implement a minimal, localhost-first Ansible baseline for one Mac and one VPS, then expand it after the second run is clean:

1. Add a pinned `collections/requirements.yml`, a small inventory, and a single `setup.yml` playbook with `macos` and `vps` groups.
2. Port packages, directories, `chezmoi.toml`, vim-plug, and Git checkouts; verify a second run reports no changes.
3. Add user-shell, Node/npm, and vendor-installer exceptions as opt-in tasks only after the core profile works.
4. Update `tests/assert.sh` and `README.md` alongside each migration increment; retire duplicate shell state only after an equivalent Ansible check and idempotence test pass.

## Upstream References

- [Ansible installation and node requirements](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html)
- [community.general collection](https://docs.ansible.com/projects/ansible/latest/collections/community/general/)
- [Homebrew module](https://docs.ansible.com/projects/ansible/latest/collections/community/general/homebrew_module.html)
- [Homebrew cask module](https://docs.ansible.com/projects/ansible/latest/collections/community/general/homebrew_cask_module.html)
- [Homebrew tap module](https://docs.ansible.com/projects/ansible/latest/collections/community/general/homebrew_tap_module.html)
- [npm module](https://docs.ansible.com/projects/ansible/latest/collections/community/general/npm_module.html)
- [APT module](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/apt_module.html)
- [DNF module](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/dnf_module.html)
- [Git module](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/git_module.html)
- [Command module](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/command_module.html)
- [Shell module](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/shell_module.html)
