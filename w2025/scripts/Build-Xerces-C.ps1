$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Assert-RequiredEnvVar -Name "XERCES_C_HOME"

$xercesCVersion = "3.3.0"
$xercesCUrl = "https://archive.apache.org/dist/xerces/c/3/sources/xerces-c-3.3.0.tar.gz"
$workRoot = "C:\xerces-c-src"
$archivePath = "$workRoot\xerces-c.tar.gz"
$sourceRoot = "$workRoot\source"
$buildPath = "$workRoot\build"
$installPath = [Environment]::GetEnvironmentVariable("XERCES_C_HOME")

Add-IssueSection "XERCES-C++ VERSION: $xercesCVersion"
Add-IssueSection "XERCES_C_HOME: $installPath"

if (Test-Path $workRoot) {
    Remove-Item -Path $workRoot -Recurse -Force
}
New-Item -Path $sourceRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading Xerces-C++ sources"
Invoke-WebRequest -Uri $xercesCUrl -OutFile $archivePath

Write-Host "Extracting Xerces-C++"
Invoke-Checked tar @('-xzf', $archivePath, '-C', $sourceRoot)

$xercesSourceDir = Get-ChildItem -Path $sourceRoot -Directory | Select-Object -First 1
if ($null -eq $xercesSourceDir) {
    throw "Unable to locate extracted Xerces-C++ source directory."
}

if (Test-Path $buildPath) {
    Remove-Item -Path $buildPath -Recurse -Force
}
if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}

$configure = 'cmake -S "{0}" -B "{1}" -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_INSTALL_PREFIX="{2}"' -f $xercesSourceDir.FullName, $buildPath, $installPath
$build = 'cmake --build "{0}" --parallel' -f $buildPath
$install = 'cmake --install "{0}"' -f $buildPath

Write-Host "Configuring and building Xerces-C++"
Invoke-VsDevShellCommand -Command $configure
Invoke-VsDevShellCommand -Command $build
Invoke-VsDevShellCommand -Command $install

Remove-Item -Path $workRoot -Recurse -Force
Remove-Item -Path $installPath/share -Recurse -Force
