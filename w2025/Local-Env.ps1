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


# Load your common script in the same session
. $common

# Import VS toolchain into *this* PowerShell process
Import-VsDevCmdEnvironment -Arch x64 -HostArch x64
