$ErrorActionPreference = "Stop"

# Setting environment variables
.\Load-DotEnv-File.ps1

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
$url = "https://ics-deps-repo.web.cern.ch/quasar/boost/boost_1_90_0-vs2026_static.zip"
$outputFolder = "C:\"

# Download the file
Invoke-WebRequest -Headers @{"PRIVATE-TOKEN" = "${env:ICS_REPO_DEPS_TOKEN}"} -Uri $url -OutFile "$outputFolder\boost.zip"

# Extract the contents of the zip file to the output folder
Expand-Archive -Path "$outputFolder\boost.zip" -DestinationPath $outputFolder -Force

Write-Host "Boost Libraries installed"
Write-Host "Deleting Boost zip file"
rm "$outputFolder\boost.zip"


# Pip dependencies
Write-Host "Refreshing environment and installing Python packages"
Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1
refreshenv

python -m pip install pybind11 pytest

# Clean up
Write-Host "Cleaning Chocolatey cache"
choco cache remove
