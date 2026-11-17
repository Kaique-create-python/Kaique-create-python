-- PROJETO BASTIÃO :: sons do monstro 731-A (passos pesados e o bote quando ele alcança o jogador).
-- Só sons publicados na Creator Store (Pro Sound Effects, licenciados pela Roblox) e o rugido do 731-A.
-- Passos: seguem os marcadores Foot_L/Foot_R das animações (o servidor repassa em BastiaoMarkerSerial),
-- então batem junto com os pés. Bote: BastiaoAttackSerial / BastiaoHitSerial vindos da Criatura.
-- Feito pelo Antigravity no Studio (Perseguição v2). O BastiaoCliente liga com passos=true: o
-- baque grave daqui soma com o passo do ElevenLabs do Foley, os dois no mesmo marcador do pé.
-- Também: o bote (rugido na cabeça de quem foi alcançado), o golpe da garra, o jumpscare
-- (captura) e as pancadas na porta da oficina.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local Workspace = game:GetService("Workspace")

local MonstroSom = {}

local IDS = {
	passos = { 9114078861, 9114077211 }, -- Dinosaur Footsteps Boomy Thumps 6 e 10 (SFX)
	rugido = 89672266220613, -- rugido do 731-A (o mesmo do alerta), aqui bem grave e estourado
	grito = 9113980319, -- Creature Mix Giant Crab Monster Roar Growl 1 (SFX)
	impacto = 9113525391, -- Body Impact 1 (SFX)
}
MonstroSom.IDS = IDS

-- Ajustes fáceis de mexer (volume vai de 0 a 10 no Roblox)
local AJUSTE = {
	passoAndando = 3.5,
	passoCorrendo = 6,
	boteVolume = 10,
	boteGanhoDb = 14, -- ganho extra do compressor (deixa MUITO mais alto e saturado)
	boteDistorcao = 0.9, -- 0 a 1: quanto mais, mais estourado
	raioNaCabeca = 22, -- quem estiver até essa distância ouve o bote "dentro da cabeça"
}
MonstroSom.AJUSTE = AJUSTE

local function efeitos(sound: Sound, cfg)
	if cfg.eq then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain, eq.MidGain, eq.HighGain = cfg.eq[1], cfg.eq[2], cfg.eq[3]
		eq.Priority = 3
		eq.Parent = sound
	end
	if cfg.ganho then
		local comp = Instance.new("CompressorSoundEffect")
		comp.Threshold = -30
		comp.Ratio = 8
		comp.Attack = 0.003
		comp.Release = 0.2
		comp.GainMakeup = cfg.ganho
		comp.Priority = 2
		comp.Parent = sound
	end
	if cfg.distorcao then
		local dist = Instance.new("DistortionSoundEffect")
		dist.Level = cfg.distorcao
		dist.Priority = 1
		dist.Parent = sound
	end
end

