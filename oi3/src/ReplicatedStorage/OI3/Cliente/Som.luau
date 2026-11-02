-- OI3 :: sons (cliente). Toca trechos de arquivos "sprite" (vários sons num áudio só).
-- AJUSTE-3: cada arquivo é pré-carregado e o som só começa DEPOIS de carregado
-- (antes, o trecho era marcado com o áudio ainda vazio e podia ficar mudo).
-- Se um áudio não carrega (ainda em moderação no Roblox, por exemplo), o jogo segue com legendas.

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local OI3 = script.Parent.Parent
local Recursos = require(OI3.Recursos)
local AudioMapa = require(OI3.AudioMapa)

local Som = {}

local grupos: { [string]: SoundGroup } = {}
local ambientes: { [string]: Sound } = {}
local modelos: { [string]: Sound } = {} -- um Sound por arquivo (já carregado)
local estadoArquivo: { [string]: string } = {} -- "carregando" | "pronto" | "falhou" | "sem_id"
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

-- true se o arquivo do item tem ID e não falhou ao carregar
function Som.disponivel(nome: string): boolean
	local it = AudioMapa.itens[nome]
	if not it or idDe(it.arquivo) <= 0 then
		return false
	end
	return estadoArquivo[it.arquivo] ~= "falhou"
end

function Som.duracao(nome: string): number?
	local it = AudioMapa.itens[nome]
	return it and it.dur or nil
end

-- Resumo para mostrar ao jogador: "pronto", "carregando", "parcial", "indisponivel", "sem_audio"
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
	elseif carregando > 0 then
		resumo = "carregando"
	elseif falhas == 0 then
		resumo = "pronto"
	elseif prontos == 0 then
		resumo = "indisponivel"
	else
		resumo = "parcial"
	end
	return resumo, table.clone(estadoArquivo)
end

function Som.aoMudarEstado(fn: () -> ())
	table.insert(ouvintesEstado, fn)
end

local function avisarEstado()
	for _, fn in ouvintesEstado do
		task.spawn(fn)
	end
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

	-- modelos (um por arquivo) + pré-carregamento com relatório
	local lista = {}
	for _, arquivo in AudioMapa.arquivos do
		local id = idDe(arquivo)
		if id > 0 then
			local s = Instance.new("Sound")
			s.Name = "OI3_Modelo_" .. arquivo
			s.SoundId = "rbxassetid://" .. id
			s.Volume = 0
			s.Parent = SoundService
			modelos[arquivo] = s
			estadoArquivo[arquivo] = "carregando"
			table.insert(lista, s)
		else
			estadoArquivo[arquivo] = "sem_id"
		end
	end
	task.spawn(function()
		if #lista > 0 then
			pcall(function()
				ContentProvider:PreloadAsync(lista)
			end)
		end
		-- confere cada arquivo (espera até 12 s pelo carregamento)
		for arquivo, s in modelos do
			task.spawn(function()
				local t0 = os.clock()
				while not s.IsLoaded and os.clock() - t0 < 12 do
					task.wait(0.25)
				end
				if s.IsLoaded and s.TimeLength > 0 then
					estadoArquivo[arquivo] = "pronto"
				else
					estadoArquivo[arquivo] = "falhou"
					warn(string.format("[OI3] o áudio '%s' (%s) não carregou. Ele pode estar em moderação no Roblox ou sem permissão.", arquivo, s.SoundId))
				end
				avisarEstado()
			end)
		end
	end)

	-- vigia: garante o trecho certo mesmo se o PlaybackRegion falhar
	RunService.Heartbeat:Connect(function()
		for s, r in ativos do
			if not s.Parent then
				ativos[s] = nil
			elseif s.IsPlaying then
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
		s.RollOffMinDistance = 6
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
		local con
		con = s.Loaded:Connect(function()
			con:Disconnect()
			comecar()
		end)
		task.delay(10, function()
			if con.Connected then
				con:Disconnect()
				if s.Parent and not s.IsPlaying then
					s:Destroy()
				end
			end
		end)
	end
	return s
end

-- Ambientes em loop com fade
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
