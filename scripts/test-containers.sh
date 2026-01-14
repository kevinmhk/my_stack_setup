#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${LOG_DIR:-${REPO_ROOT}/logs}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

abort() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    abort "Docker is not installed. Install Docker Desktop and retry."
  fi

  if ! docker info >/dev/null 2>&1; then
    abort "Docker daemon is not running. Start Docker Desktop and retry."
  fi
}

run_image() {
  local name="$1"
  local dockerfile="$2"
  local logfile="${LOG_DIR}/test_${name}.log"

  log "Building ${name} image..."
  docker build -f "$dockerfile" -t "my_stack_setup_${name}" "$REPO_ROOT"

  log "Running ${name} container test..."
  mkdir -p "$LOG_DIR"
  docker run --rm "my_stack_setup_${name}" | tee "$logfile"
  log "Wrote ${name} logs to ${logfile}"
}

main() {
  require_docker

  run_image "ubuntu" "${REPO_ROOT}/tests/docker/ubuntu/Dockerfile"
  run_image "centos" "${REPO_ROOT}/tests/docker/centos/Dockerfile"

  log "Container tests completed."
}

main "$@"
