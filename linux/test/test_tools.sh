#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[tools-test] $*"
}

assert_command() {
  local cmd=$1
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Command '$cmd' not found" >&2
    exit 1
  fi
}

log "Validating base toolchain availability"
for tool in docker git curl jq tar unzip; do
  assert_command "$tool"
  "$tool" --version || true
  log "$tool check complete"
done

log "Checking docker CLI plugins"
assert_command docker
"$(command -v docker)" buildx version
"$(command -v docker)" compose version

log "All tool assertions passed"
