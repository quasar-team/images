$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Assert-RequiredEnvVar -Name "NET_SNMP_HOME"
Assert-RequiredEnvVar -Name "LIBSSL_HOME"

$netSnmpVersion = "5.9.5.2"
$netSnmpUrl = "https://github.com/net-snmp/net-snmp/archive/refs/tags/v5.9.5.2.tar.gz"
$workRoot = "C:\net-snmp-src"
$archivePath = "$workRoot\net-snmp.tar.gz"
$sourceRoot = "$workRoot\source"
$installPath = [Environment]::GetEnvironmentVariable("NET_SNMP_HOME")
$openSslHome = [Environment]::GetEnvironmentVariable("LIBSSL_HOME")

Add-IssueSection "NET-SNMP VERSION: $netSnmpVersion"
Add-IssueSection "NET_SNMP_HOME: $installPath"

if (Test-Path $workRoot) {
    Remove-Item -Path $workRoot -Recurse -Force
}
New-Item -Path $sourceRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading Net-SNMP sources"
Invoke-WebRequest -Uri $netSnmpUrl -OutFile $archivePath

Write-Host "Extracting Net-SNMP"
Invoke-Checked tar @('-xzf', $archivePath, '-C', $sourceRoot)

$netSnmpSourceDir = Get-ChildItem -Path $sourceRoot -Directory | Select-Object -First 1
if ($null -eq $netSnmpSourceDir) {
    throw "Unable to locate extracted Net-SNMP source directory."
}

if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}

$prefixForConfigure = $installPath -replace '\\', '/'
$openSslIncludePath = (Join-Path $openSslHome "include") -replace '\\', '/'
$openSslLibraryPath = Join-Path $openSslHome "lib"
if (-not (Test-Path $openSslLibraryPath)) {
    $openSslLibraryPath = Join-Path $openSslHome "lib64"
}
if (-not (Test-Path $openSslLibraryPath)) {
    throw "Unable to locate OpenSSL libraries under '$openSslHome\\lib' or '$openSslHome\\lib64'."
}
$openSslLibraryPath = $openSslLibraryPath -replace '\\', '/'

$netSnmpWin32Dir = Join-Path $netSnmpSourceDir.FullName "win32"
if (-not (Test-Path $netSnmpWin32Dir)) {
    throw "Unable to locate Net-SNMP win32 build directory at '$netSnmpWin32Dir'."
}

# Net-SNMP win32 templates miss crypt32.lib, which is required by OpenSSL 3
# for Cert* symbols used by libcrypto on Windows.
$win32TemplateFiles = Get-ChildItem -Path $netSnmpWin32Dir -Filter "*.in" -Recurse
foreach ($template in $win32TemplateFiles) {
    $content = Get-Content -Path $template.FullName -Raw
    $updatedContent = [regex]::Replace(
        $content,
        'advapi32\.lib ws2_32\.lib kernel32\.lib user32\.lib(?! crypt32\.lib)',
        'advapi32.lib ws2_32.lib kernel32.lib user32.lib crypt32.lib'
    )
    if ($updatedContent -ne $content) {
        Set-Content -Path $template.FullName -Value $updatedContent -Encoding ascii
    }
}

$root = $netSnmpWin32Dir
if (-not (Test-Path $root)) { throw "Path not found: $root" }

$replacements = @(
    @{ Pattern = '(?i)\blibssl_static\.lib\b';    Replacement = 'libssl.lib' },
    @{ Pattern = '(?i)\blibcrypto_static\.lib\b'; Replacement = 'libcrypto.lib' }
)

# Target typical text-based build/config files (keeps it fast and avoids binaries)
$include = @('*.in','*.mak','*.mk','*.def','*.h','*.c','*.cc','*.cpp','*.rc','*.pl','*.pm','*.txt','Makefile*')

$files = Get-ChildItem -Path $root -Recurse -File -Include $include

$changed = 0
foreach ($f in $files) {
    $c = Get-Content -Path $f.FullName -Raw -ErrorAction Stop
    $u = $c
    foreach ($r in $replacements) {
        $u = [regex]::Replace($u, $r.Pattern, $r.Replacement)
    }
    if ($u -ne $c) {
        Set-Content -Path $f.FullName -Value $u -Encoding ascii
        $changed++
    }
}

Write-Host "Patched files: $changed"

$configure = 'cd /d "{0}" && perl Configure --config=release --linktype=static --prefix="{1}" --with-sdk --with-ssl --with-sslincdir="{2}" --with-ssllibdir="{3}" --enable-blumenthal-aes' -f $netSnmpWin32Dir, $prefixForConfigure, $openSslIncludePath, $openSslLibraryPath
$build = 'cd /d "{0}" && nmake /nologo' -f $netSnmpWin32Dir
$install = 'cd /d "{0}" && nmake /nologo install && nmake /nologo install_devel' -f $netSnmpWin32Dir

Write-Host "Configuring and building Net-SNMP"
Invoke-VsDevShellCommand -Command $configure
Invoke-VsDevShellCommand -Command $build
Invoke-VsDevShellCommand -Command $install

Remove-Item -Path $workRoot -Recurse -Force
