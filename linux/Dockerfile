# syntax=docker/dockerfile:1.7
ARG UBUNTU_VERSION=22.04

FROM ubuntu:${UBUNTU_VERSION} AS runner-downloader
ARG RUNNER_VERSION=2.323.0
ARG RUNNER_ARCHIVE=actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl jq && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp/runner
RUN curl -fsSLO "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_ARCHIVE}" \
    && curl -fsSLO "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_ARCHIVE}.sha256" \
    && sha256sum -c "${RUNNER_ARCHIVE}.sha256" \
    && tar -xzf "${RUNNER_ARCHIVE}" -C /opt \
    && mv /opt/actions-runner /opt/actions-runner-${RUNNER_VERSION}

FROM ubuntu:${UBUNTU_VERSION}
ARG RUNNER_VERSION=2.323.0
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    RUNNER_HOME=/opt/actions-runner

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY linux/tools-install.sh /tmp/tools-install.sh
RUN chmod +x /tmp/tools-install.sh && /tmp/tools-install.sh && rm /tmp/tools-install.sh

COPY --from=runner-downloader /opt/actions-runner-${RUNNER_VERSION} ${RUNNER_HOME}

RUN cd ${RUNNER_HOME} && ./bin/installdependencies.sh && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 1001 runner \
    && useradd --uid 1001 --gid runner --shell /bin/bash --create-home runner \
    && groupadd --gid 998 docker || true \
    && usermod -aG docker runner \
    && mkdir -p ${RUNNER_HOME} ${RUNNER_HOME}/_work /var/lib/docker \
    && chown -R runner:runner ${RUNNER_HOME} /var/lib/docker

COPY linux/entrypoint.sh /entrypoint.sh
COPY linux/test /opt/tests
RUN chmod +x /entrypoint.sh /opt/tests/*.sh

WORKDIR ${RUNNER_HOME}

LABEL org.opencontainers.image.title="golden-runner-linux" \
      org.opencontainers.image.description="Hardened GitHub Actions self-hosted runner image for Linux" \
      org.opencontainers.image.vendor="golden-runners" \
      org.opencontainers.image.source="https://github.com/golden-runners/golden-runners" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="2.323.0" \
      org.opencontainers.image.base.name="ubuntu:${UBUNTU_VERSION}"

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS https://github.com/_ping >/dev/null && pgrep -f Runner.Listener >/dev/null

USER runner
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD []
