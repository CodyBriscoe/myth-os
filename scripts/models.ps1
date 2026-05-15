param(
    [string]$Repo = $env:WB_MODEL_REPO,
    [string]$File = $env:WB_MODEL_FILE,
    [string]$OutDir = $env:WB_MODEL_DIR,
    [switch]$Force
)

. "$PSScriptRoot\common.ps1"

if (-not $OutDir) {
    $OutDir = Resolve-WorldPath 'models\llm'
}

Ensure-Directory $OutDir

$candidates = @(
    @{ Repo = 'TheDrummer/Cydonia-24B-v3-GGUF'; File = 'Cydonia-24B-v3e-Q4_K_M.gguf' },
    @{ Repo = 'TheDrummer/Precog-24B-v1-GGUF'; File = 'Precog-24B-v1b-Q4_K_M.gguf' },
    @{ Repo = 'TheDrummer/Star-Command-R-32B-v1-GGUF'; File = 'Star-Command-R-32B-v1-Q4_K_M.gguf' }
)

if (-not $Repo) {
    $Repo = $candidates[0].Repo
}

if (-not $File) {
    $match = $candidates | Where-Object { $_.Repo -eq $Repo } | Select-Object -First 1
    if ($match) {
        $File = $match.File
    }
}

if (-not $File) {
    Write-Warn "WB_MODEL_FILE not set. Will try Hugging Face CLI pattern '*.gguf' fallback."
}

$target = if ($File) { Join-Path $OutDir $File } else { $null }
if ($target -and (Test-Path -LiteralPath $target) -and -not $Force) {
    Write-Ok "Model already exists: $target"
    exit 0
}

Write-Step "Download TheDrummer GGUF"
Write-Host "Repo: $Repo"
if ($File) { Write-Host "File: $File" }
Write-Host "Output: $OutDir"

$downloaded = $false

if (Test-Tool 'huggingface-cli') {
    try {
        $args = @('download', $Repo, '--local-dir', $OutDir, '--local-dir-use-symlinks', 'False')
        if ($File) {
            $args = @('download', $Repo, $File, '--local-dir', $OutDir, '--local-dir-use-symlinks', 'False')
        }

        & huggingface-cli @args
        if ($LASTEXITCODE -eq 0) {
            $downloaded = $true
        }
        else {
            Write-Warn "huggingface-cli exited $LASTEXITCODE"
        }
    }
    catch {
        Write-Warn "huggingface-cli failed: $($_.Exception.Message)"
    }
}
else {
    Write-Warn "huggingface-cli missing. Install with: python -m pip install -U huggingface_hub"
}

if (-not $downloaded -and $File) {
    $url = "https://huggingface.co/$Repo/resolve/main/${File}?download=true"
    $target = Join-Path $OutDir $File
    $partial = "$target.partial"
    try {
        Write-Step "Try direct Hugging Face download"
        Write-Host "URL: $url"
        Invoke-WebRequest -Uri $url -OutFile $partial -UseBasicParsing
        Move-Item -LiteralPath $partial -Destination $target -Force
        $downloaded = $true
    }
    catch {
        Write-Warn "Direct download failed: $($_.Exception.Message)"
        if (Test-Path -LiteralPath $partial) {
            Write-Warn "Partial file kept: $partial"
        }
    }
}

if ($downloaded) {
    $ggufs = Get-ChildItem -LiteralPath $OutDir -Filter '*.gguf' -File -ErrorAction SilentlyContinue
    if ($ggufs.Count -gt 0) {
        Write-Ok "GGUF present:"
        $ggufs | Sort-Object Length -Descending | ForEach-Object {
            $gb = [math]::Round($_.Length / 1GB, 2)
            Write-Host "  $($_.FullName) ($gb GB)"
        }
        exit 0
    }

    Write-Warn "Download command succeeded, but no .gguf found in $OutDir."
}

Write-Step "Manual fallback"
Write-Warn "Automatic model download did not complete."
Write-Host "Manual path:"
Write-Host "  1. Open https://huggingface.co/$Repo"
Write-Host "  2. Download a Q4_K_M or Q5_K_M .gguf if VRAM/RAM allows."
Write-Host "  3. Put file in $OutDir"
Write-Host "  4. Or rerun with:"
Write-Host "     powershell -ExecutionPolicy Bypass -File scripts\models.ps1 -Repo '$Repo' -File '<file.gguf>'"
Write-Host ""
Write-Host "Config env:"
Write-Host "  WB_MODEL_REPO='TheDrummer/Precog-24B-v1-GGUF'"
Write-Host "  WB_MODEL_FILE='Precog-24B-v1b-Q4_K_M.gguf'"
exit 2
