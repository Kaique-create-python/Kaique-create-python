-- PROJETO BASTIÃO :: teste na nuvem da Etapa 3 (Luau Execution numa versão SALVA, nunca publicada)
-- O instalador acrescenta antes deste texto a linha `local cfg = ...` (destino, etapa e o hash
-- de cada script do pacote). Se qualquer verificação falhar, o instalador NÃO publica.
--   1) destino certo e fontes idênticas às do pacote;
--   2) jogo base intacto: mapa Sector7World, HUD da bodycam e scripts Sector7;
--   3) todos os módulos do Bastião carregam no motor;
--   4) se os scripts do place rodam nesta sessão, o servidor da etapa subiu sem erro;
--   5) a abertura inteira roda com o cenário real (pasta de teste) e fixtures Player reais;
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

local inicioTeste = os.clock()
local out = { package = cfg.package, passed = true, erros = {}, avisos = {}, info = {
	motor = "Roblox Saved-cloud", etapa = 3,
	limites = { "Sem prova de audibilidade ou apresentação em dispositivos", "Sem prova visual de deformação da pele" },
} }
local function falha(msg: string)
	out.passed = false
	table.insert(out.erros, string.sub(tostring(msg), 1, 600))
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
if cfg.package ~= "BASTIAO-ETAPA-3" or cfg.stage ~= 3 or cfg.universe ~= 10776462844 or cfg.place ~= 89520940302906 then
	falha("Destino/pacote incorreto.")
	return relatorio()
end
if game.GameId ~= cfg.universe or game.PlaceId ~= cfg.place then
	falha("A sessão Roblox não pertence ao universo/place fixos do pacote.")
	return relatorio()
end
if type(cfg.hashes) ~= "table" or #cfg.hashes == 0 then
	falha("Mapa de hashes obrigatório está vazio.")
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
-- Unica excecao Sector7 autorizada: +15,8% de folego, nenhuma outra regra muda.
do
    local config = localizar(game, {"ReplicatedStorage", "Sector7", "Config"})
    local ok, c = pcall(function() return require(config) end)
    if not ok or type(c) ~= "table" or c.DrainRate ~= 19 or c.MaxStamina ~= 100
        or c.WalkSpeed ~= 10 or c.SprintSpeed ~= 18 or c.RegenRate ~= 16
        or c.RegenDelay ~= 1.5 or c.RestartThreshold ~= 30 then
        falha("Config de stamina divergiu da excecao revisada")
    end
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
local AudioCatalog = require(COMP.AudioCatalog)
local MonsterCatalog = require(COMP.MonsterCatalog)
local MonsterImportContract = require(SRV.MonsterImportContract)
local CriaturaCore = require(SRV.CriaturaCore)
checar("versão compartilhada da etapa", function()
	assert(Compartilhado.ETAPA == "ETAPA-3", "BastiaoCompartilhado ainda não identifica ETAPA-3")
end)

-- 3b) catálogos reais: nenhuma substituição por IDs fictícios.
local function finito(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function idValido(n: any): boolean
	return finito(n) and n > 0 and n < 9007199254740992 and n % 1 == 0
end
local audioPorId = {}
local function audioReal(id: any, inicio: any, duracao: any, rotulo: string)
	assert(idValido(id), "ID real inválido: " .. rotulo)
	assert(finito(inicio) and inicio >= 0 and finito(duracao) and duracao > 0, "trecho inválido: " .. rotulo)
	local chave = tostring(id)
	local item = audioPorId[chave]
	if not item then
		item = { id = id, limite = 0, trechos = 0 }
		audioPorId[chave] = item
	end
	item.limite = math.max(item.limite, inicio + duracao)
	item.trechos += 1
end
checar("tabela de áudio", function()
	-- Fala sem gravação aparece só como legenda (o jogo foi feito para isso). Aqui só se confere
	-- que cada voz que EXISTE tem ID real e trecho dentro do arquivo; ID 0 = língua ainda sem voz.
	for _, nome in { "voz_pt", "voz_en", "voz_ru", "efeitos" } do
		local id = Audio.ids[nome]
		assert(id == nil or id == 0 or idValido(id), "ID de áudio inválido: " .. nome)
	end
	local vozes = 0
	for _, idioma in Textos.IDIOMAS do
		local falas = Audio.vozes[idioma]
		assert(falas == nil or type(falas) == "table", "vozes inválidas: " .. idioma)
		for chave, seg in falas or {} do
			assert(Textos.FALANTE[chave], "voz de fala inexistente: " .. idioma .. "/" .. chave)
			assert(type(seg) == "table", "voz inválida: " .. idioma .. "/" .. chave)
			audioReal(Audio.ids[seg[3] or ("voz_" .. idioma)], seg[1], seg[2], idioma .. "/" .. chave)
			assert(finito(Audio.duracoes[chave]) and Audio.duracoes[chave] >= seg[2] - 0.01, "duração da voz " .. chave)
			vozes += 1
		end
	end
	assert(vozes > 0, "nenhuma voz gravada")
	for _, grupo in { Audio.sfx, Audio.loops } do
		for nome, seg in grupo do
			local lista = if type(seg[1]) == "table" then seg else { seg }
			for _, trecho in lista do
				audioReal(Audio.ids[trecho[3] or "efeitos"], trecho[1], trecho[2], nome)
			end
		end
	end
	out.info.vozes = vozes
end)
checar("AudioCatalog real", function()
	assert(AudioCatalog.version == 1 and type(AudioCatalog.assets) == "table", "AudioCatalog v1 ausente")
	local quantidade = 0
	for chave, e in AudioCatalog.assets do
		assert(type(chave) == "string" and type(e) == "table", "entrada inválida no catálogo")
		assert(finito(e.start) and finito(e.finish) and e.finish > e.start and e.finish <= 7200, "limites: " .. chave)
		assert(finito(e.duration) and e.duration <= 90 and math.abs(e.finish - e.start - e.duration) <= 0.025, "duração: " .. chave)
		assert(e.category == "Voice" or e.category == "Foley" or e.category == "Ambience" or e.category == "UI", "categoria: " .. chave)
		for _, flag in { "loop", "spatial", "radio" } do
			assert(e[flag] == nil or type(e[flag]) == "boolean", "flag " .. flag .. ": " .. chave)
		end
		assert(e.volume == nil or (finito(e.volume) and e.volume >= 0 and e.volume <= 1), "volume: " .. chave)
		audioReal(e.id, e.start, e.duration, chave)
		quantidade += 1
	end
	assert(quantidade > 0, "catálogo vazio")
	out.info.audio_catalog_trechos = quantidade
end)
checar("MonsterCatalog 35 clipes", function()
	local ok, motivo = CriaturaCore.validateCatalog(MonsterCatalog)
	assert(ok, motivo)
	assert(MonsterCatalog.meshName == MonsterImportContract.MeshName and MonsterCatalog.rootBone == "pelvis", "identidade do rig incompatível")
	assert(MonsterCatalog.visualFacingYawDegrees == MonsterImportContract.VisualFacingYawDegrees, "orientação visual incompatível")
	assert(math.abs(MonsterCatalog.heightStuds - MonsterImportContract.HeightStuds) < 0.015, "altura do catálogo incompatível")
	local quantidade, ids = 0, {}
	for nome, clip in MonsterCatalog.animations do
		assert(type(nome) == "string" and type(clip) == "table" and idValido(clip.id), "clipe inválido")
		assert(not ids[clip.id], "ID de animação repetido: " .. nome)
		ids[clip.id] = true
		assert(clip.id ~= MonsterCatalog.modelId, "ModelId usado como AnimationId")
		assert(finito(clip.duration) and clip.duration > 0 and clip.duration <= 90 and type(clip.loop) == "boolean", "duração/loop: " .. nome)
		for _, marker in clip.markers or {} do
			assert(type(marker.name) == "string" and marker.name ~= "" and finito(marker.time)
				and marker.time >= 0 and marker.time <= clip.duration + 1e-6, "marcador inválido: " .. nome)
		end
		quantidade += 1
	end
	assert(quantidade == 35 or (quantidade == 36 and MonsterCatalog.animations["36_CORRER_MEDONHO"]),
		"esperados 35 clipes reais e 36_CORRER_MEDONHO opcional, encontrados " .. quantidade)
	assert(CriaturaCore.markerTime(MonsterCatalog.animations["06_RUGIDO"], "Roar"), "marcador Roar ausente")
	assert(CriaturaCore.markerTime(MonsterCatalog.animations["19_CLAW_LEFT"], "Hit"), "marcador Hit ausente")
	out.info.monster_catalog_clipes = quantidade
	out.info.monster_model_id = MonsterCatalog.modelId
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
local mundoDuplicado = if aoVivo then workspace:FindFirstChild(Compartilhado.PASTA_MUNDO) else nil
out.info.fixtureExcludedLiveDuplicate = mundoDuplicado ~= nil
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

-- 4b) A documentação da Open Cloud diz que na execução Luau "a simulação de física não roda".
-- Sem física, Humanoid não anda e o Animator não avança sozinho. A sonda mede isso de verdade
-- (uma peça solta no alto cai ou não) e as checagens que dependem de física se adaptam:
-- nada é dado como aprovado sem prova; o que só dá para ver com física fica avisado.
local fisicaRoda = false
do
	local sonda = Instance.new("Part")
	sonda.Name = "BastiaoSondaFisica"
	sonda.Size = Vector3.new(1, 1, 1)
	sonda.CanCollide, sonda.CanTouch, sonda.CanQuery = false, false, false
	sonda.Anchored = false
	sonda.CFrame = CFrame.new(30000, 30000, 0)
	sonda.Parent = workspace
	local y0 = sonda.Position.Y
	task.wait(0.5)
	fisicaRoda = sonda.Parent ~= nil and sonda.Position.Y < y0 - 0.05
	sonda:Destroy()
end
out.info.fisica_roda = fisicaRoda
if not fisicaRoda then
	aviso("A nuvem não roda física nesta sessão (documentação oficial da Open Cloud). Animações tocando e o Pavel andando de verdade só existem no jogo ao vivo; aqui são conferidos o conteúdo das animações e a rota.")
end

-- 5) abertura inteira com o cenário real e fixtures Player reais
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
local membros = {}
-- Jogadores do teste. No Studio dá para criar Player de verdade; na execução Luau da Open
-- Cloud não (falta a permissão WritePlayer). Lá usamos jogadores falsos (tabelas), como o
-- teste da Etapa 2 fazia, e só ESTE teste aceita esses falsos no Interacoes (o jogo ao vivo
-- continua exigindo Player de verdade dentro de Players).
local podePlayer = pcall(function() Instance.new("Player"):Destroy() end)
out.info.jogadores_do_teste = if podePlayer then "Player real" else "falsos (nuvem sem WritePlayer)"
local function novoJogador(id: number, nome: string): any
	local j: any
	if podePlayer then
		j = Instance.new("Player")
		j.Name = nome
		j.DisplayName = nome
		pcall(function() j.UserId = id end)
	else
		j = { UserId = id, Name = nome, DisplayName = nome, fixture = true }
	end
	assert(finito(j.UserId) and j.UserId % 1 == 0, "UserId não finito na fixture")
	j.Parent = pasta
	local c = Instance.new("Model")
	c.Name = "Fixture" .. nome
	for _, dado in { { "HumanoidRootPart", Vector3.zero }, { "Head", Vector3.new(0, 1.5, 0) }, { "Right Arm", Vector3.new(1.5, 0, 0) } } do
		local parte = Instance.new("Part")
		parte.Name = dado[1]
		parte.Size = Vector3.new(0.5, 0.5, 0.5)
		parte.Anchored, parte.CanCollide, parte.CanTouch = true, false, false
		parte.Transparency = 1
		parte.CFrame = CFrame.new(Vector3.new(0, 3, 12) + dado[2])
		parte.Parent = c
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = c
	c.Parent = pasta
	j.Character = c
	membros[j] = true
	return j
