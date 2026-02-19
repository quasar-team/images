#!/usr/bin/env bash
set -euo pipefail

: "${LIBXML2_HOME:?LIBXML2_HOME is required to install libxml2}"

LIBXML2_VERSION="2.15.1"
LIBXML2_URL="https://download.gnome.org/sources/libxml2/2.15/libxml2-${LIBXML2_VERSION}.tar.xz"

echo LIBXML2 VERSION: "${LIBXML2_VERSION}" >> /ISSUE
echo LIBXML2_HOME: "${LIBXML2_HOME}" >> /ISSUE
echo "*******************" >> /ISSUE

mkdir -p /tmp/libxml2-src
curl -fsSL "${LIBXML2_URL}" \
  | tar -xJ -C /tmp/libxml2-src --strip-components=1

rm -rf "${LIBXML2_HOME}"

cmake -S /tmp/libxml2-src -B /tmp/libxml2-src/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DCMAKE_INSTALL_PREFIX="${LIBXML2_HOME}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DLIBXML2_WITH_ICONV=OFF \
  -DLIBXML2_WITH_ZLIB=OFF \
  -DLIBXML2_WITH_LZMA=OFF \
  -DLIBXML2_WITH_PROGRAMS=OFF \
  -DLIBXML2_WITH_TESTS=OFF \
  -DLIBXML2_WITH_PYTHON=OFF
cmake --build /tmp/libxml2-src/build --parallel "$(nproc)"
cmake --install /tmp/libxml2-src/build

rm -rf /tmp/libxml2-src
