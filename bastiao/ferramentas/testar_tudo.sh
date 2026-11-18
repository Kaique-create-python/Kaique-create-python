#!/usr/bin/env bash
# PROJETO BASTIÃO :: roda todos os testes offline da etapa (da raiz do repositório)
#   bash bastiao/ferramentas/testar_tudo.sh [caminho/do/place_original.rbxl]
set -euo pipefail
PLACE="${1:-${BASTIAO_PLACE:-}}"
lune run bastiao/ferramentas/sintaxe.luau
lune run bastiao/ferramentas/teste_historia.luau
lune run bastiao/ferramentas/teste_idiomas.luau
lune run bastiao/ferramentas/teste_fluxo.luau
if [ -n "$PLACE" ] && [ -f "$PLACE" ]; then
  lune run bastiao/ferramentas/teste_cenario.luau "$PLACE"
  export BASTIAO_PLACE="$PLACE"
else
  echo "[Cenario] pulado: informe o place_original.rbxl para conferir a geometria no mapa real"
fi
python3 -m unittest discover -s bastiao/tests
python3 bastiao/ferramentas/gerar_etapa2.py
python3 bastiao/dist/BASTIAO_ETAPA2.py testar
