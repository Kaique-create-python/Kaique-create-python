-- OI3 :: personagens (rigs R6 montados por código + rostos desenhados por código)
-- Provisório: as roupas/acessórios oficiais virão por IDs do catálogo depois.

local Personagens = {}

local V3 = Vector3.new
local CF = CFrame.new
local RGB = Color3.fromRGB

export type Def = {
	nome: string,
	escala: number,
	cores: { pele: Color3, torso: Color3, bracos: Color3, pernas: Color3 },
	rosto: string,
	bochechas: boolean?,
	-- Futuro (AJUSTE seguinte): IDs do catálogo informados pelos criadores
	catalogo: { camisa: number?, calca: number?, acessorios: { number }? }?,
}

Personagens.DEFS = {
	VO = {
		nome = "Vô",
		escala = 1.12,
		cores = { pele = RGB(222, 182, 150), torso = RGB(108, 90, 70), bracos = RGB(108, 90, 70), pernas = RGB(62, 62, 68) },
		rosto = "feliz",
	},
	KE = {
		nome = "Keko",
		escala = 0.9,
		cores = { pele = RGB(214, 170, 134), torso = RGB(26, 26, 30), bracos = RGB(26, 26, 30), pernas = RGB(20, 20, 24) },
		rosto = "serio",
	},
	NI = {
		nome = "Nina",
		escala = 0.88,
		cores = { pele = RGB(236, 202, 170), torso = RGB(178, 150, 214), bracos = RGB(178, 150, 214), pernas = RGB(62, 88, 140) },
		rosto = "neutro",
		bochechas = true,
	},
	ME = {
		nome = "Menino",
		escala = 0.9,
		cores = { pele = RGB(228, 186, 148), torso = RGB(46, 98, 178), bracos = RGB(228, 186, 148), pernas = RGB(24, 24, 28) },
		rosto = "neutro",
	},
} :: { [string]: Def }

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

local function quadro(pai: Instance, nome: string, tam: UDim2, pos: UDim2, cor: Color3, circulo: boolean?): Frame
	local f = Instance.new("Frame")
	f.Name = nome
	f.Size = tam
	f.Position = pos
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = cor
	f.BorderSizePixel = 0
	if circulo then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = f
	end
	f.Parent = pai
	return f
end

-- arco (meia circunferência) usando um círculo com contorno recortado
local function arco(pai: Instance, nome: string, tam: UDim2, pos: UDim2, paraCima: boolean, espessura: number): Frame
	local recorte = Instance.new("Frame")
	recorte.Name = nome
	recorte.Size = tam
	recorte.Position = pos
	recorte.AnchorPoint = Vector2.new(0.5, 0.5)
	recorte.BackgroundTransparency = 1
	recorte.ClipsDescendants = true
	recorte.Parent = pai
	local circ = Instance.new("Frame")
	circ.Name = "Circulo"
	circ.Size = UDim2.fromScale(1, 2)
	circ.Position = if paraCima then UDim2.fromScale(0, 0) else UDim2.fromScale(0, -1)
	circ.BackgroundTransparency = 1
	circ.Parent = recorte
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = circ
	local st = Instance.new("UIStroke")
	st.Thickness = espessura
	st.Color = ESCURO
	st.Parent = circ
	return recorte
end

