param(
    [int]$Port = $(if ($env:WB_ORCH_PORT) { [int]$env:WB_ORCH_PORT } else { 8001 }),
    [string]$HostName = '127.0.0.1',
    [string]$DbPath = ''
)

. "$PSScriptRoot\common.ps1"

$orchDir = Resolve-WorldPath 'orchestrator'
$serverPath = Join-Path $orchDir 'server.py'
if (-not (Test-Path -LiteralPath $serverPath)) {
    Write-Fail "orchestrator\\server.py missing."
    exit 1
}

$args = @($serverPath, '--host', $HostName, '--port', "$Port")
if ($DbPath) {
    $args += @('--db', $DbPath)
}

Write-Step "Start orchestrator"
Write-Host "Open: http://$HostName`:$Port/health"
Push-Location $orchDir
try {
    python @args
}
finally {
    Pop-Location
}
