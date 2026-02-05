# Stop execution on PowerShell snippet errors.
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# For external commands, explicitly check $LASTEXITCODE after execution.
$issuePath = "C:\ISSUE"
if (-not (Test-Path -Path $issuePath)) {
    Write-Host "ISSUE file is not available at $issuePath"
    exit 1
}

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
