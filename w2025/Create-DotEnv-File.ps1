$ErrorActionPreference = "Stop" 

# Define a list of variable names
$variableNames = @(
    "ICS_REPO_DEPS_TOKEN"
)

# Create an empty hashtable to store the environment variable values
$envValues = @{}

# Loop through each variable name in the list
foreach ($varName in $variableNames) {
    # Check if the environment variable exists
    if ($envValue = Get-Item "env:$varName" -ErrorAction SilentlyContinue) {
        # If it does, add it to the hashtable
        $envValues[$varName] = $envValue.Value
    } else {
        # If it doesn't, print an error message and exit with code 1
        Write-Error "Environment variable '$varName' not found."
        exit 1
    }
}

# Create or overwrite the .env file with the variable values
$envFilePath = ".env"
foreach ($envVar in $envValues.GetEnumerator()) {
    "$($envVar.Key)=$($envVar.Value)" | Out-File -Append $envFilePath -Encoding utf8
}

# Print a success message
Write-Host "Environment variables written to '$envFilePath' with content:"
type .env
