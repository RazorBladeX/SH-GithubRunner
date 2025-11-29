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

DOCKER_VERSION="27.1.1"
BUILDX_VERSION="0.15.1"
COMPOSE_VERSION="2.29.7"

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

install_base_packages() {
  retry 5 apt-get update
  retry 3 apt-get install -y --no-install-recommends "${APT_COMMON_PACKAGES[@]}"
}


install_docker_cli() {
  curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" -o /tmp/docker.tgz
  tar -xzf /tmp/docker.tgz -C /tmp
  install -m 0755 /tmp/docker/docker "${INSTALL_DIR}/docker"
  for bin in containerd ctr dockerd docker-init docker-proxy; do
    install -m 0755 "/tmp/docker/${bin}" "${INSTALL_DIR}/${bin}"
  done
  install -m 0755 /tmp/docker/runc "${INSTALL_DIR}/runc"
  curl -fsSL "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-amd64" -o /tmp/docker-buildx
  install -m 0755 /tmp/docker-buildx "${DOCKER_PLUGIN_DIR}/docker-buildx"
  curl -fsSL "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /tmp/docker-compose
  install -m 0755 /tmp/docker-compose "${DOCKER_PLUGIN_DIR}/docker-compose"
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
