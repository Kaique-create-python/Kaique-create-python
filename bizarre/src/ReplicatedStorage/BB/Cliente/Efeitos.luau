-- BIZARRE BATTLEGROUNDS :: efeitos visuais (só no celular; o servidor manda o "que" e o "onde")
-- faíscas, anéis, crateras, destroços, punhos da barragem, projéteis, tempo parado, sol, onomatopeias.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local BB = script.Parent.Parent
local Config = require(BB:WaitForChild("Config"))
local Stands = require(BB:WaitForChild("Stands"))
local Sons = require(BB:WaitForChild("Sons"))
local Som = require(script.Parent:WaitForChild("Som"))
local Animador = require(script.Parent:WaitForChild("Animador"))
local Camera = require(script.Parent:WaitForChild("Camera"))

local Efeitos = {}

local pasta: Folder
local rng = Random.new()
local qualidadeAlta = true
local destrocosAtivos = 0
local RGB = Color3.fromRGB
local BRANCO = RGB(255, 255, 255)

function Efeitos.qualidade(alta: boolean)
	qualidadeAlta = alta
end

function Efeitos.altaQualidade(): boolean
	return qualidadeAlta
end

local function corStand(id: string?): Color3
	local s = id and Stands.get(id)
	return if s then s.aura else BRANCO
end
Efeitos.corStand = corStand

local function parte(tam: Vector3, cf: CFrame, cor: Color3, material: Enum.Material?, forma: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = tam
	p.CFrame = cf
	p.Color = cor
	p.Material = material or Enum.Material.Neon
	if forma then
		p.Shape = forma
	end
	p.Parent = pasta
	return p
end

local function tween(obj: Instance, dur: number, props: any, estilo: Enum.EasingStyle?, direcao: Enum.EasingDirection?)
	local t = TweenService:Create(obj, TweenInfo.new(dur, estilo or Enum.EasingStyle.Quad, direcao or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

------------------------------------------------------------------------------------- primitivos
-- estilhaços brilhantes que voam para fora
function Efeitos.faiscas(pos: Vector3, cor: Color3, n: number?, forca: number?)
	local qtd = n or 8
	if not qualidadeAlta then
		qtd = math.ceil(qtd / 2)
	end
	local f = forca or 6
	for _ = 1, qtd do
		local dir = rng:NextUnitVector()
		local tam = rng:NextNumber(0.15, 0.35)
		local p = parte(Vector3.new(tam, tam, rng:NextNumber(1, 2.4)), CFrame.lookAt(pos, pos + dir), cor)
		tween(p, rng:NextNumber(0.18, 0.32), { CFrame = CFrame.lookAt(pos + dir * f, pos + dir * (f + 1)), Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.2) })
		Debris:AddItem(p, 0.4)
	end
end

-- anel deitado que se espalha
function Efeitos.anel(pos: Vector3, raio: number, cor: Color3, dur: number?, espessura: number?, normal: Vector3?)
	local n = normal or Vector3.new(0, 1, 0)
	local base
	if math.abs(n.Unit.Y) > 0.98 then
		base = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	else
		base = CFrame.lookAt(pos, pos + n) * CFrame.Angles(0, math.rad(90), 0)
	end
	local p = parte(Vector3.new(espessura or 0.4, 1, 1), base, cor, Enum.Material.Neon, Enum.PartType.Cylinder)
	p.Transparency = 0.15
	tween(p, dur or 0.35, { Size = Vector3.new(0.05, raio * 2, raio * 2), Transparency = 1 })
	Debris:AddItem(p, (dur or 0.35) + 0.05)
end

-- bola que cresce e some (explosões, ondas)
function Efeitos.bolha(pos: Vector3, raio: number, cor: Color3, dur: number?, material: Enum.Material?)
	local p = parte(Vector3.new(1, 1, 1), CFrame.new(pos), cor, material or Enum.Material.ForceField, Enum.PartType.Ball)
	p.Transparency = 0.05
	tween(p, dur or 0.4, { Size = Vector3.new(raio * 2, raio * 2, raio * 2), Transparency = 1 })
	Debris:AddItem(p, (dur or 0.4) + 0.05)
end

function Efeitos.luz(pos: Vector3, cor: Color3, brilho: number, alcance: number, dur: number)
	local p = parte(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), cor)
	p.Transparency = 1
	local l = Instance.new("PointLight")
	l.Color = cor
	l.Brightness = brilho
	l.Range = alcance
	l.Shadows = false
	l.Parent = p
	tween(l, dur, { Brightness = 0 })
	Debris:AddItem(p, dur + 0.05)
end

-- fumaça/poeira
function Efeitos.poeira(pos: Vector3, tam: number, cor: Color3?, n: number?)
	local p = parte(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), BRANCO)
	p.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(cor or RGB(200, 192, 180))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, tam * 0.4), NumberSequenceKeypoint.new(1, tam) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(tam * 1.2, tam * 2.4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Rate = 0
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Parent = p
	e:Emit(if qualidadeAlta then (n or 14) else math.ceil((n or 14) / 2))
	Debris:AddItem(p, 1.4)
end

-- onomatopeia de mangá ("DOOM!", "TUM TUM")
function Efeitos.onomatopeia(pos: Vector3, texto: string, cor: Color3?, tam: number?)
	local p = parte(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), BRANCO)
	p.Transparency = 1
	local b = Instance.new("BillboardGui")
	b.Size = UDim2.fromScale(10 * (tam or 1), 4 * (tam or 1))
	b.StudsOffset = Vector3.new(rng:NextNumber(-1.5, 1.5), 2.5, 0)
	b.AlwaysOnTop = true
	b.LightInfluence = 0
	b.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(0.4, 0.4)
	t.Position = UDim2.fromScale(0.5, 0.5)
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.BackgroundTransparency = 1
	t.Text = texto
	t.Font = Enum.Font.Bangers
	t.TextScaled = true
	t.TextColor3 = cor or RGB(255, 230, 80)
	t.Rotation = rng:NextNumber(-12, 12)
	t.Parent = b
	local contorno = Instance.new("UIStroke")
	contorno.Thickness = 3
	contorno.Color = RGB(20, 10, 30)
	contorno.Parent = t
	tween(t, 0.16, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
	task.delay(0.55, function()
		tween(t, 0.35, { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.2) })
		tween(contorno, 0.35, { Transparency = 1 })
	end)
	Debris:AddItem(p, 1)
