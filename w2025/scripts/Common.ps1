$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @()
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $Command $($Arguments -join ' ')"
    }
}

function Get-VsDevCmdPath {
    $candidates = @(
        "$env:ProgramFiles\Microsoft Visual Studio\2026\BuildTools\Common7\Tools\VsDevCmd.bat",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2026\BuildTools\Common7\Tools\VsDevCmd.bat",
        "$env:ProgramFiles\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"
    )

    foreach ($path in $candidates) {
        if (Test-Path $path) {
            return $path
        }
    }

    throw "Unable to find VsDevCmd.bat from Visual Studio Build Tools."
}

function Invoke-VsDevShellCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command
    )

    $vsDevCmd = Get-VsDevCmdPath
    $fullCommand = ('"{0}" -arch=x64 -host_arch=x64 && {1}' -f $vsDevCmd, $Command)

    cmd.exe /S /C $fullCommand
    if ($LASTEXITCODE -ne 0) {
        throw "Developer shell command failed with exit code ${LASTEXITCODE}: $Command"
    }
}

function Assert-RequiredEnvVar {
    param(
        [Parameter(Mandatory = $true)][string]$Name
    )

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Environment variable '$Name' is required."
    }
}

function Initialize-IssueFile {
    Set-Content -Path "C:\ISSUE" -Value "" -NoNewline
}

function Add-IssueSection {
    param(
        [Parameter(Mandatory = $true)][string]$Line
    )

    Add-Content -Path "C:\ISSUE" -Value $Line
    Add-Content -Path "C:\ISSUE" -Value "*******************"
}
