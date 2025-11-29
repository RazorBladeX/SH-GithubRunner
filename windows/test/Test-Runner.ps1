Param()

$ErrorActionPreference = 'Stop'
$runnerRoot = if ($env:RUNNER_ROOT) { $env:RUNNER_ROOT } else { 'C:\actions-runner' }
$fakeUrl = if ($env:FAKE_RUNNER_URL) { $env:FAKE_RUNNER_URL } else { 'https://github.invalid/acme/repo' }
$fakeToken = if ($env:FAKE_RUNNER_TOKEN) { $env:FAKE_RUNNER_TOKEN } else { 'FAKE_TOKEN_000000' }

Write-Host 'Attempting ephemeral configuration with fake token (expected failure)'
Push-Location $runnerRoot
New-Item -ItemType Directory -Path C:\tmp -Force | Out-Null
try {
    & .\config.cmd --url $fakeUrl --token $fakeToken --name test-win --work _work --runnergroup Default --ephemeral --unattended --replace *> C:\tmp\config.log
    $rc = $LASTEXITCODE
    if ($rc -eq 0) {
        throw 'Configuration unexpectedly succeeded'
    }
    else {
        Write-Host "Config exited with $rc as expected"
    }
}
finally {
    Remove-Item -Path (Join-Path $runnerRoot '.runner') -Force -ErrorAction SilentlyContinue
    Remove-Item -Path C:\tmp\config.log -Force -ErrorAction SilentlyContinue
    Pop-Location
}

Write-Host 'Simulating hello-world workflow run'
$temp = Join-Path $env:TEMP ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
    git clone https://github.com/octocat/Hello-World.git (Join-Path $temp 'repo') *> $null
}
catch {
    Write-Warning $_
}
$repoPath = Join-Path $temp 'repo'
$helloScript = Join-Path $repoPath 'hello.ps1'
if (-not (Test-Path $helloScript)) {
    New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
    Set-Content -Path $helloScript -Value "Write-Output 'hello-world from golden windows runner'"
}
try {
    & $helloScript | Tee-Object -FilePath (Join-Path $temp 'hello.log')
    Select-String -Path (Join-Path $temp 'hello.log') -Pattern 'hello-world'
}
finally {
    Remove-Item -Path $temp -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host 'Synthetic workflow completed'
