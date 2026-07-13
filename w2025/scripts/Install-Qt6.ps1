$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Assert-RequiredEnvVar -Name "QT_ACCOUNT_EMAIL"
Assert-RequiredEnvVar -Name "QT_ACCOUNT_PASSWORD"

$qtScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$qtCommonScript = Join-Path $qtScriptRoot "Common.ps1"
if (-not (Test-Path -LiteralPath $qtCommonScript -PathType Leaf)) {
    throw "Common helper script not found: $qtCommonScript"
}

. $qtCommonScript

$qtUsername = [Environment]::GetEnvironmentVariable("QT_ACCOUNT_EMAIL")
$qtPassword = [Environment]::GetEnvironmentVariable("QT_ACCOUNT_PASSWORD")
$qtVersion = "6.11.1"
$qtPackageName = "qt.qt6.6111.win64_msvc2022_64"
$qt5CompatPackageName = "qt.qt6.6111.addons.qt5compat"
$installPath = "C:\qt6"
$qtOnlineInstallerUrl = "https://download.qt.io/official_releases/online_installers/qt-online-installer-windows-x64-online.exe"
$workRoot = "C:\qt6-src"
$installerPath = Join-Path $workRoot "qt-online-installer-windows-x64-online.exe"
$installerRoot = Join-Path $workRoot "qt-online-root"
$installedQtRoot = Join-Path $installerRoot "$qtVersion\msvc2022_64"

if (-not (Test-Path -LiteralPath "C:\ISSUE\ISSUE.txt" -PathType Leaf)) {
    Initialize-IssueFile
}

Add-IssueSection "QT6 VERSION: $qtVersion"
Add-IssueSection "QT6_HOME: $installPath"

$env:QT6_HOME = $installPath

if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -Path $workRoot -Recurse -Force
}
New-Item -Path $installerRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading Qt Online Installer"
Invoke-WebRequest -Uri $qtOnlineInstallerUrl -OutFile $installerPath

$installerArgs = @(
    "--root", $installerRoot,
    "--email", $qtUsername,
    "--pw", $qtPassword,
    "--accept-licenses",
    "--accept-obligations",
    "--default-answer",
    "--confirm-command",
    "install",
    $qtPackageName,
    $qt5CompatPackageName
)

Write-Host "Installing Qt 6 with Qt Online Installer CLI"
Invoke-Checked $installerPath $installerArgs

if (-not (Test-Path -LiteralPath $installedQtRoot -PathType Container)) {
    throw "Qt Online Installer completed but expected installed Qt directory '$installedQtRoot' was not created."
}

if (Test-Path -LiteralPath $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}
New-Item -Path $installPath -ItemType Directory -Force | Out-Null

Write-Host "Installing Qt 6 into $installPath"
Copy-Item -Path (Join-Path $installedQtRoot "*") -Destination $installPath -Recurse -Force

$requiredPaths = @(
    (Join-Path $installPath "include\QtCore"),
    (Join-Path $installPath "include\QtNetwork"),
    (Join-Path $installPath "include\QtCore5Compat"),
    (Join-Path $installPath "lib\Qt6Core.lib"),
    (Join-Path $installPath "lib\Qt6Network.lib"),
    (Join-Path $installPath "lib\Qt6Core5Compat.lib"),
    (Join-Path $installPath "bin\Qt6Core.dll"),
    (Join-Path $installPath "bin\Qt6Network.dll"),
    (Join-Path $installPath "bin\Qt6Core5Compat.dll")
)

foreach ($path in $requiredPaths) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Validation failed: expected Qt path '$path' was not created."
    }
}

Remove-Item -Path $workRoot -Recurse -Force

Write-Host "Qt 6 installed successfully."
Write-Host "QT6_HOME: $installPath"
