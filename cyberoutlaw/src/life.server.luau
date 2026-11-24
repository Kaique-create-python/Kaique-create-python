-- CyberOutlaw · vida em Maré Baixa (Script em ServerScriptService).
-- Carteira em eurodólares (€$) salva no DataStore; um apartamento por jogador no Edifício Colmeia (12 por
-- servidor) que começa imundo e recebe móveis comprados; missões de mercenário oferecidas pelos fixers por
-- holochamada; assaltos (caixas eletrônicos, máquinas e camelôs) com nível de procurado e a polícia (PMMB);
-- e os pedestres cyberpunk das calçadas: civis com implantes, gangues que revidam com arma.
-- Tudo montado por código, sem imagens. As partes puras (catálogo, roupas, rotas, regras) são testadas em
-- tests/life_test.luau.

local rgb = Color3.fromRGB
local MAT = Enum.Material

local M = {}

-- Utilidades de montagem ---------------------------------------------------------------------------------
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local item = Instance.new("Part")
	item.Name = name
	if shape then
		item.Shape = shape
	end
	item.Size = size
	item.CFrame = cf
	item.Color = color
	item.Material = material or MAT.SmoothPlastic
	item.Anchored = true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function box(parent, name, sx, sy, sz, x, y, z, color, material)
	return part(parent, name, Vector3.new(sx, sy, sz), CFrame.new(x, y, z), color, material)
end

-- Cilindro em pé (o eixo do cilindro do Roblox é o X; gira para ficar no Y).
local function post(parent, name, diameter, height, x, y, z, color, material)
	return part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2), color, material,
		Enum.PartType.Cylinder)
end

local function ball(parent, name, diameter, x, y, z, color, material)
	return part(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(x, y, z), color, material, Enum.PartType.Ball)
end

local function neon(parent, name, sx, sy, sz, x, y, z, color)
	local item = box(parent, name, sx, sy, sz, x, y, z, color, MAT.Neon)
	item.CastShadow = false
	return item
end

