#!/usr/bin/env bash
set -euo pipefail

: "${NET_SNMP_HOME:?NET_SNMP_HOME is required to install Net-SNMP}"
: "${LIBSSL_HOME:?LIBSSL_HOME is required to build Net-SNMP}"

NET_SNMP_VERSION="5.9.5.2"
NET_SNMP_URL="https://github.com/net-snmp/net-snmp/archive/refs/tags/v${NET_SNMP_VERSION}.tar.gz"

echo NET-SNMP VERSION: "${NET_SNMP_VERSION}" >> /ISSUE
echo NET_SNMP_HOME: "${NET_SNMP_HOME}" >> /ISSUE
echo "*******************" >> /ISSUE

rm -rf /tmp/net-snmp-src
mkdir -p /tmp/net-snmp-src
curl -fsSL "${NET_SNMP_URL}" \
  | tar -xz -C /tmp/net-snmp-src --strip-components=1

rm -rf "${NET_SNMP_HOME}"

pushd /tmp/net-snmp-src

./configure \
  --prefix="${NET_SNMP_HOME}" \
  --with-openssl="${LIBSSL_HOME}/lib" \
  --disable-shared \
  --enable-static \
  --disable-debugging \
  --disable-manuals
make -j"$(nproc)"
make install
popd

rm -rf /tmp/net-snmp-src
