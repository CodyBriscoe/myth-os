param(
    [int]$Port = $(if ($env:WB_ORCH_PORT) { [int]$env:WB_ORCH_PORT } else { 8001 }),
    [string]$HostName = '127.0.0.1',
    [string]$DbPath = ''
)

. "$PSScriptRoot\common.ps1"

$orchDir = Resolve-WorldPath 'orchestrator'
if (-not (Test-Path -LiteralPath (Join-Path $orchDir 'server.py'))) {
    Write-Fail "orchestrator\\server.py missing."
    exit 1
}

$args = @('server.py', '--host', $HostName, '--port', "$Port")
if ($DbPath) {
    $args += @('--db', $DbPath)
}

Write-Step "Start orchestrator"
Write-Host "Open: http://$HostName`:$Port/health"
python @args
