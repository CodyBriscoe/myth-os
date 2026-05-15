param(
    [switch]$SkipModelDownload,
    [switch]$SkipAppInstall
)

. "$PSScriptRoot\common.ps1"

Write-Step "Create RP stack directories"
$dirs = @(
    'apps',
    'apps\KoboldCpp',
    'apps\SillyTavern',
    'models',
    'models\llm',
    'data',
    'logs',
    'tmp'
)

foreach ($dir in $dirs) {
    Ensure-Directory (Resolve-WorldPath $dir)
}

Write-Step "Run prerequisite checks"
& "$PSScriptRoot\check-prereqs.ps1" -WarnOnly

if (-not $SkipAppInstall) {
    Write-Step "Attempt app install/update"
    & "$PSScriptRoot\install-apps.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "App install incomplete. Manual instructions printed above."
    }
}
else {
    Write-Warn "Skipped app install."
}

if (-not $SkipModelDownload) {
    Write-Step "Attempt model download"
    & "$PSScriptRoot\models.ps1"
    $modelExit = $LASTEXITCODE
    if ($modelExit -ne 0) {
        Write-Warn "Model download incomplete. Manual instructions printed above."
    }
}
else {
    Write-Warn "Skipped model download."
}

Write-Step "Setup result"
Write-Ok "Directories ready. Use scripts\\launch.ps1 after a GGUF exists in models\\llm."
