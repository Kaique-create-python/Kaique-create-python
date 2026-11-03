-- BIZARRE BATTLEGROUNDS :: animações feitas por código (Motor6D.Transform)
-- Roda depois das animações do Roblox (PreSimulation): por cima do andar/correr normal do
-- avatar entra o golpe, mesclado. Bots e Stands não têm animação do Roblox: aqui também
-- fazemos o andar, o pulo e a respiração deles.

local RunService = game:GetService("RunService")

local BB = script.Parent.Parent
local Poses = require(BB:WaitForChild("Poses"))

local Animador = {}

local anims: { [Model]: any } = {}
local rad = math.rad
local pausaGlobal = 0

-- para o R6 (se alguém entrar com R6) usamos só as juntas que existem
local R6 = {
	RootJoint = "Root",
	Neck = "Neck",
	["Left Shoulder"] = "LeftShoulder",
	["Right Shoulder"] = "RightShoulder",
	["Left Hip"] = "LeftHip",
	["Right Hip"] = "RightHip",
}

local CURTO: { [string]: string } = {}
for curto, longo in Poses.JUNTAS do
	CURTO[longo] = curto
end

local function lerJuntas(modelo: Model)
	local j = {}
	for _, d in modelo:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 and d:IsDescendantOf(modelo) then
			local nome = R6[d.Name] or d.Name
			local curto = CURTO[nome]
			if curto and not j[curto] then
				local c0 = d.C0
				local rot0 = c0 - c0.Position
				j[curto] = { motor = d, rot0 = rot0, inv = rot0:Inverse(), r6 = R6[d.Name] ~= nil }
			end
		end
	end
	return j
end

local function angulos(v: { number }?): CFrame
	if not v then
		return CFrame.identity
	end
	return CFrame.Angles(rad(v[1]), rad(v[2]), rad(v[3]))
end

-- tipo: "jogador" (tem animação do Roblox por baixo), "npc" (bot/boneco) ou "stand"
function Animador.registrar(modelo: Model, tipo: string?): any
	local a = anims[modelo]
	if a then
		return a
	end
	a = {
		modelo = modelo,
		tipo = tipo or "jogador",
		juntas = lerJuntas(modelo),
		clipe = nil,
		nome = nil,
		t = 0,
		vel = 1,
		peso = 0,
		pesoAlvo = 0,
		ate = nil,
		semente = math.random() * 100,
		ragdoll = 0,
		congelado = false,
		hitstop = 0,
		fase = 0,
		ultimo = {},
		boneco = modelo:GetAttribute("BB_Boneco") == true,
		temTrilhas = true,
		conferido = 0,
	}
	anims[modelo] = a
	modelo.Destroying:Connect(function()
		anims[modelo] = nil
	end)
	return a
end

function Animador.de(modelo: Model?): any
	if not modelo then
		return nil
	end
	return anims[modelo]
end

function Animador.atualizarJuntas(modelo: Model)
	local a = anims[modelo]
	if a then
		a.juntas = lerJuntas(modelo)
	end
end

-- toca um clipe. opcoes = { impacto (s): o golpe de verdade acontece nesse tempo, ate (os.clock), vel }
function Animador.tocar(modelo: Model?, nome: string?, opcoes: any?)
	if not modelo or not nome then
		return
	end
	local a = anims[modelo] or Animador.registrar(modelo)
	local clipe = Poses.clipe(nome)
	if not clipe then
		return
	end
	local o = opcoes or {}
	a.clipe = clipe
	a.nome = nome
	a.t = o.inicio or 0
	a.vel = o.vel or 1
	if o.impacto and clipe.impacto and o.impacto > 0.01 then
		a.vel = math.clamp(clipe.impacto / o.impacto, 0.35, 3)
	end
	a.ate = o.ate
	a.pesoAlvo = 1
	a.semente = math.random() * 100
end

function Animador.parar(modelo: Model?)
	local a = modelo and anims[modelo]
	if a then
		a.pesoAlvo = 0
		a.ate = nil
	end
end

function Animador.tocando(modelo: Model?): string?
	local a = modelo and anims[modelo]
	if a and a.pesoAlvo > 0 then
		return a.nome
	end
	return nil
end

function Animador.hitstop(modelo: Model?, dur: number)
	local a = modelo and anims[modelo]
	if a then
		a.hitstop = math.max(a.hitstop, os.clock() + dur)
	end
end

function Animador.pausarTudo(dur: number)
	pausaGlobal = math.max(pausaGlobal, os.clock() + dur)
end

