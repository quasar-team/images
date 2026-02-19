$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\Common.ps1"
Assert-RequiredEnvVar -Name "OPEN6_HOME"

$open6Version = "1.5.0"
$open6Url = "https://github.com/open62541/open62541/archive/refs/tags/v1.5.0.tar.gz"
$workRoot = "C:\open6-src"
$archivePath = "$workRoot\open6.tar.gz"
$sourceRoot = "$workRoot\source"
$buildPath = "$workRoot\build"
$installPath = [Environment]::GetEnvironmentVariable("OPEN6_HOME")

Add-IssueSection "OPEN6 VERSION: $open6Version"
Add-IssueSection "OPEN6_HOME: $installPath"

if (Test-Path $workRoot) {
    Remove-Item -Path $workRoot -Recurse -Force
}
New-Item -Path $sourceRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading Open6 sources"
Invoke-WebRequest -Uri $open6Url -OutFile $archivePath

Write-Host "Extracting Open6"
Invoke-Checked tar @('-xzf', $archivePath, '-C', $sourceRoot)

$open6SourceDir = Get-ChildItem -Path $sourceRoot -Directory | Select-Object -First 1
if ($null -eq $open6SourceDir) {
    throw "Unable to locate extracted Open6 source directory."
}

if (Test-Path $buildPath) {
    Remove-Item -Path $buildPath -Recurse -Force
}
if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}

$openSslHomeForCMake = $env:LIBSSL_HOME -replace '\\', '/'


$configureArgs = @(
    '-S', $open6SourceDir.FullName,
    '-B', $buildPath,
    '-G', 'Ninja',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DBUILD_SHARED_LIBS=OFF',
    "-DOPENSSL_ROOT_DIR=$openSslHomeForCMake",
    '-DOPENSSL_USE_STATIC_LIBS=TRUE',
    '-DUA_ENABLE_ENCRYPTION=OPENSSL',
    "-DCMAKE_INSTALL_PREFIX=$installPath"
)

Write-Host "Configuring and building Open6"
Invoke-Checked cmake $configureArgs
Invoke-Checked cmake @('--build', $buildPath, '--parallel')
Invoke-Checked cmake @('--install', $buildPath)

Remove-Item -Path $workRoot -Recurse -Force
