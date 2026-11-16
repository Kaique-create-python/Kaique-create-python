-- PROJETO BASTIÃO :: as 3 línguas (PT · EN · RU) estão completas e cabem na tela
-- Confere: mesmas chaves nas 3 línguas, mesmos %s, toda fala/som/objetivo/aviso/prompt usado
-- pelo jogo tem texto, russo em cirílico de verdade, telas dos terminais cabem no visor e o
-- seletor escolhe a língua certa pela conta Roblox.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local raiz = if fs.isDir("bastiao/src") then "bastiao/src/" else "src/"
local G = {
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	NumberRange = roblox.NumberRange,
	Font = roblox.Font,
	game = { GetService = function()
		return {}
	end },
}
local function carregar(caminho: string)
	return luau.load(fs.readFile(raiz .. caminho), { debugName = caminho, environment = G })()
end
local Textos = carregar("ReplicatedStorage/BastiaoCompartilhado/Textos.luau")
local Cap = carregar("ServerScriptService/BastiaoServidor/Capitulo01.luau")
local Telas = carregar("StarterPlayer/StarterPlayerScripts/BastiaoCliente/Telas.luau")
local fonteCenario = fs.readFile(raiz .. "ServerScriptService/BastiaoServidor/Cenario.luau")

local falhas = 0
local function confere(cond: any, msg: string)
	if not cond then
		falhas += 1
		print("[Idiomas] FALHA " .. msg)
	end
end
local function pass(nome: string)
	if falhas == 0 then
		print("[Idiomas] PASS " .. nome)
	end
end

local CATEGORIAS = { "falantes", "falas", "sons", "objetivos", "prompts", "avisos", "terminais", "fim", "ui" }
local function formatos(s: string): string
	local r = {}
	for f in string.gmatch(s, "%%[%d%.]*[sdif]") do
		table.insert(r, f)
	end
	return table.concat(r, ",")
end

-- 1) mesmas chaves e mesmos marcadores nas 3 línguas
confere(#Textos.IDIOMAS == 3, "3 línguas")
local base = Textos.L.pt
for _, idioma in Textos.IDIOMAS do
	local L = Textos.L[idioma]
	confere(L ~= nil, "língua sem tabela: " .. idioma)
	for _, cat in CATEGORIAS do
		for k, v in base[cat] do
			local t = L[cat] and L[cat][k]
			confere(type(t) == "string" and #t > 0, string.format("%s.%s.%s faltando", idioma, cat, k))
			if type(t) == "string" then
				confere(formatos(t) == formatos(v), string.format("%s.%s.%s com marcadores diferentes (%s vs %s)", idioma, cat, k, formatos(t), formatos(v)))
				confere(utf8.len(t) ~= nil, string.format("%s.%s.%s não é UTF-8 válido", idioma, cat, k))
			end
		end
		for k in L[cat] or {} do
			confere(base[cat][k] ~= nil, string.format("%s.%s.%s sobrando (não existe em pt)", idioma, cat, k))
		end
	end
	confere(Textos.NOME_IDIOMA[idioma] ~= nil, "nome da língua no menu: " .. idioma)
end
pass("mesmas_chaves_nas_3_linguas")

-- 2) russo é russo (cirílico) e o inglês não ficou em português
local function temCirilico(s: string): boolean
	for _, c in utf8.codes(s) do
		if c >= 0x0400 and c <= 0x04FF then
			return true
		end
	end
	return false
end
-- falas só com nomes ou números podem ser iguais nas 3 línguas (a voz lê a forma falada)
local SO_NOMES = { pavel_731 = true, pavel_lista1 = true }
for k, v in Textos.L.ru.falas do
	confere(temCirilico(v) or SO_NOMES[k], "fala russa sem cirílico: " .. k)
end
for _, idioma in Textos.IDIOMAS do
	for k, v in Textos.FALADO[idioma] or {} do
		confere(Textos.L[idioma].falas[k] ~= nil, "forma falada de uma fala que não existe: " .. idioma .. "." .. k)
		confere(idioma ~= "ru" or temCirilico(v), "forma falada russa sem cirílico: " .. k)
	end
end
confere(Textos.FALADO.ru.pavel_731 and Textos.FALADO.en.pavel_731 ~= Textos.FALADO.pt.pavel_731, "731 dito por extenso em cada língua")
for k, v in Textos.L.ru.objetivos do
	confere(temCirilico(v), "objetivo russo sem cirílico: " .. k)
end
for k, v in Textos.L.en.falas do
	confere(not string.find(v, "ção", 1, true) and not string.find(v, "ã", 1, true), "fala inglesa com português: " .. k)
	confere(v ~= Textos.L.pt.falas[k] or SO_NOMES[k], "fala inglesa igual à portuguesa: " .. k)
end
for k, v in Textos.MUNDO do
	confere(temCirilico(v), "placa do mundo deveria estar em russo: " .. k)
end
pass("russo_em_cirilico_e_ingles_traduzido")

-- 3) tudo o que o capítulo usa tem texto, falante, canal e direção de voz
for id, s in Cap.sequences do
	for _, cue in s.cues do
		if cue.fala then
			local quem = Textos.FALANTE[cue.fala]
			confere(quem ~= nil, id .. ": fala sem falante " .. cue.fala)
			confere(quem == nil or Textos.CANAL[quem] ~= nil, id .. ": falante sem canal " .. tostring(quem))
			confere(Textos.DIRECAO[cue.fala] ~= nil, id .. ": fala sem direção de voz " .. cue.fala)
			for _, idioma in Textos.IDIOMAS do
				confere(Textos.L[idioma].falas[cue.fala] ~= nil, id .. ": fala sem texto em " .. idioma .. ": " .. cue.fala)
				confere(quem == nil or Textos.L[idioma].falantes[quem] ~= nil, "falante sem nome em " .. idioma)
			end
		elseif cue.som then
			for _, idioma in Textos.IDIOMAS do
				confere(Textos.L[idioma].sons[cue.som] ~= nil, id .. ": som sem legenda em " .. idioma .. ": " .. cue.som)
			end
		end
	end
