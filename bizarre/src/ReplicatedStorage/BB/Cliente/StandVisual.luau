-- BIZARRE BATTLEGROUNDS :: o Stand de cada lutador, desenhado no celular
-- O servidor só diz QUAL Stand e se está para fora (atributos). Aqui o celular copia o corpo
-- (R6 com roupa e acessórios do catálogo, sólido), posiciona atrás do dono (ou na frente quando
-- ataca), anima e faz aparecer/sumir. ARMOR OFF: o Silver Chariot tira as peças de armadura.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BB = script.Parent.Parent
local Stands = require(BB:WaitForChild("Stands"))
local Animador = require(script.Parent:WaitForChild("Animador"))

local StandVisual = {}

local visuais: { [Model]: any } = {}
local pastaVisual: Folder

local MODOS = {
	costas = CFrame.new(1.9, 0.9, 2.4),
	frente = CFrame.new(0, 0.25, -3.6),
	frente_perto = CFrame.new(0.3, 0.15, -2.6),
	acima = CFrame.new(0, 3.8, 1.4),
	lado = CFrame.new(-2.7, 0.6, -0.6),
}

local COLISAO_FORCADA = { "Torso", "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" }

local function agoraServidor(): number
	return workspace:GetServerTimeNow()
end

local function modelosProntos(): Folder?
	return ReplicatedStorage:FindFirstChild("BB_Stands") :: Folder?
end

local function partes(modelo: Model): { BasePart }
	local l = {}
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(l, d)
		end
	end
	return l
end

local function criar(dono: Model, standId: string): any
	local pasta = modelosProntos()
	local molde = pasta and pasta:FindFirstChild(standId)
	if not molde then
		return nil
	end
	local m = (molde :: Model):Clone()
	m.Name = "Stand_" .. dono.Name
	local raiz = m:FindFirstChild("HumanoidRootPart") :: BasePart
	if not raiz then
		m:Destroy()
		return nil
	end
	-- AJUSTE-3: o Stand nunca encosta em ninguém (nem no próprio dono). O Humanoid do R6 força
	-- colisão no tronco e na cabeça; o grupo BB_Efeitos não colide com nada e o passo desliga de novo.
	for _, p in partes(m) do
		p.Anchored = p == raiz
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.CollisionGroup = "BB_Efeitos"
		p.LocalTransparencyModifier = 1
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.EvaluateStateMachine = false
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end
	local s = Stands.get(standId)
	local brilho = Instance.new("Highlight")
	brilho.FillColor = s.aura
	brilho.OutlineColor = s.aura
	brilho.FillTransparency = 0.86
	brilho.OutlineTransparency = 0.2
	brilho.DepthMode = Enum.HighlightDepthMode.Occluded
	brilho.Enabled = false
	brilho.Parent = m
	local torso = (m:FindFirstChild("Torso") or m:FindFirstChild("UpperTorso") or raiz) :: BasePart
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Aura"
	aura.Color = ColorSequence.new(s.aura)
	aura.LightEmission = 0.8
	aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	aura.Lifetime = NumberRange.new(0.5, 0.9)
	aura.Rate = 0
	aura.Speed = NumberRange.new(1, 3)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Parent = torso
	if s.visual.fogo then
		for _, nomeMao in { "Left Arm", "Right Arm", "LeftHand", "RightHand" } do
			local mao = m:FindFirstChild(nomeMao)
			if mao then
				local fogo = Instance.new("Fire")
				fogo.Size = 3
				fogo.Heat = 6
				fogo.Color = Color3.fromRGB(255, 140, 30)
				fogo.SecondaryColor = Color3.fromRGB(255, 220, 80)
				fogo.Enabled = false
				fogo.Parent = mao
			end
		end
	end
	-- peças de armadura (ombreiras, cinto, peitoral): somem no ARMOR OFF
	local armadura = {}
	for _, ac in m:GetChildren() do
		if ac:IsA("Accessory") then
			local tipo = ac.AccessoryType
			if tipo == Enum.AccessoryType.Shoulder or tipo == Enum.AccessoryType.Waist or tipo == Enum.AccessoryType.Front or tipo == Enum.AccessoryType.Back then
				local h = ac:FindFirstChild("Handle")
				if h and h:IsA("BasePart") then
					table.insert(armadura, h)
				end
			end
		end
	end
	local escalaBase = 1
	pcall(function()
		escalaBase = m:GetScale()
	end)
	m.Parent = pastaVisual
	local anim = Animador.registrar(m, "stand")
	local v = {
		dono = dono,
		standId = standId,
		modelo = m,
		raiz = raiz,
		partes = partes(m),
		brilho = brilho,
		aura = aura,
		anim = anim,
		vis = 0,
		alvoVis = 0,
		offset = MODOS.costas,
		modo = "costas",
		acaoAte = 0,
		modoAte = 0,
		escala = 1,
		escalaAlvo = 1,
		escalaBase = escalaBase,
		visita = nil,
		armadura = armadura,
		semArmadura = false,
	}
	return v
