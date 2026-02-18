# Stop execution on PowerShell snippet errors.
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# For external commands, explicitly check $LASTEXITCODE after execution.
$issuePath = "C:\ISSUE"
if (-not (Test-Path -Path $issuePath)) {
    Write-Host "ISSUE file is not available at $issuePath"
    exit 1
}

# Add XSD_HOME/bin to PATH for subsequent commands.
$xsdHome = [Environment]::GetEnvironmentVariable("XSD_HOME")
if (-not $xsdHome) {
    Write-Host "XSD_HOME environment variable is not set."
    exit 1
}
$xsdBinPath = Join-Path $xsdHome "bin"
if (-not (Test-Path -Path $xsdBinPath)) {
    Write-Host "XSD bin directory does not exist at $xsdBinPath"
    exit 1
}
$env:PATH = "$xsdBinPath;$env:PATH"

Write-Host "Printing issue file"
Get-Content $issuePath

if ($args.Count -eq 0) {
    pwsh -NoLogo
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Entrypoint interactive shell failed with code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    exit 0
}

pwsh -Command $args
if ($LASTEXITCODE -ne 0) {
    Write-Host "Entrypoint executed command failed with code $LASTEXITCODE"
    exit $LASTEXITCODE
}