end

function Efeitos.numero(pos: Vector3, valor: number, cor: Color3?)
	local p = parte(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1), 1.5, rng:NextNumber(-1, 1))), BRANCO)
	p.Transparency = 1
	local b = Instance.new("BillboardGui")
	b.Size = UDim2.fromOffset(90, 40)
	b.AlwaysOnTop = true
	b.LightInfluence = 0
	b.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = string.format("%g", math.floor(valor * 10 + 0.5) / 10)
	t.Font = Enum.Font.Bangers
	t.TextScaled = true
	t.TextColor3 = cor or RGB(255, 255, 255)
	t.Parent = b
	local c = Instance.new("UIStroke")
	c.Thickness = 2
	c.Parent = t
	tween(b, 0.7, { StudsOffset = Vector3.new(0, 2.5, 0) })
	task.delay(0.35, function()
		tween(t, 0.35, { TextTransparency = 1 })
		tween(c, 0.35, { Transparency = 1 })
	end)
	Debris:AddItem(p, 0.8)
end

-- cópia "fantasma" do corpo (dash, teleporte)
function Efeitos.fantasma(modelo: Model, cor: Color3, dur: number?)
	if not qualidadeAlta then
		return
	end
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.9 and d.Name ~= "HumanoidRootPart" then
			local p = parte(d.Size, d.CFrame, cor, Enum.Material.Neon)
			p.Transparency = 0.45
			tween(p, dur or 0.35, { Transparency = 1 })
			Debris:AddItem(p, (dur or 0.35) + 0.05)
		end
	end
end

-- cratera: pedras em volta do ponto de impacto que sobem e depois afundam
function Efeitos.cratera(pos: Vector3, raio: number, cor: Color3?)
	local n = if qualidadeAlta then math.clamp(math.floor(raio * 1.1), 8, 22) else 8
	local c = cor or RGB(110, 108, 104)
	local chao = pos.Y
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local d = raio * rng:NextNumber(0.75, 1)
		local tam = Vector3.new(rng:NextNumber(1.4, 2.6), rng:NextNumber(1, 2.2), rng:NextNumber(1.4, 2.6)) * math.clamp(raio / 8, 0.8, 2)
		local alvo = CFrame.new(pos.X + math.cos(a) * d, chao + tam.Y * 0.2, pos.Z + math.sin(a) * d)
			* CFrame.Angles(rng:NextNumber(-0.6, 0.6), a, rng:NextNumber(-0.6, 0.6))
		local p = parte(tam, alvo * CFrame.new(0, -tam.Y, 0), c, Enum.Material.Slate)
		p.CastShadow = true
		tween(p, 0.14, { CFrame = alvo }, Enum.EasingStyle.Back)
		task.delay(3.5 + rng:NextNumber(0, 1), function()
			if p.Parent then
				tween(p, 0.8, { CFrame = alvo * CFrame.new(0, -tam.Y * 1.2, 0), Transparency = 1 })
			end
		end)
		Debris:AddItem(p, 5.6)
	end
	-- buraco escuro no meio
	local disco = parte(Vector3.new(0.2, raio * 1.6, raio * 1.6), CFrame.new(pos.X, chao + 0.06, pos.Z) * CFrame.Angles(0, 0, math.rad(90)), RGB(40, 36, 34), Enum.Material.Slate, Enum.PartType.Cylinder)
	disco.Transparency = 0.25
	task.delay(4, function()
		if disco.Parent then
			tween(disco, 1, { Transparency = 1 })
		end
	end)
	Debris:AddItem(disco, 5.2)
	Efeitos.poeira(Vector3.new(pos.X, chao + 1, pos.Z), raio * 0.6, nil, 18)
end

-- pedaços de uma peça do mapa que quebrou (física de verdade no celular)
local GRUPO_DESTROCOS = "BB_Destrocos"
function Efeitos.destrocos(peca: BasePart, dir: Vector3, forca: number)
	if destrocosAtivos > Config.MAPA.limiteDestrocos then
		return
	end
	local tam = peca.Size
	local volume = tam.X * tam.Y * tam.Z
	local n = if qualidadeAlta then Config.MAPA.destrocosAlto else Config.MAPA.destrocosBaixo
	n = math.clamp(math.floor(n * math.clamp(volume / 40, 0.4, 1.6)), 2, 14)
	local vidro = peca.Material == Enum.Material.Glass
	for _ = 1, n do
		local s = math.clamp(math.min(tam.X, tam.Y, tam.Z) * 0.9, 0.4, 2.6)
		local pedacoTam = Vector3.new(rng:NextNumber(0.5, 1.2) * s, rng:NextNumber(0.5, 1.2) * s, rng:NextNumber(0.5, 1.2) * s)
		if vidro then
			pedacoTam = Vector3.new(rng:NextNumber(0.6, 1.6), rng:NextNumber(0.6, 1.6), 0.15)
		end
		local local_ = Vector3.new(rng:NextNumber(-0.45, 0.45) * tam.X, rng:NextNumber(-0.45, 0.45) * tam.Y, rng:NextNumber(-0.45, 0.45) * tam.Z)
		local p = Instance.new("Part")
		p.Size = pedacoTam
		p.CFrame = peca.CFrame * CFrame.new(local_) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		p.Color = peca.Color
		p.Material = peca.Material
		p.Transparency = if vidro then 0.4 else 0
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = qualidadeAlta
		p.CollisionGroup = GRUPO_DESTROCOS
		p.Parent = pasta
		local v = dir * forca * rng:NextNumber(8, 16) + rng:NextUnitVector() * rng:NextNumber(6, 18) + Vector3.new(0, rng:NextNumber(6, 16), 0)
		p.AssemblyLinearVelocity = v
		p.AssemblyAngularVelocity = rng:NextUnitVector() * rng:NextNumber(4, 12)
		destrocosAtivos += 1
		local vida = rng:NextNumber(3.5, 5.5)
		task.delay(vida, function()
			if p.Parent then
				p.Anchored = true
				tween(p, 0.6, { Transparency = 1, Size = p.Size * 0.4 })
			end
		end)
		task.delay(vida + 0.65, function()
			destrocosAtivos -= 1
			p:Destroy()
		end)
	end
