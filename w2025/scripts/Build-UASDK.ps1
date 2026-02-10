$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\Common.ps1"

Assert-RequiredEnvVar -Name "ICS_REPO_DEPS_TOKEN"

$uasdkVersion = "2.0.2-675"
$uasdkUrl = "https://ics-deps-repo.web.cern.ch/quasar/uasdk/2.0.2-675/uasdkcppbundle-src-windows-v2.0.2-675.zip"
$workRoot = "C:\uasdk-src"
$archivePath = "$workRoot\uasdk.zip"
$sourceRoot = "$workRoot\source"
$buildPath = "$workRoot\build"
$installPath = "C:\unified-automation"

Add-IssueSection "UNIFIED AUTOMATION UASDK VERSION: $uasdkVersion"

if (Test-Path $workRoot) {
    Remove-Item -Path $workRoot -Recurse -Force
}
New-Item -Path $sourceRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading UASDK"
Invoke-WebRequest -Headers @{ "PRIVATE-TOKEN" = "$env:ICS_REPO_DEPS_TOKEN" } -Uri $uasdkUrl -OutFile $archivePath

Write-Host "Extracting UASDK"
Expand-Archive -Path $archivePath -DestinationPath $sourceRoot -Force

$cmakeListsFile = Get-ChildItem -Path $sourceRoot -Filter "CMakeLists.txt" -Recurse -File |
    Sort-Object { $_.FullName.Length } |
    Select-Object -First 1

if ($null -eq $cmakeListsFile) {
    throw "Unable to find CMakeLists.txt in extracted UASDK sources."
}

$resolvedSourcePath = Split-Path -Path $cmakeListsFile.FullName -Parent

if (Test-Path $buildPath) {
    Remove-Item -Path $buildPath -Recurse -Force
}
if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}

$configure = 'cmake -S "{0}" -B "{1}" -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX="{2}"' -f $resolvedSourcePath, $buildPath, $installPath
$build = 'cmake --build "{0}" --parallel' -f $buildPath
$install = 'cmake --install "{0}"' -f $buildPath

Write-Host "Configuring and building UASDK"
Invoke-VsDevShellCommand -Command $configure
Invoke-VsDevShellCommand -Command $build
Invoke-VsDevShellCommand -Command $install

$thirdPartyDir = Get-ChildItem -Path $sourceRoot -Directory -Recurse |
    Where-Object { $_.Name -eq "third-party" } |
    Sort-Object { $_.FullName.Length } |
    Select-Object -First 1

if ($null -eq $thirdPartyDir) {
    throw "Unable to find third-party directory in extracted UASDK sources."
}

$thirdPartyInstallPath = Join-Path $installPath "third-party"
Write-Host "Copying UASDK third-party folder to install path"
Copy-Item -Path $thirdPartyDir.FullName -Destination $thirdPartyInstallPath -Recurse -Force

Remove-Item -Path $workRoot -Recurse -Force
