#!/usr/bin/env bash
set -euo pipefail

BOOST_VERSION="1.90.0"
BOOST_URL="https://archives.boost.io/release/${BOOST_VERSION}/source/boost_1_90_0.tar.gz"

echo BOOST VERSION: "${BOOST_VERSION}" >> /ISSUE
echo "*******************" >> /ISSUE

mkdir -p /tmp/boost-src
curl -fsSL "${BOOST_URL}" \
  | tar -xz -C /tmp/boost-src --strip-components=1

pushd /tmp/boost-src >/dev/null
./bootstrap.sh
./b2 --quiet -d0 -j"$(nproc)" link=static runtime-link=static variant=release threading=multi \
  --prefix=/opt/boost install >/dev/null 2>&1
popd >/dev/null

rm -rf /tmp/boost-src
