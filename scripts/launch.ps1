param(
    [string]$ModelPath = $env:WB_MODEL_PATH,
    [int]$KoboldPort = $(if ($env:WB_KOBOLD_PORT) { [int]$env:WB_KOBOLD_PORT } else { 5001 }),
    [int]$SillyPort = $(if ($env:WB_SILLY_PORT) { [int]$env:WB_SILLY_PORT } else { 8000 }),
    [int]$OrchestratorPort = $(if ($env:WB_ORCH_PORT) { [int]$env:WB_ORCH_PORT } else { 8001 }),
    [switch]$SkipChecks,
    [switch]$NoVulkan
)

. "$PSScriptRoot\common.ps1"

$koboldDir = Resolve-WorldPath 'apps\KoboldCpp'
$sillyDir = Resolve-WorldPath 'apps\SillyTavern'
$orchDir = Resolve-WorldPath 'orchestrator'
$logDir = Resolve-WorldPath 'logs'

if (-not $SkipChecks) {
    Write-Step "Check launch ports"
    foreach ($port in @($KoboldPort, $SillyPort, $OrchestratorPort)) {
        if (Test-PortFree $port) {
            Write-Ok "Port $port free"
        }
        else {
            Write-Fail "Port $port busy. Stop process or set WB_KOBOLD_PORT/WB_SILLY_PORT/WB_ORCH_PORT."
            exit 1
        }
    }
}

if (-not $ModelPath) {
    $modelDir = Resolve-WorldPath 'models\llm'
    $model = Get-ChildItem -LiteralPath $modelDir -Filter '*.gguf' -File -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending |
        Select-Object -First 1
    if ($model) {
        $ModelPath = $model.FullName
    }
}

if (-not $ModelPath -or -not (Test-Path -LiteralPath $ModelPath)) {
    Write-Fail "No GGUF model found. Run scripts\\models.ps1 or set WB_MODEL_PATH."
    exit 1
}

Write-Step "Launch KoboldCpp"
$koboldExe = Get-FirstExistingPath @(
    (Join-Path $koboldDir 'koboldcpp.exe'),
    (Join-Path $koboldDir 'koboldcpp_cu12.exe'),
    (Join-Path $koboldDir 'koboldcpp_rocm.exe'),
    (Join-Path $koboldDir 'koboldcpp_vulkan.exe')
)

if (-not $koboldExe) {
    Write-Fail "KoboldCpp exe missing in $koboldDir. Place Windows KoboldCpp build there."
    exit 1
}

$koboldArgs = @(
    '--model', $ModelPath,
    '--port', "$KoboldPort",
    '--host', '127.0.0.1'
)

if (-not $NoVulkan) {
    $koboldArgs += @('--usevulkan')
}

$kobold = Start-LoggedProcess `
    -Name 'KoboldCpp' `
    -FilePath $koboldExe `
    -ArgumentList $koboldArgs `
    -WorkingDirectory $koboldDir `
    -LogPath (Join-Path $logDir 'koboldcpp.log')

Write-Step "Launch SillyTavern"
if (-not (Test-Path -LiteralPath $sillyDir)) {
    Write-Fail "SillyTavern dir missing: $sillyDir"
    exit 1
}

$sillyStart = Get-FirstExistingPath @(
    (Join-Path $sillyDir 'Start.bat'),
    (Join-Path $sillyDir 'start.bat')
)

if ($sillyStart) {
    $silly = Start-LoggedProcess `
        -Name 'SillyTavern' `
        -FilePath $sillyStart `
        -WorkingDirectory $sillyDir `
        -LogPath (Join-Path $logDir 'sillytavern.log')
}
elseif (Test-Path -LiteralPath (Join-Path $sillyDir 'package.json')) {
    $silly = Start-LoggedProcess `
        -Name 'SillyTavern' `
        -FilePath 'cmd.exe' `
        -ArgumentList @('/c', 'npm', 'start') `
        -WorkingDirectory $sillyDir `
        -LogPath (Join-Path $logDir 'sillytavern.log')
}
else {
    Write-Warn "SillyTavern not installed or no Start.bat/package.json found in $sillyDir."
}

Write-Step "Launch orchestrator"
if (Test-Path -LiteralPath (Join-Path $orchDir 'server.py')) {
    $orch = Start-LoggedProcess `
        -Name 'Orchestrator' `
        -FilePath 'python' `
        -ArgumentList @('server.py', '--host', '127.0.0.1', '--port', "$OrchestratorPort") `
        -WorkingDirectory $orchDir `
        -LogPath (Join-Path $logDir 'orchestrator.log')
}
else {
    Write-Warn "No orchestrator\\server.py found in $orchDir."
}

Write-Step "Launch result"
Write-Ok "KoboldCpp: http://127.0.0.1:$KoboldPort"
Write-Ok "SillyTavern expected: http://127.0.0.1:$SillyPort"
Write-Ok "Orchestrator expected: http://127.0.0.1:$OrchestratorPort"
Write-Host "Logs: $logDir"
Write-Host "PIDs started this run:"
foreach ($proc in @($kobold, $silly, $orch)) {
    if ($proc) {
        Write-Host "  $($proc.ProcessName) pid=$($proc.Id)"
    }
}
