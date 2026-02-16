$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "Starting Windows image cleanup"

# These are safe
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "Cleaning Chocolatey cache"
    choco cache remove
}

$keep = "entrypoint.ps1"
Get-ChildItem -Path "C:\" -Filter "*.ps1" -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne $keep } |
    Remove-Item -Force -ErrorAction SilentlyContinue

# Call System Clean-Up
$volumeCacheRoot = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
if (Test-Path $volumeCacheRoot) {
    Get-ItemProperty -Path "$volumeCacheRoot\*" -ErrorAction SilentlyContinue | ForEach-Object {
        New-ItemProperty -Path $_.PSPath -Name StateFlags0001 -Value 2 -PropertyType DWord -Force | Out-Null
    }
}

if (Get-Command CleanMgr.exe -ErrorAction SilentlyContinue) {
    Start-Process -FilePath CleanMgr.exe -ArgumentList "/sagerun:1" -Wait -NoNewWindow
}

# Remove temp files and caches
$pipCacheDir = Join-Path $env:USERPROFILE "AppData\Local\pip\Cache"
$pathsToDelete = @(
    "C:\Users\ContainerAdministrator\AppData\Local\Temp\chocolatey",
    "$env:TEMP\*",
    "C:\Windows\Temp\*",
    "C:\.env",
    "C:\Program Files (x86)\Microsoft\EdgeUpdate\Install",
    "C:\Program Files (x86)\Microsoft\EdgeUpdate\Download",
    $pipCacheDir
)

foreach ($path in $pathsToDelete) {
    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
}

# Remove Windows Installer cache artifacts
Get-ChildItem "C:\Windows\Installer" -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -match '^\.(msi|msp|exe|exe_64)$' } |
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "Windows image cleanup completed"
