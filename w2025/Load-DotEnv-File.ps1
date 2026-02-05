$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Test-Path ".env")) {
    throw "Expected .env file was not found."
}

$fileContent = Get-Content ".env"

foreach ($line in $fileContent) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
        continue
    }

    $parts = $trimmed -split "=", 2
    if ($parts.Count -ne 2) {
        throw "Invalid .env line: '$line'"
    }

    $variableName = $parts[0].Trim()
    $value = $parts[1]

    Set-Item -Path "env:$variableName" -Value $value
}

Remove-Item ".env"