end

local function destruir(v: any)
	if v and v.modelo then
		v.modelo:Destroy()
	end
end

-- dono fez uma ação que usa o Stand (golpe, M1 com Stand fora...)
function StandVisual.acao(dono: Model, opcoes: any)
	local v = visuais[dono]
	if not v then
		return
	end
	local agora = os.clock()
	local dur = opcoes.dur or 0.6
	v.acaoAte = math.max(v.acaoAte, agora + dur + 0.9)
	v.modo = opcoes.modo or "frente"
	v.modoAte = agora + dur
	v.escalaAlvo = opcoes.escala or 1
	if opcoes.clipe then
		Animador.tocar(v.modelo, opcoes.clipe, { impacto = opcoes.impacto, ate = agora + dur })
	end
end

-- o Stand aparece em outro lugar (ex.: SAUDADE visita cada inimigo preso)
function StandVisual.visitar(dono: Model, alvo: Model, dur: number)
	local v = visuais[dono]
	if not v or not alvo then
		return
	end
	v.visita = { alvo = alvo, ate = os.clock() + dur }
	v.acaoAte = math.max(v.acaoAte, os.clock() + dur + 0.6)
	Animador.tocar(v.modelo, "barragem", { ate = os.clock() + dur })
end

function StandVisual.modelo(dono: Model): Model?
	local v = visuais[dono]
	return v and v.modelo
end

function StandVisual.visivel(dono: Model): boolean
	local v = visuais[dono]
	return v ~= nil and v.vis > 0.5
end

