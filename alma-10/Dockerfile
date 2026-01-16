FROM gitlab-registry.cern.ch/linuxsupport/alma10-base:latest

RUN dnf install -y epel-release &&\
    dnf update -y &&\
    dnf install -y cmake ninja-build g++ automake autoconf libtool \
                   cppcheck nano git git-lfs python \
                   python-pip python-devel doxygen \
                   curl tar &&\
    dnf clean all
RUN pip install pre-commit clang-format pytest pybind11

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
    ./b2 -j"$(nproc)" link=static runtime-link=static variant=release threading=multi \
      --prefix=/boost install &&\
    rm -rf /tmp/boost-src
