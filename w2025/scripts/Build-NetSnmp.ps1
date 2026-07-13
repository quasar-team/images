$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Assert-RequiredEnvVar -Name "NET_SNMP_HOME"
Assert-RequiredEnvVar -Name "LIBSSL_HOME"

$netSnmpVersion = "5.9.5.2"
$netSnmpUrl = "https://github.com/net-snmp/net-snmp/archive/refs/tags/v5.9.5.2.tar.gz"
$workRoot = "C:\net-snmp-src"
$archivePath = "$workRoot\net-snmp.tar.gz"
$sourceRoot = "$workRoot\source"
$debugInstallPath = "$workRoot\install-debug"
$installPath = [Environment]::GetEnvironmentVariable("NET_SNMP_HOME")
$openSslHome = [Environment]::GetEnvironmentVariable("LIBSSL_HOME")
$debugModeEnabled = Test-DebugModeEnabled
$findNetSnmpCmake = Join-Path (Get-Location) "FindNetSNMP.cmake"
if (-not (Test-Path -LiteralPath $findNetSnmpCmake -PathType Leaf)) {
    throw "Unable to locate $findNetSnmpCmake."
}

Add-IssueSection "NET-SNMP VERSION: $netSnmpVersion"
Add-IssueSection "NET_SNMP_HOME: $installPath"
Add-IssueSection "NET-SNMP DEBUG BUILD: $debugModeEnabled"

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

function Set-NetSnmpOpenSslLibraryNames {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("release", "debug")][string]$Config
    )

    $sslLibraryName = if ($Config -eq "debug") { "libssld.lib" } else { "libssl.lib" }
    $cryptoLibraryName = if ($Config -eq "debug") { "libcryptod.lib" } else { "libcrypto.lib" }

    foreach ($requiredOpenSslLibrary in @($sslLibraryName, $cryptoLibraryName)) {
        $requiredOpenSslPath = Join-Path ($openSslLibraryPath -replace '/', '\') $requiredOpenSslLibrary
        if (-not (Test-Path -LiteralPath $requiredOpenSslPath -PathType Leaf)) {
            throw "Unable to locate OpenSSL library required for Net-SNMP $Config build: $requiredOpenSslPath"
        }
    }

    $libraryReplacements = @(
        @{ Pattern = '(?i)\blibssl(?:_static)?(?:d)?\.lib\b';    Replacement = $sslLibraryName },
        @{ Pattern = '(?i)\blibcrypto(?:_static)?(?:d)?\.lib\b'; Replacement = $cryptoLibraryName }
    )

    $updated = 0
    foreach ($f in $files) {
        $c = Get-Content -Path $f.FullName -Raw -ErrorAction Stop
        $u = $c
        foreach ($r in $libraryReplacements) {
            $u = [regex]::Replace($u, $r.Pattern, $r.Replacement)
        }
        if ($u -ne $c) {
            Set-Content -Path $f.FullName -Value $u -Encoding ascii
            $updated++
        }
    }

    Write-Host "Patched Net-SNMP OpenSSL library names for ${Config}: $updated files"
}