end

-- punhos fantasmas na frente do Stand durante a barragem ("mil socos")
function Efeitos.punhos(standModelo: Model?, dur: number, cor: Color3)
	if not standModelo then
		return
	end
	local raiz = standModelo:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return
	end
	local fim = os.clock() + dur
	task.spawn(function()
		while os.clock() < fim and raiz.Parent do
			for _ = 1, (if qualidadeAlta then 3 else 1) do
				local base = raiz.CFrame * CFrame.new(rng:NextNumber(-1.8, 1.8), rng:NextNumber(-0.2, 1.8), -1.2)
				local p = parte(Vector3.new(0.9, 0.9, 1.1), base, cor, Enum.Material.Neon)
				p.Transparency = 0.35
				tween(p, 0.12, { CFrame = base * CFrame.new(0, 0, -2.6), Transparency = 1 })
				Debris:AddItem(p, 0.15)
			end
			task.wait(0.035)
		end
	end)
end

-- rastro (trilha) preso numa peça
function Efeitos.rastro(peca: BasePart?, cor: Color3, dur: number)
	if not peca then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.6, 0)
	a0.Parent = peca
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.6, 0)
	a1.Parent = peca
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Color = ColorSequence.new(cor)
	tr.LightEmission = 0.8
	tr.Lifetime = 0.25
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	tr.Parent = peca
	task.delay(dur, function()
		tr.Enabled = false
		task.wait(0.3)
		tr:Destroy()
		a0:Destroy()
		a1:Destroy()
	end)
end

-- brilho branco rápido em quem apanhou
local brilhosAtivos = 0
function Efeitos.piscar(modelo: Model?, cor: Color3?)
	if not modelo or brilhosAtivos > 8 then
		return
	end
	brilhosAtivos += 1
	local h = Instance.new("Highlight")
	h.FillColor = cor or BRANCO
	h.FillTransparency = 0.25
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = modelo
	task.delay(0.08, function()
		h:Destroy()
		brilhosAtivos -= 1
	end)
end

-- letras "ゴゴゴ" flutuando (pose ameaçadora)
function Efeitos.ameaca(modelo: Model?, dur: number, cor: Color3?)
	local raiz = modelo and modelo:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return
	end
	local fim = os.clock() + dur
	task.spawn(function()
		while os.clock() < fim and raiz.Parent do
			local pos = raiz.Position + Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(0, 4), rng:NextNumber(-4, 4))
			local p = parte(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), BRANCO)
			p.Transparency = 1
			local b = Instance.new("BillboardGui")
			b.Size = UDim2.fromScale(2.4, 2.4)
			b.LightInfluence = 0
			b.Parent = p
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Text = "ゴ"
			t.Font = Enum.Font.GothamBlack
			t.TextScaled = true
			t.TextColor3 = cor or RGB(170, 90, 230)
			t.TextTransparency = 1
			t.Rotation = rng:NextNumber(-15, 15)
			t.Parent = b
			local c = Instance.new("UIStroke")
			c.Thickness = 2
			c.Color = RGB(30, 0, 40)
			c.Transparency = 1
			c.Parent = t
			tween(t, 0.25, { TextTransparency = 0 })
			tween(c, 0.25, { Transparency = 0 })
			tween(b, 1.4, { StudsOffset = Vector3.new(0, 1.8, 0) }, Enum.EasingStyle.Linear)
			task.delay(1, function()
				tween(t, 0.4, { TextTransparency = 1 })
				tween(c, 0.4, { Transparency = 1 })
			end)
			Debris:AddItem(p, 1.5)
			task.wait(0.22)
		end
	end)
end

-- quadro de impacto (tela pisca em preto e branco por um instante)
local telaImpacto: Frame? = nil
local corImpacto: ColorCorrectionEffect? = nil
function Efeitos.impactFrame()
	if not telaImpacto then
		return
	end
	local tela = telaImpacto
	local cc = corImpacto
	Animador.pausarTudo(0.12)
	if cc then
		cc.Saturation = -1
		cc.Contrast = 0.9
		cc.Brightness = 0.1
		task.delay(0.12, function()
			tween(cc, 0.25, { Saturation = 0, Contrast = 0, Brightness = 0 })
		end)
	end
	tela.BackgroundColor3 = BRANCO
	tela.BackgroundTransparency = 0.25
	task.delay(0.04, function()
		tela.BackgroundColor3 = RGB(0, 0, 0)
		tela.BackgroundTransparency = 0.5
		task.delay(0.05, function()
			tween(tela, 0.15, { BackgroundTransparency = 1 })
		end)
	end)
end

------------------------------------------------------------------------------------- acerto
local TIPOS = {
	impacto = { n = 7, forca = 5, anel = 3, luz = 4 },
	impacto_forte = { n = 14, forca = 9, anel = 6, luz = 8, poeira = 4 },
	impacto_enorme = { n = 22, forca = 13, anel = 10, luz = 12, poeira = 7, bolha = 6 },
	impacto_dourado = { n = 9, forca = 6, anel = 4, luz = 5, cor = RGB(255, 210, 70) },
	impacto_colorido = { n = 12, forca = 7, anel = 5, luz = 6, arcoiris = true },
	impacto_fogo = { n = 9, forca = 6, anel = 3, luz = 6, cor = RGB(255, 130, 30), fogo = true },
	impacto_som = { n = 6, forca = 5, anel = 5, luz = 4, cor = RGB(170, 90, 255), aneis = 2 },
	impacto_rosa = { n = 9, forca = 6, anel = 4, luz = 5, cor = RGB(255, 150, 210) },
	corte_colorido = { n = 6, forca = 7, anel = 2, luz = 3, arcoiris = true },
	explosao_fogo = { n = 16, forca = 10, anel = 7, luz = 12, cor = RGB(255, 120, 30), fogo = true, bolha = 5 },
	explosao_som = { n = 10, forca = 9, anel = 9, luz = 8, cor = RGB(170, 90, 255), aneis = 3, bolha = 7 },
	estilhaco = { n = 14, forca = 8, anel = 5, luz = 6, cor = RGB(255, 160, 220), poeira = 4 },
	eco = { n = 12, forca = 8, anel = 7, luz = 8, cor = RGB(255, 220, 90), aneis = 2 },
	barragem = { n = 3, forca = 4, anel = 0, luz = 0 },
	brasa = { n = 2, forca = 3, anel = 0, luz = 0, cor = RGB(255, 140, 30) },
	cratera = { n = 14, forca = 9, anel = 7, luz = 8, cratera = 9, poeira = 5 },
	agarrao = { n = 4, forca = 3, anel = 2, luz = 2 },
}
local ARCOIRIS = { RGB(232, 44, 70), RGB(250, 210, 40), RGB(36, 200, 96), RGB(40, 120, 230) }

