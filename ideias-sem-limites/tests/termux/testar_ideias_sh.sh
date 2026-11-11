#!/usr/bin/env bash
# Teste de ponta a ponta do termux/ideias.sh contra o Open Cloud simulado.
# Uso: bash tests/termux/testar_ideias_sh.sh   (a partir de ideias-sem-limites/)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
KEY="chave-de-teste-123"
export IDEIAS_CONF_DIR="$WORK/state"
export IDEIAS_BASE="$WORK/downloads"
export IDEIAS_API="http://localhost"
export IDEIAS_MOCK_WORK="$WORK"
export IDEIAS_MOCK_KEY="$KEY"
export IDEIAS_MOCK_ADAPTER="$ROOT/tests/termux/mock_curl_stdio.py"
export IDEIAS_RAW="file://$ROOT"
mkdir -p "$IDEIAS_CONF_DIR" "$IDEIAS_BASE"
S="$ROOT/termux/ideias.sh"
falhas=0
check() { if eval "$2"; then echo "  OK   $1"; else echo "  FALHA $1"; falhas=$((falhas + 1)); fi; }

trap 'rm -rf "$WORK"' EXIT
# O handler HTTP simulado recebe bytes em memoria; nao abre portas ou rede.
# So a fronteira HTTP e dobrada. Downloads file:// usam o curl real.
curl() {
 if [[ "${@: -1}" == file://* ]];then command curl "$@"
 else (cd "$IDEIAS_MOCK_WORK" && python3 "$IDEIAS_MOCK_ADAPTER" "$@")
 fi
}
export -f curl

echo "== configurar"
printf '\n\n%s\n' "$KEY" | bash "$S" configurar >/dev/null
check "chave salva com permissão 600" '[[ "$(stat -c %a "$IDEIAS_CONF_DIR/chave")" == 600 ]]'
check "chave não vaza no config" '! grep -q "$KEY" "$IDEIAS_CONF_DIR/config"'

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
bash "$S" enviar "$IDEIAS_BASE/IdeiasSemLimites/V3/IdeiasSemLimites_V3.rbxl" >"$WORK/enviar.log" 2>&1 || { cat "$WORK/enviar.log"; false; }
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

echo "== teste concluido mas reprovado precisa falhar"
if bash "$S" testar 999 >"$WORK/reprovado.log" 2>&1;then r=1;else r=0;fi
check "ok=false nao e tratado como teste aprovado" '[[ $r == 0 ]]'

echo "== enviar-assets"
bash "$S" enviar-assets >"$WORK/assets.log" 2>&1 || { cat "$WORK/assets.log"; false; }
check "Assets API salvou sem publicar" 'grep -q "revisão 7" "$WORK/assets.log"'
check "multipart com published=false" 'python3 -c "import json;l=json.load(open(\"$WORK/mock_log.json\"));exit(0 if any(e.get(\"has_request\") for e in l) else 1)"'

echo "== sons (áudio do ElevenLabs -> asset -> ID gravado no lugar)"
printf '999\n' | bash "$S" sons >"$WORK/sons.log" 2>&1 || { cat "$WORK/sons.log"; false; }
check "áudio enviado como Audio/ogg" 'python3 -c "import json;l=json.load(open(\"$WORK/mock_log.json\"));exit(0 if any(e.get(\"audio\") for e in l) else 1)"'
check "ID do áudio gravado no lugar" 'grep -q "Id = 123456, --@@SPRITE_ID@@" "$IDEIAS_BASE/IdeiasSemLimites/V3/IdeiasSemLimites_V3_sons.rbxlx"'
check "lugar com sons salvo (Saved)" 'grep -q "versão" "$WORK/sons.log"'

echo "== verificar-sons (moderação) e áudio igual reaproveitado"
bash "$S" verificar-sons >"$WORK/vs.log" 2>&1 || { cat "$WORK/vs.log"; false; }
check "estado da moderação lido" 'grep -q "APROVADO" "$WORK/vs.log"'
check "chave não aparece na consulta" '! grep -q "$KEY" "$WORK/vs.log"'
n1=$(python3 -c "import json;print(sum(1 for e in json.load(open('$WORK/mock_log.json')) if e.get('audio')))")
printf '999\n' | bash "$S" sons >"$WORK/sons2.log" 2>&1 || { cat "$WORK/sons2.log"; false; }
n2=$(python3 -c "import json;print(sum(1 for e in json.load(open('$WORK/mock_log.json')) if e.get('audio')))")
check "mesmo áudio não é enviado de novo" '[[ "$n1" == "$n2" ]] && grep -q "reaproveitado" "$WORK/sons2.log"'

echo "== imagens (logo do Canva -> Decal -> ID gravado no lugar)"
bash "$S" imagens >"$WORK/img.log" 2>&1 || { cat "$WORK/img.log"; false; }
check "ID do logo gravado no lugar" 'grep -q "Logo = 234567, --@@LOGO_ID@@" "$IDEIAS_BASE/IdeiasSemLimites/V3/IdeiasSemLimites_V3_final.rbxlx"'
check "ID dos icones gravado no lugar" 'grep -q "Icons = 345678, --@@ICONS_ID@@" "$IDEIAS_BASE/IdeiasSemLimites/V3/IdeiasSemLimites_V3_final.rbxlx"'
check "lugar com logo salvo (Saved)" 'grep -q "versão" "$WORK/img.log"'

echo "== imagens iguais reaproveitadas, sons preservam imagens e envio padrao"
n1=$(python3 -c "import json;print(sum(1 for e in json.load(open('$WORK/mock_log.json')) if e.get('decal')))")
bash "$S" imagens >"$WORK/img2.log" 2>&1 || { cat "$WORK/img2.log"; false; }
n2=$(python3 -c "import json;print(sum(1 for e in json.load(open('$WORK/mock_log.json')) if e.get('decal')))")
check "imagens iguais nao sao reenviadas" '[[ "$n1" == "$n2" ]] && grep -q "reaproveitado" "$WORK/img2.log"'
bash "$S" sons >"$WORK/sons3.log" 2>&1 || { cat "$WORK/sons3.log"; false; }
check "sons mantem o logo confirmado" 'grep -q "Logo = 234567, --@@LOGO_ID@@" "$IDEIAS_BASE/IdeiasSemLimites/V3/IdeiasSemLimites_V3_final.rbxlx"'
bash "$S" enviar >"$WORK/padrao.log" 2>&1 || { cat "$WORK/padrao.log"; false; }
check "envio padrao usa o arquivo final" 'grep -q "IdeiasSemLimites_V3_final.rbxlx" "$WORK/padrao.log"'

echo "== destino diferente bloqueado"
cp "$IDEIAS_CONF_DIR/config" "$WORK/config-original"
printf 'UNIVERSE_ID="999"\nPLACE_ID="888"\n' >"$IDEIAS_CONF_DIR/config"
if bash "$S" enviar >"$WORK/destino.log" 2>&1;then r=1;else r=0;fi
check "outro universo recusado localmente" '[[ $r == 0 ]] && grep -q "Destino bloqueado" "$WORK/destino.log"'
cp "$WORK/config-original" "$IDEIAS_CONF_DIR/config"

echo "== publicar exige confirmação"
if echo "nao" | bash "$S" publicar "$IDEIAS_BASE/IdeiasSemLimites/V3/IdeiasSemLimites_V3.rbxl" >/dev/null 2>&1; then r=1; else r=0; fi
check "publicação cancelada sem PUBLICAR" '[[ $r == 0 ]]'
check "nenhum Published enviado" '! grep -q "versionType=Published" "$WORK/mock_log.json"'

echo "== chave errada"
printf 'outra' >"$IDEIAS_CONF_DIR/chave"
if bash "$S" enviar >/dev/null 2>&1; then r=1; else r=0; fi
check "401 tratado" '[[ $r == 0 ]]'

echo
python3 "$ROOT/tests/termux/test_midias.py" || exit 1
python3 "$ROOT/tests/termux/test_preparar_midias.py" || exit 1
if [[ $falhas -eq 0 ]]; then echo "RESULTADO: TUDO OK"; else echo "RESULTADO: $falhas FALHA(S)"; exit 1; fi
