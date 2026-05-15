param(
    [switch]$SkipSillyTavern,
    [switch]$SkipKoboldCpp,
    [switch]$ForceKoboldDownload
)

. "$PSScriptRoot\common.ps1"

$appsDir = Resolve-WorldPath 'apps'
$sillyDir = Resolve-WorldPath 'apps\SillyTavern'
$koboldDir = Resolve-WorldPath 'apps\KoboldCpp'

Ensure-Directory $appsDir
Ensure-Directory $koboldDir

if (-not $SkipSillyTavern) {
    Write-Step "Install/update SillyTavern"
    if (Test-Path -LiteralPath (Join-Path $sillyDir '.git')) {
        Write-Host "Existing git checkout: $sillyDir"
        Push-Location $sillyDir
        try {
            git pull --ff-only
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "git pull failed. Existing SillyTavern kept."
            }
        }
        finally {
            Pop-Location
        }
    }
    elseif (Test-Path -LiteralPath $sillyDir) {
        $hasFiles = Get-ChildItem -LiteralPath $sillyDir -Force -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hasFiles) {
            Write-Warn "SillyTavern directory exists but is not git checkout: $sillyDir"
            Write-Host "Manual update/install: https://docs.sillytavern.app/installation/windows/"
        }
        else {
            git clone https://github.com/SillyTavern/SillyTavern.git $sillyDir
        }
    }
    else {
        git clone https://github.com/SillyTavern/SillyTavern.git $sillyDir
    }
}

if (-not $SkipKoboldCpp) {
    Write-Step "Install/update KoboldCpp executable"
    $existingExe = Get-FirstExistingPath @(
        (Join-Path $koboldDir 'koboldcpp.exe'),
        (Join-Path $koboldDir 'koboldcpp_vulkan.exe'),
        (Join-Path $koboldDir 'koboldcpp_rocm.exe')
    )
    if ($existingExe) {
        $existingInfo = Get-Item -LiteralPath $existingExe
        if ($existingInfo.Length -lt 1MB) {
            Write-Warn "Ignoring incomplete KoboldCpp exe: $existingExe"
            $existingExe = $null
        }
    }

    if ($existingExe -and -not $ForceKoboldDownload) {
        Write-Ok "KoboldCpp exe exists: $existingExe"
    }
    else {
        try {
            $api = 'https://api.github.com/repos/LostRuins/koboldcpp/releases/latest'
            Write-Host "Query: $api"
            $release = Invoke-RestMethod -Uri $api -UseBasicParsing
            $asset = $release.assets |
                Where-Object { $_.name -match '^koboldcpp.*\.exe$' -and $_.name -notmatch 'cuda|cu12|nocuda|oldpc' } |
                Sort-Object name |
                Select-Object -First 1
            if (-not $asset) {
                $asset = $release.assets |
                    Where-Object { $_.name -match '^koboldcpp.*\.exe$' -and $_.name -notmatch 'oldpc' } |
                    Sort-Object name |
                    Select-Object -First 1
            }
            if (-not $asset) {
                throw "No Windows .exe asset found in latest release."
            }

            $target = Join-Path $koboldDir $asset.name
            Write-Host "Download: $($asset.browser_download_url)"
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $target -UseBasicParsing
            $downloadedInfo = Get-Item -LiteralPath $target
            if ($downloadedInfo.Length -lt 1MB) {
                throw "Downloaded file too small: $($downloadedInfo.Length) bytes."
            }

            $stable = Join-Path $koboldDir 'koboldcpp.exe'
            if ((Split-Path -Leaf $target) -ne 'koboldcpp.exe') {
                Copy-Item -LiteralPath $target -Destination $stable -Force
            }
            Write-Ok "KoboldCpp ready: $stable"
        }
        catch {
            Write-Warn "KoboldCpp download failed: $($_.Exception.Message)"
            Write-Host "Manual path:"
            Write-Host "  1. Open https://github.com/LostRuins/koboldcpp/releases/latest"
            Write-Host "  2. Download Windows koboldcpp .exe"
            Write-Host "  3. Put it in $koboldDir as koboldcpp.exe"
            exit 2
        }
    }
}

Write-Step "App install result"
Write-Ok "App install step complete or manual fallback printed."
