Param()

$ErrorActionPreference = 'Stop'

function Assert-Command($name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "Command $name is missing"
    }
}

$tools = @('git', 'nerdctl', 'docker')
foreach ($tool in $tools) {
    Assert-Command $tool
    Write-Host "[$tool] -> $((Invoke-Expression "$tool --version") | Select-Object -First 1)"
}

Write-Host 'Validating nerdctl'
nerdctl --version | Select-String -Pattern '2.0'

Write-Host 'Validating docker CLI'
docker --version | Select-String -Pattern '27.1'

Write-Host 'Tool verification completed successfully'
