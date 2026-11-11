#!/data/data/com.termux/files/usr/bin/env bash
# =============================================================================
#  Ideias Sem Limites — ferramenta Termux (Android) para Roblox Open Cloud
# =============================================================================
#  Subcomandos (rode sem argumentos para ver a ajuda):
#    configurar        guarda IDs e a chave Open Cloud só neste celular
#    baixar            baixa a V3 (rbxl/rbxlx) e ferramentas do GitHub e confere SHA-256
#    backup            copia V1/V2 encontradas para uma pasta de backup (nunca apaga)
#    diagnosticar ARQ  analisa um .rbxlx (ex.: a V2) e aponta a causa do erro 400
#    enviar [ARQ]      envia como versão SALVA (Saved) — nunca publica
#    enviar-assets [ARQ]  envia pela Assets API (salva sem publicar, com acompanhamento)
#    testar [VERSAO]   roda os testes automáticos NA NUVEM (Luau Execution)
#    auditar [VERSAO]  lista o conteúdo de uma versão (ex.: a V1, versão 4)
#    publicar ARQ      publica para os jogadores (pede confirmação digitando PUBLICAR)
#    status            mostra o histórico de envios/testes deste celular
#
#  Segurança: a chave fica em ~/.ideias/chave (permissão 600), é passada ao
#  curl por arquivo de cabeçalho temporário e nunca aparece na tela ou em logs.
# =============================================================================
set -euo pipefail

UNIVERSE_ID_PADRAO="10774214423"
PLACE_ID_PADRAO="122033314086516"
RAMO="claude/ideias-sem-limites-roblox-t44sea"
RAW="${IDEIAS_RAW:-https://raw.githubusercontent.com/Kaique-create-python/Kaique-create-python/${RAMO}/ideias-sem-limites}"
CONF_DIR="${HOME}/.ideias"
CONF="${CONF_DIR}/config"
CHAVE="${CONF_DIR}/chave"
LEDGER="${CONF_DIR}/historico.tsv"
BASE="${IDEIAS_BASE:-${HOME}/storage/downloads}"
PASTA="${BASE}/IdeiasSemLimites"
API="${IDEIAS_API:-https://apis.roblox.com}"

cor() { printf '\033[%sm%s\033[0m\n' "$1" "$2"; }
info() { cor "1;36" "▶ $*"; }
ok() { cor "1;32" "✔ $*"; }
aviso() { cor "1;33" "⚠ $*"; }
erro() { cor "1;31" "✘ $*" >&2; }
morre() { erro "$*"; exit 1; }

precisa() {
	for c in "$@"; do
		command -v "$c" >/dev/null 2>&1 || morre "Falta o comando '$c'. Rode: pkg install curl python coreutils -y"
	done
}

carregar_config() {
	UNIVERSE_ID="$UNIVERSE_ID_PADRAO"
	PLACE_ID="$PLACE_ID_PADRAO"
	if [[ -f "$CONF" ]]; then
		# shellcheck disable=SC1090
		source "$CONF"
	fi
}

garantir_pastas() {
	if [[ ! -d "$BASE" ]]; then
		morre "Pasta de downloads não encontrada. Rode 'termux-setup-storage', permita o acesso e tente de novo."
	fi
	mkdir -p "$PASTA" "$CONF_DIR"
	chmod 700 "$CONF_DIR"
	[[ -f "$LEDGER" ]] || printf 'data\tacao\tarquivo\tsha256\tversao\tresultado\n' >"$LEDGER"
}

registrar() {
	# data, ação, arquivo, sha, versão, resultado
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" "$3" "$4" "$5" >>"$LEDGER"
}

# cria arquivo de cabeçalho temporário com a chave (removido ao sair)
HDR=""
limpar() {
	if [[ -n "$HDR" && -f "$HDR" ]]; then
		rm -f "$HDR"
	fi
	HDR=""
	return 0
}
trap limpar EXIT INT TERM
cabecalho_chave() {
	[[ -s "$CHAVE" ]] || morre "Chave não configurada. Rode: bash ideias.sh configurar"
	local perm
	perm=$(stat -c '%a' "$CHAVE" 2>/dev/null || echo 600)
	[[ "$perm" == "600" ]] || chmod 600 "$CHAVE"
	umask 077
	HDR=$(mktemp "${TMPDIR:-/tmp}/ideias_hdr.XXXXXX")
	printf 'x-api-key: %s\n' "$(tr -d '\r\n' <"$CHAVE")" >"$HDR"
}