local function chaoAbaixo(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local mapa = workspace:FindFirstChild("BB_Mapa")
	params.FilterDescendantsInstances = if mapa then { mapa } else {}
	local r = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -40, 0), params)
	return if r then r.Position else Vector3.new(pos.X, 0.6, pos.Z)
end
Efeitos.chaoAbaixo = chaoAbaixo

function Efeitos.acerto(d: any)
	local eu = Players.LocalPlayer.Character
	local pos: Vector3 = d.pos or Vector3.zero
	local tipo = d.tipo or "impacto"
	if tipo == "bloqueio" then
		Efeitos.faiscas(pos, RGB(160, 210, 255), 6, 4)
		Efeitos.anel(pos, 2.4, RGB(160, 210, 255), 0.2, 0.2, d.dir)
		Som.tocar("bloqueio", pos)
		if d.v == eu then
			Camera.tremer(0.12, 0.12)
		end
		return
	elseif tipo == "parry" then
		Efeitos.faiscas(pos, BRANCO, 18, 9)
		Efeitos.anel(pos, 6, BRANCO, 0.3, 0.5)
		Efeitos.luz(pos, BRANCO, 8, 18, 0.3)
		Efeitos.onomatopeia(pos, "PARRY!", RGB(140, 220, 255), 1)
		Som.tocar("parry", pos)
		Animador.tocar(d.a, "atordoado", { ate = os.clock() + Config.BLOQUEIO.parryAtordoa })
		if d.a == eu or d.v == eu then
			Camera.tremer(0.35, 0.25)
		end
		return
	elseif tipo == "quebra_guarda" then
		Efeitos.faiscas(pos, RGB(170, 220, 255), 20, 10)
		Efeitos.bolha(pos, 4, RGB(170, 220, 255), 0.3, Enum.Material.Glass)
		Efeitos.onomatopeia(pos, "GUARDA QUEBRADA!", RGB(140, 200, 255), 1.1)
		Som.tocar("quebra_guarda", pos)
		Animador.tocar(d.v, "atordoado", { ate = os.clock() + Config.BLOQUEIO.quebraAtordoa })
		return
	end
	local def = TIPOS[tipo] or TIPOS.impacto
	local cor = def.cor or corStand(d.stand)
	if def.arcoiris then
		cor = ARCOIRIS[rng:NextInteger(1, 4)]
	end
	Efeitos.faiscas(pos, cor, def.n, def.forca)
	if def.anel > 0 then
		Efeitos.anel(pos, def.anel, cor, 0.28, 0.3, d.dir)
	end
	if def.aneis then
		for i = 1, def.aneis do
			task.delay(i * 0.06, function()
				Efeitos.anel(pos, def.anel * (1 + i * 0.4), cor, 0.3, 0.25, d.dir)
			end)
		end
	end
	if def.luz > 0 and qualidadeAlta then
		Efeitos.luz(pos, cor, def.luz * 0.6, def.luz * 3, 0.2)
	end
	if def.bolha then
		Efeitos.bolha(pos, def.bolha, cor, 0.35)
	end
	if def.poeira then
		Efeitos.poeira(pos, def.poeira, nil, 10)
	end
	if def.fogo and qualidadeAlta then
		Efeitos.bolha(pos, 3, RGB(255, 170, 40), 0.25, Enum.Material.Neon)
	end
	if def.cratera then
		Efeitos.cratera(chaoAbaixo(pos), def.cratera)
	end
	if d.som then
		Som.tocar(d.som, pos, { max = if tipo == "barragem" then 3 else 5 })
	end
	if not d.congelado then
		Efeitos.piscar(d.v)
		local forte = (d.ragdoll or 0) > 0 or tipo == "impacto_forte" or tipo == "impacto_enorme"
		local hs = if forte then 0.11 else 0.05
		Animador.hitstop(d.a, hs)
		Animador.hitstop(d.v, hs)
		Animador.hitstop(require(script.Parent:WaitForChild("StandVisual")).modelo(d.a), hs)
		if not forte and not Animador.tocando(d.v) then
			Animador.tocar(d.v, "atordoado")
		end
	end
	-- câmera e números para quem está envolvido
	if d.a == eu then
		Camera.tremer(math.max(0.06, (d.tremor or 0.1) * 0.5), 0.12)
		if (d.dano or 0) > 0 then
			Efeitos.numero(pos, d.dano, if (d.dano or 0) >= 10 then RGB(255, 210, 60) else BRANCO)
		end
	elseif d.v == eu then
		Camera.tremer(math.max(0.15, d.tremor or 0.2), 0.2)
	elseif d.tremor and d.tremor >= 0.8 then
		local meu = eu and eu:FindFirstChild("HumanoidRootPart") :: BasePart?
		if meu and (meu.Position - pos).Magnitude < 60 then
			Camera.tremer(d.tremor * 0.4, 0.3)
		end
	end
	if d.impactFrame and (d.a == eu or d.v == eu) then
		Efeitos.impactFrame()
	end
end

------------------------------------------------------------------------------------- mapa
function Efeitos.quebra(d: any)
	local sons = 0
	for _, item in d.pecas or {} do
		local peca: BasePart? = item[1]
		if peca and peca:IsA("BasePart") then
			local dir = item[2] or Vector3.zero
			local forca = item[3] or 1
			Efeitos.destrocos(peca, if typeof(dir) == "Vector3" then dir else Vector3.zero, math.min(forca, 4))
			if sons < 3 then
				sons += 1
				Som.tocar(Sons.doMaterial(peca.Material.Name), peca.Position, { max = 6 })
			end
			if qualidadeAlta and peca.Size.Magnitude > 4 then
				Efeitos.poeira(peca.Position, math.min(5, peca.Size.Magnitude * 0.3), nil, 6)
			end
		end
	end
