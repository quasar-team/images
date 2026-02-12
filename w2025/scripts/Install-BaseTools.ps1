$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot\Common.ps1"

Write-Host "Installing Chocolatey"
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

Write-Host "Installing base tools"
Invoke-Checked choco @('install', '-y', '--no-progress', 'powershell-core', 'python', 'git', 'git-lfs.install', 'nano', '7zip')

Write-Host "Installing CMake and Ninja"
Invoke-Checked choco @('install', '-y', '--no-progress', 'cmake', '--installargs', 'ADD_CMAKE_TO_PATH=System')
Invoke-Checked choco @('install', '-y', '--no-progress', 'ninja')

Write-Host "Installing Visual Studio Build Tools"
Invoke-Checked choco @('install', '-y', '--no-progress', 'visualstudio2026buildtools')
Invoke-Checked choco @('install', '-y', '--no-progress', 'visualstudio2026-workload-vctools')

Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
refreshenv

Write-Host "Cleaning Chocolatey cache"
Invoke-Checked choco @('cache', 'remove')

Write-Host "Installing Python packages"
Invoke-Checked python @('-m', 'pip', 'install', '--upgrade', 'pip')
Invoke-Checked python @('-m', 'pip', 'install', '--no-cache-dir', 'pybind11', 'pytest', 'colorama')

$osCaption = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
Add-IssueSection "OS: $osCaption"
Add-IssueSection "Ninja Version: $(ninja --version)"
$cmakeFirstLine = (cmake --version | Select-Object -First 1)
Add-IssueSection "$cmakeFirstLine"
