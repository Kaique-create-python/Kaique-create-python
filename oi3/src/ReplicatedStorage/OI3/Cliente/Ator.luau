-- OI3 :: atores da cutscene (personagens locais, raiz ancorada, clipes R6 prontos)

local OI3 = script.Parent.Parent
local Animacoes = require(OI3.Animacoes)
local Personagens = require(OI3.Personagens)
local Construtor = require(OI3.Construtor)
local Moveis = require(OI3.Moveis)

local Ator = {}
Ator.__index = Ator

local PRIORIDADE = {
	parado = Enum.AnimationPriority.Idle,
	parado2 = Enum.AnimationPriority.Idle,
	andar = Enum.AnimationPriority.Movement,
	rir = Enum.AnimationPriority.Action,
	apontar = Enum.AnimationPriority.Action,
	acenar = Enum.AnimationPriority.Action,
	segurar = Enum.AnimationPriority.Action,
	pular = Enum.AnimationPriority.Action,
}
local EM_LOOP = { parado = true, parado2 = true, andar = true, segurar = true }

local function carregar(modelo: Model): { [string]: AnimationTrack }
	local hum = modelo:FindFirstChildOfClass("Humanoid")
	local animador = hum and hum:FindFirstChildOfClass("Animator")
	local trilhas = {}
	if not animador then
		return trilhas
	end
	for nome, id in Animacoes do
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, tr = pcall(function()
			return animador:LoadAnimation(a)
		end)
		if ok and tr then
			tr.Priority = PRIORIDADE[nome] or Enum.AnimationPriority.Action
			tr.Looped = EM_LOOP[nome] == true
			trilhas[nome] = tr
		end
	end
	return trilhas
end

local function difAngulo(a: number, b: number): number
	local d = (b - a) % (2 * math.pi)
	if d > math.pi then
		d -= 2 * math.pi
	end
	return d
end

local function yawPara(de: Vector3, para: Vector3): number?
	local d = Vector3.new(para.X - de.X, 0, para.Z - de.Z)
	if d.Magnitude < 0.01 then
		return nil
	end
	return math.atan2(-d.X, -d.Z)
end

function Ator.novo(codigo: string, pasta: Instance, posPes: Vector3, olhar: Vector3?)
	local self = setmetatable({}, Ator)
	local modelo = if codigo == "CRIATURA" then Personagens.criarCriatura() else Personagens.criar(codigo)
	self.codigo = codigo
	self.modelo = modelo
	self.raiz = modelo.PrimaryPart :: BasePart
	self.escala = modelo:GetAttribute("Escala") or 1
	self.altura = 3 * self.escala
	self.pos = posPes
	self.yaw = 0
	self.movimento = nil :: any
	self.giro = nil :: any
	self.corpos = {}
	self.proximoPiscar = os.clock() + 1 + math.random() * 2
	self.ultimoPasso = 0
	self.aoPasso = nil :: ((Ator) -> ())?
	if olhar then
		self.yaw = yawPara(posPes, olhar) or 0
	end
	modelo.Parent = pasta
	self:aplicar()
	self.trilhas = carregar(modelo)
	table.insert(self.corpos, { modelo = modelo, trilhas = self.trilhas })
	self:tocar("parado", 0)
	return self
end

function Ator:cframe(): CFrame
	return CFrame.new(self.pos + Vector3.new(0, self.altura, 0)) * CFrame.Angles(0, self.yaw, 0)
end

function Ator:cabeca(): Vector3
	return self.pos + Vector3.new(0, 4.5 * self.escala, 0)
end

function Ator:aplicar()
	local cf = self:cframe()
	self.raiz.CFrame = cf
	for i = 2, #self.corpos do
		local c = self.corpos[i]
		if c.refletir and c.modelo.PrimaryPart then
			c.modelo.PrimaryPart.CFrame = c.refletir(cf)
		end
	end
end

function Ator:posicionar(posPes: Vector3, olhar: Vector3?)
	self.pos = posPes
	if olhar then
		self.yaw = yawPara(posPes, olhar) or self.yaw
	end
	self.movimento = nil
	self.giro = nil
	self:parar("andar", 0)
	self:aplicar()
end

function Ator:tocar(nome: string, fade: number?, velocidade: number?)
	for _, c in self.corpos do
		local tr = c.trilhas[nome]
		if tr then
			if not tr.IsPlaying then
				tr:Play(fade or 0.2)
			end
			if velocidade then
				tr:AdjustSpeed(velocidade)
			end
		end
	end
end

function Ator:parar(nome: string, fade: number?)
	for _, c in self.corpos do
		local tr = c.trilhas[nome]
		if tr and tr.IsPlaying then
			tr:Stop(fade or 0.2)
		end
	end
end

-- Toca um clipe uma vez (rir, acenar, apontar)
function Ator:gesto(nome: string, velocidade: number?)
	for _, c in self.corpos do
		local tr = c.trilhas[nome]
		if tr then
			tr:Stop(0)
			tr:Play(0.15)
			if velocidade then
				tr:AdjustSpeed(velocidade)
			end
		end
	end
end

function Ator:expressao(nome: string)
	for _, c in self.corpos do
		Personagens.expressao(c.modelo, nome)
	end
end

-- Anda em linha reta até o destino. Retorna a duração.
function Ator:andar(destino: Vector3, velocidade: number?, deCostas: boolean?): number
	local v = velocidade or 4.5
	local de = self.pos
	local para = Vector3.new(destino.X, de.Y, destino.Z)
	local dist = (para - de).Magnitude
	if dist < 0.05 then
		return 0
	end
	local yaw = yawPara(de, para) or self.yaw
	if deCostas then
		yaw = self.yaw
	end
	self.movimento = { de = de, para = para, t0 = os.clock(), dur = dist / v, yaw = yaw, costas = deCostas }
	local vel = v / (14.5 * self.escala)
	self:tocar("andar", 0.15, if deCostas then -vel else vel)
	return dist / v
