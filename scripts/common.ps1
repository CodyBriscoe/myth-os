$ErrorActionPreference = 'Stop'

function Get-WorldRoot {
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
}

function Resolve-WorldPath {
    param([Parameter(Mandatory)][string]$RelativePath)
    return (Join-Path (Get-WorldRoot) $RelativePath)
}

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Test-Tool {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-ToolVersionLine {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string[]]$Arguments = @('--version')
    )

    try {
        $output = & $Name @Arguments 2>$null | Where-Object { $_ } | Select-Object -First 1
        if ($output) { return ($output.ToString().Trim()) }
    }
    catch {
        return $null
    }

    return $null
}

function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
        Write-Ok "Created $Path"
    }
    else {
        Write-Ok "Exists $Path"
    }
}

function Test-PortFree {
    param([Parameter(Mandatory)][int]$Port)

    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
        $listener.Start()
        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($listener) {
            $listener.Stop()
        }
    }
}

function Get-FirstExistingPath {
    param([Parameter(Mandatory)][string[]]$Paths)

    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    return $null
}

function Get-ModelCandidate {
    param(
        [string]$ModelPath = $env:WB_MODEL_PATH,
        [string]$ModelDir = (Resolve-WorldPath 'models\llm'),
        [int64]$MinBytes = 1MB
    )

    if ($ModelPath) {
        if (-not (Test-Path -LiteralPath $ModelPath -PathType Leaf)) {
            return $null
        }

        $item = Get-Item -LiteralPath $ModelPath
        if ($item.Name -like '*.partial' -or $item.Extension -ne '.gguf' -or $item.Length -lt $MinBytes) {
            return $null
        }

        return $item
    }

    Get-ChildItem -LiteralPath $ModelDir -Filter '*.gguf' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.partial' -and $_.Length -ge $MinBytes } |
        Sort-Object Length -Descending |
        Select-Object -First 1
}

function Get-KoboldCppCandidates {
    param(
        [string]$KoboldDir = (Resolve-WorldPath 'apps\KoboldCpp'),
        [ValidateSet('auto', 'vulkan', 'cuda', 'rocm', 'cpu')]
        [string]$Flavor = $(if ($env:WB_KOBOLDCPP_FLAVOR) { $env:WB_KOBOLDCPP_FLAVOR } else { 'auto' })
    )

    $patternsByFlavor = @{
        vulkan = @('koboldcpp_vulkan.exe', 'koboldcpp.exe')
        cuda = @('koboldcpp_cu12.exe', 'koboldcpp_cuda.exe', 'koboldcpp.exe')
        rocm = @('koboldcpp_rocm.exe', 'koboldcpp.exe')
        cpu = @('koboldcpp_nocuda.exe', 'koboldcpp.exe')
        auto = @('koboldcpp.exe', 'koboldcpp_vulkan.exe', 'koboldcpp_cu12.exe', 'koboldcpp_cuda.exe', 'koboldcpp_rocm.exe', 'koboldcpp_nocuda.exe')
    }

    $candidates = @()
    if ($env:WB_KOBOLDCPP_EXE) {
        $candidates += $env:WB_KOBOLDCPP_EXE
    }

    foreach ($name in $patternsByFlavor[$Flavor]) {
        $candidates += (Join-Path $KoboldDir $name)
    }

    $candidates | Select-Object -Unique
}

function Get-KoboldCppExecutable {
    param(
        [string]$KoboldDir = (Resolve-WorldPath 'apps\KoboldCpp'),
        [ValidateSet('auto', 'vulkan', 'cuda', 'rocm', 'cpu')]
        [string]$Flavor = $(if ($env:WB_KOBOLDCPP_FLAVOR) { $env:WB_KOBOLDCPP_FLAVOR } else { 'auto' })
    )

    foreach ($path in (Get-KoboldCppCandidates -KoboldDir $KoboldDir -Flavor $Flavor)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $item = Get-Item -LiteralPath $path
            if ($item.Length -ge 1MB) {
                return $item
            }
        }
    }

    return $null
}

