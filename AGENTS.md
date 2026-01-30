# Repository Guidelines

## Project Structure & Module Organization
- `scripts/` holds automation entrypoints: `setup.sh` (main installer), `install-gemini-extensions.sh`, and `test-containers.sh` (Docker-based tests).
- `tests/` contains validation tooling. `assert.sh` is the primary post-setup check; Dockerfiles live in `tests/docker/ubuntu` and `tests/docker/centos`.
- `logs/` is generated at runtime for setup and test runs.
- `README.md` documents usage and installed packages.

## Build, Test, and Development Commands
- `scripts/setup.sh`: non-interactive bootstrap for macOS/Linux (Homebrew, npm globals, chezmoi, tooling). Writes a timestamped log in `logs/`.
- `tests/assert.sh`: verifies expected tools, directories, and configs. Fails with a summary log in `logs/`.
- `scripts/test-containers.sh ubuntu|centos|--all`: builds and runs container tests; outputs per-container logs in `logs/`. Requires Docker Desktop running.

## Coding Style & Naming Conventions
- Shell scripts use `bash` with `set -euo pipefail` and `log`/`run` helpers for traceability.
- Indentation is two spaces; functions use `lower_snake_case`.
- Prefer explicit command checks via `command -v` and guard platform-specific logic (`Darwin` vs `Linux`).

## Testing Guidelines
- Primary test: `tests/assert.sh` (no external framework). It collects all failures and exits non-zero if any.
- Container tests validate end-to-end install flows on Ubuntu and CentOS via Dockerfiles in `tests/docker/`.

## Commit & Pull Request Guidelines
- Commits follow Conventional Commits (e.g., `feat:`, `fix:`, `docs:`) with multi-line messages when needed.
- PRs should include a short summary, testing performed (command + outcome), and mention any platform-specific impacts.

## Security & Configuration Notes
- Logs may contain environment-sensitive paths; avoid committing files under `logs/`.
- The setup script is non-interactive and designed to be re-run safely; keep changes idempotent.
