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

$configureArgs = @(
    '-S', $libXml2SourceDir.FullName,
    '-B', $buildPath,
    '-G', 'Ninja',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DBUILD_SHARED_LIBS=OFF',
    "-DCMAKE_INSTALL_PREFIX=$installPath",
    '-DLIBXML2_WITH_ICONV=OFF',
    '-DLIBXML2_WITH_ZLIB=OFF',
    '-DLIBXML2_WITH_PROGRAMS=OFF',
    '-DLIBXML2_WITH_TESTS=OFF',
    '-DLIBXML2_WITH_PYTHON=OFF'
)

Write-Host "Configuring and building libxml2"
Invoke-Checked cmake $configureArgs
Invoke-Checked cmake @('--build', $buildPath, '--parallel')
Invoke-Checked cmake @('--install', $buildPath)

Remove-Item -Path $workRoot -Recurse -Force
