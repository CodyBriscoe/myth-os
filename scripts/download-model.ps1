param(
    [string]$Repo = $env:WB_MODEL_REPO,
    [string]$File = $env:WB_MODEL_FILE,
    [string]$OutDir = $env:WB_MODEL_DIR,
    [switch]$Force
)

& "$PSScriptRoot\models.ps1" -Repo $Repo -File $File -OutDir $OutDir -Force:$Force
