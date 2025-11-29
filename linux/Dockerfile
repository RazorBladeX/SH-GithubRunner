# syntax=docker/dockerfile:1.7
ARG UBUNTU_VERSION=22.04
ARG RUNNER_VERSION=2.330.0
ARG RUNNER_BASE_IMAGE=ghcr.io/actions/actions-runner:${RUNNER_VERSION}

# hadolint ignore=DL3006
FROM ${RUNNER_BASE_IMAGE} AS runner-source

FROM ubuntu:${UBUNTU_VERSION}
ARG RUNNER_VERSION=2.330.0
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    RUNNER_HOME=/opt/actions-runner

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY linux/tools-install.sh /tmp/tools-install.sh
RUN chmod +x /tmp/tools-install.sh && /tmp/tools-install.sh

COPY --from=runner-source /home/runner ${RUNNER_HOME}

WORKDIR ${RUNNER_HOME}

RUN ./bin/installdependencies.sh && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 1001 runner \
    && useradd --uid 1001 --gid runner --shell /bin/bash --create-home runner \
    && groupadd --gid 998 docker || true \
    && usermod -aG docker runner \
    && mkdir -p ${RUNNER_HOME} ${RUNNER_HOME}/_work /var/lib/docker \
    && chown -R runner:runner ${RUNNER_HOME} /var/lib/docker

COPY linux/entrypoint.sh /entrypoint.sh
COPY linux/test /opt/tests
RUN chmod +x /entrypoint.sh /opt/tests/*.sh

LABEL org.opencontainers.image.title="golden-runner-linux" \
      org.opencontainers.image.description="Hardened GitHub Actions self-hosted runner image for Linux" \
      org.opencontainers.image.vendor="golden-runners" \
      org.opencontainers.image.source="https://github.com/golden-runners/golden-runners" \
      org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.version="${RUNNER_VERSION}" \
      org.opencontainers.image.base.name="ubuntu:${UBUNTU_VERSION}"

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS https://github.com/_ping >/dev/null && pgrep -f Runner.Listener >/dev/null

USER runner
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD []
