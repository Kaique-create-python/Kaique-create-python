-- BIZARRE BATTLEGROUNDS :: VFX estilo anime (AJUSTE-10)
-- Biblioteca de efeitos reaproveitáveis, no jeito dos battlegrounds do Roblox (Jujutsu Shenanigans,
-- jogos de Stand): clarão, anel de choque, arco branco em meia-lua (o "swoosh"), brilho em estrela,
-- estilhaços brancos/pretos/da cor do Stand, linhas de velocidade e fumaça.
-- Tudo é local (cada celular desenha o seu), some sozinho e tem teto de peças vivas.
-- Feito só com peças Neon e as texturas que já vêm dentro do Roblox: nada para moderar ou baixar.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local VFX = {}

local RGB = Color3.fromRGB
local BRANCO = RGB(255, 255, 255)
local PRETO = RGB(14, 6, 24)
VFX.BRANCO = BRANCO
VFX.PRETO = PRETO

local rng = Random.new()
local alta = true
local vivos = 0 -- peças de efeito vivas agora
local TETO = 320 -- passou disso, os detalhes são pulados (o celular não engasga)
local pasta: Instance? = nil

local TEX = {
	brilho = "rbxasset://textures/particles/sparkles_main.dds",
	fumaca = "rbxasset://textures/particles/smoke_main.dds",
}

function VFX.qualidade(sim: boolean)
	alta = sim
end

function VFX.vivos(): number
	return vivos
end

local function obterPasta(): Instance
	if pasta and pasta.Parent then
		return pasta
	end
	local p = workspace:FindFirstChild("BB_VFX")
	if not p then
		p = Instance.new("Folder")
		p.Name = "BB_VFX"
		p.Parent = workspace
	end
	pasta = p
	return p
end

