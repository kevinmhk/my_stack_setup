# Ansible Conversion Research for `scripts/setup.sh`

## Executive Summary

Yes, this repository's macOS/Linux installer can be converted to Ansible, but it should not be translated line by line.

The current `scripts/setup.sh` mixes four concerns:

1. Host/package state management.
2. User-level file and Git checkout management.
3. Interactive decision-making.
4. Third-party bootstrap scripts that are piped from the network.

Ansible is a strong fit for the first two concerns and a weaker fit for the last two. The cleanest migration path is:

1. Replace interactive prompts with variables.
2. Convert package, file, Git, and shell configuration work to Ansible-native modules.
3. Keep a small number of explicit `ansible.builtin.command` or `ansible.builtin.shell` tasks for installers that do not have first-class Ansible module coverage.
4. Split the playbook into roles by responsibility instead of preserving the current shell function layout.

My assessment is that most of the installer can be moved to Ansible with good idempotence. The main rough edges are `Homebrew` bootstrap, `nvm`, `oh-my-zsh`, `Claude Code`, `Tailscale`, `agent-browser install`, and the `chezmoi` apply/init flow.

## Scope Reviewed

Primary script sections reviewed:

- `parse_args()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:67)
- `confirm_linux_user_requirements()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:198)
- `setup_vps_gui_start_scripts_if_requested()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:305)
- `install_shell_welcome_messages_and_tools_reminder_if_requested()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:386)
- `install_homebrew()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:483)
- `install_brew_formulae()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:581)
- `install_oh_my_zsh()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:675)
- `ensure_linux_zsh_login_shell()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:703)
- `install_brew_casks()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:739)
- `ensure_linux_build_essential()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:772)
- `install_linux_vps_gui_packages()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:814)
- `install_dbeaver_linux()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:921)
- `install_linux_bubblewrap()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:1001)
- `install_espeak_ng()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:1039)
- `install_nvm_and_node()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:1065)
- `install_npm_globals()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:1118)
- `install_claude_code_linux()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:1144)
- `install_openclaw()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:1162)
- `install_chezmoi_and_apply()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:1176)
- `install_agent_browser_runtime()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:1198)
- `install_or_notify_tailscale()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:1209)
- `install_vim_plug()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:1236)
- `install_nvchad()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:1252)
- `install_harlequin()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:1269)
- `ensure_chezmoi_config()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:1324)
- `main()` at [scripts/setup.sh](/home/kevinmhk/workspaces/my_stack_setup/scripts/setup.sh:1345)

Related validation/docs reviewed:

- [tests/assert.sh](/home/kevinmhk/workspaces/my_stack_setup/tests/assert.sh:1)
- [README.md](/home/kevinmhk/workspaces/my_stack_setup/README.md:1)

## High-Level Verdict

### Good Ansible Candidates

- Directory creation such as `~/workspaces` and config directories.
- Package installation on Linux.
- Homebrew package and cask management after Homebrew already exists.
- Git repository checkouts and updates.
- File creation and templating such as `~/.config/chezmoi/chezmoi.toml`.
- `/etc/shells` updates and user login shell management.
- Downloading files such as `vim-plug`, Chrome packages, and DBeaver packages.
- Conditional execution based on OS family, architecture, and feature flags.

### Weak Ansible Candidates

- Prompt-driven decision trees.
- Installer scripts piped from remote URLs.
- Tools whose installation depends on shell session mutation, especially `nvm`.
- Third-party post-install commands with limited introspection, such as `agent-browser install`.
- `chezmoi apply/init/purge`, which is automatable but still fundamentally command-driven.

## Module-by-Module Mapping

The table below focuses on the practical Ansible translation, not a literal shell-function clone.

| Current shell area | Current function(s) | Recommended Ansible approach | Notes |
| --- | --- | --- | --- |
| Argument parsing and interactivity | `parse_args`, `confirm_*`, `should_*` | Replace with inventory/group vars, role defaults, and `when` clauses. Use `ansible.builtin.pause` only if you intentionally want interactive local runs. | Ansible is normally variable-driven, not prompt-driven. This part should be redesigned, not ported literally. |
| Logging | `setup_logging`, `log`, `run` | Use Ansible task output, `log_path`, and structured task names. | No reason to recreate shell-style tee logging inside Ansible. |
| macOS Xcode CLT bootstrap | `ensure_xcode_cli_tools` | `ansible.builtin.command` for `xcode-select -p` check and `xcode-select --install` when missing. | There is no general built-in module for this exact macOS bootstrap step. |
| Homebrew bootstrap | `install_homebrew`, `ensure_brew_shellenv` | `ansible.builtin.command` or `ansible.builtin.shell` guarded by `creates`/checks. | `community.general.homebrew` manages packages after Brew exists; it does not solve Brew bootstrap itself. |
| Homebrew taps | implicit `brew tap ...` in `main`, plus cask fonts tap | `community.general.homebrew_tap` | Good Ansible fit. |
| Homebrew formulae | `install_brew_formulae` | `community.general.homebrew` with package lists | Strong fit on both macOS and Linux once Brew is installed. |
| Homebrew casks | `install_brew_casks` | `community.general.homebrew_cask` | macOS only. Strong fit. |
| Generic Linux packages | `install_linux_zsh`, `install_linux_bubblewrap`, `install_espeak_ng` | Prefer `ansible.builtin.package` where possible. Use `ansible.builtin.apt` or `ansible.builtin.dnf` when you need package-manager-specific options such as cache updates. | This is exactly the kind of host state Ansible handles well. |
| Linux compiler/bootstrap group | `ensure_linux_build_essential` | `ansible.builtin.apt` for `build-essential`; `ansible.builtin.dnf` for `"Development Tools"` on RHEL-family hosts. | RHEL group installs should be handled with package-manager-aware tasks instead of generic shell. |
| Optional Linux VPS GUI packages | `install_linux_vps_gui_packages` | `ansible.builtin.package` or package-manager-specific tasks, plus `ansible.builtin.get_url` for Chrome package downloads. | Debian is straightforward. The current RHEL path is intentionally incomplete, so the playbook should preserve that limitation explicitly. |
| DBeaver native packages | `install_dbeaver_linux` | `ansible.builtin.get_url` plus `ansible.builtin.apt` for local `.deb`, or `ansible.builtin.dnf`/`yum` for local `.rpm`. | Good fit. Architecture- and distro-based URL selection belongs in vars or facts-driven conditionals. |
| Workspace repositories | `setup_vps_gui_start_scripts_if_requested`, `install_shell_welcome_message_repo`, `install_nvchad` | `ansible.builtin.git` | Strong fit for `vps-gui-scripts`, welcome-message repos, and `NvChad/starter`. |
| Repo-provided follow-up scripts | `deploy.sh`, `install.sh` calls in helper repos | `ansible.builtin.command` | Use `chdir`, `creates`, and clear ownership. These are external imperative steps, so keep them explicit. |
| `oh-my-zsh` | `install_oh_my_zsh` | Prefer `ansible.builtin.git` to clone `~/.oh-my-zsh`; use `command` only for any truly unavoidable post-step. | This should not remain a remote `curl | sh` if migrated to Ansible. |
| Login shell | `ensure_linux_zsh_login_shell` | `ansible.builtin.lineinfile` for `/etc/shells`, `ansible.builtin.user` for the login shell | Very good fit. |
| `nvm` install and shell sourcing | `install_nvm_and_node` | Likely `ansible.builtin.git` or `ansible.builtin.command` for `nvm` install, then `command`/`shell` for `nvm install --lts` in a sourced shell. | Possible, but awkward. This is one of the least elegant parts of the migration. |
| npm globals | `install_npm_globals`, `install_openclaw` | `community.general.npm` if `npm` is available in a stable path; otherwise `command` with sourced `nvm`. | The more tightly Node is coupled to `nvm`, the more shell-heavy this part becomes. |
| Claude Code Linux installer | `install_claude_code_linux` | `ansible.builtin.shell` or `ansible.builtin.command` guarded by checks | No obvious first-class Ansible module for this installer flow. |
| `agent-browser install` runtime step | `install_agent_browser_runtime` | `ansible.builtin.command` | This is a post-install imperative command, not a declarative resource. |
| Tailscale | `install_or_notify_tailscale` | Prefer native packages/repo setup if you standardize it. If you keep the vendor script, use explicit `command`/`shell`. | The current `curl | sh` pattern is automatable but less desirable than repo-based package management. |
| `vim-plug` download | `install_vim_plug` | `ansible.builtin.get_url` | Excellent fit. |
| uv tools | `install_harlequin` | `ansible.builtin.command` for `uv tool install ...`, ideally with idempotence guards | There is no first-class Ansible `uv tool` module. |
| Config file creation | `ensure_chezmoi_config` | `ansible.builtin.template` or `ansible.builtin.copy` | Excellent fit. |
| `chezmoi` init/apply/purge | `install_chezmoi_and_apply`, `purge_chezmoi_if_requested` | `ansible.builtin.command` with `creates`, `changed_when`, and explicit feature flags | This is feasible but remains command-driven. |
| Reminders | `add_reminder`, `print_reminders`, reminder helpers | `ansible.builtin.debug` or end-of-run summary tasks | Good fit, but some reminders may become unnecessary once the playbook owns more state. |

## What Should Be Redesigned Instead of Ported Literally

### 1. Interactive Prompts

The script currently asks the operator about:

- whether Linux setup is being run as a non-root sudo-capable user;
- whether to install Linux VPS GUI packages;
- whether to deploy VPS GUI start scripts;
- whether to apply `chezmoi`;
- whether to purge `chezmoi`;
- whether to install `openclaw`;
- whether to install welcome-message/tool repos.

That pattern is natural in shell and unnatural in Ansible. The better Ansible model is a variable contract such as:

```yaml
setup_confirm_linux_user_requirements: true
setup_install_vps_gui: false
setup_install_vps_gui_scripts: false
setup_chezmoi_apply: true
setup_chezmoi_purge: false
setup_install_openclaw: false
setup_install_shell_welcome_repos: false
```

Then each role or task block uses `when:` instead of an inline prompt.

If you still want an interactive local mode, use `vars_prompt` or `ansible.builtin.pause` as a thin front-end, but do not make that the primary execution model.

### 2. Remote `curl | sh` Installers

These show up in multiple places:

- Homebrew bootstrap
- `oh-my-zsh`
- `nvm`
- `Claude Code`
- `Tailscale`

Ansible can run them, but a cleaner Ansible migration would reduce them where possible:

- use Git checkout plus file tasks instead of the `oh-my-zsh` installer;
- prefer package repositories over vendor scripts when available;
- isolate unavoidable vendor installers behind clearly named `command` or `shell` tasks with strong guards.

### 3. `nvm`

`nvm` is the single biggest source of operational friction in an Ansible migration because:

- it depends on shell sourcing;
- it mutates per-user shell state;
- global npm installs depend on the active Node selection;
- idempotence is less clean than package-manager-native Node installation.

You can still automate it, but it is not the cleanest Ansible story. If you want the Ansible playbook to be easy to maintain, consider whether `nvm` is still a requirement or whether Node should be installed from Homebrew on macOS/Linuxbrew hosts, or managed by a different tool with less shell coupling.

## Suggested Ansible Role Layout

I would not put everything into one playbook file. A cleaner layout would look like this:

```text
ansible/
  inventories/
    localhost.yml
  playbooks/
    setup.yml
  roles/
    bootstrap/
    brew/
    linux_base/
    node/
    shell/
    editors/
    dotfiles/
    extras/
