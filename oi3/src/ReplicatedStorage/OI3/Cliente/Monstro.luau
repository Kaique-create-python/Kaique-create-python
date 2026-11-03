-- OI3 :: O MONSTRO (AJUSTE-9) — "a sombra", agora grotesca
-- O corpo é um avatar do catálogo do Roblox (montado pelo servidor só com IDs: corpo alto e magro todo
-- preto com um sorriso cheio de dentes, braços extras saindo das costas e a espinha para fora).
-- O que dá medo é o MOVIMENTO, feito aqui por código, junta por junta (Motor6D.Transform):
--  * anda curvado e pesado como um dinossauro: corpo inclinado, cabeça esticada para a frente,
--    joelhos dobrados, braços compridos balançando, cada pisada faz o chão (e a câmera) tremer;
--  * se contorce: espasmos rápidos com ossos estalando — a cabeça vira de lado e de cabeça para baixo,
--    o cotovelo dobra para trás, a coluna torce;
--  * fareja, geme e espia pelas frestas dos esconderijos (ou de cabeça para baixo embaixo da cama).
-- Sons: só gravações reais (passos gigantes, ossos, gemidos, respiração nojenta, faro).
-- Funciona com corpo R15 (o normal) e, se o catálogo falhar, com o corpo R6 antigo (menos juntas).

local RunService = game:GetService("RunService")

local OI3 = script.Parent.Parent
local Personagens = require(OI3.Personagens)
local Som = require(script.Parent.Som)
local Medo = require(script.Parent.Medo)

local Monstro = {}
Monstro.__index = Monstro

local V3 = Vector3.new
local ANG = CFrame.Angles
local PI = math.pi

-- nomes das juntas no R15 e o equivalente no R6
local JUNTAS = {
	Root = { "Root", "Root Joint" },
	Waist = { "Waist" },
	Neck = { "Neck" },
	LeftShoulder = { "LeftShoulder", "Left Shoulder" },
	RightShoulder = { "RightShoulder", "Right Shoulder" },
	LeftElbow = { "LeftElbow" },
	RightElbow = { "RightElbow" },
	LeftWrist = { "LeftWrist" },
	RightWrist = { "RightWrist" },
	LeftHip = { "LeftHip", "Left Hip" },
	RightHip = { "RightHip", "Right Hip" },
	LeftKnee = { "LeftKnee" },
	RightKnee = { "RightKnee" },
	LeftAnkle = { "LeftAnkle" },
	RightAnkle = { "RightAnkle" },
}

local function difAngulo(a: number, b: number): number
	local d = (b - a) % (2 * PI)
	if d > PI then
		d -= 2 * PI
	end
	return d
end

local function yawPara(de: Vector3, para: Vector3): number?
	local d = V3(para.X - de.X, 0, para.Z - de.Z)
	if d.Magnitude < 0.01 then
		return nil
	end
	return math.atan2(-d.X, -d.Z)
end

