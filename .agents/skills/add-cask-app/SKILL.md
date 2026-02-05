---
name: add-cask-app
description: "Add a macOS Homebrew cask app to this repo's setup flow. Use when asked to install a GUI app via brew cask and to update setup, tests (Darwin only), and README."
---

# Add Cask App

## Workflow
1. Read the full contents of `scripts/setup.sh`, `tests/assert.sh`, and `README.md` before editing.
2. Confirm the cask name and any macOS-only constraints.
3. Add the cask install in `scripts/setup.sh` under the macOS-only cask section.
4. Add a macOS-only verification in `tests/assert.sh` if the app has a reliable CLI or `brew list --cask` check already used in the repo.
5. Update `README.md` to include the cask in the macOS casks list.

## Notes
- Do not add Linux logic for casks.
- Keep verification minimal and consistent with existing checks.
