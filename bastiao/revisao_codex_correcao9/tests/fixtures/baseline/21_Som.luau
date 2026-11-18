--!strict
-- PROJETO BASTIÃO :: som do jogo (cliente)
-- Tudo vem de poucos arquivos ("sprites"): cada voz/efeito é um trecho tocado com PlaybackRegion.
--   * vozes na língua do jogador: Pavel em 3D (sai da cabeça dele), rádio/gravação com chiado e
--     clique de PTT, alto-falante da base com eco;
--   * eco por lugar: corredor abobadado, sala, galpão do gerador (reverb no grupo de som);
--   * ambiente do bunker, ventilador no túnel, motor lá fora (para quando o acesso fecha);
--   * alarme saindo de cada giroflex que está carregado (streaming);
--   * passos em concreto ou metal para jogadores e para o Pavel (o passo padrão do Roblox
--     é silenciado só no cliente).
-- Sem ID (instalação sem áudio ou som ainda em moderação), nada toca e as legendas seguem.

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Som = {}

-- efeitos e loops ficam no mesmo arquivo de som (menos envios para o Roblox); vozes, um por língua
local EFEITOS_SPRITE = "efeitos"

-- efeitos: volume, alcance 3D (raio) e se vão pelo alto-falante (pa) ou "de longe" (2D com eco)
local EFEITOS: { [string]: { vol: number, raio: number?, pa: boolean?, longe: boolean? } } = {
	estatica = { vol = 0.5 },
	squelch = { vol = 0.55 },
	toques_longe = { vol = 0.85, longe = true },
	toques_perto = { vol = 1.0, raio = 70 },
	inspiracao = { vol = 1.0, raio = 55 },
	vapor = { vol = 0.75, raio = 45 },
	impacto_porta = { vol = 1.0, raio = 140 },
	portas = { vol = 0.9, longe = true },
	passos_monstro = { vol = 0.9, longe = true },
	trava = { vol = 0.95, raio = 45 },
	porta_desliza = { vol = 0.8, raio = 55 },
	alavanca = { vol = 0.85, raio = 35 },
	modulo_encaixe = { vol = 0.85, raio = 35 },
	modulo_pegar = { vol = 0.75, raio = 30 },
	terminal_bip = { vol = 0.5, raio = 28 },
	terminal_liga = { vol = 0.6, raio = 28 },
	chime_pa = { vol = 0.8, pa = true },
}
Som.EFEITOS = EFEITOS
-- legenda do capítulo -> efeito do sprite (o alarme é o loop ligado pelo atributo)
Som.DA_LEGENDA = {
	radio_chiado = "estatica",
	tres_toques = "toques_longe",
	inspiracao = "inspiracao",
	pressurizacao = "vapor",
	impacto_porta = "impacto_porta",
	portas = "portas",
	passos_longe = "passos_monstro",
	trava = "trava",
	tres_toques_parede = "toques_perto",
}

-- salas 48x44 do mapa (centros medidos) e o galpão do gerador: o resto é corredor abobadado
local SALAS = {}
for _, x in { -88, 88 } do
	for _, z in { -140, -220, -320, -400 } do
		table.insert(SALAS, { x = x, z = z, mx = 24, mz = 22 })
	end
end
local GALPAO = { x = 0, z = -535, mx = 36, mz = 25 }
local ECO = {
	sala = { DecayTime = 1.1, Density = 0.9, Diffusion = 0.8, DryLevel = 0, WetLevel = -13 },
	corredor = { DecayTime = 2.3, Density = 1, Diffusion = 1, DryLevel = 0, WetLevel = -7 },
	galpao = { DecayTime = 3.8, Density = 1, Diffusion = 1, DryLevel = -1, WetLevel = -4 },
}
function Som.zona(p: Vector3): string
	if math.abs(p.X - GALPAO.x) <= GALPAO.mx and math.abs(p.Z - GALPAO.z) <= GALPAO.mz then
		return "galpao"
	end
	for _, s in SALAS do
		if math.abs(p.X - s.x) <= s.mx and math.abs(p.Z - s.z) <= s.mz then
			return "sala"
		end
	end
	return "corredor"