local function suave(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- função pura (testável): pose = soma de camadas {rx, ry, rz} por junta
function Monstro.somar(a: { [string]: { number } }, b: { [string]: { number } }, peso: number): { [string]: { number } }
	local out = table.clone(a)
	for j, v in b do
		local base = out[j] or { 0, 0, 0, 0 }
		out[j] = { base[1] + v[1] * peso, base[2] + v[2] * peso, base[3] + v[3] * peso, (base[4] or 0) + (v[4] or 0) * peso }
	end
	return out
end

-- POSES BASE (ângulos em radianos no espaço da peça "pai": X = direita, Y = cima, -Z = frente)
-- rx < 0 = inclina para a frente / olha para baixo; rx > 0 no ombro/quadril = braço/coxa para a frente;
-- rx < 0 no joelho = dobra; [4] = descida do corpo (só na raiz, em "alturas" do monstro)
local POSE_DINO = {
	Root = { -0.2, 0, 0, -0.05 },
	Waist = { -0.5, 0, 0.06 },
	Neck = { 0.62, 0, 0.22 },
	LeftShoulder = { 0.5, 0, -0.14 },
	RightShoulder = { 0.62, 0, 0.1 },
	LeftElbow = { 0.42, 0, 0 },
	RightElbow = { 0.2, 0, 0 },
	LeftWrist = { 0.35, 0, 0 },
	RightWrist = { 0.6, 0, 0 },
	LeftHip = { 0.62, 0, -0.06 },
	RightHip = { 0.55, 0, 0.06 },
	LeftKnee = { -1.0, 0, 0 },
	RightKnee = { -0.92, 0, 0 },
	LeftAnkle = { 0.34, 0, 0 },
	RightAnkle = { 0.3, 0, 0 },
}

-- espiar por uma fresta (armário): em pé, curvado, cabeça deitada de lado contra a porta
local POSE_FRESTA = {
	Root = { -0.12, 0, 0, -0.04 },
	Waist = { -0.38, 0, 0.12 },
	Neck = { 0.4, 0, 1.45 },
	LeftShoulder = { 1.9, 0, -0.35 },
	RightShoulder = { 1.6, 0, 0.45 },
	LeftElbow = { 0.6, 0, 0 },
	RightElbow = { 0.95, 0, 0 },
	LeftWrist = { -0.6, 0, 0 },
	RightWrist = { -0.4, 0, 0 },
	LeftHip = { 0.5, 0, -0.1 },
	RightHip = { 0.35, 0, 0.12 },
	LeftKnee = { -0.85, 0, 0 },
	RightKnee = { -0.7, 0, 0 },
	LeftAnkle = { 0.3, 0, 0 },
	RightAnkle = { 0.3, 0, 0 },
}

-- espiar embaixo da cama: de quatro, corpo quase no chão, cabeça DE CABEÇA PARA BAIXO
local POSE_CHAO = {
	Root = { -1.05, 0, 0, -0.42 },
	Waist = { -0.45, 0, 0 },
	Neck = { 1.3, 0, 2.95 },
	LeftShoulder = { 2.3, 0, -0.3 },
	RightShoulder = { 2.4, 0, 0.3 },
	LeftElbow = { 0.3, 0, 0 },
	RightElbow = { 0.45, 0, 0 },
	LeftWrist = { 0.9, 0, 0 },
	RightWrist = { 0.9, 0, 0 },
	LeftHip = { 2.0, 0, -0.2 },
	RightHip = { 2.0, 0, 0.2 },
	LeftKnee = { -2.2, 0, 0 },
	RightKnee = { -2.2, 0, 0 },
	LeftAnkle = { 0.6, 0, 0 },
	RightAnkle = { 0.6, 0, 0 },
}

-- espiar o baú: debruçado por cima, a cabeça desce torta até a frente do baú
local POSE_BAU = {
	Root = { -0.45, 0, 0, -0.12 },
	Waist = { -0.85, 0, 0.2 },
	Neck = { 0.1, 0, -1.2 },
	LeftShoulder = { 1.3, 0, -0.3 },
	RightShoulder = { 1.0, 0, 0.3 },
	LeftElbow = { 1.1, 0, 0 },
	RightElbow = { 0.8, 0, 0 },
	LeftWrist = { 0.5, 0, 0 },
	RightWrist = { 0.5, 0, 0 },
	LeftHip = { 0.9, 0, -0.1 },
	RightHip = { 0.8, 0, 0.1 },
	LeftKnee = { -1.2, 0, 0 },
	RightKnee = { -1.1, 0, 0 },
	LeftAnkle = { 0.35, 0, 0 },
	RightAnkle = { 0.35, 0, 0 },
}

-- investida (o susto): ergue o corpo, braços abertos para a frente, cabeça para cima e torta
local POSE_INVESTIDA = {
	Root = { 0.05, 0, 0, 0.05 },
	Waist = { -0.15, 0, -0.1 },
	Neck = { 0.35, 0.2, 0.55 },
	LeftShoulder = { 2.0, 0, -0.75 },
	RightShoulder = { 2.15, 0, 0.8 },
	LeftElbow = { 0.25, 0, 0 },
	RightElbow = { 0.15, 0, 0 },
	LeftWrist = { -0.9, 0, 0 },
	RightWrist = { -0.9, 0, 0 },
	LeftHip = { 0.35, 0, -0.15 },
	RightHip = { 0.1, 0, 0.15 },
	LeftKnee = { -0.6, 0, 0 },
	RightKnee = { -0.3, 0, 0 },
	LeftAnkle = { 0.2, 0, 0 },
	RightAnkle = { 0.2, 0, 0 },
}

local POSES = { dino = POSE_DINO, fresta = POSE_FRESTA, chao = POSE_CHAO, bau = POSE_BAU, investida = POSE_INVESTIDA }
Monstro.POSES = POSES

-- a cabeça mira o alvo (o rosto de quem está escondido) torta deste jeito (rolagem em radianos):
-- deitada de lado na fresta, de cabeça para baixo embaixo da cama, torta no baú
local ROLAGEM = { fresta = 1.45, chao = 2.95, bau = -1.2, investida = 0.5 }
Monstro.ROLAGEM = ROLAGEM

-- tipos de espasmo: junta → impulso {rx, ry, rz} (sorteado com sinal e força)
local ESPASMOS = {
	{ { "Neck", 0.5, 0.9, 1.4 } },
	{ { "Neck", -0.6, -0.7, -1.2 } },
	{ { "Waist", 0.2, 0.9, 0.45 } },
	{ { "LeftShoulder", -1.5, 0, -0.6 }, { "LeftElbow", -1.1, 0, 0 } },
	{ { "RightShoulder", -1.4, 0, 0.7 }, { "RightElbow", -1.2, 0, 0 } },
	{ { "LeftWrist", 1.5, 0, 0.4 } },
	{ { "RightWrist", -1.4, 0, -0.5 } },
	{ { "Neck", 0, 2.6, 0.2 } }, -- a cabeça gira quase para trás
	{ { "Waist", -0.45, -0.7, -0.5 }, { "Neck", 0.4, 0.5, 1.0 } },
	{ { "LeftKnee", 0.9, 0, 0 } },
}

function Monstro.novo(pasta: Instance, posPes: Vector3, olhar: Vector3?)
	local self = setmetatable({}, Monstro)
	local modelo = Personagens.criarCriatura()
	self.codigo = "CRIATURA"
	self.modelo = modelo
	self.raiz = modelo.PrimaryPart :: BasePart
	self.r15 = modelo:FindFirstChild("UpperTorso") ~= nil
	self.cabecaParte = modelo:FindFirstChild("Head") :: BasePart?
	self.tronco = (modelo:FindFirstChild("UpperTorso") or modelo:FindFirstChild("Torso")) :: BasePart?
	self.pesoMira = 0
	self.pos = posPes
	self.yaw = 0
	self.movimento = nil :: any
	self.giro = nil :: any
	self.aoPasso = nil :: any -- (compatível com o Ator antigo; o monstro faz as próprias pisadas)
	self.fase = 0
	self.ultimaPos = posPes
	self.tempo = 0
	self.ultimoQuadro = os.clock()
	self.andandoExterno = false
	self.poseNome = "dino"
	self.poseAnterior = "dino"
	self.misturaPose = 1
	self.espasmos = {} :: { any }
	self.proximoEspasmo = os.clock() + 1 + math.random() * 2
	self.contorcendoAte = 0
	self.espiada = nil :: any
	self.ajuste = Vector3.zero
	self.olharCabeca = nil :: Vector3?
	self.proximoFaro = 0
	self.destruido = false
	if olhar then
		self.yaw = yawPara(posPes, olhar) or 0
	end
	-- medidas do corpo (antes de mexer em qualquer junta)
	local raiz = self.raiz
	local fundo = math.huge
	local topo = -math.huge
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") and p ~= raiz and not p:FindFirstAncestorOfClass("Accessory") then
			local meia = p.Size.Y / 2
			fundo = math.min(fundo, p.CFrame.Position.Y - meia)
			topo = math.max(topo, p.CFrame.Position.Y + meia)
		end
	end
	if fundo == math.huge then
		fundo = raiz.CFrame.Position.Y - 3
		topo = raiz.CFrame.Position.Y + 2
	end
	self.altura = math.max(raiz.CFrame.Position.Y - fundo, 1) -- da raiz até a sola
	self.alturaTotal = math.max(topo - fundo, 3)
	self.escala = self.alturaTotal / 5.2
	-- juntas
	self.juntas = {}
	for nome, opcoes in JUNTAS do
		for _, n in opcoes do
			local m = modelo:FindFirstChild(n, true)
			if m and m:IsA("Motor6D") then
				self.juntas[nome] = { motor = m, rot0 = m.C0.Rotation }
				break
			end
		end
	end
	local hum = modelo:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum.EvaluateStateMachine = false
		end)
		-- nenhuma animação pronta: quem mexe as juntas é este módulo
		local animador = hum:FindFirstChildOfClass("Animator")
		if animador then
			animador:Destroy()
		end
	end
	modelo.Parent = pasta
	self:detalhes()
	self:aplicar(0)
	-- respiração nojenta sempre (3D, presa no corpo) e um rosnado baixo que cresce quando ele espia
	self.respira = Som.tocar("respira_monstro", { pai = raiz, volume = 0.85, loop = true, alcance = 45, minimo = 5 })
	self.rosnado = Som.tocar("rosnado", { pai = raiz, volume = 0, loop = true, alcance = 35, minimo = 4 })
	Medo.registrar(self)
	return self
