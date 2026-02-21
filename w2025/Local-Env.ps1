$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$common = Join-Path $root 'scripts\Common.ps1'

# Set environment variables
$env:NET_SNMP_HOME="C:\net-snmp"
$env:LIBSSL_HOME="C:\libssl"
$env:BOOST_HOME="C:\boost"
$env:UNIFIED_AUTOMATION_HOME="C:\unified-automation"
$env:OPEN6_HOME="C:\open6"
$env:XERCES_C_HOME="C:\xerces-c"
$env:LIBXML2_HOME="C:\libxml2"
$env:XSD_HOME="C:\xsd"

# Start an interactive pwsh that loads Common
pwsh -NoLogo -NoExit -Interactive -Command ". '$common'"
