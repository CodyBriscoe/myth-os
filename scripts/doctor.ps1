param(
    [int]$KoboldPort = $(if ($env:WB_KOBOLD_PORT) { [int]$env:WB_KOBOLD_PORT } else { 5001 }),
    [int]$SillyPort = $(if ($env:WB_SILLY_PORT) { [int]$env:WB_SILLY_PORT } else { 8000 }),
    [int]$OrchestratorPort = $(if ($env:WB_ORCH_PORT) { [int]$env:WB_ORCH_PORT } else { 8001 }),
    [ValidateSet('auto', 'vulkan', 'cuda', 'rocm', 'cpu')]
    [string]$KoboldFlavor = $(if ($env:WB_KOBOLDCPP_FLAVOR) { $env:WB_KOBOLDCPP_FLAVOR } else { 'auto' })
)

. "$PSScriptRoot\common.ps1"

$failures = 0

function Add-DoctorFailure {
    param([Parameter(Mandatory)][string]$Message)
    $script:failures += 1
    Write-Fail $Message
}

$appsDir = Resolve-WorldPath 'apps'
$koboldDir = Resolve-WorldPath 'apps\KoboldCpp'
$sillyDir = Resolve-WorldPath 'apps\SillyTavern'
$modelDir = Resolve-WorldPath 'models\llm'
$orchDir = Resolve-WorldPath 'orchestrator'
$logDir = Resolve-WorldPath 'logs'

Write-Step "Doctor: directories"
foreach ($path in @($appsDir, $koboldDir, $sillyDir, $modelDir, $logDir)) {
    if (Test-Path -LiteralPath $path -PathType Container) {
        Write-Ok "Exists: $path"
    }
    else {
        Add-DoctorFailure "Missing: $path"
    }
}

Write-Step "Doctor: commands"
foreach ($tool in @('git', 'node')) {
    if (Test-Tool $tool) {
        Write-Ok "$tool`: $(Get-ToolVersionLine $tool)"
    }
    else {
        Add-DoctorFailure "$tool missing from PATH"
    }
}

if (Test-Tool 'python') {
    Write-Ok "python: $(Get-ToolVersionLine 'python' @('--version'))"
}
elseif (Test-Tool 'py') {
    Write-Ok "py: $(Get-ToolVersionLine 'py' @('--version'))"
}
else {
    Add-DoctorFailure "python missing from PATH"
}

Write-Step "Doctor: model"
$model = Get-ModelCandidate -ModelDir $modelDir
if ($model) {
    Write-Ok "Usable GGUF: $($model.FullName) ($([math]::Round($model.Length / 1GB, 2)) GB)"
}
else {
    Add-DoctorFailure "No usable .gguf in $modelDir. .partial and files under 1 MB ignored."
}

$partials = Get-ChildItem -LiteralPath $modelDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like '*.partial' }
foreach ($partial in $partials) {
    Write-Warn "Partial download ignored: $($partial.FullName)"
}

Write-Step "Doctor: KoboldCpp"
Write-KoboldCppSelectionHelp -KoboldDir $koboldDir -Flavor $KoboldFlavor
$koboldExe = Get-KoboldCppExecutable -KoboldDir $koboldDir -Flavor $KoboldFlavor
if ($koboldExe) {
    Write-Ok "Selected exe: $($koboldExe.FullName)"
}
else {
    Add-DoctorFailure "No matching KoboldCpp exe found. Use WB_KOBOLDCPP_FLAVOR or WB_KOBOLDCPP_EXE."
}

Write-Step "Doctor: SillyTavern"
if (Test-Path -LiteralPath $sillyDir -PathType Container) {
    $sillyCommand = Get-SillyTavernLaunchCommand -SillyDir $sillyDir
    if ($sillyCommand) {
        Write-Ok "Launch method: $($sillyCommand.Label)"
    }
    else {
        Add-DoctorFailure "No node_modules/server.js, Start.bat, or package.json found in $sillyDir."
    }
}

Write-Step "Doctor: orchestrator"
if (Test-Path -LiteralPath (Join-Path $orchDir 'server.py') -PathType Leaf) {
    Write-Ok "orchestrator server.py present"
}
else {
    Write-Warn "orchestrator\\server.py missing; launch skips orchestrator."
}

Write-Step "Doctor: ports"
foreach ($port in @($KoboldPort, $SillyPort, $OrchestratorPort)) {
    if (Test-PortFree $port) {
        Write-Ok "Port $port free"
    }
    else {
        Write-Warn "Port $port busy; service may already be running."
    }
}

Write-Step "Doctor result"
if ($failures -gt 0) {
    Write-Fail "$failures blocking issue(s)."
    exit 1
}

Write-Ok "No blocking issues found."
