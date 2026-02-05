$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$scriptRoot\Load-DotEnv-File.ps1"
. "$scriptRoot\scripts\Common.ps1"

Initialize-IssueFile

& "$scriptRoot\scripts\Install-BaseTools.ps1"
& "$scriptRoot\scripts\Install-Boost.ps1"
& "$scriptRoot\scripts\Build-UASDK.ps1"
& "$scriptRoot\scripts\Build-Open6.ps1"

$requiredPaths = @(
    "C:\ISSUE",
    "C:\boost\include",
    "C:\boost\libs",
    "C:\unified-automation\include",
    "C:\unified-automation\libs",
    "C:\open6\include",
    "C:\open6\libs"
)

foreach ($path in $requiredPaths) {
    if (-not (Test-Path $path)) {
        throw "Validation failed: expected path '$path' was not created."
    }
}

Write-Host "Windows image dependencies installed successfully."
Write-Host "Issue file location: C:\ISSUE"
Get-Content "C:\ISSUE"
