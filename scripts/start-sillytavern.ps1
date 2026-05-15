. "$PSScriptRoot\common.ps1"

$sillyDir = Resolve-WorldPath 'apps\SillyTavern'
if (-not (Test-Path -LiteralPath $sillyDir)) {
    Write-Fail "SillyTavern missing. Run scripts\\install-apps.ps1 or clone into $sillyDir."
    exit 1
}

Write-Step "Start SillyTavern"
$command = Get-SillyTavernLaunchCommand -SillyDir $sillyDir
if ($command) {
    Write-Ok "Launch method: $($command.Label)"
    Push-Location $sillyDir
    try {
        & $command.FilePath @($command.ArgumentList)
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Fail "No node_modules/server.js, Start.bat, or package.json found in $sillyDir."
    exit 1
}
