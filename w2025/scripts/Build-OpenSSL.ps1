$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Assert-RequiredEnvVar -Name "LIBSSL_HOME"

$openSslVersion = "3.5.7"
$openSslUrl = "https://github.com/openssl/openssl/releases/download/openssl-3.5.7/openssl-3.5.7.tar.gz"
$workRoot = "C:\openssl-src"
$archivePath = "$workRoot\openssl.tar.gz"
$sourceRoot = "$workRoot\source"
$debugSourceRoot = "$workRoot\source-debug"
$debugInstallPath = "$workRoot\install-debug"
$installPath = [Environment]::GetEnvironmentVariable("LIBSSL_HOME")
$debugModeEnabled = Test-DebugModeEnabled

Add-IssueSection "OPENSSL VERSION: $openSslVersion"
Add-IssueSection "LIBSSL_HOME: $installPath"
Add-IssueSection "OPENSSL DEBUG BUILD: $debugModeEnabled"

if (Test-Path $workRoot) {
    Remove-Item -Path $workRoot -Recurse -Force
}
New-Item -Path $sourceRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading OpenSSL sources"
Invoke-WebRequest -Uri $openSslUrl -OutFile $archivePath

Write-Host "Extracting OpenSSL"
Invoke-Checked tar @('-xzf', $archivePath, '-C', $sourceRoot)

function Get-OpenSslSourceDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath
    )

    $sourceDir = Get-ChildItem -Path $RootPath -Directory | Select-Object -First 1
    if ($null -eq $sourceDir) {
        throw "Unable to locate extracted OpenSSL source directory under '$RootPath'."
    }

    return $sourceDir
}

function Invoke-OpenSslBuild {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][bool]$IsDebug
    )

    New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null

    $prefixForConfigure = $DestinationPath -replace '\\', '/'
    $buildTypeOptions = if ($IsDebug) { "--debug -MDd" } else { "-MD" }
    $configure = 'cd /d "{0}" && perl Configure threads no-tests no-apps no-shared {1} VC-WIN64A --prefix="{2}" --openssldir="{3}"' -f `
      $SourcePath, $buildTypeOptions, $prefixForConfigure, "$prefixForConfigure/ssl"
    $build = 'cd /d "{0}" && nmake' -f $SourcePath
    $install = 'cd /d "{0}" && nmake install_sw' -f $SourcePath

    $label = if ($IsDebug) { "Debug" } else { "Release" }
    Write-Host "Configuring and building OpenSSL ($label)"
    Invoke-VsDevShellCommand -Command $configure
    Invoke-VsDevShellCommand -Command $build
    Invoke-VsDevShellCommand -Command $install
}

if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}

$openSslSourceDir = Get-OpenSslSourceDirectory -RootPath $sourceRoot
Invoke-OpenSslBuild -SourcePath $openSslSourceDir.FullName -DestinationPath $installPath -IsDebug $false

if ($debugModeEnabled) {
    New-Item -Path $debugSourceRoot -ItemType Directory -Force | Out-Null
    Invoke-Checked tar @('-xzf', $archivePath, '-C', $debugSourceRoot)
    $openSslDebugSourceDir = Get-OpenSslSourceDirectory -RootPath $debugSourceRoot

    Invoke-OpenSslBuild -SourcePath $openSslDebugSourceDir.FullName -DestinationPath $debugInstallPath -IsDebug $true
    $debugLibraries = Copy-DebugBuildArtifacts `
        -DebugInstallPath $debugInstallPath `
        -InstallPath $installPath
    Write-Host "Installed OpenSSL debug libraries: $($debugLibraries -join ', ')"
}

Remove-Item -Path $workRoot -Recurse -Force
