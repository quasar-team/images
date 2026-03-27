$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$variableNames = @(
    "ICS_REPO_DEPS_TOKEN",
    "QT_ACCOUNT_EMAIL",
    "QT_ACCOUNT_PASSWORD"
)

$envValues = @{}

foreach ($varName in $variableNames) {
    if ($envValue = Get-Item "env:$varName" -ErrorAction SilentlyContinue) {
        $envValues[$varName] = $envValue.Value
    } else {
        Write-Error "Environment variable '$varName' not found."
        exit 1
    }
}

$envFilePath = ".env"
Set-Content -Path $envFilePath -Value ""

foreach ($envVar in $envValues.GetEnumerator()) {
    "$($envVar.Key)=$($envVar.Value)" | Add-Content -Path $envFilePath
}

Write-Host "Environment variables written to '$envFilePath'."
