-- OI3 :: sons (cliente). Toca trechos de arquivos "sprite" (vários sons num áudio só).
-- AJUSTE-4:
--  * cada arquivo é vigiado até carregar (sem prazo curto) e ganha novas tentativas se falhar;
--    quando um arquivo fica pronto mais tarde, o jogo é avisado e liga a música/ambiente sozinho;
--  * um som PÚBLICO do próprio Roblox serve de "controle": se ele carrega e o nosso não,
--    o áudio está bloqueado (falta liberar a permissão do jogo) e a tela de Configurações diz isso;
--  * o trecho do sprite só é marcado depois que o áudio carregou (antes podia ficar mudo).
-- AJUSTE-9 ("nada sintético"):
--  * os sons agora são GRAVAÇÕES de verdade das bibliotecas licenciadas do Roblox (SonsBiblioteca):
--    coração, respiração, rangidos, batidas, máquinas, vento, grilos... e os sons do monstro;
--  * eles são públicos (não precisam de upload nem de permissão); se algum não carregar, o jogo toca o
--    som antigo do mesmo nome (sprite) no lugar;
--  * a caixinha de música toca "Parabéns" nota por nota com uma nota gravada de uma caixinha de verdade.

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local OI3 = script.Parent.Parent
local Recursos = require(OI3.Recursos)
local AudioMapa = require(OI3.AudioMapa)
local Biblioteca = require(OI3.SonsBiblioteca)

local Som = {}

-- som público do Roblox (espada clássica, criador "Roblox"): só para diagnóstico, nunca toca
local CONTROLE_ID = "rbxassetid://12222216"

local NOMES = {
	sfx = "efeitos",
	vozes1 = "vozes",
	vozes2 = "vozes 2",
	musica = "música",
	ambiente = "ambiente",
	passos = "passos",
	historia = "história",
	vozes3 = "vozes 3",
}

local grupos: { [string]: SoundGroup } = {}
local ambientes: { [string]: Sound } = {}
local modelos: { [string]: Sound } = {} -- um Sound por arquivo (o modelo que é clonado)
local estadoArquivo: { [string]: string } = {} -- "carregando" | "pronto" | "falhou" | "sem_id"
local estadoControle = "carregando" -- "carregando" | "pronto" | "falhou"
local ativos: { [Sound]: { inicio: number, fim: number, loop: boolean } } = {}
local ouvintesEstado: { () -> () } = {}
local iniciado = false
-- biblioteca (AJUSTE-9): um Sound modelo por ID público
local modelosLib: { [number]: Sound } = {}
local estadoLib: { [number]: string } = {} -- "carregando" | "pronto" | "falhou"

local function idDe(arquivo: string): number
	local audio = Recursos.audio
	if type(audio) ~= "table" then
		return 0
	end
	return tonumber(audio[arquivo]) or 0
end

function Som.item(nome: string)
	return AudioMapa.itens[nome]
end

-- variantes da biblioteca que ainda podem tocar (não falharam)
local function variantesVivas(nome: string): { any }
	local b = Biblioteca.sons[nome]
	local lista = {}
	if b and iniciado then
		for _, v in b.variantes do
			if estadoLib[v.id] ~= "falhou" then
				table.insert(lista, v)
			end
		end
	end
	return lista
end

-- true se o som gravado (biblioteca) deste nome pode tocar
function Som.temGravacao(nome: string): boolean
	return #variantesVivas(nome) > 0
end

-- AJUSTE-11: o trecho de sprite que pode tocar AGORA. Se o arquivo novo não toca (ainda em análise no
-- Roblox, ou bloqueado) ou a fala nova não existe, usa a gravação antiga ("nome_v1"), se houver:
-- assim nenhuma fala que tem gravação fica muda.
local function itemTocavel(nome: string): any
	local it = AudioMapa.itens[nome]
	if it and idDe(it.arquivo) > 0 and estadoArquivo[it.arquivo] ~= "falhou" then
		return it
	end
	local antigo = AudioMapa.itens[nome .. "_v1"]
	if antigo and idDe(antigo.arquivo) > 0 and estadoArquivo[antigo.arquivo] ~= "falhou" then
		return antigo
	end
	return nil
end
Som.itemTocavel = itemTocavel

-- true se o arquivo do item tem ID e não está marcado como falho (ou se há gravação da biblioteca)
function Som.disponivel(nome: string): boolean
	if Som.temGravacao(nome) then
		return true
	end
	return itemTocavel(nome) ~= nil
