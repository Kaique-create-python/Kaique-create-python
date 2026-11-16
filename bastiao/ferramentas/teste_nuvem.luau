-- PROJETO BASTIÃO :: teste na nuvem da Etapa 2 (Luau Execution numa versão SALVA, nunca publicada)
-- O instalador acrescenta antes deste texto a linha `local cfg = ...` (destino, etapa e o hash
-- de cada script do pacote). Se qualquer verificação falhar, o instalador NÃO publica.
--   1) destino certo e fontes idênticas às do pacote;
--   2) jogo base intacto: mapa Sector7World, HUD da bodycam e scripts Sector7;
--   3) todos os módulos do Bastião carregam no motor;
--   4) se os scripts do place rodam nesta sessão, o servidor da etapa subiu sem erro;
--   5) a abertura inteira roda com o cenário real (pasta de teste) e jogadores falsos;
--   6) a interface do cliente é montada sem erro de propriedade, nas 3 línguas (PT · EN · RU),
--      com as telas dos terminais e o som (grupos, eco, vozes, efeitos, loops) montados de verdade;
--   7) o Pavel anda de verdade pela rota do arsenal (quando a sessão não tem o servidor ao vivo);
--   8) nenhum erro "Bastiao" no log.
-- Nada aqui salva ou publica: a sessão é descartada no fim.

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local out = { package = cfg.package, passed = true, erros = {}, avisos = {}, info = {} }
local function falha(msg: string)
	out.passed = false
	table.insert(out.erros, msg)
end
local function aviso(msg: string)
	table.insert(out.avisos, msg)
end
local function checar(nome: string, fn: () -> ()): boolean
	local ok, err = pcall(fn)
	if not ok then
		falha(nome .. ": " .. tostring(err))
	end
	return ok
end
local function relatorio(): string
	return HttpService:JSONEncode(out)
end

-- 1) destino e fontes
if cfg.package ~= "BASTIAO-ETAPA-2" or cfg.stage ~= 2 or cfg.universe ~= 10776462844 or cfg.place ~= 89520940302906 then
	falha("Destino/pacote incorreto.")
	return relatorio()
end
local function djb(source: string): string
	local v = 5381
	for i = 1, #source do
		v = (v * 33 + string.byte(source, i)) % 4294967296
	end
	return string.format("%08x", v)
end
local function localizar(raiz: Instance, caminho: { string }): Instance?
	local at = raiz
	for _, nome in caminho do
		local achado = nil
		for _, filho in at:GetChildren() do
			if filho.Name == nome then
				if achado then
					return nil
				end
				achado = filho
			end
		end
		if not achado then
			return nil
		end
		at = achado
	end
	return at
end
out.info.fontes = 0
for _, row in cfg.hashes or {} do
	local rotulo = table.concat(row.path, "/")
	local obj = localizar(game, row.path)
	if not obj or obj.ClassName ~= row.class then
		falha("Fonte ausente, ambígua ou de outra classe: " .. rotulo)
	else
		local ok, fonte = pcall(function()
			return (obj :: any).Source
		end)
		if not ok or type(fonte) ~= "string" then
			falha("O teste não conseguiu ler Source: " .. rotulo)
		elseif #fonte ~= row.bytes or djb(fonte) ~= row.hash then
			falha("Fonte divergiu do pacote: " .. rotulo)
		else
			out.info.fontes += 1
		end
	end
end
if not out.passed then
	return relatorio()
end

-- 2) jogo base intacto
local mapa = workspace:FindFirstChild("Sector7World")
if not mapa then
	falha("Sector7World ausente: o mapa precisa existir e não pode ser recriado")
else
	out.info.mapa_descendentes = #mapa:GetDescendants()
	if out.info.mapa_descendentes < 8000 then
		falha("Sector7World incompleto (" .. out.info.mapa_descendentes .. " descendentes)")
	end
