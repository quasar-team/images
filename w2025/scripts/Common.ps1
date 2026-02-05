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
    $programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
    if ([string]::IsNullOrWhiteSpace($programFilesX86)) {
        $programFilesX86 = "C:\Program Files (x86)"
    }
    $programFiles = [Environment]::GetEnvironmentVariable("ProgramFiles")
    if ([string]::IsNullOrWhiteSpace($programFiles)) {
        $programFiles = "C:\Program Files"
    }

    $candidates = @(
        "$programFiles\Microsoft Visual Studio\2026\BuildTools\Common7\Tools\VsDevCmd.bat",
        "$programFilesX86\Microsoft Visual Studio\2026\BuildTools\Common7\Tools\VsDevCmd.bat",
        "$programFiles\Microsoft Visual Studio\2025\BuildTools\Common7\Tools\VsDevCmd.bat",
        "$programFilesX86\Microsoft Visual Studio\2025\BuildTools\Common7\Tools\VsDevCmd.bat",
        "$programFiles\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat",
        "$programFilesX86\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat",
        "$programFiles\Microsoft Visual Studio\2019\BuildTools\Common7\Tools\VsDevCmd.bat",
        "$programFilesX86\Microsoft Visual Studio\2019\BuildTools\Common7\Tools\VsDevCmd.bat",
        "$programFiles\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
        "$programFilesX86\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    )

    $vswherePath = "$programFilesX86\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswherePath) {
        $installPath = & $vswherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($installPath)) {
            $candidates = @(
                "$installPath\Common7\Tools\VsDevCmd.bat",
                "$installPath\VC\Auxiliary\Build\vcvars64.bat"
            ) + $candidates
        }
    }

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
    $isVcVars = $vsDevCmd.EndsWith("\vcvars64.bat", [System.StringComparison]::OrdinalIgnoreCase)
    if ($isVcVars) {
        $fullCommand = ('"{0}" && {1}' -f $vsDevCmd, $Command)
    } else {
        $fullCommand = ('"{0}" -arch=x64 -host_arch=x64 && {1}' -f $vsDevCmd, $Command)
    }

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