local function tween(obj: Instance, dur: number, props: any, estilo: Enum.EasingStyle?, direcao: Enum.EasingDirection?)
	local t = TweenService:Create(obj, TweenInfo.new(dur, estilo or Enum.EasingStyle.Quad, direcao or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- peça de efeito que some sozinha; nil se o teto de peças foi atingido
local function peca(tam: Vector3, cf: CFrame, cor: Color3, vida: number, material: Enum.Material?, forma: Enum.PartType?): Part?
	if vivos >= TETO then
		return nil
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if forma then
		p.Shape = forma
	end
	p.Size = tam
	p.CFrame = cf
	p.Color = cor
	p.Material = material or Enum.Material.Neon
	p.Parent = obterPasta()
	vivos += 1
	task.delay(vida, function()
		vivos -= 1
		p:Destroy()
	end)
	return p
end

-- de frente para a câmera
local function deFrente(pos: Vector3): CFrame
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - pos).Magnitude > 0.05 then
		return CFrame.lookAt(pos, cam.CFrame.Position)
	end
	return CFrame.new(pos)
end

-- olhando para "dir" (cuida do caso de olhar reto para cima/baixo)
local function olhando(pos: Vector3, dir: Vector3): CFrame
	local u = dir.Unit
	if math.abs(u.Y) > 0.97 then
		return CFrame.new(pos) * CFrame.Angles(if u.Y > 0 then math.pi / 2 else -math.pi / 2, 0, 0)
	end
	return CFrame.lookAt(pos, pos + u)
end
VFX._olhando = olhando

local function qtd(n: number): number
	return if alta then n else math.max(1, math.ceil(n / 2))
end

----------------------------------------------------------------------------------- peças básicas

-- clarão: miolo branco + casca da cor do Stand (cresce e some em ~0,2 s)
function VFX.flash(pos: Vector3, cor: Color3, tam: number)
	local miolo = peca(Vector3.one * tam * 0.3, CFrame.new(pos), BRANCO, 0.2, Enum.Material.Neon, Enum.PartType.Ball)
	if miolo then
		miolo.Transparency = 0
		tween(miolo, 0.14, { Size = Vector3.one * tam, Transparency = 1 })
	end
	local casca = peca(Vector3.one * tam * 0.5, CFrame.new(pos), cor, 0.28, Enum.Material.ForceField, Enum.PartType.Ball)
	if casca then
		casca.Transparency = 0
		tween(casca, 0.24, { Size = Vector3.one * tam * 1.8, Transparency = 1 })
	end
end

-- anel de choque que se abre. normal = para onde o anel "olha" (nil = de frente para a câmera)
function VFX.anel(pos: Vector3, cor: Color3, raio: number, dur: number?, normal: Vector3?, segmentos: number?, espessura: number?)
	local d = dur or 0.25
	local n = segmentos or (if alta then 14 else 8)
	local base = if normal and normal.Magnitude > 0.01 then olhando(pos, normal) else deFrente(pos)
	local esp = espessura or math.max(0.12, raio * 0.055)
	local r0 = raio * 0.25
	local comp0 = 2 * math.pi * r0 / n * 1.2
	local comp1 = 2 * math.pi * raio / n * 1.2
	for i = 1, n do
		local ang = (i / n) * math.pi * 2
		-- segmento tangente ao círculo, no plano XY do "base"
		local cf0 = base * CFrame.Angles(0, 0, ang) * CFrame.new(r0, 0, 0)
		local cf1 = base * CFrame.Angles(0, 0, ang) * CFrame.new(raio, 0, 0)
		local p = peca(Vector3.new(esp, comp0, esp), cf0, cor, d + 0.05)
		if p then
			p.Transparency = 0.05
			tween(p, d, { CFrame = cf1, Size = Vector3.new(esp * 0.35, comp1, esp * 0.35), Transparency = 1 })
		end
	end
end

-- arco em meia-lua (o "swoosh" dos animes): grosso no meio, fino nas pontas; gira, abre e some
function VFX.arco(pos: Vector3, cor: Color3, raio: number, dur: number?)
	local d = dur or 0.22
	local n = if alta then 7 else 5
	local base = deFrente(pos) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi * 2))
	local abertura = math.rad(rng:NextNumber(110, 165))
	local giro = math.rad(rng:NextNumber(35, 70)) * (if rng:NextNumber() < 0.5 then -1 else 1)
	local compr = raio * abertura / n * 1.3
	for i = 1, n do
		local f = (i - 0.5) / n
		local larg = math.sin(f * math.pi)
		local ang = (f - 0.5) * abertura
		local esp = math.max(0.05, raio * 0.17 * larg)
		local cf0 = base * CFrame.Angles(0, 0, ang) * CFrame.new(raio, 0, 0)
		local cf1 = base * CFrame.Angles(0, 0, ang + giro) * CFrame.new(raio * 1.35, 0, 0)
		local p = peca(Vector3.new(esp, compr, esp * 0.5), cf0, if i % 2 == 0 then BRANCO else cor:Lerp(BRANCO, 0.65), d + 0.05)
		if p then
			p.Transparency = 0.02
			tween(p, d, { CFrame = cf1, Size = Vector3.new(esp * 0.2, compr * 1.15, esp * 0.1), Transparency = 1 }, Enum.EasingStyle.Quart)
		end
	end
end

-- brilho em estrela (4 pontas grandes + 2 pequenas): aparece e some rapidinho
function VFX.estrela(pos: Vector3, cor: Color3, tam: number)
	local cf = deFrente(pos) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi / 2))
	local barras = { { 0, 1, BRANCO }, { math.pi / 2, 1, BRANCO }, { math.pi / 4, 0.5, cor }, { -math.pi / 4, 0.5, cor } }
	if not alta then
		barras = { barras[1], barras[2] }
	end
	for _, b in barras do
		local rot = cf * CFrame.Angles(0, 0, b[1])
		local comp = tam * b[2]
		local p = peca(Vector3.new(tam * 0.07, comp * 0.15, 0.05), rot, b[3], 0.26)
		if p then
			tween(p, 0.06, { Size = Vector3.new(tam * 0.1, comp, 0.05) })
			task.delay(0.06, function()
				if p.Parent then
					tween(p, 0.16, { Size = Vector3.new(0.02, comp * 0.2, 0.02), Transparency = 1 })
				end
			end)
		end
	end
end

