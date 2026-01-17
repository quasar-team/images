$ErrorActionPreference = "Stop"

# Install chocolatey
Write-Host "Installing Chocolatey"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Miscelaneous dependencies
Write-Host "Installing base tools"
choco install -y --no-progress powershell-core python git git-lfs.install nano 7zip

# Install CMake and Ninja
Write-Host "Installing CMake"
choco install -y --no-progress cmake --installargs 'ADD_CMAKE_TO_PATH=System'
Write-Host "Installing Ninja"
choco install -y --no-progress ninja

# Visual Studio 2026 Build Tools
Write-Host "Installing Visual Studio 2026 Build Tools"
choco install -y --no-progress visualstudio2026buildtools
Write-Host "Installing Visual Studio 2026 VC++ workload"
choco install -y --no-progress visualstudio2026-workload-vctools

# Boost
$boostVersion = "1.90.0"
$boostVersionUnderscore = $boostVersion.Replace(".", "_")
$boostZip = "boost_$boostVersionUnderscore.zip"
$boostUrl = "https://archives.boost.io/release/$boostVersion/source/$boostZip"
$boostSrcDir = "C:\boost-src\"
$boostInstallDir = "C:\boost"

Write-Host "Downloading Boost $boostVersion"
New-Item -ItemType Directory -Force -Path $boostSrcDir | Out-Null
cd $boostSrcDir
curl $boostUrl -o $boostZip
."C:\Program Files\7-Zip\7z.exe" x $boostZip

$boostSourceDir = Join-Path $boostSrcDir "boost_$boostVersionUnderscore"
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vcvarsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find **\VC\Auxiliary\Build\vcvars64.bat
if (-not $vcvarsPath) {
  throw "Could not locate vcvars64.bat via vswhere."
}

Write-Host "Building Boost with MSVC"
cmd /c "`"$vcvarsPath`" && cd /d `"$boostSourceDir`" && bootstrap.bat && b2 -j%NUMBER_OF_PROCESSORS% link=static runtime-link=static variant=release threading=multi --prefix=`"$boostInstallDir`" install"

Write-Host "Cleaning Boost build artifacts"
cd \
Remove-Item -Recurse -Force $boostSrcDir

# Pip dependencies
Write-Host "Refreshing environment and installing Python packages"
Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1
refreshenv

python -m pip install pybind11 pytest

# Clean up
Write-Host "Cleaning Chocolatey cache"
choco cache remove