end
for chave in Textos.FALANTE do
	confere(Textos.L.pt.falas[chave] ~= nil, "falante de uma fala que não existe: " .. chave)
end
for nome, no in Cap.nodes do
	if no.objective then
		for _, idioma in Textos.IDIOMAS do
			confere(Textos.L[idioma].objetivos[no.objective] ~= nil, "objetivo sem texto em " .. idioma .. ": " .. no.objective .. " (" .. nome .. ")")
		end
	end
end
-- prompts e avisos citados pelo cenário
local nPrompts, nAvisos = 0, 0
for nomePrompt in string.gmatch(fonteCenario, 'prompt%([%w_%.]+,%s*"([%w]+)"') do
	nPrompts += 1
	confere(Textos.L.pt.prompts[nomePrompt] ~= nil, "prompt sem texto: " .. nomePrompt)
end
for chave in string.gmatch(fonteCenario, 'return false, "([%w_]+)"') do
	nAvisos += 1
	confere(Textos.L.pt.avisos[chave] ~= nil, "aviso sem texto: " .. chave)
end
confere(nPrompts >= 5 and nAvisos >= 4, string.format("o teste achou %d prompts e %d avisos no cenário (esperava 5 e 4)", nPrompts, nAvisos))
confere(Textos.L.pt.avisos.modulo_voltou ~= nil, "aviso do servidor: modulo_voltou")
pass("tudo_que_o_jogo_usa_tem_texto")

-- 4) telas dos terminais cabem no visor em todas as línguas (letras por linha e linhas)
local VISOR = {
	-- largura e altura do SurfaceGui em pixels (studs x pixels por stud) e tamanho do texto
	enfermaria = { w = 1.8 * 170, h = 1.2 * 170, texto = 16, estados = { "sem_energia", "ligado", "autorizado" } },
	oficina = { w = 1.6 * 220, h = 1.2 * 220, texto = 13, estados = { "apagado", "aguardando", "lista" } },
}
local seis = table.concat({ "ALEKSANDROVA_XX", "BIA", "CAIO", "DMITRI", "ЕКАТЕРИНА", "FERNANDO_LONG" }, "\n")
for id, v in VISOR do
	local largura = v.w - math.floor(v.texto * 0.8) - math.floor(v.texto * 0.6)
	local maxLetras = math.floor(largura / (v.texto * 0.6))
	local maxLinhas = math.floor((v.h - math.floor(v.texto * 0.7)) / (v.texto * 1.05))
	for _, idioma in Textos.IDIOMAS do
		for _, estado in v.estados do
			local texto = Telas.conteudo(Textos.L[idioma], id, estado, seis)
			confere(#texto > 0, string.format("%s/%s/%s vazio", id, estado, idioma))
			local linhas = 0
			for linha in string.gmatch(texto .. "\n", "(.-)\n") do
				linhas += 1
				local n = utf8.len(linha) or #linha
				confere(n <= maxLetras, string.format("%s/%s/%s: linha com %d letras (máx %d): %s", id, estado, idioma, n, maxLetras, linha))
			end
			confere(linhas <= maxLinhas, string.format("%s/%s/%s: %d linhas (máx %d)", id, estado, idioma, linhas, maxLinhas))
		end
	end
end
-- a lista alinha as colunas contando letras (russo tem 2 bytes por letra)
confere(Telas.coluna("АБВ", 6) == "АБВ   ", "coluna conta letras, não bytes")
pass("telas_cabem_no_visor")

-- 5) língua inicial pela conta Roblox e normalização
confere(Textos.daLocalidade("pt-br") == "pt" and Textos.daLocalidade("pt-pt") == "pt", "português pela conta")
confere(Textos.daLocalidade("ru-ru") == "ru", "russo pela conta")
confere(Textos.daLocalidade("en-us") == "en" and Textos.daLocalidade("es-es") == "en" and Textos.daLocalidade(nil) == "en", "outras línguas caem no inglês")
confere(Textos.normalizar("ru") == "ru" and Textos.normalizar("xx") == Textos.PADRAO and Textos.normalizar(42) == Textos.PADRAO, "normalizar")
confere(Textos.de("en") == Textos.L.en and Textos.de("zz") == Textos.L[Textos.PADRAO], "de()")
pass("lingua_inicial")

if falhas > 0 then
	print(string.format("[Idiomas] %d falha(s)", falhas))
	process.exit(1)
end
print("[Idiomas] TUDO OK")