function Personagens.criarRosto(modelo: Model, bochechas: boolean?)
	local cabeca = modelo:FindFirstChild("Head") :: BasePart
	local s = modelo:GetAttribute("Escala") or 1
	local placa = Instance.new("Part")
	placa.Name = "Rosto"
	placa.Size = V3(1.1, 0.98, 0.05) * s
	placa.Transparency = 1
	placa.CanCollide = false
	placa.CanQuery = false
	placa.CanTouch = false
	placa.Massless = true
	placa.CFrame = cabeca.CFrame * CF(0, 0.02 * s, -0.63 * s)
	placa.Parent = modelo
	local solda = Instance.new("Weld")
	solda.Part0 = cabeca
	solda.Part1 = placa
	solda.C0 = CF(0, 0.02 * s, -0.63 * s)
	solda.Parent = placa

	local sg = Instance.new("SurfaceGui")
	sg.Name = "Desenho"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 140
	sg.LightInfluence = 1
	sg.ClipsDescendants = true
	sg.Parent = placa

	-- olhos
	for _, lado in { "E", "D" } do
		local x = if lado == "E" then 0.31 else 0.69
		local olho = quadro(sg, "Olho" .. lado, UDim2.fromScale(0.2, 0.27), UDim2.fromScale(x, 0.44), RGB(250, 248, 244), true)
		local pupila = quadro(olho, "Pupila", UDim2.fromScale(0.58, 0.5), UDim2.fromScale(0.5, 0.55), ESCURO, true)
		quadro(pupila, "Brilho", UDim2.fromScale(0.34, 0.34), UDim2.fromScale(0.68, 0.3), RGB(255, 255, 255), true)
		local fechado = arco(sg, "Fechado" .. lado, UDim2.fromScale(0.2, 0.1), UDim2.fromScale(x, 0.45), true, 4)
		fechado.Visible = false
		quadro(sg, "Sobrancelha" .. lado, UDim2.fromScale(0.24, 0.055), UDim2.fromScale(x, 0.2), ESCURO, true)
	end
	-- bocas (uma visível por vez)
	local boca = Instance.new("Frame")
	boca.Name = "Boca"
	boca.Size = UDim2.fromScale(0.5, 0.3)
	boca.Position = UDim2.fromScale(0.5, 0.78)
	boca.AnchorPoint = Vector2.new(0.5, 0.5)
	boca.BackgroundTransparency = 1
	boca.Parent = sg
	arco(boca, "Sorriso", UDim2.fromScale(0.62, 0.4), UDim2.fromScale(0.5, 0.42), false, 4)
	arco(boca, "Triste", UDim2.fromScale(0.5, 0.32), UDim2.fromScale(0.5, 0.62), true, 4)
	quadro(boca, "Reta", UDim2.fromScale(0.38, 0.1), UDim2.fromScale(0.5, 0.45), ESCURO, true)
	quadro(boca, "Aberta", UDim2.fromScale(0.26, 0.5), UDim2.fromScale(0.5, 0.5), ESCURO, true)
	local grito = quadro(boca, "Grito", UDim2.fromScale(0.36, 0.86), UDim2.fromScale(0.5, 0.52), ESCURO, true)
	quadro(grito, "Lingua", UDim2.fromScale(0.6, 0.3), UDim2.fromScale(0.5, 0.82), RGB(170, 70, 72), true)
	local risadaRec = Instance.new("Frame")
	risadaRec.Name = "Risada"
	risadaRec.Size = UDim2.fromScale(0.6, 0.6)
	risadaRec.Position = UDim2.fromScale(0.5, 0.62)
	risadaRec.AnchorPoint = Vector2.new(0.5, 0.5)
	risadaRec.BackgroundTransparency = 1
	risadaRec.ClipsDescendants = true
	risadaRec.Parent = boca
	local meia = quadro(risadaRec, "Meia", UDim2.fromScale(1, 2), UDim2.fromScale(0.5, 0), ESCURO, true)
	quadro(meia, "Lingua", UDim2.fromScale(0.5, 0.22), UDim2.fromScale(0.5, 0.86), RGB(170, 70, 72), true)
	if bochechas then
		quadro(sg, "BochechaE", UDim2.fromScale(0.14, 0.09), UDim2.fromScale(0.2, 0.66), RGB(232, 120, 128), true).BackgroundTransparency = 0.55
		quadro(sg, "BochechaD", UDim2.fromScale(0.14, 0.09), UDim2.fromScale(0.8, 0.66), RGB(232, 120, 128), true).BackgroundTransparency = 0.55
	end
	return sg
end

