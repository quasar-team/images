$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\Common.ps1"
Assert-RequiredEnvVar -Name "XERCES_C_HOME"

$xercesCVersion = "3.3.0"
$xercesCUrl = "https://archive.apache.org/dist/xerces/c/3/sources/xerces-c-3.3.0.tar.gz"
$workRoot = "C:\xerces-c-src"
$archivePath = "$workRoot\xerces-c.tar.gz"
$sourceRoot = "$workRoot\source"
$buildPath = "$workRoot\build"
$installPath = [Environment]::GetEnvironmentVariable("XERCES_C_HOME")

Add-IssueSection "XERCES-C++ VERSION: $xercesCVersion"
Add-IssueSection "XERCES_C_HOME: $installPath"

if (Test-Path $workRoot) {
    Remove-Item -Path $workRoot -Recurse -Force
}
New-Item -Path $sourceRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading Xerces-C++ sources"
Invoke-WebRequest -Uri $xercesCUrl -OutFile $archivePath

Write-Host "Extracting Xerces-C++"
Invoke-Checked tar @('-xzf', $archivePath, '-C', $sourceRoot)

$xercesSourceDir = Get-ChildItem -Path $sourceRoot -Directory | Select-Object -First 1
if ($null -eq $xercesSourceDir) {
    throw "Unable to locate extracted Xerces-C++ source directory."
}

if (Test-Path $buildPath) {
    Remove-Item -Path $buildPath -Recurse -Force
}
if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}

$configureArgs = @(
    '-S', $xercesSourceDir.FullName,
    '-B', $buildPath,
    '-G', 'Ninja',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DBUILD_SHARED_LIBS=OFF',
    "-DCMAKE_INSTALL_PREFIX=$installPath"
)

Write-Host "Configuring and building Xerces-C++"
Invoke-Checked cmake $configureArgs
Invoke-Checked cmake @('--build', $buildPath, '--parallel')
Invoke-Checked cmake @('--install', $buildPath)

Remove-Item -Path $workRoot -Recurse -Force