end

local METAIS = {
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.CorrodedMetal] = true,
	[Enum.Material.Foil] = true,
}

export type Opcoes = {
	audio: any,
	textos: any,
	idioma: () -> string,
	alarme: () -> boolean,
	acessoBloqueado: () -> boolean,
}

function Som.iniciar(op: Opcoes): any
	local audio, textos = op.audio, op.textos
	local api = {} :: any
	local camera = workspace.CurrentCamera
	local conexoes: { RBXScriptConnection } = {}
	local criados: { Instance } = {}

	local function id(nome: string): number
		local v = audio.ids and audio.ids[nome]
		return if type(v) == "number" then v else 0
	end
	local function temSom(nome: string): boolean
		return id(nome) > 0
	end

	-- ===== grupos de som (só neste cliente) =====
	local function grupo(nome: string, volume: number): SoundGroup
		local g = SoundService:FindFirstChild(nome) :: SoundGroup?
		if g then
			g:Destroy()
		end
		local novo = Instance.new("SoundGroup")
		novo.Name = nome
		novo.Volume = volume
		novo.Parent = SoundService
		table.insert(criados, novo)
		return novo
	end
	local gVozes = grupo("BastiaoVozes", 1)
	local gRadio = grupo("BastiaoRadio", 1)
	local gPA = grupo("BastiaoPA", 1)
	local gEfeitos = grupo("BastiaoEfeitos", 1)
	local gAmbiente = grupo("BastiaoAmbiente", 0.8)
	-- "de longe": sem agudos e com cauda longa, como se viesse do fundo do túnel
	local gLonge = grupo("BastiaoLonge", 1)
	local eqLonge = Instance.new("EqualizerSoundEffect")
	eqLonge.HighGain = -16
	eqLonge.MidGain = -5
	eqLonge.LowGain = 2
	eqLonge.Parent = gLonge
	local caudaLonge = Instance.new("ReverbSoundEffect")
	caudaLonge.DecayTime = 4.2
	caudaLonge.Density = 1
	caudaLonge.Diffusion = 1
	caudaLonge.DryLevel = -2
	caudaLonge.WetLevel = -2
	caudaLonge.Parent = gLonge
	local ecoVozes = Instance.new("ReverbSoundEffect")
	ecoVozes.Parent = gVozes
	local ecoEfeitos = Instance.new("ReverbSoundEffect")
	ecoEfeitos.Parent = gEfeitos
	local ecoPA = Instance.new("EchoSoundEffect")
	ecoPA.Delay = 0.34
	ecoPA.Feedback = 0.38
	ecoPA.DryLevel = 0
	ecoPA.WetLevel = -5
	ecoPA.Parent = gPA
	local salaPA = Instance.new("ReverbSoundEffect")
	salaPA.DecayTime = 3.2
	salaPA.WetLevel = -6
	salaPA.Parent = gPA

	local zonaAtual = ""
	local function aplicarZona(z: string)
		if z == zonaAtual then
			return
		end
		zonaAtual = z
		for k, v in ECO[z] do
			(ecoVozes :: any)[k] = v;
			(ecoEfeitos :: any)[k] = v
		end
	end
	aplicarZona("corredor")

	-- ===== tocar um trecho de um sprite =====
	local function trecho(sprite: string, seg: { number }, volume: number, pai: Instance, g: SoundGroup, laco: boolean?): Sound
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. id(sprite)
		s.Volume = volume
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(seg[1], seg[1] + seg[2])
		if laco then
			s.LoopRegion = NumberRange.new(seg[1], seg[1] + seg[2])
			s.Looped = true
		end
		s.SoundGroup = g
		s.Parent = pai
		return s
	end
	-- ponto no mundo para um som 3D (o Terrain fica na origem: Position = posição no mundo)
	local function noLugar(pos: Vector3): Attachment
		local a = Instance.new("Attachment")
		a.Name = "BastiaoSom"
		a.Position = pos
		a.Parent = workspace.Terrain
		return a
	end
	local function alcance(s: Sound, raio: number)
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = math.min(8, raio * 0.15)
		s.RollOffMaxDistance = raio
	end

	-- pré-carrega os sprites (e o da língua nova quando o jogador troca) para a fala não atrasar
	local carregados: { [string]: boolean } = {}
	function api.precarregar()
		local lista = {}
		for _, nome in { "voz_" .. op.idioma(), EFEITOS_SPRITE } do
			if temSom(nome) and not carregados[nome] then
				carregados[nome] = true
				local s = Instance.new("Sound")
				s.SoundId = "rbxassetid://" .. id(nome)
				table.insert(lista, s)
			end
		end
		if #lista > 0 then
			task.spawn(function()
				pcall(function()
					ContentProvider:PreloadAsync(lista)
				end)
			end)
		end
	end
	api.precarregar()

	-- ===== efeitos =====
	function api.efeito(nome: string, pos: Vector3?): Sound?
		local seg = audio.sfx and audio.sfx[nome]
		local cfg = EFEITOS[nome]
		if not seg or not cfg or not temSom(EFEITOS_SPRITE) or type(seg[1]) ~= "number" then
			return nil
		end
		local s
		if pos and cfg.raio then
			local a = noLugar(pos)
			s = trecho(EFEITOS_SPRITE, seg, cfg.vol, a, gEfeitos)
			alcance(s, cfg.raio)
			Debris:AddItem(a, seg[2] + 1.5)
		else
			s = trecho(EFEITOS_SPRITE, seg, cfg.vol, SoundService, if cfg.pa then gPA elseif cfg.longe then gLonge else gEfeitos)
			Debris:AddItem(s, seg[2] + 1.5)
		end
		s:Play()
		return s
	end

	-- legenda de som do capítulo (com posição quando a deixa diz de onde vem)
	function api.som(chave: string, pos: Vector3?)
		local nome = Som.DA_LEGENDA[chave]
		if nome then
			api.efeito(nome, pos)
		end
	end
	-- ruído mecânico sem legenda (porta, alavanca, módulo, bipe, chime, segundo impacto)
	function api.ruido(chave: string, pos: Vector3?)
		api.efeito(chave, pos)
	end

	-- ===== vozes =====
	local vozAtual: Sound? = nil
	local leitoRadio: Sound? = nil
	local function cabecaPavel(): BasePart?
		local pasta = workspace:FindFirstChild("BastiaoHistoria")
		local pavel = pasta and pasta:FindFirstChild("Pavel")
		local cabeca = pavel and pavel:FindFirstChild("Head")
		return if cabeca and cabeca:IsA("BasePart") then cabeca else nil
	end
	function api.fala(chave: string)
		local idioma = op.idioma()
		local seg = audio.vozes and audio.vozes[idioma] and audio.vozes[idioma][chave]
		local sprite = "voz_" .. idioma
		if not seg or not temSom(sprite) then
			return
		end
		if vozAtual then
			vozAtual:Stop()
		end
		local canal = textos.CANAL[textos.FALANTE[chave]] or "radio"
		local s
		if canal == "pessoa" then
			local cabeca = cabecaPavel()
			if cabeca then
				s = trecho(sprite, seg, 1.0, cabeca, gVozes)
				alcance(s, 80)
			else
				s = trecho(sprite, seg, 0.85, SoundService, gVozes)
			end
		elseif canal == "pa" then
			s = trecho(sprite, seg, 0.95, SoundService, gPA)
		else
			-- rádio (e a gravação velha que chega pelo rádio): PTT, chiado por baixo e PTT no fim
			s = trecho(sprite, seg, 1.0, SoundService, gRadio)
			api.efeito("squelch")
			local leito = audio.loops and audio.loops.estatica
			if leito and temSom(EFEITOS_SPRITE) then
				if leitoRadio then
					leitoRadio:Destroy()
				end
				local l = trecho(EFEITOS_SPRITE, leito, if canal == "gravacao" then 0.16 else 0.1, SoundService, gRadio, true)
				l:Play()
				leitoRadio = l
				task.delay(seg[2] + 0.15, function()
					if leitoRadio == l then
						leitoRadio = nil
					end
					l:Destroy()
					api.efeito("squelch")
				end)
			end
		end
		vozAtual = s
		Debris:AddItem(s, seg[2] + 1)
		s:Play()
	end

	-- ===== loops de ambiente =====
	local function laco(nome: string, volume: number, pai: Instance, g: SoundGroup, raio: number?): Sound?
		local seg = audio.loops and audio.loops[nome]
		if not seg or not temSom(EFEITOS_SPRITE) then
			return nil
		end
		local s = trecho(EFEITOS_SPRITE, seg, volume, pai, g, true)
		if raio then
			alcance(s, raio)
		end
		s:Play()
		return s
	end
	local ambiente = laco("ambiente", 0.3, SoundService, gAmbiente)
	if ambiente then
		table.insert(criados, ambiente)
	end
	local ventiladorLugar = noLugar(Vector3.new(6.2, 6.0, 2.0))
	table.insert(criados, ventiladorLugar)
	laco("ventilador", 0.45, ventiladorLugar, gEfeitos, 30)
	local motorLugar = noLugar(Vector3.new(0, 5, 24.4))
	table.insert(criados, motorLugar)
	local motor = laco("motor", 0.55, motorLugar, gEfeitos, 50)
	local motorParou = false
	local function conferirMotor()
		if motor and not motorParou and op.acessoBloqueado() then
			motorParou = true
			local m = motor :: Sound
			TweenService:Create(m, TweenInfo.new(2.5), { Volume = 0, PlaybackSpeed = 0.6 }):Play()
			task.delay(2.6, function()
				m:Stop()
			end)
		end
	end
	conferirMotor()

	-- alarme: um loop em cada giroflex carregado + uma camada baixa em toda parte
	local alarmes: { [Instance]: Sound } = {}
	local alarmeGeral: Sound? = nil
	local function atualizarAlarme()
		local ligado = op.alarme()
		if ligado then
			if not alarmeGeral then
				alarmeGeral = laco("alarme", 0.12, SoundService, gAmbiente)
			end
			for _, rotor in CollectionService:GetTagged("BastiaoGiroflex") do
				if not alarmes[rotor] and rotor:IsA("BasePart") then
					local s = laco("alarme", 0.75, rotor, gEfeitos, 90)
					if s then
						alarmes[rotor] = s
					end
				end
			end
		else
			if alarmeGeral then
				alarmeGeral:Destroy()
				alarmeGeral = nil
			end
			for rotor, s in alarmes do
				s:Destroy()
				alarmes[rotor] = nil
			end
		end
	end
	table.insert(conexoes, CollectionService:GetInstanceAddedSignal("BastiaoGiroflex"):Connect(function()
		task.defer(atualizarAlarme)
	end))
	table.insert(conexoes, CollectionService:GetInstanceRemovedSignal("BastiaoGiroflex"):Connect(function(rotor)
		local s = alarmes[rotor]
		if s then
			s:Destroy()
			alarmes[rotor] = nil
		end
	end))
	function api.estado()
		atualizarAlarme()
		conferirMotor()
	end
	atualizarAlarme()

	-- ===== passos =====
	local distancias: { [Model]: number } = {}
	local parametros = RaycastParams.new()
	parametros.FilterType = Enum.RaycastFilterType.Exclude
	-- só troca os passos quando há gravação de passos (sem ela o passo padrão do Roblox continua)
	local listaPassos = audio.sfx and audio.sfx.passo_concreto
	local temPassos = type(listaPassos) == "table" and #listaPassos > 0 and type(listaPassos[1]) == "table"
	local function silenciarPadrao(raiz: BasePart)
		local padrao = raiz:FindFirstChild("Running")
		if padrao and padrao:IsA("Sound") and padrao.Volume > 0 then
			padrao.Volume = 0
		end
	end
	local function personagens(): { Model }
		local r = {}
		for _, j in Players:GetPlayers() do
			if j.Character then
				table.insert(r, j.Character)
			end
		end
		local pasta = workspace:FindFirstChild("BastiaoHistoria")
		local pavel = pasta and pasta:FindFirstChild("Pavel")
		if pavel and pavel:IsA("Model") then
			table.insert(r, pavel)
		end
		return r
	end
	local function passo(personagem: Model, raiz: BasePart)
		parametros.FilterDescendantsInstances = { personagem }
		local hit = workspace:Raycast(raiz.Position, Vector3.new(0, -4.2, 0), parametros)
		if not hit then
			return
		end
		-- o chão do bunker é concreto; metal só se houver gravação própria
		local lista = if METAIS[hit.Material] and audio.sfx.passo_metal then audio.sfx.passo_metal else audio.sfx.passo_concreto
		if type(lista) ~= "table" or #lista == 0 or type(lista[1]) ~= "table" then
			return
		end
		local seg = lista[math.random(1, #lista)]
		local eu = Players.LocalPlayer
		local local_ = eu ~= nil and personagem == eu.Character
		local a = noLugar(hit.Position + Vector3.new(0, 0.3, 0))
		local s = trecho(EFEITOS_SPRITE, seg, if local_ then 0.42 else 0.7, a, gEfeitos)
		s.PlaybackSpeed = 0.94 + math.random() * 0.12
		alcance(s, if local_ then 20 else 40)
		Debris:AddItem(a, seg[2] + 0.5)
		s:Play()
	end
	local acumulado = 0
	local ultimaZona = 0
	table.insert(conexoes, RunService.Heartbeat:Connect(function(dt: number)
		acumulado += dt
		ultimaZona += dt
		if ultimaZona >= 0.4 then
			ultimaZona = 0
			camera = workspace.CurrentCamera
			if camera then
				aplicarZona(Som.zona(camera.CFrame.Position))
			end
		end
		if acumulado < 0.05 or not temPassos or not temSom(EFEITOS_SPRITE) then
			return
		end
		local passoDt = acumulado
		acumulado = 0
		local origem = if camera then camera.CFrame.Position else Vector3.zero
		local vivos = {}
		for _, personagem in personagens() do
			local raiz = personagem:FindFirstChild("HumanoidRootPart") :: BasePart?
			if raiz then
				vivos[personagem] = true
				silenciarPadrao(raiz)
				if (raiz.Position - origem).Magnitude <= 55 then
					local v = raiz.AssemblyLinearVelocity
					local h = Vector3.new(v.X, 0, v.Z).Magnitude
					if h > 1.2 and math.abs(v.Y) < 6 then
						local d = (distancias[personagem] or 0) + h * passoDt
						if d >= 3.2 + h * 0.1 then
							d = 0
							passo(personagem, raiz)
						end
						distancias[personagem] = d
					else
						distancias[personagem] = 0
					end
				end
			end
		end
		for personagem in distancias do
			if not vivos[personagem] then
				distancias[personagem] = nil
			end
		end
	end))

	-- desliga tudo o que este módulo criou (usado pelo teste na nuvem; o jogo nunca precisa)
	function api.parar()
		for _, c in conexoes do
			c:Disconnect()
		end
		table.clear(conexoes)
		for _, s in alarmes do
			s:Destroy()
		end
		table.clear(alarmes)
		if alarmeGeral then
			alarmeGeral:Destroy()
			alarmeGeral = nil
		end
		if leitoRadio then
			leitoRadio:Destroy()
			leitoRadio = nil
		end
		for _, inst in criados do
			inst:Destroy()
		end
		table.clear(criados)
	end

	return api
end

return Som
