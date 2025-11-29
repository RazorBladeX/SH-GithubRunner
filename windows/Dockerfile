# escape=`
ARG BASE_IMAGE=mcr.microsoft.com/windows/servercore:ltsc2022

FROM ${BASE_IMAGE} AS runner-download
SHELL ["powershell","-Command"]
ARG RUNNER_VERSION=2.323.0
RUN $ErrorActionPreference = 'Stop'; `
    Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$env:RUNNER_VERSION/actions-runner-win-x64-$env:RUNNER_VERSION.zip" -OutFile C:\runner.zip; `
    Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$env:RUNNER_VERSION/actions-runner-win-x64-$env:RUNNER_VERSION.zip.sha256" -OutFile C:\runner.zip.sha256; `
    $expected = ((Get-Content C:\runner.zip.sha256) -split ' ')[0].ToUpper(); `
    $actual = (Get-FileHash C:\runner.zip -Algorithm SHA256).Hash.ToUpper(); `
    if ($expected -ne $actual) { throw 'Runner checksum mismatch'; }; `
    Expand-Archive -Path C:\runner.zip -DestinationPath C:\actions-runner

FROM ${BASE_IMAGE}
SHELL ["powershell","-Command"]
ARG RUNNER_VERSION=2.323.0
ENV RUNNER_ROOT="C:\actions-runner" `
    CONTAINERD_VERSION="1.7.15" `
    NERDCTL_VERSION="2.0.0" `
    DOCKER_VERSION="27.1.1" `
    chocolateyUseWindowsCompression="false"

COPY --from=runner-download C:\actions-runner ${RUNNER_ROOT}
COPY windows/chocolatey-packages.list C:\install\chocolatey-packages.list
COPY windows/start.ps1 C:\start.ps1
COPY windows/test C:\tests

RUN Set-ExecutionPolicy Bypass -Scope Process -Force; `
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; `
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

RUN $ErrorActionPreference = 'Stop'; `
    $packages = Get-Content C:\install\chocolatey-packages.list | Where-Object { $_ -and -not $_.StartsWith('#') }; `
    foreach ($line in $packages) { `
        $parts = $line.Split('|'); `
        $name = $parts[0]; `
        $version = $parts[1]; `
        choco install $name --version $version -y --no-progress; `
    }; `
    choco clean --yes

RUN $ErrorActionPreference = 'Stop'; `
    New-Item -ItemType Directory -Path C:\containerd -Force | Out-Null; `
    $containerdUrl = "https://github.com/containerd/containerd/releases/download/v$env:CONTAINERD_VERSION/containerd-$env:CONTAINERD_VERSION-windows-amd64.tar.gz"; `
    Invoke-WebRequest -Uri $containerdUrl -OutFile C:\containerd.tar.gz; `
    tar -xzf C:\containerd.tar.gz -C C:\containerd --strip-components=1; `
    Remove-Item C:\containerd.tar.gz; `
    New-Item -ItemType Directory -Path C:\nerdctl -Force | Out-Null; `
    $nerdctlUrl = "https://github.com/containerd/nerdctl/releases/download/v$env:NERDCTL_VERSION/nerdctl-$env:NERDCTL_VERSION-windows-amd64.zip"; `
    Invoke-WebRequest -Uri $nerdctlUrl -OutFile C:\nerdctl.zip; `
    Expand-Archive -Path C:\nerdctl.zip -DestinationPath C:\nerdctl -Force; `
    Remove-Item C:\nerdctl.zip; `
    $dockerUrl = "https://download.docker.com/win/static/stable/x86_64/docker-$env:DOCKER_VERSION.zip"; `
    Invoke-WebRequest -Uri $dockerUrl -OutFile C:\docker.zip; `
    Expand-Archive -Path C:\docker.zip -DestinationPath C:\docker -Force; `
    Remove-Item C:\docker.zip

RUN New-Item -ItemType Directory -Path C:\logs -Force | Out-Null

ENV PATH="C:\\containerd;C:\\nerdctl;C:\\docker;%PATH%"

WORKDIR ${RUNNER_ROOT}

LABEL org.opencontainers.image.title="golden-runner-windows" `
      org.opencontainers.image.description="Hardened GitHub Actions self-hosted runner image for Windows" `
      org.opencontainers.image.vendor="golden-runners" `
      org.opencontainers.image.source="https://github.com/golden-runners/golden-runners" `
      org.opencontainers.image.licenses="MIT" `
      org.opencontainers.image.version="${RUNNER_VERSION}" `
      org.opencontainers.image.base.name="${BASE_IMAGE}"

HEALTHCHECK --interval=60s --timeout=10s --start-period=90s --retries=3 CMD powershell -Command "try { Invoke-WebRequest -Uri https://github.com/_ping -UseBasicParsing | Out-Null; if (Get-Process -Name 'Runner.Listener' -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 } } catch { exit 1 }"

ENTRYPOINT ["powershell","-File","C:\\start.ps1"]