local function glow(item: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = item
	return light
end

-- Texto numa face (telas, letreiros, pichações): SurfaceGui com uma TextLabel.
local function screen(item: BasePart, face: Enum.NormalId, text: string, font: Enum.Font, color: Color3, background: Color3?, glowing: boolean?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Tela"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = if glowing == false then 1 else 0
	gui.Brightness = if glowing == false then 1 else 1.6
	gui.MaxDistance = 140
	gui.Parent = item
	local label = Instance.new("TextLabel")
	label.Name = "Texto"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background or Color3.new(0, 0, 0)
	label.BackgroundTransparency = if background then 0 else 1
	label.BorderSizePixel = 0
	label.Text = text
	label.Font = font
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = color
	label.TextStrokeTransparency = if glowing == false then 1 else 0.55
	label.Parent = gui
	return label
end

-- Caixa envolvente de todas as peças (o Lune não tem GetBoundingBox): mínimo e máximo no espaço do mundo.
local function bounds(model: Instance): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local cf, half = item.CFrame, item.Size / 2
			local r = { cf:GetComponents() }
			local ex = math.abs(r[4]) * half.X + math.abs(r[5]) * half.Y + math.abs(r[6]) * half.Z
			local ey = math.abs(r[7]) * half.X + math.abs(r[8]) * half.Y + math.abs(r[9]) * half.Z
			local ez = math.abs(r[10]) * half.X + math.abs(r[11]) * half.Y + math.abs(r[12]) * half.Z
			local p = cf.Position
			lo = Vector3.new(math.min(lo.X, p.X - ex), math.min(lo.Y, p.Y - ey), math.min(lo.Z, p.Z - ez))
			hi = Vector3.new(math.max(hi.X, p.X + ex), math.max(hi.Y, p.Y + ey), math.max(hi.Z, p.Z + ez))
		end
	end
	return lo, hi
end
M.bounds = bounds

-- Centraliza o modelo: centro da base no (0, 0, 0), e uma peça invisível "Base" do tamanho da pegada vira o
-- PrimaryPart (é ela que o cliente usa para o fantasma de posicionamento e o servidor para colisão).
local function finish(model: Model): Vector3
	local lo, hi = bounds(model)
	local shift = Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.CFrame = item.CFrame - shift
		end
	end
	local size = hi - lo
	local base = part(model, "Base", Vector3.new(math.max(size.X, 0.2), math.max(size.Y, 0.2), math.max(size.Z, 0.2)),
		CFrame.new(0, size.Y / 2, 0), Color3.new(1, 1, 1))
	base.Transparency = 1
	base.CanCollide = false
	base.CanTouch = false
	base.CastShadow = false
	-- O pivô do modelo fica no chão (centro da pegada): PivotTo(chão) apoia o móvel no piso.
	pcall(function()
		base.PivotOffset = CFrame.new(0, -size.Y / 2, 0)
	end)
	model.PrimaryPart = base
	return size
end
M.finish = finish

-- Paleta dos móveis ------------------------------------------------------------------------------------------
local INK = rgb(24, 24, 30)
local GRAPHITE = rgb(40, 40, 48)
local CHROME = rgb(176, 180, 190)
local PINK = rgb(255, 60, 150)
local CYAN = rgb(60, 230, 255)
local VIOLET = rgb(150, 90, 255)
local GOLD = rgb(255, 206, 80)
local ORANGE = rgb(255, 130, 50)
local LIME = rgb(120, 255, 120)
local WHITE = rgb(232, 232, 240)

-- Móveis: frente para -Z, chão no y = 0. preco em €$, cat (aba da loja), chao = tapete (pode ficar embaixo
-- de outros móveis), luz = acende de noite. build recebe o Model vazio.
local FURNITURE = {
	{
		id = "colchao", nome = "Colchão no chão", preco = 80, cat = "Quarto",
		desc = "Começo humilde. Pelo menos não é o chão.",
		build = function(m)
			box(m, "Colchão", 4.2, 0.9, 7.4, 0, 0.45, 0, rgb(170, 160, 140), MAT.Fabric)
			box(m, "Travesseiro", 2.6, 0.5, 1.2, 0, 1.15, 2.8, WHITE, MAT.Fabric)
			part(m, "Coberta", Vector3.new(4.3, 0.25, 3.8), CFrame.new(0.1, 1.0, -1.4) * CFrame.Angles(0, 0.06, 0), rgb(60, 82, 120), MAT.Fabric)
		end,
	},
	{
		id = "cama_capsula", nome = "Cama-cápsula", preco = 1600, cat = "Quarto",
		desc = "Cápsula de hotel japonês com tela e luz de leitura.",
		build = function(m)
			box(m, "Base", 5, 1.2, 8.4, 0, 0.6, 0, GRAPHITE, MAT.Metal)
			box(m, "Colchão", 4.4, 0.6, 7.8, 0, 1.5, -0.1, WHITE, MAT.Fabric)
			box(m, "Travesseiro", 3, 0.5, 1.2, 0, 2.05, 3.2, rgb(200, 200, 214), MAT.Fabric)
			box(m, "Parede esquerda", 0.3, 3.6, 8.4, -2.35, 3, 0, rgb(220, 222, 230), MAT.SmoothPlastic)
			box(m, "Parede direita", 0.3, 3.6, 8.4, 2.35, 3, 0, rgb(220, 222, 230), MAT.SmoothPlastic)
			box(m, "Fundo", 5, 3.6, 0.3, 0, 3, 4.05, rgb(220, 222, 230), MAT.SmoothPlastic)
			box(m, "Teto", 5, 0.3, 8.4, 0, 4.95, 0, rgb(220, 222, 230), MAT.SmoothPlastic)
			box(m, "Moldura", 5.1, 0.4, 0.4, 0, 4.95, -4.2, INK, MAT.Metal)
			box(m, "Moldura", 0.4, 4.1, 0.4, -2.4, 2.95, -4.2, INK, MAT.Metal)
			box(m, "Moldura", 0.4, 4.1, 0.4, 2.4, 2.95, -4.2, INK, MAT.Metal)
			local strip = neon(m, "Luz de leitura", 0.12, 0.12, 7.6, -2.1, 4.7, 0, CYAN)
			glow(strip, CYAN, 1.2, 9)
			local tv = box(m, "Telinha", 1.6, 0.9, 0.08, 1.1, 3.6, 3.86, INK)
			screen(tv, Enum.NormalId.Front, "DORMIR 8H\n☾ 23:40", Enum.Font.Michroma, CYAN, rgb(8, 14, 24))
		end,
	},
	{
		id = "cama_neon", nome = "Cama king com LED", preco = 3400, cat = "Quarto", luz = true,
		desc = "Cama enorme com luz por baixo e cabeceira em néon.",
		build = function(m)
			neon(m, "Luz de baixo", 8.6, 0.1, 9.6, 0, 0.06, 0, PINK)
			box(m, "Base", 8.4, 1, 9.4, 0, 0.6, 0, INK, MAT.Metal)
			box(m, "Colchão", 8, 1, 8.6, 0, 1.6, -0.3, WHITE, MAT.Fabric)
			box(m, "Edredom", 8.1, 0.3, 5.4, 0, 2.2, -1.8, rgb(46, 30, 84), MAT.Fabric)
			box(m, "Travesseiro", 2.8, 0.6, 1.3, -1.9, 2.4, 3.1, WHITE, MAT.Fabric)
			box(m, "Travesseiro", 2.8, 0.6, 1.3, 1.9, 2.4, 3.1, WHITE, MAT.Fabric)
			box(m, "Cabeceira", 8.4, 4.4, 0.6, 0, 2.7, 4.4, GRAPHITE, MAT.Leather)
			for _, y in { 2.6, 3.6, 4.6 } do
				neon(m, "Faixa da cabeceira", 7.6, 0.1, 0.08, 0, y, 4.07, if y == 3.6 then CYAN else PINK)
			end
			glow(m:FindFirstChild("Luz de baixo") :: BasePart, PINK, 1.4, 12)
		end,
	},
	{
		id = "sofa_couro", nome = "Sofá de couro sintético", preco = 900, cat = "Sala",
		desc = "Couro de laboratório, sem nenhuma vaca envolvida.",
		build = function(m)
			local leather = rgb(92, 40, 34)
			for _, x in { -3.7, 3.7 } do
				for _, z in { -1.4, 1.4 } do
					post(m, "Pé", 0.3, 0.3, x, 0.15, z, CHROME, MAT.Metal)
				end
			end
			box(m, "Base", 8, 1, 3.4, 0, 0.8, 0, rgb(60, 28, 24), MAT.Leather)
			for _, x in { -2.55, 0, 2.55 } do
				box(m, "Almofada", 2.5, 0.6, 2.9, x, 1.6, -0.2, leather, MAT.Leather)
				box(m, "Encosto", 2.5, 1.8, 0.7, x, 2.6, 1.3, leather, MAT.Leather)
			end
			box(m, "Braço", 0.8, 1.9, 3.4, -4.4, 1.35, 0, rgb(70, 32, 28), MAT.Leather)
			box(m, "Braço", 0.8, 1.9, 3.4, 4.4, 1.35, 0, rgb(70, 32, 28), MAT.Leather)
		end,
	},
	{
		id = "sofa_modular", nome = "Sofá modular néon", preco = 2400, cat = "Sala", luz = true,
		desc = "Sofá em L com fita de LED ciano por baixo.",
		build = function(m)
			local fabric, dark = rgb(78, 66, 120), rgb(40, 34, 66)
			local under = neon(m, "Luz de baixo", 9.2, 0.1, 3.5, 0, 0.06, 1.7, CYAN)
			neon(m, "Luz de baixo", 3.1, 0.1, 3.7, -3, 0.06, -1.8, CYAN)
			glow(under, CYAN, 1.1, 11)
			box(m, "Base", 9, 0.9, 3.4, 0, 0.6, 1.7, dark, MAT.Fabric)
			box(m, "Base da chaise", 3, 0.9, 3.6, -3, 0.6, -1.8, dark, MAT.Fabric)
			box(m, "Assento", 9, 0.5, 2.8, 0, 1.3, 1.5, fabric, MAT.Fabric)
			box(m, "Assento da chaise", 2.9, 0.5, 3.6, -3, 1.3, -1.8, fabric, MAT.Fabric)
			box(m, "Encosto", 9, 1.9, 0.7, 0, 2, 3.05, dark, MAT.Fabric)
			box(m, "Braço", 0.7, 1.6, 7, -4.15, 1.6, 0, dark, MAT.Fabric)
			box(m, "Braço", 0.7, 1.3, 3.4, 4.15, 1.45, 1.7, dark, MAT.Fabric)
			part(m, "Almofada", Vector3.new(1.3, 1.2, 0.4), CFrame.new(2.4, 2.05, 2.45) * CFrame.Angles(0.15, 0.2, 0.1), PINK, MAT.Fabric)
			part(m, "Almofada", Vector3.new(1.3, 1.2, 0.4), CFrame.new(-1.2, 2.05, 2.5) * CFrame.Angles(0.12, -0.15, -0.08), GOLD, MAT.Fabric)
		end,
	},
	{
		id = "poltrona_gamer", nome = "Poltrona gamer", preco = 1100, cat = "Sala",
		desc = "Encosto de corrida e faixas vermelhas de LED.",
		build = function(m)
			local red = rgb(220, 40, 60)
			post(m, "Base", 2.6, 0.25, 0, 0.13, 0, INK, MAT.Metal)
			post(m, "Pistão", 0.45, 1.3, 0, 0.9, 0, CHROME, MAT.Metal)
			box(m, "Assento", 2.4, 0.5, 2.4, 0, 1.8, 0, INK, MAT.Leather)
			box(m, "Abas do assento", 0.3, 0.45, 2.4, -1.15, 2.05, 0, red, MAT.Leather)
			box(m, "Abas do assento", 0.3, 0.45, 2.4, 1.15, 2.05, 0, red, MAT.Leather)
			part(m, "Encosto", Vector3.new(2.3, 3.8, 0.45), CFrame.new(0, 3.85, 1.2) * CFrame.Angles(0.12, 0, 0), INK, MAT.Leather)
			for _, x in { -0.7, 0.7 } do
				local stripe = part(m, "Faixa", Vector3.new(0.14, 3.2, 0.06), CFrame.new(x, 3.95, 0.95) * CFrame.Angles(0.12, 0, 0), red, MAT.Neon)
				stripe.CastShadow = false
			end
			for _, x in { -1.35, 1.35 } do
				box(m, "Suporte do braço", 0.25, 0.9, 0.25, x, 2.35, 0.2, INK, MAT.Metal)
				box(m, "Braço", 0.4, 0.16, 1.6, x, 2.85, 0.1, INK, MAT.Leather)
			end
		end,
	},
	{
		id = "mesa_centro", nome = "Mesa de centro de vidro", preco = 600, cat = "Sala",
		desc = "Tampo de vidro com contorno rosa.",
		build = function(m)
			local top = box(m, "Tampo", 5, 0.2, 3, 0, 1.5, 0, rgb(120, 200, 220), MAT.Glass)
			top.Transparency = 0.35
			for _, x in { -2.3, 2.3 } do
				for _, z in { -1.3, 1.3 } do
					box(m, "Perna", 0.25, 1.4, 0.25, x, 0.7, z, CHROME, MAT.Metal)
				end
			end
			box(m, "Prateleira", 4.6, 0.15, 2.6, 0, 0.35, 0, GRAPHITE, MAT.Metal)
			neon(m, "Contorno", 5, 0.06, 0.06, 0, 1.38, -1.5, PINK)
			neon(m, "Contorno", 5, 0.06, 0.06, 0, 1.38, 1.5, PINK)
			box(m, "Revista", 1.1, 0.06, 1.4, -1, 1.63, 0.2, rgb(240, 70, 120), MAT.SmoothPlastic)
			post(m, "Lata", 0.35, 0.6, 1.4, 1.9, -0.4, rgb(60, 220, 255), MAT.Metal)
		end,
	},
	{
		id = "tapete_holo", nome = "Tapete holográfico", preco = 800, cat = "Decoração", chao = true,
		desc = "Fibra escura com bordas de luz. Dá para pôr móveis em cima.",
		build = function(m)
			box(m, "Tapete", 10, 0.08, 7, 0, 0.04, 0, rgb(22, 20, 40), MAT.Fabric)
			neon(m, "Borda", 10, 0.04, 0.2, 0, 0.1, -3.4, CYAN)
			neon(m, "Borda", 10, 0.04, 0.2, 0, 0.1, 3.4, CYAN)
			neon(m, "Borda", 0.2, 0.04, 7, -4.9, 0.1, 0, CYAN)
			neon(m, "Borda", 0.2, 0.04, 7, 4.9, 0.1, 0, CYAN)
			local ring = part(m, "Anel", Vector3.new(0.06, 4.4, 4.4), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), PINK, MAT.Neon,
				Enum.PartType.Cylinder)
			ring.CastShadow = false
			part(m, "Miolo", Vector3.new(0.07, 3.8, 3.8), CFrame.new(0, 0.11, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(22, 20, 40), MAT.Fabric,
				Enum.PartType.Cylinder)
		end,
	},
	{
		id = "tapete_pelucia", nome = "Tapete redondo de pelúcia", preco = 350, cat = "Decoração", chao = true,
		desc = "Roxo, felpudo e macio.",
		build = function(m)
			part(m, "Tapete", Vector3.new(0.12, 8, 8), CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(110, 56, 160), MAT.Fabric,
				Enum.PartType.Cylinder)
			part(m, "Anel", Vector3.new(0.13, 5.6, 5.6), CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(150, 90, 200), MAT.Fabric,
				Enum.PartType.Cylinder)
		end,
	},
	{
		id = "tv_holo", nome = "TV holográfica", preco = 3200, cat = "Tecnologia", luz = true,
		desc = "Tela gigante com o noticiário N54 e um holograma ao lado.",
		build = function(m)
			box(m, "Rack", 7, 1.6, 1.8, 0, 0.8, 0, INK, MAT.Metal)
			neon(m, "Faixa do rack", 6.6, 0.08, 0.05, 0, 0.25, -0.92, VIOLET)
			box(m, "Suporte", 0.6, 0.8, 0.3, 0, 2, 0.4, GRAPHITE, MAT.Metal)
			local tv = box(m, "Tela", 6.4, 3.6, 0.2, 0, 4.1, 0.3, rgb(8, 8, 12))
			screen(tv, Enum.NormalId.Front, "N54 · NOTÍCIAS\nCHUVA ÁCIDA NA MARÉ BAIXA", Enum.Font.Michroma, rgb(140, 220, 255), rgb(10, 22, 48))
			local cone = part(m, "Cone do holograma", Vector3.new(1.4, 1.4, 1.4), CFrame.new(2.7, 2.4, -0.2) * CFrame.Angles(0, 0, math.pi / 2), CYAN,
				MAT.Neon, Enum.PartType.Cylinder)
			cone.Transparency = 0.78
			cone.CastShadow = false
			local cube = part(m, "Holograma", Vector3.new(0.6, 0.6, 0.6), CFrame.new(2.7, 3.4, -0.2) * CFrame.Angles(0.6, 0.6, 0.2), CYAN, MAT.Neon)
			cube.Transparency = 0.35
			cube.CastShadow = false
			glow(tv, rgb(120, 190, 255), 1.4, 14)
		end,
	},
	{
		id = "estacao_hacker", nome = "Estação de netrunner", preco = 2800, cat = "Tecnologia", luz = true,
		desc = "Três monitores, teclado com luz e um PC com janela rosa.",
		build = function(m)
			box(m, "Tampo", 7, 0.25, 3, 0, 2.6, 0, GRAPHITE, MAT.Metal)
			box(m, "Lateral", 0.25, 2.5, 2.8, -3.3, 1.25, 0, INK, MAT.Metal)
			box(m, "Lateral", 0.25, 2.5, 2.8, 3.3, 1.25, 0, INK, MAT.Metal)
			neon(m, "Borda", 7, 0.06, 0.06, 0, 2.45, -1.5, CYAN)
			local code = "> conectando ao ICE...\n> brecha em 0x3F\n> acesso liberado_"
			for index, spot in { { 0, 0.85, 0 }, { -2.6, 0.55, 0.42 }, { 2.6, 0.55, -0.42 } } do
				local cf = CFrame.new(spot[1], 3.9, spot[2]) * CFrame.Angles(0, spot[3], 0)
				local monitor = part(m, "Monitor", Vector3.new(2.6, 1.6, 0.12), cf, rgb(10, 10, 14))
				screen(monitor, Enum.NormalId.Front, if index == 1 then code else "▓▒░ ICE ░▒▓\n" .. string.rep("01", 6), Enum.Font.RobotoMono,
					rgb(110, 255, 170), rgb(4, 16, 12))
				part(m, "Haste", Vector3.new(0.2, 1.1, 0.2), cf * CFrame.new(0, -1.05, 0.1), INK, MAT.Metal)
			end
			box(m, "Teclado", 2, 0.08, 0.7, 0, 2.77, -0.6, INK, MAT.SmoothPlastic)
			neon(m, "Luz do teclado", 2.05, 0.03, 0.75, 0, 2.72, -0.6, PINK)
			box(m, "Gabinete", 1, 2.2, 2.2, 2.6, 1.1, 0.2, INK, MAT.Metal)
			local window = neon(m, "Janela do gabinete", 0.05, 1.6, 1.6, 2.08, 1.15, 0.2, PINK)
			glow(window, PINK, 0.9, 7)
		end,
	},
	{
		id = "fliperama", nome = "Fliperama retrô", preco = 1900, cat = "Tecnologia", luz = true,
		desc = "NEO RUN: o clássico de 2048, com fichas infinitas.",
		build = function(m)
			local body = rgb(48, 22, 92)
			box(m, "Gabinete", 2.8, 6.4, 2.6, 0, 3.2, 0.2, body, MAT.SmoothPlastic)
			for _, x in { -1.42, 1.42 } do
				neon(m, "Faixa lateral", 0.05, 5.6, 0.14, x, 3.2, -0.6, PINK)
				neon(m, "Faixa lateral", 0.05, 5.6, 0.14, x, 3.2, 0.4, GOLD)
			end
			local display = part(m, "Tela", Vector3.new(2.2, 1.8, 0.1), CFrame.new(0, 4.5, -1.08) * CFrame.Angles(-0.2, 0, 0), rgb(4, 4, 10))
			screen(display, Enum.NormalId.Front, "▄▀▄ NEO RUN ▄▀▄\n★ 0099990 ★\n▀▄▀▄▀▄▀▄", Enum.Font.Arcade, LIME, rgb(6, 4, 20))
			part(m, "Painel", Vector3.new(2.8, 0.35, 1.1), CFrame.new(0, 3.2, -1.45) * CFrame.Angles(0.25, 0, 0), INK, MAT.SmoothPlastic)
			for index, color in { PINK, CYAN, GOLD, LIME } do
				local button = ball(m, "Botão", 0.28, -0.2 + index * 0.32, 3.42, -1.55, color, MAT.Neon)
				button.CastShadow = false
			end
			post(m, "Manche", 0.12, 0.5, -0.8, 3.6, -1.5, CHROME, MAT.Metal)
			ball(m, "Bola do manche", 0.3, -0.8, 3.9, -1.5, rgb(220, 30, 40), MAT.SmoothPlastic)
			local marquee = box(m, "Letreiro", 2.8, 0.8, 0.3, 0, 6.2, -0.95, rgb(10, 6, 24))
			screen(marquee, Enum.NormalId.Front, "NEO RUN", Enum.Font.Arcade, GOLD, nil)
			glow(marquee, PINK, 1.1, 9)
		end,
	},
	{
		id = "geladeira", nome = "Geladeira inteligente", preco = 1300, cat = "Cozinha",
		desc = "Inox, tela de temperatura e cheia de energético.",
		build = function(m)
			box(m, "Corpo", 3.4, 7, 3, 0, 3.5, 0, rgb(176, 180, 188), MAT.Metal)
			box(m, "Divisão", 3.42, 0.08, 3.02, 0, 4.6, 0, GRAPHITE, MAT.Metal)
			box(m, "Puxador", 0.15, 1.8, 0.2, 1.35, 5.7, -1.6, CHROME, MAT.Metal)
			box(m, "Puxador", 0.15, 1.6, 0.2, 1.35, 3.5, -1.6, CHROME, MAT.Metal)
			local panel = box(m, "Tela", 1.2, 0.8, 0.05, -0.7, 5.5, -1.53, INK)
			screen(panel, Enum.NormalId.Front, "4°C\n23:40", Enum.Font.Michroma, CYAN, rgb(6, 14, 22))
			neon(m, "Filete", 0.06, 6.8, 0.06, -1.68, 3.5, -1.5, CYAN)
		end,
	},
	{
		id = "cozinha", nome = "Cozinha compacta", preco = 2000, cat = "Cozinha", luz = true,
		desc = "Pia, cooktop de indução e armários com luz.",
		build = function(m)
			box(m, "Balcão", 7, 3.2, 2.4, 0, 1.6, 0, rgb(36, 36, 44), MAT.Metal)
			box(m, "Tampo", 7.2, 0.25, 2.6, 0, 3.32, 0, rgb(200, 202, 210), MAT.Metal)
			box(m, "Cuba", 1.8, 0.2, 1.4, -1.8, 3.38, -0.1, GRAPHITE, MAT.Metal)
			post(m, "Torneira", 0.15, 1.2, -1.8, 4, 0.7, CHROME, MAT.Metal)
			for _, x in { 1.2, 2.5 } do
				local burner = part(m, "Boca", Vector3.new(0.05, 0.9, 0.9), CFrame.new(x, 3.46, -0.1) * CFrame.Angles(0, 0, math.pi / 2), rgb(255, 60, 40),
					MAT.Neon, Enum.PartType.Cylinder)
				burner.CastShadow = false
			end
			box(m, "Painel de fundo", 7, 3.4, 0.2, 0, 5.2, 1.1, rgb(30, 30, 36), MAT.SmoothPlastic)
			box(m, "Armário de cima", 7, 1.8, 1.4, 0, 7.6, 0.5, rgb(36, 36, 44), MAT.Metal)
			local strip = neon(m, "Luz do armário", 6.8, 0.06, 0.1, 0, 6.66, -0.1, GOLD)
			glow(strip, rgb(255, 214, 150), 1, 9)
			for _, x in { -2.3, 0, 2.3 } do
				box(m, "Porta", 2.2, 2.6, 0.06, x, 1.65, -1.22, rgb(48, 48, 58), MAT.SmoothPlastic)
			end
		end,
	},
	{
		id = "bancada_bar", nome = "Bancada de bar", preco = 1500, cat = "Cozinha", luz = true,
		desc = "Tampo de mármore escuro, garrafas e luz rosa.",
		build = function(m)
			box(m, "Corpo", 8, 3.3, 2, 0, 1.65, 0, INK, MAT.Metal)
			box(m, "Tampo", 8.4, 0.25, 2.6, 0, 3.42, -0.2, rgb(38, 38, 48), MAT.Marble)
			local strip = neon(m, "Luz do tampo", 8.2, 0.08, 0.06, 0, 3.25, -1.48, PINK)
			glow(strip, PINK, 1, 9)
			part(m, "Apoio dos pés", Vector3.new(7.6, 0.2, 0.2), CFrame.new(0, 0.6, -1.2), CHROME, MAT.Metal, Enum.PartType.Cylinder)
			for index, color in { rgb(40, 160, 90), rgb(160, 90, 40), rgb(60, 120, 220), rgb(200, 200, 210) } do
				local x = -3 + index * 0.6
				local bottle = post(m, "Garrafa", 0.45, 1.1, x, 4.1, 0.4, color, MAT.Glass)
				bottle.Transparency = 0.25
				post(m, "Gargalo", 0.18, 0.5, x, 4.9, 0.4, color, MAT.Glass)
			end
			post(m, "Copo", 0.35, 0.45, 1.8, 3.78, -0.4, rgb(200, 230, 255), MAT.Glass).Transparency = 0.4
		end,
	},
	{
		id = "banqueta", nome = "Banqueta de bar", preco = 250, cat = "Cozinha",
		desc = "Assento giratório com anel de luz.",
		build = function(m)
			post(m, "Base", 1.6, 0.15, 0, 0.08, 0, CHROME, MAT.Metal)
			post(m, "Haste", 0.25, 2.7, 0, 1.45, 0, CHROME, MAT.Metal)
			local ring = post(m, "Anel de luz", 1.52, 0.06, 0, 2.78, 0, PINK, MAT.Neon)
			ring.CastShadow = false
			post(m, "Assento", 1.5, 0.35, 0, 3, 0, rgb(170, 30, 50), MAT.Leather)
		end,
	},
	{
		id = "aquario", nome = "Aquário de carpas holográficas", preco = 2600, cat = "Decoração", luz = true,
		desc = "Carpas de luz nadando em água de verdade (quase).",
		build = function(m)
			box(m, "Móvel", 6, 2.4, 2.2, 0, 1.2, 0, INK, MAT.Metal)
			local water = box(m, "Água", 6, 3.4, 2.2, 0, 4.1, 0, rgb(70, 160, 255), MAT.Glass)
			water.Transparency = 0.62
			box(m, "Tampa", 6.2, 0.3, 2.4, 0, 5.95, 0, INK, MAT.Metal)
			local strip = neon(m, "Luz da tampa", 5.8, 0.05, 0.1, 0, 5.78, -0.9, CYAN)
			glow(strip, CYAN, 1.3, 11)
			for index, spot in { { -1.6, 4.4, 0.2, 0.3 }, { 0.8, 3.6, -0.3, -0.5 }, { 1.9, 4.8, 0.4, 2.6 } } do
				local koi = part(m, "Carpa", Vector3.new(0.9, 0.28, 0.34), CFrame.new(spot[1], spot[2], spot[3]) * CFrame.Angles(0, spot[4], 0),
					if index == 2 then WHITE else ORANGE, MAT.Neon)
				koi.CastShadow = false
				local tail = part(m, "Cauda", Vector3.new(0.35, 0.3, 0.06), koi.CFrame * CFrame.new(0.6, 0, 0), ORANGE, MAT.Neon)
				tail.CastShadow = false
			end
			for _, x in { -2.4, -0.3, 2.2 } do
				local weed = neon(m, "Alga", 0.08, 2.2, 0.08, x, 3.5, 0.6, rgb(60, 220, 140))
				weed.Transparency = 0.2
			end
			local bubbles = Instance.new("ParticleEmitter")
			bubbles.Name = "Bolhas"
			bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			bubbles.Rate = 6
			bubbles.Lifetime = NumberRange.new(1.2, 1.8)
			bubbles.Speed = NumberRange.new(1.4, 2)
			bubbles.Size = NumberSequence.new(0.12)
			bubbles.LightEmission = 0.6
			bubbles.Color = ColorSequence.new(rgb(200, 240, 255))
			bubbles.EmissionDirection = Enum.NormalId.Top
			bubbles.Parent = box(m, "Bomba de ar", 0.4, 0.2, 0.4, -2.4, 2.55, -0.5, GRAPHITE, MAT.Metal)
		end,
	},
	{
		id = "bonsai_led", nome = "Bonsai de LED", preco = 450, cat = "Decoração", luz = true,
		desc = "Uma árvore que nunca precisa de água.",
		build = function(m)
			box(m, "Pedestal", 1.4, 2.2, 1.4, 0, 1.1, 0, rgb(236, 236, 240), MAT.Marble)
			box(m, "Vaso", 1.6, 0.6, 1.2, 0, 2.5, 0, INK, MAT.SmoothPlastic)
			part(m, "Tronco", Vector3.new(0.25, 1.4, 0.25), CFrame.new(0.15, 3.4, 0) * CFrame.Angles(0, 0, -0.35), rgb(80, 56, 40), MAT.Wood)
			part(m, "Galho", Vector3.new(0.18, 1, 0.18), CFrame.new(-0.25, 3.7, 0) * CFrame.Angles(0, 0, 0.7), rgb(80, 56, 40), MAT.Wood)
			for _, leaf in { { 0.45, 4.15, 0, 1.1 }, { -0.6, 4, 0.1, 0.9 }, { 0.05, 4.5, -0.2, 0.8 } } do
				local crown = ball(m, "Copa", leaf[4], leaf[1], leaf[2], leaf[3], PINK, MAT.Neon)
				crown.Transparency = 0.15
				crown.CastShadow = false
			end
			glow(m:FindFirstChild("Copa") :: BasePart, PINK, 1, 8)
		end,
	},
	{
		id = "planta_neon", nome = "Planta de néon", preco = 300, cat = "Decoração",
		desc = "Folhas de acrílico verde que brilham no escuro.",
		build = function(m)
			post(m, "Vaso", 1.4, 1.4, 0, 0.7, 0, INK, MAT.SmoothPlastic)
			post(m, "Terra", 1.2, 0.1, 0, 1.38, 0, rgb(40, 30, 24), MAT.Ground)
			for index = 1, 6 do
				local angle = index * math.pi / 3
				local leaf = part(m, "Folha", Vector3.new(0.08, 2.4, 0.5),
					CFrame.new(math.cos(angle) * 0.35, 2.5, math.sin(angle) * 0.35) * CFrame.Angles(0, -angle, 0) * CFrame.Angles(0, 0, 0.35),
					if index % 2 == 0 then LIME else CYAN, MAT.Neon)
				leaf.CastShadow = false
			end
		end,
	},
	{
		id = "letreiro_rosa", nome = "Letreiro \"SEM FUTURO\"", preco = 500, cat = "Decoração", luz = true,
		desc = "Néon rosa num suporte de metal.",
		build = function(m)
			box(m, "Perna", 0.25, 2.4, 0.25, -2.6, 1.2, 0, INK, MAT.Metal)
			box(m, "Perna", 0.25, 2.4, 0.25, 2.6, 1.2, 0, INK, MAT.Metal)
			local board = box(m, "Placa", 6, 1.8, 0.25, 0, 3.2, 0, rgb(12, 10, 20), MAT.Metal)
			screen(board, Enum.NormalId.Front, "SEM FUTURO", Enum.Font.Bangers, PINK, nil)
			glow(board, PINK, 1.4, 12)
		end,
	},
	{
		id = "letreiro_ciano", nome = "Letreiro \"MARÉ BAIXA\"", preco = 500, cat = "Decoração", luz = true,
		desc = "Néon ciano com o nome do bairro.",
		build = function(m)
			box(m, "Perna", 0.25, 2.4, 0.25, -2.6, 1.2, 0, INK, MAT.Metal)
			box(m, "Perna", 0.25, 2.4, 0.25, 2.6, 1.2, 0, INK, MAT.Metal)
			local board = box(m, "Placa", 6, 1.8, 0.25, 0, 3.2, 0, rgb(10, 14, 22), MAT.Metal)
			screen(board, Enum.NormalId.Front, "MARÉ BAIXA", Enum.Font.Michroma, CYAN, nil)
			glow(board, CYAN, 1.4, 12)
		end,
	},
	{
		id = "letreiro_ouro", nome = "Letreiro \"CROMO\"", preco = 650, cat = "Decoração", luz = true,
		desc = "Dourado, para quem já subiu na vida.",
		build = function(m)
			box(m, "Perna", 0.25, 2.4, 0.25, -2.1, 1.2, 0, INK, MAT.Metal)
			box(m, "Perna", 0.25, 2.4, 0.25, 2.1, 1.2, 0, INK, MAT.Metal)
			local board = box(m, "Placa", 5, 1.8, 0.25, 0, 3.2, 0, rgb(18, 14, 8), MAT.Metal)
			screen(board, Enum.NormalId.Front, "CROMO", Enum.Font.Sarpanch, GOLD, nil)
			glow(board, GOLD, 1.4, 12)
		end,
	},
	{
		id = "luminaria_lava", nome = "Luminária de lava gigante", preco = 220, cat = "Decoração", luz = true,
		desc = "Bolhas de cera quente subindo devagar.",
		build = function(m)
			post(m, "Base", 1.2, 1.2, 0, 0.6, 0, CHROME, MAT.Metal)
			local glass = post(m, "Vidro", 0.9, 2.6, 0, 2.5, 0, rgb(255, 140, 60), MAT.Glass)
			glass.Transparency = 0.45
			for _, blob in { { 0.1, 1.7, 0.5 }, { -0.1, 2.6, 0.4 }, { 0.05, 3.3, 0.35 } } do
				local wax = ball(m, "Cera", blob[3], blob[1], blob[2], 0, ORANGE, MAT.Neon)
				wax.CastShadow = false
			end
			post(m, "Tampa", 0.7, 0.4, 0, 4, 0, CHROME, MAT.Metal)
			glow(glass, ORANGE, 1.2, 10)
		end,
	},
	{
		id = "poste_led", nome = "Luminária de pé LED", preco = 380, cat = "Decoração", luz = true,
		desc = "Um tubo de luz ciano de quase dois metros.",
		build = function(m)
			post(m, "Base", 1.4, 0.2, 0, 0.1, 0, INK, MAT.Metal)
			local tube = neon(m, "Tubo", 0.3, 5.4, 0.3, 0, 2.9, 0, CYAN)
			box(m, "Ponta", 0.45, 0.3, 0.45, 0, 5.75, 0, INK, MAT.Metal)
			glow(tube, CYAN, 1.6, 14)
		end,
	},
	{
		id = "divisoria", nome = "Divisória de painéis", preco = 700, cat = "Decoração",
		desc = "Três painéis de vidro roxo para separar ambientes.",
		build = function(m)
			for index, angle in { 0.35, 0, -0.35 } do
				local x = (index - 2) * 2.1
				local cf = CFrame.new(x, 3.05, (index == 2) and 0.35 or 0) * CFrame.Angles(0, angle, 0)
				part(m, "Moldura", Vector3.new(2.2, 6, 0.2), cf, INK, MAT.Metal)
				local pane = part(m, "Vidro", Vector3.new(1.8, 5.4, 0.22), cf, VIOLET, MAT.Glass)
				pane.Transparency = 0.35
				local edge = part(m, "Filete", Vector3.new(0.06, 5.6, 0.24), cf * CFrame.new(1.02, 0, 0), PINK, MAT.Neon)
				edge.CastShadow = false
			end
		end,
	},
	{
		id = "rack_katanas", nome = "Rack de katanas", preco = 1800, cat = "Decoração",
		desc = "Três lâminas monomoleculares em exposição.",
		build = function(m)
			box(m, "Base", 3.8, 0.6, 1.4, 0, 0.3, 0, rgb(50, 30, 24), MAT.Wood)
			for _, x in { -1.6, 1.6 } do
				box(m, "Coluna", 0.3, 3.4, 0.5, x, 2.3, 0, rgb(50, 30, 24), MAT.Wood)
			end
			for index = 1, 3 do
				local y = 1.6 + index * 0.75
				box(m, "Lâmina", 3.2, 0.08, 0.22, 0.25, y, -0.2, rgb(210, 214, 224), MAT.Metal)
				box(m, "Cabo", 0.9, 0.18, 0.18, -1.95, y, -0.2, INK, MAT.Fabric)
				post(m, "Guarda", 0.42, 0.06, -1.45, y, -0.2, GOLD, MAT.Metal).CFrame = CFrame.new(-1.45, y, -0.2)
			end
			neon(m, "Luz da base", 3.7, 0.05, 0.08, 0, 0.62, -0.72, PINK)
		end,
	},
	{
		id = "parede_armas", nome = "Expositor de armas", preco = 2200, cat = "Decoração", luz = true,
		desc = "Painel com fuzis e pistolas, moldura de néon.",
		build = function(m)
			box(m, "Base", 6, 0.5, 1.4, 0, 0.25, 0, INK, MAT.Metal)
			box(m, "Painel", 6, 5.4, 0.4, 0, 3.2, 0.3, rgb(30, 30, 36), MAT.DiamondPlate)
			neon(m, "Moldura", 6.1, 0.12, 0.1, 0, 5.9, 0.08, CYAN)
			neon(m, "Moldura", 6.1, 0.12, 0.1, 0, 0.55, 0.08, CYAN)
			neon(m, "Moldura", 0.12, 5.4, 0.1, -3, 3.2, 0.08, CYAN)
			neon(m, "Moldura", 0.12, 5.4, 0.1, 3, 3.2, 0.08, CYAN)
			local gun = rgb(54, 56, 62)
			for _, y in { 4.6, 3.4 } do
				box(m, "Fuzil", 4.2, 0.4, 0.2, 0, y, 0.02, gun, MAT.Metal)
				box(m, "Coronha", 1, 0.7, 0.2, -2.3, y - 0.1, 0.02, rgb(80, 60, 44), MAT.Wood)
				box(m, "Pente", 0.35, 0.8, 0.2, 0.4, y - 0.55, 0.02, gun, MAT.Metal)
			end
			for _, x in { -1.4, 1.4 } do
				box(m, "Pistola", 1.2, 0.35, 0.2, x, 2.1, 0.02, gun, MAT.Metal)
				box(m, "Cabo", 0.3, 0.6, 0.2, x - 0.4, 1.75, 0.02, gun, MAT.Metal)
			end
			glow(m:FindFirstChild("Moldura") :: BasePart, CYAN, 0.9, 9)
		end,
	},
	{
		id = "saco_pancada", nome = "Saco de pancada", preco = 650, cat = "Academia",
		desc = "Para descarregar a raiva sem chamar a PMMB.",
		build = function(m)
			box(m, "Base", 3, 0.3, 3, 0, 0.15, 0, INK, MAT.Metal)
			box(m, "Coluna", 0.4, 7.4, 0.4, 0, 3.85, 1.3, INK, MAT.Metal)
			box(m, "Braço", 0.4, 0.4, 1.5, 0, 7.4, 0.6, INK, MAT.Metal)
			post(m, "Corrente", 0.12, 1.2, 0, 6.6, 0, CHROME, MAT.Metal)
			post(m, "Saco", 1.6, 3.4, 0, 4.2, 0, rgb(170, 24, 36), MAT.Leather)
			post(m, "Fita", 1.64, 0.25, 0, 5.4, 0, INK, MAT.Fabric)
			post(m, "Fita", 1.64, 0.25, 0, 3, 0, INK, MAT.Fabric)
		end,
	},
	{
		id = "supino", nome = "Banco de supino", preco = 900, cat = "Academia",
		desc = "Barra com anilhas de néon. Força de cromo.",
		build = function(m)
			box(m, "Estofado", 1.3, 0.4, 4.4, 0, 1.5, -0.4, INK, MAT.Leather)
			box(m, "Pé", 1, 1.3, 0.3, 0, 0.65, -2.2, GRAPHITE, MAT.Metal)
			box(m, "Pé", 1, 1.3, 0.3, 0, 0.65, 1.2, GRAPHITE, MAT.Metal)
			for _, x in { -1.6, 1.6 } do
				box(m, "Suporte", 0.25, 3.8, 0.25, x, 1.9, 2, GRAPHITE, MAT.Metal)
			end
			part(m, "Barra", Vector3.new(6.6, 0.2, 0.2), CFrame.new(0, 3.6, 2), CHROME, MAT.Metal, Enum.PartType.Cylinder)
			for _, x in { -2.7, 2.7 } do
				part(m, "Anilha", Vector3.new(0.3, 1.8, 1.8), CFrame.new(x, 3.6, 2), INK, MAT.Rubber, Enum.PartType.Cylinder)
				local rim = part(m, "Aro", Vector3.new(0.32, 1.84, 1.84), CFrame.new(x + (if x > 0 then 0.04 else -0.04), 3.6, 2), PINK, MAT.Neon,
					Enum.PartType.Cylinder)
				rim.Size = Vector3.new(0.05, 1.84, 1.84)
				rim.CFrame = CFrame.new(x + (if x > 0 then 0.17 else -0.17), 3.6, 2)
				rim.CastShadow = false
			end
		end,
	},
	{
		id = "jukebox", nome = "Jukebox néon", preco = 1400, cat = "Sala", luz = true,
		desc = "Discos de vinil de verdade. Raridade em 2077.",
		build = function(m)
			box(m, "Corpo", 3, 4.2, 2, 0, 2.1, 0, rgb(60, 28, 20), MAT.Wood)
			part(m, "Arco", Vector3.new(2, 3, 3), CFrame.new(0, 4.2, 0) * CFrame.Angles(0, math.pi / 2, 0), rgb(60, 28, 20), MAT.Wood,
				Enum.PartType.Cylinder)
			for index, color in { PINK, GOLD, CYAN } do
				local x = (index - 2) * 1.05
				neon(m, "Tubo", 0.14, 3.6, 0.14, x * 1.3, 2.6, -1.02, color)
			end
			local window = box(m, "Janela", 1.9, 1.3, 0.08, 0, 4.25, -1.02, rgb(20, 20, 30), MAT.Glass)
			window.Transparency = 0.2
			screen(window, Enum.NormalId.Front, "◉ ◉ ◉ ◉", Enum.Font.GothamBlack, GOLD, nil)
			box(m, "Grade", 2.2, 1.2, 0.06, 0, 1.2, -1.02, INK, MAT.DiamondPlate)
			glow(window, GOLD, 1, 9)
		end,
	},
	{
		id = "caixa_som", nome = "Caixa de som", preco = 500, cat = "Sala",
		desc = "Grave que treme o prédio inteiro.",
		build = function(m)
			box(m, "Caixa", 2, 5, 2, 0, 2.5, 0, INK, MAT.SmoothPlastic)
			for _, spec in { { 1.5, 1.6 }, { 0.9, 3.6 } } do
				part(m, "Alto-falante", Vector3.new(0.2, spec[1], spec[1]), CFrame.new(0, spec[2], -1) * CFrame.Angles(0, math.pi / 2, 0), GRAPHITE,
					MAT.Rubber, Enum.PartType.Cylinder)
				local rim = part(m, "Aro", Vector3.new(0.12, spec[1] + 0.16, spec[1] + 0.16), CFrame.new(0, spec[2], -0.98) * CFrame.Angles(0, math.pi / 2, 0),
					if spec[1] > 1 then PINK else CYAN, MAT.Neon, Enum.PartType.Cylinder)
				rim.CastShadow = false
			end
		end,
	},
	{
		id = "guarda_roupa", nome = "Guarda-roupa espelhado", preco = 1200, cat = "Quarto",
		desc = "Portas de espelho para conferir o visual cromado.",
		build = function(m)
			box(m, "Corpo", 6, 7.4, 2.4, 0, 3.7, 0, rgb(30, 30, 38), MAT.Metal)
			for _, x in { -1.48, 1.48 } do
				local mirror = box(m, "Espelho", 2.8, 6.8, 0.08, x, 3.7, -1.22, rgb(200, 210, 230), MAT.Glass)
				mirror.Reflectance = 0.55
			end
			neon(m, "Luz de cima", 5.8, 0.08, 0.08, 0, 7.42, -1.2, VIOLET)
		end,
	},
	{
		id = "estatua", nome = "Estátua cromada", preco = 3000, cat = "Decoração",
		desc = "Você em cromo, posando como lenda da rua.",
		build = function(m)
			box(m, "Pedestal", 2.6, 2, 2.6, 0, 1, 0, rgb(236, 236, 240), MAT.Marble)
			neon(m, "Faixa", 2.62, 0.1, 2.62, 0, 1.9, 0, PINK)
			local chrome = rgb(196, 200, 210)
			local s = 0.8
			local figure = {
				{ "Torso", 2, 2, 1, 0, 5, 0, 0 }, { "Cabeça", 1.2, 1.2, 1.2, 0, 6.6, 0, 0 },
				{ "Braço", 1, 2, 1, -1.6, 4.9, 0, -0.35 }, { "Braço", 1, 2, 1, 1.75, 5.9, -0.2, 2.5 },
				{ "Perna", 1, 2, 1, -0.55, 3, 0, 0.1 }, { "Perna", 1, 2, 1, 0.55, 3, 0, -0.1 },
			}
			for _, piece in figure do
				local cf = CFrame.new(piece[5] * s, 2 + (piece[6] - 2) * s, piece[7] * s) * CFrame.Angles(0, 0, piece[8])
				local limb = part(m, piece[1], Vector3.new(piece[2], piece[3], piece[4]) * s, cf, chrome, MAT.Metal)
				limb.Reflectance = 0.35
			end
		end,
	},
}
local FURNITURE_BY_ID = {}
for index, def in FURNITURE do
	def.ordem = index
	FURNITURE_BY_ID[def.id] = def
end
M.FURNITURE = FURNITURE
M.FURNITURE_BY_ID = FURNITURE_BY_ID

local function buildFurniture(def): (Model, Vector3)
	local model = Instance.new("Model")
	model.Name = def.id
	def.build(model)
	local size = finish(model)
	model:SetAttribute("Id", def.id)
	model:SetAttribute("Tamanho", size)
	return model, size
end
M.buildFurniture = buildFurniture

-- Reforma: piso, luz do teto e vidro das janelas. O primeiro de cada lista é o de graça.
local RENOVATIONS = {
	piso = {
		{ id = "concreto", nome = "Concreto", preco = 0, cor = { 92, 92, 100 }, mat = "Concrete" },
		{ id = "vinilico", nome = "Vinílico grafite", preco = 400, cor = { 58, 58, 66 }, mat = "SmoothPlastic" },
		{ id = "madeira", nome = "Madeira escura", preco = 900, cor = { 86, 58, 42 }, mat = "WoodPlanks" },
		{ id = "porcelanato", nome = "Porcelanato espelhado", preco = 1800, cor = { 30, 30, 36 }, mat = "Marble", brilho = 0.18 },
		{ id = "hexagono", nome = "Hexágono néon", preco = 3200, cor = { 34, 24, 60 }, mat = "CeramicTiles", brilho = 0.1, neon = { 150, 90, 255 } },
	},
	luz = {
		{ id = "fluorescente", nome = "Fluorescente", preco = 0, cor = { 235, 245, 255 } },
		{ id = "quente", nome = "Luz quente", preco = 200, cor = { 255, 214, 160 } },
		{ id = "rosa", nome = "Néon rosa", preco = 600, cor = { 255, 90, 170 } },
		{ id = "ciano", nome = "Néon ciano", preco = 600, cor = { 90, 230, 255 } },
		{ id = "por_do_sol", nome = "Pôr do sol", preco = 900, cor = { 255, 140, 90 } },
	},
	vidro = {
		{ id = "comum", nome = "Vidro comum", preco = 0, cor = { 150, 170, 190 }, transparencia = 0.55 },
		{ id = "fume", nome = "Vidro fumê", preco = 500, cor = { 40, 44, 54 }, transparencia = 0.35 },
		{ id = "roxo", nome = "Vidro inteligente roxo", preco = 1200, cor = { 120, 70, 200 }, transparencia = 0.45 },
	},
}
M.RENOVATIONS = RENOVATIONS
local function renovation(kind: string, id: string?)
	for _, option in RENOVATIONS[kind] or {} do
		if option.id == id then
			return option
		end
	end
	return (RENOVATIONS[kind] or {})[1]
end
M.renovation = renovation

-- Sorteio determinístico (mesma semente, mesmo resultado no servidor e nos testes).
local function rand(seed: number)
	local state = math.floor(seed) % 2147483646 + 1
	local r = {}
	function r.next(): number
		state = state * 48271 % 2147483647
		return state / 2147483647
	end
	function r.range(a: number, b: number): number
		return a + (b - a) * r.next()
	end
	function r.int(a: number, b: number): number
		return math.min(b, a + math.floor((b - a + 1) * r.next()))
	end
	function r.pick(list)
		return list[r.int(1, #list)]
	end
	function r.chance(p: number): boolean
		return r.next() < p
	end
	return r
end
M.rand = rand

-- Pedestres: corpo R6 padrão do Roblox, roupa e implantes feitos de peças soldadas ---------------------------
local function cfm(x, y, z, m)
	return CFrame.new(x, y, z, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
end
local RM = { 0, 0, 1, 0, 1, 0, -1, 0, 0 }
local LM = { 0, 0, -1, 0, 1, 0, 1, 0, 0 }
local ROOTM = { -1, 0, 0, 0, 0, 1, 0, 1, 0 }
-- Mesmos C0/C1 do rig R6 que o Roblox cria para os jogadores (as animações do jogo contam com eles).
local R6_MOTORS = {
	{ "RootJoint", "HumanoidRootPart", "Torso", cfm(0, 0, 0, ROOTM), cfm(0, 0, 0, ROOTM) },
	{ "Neck", "Torso", "Head", cfm(0, 1, 0, ROOTM), cfm(0, -0.5, 0, ROOTM) },
	{ "Right Shoulder", "Torso", "Right Arm", cfm(1, 0.5, 0, RM), cfm(-0.5, 0.5, 0, RM) },
	{ "Left Shoulder", "Torso", "Left Arm", cfm(-1, 0.5, 0, LM), cfm(0.5, 0.5, 0, LM) },
	{ "Right Hip", "Torso", "Right Leg", cfm(1, -1, 0, RM), cfm(0.5, 1, 0, RM) },
	{ "Left Hip", "Torso", "Left Leg", cfm(-1, -1, 0, LM), cfm(-0.5, 1, 0, LM) },
}
M.R6_MOTORS = R6_MOTORS
local REST = {
	HumanoidRootPart = Vector3.new(0, 3, 0), Torso = Vector3.new(0, 3, 0), Head = Vector3.new(0, 4.5, 0),
	["Right Arm"] = Vector3.new(1.5, 3, 0), ["Left Arm"] = Vector3.new(-1.5, 3, 0),
	["Right Leg"] = Vector3.new(0.5, 1, 0), ["Left Leg"] = Vector3.new(-0.5, 1, 0),
}

local function rig(name: string, skin: Color3, shirt: Color3, pants: Color3, sleeves: Color3): Model
	local model = Instance.new("Model")
	model.Name = name
	local sizes = {
		HumanoidRootPart = Vector3.new(2, 2, 1), Torso = Vector3.new(2, 2, 1), Head = Vector3.new(2, 1, 1),
		["Right Arm"] = Vector3.new(1, 2, 1), ["Left Arm"] = Vector3.new(1, 2, 1), ["Right Leg"] = Vector3.new(1, 2, 1), ["Left Leg"] = Vector3.new(1, 2, 1),
	}
	local colors = {
		HumanoidRootPart = skin, Torso = shirt, Head = skin, ["Right Arm"] = sleeves, ["Left Arm"] = sleeves, ["Right Leg"] = pants, ["Left Leg"] = pants,
	}
	local parts = {}
	for _, key in { "HumanoidRootPart", "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
		local item = part(model, key, sizes[key], CFrame.new(REST[key]), colors[key], MAT.SmoothPlastic)
		item.Anchored = false
		item.CanCollide = key == "Torso" or key == "Head"
		parts[key] = item
	end
	local root = parts.HumanoidRootPart
	root.Transparency = 1
	root.CanCollide = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = parts.Head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = parts.Head
	for _, spec in R6_MOTORS do
		local motor = Instance.new("Motor6D")
		motor.Name = spec[1]
		motor.Part0 = parts[spec[2]]
		motor.Part1 = parts[spec[3]]
		motor.C0 = spec[4]
		motor.C1 = spec[5]
		motor.Parent = parts[spec[2]]
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end
M.rig = rig

-- Peça de roupa ou implante soldada numa parte do corpo (offset no espaço da parte).
local function wear(model: Model, bodyName: string, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local body = model:FindFirstChild(bodyName) :: BasePart
	local item = part(model, name, size, body.CFrame * offset, color, material, shape)
	item.Anchored = false
	item.CanCollide = false
	item.CanTouch = false
	item.Massless = true
	local weld = Instance.new("Weld")
	weld.Name = "Solda"
	weld.Part0 = body
	weld.Part1 = item
	weld.C0 = offset
	weld.Parent = item
	if material == MAT.Neon then
		item.CastShadow = false
	end
	return item
end
M.wear = wear

local SKINS = { rgb(255, 222, 194), rgb(236, 192, 152), rgb(208, 154, 112), rgb(164, 112, 78), rgb(124, 84, 58), rgb(88, 60, 42), rgb(246, 206, 172) }
local HAIR = { rgb(28, 22, 18), rgb(70, 46, 30), rgb(140, 100, 62), rgb(206, 174, 112), rgb(154, 154, 160) }
local NEONS = { PINK, CYAN, VIOLET, LIME, GOLD, rgb(255, 84, 60) }
local DARKS = { rgb(26, 26, 32), rgb(40, 40, 50), rgb(58, 46, 42), rgb(30, 40, 62), rgb(62, 30, 42), rgb(36, 54, 46), rgb(72, 72, 82), rgb(112, 102, 92) }
local BRIGHTS = { rgb(200, 40, 70), rgb(240, 200, 40), rgb(40, 160, 200), rgb(232, 232, 238), rgb(140, 60, 200), rgb(240, 120, 40) }

-- Gangues de Maré Baixa (nomes próprios do jogo).
local GANGS = {
	cromados = { nome = "Os Cromados", cor = GOLD, roupa = rgb(30, 30, 34), detalhe = rgb(196, 200, 210), armas = { "uzi", "glock", "deagle" } },
	vudu = { nome = "Vudu Néon", cor = CYAN, roupa = rgb(30, 26, 70), detalhe = rgb(60, 40, 120), armas = { "glock", "uzi", "escopeta" } },
	rubra = { nome = "Lâmina Rubra", cor = rgb(255, 50, 60), roupa = rgb(110, 16, 26), detalhe = rgb(40, 10, 14), armas = { "ak47", "glock", "escopeta" } },
}
M.GANGS = GANGS
local GANG_ORDER = { "cromados", "vudu", "rubra" }
M.GANG_ORDER = GANG_ORDER

-- Sorteia o visual de um pedestre. kind: civil, gangue, policia, alvo, camelo, contato.
local CIVIL_STYLES = { "corpo", "punk", "netrunner", "rua", "nomade", "trabalhador", "idoso", "balada" }
local function outfit(seed: number, kind: string, gangKey: string?, forced: string?)
	local r = rand(seed)
	local spec = {
		kind = kind, skin = r.pick(SKINS), hair = { style = "curto", color = r.pick(HAIR) }, face = {}, extras = {},
		boots = rgb(22, 22, 26), cyberarm = nil :: string?, gang = gangKey,
	}
	local style = forced or (if kind == "civil" then r.pick(CIVIL_STYLES) else kind)
	spec.style = style
	local function jacket(color: Color3, open: boolean, trim: Color3?)
		spec.jacket = { color = color, open = open, trim = trim }
		spec.sleeve = color
	end
	spec.shirt = r.pick(DARKS)
	spec.pants = r.pick(DARKS)
	spec.sleeve = spec.skin
	if style == "corpo" then
		spec.shirt, spec.pants = rgb(230, 232, 238), rgb(28, 28, 34)
		jacket(r.pick({ rgb(28, 28, 34), rgb(40, 44, 60), rgb(70, 70, 80) }), true, nil)
		spec.extras.gravata = r.pick({ rgb(160, 20, 40), rgb(30, 30, 40), CYAN })
		spec.hair.style = r.pick({ "penteado", "curto", "coque" })
		spec.face.oculos = r.chance(0.5)
		if r.chance(0.35) then
			spec.face.leds = r.pick(NEONS)
		end
	elseif style == "punk" then
		jacket(rgb(24, 24, 28), true, r.pick(NEONS))
		spec.shirt = r.pick(BRIGHTS)
		spec.hair = { style = "moicano", color = r.pick(NEONS) }
		spec.extras.ombreiras = true
		if r.chance(0.5) then
			spec.cyberarm = r.pick({ "Right Arm", "Left Arm" })
		end
		spec.face.placa = r.chance(0.4)
	elseif style == "netrunner" then
		spec.shirt = rgb(24, 24, 30)
		jacket(r.pick({ rgb(30, 30, 40), rgb(50, 40, 70), rgb(20, 40, 46) }), false, nil)
		spec.extras.capuz = true
		spec.extras.cabos = true
		spec.face.visor = r.pick({ CYAN, LIME, VIOLET })
		spec.hair.style = "raspado"
	elseif style == "rua" then
		spec.shirt = r.pick(BRIGHTS)
		jacket(r.pick(DARKS), true, if r.chance(0.5) then r.pick(NEONS) else nil)
		spec.hair.style = r.pick({ "bone", "curto", "afro", "tranças" })
		if r.chance(0.4) then
			spec.face.mascara = r.pick(NEONS)
		end
		spec.extras.mochila = r.chance(0.4)
	elseif style == "nomade" then
		jacket(rgb(120, 90, 60), true, nil)
		spec.shirt, spec.pants = rgb(170, 150, 120), rgb(70, 60, 50)
		spec.boots = rgb(70, 50, 36)
		spec.face.oculos = true
		spec.hair.style = r.pick({ "longo", "curto", "bone" })
		spec.extras.lenco = r.pick({ rgb(160, 60, 40), rgb(60, 90, 120) })
	elseif style == "trabalhador" then
		spec.shirt = rgb(60, 90, 140)
		spec.pants = rgb(60, 90, 140)
		spec.extras.colete = rgb(240, 160, 30)
		spec.hair.style = "bone"
		spec.cyberarm = if r.chance(0.4) then "Right Arm" else nil
	elseif style == "idoso" then
		spec.hair = { style = "careca", color = rgb(200, 200, 206) }
		jacket(r.pick({ rgb(80, 70, 60), rgb(50, 56, 70) }), false, nil)
		spec.face.oculos = true
		spec.face.lente = r.chance(0.5) and r.pick(NEONS) or nil
	elseif style == "balada" then
		spec.shirt = r.pick({ PINK, VIOLET, CYAN, rgb(30, 30, 36) })
		spec.pants = rgb(24, 24, 30)
		spec.hair = { style = r.pick({ "longo", "coque", "moicano", "afro" }), color = r.pick(NEONS) }
		spec.face.leds = r.pick(NEONS)
		spec.extras.saia = r.chance(0.5) and r.pick({ rgb(30, 30, 36), PINK, rgb(230, 230, 236) }) or nil
		spec.extras.fita = r.pick(NEONS)
	elseif style == "gangue" or style == "alvo" then
		local gang = GANGS[gangKey or "cromados"] or GANGS.cromados
		spec.shirt, spec.pants = gang.roupa, rgb(26, 26, 30)
		if gangKey == "cromados" then
			spec.extras.colete = gang.roupa
			spec.sleeve = gang.detalhe
			spec.cyberarm = "Both"
			spec.hair = { style = r.pick({ "raspado", "moicano" }), color = GOLD }
			spec.face.placa = true
		elseif gangKey == "vudu" then
			jacket(gang.roupa, true, CYAN)
			spec.hair = { style = r.pick({ "tranças", "longo" }), color = r.pick({ rgb(28, 22, 18), VIOLET }) }
			spec.face.leds = CYAN
			spec.face.visor = if r.chance(0.5) then CYAN else nil
		else
			jacket(gang.roupa, true, rgb(255, 50, 60))
			spec.hair = { style = r.pick({ "curto", "moicano", "raspado" }), color = r.pick({ rgb(28, 22, 18), rgb(255, 50, 60) }) }
			spec.face.mascara = rgb(255, 50, 60)
		end
		spec.extras["braçadeira"] = gang.cor
		if style == "alvo" then
			spec.extras.ombreiras = true
			spec.extras.corrente = GOLD
		end
	elseif style == "policia" then
		spec.shirt, spec.pants, spec.sleeve = rgb(24, 32, 56), rgb(20, 24, 40), rgb(24, 32, 56)
		spec.extras.colete = rgb(30, 34, 46)
		spec.extras.capacete = true
		spec.face.visor = CYAN
		spec.hair.style = "careca"
		spec.extras.ombreiras = true
	elseif style == "camelo" then
		spec.shirt = r.pick(BRIGHTS)
		spec.extras.avental = rgb(230, 230, 236)
		spec.hair.style = "bone"
	elseif style == "contato" then
		jacket(rgb(30, 30, 36), true, r.pick(NEONS))
		spec.hair.style = r.pick({ "curto", "moicano", "bone" })
		spec.face.oculos = true
	end
	return spec
end
M.outfit = outfit

-- Cor sorteada a partir da pele e do estilo (estável por pedestre, sem guardar outro gerador).
local function r_or(spec, list)
	local c = spec.skin
	local index = (math.floor(c.R * 255) + math.floor(c.G * 255) * 3 + math.floor(c.B * 255) * 7 + #spec.style) % #list + 1
	return list[index]
end

-- Veste o rig com o visual sorteado. Devolve o modelo (as peças vão soldadas no próprio corpo).
local function dress(model: Model, spec)
	local skin = spec.skin
	local function cyber(arm: string)
		local chrome = if spec.gang == "cromados" then rgb(210, 214, 222) else rgb(150, 154, 164)
		local limb = model:FindFirstChild(arm) :: BasePart
		limb.Color = chrome
		limb.Material = MAT.Metal
		limb.Reflectance = 0.2
		wear(model, arm, "Anel cibernético", Vector3.new(1.06, 0.14, 1.06), CFrame.new(0, 0.1, 0), spec.hair.color or CYAN, MAT.Neon)
		wear(model, arm, "Placa do braço", Vector3.new(1.08, 0.8, 0.5), CFrame.new(0, 0.55, 0.28), rgb(60, 62, 70), MAT.Metal)
		wear(model, arm, "Mão cibernética", Vector3.new(1.04, 0.5, 1.04), CFrame.new(0, -0.76, 0), rgb(52, 54, 62), MAT.Metal)
	end
	-- Mãos com a cor da pele quando a manga cobre o braço.
	for _, arm in { "Right Arm", "Left Arm" } do
		local isCyber = spec.cyberarm == arm or spec.cyberarm == "Both"
		if isCyber then
			cyber(arm)
		elseif spec.sleeve ~= skin then
			wear(model, arm, "Mão", Vector3.new(1.02, 0.42, 1.02), CFrame.new(0, -0.8, 0), skin, MAT.SmoothPlastic)
		end
	end
	if spec.jacket then
		local j = spec.jacket
		wear(model, "Torso", "Jaqueta", Vector3.new(2.1, 2.04, 0.56), CFrame.new(0, 0, 0.26), j.color, MAT.Fabric)
		if j.open then
			wear(model, "Torso", "Lapela", Vector3.new(0.62, 2.04, 0.54), CFrame.new(-0.74, 0, -0.26), j.color, MAT.Fabric)
			wear(model, "Torso", "Lapela", Vector3.new(0.62, 2.04, 0.54), CFrame.new(0.74, 0, -0.26), j.color, MAT.Fabric)
			if j.trim then
				wear(model, "Torso", "Filete", Vector3.new(0.08, 2.02, 0.08), CFrame.new(-0.42, 0, -0.52), j.trim, MAT.Neon)
				wear(model, "Torso", "Filete", Vector3.new(0.08, 2.02, 0.08), CFrame.new(0.42, 0, -0.52), j.trim, MAT.Neon)
			end
		else
			wear(model, "Torso", "Frente da jaqueta", Vector3.new(2.1, 2.04, 0.54), CFrame.new(0, 0, -0.26), j.color, MAT.Fabric)
			if j.trim then
				wear(model, "Torso", "Filete", Vector3.new(2.12, 0.08, 1.12), CFrame.new(0, -0.6, 0), j.trim, MAT.Neon)
			end
		end
		wear(model, "Torso", "Gola", Vector3.new(2.2, 0.3, 1.2), CFrame.new(0, 0.92, 0), j.color, MAT.Fabric)
	end
	wear(model, "Torso", "Cinto", Vector3.new(2.06, 0.24, 1.06), CFrame.new(0, -0.9, 0), rgb(20, 20, 24), MAT.Leather)
	local extras = spec.extras
	if extras.colete then
		wear(model, "Torso", "Colete", Vector3.new(2.14, 1.5, 1.16), CFrame.new(0, 0.2, 0), extras.colete, MAT.Fabric)
		if spec.style == "policia" then
			local back = wear(model, "Torso", "Placa do colete", Vector3.new(1.6, 0.6, 0.06), CFrame.new(0, 0.35, 0.6), rgb(20, 24, 36), MAT.SmoothPlastic)
			screen(back, Enum.NormalId.Back, "PMMB", Enum.Font.Michroma, CYAN, rgb(20, 24, 36))
			wear(model, "Torso", "Distintivo", Vector3.new(0.3, 0.36, 0.06), CFrame.new(-0.5, 0.45, -0.6), GOLD, MAT.Metal)
		end
	end
	if extras.gravata then
		wear(model, "Torso", "Gravata", Vector3.new(0.24, 1.3, 0.06), CFrame.new(0, 0.25, -0.52), extras.gravata, MAT.Fabric)
	end
	if extras.avental then
		wear(model, "Torso", "Avental", Vector3.new(1.7, 2.6, 0.06), CFrame.new(0, -0.5, -0.53), extras.avental, MAT.Fabric)
	end
	if extras["braçadeira"] then
		wear(model, "Left Arm", "Braçadeira", Vector3.new(1.06, 0.3, 1.06), CFrame.new(0, 0.5, 0), extras["braçadeira"], MAT.Neon)
	end
	if extras.ombreiras then
		local tone = if spec.style == "policia" then rgb(30, 36, 58) else rgb(60, 62, 70)
		for _, arm in { "Right Arm", "Left Arm" } do
			wear(model, arm, "Ombreira", Vector3.new(1.2, 0.5, 1.24), CFrame.new(0, 0.85, 0), tone, MAT.Metal)
		end
	end
	if extras.corrente then
		wear(model, "Torso", "Corrente", Vector3.new(1.3, 0.12, 0.12), CFrame.new(0, 0.55, -0.56) * CFrame.Angles(0, 0, 0.05), extras.corrente, MAT.Metal)
	end
	if extras.mochila then
		wear(model, "Torso", "Mochila", Vector3.new(1.6, 1.6, 0.7), CFrame.new(0, 0.1, 0.85), r_or(spec, DARKS), MAT.Fabric)
	end
	if extras.lenco then
		wear(model, "Torso", "Lenço", Vector3.new(1.4, 0.4, 1.14), CFrame.new(0, 0.86, 0) * CFrame.Angles(0, 0, 0.08), extras.lenco, MAT.Fabric)
	end
	if extras.saia then
		wear(model, "Torso", "Saia", Vector3.new(2.2, 1, 1.2), CFrame.new(0, -1.4, 0), extras.saia, MAT.Fabric)
	end
	if extras.fita then
		wear(model, "Right Arm", "Pulseira", Vector3.new(1.05, 0.14, 1.05), CFrame.new(0, -0.45, 0), extras.fita, MAT.Neon)
	end
	-- Pernas: botas e, nas gangues, joelheiras.
	for _, leg in { "Right Leg", "Left Leg" } do
		wear(model, leg, "Bota", Vector3.new(1.06, 0.62, 1.12), CFrame.new(0, -0.7, -0.04), spec.boots, MAT.Leather)
		if spec.style == "gangue" or spec.style == "alvo" or spec.style == "policia" then
			wear(model, leg, "Joelheira", Vector3.new(1.08, 0.4, 0.3), CFrame.new(0, 0.05, -0.5), rgb(46, 48, 56), MAT.Metal)
		end
	end
	-- Cabeça: cabelo, chapéus, visor e implantes de rosto (a cabeça R6 é a malha "Head" a 1,25).
	local hair, color = spec.hair.style, spec.hair.color
	if hair == "curto" or hair == "penteado" or hair == "raspado" or hair == "coque" or hair == "longo" or hair == "tranças" then
		local thick = if hair == "raspado" then 0.14 else 0.32
		wear(model, "Head", "Cabelo", Vector3.new(1.32, thick, 1.32), CFrame.new(0, 0.58 + thick / 2 - 0.12, 0.02), color, MAT.Fabric)
		if hair ~= "raspado" then
			wear(model, "Head", "Nuca", Vector3.new(1.32, 0.7, 0.3), CFrame.new(0, 0.2, 0.54), color, MAT.Fabric)
		end
		if hair == "penteado" then
			wear(model, "Head", "Topete", Vector3.new(1.1, 0.25, 0.5), CFrame.new(0, 0.82, -0.32), color, MAT.Fabric)
		elseif hair == "coque" then
			wear(model, "Head", "Coque", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 0.9, 0.35), color, MAT.Fabric, Enum.PartType.Ball)
		elseif hair == "longo" then
			wear(model, "Head", "Cabelo comprido", Vector3.new(1.34, 1.5, 0.34), CFrame.new(0, -0.15, 0.56), color, MAT.Fabric)
		elseif hair == "tranças" then
			for _, x in { -0.4, 0, 0.4 } do
				wear(model, "Head", "Trança", Vector3.new(0.22, 1.5, 0.22), CFrame.new(x, -0.3, 0.6), color, MAT.Fabric)
			end
		end
	elseif hair == "moicano" then
		wear(model, "Head", "Moicano", Vector3.new(0.3, 0.7, 1.3), CFrame.new(0, 0.9, 0.05), color, MAT.Neon)
		wear(model, "Head", "Raspado", Vector3.new(1.3, 0.1, 1.3), CFrame.new(0, 0.55, 0.02), rgb(40, 34, 30), MAT.Fabric)
	elseif hair == "afro" then
		wear(model, "Head", "Black power", Vector3.new(1.75, 1.6, 1.7), CFrame.new(0, 0.55, 0.15), color, MAT.Fabric, Enum.PartType.Ball)
	elseif hair == "bone" then
		local cap = if spec.style == "camelo" then rgb(230, 230, 236) else r_or(spec, BRIGHTS)
		wear(model, "Head", "Boné", Vector3.new(1.34, 0.4, 1.34), CFrame.new(0, 0.6, 0.02), cap, MAT.Fabric)
		wear(model, "Head", "Aba", Vector3.new(1.1, 0.1, 0.7), CFrame.new(0, 0.44, -0.86), cap, MAT.Fabric)
	end
	if extras.capuz then
		wear(model, "Head", "Capuz", Vector3.new(1.5, 1.45, 1.4), CFrame.new(0, 0.15, 0.14), spec.jacket and spec.jacket.color or rgb(30, 30, 40), MAT.Fabric)
	end
	if extras.capacete then
		wear(model, "Head", "Capacete", Vector3.new(1.46, 0.9, 1.46), CFrame.new(0, 0.5, 0.02), rgb(26, 30, 44), MAT.Metal)
	end
	local face = spec.face
	if face.visor then
		local visor = wear(model, "Head", "Visor", Vector3.new(1.36, 0.26, 0.2), CFrame.new(0, 0.12, -0.62), face.visor, MAT.Neon)
		visor.Transparency = 0.15
	elseif face.oculos then
		for _, x in { -0.3, 0.3 } do
			wear(model, "Head", "Lente", Vector3.new(0.42, 0.24, 0.08), CFrame.new(x, 0.12, -0.64), face.lente or rgb(16, 16, 20), if face.lente then MAT.Neon else MAT.Glass)
		end
		wear(model, "Head", "Armação", Vector3.new(1.3, 0.06, 0.06), CFrame.new(0, 0.22, -0.64), rgb(20, 20, 24), MAT.Metal)
	end
	if face.mascara then
		wear(model, "Head", "Máscara", Vector3.new(1.3, 0.46, 0.3), CFrame.new(0, -0.32, -0.55), rgb(24, 24, 28), MAT.Rubber)
		for _, x in { -0.28, 0, 0.28 } do
			wear(model, "Head", "Fenda", Vector3.new(0.08, 0.3, 0.04), CFrame.new(x, -0.32, -0.71), face.mascara, MAT.Neon)
		end
	end
	if face.placa then
		wear(model, "Head", "Placa do queixo", Vector3.new(0.5, 0.5, 1.24), CFrame.new(0.5, -0.3, 0), rgb(190, 194, 204), MAT.Metal)
		wear(model, "Head", "Ótica", Vector3.new(0.16, 0.16, 0.08), CFrame.new(0.3, 0.14, -0.64), rgb(255, 50, 50), MAT.Neon)
	end
	if face.leds then
		for _, y in { -0.05, 0.12 } do
			wear(model, "Head", "LED", Vector3.new(0.06, 0.06, 0.4), CFrame.new(-0.64, y, -0.1), face.leds, MAT.Neon)
		end
	end
	if extras.cabos then
		for _, x in { -0.3, 0.3 } do
			wear(model, "Head", "Cabo", Vector3.new(0.12, 0.12, 0.9), CFrame.new(x, -0.4, 0.6) * CFrame.Angles(0.9, 0, 0), rgb(30, 30, 36), MAT.Rubber)
		end
	end
	return model
end

-- override (fixers): estilo, cabelo, cor do cabelo, visor, leds, lente, placa.
local function buildPedestrian(seed: number, kind: string, gangKey: string?, override): (Model, any)
	local spec = outfit(seed, kind, gangKey, override and override.estilo)
	if override then
		spec.hair.style = override.cabelo or spec.hair.style
		spec.hair.color = override.cor or spec.hair.color
		spec.face.visor = override.visor or spec.face.visor
		spec.face.leds = override.leds or spec.face.leds
		if override.lente then
			spec.face.oculos, spec.face.lente = true, override.lente
		end
		if override.placa then
			spec.face.placa = true
		end
	end
	local model = rig("Pedestre", spec.skin, spec.shirt, spec.pants, spec.sleeve)
	dress(model, spec)
	model:SetAttribute("CyberOutlawTipo", kind)
	model:SetAttribute("CyberOutlawEstilo", spec.style)
	if gangKey then
		model:SetAttribute("CyberOutlawGangue", gangKey)
	end
	return model, spec
end
M.buildPedestrian = buildPedestrian

-- Calçadas: cada quadra tem um anel de caminhada em cada sentido, numa faixa que os testes conferem livre
-- (postes e lixeiras ficam perto do meio-fio, máquinas e carrinhos perto das vitrines). Nas esquinas o
-- pedestre pode atravessar para a quadra vizinha pela linha da faixa de pedestres.
local CURB = 0.85
local LANES = { [1] = 6.0, [-1] = 7.2 }
M.LANES = LANES
local function cityBlocks(layout)
	local lines = layout.lines
	local blocks, list = {}, {}
	for i = 1, #lines - 1 do
		for j = 1, #lines - 1 do
			local a, b, c, e = lines[i], lines[i + 1], lines[j], lines[j + 1]
			local block = { i = i, j = j, x0 = a[1] + a[2] / 2, x1 = b[1] - b[2] / 2, z0 = c[1] + c[2] / 2, z1 = e[1] - e[2] / 2 }
			block.cx, block.cz = (block.x0 + block.x1) / 2, (block.z0 + block.z1) / 2
			block.key = i .. "," .. j
			blocks[block.key] = block
			table.insert(list, block)
		end
	end
	return blocks, list
end
M.cityBlocks = cityBlocks

local function corner(block, index: number, dir: number): Vector3
	local inset = LANES[dir] or LANES[1]
	if index == 1 then
		return Vector3.new(block.x0 + inset, CURB, block.z0 + inset)
	elseif index == 2 then
		return Vector3.new(block.x1 - inset, CURB, block.z0 + inset)
	elseif index == 3 then
		return Vector3.new(block.x1 - inset, CURB, block.z1 - inset)
	end
	return Vector3.new(block.x0 + inset, CURB, block.z1 - inset)
end
M.corner = corner

-- Travessias de cada canto: { di, dj, canto de chegada } (a rua fica entre as duas quadras).
local CROSSINGS = {
	[1] = { { -1, 0, 2 }, { 0, -1, 4 } },
	[2] = { { 1, 0, 1 }, { 0, -1, 3 } },
	[3] = { { 1, 0, 4 }, { 0, 1, 2 } },
	[4] = { { -1, 0, 3 }, { 0, 1, 1 } },
}
M.CROSSINGS = CROSSINGS
local function nextCorner(index: number, dir: number): number
	return (index - 1 + dir) % 4 + 1
end
M.nextCorner = nextCorner

-- Ponto no anel: lado (1..4, do canto k ao k+1 no sentido +1) e fração t. Para sorteio de nascimento.
local function ringPoint(block, side: number, t: number, dir: number): Vector3
	local a = corner(block, side, dir)
	local b = corner(block, nextCorner(side, 1), dir)
	return a:Lerp(b, t)
end
M.ringPoint = ringPoint

-- Caixas (centro, tamanho) que um pedestre ocupa ao andar um lado do anel ou ao atravessar a rua.
local function corridor(a: Vector3, b: Vector3, width: number): (CFrame, Vector3)
	local mid = (a + b) / 2
	local delta = b - a
	local size = Vector3.new(math.abs(delta.X) + width, 5.2, math.abs(delta.Z) + width)
	return CFrame.new(mid.X, CURB + 3.2, mid.Z), size
end
M.corridor = corridor

-- Apartamento: área útil em coordenadas do marcador "Unidade" (52 x 42), menos o núcleo do elevador e a
-- chegada, que ficam livres para ninguém prender a saída.
local UNIT = { half = Vector2.new(26, 21), keepOut = { 12, 26, 8, 21 }, maxItems = 60, maxOwned = 140, grid = 0.5 }
M.UNIT = UNIT

local function footprint(size: Vector3, rot: number): (number, number)
	if rot % 2 == 1 then
		return size.Z / 2, size.X / 2
	end
	return size.X / 2, size.Z / 2
end
M.footprint = footprint

-- placed: lista de { u, id, x, z, r } já no apartamento. sizes[id] = Vector3. Devolve ok e o motivo.
local function canPlace(sizes, placed, id: string, x: number, z: number, rot: number, ignore: number?): (boolean, string?)
	local def = FURNITURE_BY_ID[id]
	local size = sizes[id]
	if not def or not size then
		return false, "Móvel desconhecido."
	end
	if rot ~= math.floor(rot) or rot < 0 or rot > 3 then
		return false, "Rotação inválida."
	end
	if x ~= x or z ~= z or math.abs(x) > 100 or math.abs(z) > 100 then
		return false, "Posição inválida."
	end
	local hx, hz = footprint(size, rot)
	if math.abs(x) + hx > UNIT.half.X + 0.01 or math.abs(z) + hz > UNIT.half.Y + 0.01 then
		return false, "Fora do apartamento."
	end
	local k = UNIT.keepOut
	if x + hx > k[1] and x - hx < k[2] and z + hz > k[3] and z - hz < k[4] then
		return false, "Deixe livre a saída do elevador."
	end
	local count = 0
	for _, item in placed do
		if item.u ~= ignore then
			count += 1
			local other = FURNITURE_BY_ID[item.id]
			local otherSize = sizes[item.id]
			if other and otherSize and not def.chao and not other.chao then
				local ox, oz = footprint(otherSize, item.r)
				if math.abs(item.x - x) < hx + ox - 0.1 and math.abs(item.z - z) < hz + oz - 0.1 then
					return false, "Encostado em outro móvel."
				end
			end
		end
	end
	if count >= UNIT.maxItems then
		return false, "Apartamento cheio (máximo de " .. UNIT.maxItems .. " móveis)."
	end
	return true, nil
end
M.canPlace = canPlace

-- Sujeira inicial: cada monte some com "Limpar" (só o dono). pos em coordenadas da unidade.
local TRASH = {
	{ id = "sacos", nome = "Sacos de lixo", pos = { -18, -14 }, solido = true },
	{ id = "pizza", nome = "Caixas de pizza", pos = { -6, -16 } },
	{ id = "latas", nome = "Latas e garrafas", pos = { 6, -12 } },
	{ id = "colchao_rasgado", nome = "Colchão rasgado", pos = { -19, 7 }, solido = true },
	{ id = "cadeira_quebrada", nome = "Cadeira quebrada", pos = { -4, 8 } },
	{ id = "tapume", nome = "Janela com tapume pichado", pos = { -25, -4 } },
	{ id = "manchas", nome = "Manchas no chão", pos = { 9, 2 } },
	{ id = "roupas", nome = "Roupa suja", pos = { 2, -4 } },
	{ id = "entulho", nome = "Entulho", pos = { -10, -2 }, solido = true },
	{ id = "lampada", nome = "Lâmpada queimada", pos = { -10, 14 } },
	{ id = "pichacao", nome = "Pichação no elevador", pos = { 11, 17 } },
	{ id = "geladeira_podre", nome = "Geladeira podre", pos = { 4, 18 }, solido = true },
}
M.TRASH = TRASH

local DIRT = rgb(70, 62, 52)
local function buildTrash(def): Model
	local m = Instance.new("Model")
	m.Name = "Sujeira " .. def.id
	local id = def.id
	if id == "sacos" then
		for index, spot in { { 0, 0.9, 0, 2 }, { 1.6, 0.8, 0.6, 1.7 }, { -1.3, 0.7, 0.9, 1.5 }, { 0.4, 0.6, -1.4, 1.3 }, { 0.6, 2.1, 0.3, 1.2 } } do
			local bag = ball(m, "Saco", spot[4], spot[1], spot[2], spot[3], if index % 2 == 0 then rgb(28, 28, 30) else rgb(40, 40, 44), MAT.Plastic)
			bag.Size = Vector3.new(spot[4], spot[4] * 1.15, spot[4])
			bag.Reflectance = 0.08
		end
	elseif id == "pizza" then
		for index = 1, 6 do
			part(m, "Caixa de pizza", Vector3.new(2, 0.2, 2), CFrame.new(math.sin(index) * 0.3, 0.1 + index * 0.21, math.cos(index * 2) * 0.3) * CFrame.Angles(0, index * 0.5, 0),
				rgb(170, 130, 86), MAT.Cardboard)
		end
		part(m, "Caixa aberta", Vector3.new(2, 0.1, 2), CFrame.new(2.4, 0.05, 0.6) * CFrame.Angles(0, 0.4, 0), rgb(170, 130, 86), MAT.Cardboard)
		part(m, "Fatia velha", Vector3.new(0.9, 0.06, 0.6), CFrame.new(2.3, 0.14, 0.5) * CFrame.Angles(0, 1, 0), rgb(200, 150, 60), MAT.SmoothPlastic)
	elseif id == "latas" then
		local r = rand(77)
		for index = 1, 14 do
			local can = part(m, if index % 3 == 0 then "Garrafa" else "Lata", Vector3.new(0.6, 0.34, 0.34),
				CFrame.new(r.range(-2.4, 2.4), 0.17, r.range(-2, 2)) * CFrame.Angles(0, r.range(0, 6.3), 0),
				if index % 3 == 0 then rgb(40, 120, 60) else r.pick({ rgb(200, 30, 40), rgb(60, 200, 255), rgb(190, 190, 196) }),
				if index % 3 == 0 then MAT.Glass else MAT.Metal, Enum.PartType.Cylinder)
			can.Transparency = if index % 3 == 0 then 0.3 else 0
		end
	elseif id == "colchao_rasgado" then
		part(m, "Colchão", Vector3.new(4.2, 0.8, 7.2), CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0.2, 0.04), rgb(150, 138, 110), MAT.Fabric)
		for _, spot in { { -0.8, 1.4, 1.2 }, { 1, -1.6, 0.9 }, { 0.2, 0.2, 1.4 } } do
			part(m, "Mancha", Vector3.new(0.03, spot[3], spot[3]), CFrame.new(spot[1], 0.82, spot[2]) * CFrame.Angles(0, 0, math.pi / 2), rgb(96, 80, 50), MAT.Fabric,
				Enum.PartType.Cylinder)
		end
		part(m, "Mola", Vector3.new(0.1, 0.9, 0.1), CFrame.new(1.2, 1, -2) * CFrame.Angles(0.3, 0, 0.4), rgb(150, 150, 156), MAT.Metal)
	elseif id == "cadeira_quebrada" then
		local cf = CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0.7, math.pi / 2.2)
		part(m, "Assento", Vector3.new(2, 0.25, 2), cf, rgb(90, 70, 50), MAT.Wood)
		part(m, "Encosto", Vector3.new(2, 2, 0.25), cf * CFrame.new(0, 1.1, 0.9), rgb(90, 70, 50), MAT.Wood)
		part(m, "Perna", Vector3.new(0.2, 1.6, 0.2), cf * CFrame.new(0.8, -0.9, -0.8), rgb(80, 60, 44), MAT.Wood)
		part(m, "Perna quebrada", Vector3.new(0.2, 0.9, 0.2), CFrame.new(1.6, 0.1, 1.2) * CFrame.Angles(0, 0.4, math.pi / 2), rgb(80, 60, 44), MAT.Wood)
	elseif id == "tapume" then
		local board = part(m, "Tapume", Vector3.new(0.3, 7, 7), CFrame.new(-0.6, 3.6, 0) * CFrame.Angles(0, 0, -0.08), rgb(150, 116, 74), MAT.WoodPlanks)
		screen(board, Enum.NormalId.Right, "SAI DAQUI\nCROMO 4EVER", Enum.Font.PermanentMarker, PINK, nil, false)
		part(m, "Vidro quebrado", Vector3.new(0.1, 1.2, 1.6), CFrame.new(0.6, 0.1, 1.6) * CFrame.Angles(0, 0.6, math.pi / 2), rgb(170, 200, 220), MAT.Glass).Transparency = 0.4
		part(m, "Vidro quebrado", Vector3.new(0.1, 0.8, 1.1), CFrame.new(1.2, 0.08, -1.4) * CFrame.Angles(0, -0.3, math.pi / 2), rgb(170, 200, 220), MAT.Glass).Transparency = 0.4
	elseif id == "manchas" then
		local r = rand(91)
		for _ = 1, 6 do
			local size = r.range(1.2, 3.2)
			part(m, "Mancha", Vector3.new(0.04, size, size * r.range(0.6, 1)), CFrame.new(r.range(-3, 3), 0.02, r.range(-3, 3)) * CFrame.Angles(0, r.range(0, 3), math.pi / 2),
				r.pick({ rgb(52, 44, 34), rgb(70, 58, 40), rgb(40, 50, 36) }), MAT.SmoothPlastic, Enum.PartType.Cylinder)
		end
	elseif id == "roupas" then
		for index, color in { rgb(60, 80, 120), rgb(140, 40, 50), rgb(200, 200, 190), rgb(50, 50, 56) } do
			part(m, "Roupa", Vector3.new(1.8, 0.3, 1.4), CFrame.new(index * 0.35 - 0.8, 0.15 + index * 0.18, (index % 2) * 0.4) * CFrame.Angles(0.1, index, 0.05), color,
				MAT.Fabric)
		end
		part(m, "Meia", Vector3.new(0.4, 0.15, 1), CFrame.new(1.8, 0.08, -0.6) * CFrame.Angles(0, 0.8, 0), rgb(230, 230, 220), MAT.Fabric)
	elseif id == "entulho" then
		local r = rand(55)
		for _ = 1, 8 do
			local size = r.range(0.6, 1.6)
			part(m, "Pedaço de concreto", Vector3.new(size, size * 0.7, size * 0.9), CFrame.new(r.range(-1.6, 1.6), size * 0.35, r.range(-1.6, 1.6)) * CFrame.Angles(r.range(-0.3, 0.3), r.range(0, 3), 0),
				rgb(120, 118, 112), MAT.Concrete)
		end
		part(m, "Vergalhão", Vector3.new(0.12, 0.12, 3.4), CFrame.new(0.4, 0.6, 0.2) * CFrame.Angles(0.3, 0.6, 0), rgb(110, 70, 50), MAT.CorrodedMetal)
	elseif id == "lampada" then
		part(m, "Escada", Vector3.new(1.8, 6, 0.3), CFrame.new(0, 3, 0) * CFrame.Angles(0.25, 0, 0), rgb(200, 170, 60), MAT.Metal)
		part(m, "Lâmpada queimada", Vector3.new(4, 0.25, 0.25), CFrame.new(1.8, 0.13, 1.2) * CFrame.Angles(0, 0.4, 0), rgb(220, 220, 214), MAT.Glass)
	elseif id == "pichacao" then
		local wall = part(m, "Pichação", Vector3.new(0.1, 6, 7), CFrame.new(4.9, 4, 2.8), Color3.new(1, 1, 1), MAT.SmoothPlastic)
		wall.Transparency = 1
		wall.CanCollide = false
		screen(wall, Enum.NormalId.Left, "PAGA O\nALUGUEL!!", Enum.Font.PermanentMarker, LIME, nil, false)
	elseif id == "geladeira_podre" then
		part(m, "Geladeira", Vector3.new(3.2, 6.4, 2.8), CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0.15, 0.03), rgb(150, 140, 110), MAT.CorrodedMetal)
		part(m, "Porta aberta", Vector3.new(3, 3.4, 0.2), CFrame.new(-1.9, 4.6, -2.2) * CFrame.Angles(0, -1.1, 0), rgb(160, 150, 120), MAT.CorrodedMetal)
		local flies = Instance.new("ParticleEmitter")
		flies.Name = "Moscas"
		flies.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		flies.Color = ColorSequence.new(rgb(20, 20, 20))
		flies.Size = NumberSequence.new(0.12)
		flies.Rate = 8
		flies.Speed = NumberRange.new(0.5, 1.2)
		flies.Lifetime = NumberRange.new(1.5, 2.5)
		flies.SpreadAngle = Vector2.new(180, 180)
		flies.RotSpeed = NumberRange.new(-200, 200)
		flies.Parent = m:FindFirstChild("Geladeira")
	end
	for _, item in m:GetDescendants() do
		if item:IsA("BasePart") then
			item.CanCollide = def.solido == true and item.Name ~= "Mancha"
			item.CastShadow = item.Size.Magnitude > 2
		end
	end
	local center = part(m, "Alvo da limpeza", Vector3.new(1, 1, 1), CFrame.new(0, 1.5, 0), DIRT, MAT.SmoothPlastic)
	center.Transparency, center.CanCollide, center.CanQuery, center.CanTouch = 1, false, false, false
	m.PrimaryPart = center
	return m
end
M.buildTrash = buildTrash

-- Fixers (contatos de trabalho) e as falas da holochamada ------------------------------------------------------
local FIXERS = {
	{
		id = "cidinha", nome = "Dona Cidinha", titulo = "Fixer do Mercado", cor = { 255, 150, 72 }, semente = 7101,
		visual = { estilo = "idoso", cabelo = "coque", cor = rgb(170, 120, 200), lente = GOLD },
		oi = "Oi, {apelido}. Aqui é a Cidinha, do Mercado.",
		tchau = "Vai com Deus e volta inteiro, viu?",
	},
	{
		id = "jet", nome = "Jet Moraes", titulo = "Fixer corporativo", cor = { 72, 226, 210 }, semente = 7202,
		visual = { estilo = "corpo", cabelo = "penteado", cor = rgb(28, 22, 18), visor = CYAN },
		oi = "{apelido}. Jet Moraes. Serei breve, meu tempo é caro.",
		tchau = "Não me decepcione.",
	},
	{
		id = "padre", nome = "Padre Néon", titulo = "Fixer da Colmeia", cor = { 255, 72, 140 }, semente = 7303,
		visual = { estilo = "contato", cabelo = "careca", cor = rgb(255, 72, 140), leds = PINK },
		oi = "Que o néon te ilumine, {apelido}. Tenho uma missão pra sua alma.",
		tchau = "Vai em paz. E leva munição.",
	},
	{
		id = "rato", nome = "Rato Kowalski", titulo = "Atravessador das Docas", cor = { 160, 140, 255 }, semente = 7404,
		visual = { estilo = "trabalhador", cabelo = "bone", cor = rgb(40, 40, 46), placa = true },
		oi = "E aí, parceiro. Rato na linha. Coisa rápida, coisa boa.",
		tchau = "Fui. Não fala que me conhece.",
	},
}
local FIXER_BY_ID = {}
for _, fixer in FIXERS do
	FIXER_BY_ID[fixer.id] = fixer
end
M.FIXERS = FIXERS
M.FIXER_BY_ID = FIXER_BY_ID

local MISSION_TEXT = {
	alvo = {
		titulo = "Eliminar alvo",
		falas = {
			"Um tal de {alvo}, da {gangue}, anda cobrando pedágio no {bairro}.",
			"Tem dois capangas com ele. Some com o {alvo} e eu te pago €$ {valor}.",
			"Você tem {minutos} minutos antes dele trocar de esconderijo.",
		},
		objetivo = "Elimine {alvo} ({gangue})",
	},
	limpeza = {
		titulo = "Limpar o quarteirão",
		falas = {
			"A {gangue} tomou uma esquina no {bairro}. Ninguém passa mais lá.",
			"São {qtd} deles, armados até os dentes.",
			"Limpa a área e são €$ {valor} pra você. Prazo de {minutos} minutos.",
		},
		objetivo = "Derrube os {qtd} da {gangue}",
	},
	entrega = {
		titulo = "Entrega urgente",
		falas = {
			"Preciso de um entregador. Pacote quente, sem perguntas.",
			"Pega com o meu contato no {bairro} e leva até o destino que eu marcar.",
			"Você tem {minutos} minutos. Na entrega, €$ {valor}.",
		},
		objetivo = "Pegue o pacote com o contato",
		objetivo2 = "Entregue o pacote no destino",
	},
	roubo = {
		titulo = "Caixa eletrônico cheio",
		falas = {
			"Tem um caixa eletrônico no {bairro} transbordando de eurodólar.",
			"Hackeia ele, fica com o que tiver dentro, e eu ainda te dou €$ {valor} pela dica.",
			"Só cuidado: o alarme chama a PMMB. {minutos} minutos.",
		},
		objetivo = "Hackeie o caixa eletrônico marcado",
	},
}
M.MISSION_TEXT = MISSION_TEXT
local MISSION_KINDS = { "alvo", "limpeza", "entrega", "roubo" }
M.MISSION_KINDS = MISSION_KINDS
local FIRST_NAMES = { "Kaio", "Duda", "Bruno", "Jéssica", "Tavinho", "Marrento", "Lia", "Grilo", "Neca", "Zeca", "Pâmela", "Toninho" }
local NICKNAMES = { "Sucata", "Navalha", "Faísca", "Dente de Aço", "Curto-Circuito", "Ferrugem", "Cromo", "Vidro", "Zumbi", "Bala" }

local function fill(text: string, vars): string
	return (string.gsub(text, "{(%w+)}", function(key)
		local value = vars[key]
		return if value ~= nil then tostring(value) else "{" .. key .. "}"
	end))
end
M.fill = fill

-- Monta uma oferta de trabalho. ctx: { origin = Vector3, blocks = lista, districtAt = fn(x, z) -> {name}, atms = { Vector3 },
-- blocked = fn(block) -> bool, apelido = string }. Pura: o sorteio vem da semente.
local function missionOffer(seed: number, fixerId: string, kind: string?, ctx)
	local r = rand(seed)
	local fixer = FIXER_BY_ID[fixerId] or FIXERS[1]
	kind = kind or r.pick(MISSION_KINDS)
	if kind == "roubo" and #(ctx.atms or {}) == 0 then
		kind = "alvo"
	end
	local origin = ctx.origin or Vector3.zero
	local options = {}
	for _, block in ctx.blocks do
		local distance = (Vector3.new(block.cx, 0, block.cz) - Vector3.new(origin.X, 0, origin.Z)).Magnitude
		local safe = (Vector3.new(block.cx, 0, block.cz) - Vector3.new(108, 0, 108)).Magnitude < 150
		if distance >= 230 and distance <= 720 and not safe and not (ctx.blocked and ctx.blocked(block)) then
			table.insert(options, block)
		end
	end
	if #options == 0 then
		options = ctx.blocks
	end
	local block = r.pick(options)
	local cornerIndex = r.int(1, 4)
	local target = corner(block, cornerIndex, 1)
	local gangKey = r.pick(GANG_ORDER)
	local offer = {
		id = string.format("%s-%d", fixer.id, seed % 1000000), fixer = fixer.id, kind = kind, semente = seed,
		gangue = gangKey, bloco = block.key, canto = cornerIndex, alvo = target,
	}
	local district = if ctx.districtAt then ctx.districtAt(target.X, target.Z) else nil
	local vars = {
		apelido = ctx.apelido or "mercenário", gangue = GANGS[gangKey].nome, bairro = if district then district.name else "centro",
		alvo = r.pick(FIRST_NAMES) .. " \"" .. r.pick(NICKNAMES) .. "\"",
	}
	if kind == "alvo" then
		offer.valor = 100 * r.int(9, 15)
		offer.prazo = 360
	elseif kind == "limpeza" then
		offer.qtd = r.int(4, 6)
		vars.qtd = offer.qtd
		offer.valor = 100 * r.int(11, 18)
		offer.prazo = 420
	elseif kind == "entrega" then
		local far = {}
		for _, other in ctx.blocks do
			local d = (Vector3.new(other.cx, 0, other.cz) - Vector3.new(block.cx, 0, block.cz)).Magnitude
			if d >= 300 and d <= 800 and not (ctx.blocked and ctx.blocked(other)) then
				table.insert(far, other)
			end
		end
		local destination = if #far > 0 then r.pick(far) else block
		offer.destino = corner(destination, r.int(1, 4), 1)
		offer.blocoDestino = destination.key
		local trip = (offer.destino - target).Magnitude + (target - origin).Magnitude
		offer.prazo = math.clamp(math.floor(trip / 13 + 90), 150, 420)
		offer.valor = 50 * r.int(9, 15)
	elseif kind == "roubo" then
		local nearest, best = nil, math.huge
		for _, atm in ctx.atms do
			local d = math.abs((atm - origin).Magnitude - 420)
			if d < best and (atm - Vector3.new(108, 0, 108)).Magnitude > 150 then
				nearest, best = atm, d
			end
		end
		offer.alvo = nearest or ctx.atms[1]
		offer.valor = 100 * r.int(3, 5)
		offer.prazo = 300
		if ctx.districtAt then
			local spot = ctx.districtAt(offer.alvo.X, offer.alvo.Z)
			vars.bairro = if spot then spot.name else vars.bairro
		end
	end
	vars.valor = offer.valor
	vars.minutos = math.floor(offer.prazo / 60 + 0.5)
	offer.nomeAlvo = vars.alvo
	local text = MISSION_TEXT[kind]
	offer.titulo = text.titulo
	offer.objetivo = fill(text.objetivo, vars)
	if text.objetivo2 then
		offer.objetivo2 = fill(text.objetivo2, vars)
	end
	offer.falas = { fill(fixer.oi, vars) }
	for _, line in text.falas do
		table.insert(offer.falas, fill(line, vars))
	end
	offer.tchau = fill(fixer.tchau, vars)
	offer.bairro = vars.bairro
	return offer
end
M.missionOffer = missionOffer

-- Procurado: estrelas de 0 a 5; cada crime soma; sem polícia por perto o nível cai uma estrela a cada `decay` s.
local WANTED = {
	max = 5, decay = 22, seen = 120,
	cops = { 2, 3, 4, 6, 8 },
	crimes = { caixa = 2, maquina = 1, camelo = 2, carteira = 1, civil = 1, policia = 2, tiroPolicia = 1 },
}
M.WANTED = WANTED
local function wantedAfter(level: number, crime: string): number
	return math.clamp(level + (WANTED.crimes[crime] or 0), 0, WANTED.max)
end
M.wantedAfter = wantedAfter

-- Recompensas e preços que o cliente também mostra.
local ECONOMY = {
	start = 600, cleanEach = 12, cleanAll = 100, express = 150, sellBack = 0.5,
	loot = { caixa = { 180, 420 }, maquina = { 30, 80 }, camelo = { 90, 240 }, carteira = { 12, 55 }, gangue = { 30, 90 }, alvo = { 120, 260 } },
	cooldown = { caixa = 240, maquina = 180, camelo = 300 },
	hospital = 0.1, homeCooldown = 25,
}
M.ECONOMY = ECONOMY

-- Dados salvos: só campos conhecidos e com limites (nada que venha quebrado do DataStore passa).
local function sanitize(raw)
	local data = {
		v = 1, eddies = ECONOMY.start, cred = 0, missoes = 0, assaltos = 0,
		casa = { limpo = {}, piso = "concreto", luz = "fluorescente", vidro = "comum", moveis = {}, guardados = {}, seq = 0 },
	}
	if type(raw) ~= "table" then
		return data
	end
	if type(raw.eddies) == "number" and raw.eddies == raw.eddies then
		data.eddies = math.clamp(math.floor(raw.eddies), 0, 99999999)
	end
	for _, key in { "cred", "missoes", "assaltos" } do
		if type(raw[key]) == "number" and raw[key] == raw[key] then
			data[key] = math.clamp(math.floor(raw[key]), 0, 999999)
		end
	end
	local casa = raw.casa
	if type(casa) == "table" then
		if type(casa.limpo) == "table" then
			for _, def in TRASH do
				if casa.limpo[def.id] == true then
					data.casa.limpo[def.id] = true
				end
			end
		end
		for _, kind in { "piso", "luz", "vidro" } do
			if type(casa[kind]) == "string" and renovation(kind, casa[kind]).id == casa[kind] then
				data.casa[kind] = casa[kind]
			end
		end
		if type(casa.seq) == "number" then
			data.casa.seq = math.clamp(math.floor(casa.seq), 0, 1e9)
		end
		if type(casa.guardados) == "table" then
			for id, count in casa.guardados do
				if FURNITURE_BY_ID[id] and type(count) == "number" and count >= 1 then
					data.casa.guardados[id] = math.min(math.floor(count), UNIT.maxOwned)
				end
			end
		end
		if type(casa.moveis) == "table" then
			for _, item in casa.moveis do
				if type(item) == "table" and FURNITURE_BY_ID[item.id] and type(item.x) == "number" and type(item.z) == "number"
					and type(item.r) == "number" and type(item.u) == "number" and #data.casa.moveis < UNIT.maxItems then
					table.insert(data.casa.moveis, { u = math.floor(item.u), id = item.id, x = item.x, z = item.z, r = math.floor(item.r) % 4 })
					data.casa.seq = math.max(data.casa.seq, math.floor(item.u))
				end
			end
		end
	end
	return data
end
M.sanitize = sanitize

-- Servidor --------------------------------------------------------------------------------------------------
-- Carteira e dados salvos. Se o DataStore falhar (Studio sem acesso às APIs, fila cheia), o jogo continua com
-- os dados da sessão e não grava por cima do que estava salvo.
local function dataSystem(S)
	local store
	pcall(function()
		store = S.DataStoreService:GetDataStore("CyberOutlawVida1")
	end)
	local data = {}
	local api = {}
	local function key(player: Player): string
		return "jogador_" .. tostring(player.UserId)
	end
	function api.publish(player: Player)
		local entry = data[player]
		if entry then
			player:SetAttribute("CyberOutlawEddies", entry.eddies)
			player:SetAttribute("CyberOutlawReputacao", entry.cred)
			player:SetAttribute("CyberOutlawSalvo", entry.canSave == true)
		end
	end
	function api.load(player: Player)
		local entry = sanitize(nil)
		entry.canSave = false
		if store then
			for attempt = 1, 3 do
				local ok, raw = pcall(function()
					return store:GetAsync(key(player))
				end)
				if ok then
					entry = sanitize(raw)
					entry.canSave = true
					break
				end
				task.wait(attempt * 1.5)
			end
		end
		data[player] = entry
		api.publish(player)
		return entry
	end
	function api.get(player: Player)
		return data[player]
	end
	function api.save(player: Player, final: boolean?)
		local entry = data[player]
		if not entry or not entry.canSave or not store or (not entry.dirty and not final) then
			return
		end
		local payload = { v = 1, eddies = entry.eddies, cred = entry.cred, missoes = entry.missoes, assaltos = entry.assaltos, casa = entry.casa }
		local ok = pcall(function()
			store:UpdateAsync(key(player), function()
				return payload
			end)
		end)
		if ok then
			entry.dirty = false
		end
	end
	function api.give(player: Player, amount: number, reason: string?)
		local entry = data[player]
		amount = math.floor(amount)
		if not entry or amount == 0 then
			return
		end
		entry.eddies = math.clamp(entry.eddies + amount, 0, 99999999)
		entry.dirty = true
		api.publish(player)
		S.notify(player, "dinheiro", amount, reason)
	end
	function api.take(player: Player, amount: number, reason: string?): boolean
		local entry = data[player]
		amount = math.floor(amount)
		if not entry or amount < 0 or entry.eddies < amount then
			return false
		end
		if amount > 0 then
			entry.eddies -= amount
			entry.dirty = true
			api.publish(player)
			S.notify(player, "dinheiro", -amount, reason)
		end
		return true
	end
	function api.touch(player: Player)
		local entry = data[player]
		if entry then
			entry.dirty = true
		end
	end
	function api.drop(player: Player)
		api.save(player, true)
		data[player] = nil
	end
	task.spawn(function()
		while true do
			task.wait(75)
			for player in data do
				task.spawn(api.save, player, false)
			end
		end
	end)
	game:BindToClose(function()
		for player in data do
			task.spawn(api.save, player, true)
		end
		task.wait(4)
	end)
	return api
end

-- Apartamentos do Edifício Colmeia: um por jogador, montado a partir dos marcadores "Unidade" da cidade.
local function homeSystem(S)
	local api = {}
	local units = {}
	local owners: { [Player]: any } = {}
	local folder = Instance.new("Folder")
	folder.Name = "CyberOutlawCasas"
	folder.Parent = workspace
	local lobby: Vector3? = nil
	local lastHome = {}
	local building = S.city:FindFirstChild("Edifício Colmeia", true)
	if building then
		local strips, panes, doors = {}, {}, {}
		for _, item in building:GetDescendants() do
			if item:IsA("BasePart") then
				if item.Name == "Unidade" and type(item:GetAttribute("Unidade")) == "number" then
					local n = item:GetAttribute("Unidade")
					units[n] = {
						n = n, marker = item, cf = item.CFrame, size = item.Size, floorY = item.Position.Y - item.Size.Y / 2,
						arrival = item:GetAttribute("Chegada"), windows = {}, models = {}, piles = {},
					}
				elseif item.Name == "Luz do apartamento" then
					table.insert(strips, item)
				elseif item.Name == "Janela" then
					table.insert(panes, item)
				elseif item.Name == "Porta do elevador" and type(item:GetAttribute("Unidade")) == "number" then
					doors[item:GetAttribute("Unidade")] = item
				elseif item.Name == "Painel do elevador" and item:GetAttribute("CyberOutlawElevador") == "saguao" then
					lobby = item.Position + Vector3.new(0, -1, -5)
					local prompt = Instance.new("ProximityPrompt")
					prompt.Name = "Elevador"
					prompt.ActionText = "Subir"
					prompt.ObjectText = "Elevador · meu apartamento"
					prompt.HoldDuration = 0.4
					prompt.MaxActivationDistance = 10
					prompt.RequiresLineOfSight = false
					prompt.Parent = item
					prompt.Triggered:Connect(function(player)
						api.goHome(player, true)
					end)
				end
			end
		end
		for _, unit in units do
			for _, strip in strips do
				if strip.Position.Y > unit.floorY and strip.Position.Y < unit.floorY + 13.6 then
					unit.light = strip
				end
			end
			for _, pane in panes do
				if math.abs(pane.Position.Y - (unit.floorY + 6.7)) < 1.2 then
					table.insert(unit.windows, pane)
				end
			end
			unit.door = doors[unit.n]
			if unit.door then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "Elevador"
				prompt.ActionText = "Descer"
				prompt.ObjectText = "Elevador · saguão"
				prompt.HoldDuration = 0.4
				prompt.MaxActivationDistance = 10
				prompt.RequiresLineOfSight = false
				prompt.Parent = unit.door
				prompt.Triggered:Connect(function(player)
					local character = player.Character
					if character and lobby then
						character:PivotTo(CFrame.lookAt(lobby + Vector3.new(0, 3, 0), lobby + Vector3.new(0, 3, -1)))
					end
				end)
			end
		end
	end
	S.units = units

	-- Coordenadas da unidade -> mundo, no piso.
	local function floorAt(unit, x: number, z: number, rot: number?): CFrame
		return unit.cf * CFrame.new(x, -unit.size.Y / 2 + 0.1, z) * CFrame.Angles(0, (rot or 0) * math.pi / 2, 0)
	end
	api.floorAt = floorAt

	local function color(list)
		return Color3.fromRGB(list[1], list[2], list[3])
	end

	-- Aplica piso, vidro e luz da reforma (e a sujeira que ainda não foi limpa).
	local function decorate(unit, data)
		local casa = data.casa
		local floor = unit.floor
		if not floor then
			floor = part(unit.content, "Piso", Vector3.new(unit.size.X, 0.1, unit.size.Z), unit.cf * CFrame.new(0, -unit.size.Y / 2 + 0.05, 0), Color3.new(1, 1, 1))
			unit.floor = floor
		end
		local option = renovation("piso", casa.piso)
		local dirty = not casa.limpo.manchas
		floor.Color = if dirty and option.id == "concreto" then color(option.cor):Lerp(rgb(70, 60, 46), 0.45) else color(option.cor)
		floor.Material = (MAT :: any)[option.mat] or MAT.Concrete
		floor.Reflectance = option.brilho or 0
		for _, edge in unit.floorNeon or {} do
			edge:Destroy()
		end
		unit.floorNeon = {}
		if option.neon then
			local tone = color(option.neon)
			local hx, hz = unit.size.X / 2 - 0.2, unit.size.Z / 2 - 0.2
			for _, spec in { { 0, -hz, unit.size.X - 0.4, 0.2 }, { 0, hz, unit.size.X - 0.4, 0.2 }, { -hx, 0, 0.2, unit.size.Z - 0.4 }, { hx, 0, 0.2, unit.size.Z - 0.4 } } do
				local edge = part(unit.content, "Faixa do piso", Vector3.new(spec[3], 0.04, spec[4]), unit.cf * CFrame.new(spec[1], -unit.size.Y / 2 + 0.12, spec[2]), tone, MAT.Neon)
				edge.CanCollide = false
				edge.CastShadow = false
				table.insert(unit.floorNeon, edge)
			end
		end
		local glass = renovation("vidro", casa.vidro)
		for _, pane in unit.windows do
			if not unit.paneDefault then
				unit.paneDefault = { pane.Color, pane.Transparency }
			end
			local dirtyGlass = not casa.limpo.tapume
			pane.Color = if dirtyGlass then color(glass.cor):Lerp(rgb(120, 104, 70), 0.5) else color(glass.cor)
			pane.Transparency = if dirtyGlass then 0.35 else glass.transparencia
		end
		if unit.light then
			local tone = color(renovation("luz", casa.luz).cor)
			local broken = not casa.limpo.lampada
			unit.light.Color = if broken then rgb(90, 90, 84) else tone
			local surface = unit.light:FindFirstChildWhichIsA("Light")
			if surface then
				surface.Color = tone
				surface.Brightness = if broken then 0.12 else 0.9
			end
		end
	end

	local function spawnItem(unit, item)
		local template = S.furniture[item.id]
		if not template then
			return
		end
		local model = template:Clone()
		model:SetAttribute("Uid", item.u)
		model:SetAttribute("Dono", unit.owner and unit.owner.UserId or 0)
		model:PivotTo(floorAt(unit, item.x, item.z, item.r))
		model.Parent = unit.content
		unit.models[item.u] = model
	end

	local function pileCleaned(unit, def, player: Player)
		local data = S.data.get(player)
		if not data or data.casa.limpo[def.id] or unit.owner ~= player then
			return
		end
		data.casa.limpo[def.id] = true
		S.data.touch(player)
		local pile = unit.piles[def.id]
		if pile then
			pile:Destroy()
			unit.piles[def.id] = nil
		end
		decorate(unit, data)
		S.data.give(player, ECONOMY.cleanEach, "Recicláveis: " .. def.nome)
		local left = 0
		for _, other in TRASH do
			if not data.casa.limpo[other.id] then
				left += 1
			end
		end
		if left == 0 then
			S.data.give(player, ECONOMY.cleanAll, "Apartamento limpo!")
		end
		api.send(player)
	end

	local function spawnPiles(unit, data)
		for _, def in TRASH do
			if not data.casa.limpo[def.id] and not unit.piles[def.id] then
				local pile = buildTrash(def)
				pile:PivotTo(floorAt(unit, def.pos[1], def.pos[2], 0) * CFrame.new(0, 1.4, 0))
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "Limpar"
				prompt.ActionText = if def.id == "lampada" then "Trocar" elseif def.id == "tapume" then "Consertar" else "Limpar"
				prompt.ObjectText = def.nome
				prompt.HoldDuration = 1.2
				prompt.MaxActivationDistance = 10
				prompt.RequiresLineOfSight = false
				prompt.Parent = pile.PrimaryPart
				prompt.Triggered:Connect(function(player)
					pileCleaned(unit, def, player)
				end)
				pile.Parent = unit.content
				unit.piles[def.id] = pile
			end
		end
	end

	local function nameplate(unit, player: Player?)
		if not unit.door then
			return
		end
		local old = unit.door:FindFirstChild("Tela")
		if old then
			old:Destroy()
		end
		if player then
			local label = screen(unit.door, Enum.NormalId.Front, string.format("APTO %02d\n%s", unit.n, player.DisplayName), Enum.Font.Michroma, CYAN, rgb(10, 12, 20))
			label.TextStrokeTransparency = 0.8
		end
	end

	function api.claim(player: Player)
		if owners[player] then
			return owners[player]
		end
		local data = S.data.get(player)
		for n = 1, 12 do
			local unit = units[n]
			if unit and not unit.owner then
				unit.owner = player
				owners[player] = unit
				unit.content = Instance.new("Folder")
				unit.content.Name = string.format("Apartamento %02d", n)
				unit.content.Parent = folder
				unit.models, unit.piles = {}, {}
				unit.floor = nil
				if data then
					decorate(unit, data)
					spawnPiles(unit, data)
					for _, item in data.casa.moveis do
						spawnItem(unit, item)
					end
				end
				nameplate(unit, player)
				player:SetAttribute("CyberOutlawUnidade", n)
				return unit
			end
		end
		player:SetAttribute("CyberOutlawUnidade", 0)
		return nil
	end

	function api.release(player: Player)
		local unit = owners[player]
		owners[player] = nil
		if not unit then
			return
		end
		unit.owner = nil
		if unit.content then
			unit.content:Destroy()
			unit.content = nil
		end
		unit.floor, unit.models, unit.piles, unit.floorNeon = nil, {}, {}, {}
		if unit.paneDefault then
			for _, pane in unit.windows do
				pane.Color, pane.Transparency = unit.paneDefault[1], unit.paneDefault[2]
			end
		end
		if unit.light then
			unit.light.Color = rgb(255, 236, 210)
		end
		nameplate(unit, nil)
	end

	function api.unitOf(player: Player)
		return owners[player]
	end

	-- Estado completo da casa para o painel do dono.
	function api.send(player: Player)
		local data = S.data.get(player)
		local unit = owners[player]
		if not data then
			return
		end
		local left = {}
		for _, def in TRASH do
			if not data.casa.limpo[def.id] then
				table.insert(left, def.nome)
			end
		end
		S.notify(player, "casa", {
			unidade = if unit then unit.n else 0, moveis = data.casa.moveis, guardados = data.casa.guardados,
			piso = data.casa.piso, luz = data.casa.luz, vidro = data.casa.vidro, sujeira = left,
		})
	end

	local function inside(unit, position: Vector3): boolean
		local here = unit.cf:PointToObjectSpace(position)
		return math.abs(here.X) <= unit.size.X / 2 + 1 and math.abs(here.Z) <= unit.size.Z / 2 + 1 and here.Y > -unit.size.Y / 2 - 1 and here.Y < unit.size.Y / 2 + 2
	end
	api.inside = inside

	function api.goHome(player: Player, fromLobby: boolean?)
		local unit = owners[player]
		local character = player.Character
		if not unit or not unit.arrival or not character then
			S.notify(player, "msg", if unit then "Não deu para subir agora." else "O Colmeia está lotado: sem apartamento livre neste servidor.")
			return
		end
		if not fromLobby then
			local now = os.clock()
			if (player:GetAttribute("CyberOutlawProcurado") or 0) > 0 then
				S.notify(player, "msg", "Com a polícia atrás de você, não dá para ir para casa.")
				return
			end
			if S.inCombat(player) then
				S.notify(player, "msg", "Saia do combate antes de ir para casa.")
				return
			end
			if lastHome[player] and now - lastHome[player] < ECONOMY.homeCooldown then
				S.notify(player, "msg", string.format("Aguarde %d s para ir para casa de novo.", math.ceil(ECONOMY.homeCooldown - (now - lastHome[player]))))
				return
			end
			lastHome[player] = now
		end
		local arrival = unit.arrival + Vector3.new(0, 3.2, 0)
		character:PivotTo(CFrame.lookAt(arrival, arrival + Vector3.new(0, 0, -1)))
	end

	local function sizes()
		return S.furnitureSizes
	end

	-- Pedidos do painel da casa.
	function api.request(player: Player, action: string, a, b, c, d)
		local data = S.data.get(player)
		if not data then
			return
		end
		local casa = data.casa
		local unit = owners[player]
		if action == "comprar" then
			local def = FURNITURE_BY_ID[a]
			if type(a) ~= "string" or not def then
				return
			end
			local owned = #casa.moveis
			for _, count in casa.guardados do
				owned += count
			end
			if owned >= UNIT.maxOwned then
				S.notify(player, "msg", "Você já tem móveis demais.")
				return
			end
			if not S.data.take(player, def.preco, def.nome) then
				S.notify(player, "msg", "€$ insuficientes para " .. def.nome .. ".")
				return
			end
			casa.guardados[def.id] = (casa.guardados[def.id] or 0) + 1
			S.data.touch(player)
			S.notify(player, "comprado", def.id)
			api.send(player)
		elseif action == "colocar" or action == "mover" then
			if not unit then
				S.notify(player, "msg", "Você não tem apartamento neste servidor.")
				return
			end
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if not rootPart or not inside(unit, rootPart.Position) then
				S.notify(player, "msg", "Entre no seu apartamento para arrumar os móveis.")
				return
			end
			if type(b) ~= "number" or type(c) ~= "number" or type(d) ~= "number" then
				return
			end
			local x = math.floor(b / UNIT.grid + 0.5) * UNIT.grid
			local z = math.floor(c / UNIT.grid + 0.5) * UNIT.grid
			local rot = math.floor(d) % 4
			if action == "colocar" then
				local id = a
				if type(id) ~= "string" or (casa.guardados[id] or 0) < 1 then
					return
				end
				local ok, reason = canPlace(sizes(), casa.moveis, id, x, z, rot, nil)
				if not ok then
					S.notify(player, "msg", reason)
					return
				end
				casa.guardados[id] -= 1
				if casa.guardados[id] <= 0 then
					casa.guardados[id] = nil
				end
				casa.seq += 1
				local item = { u = casa.seq, id = id, x = x, z = z, r = rot }
				table.insert(casa.moveis, item)
				spawnItem(unit, item)
			else
				local uid = a
				for _, item in casa.moveis do
					if item.u == uid then
						local ok, reason = canPlace(sizes(), casa.moveis, item.id, x, z, rot, uid)
						if not ok then
							S.notify(player, "msg", reason)
							return
						end
						item.x, item.z, item.r = x, z, rot
						local model = unit.models[uid]
						if model then
							model:PivotTo(floorAt(unit, x, z, rot))
						end
					end
				end
			end
			S.data.touch(player)
			api.send(player)
		elseif action == "guardar" or action == "vender" then
			for index, item in casa.moveis do
				if item.u == a then
					table.remove(casa.moveis, index)
					if unit and unit.models[item.u] then
						unit.models[item.u]:Destroy()
						unit.models[item.u] = nil
					end
					if action == "guardar" then
						casa.guardados[item.id] = (casa.guardados[item.id] or 0) + 1
					else
						S.data.give(player, FURNITURE_BY_ID[item.id].preco * ECONOMY.sellBack, "Venda: " .. FURNITURE_BY_ID[item.id].nome)
					end
					S.data.touch(player)
					break
				end
			end
			api.send(player)
		elseif action == "venderGuardado" then
			if type(a) == "string" and (casa.guardados[a] or 0) > 0 then
				casa.guardados[a] -= 1
				if casa.guardados[a] <= 0 then
					casa.guardados[a] = nil
				end
				S.data.give(player, FURNITURE_BY_ID[a].preco * ECONOMY.sellBack, "Venda: " .. FURNITURE_BY_ID[a].nome)
				S.data.touch(player)
				api.send(player)
			end
		elseif action == "reforma" then
			if type(a) ~= "string" or not RENOVATIONS[a] or type(b) ~= "string" then
				return
			end
			local option = renovation(a, b)
			if option.id ~= b or casa[a] == b then
				return
			end
			if not S.data.take(player, option.preco, option.nome) then
				S.notify(player, "msg", "€$ insuficientes para " .. option.nome .. ".")
				return
			end
			casa[a] = b
			S.data.touch(player)
			if unit then
				decorate(unit, data)
			end
			api.send(player)
		elseif action == "faxina" then
			local any = false
			for _, def in TRASH do
				if not casa.limpo[def.id] then
					any = true
				end
			end
			if not any then
				return
			end
			if not S.data.take(player, ECONOMY.express, "Faxina expressa") then
				S.notify(player, "msg", "€$ insuficientes para a faxina.")
				return
			end
			for _, def in TRASH do
				casa.limpo[def.id] = true
				if unit and unit.piles[def.id] then
					unit.piles[def.id]:Destroy()
					unit.piles[def.id] = nil
				end
			end
			if unit then
				decorate(unit, data)
			end
			S.data.touch(player)
			S.notify(player, "msg", "A equipe de faxina deixou tudo brilhando.")
			api.send(player)
		elseif action == "irCasa" then
			api.goHome(player, false)
		elseif action == "casa" then
			api.send(player)
		end
	end
	return api
end

-- Direção sorteada dentro de um cone (espalhamento dos tiros dos NPCs).
local function cone(direction: Vector3, angle: number, r): Vector3
	local cf = CFrame.lookAt(Vector3.zero, direction)
	return (cf * CFrame.Angles(0, 0, r.range(0, 2 * math.pi)) * CFrame.Angles(r.range(0, angle), 0, 0)).LookVector
end
M.cone = cone

-- Pedestres, gangues, polícia e figurantes das missões.
local function npcSystem(S)
	local api = {}
	local Players = S.Players
	local folder = Instance.new("Folder")
	folder.Name = "CyberOutlawNPCs"
	folder.Parent = workspace
	local list = {}
	local byModel = {}
	api.list = list
	pcall(function()
		S.PhysicsService:RegisterCollisionGroup("CyberOutlawNPC")
		S.PhysicsService:CollisionGroupSetCollidable("CyberOutlawNPC", "CyberOutlawNPC", false)
	end)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { S.city }
	overlap.RespectCanCollide = true
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.IgnoreWater = true
	local random = rand(os.time() % 100000 + 17)
	local counter = 0

	-- Faixas livres: conferidas no mundo de verdade (cache), além do teste da cidade.
	local clearCache = {}
	local function clear(a: Vector3, b: Vector3): boolean
		local key = string.format("%.1f,%.1f,%.1f,%.1f", a.X, a.Z, b.X, b.Z)
		local cached = clearCache[key]
		if cached ~= nil then
			return cached
		end
		local cf, size = corridor(a, b, 2)
		local ok, hits = pcall(function()
			return workspace:GetPartBoundsInBox(cf, size, overlap)
		end)
		local result = ok and #hits == 0
		clearCache[key] = result
		return result
	end
	local function ringClear(block, dir: number): boolean
		for k = 1, 4 do
			if not clear(corner(block, k, dir), corner(block, nextCorner(k, 1), dir)) then
				return false
			end
		end
		return true
	end
	api.ringClear = ringClear

	local function blockAt(position: Vector3)
		local best, bestDistance = nil, math.huge
		for _, block in S.blockList do
			local dx = math.max(block.x0 - position.X, 0, position.X - block.x1)
			local dz = math.max(block.z0 - position.Z, 0, position.Z - block.z1)
			local distance = dx * dx + dz * dz
			if distance < bestDistance then
				best, bestDistance = block, distance
			end
		end
		return best
	end
	api.blockAt = blockAt

	local HEALTH = { civil = 60, gangue = 110, alvo = 280, policia = 140, camelo = 70, contato = 120 }
	local NAMES = { civil = "Pedestre", gangue = "Gangue", alvo = "Alvo", policia = "Policial", camelo = "Camelô", contato = "Contato" }

	local function walkTo(npc, point: Vector3)
		npc.target = point
		npc.humanoid:MoveTo(point)
		npc.lastMove = os.clock()
	end

	-- Volta para a calçada: o canto mais perto da quadra onde está, no sentido que já andava.
	local function relocate(npc)
		local block = blockAt(npc.root.Position)
		npc.block = block
		local best, bestDistance = 1, math.huge
		for k = 1, 4 do
			local distance = (corner(block, k, npc.dir) - npc.root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = k, distance
			end
		end
		npc.corner = best
		walkTo(npc, corner(block, best, npc.dir))
	end

	local function advance(npc)
		local block = npc.block
		if npc.state == "andar" and random.chance(0.32) then
			local option = CROSSINGS[npc.corner][random.int(1, 2)]
			local neighbor = S.blocks[(block.i + option[1]) .. "," .. (block.j + option[2])]
			if neighbor and ringClear(neighbor, npc.dir) and clear(corner(block, npc.corner, npc.dir), corner(neighbor, option[3], npc.dir)) then
				npc.block, npc.corner = neighbor, option[3]
				walkTo(npc, corner(neighbor, option[3], npc.dir))
				return
			end
		end
		npc.corner = nextCorner(npc.corner, npc.dir)
		walkTo(npc, corner(block, npc.corner, npc.dir))
	end

	local function arm(npc, id: string)
		local arsenal = S.ReplicatedStorage:FindFirstChild("CyberOutlawArsenal")
		local models = arsenal and arsenal:FindFirstChild("Modelos")
		local template = models and models:FindFirstChild(id)
		local rightArm = npc.model:FindFirstChild("Right Arm")
		if not template or not template:IsA("Model") or not template.PrimaryPart or not rightArm then
			return
		end
		local weapon = template:Clone()
		weapon.Name = "CyberOutlawArma"
		for _, item in weapon:GetDescendants() do
			if item:IsA("BasePart") then
				item.Anchored = false
				item.Massless = true
				item.CanCollide = false
				item.CanQuery = false
				item.CanTouch = false
				item.CollisionGroup = "CyberOutlawNPC"
			end
		end
		local grip = template:GetAttribute("Pega")
		local weld = Instance.new("Weld")
		weld.Name = "Pega"
		weld.Part0 = rightArm
		weld.Part1 = weapon.PrimaryPart
		weld.C0 = if typeof(grip) == "CFrame" then grip else CFrame.new(0, -1, -0.4) * CFrame.Angles(-math.pi / 2, 0, 0)
		weld.Parent = weapon.PrimaryPart
		weapon.Parent = npc.model
		npc.model:SetAttribute("CyberOutlawArma", id)
		npc.weapon = S.weapons[id]
		local attachment = Instance.new("Attachment")
		attachment.Name = "Mira"
		attachment.Parent = npc.root
		local align = Instance.new("AlignOrientation")
		align.Name = "Mira"
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.MaxTorque = 1e7
		align.Responsiveness = 35
		align.Enabled = false
		align.Parent = npc.root
		npc.align = align
	end

	local function remove(npc)
		if npc.removed then
			return
		end
		npc.removed = true
		byModel[npc.model] = nil
		for index, other in list do
			if other == npc then
				table.remove(list, index)
				break
			end
		end
		npc.model:Destroy()
	end
	api.remove = remove

	local function ragdoll(npc)
		for _, motor in npc.model:GetDescendants() do
			if motor:IsA("Motor6D") and motor.Name ~= "RootJoint" and motor.Part0 and motor.Part1 then
				local a0 = Instance.new("Attachment")
				a0.CFrame = motor.C0
				a0.Parent = motor.Part0
				local a1 = Instance.new("Attachment")
				a1.CFrame = motor.C1
				a1.Parent = motor.Part1
				local socket = Instance.new("BallSocketConstraint")
				socket.Attachment0, socket.Attachment1 = a0, a1
				socket.LimitsEnabled = true
				socket.UpperAngle = if motor.Name == "Neck" then 30 else 75
				socket.Parent = motor.Part0
				motor.Enabled = false
			end
		end
		for _, name in { "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
			local limb = npc.model:FindFirstChild(name)
			if limb and limb:IsA("BasePart") then
				limb.CanCollide = true
			end
		end
	end

	local function calm(npc)
		npc.enemy = nil
		npc.model:SetAttribute("CyberOutlawMirando", false)
		if npc.align then
			npc.align.Enabled = false
		end
		npc.humanoid.AutoRotate = true
		npc.humanoid.WalkSpeed = npc.speed
		if npc.home then
			npc.state = "parado"
			npc.humanoid:MoveTo(npc.home)
		elseif npc.root.Anchored then
			npc.state = "parado"
		else
			npc.state = "andar"
			relocate(npc)
		end
	end
	api.calm = calm

	local function flee(npc, from: Vector3)
		if npc.state == "morto" or npc.root.Anchored or npc.weapon then
			return
		end
		npc.state = "fugir"
		npc.fleeUntil = os.clock() + random.range(8, 13)
		npc.humanoid.WalkSpeed = random.range(19, 23)
		local block = blockAt(npc.root.Position)
		npc.block = block
		local best, bestDistance = 1, -1
		for k = 1, 4 do
			local distance = (corner(block, k, npc.dir) - from).Magnitude
			if distance > bestDistance then
				best, bestDistance = k, distance
			end
		end
		npc.corner = best
		walkTo(npc, corner(block, best, npc.dir))
	end
	api.flee = flee

	local function engage(npc, player: Player)
		if npc.state == "morto" or not npc.weapon then
			return
		end
		npc.enemy = player
		npc.state = "atacar"
		npc.lostAt = nil
		npc.nextShot = math.max(npc.nextShot or 0, os.clock() + random.range(0.4, 0.9))
		npc.humanoid.WalkSpeed = if npc.kind == "policia" then 17 else 15
		npc.model:SetAttribute("CyberOutlawMirando", true)
	end
	api.engage = engage

	local function died(npc)
		if npc.state == "morto" then
			return
		end
		npc.state = "morto"
		npc.model:SetAttribute("CyberOutlawMirando", false)
		npc.model:SetAttribute("CyberOutlawMaosAlto", false)
		if npc.align then
			npc.align.Enabled = false
		end
		if npc.root.Anchored then
			npc.root.Anchored = false
		end
		pcall(ragdoll, npc)
		for _, item in npc.model:GetDescendants() do
			if item:IsA("ProximityPrompt") then
				item.Enabled = false
			end
		end
		local id = npc.model:GetAttribute("CyberOutlawAgressor")
		local killer = if type(id) == "number" then Players:GetPlayerByUserId(id) else nil
		if S.onNpcDied then
			task.spawn(S.onNpcDied, npc, killer)
		end
		task.delay(14, remove, npc)
	end

	local function attacked(npc)
		if npc.state == "morto" then
			return
		end
		local id = npc.model:GetAttribute("CyberOutlawAgressor")
		local player = if type(id) == "number" then Players:GetPlayerByUserId(id) else nil
		if not player then
			return
		end
		if npc.weapon then
			engage(npc, player)
			for _, other in list do
				if other ~= npc and other.weapon and other.state ~= "morto" and other.state ~= "atacar"
					and other.kind ~= "civil" and (other.gang == npc.gang or other.kind == npc.kind)
					and (other.root.Position - npc.root.Position).Magnitude < 36 then
					engage(other, player)
				end
			end
		else
			local character = player.Character
			flee(npc, if character then character:GetPivot().Position else npc.root.Position)
		end
		if S.onNpcAttacked then
			task.spawn(S.onNpcAttacked, npc, player)
		end
	end

	-- opts: gang, weapon, home (fica parado ali), aggro, speed, yaw, anchored, ambient, mission, role, seed, dir, block, corner.
	function api.spawn(kind: string, position: Vector3, opts)
		opts = opts or {}
		counter += 1
		local seed = opts.seed or (os.time() * 31 + counter * 7919) % 2147483000
		local model = buildPedestrian(seed, kind, opts.gang, opts.override)
		model.Name = NAMES[kind] or "Pedestre"
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
		humanoid.MaxHealth = HEALTH[kind] or 80
		humanoid.Health = humanoid.MaxHealth
		local speed = opts.speed or random.range(6.2, 8.4)
		humanoid.WalkSpeed = speed
		for _, state in { Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.GettingUp, Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.Flying,
			Enum.HumanoidStateType.StrafingNoPhysics } do
			pcall(humanoid.SetStateEnabled, humanoid, state, false)
		end
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				item.CollisionGroup = "CyberOutlawNPC"
			end
		end
		model:PivotTo(CFrame.new(position + Vector3.new(0, 3.05, 0)) * CFrame.Angles(0, opts.yaw or random.range(0, 2 * math.pi), 0))
		local npc = {
			model = model, humanoid = humanoid, root = root, kind = kind, gang = opts.gang, speed = speed, state = "andar",
			dir = opts.dir or (if random.chance(0.5) then 1 else -1), lastMove = 0, lastPos = position, lastProgress = os.clock(),
			ambient = opts.ambient == true, mission = opts.mission, role = opts.role, home = opts.home, aggro = opts.aggro,
			born = os.clock(),
		}
		if opts.weapon then
			arm(npc, opts.weapon)
		end
		if opts.anchored then
			root.Anchored = true
			npc.state = "parado"
		elseif opts.home then
			npc.state = "parado"
		end
		model.Parent = folder
		if not root.Anchored then
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
		end
		table.insert(list, npc)
		byModel[model] = npc
		humanoid.Died:Connect(function()
			died(npc)
		end)
		model:GetAttributeChangedSignal("CyberOutlawAgressor"):Connect(function()
			attacked(npc)
		end)
		if npc.state == "andar" then
			if opts.block and opts.corner then
				npc.block, npc.corner = opts.block, opts.corner
				walkTo(npc, corner(opts.block, opts.corner, npc.dir))
			else
				relocate(npc)
			end
		end
		return npc
	end

	function api.of(model: Instance)
		return byModel[model]
	end

	local function sees(npc, target: BasePart): boolean
		local head = npc.model:FindFirstChild("Head")
		if not head then
			return false
		end
		ray.FilterDescendantsInstances = { folder }
		local origin = head.Position
		local result = workspace:Raycast(origin, target.Position - origin, ray)
		return result == nil or result.Instance:IsDescendantOf(target.Parent :: Instance)
	end
	api.sees = sees

	local function characterOf(item: Instance): Model?
		local model = item:FindFirstAncestorOfClass("Model")
		while model do
			if model:FindFirstChildOfClass("Humanoid") then
				return model
			end
			model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
		end
		return nil
	end

	local function fire(npc, character: Model)
		local def = npc.weapon
		local head = npc.model:FindFirstChild("Head") :: BasePart
		local aimRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart
		if not def or not head or not aimRoot then
			return
		end
		local weapon = npc.model:FindFirstChild("CyberOutlawArma")
		local barrel = weapon and weapon:IsA("Model") and weapon.PrimaryPart and weapon.PrimaryPart:FindFirstChild("Cano")
		local from = if barrel and barrel:IsA("Attachment") then barrel.WorldPosition else head.Position
		local aimPart = (random.chance(0.12) and character:FindFirstChild("Head")) or character:FindFirstChild("Torso") or aimRoot
		local distance = (aimPart.Position - from).Magnitude
		local speed = aimRoot.AssemblyLinearVelocity.Magnitude
		local spread = math.rad((def.spread or 1) * 1.4 + 2.2 + distance * 0.025 + speed * 0.12)
		local range = def.range or 200
		ray.FilterDescendantsInstances = { npc.model }
		local hits, damage = {}, 0
		for _ = 1, def.pellets or 1 do
			local direction = cone((aimPart.Position - from).Unit, spread, random)
			local result = workspace:Raycast(from, direction * range, ray)
			local point = if result then result.Position else from + direction * range
			local onTarget = false
			if result and characterOf(result.Instance) == character then
				onTarget = true
				damage += (def.damage or 12) * 0.5 * (if result.Instance.Name == "Head" then 1.5 else 1)
			end
			table.insert(hits, { point, if result then result.Normal else -direction, onTarget })
		end
		if damage > 0 and not S.inSafeZone(aimRoot.Position) then
			S.damagePlayer(character, damage, npc)
		end
		S.shotFx(npc.model, def.id, from, hits)
	end

	local function attackThink(npc, now: number)
		local player = npc.enemy
		local character = player and player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local enemyRoot = character and character:FindFirstChild("HumanoidRootPart")
		if not player or not player.Parent or not humanoid or humanoid.Health <= 0 or not enemyRoot or not enemyRoot:IsA("BasePart") then
			calm(npc)
			return
		end
		if npc.kind == "policia" and not S.isWanted(player) then
			calm(npc)
			npc.leaveAt = now + 3
			return
		end
		local offset = enemyRoot.Position - npc.root.Position
		local distance = offset.Magnitude
		if distance > 200 then
			npc.lostAt = npc.lostAt or now
			if now - npc.lostAt > 8 then
				calm(npc)
				return
			end
		else
			npc.lostAt = nil
		end
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if npc.align and flat.Magnitude > 0.1 then
			npc.humanoid.AutoRotate = false
			npc.align.Enabled = true
			npc.align.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
		end
		local pitch = math.deg(math.asin(math.clamp(offset.Unit.Y, -1, 1)))
		if math.abs((npc.model:GetAttribute("CyberOutlawPitch") or 0) - pitch) > 3 then
			npc.model:SetAttribute("CyberOutlawPitch", math.floor(pitch))
		end
		local visible = distance < 120 and sees(npc, enemyRoot)
		local reach = if npc.home then 70 else (if npc.kind == "policia" then 48 else 55)
		if npc.root.Anchored then
			-- Parado de vez (sem físicas): só mira e atira.
		elseif not visible or distance > reach then
			if now - npc.lastMove > 0.6 then
				walkTo(npc, enemyRoot.Position)
			end
		elseif now - npc.lastMove > 1.4 then
			-- Em posição: passinhos para o lado enquanto atira.
			local side = Vector3.new(-flat.Z, 0, flat.X).Unit * random.range(-5, 5)
			walkTo(npc, npc.root.Position + side)
		end
		if visible and now >= (npc.nextShot or 0) then
			fire(npc, character)
			local def = npc.weapon
			npc.burst = (npc.burst or 0) + 1
			local limit = if def.auto then random.int(3, 5) else random.int(1, 2)
			if npc.burst >= limit then
				npc.burst = 0
				npc.nextShot = now + random.range(1.1, 1.9)
			else
				npc.nextShot = now + math.max(0.18, 1 / (def.rate or 2))
			end
		end
	end

	local function guardThink(npc, now: number)
		if not npc.weapon or not npc.aggro then
			return
		end
		local head = npc.model:FindFirstChild("Head")
		if not head then
			return
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local enemyRoot = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if enemyRoot and enemyRoot:IsA("BasePart") and humanoid and humanoid.Health > 0 and (enemyRoot.Position - head.Position).Magnitude < npc.aggro
				and not S.inSafeZone(enemyRoot.Position) and sees(npc, enemyRoot) then
				engage(npc, player)
				for _, other in list do
					if other ~= npc and other.mission == npc.mission and other.state == "parado" and other.weapon then
						engage(other, player)
					end
				end
				return
			end
		end
		local _ = now
	end

	local function think(npc, now: number)
		local state = npc.state
		if state == "morto" or state == "rendido" then
			return
		end
		if npc.leaveAt and now > npc.leaveAt then
			remove(npc)
			return
		end
		if state == "andar" or state == "fugir" then
			local position = npc.root.Position
			local target = npc.target or position
			local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
			if flat.Magnitude < 2.2 then
				advance(npc)
			elseif now - npc.lastMove > 4 then
				npc.humanoid:MoveTo(target)
				npc.lastMove = now
			end
			if (position - npc.lastPos).Magnitude > 0.8 then
				npc.lastPos, npc.lastProgress = position, now
			elseif now - npc.lastProgress > 2.5 then
				npc.humanoid.Jump = true
				if now - npc.lastProgress > 6 then
					npc.dir = -npc.dir
					npc.lastProgress = now
					relocate(npc)
				end
			end
			if state == "fugir" and now > (npc.fleeUntil or 0) then
				npc.humanoid.WalkSpeed = npc.speed
				npc.state = "andar"
			end
		elseif state == "atacar" then
			attackThink(npc, now)
		elseif state == "parado" then
			guardThink(npc, now)
		end
	end

	local elapsed = 0
	S.RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		local now = os.clock()
		for index = #list, 1, -1 do
			local npc = list[index]
			if not npc or npc.removed then
				continue
			end
			if npc.model.Parent == nil then
				remove(npc)
			else
				local ok, err = pcall(think, npc, now)
				if not ok and not npc.warned then
					npc.warned = true
					warn("[CyberOutlaw] pedestre:", err)
				end
			end
		end
	end)

	-- Tiros fazem civis fugirem e gangues perto revidarem.
	function api.noise(player: Player, position: Vector3)
		for _, npc in list do
			if npc.state ~= "morto" then
				local distance = (npc.root.Position - position).Magnitude
				if not npc.weapon and distance < 75 and npc.state ~= "fugir" and not npc.root.Anchored then
					flee(npc, position)
				elseif npc.weapon and npc.kind ~= "policia" and npc.state ~= "atacar" and distance < 30 then
					engage(npc, player)
				end
			end
		end
	end

	-- População em volta dos jogadores: nasce longe da vista (95 a 230 studs), some quando ninguém está perto.
	local MAX_AMBIENT, PER_PLAYER = 40, 10
	local GANG_CHANCE = { docas = 0.34, mercado = 0.24, colmeia = 0.18, centro = 0.12, corporativo = 0.06 }
	local function spawnAmbient(position: Vector3, look: Vector3)
		for _ = 1, 8 do
			local block = S.blockList[random.int(1, #S.blockList)]
			local center = Vector3.new(block.cx, position.Y, block.cz)
			if (center - position).Magnitude < 320 then
				local dir = if random.chance(0.5) then 1 else -1
				local side = random.int(1, 4)
				local point = ringPoint(block, side, random.range(0.1, 0.9), dir)
				local offset = Vector3.new(point.X - position.X, 0, point.Z - position.Z)
				local distance = offset.Magnitude
				local behind = distance > 0 and offset.Unit:Dot(look) < 0.35
				if distance > 95 and distance < 230 and (behind or distance > 160) and ringClear(block, dir) and not S.inSafeZone(point) then
					local district = S.districtAt(point.X, point.Z)
					local gangChance = GANG_CHANCE[district and district.key or ""] or 0.12
					local nextIndex = if dir == 1 then nextCorner(side, 1) else side
					if random.chance(gangChance) then
						local gangKey = GANG_ORDER[random.int(1, #GANG_ORDER)]
						return api.spawn("gangue", point, { gang = gangKey, weapon = random.pick(GANGS[gangKey].armas), ambient = true, dir = dir, block = block, corner = nextIndex })
					end
					return api.spawn("civil", point, { ambient = true, dir = dir, block = block, corner = nextIndex })
				end
			end
		end
		return nil
	end

	-- Camelôs atrás dos carrinhos de comida (aparecem quando alguém chega perto).
	local carts = {}
	for _, item in S.city:GetDescendants() do
		if item:IsA("BasePart") and item.Name == "Carrinho de comida" then
			local spot = item.CFrame * CFrame.new(4.4, -item.Size.Y / 2 - 0.4, 0)
			table.insert(carts, { cart = item, position = Vector3.new(spot.Position.X, CURB, spot.Position.Z), look = item.CFrame.LookVector })
		end
	end
	api.carts = carts

	task.spawn(function()
		while true do
			task.wait(1.5)
			local players = Players:GetPlayers()
			local spots = {}
			for _, player in players do
				local character = player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if rootPart and rootPart:IsA("BasePart") then
					table.insert(spots, { position = rootPart.Position, look = rootPart.CFrame.LookVector })
				end
			end
			local ambient = 0
			for index = #list, 1, -1 do
				local npc = list[index]
				if npc.ambient and npc.state ~= "morto" then
					local near = false
					for _, spot in spots do
						if (spot.position - npc.root.Position).Magnitude < 330 then
							near = true
							break
						end
					end
					if near then
						npc.farSince = nil
						ambient += 1
					elseif npc.state ~= "atacar" then
						npc.farSince = npc.farSince or os.clock()
						if os.clock() - npc.farSince > 5 then
							remove(npc)
						end
					end
				end
			end
			for _, spot in spots do
				if ambient >= MAX_AMBIENT then
					break
				end
				local nearby = 0
				for _, npc in list do
					if npc.ambient and npc.state ~= "morto" and (npc.root.Position - spot.position).Magnitude < 240 then
						nearby += 1
					end
				end
				if nearby < PER_PLAYER and spawnAmbient(spot.position, spot.look) then
					ambient += 1
				end
			end
			for _, cart in carts do
				local near = false
				for _, spot in spots do
					local distance = (spot.position - cart.position).Magnitude
					if distance < (if cart.npc then 320 else 220) then
						near = true
						break
					end
				end
				if near and (not cart.npc or cart.npc.removed) and (cart.respawnAt or 0) < os.clock() then
					local yaw = math.atan2(-cart.look.X, -cart.look.Z)
					cart.npc = api.spawn("camelo", cart.position, { anchored = true, yaw = yaw })
					if S.onVendor then
						S.onVendor(cart.npc)
					end
				elseif not near and cart.npc and not cart.npc.removed and cart.npc.state ~= "morto" then
					remove(cart.npc)
					cart.npc = nil
				elseif cart.npc and cart.npc.removed then
					cart.npc = nil
					cart.respawnAt = os.clock() + 60
				end
			end
		end
	end)
	return api
end

-- Assaltos e nível de procurado (polícia PMMB).
local function crimeSystem(S)
	local api = {}
	local Players = S.Players
	local wanted: { [Player]: any } = {}
	local spots = {}
	local copNoise = {}
	local GUNS = {}
	for id, def in S.weapons do
		if def.kind == "gun" then
			GUNS[id] = true
		end
	end

	local function publish(player: Player)
		local entry = wanted[player]
		player:SetAttribute("CyberOutlawProcurado", if entry then entry.level else 0)
		player:SetAttribute("CyberOutlawVisto", entry ~= nil and entry.seen == true)
	end

	function api.crime(player: Player, kind: string)
		local entry = wanted[player] or { level = 0, lastSeen = os.clock(), seen = false }
		wanted[player] = entry
		local before = entry.level
		entry.level = wantedAfter(entry.level, kind)
		entry.lastSeen = os.clock()
		publish(player)
		if entry.level > before then
			S.notify(player, "procurado", entry.level)
		end
	end
	function api.level(player: Player): number
		local entry = wanted[player]
		return if entry then entry.level else 0
	end
	function api.clear(player: Player)
		wanted[player] = nil
		publish(player)
	end

	local function screenText(spot, text: string, color: Color3)
		local label = spot.label
		if label then
			label.Text = text
			label.TextColor3 = color
		end
	end

	function api.rob(player: Player, spot)
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart or not rootPart:IsA("BasePart") or (rootPart.Position - spot.position).Magnitude > 14 then
			return
		end
		if os.clock() < spot.readyAt then
			S.notify(player, "msg", "Já foi esvaziado. Volte mais tarde.")
			return
		end
		if S.inSafeZone(rootPart.Position) then
			S.notify(player, "msg", "Na Praça da Maré não tem crime.")
			return
		end
		local cooldown = ECONOMY.cooldown[spot.kind] or 200
		spot.readyAt = os.clock() + cooldown
		if spot.prompt then
			spot.prompt.Enabled = false
		end
		screenText(spot, "FORA DE SERVIÇO", rgb(255, 70, 80))
		task.delay(cooldown, function()
			if spot.prompt then
				spot.prompt.Enabled = true
			end
			screenText(spot, spot.idle or "", CYAN)
		end)
		local range = ECONOMY.loot[spot.kind]
		S.data.give(player, math.random(range[1], range[2]), if spot.kind == "caixa" then "Caixa eletrônico hackeado"
			elseif spot.kind == "camelo" then "Assalto ao camelô" else "Máquina arrombada")
		local data = S.data.get(player)
		if data then
			data.assaltos += 1
		end
		api.crime(player, spot.kind)
		if S.onRobbery then
			S.onRobbery(player, spot)
		end
	end

	local function prompt(parent: Instance, action: string, object: string, hold: number)
		local item = Instance.new("ProximityPrompt")
		item.Name = "Assalto"
		item.ActionText = action
		item.ObjectText = object
		item.HoldDuration = hold
		item.MaxActivationDistance = 7
		item.RequiresLineOfSight = false
		item.Parent = parent
		return item
	end

	-- Caixas eletrônicos (prop da cidade) e máquinas de venda.
	local atms = {}
	for _, item in S.city:GetDescendants() do
		if item:IsA("BasePart") then
			local kind = item:GetAttribute("CyberOutlawRoubo")
			if not kind and item.Name == "Máquina de venda" then
				kind = "maquina"
			end
			if kind == "caixa" or kind == "maquina" then
				local spot = { kind = kind, part = item, position = item.Position, readyAt = 0 }
				if kind == "caixa" then
					table.insert(atms, item.Position)
					local gui = item:FindFirstChild("Tela", true)
					local label = gui and gui:FindFirstChildWhichIsA("TextLabel", true)
					if label then
						spot.label = label
						spot.idle = label.Text
					end
				end
				spot.prompt = prompt(item, if kind == "caixa" then "Hackear" else "Arrombar", if kind == "caixa" then "Caixa eletrônico" else "Máquina de venda",
					if kind == "caixa" then 4 else 2.5)
				spot.prompt.Triggered:Connect(function(player)
					api.rob(player, spot)
				end)
				table.insert(spots, spot)
			end
		end
	end
	S.atmPositions = atms
	api.spots = spots

	-- Camelô: só com arma na mão; ele levanta as mãos enquanto o assalto acontece.
	S.onVendor = function(npc)
		local spot = { kind = "camelo", position = npc.root.Position, readyAt = 0, npc = npc }
		local item = prompt(npc.root, "Assaltar", "Camelô", 3)
		item.MaxActivationDistance = 9
		spot.prompt = item
		item.PromptButtonHoldBegan:Connect(function(player)
			local character = player.Character
			if character and GUNS[character:GetAttribute("CyberOutlawArma") or ""] then
				npc.model:SetAttribute("CyberOutlawMaosAlto", true)
			end
		end)
		item.PromptButtonHoldEnded:Connect(function()
			task.delay(0.2, function()
				if npc.state ~= "rendido" and npc.model.Parent then
					npc.model:SetAttribute("CyberOutlawMaosAlto", false)
				end
			end)
		end)
		item.Triggered:Connect(function(player)
			local character = player.Character
			if not character or not GUNS[character:GetAttribute("CyberOutlawArma") or ""] then
				S.notify(player, "msg", "Saque uma arma de fogo para assaltar.")
				npc.model:SetAttribute("CyberOutlawMaosAlto", false)
				return
			end
			npc.state = "rendido"
			npc.model:SetAttribute("CyberOutlawMaosAlto", true)
			api.rob(player, spot)
			task.delay(6, function()
				if npc.model.Parent and npc.state == "rendido" then
					npc.state = "parado"
					npc.model:SetAttribute("CyberOutlawMaosAlto", false)
				end
			end)
		end)
	end

	-- Bater carteira dos civis (às vezes eles percebem).
	function api.pickpocket(npc)
		local item = prompt(npc.root, "Bater carteira", "Pedestre", 1.2)
		item.MaxActivationDistance = 6
		item.Triggered:Connect(function(player)
			if npc.robbed or npc.state == "morto" then
				return
			end
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if not rootPart or S.inSafeZone(rootPart.Position) then
				S.notify(player, "msg", "Na Praça da Maré não tem crime.")
				return
			end
			npc.robbed = true
			item:Destroy()
			local range = ECONOMY.loot.carteira
			S.data.give(player, math.random(range[1], range[2]), "Carteira batida")
			if math.random() < 0.35 then
				S.notify(player, "msg", "Ele percebeu! Alguém chamou a polícia.")
				api.crime(player, "carteira")
				S.npc.flee(npc, rootPart.Position)
			end
		end)
	end

	-- Mortes e agressões contam como crime; gangues deixam saque para quem derrubou.
	function api.npcDied(npc, killer: Player?)
		if not killer then
			return
		end
		if npc.kind == "civil" or npc.kind == "camelo" then
			api.crime(killer, "civil")
		elseif npc.kind == "policia" then
			api.crime(killer, "policia")
		elseif (npc.kind == "gangue" or npc.kind == "alvo") and not npc.mission then
			local range = ECONOMY.loot[npc.kind]
			S.data.give(killer, math.random(range[1], range[2]), "Saque da gangue")
		end
	end
	function api.npcAttacked(npc, player: Player)
		if npc.kind == "policia" then
			local last = copNoise[player]
			if not last or os.clock() - last > 8 then
				copNoise[player] = os.clock()
				api.crime(player, "tiroPolicia")
			end
		end
	end
	-- Tiro perto de policial também vira procurado.
	function api.shot(player: Player, position: Vector3)
		for _, npc in S.npc.list do
			if npc.kind == "policia" and npc.state ~= "morto" and (npc.root.Position - position).Magnitude < 70 then
				local last = copNoise[player]
				if not last or os.clock() - last > 8 then
					copNoise[player] = os.clock()
					api.crime(player, "tiroPolicia")
				end
				return
			end
		end
	end

	-- Visto pela polícia, o nível segura; longe dela, cai uma estrela a cada WANTED.decay segundos.
	local random = rand(os.time() % 7777 + 3)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			local now = os.clock()
			for player, entry in wanted do
				if not player.Parent then
					wanted[player] = nil
					continue
				end
				local character = player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				local seen = false
				if rootPart and rootPart:IsA("BasePart") then
					for _, npc in S.npc.list do
						if npc.kind == "policia" and npc.state ~= "morto" and (npc.root.Position - rootPart.Position).Magnitude < WANTED.seen and S.npc.sees(npc, rootPart) then
							seen = true
							break
						end
					end
				end
				if seen then
					entry.lastSeen = now
				end
				if entry.seen ~= seen then
					entry.seen = seen
					publish(player)
				end
				local safe = rootPart and S.inSafeZone(rootPart.Position)
				if not safe and now - entry.lastSeen > WANTED.decay then
					entry.level -= 1
					entry.lastSeen = now
					if entry.level <= 0 then
						wanted[player] = nil
						S.notify(player, "msg", "Você despistou a polícia.")
					end
					publish(player)
				end
				-- Viaturas: chegam policiais até o número do nível, nascendo fora da vista.
				if tick % 2 == 0 and rootPart and rootPart:IsA("BasePart") and wanted[player] then
					local desired = WANTED.cops[math.clamp(entry.level, 1, WANTED.max)]
					local chasing = 0
					for _, npc in S.npc.list do
						if npc.kind == "policia" and npc.state ~= "morto" and npc.enemy == player then
							chasing += 1
						end
					end
					for _ = 1, math.min(2, desired - chasing) do
						for _ = 1, 6 do
							local block = S.blockList[random.int(1, #S.blockList)]
							local point = ringPoint(block, random.int(1, 4), random.range(0.1, 0.9), 1)
							local distance = (Vector3.new(point.X, rootPart.Position.Y, point.Z) - rootPart.Position).Magnitude
							if distance > 100 and distance < 200 and not S.inSafeZone(point) then
								local weapon = if entry.level >= 4 then "m4" elseif entry.level >= 3 then "escopeta" else "glock"
								local cop = S.npc.spawn("policia", point, { weapon = weapon, speed = 17 })
								S.npc.engage(cop, player)
								break
							end
						end
					end
				end
			end
		end
	end)
	return api
end

-- Missões dos fixers e as holochamadas.
local function missionSystem(S)
	local api = {}
	local Players = S.Players
	local active: { [Player]: any } = {}
	local pending: { [Player]: any } = {}
	local nextCall: { [Player]: number } = {}
	local quiet: { [Player]: boolean } = {}
	local lastAsk: { [Player]: number } = {}
	local seq = 0
	local random = rand(os.time() % 9999 + 11)

	local function publicOffer(offer)
		local fixer = FIXER_BY_ID[offer.fixer]
		return {
			id = offer.id, fixer = offer.fixer, nome = fixer.nome, cargo = fixer.titulo, cor = fixer.cor, kind = offer.kind,
			titulo = offer.titulo, objetivo = offer.objetivo, valor = offer.valor, prazo = offer.prazo, falas = offer.falas,
			tchau = offer.tchau, bairro = offer.bairro,
		}
	end

	local function makeOffer(player: Player, fixerId: string?, kind: string?)
		seq += 1
		local character = player.Character
		local origin = if character then character:GetPivot().Position else Vector3.zero
		return missionOffer(os.time() * 13 + seq * 104729 + player.UserId % 1000, fixerId or FIXERS[random.int(1, #FIXERS)].id, kind, {
			origin = origin, blocks = S.blockList, districtAt = S.districtAt, atms = S.atmPositions,
			blocked = function(block)
				return not S.npc.ringClear(block, 1)
			end,
			apelido = player.DisplayName,
		})
	end

	local function waypoint(mission): Vector3?
		local offer = mission.offer
		if offer.kind == "alvo" and mission.target and mission.target.state ~= "morto" then
			return mission.target.root.Position
		elseif offer.kind == "entrega" then
			return if mission.stage == 1 then offer.alvo else offer.destino
		end
		return offer.alvo
	end

	local function publish(player: Player)
		local mission = active[player]
		if not mission then
			player:SetAttribute("CyberOutlawMissao", nil)
			return
		end
		local offer = mission.offer
		local fixer = FIXER_BY_ID[offer.fixer]
		local point = waypoint(mission)
		local left = 0
		for _, npc in mission.npcs do
			if npc.state ~= "morto" and npc.role ~= "contato" then
				left += 1
			end
		end
		player:SetAttribute("CyberOutlawMissao", S.HttpService:JSONEncode({
			id = offer.id, kind = offer.kind, fixer = offer.fixer, nomeFixer = fixer.nome, cor = fixer.cor, titulo = offer.titulo,
			objetivo = if mission.stage == 2 and offer.objetivo2 then offer.objetivo2 else offer.objetivo,
			alvo = if point then { math.floor(point.X * 10) / 10, math.floor(point.Y * 10) / 10, math.floor(point.Z * 10) / 10 } else nil,
			prazo = mission.deadline, valor = offer.valor, restantes = if offer.kind == "limpeza" then left else nil,
		}))
	end

	local function package(player: Player, on: boolean)
		local character = player.Character
		local torso = character and character:FindFirstChild("Torso")
		local old = character and character:FindFirstChild("CyberOutlawPacote")
		if old then
			old:Destroy()
		end
		if on and torso and torso:IsA("BasePart") then
			local box = part(character, "CyberOutlawPacote", Vector3.new(1.6, 1.2, 0.9), torso.CFrame * CFrame.new(0, 0.1, 1), rgb(60, 56, 50), MAT.Metal)
			box.Anchored = false
			box.CanCollide = false
			box.Massless = true
			local strip = part(box, "Luz", Vector3.new(1.62, 0.12, 0.92), box.CFrame, ORANGE, MAT.Neon)
			strip.Anchored = false
			strip.CanCollide = false
			strip.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = box, strip
			weld.Parent = strip
			local back = Instance.new("Weld")
			back.Part0, back.Part1, back.C0 = torso, box, CFrame.new(0, 0.1, 1)
			back.Parent = box
		end
	end

	local function finish(player: Player, success: boolean, reason: string?)
		local mission = active[player]
		if not mission then
			return
		end
		active[player] = nil
		local offer = mission.offer
		local fixer = FIXER_BY_ID[offer.fixer]
		package(player, false)
		for _, npc in mission.npcs do
			if not npc.removed and npc.state ~= "morto" then
				npc.leaveAt = os.clock() + (if success then 3 else 8)
				npc.mission = nil
			end
		end
		publish(player)
		if success then
			S.data.give(player, offer.valor, "Pagamento: " .. fixer.nome)
			local data = S.data.get(player)
			if data then
				data.cred += 1
				data.missoes += 1
				S.data.publish(player)
			end
			S.notify(player, "fixer", fixer.id, "Trabalho limpo, " .. player.DisplayName .. ". O dinheiro já caiu na conta.", true)
		else
			S.notify(player, "fixer", fixer.id, reason or "Você me deixou na mão.", false)
		end
		nextCall[player] = os.clock() + random.range(90, 150)
	end
	api.finish = finish

	local function contact(mission, position: Vector3, action: string, onDone)
		local npc = S.npc.spawn("contato", position, { home = position, mission = mission, role = "contato", speed = 6 })
		local item = Instance.new("ProximityPrompt")
		item.Name = "Missão"
		item.ActionText = action
		item.ObjectText = "Contato de " .. FIXER_BY_ID[mission.offer.fixer].nome
		item.HoldDuration = 0.8
		item.MaxActivationDistance = 9
		item.RequiresLineOfSight = false
		item.Parent = npc.root
		item.Triggered:Connect(function(player)
			if player == mission.player and active[player] == mission then
				item:Destroy()
				onDone()
			end
		end)
		table.insert(mission.npcs, npc)
		return npc
	end

	local function start(player: Player, offer)
		local mission = { offer = offer, player = player, deadline = S.now() + offer.prazo, npcs = {}, stage = 1 }
		active[player] = mission
		local block = S.blocks[offer.bloco]
		local function along(k: number, distance: number): Vector3
			local a = corner(block, offer.canto, 1)
			local b = corner(block, nextCorner(offer.canto, k), 1)
			return a + (b - a).Unit * distance
		end
		local gang = GANGS[offer.gangue]
		if offer.kind == "alvo" then
			mission.target = S.npc.spawn("alvo", offer.alvo, { gang = offer.gangue, weapon = gang.armas[1], home = offer.alvo, aggro = 42, mission = mission, role = "alvo", seed = offer.semente })
			table.insert(mission.npcs, mission.target)
			for _, k in { 1, -1 } do
				local spot = along(k, 5)
				table.insert(mission.npcs, S.npc.spawn("gangue", spot, { gang = offer.gangue, weapon = random.pick(gang.armas), home = spot, aggro = 42, mission = mission, role = "guarda" }))
			end
		elseif offer.kind == "limpeza" then
			for index = 1, offer.qtd do
				local k = if index % 2 == 0 then 1 else -1
				local spot = along(k, 3 + math.floor((index - 1) / 2) * 6)
				table.insert(mission.npcs, S.npc.spawn("gangue", spot, { gang = offer.gangue, weapon = random.pick(gang.armas), home = spot, aggro = 46, mission = mission, role = "guarda" }))
			end
		elseif offer.kind == "entrega" then
			contact(mission, offer.alvo, "Pegar o pacote", function()
				mission.stage = 2
				package(player, true)
				S.notify(player, "msg", "Pacote na mão. Leve até o destino marcado.")
				contact(mission, offer.destino, "Entregar o pacote", function()
					finish(player, true)
				end)
				publish(player)
			end)
		end
		publish(player)
		S.notify(player, "missao", publicOffer(offer))
	end

	local function eligible(player: Player): boolean
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return humanoid ~= nil and humanoid.Health > 0 and not quiet[player] and not active[player] and not pending[player]
			and not S.isWanted(player) and not S.inCombat(player) and player:GetAttribute("CyberOutlawArrived") == true
	end

	function api.call(player: Player, fixerId: string?, outgoing: boolean)
		local offer = makeOffer(player, fixerId, nil)
		pending[player] = { offer = offer, sentAt = os.clock(), answered = outgoing }
		S.notify(player, "chamada", publicOffer(offer), outgoing)
	end

	function api.request(player: Player, action: string, a, b)
		local entry = pending[player]
		if action == "atender" then
			if entry and entry.offer.id == a then
				entry.answered = true
				entry.sentAt = os.clock()
			end
		elseif action == "recusar" then
			if entry and entry.offer.id == a then
				pending[player] = nil
				nextCall[player] = os.clock() + random.range(150, 240)
			end
		elseif action == "aceitar" then
			if entry and entry.offer.id == a and entry.answered and not active[player] then
				pending[player] = nil
				start(player, entry.offer)
			end
		elseif action == "abandonar" then
			finish(player, false, "Desistiu? Tudo bem. Da próxima vez eu ligo pra outro.")
		elseif action == "ligar" then
			if type(a) ~= "string" or not FIXER_BY_ID[a] then
				return
			end
			if active[player] then
				S.notify(player, "msg", "Termine o trabalho atual antes de pedir outro.")
				return
			end
			if lastAsk[player] and os.clock() - lastAsk[player] < 8 then
				return
			end
			lastAsk[player] = os.clock()
			pending[player] = nil
			api.call(player, a, true)
		elseif action == "naoPerturbe" then
			quiet[player] = b == true or a == true
			player:SetAttribute("CyberOutlawNaoPerturbe", quiet[player])
		end
	end

	function api.join(player: Player)
		nextCall[player] = os.clock() + random.range(45, 80)
	end
	function api.leave(player: Player)
		local mission = active[player]
		if mission then
			for _, npc in mission.npcs do
				S.npc.remove(npc)
			end
		end
		active[player], pending[player], nextCall[player], quiet[player], lastAsk[player] = nil, nil, nil, nil, nil
	end
	function api.died(player: Player)
		local mission = active[player]
		if mission then
			finish(player, false, if mission.offer.kind == "entrega" and mission.stage == 2 then "O pacote se perdeu com você. Que fiasco." else "Você caiu. O serviço foi pro saco.")
		end
	end

	function api.npcDied(npc, killer: Player?)
		local mission = npc.mission
		if not mission or active[mission.player] ~= mission then
			return
		end
		local offer = mission.offer
		if offer.kind == "alvo" and npc.role == "alvo" then
			if killer == mission.player then
				finish(mission.player, true)
			else
				finish(mission.player, false, "Alguém chegou antes de você no alvo.")
			end
		elseif offer.kind == "limpeza" then
			local left = 0
			for _, other in mission.npcs do
				if other.state ~= "morto" then
					left += 1
				end
			end
			if left == 0 then
				finish(mission.player, true)
			else
				publish(mission.player)
			end
		elseif npc.role == "contato" then
			finish(mission.player, false, "Mataram o meu contato. O trabalho acabou.")
		end
	end

	function api.robbery(player: Player, spot)
		local mission = active[player]
		if mission and mission.offer.kind == "roubo" and (spot.position - mission.offer.alvo).Magnitude < 4 then
			finish(player, true)
		end
	end

	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, mission in active do
				if not player.Parent then
					active[player] = nil
				elseif S.now() > mission.deadline then
					finish(player, false, "O prazo acabou. Não trabalho com gente lenta.")
				elseif mission.offer.kind == "alvo" then
					publish(player)
				end
			end
			for _, player in Players:GetPlayers() do
				local entry = pending[player]
				if entry and not entry.answered and now - entry.sentAt > 24 then
					pending[player] = nil
					S.notify(player, "perdida", entry.offer.fixer)
					nextCall[player] = now + random.range(120, 200)
				elseif entry and entry.answered and now - entry.sentAt > 120 then
					pending[player] = nil
				elseif not entry and now >= (nextCall[player] or math.huge) and eligible(player) then
					api.call(player, nil, false)
				end
			end
		end
	end)
	return api
end

local function main()
	local S = {
		Players = game:GetService("Players"),
		ReplicatedStorage = game:GetService("ReplicatedStorage"),
		HttpService = game:GetService("HttpService"),
		RunService = game:GetService("RunService"),
		PhysicsService = game:GetService("PhysicsService"),
		DataStoreService = game:GetService("DataStoreService"),
	}
	local ReplicatedStorage, HttpService, Players = S.ReplicatedStorage, S.HttpService, S.Players
	if ReplicatedStorage:FindFirstChild("CyberOutlawVida") then
		return
	end
	-- A cidade e o arsenal são montados por outros scripts: espera os dois.
	local board = ReplicatedStorage:WaitForChild("CyberOutlawCityInfo", 180)
	local arsenal = ReplicatedStorage:WaitForChild("CyberOutlawArsenal", 60)
	S.city = workspace:FindFirstChild("CyberOutlawCity")
	if not board or not S.city then
		warn("[CyberOutlaw] vida: a cidade não ficou pronta; sem casas, missões e pedestres.")
		return
	end
	local layout = HttpService:JSONDecode(board:GetAttribute("Layout"))
	S.blocks, S.blockList = cityBlocks(layout)
	local districts = layout.districts or {}
	function S.districtAt(x: number, z: number)
		for _, district in districts do
			local r = district.rect
			if x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4] then
				return district
			end
		end
		return districts[#districts]
	end
	S.weapons = {}
	local effect = arsenal and arsenal:FindFirstChild("Efeito")
	if arsenal then
		local ok, list = pcall(HttpService.JSONDecode, HttpService, arsenal:GetAttribute("Armas") or "[]")
		for _, def in if ok then list else {} do
			S.weapons[def.id] = def
		end
	end
	local safe = { 108, 108, 95 }
	pcall(function()
		safe = HttpService:JSONDecode(arsenal:GetAttribute("ZonaSegura"))
	end)
	function S.inSafeZone(position: Vector3): boolean
		return Vector2.new(position.X - safe[1], position.Z - safe[2]).Magnitude < safe[3]
	end
	function S.now(): number
		return workspace:GetServerTimeNow()
	end
	function S.shotFx(model: Model, id: string, from: Vector3, hits)
		if effect then
			effect:FireAllClients("tiro", model, id, from, hits)
		end
	end
	local lastHurt: { [Player]: number } = {}
	local lastShot: { [Player]: number } = {}
	function S.inCombat(player: Player): boolean
		local now = os.clock()
		return (lastHurt[player] ~= nil and now - lastHurt[player] < 10) or (lastShot[player] ~= nil and now - lastShot[player] < 8)
	end
	function S.damagePlayer(character: Model, amount: number, _source)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local player = Players:GetPlayerFromCharacter(character)
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		if player then
			local raw = player:GetAttribute("CyberOutlawImplantes")
			if type(raw) == "string" and string.find(raw, "subdermal", 1, true) then
				amount *= 0.7
			end
		end
		humanoid:TakeDamage(amount)
	end

	-- Remotos e catálogo público.
	local folder = Instance.new("Folder")
	folder.Name = "CyberOutlawVida"
	local request = Instance.new("RemoteEvent")
	request.Name = "Pedido"
	request.Parent = folder
	local notice = Instance.new("RemoteEvent")
	notice.Name = "Aviso"
	notice.Parent = folder
	function S.notify(player: Player, kind: string, ...)
		if player.Parent then
			notice:FireClient(player, kind, ...)
		end
	end
	local moveis = Instance.new("Folder")
	moveis.Name = "Moveis"
	moveis.Parent = folder
	S.furniture, S.furnitureSizes = {}, {}
	local catalog = {}
	for _, def in FURNITURE do
		local model, size = buildFurniture(def)
		model.Parent = moveis
		S.furniture[def.id] = model
		S.furnitureSizes[def.id] = size
		table.insert(catalog, { id = def.id, nome = def.nome, preco = def.preco, cat = def.cat, desc = def.desc, chao = def.chao == true,
			tam = { size.X, size.Y, size.Z }, ordem = def.ordem })
	end
	local busts = Instance.new("Folder")
	busts.Name = "Fixers"
	busts.Parent = folder
	local fixers = {}
	for _, fixer in FIXERS do
		local model = buildPedestrian(fixer.semente, "contato", nil, fixer.visual)
		model.Name = fixer.id
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				item.Anchored = true
			end
		end
		model.Parent = busts
		table.insert(fixers, { id = fixer.id, nome = fixer.nome, titulo = fixer.titulo, cor = fixer.cor })
	end
	folder:SetAttribute("Catalogo", HttpService:JSONEncode(catalog))
	folder:SetAttribute("Reformas", HttpService:JSONEncode(RENOVATIONS))
	folder:SetAttribute("Fixers", HttpService:JSONEncode(fixers))
	folder:SetAttribute("Economia", HttpService:JSONEncode({ faxina = ECONOMY.express, venda = ECONOMY.sellBack, limpeza = ECONOMY.cleanEach }))
	folder:SetAttribute("Unidade", HttpService:JSONEncode({ meia = { UNIT.half.X, UNIT.half.Y }, livre = UNIT.keepOut, grade = UNIT.grid, maximo = UNIT.maxItems }))
	folder:SetAttribute("Lixo", HttpService:JSONEncode((function()
		local names = {}
		for _, def in TRASH do
			table.insert(names, { id = def.id, nome = def.nome })
		end
		return names
	end)()))
	folder.Parent = ReplicatedStorage

	S.data = dataSystem(S)
	S.homes = homeSystem(S)
	S.npc = npcSystem(S)
	S.crime = crimeSystem(S)
	S.missions = missionSystem(S)
	function S.isWanted(player: Player): boolean
		return S.crime.level(player) > 0
	end
	S.onNpcDied = function(npc, killer)
		S.crime.npcDied(npc, killer)
		S.missions.npcDied(npc, killer)
	end
	S.onNpcAttacked = function(npc, player)
		S.crime.npcAttacked(npc, player)
	end
	S.onRobbery = function(player, spot)
		S.missions.robbery(player, spot)
	end
	-- Os civis do ambiente ganham "bater carteira".
	local spawnNpc = S.npc.spawn
	S.npc.spawn = function(kind, position, opts)
		local npc = spawnNpc(kind, position, opts)
		if kind == "civil" then
			S.crime.pickpocket(npc)
		end
		return npc
	end

	local HOME_ACTIONS = { comprar = true, colocar = true, mover = true, guardar = true, vender = true, venderGuardado = true, reforma = true,
		faxina = true, irCasa = true, casa = true }
	local MISSION_ACTIONS = { atender = true, recusar = true, aceitar = true, abandonar = true, ligar = true, naoPerturbe = true }
	local budget: { [Player]: { number } } = {}
	request.OnServerEvent:Connect(function(player, action, a, b, c, d)
		if type(action) ~= "string" then
			return
		end
		local now = os.clock()
		local entry = budget[player]
		if not entry or now - entry[1] > 1 then
			entry = { now, 0 }
			budget[player] = entry
		end
		entry[2] += 1
		if entry[2] > 12 then
			return
		end
		if HOME_ACTIONS[action] then
			S.homes.request(player, action, a, b, c, d)
		elseif MISSION_ACTIONS[action] then
			S.missions.request(player, action, a, b)
		end
	end)

	local function watch(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		local health = humanoid.Health
		humanoid.HealthChanged:Connect(function(value)
			if value < health then
				lastHurt[player] = os.clock()
			end
			health = value
		end)
		humanoid.Died:Connect(function()
			S.missions.died(player)
			if S.crime.level(player) > 0 then
				S.crime.clear(player)
				local data = S.data.get(player)
				if data and data.eddies > 0 then
					S.data.take(player, math.floor(data.eddies * ECONOMY.hospital), "Hospital e fiança")
				end
			end
		end)
		character:GetAttributeChangedSignal("CyberOutlawUltimoTiro"):Connect(function()
			lastShot[player] = os.clock()
			local position = character:GetPivot().Position
			S.npc.noise(player, position)
			S.crime.shot(player, position)
		end)
	end
	local function join(player: Player)
		task.spawn(function()
			S.data.load(player)
			if not player.Parent then
				S.data.drop(player)
				return
			end
			S.homes.claim(player)
			S.homes.send(player)
			S.missions.join(player)
		end)
		player.CharacterAdded:Connect(function(character)
			watch(player, character)
		end)
		if player.Character then
			task.spawn(watch, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		S.missions.leave(player)
		S.homes.release(player)
		S.crime.clear(player)
		S.data.drop(player)
		lastHurt[player], lastShot[player], budget[player] = nil, nil, nil
	end)
	print(string.format("[CyberOutlaw] Vida em Maré Baixa: %d apartamentos, %d móveis, %d pontos de assalto, %d camelôs",
		(function()
			local count = 0
			for _ in S.units do
				count += 1
			end
			return count
		end)(), #FURNITURE, #S.crime.spots, #S.npc.carts))
end

if typeof(game) == "Instance" then
	task.spawn(main)
end

return M
