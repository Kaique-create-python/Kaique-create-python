-- BIZARRE BATTLEGROUNDS :: monta o corpo de cada Stand com peças do catálogo do Roblox
-- O servidor monta uma vez e guarda em ReplicatedStorage.BB_Stands; cada celular copia e anima.
-- Se o catálogo falhar, usa o próximo corpo da lista; se tudo falhar, um corpo de peças (Rig).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BB = ReplicatedStorage:WaitForChild("BB")
local Stands = require(BB:WaitForChild("Stands"))
local Rig = require(BB:WaitForChild("Rig"))

local StandModelos = {}
StandModelos.relatorio = {} :: { [string]: string }

local REGIOES = {
	Head = "cabeca",
	UpperTorso = "torso",
	LowerTorso = "torso",
	LeftUpperArm = "bracos",
	LeftLowerArm = "bracos",
	RightUpperArm = "bracos",
	RightLowerArm = "bracos",
	LeftHand = "maos",
	RightHand = "maos",
	LeftUpperLeg = "pernas",
	LeftLowerLeg = "pernas",
	RightUpperLeg = "pernas",
	RightLowerLeg = "pernas",
	LeftFoot = "pes",
	RightFoot = "pes",
}

local function coresDe(s: any)
	return {
		cabeca = s.cor,
		torso = s.cor,
		bracos = s.cor,
		maos = s.cor2,
		pernas = s.corPernas or s.cor,
		pes = s.cor2,
	}
end

local function descricao(s: any, corpo: any): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	d.Torso = corpo.torso
	d.LeftArm = corpo.bracoE
	d.RightArm = corpo.bracoD
	d.LeftLeg = corpo.pernaE
	d.RightLeg = corpo.pernaD
	d.Head = corpo.cabeca
	local esc = s.visual.escala or {}
	d.HeightScale = esc.altura or 1.1
	d.WidthScale = esc.largura or 1
	d.DepthScale = esc.profundidade or 1
	d.HeadScale = esc.cabeca or 1
	d.BodyTypeScale = 0
	d.ProportionScale = 0
	local acess = {}
	for _, id in s.visual.acessorios or {} do
		table.insert(acess, tostring(id))
	end
	d.HatAccessory = table.concat(acess, ",")
	local c = coresDe(s)
	d.HeadColor = c.cabeca
	d.TorsoColor = c.torso
	d.LeftArmColor = c.bracos
	d.RightArmColor = c.bracos
	d.LeftLegColor = c.pernas
	d.RightLegColor = c.pernas
	return d
end

-- deixa com cara de "espírito": cor lisa, sem textura, um pouco brilhante
local function pintar(modelo: Model, s: any)
	local c = coresDe(s)
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.CastShadow = false
			local regiao = REGIOES[p.Name]
			if regiao and p.Parent == modelo then
				p.Color = c[regiao]
				p.Material = Enum.Material.SmoothPlastic
				p.Reflectance = 0.06
				if p:IsA("MeshPart") then
					pcall(function()
						(p :: any).TextureID = ""
					end)
				end
				for _, filho in p:GetChildren() do
					if filho:IsA("SurfaceAppearance") or filho:IsA("Decal") then
						filho:Destroy()
					end
				end
			end
		elseif p:IsA("Script") or p:IsA("LocalScript") or p:IsA("ModuleScript") then
			p:Destroy()
		end
	end
end

