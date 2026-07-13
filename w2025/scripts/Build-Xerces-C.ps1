$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Assert-RequiredEnvVar -Name "XERCES_C_HOME"

$xercesCVersion = "3.3.0"
$xercesCUrl = "https://archive.apache.org/dist/xerces/c/3/sources/xerces-c-3.3.0.tar.gz"
$workRoot = "C:\xerces-c-src"
$archivePath = "$workRoot\xerces-c.tar.gz"
$sourceRoot = "$workRoot\source"
$releaseBuildPath = "$workRoot\build-release"
$debugBuildPath = "$workRoot\build-debug"
$debugInstallPath = "$workRoot\install-debug"
$installPath = [Environment]::GetEnvironmentVariable("XERCES_C_HOME")
$debugModeEnabled = Test-DebugModeEnabled

Add-IssueSection "XERCES-C++ VERSION: $xercesCVersion"
Add-IssueSection "XERCES_C_HOME: $installPath"
Add-IssueSection "XERCES-C++ DEBUG BUILD: $debugModeEnabled"

if (Test-Path $workRoot) {
    Remove-Item -Path $workRoot -Recurse -Force
}
New-Item -Path $sourceRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading Xerces-C++ sources"
Invoke-WebRequest -Uri $xercesCUrl -OutFile $archivePath

Write-Host "Extracting Xerces-C++"
Invoke-Checked tar @('-xzf', $archivePath, '-C', $sourceRoot)

$xercesSourceDir = Get-ChildItem -Path $sourceRoot -Directory | Select-Object -First 1
if ($null -eq $xercesSourceDir) {
    throw "Unable to locate extracted Xerces-C++ source directory."
}

if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
}

function Invoke-XercesCBuild {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("Release", "Debug")][string]$BuildType,
        [Parameter(Mandatory = $true)][string]$BuildPath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    $configure = 'cmake -S "{0}" -B "{1}" -G Ninja -DCMAKE_BUILD_TYPE={2} -DBUILD_SHARED_LIBS=OFF -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_INSTALL_PREFIX="{3}"' -f $xercesSourceDir.FullName, $BuildPath, $BuildType, $DestinationPath
    $build = 'cmake --build "{0}" --parallel' -f $BuildPath
    $install = 'cmake --install "{0}"' -f $BuildPath

    Write-Host "Configuring and building Xerces-C++ ($BuildType)"
    Invoke-VsDevShellCommand -Command $configure
    Invoke-VsDevShellCommand -Command $build
    Invoke-VsDevShellCommand -Command $install
}

Invoke-XercesCBuild -BuildType "Release" -BuildPath $releaseBuildPath -DestinationPath $installPath

if ($debugModeEnabled) {
    Invoke-XercesCBuild -BuildType "Debug" -BuildPath $debugBuildPath -DestinationPath $installPath

    $xercesCDebugPdb = Get-ChildItem -LiteralPath $debugBuildPath -Recurse -File -Filter "xerces-c.pdb" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $xercesCDebugPdb) {
        throw "Unable to locate Xerces-C++ debug PDB 'xerces-c.pdb' under '$debugBuildPath'."
    }

    $targetLibPath = Join-Path $installPath "lib"
    New-Item -Path $targetLibPath -ItemType Directory -Force | Out-Null
    $xercesCDebugPdbTargetPath = Join-Path $targetLibPath $xercesCDebugPdb.Name
    Copy-Item -LiteralPath $xercesCDebugPdb.FullName -Destination $xercesCDebugPdbTargetPath -Force
    Write-Host "Installed Xerces-C++ debug PDB: $xercesCDebugPdbTargetPath"
}

Remove-Item -Path $workRoot -Recurse -Force
Remove-Item -Path $installPath/share -Recurse -Force -ErrorAction SilentlyContinue