function MonstroSom.iniciar(op)
	op = op or {}
	local jogador = op.jogador or Players.LocalPlayer
	local grupo = op.grupo
	local comPassos = op.passos ~= false -- false: passos ficam só com o Foley
	local efeito = op.efeito -- sons do ElevenLabs (Som.efeito); nil enquanto não existirem
	local vivo = true
	local conexoes, monstros, vivos = {}, {}, {}
	local random = Random.new()

	local pasta2D = Instance.new("Folder")
	pasta2D.Name = "BastiaoMonstroSomLocal"
	pasta2D.Parent = SoundService

	local function tocar(id: number, pai: Instance, cfg)
		if not vivo or not pai.Parent then return nil end
		local s = Instance.new("Sound")
		s.Name = "BastiaoMonstro_" .. (cfg.nome or "som")
		s.SoundId = "rbxassetid://" .. tostring(id)
		s.Volume = math.clamp(cfg.volume or 1, 0, 10)
		s.PlaybackSpeed = cfg.velocidade or 1
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = cfg.perto or 10
		s.RollOffMaxDistance = cfg.longe or 160
		if cfg.grupo then s.SoundGroup = cfg.grupo end
		efeitos(s, cfg)
		s.Parent = pai
		vivos[s] = true
		local function apagar()
			vivos[s] = nil
			if s.Parent then s:Destroy() end
		end
		s.Ended:Connect(apagar)
		s:Play()
		local fade = cfg.fade or 0.35
		task.delay(cfg.duracao or 2, function()
			if not s.Parent then vivos[s] = nil; return end
			TweenService:Create(s, TweenInfo.new(fade), { Volume = 0 }):Play()
			task.delay(fade + 0.05, apagar)
		end)
		return s
	end

	local function meuRoot(): BasePart?
		local ch = jogador.Character
		local r = ch and ch:FindFirstChild("HumanoidRootPart")
		return if r and r:IsA("BasePart") then r else nil
	end

	local function soltar(model)
		local m = monstros[model]
		if not m then return end
		monstros[model] = nil
		for _, c in m.conexoes do c:Disconnect() end
		if m.pes then m.pes:Destroy() end
		if m.boca then m.boca:Destroy() end
	end

	local function ligar(model: Model)
		if not vivo or monstros[model] then return end
		local root = model:FindFirstChild("HumanoidRootPart") or model:WaitForChild("HumanoidRootPart", 10)
		if not vivo or monstros[model] or not root or not root:IsA("BasePart") then return end
		local h = root.Size.Y
		local pes = Instance.new("Attachment")
		pes.Name = "BastiaoMonstroPes"
		pes.Position = Vector3.new(0, -h / 2 + 0.3, 0)
		pes.Parent = root
		local boca = Instance.new("Attachment")
		boca.Name = "BastiaoMonstroBoca"
		boca.Position = Vector3.new(0, h * 0.32, 0)
		boca.Parent = root
		local m = {
			conexoes = {}, pes = pes, boca = boca, lado = 0, ultimoPasso = 0,
			marcador = model:GetAttribute("BastiaoMarkerSerial"),
			ataque = model:GetAttribute("BastiaoAttackSerial"),
			golpe = model:GetAttribute("BastiaoHitSerial"),
		}
		monstros[model] = m

		local function pertoDeMim(raio: number): boolean
			local r = meuRoot()
			return r ~= nil and root.Parent ~= nil and (r.Position - root.Position).Magnitude <= raio
		end

		-- PASSOS: um baque grave a cada pé que encosta no chão
		if comPassos then table.insert(m.conexoes, model:GetAttributeChangedSignal("BastiaoMarkerSerial"):Connect(function()
			local serial = model:GetAttribute("BastiaoMarkerSerial")
			if serial == m.marcador then return end
			m.marcador = serial
			local nome = model:GetAttribute("BastiaoMarkerName")
			if type(nome) ~= "string" or nome:sub(1, 4) ~= "Foot" then return end
			local agora = os.clock()
			if agora - m.ultimoPasso < 0.18 then return end
			m.ultimoPasso = agora
			local estado = model:GetAttribute("BastiaoState")
			local correndo = estado == "chase" or estado == "attack"
				or model:GetAttribute("BastiaoAnimation") == "08_CORRER"
			m.lado = m.lado % #IDS.passos + 1
			tocar(IDS.passos[m.lado], pes, {
				nome = "passo",
				volume = if correndo then AJUSTE.passoCorrendo else AJUSTE.passoAndando,
				velocidade = random:NextNumber(0.78, 0.9), -- mais grave e com variação entre um pé e outro
				eq = { 9, -2, -8 },
				perto = 14, longe = 170,
				grupo = grupo, -- mesmo eco dos corredores
				duracao = 1.1, fade = 0.4,
			})
		end)) end

		-- CAPTURA (jumpscare) e PORTA: os marcadores das animações extras
		table.insert(m.conexoes, model:GetAttributeChangedSignal("BastiaoMarkerSerial"):Connect(function()
			local nome = model:GetAttribute("BastiaoMarkerName")
			local estado = model:GetAttribute("BastiaoState")
			if type(nome) ~= "string" then return end
			local vitima = model:GetAttribute("BastiaoCapturaVitima") == jogador.UserId
			if estado == "capture" then
				if nome == "Grip" then
					tocar(IDS.impacto, if vitima then pasta2D else boca, {
						nome = "captura_agarra", volume = 7, velocidade = 0.55, eq = { 9, 0, -6 },
						distorcao = 0.5, perto = 14, longe = 160, duracao = 1.2, fade = 0.3,
					})
				elseif nome == "Roar" then
					tocar(IDS.rugido, boca, {
						nome = "captura_rugido", volume = AJUSTE.boteVolume, velocidade = 0.66,
						eq = { 10, 0, -6 }, ganho = AJUSTE.boteGanhoDb, distorcao = AJUSTE.boteDistorcao,
						perto = 25, longe = 260, duracao = 2.4, fade = 0.5,
					})
					tocar(IDS.grito, if vitima then pasta2D else boca, {
						nome = "captura_grito", volume = 9, velocidade = 0.72,
						eq = { 10, -1, -6 }, ganho = AJUSTE.boteGanhoDb - 2, distorcao = 0.85,
						perto = 25, longe = 240, duracao = 2.2, fade = 0.5,
					})
					if vitima then
						tocar(IDS.rugido, pasta2D, {
							nome = "captura_cabeca", volume = AJUSTE.boteVolume, velocidade = 0.6,
							eq = { 10, 2, -4 }, ganho = AJUSTE.boteGanhoDb + 3, distorcao = 0.95,
							duracao = 2.4, fade = 0.4,
						})
					end
				elseif nome == "Impact" then
					tocar(IDS.impacto, if vitima then pasta2D else boca, {
						nome = "captura_golpe", volume = 10, velocidade = 0.5, eq = { 10, 0, -5 },
						ganho = AJUSTE.boteGanhoDb, distorcao = 0.95, perto = 14, longe = 180,
						duracao = 1.6, fade = 0.3,
					})
				end
			elseif nome == "DoorHit" or (nome == "Impact" and model:GetAttribute("BastiaoAnimation") == "17_ESMURRAR_PORTA") then
				-- pancada na porta da oficina: baque metálico grave que se ouve longe
				local tocou = false
				if efeito then
					local ok, som = pcall(efeito, "impacto_porta", boca.WorldPosition)
					tocou = ok and som ~= nil
				end
				if not tocou then
					tocar(IDS.impacto, boca, {
						nome = "porta_pancada", volume = 9, velocidade = random:NextNumber(0.42, 0.5),
						eq = { 10, 2, -3 }, ganho = 8, distorcao = 0.6, perto = 22, longe = 220,
						grupo = grupo, duracao = 1.6, fade = 0.4,
					})
				end
			end
		end))

		-- BOTE: quando alcança o jogador, rugido gravíssimo, altíssimo e estourado
		table.insert(m.conexoes, model:GetAttributeChangedSignal("BastiaoAttackSerial"):Connect(function()
			local serial = model:GetAttribute("BastiaoAttackSerial")
			if serial == m.ataque or serial == 0 then m.ataque = serial; return end
			m.ataque = serial
			tocar(IDS.rugido, boca, {
				nome = "bote_rugido", volume = AJUSTE.boteVolume, velocidade = 0.7,
				eq = { 10, 0, -6 }, ganho = AJUSTE.boteGanhoDb, distorcao = AJUSTE.boteDistorcao,
				perto = 25, longe = 240, duracao = 2.6, fade = 0.5,
			})
			tocar(IDS.grito, boca, {
				nome = "bote_grito", volume = 8, velocidade = 0.78,
				eq = { 10, -1, -6 }, ganho = AJUSTE.boteGanhoDb - 4, distorcao = AJUSTE.boteDistorcao - 0.2,
				perto = 25, longe = 220, duracao = 2.2, fade = 0.6,
			})
			if model:GetAttribute("BastiaoAttackVictim") == jogador.UserId or pertoDeMim(AJUSTE.raioNaCabeca) then
				-- na cabeça de quem foi alcançado: sem distância, sem grupo, no máximo
				tocar(IDS.rugido, pasta2D, {
					nome = "bote_cabeca", volume = AJUSTE.boteVolume, velocidade = 0.64,
					eq = { 10, 2, -4 }, ganho = AJUSTE.boteGanhoDb + 2, distorcao = 0.95,
					duracao = 2.6, fade = 0.5,
				})
			end
		end))

		-- GOLPE: quando a garra acerta, um impacto seco e estourado para quem apanhou
		table.insert(m.conexoes, model:GetAttributeChangedSignal("BastiaoHitSerial"):Connect(function()
			local serial = model:GetAttribute("BastiaoHitSerial")
			if serial == m.golpe or serial == 0 then m.golpe = serial; return end
			m.golpe = serial
			if model:GetAttribute("BastiaoHitVictim") == jogador.UserId then
				tocar(IDS.impacto, pasta2D, {
					nome = "golpe_cabeca", volume = 10, velocidade = 0.62,
					eq = { 10, 0, -5 }, ganho = AJUSTE.boteGanhoDb, distorcao = 0.9,
					duracao = 1.4, fade = 0.3,
				})
			else
				tocar(IDS.impacto, boca, {
					nome = "golpe", volume = 7, velocidade = 0.7,
					eq = { 8, 0, -5 }, distorcao = 0.6, perto = 12, longe = 140,
					duracao = 1.4, fade = 0.3,
				})
			end
		end))

		table.insert(m.conexoes, model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) then soltar(model) end
		end))
	end

	local function considerar(inst: Instance)
		if inst:IsA("Model") and (inst:GetAttribute("BastiaoCreature") == true or inst.Name == "Bastiao731A") then
			task.spawn(ligar, inst)
		end
	end
	for _, inst in Workspace:GetDescendants() do considerar(inst) end
	table.insert(conexoes, Workspace.DescendantAdded:Connect(considerar))

	-- pré-carrega para o primeiro passo/bote não sair atrasado
	task.spawn(function()
		local probes = {}
		local ids = if comPassos then { IDS.passos[1], IDS.passos[2], IDS.rugido, IDS.grito, IDS.impacto } else { IDS.rugido, IDS.grito, IDS.impacto }
		for _, id in ids do
			local p = Instance.new("Sound")
			p.SoundId = "rbxassetid://" .. tostring(id)
			p.Volume = 0
			p.Parent = pasta2D
			table.insert(probes, p)
		end
		local ok, erro = pcall(function() ContentProvider:PreloadAsync(probes) end)
		if not ok then warn("[Bastiao MonstroSom] pré-carregamento falhou: " .. tostring(erro)) end
		for _, p in probes do p:Destroy() end
	end)

	local api = {}
	function api.parar()
		if not vivo then return end
		vivo = false
		for _, c in conexoes do c:Disconnect() end
		local lista = {}
		for model in monstros do table.insert(lista, model) end
		for _, model in lista do soltar(model) end
		for s in vivos do if s.Parent then s:Destroy() end end
		pasta2D:Destroy()
	end
	return api
end

return MonstroSom