local function soldar(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function peca(nome: string, tam: Vector3, cor: Color3, material: Enum.Material, forma: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Size = tam
	p.Color = cor
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	if forma then
		p.Shape = forma
	end
	return p
end

-- detalhes feitos por código: olhos que brilham, sombrinha, caixas de som, cristais...
local function detalhes(modelo: Model, s: any)
	local cabeca = modelo:FindFirstChild("Head") :: BasePart?
	local torso = modelo:FindFirstChild("UpperTorso") :: BasePart?
	local maoD = modelo:FindFirstChild("RightHand") :: BasePart?
	if cabeca and s.visual.olhos then
		local tam = cabeca.Size
		for _, lado in { -1, 1 } do
			local olho = peca("Olho", Vector3.new(0.26, 0.12, 0.08) * math.max(1, tam.X / 1.2), s.olhos, Enum.Material.Neon)
			olho.CFrame = cabeca.CFrame * CFrame.new(lado * tam.X * 0.18, tam.Y * 0.08, -tam.Z * 0.5 - 0.02) * CFrame.Angles(0, 0, math.rad(lado * -12))
			olho.Parent = modelo
			soldar(cabeca, olho)
		end
	end
	if torso and s.visual.cristais then
		for _, lado in { -1, 1 } do
			for k = 0, 1 do
				local cr = peca("Cristal", Vector3.new(0.5, 1.1 - k * 0.3, 0.5), s.cor2, Enum.Material.Neon)
				cr.Transparency = 0.15
				cr.CFrame = torso.CFrame * CFrame.new(lado * (torso.Size.X * 0.5 + 0.1), torso.Size.Y * 0.42 + k * 0.1, -0.2 + k * 0.4) * CFrame.Angles(math.rad(20 - k * 30), 0, math.rad(lado * -30))
				cr.Parent = modelo
				soldar(torso, cr)
			end
		end
	end
	if torso and s.visual.caixasDeSom then
		for _, lado in { -1, 1 } do
			local cone = peca("Caixa", Vector3.new(0.25, 0.85, 0.85), Color3.fromRGB(26, 24, 32), Enum.Material.Metal, Enum.PartType.Cylinder)
			cone.CFrame = torso.CFrame * CFrame.new(lado * torso.Size.X * 0.24, torso.Size.Y * 0.12, -torso.Size.Z * 0.5 - 0.05) * CFrame.Angles(0, math.rad(90), 0)
			cone.Parent = modelo
			soldar(torso, cone)
			local anel = peca("AnelSom", Vector3.new(0.12, 0.95, 0.95), s.olhos, Enum.Material.Neon, Enum.PartType.Cylinder)
			anel.CFrame = cone.CFrame * CFrame.new(-0.08, 0, 0)
			anel.Parent = modelo
			soldar(torso, anel)
		end
	end
	if maoD and s.visual.arma == "sombrinha" then
		-- sombrinha de frevo: cabo + copa colorida em gomos
		local cabo = peca("Cabo", Vector3.new(0.18, 4.2, 0.18), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
		cabo.CFrame = maoD.CFrame * CFrame.new(0, 0, -0.1) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, 1.6, 0)
		cabo.Parent = modelo
		soldar(maoD, cabo)
		local ponta = peca("Ponta", Vector3.new(0.12, 1.2, 0.12), Color3.fromRGB(230, 230, 236), Enum.Material.Metal)
		ponta.CFrame = cabo.CFrame * CFrame.new(0, 2.6, 0)
		ponta.Parent = modelo
		soldar(maoD, ponta)
		local cores = { Color3.fromRGB(232, 44, 70), Color3.fromRGB(250, 210, 40), Color3.fromRGB(36, 200, 96), Color3.fromRGB(40, 120, 230) }
		for i = 0, 7 do
			local gomo = peca("Gomo", Vector3.new(0.08, 1.9, 1.1), cores[i % 4 + 1], Enum.Material.Fabric)
			gomo.CFrame = cabo.CFrame * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, math.rad(i * 45), 0) * CFrame.new(0, 0, -0.9) * CFrame.Angles(math.rad(-58), 0, 0)
			gomo.Parent = modelo
			soldar(maoD, gomo)
		end
	end
end

local function finalizar(modelo: Model, s: any, origem: string)
	modelo.Name = s.id
	pintar(modelo, s)
	detalhes(modelo, s)
	local hum = modelo:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.RequiresNeck = false
		hum.BreakJointsOnDeath = false
		hum.EvaluateStateMachine = false
	end
	local raiz = modelo:FindFirstChild("HumanoidRootPart") :: BasePart?
	if raiz then
		raiz.Transparency = 1
		modelo.PrimaryPart = raiz
	end
	modelo:SetAttribute("Stand", s.id)
	modelo:SetAttribute("Origem", origem)
	return modelo
end

local function contarJuntas(modelo: Model): number
	local n = 0
	for _, d in modelo:GetDescendants() do
		if d:IsA("Motor6D") then
			n += 1
		end
	end
	return n
end

function StandModelos.montar(s: any): (Model, string)
	for _, nomeCorpo in s.visual.corpos or {} do
		local corpo = Stands.CORPOS[nomeCorpo]
		if not corpo then
			continue
		end
		local ok, modelo = pcall(function()
			return Players:CreateHumanoidModelFromDescription(descricao(s, corpo), Enum.HumanoidRigType.R15)
		end)
		if ok and modelo and contarJuntas(modelo) >= 15 then
			return finalizar(modelo, s, "catálogo:" .. nomeCorpo), "catálogo (" .. nomeCorpo .. ")"
		elseif ok and modelo then
			modelo:Destroy()
		end
	end
	local reserva = Rig.montar(s.id, 1.1, coresDe(s), true)
	return finalizar(reserva, s, "reserva"), "corpo reserva (catálogo não respondeu)"
end

function StandModelos.preparar(): Folder
	local pasta = ReplicatedStorage:FindFirstChild("BB_Stands")
	if pasta then
		pasta:Destroy()
	end
	local nova = Instance.new("Folder")
	nova.Name = "BB_Stands"
	for _, id in Stands.ORDEM do
		local s = Stands.get(id)
		local modelo, origem = StandModelos.montar(s)
		modelo.Parent = nova
		StandModelos.relatorio[id] = origem
	end
	nova.Parent = ReplicatedStorage
	return nova
end

return StandModelos
