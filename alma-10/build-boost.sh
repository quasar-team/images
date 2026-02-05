#!/usr/bin/env bash
set -euo pipefail

mkdir -p /tmp/boost-src
curl -fsSL https://archives.boost.io/release/1.90.0/source/boost_1_90_0.tar.gz \
  | tar -xz -C /tmp/boost-src --strip-components=1

pushd /tmp/boost-src >/dev/null
./bootstrap.sh
./b2 --quiet -d0 -j"$(nproc)" link=static runtime-link=static variant=release threading=multi \
  --prefix=/opt/boost install >/dev/null 2>&1
popd >/dev/null

rm -rf /tmp/boost-src
