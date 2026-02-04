FROM gitlab-registry.cern.ch/linuxsupport/alma10-base:latest
ARG ICS_REPO_DEPS_TOKEN

RUN dnf install -q -y epel-release &&\
    dnf update -q -y &&\
    dnf install -q -y cmake ninja-build g++ automake autoconf libtool \
                   cppcheck nano git git-lfs python \
                   python-pip python-devel doxygen \
                   curl tar unzip which &&\
    dnf clean all
RUN pip install --quiet pre-commit clang-format pytest pybind11

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
      --prefix=/opt/boost install &&\
    rm -rf /tmp/boost-src

RUN mkdir -p /tmp/uasdk-src &&\
    curl -fsSL -H "PRIVATE_TOKEN: $ICS_REPO_DEPS_TOKEN" \
      "https://ics-deps-repo.web.cern.ch/quasar/uasdk/src/uasdkcppbundle-src-linux-v2.0.2-675.zip" - \
      | unzip -d /tmp/uasdk-src &&\
    ls /tmp/uasdk-src/ &&\
    rm -Rf /tmp/uasdk-src