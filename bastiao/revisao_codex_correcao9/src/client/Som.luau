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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Som = {}

local function finito(v: any): boolean
	return type(v) == "number" and v == v and math.abs(v) < math.huge
end
local function segmento(seg: any): boolean
	return type(seg) == "table" and finito(seg[1]) and finito(seg[2]) and seg[1] >= 0
		and seg[2] > 0 and seg[2] <= 90 and seg[1] + seg[2] <= 7200
		and (seg[3] == nil or type(seg[3]) == "string")
end
local function sprite(seg: any, padrao: string): string
	return if type(seg) == "table" and type(seg[3]) == "string" then seg[3] else padrao
end

-- efeitos e loops ficam no mesmo arquivo de som (menos envios para o Roblox); vozes, um por língua
local EFEITOS_SPRITE = "efeitos"

-- efeitos: volume, alcance 3D (raio) e se vão pelo alto-falante (pa) ou "de longe" (2D com eco)
local EFEITOS: { [string]: { vol: number, raio: number?, pa: boolean?, longe: boolean?, ouvido: boolean? } } = {
	impacto_zumbido = { vol = 0.20, ouvido = true }, -- região real do catálogo; nunca inventa ID
	estatica = { vol = 0.5 },
	squelch = { vol = 0.55 },
	toques_longe = { vol = 0.85, longe = true },
	toques_perto = { vol = 1.0, raio = 70 },
	inspiracao = { vol = 1.0, raio = 80 },
	vapor = { vol = 0.75, raio = 45 },
	impacto_porta = { vol = 2.0, raio = 180 }, -- pancadas do monstro na porta (bem pesadas)
	portas = { vol = 0.9, longe = true },
	passos_monstro = { vol = 1.0, longe = true },
	trava = { vol = 0.95, raio = 45 },
	porta_desliza = { vol = 0.8, raio = 55 },
	alavanca = { vol = 0.85, raio = 35 },
	modulo_encaixe = { vol = 0.85, raio = 35 },
	modulo_pegar = { vol = 0.75, raio = 30 },
	terminal_bip = { vol = 0.5, raio = 28 },
	terminal_liga = { vol = 0.6, raio = 28 },
	chime_pa = { vol = 0.8, pa = true },
	-- Etapa 3: lanterna, menu da bodycam e a legenda que se quebra (2D, perto do ouvido)
	lanterna_liga = { vol = 0.75 },
	lanterna_desliga = { vol = 0.65 },
	menu_abre = { vol = 0.7 },
	legenda_quebra = { vol = 0.35 },
	jumpscare = { vol = 3.0 }, -- grito do jumpscare (na cabeça de quem foi pego)
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
	passosExternos: boolean?,
}