end
for _, caminho in {
	{ "StarterPlayer", "StarterPlayerScripts", "Sector7Client" },
	{ "StarterPlayer", "StarterPlayerScripts", "Sector7Client", "BodycamHUD" },
	{ "StarterPlayer", "StarterPlayerScripts", "Sector7Client", "BodycamCamera" },
	{ "StarterPlayer", "StarterCharacter", "Animate" },
	{ "ServerScriptService", "Sector7", "Server" },
	{ "ServerScriptService", "Sector7", "WorldBuilder" },
	{ "ReplicatedStorage", "Sector7", "Config" },
} do
	if not localizar(game, caminho) then
		falha("Parte do jogo base ausente: " .. table.concat(caminho, "/"))
	end
end

-- 3) módulos
local SRV = ServerScriptService:FindFirstChild("BastiaoServidor")
local COMP = ReplicatedStorage:FindFirstChild("BastiaoCompartilhado")
local SPS = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local CLI = SPS and SPS:FindFirstChild("BastiaoCliente")
if not SRV or not COMP or not CLI then
	falha("Scripts do Bastião não estão nos lugares esperados")
	return relatorio()
end
local modulos = 0
for _, raiz in { SRV, COMP, CLI } do
	local lista = raiz:GetDescendants()
	if raiz:IsA("ModuleScript") then
		table.insert(lista, raiz)
	end
	for _, m in lista do
		if m:IsA("ModuleScript") then
			modulos += 1
			checar("require " .. m:GetFullName(), function()
				require(m)
			end)
		end
	end
end
out.info.modulos = modulos
if not out.passed then
	return relatorio()
end
local Compartilhado = require(COMP)
local Textos = require(COMP.Textos)
local Runner = require(SRV.StoryRunner)
local Validator = require(SRV.StoryValidator)
local Cap = require(SRV.Capitulo01)
local Mundo = require(SRV.Mundo)
local Missao = require(SRV.Missao)
local Sequencias = require(SRV.Sequencias)
local Interacoes = require(SRV.Interacoes)
local Zonas = require(SRV.Zonas)
local Checkpoint = require(SRV.Checkpoint)
local Cenario = require(SRV.Cenario)
local Pavel = require(SRV.Pavel)
local Interface = require(CLI.Interface)
local Prompts = require(CLI.Prompts)
local Telas = require(CLI.Telas)
local Som = require(CLI.Som)
local Audio = require(COMP.Audio)

-- 3b) tabela de áudio: IDs inteiros, trechos válidos, toda voz com duração
checar("tabela de áudio", function()
	for _, nome in { "voz_pt", "voz_en", "voz_ru", "efeitos" } do
		local id = Audio.ids[nome]
		assert(type(id) == "number" and id >= 0 and id % 1 == 0, "ID inválido: " .. nome)
	end
	local vozes = 0
	for idioma, falas in Audio.vozes do
		assert(Textos.L[idioma], "língua desconhecida no áudio: " .. tostring(idioma))
		for chave, seg in falas do
			assert(Textos.FALANTE[chave], "voz de fala inexistente: " .. chave)
			assert(seg[2] > 0 and (Audio.duracoes[chave] or 0) >= seg[2] - 0.01, "duração da voz " .. chave)
			vozes += 1
		end
	end
	out.info.vozes = vozes
	local efeitos = 0
	for _ in Audio.sfx do
		efeitos += 1
	end
	out.info.efeitos = efeitos
	out.info.audio_ids = Audio.ids
end)

-- 4) servidor da etapa ao vivo nesta sessão?
local t0 = os.clock()
while os.clock() - t0 < 12 do
	if COMP:GetAttribute("BastiaoEtapa") == Compartilhado.ETAPA and workspace:FindFirstChild(Compartilhado.PASTA_MUNDO) then
		break
	end
	task.wait(0.25)