```

Suggested responsibilities:

- `bootstrap`
  - Xcode CLT checks on macOS
  - Homebrew bootstrap when missing

- `brew`
  - taps
  - formulae
  - casks

- `linux_base`
  - build tools
  - `zsh`
  - `bubblewrap`
  - `espeak-ng`
  - optional VPS GUI packages
  - optional DBeaver package install

- `node`
  - Node runtime strategy
  - npm global packages
  - optional `openclaw`
  - `agent-browser install`

- `shell`
  - `oh-my-zsh`
  - `/etc/shells`
  - user login shell
  - shell welcome repos

- `editors`
  - `vim-plug`
  - `NvChad`
  - `harlequin`
  - `ruff`
  - `ty`

- `dotfiles`
  - `chezmoi.toml`
  - `chezmoi init`
  - optional `chezmoi apply`
  - optional `chezmoi purge`

- `extras`
  - `Claude Code`
  - `Tailscale`
  - reminders/debug summaries

## Conversion Feasibility by Area

### Very Strong Fit

- `~/workspaces` directory creation
- package lists
- Homebrew package state after bootstrap
- Git clones
- config file templating
- `/etc/shells` and login shell
- `vim-plug` download

### Feasible but Shell-Backed

- Homebrew bootstrap
- `nvm`
- `Claude Code`
- `agent-browser install`
- `chezmoi apply/init/purge`
- `Tailscale` if you keep the vendor script

### Should Be Treated as Product Decisions

- whether interactive prompts should survive at all;
- whether `nvm` should remain part of the design;
- whether the welcome-message repositories should stay as separate repos with their own install scripts, or be absorbed into the main configuration model;
- whether `chezmoi` should remain an imperative post-step or become a separately managed concern.

## Risks and Migration Traps

### 1. False Idempotence

If the migration uses too many raw `shell` tasks without `creates`, `changed_when`, and pre-checks, the playbook will appear to work but will not behave like an Ansible-native system.

### 2. Shell Environment Drift

Tasks that depend on sourced shell files, especially `nvm`, can behave differently under Ansible than under an interactive terminal.

### 3. User vs Root Ownership

This installer mixes system-level package changes and user-level dotfile/editor setup. In Ansible, that separation should be made explicit using `become: true` only where needed.

### 4. Localhost vs Remote Host Assumptions

The current script is written for a human running it locally. If you convert it to Ansible, decide early whether the supported model is:

- `localhost` only; or
- remote hosts over SSH; or
- both.

That decision affects how much shell-state tooling is acceptable.

## Recommended Migration Plan

### Phase 1: Normalize the Contract

Before writing many Ansible tasks, extract the shell script's decisions into documented variables:

- package lists;
- OS-specific package maps;
- feature flags for optional components;
- URLs for downloaded assets and Git repos.

This reduces the risk of baking shell control flow directly into Ansible.

### Phase 2: Migrate Native-State Tasks First

Port these first because they are high value and low risk:

- directories;
- Homebrew taps, formulae, and casks;
- Linux system packages;
- config files;
- Git clones;
- `/etc/shells` and login shell;
- `vim-plug`.

### Phase 3: Isolate Shell-Heavy Tasks

Keep these in dedicated tasks or roles with strong guards:

- Homebrew bootstrap;
- `nvm`;
- `Claude Code`;
- `agent-browser install`;
- `chezmoi apply`;
- `Tailscale` vendor installer if kept.

### Phase 4: Decide Whether to Keep the Imperative Extras

Reassess whether the playbook should continue to own:

- optional welcome-message repo installs;
- optional VPS GUI script deployment;
- `chezmoi purge`;
- prompt-style reminders.

Some of these may be better documented than automated.

## Recommended Final Answer to the Core Question

If the question is "Can `scripts/setup.sh` be converted to Ansible?", the answer is yes.

If the question is "Should it be converted as a direct shell-to-task translation?", the answer is no.

The best Ansible version of this repo would:

- be variable-driven instead of prompt-driven;
- use Ansible-native modules for packages, files, Git, and user state;
- keep only a small number of explicit command tasks for tools without module coverage;
- treat `nvm` and `chezmoi` as deliberate exceptions rather than pretending they are first-class declarative resources.

## Current Upstream Docs Used

The following current Ansible documentation pages are the key references behind this assessment:

- `community.general.homebrew`
  - https://docs.ansible.com/ansible/latest/collections/community/general/homebrew_module.html
- `community.general.homebrew_cask`
  - https://docs.ansible.com/ansible/latest/collections/community/general/homebrew_cask_module.html
- `community.general.homebrew_tap`
  - https://docs.ansible.com/ansible/latest/collections/community/general/homebrew_tap_module.html
- `community.general.npm`
  - https://docs.ansible.com/ansible/latest/collections/community/general/npm_module.html
- `ansible.builtin.git`
  - https://docs.ansible.com/ansible/latest/collections/ansible/builtin/git_module.html
- `ansible.builtin.package`
  - https://docs.ansible.com/ansible/latest/collections/ansible/builtin/package_module.html
- `ansible.builtin.apt`
  - https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html
- `ansible.builtin.dnf`
  - https://docs.ansible.com/ansible/latest/collections/ansible/builtin/dnf_module.html
- `ansible.builtin.get_url`
  - https://docs.ansible.com/ansible/latest/collections/ansible/builtin/get_url_module.html
- `ansible.builtin.file`
  - https://docs.ansible.com/ansible/latest/collections/ansible/builtin/file_module.html
- `ansible.builtin.copy`
  - https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html
- `ansible.builtin.template`
  - https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html
- `ansible.builtin.lineinfile`
  - https://docs.ansible.com/ansible/latest/collections/ansible/builtin/lineinfile_module.html
- `ansible.builtin.user`
  - https://docs.ansible.com/ansible/latest/collections/ansible/builtin/user_module.html
- `ansible.builtin.pause`
  - https://docs.ansible.com/ansible/latest/collections/ansible/builtin/pause_module.html
- `ansible.builtin.command`
  - https://docs.ansible.com/ansible/latest/collections/ansible/builtin/command_module.html
- `ansible.builtin.shell`
  - https://docs.ansible.com/ansible/latest/collections/ansible/builtin/shell_module.html
