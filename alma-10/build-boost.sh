#!/usr/bin/env bash
set -euo pipefail

: "${BOOST_HOME:?BOOST_HOME is required to install Boost}"

BOOST_VERSION="1.90.0"
BOOST_URL="https://archives.boost.io/release/${BOOST_VERSION}/source/boost_1_90_0.tar.gz"

echo BOOST VERSION: "${BOOST_VERSION}" >> /ISSUE
echo BOOST_HOME: "${BOOST_HOME}" >> /ISSUE
echo "*******************" >> /ISSUE

mkdir -p /tmp/boost-src
curl -fsSL "${BOOST_URL}" \
  | tar -xz -C /tmp/boost-src --strip-components=1

pushd /tmp/boost-src
./bootstrap.sh
./b2 --quiet -d0 -j"$(nproc)" link=static runtime-link=shared variant=release threading=multi \
  cflags=-fPIC cxxflags=-fPIC \
  --prefix="${BOOST_HOME}" install
popd

rm -rf /tmp/boost-src
