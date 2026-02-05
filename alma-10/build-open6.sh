#!/usr/bin/env bash
set -euo pipefail

OPEN6_VERSION="1.5.0"
OPEN6_URL="https://github.com/open62541/open62541/archive/refs/tags/v${OPEN6_VERSION}.tar.gz"

echo OPEN6 VERSION: "${OPEN6_VERSION}" >> /ISSUE
echo "*******************" >> /ISSUE

mkdir -p /tmp/open6-src

curl -fsSL "${OPEN6_URL}" \
  | tar -xz -C /tmp/open6-src --strip-components=1

cmake -S /tmp/open6-src -B /tmp/open6-src/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DUA_BUILD_SHARED_LIBS=OFF \
  -DCMAKE_INSTALL_PREFIX=/opt/open6 \
  -DCMAKE_INSTALL_LIBDIR=libs >/dev/null 2>&1
cmake --build /tmp/open6-src/build --parallel "$(nproc)" >/dev/null 2>&1
cmake --install /tmp/open6-src/build >/dev/null 2>&1

rm -rf /tmp/open6-src
