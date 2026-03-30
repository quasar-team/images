# alma-10 image setup

This directory contains the Docker build context and helper scripts used to create the Quasar development image for AlmaLinux 10.

## Build the Docker image

From this directory:

```bash
docker build \
  --build-arg ICS_REPO_DEPS_TOKEN="<your_token>" \
  -t quasar-alma10:latest \
  .
```

`ICS_REPO_DEPS_TOKEN` is required to download the Unified Automation UASDK bundle.

To run the same GitLab build job locally from the repository root:

```bash
gitlab-ci-local --variables-file .env "Image Alma 10"
```

## What is built in this image

The `Dockerfile` installs core build tools with `dnf` and then runs these scripts in order:

1. `build-openssl.sh`
2. `build-libxml2.sh`
3. `build-net-snmp.sh`
5. `build-boost.sh`
6. `build-uasdk.sh`
7. `build-xerces-c.sh`

They install dependencies under `/opt/*` as static-oriented local installs used by Quasar builds. The Linux dependency builds are configured to produce static `.a` libraries and compile them as position-independent code (`-fPIC` / `CMAKE_POSITION_INDEPENDENT_CODE=ON`) for downstream linking.

## Use the scripts on your own AlmaLinux environment

If you want to reproduce the same setup directly on a host (without Docker), run the scripts with the same environment variables and order.

### 1) Install build prerequisites

```bash
sudo dnf install -y epel-release
sudo dnf update -y
sudo dnf install -y \
  cmake ninja-build g++ automake autoconf libtool \
  cppcheck nano git git-lfs patch graphviz xsd astyle \
  python python-pip python-devel doxygen perl \
  qt6-qtbase-devel \
  curl tar unzip which rpm-build
```

### 2) Export install paths and token

```bash
export BOOST_HOME=/opt/boost
export UNIFIED_AUTOMATION_HOME=/opt/unified-automation
export XERCES_C_HOME=/opt/xerces-c
export LIBSSL_HOME=/opt/libssl
export LIBXML2_HOME=/opt/libxml2
export NET_SNMP_HOME=/opt/net-snmp
export PATH=/opt/xsd:$PATH
export ICS_REPO_DEPS_TOKEN="<your_token>"
```

### 3) Run scripts as root (required)

All scripts install under `/opt` and therefore must run as root. Use `sudo`.

```bash
sudo -E ./build-openssl.sh
sudo -E ./build-libxml2.sh
sudo -E ./build-net-snmp.sh
sudo -E ./build-boost.sh
sudo -E ./build-uasdk.sh
sudo -E ./build-xerces-c.sh
```

`-E` preserves your exported environment variables while running with `sudo`.

## Dynamic dependencies in Quasar on Linux

Quasar on Linux also supports dynamic dependencies. If you prefer distro-provided shared libraries instead of building local static-style dependencies, install the corresponding `-devel` packages with `dnf`.

Example:

```bash
sudo dnf install -y \
  openssl-devel libxml2-devel net-snmp-devel \
  boost-devel xerces-c-devel \
  qt6-qtbase-devel
```

On AlmaLinux 10, `qt6-qtbase-devel` provides the development files for both the Qt6 base module (`Qt6Core`) and the network module (`Qt6Network`), including the CMake package files and pkg-config metadata.