end
local aoVivo = COMP:GetAttribute("BastiaoEtapa") == Compartilhado.ETAPA and workspace:FindFirstChild(Compartilhado.PASTA_MUNDO) ~= nil
out.info.servidor_ao_vivo = aoVivo
if aoVivo then
	local erro = COMP:GetAttribute("BastiaoErro")
	if erro then
		falha("Servidor da etapa subiu com erro: " .. tostring(erro))
	end
	local pasta = workspace:FindFirstChild(Compartilhado.PASTA_MUNDO)
	for _, nome in { "CantoPavel", "Radio", "RelogioBase", "CarregadorModulos", "ModuloBateria", "TerminalEnfermaria", "PortaContencao", "PortaOficina", "TravaOficina", "TerminalOficina", "Giroflexes", "Pavel" } do
		if not pasta:FindFirstChild(nome) then
			falha("Servidor ao vivo sem " .. nome)
		end
	end
	local remotos = ReplicatedStorage:FindFirstChild(Compartilhado.PASTA_REMOTOS)
	if remotos == nil then
		falha("Remotos do Bastião não foram criados")
	elseif not remotos:FindFirstChild(Compartilhado.REMOTO_IDIOMA) or not remotos:FindFirstChild(Compartilhado.REMOTO_APRESENTACAO) then
		falha("Remotos de idioma/apresentação ausentes")
	end
	if COMP:GetAttribute(Compartilhado.ATR_ACESSO) ~= "aberto" then
		falha("Acesso externo deveria começar aberto")
	end
	if COMP:GetAttribute(Compartilhado.ATR_OBJETIVO) ~= "" then
		falha("Objetivo deveria começar recolhido")
	end
else
	aviso("Scripts do place não rodaram nesta sessão; o teste montou a etapa sozinho.")
end

-- 5) abertura inteira com o cenário real e jogadores falsos
local pasta = Instance.new("Folder")
pasta.Name = "BastiaoTesteNuvem"
pasta.Parent = workspace
local agora = 0
local fila = {}
local function agendar(t: number, fn: () -> ())
	local h = { em = agora + t, fn = fn, vivo = true }
	table.insert(fila, h)
	return h
end
local function avancar(dt: number)
	local alvo = agora + dt
	while true do
		local proximo, idx = nil, nil
		for i, h in fila do
			if h.vivo and h.em <= alvo and (proximo == nil or h.em < proximo.em) then
				proximo, idx = h, i
			end
		end
		if not proximo then
			break
		end
		table.remove(fila, idx)
		agora = math.max(agora, proximo.em)
		proximo.fn()
	end
	agora = alvo
end
local function novoJogador(id: number, nome: string)
	local c = Instance.new("Model")
	c.Name = "Falso" .. nome
	local raiz = Instance.new("Part")
	raiz.Name = "HumanoidRootPart"
	raiz.Anchored = true
	raiz.CanCollide = false
	raiz.Transparency = 1
	raiz.CFrame = CFrame.new(0, 3, 12)
	raiz.Parent = c
	local braco = Instance.new("Part")
	braco.Name = "Right Arm"
	braco.Anchored = true
	braco.CanCollide = false
	braco.Transparency = 1
	braco.CFrame = CFrame.new(1.5, 3, 12)
	braco.Parent = c
	c.Parent = pasta
	return { UserId = id, Name = nome, DisplayName = nome, Parent = workspace, Character = c, vivo = true }
end
local ana, bia = novoJogador(901, "Ana"), novoJogador(902, "Bia")
local jogadores = { ana, bia }
local function mover(j: any, p: Vector3)
	j.Character.HumanoidRootPart.CFrame = CFrame.new(p)
	j.Character["Right Arm"].CFrame = CFrame.new(p + Vector3.new(1.5, 0, 0))
end
local function localizarJ(j: any): (Vector3?, boolean)
	return j.Character.HumanoidRootPart.Position, j.vivo
end

local pavelReal = nil
local pavelProxy
if aoVivo then
	-- o servidor ao vivo já tem um Pavel; aqui basta um substituto que chega na hora
	pavelProxy = {
		ir = function() end,
		chegou = function()
			return true
		end,
	}
else
	checar("criar o Pavel no motor", function()
		pavelReal = Pavel.criar(pasta, function(m)
			falha(m)
		end)
		assert(pavelReal.rig and pavelReal.rig.Parent == pasta, "rig do Pavel não foi criado")
	end)
	pavelProxy = {
		ir = function(_, estado)
			if pavelReal then
				pavelReal:ir(estado, true)
			end
		end,
		chegou = function()
			return pavelReal == nil or pavelReal:chegou()
		end,
	}
end

