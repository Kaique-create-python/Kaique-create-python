-- BIZARRE BATTLEGROUNDS :: empurrões, ragdoll, prender e mover lutadores
-- O personagem do jogador é simulado pelo celular dele: o servidor cria um LinearVelocity dentro
-- dele (isso vai junto para o celular) e marca BB_Ragdoll; o celular do dono deita o personagem.

local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")

local Fisica = {}

Fisica.GRUPOS = {
	lutador = "BB_Lutadores",
	voando = "BB_Voando",
	quebravel = "BB_Quebravel",
	destrocos = "BB_Destrocos",
	efeito = "BB_Efeitos",
}

local remotoPrivado: RemoteEvent? = nil
Fisica.VEL_MAX = 95

function Fisica.iniciar(privado: RemoteEvent?)
	remotoPrivado = privado
	local G = Fisica.GRUPOS
	for _, nome in { G.lutador, G.voando, G.quebravel, G.destrocos, G.efeito } do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(nome)
		end)
	end
	pcall(function()
		-- lutadores não se empurram (ninguém fica entalado no meio de uma rajada)
		PhysicsService:CollisionGroupSetCollidable(G.lutador, G.lutador, false)
		PhysicsService:CollisionGroupSetCollidable(G.lutador, G.voando, false)
		PhysicsService:CollisionGroupSetCollidable(G.voando, G.voando, false)
		-- quem está voando atravessa (e quebra) as paredes
		PhysicsService:CollisionGroupSetCollidable(G.voando, G.quebravel, false)
		-- destroços não empurram ninguém
		PhysicsService:CollisionGroupSetCollidable(G.destrocos, G.lutador, false)
		PhysicsService:CollisionGroupSetCollidable(G.destrocos, G.voando, false)
		PhysicsService:CollisionGroupSetCollidable(G.destrocos, G.destrocos, false)
		-- efeitos não colidem com nada
		for _, outro in { "Default", G.lutador, G.voando, G.quebravel, G.destrocos, G.efeito } do
			PhysicsService:CollisionGroupSetCollidable(G.efeito, outro, false)
		end
	end)
end

function Fisica.grupo(modelo: Model, nome: string)
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = nome
		end
	end
end

local function anexo(raiz: BasePart): Attachment
	local a = raiz:FindFirstChild("RootAttachment") or raiz:FindFirstChild("BB_Anexo")
	if a and a:IsA("Attachment") then
		return a
	end
	local novo = Instance.new("Attachment")
	novo.Name = "BB_Anexo"
	novo.Parent = raiz
	return novo
end

function Fisica.limparEmpurroes(raiz: BasePart)
	for _, f in raiz:GetChildren() do
		if f.Name == "BB_Empurrao" then
			f:Destroy()
		end
	end
end

-- empurra o lutador com velocidade constante por "dur" segundos
function Fisica.empurrar(lut: any, vel: Vector3, dur: number)
	local raiz: BasePart = lut.raiz
	if raiz.Anchored then
		return
	end
	local maximo = Fisica.VEL_MAX or 95
	if vel.Magnitude > maximo then
		vel = vel.Unit * maximo
	end
	Fisica.limparEmpurroes(raiz)
	local lv = Instance.new("LinearVelocity")
	lv.Name = "BB_Empurrao"
	lv.Attachment0 = anexo(raiz)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = 1e7
	lv.VectorVelocity = vel
	lv.Parent = raiz
	Debris:AddItem(lv, math.max(0.04, dur))
	if not lut.jogador then
		pcall(function()
			raiz.AssemblyLinearVelocity = vel
		end)
	end
end

-- ragdoll de verdade (AJUSTE-2): as juntas soltam (BallSocket) em todos os celulares, o corpo cai
-- mole e levanta sozinho depois. As juntas de reserva são criadas uma vez por personagem.
local LIMITES = {
	Neck = 35,
	["Left Shoulder"] = 100,
	["Right Shoulder"] = 100,
	["Left Hip"] = 70,
	["Right Hip"] = 70,
	LeftShoulder = 100,
	RightShoulder = 100,
	LeftHip = 70,
	RightHip = 70,
	LeftElbow = 80,
	RightElbow = 80,
	LeftKnee = 80,
	RightKnee = 80,
	Waist = 30,
}

local function ehRaiz(m: Motor6D): boolean
	return m.Name == "RootJoint" or m.Name == "Root"
end

local function prepararRagdoll(modelo: Model)
	if modelo:GetAttribute("BB_RagdollPronto") then
		return
	end
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("BB_ColOrig") == nil then
			p:SetAttribute("BB_ColOrig", p.CanCollide)
		end
	end
	for _, m in modelo:GetDescendants() do
		if m:IsA("Motor6D") and not ehRaiz(m) and m.Part0 and m.Part1 and LIMITES[m.Name] then
			local a0 = Instance.new("Attachment")
			a0.Name = "BB_RA0_" .. m.Name
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "BB_RA1_" .. m.Name
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Name = "BB_Junta_" .. m.Name
			bs.Attachment0 = a0
			bs.Attachment1 = a1
			bs.LimitsEnabled = true
			bs.UpperAngle = LIMITES[m.Name]
			bs.TwistLimitsEnabled = false
			bs.Enabled = false
			bs.Parent = m.Part1
		end
	end
	modelo:SetAttribute("BB_RagdollPronto", true)
