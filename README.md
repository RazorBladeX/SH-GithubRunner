# golden-runners

Enterprise-grade GitHub Actions self-hosted runner images (Linux + Windows) built as golden container bases with automated security, compliance, and delivery pipelines.

## Why this repo exists

- **Immutable, minimal, and fast** images based on `ubuntu:22.04` and `mcr.microsoft.com/windows/servercore:ltsc2022`, held under 1.8 GB compressed.
- **Pinned dependencies** for every tool and runner component with sha256 verification and continuous CVE scanning.
- **Batteries included**: Docker CLI 27 + Buildx + Compose V2, git, curl, jq, and nerdctl + containerd (Windows) — everything else (Node, Python, Terraform, etc.) is layered later per environment.
- **Strict CI/CD gates**: Hadolint, Trivy (fail on CRITICAL/HIGH), runtime smoke tests, and manual approval before costly Windows pushes.
- **Deterministic publishing**: Only pushes on `main` merges or the nightly rebuild workflow, tagged with `:latest` and immutable `:YYYYMMDD`.

```
.golden-runners/
├── .github/workflows        # CI + governance automation
├── linux                    # Ubuntu runner definition, scripts, tests
├── windows                  # Windows runner definition, scripts, tests
├── terraform/.gitkeep       # Placeholder for future infra modules (Dependabot scope)
├── .dockerignore
├── .hadolint.yaml
└── README.md
```

## Image contents

| Capability | Linux | Windows |
|------------|-------|---------|
| Base image | `ubuntu:22.04` | `mcr.microsoft.com/windows/servercore:ltsc2022` |
| Runner | `actions/runner@2.330.0` pinned w/ sha256 | Same |
| Container runtime | Docker CLI 27.1.1 + Buildx 0.15, Compose v2.29 | containerd 1.7.15 + nerdctl 2.0.0 + Docker CLI 27.1.1 |
| Base tools | Git, curl, jq, Docker CLI 27.1.1 + Buildx 0.15 + Compose v2.29 | Git, Docker CLI 27.1.1 + containerd 1.7.15 + nerdctl 2.0.0 |
| Security | Non-root `runner` user, HEALTHCHECK (curl + runner process), curated `/etc/sudoers` free | Transcript logging, retryable config, graceful cleanup |
| Tests | `/opt/tests/test_tools.sh`, `/opt/tests/test_runner.sh` | `C:\tests\Test-Tools.ps1`, `C:\tests\Test-Runner.ps1` |

> Need Terraform, Node, Python, or other language stacks? Build a layered image or run provisioning tasks that install those per-project — this base intentionally stays lean so each workload can pin its own versions.

## Building locally

```powershell
# Linux
cd .golden-runners
REGISTRY=ghcr.io/$(gh repo view --json owner --jq '.owner.login')
docker build -f linux/Dockerfile -t $REGISTRY/runner-linux:dev .

# Windows (PowerShell)
docker build -f windows/Dockerfile -t $Env:REGISTRY/runner-windows:dev .
```

Run the embedded tests before publishing:

```bash
docker run --rm --entrypoint /bin/bash ghcr.io/your-org/runner-linux:dev /opt/tests/test_tools.sh
docker run --rm --entrypoint /bin/bash ghcr.io/your-org/runner-linux:dev /opt/tests/test_runner.sh
```

```powershell
docker run --rm --entrypoint pwsh ghcr.io/your-org/runner-windows:dev -File C:\tests\Test-Tools.ps1
docker run --rm --entrypoint pwsh ghcr.io/your-org/runner-windows:dev -File C:\tests\Test-Runner.ps1
```

## CI/CD pipelines (.1 workflows)

1. **`ci-linux.yml`** – build → tests → hadolint → Trivy → conditional push.
2. **`ci-windows.yml`** – same flow, but pushes only after an environment approval (`windows-production`). Artifacts (`docker save`) keep layers immutable across the approval gate.
3. **`nightly-rebuild.yml`** – triggers both CI workflows via `workflow_call` every night (02:00 UTC) or on-demand.
4. **`cleanup-old-images.yml`** – prunes GHCR tags older than 30 days while retaining `latest` + recent date tags.
5. **`dependabot.yml`** – weekly refresh for Actions, Dockerfiles, and Terraform modules.

