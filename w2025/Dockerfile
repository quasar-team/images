FROM registry.cern.ch/mcr.microsoft.com/windows/server:ltsc2025
ENV BOOST_HOME=C:\\boost
ENV UNIFIED_AUTOMATION_HOME=C:\\unified-automation
ENV OPEN6_HOME=C:\\open6
ENV XERCES_C_HOME=C:\\xerces-c

WORKDIR C:\\
COPY . .

RUN powershell -NoLogo -NoProfile -ExecutionPolicy Bypass .\install.ps1

ENTRYPOINT ["pwsh", "-NoLogo", "-NoProfile", "-File", "C:\\entrypoint.ps1"]
