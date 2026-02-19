$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\Common.ps1"
Assert-RequiredEnvVar -Name "LIBXML2_HOME"

$libXml2Version = "2.15.1"
$libXml2Url = "https://download.gnome.org/sources/libxml2/2.15/libxml2-2.15.1.tar.xz"
$workRoot = "C:\libxml2-src"
$archivePath = "$workRoot\libxml2.tar.xz"
$sourceRoot = "$workRoot\source"
$buildPath = "$workRoot\build"
$installPath = [Environment]::GetEnvironmentVariable("LIBXML2_HOME")

Add-IssueSection "LIBXML2 VERSION: $libXml2Version"
Add-IssueSection "LIBXML2_HOME: $installPath"

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

if (Test-Path $buildPath) {
    Remove-Item -Path $buildPath -Recurse -Force
}
if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}

$configure = 'cmake -S "{0}" -B "{1}" -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX="{2}" -DLIBXML2_WITH_ICONV=OFF -DLIBXML2_WITH_ZLIB=OFF -DLIBXML2_WITH_PROGRAMS=OFF -DLIBXML2_WITH_TESTS=OFF -DLIBXML2_WITH_PYTHON=OFF' -f $libXml2SourceDir.FullName, $buildPath, $installPath
$build = 'cmake --build "{0}" --parallel' -f $buildPath
$install = 'cmake --install "{0}"' -f $buildPath

Write-Host "Configuring and building libxml2"
Invoke-VsDevShellCommand -Command $configure
Invoke-VsDevShellCommand -Command $build
Invoke-VsDevShellCommand -Command $install

Remove-Item -Path $workRoot -Recurse -Force