end

-- detalhes que só existem no jogo: luz fraca no rosto (dá para ver o sorriso no escuro), uma névoa preta
-- saindo do corpo ("a sombra") e uma baba escura pingando da boca
function Monstro:detalhes()
	local cab = self.cabecaParte
	local s = self.escala
	if cab then
		local luz = Instance.new("PointLight")
		luz.Name = "OI3_LuzRosto"
		luz.Range = 7 * s
		luz.Brightness = 0.45
		luz.Color = Color3.fromRGB(255, 236, 222)
		luz.Shadows = false
		luz.Parent = cab
		local boca = Instance.new("Attachment")
		boca.Name = "OI3_Boca"
		boca.Position = V3(0, -0.25 * cab.Size.Y, -0.45 * cab.Size.Z)
		boca.Parent = cab
		local baba = Instance.new("ParticleEmitter")
		baba.Name = "OI3_Baba"
		baba.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		baba.Color = ColorSequence.new(Color3.fromRGB(18, 10, 10))
		baba.LightEmission = 0
		baba.LightInfluence = 1
		baba.Size = NumberSequence.new(0.07 * s, 0.03 * s)
		baba.Transparency = NumberSequence.new(0.1, 0.6)
		baba.Lifetime = NumberRange.new(0.5, 0.9)
		baba.Rate = 5
		baba.Speed = NumberRange.new(0.1, 0.4)
		baba.Acceleration = V3(0, -28, 0)
		baba.SpreadAngle = Vector2.new(12, 12)
		baba.Parent = boca
	end
	local tronco = self.modelo:FindFirstChild("UpperTorso") or self.modelo:FindFirstChild("Torso")
	if tronco and tronco:IsA("BasePart") then
		local nevoa = Instance.new("ParticleEmitter")
		nevoa.Name = "OI3_Sombra"
		nevoa.Texture = "rbxasset://textures/particles/smoke_main.dds"
		nevoa.Color = ColorSequence.new(Color3.fromRGB(4, 4, 6))
		nevoa.LightEmission = 0
		nevoa.LightInfluence = 0.2
		nevoa.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * s), NumberSequenceKeypoint.new(1, 3.2 * s) })
		nevoa.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.82), NumberSequenceKeypoint.new(1, 1) })
		nevoa.Lifetime = NumberRange.new(1.6, 2.6)
		nevoa.Rate = 7
		nevoa.Speed = NumberRange.new(0.3, 0.9)
		nevoa.SpreadAngle = Vector2.new(180, 180)
		nevoa.Rotation = NumberRange.new(0, 360)
		nevoa.RotSpeed = NumberRange.new(-20, 20)
		nevoa.Parent = tronco
	end
