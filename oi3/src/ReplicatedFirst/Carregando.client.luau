-- OI3 :: tela de carregamento animada (AJUSTE-7)
-- A arte de fundo (a casa velha na neblina) foi feita no Canva e vai como imagem pelo instalador.
-- A animação é toda aqui: zoom lento na arte, neblina andando, luz da janela piscando, brilho da lua,
-- relâmpago de vez em quando, título com brilho, barra de progresso e dicas.
-- Se a arte ainda não foi liberada pelo Roblox (moderação), aparece um céu desenhado no lugar.

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

-- o instalador troca o número abaixo pelo ID da arte (0 = ainda sem arte)
local FUNDO = 0 --@@OI3_IMG_CARREGANDO@@
local PROPORCAO = 1024 / 575
local JANELA = Vector2.new(0.6724, 0.7403) -- onde fica a janela acesa na arte (0..1)
local LUA = Vector2.new(0.8064, 0.5333)
local TEMPO_MINIMO = 3.5
local TEMPO_MAXIMO = 40

local DICAS = {
	"Dica: a lanterna liga e desliga no botão da tela.",
	"Dica: correr cansa. Fique de olho na barrinha de fôlego.",
	"Dica: à tarde, repare nas coisas estranhas da casa.",
	"Dica: dá para jogar com até 3 amigos, cada um com uma criança.",
	"Dica: celular esquentando? Ligue os efeitos leves nos ajustes.",
	"Dica: jogue com fone de ouvido.",
}

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")
local RGB = Color3.fromRGB

local function novo(classe: string, props: { [string]: any }, pai: Instance?): any
	local o = Instance.new(classe)
	for k, v in props do
		(o :: any)[k] = v
	end
	if pai then
		o.Parent = pai
	end
	return o
end

local function tween(o: Instance, tempo: number, props: { [string]: any }, estilo: Enum.EasingStyle?, direcao: Enum.EasingDirection?, repetir: number?, vaivem: boolean?)
	local t = TweenService:Create(o, TweenInfo.new(tempo, estilo or Enum.EasingStyle.Sine, direcao or Enum.EasingDirection.InOut, repetir or 0, vaivem or false), props)
	t:Play()
	return t
end

local function circulo(pai: Instance, pos: Vector2, raio: number, cor: Color3, transp: number, z: number)
	local c = novo("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(pos.X, pos.Y),
		Size = UDim2.fromScale(raio * 2, raio * 2 * PROPORCAO),
		BackgroundColor3 = cor,
		BackgroundTransparency = transp,
		BorderSizePixel = 0,
		ZIndex = z,
	}, pai)
	novo("UICorner", { CornerRadius = UDim.new(1, 0) }, c)
	return c
end

-- brilho "redondo" feito de vários círculos (degradê radial sem imagem)
local function brilho(pai: Instance, pos: Vector2, raio: number, cor: Color3, forca: number, z: number)
	local grupo = novo("Frame", { Name = "Brilho", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z }, pai)
	local camadas = 6
	for i = 1, camadas do
		local r = raio * (1 - (i - 1) / camadas)
		circulo(grupo, pos, r, cor, 1 - forca * (0.05 + 0.09 * i / camadas), z)
	end
	return grupo
end

