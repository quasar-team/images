$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Tell nmake to run in parallel where possible to speed up builds
$env:CL = "/MP"

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
    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { throw "vswhere not found: $vswhere" }

    $install = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $install) { $install = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Workload.VCTools -property installationPath }
    if (-not $install) { throw "No VS instance with MSVC tools found via vswhere." }

    $vsDevCmd = Join-Path $install "Common7\Tools\VsDevCmd.bat"
    if (-not (Test-Path $vsDevCmd)) { throw "VsDevCmd.bat not found: $vsDevCmd" }

    $vsDevCmd
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


function Import-VsDevCmdEnvironment {
    param(
        [ValidateSet('x86','x64','arm64')] [string] $Arch = 'x64',
        [ValidateSet('x86','x64','arm64')] [string] $HostArch = 'x64'
    )

    $vsDevCmd = Get-VsDevCmdPath

    # Run VsDevCmd in cmd, then dump the environment as NAME=VALUE lines.
    $cmdLine = "`"$vsDevCmd`" -no_logo -arch=$Arch -host_arch=$HostArch >nul && set"
    $envLines = & cmd.exe /d /s /c $cmdLine

    foreach ($line in $envLines) {
        if ($line -match '^(?<Name>[^=]+)=(?<Value>.*)$') {
            [Environment]::SetEnvironmentVariable($matches.Name, $matches.Value, 'Process')
        }
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
    # Create directory C:\ISSUE if it doesn't exist, then create or clear the ISSUE.txt file within it.
    $issueDir = "C:\ISSUE"
    if (-not (Test-Path -Path $issueDir)) {
        New-Item -Path $issueDir -ItemType Directory | Out-Null
    }

    Set-Content -Path "C:\ISSUE\ISSUE.txt" -Value "" -NoNewline
}

function Add-IssueSection {
    param(
        [Parameter(Mandatory = $true)][string]$Line
    )

    Add-Content -Path "C:\ISSUE\ISSUE.txt" -Value $Line
    Add-Content -Path "C:\ISSUE\ISSUE.txt" -Value "*******************"
}