local function atualizar(v: any, dt: number)
	local dono = v.dono
	local raizDono = dono:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = dono:FindFirstChildOfClass("Humanoid")
	if not raizDono or not hum or hum.Health <= 0 then
		v.alvoVis = 0
	else
		local agora = os.clock()
		local fora = dono:GetAttribute("BB_StandFora") == true
		local desperto = (dono:GetAttribute("BB_Desperto") or 0) > agoraServidor()
		local caido = (dono:GetAttribute("BB_Ragdoll") or 0) > agoraServidor()
		v.alvoVis = if (fora or desperto or agora < v.acaoAte) and not caido then 1 else 0
		-- o Humanoid liga a colisão do tronco/cabeça sozinho: desliga antes da câmera olhar
		for _, nome in COLISAO_FORCADA do
			local p = v.modelo:FindFirstChild(nome)
			if p and p:IsA("BasePart") and p.CanCollide then
				p.CanCollide = false
			end
		end
		if agora >= v.modoAte then
			v.modo = "costas"
			v.escalaAlvo = 1
		end
		local alvoOffset = MODOS[v.modo] or MODOS.costas
		local bob = math.sin(agora * 2.1) * 0.22
		if v.modo == "costas" then
			alvoOffset = alvoOffset * CFrame.new(0, bob, 0)
		end
		v.offset = v.offset:Lerp(alvoOffset, math.min(1, dt * 16))
		local cf = raizDono.CFrame * v.offset
		if v.visita and agora < v.visita.ate and v.visita.alvo.Parent then
			local r = v.visita.alvo:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				local p = r.Position + (raizDono.Position - r.Position).Unit * 3.2
				cf = CFrame.lookAt(p, r.Position)
			end
		end
		v.raiz.CFrame = cf
		-- aura mais forte desperto
		v.aura.Rate = if v.vis > 0.5 then (if desperto then 26 else 7) else 0
		for _, d in v.modelo:GetDescendants() do
			if d:IsA("Fire") then
				d.Enabled = v.vis > 0.5
			end
		end
	end
	-- aparecer / sumir
	local antes = v.vis
	local vel = if v.alvoVis > v.vis then 9 else 5
	v.vis += (v.alvoVis - v.vis) * math.min(1, dt * vel)
	if math.abs(v.vis - antes) > 0.002 or (v.vis > 0.99 and antes <= 0.99) or (v.vis < 0.01 and antes >= 0.01) then
		-- AJUSTE-2: aparecido, o Stand fica sólido (sem transparência)
		local ltm = 1 - v.vis
		if v.vis > 0.97 then
			ltm = 0
		elseif v.vis < 0.01 then
			ltm = 1
		end
		for _, p in v.partes do
			p.LocalTransparencyModifier = ltm
		end
		v.ltm = ltm
		v.semArmadura = nil -- recalcula a armadura abaixo
		v.brilho.Enabled = v.vis > 0.05
		v.brilho.FillTransparency = 1 - v.vis * 0.08
		v.brilho.OutlineTransparency = 1 - v.vis * 0.75
	end
	-- ARMOR OFF: esconde ombreiras/cinto/peitoral enquanto durar
	local semArmadura = (dono:GetAttribute("BB_SemArmadura") or 0) > agoraServidor()
	if #v.armadura > 0 and semArmadura ~= v.semArmadura then
		v.semArmadura = semArmadura
		for _, h in v.armadura do
			h.LocalTransparencyModifier = if semArmadura then 1 else (v.ltm or 1)
		end
	end
	-- crescer na ULT (a escala do molde já vem maior que o usuário)
	if math.abs(v.escala - v.escalaAlvo) > 0.01 then
		v.escala += (v.escalaAlvo - v.escala) * math.min(1, dt * 6)
		pcall(function()
			v.modelo:ScaleTo(v.escalaBase * v.escala)
		end)
		Animador.atualizarJuntas(v.modelo)
	end
end

function StandVisual.passo(dt: number)
	-- quem tem Stand
	for _, m in StandVisual.donos() do
		local id = m:GetAttribute("BB_Stand")
		local v = visuais[m]
		if type(id) == "string" and Stands.get(id) then
			if not v or v.standId ~= id then
				if v then
					destruir(v)
				end
				visuais[m] = criar(m, id)
			end
		elseif v then
			destruir(v)
			visuais[m] = nil
		end
	end
	for dono, v in visuais do
		if not dono.Parent then
			destruir(v)
			visuais[dono] = nil
		else
			atualizar(v, dt)
		end
	end
end

local listaDonos: { Model } = {}
local proximaBusca = 0
function StandVisual.donos(): { Model }
	if os.clock() < proximaBusca then
		return listaDonos
	end
	proximaBusca = os.clock() + 0.5
	local l = {}
	for _, d in workspace:GetChildren() do
		if d:IsA("Model") and d:GetAttribute("BB_Lutador") then
			table.insert(l, d)
		end
	end
	local bots = workspace:FindFirstChild("BB_Bots")
	if bots then
		for _, d in bots:GetChildren() do
			if d:IsA("Model") and d:GetAttribute("BB_Lutador") and not d:GetAttribute("BB_Boneco") then
				table.insert(l, d)
			end
		end
	end
	listaDonos = l
	return l
end

function StandVisual.iniciar()
	pastaVisual = Instance.new("Folder")
	pastaVisual.Name = "BB_StandsVisuais"
	pastaVisual.Parent = workspace
	RunService.PreRender:Connect(function(dt)
		StandVisual.passo(dt)
	end)
end

StandVisual.MODOS = MODOS
local _ = TweenService
return StandVisual
