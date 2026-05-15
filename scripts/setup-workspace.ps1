param(
    [switch]$SkipModelDownload,
    [switch]$SkipAppInstall
)

& "$PSScriptRoot\setup.ps1" -SkipModelDownload:$SkipModelDownload -SkipAppInstall:$SkipAppInstall
