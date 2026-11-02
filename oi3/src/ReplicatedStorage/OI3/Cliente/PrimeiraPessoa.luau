-- OI3 :: primeira pessoa na exploração
-- câmera balançando ao andar/correr, lanterna na mão (com luz e sombra), corrida com estamina e passos.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local OI3 = script.Parent.Parent
local Construtor = require(OI3.Construtor)
local Moveis = require(OI3.Moveis)
local Som = require(script.Parent.Som)

local PrimeiraPessoa = {}

local V3 = Vector3.new
local CF = CFrame.new
local RGB = Color3.fromRGB

local VEL_ANDAR = 12
local VEL_CORRER = 20
local VEL_CANSADO = 9
local PASSADA = 10.5 -- studs por ciclo (2 passos)

local estado = {
	ativo = false,
	char = nil :: Model?,
	hum = nil :: Humanoid?,
	raiz = nil :: BasePart?,
	fase = 0,
	amp = 0,
	tempo = 0,
	passoAnterior = 0,
	stamina = 1,
	ultimoGasto = 0,
	cansado = false,
	querCorrer = false,
	correndo = false,
	fov = 72,
	luzLigada = false,
	vm = nil :: Model?,
	vmRaiz = nil :: BasePart?,
	lente = nil :: BasePart?,
	luzes = {} :: { Light },
	balancoRot = Vector2.new(0, 0),
	ultimoCam = nil :: CFrame?,
	proximaPiscada = 0,
	piscando = false,
	tremor = true,
	leve = false,
	conexoes = {} :: { RBXScriptConnection },
	aoEstamina = nil :: ((number, boolean, boolean) -> ())?,
}

---------------------------------------------------------------------------
-- Passos: som certo para cada chão (madeira, grama, pedra...)
---------------------------------------------------------------------------
local CHAO_MADEIRA = {
	[Enum.Material.Wood] = true,
	[Enum.Material.WoodPlanks] = true,
}
local CHAO_GRAMA = {
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Ground] = true,
	[Enum.Material.Mud] = true,
	[Enum.Material.Sand] = true,
	[Enum.Material.Fabric] = true, -- tapete: abafado como grama
}

-- função pura (testável): escolhe o nome do som do passo
function PrimeiraPessoa.somDoPasso(material: Enum.Material, n: number, disponivel: ((string) -> boolean)?): string
	local tipo = nil
	if CHAO_MADEIRA[material] then
		tipo = "passo_madeira"
	elseif CHAO_GRAMA[material] then
		tipo = "passo_grama"
	end
	if tipo and (disponivel == nil or disponivel(tipo .. n)) then
		return tipo .. n
	end
	return "passo" .. n
end

---------------------------------------------------------------------------
-- Lanterna na mão (modelo local, preso à câmera)
---------------------------------------------------------------------------

-- Monta a lanterna + mão (função pura: dá para testar fora do Roblox)
function PrimeiraPessoa.montarLanterna(pele: Color3?)
	local m = Instance.new("Model")
	m.Name = "OI3_Lanterna1P"
	local c = Construtor.novo(m)
	local metal = RGB(46, 48, 54)
	local borracha = RGB(18, 18, 20)
	-- referência: eixo X da lanterna aponta para a frente (-Z depois de girar)
	local raiz = c:caixa(V3(0, 0, 0), V3(0.1, 0.1, 0.1), RGB(0, 0, 0), Enum.Material.SmoothPlastic, { Name = "Raiz", Transparency = 1 })
	local giro = CFrame.Angles(0, math.pi / 2, 0) -- cilindro (eixo X) passa a apontar para -Z
	c:cilindro(CF(0, 0, 0.1) * giro, 1.15, 0.3, metal, Enum.Material.Metal, { Name = "Corpo" })
	c:cilindro(CF(0, 0, 0.35) * giro, 0.12, 0.33, borracha, Enum.Material.SmoothPlastic)
	c:cilindro(CF(0, 0, -0.05) * giro, 0.12, 0.33, borracha, Enum.Material.SmoothPlastic)
	c:cilindro(CF(0, 0, -0.6) * giro, 0.32, 0.44, metal, Enum.Material.Metal, { Name = "Cabeca" })
	c:cilindro(CF(0, 0, -0.78) * giro, 0.06, 0.47, RGB(160, 162, 168), Enum.Material.Metal)
	local lente = c:cilindro(CF(0, 0, -0.8) * giro, 0.03, 0.36, RGB(255, 244, 222), Enum.Material.Neon, { Name = "Lente" })
	c:caixa(V3(0, 0.17, 0.05), V3(0.08, 0.06, 0.18), RGB(150, 40, 36), Enum.Material.SmoothPlastic, { Name = "Botao" })
	c:cilindro(CF(0, 0, 0.7) * giro, 0.06, 0.26, metal, Enum.Material.Metal)
	-- mão segurando (estilo blocado, combina com o Roblox)
	local corPele = pele or RGB(214, 170, 134)
	c:caixa(V3(0.02, -0.12, 0.25), V3(0.36, 0.34, 0.5), corPele, Enum.Material.SmoothPlastic, { Name = "Mao" })
	c:caixa(V3(0.02, -0.22, 0.85), V3(0.44, 0.44, 0.9), RGB(48, 46, 54), Enum.Material.Fabric, { Name = "Manga" })
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Anchored = true
		end
	end
	m.PrimaryPart = raiz
	return m, lente