function Write-KoboldCppSelectionHelp {
    param(
        [string]$KoboldDir = (Resolve-WorldPath 'apps\KoboldCpp'),
        [string]$Flavor = $(if ($env:WB_KOBOLDCPP_FLAVOR) { $env:WB_KOBOLDCPP_FLAVOR } else { 'auto' })
    )

    Write-Host "KoboldCpp flavor: $Flavor (set WB_KOBOLDCPP_FLAVOR=auto|vulkan|cuda|rocm|cpu)"
    Write-Host "KoboldCpp override: set WB_KOBOLDCPP_EXE to exact .exe path"
    Write-Host "Search order:"
    foreach ($path in (Get-KoboldCppCandidates -KoboldDir $KoboldDir -Flavor $Flavor)) {
        Write-Host "  $path"
    }
}

function Get-SillyTavernLaunchCommand {
    param([string]$SillyDir = (Resolve-WorldPath 'apps\SillyTavern'))

    $serverJs = Join-Path $SillyDir 'server.js'
    $nodeModules = Join-Path $SillyDir 'node_modules'
    if ((Test-Path -LiteralPath $serverJs -PathType Leaf) -and (Test-Path -LiteralPath $nodeModules -PathType Container)) {
        return @{
            FilePath = 'node'
            ArgumentList = @('server.js')
            Label = 'node server.js'
        }
    }

    $startBat = Get-FirstExistingPath @(
        (Join-Path $SillyDir 'Start.bat'),
        (Join-Path $SillyDir 'start.bat')
    )
    if ($startBat) {
        return @{
            FilePath = $startBat
            ArgumentList = @()
            Label = $startBat
        }
    }

    if (Test-Path -LiteralPath (Join-Path $SillyDir 'package.json') -PathType Leaf) {
        return @{
            FilePath = 'cmd.exe'
            ArgumentList = @('/c', 'npm', 'start')
            Label = 'npm start'
        }
    }

    return $null
}

function Wait-HttpReady {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Url,
        [int]$TimeoutSeconds = 90,
        [int]$DelaySeconds = 2
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -Method Get
            if ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 500) {
                Write-Ok "$Name ready: $Url"
                return $true
            }
        }
        catch {
        }

        Start-Sleep -Seconds $DelaySeconds
    }

    Write-Warn "$Name not ready after $TimeoutSeconds seconds: $Url"
    return $false
}

function Convert-ToProcessArgumentString {
    param([string[]]$ArgumentList = @())

    $quoted = foreach ($arg in $ArgumentList) {
        if ($null -eq $arg) {
            continue
        }

        $text = [string]$arg
        if ($text -notmatch '[\s"]') {
            $text
        }
        else {
            '"' + ($text -replace '"', '\"') + '"'
        }
    }

    return ($quoted -join ' ')
}

function Start-LoggedProcess {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$LogPath
    )

    Ensure-Directory (Split-Path -Parent $LogPath)

    $displayArgs = ($ArgumentList -join ' ')
    Write-Host "$Name command: $FilePath $displayArgs"
    $stdoutLog = $LogPath
    $stderrLog = [System.IO.Path]::Combine(
        (Split-Path -Parent $LogPath),
        "$([System.IO.Path]::GetFileNameWithoutExtension($LogPath)).err$([System.IO.Path]::GetExtension($LogPath))"
    )

    Write-Host "$Name log target: $stdoutLog"
    Write-Warn "$Name launched detached; console output may not be captured on this Windows shell."

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    $psi.Arguments = Convert-ToProcessArgumentString -ArgumentList $ArgumentList
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $false
    $psi.RedirectStandardError = $false

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    $null = $process.Start()

    Write-Ok "$Name started pid=$($process.Id)"
    return $process
}
