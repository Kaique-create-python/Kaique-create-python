-- BIZARRE BATTLEGROUNDS :: monta o corpo de cada Stand em R6 com itens do catálogo do Roblox
-- (camisa e calça clássicas + cabeça/cabelo/ombreiras/cinto feitos pela comunidade com o nome do
-- Stand). Fica sólido, sem transparência. O servidor monta uma vez e guarda em
-- ReplicatedStorage.BB_Stands; cada celular copia e anima.
-- Se algum item falhar, tenta de novo sem os acessórios; se tudo falhar, usa um R6 de peças.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BB = ReplicatedStorage:WaitForChild("BB")
local Stands = require(BB:WaitForChild("Stands"))
local Rig = require(BB:WaitForChild("Rig"))

local StandModelos = {}
StandModelos.relatorio = {} :: { [string]: string }

local CAMPOS = {
	chapeu = "HatAccessory",
	cabelo = "HairAccessory",
	rosto = "FaceAccessory",
	pescoco = "NeckAccessory",
	ombro = "ShouldersAccessory",
	frente = "FrontAccessory",
	costas = "BackAccessory",
	cintura = "WaistAccessory",
}

local function descricao(s: any, comAcessorios: boolean): HumanoidDescription
	local v = s.visual
	local d = Instance.new("HumanoidDescription")
	d.Shirt = v.camisa or 0
	d.Pants = v.calca or 0
	d.Face = 0
	local pele = v.pele or s.cor
	d.HeadColor = pele
	d.TorsoColor = pele
	d.LeftArmColor = pele
	d.RightArmColor = pele
	d.LeftLegColor = v.pernas or pele
	d.RightLegColor = v.pernas or pele
	if comAcessorios then
		for tipo, lista in v.acessorios or {} do
			local campo = CAMPOS[tipo]
			if campo then
				local ids = {}
				for _, id in lista do
					table.insert(ids, tostring(id))
				end
				(d :: any)[campo] = table.concat(ids, ",")
			end
		end
	end
	return d
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
	p.CastShadow = true
	if forma then
		p.Shape = forma
	end
	return p
end

-- detalhes feitos por código que o catálogo não tem
local function detalhes(modelo: Model, s: any)
	local braco = modelo:FindFirstChild("Right Arm") :: BasePart?
	if braco and s.visual.arma == "rapieira" then
		-- rapieira do Silver Chariot: punho dourado, guarda em concha e lâmina fina
		local base = braco.CFrame * CFrame.new(0, -1.05, -0.1) * CFrame.Angles(math.rad(-90), 0, 0)
		local punho = peca("Punho", Vector3.new(0.3, 0.9, 0.3), Color3.fromRGB(220, 180, 60), Enum.Material.Metal)
		punho.CFrame = base
		punho.Parent = modelo
		soldar(braco, punho)
		local guarda = peca("Guarda", Vector3.new(0.25, 1.1, 1.1), Color3.fromRGB(200, 206, 218), Enum.Material.Metal, Enum.PartType.Cylinder)
		guarda.CFrame = base * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90))
		guarda.Parent = modelo
		soldar(braco, guarda)
		local lamina = peca("Lamina", Vector3.new(0.12, 5.2, 0.12), Color3.fromRGB(235, 240, 250), Enum.Material.Metal)
		lamina.CFrame = base * CFrame.new(0, 3.2, 0)
		lamina.Reflectance = 0.3
		lamina.Parent = modelo
		soldar(braco, lamina)
		modelo:SetAttribute("TemArma", true)
	end
end

local function finalizar(modelo: Model, s: any, origem: string): Model
	modelo.Name = s.id
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
		elseif p:IsA("Script") or p:IsA("LocalScript") then
			p:Destroy()
		end
	end
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
	-- Stand um pouco maior que o usuário
	local escala = s.visual.escala or 1.12
	if escala ~= 1 then
		pcall(function()
			modelo:ScaleTo(escala)
		end)
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

local function contarAcessorios(modelo: Model): number
	local n = 0
	for _, d in modelo:GetChildren() do
		if d:IsA("Accessory") then
			n += 1
		end
	end
	return n
end

function StandModelos.montar(s: any): (Model, string)
	for _, comAcessorios in { true, false } do
		local ok, modelo = pcall(function()
			return Players:CreateHumanoidModelFromDescription(descricao(s, comAcessorios), Enum.HumanoidRigType.R6)
		end)
		if ok and modelo and contarJuntas(modelo) >= 6 then
			local acess = contarAcessorios(modelo)
			local roupa = (modelo:FindFirstChildOfClass("Shirt") and 1 or 0) + (modelo:FindFirstChildOfClass("Pants") and 1 or 0)
			local esperados = 0
			for _, lista in s.visual.acessorios or {} do
				esperados += #lista
			end
			local origem = string.format("catálogo R6: roupa %d, acessórios %d/%d", roupa, acess, if comAcessorios then esperados else 0)
			return finalizar(modelo, s, origem), origem
		elseif ok and modelo then
			modelo:Destroy()
		end
	end
	local pele = s.visual.pele or s.cor
	local reserva = Rig.montarR6(s.id, { cabeca = pele, torso = s.cor, bracos = pele, pernas = s.corPernas or pele }, true)
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