-- Expressões: tamanho do olho, pupila, sobrancelhas (y, rotação E/D) e boca
local EXPR = {
	neutro = { olho = { 0.2, 0.27 }, pupila = 0.5, sob = { 0.2, -4, 4 }, boca = "Reta" },
	feliz = { olho = { 0.19, 0.24 }, pupila = 0.52, sob = { 0.19, -8, 8 }, boca = "Sorriso" },
	serio = { olho = { 0.2, 0.18 }, pupila = 0.62, sob = { 0.25, 16, -16 }, boca = "Reta" },
	sapeca = { olho = { 0.2, 0.2 }, pupila = 0.6, sob = { 0.23, 14, -6 }, boca = "Sorriso" },
	curioso = { olho = { 0.21, 0.29 }, pupila = 0.5, sob = { 0.15, -6, 6 }, boca = "Aberta" },
	nervoso = { olho = { 0.21, 0.29 }, pupila = 0.4, sob = { 0.17, -14, 14 }, boca = "Triste" },
	medo = { olho = { 0.24, 0.34 }, pupila = 0.3, sob = { 0.12, -18, 18 }, boca = "Aberta" },
	grito = { olho = { 0.25, 0.35 }, pupila = 0.26, sob = { 0.11, -22, 22 }, boca = "Grito" },
	rindo = { fechado = true, sob = { 0.17, -8, 8 }, boca = "Risada" },
}
Personagens.EXPRESSOES = EXPR

function Personagens.expressao(modelo: Model, nome: string)
	local placa = modelo:FindFirstChild("Rosto")
	local sg = placa and placa:FindFirstChild("Desenho")
	if not sg then
		return
	end
	local e = EXPR[nome] or EXPR.neutro
	for _, lado in { "E", "D" } do
		local olho = sg:FindFirstChild("Olho" .. lado) :: Frame
		local fechado = sg:FindFirstChild("Fechado" .. lado) :: Frame
		local sob = sg:FindFirstChild("Sobrancelha" .. lado) :: Frame
		if olho and fechado then
			olho.Visible = not e.fechado
			fechado.Visible = e.fechado == true
			if e.olho then
				olho.Size = UDim2.fromScale(e.olho[1], e.olho[2])
				local pupila = olho:FindFirstChild("Pupila") :: Frame
				if pupila then
					pupila.Size = UDim2.fromScale(e.pupila * 1.15, e.pupila)
				end
			end
		end
		if sob then
			local x = if lado == "E" then 0.31 else 0.69
			sob.Position = UDim2.fromScale(x, e.sob[1])
			sob.Rotation = if lado == "E" then e.sob[2] else e.sob[3]
		end
	end
	local boca = sg:FindFirstChild("Boca")
	if boca then
		for _, f in boca:GetChildren() do
			if f:IsA("GuiObject") then
				f.Visible = (f.Name == e.boca)
			end
		end
	end
	modelo:SetAttribute("Expressao", nome)
end

-- Piscar (fecha os olhos rapidamente). Não bloqueia.
function Personagens.piscar(modelo: Model)
	local placa = modelo:FindFirstChild("Rosto")
	local sg = placa and placa:FindFirstChild("Desenho")
	if not sg then
		return
	end
	local olhos = {}
	for _, lado in { "E", "D" } do
		local o = sg:FindFirstChild("Olho" .. lado) :: Frame
		if o and o.Visible then
			table.insert(olhos, { o, o.Size })
		end
	end
	for _, par in olhos do
		par[1].Size = UDim2.fromScale(par[2].X.Scale, 0.03)
	end
	task.delay(0.11, function()
		for _, par in olhos do
			if par[1].Parent and math.abs(par[1].Size.Y.Scale - 0.03) < 0.001 then
				par[1].Size = par[2]
			end
		end
	end)
end

