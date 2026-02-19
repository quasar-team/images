#!/usr/bin/env bash
set -euo pipefail

: "${LIBSSL_HOME:?LIBSSL_HOME is required to install OpenSSL}"

OPENSSL_VERSION="3.5.5"
OPENSSL_URL="https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz"

echo OPENSSL VERSION: "${OPENSSL_VERSION}" >> /ISSUE
echo LIBSSL_HOME: "${LIBSSL_HOME}" >> /ISSUE
echo "*******************" >> /ISSUE

mkdir -p /tmp/openssl-src
curl -fsSL "${OPENSSL_URL}" \
  | tar -xz -C /tmp/openssl-src --strip-components=1

rm -rf "${LIBSSL_HOME}"

pushd /tmp/openssl-src
./Configure linux-x86_64 no-shared no-tests no-apps \
  --prefix="${LIBSSL_HOME}" \
  --openssldir="${LIBSSL_HOME}/ssl"
make -j"$(nproc)"
make install_sw
popd

rm -rf /tmp/openssl-src
