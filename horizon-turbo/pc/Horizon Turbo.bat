@echo off
rem Horizon Turbo para Windows. A pasta do jogo (mundos, opcoes, horizon-player.txt) e esta pasta.
rem Na primeira vez o jogo baixa os arquivos do Minecraft 26.3 direto da Mojang (cerca de 500 MiB).
cd /d "%~dp0"
rem Build nao oficial: nao envia o "estou jogando" anonimo para o servidor do Horizon oficial.
set HORIZON_TELEMETRY_URL=off
"%~dp0horizon-client.exe" %*