-- estilhaços que voam para fora (branco, preto e a cor do Stand, como nos battlegrounds)
function VFX.estilhacos(pos: Vector3, cores: { Color3 }, n: number, forca: number)
	for i = 1, qtd(n) do
		local d = rng:NextUnitVector()
		local tam = rng:NextNumber(0.16, 0.42)
		local p = peca(Vector3.new(tam, tam * 0.45, rng:NextNumber(0.8, 2.2)), CFrame.lookAt(pos, pos + d), cores[(i % #cores) + 1], 0.42)
		if p then
			local fim = pos + d * (forca * rng:NextNumber(0.7, 1.2))
			tween(p, rng:NextNumber(0.2, 0.34), { CFrame = CFrame.lookAt(fim, fim + d), Size = Vector3.new(0.04, 0.04, 0.3), Transparency = 1 })
		end
	end
end

-- linhas de velocidade saindo do impacto (na direção do golpe, abertas em leque)
function VFX.linhas(pos: Vector3, dir: Vector3?, cor: Color3, n: number, comp: number)
	for _ = 1, qtd(n) do
		local d = if dir and dir.Magnitude > 0.01 then (dir.Unit + rng:NextUnitVector() * 0.6).Unit else rng:NextUnitVector()
		local ini = pos + d * rng:NextNumber(0.4, 1.4)
		local p = peca(Vector3.new(0.07, 0.07, comp * 0.35), CFrame.lookAt(ini, ini + d), if rng:NextNumber() < 0.55 then BRANCO else cor, 0.24)
		if p then
			local fim = pos + d * (comp + rng:NextNumber(1, 3))
			tween(p, 0.18, { CFrame = CFrame.lookAt(fim, fim + d), Size = Vector3.new(0.02, 0.02, comp), Transparency = 1 })
		end
	end
end

-- solta n partículas (protegido: um pacote estranho nunca derruba o efeito inteiro)
local function emitir(e: any, n: number)
	pcall(function()
		e:Emit(n)
	end)
end

-- partículas (fumaça ou brilhos), num ponto
local function particulas(pos: Vector3, tex: string, cor: ColorSequence, n: number, o: any)
	if vivos >= TETO then
		return
	end
	local a = Instance.new("Attachment")
	a.Position = pos
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = tex
	e.Color = cor
	e.LightEmission = o.luz or 0.1
	e.LightInfluence = o.influencia or 0.6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.tam0), NumberSequenceKeypoint.new(1, o.tam1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.transp or 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(o.vida0, o.vida1)
	e.Speed = NumberRange.new(o.vel0, o.vel1)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = o.arrasto or 5
	e.Acceleration = o.acel or Vector3.zero
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 0
	e.Parent = a
	emitir(e, qtd(n))
	Debris:AddItem(a, o.vida1 + 0.3)
end

function VFX.fumaca(pos: Vector3, cor: Color3?, n: number, tam: number)
	particulas(pos, TEX.fumaca, ColorSequence.new(cor or RGB(205, 200, 215)), n, {
		tam0 = tam * 0.5, tam1 = tam * 1.7, vida0 = 0.45, vida1 = 0.8, vel0 = 4, vel1 = 11, transp = 0.45,
	})
end

function VFX.brilhos(pos: Vector3, cor: Color3, n: number, subir: boolean?)
	particulas(pos, TEX.brilho, ColorSequence.new(BRANCO, cor), n, {
		tam0 = 0.9, tam1 = 0, vida0 = 0.35, vida1 = 0.7, vel0 = 6, vel1 = 18, transp = 0.05, luz = 1, influencia = 0,
		arrasto = 4, acel = if subir then Vector3.new(0, 14, 0) else Vector3.zero,
	})
end

----------------------------------------------------------------------------------- VFX da loja
-- AJUSTE-11: efeitos dos pacotes que o dono pegou na Creator Store. O servidor (VFXLoja) carrega,
-- tira os scripts e guarda por tipo em ReplicatedStorage.BB_VFXLoja; aqui o efeito é copiado para o
-- ponto do golpe, as partículas são soltas do jeito que o pacote configurou (EmitCount/EmitDelay) e
-- as peças visíveis (anéis, ondas) crescem e somem. Sem pacote, volta false e ficam os nossos.
local pastaLojaTeste: Instance? = nil
function VFX._lojaPasta(p: Instance?)
	pastaLojaTeste = p
end
local function lojaPasta(): Instance?
	if pastaLojaTeste then
		return pastaLojaTeste
	end
	return ReplicatedStorage:FindFirstChild("BB_VFXLoja")
end

function VFX.temLoja(categoria: string): boolean
	local p = lojaPasta()
	local c = p and p:FindFirstChild(categoria)
	return c ~= nil and #c:GetChildren() > 0
end

-- leva um modelo para cf (PivotTo; sem ele, peça por peça a partir da primeira)
local function moverModelo(m: Model, cf: CFrame)
	if pcall(function()
		m:PivotTo(cf)
	end) then
		return
	end
	local ref: BasePart? = nil
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			ref = d
			break
		end
	end
	if not ref then
		return
	end
	local delta = cf * ref.CFrame:Inverse()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end

function VFX.loja(categoria: string, pos: Vector3, dir: Vector3?, escala: number?): boolean
	if vivos >= TETO then
		return false
	end
	local p = lojaPasta()
	local c = p and p:FindFirstChild(categoria)
	if not c then
		return false
	end
	local lista = c:GetChildren()
	if #lista == 0 then
		return false
	end
	local molde = lista[rng:NextInteger(1, #lista)]
	local cf = if dir and dir.Magnitude > 0.01 then olhando(pos, dir) else CFrame.new(pos)
	local copia = molde:Clone()
	local suporte: Instance = copia
	if copia:IsA("BasePart") then
		copia.CFrame = cf
		copia.Anchored = true
		copia.Parent = obterPasta()
	elseif copia:IsA("Model") then
		moverModelo(copia, cf)
		copia.Parent = obterPasta()
	else
		-- anexo ou emissor solto: uma peça invisível segura
		local base = Instance.new("Part")
		base.Anchored = true
		base.CanCollide = false
		base.CanQuery = false
		base.CanTouch = false
		base.Transparency = 1
		base.Size = Vector3.one * 0.2
		base.CFrame = cf
		if copia:IsA("Attachment") then
			copia.CFrame = CFrame.identity
			copia.Parent = base
		else
			local a = Instance.new("Attachment")
			a.Parent = base
			copia.Parent = a
		end
		base.Parent = obterPasta()
		suporte = base
	end
	vivos += 1
	local e = escala or 1
	local vida = 0.6
	local itens = suporte:GetDescendants()
	table.insert(itens, suporte)
	for _, d in itens do
		if d:IsA("ParticleEmitter") then
			d.Enabled = false
			if e ~= 1 then
				local k = {}
				for _, kp in d.Size.Keypoints do
					table.insert(k, NumberSequenceKeypoint.new(kp.Time, kp.Value * e, kp.Envelope * e))
				end
				d.Size = NumberSequence.new(k)
			end
			local n = tonumber(d:GetAttribute("EmitCount")) or tonumber(d:GetAttribute("emitcount")) or math.clamp(math.floor(d.Rate * 0.08), 3, 24)
			n = math.clamp(math.floor(n), 1, if alta then 60 else 25)
			local atraso = tonumber(d:GetAttribute("EmitDelay")) or 0
			vida = math.max(vida, atraso + d.Lifetime.Max)
			if atraso > 0 then
				task.delay(atraso, function()
					if d.Parent then
						emitir(d, n)
					end
				end)
			else
				emitir(d, n)
			end
		elseif d:IsA("Beam") or d:IsA("Trail") then
			d.Enabled = true
			task.delay(0.25, function()
				if d.Parent then
					d.Enabled = false
				end
			end)
		elseif d:IsA("BasePart") and d.Transparency < 1 then
			-- peças visíveis (anéis, ondas) eram animadas por script no pacote: aqui crescem e somem
			d.Anchored = true
			tween(d, 0.35, { Size = d.Size * 1.6 * e, Transparency = 1 })
		elseif d:IsA("Decal") or d:IsA("Texture") then
			tween(d, 0.35, { Transparency = 1 })
		end
	end
	vida = math.min(vida + 0.3, 4)
	task.delay(vida, function()
		vivos -= 1
		suporte:Destroy()
	end)
	return true
end

----------------------------------------------------------------------------------- golpes

-- impacto em 3 níveis: 1 leve (soco do combo), 2 forte (4º soco, golpe pesado), 3 enorme (finalização/ULT)
function VFX.impacto(pos: Vector3, dir: Vector3?, cor: Color3, nivel: number)
	local d = if dir and dir.Magnitude > 0.01 then dir.Unit else nil
	if nivel <= 1 then
		VFX.flash(pos, cor, 2.6)
		-- AJUSTE-11: efeito de impacto do pacote da loja (se tiver); senão o nosso arco
		if not VFX.loja("impacto", pos, d, 0.8) then
			VFX.arco(pos, cor, 2.1, 0.18)
		end
		VFX.estilhacos(pos, { BRANCO, cor }, 5, 4)
		if alta then
			VFX.estrela(pos + rng:NextUnitVector() * 0.9, cor, 2.2)
		end
		return
	end
	if nivel == 2 then
		VFX.loja("impacto", pos, d, 1)
		VFX.loja("choque", pos, d, 1)
		VFX.flash(pos, cor, 4.6)
		VFX.anel(pos, cor:Lerp(BRANCO, 0.4), 6, 0.24, d)
		VFX.arco(pos, cor, 3, 0.22)
		VFX.arco(pos, cor, 3.8, 0.27)
		VFX.estilhacos(pos, { BRANCO, cor, PRETO }, 10, 7)
		VFX.estrela(pos + rng:NextUnitVector() * 1.2, cor, 3.4)
		VFX.estrela(pos + rng:NextUnitVector() * 1.6, cor, 2.4)
		VFX.linhas(pos, d, cor, 6, 5)
		VFX.fumaca(pos, nil, 5, 2.2)
		return
	end
	if not VFX.loja("explosao", pos, d, 1) then
		VFX.loja("impacto", pos, d, 1.3)
	end
	VFX.loja("choque", pos, d, 1.3)
	VFX.loja("chao", pos - Vector3.new(0, 2.5, 0), nil, 1)
	VFX.flash(pos, cor, 7.5)
	VFX.anel(pos, BRANCO, 8, 0.26, d)
	task.delay(0.06, function()
		VFX.anel(pos, cor, 13, 0.34, d)
	end)
	VFX.anel(pos, cor:Lerp(BRANCO, 0.3), 11, 0.36, Vector3.yAxis)
	for i = 1, 3 do
		VFX.arco(pos, cor, 3 + i * 0.9, 0.2 + i * 0.04)
	end
	VFX.estilhacos(pos, { BRANCO, cor, PRETO }, 16, 10)
	for i = 1, 3 do
		VFX.estrela(pos + rng:NextUnitVector() * (1 + i * 0.6), cor, 4.2 - i * 0.6)
	end
	VFX.linhas(pos, d, cor, 10, 8)
	VFX.fumaca(pos, nil, 9, 3)
	VFX.brilhos(pos, cor, 12)
end

-- soco no vento (o Stand bate mesmo sem acertar): estouro de ar na frente do punho
function VFX.estouroAr(pos: Vector3, dir: Vector3, cor: Color3, forte: boolean?)
	if forte then
		VFX.loja("corte", pos, dir, 0.9)
	end
	VFX.anel(pos, cor:Lerp(BRANCO, 0.55), if forte then 3.6 else 2.2, if forte then 0.2 else 0.15, dir, if alta then 10 else 6, 0.1)
	VFX.linhas(pos - dir * 0.5, dir, cor, if forte then 6 else 3, if forte then 5 else 3)
end

-- onda de pressão da barragem (ORA ORA / MUDA MUDA)
function VFX.pressao(pos: Vector3, dir: Vector3, cor: Color3)
	VFX.anel(pos, cor:Lerp(BRANCO, 0.5), 3.4, 0.16, dir, if alta then 10 else 6, 0.12)
	if alta and rng:NextNumber() < 0.6 then
		VFX.arco(pos + dir * 0.6, cor, 2.4, 0.16)
	end
end

-- guarda: faíscas azuladas no braço do Stand e um anel virado para quem bateu
function VFX.guarda(pos: Vector3, dir: Vector3?, cor: Color3)
	local azul = RGB(170, 215, 255)
	VFX.flash(pos, azul, 2.4)
	VFX.anel(pos, azul, 3, 0.16, dir, if alta then 10 else 6, 0.12)
	VFX.estilhacos(pos, { BRANCO, azul, cor }, 7, 5)
end

-- parry perfeito: clarão branco grande, dois anéis, estrelas e estilhaços
function VFX.parry(pos: Vector3, cor: Color3)
	VFX.loja("flash", pos, nil, 1)
	VFX.flash(pos, BRANCO, 6)
	VFX.anel(pos, BRANCO, 7, 0.22)
	task.delay(0.05, function()
		VFX.anel(pos, RGB(150, 225, 255), 10, 0.3)
	end)
	VFX.estrela(pos, BRANCO, 5)
	VFX.estrela(pos + rng:NextUnitVector() * 1.5, cor, 3)
	VFX.estilhacos(pos, { BRANCO, RGB(150, 225, 255) }, 12, 8)
	VFX.brilhos(pos, RGB(150, 225, 255), 14)
end

-- o Stand aparece (sai do dono): clarão, anel no chão, estilhaços e brilhos subindo
function VFX.invocar(pos: Vector3, cor: Color3)
	VFX.loja("aura", pos, nil, 1)
	VFX.flash(pos, cor, 4)
	VFX.anel(pos - Vector3.new(0, 2.6, 0), cor, 6, 0.32, Vector3.yAxis)
	VFX.anel(pos, BRANCO, 3.6, 0.2)
	VFX.estilhacos(pos, { cor, BRANCO }, 8, 5)
	VFX.brilhos(pos, cor, 12, true)
end

-- tempo parado: anéis enormes em três planos (cores de cada Stand) e brilhos
function VFX.tempo(centro: Vector3, cor1: Color3, cor2: Color3, raio: number)
	local dur = 0.9
	VFX.loja("choque", centro, nil, 3)
	VFX.flash(centro, cor1, 10)
	VFX.anel(centro, cor1, raio * 0.6, dur, Vector3.yAxis, if alta then 24 else 12, 0.6)
	task.delay(0.08, function()
		VFX.anel(centro + Vector3.new(0, 2, 0), cor2, raio * 0.45, dur, Vector3.xAxis, if alta then 20 else 10, 0.5)
		VFX.anel(centro + Vector3.new(0, 2, 0), cor2, raio * 0.45, dur, Vector3.zAxis, if alta then 20 else 10, 0.5)
	end)
	task.delay(0.16, function()
		VFX.anel(centro, BRANCO, raio * 0.8, dur * 1.1, Vector3.yAxis, if alta then 24 else 12, 0.35)
	end)
	VFX.brilhos(centro, cor1, 20, true)
end

-- o tempo volta: um anel que fecha (de fora para dentro) e um clarão no dono
function VFX.tempoVolta(centro: Vector3, cor: Color3, raio: number)
	local n = if alta then 20 else 10
	local base = olhando(centro, Vector3.yAxis)
	for i = 1, n do
		local ang = (i / n) * math.pi * 2
		local cf0 = base * CFrame.Angles(0, 0, ang) * CFrame.new(raio, 0, 0)
		local cf1 = base * CFrame.Angles(0, 0, ang) * CFrame.new(1, 0, 0)
		local p = peca(Vector3.new(0.5, 2 * math.pi * raio / n * 1.2, 0.5), cf0, cor, 0.6)
		if p then
			p.Transparency = 0.2
			tween(p, 0.5, { CFrame = cf1, Size = Vector3.new(0.2, 0.6, 0.2), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end
	task.delay(0.45, function()
		VFX.flash(centro, cor, 6)
	end)
end

-- ORA x MUDA: o choque das duas rajadas no meio
function VFX.clash(pos: Vector3, cor1: Color3, cor2: Color3)
	if not VFX.loja("faisca", pos, nil, 1) then
		VFX.loja("impacto", pos, nil, 1)
	end
	VFX.flash(pos, BRANCO, 4)
	VFX.arco(pos, cor1, 2.8, 0.18)
	VFX.arco(pos, cor2, 2.8, 0.18)
	VFX.estilhacos(pos, { BRANCO, cor1, cor2, PRETO }, 10, 7)
	if alta then
		VFX.estrela(pos + rng:NextUnitVector(), BRANCO, 3)
		VFX.anel(pos, cor1:Lerp(cor2, 0.5), 5, 0.2)
	end
end

return VFX
