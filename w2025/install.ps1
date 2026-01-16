$ErrorActionPreference = "Stop"

# Install chocolatey
Write-Host "Installing Chocolatey"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Miscelaneous dependencies
Write-Host "Installing base tools"
choco install -y --no-progress powershell-core python git git-lfs.install nano

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
Write-Host "Downloading Boost 1.90.0 installer"
$boostUrl = "https://archives.boost.io/release/1.90.0/binaries/boost_1_90_0-msvc-14.3-64.exe"
$boostInstaller = Join-Path $env:TEMP "boost_1_90_0-msvc-14.3-64.exe"
Invoke-WebRequest -Uri $boostUrl -OutFile $boostInstaller
Write-Host "Installing Boost to C:\boost"
Start-Process -FilePath $boostInstaller -ArgumentList '/DIR="C:\boost" /VERYSILENT /NORESTART' -Wait
Write-Host "Cleaning up Boost installer"
Remove-Item -Force $boostInstaller

# Pip dependencies
Write-Host "Refreshing environment and installing Python packages"
Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1
refreshenv

python -m pip install pybind11 pytest

# Clean up
Write-Host "Cleaning Chocolatey cache"
choco cache remove