# lê campo de JSON (stdin) com Python, sem dependências extras
json_campo() {
	python3 -c 'import json,sys
d=json.load(sys.stdin)
for k in sys.argv[1].split("."):
    d = d.get(k) if isinstance(d, dict) else None
print("" if d is None else (json.dumps(d, ensure_ascii=False) if isinstance(d,(dict,list)) else d))' "$1"
}

tipo_conteudo() {
	# decide pelo conteúdo, não pela extensão
	local magic
	magic=$(head -c 8 "$1" | od -An -c | tr -d ' \n')
	if [[ "$magic" == "<roblox!"* ]]; then
		echo "application/octet-stream"
	else
		echo "application/xml"
	fi
}

validar_arquivo() {
	local arq="$1"
	[[ -f "$arq" ]] || morre "Arquivo não encontrado: $arq"
	local tam
	tam=$(stat -c '%s' "$arq")
	[[ "$tam" -gt 0 ]] || morre "Arquivo vazio: $arq (download incompleto?)"
	[[ "$tam" -lt 104857600 ]] || morre "Arquivo maior que 100 MB."
	local inicio
	inicio=$(head -c 4 "$arq" | od -An -tx1 | tr -d ' \n')
	if [[ "$inicio" == "504b0304" ]]; then
		morre "Isto é um ZIP. Extraia o .rbxlx/.rbxl antes: unzip '$arq'"
	fi
	echo "$tam"
}

ultima_versao_salva() {
	awk -F'\t' '$2 ~ /enviar/ && $6 == "ok" {v=$5} END {print v}' "$LEDGER"
}

# ---------------------------------------------------------------------------
cmd_configurar() {
	garantir_pastas
	carregar_config
	info "Configuração (Enter mantém o valor atual)"
	read -r -p "Universe ID [$UNIVERSE_ID]: " u
	read -r -p "Place ID [$PLACE_ID]: " p
	UNIVERSE_ID="${u:-$UNIVERSE_ID}"
	PLACE_ID="${p:-$PLACE_ID}"
	[[ "$UNIVERSE_ID" =~ ^[0-9]+$ && "$PLACE_ID" =~ ^[0-9]+$ ]] || morre "IDs devem ser números."
	printf 'UNIVERSE_ID="%s"\nPLACE_ID="%s"\n' "$UNIVERSE_ID" "$PLACE_ID" >"$CONF"
	echo
	info "Cole a chave Open Cloud (não aparece na tela). Enter vazio mantém a atual."
	read -r -s -p "Chave: " k
	echo
	if [[ -n "$k" ]]; then
		umask 077
		printf '%s' "$k" >"$CHAVE"
		chmod 600 "$CHAVE"
		ok "Chave guardada em $CHAVE (somente este usuário do Termux pode ler)."
	fi
	unset k
	ok "Configurado: universo $UNIVERSE_ID, lugar $PLACE_ID"
	echo "Permissões necessárias na chave (Creator Dashboard > Credenciais > editar chave):"
	echo "  • universe-places: Write (enviar versões)  — já usada na V1"
	echo "  • universe.place.luau-execution-session: Read + Write (testes na nuvem)"
	echo "  • asset: Read + Write (opcional, só para 'enviar-assets')"
}