function Som.iniciar(op: Opcoes): any
	local audio, textos = op.audio, op.textos
	local api = {} :: any
	local ativo = true
	local externos = op.passosExternos == true
	local sons: { [Sound]: any } = {}
	local locais: { [Attachment]: boolean } = {}
	local provas: { [Sound]: boolean } = {}
	local tarefas: { [thread]: boolean } = {}
	local padroes: { [Sound]: any } = {}
	local camera = workspace.CurrentCamera
	local conexoes: { RBXScriptConnection } = {}
	local criados: { Instance } = {}

	local function id(nome: string): number
		local v = audio.ids and audio.ids[nome]
		return if finito(v) and v > 0 and v % 1 == 0 and v <= 9007199254740991 then v else 0
	end
	local function temSom(nome: string): boolean
		return id(nome) > 0
	end

	local function agendar(tempo: number, fn: () -> ())
		local handle: thread?
		handle = task.delay(tempo, function()
			if handle then tarefas[handle] = nil end
			if ativo then fn() end
		end)
		tarefas[handle :: thread] = true
	end
	local function restaurar(s: Sound)
		local salvo = padroes[s]
		if not salvo then return end
		padroes[s] = nil
		salvo.conexao:Disconnect()
		if s.Parent then s.Volume = salvo.volume end
	end
	local function restaurarTodos()
		local lista = {}
		for s in padroes do table.insert(lista, s) end
		for _, s in lista do restaurar(s) end
	end
	local function encerrar(s: Sound)
		local registro = sons[s]
		if not registro then return end
		sons[s] = nil
		for _, c in registro.conexoes do c:Disconnect() end
		local pai = s.Parent
		s:Stop()
		s:Destroy()
		if pai and locais[pai :: Attachment] then
			locais[pai :: Attachment] = nil
			pai:Destroy()
		end
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
	local gOuvido = grupo("BastiaoOuvido", 1) -- zumbido interno não atravessa o abafamento dos SFX
	local gAmbiente = grupo("BastiaoAmbiente", 0.8)
	api.grupoEfeitos = gEfeitos
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
	local function trecho(nome: string, seg: { any }, volume: number, pai: Instance, g: SoundGroup, laco: boolean?): Sound
		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. id(sprite(seg, nome))
		s.Volume = volume
		s.Looped = laco == true
		s.PlayOnRemove = false
		s.SoundGroup = g
		sons[s] = { seg = seg, conexoes = {}, iniciado = false, prazo = os.clock() + 8, laco = laco == true }
		s.Parent = pai
		return s
	end
	local function tocar(s: Sound)
		local registro = sons[s]
		if not ativo or not registro then return end
		local function comecar()
			if not ativo or sons[s] ~= registro or registro.iniciado or not s.IsLoaded then return end
			local seg = registro.seg
			if not finito(s.TimeLength) or s.TimeLength <= 0 or seg[1] + seg[2] > s.TimeLength + 0.05 then
				encerrar(s)
				return
			end
			local ok = pcall(function()
				s.PlaybackRegionsEnabled = true
				s.PlaybackRegion = NumberRange.new(seg[1], seg[1] + seg[2])
				s.LoopRegion = NumberRange.new(seg[1], seg[1] + seg[2])
			end)
			if not ok then encerrar(s); return end
			s.TimePosition = seg[1]
			registro.iniciado = true
			registro.prazo = if registro.laco then math.huge else os.clock() + seg[2] + 1
			s:Play()
		end
		table.insert(registro.conexoes, s.Loaded:Connect(comecar))
		table.insert(registro.conexoes, s.Ended:Connect(function()
			if not registro.laco then encerrar(s) end
		end))
		if s.IsLoaded then comecar() end
	end

	-- ponto no mundo para um som 3D (o Terrain fica na origem: Position = posição no mundo)
	local function noLugar(pos: Vector3): Attachment
		local a = Instance.new("Attachment")
		a.Name = "BastiaoSom"
		a.Position = pos
		a.Parent = workspace.Terrain
		locais[a] = true
		return a
	end
	local function alcance(s: Sound, raio: number)
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = math.min(8, raio * 0.15)
		s.RollOffMaxDistance = raio
	end

	-- Pré-carrega IDs reais usados pela língua atual e todos os sprites de efeitos/loops.
	-- seg[3] escolhe um atlas novo; entradas antigas de dois valores mantêm o atlas legado.
	local carregados: { [number]: boolean } = {}
	local carregando: { [number]: boolean } = {}
	local comprimentos: { [number]: number } = {}
	local function pronto(seg: any, padrao: string): boolean
		if not segmento(seg) then return false end
		local numero = id(sprite(seg, padrao))
		return carregados[numero] == true and seg[1] + seg[2] <= (comprimentos[numero] or 0) + 0.05
	end
	function api.precarregar()
		if not ativo then return end
		local lista = {}
		local function adicionar(seg: any, padrao: string)
			if not segmento(seg) then return end
			local numero = id(sprite(seg, padrao))
			if numero > 0 and not carregados[numero] and not carregando[numero] then
				carregando[numero] = true
				table.insert(lista, numero)
			end
		end
		local lingua = op.idioma()
		for _, seg in (audio.vozes and audio.vozes[lingua]) or {} do adicionar(seg, "voz_" .. lingua) end
		for _, seg in audio.sfx or {} do
			if type(seg) == "table" and type(seg[1]) == "table" then
				for _, passo in seg do adicionar(passo, EFEITOS_SPRITE) end
			else adicionar(seg, EFEITOS_SPRITE) end
		end
		for _, seg in audio.loops or {} do adicionar(seg, EFEITOS_SPRITE) end
		if #lista == 0 then return end
		local handle: thread?
		handle = task.spawn(function()
			for inicio = 1, #lista, 8 do
				if not ativo then break end
				local lote = {}
				for i = inicio, math.min(inicio + 7, #lista) do
					local s = Instance.new("Sound")
					s.SoundId = "rbxassetid://" .. lista[i]
					s.Volume = 0
					provas[s] = true
					table.insert(lote, s)
				end
				local ok = pcall(function() ContentProvider:PreloadAsync(lote) end)
				for i, s in lote do
					local numero = lista[inicio + i - 1]
					carregando[numero] = nil
					if ativo and ok and s.IsLoaded and finito(s.TimeLength) and s.TimeLength > 0 then
						local regioes = pcall(function()
							s.PlaybackRegionsEnabled = true
							s.PlaybackRegion = NumberRange.new(0, s.TimeLength)
						end)
						if regioes then carregados[numero] = true; comprimentos[numero] = s.TimeLength end
					end
					provas[s] = nil
					s:Destroy()
				end
			end
			if handle then tarefas[handle] = nil end
		end)
		tarefas[handle :: thread] = true
	end
	api.precarregar()

	-- ===== efeitos =====
	function api.efeito(nome: string, pos: Vector3?): Sound?
		local seg = audio.sfx and audio.sfx[nome]
		local cfg = EFEITOS[nome]
		if not ativo or not segmento(seg) or not cfg or not temSom(sprite(seg, EFEITOS_SPRITE)) then
			return nil
		end
		local s
		if pos and cfg.raio then
			local a = noLugar(pos)
			s = trecho(EFEITOS_SPRITE, seg, cfg.vol, a, gEfeitos)
			alcance(s, cfg.raio)
		else
			s = trecho(EFEITOS_SPRITE, seg, cfg.vol, SoundService, if cfg.ouvido then gOuvido elseif cfg.pa then gPA elseif cfg.longe then gLonge else gEfeitos)
		end
		tocar(s)
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
		local nomeSprite = sprite(seg, "voz_" .. idioma)
		if not ativo or not segmento(seg) or not temSom(nomeSprite) then
			return
		end
		if vozAtual then
			encerrar(vozAtual)
		end
		if leitoRadio then encerrar(leitoRadio); leitoRadio = nil end
		local canal = textos.CANAL[textos.FALANTE[chave]] or "radio"
		local s
		if canal == "pessoa" then
			local cabeca = cabecaPavel()
			if cabeca then
				s = trecho(nomeSprite, seg, 1.0, cabeca, gVozes)
				alcance(s, 80)
			else
				s = trecho(nomeSprite, seg, 0.85, SoundService, gVozes)
			end
		elseif canal == "pa" then
			s = trecho(nomeSprite, seg, 0.95, SoundService, gPA)
		else
			-- rádio (e a gravação velha que chega pelo rádio): PTT, chiado por baixo e PTT no fim
			s = trecho(nomeSprite, seg, 1.0, SoundService, gRadio)
			api.efeito("squelch")
			local leito = audio.loops and audio.loops.estatica
			if segmento(leito) and temSom(sprite(leito, EFEITOS_SPRITE)) then
				if leitoRadio then
					encerrar(leitoRadio)
				end
				local l = trecho(EFEITOS_SPRITE, leito, if canal == "gravacao" then 0.16 else 0.1, SoundService, gRadio, true)
				tocar(l)
				leitoRadio = l
				agendar(seg[2] + 0.15, function()
					if leitoRadio ~= l then return end
					leitoRadio = nil
					encerrar(l)
					api.efeito("squelch")
				end)
			end
		end
		vozAtual = s
		tocar(s)
	end

	-- ===== loops de ambiente =====
	local function laco(nome: string, volume: number, pai: Instance, g: SoundGroup, raio: number?): Sound?
		local seg = audio.loops and audio.loops[nome]
		if not ativo or not segmento(seg) or not temSom(sprite(seg, EFEITOS_SPRITE)) then
			return nil
		end
		local s = trecho(EFEITOS_SPRITE, seg, volume, pai, g, true)
		if raio then
			alcance(s, raio)
		end
		tocar(s)
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
			agendar(2.6, function()
				m:Stop()
			end)
		end
	end
	conferirMotor()

	-- alarme: um loop em cada giroflex carregado + uma camada baixa em toda parte
	local alarmes: { [Instance]: Sound } = {}
	local alarmeGeral: Sound? = nil
	local function atualizarAlarme()
		if not ativo then return end
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
				encerrar(alarmeGeral)
				alarmeGeral = nil
			end
			for rotor, s in alarmes do
				encerrar(s)
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
			encerrar(s)
			alarmes[rotor] = nil
		end
	end))
	function api.estado()
		if not ativo then return end
		atualizarAlarme()
		conferirMotor()
	end
	atualizarAlarme()

	-- ===== passos =====
	local distancias: { [Model]: number } = {}
	local parametros = RaycastParams.new()
	parametros.FilterType = Enum.RaycastFilterType.Exclude
	local ultimasPosicoes: { [Model]: Vector3 } = {}
	local function listaPronta(lista: any): { any }
		local r = {}
		if type(lista) == "table" then
			for _, seg in lista do if pronto(seg, EFEITOS_SPRITE) then table.insert(r, seg) end end
		end
		return r
	end
	local function temPassos(): boolean
		return #listaPronta(audio.sfx and audio.sfx.passo_concreto) > 0
	end
	function api.passosExternos(ligado: boolean)
		if not ativo or externos == (ligado == true) then return end
		externos = ligado == true
		table.clear(distancias)
		table.clear(ultimasPosicoes)
		restaurarTodos()
	end
	local function silenciarPadrao(raiz: BasePart)
		local padrao = raiz:FindFirstChild("Running")
		if not padrao or not padrao:IsA("Sound") or padroes[padrao] then return end
		local salvo = { volume = padrao.Volume }
		padroes[padrao] = salvo
		salvo.conexao = padrao:GetPropertyChangedSignal("Volume"):Connect(function()
			if ativo and padroes[padrao] and padrao.Volume ~= 0 then padrao.Volume = 0 end
		end)
		padrao.Volume = 0
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
		local lista = listaPronta(if METAIS[hit.Material] then audio.sfx.passo_metal else audio.sfx.passo_concreto)
		if #lista == 0 then lista = listaPronta(audio.sfx.passo_concreto) end
		if #lista == 0 then return end
		local seg = lista[math.random(1, #lista)]
		local eu = Players.LocalPlayer
		local local_ = eu ~= nil and personagem == eu.Character
		local a = noLugar(hit.Position + Vector3.new(0, 0.3, 0))
		local s = trecho(EFEITOS_SPRITE, seg, if local_ then 0.42 else 0.7, a, gEfeitos)
		s.PlaybackSpeed = 0.94 + math.random() * 0.12
		alcance(s, if local_ then 20 else 40)
		tocar(s)
	end
	local acumulado = 0
	local ultimaZona = 0
	table.insert(conexoes, RunService.Heartbeat:Connect(function(dt: number)
		if not ativo then return end
		local agora = os.clock()
		for s, registro in sons do
			if not s.Parent or agora >= registro.prazo then
				encerrar(s)
			elseif registro.iniciado and s.TimePosition >= registro.seg[1] + registro.seg[2] then
				if registro.laco then s.TimePosition = registro.seg[1] else encerrar(s) end
			end
		end
		acumulado += dt
		ultimaZona += dt
		if ultimaZona >= 0.4 then
			ultimaZona = 0
			camera = workspace.CurrentCamera
			if camera then
				aplicarZona(Som.zona(camera.CFrame.Position))
			end
		end
		if acumulado < 0.05 then return end
		if externos or not temPassos() then
			acumulado = 0
			if not externos then restaurarTodos() end
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
				local h = personagem:FindFirstChildOfClass("Humanoid")
				local vivo = h and h.Health > 0
				if vivo then silenciarPadrao(raiz) end
				local anterior = ultimasPosicoes[personagem]
				ultimasPosicoes[personagem] = raiz.Position
				local estado = h and h:GetState()
				local andando = estado == Enum.HumanoidStateType.Running or estado == Enum.HumanoidStateType.RunningNoPhysics
				local delta = if anterior then Vector3.new(raiz.Position.X - anterior.X, 0, raiz.Position.Z - anterior.Z).Magnitude else 0
				local velocidade = if passoDt > 0 then delta / passoDt else 0
				if vivo and andando and h.FloorMaterial ~= Enum.Material.Air and h.MoveDirection.Magnitude > 0.1
					and (raiz.Position - origem).Magnitude <= 55 and passoDt <= 0.25 and delta <= 6 and velocidade > 0.75 and velocidade <= 45 then
					local d = (distancias[personagem] or 0) + delta
					if d >= 3.2 + velocidade * 0.1 then d = 0; passo(personagem, raiz) end
					distancias[personagem] = d
				else distancias[personagem] = 0 end
			end
		end
		for personagem in distancias do
			if not vivos[personagem] then
				distancias[personagem] = nil
				ultimasPosicoes[personagem] = nil
			end
		end
		for padrao in padroes do
			local raiz = padrao.Parent
			local personagem = raiz and raiz.Parent
			if not personagem or not vivos[personagem] then restaurar(padrao) end
		end
	end))

	-- desliga tudo o que este módulo criou (usado pelo teste na nuvem; o jogo nunca precisa)
	function api.parar()
		if not ativo then return end
		ativo = false
		for _, c in conexoes do c:Disconnect() end
		table.clear(conexoes)
		for handle in tarefas do pcall(task.cancel, handle) end
		table.clear(tarefas)
		for s in provas do s:Destroy() end
		table.clear(provas)
		restaurarTodos()
		local lista = {}
		for s in sons do table.insert(lista, s) end
		for _, s in lista do encerrar(s) end
		for a in locais do a:Destroy() end
		table.clear(locais)
		for _, inst in criados do inst:Destroy() end
		table.clear(criados)
		table.clear(alarmes)
		alarmeGeral, leitoRadio, vozAtual = nil, nil, nil
	end

	return api
end

return Som
