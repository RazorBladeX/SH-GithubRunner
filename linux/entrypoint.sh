#!/usr/bin/env bash
set -euo pipefail

RUNNER_HOME=${RUNNER_HOME:-/opt/actions-runner}
RUNNER_NAME=${RUNNER_NAME:-runner-$(hostname)}
RUNNER_LABELS=${RUNNER_LABELS:-self-hosted,linux,x64,golden}
RUNNER_GROUP=${RUNNER_GROUP:-Default}
RUNNER_WORK_DIRECTORY=${RUNNER_WORK_DIRECTORY:-_work}
RUNNER_EPHEMERAL=${RUNNER_EPHEMERAL:-true}
RUNNER_SCOPE=${RUNNER_SCOPE:-repo}
GITHUB_URL=${GITHUB_URL:-}
RUNNER_TOKEN=${RUNNER_TOKEN:-}
child_pid=0

if [[ -z "${GITHUB_URL}" || -z "${RUNNER_TOKEN}" ]]; then
  echo "GITHUB_URL and RUNNER_TOKEN environment variables are required" >&2
  exit 1
fi

cd "${RUNNER_HOME}"

cleanup() {
  echo "[entrypoint] Cleanup triggered" >&2
  if [[ -f .runner ]]; then
    ./config.sh remove --unattended --token "${RUNNER_TOKEN}" || true
  fi
}

trap 'cleanup' EXIT

configure_runner() {
  if [[ ! -f .runner ]]; then
    local args=(
      --unattended
      --url "${GITHUB_URL}"
      --token "${RUNNER_TOKEN}"
      --name "${RUNNER_NAME}"
      --work "${RUNNER_WORK_DIRECTORY}"
      --labels "${RUNNER_LABELS}"
      --replace
    )
    if [[ "${RUNNER_SCOPE,,}" == "org" ]]; then
      args+=("--runnergroup" "${RUNNER_GROUP}")
    fi
    if [[ "${RUNNER_EPHEMERAL,,}" == "true" ]]; then
      args+=("--ephemeral")
    fi
    ./config.sh "${args[@]}"
  fi
}

configure_runner

run_runner() {
  echo "[entrypoint] Starting runner agent"
  ./run.sh "$@" &
  child_pid=$!
  wait "$child_pid"
}

term_handler() {
  echo "[entrypoint] SIGTERM received" >&2
  if [[ $child_pid -ne 0 ]]; then
    kill -TERM "$child_pid" 2>/dev/null || true
  fi
}

trap term_handler SIGTERM SIGINT

run_runner "$@"