cmd_baixar() {
	precisa curl sha256sum
	garantir_pastas
	local dest="$PASTA/V3"
	mkdir -p "$dest/ferramentas" "$dest/testes"
	info "Baixando a V3 do GitHub (ramo $RAMO)"
	local arquivos=("dist/IdeiasSemLimites_V3.rbxl" "dist/IdeiasSemLimites_V3.rbxlx" "dist/IdeiasSons.ogg" "dist/IdeiasLogo.png" "dist/IdeiasIcones.png" "dist/SHA256SUMS")
	for f in "${arquivos[@]}"; do
		curl -fL --retry 3 -o "$dest/$(basename "$f")" "$RAW/$f" || morre "Falha ao baixar $f"
	done
	curl -fL --retry 3 -o "$dest/ferramentas/diagnosticar_rbxlx.py" "$RAW/tools/diagnosticar_rbxlx.py"
	curl -fL --retry 3 -o "$dest/ferramentas/roblox_reflexao.json.gz" "$RAW/tools/roblox_reflexao.json.gz"
	curl -fL --retry 3 -o "$dest/testes/run_cloud_tests.luau" "$RAW/tests/cloud/run_cloud_tests.luau"
	curl -fL --retry 3 -o "$dest/testes/auditar_lugar.luau" "$RAW/tests/cloud/auditar_lugar.luau"
	info "Conferindo SHA-256"
	(cd "$dest" && sha256sum -c SHA256SUMS) || morre "Soma SHA-256 não confere: baixe de novo."
	ok "Arquivos em $dest"
	ls -la "$dest"
}

