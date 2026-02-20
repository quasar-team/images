#!/usr/bin/env bash
set -euo pipefail

: "${LIBXSD_HOME:?LIBXSD_HOME is required to install libxsd headers}"

LIBXSD_VERSION="4.2.0"
LIBXSD_URL="https://www.codesynthesis.com/download/xsd/4.2/libxsd-${LIBXSD_VERSION}.tar.gz"

echo LIBXSD VERSION: "${LIBXSD_VERSION}" >> /ISSUE
echo LIBXSD_HOME: "${LIBXSD_HOME}" >> /ISSUE
echo "*******************" >> /ISSUE

mkdir -p /tmp/libxsd-src
curl -fsSL "${LIBXSD_URL}" \
  | tar -xz -C /tmp/libxsd-src --strip-components=1

if [[ ! -d /tmp/libxsd-src/xsd ]]; then
  echo "Unable to locate libxsd headers in extracted archive." >&2
  exit 1
fi

rm -rf "${LIBXSD_HOME}"
mkdir -p "${LIBXSD_HOME}/include"
cp -a /tmp/libxsd-src/xsd "${LIBXSD_HOME}/include/"

rm -rf /tmp/libxsd-src