end

-- true só quando o som já carregou de verdade
function Som.pronto(nome: string): boolean
	for _, v in variantesVivas(nome) do
		if estadoLib[v.id] == "pronto" then
			return true
		end
	end
	local it = itemTocavel(nome)
	return it ~= nil and estadoArquivo[it.arquivo] == "pronto"
end

function Som.duracao(nome: string): number?
	local it = itemTocavel(nome) or AudioMapa.itens[nome] or AudioMapa.itens[nome .. "_v1"]
	if it then
		return it.dur
	end
	local b = Biblioteca.sons[nome]
	return b and b.variantes[1] and b.variantes[1].dur or nil
end

-- Resumo: "pronto", "carregando", "parcial", "indisponivel", "sem_audio"
function Som.estado(): (string, { [string]: string })
	local total, prontos, falhas, carregando = 0, 0, 0, 0
	for _, arquivo in AudioMapa.arquivos do
		local e = estadoArquivo[arquivo] or "carregando"
		if e ~= "sem_id" then
			total += 1
			if e == "pronto" then
				prontos += 1
			elseif e == "falhou" then
				falhas += 1
			else
				carregando += 1
			end
		end
	end
	local resumo
	if total == 0 then
		resumo = "sem_audio"
	elseif falhas == 0 and carregando == 0 then
		resumo = "pronto"
	elseif falhas == 0 then
		resumo = "carregando"
	elseif prontos == 0 and carregando == 0 then
		resumo = "indisponivel"
	else
		resumo = "parcial"
	end
	return resumo, table.clone(estadoArquivo)
end

-- AJUSTE-11: estado de um arquivo ("pronto", "carregando", "falhou", "sem_id")
function Som.estadoDoArquivo(arquivo: string): string
	if idDe(arquivo) <= 0 then
		return "sem_id"
	end
	return estadoArquivo[arquivo] or "carregando"
end

-- Frase curta para a tela de Configurações (e se está tudo bem)
function Som.textoEstado(): (string, boolean)
	local resumo, mapa = Som.estado()
	if resumo == "pronto" then
		return "Sons: funcionando.", true
	elseif resumo == "carregando" then
		return "Sons: carregando...", false
	elseif resumo == "sem_audio" then
		return "Sons: nenhum áudio instalado.", false
	end
	local falhos = {}
	for arquivo, e in mapa do
		if e == "falhou" then
			table.insert(falhos, NOMES[arquivo] or arquivo)
		end
	end
	table.sort(falhos)
	local lista = table.concat(falhos, ", ")
	if estadoControle == "pronto" then
		return "Sons bloqueados pelo Roblox: " .. lista .. ". Falta liberar a permissão do jogo (o instalador mostra como).", false
	elseif estadoControle == "falhou" then
		return "Sons não carregaram (" .. lista .. "). Internet fraca? Saia e entre de novo.", false
	end
	return "Sons: conferindo (" .. lista .. ")...", false
end

function Som.aoMudarEstado(fn: () -> ())
	table.insert(ouvintesEstado, fn)
end

local function avisarEstado()
	for _, fn in ouvintesEstado do
		task.spawn(fn)
	end
end

local function mudarEstado(arquivo: string, novo: string)
	if estadoArquivo[arquivo] ~= novo then
		estadoArquivo[arquivo] = novo
		avisarEstado()
	end
end

local function criarModelo(nome: string, soundId: string): Sound
	local s = Instance.new("Sound")
	s.Name = "OI3_Modelo_" .. nome
	s.SoundId = soundId
	s.Volume = 0
	s.Parent = SoundService
	return s
end

-- espera o som carregar (sondando, não depende só do evento Loaded)
local function esperarCarregar(s: Sound, limite: number): boolean
	local t0 = os.clock()
	while not s.IsLoaded and os.clock() - t0 < limite and s.Parent do
		task.wait(0.25)
	end
	return s.IsLoaded and s.TimeLength > 0
end

