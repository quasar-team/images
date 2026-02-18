$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\Common.ps1"
Assert-RequiredEnvVar -Name "XSD_HOME"

$xsdVersion = "4.2.0"
$xsdWindowsPackageUrl = "https://www.codesynthesis.com/download/xsd/4.2/windows/windows10/x86_64/xsd-4.2.0-x86_64-windows10.zip"
$workRoot = "C:\xsd-src"
$archivePath = "$workRoot\xsd.zip"
$extractPath = "$workRoot\extract"
$installPath = [Environment]::GetEnvironmentVariable("XSD_HOME")

Add-IssueSection "XSD VERSION: $xsdVersion"
Add-IssueSection "XSD_HOME: $installPath"

if (Test-Path $workRoot) {
    Remove-Item -Path $workRoot -Recurse -Force
}
New-Item -Path $extractPath -ItemType Directory -Force | Out-Null

Write-Host "Downloading XSD package"
Invoke-WebRequest -Uri $xsdWindowsPackageUrl -OutFile $archivePath

Write-Host "Extracting XSD package"
Expand-Archive -Path $archivePath -DestinationPath $extractPath -Force

$xsdExecutable = Get-ChildItem -Path $extractPath -Filter "xsd.exe" -Recurse -File | Select-Object -First 1
if ($null -eq $xsdExecutable) {
    throw "Unable to locate xsd.exe in extracted package."
}

if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}
New-Item -Path $installPath -ItemType Directory -Force | Out-Null

$xsdExePath = Join-Path $installPath "xsd.exe"
Copy-Item -Path $xsdExecutable.FullName -Destination $xsdExePath -Force
Rename-Item -Path $xsdExePath -NewName "xsdcpp.exe"

$xsdCppPath = Join-Path $installPath "xsdcpp.exe"
Add-IssueSection "XSD EXECUTABLE: $xsdCppPath"

Remove-Item -Path $workRoot -Recurse -Force
