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
    test -n "$ICS_REPO_DEPS_TOKEN" &&\
    curl -fsSL -H "PRIVATE-TOKEN: $ICS_REPO_DEPS_TOKEN" \
      "https://ics-deps-repo.web.cern.ch/quasar/uasdk/2.0.2-675/uasdkcppbundle-src-linux-v2.0.2-675.zip" \
      -o /tmp/uasdk-src/uasdk.zip &&\
    unzip -tq /tmp/uasdk-src/uasdk.zip &&\
    unzip -q /tmp/uasdk-src/uasdk.zip -d /tmp/uasdk-src/unpacked &&\
    UASDK_ROOT="$(find /tmp/uasdk-src/unpacked -name CMakeLists.txt -printf '%d:%h\n' | sort -n | head -n 1 | cut -d: -f2-)" &&\
    test -n "$UASDK_ROOT" &&\
    cmake -S "$UASDK_ROOT" -B /tmp/uasdk-src/build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=OFF \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      -DCMAKE_INSTALL_PREFIX=/opt/unified-automation &&\
    cmake --build /tmp/uasdk-src/build --parallel "$(nproc)" &&\
    cmake --install /tmp/uasdk-src/build &&\
    rm -Rf /tmp/uasdk-src
