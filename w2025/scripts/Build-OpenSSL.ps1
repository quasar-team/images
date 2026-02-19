$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\Common.ps1"
Assert-RequiredEnvVar -Name "LIBSSL_HOME"

Invoke-Checked choco @('install', '-y', '--no-progress', 'strawberryperl', 'nasm')
refreshenv

$openSslVersion = "3.5.5"
$openSslUrl = "https://github.com/openssl/openssl/releases/download/openssl-3.5.5/openssl-3.5.5.tar.gz"
$workRoot = "C:\openssl-src"
$archivePath = "$workRoot\openssl.tar.gz"
$sourceRoot = "$workRoot\source"
$installPath = [Environment]::GetEnvironmentVariable("LIBSSL_HOME")

Add-IssueSection "OPENSSL VERSION: $openSslVersion"
Add-IssueSection "LIBSSL_HOME: $installPath"

if (Test-Path $workRoot) {
    Remove-Item -Path $workRoot -Recurse -Force
}
New-Item -Path $sourceRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading OpenSSL sources"
Invoke-WebRequest -Uri $openSslUrl -OutFile $archivePath

Write-Host "Extracting OpenSSL"
Invoke-Checked tar @('-xzf', $archivePath, '-C', $sourceRoot)

$openSslSourceDir = Get-ChildItem -Path $sourceRoot -Directory | Select-Object -First 1
if ($null -eq $openSslSourceDir) {
    throw "Unable to locate extracted OpenSSL source directory."
}

if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}
New-Item -Path $installPath -ItemType Directory -Force | Out-Null

$prefixForConfigure = $installPath -replace '\\', '/'
$configure = 'cd /d "{0}" && perl Configure VC-WIN64A no-shared no-apps --prefix="{1}" --openssldir="{2}"' -f `
  $openSslSourceDir.FullName, $prefixForConfigure, "$prefixForConfigure/ssl"
$build = 'cd /d "{0}" && nmake /nologo' -f $openSslSourceDir.FullName
$install = 'cd /d "{0}" && nmake /nologo install_sw' -f $openSslSourceDir.FullName

Write-Host "Configuring and building OpenSSL"
Invoke-VsDevShellCommand -Command $configure
Invoke-VsDevShellCommand -Command $build
Invoke-VsDevShellCommand -Command $install

Remove-Item -Path $workRoot -Recurse -Force

Invoke-Checked choco @('uninstall', '-y', '--no-progress', 'strawberryperl', 'nasm')
refreshenv
