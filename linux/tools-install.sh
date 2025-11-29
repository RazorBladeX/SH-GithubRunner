#!/usr/bin/env bash
set -euo pipefail

# Centralized install script for all shared tooling layers
# Expected to run as root during image build time.

export DEBIAN_FRONTEND="noninteractive"

APT_COMMON_PACKAGES=(\
  ca-certificates\
  curl\
  unzip\
  tar\
  jq\
  git\
  gnupg\
  lsb-release\
  software-properties-common\
  apt-transport-https\
  iptables\
  uidmap\
  bash-completion\
  libicu70\
  libssl3\
  procps\
  tini\
  xz-utils\
  wget\
)

# Pinned versions with checksums for supply-chain security
DOCKER_VERSION="27.1.1"
DOCKER_SHA256="4dc5d05efa49254e7ef9c8d00e5ea6a3fcf0e9e52a2478e6da3cb399fade2eb8"
BUILDX_VERSION="0.15.1"
BUILDX_SHA256="8d486f0088b7407a90ad675525ba4a17d0a537741b9b33fe3391a88cafa2dd0b"
COMPOSE_VERSION="2.29.7"
COMPOSE_SHA256="de3a4dd59a5d1e90a11cb2e7b3a90417a34ed39c77af7fc9c24cbce5f7f03196"

INSTALL_DIR="/usr/local/bin"
DOCKER_PLUGIN_DIR="/usr/lib/docker/cli-plugins"
mkdir -p "${DOCKER_PLUGIN_DIR}"

retry() {
  local attempts=$1
  shift
  local delay=5
  for ((i=1; i<=attempts; i++)); do
    if "$@"; then
      return 0
    fi
    echo "Retry $i/$attempts for command '$*' failed. Sleeping ${delay}s" >&2
    sleep "$delay"
  done
  echo "Command '$*' failed after ${attempts} attempts" >&2
  return 1
}

verify_checksum() {
  local file=$1
  local expected_sha256=$2
  local actual_sha256
  actual_sha256=$(sha256sum "$file" | awk '{print $1}')
  if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
    echo "Checksum verification failed for ${file}" >&2
    echo "Expected: ${expected_sha256}" >&2
    echo "Actual:   ${actual_sha256}" >&2
    return 1
  fi
  echo "Checksum verified for ${file}"
}

install_base_packages() {
  retry 5 apt-get update
  retry 3 apt-get install -y --no-install-recommends "${APT_COMMON_PACKAGES[@]}"
}


install_docker_cli() {
  echo "Downloading Docker CLI ${DOCKER_VERSION}..."
  curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" -o /tmp/docker.tgz
  verify_checksum /tmp/docker.tgz "${DOCKER_SHA256}"
  tar -xzf /tmp/docker.tgz -C /tmp
  install -m 0755 /tmp/docker/docker "${INSTALL_DIR}/docker"
  for bin in containerd ctr dockerd docker-init docker-proxy; do
    install -m 0755 "/tmp/docker/${bin}" "${INSTALL_DIR}/${bin}"
  done
  install -m 0755 /tmp/docker/runc "${INSTALL_DIR}/runc"
  rm -rf /tmp/docker.tgz /tmp/docker
  
  echo "Downloading Docker Buildx ${BUILDX_VERSION}..."
  curl -fsSL "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-amd64" -o /tmp/docker-buildx
  verify_checksum /tmp/docker-buildx "${BUILDX_SHA256}"
  install -m 0755 /tmp/docker-buildx "${DOCKER_PLUGIN_DIR}/docker-buildx"
  rm -f /tmp/docker-buildx
  
  echo "Downloading Docker Compose ${COMPOSE_VERSION}..."
  curl -fsSL "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /tmp/docker-compose
  verify_checksum /tmp/docker-compose "${COMPOSE_SHA256}"
  install -m 0755 /tmp/docker-compose "${DOCKER_PLUGIN_DIR}/docker-compose"
  rm -f /tmp/docker-compose
}

finalize() {
  apt-get clean
  rm -rf /var/lib/apt/lists/* /tmp/*
}

main() {
  install_base_packages
  install_docker_cli
  finalize
}

main "$@"
