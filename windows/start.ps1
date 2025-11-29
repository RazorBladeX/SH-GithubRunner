Param()

$ErrorActionPreference = 'Stop'
$runnerRoot = $env:RUNNER_ROOT
if (-not $runnerRoot) { $runnerRoot = 'C:\actions-runner' }
$runnerName = if ($env:RUNNER_NAME) { $env:RUNNER_NAME } else { "win-runner-$($env:COMPUTERNAME)" }
$runnerLabels = if ($env:RUNNER_LABELS) { $env:RUNNER_LABELS } else { 'self-hosted,windows,x64,golden' }
$runnerGroup = if ($env:RUNNER_GROUP) { $env:RUNNER_GROUP } else { 'Default' }
$runnerWork = if ($env:RUNNER_WORK_DIRECTORY) { $env:RUNNER_WORK_DIRECTORY } else { '_work' }
$runnerUrl = $env:GITHUB_URL
$runnerToken = $env:RUNNER_TOKEN
$runnerScope = if ($env:RUNNER_SCOPE) { $env:RUNNER_SCOPE } else { 'repo' }
$ephemeral = if ($env:RUNNER_EPHEMERAL) { $env:RUNNER_EPHEMERAL } else { 'true' }

if (-not $runnerUrl -or -not $runnerToken) {
    throw 'GITHUB_URL and RUNNER_TOKEN environment variables must be provided.'
}

$logRoot = if ($env:RUNNER_LOG_ROOT) { $env:RUNNER_LOG_ROOT } else { 'C:\logs' }
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$logFile = Join-Path $logRoot 'runner.log'
Start-Transcript -Path $logFile -Append | Out-Null

function Test-IsTrue($value) {
    return ($value -match '^(?i:true|1|yes)$')
}

function Invoke-WithRetry([scriptblock]$Script, [int]$RetryCount = 5, [int]$DelaySeconds = 10) {
    for ($i = 1; $i -le $RetryCount; $i++) {
        try {
            & $Script
            return
        }
        catch {
            Write-Warning "Attempt $i failed: $($_.Exception.Message)"
            if ($i -ge $RetryCount) { throw }
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Configure-Runner {
    if (Test-Path (Join-Path $runnerRoot '.runner')) {
        Write-Host '[runner] Runner already configured.'
        return
    }

    $configArgs = @('--unattended', '--url', $runnerUrl, '--token', $runnerToken, '--name', $runnerName, '--work', $runnerWork, '--labels', $runnerLabels, '--replace')
    if ($runnerScope -and ($runnerScope.ToLower() -eq 'org')) {
        $configArgs += @('--runnergroup', $runnerGroup)
    }
    if (Test-IsTrue $ephemeral) {
        $configArgs += '--ephemeral'
    }

    Invoke-WithRetry {
        Push-Location $runnerRoot
        try {
            & .\config.cmd @configArgs
        }
        finally {
            Pop-Location
        }
    } 5 15
}

function Cleanup-Runner {
    if (Test-Path (Join-Path $runnerRoot '.runner')) {
        Write-Host '[runner] Removing registration'
        try {
            Push-Location $runnerRoot
            & .\config.cmd remove --token $runnerToken --unattended | Write-Host
        }
        catch {
            Write-Warning "Failed to remove runner: $($_.Exception.Message)"
        }
        finally {
            Pop-Location
        }
    }
}

try {
    Configure-Runner
    Push-Location $runnerRoot
    & .\run.cmd
    $exitCode = $LASTEXITCODE
    Pop-Location
    exit $exitCode
}
finally {
    Cleanup-Runner
    Stop-Transcript | Out-Null
}
