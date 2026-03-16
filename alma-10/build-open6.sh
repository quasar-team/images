#!/usr/bin/env bash
set -euo pipefail

: "${OPEN6_HOME:?OPEN6_HOME is required to install Open6}"
: "${LIBSSL_HOME:?LIBSSL_HOME is required to build Open6 with OpenSSL}"

OPEN6_VERSION="1.5.0"
OPEN6_URL="https://github.com/open62541/open62541/archive/refs/tags/v${OPEN6_VERSION}.tar.gz"

echo OPEN6 VERSION: "${OPEN6_VERSION}" >> /ISSUE
echo OPEN6_HOME: "${OPEN6_HOME}" >> /ISSUE
echo "*******************" >> /ISSUE

mkdir -p /tmp/open6-src

curl -fsSL "${OPEN6_URL}" \
  | tar -xz -C /tmp/open6-src --strip-components=1

rm -rf "${OPEN6_HOME}"

cmake -S /tmp/open6-src -B /tmp/open6-src/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DOPENSSL_ROOT_DIR="${LIBSSL_HOME}" \
  -DOPENSSL_USE_STATIC_LIBS=TRUE \
  -DUA_ENABLE_ENCRYPTION=OPENSSL \
  -DCMAKE_INSTALL_PREFIX="${OPEN6_HOME}" \
  -DCMAKE_INSTALL_LIBDIR=lib
cmake --build /tmp/open6-src/build --parallel "$(nproc)"
cmake --install /tmp/open6-src/build

rm -rf /tmp/open6-src