end

function Efeitos.restaura(d: any)
	local n = 0
	for _, peca in d.pecas or {} do
		if peca and peca:IsA("BasePart") then
			n += 1
			if n <= 30 and qualidadeAlta then
				local fantasma = parte(peca.Size * 1.08, peca.CFrame, RGB(255, 170, 225), Enum.Material.Neon)
				fantasma.Transparency = 0.5
				tween(fantasma, 0.45, { Transparency = 1, Size = peca.Size })
				Debris:AddItem(fantasma, 0.5)
			end
		end
	end
end

------------------------------------------------------------------------------------- projéteis
local projeteis: { [number]: any } = {}

local function visualProjetil(tipo: string?, cor: Color3, raio: number): (BasePart, number)
	if tipo == "lamina" then
		local p = parte(Vector3.new(0.25, 0.9, 2.6), CFrame.new(), RGB(255, 214, 80), Enum.Material.Neon)
		return p, 0
	elseif tipo == "fogo" then
		local p = parte(Vector3.new(raio * 2, raio * 2, raio * 2), CFrame.new(), RGB(255, 120, 30), Enum.Material.Neon, Enum.PartType.Ball)
		local f = Instance.new("Fire")
		f.Size = raio * 3
		f.Heat = 9
		f.Color = RGB(255, 120, 30)
		f.SecondaryColor = RGB(255, 220, 90)
		f.Parent = p
		local l = Instance.new("PointLight")
		l.Color = RGB(255, 150, 60)
		l.Range = 14
		l.Brightness = 2
		l.Parent = p
		return p, 0
	elseif tipo == "caco" then
		local p = parte(Vector3.new(0.7, 0.35, 1.8), CFrame.new(), RGB(255, 160, 220), Enum.Material.Glass)
		p.Transparency = 0.15
		return p, 0
	elseif tipo == "bola_som" then
		local p = parte(Vector3.new(raio * 2, raio * 2, raio * 2), CFrame.new(), RGB(160, 80, 255), Enum.Material.ForceField, Enum.PartType.Ball)
		return p, 0
	end
	local p = parte(Vector3.new(raio, raio, raio * 2), CFrame.new(), cor, Enum.Material.Neon)
	return p, 0
end

function Efeitos.proj(d: any)
	local cor = corStand(d.stand)
	local p = visualProjetil(d.visual, cor, d.raio or 1.5)
	Efeitos.rastro(p, if d.visual == "fogo" then RGB(255, 140, 40) else cor, 30)
	projeteis[d.id] = { p = p, origem = d.origem, dir = d.dir, vel = d.vel, t = d.t, alcance = d.alcance, visual = d.visual, pausaAte = 0, pausado = 0 }
end

function Efeitos.projFim(d: any)
	local pr = projeteis[d.id]
	if pr then
		projeteis[d.id] = nil
		pr.p:Destroy()
	end
	if d.explodiu == false and d.pos then
		Efeitos.faiscas(d.pos, BRANCO, 4, 3)
	end
end

function Efeitos.projRefletir(d: any)
	local pr = projeteis[d.id]
	if pr then
		pr.origem = d.pos
		pr.dir = d.dir
		pr.t = d.t
		Efeitos.faiscas(d.pos, RGB(255, 230, 120), 10, 6)
		Som.tocar("parry", d.pos)
	end
end

local tempoParadoAte = 0
local tempoInicio = 0
local function passoProjeteis()
	local agora = workspace:GetServerTimeNow()
	for id, pr in projeteis do
		if not pr.p.Parent then
			projeteis[id] = nil
			continue
		end
		local dt = agora - pr.t
		if agora < tempoParadoAte and pr.t < tempoInicio then
			dt = tempoInicio - pr.t
		end
		local dist = math.min(pr.alcance + 4, pr.vel * math.max(0, dt))
		local pos = pr.origem + pr.dir * dist
		local olhar = pos + pr.dir
		local giro = if pr.visual == "lamina" then CFrame.Angles(0, 0, agora * 20) else CFrame.identity
		pr.p.CFrame = CFrame.lookAt(pos, olhar) * giro
		if dist >= pr.alcance + 4 then
			pr.p:Destroy()
			projeteis[id] = nil
		end
	end
end

