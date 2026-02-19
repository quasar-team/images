$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\Common.ps1"
Assert-RequiredEnvVar -Name "LIBXSD_HOME"

$libXsdVersion = "4.2.0"
$libXsdUrl = "https://www.codesynthesis.com/download/xsd/4.2/libxsd-4.2.0.tar.gz"
$workRoot = "C:\libxsd-src"
$archivePath = "$workRoot\libxsd.tar.gz"
$sourceRoot = "$workRoot\source"
$installPath = [Environment]::GetEnvironmentVariable("LIBXSD_HOME")

Add-IssueSection "LIBXSD VERSION: $libXsdVersion"
Add-IssueSection "LIBXSD_HOME: $installPath"

if (Test-Path $workRoot) {
    Remove-Item -Path $workRoot -Recurse -Force
}
New-Item -Path $sourceRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading libxsd sources"
Invoke-WebRequest -Uri $libXsdUrl -OutFile $archivePath

Write-Host "Extracting libxsd"
Invoke-Checked tar @('-xzf', $archivePath, '-C', $sourceRoot)

$libXsdSourceDir = Get-ChildItem -Path $sourceRoot -Directory | Select-Object -First 1
if ($null -eq $libXsdSourceDir) {
    throw "Unable to locate extracted libxsd source directory."
}

$headersSourcePath = Join-Path $libXsdSourceDir.FullName "xsd"
if (-not (Test-Path $headersSourcePath)) {
    throw "Unable to locate libxsd headers in '$headersSourcePath'."
}

if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}

$includePath = Join-Path $installPath "include"
New-Item -Path $includePath -ItemType Directory -Force | Out-Null
Copy-Item -Path $headersSourcePath -Destination $includePath -Recurse -Force

Remove-Item -Path $workRoot -Recurse -Force