end

local function criarViewmodel()
	local char = estado.char
	local pele = nil
	if char then
		local cabeca = char:FindFirstChild("Head")
		if cabeca and cabeca:IsA("BasePart") then
			pele = cabeca.Color
		end
	end
	local m, lente = PrimeiraPessoa.montarLanterna(pele)
	-- luzes na lente
	local principal = Instance.new("SpotLight")
	principal.Name = "Feixe"
	principal.Face = Enum.NormalId.Right -- a lente é um cilindro girado: a face "Right" (+X) aponta para a frente
	principal.Brightness = 3.2
	principal.Range = 52
	principal.Angle = 40
	principal.Color = RGB(255, 241, 222)
	principal.Shadows = not estado.leve
	principal.Parent = lente
	local espalhada = Instance.new("SpotLight")
	espalhada.Name = "Espalhada"
	espalhada.Face = Enum.NormalId.Right
	espalhada.Brightness = 0.55
	espalhada.Range = 24
	espalhada.Angle = 100
	espalhada.Color = RGB(255, 236, 214)
	espalhada.Shadows = false
	espalhada.Enabled = not estado.leve
	espalhada.Parent = lente
	local brilho = Instance.new("PointLight")
	brilho.Name = "Brilho"
	brilho.Brightness = 0.6
	brilho.Range = 2.5
	brilho.Color = RGB(255, 236, 214)
	brilho.Parent = lente
	estado.luzes = { principal, espalhada, brilho }
	m.Parent = workspace.CurrentCamera
	estado.vm = m
	estado.vmRaiz = m.PrimaryPart
	estado.lente = lente
	PrimeiraPessoa.definirLuz(estado.luzLigada)
end

-- liga/desliga a luz da lanterna (visual local)
function PrimeiraPessoa.definirLuz(ligar: boolean)
	estado.luzLigada = ligar
	local lente = estado.lente
	if lente then
		lente.Color = if ligar then RGB(255, 244, 222) else RGB(40, 40, 44)
		lente.Material = if ligar then Enum.Material.Neon else Enum.Material.Glass
	end
	for _, l in estado.luzes do
		if l.Name == "Espalhada" then
			l.Enabled = ligar and not estado.leve
		else
			l.Enabled = ligar
		end
	end
end

-- a luz que o servidor coloca na cabeça (para os outros verem) fica desligada só para mim
local function apagarLuzDoServidor(char: Model)
	local cabeca = char:WaitForChild("Head", 5)
	if not cabeca then
		return
	end
	local function vigiar(l: Instance)
		if l:IsA("SpotLight") and l.Name == "OI3_Lanterna" then
			l.Enabled = false
			table.insert(estado.conexoes, l:GetPropertyChangedSignal("Enabled"):Connect(function()
				if l.Enabled then
					l.Enabled = false
				end
			end))
		end
	end
	for _, l in cabeca:GetChildren() do
		vigiar(l)
	end
	table.insert(estado.conexoes, cabeca.ChildAdded:Connect(vigiar))
