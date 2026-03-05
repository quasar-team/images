# Local-Env.ps1
$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$common = Join-Path $root 'scripts\Common.ps1'

# Your environment variables
$env:NET_SNMP_HOME="C:\net-snmp"
$env:LIBSSL_HOME="C:\libssl"
$env:BOOST_HOME="C:\boost"
$env:UNIFIED_AUTOMATION_HOME="C:\unified-automation"
$env:OPEN6_HOME="C:\open6"
$env:XERCES_C_HOME="C:\xerces-c"
$env:LIBXML2_HOME="C:\libxml2"
$env:XSD_HOME="C:\xsd"

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

# Import VS toolchain into *this* PowerShell process
Import-VsDevCmdEnvironment -Arch x64 -HostArch x64

# Load your common script in the same session
. $common