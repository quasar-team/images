param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$RootPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-VsWhere {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"),
        "vswhere.exe"
    )

    foreach ($c in $candidates) {
        try {
            $cmd = Get-Command $c -ErrorAction Stop
            return $cmd.Source
        } catch {
            # try next
        }
    }

    throw "vswhere.exe not found. Install Visual Studio Build Tools (Desktop development with C++)."
}

function Find-DumpTool {
    param([string]$VsWhere)

    $commonArgs = @(
        "-latest",
        "-products", "*",
        "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
    )

    # Prefer dumpbin.exe, fallback to link.exe /dump
    $dumpbin = & $VsWhere @commonArgs -find "VC\Tools\MSVC\**\bin\Hostx64\x64\dumpbin.exe" 2>$null | Select-Object -First 1
    if ($dumpbin) {
        return [pscustomobject]@{
            Path = $dumpbin.Trim()
            Kind = "dumpbin"
        }
    }

    $link = & $VsWhere @commonArgs -find "VC\Tools\MSVC\**\bin\Hostx64\x64\link.exe" 2>$null | Select-Object -First 1
    if ($link) {
        return [pscustomobject]@{
            Path = $link.Trim()
            Kind = "link"
        }
    }

    throw "Could not find dumpbin.exe or link.exe via vswhere."
}

function Get-LibDirectives {
    param(
        [string]$ToolPath,
        [string]$ToolKind,
        [string]$LibPath
    )

    if ($ToolKind -eq "dumpbin") {
        return (& $ToolPath /nologo /directives $LibPath 2>&1 | Out-String)
    }

    # link.exe fallback
    return (& $ToolPath /nologo /dump /directives $LibPath 2>&1 | Out-String)
}

function Test-LibForMD {
    param(
        [string]$ToolPath,
        [string]$ToolKind,
        [System.IO.FileInfo]$Lib
    )

    $out = Get-LibDirectives -ToolPath $ToolPath -ToolKind $ToolKind -LibPath $Lib.FullName

    $matches = [regex]::Matches($out, '(?i)DEFAULTLIB:\s*("?)([^"\s]+)\1')
    $defaultLibs = @(
        $matches | ForEach-Object { $_.Groups[2].Value.ToUpperInvariant() }
    ) | Sort-Object -Unique

    $hasMD = $defaultLibs | Where-Object { $_ -in @("MSVCRT", "MSVCRTD") }
    $hasMT = $defaultLibs | Where-Object { $_ -in @("LIBCMT", "LIBCMTD") }

    [pscustomobject]@{
        Path        = $Lib.FullName
        DefaultLibs = $defaultLibs
        HasMD       = [bool]($hasMD)
        HasMT       = [bool]($hasMT)
    }
}

$root = Resolve-Path -LiteralPath $RootPath
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "Path is not a directory: $RootPath"
}

$vswhere = Resolve-VsWhere
$tool = Find-DumpTool -VsWhere $vswhere

Write-Host "Using $($tool.Kind): $($tool.Path)"
Write-Host "Scanning: $root"

$libs = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter *.lib)
if (-not $libs) {
    Write-Warning "No .lib files found under $root"
    exit 0
}

$mdFailures = @()
$unknown = @()

foreach ($lib in $libs) {
    try {
        $result = Test-LibForMD -ToolPath $tool.Path -ToolKind $tool.Kind -Lib $lib

        if ($result.HasMD) {
            Write-Host "[FAIL /MD] $($result.Path)" -ForegroundColor Red
            if (@($result.DefaultLibs).Count -gt 0) {
                Write-Host "  DEFAULTLIBs: $($result.DefaultLibs -join ', ')"
            }
            $mdFailures += $result
        }
        elseif ($result.HasMT) {
            Write-Host "[OK  /MT] $($result.Path)" -ForegroundColor Green
        }
        else {
            Write-Host "[WARN ? ] $($result.Path)" -ForegroundColor Yellow
            if (@($result.DefaultLibs).Count -gt 0) {
                Write-Host "  DEFAULTLIBs: $($result.DefaultLibs -join ', ')"
            } else {
                Write-Host "  No DEFAULTLIB directives found (may be import lib / stripped directives / non-MSVC-built lib)."
            }
            $unknown += $result
        }
    }
    catch {
        Write-Host "[ERROR ] $($lib.FullName)" -ForegroundColor Magenta
        Write-Host "  $($_.Exception.Message)"
        $unknown += [pscustomobject]@{ Path = $lib.FullName; Error = $_.Exception.Message }
    }
}

Write-Host ""
Write-Host "Summary:"
Write-Host "  Total .lib files: $(@($libs).Count)"
Write-Host "  /MD failures:     $($mdFailures.Count)"
Write-Host "  Unknown/warnings: $($unknown.Count)"

if ($mdFailures.Count -gt 0) {
    exit 1
}
exit 0
