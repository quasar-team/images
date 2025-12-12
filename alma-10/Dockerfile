FROM gitlab-registry.cern.ch/linuxsupport/alma10-base:latest

RUN dnf install -y epel-release &&\
    dnf update -y &&\
    dnf install -y cmake ninja-build g++ autoconf cppcheck nano git git-lfs python \
                   python-pip python-devel doxygen &&\
    dnf clean all
RUN pip install pre-commit clang-format pytest pybind11

RUN g++ --version &> /ISSUE &&\
    echo "*******************" >> /ISSUE &&\
    echo Ninja Version: $(ninja-build --version) >> /ISSUE &&\
    echo "*******************" >> /ISSUE &&\
    cmake --version &> /ISSUE &&\
    echo "*******************" >> /ISSUE &&\
    uname -a &> /ISSUE