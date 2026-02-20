$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest


Assert-RequiredEnvVar -Name "ICS_REPO_DEPS_TOKEN"
Assert-RequiredEnvVar -Name "BOOST_HOME"

$boostVersion = "1.90.0"
$boostUrl = "https://ics-deps-repo.web.cern.ch/quasar/boost/boost_1_90_0_vs2026_static.zip"
$archivePath = "C:\boost.zip"
$tempExtractPath = "C:\boost-extract"
$installPath = [Environment]::GetEnvironmentVariable("BOOST_HOME")

Add-IssueSection "BOOST VERSION: $boostVersion"
Add-IssueSection "BOOST_HOME: $installPath"

Write-Host "Downloading Boost package"
Invoke-WebRequest -Headers @{ "PRIVATE-TOKEN" = "$env:ICS_REPO_DEPS_TOKEN" } -Uri $boostUrl -OutFile $archivePath

if (Test-Path $tempExtractPath) {
    Remove-Item -Path $tempExtractPath -Recurse -Force
}
New-Item -Path $tempExtractPath -ItemType Directory | Out-Null

Write-Host "Extracting Boost"
Expand-Archive -Path $archivePath -DestinationPath $tempExtractPath -Force

if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}
New-Item -Path $installPath -ItemType Directory | Out-Null

$extractEntries = @(Get-ChildItem -Path $tempExtractPath -Force)
if ($extractEntries.Count -eq 0) {
    throw "Boost archive extraction produced no files."
}

if ($extractEntries.Count -eq 1 -and $extractEntries[0].PSIsContainer) {
    Copy-Item -Path "$($extractEntries[0].FullName)\*" -Destination $installPath -Recurse -Force
} else {
    Copy-Item -Path "$tempExtractPath\*" -Destination $installPath -Recurse -Force
}

Write-Host "Cleaning Boost artifacts"
Remove-Item -Path $archivePath -Force
Remove-Item -Path $tempExtractPath -Recurse -Force