local sg = novo("ScreenGui", {
	Name = "OI3_Carregando",
	IgnoreGuiInset = true,
	DisplayOrder = 100,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
pcall(function()
	sg.ScreenInsets = Enum.ScreenInsets.None
end)

local fundo = novo("Frame", { BackgroundColor3 = RGB(4, 5, 8), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, sg)

-- céu desenhado (aparece sempre por baixo; a arte cobre quando carregar)
local ceu = novo("Frame", { BackgroundColor3 = RGB(255, 255, 255), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, fundo)
novo("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, RGB(10, 13, 20)),
		ColorSequenceKeypoint.new(0.6, RGB(26, 32, 42)),
		ColorSequenceKeypoint.new(1, RGB(8, 9, 12)),
	}),
	Rotation = 90,
}, ceu)

-- "palco" do tamanho da arte, cobrindo a tela toda (como ScaleType.Crop, mas os brilhos acompanham a arte)
local palco = novo("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 2 }, fundo)
local zoom = novo("UIScale", { Scale = 1 }, palco)
local function cobrir()
	local t = fundo.AbsoluteSize
	if t.X <= 0 or t.Y <= 0 then
		return
	end
	local w = math.max(t.X, t.Y * PROPORCAO)
	palco.Size = UDim2.fromOffset(w, w / PROPORCAO)
end
cobrir()
fundo:GetPropertyChangedSignal("AbsoluteSize"):Connect(cobrir)

local arte = novo("ImageLabel", {
	Name = "Arte",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ScaleType = Enum.ScaleType.Stretch,
	ImageTransparency = 1,
	ImageColor3 = RGB(222, 226, 234),
	ZIndex = 2,
}, palco)

-- lua (brilho pulsando devagar) e a janela acesa (pisca como lâmpada velha)
local luaBrilho = brilho(palco, LUA, 0.075, RGB(206, 220, 240), 0.55, 3)
local janela = brilho(palco, JANELA, 0.03, RGB(255, 196, 120), 0.9, 3)
local janelaNucleo = circulo(palco, JANELA, 0.007, RGB(255, 226, 170), 0.35, 4)

-- neblina: "nuvens" macias andando devagar na parte de baixo
local nevoa = novo("Frame", { Name = "Nevoa", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, ClipsDescendants = false }, fundo)
local function nuvem(y: number, largura: number, altura: number, transp: number)
	-- uma "nuvem" macia: 3 elipses uma dentro da outra, cada uma sumindo em cima e embaixo
	local n = novo("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.4, y),
		Size = UDim2.fromScale(largura, altura),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, nevoa)
	local alfa = (1 - transp) * 0.5
	for i, escala in { 1, 0.72, 0.46 } do
		local e = novo("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5 + (i - 2) * 0.04),
			Size = UDim2.fromScale(escala, escala * 0.9),
			BackgroundColor3 = RGB(176, 186, 200),
			BackgroundTransparency = 1 - alfa,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, n)
		novo("UICorner", { CornerRadius = UDim.new(1, 0) }, e)
		novo("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, e)
	end
	return n
end
-- já começa com nuvens espalhadas na tela (cada uma "adiantada" no caminho)
local nuvens = {
	{ 0.86, 0.9, 0.2, 0.82, 46 },
	{ 0.93, 1.1, 0.16, 0.78, 58 },
	{ 0.78, 0.7, 0.12, 0.88, 38 },
	{ 0.97, 0.8, 0.14, 0.8, 50 },
	{ 0.66, 0.6, 0.08, 0.93, 64 },
}
for i, nv in nuvens do
	local y, larg, alt, transp, dur = nv[1], nv[2], nv[3], nv[4], nv[5]
	local n = nuvem(y, larg, alt, transp)
	-- começa em pontos diferentes do caminho
	local inicio = -0.4 + (i / #nuvens) * 1.8
	n.Position = UDim2.fromScale(inicio, y)
	local restante = (1.4 - inicio) / 1.8 * dur
	tween(n, restante, { Position = UDim2.fromScale(1.4, y) }, Enum.EasingStyle.Linear).Completed:Connect(function()
		if n.Parent then
			n.Position = UDim2.fromScale(-0.4, y)
			tween(n, dur, { Position = UDim2.fromScale(1.4, y) }, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
		end
	end)
end

-- bordas escuras (o título e a barra ficam fáceis de ler)
local function borda(rot: number, tamanho: UDim2, pos: UDim2, ancora: Vector2, forca: number)
	local b = novo("Frame", { AnchorPoint = ancora, Position = pos, Size = tamanho, BackgroundColor3 = RGB(0, 0, 0), BorderSizePixel = 0, ZIndex = 6 }, fundo)
	novo("UIGradient", {
		Rotation = rot,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - forca), NumberSequenceKeypoint.new(1, 1) }),
	}, b)
end
borda(90, UDim2.fromScale(1, 0.42), UDim2.fromScale(0, 0), Vector2.new(0, 0), 0.75)
borda(-90, UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 1), Vector2.new(0, 1), 0.85)
borda(0, UDim2.fromScale(0.22, 1), UDim2.fromScale(0, 0), Vector2.new(0, 0), 0.6)
borda(180, UDim2.fromScale(0.22, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0), 0.6)

-- clarão do relâmpago
local clarao = novo("Frame", { BackgroundColor3 = RGB(214, 224, 255), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 7 }, fundo)

-- título
local brilhoTitulo = novo("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.25),
	Size = UDim2.fromScale(0.62, 0.3),
	TextScaled = true,
	Text = "OI3",
	FontFace = Font.new("rbxasset://fonts/families/Creepster.json"),
	TextColor3 = RGB(176, 30, 30),
	TextTransparency = 0.55,
	TextStrokeColor3 = RGB(120, 10, 10),
	TextStrokeTransparency = 0.6,
	ZIndex = 8,
}, fundo)
local titulo = novo("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.25),
	Size = UDim2.fromScale(0.56, 0.27),
	TextScaled = true,
	Text = "OI3",
	FontFace = Font.new("rbxasset://fonts/families/Creepster.json"),
	TextColor3 = RGB(232, 226, 214),
	TextTransparency = 1,
	ZIndex = 9,
}, fundo)
novo("UIStroke", { Color = RGB(20, 4, 4), Thickness = 2, Transparency = 0.2 }, titulo)
local subtitulo = novo("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.fromScale(0.5, 0.045),
	TextScaled = true,
	Text = "CAPÍTULO 1",
	FontFace = Font.new("rbxasset://fonts/families/SpecialElite.json"),
	TextColor3 = RGB(196, 186, 170),
	TextTransparency = 1,
	ZIndex = 9,
}, fundo)