-- vigia um arquivo até carregar; se falhar, tenta de novo algumas vezes (o Roblox pode liberar depois)
local function vigiarArquivo(arquivo: string, id: number)
	task.spawn(function()
		for tentativa = 1, 6 do
			local antigo = modelos[arquivo]
			if antigo then
				antigo:Destroy()
			end
			local s = criarModelo(arquivo, "rbxassetid://" .. id)
			modelos[arquivo] = s
			pcall(function()
				ContentProvider:PreloadAsync({ s })
			end)
			if esperarCarregar(s, if tentativa == 1 then 20 else 25) then
				mudarEstado(arquivo, "pronto")
				return
			end
			mudarEstado(arquivo, "falhou")
			if tentativa == 1 then
				warn(string.format("[OI3] o áudio '%s' (%s) não carregou. Pode faltar liberar a permissão do jogo para ele.", arquivo, s.SoundId))
			end
			-- dá mais um tempo ao mesmo som antes de recriar
			if esperarCarregar(s, 15 + 10 * tentativa) then
				mudarEstado(arquivo, "pronto")
				return
			end
		end
	end)
end

-- AJUSTE-9: carrega as gravações da biblioteca em lotes (em segundo plano, sem travar o jogo)
function Som.carregarBiblioteca()
	local ids: { number } = {}
	local vistos = {}
	for _, b in Biblioteca.sons do
		for _, v in b.variantes do
			if not vistos[v.id] then
				vistos[v.id] = true
				table.insert(ids, v.id)
			end
		end
	end
	table.sort(ids)
	for _, id in ids do
		if not modelosLib[id] then
			modelosLib[id] = criarModelo("Lib" .. id, "rbxassetid://" .. id)
			estadoLib[id] = "carregando"
		end
	end
	task.spawn(function()
		for i = 1, #ids, 8 do
			local lote = {}
			for k = i, math.min(i + 7, #ids) do
				table.insert(lote, modelosLib[ids[k]])
			end
			pcall(function()
				ContentProvider:PreloadAsync(lote)
			end)
			for _, s in lote do
				local id = tonumber(string.match(s.SoundId, "%d+")) :: number
				if s.IsLoaded and s.TimeLength > 0 then
					estadoLib[id] = "pronto"
				end
			end
		end
		-- quem não carregou ganha mais um tempo; depois disso o som antigo toca no lugar
		local t0 = os.clock()
		while os.clock() - t0 < 30 do
			local falta = false
			for _, id in ids do
				local s = modelosLib[id]
				if estadoLib[id] == "carregando" then
					if s.IsLoaded and s.TimeLength > 0 then
						estadoLib[id] = "pronto"
					else
						falta = true
					end
				end
			end
			if not falta then
				break
			end
			task.wait(1)
		end
		local falhos = 0
		for _, id in ids do
			if estadoLib[id] == "carregando" then
				estadoLib[id] = "falhou"
				falhos += 1
			end
		end
		if falhos > 0 then
			warn(string.format("[OI3] %d sons gravados da biblioteca não carregaram; usando os sons antigos no lugar.", falhos))
		end
	end)
end

-- quantos sons da biblioteca carregaram (para o teste e para a tela de Configurações)
function Som.estadoBiblioteca(): (number, number, number)
	local prontos, falhos, total = 0, 0, 0
	for _, e in estadoLib do
		total += 1
		if e == "pronto" then
			prontos += 1
		elseif e == "falhou" then
			falhos += 1
		end
	end
	return prontos, falhos, total
end

local function vigiarControle()
	task.spawn(function()
		for _ = 1, 2 do
			local s = criarModelo("Controle", CONTROLE_ID)
			pcall(function()
				ContentProvider:PreloadAsync({ s })
			end)
			local ok = esperarCarregar(s, 20)
			s:Destroy()
			if ok then
				estadoControle = "pronto"
				avisarEstado()
				return
			end
		end
		estadoControle = "falhou"
		avisarEstado()
	end)
end

function Som.iniciar(volumes: { musica: number, efeitos: number, vozes: number })
	if iniciado then
		return
	end
	iniciado = true
	for _, nome in { "Musica", "Efeitos", "Vozes" } do
		local g = Instance.new("SoundGroup")
		g.Name = "OI3_" .. nome
		g.Volume = 1
		g.Parent = SoundService
		grupos[nome] = g
	end
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 1.1
	reverb.Density = 0.8
	reverb.Diffusion = 0.85
	reverb.DryLevel = 0
	reverb.WetLevel = -16
	reverb.Parent = grupos.Vozes
	Som.volumes(volumes)

	for _, arquivo in AudioMapa.arquivos do
		local id = idDe(arquivo)
		if id > 0 then
			estadoArquivo[arquivo] = "carregando"
			vigiarArquivo(arquivo, id)
		else
			estadoArquivo[arquivo] = "sem_id"
		end
	end
	vigiarControle()
	Som.carregarBiblioteca()

	-- vigia: garante o trecho certo mesmo se o PlaybackRegion falhar
	RunService.Heartbeat:Connect(function()
		for s, r in ativos do
			if not s.Parent then
				ativos[s] = nil
			elseif s.IsPlaying and s.IsLoaded then
				local t = s.TimePosition
				if t < r.inicio - 0.08 then
					s.TimePosition = r.inicio
				elseif t >= r.fim then
					if r.loop then
						s.TimePosition = r.inicio
					else
						s:Stop()
						ativos[s] = nil
						s:Destroy()
					end
				end
			end
		end
	end)
end

function Som.volumes(v: { musica: number, efeitos: number, vozes: number })
	if grupos.Musica then
		grupos.Musica.Volume = math.clamp(v.musica or 0.7, 0, 1)
		grupos.Efeitos.Volume = math.clamp(v.efeitos or 0.9, 0, 1)
		grupos.Vozes.Volume = math.clamp(v.vozes or 1, 0, 1) * 1.15
	end
end

export type Opcoes = {
	grupo: string?,
	volume: number?,
	velocidade: number?,
	loop: boolean?,
	pai: Instance?,
	alcance: number?,
	minimo: number?,
	variante: number?,
}

local tocarCaixinha: (Opcoes?) -> Sound?

-- Toca um item. Retorna o Sound (ou nil se não houver áudio).
-- AJUSTE-9: se houver gravação da biblioteca com esse nome, ela toca (uma variante sorteada);
-- senão toca o trecho do sprite antigo.
function Som.tocar(nome: string, opcoes: Opcoes?): Sound?
	if nome == "caixinha" and Som.temGravacao("caixinha_nota") then
		return tocarCaixinha(opcoes)
	end
	local o = opcoes or {}
	local modelo: Sound?
	local it: any = nil
	local ganho = 1
	local vivas = variantesVivas(nome)
	if #vivas > 0 then
		local b = Biblioteca.sons[nome]
		local v = vivas[if o.variante then math.clamp(o.variante, 1, #vivas) else math.random(1, #vivas)]
		modelo = modelosLib[v.id]
		it = { inicio = v.inicio, dur = v.dur, loop = b.loop }
		ganho = v.ganho or 1
	else
		it = itemTocavel(nome)
		if not it then
			return nil
		end
		modelo = modelos[it.arquivo]
		if not modelo then
			return nil
		end
	end
	if not modelo then
		return nil
	end
	local s = modelo:Clone()
	s.Name = "OI3_" .. nome
	s.Volume = math.clamp((o.volume or 1) * ganho, 0, 10)
	s:SetAttribute("Ganho", ganho)
	s.PlaybackSpeed = o.velocidade or 1
	s.SoundGroup = grupos[o.grupo or "Efeitos"]
	local loop = o.loop or it.loop == true
	s.Looped = loop
	if o.pai then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = o.minimo or 6
		s.RollOffMaxDistance = o.alcance or 70
		s.Parent = o.pai
	else
		s.Parent = SoundService
	end
	local inicio, fim = it.inicio, it.inicio + it.dur
	local function comecar()
		if not s.Parent then
			return
		end
		pcall(function()
			s.PlaybackRegionsEnabled = true
			s.PlaybackRegion = NumberRange.new(inicio, fim)
			if loop then
				s.LoopRegion = NumberRange.new(inicio, fim)
			end
		end)
		s.TimePosition = inicio
		ativos[s] = { inicio = inicio, fim = fim, loop = loop }
		s:Play()
		if s.TimePosition < inicio - 0.05 then
			s.TimePosition = inicio
		end
		if not loop then
			task.delay(it.dur / math.max(o.velocidade or 1, 0.1) + 1.5, function()
				if s.Parent then
					ativos[s] = nil
					s:Destroy()
				end
			end)
		end
	end
	if s.IsLoaded then
		comecar()
	else
		-- espera carregar sondando (o evento Loaded às vezes não chega para clones)
		task.spawn(function()
			local limite = if loop then 120 else 12
			if esperarCarregar(s, limite) then
				comecar()
			elseif s.Parent and not s.IsPlaying then
				s:Destroy()
			end
		end)
	end
	return s
end

-- "Parabéns pra você" (semitons acima do Ré5 e duração em tempos) tocado com UMA nota gravada de uma
-- caixinha de música de verdade (PSE "Music Box Single Notes"), afinada nota por nota pela velocidade.
local PARABENS = {
	{ 0, 0.75 }, { 0, 0.25 }, { 2, 1 }, { 0, 1 }, { 5, 1 }, { 4, 2 },
	{ 0, 0.75 }, { 0, 0.25 }, { 2, 1 }, { 0, 1 }, { 7, 1 }, { 5, 2 },
	{ 0, 0.75 }, { 0, 0.25 }, { 12, 1 }, { 9, 1 }, { 5, 1 }, { 4, 1 }, { 2, 2 },
	{ 10, 0.75 }, { 10, 0.25 }, { 9, 1 }, { 5, 1 }, { 7, 1 }, { 5, 3 },
}
local RE5_HZ = 587.33

tocarCaixinha = function(opcoes: Opcoes?): Sound?
	local o = opcoes or {}
	-- "alça": um Sound mudo que representa a caixinha (quem chamou pode mudar o Volume ou destruir)
	local alca = Instance.new("Sound")
	alca.Name = "OI3_caixinha"
	alca.Volume = o.volume or 1
	alca.Parent = o.pai or SoundService
	local loop = o.loop == true
	local base = Biblioteca.caixinhaHz or 829
	task.spawn(function()
		local rodada = 0
		repeat
			rodada += 1
			-- a cada volta a caixinha fica um pouco mais lenta (a corda acabando)
			local tempo = 0.36 * (1 + math.min(rodada - 1, 6) * 0.06)
			for i, nota in PARABENS do
				if not alca.Parent then
					return
				end
				local hz = RE5_HZ * 2 ^ (nota[1] / 12)
				local vel = (hz / base) * (1 + (math.random() - 0.5) * 0.006)
				if i == #PARABENS and rodada > 2 then
					vel *= 0.985 -- a última nota sai um pouco desafinada
				end
				Som.tocar("caixinha_nota", {
					volume = alca.Volume * (if nota[2] >= 1 then 1 else 0.8),
					velocidade = vel,
					pai = if o.pai then o.pai else nil,
					alcance = o.alcance,
					minimo = o.minimo,
					grupo = o.grupo,
				})
				task.wait(nota[2] * tempo * (1 + (math.random() - 0.5) * 0.05))
			end
			task.wait(1.4)
		until not loop or not alca.Parent
		if alca.Parent then
			alca:Destroy()
		end
	end)
	return alca
end

-- Toca uma sequência curta para o jogador conferir se o som está saindo
function Som.testar()
	Som.tocar("clique", { volume = 1 })
	task.delay(0.35, function()
		if not Som.tocar("lanterna_liga", { volume = 1 }) then
			Som.tocar("whoosh", { volume = 0.8 })
		end
	end)
	task.delay(0.9, function()
		Som.tocar("NI_1", { grupo = "Vozes", volume = 1 })
	end)
end

-- Volume de verdade de um som já tocando (as gravações da biblioteca têm um ganho próprio)
function Som.volumeReal(s: Sound, volume: number): number
	local g = s:GetAttribute("Ganho")
	return math.clamp(volume * (if type(g) == "number" then g else 1), 0, 10)
end

-- Muda o volume de um som já tocando (respeitando o ganho da gravação)
function Som.mudarVolume(s: Sound?, volume: number, fade: number?)
	if not s or not s.Parent then
		return
	end
	local alvo = Som.volumeReal(s, volume)
	if fade and fade > 0 then
		TweenService:Create(s, TweenInfo.new(fade), { Volume = alvo }):Play()
	else
		s.Volume = alvo
	end
end

-- Ambientes 2D em loop com fade
function Som.ambiente(nome: string, volume: number, fade: number?)
	local atual = ambientes[nome]
	local t = fade or 1.5
	if volume <= 0 then
		if atual then
			ambientes[nome] = nil
			TweenService:Create(atual, TweenInfo.new(t), { Volume = 0 }):Play()
			task.delay(t + 0.1, function()
				ativos[atual] = nil
				atual:Destroy()
			end)
		end
		return
	end
	if atual and atual.Parent then
		TweenService:Create(atual, TweenInfo.new(t), { Volume = Som.volumeReal(atual, volume) }):Play()
		return
	end
	local s = Som.tocar(nome, { grupo = "Musica", volume = 0, loop = true })
	if s then
		ambientes[nome] = s
		TweenService:Create(s, TweenInfo.new(t), { Volume = Som.volumeReal(s, volume) }):Play()
	end
end

function Som.pararAmbientes(fade: number?)
	for nome in ambientes do
		Som.ambiente(nome, 0, fade)
	end
end

return Som
