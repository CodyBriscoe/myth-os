. "$PSScriptRoot\common.ps1"

$sillyDir = Resolve-WorldPath 'apps\SillyTavern'
if (-not (Test-Path -LiteralPath $sillyDir)) {
    Write-Fail "SillyTavern missing. Run scripts\\install-apps.ps1 or clone into $sillyDir."
    exit 1
}

$startBat = Get-FirstExistingPath @(
    (Join-Path $sillyDir 'Start.bat'),
    (Join-Path $sillyDir 'start.bat')
)

Write-Step "Start SillyTavern"
if ($startBat) {
    & $startBat
}
elseif (Test-Path -LiteralPath (Join-Path $sillyDir 'package.json')) {
    Push-Location $sillyDir
    try {
        npm install
        npm start
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Fail "No Start.bat or package.json found in $sillyDir."
    exit 1
}