-- barra de progresso (cantos de 4 px) + texto + dica
local trilho = novo("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -54),
	Size = UDim2.new(0.46, 0, 0, 6),
	BackgroundColor3 = RGB(30, 28, 32),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	ZIndex = 9,
}, fundo)
novo("UICorner", { CornerRadius = UDim.new(0, 4) }, trilho)
novo("UIStroke", { Color = RGB(92, 78, 62), Thickness = 1, Transparency = 0.45 }, trilho)
local enche = novo("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = RGB(176, 38, 38), BorderSizePixel = 0, ZIndex = 10 }, trilho)
novo("UICorner", { CornerRadius = UDim.new(0, 4) }, enche)
novo("UIGradient", { Color = ColorSequence.new(RGB(120, 20, 20), RGB(226, 84, 64)) }, enche)
local estado = novo("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -64),
	Size = UDim2.new(0.46, 0, 0, 18),
	TextScaled = true,
	Text = "carregando o orfanato",
	FontFace = Font.new("rbxasset://fonts/families/SpecialElite.json"),
	TextColor3 = RGB(176, 166, 152),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 9,
}, fundo)
local porcento = novo("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -64),
	Size = UDim2.new(0.46, 0, 0, 18),
	TextScaled = true,
	Text = "0%",
	FontFace = Font.new("rbxasset://fonts/families/SpecialElite.json"),
	TextColor3 = RGB(214, 204, 188),
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 9,
}, fundo)
local dica = novo("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -22),
	Size = UDim2.new(0.8, 0, 0, 20),
	TextScaled = true,
	Text = DICAS[math.random(1, #DICAS)],
	FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic),
	TextColor3 = RGB(150, 142, 130),
	TextTransparency = 1,
	ZIndex = 9,
}, fundo)
novo("UITextSizeConstraint", { MaxTextSize = 18 }, dica)
novo("UITextSizeConstraint", { MaxTextSize = 16 }, estado)
novo("UITextSizeConstraint", { MaxTextSize = 16 }, porcento)

sg.Parent = pg

-- ===== animações =====
local vivo = true

