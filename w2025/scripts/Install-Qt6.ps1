<#
.SYNOPSIS
Installs the official shared Qt 6 Windows package into C:\Qt6 for Visual Studio 2026 builds by using the Qt Online Installer command line interface.

.DESCRIPTION
This script downloads the official Qt Online Installer from download.qt.io, runs it in
unattended mode from the command line, and promotes the installed MSVC payload into C:\Qt6.
It then sets QT6_HOME to that location for both the current process and the machine
environment.

The requested Qt functionality is limited to Qt base and Qt network because the only current
dependency using Qt is the ISEG HAL. However, as of 2026-03-25, Qt's official online
installer package granularity for Windows provides the MSVC 2022 x64 desktop package
`qt.qt6.6110.win64_msvc2022_64`, which includes `qtbase` and additional essential
archives. The script uses that official package because it is the supported command-line
installation path documented by Qt.
#>
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonScript = Join-Path $scriptRoot "Common.ps1"
if (-not (Test-Path -LiteralPath $commonScript -PathType Leaf)) {
    throw "Common helper script not found: $commonScript"
}

. $commonScript

function Get-QtOnlineInstallerArgs {
    $jwtToken = [Environment]::GetEnvironmentVariable("QT_INSTALLER_JWT_TOKEN")
    if (-not [string]::IsNullOrWhiteSpace($jwtToken)) {
        return @()
    }

    throw "Qt Online Installer requires login. Set QT_INSTALLER_JWT_TOKEN before running this script."
}

$qtVersion = "6.11.0"
$qtPackageName = "qt.qt6.6110.win64_msvc2022_64"
$qtOnlineInstallerUrl = "https://download.qt.io/official_releases/online_installers/qt-online-installer-windows-x64-online.exe"
$workRoot = "C:\qt6-src"
$installerPath = Join-Path $workRoot "qt-online-installer-windows-x64-online.exe"
$installerRoot = Join-Path $workRoot "qt-online-root"
$installedQtRoot = Join-Path $installerRoot "$qtVersion\msvc2022_64"
$installPath = "C:\Qt6"

if (-not (Test-Path -LiteralPath "C:\ISSUE\ISSUE.txt" -PathType Leaf)) {
    Initialize-IssueFile
}

Add-IssueSection "QT6 VERSION: $qtVersion"
Add-IssueSection "QT6 PACKAGE: $qtPackageName"
Add-IssueSection "QT6 INSTALLER: qt-online-installer-windows-x64-online.exe"
Add-IssueSection "QT6 ONLY DEPENDENCY: ISEG HAL"
Add-IssueSection "QT6_HOME: $installPath"

[Environment]::SetEnvironmentVariable("QT6_HOME", $installPath, "Process")
[Environment]::SetEnvironmentVariable("QT6_HOME", $installPath, "Machine")
$env:QT6_HOME = $installPath

if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -Path $workRoot -Recurse -Force
}
New-Item -Path $installerRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading Qt Online Installer"
Invoke-Checked "curl.exe" @("-L", "-o", $installerPath, $qtOnlineInstallerUrl)

$loginArgs = Get-QtOnlineInstallerArgs
$installerArgs = @(
    "--root", $installerRoot,
    "--accept-licenses",
    "--accept-obligations",
    "--default-answer",
    "--confirm-command"
) + $loginArgs + @(
    "install",
    $qtPackageName
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
    (Join-Path $installPath "lib\Qt6Core.lib"),
    (Join-Path $installPath "lib\Qt6Network.lib"),
    (Join-Path $installPath "bin\Qt6Core.dll"),
    (Join-Path $installPath "bin\Qt6Network.dll"),
    (Join-Path $installPath "lib\cmake\Qt6\Qt6Config.cmake"),
    (Join-Path $installerRoot "MaintenanceTool.exe")
)

foreach ($path in $requiredPaths) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Validation failed: expected Qt path '$path' was not created."
    }
}

Remove-Item -Path $workRoot -Recurse -Force

Write-Host "Qt 6 installed successfully."
Write-Host "QT6_HOME: $installPath"
