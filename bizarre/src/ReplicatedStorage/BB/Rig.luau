-- BIZARRE BATTLEGROUNDS :: corpo R15 feito de peças (reserva)
-- Usado quando o catálogo do Roblox não responde (Stand ou boneco de treino) e nas prévias.
-- Mesmos nomes de peças e juntas do R15 de verdade, então as animações funcionam igual.

local Rig = {}

-- {nome, tamanho, centro (relativo ao HumanoidRootPart)}
local PECAS = {
	{ "LowerTorso", Vector3.new(1.9, 0.6, 1), Vector3.new(0, -0.1, 0) },
	{ "UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 1, 0) },
	{ "Head", Vector3.new(1.25, 1.25, 1.25), Vector3.new(0, 2.45, 0) },
	{ "LeftUpperArm", Vector3.new(0.9, 1.2, 0.9), Vector3.new(-1.45, 1.2, 0) },
	{ "LeftLowerArm", Vector3.new(0.82, 1.1, 0.82), Vector3.new(-1.45, 0.05, 0) },
	{ "LeftHand", Vector3.new(0.8, 0.45, 0.8), Vector3.new(-1.45, -0.7, 0) },
	{ "RightUpperArm", Vector3.new(0.9, 1.2, 0.9), Vector3.new(1.45, 1.2, 0) },
	{ "RightLowerArm", Vector3.new(0.82, 1.1, 0.82), Vector3.new(1.45, 0.05, 0) },
	{ "RightHand", Vector3.new(0.8, 0.45, 0.8), Vector3.new(1.45, -0.7, 0) },
	{ "LeftUpperLeg", Vector3.new(0.95, 1.25, 0.95), Vector3.new(-0.5, -1.0, 0) },
	{ "LeftLowerLeg", Vector3.new(0.88, 1.2, 0.88), Vector3.new(-0.5, -2.2, 0) },
	{ "LeftFoot", Vector3.new(0.9, 0.35, 1.1), Vector3.new(-0.5, -2.98, -0.08) },
	{ "RightUpperLeg", Vector3.new(0.95, 1.25, 0.95), Vector3.new(0.5, -1.0, 0) },
	{ "RightLowerLeg", Vector3.new(0.88, 1.2, 0.88), Vector3.new(0.5, -2.2, 0) },
	{ "RightFoot", Vector3.new(0.9, 0.35, 1.1), Vector3.new(0.5, -2.98, -0.08) },
}

-- {junta, pai, filho, posição da junta (relativa ao HRP)}
local JUNTAS = {
	{ "Root", "HumanoidRootPart", "LowerTorso", Vector3.new(0, -0.1, 0) },
	{ "Waist", "LowerTorso", "UpperTorso", Vector3.new(0, 0.2, 0) },
	{ "Neck", "UpperTorso", "Head", Vector3.new(0, 1.8, 0) },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", Vector3.new(-1.2, 1.7, 0) },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", Vector3.new(-1.45, 0.6, 0) },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", Vector3.new(-1.45, -0.5, 0) },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", Vector3.new(1.2, 1.7, 0) },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", Vector3.new(1.45, 0.6, 0) },
	{ "RightWrist", "RightLowerArm", "RightHand", Vector3.new(1.45, -0.5, 0) },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", Vector3.new(-0.5, -0.4, 0) },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", Vector3.new(-0.5, -1.6, 0) },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", Vector3.new(-0.5, -2.8, 0) },
	{ "RightHip", "LowerTorso", "RightUpperLeg", Vector3.new(0.5, -0.4, 0) },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", Vector3.new(0.5, -1.6, 0) },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", Vector3.new(0.5, -2.8, 0) },
}

Rig.ALTURA_QUADRIL = 1.95 -- do centro do HRP até o chão: 3.15 com a escala 1