local logMundo = {}
local ruidos = {}
local fluxoOk = checar("fluxo da abertura", function()
	local mundo = Mundo.novo(function(m)
		table.insert(logMundo, m)
	end)
	local cena = Cenario.construir({
		pasta = pasta,
		textos = Textos,
		mundo = mundo,
		servicos = {
			tween = function(inst, tempo, alvo)
				TweenService:Create(inst, TweenInfo.new(tempo), alvo):Play()
			end,
			atrasar = function(s, fn)
				task.delay(s, fn)
			end,
			marcar = function(inst, tag)
				CollectionService:AddTag(inst, tag)
			end,
			agora = os.clock,
			ruido = function(chave)
				ruidos[chave] = true
			end,
		},
		jogadores = function()
			return jogadores
		end,
		criarPavel = function()
			return pavelProxy
		end,
	})
	local rel = Validator.Validate(Cap, mundo:registro())
	assert(rel.ok, "capítulo inválido: " .. table.concat(rel.erros, "; "))
	local objetivo = ""
	local fimEm = 0
	local checkpoint = Checkpoint.novo(cena.spawns)
	local interacoes
	local missao = Missao.novo({
		def = Cap,
		runner = Runner,
		mundo = mundo,
		objetivo = function(chave)
			objetivo = chave or ""
		end,
		checkpoint = function(id, estado, retrato)
			checkpoint:salvar(id, estado, retrato)
		end,
		aoAvancar = function()
			if interacoes then
				interacoes:atualizar()
			end
		end,
		aoFinal = function()
			fimEm = agora
		end,
		log = function() end,
	})
	local sequencias = Sequencias.novo({
		def = Cap,
		textos = Textos,
		mundo = mundo,
		apresentar = function() end,
		aoTerminar = function(id, n)
			missao:reportar({ id = "seq:" .. id .. ":" .. n, kind = "sequencia", name = id .. "_fim" })
		end,
		agendar = agendar,
		cancelar = function(h)
			h.vivo = false
		end,
		duracaoLeitura = Compartilhado.duracaoLeitura,
		duracoes = Audio.duracoes,
	})
	missao:ligarSequencias(sequencias)
	interacoes = Interacoes.novo({
		missao = missao,
		mundo = mundo,
		localizar = localizarJ,
		agora = function()
			return agora
		end,
	})
	local prompts = {}
	local posicoes = {}
	for _, def in cena.interacoes do
		interacoes:registrar(def.nome, def)
		prompts[def.nome] = def.prompt
		posicoes[def.nome] = def.posicao
	end
	mundo:aoMudar(function()
		interacoes:atualizar()
	end)
	local zonas = Zonas.novo({
		missao = missao,
		jogadores = function()
			local r = {}
			for _, j in jogadores do
				local p, vivo = localizarJ(j)
				table.insert(r, { jogador = j, pos = p, vivo = vivo })
			end
			return r
		end,
	})
	for nome, forma in cena.zonas do
		zonas:registrar(nome, forma)
	end
	missao:iniciar()
	interacoes:atualizar()
	local function passo(nome: string, cond: boolean)
		if not cond then
			error("passo falhou: " .. nome .. " (nó " .. tostring(missao:no()) .. ")", 2)
		end
	end
	mover(ana, Vector3.new(2, 3, 7))
	zonas:verificar()
	avancar(12)
	passo("rádio aparece", prompts.pegar_radio.Enabled and objetivo == "radio")
	mover(ana, Vector3.new(4.5, 3, 3.6))
	passo("pegar rádio", (interacoes:acionar(ana, prompts.pegar_radio)))
	avancar(30)
	passo("módulo disponível", prompts.pegar_bateria.Enabled and objetivo == "bateria")
	mover(ana, Vector3.new(-88, 3, -201.6))
	passo("pegar módulo", (interacoes:acionar(ana, prompts.pegar_bateria)))
	passo("módulo na mão", ana.Character:FindFirstChild("ModuloNaMao") ~= nil)
	avancar(1)
	mover(ana, Vector3.new(-62.2, 3, -306))
	passo("encaixar", (interacoes:acionar(ana, prompts.encaixar_bateria)))
	avancar(55)
	passo("isolamento", objetivo == "oficina" and mundo:estado("alarme") == "ligado")
	mover(bia, Vector3.new(59, 3, -316))
	zonas:verificar()
	passo("porta aberta", mundo:estado("porta_oficina") == "aberta")
	avancar(1)
	mover(bia, Vector3.new(67.6, 3, -305))
	passo("trava", (interacoes:acionar(bia, prompts.fechar_trava)))
	passo("checkpoint", checkpoint:ultimo() ~= nil and checkpoint:ultimo().id == "oficina_segura")
	avancar(8)
	mover(bia, Vector3.new(87.7, 3, -302.3))
	passo("terminal", (interacoes:acionar(bia, prompts.ler_terminal)))
	local visor = pasta.TerminalOficina.Visor
	passo("tela marcada", CollectionService:HasTag(visor, Compartilhado.TAG_TELA) and visor:GetAttribute(Compartilhado.ATR_TELA_ESTADO) == "lista")
	for _, idioma in Textos.IDIOMAS do
		local texto = Telas.conteudo(Textos.L[idioma], "oficina", "lista", visor:GetAttribute(Compartilhado.ATR_TELA_NOMES))
		passo("lista com jogadores (" .. idioma .. ")", string.find(texto, "ANA", 1, true) ~= nil and string.find(texto, "BIA", 1, true) ~= nil)
	end
	avancar(30)
	passo("fim da etapa", missao:final() and objetivo == "piso" and fimEm > 0)
	out.info.no_final = missao:no()
	for _, k in { "modulo_encaixe", "alavanca", "porta_desliza", "terminal_bip" } do
		passo("ruído " .. k, ruidos[k] == true)
	end
	out.info.pecas_cenario = #pasta:GetDescendants()
end)
for _, m in logMundo do
	falha("mundo: " .. m)