end

function Ator:virar(alvo: Vector3, tempo: number?)
	local yaw = yawPara(self.pos, alvo)
	if not yaw then
		return
	end
	self.giro = { de = self.yaw, para = self.yaw + difAngulo(self.yaw, yaw), t0 = os.clock(), dur = tempo or 0.45 }
end

-- Chamar a cada quadro
function Ator:passo()
	local agora = os.clock()
	local m = self.movimento
	if m then
		local k = math.clamp((agora - m.t0) / m.dur, 0, 1)
		self.pos = m.de:Lerp(m.para, k)
		if not m.costas then
			self.yaw = self.yaw + difAngulo(self.yaw, m.yaw) * 0.22
		end
		if self.aoPasso and agora - self.ultimoPasso > 0.48 * self.escala then
			self.ultimoPasso = agora
			self.aoPasso(self)
		end
		if k >= 1 then
			self.movimento = nil
			self:parar("andar", 0.2)
		end
	end
	local g = self.giro
	if g then
		local k = math.clamp((agora - g.t0) / g.dur, 0, 1)
		local e = k * k * (3 - 2 * k)
		self.yaw = g.de + (g.para - g.de) * e
		if k >= 1 then
			self.giro = nil
		end
	end
	self:aplicar()
	if agora > self.proximoPiscar and self.codigo ~= "CRIATURA" then
		self.proximoPiscar = agora + 2.4 + math.random() * 3
		local expr = self.modelo:GetAttribute("Expressao")
		if expr ~= "rindo" then
			for _, c in self.corpos do
				Personagens.piscar(c.modelo)
			end
		end
	end
end

-- Lamparina pendurada na mão direita (luz que acompanha o personagem)
function Ator:lamparina(brilho: number?)
	local braco = self.modelo:FindFirstChild("Right Arm") :: BasePart
	if not braco then
		return
	end
	local s = self.escala
	local m = Instance.new("Model")
	m.Name = "Lamparina"
	local c = Construtor.novo(m)
	local base = CFrame.new(0, 0, 0)
	local pega = c:bloco(base, Vector3.new(0.12, 0.12, 0.12), Moveis.COR.ferro, Enum.Material.Metal, { Name = "Pega" })
	c:bloco(base * CFrame.new(0, -0.35, 0), Vector3.new(0.08, 0.6, 0.08), Moveis.COR.ferro, Enum.Material.Metal)
	c:bloco(base * CFrame.new(0, -0.7, 0), Vector3.new(0.55, 0.1, 0.55), Moveis.COR.ferro, Enum.Material.Metal)
	c:bloco(base * CFrame.new(0, -1.05, 0), Vector3.new(0.48, 0.62, 0.48), Color3.fromRGB(255, 220, 170), Enum.Material.Glass, { Transparency = 0.55 })
	c:bloco(base * CFrame.new(0, -1.42, 0), Vector3.new(0.6, 0.12, 0.6), Moveis.COR.ferro, Enum.Material.Metal)
	local chama = c:bloco(base * CFrame.new(0, -1.08, 0), Vector3.new(0.12, 0.12, 0.12), Moveis.COR.chama, Enum.Material.Neon, { Name = "OI3_Chama" })
	local malha = Instance.new("SpecialMesh")
	malha.MeshType = Enum.MeshType.Sphere
	malha.Scale = Vector3.new(1, 2, 1)
	malha.Parent = chama
	c:luz(chama, "PointLight", { Range = 17, Brightness = brilho or 1.1, Color = Moveis.COR.luzVela, Shadows = true })
	-- posiciona e solda tudo na mão
	local mao = braco.CFrame * CFrame.new(0, -1 * s, 0)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = mao * p.CFrame
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false
			if p ~= pega then
				local w = Instance.new("WeldConstraint")
				w.Part0 = pega
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	local solda = Instance.new("Weld")
	solda.Part0 = braco
	solda.Part1 = pega
	solda.C0 = CFrame.new(0, -1 * s, 0)
	solda.Parent = pega
	m.Parent = self.modelo
	return chama
end

-- Cria um "reflexo" (clone espelhado) deste ator
function Ator:criarReflexo(refletir: (CFrame) -> CFrame, pasta: Instance)
	local clone = self.modelo:Clone()
	clone.Name = self.modelo.Name .. "_Reflexo"
	clone.Parent = pasta
	local trilhas = carregar(clone)
	for nome, tr in self.trilhas do
		if tr.IsPlaying and trilhas[nome] then
			trilhas[nome]:Play(0)
			trilhas[nome]:AdjustSpeed(tr.Speed)
		end
	end
	table.insert(self.corpos, { modelo = clone, trilhas = trilhas, refletir = refletir })
	self:aplicar()
	return clone
end

function Ator:removerReflexos()
	for i = #self.corpos, 2, -1 do
		self.corpos[i].modelo:Destroy()
		table.remove(self.corpos, i)
	end
end

function Ator:visivel(sim: boolean, so: string?)
	for _, c in self.corpos do
		for _, p in c.modelo:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Name ~= "Rosto" then
				p.LocalTransparencyModifier = if sim then 0 else 1
			elseif p:IsA("SurfaceGui") then
				p.Enabled = sim
			end
		end
		if so then
			break
		end
	end
end

function Ator:destruir()
	for _, c in self.corpos do
		for _, tr in c.trilhas do
			pcall(function()
				tr:Stop(0)
			end)
		end
		c.modelo:Destroy()
	end
	self.corpos = {}
end

return Ator
