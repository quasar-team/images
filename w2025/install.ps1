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

$boostHome = [Environment]::GetEnvironmentVariable("BOOST_HOME")
$unifiedAutomationHome = [Environment]::GetEnvironmentVariable("UNIFIED_AUTOMATION_HOME")
$open6Home = [Environment]::GetEnvironmentVariable("OPEN6_HOME")
$xercesCHome = [Environment]::GetEnvironmentVariable("XERCES_C_HOME")
$libSslHome = [Environment]::GetEnvironmentVariable("LIBSSL_HOME")
$libXml2Home = [Environment]::GetEnvironmentVariable("LIBXML2_HOME")
$netSnmpHome = [Environment]::GetEnvironmentVariable("NET_SNMP_HOME")
$xsdHome = [Environment]::GetEnvironmentVariable("XSD_HOME")

. "$scriptRoot\scripts\Install-BaseTools.ps1"
. "$scriptRoot\scripts\Install-Xsd.ps1"
. "$scriptRoot\scripts\Install-LibXsd.ps1"

. "$scriptRoot\scripts\Install-SpecialDeps.ps1"
# Note: Building openssl is very slow. Speed up via meson/ninja not possible.
# See: https://github.com/openssl/openssl/issues/16812
. "$scriptRoot\scripts\Build-OpenSSL.ps1"
# Also quite slow, it relies in nmake, no cmake support
. "$scriptRoot\scripts\Build-NetSnmp.ps1"
. "$scriptRoot\scripts\Uninstall-SpecialDeps.ps1"

. "$scriptRoot\scripts\Build-LibXml2.ps1"

# Boost 1.90.0 needs a temporary Boost.Build patch for VS 2026.
. "$scriptRoot\scripts\Build-Boost.ps1"

. "$scriptRoot\scripts\Build-UASDK.ps1"
. "$scriptRoot\scripts\Build-Open6.ps1"
. "$scriptRoot\scripts\Build-Xerces-C.ps1"

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
    (Join-Path $xsdHome "xsdcxx.exe"),
    (Join-Path $xsdHome "include\xsd"),
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

$homeInstallChecks = @(
    [pscustomobject]@{ Name = "BOOST_HOME"; Path = $boostHome },
    [pscustomobject]@{ Name = "UNIFIED_AUTOMATION_HOME"; Path = $unifiedAutomationHome },
    [pscustomobject]@{ Name = "OPEN6_HOME"; Path = $open6Home },
    [pscustomobject]@{ Name = "XERCES_C_HOME"; Path = $xercesCHome },
    [pscustomobject]@{ Name = "LIBSSL_HOME"; Path = $libSslHome },
    [pscustomobject]@{ Name = "LIBXML2_HOME"; Path = $libXml2Home },
    [pscustomobject]@{ Name = "NET_SNMP_HOME"; Path = $netSnmpHome }
)

$runtimeCheckScript = Join-Path $scriptRoot "Check-MDFlag.ps1"
if (-not (Test-Path -LiteralPath $runtimeCheckScript -PathType Leaf)) {
    throw "Validation failed: expected runtime sanity check script '$runtimeCheckScript'."
}

Write-Host ""
Write-Host "Running /MD sanity checks for installed *_HOME directories..."
foreach ($homeLib in $homeInstallChecks) {
    if ([string]::IsNullOrWhiteSpace($homeLib.Path)) {
        throw "Validation failed: environment variable '$($homeLib.Name)' is empty."
    }

    if (-not (Test-Path -LiteralPath $homeLib.Path -PathType Container)) {
        throw "Validation failed: '$($homeLib.Name)' path '$($homeLib.Path)' does not exist."
    }

    Write-Host ""
    Write-Host "Checking $($homeLib.Name): $($homeLib.Path)"

    & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runtimeCheckScript -RootPath $homeLib.Path
    if ($LASTEXITCODE -ne 0) {
        throw "Runtime sanity check failed for $($homeLib.Name) ('$($homeLib.Path)')."
    }
}

& "$scriptRoot\scripts\Cleanup-Image.ps1"

Write-Host "Windows image dependencies installed successfully."
Write-Host "Issue file location: C:\ISSUE\ISSUE.txt"
Get-Content "C:\ISSUE\ISSUE.txt"
