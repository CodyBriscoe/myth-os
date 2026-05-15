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
    foreach ($arg in $ArgumentList) {
        $psi.ArgumentList.Add($arg)
    }
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
