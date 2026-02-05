---
name: add-package-manager
description: "Add a new package manager to this repo's setup flow. Use when asked to install or configure a package manager (nvm, uv, bun, etc.) and to update setup, tests, and README with proper guards and reminders."
---

# Add Package Manager

## Workflow
1. Read the full contents of `scripts/setup.sh`, `tests/assert.sh`, and `README.md` before editing.
2. Determine the official install method and any platform constraints.
3. Implement an idempotent install in `scripts/setup.sh` using existing helpers; avoid modifying shell configs without approval.
4. Add a validation check in `tests/assert.sh` that mirrors setup guards and verifies the manager is available.
5. Update `README.md` (What It Does + Installed Packages) to document the manager and any manual follow-ups.
6. If environment changes are required (PATH, profile), add a reminder instead of editing user configs.

## Notes
- Keep the setup non-interactive.
- Prefer official installers and pinned versions only if already standard in the repo.
