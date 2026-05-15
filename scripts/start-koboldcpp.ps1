param(
    [string]$ModelPath = $env:WB_MODEL_PATH,
    [int]$Port = $(if ($env:WB_KOBOLD_PORT) { [int]$env:WB_KOBOLD_PORT } else { 5001 }),
    [switch]$NoVulkan
)

. "$PSScriptRoot\common.ps1"

$koboldDir = Resolve-WorldPath 'apps\KoboldCpp'
$modelDir = Resolve-WorldPath 'models\llm'

if (-not $ModelPath) {
    $model = Get-ChildItem -LiteralPath $modelDir -Filter '*.gguf' -File -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending |
        Select-Object -First 1
    if ($model) { $ModelPath = $model.FullName }
}

if (-not $ModelPath -or -not (Test-Path -LiteralPath $ModelPath)) {
    Write-Fail "No GGUF model found. Put one in $modelDir or set WB_MODEL_PATH."
    exit 1
}

$koboldExe = Get-FirstExistingPath @(
    (Join-Path $koboldDir 'koboldcpp.exe'),
    (Join-Path $koboldDir 'koboldcpp_vulkan.exe'),
    (Join-Path $koboldDir 'koboldcpp_rocm.exe')
)

if (-not $koboldExe) {
    Write-Fail "KoboldCpp exe missing in $koboldDir. Run scripts\\install-apps.ps1 or download manually."
    exit 1
}

$args = @('--model', $ModelPath, '--port', "$Port", '--host', '127.0.0.1')
if (-not $NoVulkan) { $args += @('--usevulkan') }

Write-Step "Start KoboldCpp"
Write-Host "Open: http://127.0.0.1:$Port"
& $koboldExe @args