end

---------------------------------------------------------------------------
-- compatível com o Ator (o resto do jogo usa o monstro como um ator)
---------------------------------------------------------------------------
function Monstro:cframe(): CFrame
	local quedaRaiz = 0
	return CFrame.new(self.pos + V3(0, self.altura + quedaRaiz, 0) + self.ajuste) * ANG(0, self.yaw, 0)
end

function Monstro:cabeca(): Vector3
	local c = self.cabecaParte
	if c and c.Parent then
		return c.CFrame.Position
	end
	return self.pos + V3(0, self.alturaTotal * 0.85, 0)
end

function Monstro:posicionar(posPes: Vector3, olhar: Vector3?)
	self.pos = posPes
	self.ultimaPos = posPes
	if olhar then
		self.yaw = yawPara(posPes, olhar) or self.yaw
	end
	self.movimento = nil
	self.giro = nil
	self:aplicar(0)
end

function Monstro:andar(destino: Vector3, velocidade: number?, deCostas: boolean?): number
	local v = velocidade or 4.5
	local de = self.pos
	local para = V3(destino.X, de.Y, destino.Z)
	local dist = (para - de).Magnitude
	if dist < 0.05 then
		return 0
	end
	local yaw = yawPara(de, para) or self.yaw
	if deCostas then
		yaw = self.yaw
	end
	self.movimento = { de = de, para = para, t0 = os.clock(), dur = dist / v, yaw = yaw, costas = deCostas }
	return dist / v
