param(
    [string]$ModelPath = $env:WB_MODEL_PATH,
    [int]$Port = $(if ($env:WB_KOBOLD_PORT) { [int]$env:WB_KOBOLD_PORT } else { 5001 }),
    [switch]$NoVulkan,
    [ValidateSet('auto', 'vulkan', 'cuda', 'rocm', 'cpu')]
    [string]$KoboldFlavor = $(if ($env:WB_KOBOLDCPP_FLAVOR) { $env:WB_KOBOLDCPP_FLAVOR } else { 'auto' })
)

. "$PSScriptRoot\common.ps1"

$koboldDir = Resolve-WorldPath 'apps\KoboldCpp'
$modelDir = Resolve-WorldPath 'models\llm'

if (-not $ModelPath) {
    $model = Get-ModelCandidate -ModelDir $modelDir
    if ($model) { $ModelPath = $model.FullName }
}

$modelInfo = Get-ModelCandidate -ModelPath $ModelPath -ModelDir $modelDir
if (-not $modelInfo) {
    Write-Fail "No usable GGUF model found. Ignores .partial and files under 1 MB. Put one in $modelDir or set WB_MODEL_PATH."
    exit 1
}
$ModelPath = $modelInfo.FullName
Write-Ok "Model: $ModelPath ($([math]::Round($modelInfo.Length / 1GB, 2)) GB)"

$koboldExe = Get-KoboldCppExecutable -KoboldDir $koboldDir -Flavor $KoboldFlavor

if (-not $koboldExe) {
    Write-KoboldCppSelectionHelp -KoboldDir $koboldDir -Flavor $KoboldFlavor
    Write-Fail "KoboldCpp exe missing or too small in $koboldDir. Run scripts\\install-apps.ps1 or download manually."
    exit 1
}
Write-KoboldCppSelectionHelp -KoboldDir $koboldDir -Flavor $KoboldFlavor
Write-Ok "KoboldCpp exe: $($koboldExe.FullName)"

$args = @('--model', $ModelPath, '--port', "$Port", '--host', '127.0.0.1')
if (-not $NoVulkan) { $args += @('--usevulkan') }

Write-Step "Start KoboldCpp"
Write-Host "Open: http://127.0.0.1:$Port"
& $koboldExe.FullName @args
