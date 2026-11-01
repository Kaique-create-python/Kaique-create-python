-- OI3 :: sons (cliente). Toca trechos de arquivos "sprite" (vários sons num áudio só).
-- Se um áudio ainda não existe/foi moderado (id 0), nada toca e o jogo segue normal.

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local OI3 = script.Parent.Parent
local Recursos = require(OI3.Recursos)
local AudioMapa = require(OI3.AudioMapa)

local Som = {}

local grupos: { [string]: SoundGroup } = {}
local ambientes: { [string]: Sound } = {}
local iniciado = false

local function idDe(arquivo: string): number
	local audio = Recursos.audio
	if type(audio) ~= "table" then
		return 0
	end
	local id = tonumber(audio[arquivo]) or 0
	return id
end

function Som.item(nome: string)
	return AudioMapa.itens[nome]
end

function Som.disponivel(nome: string): boolean
	local it = AudioMapa.itens[nome]
	return it ~= nil and idDe(it.arquivo) > 0
end

function Som.duracao(nome: string): number?
	local it = AudioMapa.itens[nome]
	return it and it.dur or nil
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
	-- pré-carrega os arquivos (sem travar o jogo)
	task.spawn(function()
		local lista = {}
		for _, arquivo in AudioMapa.arquivos do
			local id = idDe(arquivo)
			if id > 0 then
				local s = Instance.new("Sound")
				s.Name = "Pre_" .. arquivo
				s.SoundId = "rbxassetid://" .. id
				s.Volume = 0
				s.Parent = SoundService
				table.insert(lista, s)
			end
		end
		if #lista > 0 then
			pcall(function()
				ContentProvider:PreloadAsync(lista)
			end)
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
	local id = idDe(it.arquivo)
	if id <= 0 then
		return nil
	end
	local o = opcoes or {}
	local s = Instance.new("Sound")
	s.Name = "OI3_" .. nome
	s.SoundId = "rbxassetid://" .. id
	s.Volume = o.volume or 1
	s.PlaybackSpeed = o.velocidade or 1
	s.SoundGroup = grupos[o.grupo or "Efeitos"]
	local loop = o.loop or it.loop == true
	local okRegiao = pcall(function()
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(it.inicio, it.inicio + it.dur)
		if loop then
			s.LoopRegion = NumberRange.new(it.inicio, it.inicio + it.dur)
		end
	end)
	s.Looped = loop
	if not okRegiao then
		s.TimePosition = it.inicio
	end
	if o.pai then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 6
		s.RollOffMaxDistance = o.alcance or 70
		s.Parent = o.pai
	else
		s.Parent = SoundService
	end
	s:Play()
	if not loop then
		local tempo = it.dur / (o.velocidade or 1) + 0.4
		if not okRegiao then
			task.delay(it.dur / (o.velocidade or 1), function()
				if s.Parent then
					s:Stop()
				end
			end)
		end
		Debris:AddItem(s, tempo)
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
			local tw = TweenService:Create(atual, TweenInfo.new(t), { Volume = 0 })
			tw:Play()
			task.delay(t + 0.1, function()
				atual:Destroy()
			end)
		end
		return
	end
	if atual then
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