end

---------------------------------------------------------------------------
-- Quadro a quadro
---------------------------------------------------------------------------

local function atualizar(dt: number)
	local cam = workspace.CurrentCamera
	local hum = estado.hum
	local raiz = estado.raiz
	if not (cam and hum and raiz and hum.Parent) then
		return
	end
	dt = math.min(dt, 0.1)
	estado.tempo += dt

	-- velocidade no chão
	local v = raiz.AssemblyLinearVelocity
	local velH = V3(v.X, 0, v.Z).Magnitude
	local noChao = hum.FloorMaterial ~= Enum.Material.Air
	local andando = velH > 0.6 and noChao

	-- corrida e estamina
	local corre = estado.querCorrer and andando and not estado.cansado and hum.MoveDirection.Magnitude > 0.1
	estado.correndo = corre
	if corre then
		estado.stamina = math.max(0, estado.stamina - dt * 0.2)
		estado.ultimoGasto = estado.tempo
		if estado.stamina <= 0 then
			estado.cansado = true
			Som.tocar("respiracao", { volume = 0.55 })
		end
	elseif estado.tempo - estado.ultimoGasto > 0.9 then
		local taxa = if andando then 0.11 else 0.17
		estado.stamina = math.min(1, estado.stamina + dt * taxa)
	end
	if estado.cansado and estado.stamina >= 0.35 then
		estado.cansado = false
	end
	local alvoVel = if estado.cansado then VEL_CANSADO elseif corre then VEL_CORRER else VEL_ANDAR
	hum.WalkSpeed += (alvoVel - hum.WalkSpeed) * math.min(1, dt * 6)
	if estado.aoEstamina then
		estado.aoEstamina(estado.stamina, corre, estado.cansado)
	end

	-- balanço da câmera
	local alvoAmp = if andando then math.clamp(velH / VEL_ANDAR, 0, 1.8) else 0
	estado.amp += (alvoAmp - estado.amp) * math.min(1, dt * 7)
	if andando then
		estado.fase += velH * dt * (2 * math.pi / PASSADA)
	end
	local k = estado.amp * (if estado.tremor then 1 else 0.35)
	local f = estado.fase
	local bobY = math.sin(f * 2) * 0.11 * k
	local bobX = math.sin(f) * 0.07 * k
	local rolagem = math.sin(f) * math.rad(0.9) * k
	local inclinacao = math.sin(f * 2) * math.rad(0.35) * k
	-- respiração parada (bem leve)
	local resp = (if estado.cansado then 2.6 else 1) * (1 - math.clamp(estado.amp, 0, 1))
	bobY += math.sin(estado.tempo * (if estado.cansado then 3.2 else 1.5)) * 0.018 * resp
	inclinacao += math.sin(estado.tempo * 1.1) * math.rad(0.12) * resp

	-- passos sincronizados com o balanço (um passo a cada meia volta)
	local passo = math.floor(f * 2 / math.pi)
	if passo ~= estado.passoAnterior and andando then
		estado.passoAnterior = passo
		local vol = math.clamp(0.18 + velH / 40, 0.2, 0.55)
		local nome = PrimeiraPessoa.somDoPasso(hum.FloorMaterial, math.random(1, 3), Som.disponivel)
		Som.tocar(nome, { volume = vol, velocidade = 0.92 + math.random() * 0.16 })
	end

	-- FOV (abre um pouco ao correr)
	local alvoFov = if corre then 80 else 72
	estado.fov += (alvoFov - estado.fov) * math.min(1, dt * 5)
	cam.FieldOfView = estado.fov

	local cfCam = cam.CFrame * CF(bobX, bobY, 0) * CFrame.Angles(inclinacao, 0, rolagem)
	cam.CFrame = cfCam

	-- lanterna na mão: segue a câmera com atraso (inércia) e balança mais que ela
	local vm = estado.vmRaiz
	if vm then
		local anterior = estado.ultimoCam or cfCam
		local delta = anterior:ToObjectSpace(cfCam)
		local rx, ry = delta:ToEulerAnglesYXZ()
		local alvoRot = Vector2.new(math.clamp(-ry * 3.5, -0.25, 0.25), math.clamp(-rx * 3.5, -0.2, 0.2))
		estado.balancoRot = estado.balancoRot:Lerp(alvoRot, math.min(1, dt * 10))
		estado.ultimoCam = cfCam
		local corrida = if corre then 1.6 else 1
		local swayX = math.sin(f) * 0.05 * k * corrida
		local swayY = math.abs(math.sin(f)) * 0.06 * k * corrida
		local base = cfCam * CF(0.78 + swayX, -0.72 - swayY, -1.35)
		local rot = CFrame.Angles(math.rad(3) + estado.balancoRot.Y, math.rad(-6) + estado.balancoRot.X, math.sin(f) * math.rad(2) * k)
		-- move o modelo inteiro (peças ancoradas dentro da câmera)
		local modelo = estado.vm
		if modelo then
			modelo:PivotTo(base * rot)
		end
	end

	-- piscadas raras da lanterna (clima)
	if estado.luzLigada and not estado.piscando and estado.tempo > estado.proximaPiscada then
		estado.proximaPiscada = estado.tempo + 35 + math.random() * 45
		estado.piscando = true
		task.spawn(function()
			for _, liga in { false, true, false, false, true } do
				for _, l in estado.luzes do
					l.Enabled = liga and estado.luzLigada
				end
				task.wait(0.05 + math.random() * 0.08)
			end
			PrimeiraPessoa.definirLuz(estado.luzLigada)
			estado.piscando = false
		end)
	end