-- Acessório (cabelo) no tamanho do boneco: os bonecos das crianças são menores que o padrão
local function escalarAcessorio(a: Accessory, s: number)
	local alca = a:FindFirstChild("Handle")
	if not alca or not alca:IsA("BasePart") then
		return
	end
	alca.Anchored = false
	alca.CanCollide = false
	alca.CanQuery = false
	alca.CanTouch = false
	alca.Massless = true
	if math.abs(s - 1) > 0.001 then
		local malha = alca:FindFirstChildOfClass("SpecialMesh")
		if malha then
			malha.Scale *= s
			malha.Offset *= s
		end
		alca.Size *= s
		for _, at in alca:GetChildren() do
			if at:IsA("Attachment") then
				at.Position *= s
			end
		end
	end
end

-- Veste o boneco com o kit do catálogo (camisa, calça, cabelo e, se houver, rosto).
-- O kit é montado pelo servidor em ReplicatedStorage.OI3_Roupas; se ainda não existir, segue sem.
function Personagens.vestir(m: Model, codigo: string): boolean
	local pasta = game:GetService("ReplicatedStorage"):FindFirstChild("OI3_Roupas")
	local kit = pasta and pasta:FindFirstChild(codigo)
	if not kit then
		return false
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	local s = (Personagens.DEFS[codigo] and Personagens.DEFS[codigo].escala) or 1
	local vestiu = false
	local pele = Personagens.DEFS[codigo] and Personagens.DEFS[codigo].cores.pele
	for _, x in kit:GetChildren() do
		if x:IsA("Shirt") or x:IsA("Pants") then
			x:Clone().Parent = m
			vestiu = true
			-- onde a roupa não cobre (manga curta, bermuda, pescoço) aparece pele, não a cor antiga
			if pele then
				local partes = if x:IsA("Shirt") then { "Torso", "Left Arm", "Right Arm" } else { "Left Leg", "Right Leg" }
				for _, n in partes do
					local p = m:FindFirstChild(n)
					if p and p:IsA("BasePart") then
						p.Color = pele
					end
				end
			end
		elseif x:IsA("Accessory") and hum then
			local a = x:Clone()
			escalarAcessorio(a, s)
			local ok = pcall(function()
				hum:AddAccessory(a)
			end)
			if not ok then
				a:Destroy()
			end
			vestiu = true
		elseif x:IsA("Decal") and x.Name == "RostoCatalogo" then
			-- rosto escolhido no catálogo: some o rosto desenhado e entra o do catálogo
			local cabeca = m:FindFirstChild("Head")
			if cabeca then
				local placa = m:FindFirstChild("Rosto")
				if placa then
					for _, g in placa:GetDescendants() do
						if g:IsA("SurfaceGui") then
							g.Enabled = false
						end
					end
				end
				local d = x:Clone()
				d.Name = "face"
				d.Parent = cabeca
				m:SetAttribute("RostoCatalogo", true)
			end
		end
	end
	return vestiu
end

-- Cria um personagem pelo código (VO, KE, NI, ME)
function Personagens.criar(codigo: string): Model
	local def = Personagens.DEFS[codigo]
	assert(def, "personagem desconhecido: " .. tostring(codigo))
	local m = Personagens.rig(def.nome, def.escala, def.cores)
	m:SetAttribute("Codigo", codigo)
	Personagens.criarRosto(m, def.bochechas)
	Personagens.expressao(m, def.rosto)
	pcall(Personagens.vestir, m, codigo) -- AJUSTE-5: roupas do catálogo
	return m
end

-- A criatura do espelho: só uma silhueta escura (aparência oficial ainda não definida)
function Personagens.criarCriatura(): Model
	local preto = RGB(6, 6, 8)
	local m = Personagens.rig("Silhueta", 1.42, { pele = preto, torso = preto, bracos = preto, pernas = preto }, Enum.Material.SmoothPlastic)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.CastShadow = false
			p.Reflectance = 0
		end
	end
	local torso = m:FindFirstChild("Torso")
	if torso then
		local fumaca = Instance.new("Smoke")
		fumaca.Color = RGB(8, 8, 10)
		fumaca.Opacity = 0.12
		fumaca.RiseVelocity = 0.6
		fumaca.Size = 2.5
		fumaca.Parent = torso
	end
	m:SetAttribute("Codigo", "CRIATURA")
	return m
end

return Personagens