end
out.info.fluxo = fluxoOk

-- 6) interface do cliente (montada aqui só para pegar erro de propriedade/enum), nas 3 línguas
checar("interface do cliente", function()
	local falsa = Instance.new("Folder")
	falsa.Name = "PlayerGuiFalso"
	falsa.Parent = pasta
	local idioma = "pt"
	local ouvintes = {}
	local function atual()
		return idioma
	end
	local function aoMudar(fn)
		table.insert(ouvintes, fn)
	end
	local ui = Interface.criar(falsa, Textos, atual)
	Prompts.iniciar(falsa, { textos = Textos, idioma = atual, aoMudar = aoMudar })
	Telas.iniciar({ playerGui = falsa, textos = Textos, idioma = atual, aoMudar = aoMudar })
	for _, l in Textos.IDIOMAS do
		idioma = l
		for _, fn in ouvintes do
			fn(l)
		end
		ui.idioma()
		ui.objetivo("terminal")
		ui.fala("orlov_ordem", 0.5)
		ui.som("alarme", 0.5)
		ui.aviso("modulo_com", { "ANA" })
	end
	ui.alarme(true)
	ui.alarme(false)
	ui.corte()
	ui.fim()
	assert(#Interface.quebrar(Textos.falas.orlov_ordem[2], 40) >= 3, "quebra de linha")
	-- telas: uma SurfaceGui por terminal marcado, desenhada na última língua (russo)
	local telas = falsa:FindFirstChild("BastiaoTelas")
	assert(telas and #telas:GetChildren() >= 2, "telas dos terminais não foram montadas")
	local achou = false
	for _, sg in telas:GetChildren() do
		if sg:IsA("SurfaceGui") and sg.Adornee == pasta.TerminalOficina.Visor then
			local t = sg:FindFirstChildWhichIsA("TextLabel", true)
			assert(t and string.find(t.Text, "ANA", 1, true), "tela da oficina sem a lista")
			assert(string.find(t.Text, Textos.L.ru.terminais.sokolov, 1, true), "tela da oficina não está em russo")
			achou = true
		end
	end
	assert(achou, "tela da oficina não achada")
	task.wait(0.6)
end)

-- 6b) som do cliente montado de verdade (grupos, eco, vozes, efeitos 3D, loops, alarme, passos)
checar("som do cliente", function()
	assert(Som.zona(Vector3.new(-88, 4, -320)) == "sala" and Som.zona(Vector3.new(0, 4, -535)) == "galpao", "zonas de eco")
	local temId = false
	for _, id in Audio.ids do
		if id > 0 then
			temId = true
		end
	end
	-- sem IDs ainda (sons em moderação ou chave sem permissão), monta com IDs falsos só para
	-- conferir as propriedades; nada disso fica no jogo (a sessão é descartada)
	local audio = Audio
	if not temId then
		audio = table.clone(Audio)
		audio.ids = { voz_pt = 1, voz_en = 1, voz_ru = 1, efeitos = 1 }
	end
	local alarmeLigado, acessoBloqueado = false, false
	local idioma = "pt"
	local som = Som.iniciar({
		audio = audio,
		textos = Textos,
		idioma = function()
			return idioma
		end,
		alarme = function()
			return alarmeLigado
		end,
		acessoBloqueado = function()
			return acessoBloqueado
		end,
	})
	for _, l in Textos.IDIOMAS do
		idioma = l
		som.precarregar()
		for chave in Textos.FALANTE do
			som.fala(chave)
		end
	end
	for chave in Som.DA_LEGENDA do
		som.som(chave, Vector3.new(0, 4, -100))
		som.som(chave, nil)
	end
	for nome in Som.EFEITOS do
		som.ruido(nome, Vector3.new(0, 4, -100))
	end
	alarmeLigado, acessoBloqueado = true, true
	som.estado()
	task.wait(0.3)
	alarmeLigado = false
	som.estado()
	som.parar()
	out.info.som_montado = true
end)

-- 6c) os arquivos de som enviados carregam e os trechos cabem neles (só informa se ainda não carregou)
if (function()
	for _, id in Audio.ids do
		if id > 0 then
			return true
		end
	end
	return false
end)() then
	out.info.sons = {}
	for nome, id in Audio.ids do
		if id > 0 then
			local s = Instance.new("Sound")
			s.SoundId = "rbxassetid://" .. id
			s.Parent = pasta
			pcall(function()
				game:GetService("ContentProvider"):PreloadAsync({ s })
			end)
			local inicio = os.clock()
			while s.TimeLength <= 0 and os.clock() - inicio < 8 do
				task.wait(0.25)
			end
			out.info.sons[nome] = math.floor(s.TimeLength * 100) / 100
			if s.TimeLength <= 0 then
				aviso("Som " .. nome .. " (" .. id .. ") ainda não carregou no motor (moderação em análise?)")
			else
				local maior = 0
				if nome == "efeitos" then
					for _, grupo in { Audio.sfx, Audio.loops } do
						for _, seg in grupo do
							local lista = if type(seg[1]) == "table" then seg else { seg }
							for _, t in lista do
								maior = math.max(maior, t[1] + t[2])
							end
						end
					end
				else
					for _, seg in Audio.vozes[string.sub(nome, 5)] or {} do
						maior = math.max(maior, seg[1] + seg[2])
					end
				end
				if maior > s.TimeLength + 0.1 then
					falha(string.format("Som %s tem %.1fs mas os trechos vão até %.1fs (ID trocado?)", nome, s.TimeLength, maior))
				end
			end
		end
	end
end

-- 7) o Pavel anda de verdade (rota túnel -> arsenal, ~300 studs)
if pavelReal and pavelReal.rig then
	checar("Pavel anda até o arsenal", function()
		pavelReal:ir("tunel", true)
		task.wait(0.5)
		local inicio = os.clock()
		pavelReal:ir("arsenal", false)
		while not pavelReal:chegou() and os.clock() - inicio < 60 do
			task.wait(0.5)
		end
		assert(pavelReal:chegou(), "não chegou em 60 s")
		local alvo = Pavel.LUGARES.arsenal.pos
		local p = pavelReal.raiz.Position
		local d = Vector3.new(p.X - alvo.X, 0, p.Z - alvo.Z).Magnitude
		assert(d < 3, string.format("parou a %.1f studs do lugar", d))
		out.info.pavel_segundos = math.floor((os.clock() - inicio) * 10) / 10
	end)
end

-- 8) log
for _, e in LogService:GetLogHistory() do
	if e.messageType == Enum.MessageType.MessageError and string.find(e.message, "Bastiao", 1, true) then
		falha("log: " .. string.sub(e.message, 1, 300))
		if #out.erros > 12 then
			break
		end
	end
end

pcall(function()
	pasta:Destroy()
end)
return relatorio()
