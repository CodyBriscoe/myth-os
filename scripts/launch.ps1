param(
    [string]$ModelPath = $env:WB_MODEL_PATH,
    [int]$KoboldPort = $(if ($env:WB_KOBOLD_PORT) { [int]$env:WB_KOBOLD_PORT } else { 5001 }),
    [int]$SillyPort = $(if ($env:WB_SILLY_PORT) { [int]$env:WB_SILLY_PORT } else { 8000 }),
    [int]$OrchestratorPort = $(if ($env:WB_ORCH_PORT) { [int]$env:WB_ORCH_PORT } else { 8001 }),
    [switch]$SkipChecks,
    [switch]$NoVulkan,
    [ValidateSet('auto', 'vulkan', 'cuda', 'rocm', 'cpu')]
    [string]$KoboldFlavor = $(if ($env:WB_KOBOLDCPP_FLAVOR) { $env:WB_KOBOLDCPP_FLAVOR } else { 'auto' }),
    [int]$ReadyTimeoutSeconds = 90
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
    $model = Get-ModelCandidate -ModelDir $modelDir
    if ($model) {
        $ModelPath = $model.FullName
    }
}

$modelInfo = Get-ModelCandidate -ModelPath $ModelPath
if (-not $modelInfo) {
    Write-Fail "No usable GGUF model found. Ignores .partial and files under 1 MB. Run scripts\\models.ps1 or set WB_MODEL_PATH."
    exit 1
}
$ModelPath = $modelInfo.FullName
Write-Ok "Model: $ModelPath ($([math]::Round($modelInfo.Length / 1GB, 2)) GB)"

Write-Step "Launch KoboldCpp"
$koboldExe = Get-KoboldCppExecutable -KoboldDir $koboldDir -Flavor $KoboldFlavor

if (-not $koboldExe) {
    Write-KoboldCppSelectionHelp -KoboldDir $koboldDir -Flavor $KoboldFlavor
    Write-Fail "KoboldCpp exe missing or too small in $koboldDir. Place Windows KoboldCpp build there."
    exit 1
}
Write-KoboldCppSelectionHelp -KoboldDir $koboldDir -Flavor $KoboldFlavor
Write-Ok "KoboldCpp exe: $($koboldExe.FullName)"

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
    -FilePath $koboldExe.FullName `
    -ArgumentList $koboldArgs `
    -WorkingDirectory $koboldDir `
    -LogPath (Join-Path $logDir 'koboldcpp.log')

Write-Step "Launch SillyTavern"
if (-not (Test-Path -LiteralPath $sillyDir)) {
    Write-Fail "SillyTavern dir missing: $sillyDir"
    exit 1
}

$sillyCommand = Get-SillyTavernLaunchCommand -SillyDir $sillyDir
if ($sillyCommand) {
    Write-Ok "SillyTavern launch: $($sillyCommand.Label)"
    $silly = Start-LoggedProcess `
        -Name 'SillyTavern' `
        -FilePath $sillyCommand.FilePath `
        -ArgumentList $sillyCommand.ArgumentList `
        -WorkingDirectory $sillyDir `
        -LogPath (Join-Path $logDir 'sillytavern.log')
}
else {
    Write-Warn "SillyTavern not installed or no node_modules/server.js, Start.bat, or package.json found in $sillyDir."
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

if (-not $SkipChecks) {
    Write-Step "Wait for readiness"
    Wait-HttpReady -Name 'KoboldCpp' -Url "http://127.0.0.1:$KoboldPort" -TimeoutSeconds $ReadyTimeoutSeconds | Out-Null
    if ($silly) {
        Wait-HttpReady -Name 'SillyTavern' -Url "http://127.0.0.1:$SillyPort" -TimeoutSeconds $ReadyTimeoutSeconds | Out-Null
    }
    if ($orch) {
        Wait-HttpReady -Name 'Orchestrator' -Url "http://127.0.0.1:$OrchestratorPort/health" -TimeoutSeconds $ReadyTimeoutSeconds | Out-Null
    }
}
