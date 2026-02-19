$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\Common.ps1"

Assert-RequiredEnvVar -Name "ICS_REPO_DEPS_TOKEN"
Assert-RequiredEnvVar -Name "UNIFIED_AUTOMATION_HOME"
Assert-RequiredEnvVar -Name "LIBSSL_HOME"
Assert-RequiredEnvVar -Name "LIBXML2_HOME"

$uasdkVersion = "2.0.2-675"
$uasdkUrl = "https://ics-deps-repo.web.cern.ch/quasar/uasdk/2.0.2-675/uasdkcppbundle-src-windows-v2.0.2-675.zip"
$openSslVersion = "3.5.5"
$workRoot = "C:\uasdk-src"
$archivePath = "$workRoot\uasdk.zip"
$sourceRoot = "$workRoot\source"
$buildPath = "$workRoot\build"
$installPath = [Environment]::GetEnvironmentVariable("UNIFIED_AUTOMATION_HOME")
$openSslHome = [Environment]::GetEnvironmentVariable("LIBSSL_HOME")
$libXml2Home = [Environment]::GetEnvironmentVariable("LIBXML2_HOME")

Add-IssueSection "UNIFIED AUTOMATION UASDK VERSION: $uasdkVersion"
Add-IssueSection "UNIFIED_AUTOMATION_HOME: $installPath"

$libXml2IncludePathCandidates = @(
    (Join-Path $libXml2Home "include")
)
$libXml2IncludePath = $libXml2IncludePathCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$libXml2LibraryDir = Join-Path $libXml2Home "lib"

$libXml2Library = $null
$preferredLibXml2LibraryNames = @("libxml2.lib", "libxml2_a.lib", "libxml2s.lib")
foreach ($libraryName in $preferredLibXml2LibraryNames) {
    $candidate = Join-Path $libXml2LibraryDir $libraryName
    if (Test-Path $candidate) {
        $libXml2Library = $candidate
        break
    }
}

if (Test-Path $workRoot) {
    Remove-Item -Path $workRoot -Recurse -Force
}
New-Item -Path $sourceRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading UASDK"
Invoke-WebRequest -Headers @{ "PRIVATE-TOKEN" = "$env:ICS_REPO_DEPS_TOKEN" } -Uri $uasdkUrl -OutFile $archivePath

Write-Host "Extracting UASDK"
Expand-Archive -Path $archivePath -DestinationPath $sourceRoot -Force

$cmakeListsFile = Get-ChildItem -Path $sourceRoot -Filter "CMakeLists.txt" -Recurse -File |
    Sort-Object { $_.FullName.Length } |
    Select-Object -First 1

if ($null -eq $cmakeListsFile) {
    throw "Unable to find CMakeLists.txt in extracted UASDK sources."
}

$resolvedSourcePath = Split-Path -Path $cmakeListsFile.FullName -Parent

if (Test-Path $buildPath) {
    Remove-Item -Path $buildPath -Recurse -Force
}
if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}

$openSslHomeForCMake = $openSslHome -replace '\\', '/'
$libXml2HomeForCMake = $libXml2Home -replace '\\', '/'

$configureArgs = @(
    '-S', $resolvedSourcePath,
    '-B', $buildPath,
    '-G', 'Ninja',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DBUILD_SHARED_LIBS=OFF',
    '-DUASTACK_WITH_PKI_WIN32=ON',
    "-DOPENSSL_ROOT_DIR=$openSslHomeForCMake",
    '-DOPENSSL_USE_STATIC_LIBS=TRUE',
    "-DLIBXML2_ROOT_DIR=$libXml2HomeForCMake",
    '-DBUILD_SHARED_STACK=OFF',
    '-DUASTACK_CLIENTAPI_ENABLED=ON',
    '-DBUILD_UACLIENTCPP=ON',
    '-DCMAKE_C_FLAGS=/DLIBXML_STATIC /DLIBXSLT_STATIC /DXMLSEC_STATIC',
    '-DCMAKE_CXX_FLAGS=/DLIBXML_STATIC /DLIBXSLT_STATIC /DXMLSEC_STATIC /FIconio.h',
    '-DCMAKE_EXE_LINKER_FLAGS=/DEFAULTLIB:bcrypt.lib',
    "-DCMAKE_INSTALL_PREFIX=$installPath"
)

Write-Host "Configuring and building UASDK"
Invoke-Checked cmake $configureArgs
Invoke-Checked cmake @('--build', $buildPath, '--parallel')
Invoke-Checked cmake @('--install', $buildPath)

$thirdPartyDir = Get-ChildItem -Path $sourceRoot -Directory -Recurse |
    Where-Object { $_.Name -eq "third-party" } |
    Sort-Object { $_.FullName.Length } |
    Select-Object -First 1

if ($null -eq $thirdPartyDir) {
    throw "Unable to find third-party directory in extracted UASDK sources."
}

$thirdPartyInstallPath = Join-Path $installPath "third-party"
Write-Host "Copying UASDK third-party folder to install path"
Copy-Item -Path $thirdPartyDir.FullName -Destination $thirdPartyInstallPath -Recurse -Force

Remove-Item -Path $workRoot -Recurse -Force
