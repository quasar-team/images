$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest


Assert-RequiredEnvVar -Name "BOOST_HOME"

$boostVersion = "1.90.0"
$boostUrl = "https://archives.boost.io/release/1.90.0/source/boost_1_90_0.zip"
$b2Version = "5.4.2"
$b2Url = "https://github.com/bfgroup/b2/releases/download/5.4.2/b2-5.4.2.zip"
$workRoot = "C:\boost-src"
$archivePath = Join-Path $workRoot "boost.zip"
$sourceRoot = Join-Path $workRoot "source"
$b2ArchivePath = Join-Path $workRoot "b2.zip"
$b2ExtractPath = Join-Path $workRoot "b2"
$installPath = [Environment]::GetEnvironmentVariable("BOOST_HOME")

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

function Install-PatchedB2 {
    param(
        [Parameter(Mandatory = $true)][string]$BoostSourcePath
    )

    # Temporary workaround for Boost 1.90.0 on VS 2026. Remove once Boost 1.90.1 is used.
    Write-Host "Downloading b2 $b2Version to patch Boost.Build for VS 2026"
    Invoke-WebRequest -Uri $b2Url -OutFile $b2ArchivePath

    if (Test-Path -LiteralPath $b2ExtractPath) {
        Remove-Item -Path $b2ExtractPath -Recurse -Force
    }
    New-Item -Path $b2ExtractPath -ItemType Directory -Force | Out-Null

    Expand-ZipArchive -ArchivePath $b2ArchivePath -DestinationPath $b2ExtractPath

    $patchedB2SourceDir = Get-ChildItem -Path $b2ExtractPath -Directory |
        Select-Object -First 1
    if ($null -eq $patchedB2SourceDir) {
        throw "Unable to locate extracted b2 source directory in '$b2ExtractPath'."
    }

    $boostToolsPath = Join-Path $BoostSourcePath "tools"
    $boostBuildPath = Join-Path $boostToolsPath "build"
    if (-not (Test-Path -LiteralPath $boostBuildPath -PathType Container)) {
        throw "Unable to locate Boost.Build directory at '$boostBuildPath'."
    }

    Remove-Item -Path $boostBuildPath -Recurse -Force
    Copy-Item -Path $patchedB2SourceDir.FullName -Destination $boostBuildPath -Recurse -Force
}

Add-IssueSection "BOOST VERSION: $boostVersion"
Add-IssueSection "BOOST_HOME: $installPath"

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

if (-not (Test-BoostBuildSupportsVc145 -BoostSourcePath $boostSourceDir.FullName)) {
    Add-IssueSection "BOOST BUILD PATCH: Replaced bundled Boost.Build with b2 $b2Version"
    Install-PatchedB2 -BoostSourcePath $boostSourceDir.FullName
}
else {
    Add-IssueSection "BOOST BUILD PATCH: bundled Boost.Build already supports vc145"
}

if (Test-Path $installPath) {
    Invoke-Checked cmd.exe @('/S', '/C', ('rmdir /S /Q "{0}"' -f $installPath))
}

Write-Host "Bootstrapping Boost.Build"
Invoke-VsDevShellCommand -Command ('cd /d "{0}" && bootstrap.bat' -f $boostSourceDir.FullName)

$build = (
    'cd /d "{0}" && ' +
    'b2.exe --quiet -d0 -j %NUMBER_OF_PROCESSORS% ' +
    'toolset=msvc address-model=64 variant=release threading=multi ' +
    'link=static runtime-link=shared visibility=global local-visibility=global ' +
    '--without-mpi --without-graph_parallel install --prefix="{1}"'
) -f $boostSourceDir.FullName, $installPath

Write-Host "Building and installing Boost"
Invoke-VsDevShellCommand -Command $build

Write-Host "Cleaning Boost artifacts"
Invoke-Checked cmd.exe @('/S', '/C', ('rmdir /S /Q "{0}"' -f $workRoot))