function Invoke-NetSnmpBuild {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("release", "debug")][string]$Config,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    Set-NetSnmpOpenSslLibraryNames -Config $Config

    $prefix = $DestinationPath -replace '\\', '/'
    $configure = 'cd /d "{0}" && perl Configure --config={1} --linktype=static --prefix="{2}" --with-sdk --with-ssl --with-sslincdir="{3}" --with-ssllibdir="{4}" --enable-blumenthal-aes' -f $netSnmpWin32Dir, $Config, $prefix, $openSslIncludePath, $openSslLibraryPath
    $build = 'cd /d "{0}" && nmake /nologo' -f $netSnmpWin32Dir
    $install = 'cd /d "{0}" && nmake /nologo install && nmake /nologo install_devel' -f $netSnmpWin32Dir

    Write-Host "Configuring and building Net-SNMP ($Config)"
    Invoke-VsDevShellCommand -Command $configure

    if ($Config -eq "debug") {
        # Net-SNMP debug link step searches for OpenSSL PDBs in win32\bin\debug.
        # libcryptod.lib expects 'ossl_static.pdb'. In our merged install the debug
        # symbols can be named 'ossl_staticd.pdb', so stage/alias accordingly.
        $openSslLibraryPathWindows = $openSslLibraryPath -replace '/', '\\'
        $netSnmpDebugBinPath = Join-Path $netSnmpWin32Dir "bin\debug"
        New-Item -Path $netSnmpDebugBinPath -ItemType Directory -Force | Out-Null

        $debugPdbCandidate = Join-Path $openSslLibraryPathWindows "ossl_staticd.pdb"
        $releasePdbCandidate = Join-Path $openSslLibraryPathWindows "ossl_static.pdb"
        $resolvedDebugPdb = if (Test-Path -LiteralPath $debugPdbCandidate -PathType Leaf) {
            $debugPdbCandidate
        } elseif (Test-Path -LiteralPath $releasePdbCandidate -PathType Leaf) {
            $releasePdbCandidate
        } else {
            $null
        }

        if ($null -ne $resolvedDebugPdb) {
            Copy-Item -LiteralPath $resolvedDebugPdb -Destination (Join-Path $netSnmpDebugBinPath "ossl_static.pdb") -Force
            # Keep the debug-specific filename as well for easier diagnostics.
            Copy-Item -LiteralPath $resolvedDebugPdb -Destination (Join-Path $netSnmpDebugBinPath "ossl_staticd.pdb") -Force
        } else {
            Write-Warning "OpenSSL debug PDB was not found in '$openSslLibraryPathWindows'; debug links may emit LNK4099/LNK4204 warnings."
        }
    }

    Invoke-VsDevShellCommand -Command $build
    Invoke-VsDevShellCommand -Command $install
}

Invoke-NetSnmpBuild -Config "release" -DestinationPath $installPath

if ($debugModeEnabled) {
    Invoke-VsDevShellCommand -Command ('cd /d "{0}" && nmake /nologo clean' -f $netSnmpWin32Dir)
    Invoke-NetSnmpBuild -Config "debug" -DestinationPath $debugInstallPath
    $debugLibraries = Copy-DebugBuildArtifacts -DebugInstallPath $debugInstallPath -InstallPath $installPath

    $netSnmpDebugPdbPath = Join-Path $netSnmpWin32Dir "libsnmp\debug\libsnmp.pdb"
    if (-not (Test-Path -LiteralPath $netSnmpDebugPdbPath -PathType Leaf)) {
        throw "Unable to locate Net-SNMP debug PDB 'libsnmp.pdb' at '$netSnmpDebugPdbPath'."
    }

    $targetLibPath = Join-Path $installPath "lib"
    New-Item -Path $targetLibPath -ItemType Directory -Force | Out-Null
    $netSnmpDebugPdbTargetPath = Join-Path $targetLibPath "libsnmp.pdb"
    Copy-Item -LiteralPath $netSnmpDebugPdbPath -Destination $netSnmpDebugPdbTargetPath -Force
    Write-Host "Installed Net-SNMP debug PDB: $netSnmpDebugPdbTargetPath"

    Write-Host "Installed Net-SNMP debug libraries: $($debugLibraries -join ', ')"
}

$netSnmpCmakeConfigPath = Join-Path $installPath "lib\cmake\NetSNMP"
New-Item -Path $netSnmpCmakeConfigPath -ItemType Directory -Force | Out-Null
Copy-Item -LiteralPath $findNetSnmpCmake -Destination (Join-Path $netSnmpCmakeConfigPath "NetSNMPConfig.cmake") -Force

Remove-Item -Path $workRoot -Recurse -Force
