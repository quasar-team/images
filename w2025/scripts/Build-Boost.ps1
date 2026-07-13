$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest


Assert-RequiredEnvVar -Name "BOOST_HOME"

$boostVersion = "1.91.0"
$boostUrl = "https://archives.boost.io/release/1.91.0/source/boost_1_91_0.zip"

$workRoot = "C:\boost-src"
$archivePath = Join-Path $workRoot "boost.zip"
$sourceRoot = Join-Path $workRoot "source"

$installPath = [Environment]::GetEnvironmentVariable("BOOST_HOME")
$debugModeEnabled = Test-DebugModeEnabled

function Expand-ZipArchive {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    $sevenZip = Get-Command "7z.exe" -ErrorAction SilentlyContinue
    if ($null -eq $sevenZip) {
        $sevenZip = Get-Command "7z" -ErrorAction SilentlyContinue
    }

    if ($null -eq $sevenZip) {
        throw "7z is required to extract Boost archives. Install 7-Zip and ensure 7z.exe is available in PATH."
    }

    Invoke-Checked $sevenZip.Source @('x', '-y', "-o$DestinationPath", $ArchivePath)
}

function Test-BoostBuildSupportsVc145 {
    param(
        [Parameter(Mandatory = $true)][string]$BoostSourcePath
    )

    $buildBatPath = Join-Path $BoostSourcePath "tools\build\src\engine\build.bat"
    if (-not (Test-Path -LiteralPath $buildBatPath -PathType Leaf)) {
        throw "Unable to locate Boost.Build engine bootstrap script at '$buildBatPath'."
    }

    return Select-String -LiteralPath $buildBatPath -Pattern '\bvc145\b' -Quiet
}

Add-IssueSection "BOOST VERSION: $boostVersion"
Add-IssueSection "BOOST_HOME: $installPath"
Add-IssueSection "BOOST DEBUG BUILD: $debugModeEnabled"

if (Test-Path $workRoot) {
    Invoke-Checked cmd.exe @('/S', '/C', ('rmdir /S /Q "{0}"' -f $workRoot))
}
New-Item -Path $sourceRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading Boost sources"
Invoke-WebRequest -Uri $boostUrl -OutFile $archivePath

Write-Host "Extracting Boost"
Expand-ZipArchive -ArchivePath $archivePath -DestinationPath $sourceRoot

$boostSourceDir = Get-ChildItem -Path $sourceRoot -Directory |
    Where-Object { $_.Name -like "boost_*" } |
    Select-Object -First 1

if ($null -eq $boostSourceDir) {
    throw "Unable to locate extracted Boost source directory."
}

if (Test-Path $installPath) {
    Invoke-Checked cmd.exe @('/S', '/C', ('rmdir /S /Q "{0}"' -f $installPath))
}

Write-Host "Bootstrapping Boost.Build"
Invoke-VsDevShellCommand -Command ('cd /d "{0}" && bootstrap.bat' -f $boostSourceDir.FullName)

function Invoke-BoostBuild {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("release", "debug")][string]$Variant
    )

    $build = (
        'cd /d "{0}" && ' +
        'b2.exe --quiet -d0 -j %NUMBER_OF_PROCESSORS% ' +
        'toolset=msvc address-model=64 variant={1} threading=multi ' +
        'link=static runtime-link=shared visibility=global local-visibility=global ' +
        '--without-mpi --without-graph_parallel install --prefix="{2}"'
    ) -f $boostSourceDir.FullName, $Variant, $installPath

    Write-Host "Building and installing Boost ($Variant)"
    Invoke-VsDevShellCommand -Command $build
}

Invoke-BoostBuild -Variant "release"

if ($debugModeEnabled) {
    Invoke-BoostBuild -Variant "debug"
}

Write-Host "Cleaning Boost artifacts"
Invoke-Checked cmd.exe @('/S', '/C', ('rmdir /S /Q "{0}"' -f $workRoot))
