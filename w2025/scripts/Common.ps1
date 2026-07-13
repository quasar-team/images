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

function Test-DebugModeEnabled {
    return ([Environment]::GetEnvironmentVariable("DEBUG_MODE") -eq "1")
}

function Get-DebugLibraryName {
    param(
        [Parameter(Mandatory = $true)][string]$LibraryName
    )

    $directory = Split-Path -Parent $LibraryName
    $fileName = Split-Path -Leaf $LibraryName
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $extension = [System.IO.Path]::GetExtension($fileName)
    $debugName = "${baseName}d${extension}"

    if ([string]::IsNullOrWhiteSpace($directory)) {
        return $debugName
    }

    return Join-Path $directory $debugName
}

function Copy-DebugBuildArtifacts {
    param(
        [Parameter(Mandatory = $true)][string]$DebugInstallPath,
        [Parameter(Mandatory = $true)][string]$InstallPath,
        [string[]]$AdditionalLibraryAliases = @()
    )

    $debugLibPath = @(
        (Join-Path $DebugInstallPath "lib"),
        (Join-Path $DebugInstallPath "lib64")
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
    $targetLibPath = @(
        (Join-Path $InstallPath "lib"),
        (Join-Path $InstallPath "lib64")
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1

    if ($null -eq $debugLibPath) {
        throw "Debug install library directory was not created under '$DebugInstallPath\\lib' or '$DebugInstallPath\\lib64'."
    }
    if ($null -eq $targetLibPath) {
        $targetLibPath = Join-Path $InstallPath "lib"
        New-Item -Path $targetLibPath -ItemType Directory -Force | Out-Null
    }

    $copiedLibraries = @()
    $debugLibraries = @(Get-ChildItem -LiteralPath $debugLibPath -File -Filter "*.lib")
    if ($debugLibraries.Count -eq 0) {
        throw "No debug .lib files found in '$debugLibPath'."
    }

    foreach ($library in $debugLibraries) {
        $targetPath = Join-Path $targetLibPath $library.Name
        if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
            $targetPath = Get-DebugLibraryName -LibraryName $targetPath
        }

        Copy-Item -LiteralPath $library.FullName -Destination $targetPath -Force
        $copiedLibraries += $targetPath
    }

    foreach ($alias in $AdditionalLibraryAliases) {
        $parts = $alias -split "=", 2
        if ($parts.Count -ne 2) {
            throw "Invalid debug library alias '$alias'. Expected 'source.lib=alias.lib'."
        }

        $sourceName = $parts[0]
        $aliasName = $parts[1]
        $sourcePath = Join-Path $debugLibPath $sourceName
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Debug library alias source was not found: $sourcePath"
        }

        Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $targetLibPath $aliasName) -Force
    }

    foreach ($subdir in @("lib", "bin")) {
        $debugArtifactPath = Join-Path $DebugInstallPath $subdir
        $targetArtifactPath = Join-Path $InstallPath $subdir
        if (-not (Test-Path -LiteralPath $debugArtifactPath -PathType Container)) {
            continue
        }

        if (-not (Test-Path -LiteralPath $targetArtifactPath -PathType Container)) {
            New-Item -Path $targetArtifactPath -ItemType Directory -Force | Out-Null
        }

        foreach ($pdb in @(Get-ChildItem -LiteralPath $debugArtifactPath -File -Filter "*.pdb")) {
            $targetPath = Join-Path $targetArtifactPath $pdb.Name
            if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
                $targetPath = Get-DebugLibraryName -LibraryName $targetPath
            }

            Copy-Item -LiteralPath $pdb.FullName -Destination $targetPath -Force
        }
    }

    return $copiedLibraries
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
