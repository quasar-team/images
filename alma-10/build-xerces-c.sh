#!/usr/bin/env bash
set -euo pipefail

: "${XERCES_C_HOME:?XERCES_C_HOME is required to install Xerces-C++}"

XERCES_C_VERSION="3.3.0"
XERCES_C_URL="https://archive.apache.org/dist/xerces/c/3/sources/xerces-c-${XERCES_C_VERSION}.tar.gz"

echo XERCES-C++ VERSION: "${XERCES_C_VERSION}" >> /ISSUE
echo XERCES_C_HOME: "${XERCES_C_HOME}" >> /ISSUE
echo "*******************" >> /ISSUE

mkdir -p /tmp/xerces-c-src
curl -fsSL "${XERCES_C_URL}" \
  | tar -xz -C /tmp/xerces-c-src --strip-components=1

cmake -S /tmp/xerces-c-src -B /tmp/xerces-c-src/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DCMAKE_INSTALL_PREFIX="${XERCES_C_HOME}" \
  -DCMAKE_INSTALL_LIBDIR=lib
cmake --build /tmp/xerces-c-src/build --parallel "$(nproc)"
cmake --install /tmp/xerces-c-src/build

rm -rf /tmp/xerces-c-src