end

function Monstro:virar(alvo: Vector3, tempo: number?)
	local yaw = yawPara(self.pos, alvo)
	if not yaw then
		return
	end
	self.giro = { de = self.yaw, para = self.yaw + difAngulo(self.yaw, yaw), t0 = os.clock(), dur = tempo or 0.45 }
end

-- "andar" vindo de fora (a presença do porão muda .pos a cada quadro)
function Monstro:tocar(nome: string)
	if nome == "andar" then
		self.andandoExterno = true
	end
end

function Monstro:parar(nome: string)
	if nome == "andar" then
		self.andandoExterno = false
	end
end

function Monstro:gesto(_nome: string)
	self:contorcer(1.6)
end

function Monstro:expressao(_nome: string) end

function Monstro:visivel(sim: boolean)
	for _, p in self.modelo:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.LocalTransparencyModifier = if sim then 0 else 1
		elseif p:IsA("ParticleEmitter") or p:IsA("Light") then
			p.Enabled = sim
		end
	end
end

---------------------------------------------------------------------------
-- comportamentos
---------------------------------------------------------------------------
local function somNoCorpo(self, nome: string, volume: number, velocidade: number?)
	local alvo = self.cabecaParte or self.raiz
	if alvo and alvo.Parent then
		return Som.tocar(nome, { pai = alvo, volume = volume, velocidade = velocidade, alcance = 60, minimo = 5 })
	end
	return nil
end

