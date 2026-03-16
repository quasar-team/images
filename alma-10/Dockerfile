FROM gitlab-registry.cern.ch/linuxsupport/alma10-base:latest
ARG ICS_REPO_DEPS_TOKEN
ENV BOOST_HOME=/opt/boost
ENV UNIFIED_AUTOMATION_HOME=/opt/unified-automation
ENV XERCES_C_HOME=/opt/xerces-c
ENV LIBSSL_HOME=/opt/libssl
ENV LIBXML2_HOME=/opt/libxml2
ENV NET_SNMP_HOME=/opt/net-snmp
ENV XSD_HOME=/opt/xsd
ENV LIBXSD_HOME=/opt/libxsd
ENV PATH=/opt/xsd:${PATH}

COPY build-boost.sh build-uasdk.sh build-xerces-c.sh build-openssl.sh build-libxml2.sh build-net-snmp.sh install-libxsd.sh /tmp/
COPY entrypoint.sh /entrypoint.sh

RUN dnf install -q -y epel-release &&\
    dnf update -q -y &&\
    dnf install -q -y cmake ninja-build g++ automake autoconf libtool \
                   cppcheck nano git git-lfs patch graphviz xsd astyle \
                   python python-pip python-devel doxygen perl \
                   curl tar unzip which rpm-build texlive-latex \
                   doxygen-latex texlive-collection-latexrecommended \
                   texlive-collection-fontsrecommended &&\
    dnf clean all &&\
    pip install --quiet pre-commit clang-format pytest pybind11 colorama jinja2 lxml pygit2 &&\
    echo "Generated: $(date '+%Y-%m-%d %H:%M')" >> /ISSUE &&\
    echo "*******************" >> /ISSUE &&\
    uname -a &>> /ISSUE &&\
    echo "*******************" >> /ISSUE &&\
    echo Ninja Version: $(ninja-build --version) >> /ISSUE &&\
    echo "*******************" >> /ISSUE &&\
    cmake --version &>> /ISSUE &&\
    echo "*******************" >> /ISSUE &&\
    g++ --version &>> /ISSUE &&\
    echo "*******************" >> /ISSUE &&\
    chmod +x /tmp/build-boost.sh /tmp/build-uasdk.sh /tmp/build-xerces-c.sh /tmp/build-openssl.sh /tmp/build-libxml2.sh /tmp/build-net-snmp.sh /tmp/install-libxsd.sh /entrypoint.sh &&\
    /tmp/build-openssl.sh &&\
    /tmp/build-libxml2.sh &&\
    /tmp/build-net-snmp.sh &&\
    /tmp/install-libxsd.sh &&\
    /tmp/build-boost.sh &&\
    ICS_REPO_DEPS_TOKEN="$ICS_REPO_DEPS_TOKEN" /tmp/build-uasdk.sh &&\
    /tmp/build-xerces-c.sh
ENTRYPOINT ["/entrypoint.sh"]
