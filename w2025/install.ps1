$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$scriptRoot\Load-DotEnv-File.ps1"
. "$scriptRoot\scripts\Common.ps1"

Initialize-IssueFile
Add-IssueSection "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

Assert-RequiredEnvVar -Name "BOOST_HOME"
Assert-RequiredEnvVar -Name "UNIFIED_AUTOMATION_HOME"
Assert-RequiredEnvVar -Name "OPEN6_HOME"
Assert-RequiredEnvVar -Name "XERCES_C_HOME"

$boostHome = [Environment]::GetEnvironmentVariable("BOOST_HOME")
$unifiedAutomationHome = [Environment]::GetEnvironmentVariable("UNIFIED_AUTOMATION_HOME")
$open6Home = [Environment]::GetEnvironmentVariable("OPEN6_HOME")
$xercesCHome = [Environment]::GetEnvironmentVariable("XERCES_C_HOME")

& "$scriptRoot\scripts\Install-BaseTools.ps1"
& "$scriptRoot\scripts\Install-Boost.ps1"
& "$scriptRoot\scripts\Build-UASDK.ps1"
& "$scriptRoot\scripts\Build-Open6.ps1"
& "$scriptRoot\scripts\Build-Xerces-C.ps1"

$requiredPaths = @(
    "C:\ISSUE",
    (Join-Path $boostHome "include"),
    (Join-Path $boostHome "lib"),
    (Join-Path $unifiedAutomationHome "include"),
    (Join-Path $unifiedAutomationHome "lib"),
    (Join-Path $open6Home "include"),
    (Join-Path $open6Home "lib"),
    (Join-Path $xercesCHome "include"),
    (Join-Path $xercesCHome "lib")
)

foreach ($path in $requiredPaths) {
    if (-not (Test-Path $path)) {
        throw "Validation failed: expected path '$path' was not created."
    }
}

& "$scriptRoot\scripts\Cleanup-Image.ps1"

Write-Host "Windows image dependencies installed successfully."
Write-Host "Issue file location: C:\ISSUE"
Get-Content "C:\ISSUE"
