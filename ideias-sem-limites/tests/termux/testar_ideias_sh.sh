#!/usr/bin/env bash
# Teste de ponta a ponta do termux/ideias.sh contra o Open Cloud simulado.
# Uso: bash tests/termux/testar_ideias_sh.sh   (a partir de ideias-sem-limites/)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
PORT=18765
KEY="chave-de-teste-123"
export HOME="$WORK/home"
export IDEIAS_BASE="$WORK/downloads"
export IDEIAS_API="http://127.0.0.1:$PORT"
export IDEIAS_RAW="file://$ROOT"
mkdir -p "$HOME" "$IDEIAS_BASE"
S="$ROOT/termux/ideias.sh"
falhas=0
check() { if eval "$2"; then echo "  OK   $1"; else echo "  FALHA $1"; falhas=$((falhas + 1)); fi; }

(cd "$WORK" && python3 "$ROOT/tests/termux/mock_opencloud.py" "$PORT" "$KEY" &)
sleep 1
trap 'pkill -f "mock_opencloud.py $PORT" || true; rm -rf "$WORK"' EXIT

echo "== configurar"
printf '\n\n%s\n' "$KEY" | bash "$S" configurar >/dev/null
check "chave salva com permissão 600" '[[ "$(stat -c %a "$HOME/.ideias/chave")" == 600 ]]'
check "chave não vaza no config" '! grep -q "$KEY" "$HOME/.ideias/config"'

echo "== baixar (de file:// local)"
mkdir -p "$ROOT/dist"
bash "$S" baixar >"$WORK/baixar.log" 2>&1 || { cat "$WORK/baixar.log"; false; }
check "rbxl baixado e conferido" '[[ -s "$IDEIAS_BASE/IdeiasSemLimites/V3/IdeiasSemLimites_V3.rbxl" ]]'

echo "== backup"
printf '<roblox version="4"></roblox>' >"$IDEIAS_BASE/Ideias_Sem_Limites_v01.rbxlx"
bash "$S" backup >/dev/null
check "backup copiou a V1" 'ls "$IDEIAS_BASE"/IdeiasSemLimites/backup-*/Ideias_Sem_Limites_v01.rbxlx >/dev/null'
check "original intacto" '[[ -f "$IDEIAS_BASE/Ideias_Sem_Limites_v01.rbxlx" ]]'

echo "== enviar (binário rbxl -> octet-stream)"
bash "$S" enviar >"$WORK/enviar.log" 2>&1 || { cat "$WORK/enviar.log"; false; }
check "versão 5 registrada" 'grep -q "versão 5" "$WORK/enviar.log"'
check "Content-Type octet-stream" 'python3 -c "import json;l=json.load(open(\"$WORK/mock_log.json\"));exit(0 if any(e.get(\"ctype\")==\"application/octet-stream\" and e.get(\"size\",0)>1000 for e in l) else 1)"'
check "chave não aparece na saída" '! grep -q "$KEY" "$WORK/enviar.log"'
check "cabeçalho temporário apagado" '! ls "${TMPDIR:-/tmp}"/ideias_hdr.* >/dev/null 2>&1'

echo "== enviar (rbxlx -> application/xml)"
bash "$S" enviar "$IDEIAS_BASE/IdeiasSemLimites/V3/IdeiasSemLimites_V3.rbxlx" >/dev/null
check "Content-Type xml" 'python3 -c "import json;l=json.load(open(\"$WORK/mock_log.json\"));exit(0 if any(e.get(\"ctype\")==\"application/xml\" for e in l) else 1)"'

echo "== enviar arquivo vazio é recusado antes do envio"
: >"$WORK/vazio.rbxlx"
if bash "$S" enviar "$WORK/vazio.rbxlx" >/dev/null 2>&1; then r=1; else r=0; fi
check "vazio recusado localmente" '[[ $r == 0 ]]'

echo "== testar (Luau Execution)"
bash "$S" testar >"$WORK/testar.log" 2>&1 || { cat "$WORK/testar.log"; false; }
check "tarefa concluída e relatório salvo" 'grep -q "Relatório salvo" "$WORK/testar.log"'
check "script de testes enviado no JSON" 'python3 -c "import json;l=json.load(open(\"$WORK/mock_log.json\"));exit(0 if any(e.get(\"script_bytes\",0)>500 for e in l) else 1)"'

echo "== enviar-assets"
bash "$S" enviar-assets >"$WORK/assets.log" 2>&1 || { cat "$WORK/assets.log"; false; }
check "Assets API salvou sem publicar" 'grep -q "revisão 7" "$WORK/assets.log"'
check "multipart com published=false" 'python3 -c "import json;l=json.load(open(\"$WORK/mock_log.json\"));exit(0 if any(e.get(\"has_request\") for e in l) else 1)"'

echo "== sons (áudio do ElevenLabs -> asset -> ID gravado no lugar)"
printf '999\n' | bash "$S" sons >"$WORK/sons.log" 2>&1 || { cat "$WORK/sons.log"; false; }
check "áudio enviado como Audio/ogg" 'python3 -c "import json;l=json.load(open(\"$WORK/mock_log.json\"));exit(0 if any(e.get(\"audio\") for e in l) else 1)"'
check "ID do áudio gravado no lugar" 'grep -q "Id = 123456, --@@SPRITE_ID@@" "$IDEIAS_BASE/IdeiasSemLimites/V3/IdeiasSemLimites_V3_sons.rbxlx"'
check "lugar com sons salvo (Saved)" 'grep -q "versão" "$WORK/sons.log"'

echo "== publicar exige confirmação"
if echo "nao" | bash "$S" publicar "$IDEIAS_BASE/IdeiasSemLimites/V3/IdeiasSemLimites_V3.rbxl" >/dev/null 2>&1; then r=1; else r=0; fi
check "publicação cancelada sem PUBLICAR" '[[ $r == 0 ]]'
check "nenhum Published enviado" '! grep -q "versionType=Published" "$WORK/mock_log.json"'

echo "== chave errada"
printf 'outra' >"$HOME/.ideias/chave"
if bash "$S" enviar >/dev/null 2>&1; then r=1; else r=0; fi
check "401 tratado" '[[ $r == 0 ]]'

echo
if [[ $falhas -eq 0 ]]; then echo "RESULTADO: TUDO OK"; else echo "RESULTADO: $falhas FALHA(S)"; exit 1; fi
