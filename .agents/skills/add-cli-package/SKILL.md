---
name: add-cli-package
description: "Add a new CLI/tool package to this repo's setup flow. Use when asked to install a CLI tool or package (brew, npm, uv, apt/yum, etc.) and to update scripts/setup.sh, tests/assert.sh, and README.md."
---

# Add CLI Package

## Workflow
1. Read the full contents of `scripts/setup.sh`, `tests/assert.sh`, and `README.md` before editing.
2. Identify the install mechanism (brew formula/cask, npm global, uv tool, apt/yum, or custom script) and the target platforms.
3. Add idempotent install logic in `scripts/setup.sh` using existing helpers and platform guards.
4. Mirror the same platform guards in `tests/assert.sh` and add a `command -v` check (or version check) for the new tool.
5. Update the relevant package list and description in `README.md`.
6. Keep changes minimal, explicit, and consistent with existing patterns.

## Notes
- Prefer explicit `command -v` checks.
- Do not modify shell configs without approval; add a reminder instead.
- If the tool is platform-specific, guard it with `Darwin` or `Linux` checks in both setup and tests.