cmd_backup() {
	garantir_pastas
	local alvo="$PASTA/backup-$(date '+%Y%m%d-%H%M%S')"
	mkdir -p "$alvo"
	local n=0
	shopt -s nullglob
	for f in "$BASE"/Ideias_Sem_Limites_v01.rbxlx "$BASE"/Ideias_Sem_Limites_V2.rbxlx "$BASE"/Ideias_Sem_Limites_V2_Completo.zip \
		"$BASE"/Servidor_Ideias.server.luau "$BASE"/Interface_Ideias.client.luau "$BASE"/Publicar_no_Termux.sh "$BASE"/gerar_lugar.py \
		"$BASE"/WordResolver.lua "$BASE"/Server_Ideias.lua "$BASE"/Client_Ideias.lua "$BASE"/Publicar_V2_Termux.sh; do
		if [[ -f "$f" ]]; then
			cp -p "$f" "$alvo/"
			n=$((n + 1))
		fi
	done
	(cd "$alvo" && sha256sum ./* >SHA256SUMS 2>/dev/null || true)
	registrar "backup" "$alvo" "-" "-" "$n arquivos"
	ok "$n arquivo(s) copiados para $alvo (os originais não foram tocados)."
	echo "Última versão conhecida aceita na nuvem: 4 (V1). Para voltar a ela: Creator Dashboard >"
	echo "  Experiência > Lugares > Histórico de versões > versão 4 > Restaurar."
}

cmd_diagnosticar() {
	precisa python3
	garantir_pastas
	local arq="${1:-$BASE/Ideias_Sem_Limites_V2.rbxlx}"
	local ferr="$PASTA/V3/ferramentas/diagnosticar_rbxlx.py"
	[[ -f "$ferr" ]] || morre "Ferramenta não encontrada. Rode primeiro: bash ideias.sh baixar"
	local extra=()
	[[ -f "$BASE/Ideias_Sem_Limites_v01.rbxlx" ]] && extra+=(--comparar "$BASE/Ideias_Sem_Limites_v01.rbxlx")
	local saida="$PASTA/diagnostico-$(date '+%Y%m%d-%H%M%S')"
	python3 -I "$ferr" "$arq" "${extra[@]}" --corrigir "$saida-corrigido.rbxlx" --bisseccao "$saida-bisseccao" --json "$saida.json" || true
	echo
	ok "Relatório: $saida.json"
	echo "Cópia corrigida (se houve correções): $saida-corrigido.rbxlx"
	echo "Bissecção: $saida-bisseccao (leia LEIA-ME.txt lá dentro)"
}

enviar_legado() {
	local arq="$1" tipo_versao="$2"
	carregar_config
	local tam ctype sha
	tam=$(validar_arquivo "$arq")
	ctype=$(tipo_conteudo "$arq")
	sha=$(sha256sum "$arq" | cut -d' ' -f1)
	info "Arquivo: $arq ($tam bytes, $ctype)"
	info "Destino: universo $UNIVERSE_ID, lugar $PLACE_ID, versionType=$tipo_versao"
	cabecalho_chave
	local resp code
	resp=$(mktemp)
	code=$(curl -sS -o "$resp" -w '%{http_code}' -X POST \
		-H @"$HDR" -H "Content-Type: $ctype" \
		--data-binary @"$arq" \
		"$API/universes/v1/${UNIVERSE_ID}/places/${PLACE_ID}/versions?versionType=${tipo_versao}") || true
	limpar
	if [[ "$code" == "200" ]]; then
		local versao
		versao=$(json_campo versionNumber <"$resp")
		ok "Aceito pelo Roblox: versão $versao ($tipo_versao)"
		registrar "enviar-$tipo_versao" "$(basename "$arq")" "$sha" "$versao" "ok"
		echo "$versao" >"$CONF_DIR/ultima_versao"
	else
		erro "HTTP $code"
		cat "$resp"
		echo
		registrar "enviar-$tipo_versao" "$(basename "$arq")" "$sha" "-" "http-$code"
		case "$code" in
		400) aviso "Conteúdo recusado. Rode: bash ideias.sh diagnosticar '$arq'" ;;
		401 | 403) aviso "Chave sem permissão 'universe-places: Write' para este universo/IP." ;;
		404 | 409) aviso "Universe ID / Place ID não conferem." ;;
		429) aviso "Muitos envios: espere 1 minuto." ;;
		esac
		rm -f "$resp"
		return 1
	fi
	rm -f "$resp"
}

cmd_enviar() {
	precisa curl python3 sha256sum
	garantir_pastas
	local arq="${1:-$PASTA/V3/IdeiasSemLimites_V3.rbxl}"
	enviar_legado "$arq" "Saved"
	echo "Próximo passo: bash ideias.sh testar   (testa esta versão na nuvem)"
}

cmd_enviar_assets() {
	precisa curl python3 sha256sum
	garantir_pastas
	carregar_config
	local arq="${1:-$PASTA/V3/IdeiasSemLimites_V3.rbxl}"
	local tam ctype sha
	tam=$(validar_arquivo "$arq")
	ctype=$(tipo_conteudo "$arq")
	sha=$(sha256sum "$arq" | cut -d' ' -f1)
	info "Assets API: salvando SEM publicar ($tam bytes)"
	cabecalho_chave
	local resp code
	resp=$(mktemp)
	code=$(curl -sS -o "$resp" -w '%{http_code}' -X PATCH -H @"$HDR" \
		--form "request={\"assetId\": ${PLACE_ID}, \"assetType\": \"Place\", \"published\": false}" \
		--form "fileContent=@${arq};type=${ctype}" \
		"$API/assets/v1/assets/${PLACE_ID}") || true
	if [[ "$code" != "200" ]]; then
		limpar
		erro "HTTP $code"
		cat "$resp"
		echo
		rm -f "$resp"
		return 1
	fi
	local op
	op=$(json_campo path <"$resp")
	info "Operação: $op — aguardando..."
	local i=0 done_
	while [[ $i -lt 40 ]]; do
		sleep 3
		curl -sS -o "$resp" -H @"$HDR" "$API/assets/v1/${op}" || true
		done_=$(json_campo done <"$resp")
		if [[ "$done_" == "True" || "$done_" == "true" ]]; then
			break
		fi
		i=$((i + 1))
	done
	limpar
	local rev errmsg
	rev=$(json_campo response.revisionId <"$resp")
	errmsg=$(json_campo error.message <"$resp")
	if [[ -n "$rev" ]]; then
		ok "Salvo pela Assets API: revisão $rev (não publicada)"
		registrar "enviar-assets" "$(basename "$arq")" "$sha" "$rev" "ok"
		echo "$rev" >"$CONF_DIR/ultima_versao"
	else
		erro "Falhou: ${errmsg:-sem resposta final}"
		registrar "enviar-assets" "$(basename "$arq")" "$sha" "-" "falhou"
	fi
	rm -f "$resp"
}

luau_tarefa() {
	# $1 = versão, $2 = arquivo .luau, $3 = nome do relatório
	local versao="$1" script="$2" nome="$3"
	carregar_config
	[[ -f "$script" ]] || morre "Script não encontrado: $script (rode 'baixar')"
	local corpo resp code caminho
	corpo=$(mktemp)
	resp=$(mktemp)
	python3 -c 'import json,sys; print(json.dumps({"script": open(sys.argv[1], encoding="utf-8").read(), "timeout": "300s"}))' "$script" >"$corpo"
	cabecalho_chave
	code=$(curl -sS -o "$resp" -w '%{http_code}' -X POST -H @"$HDR" -H "Content-Type: application/json" \
		--data-binary @"$corpo" \
		"$API/cloud/v2/universes/${UNIVERSE_ID}/places/${PLACE_ID}/versions/${versao}/luau-execution-session-tasks") || true
	if [[ "$code" != "200" ]]; then
		limpar
		erro "Não foi possível criar a tarefa (HTTP $code):"
		cat "$resp"
		echo
		[[ "$code" == "403" || "$code" == "401" ]] && aviso "A chave precisa de 'universe.place.luau-execution-session' Read+Write para este universo."
		rm -f "$corpo" "$resp"
		return 1
	fi
	caminho=$(json_campo path <"$resp")
	info "Tarefa criada: $caminho"
	local estado="" i=0
	while [[ $i -lt 80 ]]; do
		sleep 5
		curl -sS -o "$resp" -H @"$HDR" "$API/cloud/v2/${caminho}" || true
		estado=$(json_campo state <"$resp")
		printf '\r  estado: %-12s (%ds)' "$estado" $(((i + 1) * 5))
		[[ "$estado" == "COMPLETE" || "$estado" == "FAILED" || "$estado" == "CANCELLED" ]] && break
		i=$((i + 1))
	done
	echo
	local relatorio="$PASTA/${nome}-v${versao}-$(date '+%Y%m%d-%H%M%S').json"
	cp "$resp" "$relatorio"
	curl -sS -H @"$HDR" "$API/cloud/v2/${caminho}/logs" >"${relatorio%.json}-logs.json" || true
	limpar
	if [[ "$estado" == "COMPLETE" ]]; then
		python3 - "$relatorio" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
res = (d.get("output") or {}).get("results") or []
r = res[0] if res else {}
print(json.dumps(r, ensure_ascii=False, indent=2)[:6000])
PY
		ok "Relatório salvo: $relatorio"
	else
		erro "Tarefa terminou em $estado"
		json_campo error <"$resp" || true
	fi
	rm -f "$corpo" "$resp"
	[[ "$estado" == "COMPLETE" ]]
}

cmd_testar() {
	precisa curl python3
	garantir_pastas
	local versao="${1:-$(cat "$CONF_DIR/ultima_versao" 2>/dev/null || ultima_versao_salva)}"
	[[ -n "$versao" ]] || morre "Informe a versão: bash ideias.sh testar NUMERO"
	info "Testando a versão $versao na nuvem (Luau Execution, até 5 min)"
	if luau_tarefa "$versao" "$PASTA/V3/testes/run_cloud_tests.luau" "teste-nuvem"; then
		registrar "testar" "-" "-" "$versao" "concluido"
	else
		registrar "testar" "-" "-" "$versao" "falhou"
	fi
}

cmd_auditar() {
	precisa curl python3
	garantir_pastas
	local versao="${1:-4}"
	info "Auditando a versão $versao"
	luau_tarefa "$versao" "$PASTA/V3/testes/auditar_lugar.luau" "auditoria" || true
}

cmd_publicar() {
	precisa curl python3 sha256sum
	garantir_pastas
	local arq="${1:-}"
	[[ -n "$arq" ]] || morre "Uso: bash ideias.sh publicar ARQUIVO (o mesmo que você salvou e testou)"
	local sha
	sha=$(sha256sum "$arq" | cut -d' ' -f1)
	if ! grep -q "$sha" "$LEDGER"; then
		aviso "Este arquivo nunca foi enviado como Saved por este celular."
	fi
	if ! awk -F'\t' -v s="$sha" '$4 == s && $2 ~ /enviar/ && $6 == "ok" {f=1} END {exit !f}' "$LEDGER"; then
		aviso "Recomendado: enviar como Saved e testar antes de publicar."
	fi
	carregar_config
	echo
	cor "1;31" "ATENÇÃO: isto PUBLICA para todos os jogadores do lugar $PLACE_ID."
	echo "Para voltar atrás depois: Creator Dashboard > Histórico de versões > Restaurar."
	read -r -p "Digite PUBLICAR para confirmar: " conf
	[[ "$conf" == "PUBLICAR" ]] || morre "Cancelado."
	enviar_legado "$arq" "Published"
}

cmd_sons() {
	# Envia o áudio com os efeitos sonoros (ElevenLabs) como UM asset de áudio,
	# grava o ID numa cópia do .rbxlx e envia essa cópia como SALVA (Saved).
	precisa curl python3 sha256sum
	garantir_pastas
	carregar_config
	local novo=0
	if [[ "${1:-}" == "--novo" ]]; then
		novo=1
		shift
	fi
	local audio="${1:-$PASTA/V3/IdeiasSons.ogg}"
	local lugar="$PASTA/V3/IdeiasSemLimites_V3.rbxlx"
	[[ -s "$audio" ]] || morre "Áudio não encontrado: $audio (rode 'bash ideias.sh baixar')"
	[[ -s "$lugar" ]] || morre "Lugar não encontrado: $lugar (rode 'bash ideias.sh baixar')"
	local sha asset=""
	sha=$(sha256sum "$audio" | cut -d' ' -f1)
	# mesmo arquivo de áudio já enviado antes: reaproveita o ID (não gasta a cota de uploads)
	if [[ $novo -eq 0 && -s "$CONF_DIR/audio_id" && "$(cat "$CONF_DIR/audio_sha" 2>/dev/null)" == "$sha" ]]; then
		asset=$(tr -dc '0-9' <"$CONF_DIR/audio_id")
		ok "Áudio igual ao já enviado: reaproveitado o asset $asset (use 'sons --novo' para forçar novo envio)"
	fi
	if [[ -z "$asset" ]]; then
		enviar_audio "$audio" "$sha" || return 1
		asset=$(tr -dc '0-9' <"$CONF_DIR/audio_id")
	fi
	local saida="$PASTA/V3/IdeiasSemLimites_V3_sons.rbxlx"
	python3 - "$lugar" "$saida" "$asset" <<'PYEOF' || morre "Não consegui gravar o ID no lugar."
import sys
src, dst, asset = sys.argv[1], sys.argv[2], sys.argv[3]
data = open(src, encoding="utf-8").read()
marker = "Id = 0, --@@SPRITE_ID@@"
if marker not in data:
    sys.exit("marcador não encontrado")
open(dst, "w", encoding="utf-8").write(data.replace(marker, "Id = %d, --@@SPRITE_ID@@" % int(asset), 1))
PYEOF
	ok "Lugar com sons: $saida"
	cmd_enviar "$saida"
}

# envia o .ogg como asset de Áudio e guarda ID + sha256 em ~/.ideias
enviar_audio() {
	local audio="$1" sha="$2"
	local uid="${USER_ID:-}"
	if [[ -z "$uid" ]]; then
		read -r -p "Seu User ID do Roblox (número do seu perfil): " uid
		[[ "$uid" =~ ^[0-9]+$ ]] || morre "User ID deve ser um número."
		printf 'USER_ID="%s"\n' "$uid" >>"$CONF"
	fi
	info "Enviando áudio ($(wc -c <"$audio") bytes) — permissão 'asset' Read+Write"
	cabecalho_chave
	local resp code
	resp=$(mktemp)
	code=$(curl -sS -o "$resp" -w '%{http_code}' -X POST -H @"$HDR" \
		--form "request={\"assetType\": \"Audio\", \"displayName\": \"Ideias Sem Limites Sons\", \"description\": \"Efeitos sonoros do jogo\", \"creationContext\": {\"creator\": {\"userId\": \"${uid}\"}}}" \
		--form "fileContent=@${audio};type=audio/ogg" \
		"$API/assets/v1/assets") || true
	if [[ "$code" != "200" ]]; then
		limpar
		erro "HTTP $code"
		cat "$resp"
		echo
		rm -f "$resp"
		return 1
	fi
	local op asset i=0 done_
	op=$(json_campo path <"$resp")
	info "Operação: $op — aguardando o Roblox processar o áudio..."
	while [[ $i -lt 40 ]]; do
		sleep 3
		curl -sS -o "$resp" -H @"$HDR" "$API/assets/v1/${op}" || true
		done_=$(json_campo done <"$resp")
		if [[ "$done_" == "True" || "$done_" == "true" ]]; then
			break
		fi
		i=$((i + 1))
	done
	limpar
	asset=$(json_campo response.assetId <"$resp")
	if [[ ! "$asset" =~ ^[0-9]+$ ]]; then
		erro "Sem ID do áudio: $(json_campo error.message <"$resp")"
		rm -f "$resp"
		return 1
	fi
	rm -f "$resp"
	ok "Áudio criado: asset $asset"
	echo "$asset" >"$CONF_DIR/audio_id"
	echo "$sha" >"$CONF_DIR/audio_sha"
	aviso "O Roblox analisa o áudio antes de liberar (minutos a horas). Confira com: bash ideias.sh verificar-sons"
}

cmd_verificar_sons() {
	# Pergunta ao Roblox se o áudio já passou na moderação (só leitura).
	precisa curl python3
	garantir_pastas
	carregar_config
	local id="${1:-$(tr -dc '0-9' <"$CONF_DIR/audio_id" 2>/dev/null)}"
	[[ "$id" =~ ^[0-9]+$ ]] || morre "Nenhum áudio enviado ainda. Rode: bash ideias.sh sons"
	cabecalho_chave
	local resp code estado
	resp=$(mktemp)
	code=$(curl -sS -o "$resp" -w '%{http_code}' -H @"$HDR" "$API/assets/v1/assets/${id}") || true
	limpar
	if [[ "$code" != "200" ]]; then
		erro "HTTP $code ao consultar o áudio $id"
		[[ "$code" == "401" || "$code" == "403" ]] && aviso "A chave precisa da permissão 'asset' com Read."
		rm -f "$resp"
		return 1
	fi
	estado=$(json_campo moderationResult.moderationState <"$resp")
	rm -f "$resp"
	case "$estado" in
	Approved | MODERATION_STATE_APPROVED) ok "Áudio $id APROVADO: os sons do ElevenLabs tocam no jogo (versão com 'sons')." ;;
	Reviewing | MODERATION_STATE_REVIEWING) aviso "Áudio $id em ANÁLISE no Roblox. Enquanto isso o jogo toca os sons embutidos do Roblox. Tente de novo mais tarde." ;;
	Rejected | MODERATION_STATE_REJECTED) erro "Áudio $id REJEITADO pelo Roblox. O jogo continua com os sons embutidos." ;;
	*) aviso "Estado do áudio $id: ${estado:-desconhecido}" ;;
	esac
}

enviar_decal() {
	# $1 arquivo PNG, $2 nome; imprime o assetId
	local img="$1" nome="$2" uid="$3"
	local resp code
	resp=$(mktemp)
	code=$(curl -sS -o "$resp" -w '%{http_code}' -X POST -H @"$HDR" \
		--form "request={\"assetType\": \"Decal\", \"displayName\": \"${nome}\", \"description\": \"Interface do jogo\", \"creationContext\": {\"creator\": {\"userId\": \"${uid}\"}}}" \
		--form "fileContent=@${img};type=image/png" \
		"$API/assets/v1/assets") || true
	if [[ "$code" != "200" ]]; then
		erro "HTTP $code ao enviar $nome"
		cat "$resp" >&2
		rm -f "$resp"
		return 1
	fi
	local op i=0 done_
	op=$(json_campo path <"$resp")
	while [[ $i -lt 40 ]]; do
		sleep 3
		curl -sS -o "$resp" -H @"$HDR" "$API/assets/v1/${op}" || true
		done_=$(json_campo done <"$resp")
		if [[ "$done_" == "True" || "$done_" == "true" ]]; then
			break
		fi
		i=$((i + 1))
	done
	local asset
	asset=$(json_campo response.assetId <"$resp")
	rm -f "$resp"
	[[ "$asset" =~ ^[0-9]+$ ]] || return 1
	echo "$asset"
}

cmd_imagens() {
	# Envia o logo e a folha de ícones (feitos no Canva) como Decal e grava os IDs no lugar.
	precisa curl python3
	garantir_pastas
	carregar_config
	local logo="$PASTA/V3/IdeiasLogo.png"
	local icones="$PASTA/V3/IdeiasIcones.png"
	local lugar="$PASTA/V3/IdeiasSemLimites_V3_sons.rbxlx"
	[[ -s "$lugar" ]] || lugar="$PASTA/V3/IdeiasSemLimites_V3.rbxlx"
	[[ -s "$logo" ]] || morre "Logo não encontrado: $logo (rode 'bash ideias.sh baixar')"
	local uid="${USER_ID:-}"
	if [[ -z "$uid" ]]; then
		read -r -p "Seu User ID do Roblox (número do seu perfil): " uid
		[[ "$uid" =~ ^[0-9]+$ ]] || morre "User ID deve ser um número."
		printf 'USER_ID="%s"\n' "$uid" >>"$CONF"
	fi
	info "Enviando imagens da interface — permissão 'asset' Read+Write"
	cabecalho_chave
	local logo_id icons_id=0
	logo_id=$(enviar_decal "$logo" "Ideias Sem Limites Logo" "$uid") || { limpar; morre "Falha ao enviar o logo."; }
	ok "Logo criado: asset $logo_id"
	if [[ -s "$icones" ]]; then
		icons_id=$(enviar_decal "$icones" "Ideias Sem Limites Icones" "$uid") || icons_id=0
		if [[ "$icons_id" != "0" ]]; then
			ok "Folha de ícones criada: asset $icons_id"
		else
			aviso "Folha de ícones não enviada; os botões ficam com emojis."
		fi
	fi
	limpar
	local saida="$PASTA/V3/IdeiasSemLimites_V3_final.rbxlx"
	python3 - "$lugar" "$saida" "$logo_id" "$icons_id" <<'PYEOF' || morre "Não consegui gravar os IDs no lugar."
import sys
src, dst, logo, icons = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
data = open(src, encoding="utf-8").read()
m1 = "Logo = 0, --@@LOGO_ID@@"
if m1 not in data:
    sys.exit("marcador do logo não encontrado")
data = data.replace(m1, "Logo = %d, --@@LOGO_ID@@" % logo, 1)
m2 = "Icons = 0, --@@ICONS_ID@@"
if icons and m2 in data:
    data = data.replace(m2, "Icons = %d, --@@ICONS_ID@@" % icons, 1)
open(dst, "w", encoding="utf-8").write(data)
PYEOF
	ok "Lugar com imagens: $saida"
	cmd_enviar "$saida"
}

cmd_status() {
	garantir_pastas
	carregar_config
	echo "Universo: $UNIVERSE_ID | Lugar: $PLACE_ID | chave: $([[ -s "$CHAVE" ]] && echo configurada || echo AUSENTE)"
	echo "Última versão enviada: $(cat "$CONF_DIR/ultima_versao" 2>/dev/null || echo '-')"
	echo
	column -t -s $'\t' "$LEDGER" 2>/dev/null || cat "$LEDGER"
}

ajuda() {
	sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
	echo "Ordem recomendada:"
	echo "  bash ideias.sh configurar && bash ideias.sh baixar && bash ideias.sh backup"
	echo "  bash ideias.sh diagnosticar          # entende o erro da V2"
	echo "  bash ideias.sh enviar                # salva a V3 (não publica)"
	echo "  bash ideias.sh testar                # testes na nuvem"
	echo "  bash ideias.sh sons                  # envia os sons (ElevenLabs) e salva a V3 com eles"
	echo "  bash ideias.sh verificar-sons        # o Roblox já aprovou o áudio? (só consulta)"
	echo "  bash ideias.sh imagens               # envia o logo (Canva) e salva a V3 com ele"
	echo "  bash ideias.sh publicar ARQUIVO      # só quando você decidir"
}

case "${1:-}" in
configurar) cmd_configurar ;;
baixar) cmd_baixar ;;
sons) cmd_sons "${2:-}" "${3:-}" ;;
verificar-sons) cmd_verificar_sons "${2:-}" ;;
imagens) cmd_imagens "${2:-}" ;;
backup) cmd_backup ;;
diagnosticar) cmd_diagnosticar "${2:-}" ;;
enviar) cmd_enviar "${2:-}" ;;
enviar-assets) cmd_enviar_assets "${2:-}" ;;
testar) cmd_testar "${2:-}" ;;
auditar) cmd_auditar "${2:-}" ;;
publicar) cmd_publicar "${2:-}" ;;
status) cmd_status ;;
*) ajuda ;;
esac
