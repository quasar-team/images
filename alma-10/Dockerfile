FROM gitlab-registry.cern.ch/linuxsupport/alma10-base:latest
ARG ICS_REPO_DEPS_TOKEN

RUN dnf install -q -y epel-release &&\
    dnf update -q -y &&\
    dnf install -q -y cmake ninja-build g++ automake autoconf libtool \
                   cppcheck nano git git-lfs python \
                   python-pip python-devel doxygen \
                   curl tar unzip which &&\
    dnf clean all
RUN pip install --quiet pre-commit clang-format pytest pybind11 &

RUN uname -a &>> /ISSUE &&\
    echo "*******************" >> /ISSUE &&\
    echo Ninja Version: $(ninja-build --version) >> /ISSUE &&\
    echo "*******************" >> /ISSUE &&\
    cmake --version &> /ISSUE &&\
    echo "*******************" >> /ISSUE &&\
    g++ --version &>> /ISSUE &&\
    echo "*******************" >> /ISSUE

COPY build-boost.sh build-uasdk.sh build-open6.sh /tmp/
RUN chmod +x /tmp/build-boost.sh /tmp/build-uasdk.sh /tmp/build-open6.sh &&\
    /tmp/build-boost.sh &&\
    ICS_REPO_DEPS_TOKEN="$ICS_REPO_DEPS_TOKEN" /tmp/build-uasdk.sh &&\
    /tmp/build-open6.sh

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]