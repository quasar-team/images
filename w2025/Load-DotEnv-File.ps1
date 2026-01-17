$ErrorActionPreference = "Stop" 

# Read the .env file
$fileContent = Get-Content ".env"

# Loop through each line in the .env file
foreach ($line in $fileContent) {
    # Split the line into the variable name and its value
    $variableName, $value = $line -split "="

    # Set the environment variable with the given name to the specified value
    Set-Item -Path "env:$variableName" -Value $value.Trim()
}

# Delete the .env file
Remove-Item ".env"
