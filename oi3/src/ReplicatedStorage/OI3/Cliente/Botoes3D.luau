-- OI3 :: botões 3D de verdade (peças com profundidade, aro de metal e relevo).
-- O toque/clique é captado por uma SurfaceGui na frente de cada botão.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Interface = require(script.Parent.Interface)

local Botoes3D = {}

local V3 = Vector3.new
local CF = CFrame.new
local RGB = Color3.fromRGB

export type Def = {
	id: string,
	texto: string,
	cor: Color3,
	corTexto: Color3?,
	principal: boolean?,
	aoClicar: () -> (),
}

local function novaParte(pai: Instance, nome: string, tam: Vector3, cor: Color3, mat: Enum.Material, cf: CFrame, forma: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = nome
	if forma then
		p.Shape = forma
	end
	p.Size = tam
	p.Color = cor
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Anchored = false
	p.Massless = true
	p.CFrame = cf
	p.Parent = pai
	return p
end

local function soldar(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- Pílula: bloco no meio + cilindros nas pontas (eixo do cilindro na profundidade)
local function pilula(pai: Instance, ancora: BasePart, cfLocal: CFrame, L: number, A: number, P: number, cor: Color3, mat: Enum.Material, nome: string): (Part, { Part })
	local cfBase = ancora.CFrame * cfLocal
	local miolo = novaParte(pai, nome, V3(math.max(L - A, 0.05), A, P), cor, mat, cfBase)
	soldar(ancora, miolo)
	local partes = { miolo }
	for _, s in { -1, 1 } do
		local ponta = novaParte(pai, nome .. "Ponta", V3(P, A, A), cor, mat, cfBase * CF(s * (L - A) / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), Enum.PartType.Cylinder)
		soldar(ancora, ponta)
		table.insert(partes, ponta)
	end
	return miolo, partes
end

-- Monta só as peças do botão (sem interface/eventos: dá para testar fora do Roblox)
function Botoes3D.montarPecas(def: Def, L: number, A: number)
	local pecas: any = {}
	local modelo = Instance.new("Model")
	modelo.Name = "Botao_" .. def.id
	pecas.modelo = modelo

	local raiz = novaParte(modelo, "Raiz", V3(0.2, 0.2, 0.2), RGB(0, 0, 0), Enum.Material.SmoothPlastic, CF(0, 0, 0))
	raiz.Transparency = 1
	raiz.Anchored = true
	pecas.raiz = raiz
	modelo.PrimaryPart = raiz

	-- aro de metal envelhecido + fundo escuro (dá o relevo)
	local corAro = RGB(112, 88, 52)
	pilula(modelo, raiz, CF(0, 0, A * 0.22), L + A * 0.26, A * 1.26, A * 0.28, corAro, Enum.Material.Metal, "Aro")
	pilula(modelo, raiz, CF(0, 0, A * 0.13), L + A * 0.06, A * 1.06, A * 0.3, RGB(10, 9, 11), Enum.Material.SmoothPlastic, "Fundo")
	if def.principal then
		local aura = pilula(modelo, raiz, CF(0, 0, A * 0.42), L + A * 0.36, A * 1.36, 0.04, RGB(150, 24, 24), Enum.Material.Neon, "Aura")
		pecas.aura = aura
		pecas.auraPartes = {}
		for _, p in modelo:GetChildren() do
			if p:IsA("BasePart") and string.sub(p.Name, 1, 4) == "Aura" then
				p.Transparency = 0.7
				table.insert(pecas.auraPartes, p)
			end
		end
	end

	-- tampa (a parte que afunda quando aperta)
	local tampaRaiz = novaParte(modelo, "TampaRaiz", V3(0.2, 0.2, 0.2), RGB(0, 0, 0), Enum.Material.SmoothPlastic, raiz.CFrame)
	tampaRaiz.Transparency = 1
	local solda = Instance.new("Weld")
	solda.Part0 = raiz
	solda.Part1 = tampaRaiz
	solda.C0 = CF(0, 0, 0)
	solda.Parent = tampaRaiz
	pecas.solda = solda
	local frente = -A * 0.28 -- frente da tampa (z local)
	local miolo, partesTampa = pilula(modelo, tampaRaiz, CF(0, 0, -A * 0.05), L, A, A * 0.46, def.cor, Enum.Material.SmoothPlastic, "Tampa")
	pecas.tampa = miolo
	pecas.partesTampa = partesTampa
	-- brilho (verniz) na parte de cima da tampa
	local brilho = novaParte(modelo, "Brilho", V3(math.max(L - A, 0.1) * 0.86, A * 0.1, 0.02), def.cor:Lerp(Color3.new(1, 1, 1), 0.45), Enum.Material.SmoothPlastic, tampaRaiz.CFrame * CF(0, A * 0.3, frente - 0.01))
	brilho.Transparency = 0.45
	soldar(tampaRaiz, brilho)
	-- faixa escura embaixo (sombra de volume)
	local sombra = novaParte(modelo, "Sombra", V3(math.max(L - A, 0.1) * 0.9, A * 0.08, 0.02), def.cor:Lerp(Color3.new(0, 0, 0), 0.45), Enum.Material.SmoothPlastic, tampaRaiz.CFrame * CF(0, -A * 0.34, frente - 0.01))
	sombra.Transparency = 0.3
	soldar(tampaRaiz, sombra)

	-- placa invisível para o texto (largura total da pílula, anda junto com a tampa)
	local placaTexto = novaParte(modelo, "PlacaTexto", V3(L * 0.94, A, 0.02), RGB(0, 0, 0), Enum.Material.SmoothPlastic, tampaRaiz.CFrame * CF(0, 0, frente - 0.03))
	placaTexto.Transparency = 1
	soldar(tampaRaiz, placaTexto)

	pecas.frente = frente
	pecas.placaTexto = placaTexto
	pecas.miolo = miolo
	return pecas
end

local Botao = {}
Botao.__index = Botao

-- Cria um botão. L x A em studs (o grupo recalcula conforme a tela).
function Botao.novo(pasta: Instance, def: Def, L: number, A: number, tela: ScreenGui)
	local self = setmetatable({}, Botao)
	self.def = def
	self.L, self.A = L, A
	self.habilitado = true
	self.hover = false
	local pecas = Botoes3D.montarPecas(def, L, A)
	local modelo = pecas.modelo
	self.modelo = modelo
	self.raiz = pecas.raiz
	self.solda = pecas.solda
	self.tampa = pecas.tampa
	self.partesTampa = pecas.partesTampa
	self.auraPartes = pecas.auraPartes
	self.frente = pecas.frente
	local placaTexto = pecas.placaTexto

	-- texto na tampa
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local sgTexto = Instance.new("SurfaceGui")
	sgTexto.Name = "OI3_Texto_" .. def.id
	sgTexto.Adornee = placaTexto
	sgTexto.Face = Enum.NormalId.Front
	sgTexto.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sgTexto.PixelsPerStud = 110
	sgTexto.LightInfluence = 0.25
	sgTexto.Brightness = 1.4
	sgTexto.ResetOnSpawn = false
	sgTexto.Parent = pg
	local rotulo = Instance.new("TextLabel")
	rotulo.Name = "Rotulo"
	rotulo.BackgroundTransparency = 1
	rotulo.Size = UDim2.fromScale(0.9, 0.86)
	rotulo.Position = UDim2.fromScale(0.5, 0.5)
	rotulo.AnchorPoint = Vector2.new(0.5, 0.5)
	rotulo.Text = def.texto
	rotulo.TextScaled = true
	rotulo.FontFace = Interface.FONTE.tituloForte
	rotulo.TextColor3 = def.corTexto or RGB(240, 232, 216)
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = 200
	lim.Parent = rotulo
	local contorno = Instance.new("UIStroke")
	contorno.Thickness = 3
	contorno.Color = RGB(20, 12, 10)
	contorno.Transparency = 0.25
	contorno.Parent = rotulo
	rotulo.Parent = sgTexto
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = rotulo
	self.sgTexto = sgTexto
	self.rotulo = rotulo

	-- entrada (toque/clique): botão 2D invisível que acompanha o botão 3D na tela.
	-- (no celular, botões 2D recebem toque sempre; SurfaceGui não é confiável)
	local botao = Instance.new("TextButton")
	botao.Name = "Toque_" .. def.id
	botao.BackgroundTransparency = 1
	botao.Text = ""
	botao.AutoButtonColor = false
	botao.Selectable = true
	botao.Visible = false
	botao.Parent = tela
	self.botao = botao

	botao.MouseEnter:Connect(function()
		self:definirHover(true)
	end)
	botao.MouseLeave:Connect(function()
		self:definirHover(false)
		self:soltar()
	end)
	botao.MouseButton1Down:Connect(function()
		self:pressionar()
	end)
	botao.MouseButton1Up:Connect(function()
		self:soltar()
	end)
	botao.Activated:Connect(function()
		if not self.habilitado then
			return
		end
		self:soltar()
		task.delay(0.09, function()
			if self.habilitado then
				def.aoClicar()
			end
		end)
	end)

	modelo.Parent = pasta
	return self
end

function Botao:definirHover(sim: boolean)
	if self.hover == sim or not self.habilitado then
		return
	end
	self.hover = sim
	local cor = if sim then self.def.cor:Lerp(Color3.new(1, 1, 1), 0.14) else self.def.cor
	for _, p in self.partesTampa do
		TweenService:Create(p, TweenInfo.new(0.15), { Color = cor }):Play()
	end
	TweenService:Create(self.solda, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { C0 = CF(0, 0, if sim then -self.A * 0.06 else 0) }):Play()
end

function Botao:pressionar()
	if not self.habilitado then
		return
	end
	self.apertado = true
	TweenService:Create(self.solda, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = CF(0, 0, self.A * 0.2) }):Play()
	local escuro = self.def.cor:Lerp(Color3.new(0, 0, 0), 0.25)
	for _, p in self.partesTampa do
		p.Color = escuro
	end
	if self.aoApertar then
		self.aoApertar()
	end
end

function Botao:soltar()
	if not self.apertado then
		return
	end
	self.apertado = false
	TweenService:Create(self.solda, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { C0 = CF(0, 0, if self.hover then -self.A * 0.06 else 0) }):Play()
	local cor = if self.hover then self.def.cor:Lerp(Color3.new(1, 1, 1), 0.14) else self.def.cor
	for _, p in self.partesTampa do
		TweenService:Create(p, TweenInfo.new(0.2), { Color = cor }):Play()
	end
end

function Botao:habilitar(sim: boolean)
	self.habilitado = sim
	self.botao.Active = sim
	if not sim then
		self.botao.Visible = false
	end
	TweenService:Create(self.rotulo, TweenInfo.new(0.2), { TextTransparency = if sim then 0 else 0.55 }):Play()
	if not sim then
		self.hover = false
		self:soltar()
	end
end

-- Posiciona o botão 2D invisível em cima do botão 3D (coordenadas da tela inteira)
function Botao:atualizarToque(camera: Camera, pronto: boolean)
	local b = self.botao
	if not (pronto and self.habilitado) then
		b.Visible = false
		return
	end
	local cf = self.raiz.CFrame * CF(0, 0, self.frente)
	local mx = self.L / 2 + self.A * 0.08
	local my = self.A / 2 + self.A * 0.08
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	-- pontos do meio de cada lado (o retângulo não cresce com a inclinação/perspectiva)
	for _, c in { CF(-mx, 0, 0), CF(mx, 0, 0), CF(0, my, 0), CF(0, -my, 0) } do
		local p = camera:WorldToViewportPoint((cf * c).Position)
		if p.Z <= 0 then
			b.Visible = false -- atrás da câmera
			return
		end
		minX = math.min(minX, p.X)
		minY = math.min(minY, p.Y)
		maxX = math.max(maxX, p.X)
		maxY = math.max(maxY, p.Y)
	end
	local vp = camera.ViewportSize
	minX, minY = math.max(minX, 0), math.max(minY, 0)
	maxX, maxY = math.min(maxX, vp.X), math.min(maxY, vp.Y)
	if maxX - minX < 4 or maxY - minY < 4 then
		b.Visible = false
		return
	end
	b.Position = UDim2.fromOffset(minX, minY)
	b.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
	b.Visible = true
end

function Botao:destruir()
	self.sgTexto:Destroy()
	self.botao:Destroy()
	self.modelo:Destroy()
end

---------------------------------------------------------------------------
-- Grupo (layout responsivo preso à câmera do menu)
---------------------------------------------------------------------------

local Grupo = {}
Grupo.__index = Grupo

function Botoes3D.grupo(pasta: Instance, defs: { Def })
	local self = setmetatable({}, Grupo)
	self.pasta = pasta
	self.defs = defs
	local tela = Instance.new("ScreenGui")
	tela.Name = "OI3_ToqueMenu"
	tela.ResetOnSpawn = false
	tela.IgnoreGuiInset = true
	tela.DisplayOrder = 2
	pcall(function()
		tela.ScreenInsets = Enum.ScreenInsets.None
	end)
	tela.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.tela = tela
	self.botoes = {}
	self.locais = {}
	self.entrada = {} -- 0 = fora da tela, 1 = no lugar
	self.chave = ""
	return self
end

-- Calcula posições (no espaço da câmera) conforme o tamanho da tela
function Botoes3D.calcularLayout(n: number, vw: number, vh: number, fov: number)
	local D = 7
	local meiaA = D * math.tan(math.rad(fov) / 2)
	local aspecto = vw / math.max(vh, 1)
	local meiaL = meiaA * aspecto
	local alvoPx = math.clamp(vh * 0.1, 48, 74)
	local A = alvoPx / vh * 2 * meiaA
	local L = A * 4.1
	local paisagem = aspecto >= 1.15
	if paisagem then
		L = math.min(L, meiaL * 0.62)
	else
		L = math.min(L, meiaL * 1.5)
	end
	local esp = A * 0.46
	local total = n * A + (n - 1) * esp
	local pos = {}
	for i = 1, n do
		local x, y
		if paisagem then
			local margem = math.max(meiaL * 0.16, A * 1.8)
			x = -meiaL + margem + L / 2
			y = total / 2 - A / 2 - (i - 1) * (A + esp) - meiaA * 0.12
		else
			x = 0
			y = -meiaA + meiaA * 0.12 + total - A / 2 - (i - 1) * (A + esp)
		end
		-- a frente do botão (-Z) olha para a câmera, virada um pouco para o centro (mostra a espessura)
		local alvo = Vector3.new(-x * 0.3, y * 0.2, 0)
		pos[i] = CFrame.lookAt(Vector3.new(x, y, -D), alvo) * CFrame.Angles(math.rad(-2), 0, 0)
	end
	return { locais = pos, L = L, A = A, paisagem = paisagem, D = D, meiaA = meiaA, meiaL = meiaL }
end

function Grupo:recriar(vw: number, vh: number, fov: number)
	local lay = Botoes3D.calcularLayout(#self.defs, vw, vh, fov)
	local chave = string.format("%.3f_%.3f_%s", lay.L, lay.A, tostring(lay.paisagem))
	self.locais = lay.locais
	self.layout = lay
	if chave == self.chave then
		return
	end
	self.chave = chave
	local habil = true
	for _, b in self.botoes do
		habil = b.habilitado
		b:destruir()
	end
	self.botoes = {}
	for i, def in self.defs do
		local b = Botao.novo(self.pasta, def, lay.L, lay.A, self.tela)
		b.aoApertar = self.aoApertar
		b:habilitar(habil)
		self.botoes[i] = b
		if self.entrada[i] == nil then
			self.entrada[i] = 0
		end
	end
end

-- Chamar a cada quadro com o CFrame base da câmera (sem o balanço)
function Grupo:atualizar(cfCamera: CFrame, t: number)
	for i, b in self.botoes do
		local local_ = self.locais[i]
		local e = self.entrada[i] or 1
		local fora = (1 - e)
		local desloc = CF(-fora * (self.layout.meiaL * 1.4), 0, 0) * CFrame.Angles(0, -fora * 1.2, 0)
		local balanco = CF(0, math.sin(t * 1.3 + i * 0.9) * 0.012, 0)
		b.raiz.CFrame = cfCamera * desloc * local_ * balanco
		b:atualizarToque(workspace.CurrentCamera, e > 0.85)
		if b.auraPartes then
			local tr = 0.62 + math.sin(t * 2.4) * 0.12
			for _, p in b.auraPartes do
				p.Transparency = tr
			end
		end
	end
end

function Grupo:mostrar(atraso: number?)
	for i in self.defs do
		task.delay((atraso or 0) + (i - 1) * 0.09, function()
			local inicio = os.clock()
			local de = self.entrada[i] or 0
			while true do
				local k = math.clamp((os.clock() - inicio) / 0.5, 0, 1)
				local s = 1 - (1 - k) ^ 3
				self.entrada[i] = de + (1 - de) * s
				if k >= 1 then
					break
				end
				task.wait()
			end
		end)
	end
end

function Grupo:esconder(rapido: boolean?)
	for i in self.defs do
		task.delay(if rapido then 0 else (i - 1) * 0.05, function()
			local inicio = os.clock()
			local de = self.entrada[i] or 1
			while true do
				local k = math.clamp((os.clock() - inicio) / 0.35, 0, 1)
				self.entrada[i] = de * (1 - k * k)
				if k >= 1 then
					break
				end
				task.wait()
			end
		end)
	end
end

function Grupo:habilitar(sim: boolean)
	for _, b in self.botoes do
		b:habilitar(sim)
	end
end

function Grupo:destruir()
	for _, b in self.botoes do
		b:destruir()
	end
	self.botoes = {}
	self.chave = ""
end

return Botoes3D
