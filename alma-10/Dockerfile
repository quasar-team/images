FROM gitlab-registry.cern.ch/linuxsupport/alma10-base:latest
ARG ICS_REPO_DEPS_TOKEN

RUN dnf install -q -y epel-release &&\
    dnf update -q -y &&\
    dnf install -q -y cmake ninja-build g++ automake autoconf libtool \
                   cppcheck nano git git-lfs python \
                   python-pip python-devel doxygen \
                   curl tar unzip which &>/dev/null &&\
    dnf clean all
RUN pip install --quiet pre-commit clang-format pytest pybind11 &>/dev/null

RUN g++ --version &> /ISSUE &&\
    echo "*******************" >> /ISSUE &&\
    echo Ninja Version: $(ninja-build --version) >> /ISSUE &&\
    echo "*******************" >> /ISSUE &&\
    cmake --version &> /ISSUE &&\
    echo "*******************" >> /ISSUE &&\
    uname -a &> /ISSUE

RUN mkdir -p /tmp/boost-src &&\
    curl -fsSL https://archives.boost.io/release/1.90.0/source/boost_1_90_0.tar.gz \
      | tar -xz -C /tmp/boost-src --strip-components=1 &&\
    cd /tmp/boost-src &&\
    ./bootstrap.sh &&\
    ./b2 --quiet -d0 -j"$(nproc)" link=static runtime-link=static variant=release threading=multi \
      --prefix=/opt/boost install &>/dev/null &&\
    rm -rf /tmp/boost-src

RUN mkdir -p /tmp/uasdk-src &&\
    curl -fsSL -H "PRIVATE-TOKEN: $ICS_REPO_DEPS_TOKEN" \
      "https://ics-deps-repo.web.cern.ch/quasar/uasdk/2.0.2-675/uasdkcppbundle-src-linux-v2.0.2-675.zip" \
      -o /tmp/uasdk-src/uasdk.zip &&\
    unzip -q /tmp/uasdk-src/uasdk.zip -d /tmp/uasdk-src/source &&\
    UASDK_ROOT="$(find /tmp/uasdk-src/source -name CMakeLists.txt -printf '%d:%h\n' | sort -n | head -n 1 | cut -d: -f2-)" &&\
    cmake -S "$UASDK_ROOT" -B /tmp/uasdk-src/build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=OFF \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      -DCMAKE_INSTALL_PREFIX=/opt/unified-automation &> /dev/null &&\
    cmake --build /tmp/uasdk-src/build --parallel "$(nproc)" &> /dev/null &&\
    cmake --install /tmp/uasdk-src/build &> /dev/null &&\
    rm -Rf /tmp/uasdk-src

RUN mkdir -p /tmp/open6-src &&\
    curl -fsSL https://github.com/open62541/open62541/archive/refs/tags/v1.5.0.tar.gz \
      | tar -xz -C /tmp/open6-src --strip-components=1 &&\
    cmake -S /tmp/open6-src -B /tmp/open6-src/build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=OFF \
      -DUA_BUILD_SHARED_LIBS=OFF \
      -DCMAKE_INSTALL_PREFIX=/opt/open6 \
      -DCMAKE_INSTALL_LIBDIR=libs &> /dev/null &&\
    cmake --build /tmp/open6-src/build --parallel "$(nproc)" &> /dev/null &&\
    cmake --install /tmp/open6-src/build &> /dev/null &&\
    rm -rf /tmp/open6-src
