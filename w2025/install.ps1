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
Assert-RequiredEnvVar -Name "LIBSSL_HOME"
Assert-RequiredEnvVar -Name "LIBXML2_HOME"
Assert-RequiredEnvVar -Name "NET_SNMP_HOME"
Assert-RequiredEnvVar -Name "XSD_HOME"
Assert-RequiredEnvVar -Name "LIBXSD_HOME"

$boostHome = [Environment]::GetEnvironmentVariable("BOOST_HOME")
$unifiedAutomationHome = [Environment]::GetEnvironmentVariable("UNIFIED_AUTOMATION_HOME")
$open6Home = [Environment]::GetEnvironmentVariable("OPEN6_HOME")
$xercesCHome = [Environment]::GetEnvironmentVariable("XERCES_C_HOME")
$libSslHome = [Environment]::GetEnvironmentVariable("LIBSSL_HOME")
$libXml2Home = [Environment]::GetEnvironmentVariable("LIBXML2_HOME")
$netSnmpHome = [Environment]::GetEnvironmentVariable("NET_SNMP_HOME")
$xsdHome = [Environment]::GetEnvironmentVariable("XSD_HOME")
$libXsdHome = [Environment]::GetEnvironmentVariable("LIBXSD_HOME")

& "$scriptRoot\scripts\Install-BaseTools.ps1"
& "$scriptRoot\scripts\Install-Xsd.ps1"
& "$scriptRoot\scripts\Install-LibXsd.ps1"

# Note: Building openssl is very slow. Speed up via meson/ninja not possible.
# See: https://github.com/openssl/openssl/issues/16812
& "$scriptRoot\scripts\Build-OpenSSL.ps1"

& "$scriptRoot\scripts\Build-LibXml2.ps1"

# Also quite slow, it relies in nmake, no cmake support
& "$scriptRoot\scripts\Build-NetSnmp.ps1"

# Boost installed rather than built from source due to b2 incompatibility
# with Visual Studio 2026; b2 fixed in master to support latest MSVC toolset.
# Change to Build script with Boost 9.0.1 or later.
& "$scriptRoot\scripts\Install-Boost.ps1"

& "$scriptRoot\scripts\Build-UASDK.ps1"
& "$scriptRoot\scripts\Build-Open6.ps1"
& "$scriptRoot\scripts\Build-Xerces-C.ps1"

$openSslLibPathCandidates = @(
    (Join-Path $libSslHome "lib"),
    (Join-Path $libSslHome "lib64")
)
$openSslLibPath = $openSslLibPathCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($null -eq $openSslLibPath) {
    throw "Validation failed: expected OpenSSL library directory under '$libSslHome\\lib' or '$libSslHome\\lib64'."
}

$requiredPaths = @(
    "C:\ISSUE\ISSUE.txt",
    (Join-Path $xsdHome "xsdcpp.exe"),
    (Join-Path $libXsdHome "include\xsd"),
    (Join-Path $libSslHome "include"),
    (Join-Path $openSslLibPath "libcrypto.lib"),
    (Join-Path $openSslLibPath "libssl.lib"),
    (Join-Path $libXml2Home "include\libxml2"),
    (Join-Path $libXml2Home "lib"),
    (Join-Path $netSnmpHome "include"),
    (Join-Path $netSnmpHome "lib"),
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
Write-Host "Issue file location: C:\ISSUE\ISSUE.txt"
Get-Content "C:\ISSUE\ISSUE.txt"
