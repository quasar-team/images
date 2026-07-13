$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest


Assert-RequiredEnvVar -Name "ICS_REPO_DEPS_TOKEN"
Assert-RequiredEnvVar -Name "UNIFIED_AUTOMATION_HOME"
Assert-RequiredEnvVar -Name "LIBSSL_HOME"
Assert-RequiredEnvVar -Name "LIBXML2_HOME"

$uasdkVersion = "2.0.3-681"
$uasdkUrl = "https://ics-deps-repo.web.cern.ch/quasar/uasdk/2.0.3-681/uasdkcppbundle-src-windows-v2.0.3-681.zip"
$openSslVersion = "3.5.7"
$workRoot = "C:\uasdk-src"
$archivePath = "$workRoot\uasdk.zip"
$sourceRoot = "$workRoot\source"
$releaseBuildPath = "$workRoot\build-release"
$debugBuildPath = "$workRoot\build-debug"
$debugInstallPath = "$workRoot\install-debug"
$installPath = [Environment]::GetEnvironmentVariable("UNIFIED_AUTOMATION_HOME")
$openSslHome = [Environment]::GetEnvironmentVariable("LIBSSL_HOME")
$libXml2Home = [Environment]::GetEnvironmentVariable("LIBXML2_HOME")
$debugModeEnabled = Test-DebugModeEnabled

Add-IssueSection "UNIFIED AUTOMATION UASDK VERSION: $uasdkVersion"
Add-IssueSection "UNIFIED_AUTOMATION_HOME: $installPath"
Add-IssueSection "UNIFIED AUTOMATION UASDK DEBUG BUILD: $debugModeEnabled"

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

function Resolve-LibXml2Library {
    param(
        [Parameter(Mandatory = $true)][string[]]$PreferredNames,
        [Parameter(Mandatory = $true)][string]$Description
    )

    foreach ($libraryName in $PreferredNames) {
        $candidate = Join-Path $libXml2LibraryDir $libraryName
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    $fallbackLibXml2Library = Get-ChildItem -Path $libXml2LibraryDir -Filter "libxml2*.lib" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch 'd\.lib$' } |
        Sort-Object -Property Name |
        Select-Object -First 1
    if ($null -ne $fallbackLibXml2Library) {
        return $fallbackLibXml2Library.FullName
    }

    throw "Unable to locate a $Description libxml2 static library in '$libXml2LibraryDir'."
}

$libXml2Library = Resolve-LibXml2Library `
    -PreferredNames @("libxml2.lib", "libxml2_a.lib", "libxml2s.lib") `
    -Description "release"

$libXml2DebugLibrary = $null
if ($debugModeEnabled) {
    foreach ($libraryName in @("libxml2sd.lib", "libxml2d.lib", "xml2d.lib")) {
        $candidate = Join-Path $libXml2LibraryDir $libraryName
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $libXml2DebugLibrary = $candidate
            break
        }
    }

    if ($null -eq $libXml2DebugLibrary) {
        throw "Unable to locate a debug libxml2 static library in '$libXml2LibraryDir'."
    }
}

$openSslSslDebugLibrary = Join-Path $openSslLibraryDir "libssld.lib"
$openSslCryptoDebugLibrary = Join-Path $openSslLibraryDir "libcryptod.lib"
if ($debugModeEnabled) {
    foreach ($libraryPath in @($openSslSslDebugLibrary, $openSslCryptoDebugLibrary)) {
        if (-not (Test-Path -LiteralPath $libraryPath -PathType Leaf)) {
            throw "Unable to locate required debug OpenSSL library '$libraryPath'."
        }
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

if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}

$openSslHomeForCMake = $openSslHome -replace '\\', '/'
$libXml2IncludeForCMake = $libXml2IncludePath -replace '\\', '/'

function Invoke-UasdkBuild {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("Release", "Debug")][string]$BuildType,
        [Parameter(Mandatory = $true)][string]$BuildPath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][string]$LibXml2LibraryPath,
        [Parameter(Mandatory = $true)][string]$OpenSslSslLibraryPath,
        [Parameter(Mandatory = $true)][string]$OpenSslCryptoLibraryPath
    )

    $libXml2LibraryForCMake = $LibXml2LibraryPath -replace '\\', '/'
    $openSslSslLibraryForCMake = $OpenSslSslLibraryPath -replace '\\', '/'
    $openSslCryptoLibraryForCMake = $OpenSslCryptoLibraryPath -replace '\\', '/'
    $configure = ('cmake -S "{0}" -B "{1}" -G Ninja -DCMAKE_BUILD_TYPE={2} ' +
                  '-DBUILD_SHARED_LIBS=OFF -DUASTACK_WITH_PKI_WIN32=ON ' +
                  '-DOPENSSL_ROOT_DIR="{3}" -DOPENSSL_USE_STATIC_LIBS=TRUE '+
                  '-DOPENSSL_SSL_LIBRARY="{4}" -DOPENSSL_CRYPTO_LIBRARY="{5}" ' +
                  '-DLIBXML2_INCLUDE_DIR="{6}" -DLIBXML2_LIBRARIES="{7}" ' +
                  '-DBUILD_SHARED_STACK=OFF -DUASTACK_CLIENTAPI_ENABLED=ON ' +
                  '-DBUILD_UACLIENTCPP=ON ' +
                  '-DCMAKE_C_FLAGS="/DLIBXML_STATIC /DLIBXSLT_STATIC /DXMLSEC_STATIC" ' +
                  '-DCMAKE_CXX_FLAGS="/DLIBXML_STATIC /DLIBXSLT_STATIC /DXMLSEC_STATIC /FIconio.h" ' +
                  '-DCMAKE_EXE_LINKER_FLAGS="/DEFAULTLIB:bcrypt.lib" '+
                  '-DCMAKE_INSTALL_PREFIX="{8}"') -f `
                     $resolvedSourcePath, $BuildPath, $BuildType, $openSslHomeForCMake, $openSslSslLibraryForCMake, `
                     $openSslCryptoLibraryForCMake, $libXml2IncludeForCMake, $libXml2LibraryForCMake, $DestinationPath
    $build = 'cmake --build "{0}" --parallel' -f $BuildPath
    $install = 'cmake --install "{0}"' -f $BuildPath

    Write-Host "Configuring and building UASDK ($BuildType)"
    Invoke-VsDevShellCommand -Command $configure
    Invoke-VsDevShellCommand -Command $build
    Invoke-VsDevShellCommand -Command $install
}

Invoke-UasdkBuild `
    -BuildType "Release" `
    -BuildPath $releaseBuildPath `
    -DestinationPath $installPath `
    -LibXml2LibraryPath $libXml2Library `
    -OpenSslSslLibraryPath $openSslSslLibrary `
    -OpenSslCryptoLibraryPath $openSslCryptoLibrary

if ($debugModeEnabled) {
    Invoke-UasdkBuild `
        -BuildType "Debug" `
        -BuildPath $debugBuildPath `
        -DestinationPath $installPath `
        -LibXml2LibraryPath $libXml2DebugLibrary `
        -OpenSslSslLibraryPath $openSslSslDebugLibrary `
        -OpenSslCryptoLibraryPath $openSslCryptoDebugLibrary
}

Remove-Item -Path $workRoot -Recurse -Force