end
Fisica.prepararRagdoll = prepararRagdoll

local function juntasSoltas(modelo: Model, soltar: boolean)
	for _, d in modelo:GetDescendants() do
		if d:IsA("Motor6D") and not ehRaiz(d) and LIMITES[d.Name] then
			d.Enabled = not soltar
		elseif d:IsA("BallSocketConstraint") and string.sub(d.Name, 1, 9) == "BB_Junta_" then
			d.Enabled = soltar
		end
	end
end

function Fisica.derrubar(lut: any, ate: number)
	local m = lut.modelo
	local jaDeitado = (m:GetAttribute("BB_Ragdoll") or 0) > workspace:GetServerTimeNow()
	m:SetAttribute("BB_Ragdoll", ate)
	if jaDeitado then
		return
	end
	prepararRagdoll(m)
	juntasSoltas(m, true)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			p.CanCollide = p.Name ~= "HumanoidRootPart"
		end
	end
	Fisica.grupo(m, Fisica.GRUPOS.voando)
	if lut.jogador then
		-- cada pedaço solto continua sendo simulado pelo celular do dono
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				pcall(function()
					p:SetNetworkOwner(lut.jogador)
				end)
			end
		end
	else
		pcall(function()
			lut.hum:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end
end

-- bots caídos: o Humanoid do servidor tenta desligar a colisão dos braços e pernas
local MEMBROS = { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
function Fisica.manterRagdoll(lut: any)
	if lut.jogador then
		return
	end
	for _, nome in MEMBROS do
		local p = lut.modelo:FindFirstChild(nome)
		if p and p:IsA("BasePart") and not p.CanCollide then
			p.CanCollide = true
		end
	end
end

function Fisica.levantar(lut: any)
	local m = lut.modelo
	m:SetAttribute("BB_Ragdoll", 0)
	juntasSoltas(m, false)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			local orig = p:GetAttribute("BB_ColOrig")
			if orig ~= nil then
				p.CanCollide = orig
			end
		end
	end
	Fisica.grupo(m, Fisica.GRUPOS.lutador)
	if not lut.jogador and lut.hum.Health > 0 then
		pcall(function()
			lut.hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
	end
end

-- o próprio lutador se move (investidas e saltos dos bots; jogadores fazem isso no celular)
function Fisica.impulsoProprio(lut: any, dir: Vector3, frente: number, cima: number, dur: number)
	if lut.jogador then
		return
	end
	local v = Vector3.new(dir.X, 0, dir.Z)
	if v.Magnitude > 1e-3 then
		v = v.Unit
	end
	Fisica.empurrar(lut, v * frente + Vector3.new(0, cima, 0), dur)
end

Fisica.carregarRegiao = nil :: ((Player, Vector3) -> ())?

-- teleporta (jogador: pede para o celular dele; bot: move direto)
function Fisica.moverPara(lut: any, cf: CFrame)
	if lut.jogador then
		local longe = lut.raiz and (lut.raiz.Position - cf.Position).Magnitude > 220
		if longe and Fisica.carregarRegiao then
			-- longe demais: primeiro o celular recebe o lugar novo (senão cai no vazio)
			local carregar = Fisica.carregarRegiao
			task.spawn(function()
				carregar(lut.jogador, cf.Position)
				if remotoPrivado then
					remotoPrivado:FireClient(lut.jogador, "mover", { cf = cf })
				end
				pcall(function()
					lut.modelo:PivotTo(cf)
				end)
			end)
			return
		end
		if remotoPrivado then
			remotoPrivado:FireClient(lut.jogador, "mover", { cf = cf })
		end
	end
	-- o servidor também move: quem está olhando já vê no lugar novo
	pcall(function()
		lut.modelo:PivotTo(cf)
	end)
end

-- prende no lugar (tempo parado, agarrão, preso na parede)
function Fisica.prender(lut: any)
	Fisica.limparEmpurroes(lut.raiz)
	lut.raiz.Anchored = true
end

function Fisica.soltar(lut: any)
	if lut.raiz and lut.raiz.Parent then
		lut.raiz.Anchored = false
	end
end

-- avisa o celular do dono para parar uma investida/dash agora
function Fisica.pararMovimento(lut: any)
	if lut.jogador and remotoPrivado then
		remotoPrivado:FireClient(lut.jogador, "parar", {})
	else
		Fisica.limparEmpurroes(lut.raiz)
	end
end

return Fisica
