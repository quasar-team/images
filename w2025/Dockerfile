FROM registry.cern.ch/mcr.microsoft.com/windows/server:ltsc2025

WORKDIR C:\
COPY . .

RUN powershell -NoLogo -NoProfile -ExecutionPolicy Bypass .\install.ps1
