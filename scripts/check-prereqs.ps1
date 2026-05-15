param(
    [switch]$WarnOnly
)

. "$PSScriptRoot\common.ps1"

$failures = 0

function Add-Failure {
    param([Parameter(Mandatory)][string]$Message)
    $script:failures += 1
    Write-Fail $Message
}

Write-Step "Check command prerequisites"

if (Test-Tool 'git') {
    Write-Ok "Git: $(Get-ToolVersionLine 'git')"
}
else {
    Add-Failure "Git missing. Install Git for Windows: https://git-scm.com/download/win"
}

if (Test-Tool 'node') {
    Write-Ok "Node: $(Get-ToolVersionLine 'node' @('--version'))"
}
else {
    Add-Failure "Node missing. Install current LTS from https://nodejs.org/"
}

if (Test-Tool 'python') {
    Write-Ok "Python: $(Get-ToolVersionLine 'python' @('--version'))"
}
elseif (Test-Tool 'py') {
    Write-Ok "Python launcher: $(Get-ToolVersionLine 'py' @('--version'))"
}
else {
    Add-Failure "Python missing. Install Python 3.11+ and enable PATH."
}

Write-Step "Check RP stack ports"
$ports = @(5001, 8000, 8001)
foreach ($port in $ports) {
    if (Test-PortFree $port) {
        Write-Ok "Port $port free"
    }
    else {
        Add-Failure "Port $port busy. Close service using it, or change stack ports before launch."
    }
}

Write-Step "Check AMD/Vulkan hints"
$gpuNames = @()
try {
    $gpuNames = Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name } | Where-Object { $_ }
}
catch {
    Write-Warn "Could not query GPU list: $($_.Exception.Message)"
}

if ($gpuNames.Count -gt 0) {
    foreach ($gpu in $gpuNames) {
        Write-Ok "GPU seen: $gpu"
    }
}
else {
    Write-Warn "No GPU reported by WMI."
}

$amdGpu = $gpuNames | Where-Object { $_ -match 'AMD|Radeon|Advanced Micro Devices' } | Select-Object -First 1
if ($amdGpu) {
    Write-Ok "AMD GPU hint: use KoboldCpp Vulkan build, current AMD Adrenalin driver, and Vulkan runtime."
}
else {
    Write-Warn "No AMD GPU detected. Vulkan may still work with another GPU, but AMD path not confirmed."
}

if (Test-Tool 'vulkaninfo') {
    Write-Ok "vulkaninfo available: $(Get-ToolVersionLine 'vulkaninfo' @('--summary'))"
}
else {
    Write-Warn "vulkaninfo missing. Install Vulkan SDK or ensure GPU driver includes Vulkan runtime. KoboldCpp Vulkan can still be tried."
}

if ($env:VK_ICD_FILENAMES) {
    Write-Ok "VK_ICD_FILENAMES set: $env:VK_ICD_FILENAMES"
}
else {
    Write-Warn "VK_ICD_FILENAMES not set. Usually fine; set only if Vulkan picks wrong ICD."
}

if ($failures -gt 0) {
    Write-Step "Prereq result"
    if ($WarnOnly) {
        Write-Warn "$failures blocking check(s), but WarnOnly set."
        exit 0
    }

    Write-Fail "$failures blocking check(s)."
    exit 1
}

Write-Step "Prereq result"
Write-Ok "All blocking prerequisites pass."