-- entrada
tween(titulo, 1.6, { TextTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
tween(subtitulo, 2.2, { TextTransparency = 0.15 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
tween(dica, 1.2, { TextTransparency = 0.1 })

-- zoom lento na arte, indo um pouco em direção à casa (vai e volta, bem devagar)
tween(zoom, 22, { Scale = 1.09 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
tween(palco, 22, { Position = UDim2.fromScale(0.475, 0.488) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

-- a arte aparece quando carregar (se ainda está na moderação, fica o céu desenhado)
luaBrilho.Visible = false
janela.Visible = false
janelaNucleo.Visible = false
if FUNDO > 0 then
	arte.Image = "rbxassetid://" .. FUNDO
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ arte })
		end)
		local limite = os.clock() + 12
		while vivo and not arte.IsLoaded and os.clock() < limite do
			task.wait(0.25)
		end
		if vivo and arte.IsLoaded then
			tween(arte, 1.4, { ImageTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.wait(0.8)
			luaBrilho.Visible = vivo
			janela.Visible = vivo
			janelaNucleo.Visible = vivo
		end
	end)
end

-- brilho do título e da lua respirando
tween(brilhoTitulo, 2.4, { TextTransparency = 0.78 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
for _, c in luaBrilho:GetChildren() do
	if c:IsA("Frame") then
		tween(c, 3.2, { BackgroundTransparency = math.min(1, c.BackgroundTransparency + 0.04) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	end
end

-- luz da janela: tremula como lâmpada velha e às vezes apaga um instante
local function luzJanela(intensidade: number)
	for i, c in janela:GetChildren() do
		if c:IsA("Frame") then
			c.BackgroundTransparency = 1 - (1 - c:GetAttribute("base")) * intensidade
		end
	end
	janelaNucleo.BackgroundTransparency = 1 - 0.65 * intensidade
end
for _, c in janela:GetChildren() do
	if c:IsA("Frame") then
		c:SetAttribute("base", c.BackgroundTransparency)
	end
end
task.spawn(function()
	while vivo do
		local v = 0.82 + math.random() * 0.18
		luzJanela(v)
		if math.random() < 0.035 then
			luzJanela(0.1)
			task.wait(0.08)
			luzJanela(0.9)
			task.wait(0.06)
			luzJanela(0.05)
			task.wait(0.5 + math.random() * 0.6)
		end
		task.wait(0.07 + math.random() * 0.08)
	end
end)

-- relâmpago de vez em quando (dois clarões rápidos) e o título tremendo junto
task.spawn(function()
	task.wait(4 + math.random() * 3)
	while vivo do
		for _, forca in { 0.55, 0.75 } do
			clarao.BackgroundTransparency = forca
			arte.ImageColor3 = RGB(255, 255, 255)
			titulo.TextTransparency = 0.35
			tween(clarao, 0.22, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			tween(arte, 0.5, { ImageColor3 = RGB(222, 226, 234) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.wait(0.09)
			titulo.TextTransparency = 0
			task.wait(0.12 + math.random() * 0.1)
		end
		task.wait(7 + math.random() * 7)
	end
end)

-- dicas trocando
task.spawn(function()
	local i = math.random(1, #DICAS)
	while vivo do
		task.wait(4.5)
		if not vivo then
			break
		end
		tween(dica, 0.4, { TextTransparency = 1 })
		task.wait(0.45)
		i = i % #DICAS + 1
		dica.Text = DICAS[i]
		tween(dica, 0.5, { TextTransparency = 0.1 })
	end
end)

-- progresso: fila de downloads do Roblox + o aviso de "pronto" do jogo
local t0 = os.clock()
local maiorFila = 1
local mostrado = 0
local pontos = 0
local ultimoPonto = 0
while os.clock() - t0 < TEMPO_MAXIMO do
	local pronto = lp:GetAttribute("OI3_Pronto") == true
	local fila = ContentProvider.RequestQueueSize
	maiorFila = math.max(maiorFila, fila)
	local alvo = math.clamp(1 - fila / maiorFila, 0, 1) * 0.6 + math.clamp((os.clock() - t0) / 14, 0, 1) * 0.3
	if game:IsLoaded() then
		alvo += 0.05
	end
	if pronto then
		alvo = 1
	end
	alvo = math.min(alvo, if pronto then 1 else 0.95)
	mostrado += (alvo - mostrado) * 0.12
	enche.Size = UDim2.fromScale(mostrado, 1)
	porcento.Text = string.format("%d%%", math.floor(mostrado * 100 + 0.5))
	if os.clock() - ultimoPonto > 0.4 then
		ultimoPonto = os.clock()
		pontos = (pontos + 1) % 4
		estado.Text = (if pronto then "abrindo a porta" else "carregando o orfanato") .. string.rep(".", pontos)
	end
	if pronto and mostrado > 0.985 and os.clock() - t0 >= TEMPO_MINIMO then
		break
	end
	task.wait(1 / 30)
end
enche.Size = UDim2.fromScale(1, 1)
porcento.Text = "100%"

-- saída: a câmera "entra" na casa e tudo escurece
vivo = false
local sai = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
TweenService:Create(zoom, sai, { Scale = 1.22 }):Play()
TweenService:Create(arte, sai, { ImageTransparency = 1 }):Play()
for _, o in fundo:GetDescendants() do
	if o:IsA("TextLabel") then
		TweenService:Create(o, TweenInfo.new(0.7), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	elseif o:IsA("UIStroke") then
		TweenService:Create(o, TweenInfo.new(0.7), { Transparency = 1 }):Play()
	elseif o:IsA("Frame") and o ~= fundo then
		TweenService:Create(o, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
	end
end
task.wait(1.1)
TweenService:Create(fundo, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
task.wait(0.85)
sg:Destroy()
