#!/bin/sh
# Horizon Turbo para Linux. A pasta do jogo (mundos, opções, horizon-player.txt) é esta pasta.
# Na primeira vez o jogo baixa os arquivos do Minecraft 26.3 direto da Mojang (cerca de 500 MiB).
cd "$(dirname "$0")" || exit 1
# Build não oficial: não envia o "estou jogando" anônimo para o servidor do Horizon oficial.
HORIZON_TELEMETRY_URL=off exec ./horizon-client "$@"
