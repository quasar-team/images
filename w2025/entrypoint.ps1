# Stop execution on PowerShell snippet errors.
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "c:\scripts\Common.ps1"

# For external commands, explicitly check $LASTEXITCODE after execution.
$issuePath = "C:\ISSUE\ISSUE.txt"
if (-not (Test-Path -Path $issuePath)) {
    Write-Host "ISSUE file is not available at $issuePath"
    exit 1
}

# Add XSD tool directory to PATH for subsequent commands.
$xsdHome = [Environment]::GetEnvironmentVariable("XSD_HOME")
if (-not $xsdHome) {
    Write-Host "XSD_HOME environment variable is not set."
    exit 1
}

$xsdToolCandidates = @(
    (Join-Path $xsdHome "xsdcxx.exe")
)
$xsdExecutable = $xsdToolCandidates | Where-Object { Test-Path -Path $_ } | Select-Object -First 1
if (-not $xsdExecutable) {
    Write-Host "Unable to locate xsdcxx.exe under $xsdHome"
    exit 1
}
$xsdToolsPath = Split-Path -Parent $xsdExecutable
$env:PATH = "$xsdToolsPath;$env:PATH"

Write-Host "Printing issue file"
Get-Content $issuePath

# Import VS toolchain env into this PowerShell process.
Import-VsDevCmdEnvironment -Arch x64 -HostArch x64

if ($args.Count -eq 0) {
    pwsh -NoLogo
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Entrypoint interactive shell failed with code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    exit 0
}

$command = $args -join " "
pwsh -NoLogo -NoProfile -Command $command
if ($LASTEXITCODE -ne 0) {
    Write-Host "Entrypoint executed command failed with code $LASTEXITCODE"
    exit $LASTEXITCODE
}
