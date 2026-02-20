#!/usr/bin/env bash
set -euo pipefail

: "${ICS_REPO_DEPS_TOKEN:?ICS_REPO_DEPS_TOKEN is required to build UASDK}"
: "${UNIFIED_AUTOMATION_HOME:?UNIFIED_AUTOMATION_HOME is required to install UASDK}"
: "${LIBSSL_HOME:?LIBSSL_HOME is required to build UASDK}"
: "${LIBXML2_HOME:?LIBXML2_HOME is required to build UASDK}"

UASDK_VERSION="2.0.2-675"
UASDK_ZIP="uasdkcppbundle-src-linux-v${UASDK_VERSION}.zip"
UASDK_URL="https://ics-deps-repo.web.cern.ch/quasar/uasdk/${UASDK_VERSION}/${UASDK_ZIP}"

echo UNIFIED AUTOMATION UASDK VERSION: "${UASDK_VERSION}" >> /ISSUE
echo UNIFIED_AUTOMATION_HOME: "${UNIFIED_AUTOMATION_HOME}" >> /ISSUE
echo "*******************" >> /ISSUE

mkdir -p /tmp/uasdk-src
curl -fsSL -H "PRIVATE-TOKEN: ${ICS_REPO_DEPS_TOKEN}" \
  "${UASDK_URL}" \
  -o /tmp/uasdk-src/uasdk.zip
unzip -q /tmp/uasdk-src/uasdk.zip -d /tmp/uasdk-src/source

uasdk_root="$(find /tmp/uasdk-src/source -name CMakeLists.txt -printf '%d:%h\n' | sort -n | head -n 1 | cut -d: -f2-)"
rm -rf "${UNIFIED_AUTOMATION_HOME}"
cmake -S "${uasdk_root}" -B /tmp/uasdk-src/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_SHARED_STACK=OFF \
  -DUASTACK_CLIENTAPI_ENABLED=ON \
  -DBUILD_UACLIENTCPP=ON \
  -DUASDK_WITH_CRYPTO=ON \
  -DUASDK_WITH_XMLPARSER=ON \
  -DOPENSSL_ROOT_DIR="${LIBSSL_HOME}" \
  -DOPENSSL_USE_STATIC_LIBS=TRUE \
  -DLIBXML2_INCLUDE_DIR="${LIBXML2_HOME}/include/libxml2" \
  -DLIBXML2_LIBRARIES="${LIBXML2_HOME}/lib/libxml2.a" \
  -DCMAKE_PREFIX_PATH="${LIBSSL_HOME};${LIBXML2_HOME}" \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DCMAKE_INSTALL_PREFIX="${UNIFIED_AUTOMATION_HOME}"  2>&1
cmake --build /tmp/uasdk-src/build --parallel "$(nproc)"  2>&1
cmake --install /tmp/uasdk-src/build  2>&1

rm -rf /tmp/uasdk-src
