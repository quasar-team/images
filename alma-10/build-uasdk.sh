#!/usr/bin/env bash
set -euo pipefail

: "${ICS_REPO_DEPS_TOKEN:?ICS_REPO_DEPS_TOKEN is required to build UASDK}"

mkdir -p /tmp/uasdk-src
curl -fsSL -H "PRIVATE-TOKEN: ${ICS_REPO_DEPS_TOKEN}" \
  "https://ics-deps-repo.web.cern.ch/quasar/uasdk/2.0.2-675/uasdkcppbundle-src-linux-v2.0.2-675.zip" \
  -o /tmp/uasdk-src/uasdk.zip
unzip -q /tmp/uasdk-src/uasdk.zip -d /tmp/uasdk-src/source

uasdk_root="$(find /tmp/uasdk-src/source -name CMakeLists.txt -printf '%d:%h\n' | sort -n | head -n 1 | cut -d: -f2-)"
cmake -S "${uasdk_root}" -B /tmp/uasdk-src/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DCMAKE_INSTALL_PREFIX=/opt/unified-automation >/dev/null 2>&1
cmake --build /tmp/uasdk-src/build --parallel "$(nproc)" >/dev/null 2>&1
cmake --install /tmp/uasdk-src/build >/dev/null 2>&1

rm -rf /tmp/uasdk-src
