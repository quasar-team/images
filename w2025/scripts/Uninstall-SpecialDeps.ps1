$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Invoke-Checked choco @('uninstall', '-y', '--no-progress', 'strawberryperl', 'nasm')
refreshenv