end

---------------------------------------------------------------------------

function PrimeiraPessoa.configurar(o: { tremor: boolean?, leve: boolean? })
	if o.tremor ~= nil then
		estado.tremor = o.tremor
	end
	if o.leve ~= nil then
		estado.leve = o.leve
		for _, l in estado.luzes do
			if l.Name == "Feixe" then
				(l :: SpotLight).Shadows = not o.leve
			elseif l.Name == "Espalhada" then
				l.Enabled = estado.luzLigada and not o.leve
			end
		end
	end
end

function PrimeiraPessoa.aoEstamina(fn: (number, boolean, boolean) -> ())
	estado.aoEstamina = fn
end

function PrimeiraPessoa.correr(sim: boolean)
	estado.querCorrer = sim
end

function PrimeiraPessoa.luzLigada(): boolean
	return estado.luzLigada
end

function PrimeiraPessoa.ligar(char: Model)
	PrimeiraPessoa.desligar()
	local lp = Players.LocalPlayer
	estado.char = char
	estado.hum = char:WaitForChild("Humanoid", 10) :: Humanoid
	estado.raiz = char:WaitForChild("HumanoidRootPart", 10) :: BasePart
	if not (estado.hum and estado.raiz) then
		return
	end
	estado.ativo = true
	estado.stamina = 1
	estado.cansado = false
	estado.fov = 72
	estado.ultimoCam = nil
	estado.proximaPiscada = estado.tempo + 40
	lp.CameraMode = Enum.CameraMode.LockFirstPerson
	lp.CameraMinZoomDistance = 0.5
	lp.CameraMaxZoomDistance = 0.5
	criarViewmodel()
	task.spawn(apagarLuzDoServidor, char)
	RunService:BindToRenderStep("OI3_PrimeiraPessoa", Enum.RenderPriority.Camera.Value + 1, atualizar)
end

function PrimeiraPessoa.desligar()
	if not estado.ativo then
		return
	end
	estado.ativo = false
	pcall(function()
		RunService:UnbindFromRenderStep("OI3_PrimeiraPessoa")
	end)
	for _, c in estado.conexoes do
		c:Disconnect()
	end
	estado.conexoes = {}
	if estado.vm then
		estado.vm:Destroy()
		estado.vm = nil
		estado.vmRaiz = nil
		estado.lente = nil
		estado.luzes = {}
	end
	local lp = Players.LocalPlayer
	lp.CameraMode = Enum.CameraMode.Classic
	lp.CameraMinZoomDistance = 0.5
	lp.CameraMaxZoomDistance = 14
	local cam = workspace.CurrentCamera
	if cam then
		cam.FieldOfView = 70
	end
	estado.querCorrer = false
	estado.char = nil
	estado.hum = nil
	estado.raiz = nil
end

return PrimeiraPessoa
