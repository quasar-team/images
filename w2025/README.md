# w2025 Windows image build and local setup

This directory builds a Windows LTSC 2025 Docker image with all Quasar C++ dependencies preinstalled as static `.lib` artifacts using the DLL CRT (`/MD`), and also contains scripts to reproduce the same setup on your own Windows machine.

## What this folder contains

- `Dockerfile`: builds from `mcr.microsoft.com/windows/server:ltsc2025` and runs `install.ps1`.
- `install.ps1`: orchestrates the full dependency install/build flow.
- `scripts/*.ps1`: per-dependency install/build scripts.
- `Local-Env.ps1`: prepares env vars and loads Visual Studio developer environment in the current PowerShell session.
- `Create-DotEnv-File.ps1` + `Load-DotEnv-File.ps1`: pass secrets (`ICS_REPO_DEPS_TOKEN`) through a temporary `.env` file.
- `Check-MDFlag.ps1`: verifies generated `.lib` files are built with `/MD` and not `/MT`.

## Dependencies built/installed

The install flow creates these homes (default paths):

- `C:\boost`
- `C:\unified-automation`
- `C:\xerces-c`
- `C:\libssl`
- `C:\libxml2`
- `C:\net-snmp`
- `C:\xsd`
- `C:\Qt6` for Qt 6 shared binaries (`Qt6Core` and `Qt6Network`)

High-level order in `install.ps1`:

1. Install base tools (`choco`, Python, CMake, Ninja, VS Build Tools).
2. Install XSD compiler and libxsd headers.
3. Install temporary build deps (`strawberryperl`, `nasm`).
4. Build OpenSSL and Net-SNMP (then remove temporary deps).
5. Build libxml2.
6. Install Boost from CERN ICS deps repository.
7. Build UASDK and Xerces-C++.
8. Validate expected outputs and run `/MD` checks on produced `.lib` files.
9. Write version/build metadata to `C:\ISSUE\ISSUE.txt`.

## Required secret

Set `ICS_REPO_DEPS_TOKEN` before building/running install scripts.

PowerShell example:

```powershell
$env:ICS_REPO_DEPS_TOKEN = "<your-token>"
```

This token is required for private package downloads such as UASDK.

## Build the Docker image

Run from this `w2025` directory:

```powershell
# 1) Export token in your shell
$env:ICS_REPO_DEPS_TOKEN = "<your-token>"

# 2) Create temporary .env consumed by install.ps1 during docker build
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Create-DotEnv-File.ps1

# 3) Build image
docker build -t quasar/w2025:latest .
```

Notes:

- `Load-DotEnv-File.ps1` is called by `install.ps1` and deletes `.env` after loading it.
- Build can take a long time (OpenSSL and Net-SNMP are the slowest steps).

## Use the built image

```powershell
# Interactive shell with VS build environment
docker run --rm -it quasar/w2025:latest

# Or run a single command
docker run --rm quasar/w2025:latest pwsh -NoLogo -NoProfile -Command "cmake --version"
```

## Reuse scripts on your own Windows machine (no Docker)

Use this when you want the same dependency layout directly on a host machine.

### Prerequisites

- Windows machine with Administrator rights (Chocolatey installs packages system-wide).
- PowerShell 7 (`pwsh`).
- Internet access to all upstream sources used by scripts.
- `ICS_REPO_DEPS_TOKEN` set in your session.

### Steps

```powershell
# 1) Open elevated PowerShell and go to this directory
cd <path-to>\w2025

# 2) Set private token
$env:ICS_REPO_DEPS_TOKEN = "<your-token>"

# 3) Load default *_HOME variables + VS toolchain env in this process
. .\Local-Env.ps1

# 4) Run full setup
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

After completion, check:

- `C:\ISSUE\ISSUE.txt` for installed versions and build summary.
- Each `*_HOME` directory for headers/libs.

## Qt 6 install

Qt Online Installer authentication is required before you run the script.

## Important behavior and validation

- All C/C++ dependencies built from source are expected to produce static `.lib` outputs with MSVC runtime `/MD`.
- `Check-MDFlag.ps1` scans generated `.lib` files and fails the process if `/MT` is detected.
- `install.ps1` performs path validation and stops on first failure (`$ErrorActionPreference = "Stop"`).
