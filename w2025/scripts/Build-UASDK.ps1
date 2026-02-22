$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest


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

$openSslIncludePath = Join-Path $openSslHome "include"
$openSslLibraryDirCandidates = @(
    (Join-Path $openSslHome "lib"),
    (Join-Path $openSslHome "lib64")
)
$openSslLibraryDir = $openSslLibraryDirCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not (Test-Path $openSslIncludePath)) {
    throw "Unable to locate OpenSSL include directory at '$openSslIncludePath'."
}
if ($null -eq $openSslLibraryDir) {
    throw "Unable to locate OpenSSL libraries under '$openSslHome\\lib' or '$openSslHome\\lib64'."
}

$openSslSslLibrary = Join-Path $openSslLibraryDir "libssl.lib"
$openSslCryptoLibrary = Join-Path $openSslLibraryDir "libcrypto.lib"
foreach ($libraryPath in @($openSslSslLibrary, $openSslCryptoLibrary)) {
    if (-not (Test-Path $libraryPath)) {
        throw "Unable to locate required OpenSSL library '$libraryPath'."
    }
}

$libXml2IncludePathCandidates = @(
    (Join-Path $libXml2Home "include\libxml2"),
    (Join-Path $libXml2Home "include")
)
$libXml2IncludePath = $libXml2IncludePathCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$libXml2LibraryDir = Join-Path $libXml2Home "lib"

if ($null -eq $libXml2IncludePath) {
    throw "Unable to locate libxml2 include directory under '$libXml2Home\\include'."
}
if (-not (Test-Path $libXml2LibraryDir)) {
    throw "Unable to locate libxml2 library directory at '$libXml2LibraryDir'."
}

$libXml2Library = $null
$preferredLibXml2LibraryNames = @("libxml2.lib", "libxml2_a.lib", "libxml2s.lib")
foreach ($libraryName in $preferredLibXml2LibraryNames) {
    $candidate = Join-Path $libXml2LibraryDir $libraryName
    if (Test-Path $candidate) {
        $libXml2Library = $candidate
        break
    }
}

if ($null -eq $libXml2Library) {
    $fallbackLibXml2Library = Get-ChildItem -Path $libXml2LibraryDir -Filter "libxml2*.lib" -File -ErrorAction SilentlyContinue |
        Sort-Object -Property Name |
        Select-Object -First 1
    if ($null -ne $fallbackLibXml2Library) {
        $libXml2Library = $fallbackLibXml2Library.FullName
    }
}

if ($null -eq $libXml2Library) {
    throw "Unable to locate a libxml2 static library in '$libXml2LibraryDir'."
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
$libXml2IncludeForCMake = $libXml2IncludePath -replace '\\', '/'
$libXml2LibraryForCMake = $libXml2Library -replace '\\', '/'
$configure = ('cmake -S "{0}" -B "{1}" -G Ninja -DCMAKE_BUILD_TYPE=Release ' +
              '-DBUILD_SHARED_LIBS=OFF -DUASTACK_WITH_PKI_WIN32=ON ' +
              '-DOPENSSL_ROOT_DIR="{2}" -DOPENSSL_USE_STATIC_LIBS=TRUE '+
              '-DLIBXML2_INCLUDE_DIR="{3}" -DLIBXML2_LIBRARIES="{4}" ' +
              '-DBUILD_SHARED_STACK=OFF -DUASTACK_CLIENTAPI_ENABLED=ON ' +
              '-DBUILD_UACLIENTCPP=ON ' +
              '-DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded" ' +
              '-DCMAKE_C_FLAGS="/DLIBXML_STATIC /DLIBXSLT_STATIC /DXMLSEC_STATIC" ' +
              '-DCMAKE_CXX_FLAGS="/DLIBXML_STATIC /DLIBXSLT_STATIC /DXMLSEC_STATIC /FIconio.h" ' +
              '-DCMAKE_EXE_LINKER_FLAGS="/DEFAULTLIB:bcrypt.lib" '+
              '-DCMAKE_INSTALL_PREFIX="{5}"') -f `
                 $resolvedSourcePath, $buildPath, $openSslHomeForCMake, $libXml2IncludeForCMake, `
                 $libXml2LibraryForCMake, $installPath
$build = 'cmake --build "{0}" --parallel' -f $buildPath
$install = 'cmake --install "{0}"' -f $buildPath

Write-Host "Configuring and building UASDK"
Invoke-VsDevShellCommand -Command $configure
Invoke-VsDevShellCommand -Command $build
Invoke-VsDevShellCommand -Command $install

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
