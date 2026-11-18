-- OI3 :: SÓ PARA AS PRÉVIAS OFFLINE (tools). Não vai para o jogo.
-- No jogo os personagens são avatares do Roblox montados com IDs do catálogo (OI3_Atores).
-- Aqui fazemos um manequim R6 cinza/colorido só para as imagens de prévia terem os bonecos no lugar.
local roblox = require("@lune/roblox")
local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum
local V3 = Vector3.new
local CF = CFrame.new
local RGB = Color3.fromRGB
local Personagens = {}
-- Juntas R6 padrão (escaladas)
local function esc(cf: CFrame, s: number): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CF(x * s, y * s, z * s, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end

local J = {
	raiz = CF(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	pescoco0 = CF(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	pescoco1 = CF(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	ombroD0 = CF(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	ombroD1 = CF(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	ombroE0 = CF(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	ombroE1 = CF(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	quadrilD0 = CF(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	quadrilD1 = CF(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	quadrilE0 = CF(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	quadrilE1 = CF(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
}

local function anexo(pai: Instance, nome: string, pos: Vector3)
	local a = Instance.new("Attachment")
	a.Name = nome
	a.Position = pos
	a.Parent = pai
end

-- Monta um rig R6 completo e animável. Retorna o Model (raiz ancorada).
function Personagens.rig(nome: string, s: number, cores: { pele: Color3, torso: Color3, bracos: Color3, pernas: Color3 }, material: Enum.Material?): Model
	local modelo = Instance.new("Model")
	modelo.Name = nome
	local mat = material or Enum.Material.SmoothPlastic
	local function parte(n: string, tam: Vector3, cor: Color3): BasePart
		local p = Instance.new("Part")
		p.Name = n
		p.Size = tam * s
		p.Color = cor
		p.Material = mat
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = modelo
		return p
	end
	local hrp = parte("HumanoidRootPart", V3(2, 2, 1), cores.torso)
	hrp.Transparency = 1
	hrp.Anchored = true
	local torso = parte("Torso", V3(2, 2, 1), cores.torso)
	local cabeca = parte("Head", V3(2, 1, 1), cores.pele)
	local malha = Instance.new("SpecialMesh")
	malha.MeshType = Enum.MeshType.Head
	malha.Scale = V3(1.25, 1.25, 1.25)
	malha.Parent = cabeca
	local bE = parte("Left Arm", V3(1, 2, 1), cores.bracos)
	local bD = parte("Right Arm", V3(1, 2, 1), cores.bracos)
	local pE = parte("Left Leg", V3(1, 2, 1), cores.pernas)
	local pD = parte("Right Leg", V3(1, 2, 1), cores.pernas)

	local base = CF(0, 3 * s, 0)
	hrp.CFrame = base
	torso.CFrame = base
	cabeca.CFrame = base * CF(0, 1.5 * s, 0)
	bE.CFrame = base * CF(-1.5 * s, 0, 0)
	bD.CFrame = base * CF(1.5 * s, 0, 0)
	pE.CFrame = base * CF(-0.5 * s, -2 * s, 0)
	pD.CFrame = base * CF(0.5 * s, -2 * s, 0)

	local function motor(n: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame)
		local m = Instance.new("Motor6D")
		m.Name = n
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = esc(c0, s)
		m.C1 = esc(c1, s)
		m.MaxVelocity = 0.1
		m.Parent = p0
	end
	motor("RootJoint", hrp, torso, J.raiz, J.raiz)
	motor("Neck", torso, cabeca, J.pescoco0, J.pescoco1)
	motor("Right Shoulder", torso, bD, J.ombroD0, J.ombroD1)
	motor("Left Shoulder", torso, bE, J.ombroE0, J.ombroE1)
	motor("Right Hip", torso, pD, J.quadrilD0, J.quadrilD1)
	motor("Left Hip", torso, pE, J.quadrilE0, J.quadrilE1)

	-- anexos padrão R6 (para acessórios do catálogo no futuro)
	anexo(cabeca, "HatAttachment", V3(0, 0.6, 0) * s)
	anexo(cabeca, "HairAttachment", V3(0, 0.6, 0) * s)
	anexo(cabeca, "FaceFrontAttachment", V3(0, 0, -0.6) * s)
	anexo(cabeca, "FaceCenterAttachment", V3(0, 0, 0))
	anexo(torso, "NeckAttachment", V3(0, 1, 0) * s)
	anexo(torso, "BodyFrontAttachment", V3(0, 0, -0.5) * s)
	anexo(torso, "BodyBackAttachment", V3(0, 0, 0.5) * s)
	anexo(torso, "WaistFrontAttachment", V3(0, -1, -0.5) * s)
	anexo(torso, "WaistCenterAttachment", V3(0, -1, 0) * s)
	anexo(torso, "WaistBackAttachment", V3(0, -1, 0.5) * s)
	anexo(torso, "LeftCollarAttachment", V3(-1, 1, 0) * s)
	anexo(torso, "RightCollarAttachment", V3(1, 1, 0) * s)
	anexo(bE, "LeftShoulderAttachment", V3(0, 1, 0) * s)
	anexo(bE, "LeftGripAttachment", V3(0, -1, 0) * s)
	anexo(bD, "RightShoulderAttachment", V3(0, 1, 0) * s)
	anexo(bD, "RightGripAttachment", V3(0, -1, 0) * s)
	anexo(pE, "LeftFootAttachment", V3(0, -1, 0) * s)
	anexo(pD, "RightFootAttachment", V3(0, -1, 0) * s)
	anexo(hrp, "RootAttachment", V3(0, 0, 0))

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.NameDisplayDistance = 0
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.Parent = modelo
	local animador = Instance.new("Animator")
	animador.Parent = hum

	modelo.PrimaryPart = hrp
	modelo:SetAttribute("Escala", s)
	return modelo
end

---------------------------------------------------------------------------
-- Rosto desenhado (SurfaceGui numa placa na frente da cabeça)
---------------------------------------------------------------------------

local ESCURO = RGB(30, 22, 20)


return Personagens
