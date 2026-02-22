$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Assert-RequiredEnvVar -Name "XSD_HOME"

$libXsdVersion = "4.2.0"
$libXsdUrl = "https://www.codesynthesis.com/download/xsd/4.2/libxsd-4.2.0.tar.gz"
$workRoot = "C:\libxsd-src"
$archivePath = "$workRoot\libxsd.tar.gz"
$sourceRoot = "$workRoot\source"
$installPath = [Environment]::GetEnvironmentVariable("XSD_HOME")
$targetHeadersPath = Join-Path $installPath "include\xsd\cxx"

Add-IssueSection "LIBXSD VERSION: $libXsdVersion"
Add-IssueSection "XSD_HOME (headers): $targetHeadersPath"

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

$headersSourcePath = Join-Path $libXsdSourceDir.FullName "xsd\cxx"
if (-not (Test-Path $headersSourcePath)) {
    throw "Unable to locate libxsd C++ headers in '$headersSourcePath'."
}

New-Item -Path $targetHeadersPath -ItemType Directory -Force | Out-Null
Copy-Item -Path (Join-Path $headersSourcePath "*") -Destination $targetHeadersPath -Recurse -Force

Remove-Item -Path $workRoot -Recurse -Force
