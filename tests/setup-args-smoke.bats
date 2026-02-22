#!/usr/bin/env bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SETUP_SCRIPT="${REPO_ROOT}/scripts/setup.sh"

@test "--help prints usage and exits 0" {
  run "$SETUP_SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: scripts/setup.sh"* ]]
}

@test "--non-interactive requires --chezmoi-apply" {
  run "$SETUP_SCRIPT" --non-interactive
  [ "$status" -eq 1 ]
  [[ "$output" == *"--chezmoi-apply=y|n is required when --non-interactive is set."* ]]
}

@test "--chezmoi-apply rejects invalid values in non-interactive mode" {
  run "$SETUP_SCRIPT" --non-interactive --chezmoi-apply=maybe
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid value for --chezmoi-apply: maybe. Use y or n."* ]]
}

@test "--chezmoi-apply is rejected without --non-interactive" {
  run "$SETUP_SCRIPT" --chezmoi-apply=y
  [ "$status" -eq 1 ]
  [[ "$output" == *"--chezmoi-apply is only valid with --non-interactive."* ]]
}