-- camada de baixo dos bots e Stands: parado, andando, correndo, no ar
local function locomocao(a: any, dt: number): { [string]: { number } }
	local m = a.modelo
	if a.tipo == "stand" then
		local tt = os.clock()
		local base = Poses.P.cruzado_flutua
		local p = {}
		for k, v in base do
			p[k] = { v[1], v[2], v[3] }
		end
		p.Neck = { -6 + math.sin(tt * 1.3) * 3, math.sin(tt * 0.7) * 6, 0 }
		p.Waist = { 4 + math.sin(tt * 2) * 2, 0, 0 }
		return p
	end
	local raiz = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not raiz or not hum then
		return {}
	end
	local v = raiz.AssemblyLinearVelocity
	local plano = Vector3.new(v.X, 0, v.Z).Magnitude
	if a.boneco then
		return { Waist = { math.sin(os.clock() * 1.5) * 1, 0, 0 } }
	end
	local estado = hum:GetState()
	if estado == Enum.HumanoidStateType.Freefall or estado == Enum.HumanoidStateType.Jumping then
		return Poses.P.no_ar
	end
	local k = math.clamp(plano / 16, 0, 1.4)
	a.fase += dt * (4 + plano * 0.42)
	local s = math.sin(a.fase)
	local c = math.cos(a.fase)
	local resp = math.sin(os.clock() * 2) * 2 * (1 - math.min(k, 1))
	return {
		Waist = { -6 * k + resp, s * 6 * k, 0 },
		Neck = { 3 * k, -s * 4 * k, 0 },
		LS = { -s * 40 * k, 0, -6 }, LE = { 20 + 30 * k, 0, 0 },
		RS = { s * 40 * k, 0, 6 }, RE = { 20 + 30 * k, 0, 0 },
		LH = { s * 38 * k, 0, 0 }, LK = { -math.max(0, c) * 50 * k - 4, 0, 0 },
		RH = { -s * 38 * k, 0, 0 }, RK = { -math.max(0, -c) * 50 * k - 4, 0, 0 },
		Root = { -8 * math.min(k, 1), 0, 0 },
	}
end

local function ragdollPose(a: any): { [string]: { number } }
	local tt = os.clock() * 7 + a.semente
	local base = Poses.P.ragdoll
	local p = {}
	for kk, v in base do
		p[kk] = { v[1] + math.sin(tt + #kk) * 18, v[2], v[3] + math.cos(tt * 0.8 + #kk) * 14 }
	end
	return p
end

local function aplicar(a: any, dt: number)
	local agora = os.clock()
	if a.congelado then
		return -- tempo parado: fica exatamente como estava
	end
	local passo = dt
	if agora < a.hitstop or agora < pausaGlobal then
		passo = 0
	end
	-- avança o clipe
	local clipe = a.clipe
	if clipe then
		a.t += passo * a.vel
		local acabou = false
		if a.ate and agora >= a.ate then
			acabou = true
		elseif not a.ate and not clipe.segurar and clipe.dur and a.t >= clipe.dur then
			acabou = true
		end
		if acabou then
			a.pesoAlvo = 0
		end
	end
	local velPeso = if a.pesoAlvo > a.peso then 18 else 7
	a.peso += (a.pesoAlvo - a.peso) * math.min(1, dt * velPeso)
	if a.pesoAlvo == 0 and a.peso < 0.02 then
		a.peso = 0
		a.clipe = nil
		a.nome = nil
	end
	local acao: { [string]: { number } }? = nil
	local giro = 0
	if clipe and a.peso > 0 then
		if clipe.proc == "barragem" then
			acao = Poses.barragem(a.t, a.semente)
		elseif clipe.proc == "estocadas" then
			acao = Poses.estocadas(a.t)
		else
			acao, giro = Poses.amostrar(clipe, a.t)
		end
	end
	local ragdoll = a.ragdoll > 0
	local base = if a.tipo ~= "jogador" then locomocao(a, dt) else nil
	if ragdoll then
		acao = ragdollPose(a)
		giro = 0
	end
	local peso = if ragdoll then 1 else a.peso
	-- avatar sem nenhuma animação do Roblox tocando: nós cuidamos de todas as juntas
	if a.tipo == "jogador" and agora - a.conferido > 0.5 then
		a.conferido = agora
		local hum = a.modelo:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		local ok, trilhas = pcall(function()
			return if animator then #animator:GetPlayingAnimationTracks() else 0
		end)
		a.temTrilhas = ok and trilhas > 0
	end
	for curto, j in a.juntas do
		local m: Motor6D = j.motor
		local va = acao and acao[curto]
		local vb = base and base[curto]
		if a.tipo == "jogador" and a.temTrilhas then
			-- por cima da animação do Roblox: só mexe nas juntas que o golpe usa
			if va and peso > 0.001 then
				local alvo = angulos(va)
				if curto == "Root" and giro ~= 0 then
					alvo = alvo * CFrame.Angles(0, rad(giro), 0)
				end
				local cf = j.inv * alvo * j.rot0
				m.Transform = m.Transform:Lerp(cf, math.clamp(peso, 0, 1))
			elseif curto == "Root" and giro ~= 0 and peso > 0.001 then
				m.Transform = m.Transform * CFrame.Angles(0, rad(giro), 0)
			end
		else
			local alvo = angulos(vb)
			if va and peso > 0.001 then
				alvo = alvo:Lerp(angulos(va), math.clamp(peso, 0, 1))
			end
			if curto == "Root" and giro ~= 0 then
				alvo = alvo * CFrame.Angles(0, rad(giro * peso), 0)
			end
			m.Transform = j.inv * alvo * j.rot0
		end
	end
end

function Animador.passo(dt: number)
	for modelo, a in anims do
		if not modelo.Parent then
			continue
		end
		local ok, err = pcall(aplicar, a, dt)
		if not ok then
			warn("[BB] animação:", err)
			anims[modelo] = nil
		end
	end
end

function Animador.iniciar()
	RunService.PreSimulation:Connect(function(dt)
		Animador.passo(dt)
	end)
end

return Animador