------------------------------------------------------------------------------------- golpes especiais
function Efeitos.area(d: any)
	local pos: Vector3 = d.pos
	local raio = d.raio or 10
	local cor = corStand(d.stand)
	local vfx = d.vfx
	if vfx == "cratera" then
		Efeitos.cratera(chaoAbaixo(pos), math.min(raio * 0.7, 12))
		Efeitos.anel(chaoAbaixo(pos) + Vector3.new(0, 0.3, 0), raio, cor, 0.35, 0.5)
	elseif vfx == "onda_som" then
		local dir = d.dir or Vector3.new(0, 0, -1)
		for i = 0, 3 do
			task.delay(i * 0.05, function()
				Efeitos.anel(pos + dir * (3 + i * 4) + Vector3.new(0, 1, 0), 3 + i * 3, RGB(170, 90, 255), 0.25, 0.3, dir)
			end)
		end
	elseif vfx == "anel_som" or vfx == "anel_som_grande" then
		local chao = chaoAbaixo(pos) + Vector3.new(0, 0.3, 0)
		Efeitos.anel(chao, raio, RGB(170, 90, 255), 0.3, 0.6)
		Efeitos.anel(chao, raio * 0.6, RGB(80, 255, 140), 0.25, 0.4)
		if vfx == "anel_som_grande" then
			Efeitos.cratera(chao, 6)
		end
	elseif vfx == "confete" then
		for _ = 1, (if qualidadeAlta then 50 else 20) do
			local c = ARCOIRIS[rng:NextInteger(1, 4)]
			local dir = rng:NextUnitVector()
			local p = parte(Vector3.new(0.4, 0.06, 0.6), CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), c, Enum.Material.Neon)
			tween(p, 1.2, { CFrame = CFrame.new(pos + dir * raio * rng:NextNumber(0.3, 1)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Transparency = 1 })
			Debris:AddItem(p, 1.25)
		end
		Efeitos.bolha(pos, raio * 0.6, ARCOIRIS[2], 0.4, Enum.Material.Neon)
	elseif vfx == "onda_rosa" then
		Efeitos.bolha(pos, raio, RGB(255, 160, 220), 0.4)
		Efeitos.anel(chaoAbaixo(pos) + Vector3.new(0, 0.3, 0), raio, RGB(255, 160, 220), 0.35, 0.5)
	else
		Efeitos.acerto({ pos = pos, tipo = vfx, stand = d.stand })
	end
	if d.som then
		Som.tocar(d.som, pos)
	end
	if d.tremor then
		local eu = Players.LocalPlayer.Character
		local raiz = eu and eu:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz and (raiz.Position - pos).Magnitude < raio + 30 then
			Camera.tremer(d.tremor * 0.6, 0.3)
		end
	end
end

function Efeitos.explosao(d: any)
	local pos: Vector3 = d.pos
	local raio = d.raio or 10
	local tipo = d.tipo
	local cor = if tipo == "som" or tipo == "explosao_som" then RGB(170, 90, 255) elseif tipo == "sol" then RGB(255, 200, 60) else RGB(255, 120, 30)
	Efeitos.bolha(pos, raio, cor, 0.5, Enum.Material.Neon)
	Efeitos.bolha(pos, raio * 1.3, BRANCO, 0.6)
	Efeitos.anel(chaoAbaixo(pos) + Vector3.new(0, 0.4, 0), raio * 1.4, cor, 0.5, 0.8)
	Efeitos.luz(pos, cor, 10, raio * 4, 0.6)
	Efeitos.cratera(chaoAbaixo(pos), math.min(raio * 0.6, 16))
	Efeitos.faiscas(pos, cor, 24, raio)
	if d.som then
		Som.tocar(d.som, pos, { alcance = 500 })
	end
	local eu = Players.LocalPlayer.Character
	local raiz = eu and eu:FindFirstChild("HumanoidRootPart") :: BasePart?
	if raiz and (raiz.Position - pos).Magnitude < raio * 3 + 20 then
		Camera.tremer(d.tremor or 0.6, 0.4)
		if d.impactFrame then
			Efeitos.impactFrame()
		end
	end
end

function Efeitos.onda(d: any)
	-- Trio Elétrico: parede de fogo andando
	local fim = os.clock() + d.dur
	local t0 = os.clock()
	local blocos = {}
	local n = if qualidadeAlta then 7 else 4
	for i = 1, n do
		local p = parte(Vector3.new(d.largura / n, d.altura, 2.2), CFrame.new(), RGB(255, 110, 30), Enum.Material.Neon)
		p.Transparency = 0.3
		if qualidadeAlta then
			local f = Instance.new("Fire")
			f.Size = 8
			f.Heat = 12
			f.Color = RGB(255, 100, 20)
			f.SecondaryColor = RGB(255, 220, 80)
			f.Parent = p
		end
		blocos[i] = p
	end
	Som.tocar(d.som or "fogo_grande", d.origem)
	task.spawn(function()
		local base = CFrame.lookAt(d.origem, d.origem + d.dir)
		while os.clock() < fim do
			local dist = (os.clock() - t0) * d.vel
			for i, p in blocos do
				local x = (i - (n + 1) / 2) * (d.largura / n)
				local ondula = math.sin(os.clock() * 14 + i) * 0.6
				p.CFrame = base * CFrame.new(x, d.altura / 2 + ondula, -dist)
			end
			task.wait()
		end
		for _, p in blocos do
			tween(p, 0.3, { Transparency = 1 })
			Debris:AddItem(p, 0.35)
		end
	end)
end

function Efeitos.sol(d: any)
	local inicio = os.clock()
	local sol = parte(Vector3.new(1, 1, 1), CFrame.new(d.acima), RGB(255, 210, 60), Enum.Material.Neon, Enum.PartType.Ball)
	local l = Instance.new("PointLight")
	l.Color = RGB(255, 200, 80)
	l.Range = 60
	l.Brightness = 0
	l.Parent = sol
	local f = Instance.new("Fire")
	f.Size = 25
	f.Heat = 25
	f.Color = RGB(255, 140, 30)
	f.SecondaryColor = RGB(255, 240, 120)
	f.Parent = sol
	tween(sol, d.formar, { Size = Vector3.new(16, 16, 16) }, Enum.EasingStyle.Back)
	tween(l, d.formar, { Brightness = 6 })
	Som.tocar("fogo_grande", d.acima, { alcance = 500 })
	Camera.tremer(0.25, d.formar)
	task.delay(d.formar, function()
		tween(sol, d.cair, { CFrame = CFrame.new(d.alvo + Vector3.new(0, 4, 0)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(d.cair, function()
			sol:Destroy()
		end)
	end)
	local _ = inicio
end

-- tempo parado: tudo cinza, um "domo" invertido se espalha e o relógio tiquetaqueia
local corTempo: ColorCorrectionEffect? = nil
function Efeitos.tempo(d: any)
	local eu = Players.LocalPlayer.Character
	tempoParadoAte = d.fim
	tempoInicio = d.inicio
	local dono = d.dono
	local cc = corTempo
	if cc then
		tween(cc, 0.35, { Saturation = -1, Contrast = 0.25, TintColor = RGB(220, 214, 255) })
	end
	local domo = parte(Vector3.new(2, 2, 2), CFrame.new(d.centro), RGB(30, 20, 60), Enum.Material.Neon, Enum.PartType.Ball)
	domo.Transparency = 0.2
	tween(domo, 0.6, { Size = Vector3.new(d.raio * 2, d.raio * 2, d.raio * 2), Transparency = 1 }, Enum.EasingStyle.Quart)
	Debris:AddItem(domo, 0.7)
	Som.tocar("tempo_para", nil)
	Som.abafar(true)
	Efeitos.onomatopeia(d.centro + Vector3.new(0, 4, 0), "O TEMPO PAROU", RGB(255, 220, 90), 1.6)
	-- congela as animações e efeitos de todo mundo menos de quem parou
	for modelo in pairs(Efeitos._modelosLutadores()) do
		if modelo ~= dono then
			local a = Animador.de(modelo)
			if a then
				a.congelado = true
			end
		end
	end
	task.spawn(function()
		while workspace:GetServerTimeNow() < d.fim do
			Som.tocar("relogio", nil, { vol = 0.6 })
			task.wait(1)
		end
	end)
	if eu and eu ~= dono then
		Camera.tremer(0.3, 0.3)
	end
end

function Efeitos.tempoVolta(d: any)
	tempoParadoAte = 0
	local cc = corTempo
	if cc then
		tween(cc, 0.5, { Saturation = 0.12, Contrast = 0.08, TintColor = RGB(255, 255, 255) })
	end
	Som.tocar("tempo_volta", nil)
	Som.abafar(false)
	for modelo in pairs(Efeitos._modelosLutadores()) do
		local a = Animador.de(modelo)
		if a then
			a.congelado = false
		end
	end
	local raiz = d.dono and d.dono:FindFirstChild("HumanoidRootPart") :: BasePart?
	if raiz then
		Efeitos.bolha(raiz.Position, 40, RGB(255, 240, 200), 0.5)
	end
end

function Efeitos.tempoParadoAgora(): boolean
	return workspace:GetServerTimeNow() < tempoParadoAte
end

function Efeitos.despertar(d: any)
	local modelo = d.quem
	local raiz = modelo and modelo:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return
	end
	local cor = corStand(d.stand)
	Animador.tocar(modelo, "despertar")
	local coluna = parte(Vector3.new(60, 6, 6), CFrame.new(raiz.Position + Vector3.new(0, 26, 0)) * CFrame.Angles(0, 0, math.rad(90)), cor, Enum.Material.Neon, Enum.PartType.Cylinder)
	coluna.Transparency = 0.2
	tween(coluna, 1.2, { Size = Vector3.new(80, 0.5, 0.5), Transparency = 1 })
	Debris:AddItem(coluna, 1.25)
	Efeitos.bolha(raiz.Position, 14, cor, 0.6, Enum.Material.Neon)
	Efeitos.anel(chaoAbaixo(raiz.Position) + Vector3.new(0, 0.3, 0), 18, cor, 0.6, 0.8)
	Efeitos.ameaca(modelo, 2.2, cor)
	Som.tocar("despertar", raiz.Position, { alcance = 400 })
	Som.tocar("gongo", raiz.Position, { alcance = 400 })
	if modelo == Players.LocalPlayer.Character then
		Camera.tremer(0.5, 0.6)
		Camera.fov(10, 0.6)
	end
end

function Efeitos.cura(d: any)
	local modelo = d.quem
	local torso = modelo and (modelo:FindFirstChild("UpperTorso") or modelo:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not torso then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(RGB(255, 170, 225), RGB(170, 255, 230))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.8, 1.3)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Rate = 30
	e.Acceleration = Vector3.new(0, 6, 0)
	e.Parent = torso
	Som.tocar("cura", torso.Position)
	task.delay(d.dur or 2, function()
		e.Enabled = false
		task.wait(1.4)
		e:Destroy()
	end)
end

function Efeitos.teleporte(d: any)
	local modelo = d.quem
	local cor = corStand(d.stand)
	if d.de then
		Efeitos.bolha(d.de, 3, cor, 0.3, Enum.Material.Neon)
	end
	if d.para then
		Efeitos.bolha(d.para, 4, cor, 0.35)
		Efeitos.faiscas(d.para, cor, 10, 5)
		Som.tocar("teleporte", d.para)
	end
	if modelo then
		Efeitos.fantasma(modelo, cor, 0.3)
	end
end

function Efeitos.contra(d: any)
	local raiz = d.quem and d.quem:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return
	end
	if d.reflexo then
		Efeitos.anel(raiz.Position + raiz.CFrame.LookVector * 2, 4, RGB(255, 230, 120), 0.25, 0.3, raiz.CFrame.LookVector)
		return
	end
	Efeitos.onomatopeia(raiz.Position, "CONTRA!", RGB(255, 230, 120), 1.2)
	Efeitos.anel(raiz.Position, 6, BRANCO, 0.3, 0.4)
	Som.tocar("parry", raiz.Position)
end

function Efeitos.marca(d: any)
	local raiz = d.v and d.v:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return
	end
	local cor = corStand(d.stand)
	local anel = parte(Vector3.new(0.2, 4, 4), raiz.CFrame, cor, Enum.Material.Neon, Enum.PartType.Cylinder)
	anel.Transparency = 0.3
	local fim = os.clock() + math.max(0.2, (d.ate or 0) - workspace:GetServerTimeNow())
	task.spawn(function()
		while os.clock() < fim and raiz.Parent and anel.Parent do
			anel.CFrame = CFrame.new(raiz.Position) * CFrame.Angles(0, os.clock() * 6, math.rad(90))
			task.wait()
		end
		anel:Destroy()
	end)
	Som.tocar("relogio", raiz.Position)
end

function Efeitos.agarrao(d: any)
	local alvo = d.alvo
	if alvo then
		Animador.tocar(alvo, "atordoado", { ate = os.clock() + (d.dur or 1) })
	end
	local Golpes = require(BB:WaitForChild("Golpes"))
	local g = Golpes.get(d.id)
	if g and g.agarrao then
		local ag = g.agarrao
		local StandVisual = require(script.Parent:WaitForChild("StandVisual"))
		Animador.tocar(d.quem, ag.animU or "comando_cruzado", { ate = os.clock() + d.dur })
		StandVisual.acao(d.quem, { modo = "frente", clipe = ag.animS or "barragem", dur = d.dur })
		if (ag.animS or "barragem") == "barragem" then
			Efeitos.punhos(StandVisual.modelo(d.quem), d.dur * 0.8, corStand(d.quem and d.quem:GetAttribute("BB_Stand")))
		end
	end
end

function Efeitos.paredao(d: any)
	Som.tocar("tambor", d.cf.Position, { alcance = 300 })
	Efeitos.poeira(d.cf.Position, 6, nil, 16)
end

function Efeitos.pulso(d: any)
	local frente = d.cf * CFrame.new(0, d.altura / 2, -2)
	Efeitos.anel(frente.Position, d.largura * 0.7, RGB(170, 90, 255), 0.3, 0.4, d.cf.LookVector)
	Som.tocar("sub", frente.Position, { vol = 0.6, max = 2 })
end

function Efeitos.baile(d: any)
	local raiz = d.quem and d.quem:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return
	end
	-- caixa de som gigante atrás de quem usou
	local base = raiz.CFrame * CFrame.new(0, 4, 9)
	local caixa = parte(Vector3.new(14, 16, 6), base, RGB(24, 22, 30), Enum.Material.SmoothPlastic)
	local cone = parte(Vector3.new(0.6, 10, 10), base * CFrame.new(0, 1, -3.2) * CFrame.Angles(0, math.rad(90), 0), RGB(170, 90, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	cone.Transparency = 0.2
	local total = d.batidas * d.intervalo + 0.6
	task.spawn(function()
		for _ = 1, d.batidas do
			if not raiz.Parent then
				break
			end
			local pos = raiz.Position
			Efeitos.anel(chaoAbaixo(pos) + Vector3.new(0, 0.4, 0), d.raio, RGB(170, 90, 255), 0.35, 0.8)
			Efeitos.bolha(pos, d.raio * 0.5, RGB(80, 255, 140), 0.3)
			tween(cone, 0.08, { Size = Vector3.new(0.6, 12, 12) })
			task.delay(0.1, function()
				tween(cone, 0.2, { Size = Vector3.new(0.6, 10, 10) })
			end)
			Som.tocar("sub", pos, { alcance = 400 })
			Camera.tremer(0.25, 0.2)
			task.wait(d.intervalo)
		end
	end)
	task.delay(total, function()
		tween(caixa, 0.4, { Transparency = 1 })
		tween(cone, 0.4, { Transparency = 1 })
		Debris:AddItem(caixa, 0.45)
		Debris:AddItem(cone, 0.45)
	end)
end

function Efeitos.reconstruir(d: any)
	Efeitos.bolha(d.pos, d.raio, RGB(255, 160, 220), 0.6)
	Som.tocar("magia", d.pos, { alcance = 300 })
	if (d.n or 0) > 0 then
		Som.tocar("pedra", d.pos)
		Efeitos.onomatopeia(d.pos + Vector3.new(0, 3, 0), "KRIK-KRAK!", RGB(255, 170, 225), 1.2)
	end
end

function Efeitos.esquiva(d: any)
	local raiz = d.v and d.v:FindFirstChild("HumanoidRootPart") :: BasePart?
	if raiz then
		Efeitos.faiscas(raiz.Position, RGB(200, 230, 255), 4, 3)
	end
end

-- lança-chamas contínuo (AXÉ Labareda): sai da mão do Stand
function Efeitos.lancaChamas(dono: Model, dur: number)
	local StandVisual = require(script.Parent:WaitForChild("StandVisual"))
	local fim = os.clock() + dur
	local raizDono = dono:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raizDono then
		return
	end
	local som = Som.naPeca("chama", raizDono, { loop = true })
	task.spawn(function()
		while os.clock() < fim and raizDono.Parent do
			local st = StandVisual.modelo(dono)
			local origemCf = raizDono.CFrame * CFrame.new(0, 0.8, -3.5)
			local mao = st and st:FindFirstChild("RightHand") :: BasePart?
			if mao then
				origemCf = CFrame.lookAt(mao.Position, mao.Position + raizDono.CFrame.LookVector)
			end
			for _ = 1, (if qualidadeAlta then 3 else 1) do
				local dir = (raizDono.CFrame * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.45, 0.45), 0)).LookVector
				local p = parte(Vector3.new(1, 1, 1), origemCf, if rng:NextNumber() < 0.5 then RGB(255, 120, 30) else RGB(255, 210, 70), Enum.Material.Neon, Enum.PartType.Ball)
				p.Transparency = 0.2
				local alvo = origemCf.Position + dir * rng:NextNumber(14, 19)
				tween(p, 0.45, { CFrame = CFrame.new(alvo), Size = Vector3.new(4, 4, 4), Transparency = 1 })
				Debris:AddItem(p, 0.5)
			end
			task.wait(0.04)
		end
		if som then
			som:Destroy()
		end
	end)
end

------------------------------------------------------------------------------------- iniciar
local lutadoresCache: { [Model]: boolean } = {}
function Efeitos._modelosLutadores(): { [Model]: boolean }
	local r = {}
	for _, d in workspace:GetChildren() do
		if d:IsA("Model") and d:GetAttribute("BB_Lutador") then
			r[d] = true
		end
	end
	local bots = workspace:FindFirstChild("BB_Bots")
	if bots then
		for _, d in bots:GetChildren() do
			if d:IsA("Model") then
				r[d] = true
			end
		end
	end
	local sv = workspace:FindFirstChild("BB_StandsVisuais")
	if sv then
		for _, d in sv:GetChildren() do
			if d:IsA("Model") then
				r[d] = true
			end
		end
	end
	lutadoresCache = r
	return r
end

function Efeitos.iniciar(gui: ScreenGui)
	pasta = Instance.new("Folder")
	pasta.Name = "BB_Efeitos"
	pasta.Parent = workspace
	-- tela branca/preta do impact frame
	local tela = Instance.new("Frame")
	tela.Name = "Impacto"
	tela.Size = UDim2.fromScale(1, 1)
	tela.BackgroundTransparency = 1
	tela.BorderSizePixel = 0
	tela.ZIndex = 50
	tela.Parent = gui
	telaImpacto = tela
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "BB_Impacto"
	cc.Parent = Lighting
	corImpacto = cc
	local ct = Instance.new("ColorCorrectionEffect")
	ct.Name = "BB_Tempo"
	ct.Saturation = 0.12
	ct.Contrast = 0.08
	ct.Parent = Lighting
	corTempo = ct
	game:GetService("RunService").PreRender:Connect(passoProjeteis)
	local _ = lutadoresCache
end

return Efeitos