> **Push guarantees** – images publish only when `(event == push && branch == main)` or when the nightly workflow passes. All other invocations (PRs, manual dry-runs) stop before the registry push step.

## Registering the runners (one-liners)

> Use short-lived registration tokens via PAT or OIDC. The examples below use `gh api` with the default `GITHUB_TOKEN` context.

### Linux

```bash
TOKEN=$(gh api -X POST repos/<org>/<repo>/actions/runners/registration-token --jq .token)
docker run -d --restart always \
  -e GITHUB_URL=https://github.com/<org>/<repo> \
  -e RUNNER_TOKEN=${TOKEN} \
  -e RUNNER_NAME=linux-golden-$(hostname) \
  -e RUNNER_LABELS=self-hosted,linux,x64,golden \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/<org>/runner-linux:latest
```

### Windows

```powershell
$token = gh api -Method POST repos/<org>/<repo>/actions/runners/registration-token --jq '.token'
docker run -d --isolation=process `
  -e GITHUB_URL=https://github.com/<org>/<repo> `
  -e RUNNER_TOKEN=$token `
  -e RUNNER_LABELS='self-hosted,windows,x64,golden' `
  ghcr.io/<org>/runner-windows:latest
```

Both images default to **ephemeral mode** (`RUNNER_EPHEMERAL=true`), so every job auto-deregisters after completion. Override with `-e RUNNER_EPHEMERAL=false` for sticky runners (not recommended).

## Workflow usage snippet

```yaml
name: build-and-test

on: [push]

jobs:
  linux-job:
    runs-on: [self-hosted, linux-arm64]   # replace with the labels you assign (e.g., self-hosted,linux,x64,golden)
    steps:
      - uses: actions/checkout@v4
      - run: make test

  windows-job:
    runs-on: [self-hosted, windows]
    steps:
      - uses: actions/checkout@v4
      - run: .\build.ps1
```

## Ephemeral runners & auto-scaling

1. **Ephemeral mode** is default. Each container self-configures (`config.sh/config.cmd --ephemeral --replace`) and auto-removes on exit.
2. **Scale sets / controllers** – pair these images with orchestrators such as:
   - [actions-runner-controller](https://github.com/actions/actions-runner-controller) (Kubernetes) + Horizontal Pod Autoscaler.
   - Azure Container Apps / AWS Fargate scheduled jobs that call our `ci-*` workflows to bake and roll image updates.
3. **Autoscaling inputs** – feed workload metrics into your platform (KEDA ScaledObjects, Azure Scale Rules, etc.) to start containers with `RUNNER_TOKEN` issued by a lightweight provisioning service (use GitHub OIDC to mint tokens).

## Rotating images weekly

- Nightly rebuilds already emit fresh `:YYYYMMDD` tags. Adopt a **weekly rotation** by:
  1. Updating your orchestrator to use the newest date tag each Monday (e.g., `kubectl set image ... runner-linux=ghcr.io/<org>/runner-linux:$(date +%Y%m%d)`).
  2. Optionally create a scheduled job that queries GHCR for the latest tag and patches your deployment automatically.
- Always keep `:latest` pointing to the most recent verified build; the CI workflows handle this automatically after all gates pass (and, for Windows, once the environment approval is granted).

## Health + troubleshooting

- **Healthchecks**: Linux container executes `curl https://github.com/_ping && pgrep Runner.Listener`; Windows uses `Invoke-WebRequest` + `Get-Process Runner.Listener`.
- **Logs**: Linux outputs to STDOUT; Windows mirrors to `C:\logs\runner.log` via PowerShell transcripts.
- **Signals**: `entrypoint.sh` and `start.ps1` trap `SIGTERM`/Ctrl+C, unregistering the runner before exit.

## Next steps

1. Configure the `windows-production` environment in your repo settings with the required approvers.
2. Store any optional registry overrides (`REGISTRY`, `IMAGE_REPOSITORY`) as organization secrets if you mirror to multiple tenants.
3. Hook the `nightly-rebuild` workflow into whatever paging/on-call rotation monitors CVE drift.

Happy shipping! 🎯