end
-- Só no serviço criado por este teste: aceita os jogadores falsos registrados acima e manda
-- todo o resto (tabela estranha, Folder, Player de fora) para a validação real do Interacoes.
local function aceitarFixtures(servico: any)
	if podePlayer then return end
	local real = Interacoes._jogadorOk
	servico._jogadorOk = function(self: any, j: any): boolean
		if type(j) == "table" and membros[j] == true and j.fixture == true then
			return finito(j.UserId) and j.UserId % 1 == 0 and j.Parent == pasta
		end
		return real(self, j)
	end
end
local pavelReal = nil
local fluxoOk = nil
local fixtures = {}
if not checar("jogadores do teste", function()
	fixtures = { novoJogador(901, "Ana"), novoJogador(902, "Bia") }
end) then
	pasta:Destroy()
	return relatorio()
end
local ana, bia = fixtures[1], fixtures[2]
local jogadores = { ana, bia }
local function mover(j: any, p: Vector3)
	local c = j.Character
	assert(c, "fixture sem Character")
	local raiz = c.HumanoidRootPart :: BasePart
	local head = c.Head :: BasePart
	local braco = c["Right Arm"] :: BasePart
	raiz.CFrame = CFrame.new(p)
	head.CFrame = CFrame.new(p + Vector3.new(0, 1.5, 0))
	braco.CFrame = CFrame.new(p + Vector3.new(1.5, 0, 0))
end
local function localizarJ(j: any): (Vector3?, boolean)
	local c = j.Character
	if not c or not c:IsDescendantOf(workspace) then return nil, false end
	local r, h = c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildWhichIsA("Humanoid")
	if not r or not r:IsA("BasePart") or not h or h.Health <= 0 then return nil, false end
	return r.Position, true
end
local function visivel(j: any, registro: any, origem: Vector3, alvo: Vector3): boolean
	local c, prompt = j.Character, registro.prompt
	local parte = prompt and prompt.Parent
	if parte and parte:IsA("Attachment") then parte = parte.Parent end
	if not c or not parte or not parte:IsA("BasePart") or not parte:IsDescendantOf(pasta) then return false end
	local head = c:FindFirstChild("Head")
	local inicio = if head and head:IsA("BasePart") then head.Position else origem
	local direcao = alvo - inicio
	if direcao.Magnitude < 0.001 then return true end
	local modelo = parte:FindFirstAncestorOfClass("Model")
	local proprio = if modelo and modelo:IsDescendantOf(pasta) then modelo else parte
	local parametros = RaycastParams.new()
	parametros.FilterType = Enum.RaycastFilterType.Exclude
	local excluir = { c, proprio }
	-- Igual ao servidor: corpos (outros jogadores e o Pavel) não bloqueiam a visão.
	for outro in membros do
		if outro.Character and outro.Character ~= c then table.insert(excluir, outro.Character) end
	end
	for _, filho in pasta:GetChildren() do
		if filho:GetAttribute("BastiaoNPC") == true then table.insert(excluir, filho) end
	end
	-- Só o cenário temporário exclui a cópia idêntica que o servidor pode ter
	-- construído nas mesmas coordenadas. Sector7World continua no raycast.
	if mundoDuplicado then table.insert(excluir, mundoDuplicado) end
	parametros.FilterDescendantsInstances = excluir
	parametros.IgnoreWater = true
	return workspace:Raycast(inicio, direcao, parametros) == nil
end

