$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Assert-RequiredEnvVar -Name "LIBXML2_HOME"

$libXml2Version = "2.15.3"
$libXml2Url = "https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.3.tar.xz"
$workRoot = "C:\libxml2-src"
$archivePath = "$workRoot\libxml2.tar.xz"
$sourceRoot = "$workRoot\source"
$releaseBuildPath = "$workRoot\build-release"
$debugBuildPath = "$workRoot\build-debug"
$debugInstallPath = "$workRoot\install-debug"
$installPath = [Environment]::GetEnvironmentVariable("LIBXML2_HOME")
$debugModeEnabled = Test-DebugModeEnabled

Add-IssueSection "LIBXML2 VERSION: $libXml2Version"
Add-IssueSection "LIBXML2_HOME: $installPath"
Add-IssueSection "LIBXML2 DEBUG BUILD: $debugModeEnabled"

if (Test-Path $workRoot) {
    Remove-Item -Path $workRoot -Recurse -Force
}
New-Item -Path $sourceRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading libxml2 sources"
Invoke-WebRequest -Uri $libXml2Url -OutFile $archivePath

Write-Host "Extracting libxml2"
Invoke-Checked tar @('-xJf', $archivePath, '-C', $sourceRoot)

$libXml2SourceDir = Get-ChildItem -Path $sourceRoot -Directory | Select-Object -First 1
if ($null -eq $libXml2SourceDir) {
    throw "Unable to locate extracted libxml2 source directory."
}

if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}

function Invoke-LibXml2Build {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("Release", "Debug")][string]$BuildType,
        [Parameter(Mandatory = $true)][string]$BuildPath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    $configure = 'cmake -S "{0}" -B "{1}" -G Ninja -DCMAKE_BUILD_TYPE={2} -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX="{3}" -DLIBXML2_WITH_ICONV=OFF -DLIBXML2_WITH_ZLIB=OFF -DLIBXML2_WITH_PROGRAMS=OFF -DLIBXML2_WITH_TESTS=OFF -DLIBXML2_WITH_PYTHON=OFF' -f $libXml2SourceDir.FullName, $BuildPath, $BuildType, $DestinationPath
    $build = 'cmake --build "{0}" --parallel' -f $BuildPath
    $install = 'cmake --install "{0}"' -f $BuildPath

    Write-Host "Configuring and building libxml2 ($BuildType)"
    Invoke-VsDevShellCommand -Command $configure
    Invoke-VsDevShellCommand -Command $build
    Invoke-VsDevShellCommand -Command $install
}

Invoke-LibXml2Build -BuildType "Release" -BuildPath $releaseBuildPath -DestinationPath $installPath

if ($debugModeEnabled) {
    Invoke-LibXml2Build -BuildType "Debug" -BuildPath $debugBuildPath -DestinationPath $installPath

    $libXml2DebugPdb = Get-ChildItem -LiteralPath $debugBuildPath -Recurse -File -Filter "LibXml2.pdb" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $libXml2DebugPdb) {
        throw "Unable to locate libxml2 debug PDB 'LibXml2.pdb' under '$debugBuildPath'."
    }

    $targetLibPath = Join-Path $installPath "lib"
    New-Item -Path $targetLibPath -ItemType Directory -Force | Out-Null
    $libXml2DebugPdbTargetPath = Join-Path $targetLibPath $libXml2DebugPdb.Name
    Copy-Item -LiteralPath $libXml2DebugPdb.FullName -Destination $libXml2DebugPdbTargetPath -Force
    Write-Host "Installed libxml2 debug PDB: $libXml2DebugPdbTargetPath"
}

# Remove-Item -Path $workRoot -Recurse -Force