function Monstro:espasmo(forca: number?)
	local f = forca or 1
	local tipo = ESPASMOS[math.random(1, #ESPASMOS)]
	local agora = os.clock()
	local sinal = if math.random() < 0.5 then -1 else 1
	for _, j in tipo do
		local k = (0.65 + math.random() * 0.5) * f
		table.insert(self.espasmos, {
			junta = j[1],
			v = { j[2] * k * sinal, j[3] * k * sinal, j[4] * k * sinal },
			t0 = agora,
			ataque = 0.04 + math.random() * 0.05,
			segura = 0.08 + math.random() * 0.35,
			solta = 0.35 + math.random() * 0.6,
		})
	end
	if f > 0.5 then
		somNoCorpo(self, "osso", 0.9 + 0.3 * f, 0.85 + math.random() * 0.3)
	end
end

-- contorce o corpo inteiro por um tempo (espasmos seguidos, ossos estalando, gemido)
function Monstro:contorcer(dur: number)
	self.contorcendoAte = math.max(self.contorcendoAte, os.clock() + dur)
	somNoCorpo(self, "contorcer", 1.1, 0.9 + math.random() * 0.2)
	if math.random() < 0.7 then
		self:gemer()
	end
end

function Monstro:gemer()
	somNoCorpo(self, "gemido", 1.2, 0.82 + math.random() * 0.2)
end

function Monstro:farejar()
	somNoCorpo(self, "farejar", 1.1, 0.85 + math.random() * 0.2)
end

function Monstro:gritar()
	somNoCorpo(self, "grito_monstro", 1.5, 0.9 + math.random() * 0.15)
end

-- espia um esconderijo: a cabeça vai até "alvo" (bem na fresta) olhando para "olhar"
-- tipo: "fresta" (armário), "chao" (embaixo da cama) ou "bau"
function Monstro:espiar(alvo: Vector3, olhar: Vector3, tipo: string, dur: number)
	self.movimento = nil
	self.espiada = { alvo = alvo, olhar = olhar, tipo = tipo, t0 = os.clock(), dur = dur }
	self.poseAnterior = self.poseNome
	self.poseNome = if POSES[tipo] then tipo else "fresta"
	self.misturaPose = 0
	self.proximoFaro = os.clock() + 0.6
	if self.rosnado then
		Som.mudarVolume(self.rosnado, 0.9, 0.8)
	end
	if tipo == "fresta" or tipo == "bau" then
		somNoCorpo(self, "madeira_tensao", 0.9)
	else
		somNoCorpo(self, "queda", 1)
	end
end

function Monstro:pararEspiar()
	if not self.espiada then
		return
	end
	self.espiada = nil
	self.poseAnterior = self.poseNome
	self.poseNome = "dino"
	self.misturaPose = 0
	self.olharCabeca = nil
	if self.rosnado then
		Som.mudarVolume(self.rosnado, 0, 1.2)
	end
	self:espasmo(1.2)
end

-- o susto: ergue o corpo e avança (o rosto vira para a câmera)
function Monstro:investida()
	local cam = workspace.CurrentCamera
	self.olharCabeca = cam and cam.CFrame.Position or nil
	self.poseAnterior = self.poseNome
	self.poseNome = "investida"
	self.misturaPose = 0
	self:gritar()
	self:contorcer(0.8)
end

---------------------------------------------------------------------------
-- a cada quadro
---------------------------------------------------------------------------
function Monstro:pose(nome: string, cf: CFrame)
	local j = self.juntas[nome]
	if j then
		j.motor.Transform = j.rot0:Inverse() * cf * j.rot0
	end
end

-- aplica a pose (camadas: base → andar → espiar → espasmos)
function Monstro:aplicar(dt: number)
	local agora = os.clock()
	self.tempo += dt
	local t = self.tempo
	local s = self.escala

	-- mistura entre a pose anterior e a atual
	self.misturaPose = math.min(1, self.misturaPose + dt * (if self.poseNome == "investida" then 6 else 1.6))
	local m = suave(self.misturaPose)
	local base = Monstro.somar(Monstro.somar({}, POSES[self.poseAnterior] or POSE_DINO, 1 - m), POSES[self.poseNome] or POSE_DINO, m)

	-- ANDAR: fase pela distância percorrida (vale para o andar interno e para quem move .pos de fora)
	local desloc = V3(self.pos.X - self.ultimaPos.X, 0, self.pos.Z - self.ultimaPos.Z).Magnitude
	self.ultimaPos = self.pos
	local passada = 2.6 * s
	local faseAntes = self.fase
	if desloc > 0 then
		self.fase += desloc / passada * 2 * PI
	end
	local andando = desloc / math.max(dt, 1 / 240) > 0.6 or self.andandoExterno
	self.ampAndar = (self.ampAndar or 0) + ((if andando then 1 else 0) - (self.ampAndar or 0)) * math.min(1, dt * 5)
	local a = self.ampAndar * (1 - (if self.espiada then 1 else 0))
	local f = self.fase
	local fE, fD = f, f + PI
	local andar = {
		LeftHip = { 0.5 * math.sin(fE), 0, 0 },
		RightHip = { 0.5 * math.sin(fD), 0, 0 },
		LeftKnee = { -0.85 * math.max(0, math.cos(fE)), 0, 0 },
		RightKnee = { -0.85 * math.max(0, math.cos(fD)), 0, 0 },
		LeftAnkle = { 0.4 * math.max(0, math.cos(fE)), 0, 0 },
		RightAnkle = { 0.4 * math.max(0, math.cos(fD)), 0, 0 },
		Root = { 0.05 * math.cos(2 * f), 0.06 * math.sin(f), 0.09 * math.sin(f), -0.045 * (1 - math.abs(math.cos(f))) },
		Waist = { 0.06 * math.cos(2 * f), -0.16 * math.sin(f), -0.07 * math.sin(f) },
		Neck = { 0.14 * math.cos(2 * f + 0.6), 0.12 * math.sin(f), 0.05 * math.sin(f) },
		LeftShoulder = { 0.32 * math.sin(fD + 0.5), 0, -0.05 * math.sin(f) },
		RightShoulder = { 0.32 * math.sin(fE + 0.5), 0, 0.05 * math.sin(f) },
		LeftElbow = { 0.25 * math.max(0, math.sin(fD + 1.2)), 0, 0 },
		RightElbow = { 0.25 * math.max(0, math.sin(fE + 1.2)), 0, 0 },
		LeftWrist = { 0.3 * math.sin(fD + 1.8), 0, 0 },
		RightWrist = { 0.3 * math.sin(fE + 1.8), 0, 0 },
	}
	base = Monstro.somar(base, andar, a)
	-- pisadas: quando um pé chega na frente e desce (fase cruza π/2)
	if a > 0.3 and desloc > 0 then
		local function cruzou(f0: number, f1: number): boolean
			return math.floor((f0 - PI / 2) / (2 * PI)) ~= math.floor((f1 - PI / 2) / (2 * PI))
		end
		if cruzou(faseAntes, self.fase) or cruzou(faseAntes + PI, self.fase + PI) then
			self:pisar()
		end
	end

	-- respiração parada: o peito sobe e desce, a cabeça procura (com trancos)
	local resp = math.sin(t * 2.1)
	base = Monstro.somar(base, {
		Waist = { 0.04 * resp, 0, 0 },
		Neck = { 0.06 * math.noise(t * 0.9, 1.3), 0.35 * math.noise(t * 0.45, 7.1), 0.25 * math.noise(t * 0.6, 3.3) },
		LeftShoulder = { 0.05 * resp, 0, 0 },
		RightShoulder = { 0.05 * resp, 0, 0 },
	}, 1)

	-- ESPIAR: a cabeça vai até a fresta (o corpo inteiro se ajusta) e olha para dentro
	local e = self.espiada
	if e then
		local k = (agora - e.t0)
		if k > 0.5 and agora >= self.proximoFaro then
			self.proximoFaro = agora + 1.1 + math.random() * 0.9
			if math.random() < 0.6 then
				self:farejar()
			else
				self:espasmo(0.55)
			end
		end
		-- realimentação: empurra o corpo até a cabeça chegar no ponto certo
		local cab = self.cabecaParte
		if cab and cab.Parent and dt > 0 then
			local erro = e.alvo - cab.CFrame.Position
			local passoAjuste = erro * math.min(1, dt * 3.2)
			local novo = self.ajuste + passoAjuste
			local h = V3(novo.X, 0, novo.Z)
			if h.Magnitude > 4.5 then
				h = h.Unit * 4.5
			end
			self.ajuste = V3(h.X, math.clamp(novo.Y, -self.alturaTotal * 0.75, 2.5), h.Z)
		end
	else
		-- volta o corpo para o lugar
		self.ajuste = self.ajuste:Lerp(Vector3.zero, math.min(1, dt * 2.5))
	end

	-- CONTORCER: espasmos em sequência + tremedeira
	local contorcendo = agora < self.contorcendoAte
	if contorcendo then
		if agora >= self.proximoEspasmo then
			self.proximoEspasmo = agora + 0.12 + math.random() * 0.22
			self:espasmo(1.15)
		end
		base = Monstro.somar(base, {
			Waist = { 0.25 * math.sin(t * 5.3), 0.5 * math.sin(t * 3.1), 0.3 * math.sin(t * 4.2) },
			Neck = { 0, 0.4 * math.sin(t * 6.7), 1.3 * math.sin(t * 2.3) },
			LeftShoulder = { 0.9 + 0.6 * math.sin(t * 7.1), 0, -0.5 },
			RightShoulder = { 1.2 + 0.5 * math.sin(t * 6.3), 0, 0.6 },
			LeftElbow = { -0.9, 0, 0 },
			RightElbow = { -0.7 + 0.4 * math.sin(t * 9), 0, 0 },
			Root = { 0.03 * math.sin(t * 31), 0, 0.03 * math.sin(t * 27), 0 },
		}, 1)
	elseif agora >= self.proximoEspasmo then
		-- espasmo de vez em quando, mesmo andando
		self.proximoEspasmo = agora + (if e then 0.9 + math.random() * 1.4 else 1.8 + math.random() * 3)
		self:espasmo(if e then 0.8 else 0.7)
	end

	-- ESPASMOS ativos (sobem rápido, seguram, voltam devagar)
	local vivos = {}
	local extra: { [string]: { number } } = {}
	for _, sp in self.espasmos do
		local d = agora - sp.t0
		local fim = sp.ataque + sp.segura + sp.solta
		if d < fim then
			table.insert(vivos, sp)
			local k
			if d < sp.ataque then
				k = d / sp.ataque
			elseif d < sp.ataque + sp.segura then
				k = 1
			else
				k = 1 - suave((d - sp.ataque - sp.segura) / sp.solta)
			end
			local b = extra[sp.junta] or { 0, 0, 0 }
			extra[sp.junta] = { b[1] + sp.v[1] * k, b[2] + sp.v[2] * k, b[3] + sp.v[3] * k }
		end
	end
	self.espasmos = vivos
	local extraPescoco = extra.Neck
	extra.Neck = nil
	base = Monstro.somar(base, extra, 1)

	-- MIRA DA CABEÇA: espiando (ou no susto), o rosto vira para quem está escondido, torto
	local alvoOlhar = (e and e.olhar) or self.olharCabeca
	local cab = self.cabecaParte
	local tronco = self.tronco
	self.pesoMira += ((if alvoOlhar then 1 else 0) - self.pesoMira) * math.min(1, dt * 2.4)
	local pescoco = base.Neck or { 0, 0, 0 }
	local neckCF = ANG(pescoco[1], pescoco[2], pescoco[3])
	if alvoOlhar and cab and tronco and self.pesoMira > 0.01 then
		local dir = alvoOlhar - cab.CFrame.Position
		if dir.Magnitude > 0.2 then
			local dl = tronco.CFrame:VectorToObjectSpace(dir.Unit)
			local rol = (ROLAGEM[self.poseNome] or 0) + math.sin(t * 0.8) * 0.3 + math.noise(t * 3.1, 9.9) * 0.22
			local mira = CFrame.lookAt(Vector3.zero, dl) * ANG(0, 0, rol)
			neckCF = neckCF:Lerp(mira, self.pesoMira)
		end
	end
	if extraPescoco then
		neckCF = neckCF * ANG(extraPescoco[1] * 0.7, extraPescoco[2] * 0.7, extraPescoco[3] * 0.7)
	end

	-- MOVIMENTO e GIRO (como o Ator)
	local mv = self.movimento
	if mv then
		local k = math.clamp((agora - mv.t0) / mv.dur, 0, 1)
		self.pos = mv.de:Lerp(mv.para, k)
		if not mv.costas then
			self.yaw = self.yaw + difAngulo(self.yaw, mv.yaw) * math.min(1, dt * 6)
		end
		if k >= 1 then
			self.movimento = nil
		end
	end
	local g = self.giro
	if g then
		local k = math.clamp((agora - g.t0) / g.dur, 0, 1)
		self.yaw = g.de + (g.para - g.de) * suave(k)
		if k >= 1 then
			self.giro = nil
		end
	end

	-- aplica nas juntas
	for nome, v in base do
		if nome == "Root" then
			local queda = (v[4] or 0) * self.alturaTotal
			self:pose("Root", CFrame.new(0, queda, 0) * ANG(v[1], v[2], v[3]))
		elseif nome ~= "Neck" then
			self:pose(nome, ANG(v[1], v[2], v[3]))
		end
	end
	self:pose("Neck", neckCF)
	-- no R6 não existe cintura: a inclinação dela vai para a raiz
	if not self.r15 and base.Waist then
		local r, w = base.Root or { 0, 0, 0, 0 }, base.Waist
		self:pose("Root", CFrame.new(0, (r[4] or 0) * self.alturaTotal, 0) * ANG(r[1] + w[1], r[2] + w[2], r[3] + w[3]))
	end
	self.raiz.CFrame = self:cframe()
end

-- uma pisada pesada: som gravado de passo gigante + chão rangendo + a câmera de quem está perto treme
function Monstro:pisar()
	local r = self.raiz
	Som.tocar("passo_monstro", { pai = r, volume = 1.25, velocidade = 0.88 + math.random() * 0.16, alcance = 95, minimo = 9 })
	if math.random() < 0.3 then
		Som.tocar(if math.random() < 0.5 then "estalo1" else "estalo2", { pai = r, volume = 0.8, velocidade = 0.7 + math.random() * 0.2, alcance = 40 })
	end
	Medo.pisada(self.pos, 1)
	if self.aoPassoExtra then
		self.aoPassoExtra(self)
	end
end

function Monstro:passo()
	if self.destruido or not self.raiz.Parent then
		return
	end
	local agora = os.clock()
	local dt = math.min(agora - self.ultimoQuadro, 0.1)
	self.ultimoQuadro = agora
	self:aplicar(dt)
end

-- este monstro não embaça a câmera nem acelera o coração (cutscene e o susto, onde precisa ver bem)
function Monstro:semMedo()
	Medo.remover(self)
end

function Monstro:destruir()
	if self.destruido then
		return
	end
	self.destruido = true
	Medo.remover(self)
	for _, s in { self.respira, self.rosnado } do
		if s then
			s:Destroy()
		end
	end
	self.modelo:Destroy()
end

-- compatível com o Ator: reflexos não existem para o monstro (ele É o reflexo)
function Monstro:criarReflexo()
	return nil
end
function Monstro:removerReflexos() end

local _ = RunService
return Monstro