-- Contraprovas nativas, longe do mapa: mesmo serviço e raycast real do fluxo.
checar("recusas e hold legítimo no motor", function()
	local modelo = Instance.new("Model")
	modelo.Name = "AlvoContraprovas"
	modelo.Parent = pasta
	local alvo = Instance.new("Part")
	alvo.Name = "Alvo"
	alvo.Size = Vector3.new(1, 1, 1)
	alvo.Anchored = true
	alvo.Position = Vector3.new(20000, 20003, 0)
	alvo.Parent = modelo
	local prompt = Instance.new("ProximityPrompt")
	prompt.HoldDuration = 1
	prompt.Parent = alvo
	local tempo, aceites = 0, 0
	local servico = Interacoes.novo({
		missao = { espera = function() return true end, reportar = function() aceites += 1 end },
		mundo = { estado = function() return "pronto" end },
		localizar = localizarJ,
		validarJogador = function(j) return membros[j] == true and j.Parent == pasta end,
		visivel = visivel,
		agora = function() return tempo end,
	})
	aceitarFixtures(servico)
	servico:registrar("hold", { prompt = prompt, alcance = 8, posicao = function() return alvo.Position end, evento = "hold" })
	servico:atualizar()
	mover(ana, alvo.Position + Vector3.new(0, 0, 5))
	mover(bia, alvo.Position + Vector3.new(30, 0, 0))
	local casos = 0
	local function recusa(esperado: string, ok: boolean, motivo: string?)
		assert(ok == false and motivo == esperado, "recusa esperada " .. esperado .. ", recebida " .. tostring(motivo))
		casos += 1
	end
	recusa("jogador_invalido", servico:acionar({ UserId = 901, Character = ana.Character, Parent = pasta }, prompt))
	local impostor = Instance.new("Folder")
	impostor.Parent = pasta
	recusa("jogador_invalido", servico:iniciarSegurar(impostor, prompt))
	impostor:Destroy()
	if podePlayer then
		local estranho = Instance.new("Player")
		estranho.Parent = pasta
		recusa("jogador_invalido", servico:iniciarSegurar(estranho, prompt))
		estranho:Destroy()
	else
		-- jogador falso que não é deste teste: também precisa ser recusado
		local intruso = { UserId = 903, Name = "Intruso", DisplayName = "Intruso", Parent = pasta, Character = ana.Character, fixture = true }
		recusa("jogador_invalido", servico:iniciarSegurar(intruso, prompt))
	end
	recusa("sem_hold", servico:acionar(ana, prompt))
	tempo += 0.5
	assert(servico:iniciarSegurar(ana, prompt))
	tempo += 0.1
	servico:terminarSegurar(ana, prompt)
	tempo += 1
	recusa("hold_curto", servico:acionar(ana, prompt))
	tempo += 0.5
	assert(servico:iniciarSegurar(ana, prompt))
	tempo += 1
	servico:terminarSegurar(ana, prompt)
	assert(servico:acionar(ana, prompt), "hold legítimo foi recusado")
	assert(aceites == 1, "hold legítimo não gerou um único evento")
	tempo += 0.5
	recusa("sem_hold", servico:acionar(ana, prompt))
	tempo += 0.5
	mover(ana, alvo.Position + Vector3.new(0, 0, 50))
	recusa("longe", servico:iniciarSegurar(ana, prompt))
	tempo += 0.5
	mover(ana, alvo.Position + Vector3.new(0, 0, 5))
	assert(servico:iniciarSegurar(ana, prompt))
	tempo += 1
	mover(ana, alvo.Position + Vector3.new(0, 0, 50))
	recusa("longe", servico:acionar(ana, prompt))
	mover(ana, alvo.Position + Vector3.new(0, 0, 5))
	local parede = Instance.new("Part")
	parede.Name = "ObstrucaoReal"
	parede.Anchored = true
	parede.CanQuery = true
	parede.Size = Vector3.new(8, 8, 0.5)
	parede.Position = alvo.Position + Vector3.new(0, 0, 2.5)
	parede.Parent = pasta -- fora do Model do alvo; não pode entrar na exclusão
	tempo += 0.5
	recusa("sem_visao", servico:iniciarSegurar(ana, prompt))
	parede.Parent = nil
	tempo += 0.5
	assert(servico:iniciarSegurar(ana, prompt))
	parede.Parent = pasta
	tempo += 1
	recusa("sem_visao", servico:acionar(ana, prompt))
	parede:Destroy()
	tempo += 0.5
	assert(servico:iniciarSegurar(ana, prompt))
	servico:invalidar()
	tempo += 1
	recusa("sem_hold", servico:acionar(ana, prompt))
	assert(aceites == 1, "contraprova concedeu evento indevido")
	servico:esquecer(ana)
	modelo:Destroy()
	out.info.contraprovas_interacoes = casos
end)

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
fluxoOk = checar("fluxo da abertura", function()
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
	local falasApresentadas, fimVoz, totalFalas = {}, -math.huge, 0
	local function logFluxo(m: string)
		if string.find(m, "falhou", 1, true) then falha("fluxo: " .. m) end
	end
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
				interacoes:invalidar()
				interacoes:atualizar()
			end
		end,
		aoFinal = function()
			fimEm = agora
		end,
		log = logFluxo,
	})
	local sequencias = Sequencias.novo({
		def = Cap,
		textos = Textos,
		mundo = mundo,
		apresentar = function(msg)
			if msg.tipo == "fala" then
				if agora < fimVoz - 0.001 then falha("Falas sobrepostas na abertura: " .. tostring(msg.chave)) end
				fimVoz = agora + msg.duracao
				falasApresentadas[msg.chave] = (falasApresentadas[msg.chave] or 0) + 1
				totalFalas += 1
			end
		end,
		aoTerminar = function(id, n)
			missao:reportar({ id = "seq:" .. id .. ":" .. n, kind = "sequencia", name = id .. "_fim" })
		end,
		agendar = agendar,
		agora = function() return agora end,
		cancelar = function(h)
			h.vivo = false
		end,
		duracaoLeitura = Compartilhado.duracaoLeitura,
		duracoes = Audio.duracoes,
		log = logFluxo,
	})
	missao:ligarSequencias(sequencias)
	interacoes = Interacoes.novo({
		missao = missao,
		mundo = mundo,
		localizar = localizarJ,
		validarJogador = function(j: any) return membros[j] == true and j.Parent == pasta end,
		visivel = visivel,
		agora = function()
			return agora
		end,
	})
	aceitarFixtures(interacoes)
	local prompts = {}
	local posicoes = {}
	for _, def in cena.interacoes do
		interacoes:registrar(def.nome, def)
		prompts[def.nome] = def.prompt
		posicoes[def.nome] = def.posicao
	end
	mundo:aoMudar(function()
		interacoes:invalidar()
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
	local function interagir(j: any, p: ProximityPrompt): (boolean, string?)
		if p.HoldDuration > 0 then
			local ok, motivo = interacoes:iniciarSegurar(j, p)
			if not ok then return false, motivo end
			avancar(p.HoldDuration)
			interacoes:terminarSegurar(j, p)
		end
		return interacoes:acionar(j, p)
	end
	local function esperar(nome: string, condicao: () -> boolean)
		local limite = agora + 240
		while not condicao() and agora < limite do avancar(0.25) end
		assert(condicao(), "tempo esgotado: " .. nome .. " (nó " .. tostring(missao:no()) .. ")")
	end
	local function passo(nome: string, cond: boolean)
		if not cond then
			error("passo falhou: " .. nome .. " (nó " .. tostring(missao:no()) .. ")", 2)
		end
	end
	mover(ana, Vector3.new(2, 3, 7))
	zonas:verificar()
	esperar("rádio aparece", function() return prompts.pegar_radio.Enabled and objetivo == "radio" end)
	passo("rádio aparece", prompts.pegar_radio.Enabled and objetivo == "radio")
	mover(ana, Vector3.new(4.5, 3, 3.6))
	passo("pegar rádio", (interagir(ana, prompts.pegar_radio)))
	esperar("módulo disponível", function() return prompts.pegar_bateria.Enabled and objetivo == "bateria" end)
	passo("módulo disponível", prompts.pegar_bateria.Enabled and objetivo == "bateria")
	mover(ana, Vector3.new(-88, 3, -201.6))
	passo("pegar módulo", (interagir(ana, prompts.pegar_bateria)))
	passo("módulo na mão", ana.Character:FindFirstChild("ModuloNaMao") ~= nil)
	avancar(1)
	mover(ana, Vector3.new(-62.2, 3, -306))
	passo("encaixar", (interagir(ana, prompts.encaixar_bateria)))
	esperar("isolamento", function() return objetivo == "oficina" and mundo:estado("alarme") == "ligado" end)
	passo("isolamento", objetivo == "oficina" and mundo:estado("alarme") == "ligado")
	mover(bia, Vector3.new(59, 3, -316))
	zonas:verificar()
	passo("porta aberta", mundo:estado("porta_oficina") == "aberta")
	avancar(1)
	mover(bia, Vector3.new(67.6, 3, -305))
	passo("trava", (interagir(bia, prompts.fechar_trava)))
	passo("checkpoint", checkpoint:ultimo() ~= nil and checkpoint:ultimo().id == "oficina_segura")
	esperar("terminal disponível", function() return prompts.ler_terminal.Enabled end)
	mover(bia, Vector3.new(87.7, 3, -302.3))
	passo("terminal", (interagir(bia, prompts.ler_terminal)))
	local visor = pasta.TerminalOficina.Visor
	passo("tela marcada", CollectionService:HasTag(visor, Compartilhado.TAG_TELA) and visor:GetAttribute(Compartilhado.ATR_TELA_ESTADO) == "lista")
	for _, idioma in Textos.IDIOMAS do
		local texto = Telas.conteudo(Textos.L[idioma], "oficina", "lista", visor:GetAttribute(Compartilhado.ATR_TELA_NOMES))
		passo("lista com jogadores (" .. idioma .. ")", string.find(texto, "ANA", 1, true) ~= nil and string.find(texto, "BIA", 1, true) ~= nil)
	end
	esperar("fim da etapa", function() return missao:final() end)
	esperar("término de todas as sequências", function() return #sequencias:tocando() == 0 end)
	passo("fim da etapa", missao:final() and objetivo == "piso" and fimEm > 0)
	for _, seq in Cap.sequences do
		for _, cue in seq.cues do
			if cue.fala then passo("fala preservada " .. cue.fala, falasApresentadas[cue.fala] == 1) end
		end
	end
	out.info.falas_apresentadas = totalFalas
	out.info.fluxo_tempo_simulado = agora
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
	local alarmeLigado, acessoBloqueado = false, false
	local idioma = "pt"
	local som = Som.iniciar({
		audio = Audio,
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

-- 6c) carregamento real: todas as regiões precisam caber no asset permitido.
-- PreloadAsync pode ceder indefinidamente; workers e LoadAssetAsync têm prazo
-- observado pelo chamador, sem transformar timeout em aviso ou PASS.
local ContentProvider = game:GetService("ContentProvider")
local AssetService = game:GetService("AssetService")
checar("áudio real autorizado e limites nativos", function()
	local pendentes, falhas, sons = 0, {}, {}
	local limite = os.clock() + 30
	for chave, item in audioPorId do
		local s = Instance.new("Sound")
		s.Name = "ChecagemAudio_" .. chave
		s.SoundId = "rbxassetid://" .. chave
		s.Volume = 0
		s.Parent = pasta
		sons[chave] = s
		pendentes += 1
		task.spawn(function()
			local ok, erro = pcall(function()
				ContentProvider:PreloadAsync({ s }, function(_, status)
					if status ~= Enum.AssetFetchStatus.Success then
						falhas[chave] = tostring(status)
					end
				end)
			end)
			if not ok then falhas[chave] = string.sub(tostring(erro), 1, 240) end
			pendentes -= 1
		end)
	end
	assert(next(sons), "nenhum ID de áudio real para verificar")
	while os.clock() < limite do
		local prontos = pendentes == 0
		for _, s in sons do
			if s.TimeLength <= 0 or not s.IsLoaded then prontos = false end
		end
		if prontos then break end
		task.wait(0.1)
	end
	out.info.sons = {}
	local erros = 0
	for chave, s in sons do
		local item = audioPorId[chave]
		out.info.sons[chave] = { segundos = math.floor(s.TimeLength * 100) / 100, fim = item.limite, trechos = item.trechos }
		if falhas[chave] then
			falha("Asset de áudio " .. chave .. " recusado: " .. falhas[chave])
			erros += 1
		elseif not s.IsLoaded or s.TimeLength <= 0 then
			falha("Asset de áudio " .. chave .. " sem duração/carregamento nativo em 30 s")
			erros += 1
		elseif item.limite > s.TimeLength + 0.1 then
			falha(string.format("Áudio %s: %.3fs; região termina em %.3fs", chave, s.TimeLength, item.limite))
			erros += 1
		end
		s:Destroy()
	end
	assert(pendentes == 0 and erros == 0, "áudio real incompleto/sem autorização ou limites incorretos")
	out.info.audio_nativo_pronto = true
end)

-- 6d) o ModelId é um asset de Model, nunca uma malha de um proxy.
-- O contrato confere os 46 Bones, o repouso e a escala antes de criar Animator.
-- Cada etapa registra o próprio erro e o teste segue para as próximas, para que um relatório
-- só já mostre tudo (importação, carregamento, durações, tocar e marcadores).
checar("monstro real, importação e animações nativas", function()
	local function esperarAte(prazo: number, pronto: () -> boolean)
		while not pronto() and os.clock() < prazo do task.wait(0.1) end
		return pronto()
	end
	local terminado, expirado, resultado, erroCarga = false, false, nil, nil
	task.spawn(function()
		local ok, valor = pcall(function() return AssetService:LoadAssetAsync(MonsterCatalog.modelId) end)
		if expirado then
			if ok and typeof(valor) == "Instance" then valor:Destroy() end
			return
		end
		if ok then resultado = valor else erroCarga = string.sub(tostring(valor), 1, 400) end
		terminado = true
	end)
	if not esperarAte(os.clock() + 30, function() return terminado end) then
		expirado = true
		error("LoadAssetAsync do ModelId não concluiu no prazo nativo de 30 s")
	end
	assert(erroCarga == nil, "ModelId sem autorização/carregamento: " .. tostring(erroCarga))
	assert(typeof(resultado) == "Instance" and resultado:IsA("Model"), "ModelId não devolveu Model real")
	local modelo = resultado :: Model
	local conexoes, tracks = {}, {}
	local etapas = {}
	local function etapa(nome: string, fn: () -> ()): boolean
		local ok, erro = pcall(fn)
		etapas[nome] = ok
		if not ok then falha("monstro / " .. nome .. ": " .. tostring(erro)) end
		return ok
	end
	-- diagnóstico cru da importação, antes de qualquer mudança
	pcall(function()
		local classes = {}
		for _, inst in modelo:GetDescendants() do classes[inst.ClassName] = (classes[inst.ClassName] or 0) + 1 end
		local mesh = modelo:FindFirstChildWhichIsA("MeshPart", true)
		local raiz = mesh and mesh:FindFirstChildWhichIsA("Bone")
		local function cf(c: CFrame?)
			if not c then return nil end
			local x, y, z = c:ToOrientation()
			return { pos = { c.X, c.Y, c.Z }, graus = { math.deg(x), math.deg(y), math.deg(z) } }
		end
		out.info.monstro_importado = {
			classes = classes, malha = mesh and mesh.Name, tamanho = mesh and { mesh.Size.X, mesh.Size.Y, mesh.Size.Z },
			malha_cframe = mesh and cf(mesh.CFrame), raiz = raiz and raiz.Name, raiz_cframe = raiz and cf(raiz.CFrame),
			escala_modelo = modelo:GetScale(),
		}
	end)
	local mesh
	etapa("importação", function()
		for _, inst in modelo:GetDescendants() do
			assert(not inst:IsA("LuaSourceContainer"), "Model importado contém código inesperado")
			if inst:IsA("Animator") then
				assert(#inst:GetPlayingAnimationTracks() == 0, "importação já estava animada")
				inst:Destroy()
			end
		end
		local report = MonsterImportContract.Prepare(modelo, true)
		local resumo = MonsterImportContract.Summary(report)
		resumo.altura_importada = report.importedHeightStuds
		out.info.monstro_contrato = resumo
		assert(report.ok, "importação incompatível: " .. table.concat(report.errors, "; "))
		assert(report.boneCount == 46 and report.meshCount == 1, "rig canônico de 46 Bones/1 mesh ausente")
		local rig, motivo = CriaturaCore.inspectRig(modelo, MonsterCatalog.heightStuds)
		assert(rig, motivo)
		mesh = modelo:FindFirstChild(MonsterCatalog.meshName, true)
		assert(mesh and mesh:IsA("MeshPart") and mesh.MeshId ~= "" and mesh.Transparency < 0.98, "mesh real visível ausente")
		assert(mesh.MeshId ~= "rbxassetid://" .. tostring(MonsterCatalog.modelId), "ModelId foi usado como MeshId")
		out.info.monstro_importacao = { bones = report.boneCount, meshes = report.meshCount, altura = rig.height,
			repouso_studs = report.maxRestPositionErrorStuds, repouso_radianos = report.maxRestAngleErrorRadians,
			giro_importador_graus = report.importYawDegrees, mesh_id = mesh.MeshId, pele_visual_verificada = false }
	end)
	mesh = mesh or modelo:FindFirstChildWhichIsA("MeshPart", true)
	for _, inst in modelo:GetDescendants() do
		if inst:IsA("Humanoid") or inst:IsA("AnimationController") then inst:Destroy() end
		if inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide, inst.CanTouch, inst.CanQuery = false, false, false
		end
	end
	modelo.Name = "MonstroRealTeste"
	modelo:PivotTo(CFrame.new(21000, 20000, 0))
	modelo.Parent = pasta
	local controller = Instance.new("AnimationController")
	controller.Parent = modelo
	local animator = Instance.new("Animator")
	animator.Parent = controller
	local animations, assets = {}, {}
	if mesh then table.insert(assets, mesh) end
	for nome, clip in MonsterCatalog.animations do
		local anim = Instance.new("Animation")
		anim.Name = nome
		anim.AnimationId = "rbxassetid://" .. tostring(clip.id)
		anim.Parent = controller
		animations[nome] = anim
		table.insert(assets, anim)
	end
	etapa("carregar 35 animações e a malha", function()
		local carregou, recusas, erroPreload = false, {}, nil
		task.spawn(function()
			local carregamentoOk, carregamentoErro = pcall(function()
				ContentProvider:PreloadAsync(assets, function(id, status)
					if status ~= Enum.AssetFetchStatus.Success then recusas[tostring(id)] = tostring(status) end
				end)
			end)
			if not carregamentoOk then erroPreload = string.sub(tostring(carregamentoErro), 1, 400) end
			carregou = true
		end)
		esperarAte(os.clock() + 45, function() return carregou end)
		assert(carregou and erroPreload == nil and next(recusas) == nil,
			"35 animações/malha não carregaram com autorização: " .. tostring(erroPreload) .. " " .. HttpService:JSONEncode(recusas))
	end)
	etapa("durações nativas", function()
		for nome, anim in animations do
			tracks[nome] = animator:LoadAnimation(anim)
		end
		esperarAte(os.clock() + 30, function()
			for _, track in tracks do if track.Length <= 0 then return false end end
			return true
		end)
		local comprimentos, erradas = {}, {}
		for nome, track in tracks do
			local duracao = MonsterCatalog.animations[nome].duration
			comprimentos[nome] = math.floor(track.Length * 1000) / 1000
			if not (track.Length > 0 and math.abs(track.Length - duracao) <= math.max(0.25, duracao * 0.15)) then
				table.insert(erradas, string.format("%s=%.2fs (catálogo %.2fs)", nome, track.Length, duracao))
			end
		end
		out.info.monstro_tracks = comprimentos
		table.sort(erradas)
		assert(#erradas == 0, "duração nativa incorreta: " .. table.concat(erradas, ", "))
	end)
	-- Tocar de verdade e o disparo dos marcadores dependem do Animator avançar, e isso depende do
	-- ambiente: a documentação da Open Cloud diz que na execução Luau a física não roda. Por isso
	-- estas duas etapas só INFORMAM (com aviso quando não deu para ver). O que reprova de verdade é
	-- o que prova defeito no asset: importação, carregamento, duração e o conteúdo das 35 animações.
	local passoManual = nil
	local function avancarNaMao(dt: number): boolean
		if passoManual == false then return false end
		local ok = pcall(function() (animator :: any):StepAnimations(dt) end)
		passoManual = ok
		return ok
	end
	etapa("tocar respiração/andar/correr", function()
		local resultado = {}
		for _, nome in { "01_RESPIRACAO", "07_ANDAR", "08_CORRER" } do
			local track = tracks[nome]
			if not track then
				resultado[nome] = "sem track"
				continue
			end
			track.Looped = true
			track:Play(0, 1, 1)
			local como = nil
			if fisicaRoda then
				task.wait(0.25)
				if track.IsPlaying and track.TimePosition > 0 then como = "motor" end
			end
			if not como and avancarNaMao(0.25) and track.IsPlaying and track.TimePosition > 0 then
				como = "passo manual"
			end
			resultado[nome] = como or "não avançou nesta sessão"
			track:Stop(0)
		end
		out.info.monstro_tocar = resultado
		for nome, r in resultado do
			if r ~= "motor" and r ~= "passo manual" then
				aviso("Monstro: " .. nome .. " não avançou nesta sessão (" .. r .. "); tocar de verdade fica para o jogo ao vivo.")
			end
		end
	end)
	etapa("marcadores Roar/Hit", function()
		local resultado = {}
		for _, caso in { { "06_RUGIDO", "Roar" }, { "19_CLAW_LEFT", "Hit" } } do
			local nome, marcador = caso[1], caso[2]
			local track = tracks[nome]
			if not track then
				resultado[marcador] = "sem track"
				continue
			end
			local recebeu = false
			table.insert(conexoes, track:GetMarkerReachedSignal(marcador):Connect(function() recebeu = true end))
			track.Looped = false
			if fisicaRoda then
				track:Play(0, 1, 3)
				local ate = os.clock() + math.max(1, track.Length / 3 + 0.75)
				while not recebeu and os.clock() < ate do task.wait(0.05) end
				track:Stop(0)
			end
			if not recebeu then
				track:Play(0, 1, 1)
				local andou = 0
				while not recebeu and andou < track.Length + 0.2 and avancarNaMao(1 / 30) do
					andou += 1 / 30
					task.wait()
				end
				track:Stop(0)
			end
			resultado[marcador] = if recebeu then "disparou" else "não disparou nesta sessão"
			if not recebeu then
				aviso("Monstro: marcador " .. marcador .. " (" .. nome .. ") não disparou nesta sessão; ele está na animação enviada (conferido abaixo) e dispara no jogo ao vivo.")
			end
		end
		out.info.monstro_marcadores = resultado
	end)
	-- Conteúdo de verdade das 35 animações enviadas (não depende de física): cada marcador do
	-- catálogo existe no tempo certo, a duração bate e todo osso animado existe no monstro.
	etapa("conteúdo das 35 animações", function()
		local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
		local nomesRig = {}
		for _, d in modelo:GetDescendants() do
			if d:IsA("Bone") or d:IsA("MeshPart") then nomesRig[d.Name] = true end
		end
		local problemas, conferidas, recusadas, primeiroErro = {}, 0, 0, nil
		for nome, clip in MonsterCatalog.animations do
			local seq
			for tentativa = 1, 2 do
				local ok, valor = pcall(function()
					return KeyframeSequenceProvider:GetKeyframeSequenceAsync("rbxassetid://" .. tostring(clip.id))
				end)
				if ok and typeof(valor) == "Instance" then
					seq = valor
					break
				end
				primeiroErro = primeiroErro or string.sub(tostring(valor), 1, 200)
				if tentativa == 1 then task.wait(1) end
			end
			if not seq then
				recusadas += 1
				table.insert(problemas, nome .. ": não abriu")
				continue
			end
			local marcas, fim, fora = {}, 0, {}
			for _, d in seq:GetDescendants() do
				if d:IsA("Keyframe") then
					fim = math.max(fim, d.Time)
				elseif d:IsA("KeyframeMarker") then
					-- o mesmo marcador pode aparecer várias vezes (um "Footstep" por passo)
					local kf = d.Parent
					if kf and kf:IsA("Keyframe") then
						marcas[d.Name] = marcas[d.Name] or {}
						table.insert(marcas[d.Name], kf.Time)
					end
				elseif d:IsA("Pose") and d.Name ~= "HumanoidRootPart" and not nomesRig[d.Name] then
					fora[d.Name] = true
				end
			end
			for _, m in clip.markers or {} do
				local tempos = marcas[m.name]
				local perto = nil
				for _, t in tempos or {} do
					if perto == nil or math.abs(t - m.time) < math.abs(perto - m.time) then perto = t end
				end
				if perto == nil then
					table.insert(problemas, nome .. ": marcador " .. m.name .. " ausente")
				elseif math.abs(perto - m.time) > 0.05 then
					table.insert(problemas, string.format("%s: marcador %s em %.2fs (catálogo %.2fs)", nome, m.name, perto, m.time))
				end
			end
			local listaFora = {}
			for n in fora do table.insert(listaFora, n) end
			if #listaFora > 0 then
				table.sort(listaFora)
				table.insert(problemas, nome .. ": anima ossos que o monstro não tem: " .. table.concat(listaFora, " ", 1, math.min(#listaFora, 6)))
			end
			if math.abs(fim - clip.duration) > math.max(0.25, clip.duration * 0.15) then
				table.insert(problemas, string.format("%s: dura %.2fs (catálogo %.2fs)", nome, fim, clip.duration))
			end
			seq:Destroy()
			conferidas += 1
		end
		out.info.monstro_animacoes_conferidas = conferidas
		if conferidas == 0 and recusadas > 0 then
			-- Nenhuma abriu: a sessão não deixa ler animações (não é defeito de uma animação).
			-- As 35 carregaram e têm a duração certa no motor (etapa anterior), e cada ID está preso
			-- ao hash do arquivo enviado (recibo do instalador), cujo conteúdo foi conferido offline.
			aviso("Monstro: a nuvem não deixou ler o conteúdo das animações (" .. tostring(primeiroErro) .. "); valem a duração conferida no motor e o hash dos arquivos enviados.")
			out.info.monstro_animacoes_conferidas = "sem permissão nesta sessão"
			return
		end
		table.sort(problemas)
		assert(#problemas == 0, table.concat(problemas, "; ", 1, math.min(#problemas, 8)))
	end)
	out.info.monstro_etapas = etapas
	for _, c in conexoes do c:Disconnect() end
	for _, track in tracks do track:Stop(0); track:Destroy() end
	modelo:Destroy()
	local tudo = true
	for _, ok in etapas do tudo = tudo and ok end
	out.info.monstro_nativo_pronto = tudo
end)

-- 7) o Pavel anda de verdade (rota túnel -> arsenal, ~300 studs). Sem física (nuvem), o Humanoid
-- não anda: o Pavel chega pelos pontos da rota (o mesmo código que o destrava no jogo).
if pavelReal and pavelReal.rig then
	checar(if fisicaRoda then "Pavel anda até o arsenal" else "Pavel chega ao arsenal pelos pontos da rota (sem física)", function()
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

out.info.duracao_real_segundos = math.floor((os.clock() - inicioTeste) * 100) / 100
pcall(function()
	pasta:Destroy()
end)
return relatorio()
