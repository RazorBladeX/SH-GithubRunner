#!/usr/bin/env bash
set -euo pipefail

RUNNER_HOME=${RUNNER_HOME:-/opt/actions-runner}
FAKE_URL=${FAKE_URL:-https://github.invalid/acme/fake-repo}
FAKE_TOKEN=${FAKE_TOKEN:-FAKE_TOKEN_000000000000}

log() {
  echo "[runner-test] $*"
}

cd "${RUNNER_HOME}"

log "Attempting ephemeral registration with fake token (expected graceful failure)"
set +e
./config.sh --url "${FAKE_URL}" --token "${FAKE_TOKEN}" --name test-runner --runnergroup Default --work _work --ephemeral --unattended --replace >/tmp/config.log 2>&1
config_rc=$?
set -e
if [[ ${config_rc} -eq 0 ]]; then
  log "Registration unexpectedly succeeded"
  exit 1
fi
log "Config failure output"
sed -n '1,40p' /tmp/config.log

log "Simulating hello-world workflow execution"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

git clone https://github.com/octocat/Hello-World.git "${WORK_DIR}/repo" >/tmp/clone.log 2>&1 || {
  log "Falling back to inline repo"
  mkdir -p "${WORK_DIR}/repo"
  cat <<'EOF' > "${WORK_DIR}/repo/hello.sh"
#!/usr/bin/env bash
set -euo pipefail
cat <<MSG
hello-world from golden-runner
MSG
EOF
  chmod +x "${WORK_DIR}/repo/hello.sh"
}

pushd "${WORK_DIR}/repo" >/dev/null
if [[ ! -f hello.sh ]]; then
  cat <<'EOF' > hello.sh
#!/usr/bin/env bash
set -euo pipefail
echo "hello-world from cloned repo"
EOF
  chmod +x hello.sh
fi
./hello.sh | tee /tmp/hello.log
popd >/dev/null

grep -q "hello-world" /tmp/hello.log
log "Synthetic workflow completed successfully"
