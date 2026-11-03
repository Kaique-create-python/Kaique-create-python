-- BIZARRE BATTLEGROUNDS :: sons no celular (efeitos 3D, interface e música)

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local BB = script.Parent.Parent
local Sons = require(BB:WaitForChild("Sons"))
local Config = require(BB:WaitForChild("Config"))

local Som = {}

local grupoEfeitos: SoundGroup
local grupoMusica: SoundGroup
local pastaSons: Folder
local musicaAtual: Sound? = nil
local nomeMusica = ""
local contagem: { [string]: number } = {}
local rng = Random.new()
local volMusica = Config.VOLUME_MUSICA

function Som.iniciar()
	grupoEfeitos = Instance.new("SoundGroup")
	grupoEfeitos.Name = "BB_Efeitos"
	grupoEfeitos.Volume = Config.VOLUME_EFEITOS
	grupoEfeitos.Parent = SoundService
	grupoMusica = Instance.new("SoundGroup")
	grupoMusica.Name = "BB_Musica"
	grupoMusica.Volume = Config.VOLUME_MUSICA
	grupoMusica.Parent = SoundService
	pastaSons = Instance.new("Folder")
	pastaSons.Name = "BB_Sons"
	pastaSons.Parent = workspace
	-- pré-carrega um de cada (sem travar o jogo)
	task.spawn(function()
		local lista = {}
		for _, s in Sons.LISTA do
			local snd = Instance.new("Sound")
			snd.SoundId = "rbxassetid://" .. s.ids[1]
			table.insert(lista, snd)
		end
		pcall(function()
			ContentProvider:PreloadAsync(lista)
		end)
	end)
end

local function escolher(nome: string): (any, number?)
	local s = Sons.LISTA[nome]
	if not s then
		return nil, nil
	end
	return s, s.ids[rng:NextInteger(1, #s.ids)]
end

-- toca um som (pos = no mundo; sem pos = na interface). Limita sons iguais ao mesmo tempo.
function Som.tocar(nome: string?, pos: Vector3?, opcoes: any?): Sound?
	if not nome then
		return nil
	end
	local s, id = escolher(nome)
	if not s or not id then
		return nil
	end
	local o = opcoes or {}
	local ativos = contagem[nome] or 0
	if ativos >= (o.max or 4) then
		return nil
	end
	contagem[nome] = ativos + 1
	local snd = Instance.new("Sound")
	snd.SoundId = "rbxassetid://" .. id
	snd.Volume = (s.vol or 1) * (o.vol or 1)
	snd.PlaybackSpeed = rng:NextNumber(s.vel[1], s.vel[2]) * (o.vel or 1)
	snd.SoundGroup = grupoEfeitos
	snd.RollOffMaxDistance = o.alcance or 260
	snd.RollOffMinDistance = o.perto or 14
	local suporte: Instance = SoundService
	if pos then
		local a = Instance.new("Attachment")
		a.WorldPosition = pos
		a.Parent = workspace.Terrain
		snd.Parent = a
		suporte = a
	else
		snd.Parent = pastaSons
	end
	snd:Play()
	local duracao = 6
	task.delay(duracao, function()
		contagem[nome] = math.max(0, (contagem[nome] or 1) - 1)
		if suporte ~= SoundService then
			suporte:Destroy()
		else
			snd:Destroy()
		end
	end)
	return snd
end

-- som preso numa peça (acompanha quem se mexe)
function Som.naPeca(nome: string?, peca: BasePart?, opcoes: any?): Sound?
	if not nome or not peca then
		return nil
	end
	local s, id = escolher(nome)
	if not s or not id then
		return nil
	end
	local o = opcoes or {}
	local snd = Instance.new("Sound")
	snd.SoundId = "rbxassetid://" .. id
	snd.Volume = (s.vol or 1) * (o.vol or 1)
	snd.PlaybackSpeed = rng:NextNumber(s.vel[1], s.vel[2]) * (o.vel or 1)
	snd.SoundGroup = grupoEfeitos
	snd.Looped = o.loop == true
	snd.RollOffMaxDistance = o.alcance or 220
	snd.Parent = peca
	snd:Play()
	if not snd.Looped then
		task.delay(6, function()
			snd:Destroy()
		end)
	end
	return snd
end

function Som.musica(nome: string)
	if nome == nomeMusica then
		return
	end
	nomeMusica = nome
	local grupo = Sons.MUSICAS[nome]
	local id = if type(grupo) == "table" then grupo[rng:NextInteger(1, #grupo)] else grupo
	local antiga = musicaAtual
	if antiga then
		TweenService:Create(antiga, TweenInfo.new(1.2), { Volume = 0 }):Play()
		task.delay(1.3, function()
			antiga:Destroy()
		end)
	end
	if not id then
		musicaAtual = nil
		return
	end
	local snd = Instance.new("Sound")
	snd.Name = "Musica"
	snd.SoundId = "rbxassetid://" .. id
	snd.Looped = true
	snd.Volume = 0
	snd.SoundGroup = grupoMusica
	snd.Parent = pastaSons
	snd:Play()
	TweenService:Create(snd, TweenInfo.new(1.5), { Volume = 1 }):Play()
	musicaAtual = snd
	-- na luta, troca de música no fim de cada faixa
	if nome == "luta" and type(grupo) == "table" then
		snd.Looped = false
		snd.Ended:Connect(function()
			if nomeMusica == "luta" and musicaAtual == snd then
				nomeMusica = ""
				Som.musica("luta")
			end
		end)
	end
end

function Som.volumeMusica(v: number)
	volMusica = math.clamp(v, 0, 1)
	if grupoMusica then
		grupoMusica.Volume = volMusica
	end
end

function Som.volumeEfeitos(v: number)
	if grupoEfeitos then
		grupoEfeitos.Volume = math.clamp(v, 0, 1.2)
	end
end

function Som.abafar(sim: boolean)
	-- durante o tempo parado a música fica abafada
	if grupoMusica then
		TweenService:Create(grupoMusica, TweenInfo.new(0.4), { Volume = if sim then volMusica * 0.25 else volMusica }):Play()
	end
end

return Som