-- cores = { cabeca, torso, bracos, maos, pernas, pes }
function Rig.montar(nome: string, escala: number?, cores: { [string]: Color3 }?, comHumanoid: boolean?): Model
	local s = escala or 1
	local c = cores or {}
	local modelo = Instance.new("Model")
	modelo.Name = nome
	local raiz = Instance.new("Part")
	raiz.Name = "HumanoidRootPart"
	raiz.Size = Vector3.new(2, 2, 1) * s
	raiz.Transparency = 1
	raiz.CanCollide = false
	raiz.CFrame = CFrame.new(0, 3.15 * s, 0)
	raiz.Parent = modelo
	modelo.PrimaryPart = raiz
	local partes = { HumanoidRootPart = raiz }
	local function cor(nomePeca: string): Color3
		if nomePeca == "Head" then
			return c.cabeca or Color3.fromRGB(245, 205, 48)
		elseif string.find(nomePeca, "Torso") then
			return c.torso or Color3.fromRGB(40, 110, 200)
		elseif string.find(nomePeca, "Hand") then
			return c.maos or c.bracos or Color3.fromRGB(245, 205, 48)
		elseif string.find(nomePeca, "Arm") then
			return c.bracos or Color3.fromRGB(245, 205, 48)
		elseif string.find(nomePeca, "Foot") then
			return c.pes or c.pernas or Color3.fromRGB(30, 30, 34)
		end
		return c.pernas or Color3.fromRGB(30, 60, 140)
	end
	for _, d in PECAS do
		local p = Instance.new("Part")
		p.Name = d[1]
		p.Size = d[2] * s
		p.CFrame = raiz.CFrame * CFrame.new(d[3] * s)
		p.Color = cor(d[1])
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = d[1] == "UpperTorso" or d[1] == "LowerTorso" or d[1] == "Head"
		p.Parent = modelo
		partes[d[1]] = p
	end
	for _, j in JUNTAS do
		local m = Instance.new("Motor6D")
		m.Name = j[1]
		local p0, p1 = partes[j[2]], partes[j[3]]
		local pos = raiz.CFrame * CFrame.new(j[4] * s)
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = p0.CFrame:ToObjectSpace(pos)
		m.C1 = p1.CFrame:ToObjectSpace(pos)
		m.Parent = p1
	end
	if comHumanoid then
		local hum = Instance.new("Humanoid")
		hum.RigType = Enum.HumanoidRigType.R15
		hum.HipHeight = Rig.ALTURA_QUADRIL * s
		hum.Parent = modelo
		local anim = Instance.new("Animator")
		anim.Parent = hum
	end
	return modelo
end

-- R6 clássico (6 peças), com as juntas e as posições padrão do Roblox
local R6_PECAS = {
	{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), "torso" },
	{ "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), "cabeca" },
	{ "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), "bracos" },
	{ "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), "bracos" },
	{ "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), "pernas" },
	{ "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), "pernas" },
}

function Rig.montarR6(nome: string, cores: { [string]: Color3 }?, comHumanoid: boolean?): Model
	local c = cores or {}
	local modelo = Instance.new("Model")
	modelo.Name = nome
	local raiz = Instance.new("Part")
	raiz.Name = "HumanoidRootPart"
	raiz.Size = Vector3.new(2, 2, 1)
	raiz.Transparency = 1
	raiz.CanCollide = false
	raiz.CFrame = CFrame.new(0, 3, 0)
	raiz.Parent = modelo
	modelo.PrimaryPart = raiz
	local partes = {}
	for _, d in R6_PECAS do
		local p = Instance.new("Part")
		p.Name = d[1]
		p.Size = d[2]
		p.CFrame = raiz.CFrame * CFrame.new(d[3])
		p.Color = c[d[4]] or Color3.fromRGB(200, 200, 200)
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = d[1] == "Torso" or d[1] == "Head"
		p.Parent = modelo
		partes[d[1]] = p
	end
	local malha = Instance.new("SpecialMesh")
	malha.MeshType = Enum.MeshType.Head
	malha.Scale = Vector3.new(1.25, 1.25, 1.25)
	malha.Parent = partes.Head
	local meia = math.pi / 2
	local function junta(nomeJ: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame, pai: Instance)
		local m = Instance.new("Motor6D")
		m.Name = nomeJ
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = c0
		m.C1 = c1
		m.Parent = pai
	end
	local torso = partes.Torso
	junta("RootJoint", raiz, torso, CFrame.Angles(-meia, 0, math.pi), CFrame.Angles(-meia, 0, math.pi), raiz)
	junta("Neck", torso, partes.Head, CFrame.new(0, 1, 0) * CFrame.Angles(-meia, 0, math.pi), CFrame.new(0, -0.5, 0) * CFrame.Angles(-meia, 0, math.pi), torso)
	junta("Right Shoulder", torso, partes["Right Arm"], CFrame.new(1, 0.5, 0) * CFrame.Angles(0, meia, 0), CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, meia, 0), torso)
	junta("Left Shoulder", torso, partes["Left Arm"], CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -meia, 0), CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -meia, 0), torso)
	junta("Right Hip", torso, partes["Right Leg"], CFrame.new(1, -1, 0) * CFrame.Angles(0, meia, 0), CFrame.new(0.5, 1, 0) * CFrame.Angles(0, meia, 0), torso)
	junta("Left Hip", torso, partes["Left Leg"], CFrame.new(-1, -1, 0) * CFrame.Angles(0, -meia, 0), CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -meia, 0), torso)
	if comHumanoid then
		local hum = Instance.new("Humanoid")
		hum.RigType = Enum.HumanoidRigType.R6
		hum.Parent = modelo
		local anim = Instance.new("Animator")
		anim.Parent = hum
	end
	return modelo
end

return Rig
