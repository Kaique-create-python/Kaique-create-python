-- OI3 :: sons (cliente). Toca trechos de arquivos "sprite" (vários sons num áudio só).
-- AJUSTE-4:
--  * cada arquivo é vigiado até carregar (sem prazo curto) e ganha novas tentativas se falhar;
--    quando um arquivo fica pronto mais tarde, o jogo é avisado e liga a música/ambiente sozinho;
--  * um som PÚBLICO do próprio Roblox serve de "controle": se ele carrega e o nosso não,
--    o áudio está bloqueado (falta liberar a permissão do jogo) e a tela de Configurações diz isso;
--  * o trecho do sprite só é marcado depois que o áudio carregou (antes podia ficar mudo).

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local OI3 = script.Parent.Parent
local Recursos = require(OI3.Recursos)
local AudioMapa = require(OI3.AudioMapa)

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
}

local grupos: { [string]: SoundGroup } = {}
local ambientes: { [string]: Sound } = {}
local modelos: { [string]: Sound } = {} -- um Sound por arquivo (o modelo que é clonado)
local estadoArquivo: { [string]: string } = {} -- "carregando" | "pronto" | "falhou" | "sem_id"
local estadoControle = "carregando" -- "carregando" | "pronto" | "falhou"
local ativos: { [Sound]: { inicio: number, fim: number, loop: boolean } } = {}
local ouvintesEstado: { () -> () } = {}
local iniciado = false

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

-- true se o arquivo do item tem ID e não está marcado como falho
function Som.disponivel(nome: string): boolean
	local it = AudioMapa.itens[nome]
	if not it or idDe(it.arquivo) <= 0 then
		return false
	end
	return estadoArquivo[it.arquivo] ~= "falhou"
end

-- true só quando o arquivo do item já carregou de verdade
function Som.pronto(nome: string): boolean
	local it = AudioMapa.itens[nome]
	return it ~= nil and estadoArquivo[it.arquivo] == "pronto"
end

function Som.duracao(nome: string): number?
	local it = AudioMapa.itens[nome]
	return it and it.dur or nil
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
}

-- Toca um item. Retorna o Sound (ou nil se não houver áudio).
function Som.tocar(nome: string, opcoes: Opcoes?): Sound?
	local it = AudioMapa.itens[nome]
	if not it then
		return nil
	end
	local modelo = modelos[it.arquivo]
	if not modelo or estadoArquivo[it.arquivo] == "falhou" then
		return nil
	end
	local o = opcoes or {}
	local s = modelo:Clone()
	s.Name = "OI3_" .. nome
	s.Volume = o.volume or 1
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
		TweenService:Create(atual, TweenInfo.new(t), { Volume = volume }):Play()
		return
	end
	local s = Som.tocar(nome, { grupo = "Musica", volume = 0, loop = true })
	if s then
		ambientes[nome] = s
		TweenService:Create(s, TweenInfo.new(t), { Volume = volume }):Play()
	end
end

function Som.pararAmbientes(fade: number?)
	for nome in ambientes do
		Som.ambiente(nome, 0, fade)
	end
end

return Som
