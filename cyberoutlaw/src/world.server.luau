-- Maré Baixa · cidade jogável do CyberOutlaw (Script em ServerScriptService).
-- O servidor monta a cidade por código ao iniciar, sempre igual (semente fixa).
-- Arte sem IA: asfalto e concreto são digitalizações Poly Haven (CC0); janelas, painéis,
-- vitrines, anúncios, poças e céu são desenhados por código (tools/draw_city_textures.py).
-- Sem as imagens aprovadas, cada uma vira cor e faixas de luz em geometria.

local ART = __CYBEROUTLAW_ART__

local CITY_VERSION = 2
local SEED = 20261123
local GROUND = 0.25 -- topo do asfalto, acima de um Baseplate padrão
local CURB = 0.85 -- topo das calçadas e quadras
local HALF = 1000 -- área jogável de -1000 a 1000 em X e Z
local STEP = 200 -- distância entre os eixos das ruas
local FLOOR = 14 -- altura de um andar
local GF = 14 -- térreo com lojas recuadas
local INSET, DEPTH = 3, 3.4 -- recuo da vitrine sob a marquise e profundidade visível da loja
local GLASS_H = 10.4 -- altura das vitrines; acima delas fica a faixa de letreiros
local PARKING = 8 -- faixa de estacionamento junto ao meio-fio
local MEDIAN = 8 -- canteiro central das avenidas
local QUAY = 1070 -- borda do cais, ao sul
local WATER = -3
local DECK = 66 -- topo do viaduto do monotrilho
local LIMIT = 1036 -- muros invisíveis do mapa
local TILE = 32 -- ladrilho do asfalto; as poças ocupam células desta grade
local PLAZA = Vector3.new(108, 0, 108) -- centro da quadra entre os eixos 0 e 200
local SPAWN = Vector3.new(108, CURB, 140)

local rgb = Color3.fromRGB
local M = Enum.Material
local N = Enum.NormalId
local PALETTE = {
	ink = rgb(9, 11, 18),
	iron = rgb(30, 33, 42),
	steel = rgb(64, 69, 80),
	concrete = rgb(86, 84, 90),
	walk = rgb(72, 72, 78),
	asphalt = rgb(26, 28, 34),
	glass = rgb(24, 34, 50),
	pink = rgb(236, 52, 146),
	violet = rgb(156, 86, 240),
	cyan = rgb(44, 206, 240),
	ice = rgb(176, 216, 255),
	amber = rgb(255, 152, 72),
	red = rgb(236, 54, 64),
	lime = rgb(112, 226, 136),
	sodium = rgb(255, 168, 92),
	warm = rgb(255, 210, 160),
	led = rgb(208, 226, 250),
	white = rgb(222, 224, 214),
	paint = rgb(200, 200, 190),
	yellow = rgb(214, 166, 56),
	monorail = rgb(170, 128, 58),
}
-- Paleta curta por distrito: um ou dois destaques, mais luz branca ou âmbar.
local THEMES = {
	centro = { accents = { PALETTE.pink, PALETTE.cyan }, signs = { PALETTE.pink, PALETTE.cyan, PALETTE.warm, PALETTE.ice }, lamp = PALETTE.led,
		fabric = { rgb(92, 22, 52), rgb(18, 60, 74), rgb(40, 40, 48) } },
	corporativo = { accents = { PALETTE.cyan, PALETTE.ice }, signs = { PALETTE.cyan, PALETTE.ice, PALETTE.white }, lamp = PALETTE.led,
		fabric = { rgb(20, 48, 70), rgb(44, 46, 54) } },
	colmeia = { accents = { PALETTE.violet, PALETTE.amber }, signs = { PALETTE.violet, PALETTE.amber, PALETTE.pink, PALETTE.warm }, lamp = PALETTE.warm,
		fabric = { rgb(60, 30, 86), rgb(110, 58, 24), rgb(36, 60, 48) } },
	mercado = { accents = { PALETTE.amber, PALETTE.red }, signs = { PALETTE.amber, PALETTE.red, PALETTE.warm, PALETTE.lime }, lamp = PALETTE.sodium,
		fabric = { rgb(120, 30, 30), rgb(130, 76, 20), rgb(30, 70, 50), rgb(40, 50, 90) } },
	docas = { accents = { PALETTE.sodium, PALETTE.red }, signs = { PALETTE.sodium, PALETTE.red, PALETTE.ice }, lamp = PALETTE.sodium,
		fabric = { rgb(60, 60, 66) } },
}
-- Nome, interior desenhado e palavra curta para a placa vertical.
local SHOPS = {
	{ "BAR CROMO", "bar", "BAR" }, { "FARMÁCIA VIVA", "farmacia", "24H" }, { "IMPLANTES NOVA", "farmacia", "CYBER" },
	{ "MOTEL ÓRBITA", "saguao", "MOTEL" }, { "PEÇAS VOLT", "eletronicos", "PEÇAS" }, { "CÂMBIO 3X", "saguao", "CÂMBIO" },
	{ "HOTEL ESTUÁRIO", "saguao", "HOTEL" }, { "LAN HOUSE PIXEL", "fliperama", "LAN" }, { "TATUAGEM LÚMEN", "bar", "TATTOO" },
	{ "FLIPERAMA ZERO", "fliperama", "JOGOS" }, { "PENHORES ÔMEGA", "eletronicos", "PENHOR" }, { "LAVANDERIA AZUL", "roupas", "LAVA" },
	{ "BOATE SINAL", "bar", "CLUB" }, { "LANCHONETE 24H", "lanchonete", "24H" }, { "ARMARIA FAROL", "eletronicos", "ARMAS" },
	{ "PIZZARIA FORNO 9", "lanchonete", "PIZZA" }, { "BARBEARIA NAVALHA", "roupas", "BARBA" }, { "MERCADINHO DA MARÉ", "mercadinho", "LOJA" },
	{ "AÇAÍ NEON", "lanchonete", "AÇAÍ" }, { "ELETRÔNICOS KAIROS", "eletronicos", "CHIPS" }, { "PADARIA ALVORADA", "mercadinho", "PÃO" },
	{ "DROGARIA LIMIAR", "farmacia", "FARMA" }, { "ÓTICA VÉRTICE", "roupas", "ÓTICA" }, { "BRECHÓ CROMADO", "roupas", "BRECHÓ" },
	{ "CAFÉ RUÍDO", "lanchonete", "CAFÉ" }, { "OFICINA ROTOR", "eletronicos", "MOTOS" },
}
-- Marca, chamada, cores e células nos atlas de anúncios (horizontal e vertical).
local ADS = {
	{ "ALVOR", "ENERGIA QUE NÃO DORME", PALETTE.pink, rgb(54, 8, 58), h = 1, v = 3 },
	{ "LIMIAR", "SEGUROS PARA CORPOS NOVOS", PALETTE.cyan, rgb(6, 30, 58), h = 2, v = 2 },
	{ "ESTUÁRIO NET", "9G EM TODA A MARÉ", PALETTE.violet, rgb(22, 8, 44), h = 4, v = 1 },
	{ "KAIROS", "IMPLANTES NEURAIS · 0% DE JUROS", PALETTE.amber, rgb(54, 18, 6), h = 3, v = 4 },
	{ "VÉRTICE", "MOTORES ELÉTRICOS", PALETTE.lime, rgb(6, 40, 30), h = 2, v = 2 },
	{ "NOVA CHUVA", "REFRIGERANTE SINTÉTICO", PALETTE.red, rgb(44, 6, 14), h = 4, v = 3 },
}
-- Ordem de prioridade: o primeiro retângulo que contém o ponto define o distrito.
local DISTRICTS = {
	{ key = "docas", name = "Docas da Maré", color = PALETTE.lime, rect = { -HALF, 600, HALF, QUAY } },
	{ key = "centro", name = "Distrito Prisma", color = PALETTE.pink, rect = { -400, -400, 400, 400 } },
	{ key = "mercado", name = "Mercado Fosso", color = PALETTE.amber, rect = { -HALF, -HALF, -400, 600 } },
	{ key = "corporativo", name = "Alto Vértice", color = PALETTE.cyan, rect = { 400, -HALF, HALF, 600 } },
	{ key = "colmeia", name = "Colmeia", color = PALETTE.violet, rect = { -400, -HALF, 400, 600 } },
}
-- Torres-marco do Distrito Prisma, pela quadra (centro do bloco).
local LANDMARKS = {
	["-100,-100"] = { name = "Torre Alvor", height = 1148, brand = "ALVOR", accent = PALETTE.pink },
	["300,-300"] = { name = "Torre Limiar", height = 980, brand = "LIMIAR", accent = PALETTE.cyan },
	["-300,300"] = { name = "Torre Kairos", height = 896, brand = "KAIROS", accent = PALETTE.amber },
}
-- Megaprédios da Colmeia: blocos inteiros de painéis modulares com treliças nas quinas.
local MEGABLOCKS = {
	["-300,-500"] = { number = "01", height = 392 },
	["100,-700"] = { number = "02", height = 336 },
	["300,500"] = { number = "07", height = 308 },
	["-100,-900"] = { number = "04", height = 364 },
}
local WINDOW_ART = { residencial = "fachada_residencial", escritorio = "fachada_escritorio", vidro = "fachada_vidro", painel = "fachada_painel" }
-- Um quadro de janelas cobre 16 colunas de 6 studs e 8 andares de 14 studs.
local TILE_STUDS = Vector2.new(96, 112)
-- Atlas desenhados por código, 1024 x 1024.
local VITRINES = { -- 2 colunas x 4 linhas de 512 x 256
	mercadinho = { 0, 0 }, bar = { 512, 0 }, farmacia = { 0, 256 }, eletronicos = { 512, 256 },
	lanchonete = { 0, 512 }, roupas = { 512, 512 }, fliperama = { 0, 768 }, saguao = { 512, 768 },
}
local ANUNCIOS = {
	vertical = { { 0, 0 }, { 256, 0 }, { 512, 0 }, { 768, 0 } }, -- 256 x 512
	horizontal = { { 0, 512 }, { 512, 512 }, { 0, 768 }, { 512, 768 } }, -- 512 x 256
}
-- Poças: quatro ladrilhos de asfalto (512 x 512) com a água recortada no canal alfa, na mesma convenção do chão.
local POCAS = { "poca_1", "poca_2", "poca_3", "poca_4" }

local function isAvenue(p: number): boolean
	return p % 400 == 0
end

local function roadWidth(p: number): number
	return if isAvenue(p) then 76 else 44
end

local function walkWidth(p: number): number
	return if isAvenue(p) then 16 else 14
end

-- Faixas de rolamento de cada lado do eixo da via: distância interna e externa ao eixo.
local function driveBand(p: number): (number, number)
	return if isAvenue(p) then MEDIAN / 2 else 0, roadWidth(p) / 2 - PARKING
end

local function districtAt(x: number, z: number)
	for _, district in DISTRICTS do
		local r = district.rect
		if x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4] then
			return district
		end
	end
	return DISTRICTS[#DISTRICTS]
end

local function random(seed: number)
	local state = seed % 2147483646 + 1
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

local function shade(color: Color3, amount: number): Color3
	return PALETTE.ink:Lerp(color, amount)
end

local function layoutData()
	local lines = {}
	for p = -HALF, HALF, STEP do
		table.insert(lines, { p, roadWidth(p), walkWidth(p) })
	end
	local districts = {}
	for _, d in DISTRICTS do
		table.insert(districts, { key = d.key, name = d.name, rect = d.rect,
			color = { math.round(d.color.R * 255), math.round(d.color.G * 255), math.round(d.color.B * 255) } })
	end
	return {
		version = CITY_VERSION,
		half = HALF,
		lines = lines,
		districts = districts,
		quay = QUAY,
		spawn = { SPAWN.X, SPAWN.Z },
		plaza = { PLAZA.X, PLAZA.Z },
		monorail = { { 400, -340 }, { 400, 340 }, { 340, 400 }, { -340, 400 }, { -400, 340 },
			{ -400, -340 }, { -340, -400 }, { 340, -400 } },
		station = { 400, 0 },
	}
end

local function buildCity(root: Instance, art, options)
	options = options or {}
	art = if type(art) == "table" then art else {}
	local stats = { parts = 0, lights = 0, guis = 0, towers = 0, signs = 0, emitters = 0, cars = 0, props = 0, puddles = 0 }
	local pause = options.yield
	local FONTS = {
		street = Font.fromEnum(Enum.Font.Sarpanch),
		corporate = Font.fromEnum(Enum.Font.Michroma),
		heavy = Font.fromEnum(Enum.Font.GothamBlack),
		clean = Font.fromEnum(Enum.Font.GothamBold),
		tall = Font.fromEnum(Enum.Font.Oswald),
	}

	local function uri(id): string?
		return if type(id) == "number" and id > 0 and id % 1 == 0 then string.format("rbxassetid://%.0f", id) else nil
	end

	local function group(parent: Instance, name: string): Model
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = parent
		return model
	end

	-- Peças decorativas não colidem nem recebem consultas; chão, quadras, prédios e objetos grandes sim.
	local function piece(parent: Instance, name: string, size: Vector3, pose: CFrame, color: Color3,
		material: Enum.Material?, solid: boolean?, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = Vector3.new(math.clamp(size.X, 0.05, 2048), math.clamp(size.Y, 0.05, 2048), math.clamp(size.Z, 0.05, 2048))
		p.CFrame = pose
		p.Color = color
		p.Material = material or M.SmoothPlastic
		p.Shape = shape or Enum.PartType.Block
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow = false
		p.CanTouch = false
		p.CanCollide = solid == true
		p.CanQuery = solid == true
		p.Parent = parent
		stats.parts += 1
		if pause and stats.parts % 350 == 0 then
			pause()
		end
		return p
	end

	local function box(parent, name, x, y, z, sx, sy, sz, color, material, solid): Part
		return piece(parent, name, Vector3.new(sx, sy, sz), CFrame.new(x, y, z), color, material, solid)
	end

	local function span(parent, name, x0, x1, y0, y1, z0, z1, color, material, solid): Part
		-- Peças do Roblox têm no máximo 2048 studs por eixo; faixas maiores viram duas.
		if x1 - x0 > 2048 then
			local mid = (x0 + x1) / 2
			local first = span(parent, name, x0, mid, y0, y1, z0, z1, color, material, solid)
			span(parent, name, mid, x1, y0, y1, z0, z1, color, material, solid)
			return first
		elseif z1 - z0 > 2048 then
			local mid = (z0 + z1) / 2
			local first = span(parent, name, x0, x1, y0, y1, z0, mid, color, material, solid)
			span(parent, name, x0, x1, y0, y1, mid, z1, color, material, solid)
			return first
		end
		return box(parent, name, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0, color, material, solid)
	end

	local function rod(parent, name, x, y0, y1, z, diameter, color, material, solid): Part
		return piece(parent, name, Vector3.new(y1 - y0, diameter, diameter),
			CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.pi / 2), color, material, solid, Enum.PartType.Cylinder)
	end

	local function beam(parent, name, a: Vector3, b: Vector3, width: number, height: number, color, material, solid): Part
		local direction = (b - a).Unit
		local up = if math.abs(direction.Y) > 0.98 then Vector3.zAxis else Vector3.yAxis
		local pose = CFrame.lookAt(a:Lerp(b, 0.5), b, up)
		return piece(parent, name, Vector3.new(width, height, (b - a).Magnitude), pose, color, material, solid)
	end

	local function light(p: BasePart, class: string, color: Color3, brightness: number, range: number, face: Enum.NormalId?, angle: number?)
		local lamp = Instance.new(class)
		lamp.Color = color
		lamp.Brightness = brightness
		lamp.Range = range
		lamp.Shadows = false
		if face then
			lamp.Face = face
		end
		if angle then
			lamp.Angle = angle
		end
		lamp.Parent = p
		stats.lights += 1
		return lamp
	end

	local function pbr(p: BasePart, key: string, face: Enum.NormalId, tile: number, color: Color3, transparency: number)
		local diffuse = uri(art[key])
		if not diffuse then
			return
		end
		local texture = Instance.new("Texture")
		texture.Name = "Acabamento " .. key
		texture.Face = face
		texture.Texture = diffuse
		texture.StudsPerTileU = tile
		texture.StudsPerTileV = tile
		texture.Color3 = color
		texture.Transparency = transparency
		texture:SetAttribute("CyberOutlawMaterial", key)
		local normal, rough = uri(art[key .. "_normal"]), uri(art[key .. "_rough"])
		if Content and normal then
			pcall(function()
				texture.NormalMapContent = Content.fromUri(normal)
			end)
		end
		if Content and rough then
			pcall(function()
				texture.RoughnessMapContent = Content.fromUri(rough)
			end)
		end
		texture.Parent = p
	end

	local function surface(p: BasePart, face: Enum.NormalId, name: string, pixels: number, brightness: number, distance: number)
		local gui = Instance.new("SurfaceGui")
		gui.Name = name
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = pixels
		gui.LightInfluence = 0
		gui.Brightness = brightness
		gui.MaxDistance = distance
		gui.ClipsDescendants = true
		gui.AlwaysOnTop = false
		gui.Parent = p
		stats.guis += 1
		return gui
	end

	local function label(parent: Instance, text: string, font: Font, color: Color3, stroke: Color3?, position: UDim2?, size: UDim2?)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.BorderSizePixel = 0
		t.Position = position or UDim2.fromScale(0, 0)
		t.Size = size or UDim2.fromScale(1, 1)
		t.FontFace = font
		t.Text = text
		t.TextScaled = true
		t.TextWrapped = true
		t.TextColor3 = color
		if stroke then
			t.TextStrokeColor3 = stroke
			t.TextStrokeTransparency = 0.45
		end
		t.Parent = parent
		return t
	end

	local function panel(parent: Instance, color: Color3, transparency: number, position: UDim2, size: UDim2): Frame
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency
		f.Position = position
		f.Size = size
		f.Parent = parent
		return f
	end

	local function fade(parent: Instance, a: Color3, b: Color3, rotation: number)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(a, b)
		g.Rotation = rotation
		g.Parent = parent
		return g
	end

	local function atlas(parent: Instance, id: string, offset, cell: Vector2, position: UDim2, size: UDim2): ImageLabel
		local image = Instance.new("ImageLabel")
		image.Name = "Arte"
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.Image = id
		image.ImageRectOffset = Vector2.new(offset[1], offset[2])
		image.ImageRectSize = cell
		image.Position = position
		image.Size = size
		image.Parent = parent
		return image
	end

	-- Referencial de uma face de lote: -Z do CFrame aponta para a rua (para fora do prédio), +X corre ao longo da face.
	local function faceFrame(x: number, z: number, w: number, d: number, base: number, face: Enum.NormalId): (CFrame, number, Vector3)
		local n = Vector3.FromNormalId(face)
		local c = Vector3.new(x + n.X * w / 2, base, z + n.Z * d / 2)
		return CFrame.lookAt(c, c + n), if n.X ~= 0 then d else w, n
	end

	-- O mesmo referencial na face de uma peça já criada, na altura da base da peça.
	local function facing(core: BasePart, face: Enum.NormalId): (CFrame, number, number)
		local size, p = core.Size, core.CFrame.Position
		local n = Vector3.FromNormalId(face)
		local c = Vector3.new(p.X + n.X * size.X / 2, p.Y - size.Y / 2, p.Z + n.Z * size.Z / 2)
		return CFrame.lookAt(c, c + n), if n.X ~= 0 then size.Z else size.X, size.Y
	end

	-- Coordenada horizontal (0 a 1) de uma SurfaceGui vista de fora, para um ponto u ao longo de +X do referencial.
	local function guiX(u: number, width: number): number
		return 0.5 - u / width
	end

	local function adCell(ad, vertical: boolean)
		local id = uri(art.anuncios)
		if not id then
			return nil
		end
		if vertical then
			return id, ANUNCIOS.vertical[ad.v], Vector2.new(256, 512)
		end
		return id, ANUNCIOS.horizontal[ad.h], Vector2.new(512, 256)
	end

	-- Tela de anúncio: arte desenhada (atlas) ou composição tipográfica com as cores da marca.
	local function adScreen(gui: SurfaceGui, ad, vertical: boolean)
		local id, offset, cell = adCell(ad, vertical)
		if id then
			atlas(gui, id, offset, cell, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
			return
		end
		local brand, tagline, glow, deep = ad[1], ad[2], ad[3], ad[4]
		local back = panel(gui, Color3.new(1, 1, 1), 0, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
		fade(back, deep:Lerp(glow, 0.32), deep, 90)
		panel(back, glow, 0.1, UDim2.fromScale(0.08, if vertical then 0.1 else 0.17), UDim2.fromScale(0.18, 0.02))
		label(back, brand, FONTS.corporate, Color3.new(1, 1, 1), nil,
			UDim2.fromScale(0.08, if vertical then 0.16 else 0.24), UDim2.fromScale(0.84, if vertical then 0.16 else 0.32))
		label(back, tagline, FONTS.clean, glow:Lerp(Color3.new(1, 1, 1), 0.55), nil,
			UDim2.fromScale(0.08, if vertical then 0.36 else 0.6), UDim2.fromScale(0.84, if vertical then 0.12 else 0.12))
	end

	-- Placa de loja com moldura de néon fina; a vertical usa poucas letras grandes.
	local function streetSign(parent: Instance, text: string, pose: CFrame, w: number, h: number, color: Color3, r, vertical: boolean?)
		piece(parent, "Moldura da placa", Vector3.new(w + 0.4, h + 0.4, 0.3), pose, shade(color, 0.8), M.Neon)
		local plate = piece(parent, "Placa", Vector3.new(w, h, 0.5), pose, rgb(14, 14, 20))
		local copy = text
		if vertical then
			local letters = {}
			for _, code in utf8.codes(text) do
				local char = utf8.char(code)
				if char ~= " " then
					table.insert(letters, char)
				end
			end
			copy = table.concat(letters, "\n")
		end
		local font = if vertical then FONTS.tall else (if r.chance(0.5) then FONTS.clean else FONTS.street)
		for _, face in if vertical then { N.Front, N.Back } else { N.Front } do
			local gui = surface(plate, face, "Letreiro", if vertical then 12 else 10, 1.5, 420)
			local t = label(gui, copy, font, color:Lerp(Color3.new(1, 1, 1), 0.5), color, UDim2.fromScale(0.08, 0.04), UDim2.fromScale(0.84, 0.92))
			t.LineHeight = 0.86
		end
		stats.signs += 1
		return plate
	end

	local function lamp(parent: Instance, x: number, z: number, out: Vector3, color: Color3, lit: boolean, double: boolean?)
		rod(parent, "Poste", x, CURB, CURB + 24, z, 0.7, PALETTE.iron, M.Metal, true)
		box(parent, "Base do poste", x, CURB + 0.6, z, 1.3, 1.2, 1.3, PALETTE.iron, M.Metal)
		for _, dir in if double then { out, -out } else { out } do
			local root0 = Vector3.new(x, CURB + 23.3, z)
			local tip = root0 + dir * 6.2 + Vector3.new(0, 1.1, 0)
			beam(parent, "Braço do poste", root0, tip, 0.32, 0.32, PALETTE.iron, M.Metal)
			local head = piece(parent, "Luminária", Vector3.new(1.3, 0.42, 3.1), CFrame.lookAt(tip, tip + dir) * CFrame.new(0, -0.1, -1.1),
				PALETTE.iron, M.Metal)
			piece(parent, "Lente da luminária", Vector3.new(0.9, 0.06, 2.2), head.CFrame * CFrame.new(0, -0.24, 0), shade(color, 0.9), M.Neon)
			if lit then
				light(head, "SpotLight", color, 1.7, 46, N.Bottom, 118)
			end
		end
	end

	-- Lojas do térreo: vitrine recuada sob a marquise, letreiros na marquise e o interior desenhado no fundo.
	local function storefront(model: Instance, core: BasePart, x: number, z: number, w: number, d: number, base: number, faces, theme, r, mode: string)
		local interiorArt = uri(art.vitrines)
		local coreSize, corePos = core.Size, core.CFrame.Position
		for _, face in faces do
			local front, width, n = faceFrame(x, z, w, d, base, face)
			local spanW = width - 2.4
			local units = if mode == "saguao" then 1 else math.clamp(math.floor(spanW / 18), 1, 5)
			local unitW = spanW / units
			local fascia = piece(model, "Marquise", Vector3.new(width, GF - GLASS_H, INSET + 0.3),
				front * CFrame.new(0, GLASS_H + (GF - GLASS_H) / 2, (INSET + 0.3) / 2 - 0.3), PALETTE.iron, M.Metal, true)
			local signs = surface(fascia, N.Front, "Letreiros", 10, 1.2, 420)
			local glass = piece(model, "Vitrine", Vector3.new(spanW, GLASS_H - 0.3, 0.3), front * CFrame.new(0, 0.3 + (GLASS_H - 0.3) / 2, INSET),
				rgb(40, 52, 70), M.Glass, true)
			glass.Transparency = 0.45
			glass.Reflectance = 0.14
			piece(model, "Luz das lojas", Vector3.new(spanW - 0.6, 0.16, 0.7), front * CFrame.new(0, GLASS_H - 0.3, INSET + DEPTH / 2),
				shade(if mode == "saguao" then PALETTE.led else PALETTE.warm, 0.82), M.Neon)
			if r.chance(0.4) then
				light(fascia, "SurfaceLight", PALETTE.warm, 0.8, 12, N.Bottom, 110)
			end
			-- Fundo das lojas: a face do térreo recuado.
			local coreWidth = if n.X ~= 0 then coreSize.Z else coreSize.X
			local coreCenter = Vector3.new(corePos.X + n.X * coreSize.X / 2, base, corePos.Z + n.Z * coreSize.Z / 2)
			local interior = surface(core, face, "Interiores", 6, 1.05, 320)
			for k = 0, units do
				local u = -spanW / 2 + k * unitW
				piece(model, "Pilar", Vector3.new(1.4, GF, 1.4), front * CFrame.new(u, GF / 2, 0.7), PALETTE.concrete, M.Concrete, true)
				if k > 0 and k < units then
					piece(model, "Divisória", Vector3.new(0.4, GLASS_H, DEPTH), front * CFrame.new(u, GLASS_H / 2, INSET + DEPTH / 2), PALETTE.ink)
				end
			end
			for k = 1, units do
				local u = -spanW / 2 + (k - 0.5) * unitW
				local shop = if mode == "saguao" then { theme.brand or "SAGUÃO", "saguao", "" } else r.pick(SHOPS)
				local color = r.pick(theme.signs)
				local closed = mode ~= "saguao" and r.chance(0.22)
				label(signs, shop[1], if r.chance(0.55) then FONTS.tall else FONTS.clean, color:Lerp(Color3.new(1, 1, 1), 0.62), nil,
					UDim2.fromScale(guiX(u + unitW / 2 - 0.6, width), 0.14), UDim2.fromScale((unitW - 1.2) / width, 0.72))
				local world = front * Vector3.new(u, 0, 0)
				local uc = (world - coreCenter):Dot(front.RightVector)
				local position = UDim2.fromScale(guiX(uc + unitW / 2 - 0.3, coreWidth), (GF - GLASS_H) / GF)
				local size = UDim2.fromScale((unitW - 0.6) / coreWidth, GLASS_H / GF)
				if closed then
					local corrugated = uri(art.metal_ondulado) ~= nil
					local shutter = piece(model, "Porta de aço", Vector3.new(GLASS_H - 0.4, unitW - 0.5, 0.2),
						front * CFrame.new(u, 0.2 + (GLASS_H - 0.4) / 2, INSET - 0.3) * CFrame.Angles(0, 0, math.pi / 2), rgb(84, 88, 96), M.Metal)
					if corrugated then
						pbr(shutter, "metal_ondulado", N.Front, 6, rgb(200, 204, 214), 0)
					else
						local slats = panel(surface(shutter, N.Front, "Ripas", 8, 1, 200), Color3.new(1, 1, 1), 0, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
						slats.Parent.LightInfluence = 1
						local keys = {}
						for s = 0, 9 do
							table.insert(keys, ColorSequenceKeypoint.new(s / 10, rgb(150, 154, 162)))
							table.insert(keys, ColorSequenceKeypoint.new(s / 10 + 0.07, rgb(96, 100, 108)))
						end
						keys[#keys] = ColorSequenceKeypoint.new(1, rgb(96, 100, 108))
						local g = Instance.new("UIGradient")
						g.Color = ColorSequence.new(keys)
						g.Rotation = 0
						g.Parent = slats
					end
				else
					if interiorArt then
						atlas(interior, interiorArt, VITRINES[shop[2]], Vector2.new(512, 256), position, size)
					else
						local room = panel(interior, Color3.new(1, 1, 1), 0, position, size)
						fade(room, color:Lerp(PALETTE.warm, 0.7), shade(color, 0.35), 90)
						for s = 1, 3 do
							panel(room, PALETTE.ink, 0.2, UDim2.fromScale(0.08, 0.22 + s * 0.17), UDim2.fromScale(0.84, 0.035))
						end
						panel(room, PALETTE.ink, 0.1, UDim2.fromScale(0.3, 0.78), UDim2.fromScale(0.4, 0.22))
					end
					if mode ~= "saguao" and r.chance(0.3) then
						-- Toldo de lona inclinado para a calçada.
						local cloth = r.pick(theme.fabric)
						piece(model, "Toldo", Vector3.new(unitW - 1.2, 0.25, 4.6), front * CFrame.new(u, GLASS_H - 0.62, -2.4) * CFrame.Angles(math.rad(-16), 0, 0),
							cloth, M.Fabric)
					end
				end
				if mode ~= "saguao" and r.chance(0.28) then
					local words = utf8.len(shop[3]) or 4
					local h = words * 2.9 + 1.4
					local pose = front * CFrame.new(u + unitW * 0.32, GF + 1.2 + h / 2, -3.4) * CFrame.Angles(0, math.pi / 2, 0)
					streetSign(model, shop[3], pose, 4.2, h, color, r, true)
				elseif not closed and r.chance(0.2) then
					-- Letras-caixa luminosas presas na fachada, acima da marquise.
					local plate = piece(model, "Letras luminosas", Vector3.new(math.min(unitW * 0.92, 16), 3.4, 0.1),
						front * CFrame.new(u, GF + 3, -0.15), color)
					plate.Transparency = 1
					local gui = surface(plate, N.Front, "Letras", 14, 1.6, 380)
					local t = label(gui, shop[1], FONTS.street, color:Lerp(Color3.new(1, 1, 1), 0.35), color)
					t.TextStrokeTransparency = 0.2
				end
			end
		end
	end

	-- Térreo: bloco recuado nas faces de rua e lojas na frente; nas outras faces, parede cega.
	local function podium(model: Instance, x: number, z: number, w: number, d: number, base: number, faces, theme, r, mode: string)
		local cut = INSET + DEPTH
		local x0, x1, z0, z1 = x - w / 2, x + w / 2, z - d / 2, z + d / 2
		for _, face in faces do
			if face == N.Front then
				z0 += cut
			elseif face == N.Back then
				z1 -= cut
			elseif face == N.Left then
				x0 += cut
			elseif face == N.Right then
				x1 -= cut
			end
		end
		local core = span(model, "Térreo", x0, x1, base, base + GF, z0, z1, rgb(34, 35, 44), M.Concrete, true)
		storefront(model, core, x, z, w, d, base, faces, theme, r, mode)
	end

	-- Janelas por quadro desenhado por código; sem a imagem, faixas de andar em geometria.
	local function facade(model: Instance, core: BasePart, style: string, faces, accent: Color3, floorsPerBand: number?)
		local id = uri(art[WINDOW_ART[style]])
		local size = core.Size
		local x, z = core.CFrame.Position.X, core.CFrame.Position.Z
		local y0, y1 = core.CFrame.Position.Y - size.Y / 2, core.CFrame.Position.Y + size.Y / 2
		-- Sorteio próprio da fachada: a cidade fica igual com ou sem as imagens aprovadas.
		local r = random(math.floor(math.abs(x * 31 + z * 17 + y0 * 7 + size.Y)) + SEED)
		if id then
			local shiftX, shiftY = r.int(0, 15) * 6, r.int(0, 7) * FLOOR
			for _, face in faces do
				local gui = surface(core, face, "Janelas", 2, if style == "residencial" then 1.2 else 1.0, 2600)
				gui.LightInfluence = 0.12
				local image = Instance.new("ImageLabel")
				image.Name = "Quadro de janelas"
				image.BackgroundTransparency = 1
				image.BorderSizePixel = 0
				image.Image = id
				image.ScaleType = Enum.ScaleType.Tile
				image.TileSize = UDim2.fromOffset(TILE_STUDS.X * 2, TILE_STUDS.Y * 2)
				image.Position = UDim2.fromOffset(-shiftX * 2, -shiftY * 2)
				image.Size = UDim2.new(1, shiftX * 2, 1, shiftY * 2)
				image.Parent = gui
			end
			return
		end
		local warm = { rgb(150, 96, 52), rgb(132, 84, 46), rgb(96, 64, 40) }
		local cool = { rgb(104, 124, 150), rgb(86, 110, 140) }
		for y = y0 + FLOOR, y1 - 3, FLOOR * (floorsPerBand or 2) do
			if r.chance(if style == "residencial" then 0.3 else 0.24) then
				local tone = if style == "residencial" or style == "painel" then r.pick(warm) else r.pick(cool)
				box(model, "Andar aceso", x, y + 5, z, size.X + 0.2, 3.2, size.Z + 0.2, tone, M.Neon)
			end
		end
		if r.chance(0.4) then
			box(model, "Faixa de destaque", x, y1 - FLOOR * 0.5, z, size.X + 0.25, 0.8, size.Z + 0.25, shade(accent, 0.75), M.Neon)
		end
	end

	-- Relevo: frisos de laje em volta do volume e pilastras ou aletas nas faces de rua.
	local function relief(model: Instance, core: BasePart, style: string, faces)
		local size, p = core.Size, core.CFrame.Position
		local y0 = p.Y - size.Y / 2
		local floors = math.floor(size.Y / FLOOR + 0.01)
		local every = if style == "vidro" then 4 elseif style == "residencial" then 2 elseif style == "painel" then 3 else 3
		local tone = if style == "vidro" then rgb(36, 40, 50) elseif style == "painel" then rgb(52, 54, 60) else rgb(96, 94, 100)
		local thick = if style == "vidro" then 0.5 elseif style == "painel" then 1.6 else 1.0
		for f = every, floors - 1, every do
			box(model, "Friso", p.X, y0 + f * FLOOR, p.Z, size.X + 1.1, thick, size.Z + 1.1, tone, if style == "vidro" then M.Metal else M.Concrete)
		end
		if style == "painel" then
			return
		end
		local spacing = if style == "vidro" then 12 elseif style == "residencial" then 24 else 18
		local finW, finD = if style == "vidro" then 0.45 else 1.1, if style == "vidro" then 1.3 else 0.7
		for _, face in faces do
			local front, width, height = facing(core, face)
			local count = math.max(2, math.floor(width / spacing))
			for k = 1, count - 1 do
				local u = -width / 2 + k * width / count
				piece(model, if style == "vidro" then "Aleta" else "Pilastra", Vector3.new(finW, height, finD),
					front * CFrame.new(u, height / 2, -finD / 2), tone, if style == "vidro" then M.Metal else M.Concrete)
			end
		end
	end

	-- Aparelhos de ar-condicionado e um cano de descida nas faces de rua dos prédios baixos.
	local function clutter(model: Instance, core: BasePart, faces, r, amount: number)
		for _, face in faces do
			local front, width, height = facing(core, face)
			local floors = math.floor(height / FLOOR + 0.01)
			local count = math.min(12, math.floor(width * floors / 300 * amount))
			for _ = 1, count do
				local f = r.int(0, math.max(0, floors - 1))
				local u = r.range(-width / 2 + 3, width / 2 - 3)
				piece(model, "Ar-condicionado", Vector3.new(2.6, 1.8, 1.4), front * CFrame.new(u, f * FLOOR + 2.4, -0.7), rgb(146, 148, 152), M.Metal)
			end
			if r.chance(0.55) then
				local u = (if r.chance(0.5) then -1 else 1) * (width / 2 - 1.3)
				piece(model, "Cano", Vector3.new(height, 0.7, 0.7), front * CFrame.new(u, height / 2, -0.5) * CFrame.Angles(0, 0, math.pi / 2),
					rgb(58, 60, 66), M.Metal, false, Enum.PartType.Cylinder)
			end
		end
	end

	local function fireEscape(model: Instance, core: BasePart, face: Enum.NormalId, r)
		local front, width, height = facing(core, face)
		local floors = math.floor(height / FLOOR + 0.01)
		if floors < 3 or width < 24 then
			return
		end
		local u = r.range(-width / 2 + 7, width / 2 - 7)
		local steel = rgb(46, 48, 56)
		for f = 1, floors - 1 do
			local y = f * FLOOR - 0.15
			piece(model, "Patamar da escada", Vector3.new(9, 0.25, 3.2), front * CFrame.new(u, y, -1.6), steel, M.Metal)
			piece(model, "Guarda-corpo", Vector3.new(9, 0.18, 0.18), front * CFrame.new(u, y + 1.7, -3.15), steel, M.Metal)
			if f < floors - 1 then
				local side = if f % 2 == 0 then 1 else -1
				local a = front * Vector3.new(u + side * 3.4, y + 0.1, -1.6)
				local b = front * Vector3.new(u - side * 3.4, y + FLOOR, -1.6)
				beam(model, "Lance da escada", a, b, 1.5, 0.22, steel, M.Metal)
			end
		end
	end

	-- Cobertura: platibanda, exaustores, caixa d'água, antena e, às vezes, um outdoor virado para a rua.
	local function roof(model: Instance, x: number, top: number, z: number, w: number, d: number, r, face: Enum.NormalId?)
		local tone = rgb(74, 74, 80)
		for _, e in { { 0, -d / 2 + 0.3, w, 0.6 }, { 0, d / 2 - 0.3, w, 0.6 }, { -w / 2 + 0.3, 0, 0.6, d - 1.2 }, { w / 2 - 0.3, 0, 0.6, d - 1.2 } } do
			box(model, "Platibanda", x + e[1], top + 1.1, z + e[2], e[3], 2.2, e[4], tone, M.Concrete)
		end
		for _ = 1, r.int(1, 3) do
			local hw, hd = r.range(4, math.max(5, w * 0.18)), r.range(4, math.max(5, d * 0.18))
			box(model, "Exaustor", x + r.range(-0.3, 0.3) * w, top + 1.6, z + r.range(-0.3, 0.3) * d, hw, 3.2, hd, rgb(118, 120, 126), M.Metal, true)
		end
		if r.chance(0.55) then
			local tx, tz = x + r.range(-0.3, 0.3) * w, z + r.range(-0.3, 0.3) * d
			box(model, "Base da caixa d'água", tx, top + 1.2, tz, 7, 2.4, 7, rgb(60, 60, 66), M.Metal, true)
			rod(model, "Caixa d'água", tx, top + 2.4, top + 9.4, tz, 6.4, rgb(110, 98, 86), M.Wood, true)
		end
		if r.chance(0.4) then
			local ax, az = x + r.range(-0.35, 0.35) * w, z + r.range(-0.35, 0.35) * d
			local height = r.range(10, 22)
			rod(model, "Antena", ax, top, top + height, az, 0.5, PALETTE.steel, M.Metal)
			box(model, "Luz da antena", ax, top + height + 0.4, az, 0.8, 0.8, 0.8, PALETTE.red, M.Neon)
		end
		if face and r.chance(0.3) and math.min(w, d) > 30 then
			local front, width = faceFrame(x, z, w, d, top, face)
			local bw = math.min(width * 0.7, 42)
			local bh = bw * 0.5
			for _, side in { -1, 1 } do
				piece(model, "Pé do outdoor", Vector3.new(0.8, 8, 0.8), front * CFrame.new(side * bw * 0.35, 4, 4), PALETTE.iron, M.Metal)
			end
			piece(model, "Treliça do outdoor", Vector3.new(bw, bh, 1.2), front * CFrame.new(0, 8 + bh / 2, 4.8), PALETTE.iron, M.Metal)
			local screen = piece(model, "Outdoor", Vector3.new(bw - 1, bh - 1, 0.3), front * CFrame.new(0, 8 + bh / 2, 4.1), PALETTE.ink)
			adScreen(surface(screen, N.Front, "Anúncio", math.clamp(220 / bw, 3, 8), 1.35, 1600), r.pick(ADS), false)
		end
	end

	local function crown(model: Instance, x: number, top: number, z: number, w: number, d: number, accent: Color3, r)
		local kind = r.int(1, 4)
		box(model, "Casa de máquinas", x + r.range(-0.2, 0.2) * w, top + 4, z + r.range(-0.2, 0.2) * d,
			w * r.range(0.3, 0.45), 8, d * r.range(0.3, 0.45), PALETTE.iron, M.Metal, true)
		for _, edge in { { 0, d / 2 }, { 0, -d / 2 }, { w / 2, 0 }, { -w / 2, 0 } } do
			box(model, "Contorno de LED da cobertura", x + edge[1], top + 0.5, z + edge[2],
				if edge[1] == 0 then w + 0.4 else 0.35, 0.35, if edge[2] == 0 then d + 0.4 else 0.35, shade(accent, 0.8), M.Neon)
		end
		if kind == 1 then
			local height = r.range(50, 130)
			rod(model, "Agulha", x, top, top + height, z, 2.2, PALETTE.steel, M.Metal)
			box(model, "Baliza de aviação", x, top + height + 1, z, 2.2, 1.6, 2.2, PALETTE.red, M.Neon)
		elseif kind == 2 then
			local radius = math.min(w, d) * 0.36
			piece(model, "Heliponto", Vector3.new(1.2, radius * 2, radius * 2), CFrame.new(x, top + 9, z) * CFrame.Angles(0, 0, math.pi / 2),
				PALETTE.steel, M.Concrete, true, Enum.PartType.Cylinder)
			box(model, "Marca do heliponto", x, top + 9.65, z, radius * 0.18, 0.1, radius * 0.9, PALETTE.white, M.SmoothPlastic)
			box(model, "Marca do heliponto", x, top + 9.65, z, radius * 0.6, 0.1, radius * 0.18, PALETTE.white, M.SmoothPlastic)
			for _, side in { -1, 1 } do
				box(model, "Marca do heliponto", x + side * radius * 0.3, top + 9.65, z, radius * 0.18, 0.1, radius * 0.9, PALETTE.white, M.SmoothPlastic)
			end
		elseif kind == 3 then
			local cw, cd = w * 0.62, d * 0.62
			box(model, "Coroa escalonada", x, top + 9, z, cw, 18, cd, PALETTE.glass, M.Glass, true).Reflectance = 0.25
			for _, edge in { { 0, cd / 2 }, { 0, -cd / 2 }, { cw / 2, 0 }, { -cw / 2, 0 } } do
				box(model, "Contorno da coroa", x + edge[1], top + 18.2, z + edge[2],
					if edge[1] == 0 then cw + 0.4 else 0.4, 0.5, if edge[2] == 0 then cd + 0.4 else 0.4, shade(accent, 0.85), M.Neon)
			end
		else
			for _, side in { -1, 1 } do
				local height = r.range(20, 44)
				rod(model, "Antena", x + side * w * 0.3, top, top + height, z - side * d * 0.25, 0.8, PALETTE.steel, M.Metal)
				box(model, "Luz da antena", x + side * w * 0.3, top + height + 0.6, z - side * d * 0.25, 1.1, 1.1, 1.1, PALETTE.red, M.Neon)
			end
		end
	end

	-- Painel de LED preso a uma fachada, com moldura e respiro.
	local function billboard(parent: Instance, pose: CFrame, w: number, h: number, ad, vertical: boolean?)
		piece(parent, "Estrutura do painel", Vector3.new(w + 1.6, h + 1.6, 1.4), pose * CFrame.new(0, 0, 0.9), PALETTE.iron, M.Metal)
		local screen = piece(parent, "Painel de LED", Vector3.new(w, h, 0.4), pose, ad[4])
		adScreen(surface(screen, N.Front, "Anúncio", math.clamp(260 / w, 2.5, 8), 1.35, 2200), ad, vertical == true)
		return screen
	end

	-- Tambor de anúncios num mastro: doze telas formam um cilindro que mostra duas campanhas.
	local function adDrum(parent: Instance, x: number, z: number, base: number, mast: number, radius: number, r)
		rod(parent, "Mastro do tambor", x, base, base + mast, z, 2.4, PALETTE.iron, M.Metal, true)
		local height = radius * 1.15
		local y = base + mast + height / 2
		local first, second = r.pick(ADS), r.pick(ADS)
		local sides = 12
		local panelW = 2 * radius * math.tan(math.pi / sides) + 0.1
		local id = uri(art.anuncios)
		for k = 0, sides - 1 do
			local a = (k + 0.5) / sides * math.pi * 2
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local center = Vector3.new(x, y, z) + out * radius
			local screen = piece(parent, "Tela do tambor", Vector3.new(panelW, height, 0.4), CFrame.lookAt(center, center + out), PALETTE.ink)
			local gui = surface(screen, N.Front, "Anúncio", math.clamp(160 / panelW, 4, 16), 1.4, 1400)
			local ad = if k < sides / 2 then first else second
			local slice = k % (sides / 2)
			if id then
				local offset = ANUNCIOS.horizontal[ad.h]
				local cell = 512 / (sides / 2)
				atlas(gui, id, { offset[1] + (sides / 2 - 1 - slice) * cell, offset[2] }, Vector2.new(cell, 256), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
			else
				local back = panel(gui, Color3.new(1, 1, 1), 0, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
				fade(back, ad[4]:Lerp(ad[3], 0.35), ad[4], 90)
				if slice == 2 then
					label(back, ad[1], FONTS.corporate, Color3.new(1, 1, 1), nil, UDim2.fromScale(0, 0.3), UDim2.fromScale(1, 0.4))
				end
			end
		end
		for _, dy in { -height / 2 - 0.4, height / 2 + 0.4 } do
			piece(parent, "Aro do tambor", Vector3.new(0.8, radius * 2 + 1.2, radius * 2 + 1.2), CFrame.new(x, y + dy, z) * CFrame.Angles(0, 0, math.pi / 2),
				PALETTE.iron, M.Metal, false, Enum.PartType.Cylinder)
		end
	end

	local function tower(model: Instance, spec, r, theme)
		-- spec: x, z, w, d, base, height, style, accent, faces (faces de rua), tiers, led, ad, lobby
		local x, z, w, d = spec.x, spec.z, spec.w, spec.d
		local streetFaces = spec.faces or {}
		local y = spec.base
		local remaining = spec.height
		if #streetFaces > 0 and spec.base <= CURB + 0.01 then
			podium(model, x, z, w, d, spec.base, streetFaces, theme, r, if spec.lobby then "saguao" else "lojas")
			y += GF
			remaining -= GF
		end
		local top = y + remaining
		local tiers = spec.tiers or 1
		local style = spec.style
		local material = if style == "vidro" then M.Glass else M.Concrete
		local color = if style == "vidro" then PALETTE.glass elseif style == "escritorio" then rgb(54, 58, 70) else rgb(70, 64, 66)
		local tierW, tierD = w, d
		local all = { N.Front, N.Back, N.Left, N.Right }
		for tier = 1, tiers do
			local h = if tier == tiers then remaining else math.floor(remaining * r.range(0.45, 0.6) / FLOOR) * FLOOR
			remaining -= h
			local core = box(model, if tier == 1 then "Torre" else "Recuo da torre", x, y + h / 2, z, tierW, h, tierD, color, material, true)
			if style == "vidro" then
				core.Reflectance = 0.2
			end
			facade(model, core, style, all, spec.accent)
			relief(model, core, style, if tier == 1 and #streetFaces > 0 then streetFaces else all)
			if style == "residencial" and tier == 1 then
				clutter(model, core, streetFaces, r, 0.6)
			end
			if spec.led and tier == 1 then
				for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
					box(model, "Fita de LED", x + corner[1] * (tierW / 2 + 0.2), y + h / 2, z + corner[2] * (tierD / 2 + 0.2),
						0.45, h, 0.45, shade(spec.accent, 0.8), M.Neon)
				end
			end
			y += h
			if tier < tiers then
				box(model, "Terraço do recuo", x, y + 0.6, z, tierW + 1, 1.2, tierD + 1, PALETTE.concrete, M.Concrete, true)
				tierW *= r.range(0.72, 0.86)
				tierD *= r.range(0.72, 0.86)
			end
		end
		crown(model, x, top, z, tierW, tierD, spec.accent, r)
		if spec.ad and #streetFaces > 0 then
			local front, width = faceFrame(x, z, w, d, spec.base, streetFaces[1])
			local vertical = r.chance(0.5)
			local bw = if vertical then math.min(width * 0.36, 40) else math.min(width * 0.7, 66)
			local bh = if vertical then bw * 2 else bw * 0.5
			billboard(model, front * CFrame.new(0, spec.height * r.range(0.22, 0.4), -1.9), bw, bh, spec.ad, vertical)
		end
		stats.towers += 1
	end

	local function midrise(model: Instance, x: number, z: number, w: number, d: number, height: number, faces, r, style: string, dense: boolean, theme)
		local base = CURB
		local y = base
		if #faces > 0 then
			podium(model, x, z, w, d, base, faces, theme, r, "lojas")
			y += GF
		end
		local volumes = if dense then r.int(2, 3) else r.int(1, 2)
		local cw, cd, cx, cz = w, d, x, z
		for index = 1, volumes do
			local h = if index == volumes then math.max(FLOOR * 2, base + height - y)
				else math.max(FLOOR * 2, math.floor((height - GF) / volumes / FLOOR) * FLOOR)
			local tint = rgb(66, 62, 66):Lerp(r.pick(theme.accents), 0.06)
			local core = box(model, if index == 1 then "Bloco" else "Bloco empilhado", cx, y + h / 2, cz, cw, h, cd, tint, M.Brick, true)
			-- Tijolo de foto (Poly Haven, CC0) em volta; as janelas desenhadas ficam por cima.
			for _, face in { N.Front, N.Back, N.Left, N.Right } do
				pbr(core, "tijolo", face, 8, rgb(196, 188, 190), 0)
			end
			local front = if #faces > 0 then faces else { N.Front }
			facade(model, core, style, front, r.pick(theme.accents))
			relief(model, core, "residencial", front)
			clutter(model, core, front, r, if dense then 1.2 else 0.8)
			if index == 1 and r.chance(0.35) then
				fireEscape(model, core, front[1], r)
			end
			y += h
			if index < volumes then
				cw *= r.range(0.72, 0.95)
				cd *= r.range(0.72, 0.95)
				cx += r.range(-0.1, 0.1) * w
				cz += r.range(-0.1, 0.1) * d
			end
		end
		roof(model, cx, y, cz, cw, cd, r, faces[1])
	end

	-- Megaprédio: painéis modulares, frisos fortes, treliças de aço nas quinas e o número do bloco no topo.
	local function megablock(model: Instance, x: number, z: number, w: number, d: number, spec, faces, r, theme)
		local base = CURB
		podium(model, x, z, w, d, base, faces, theme, r, "lojas")
		local y0, top = base + GF, base + spec.height
		local core = box(model, "Megaprédio", x, (y0 + top) / 2, z, w, top - y0, d, rgb(58, 60, 66), M.Concrete, true)
		facade(model, core, "painel", { N.Front, N.Back, N.Left, N.Right }, PALETTE.amber, 3)
		relief(model, core, "painel", {})
		local steel = rgb(46, 48, 54)
		for _, corner in { { -1, -1 }, { 1, 1 } } do
			-- Torre de treliça: quatro montantes e diagonais em X nas duas faces de fora.
			local cx, cz = x + corner[1] * (w / 2 + 3), z + corner[2] * (d / 2 + 3)
			for _, m in { { -2.5, -2.5 }, { 2.5, -2.5 }, { -2.5, 2.5 }, { 2.5, 2.5 } } do
				box(model, "Montante da treliça", cx + m[1], (y0 + top) / 2, cz + m[2], 1, top - y0, 1, steel, M.Metal, true)
			end
			for y = y0, top - 28, 28 do
				for _, face in { { corner[1], 0 }, { 0, corner[2] } } do
					local fx, fz = cx + face[1] * 2.5, cz + face[2] * 2.5
					local tx, tz = face[2] ~= 0 and 1 or 0, face[1] ~= 0 and 1 or 0
					local a = Vector3.new(fx - tx * 2.5, y, fz - tz * 2.5)
					local b = Vector3.new(fx + tx * 2.5, y + 28, fz + tz * 2.5)
					beam(model, "Diagonal da treliça", a, b, 0.5, 0.5, steel, M.Metal)
					beam(model, "Diagonal da treliça", Vector3.new(b.X, y, b.Z), Vector3.new(a.X, y + 28, a.Z), 0.5, 0.5, steel, M.Metal)
				end
			end
		end
		for _, face in { N.Front, N.Right } do
			local front, width = facing(core, face)
			local plate = piece(model, "Número do bloco", Vector3.new(width * 0.34, width * 0.26, 0.2),
				front * CFrame.new(width * 0.24, (top - y0) - width * 0.2, -0.3), rgb(20, 20, 24))
			plate.Transparency = 1
			local gui = surface(plate, N.Front, "Número", 3, 1.6, 4000)
			label(gui, spec.number, FONTS.heavy, rgb(238, 232, 220), nil)
		end
		for _, edge in { { 0, d / 2 }, { 0, -d / 2 }, { w / 2, 0 }, { -w / 2, 0 } } do
			box(model, "Contorno do megaprédio", x + edge[1], top + 0.3, z + edge[2],
				if edge[1] == 0 then w + 0.4 else 0.4, 0.4, if edge[2] == 0 then d + 0.4 else 0.4, shade(PALETTE.amber, 0.8), M.Neon)
		end
		roof(model, x, top, z, w, d, r, nil)
		stats.towers += 1
	end

	local function warehouse(model: Instance, x: number, z: number, w: number, d: number, faces, r)
		local h = r.range(30, 46)
		local tone = r.pick({ rgb(52, 70, 74), rgb(78, 74, 70), rgb(66, 66, 72), rgb(44, 54, 76) })
		local shed = box(model, "Galpão", x, CURB + h / 2, z, w, h, d, tone, M.Metal, true)
		for _, face in { N.Front, N.Back, N.Left, N.Right } do
			pbr(shed, "metal_ondulado", face, 10, tone:Lerp(Color3.new(1, 1, 1), 0.55), 0)
		end
		box(model, "Cumeeira", x, CURB + h + 2, z, w * 0.96, 4, d * 0.5, tone:Lerp(PALETTE.ink, 0.3), M.Metal, true)
		for _, face in faces do
			local front, width = faceFrame(x, z, w, d, CURB, face)
			local doors = math.max(1, math.floor(width / 34))
			for k = 1, doors do
				local offset = (k - (doors + 1) / 2) * (width / doors)
				piece(model, "Porta de enrolar", Vector3.new(16, 18, 0.6), front * CFrame.new(offset, 9, -0.2), PALETTE.steel, M.Metal)
				local lampPart = piece(model, "Refletor", Vector3.new(2.4, 0.8, 1.2), front * CFrame.new(offset, 21, -0.8), shade(PALETTE.sodium, 0.85), M.Neon)
				if k == 1 then
					light(lampPart, "SpotLight", PALETTE.sodium, 2, 34, N.Bottom, 120)
				end
			end
			local plate = piece(model, "Pintura da empresa", Vector3.new(math.min(width - 6, 60), 7, 0.2),
				front * CFrame.new(0, h - 6, -0.1), tone:Lerp(PALETTE.ink, 0.5))
			local gui = surface(plate, N.Front, "Nome do galpão", 8, 1.1, 600)
			gui.LightInfluence = 1
			label(gui, r.pick({ "MARÉ LOGÍSTICA", "CONTÊINERES IARA", "FRIGORÍFICO 9", "CARGA PESADA ROTOR", "ALFÂNDEGA SUL" }),
				FONTS.heavy, rgb(210, 206, 196))
		end
	end

	local function containers(model: Instance, x0: number, x1: number, z0: number, z1: number, r)
		local colors = { rgb(160, 58, 44), rgb(40, 92, 128), rgb(196, 140, 40), rgb(46, 110, 76), rgb(120, 120, 126), rgb(140, 40, 90) }
		for x = x0 + 22, x1 - 22, 40 do
			for z = z0 + 6, z1 - 6, 9 do
				if r.chance(0.82) then
					local stack = r.int(1, 4)
					for level = 1, stack do
						box(model, "Contêiner", x, CURB + 3.7 + (level - 1) * 7.5, z, 35, 7.4, 7.2, r.pick(colors), M.CorrodedMetal, true)
					end
				end
			end
		end
	end

	-- Objetos de rua -------------------------------------------------------------------------------
	local props = {}

	function props.palm(parent: Instance, x: number, z: number, r, base: number?)
		local y = base or CURB
		local height = r.range(22, 30)
		local lean = Vector3.new(r.range(-1, 1), 0, r.range(-1, 1)) * 0.7
		local p0 = Vector3.new(x, y, z)
		local p1 = p0 + Vector3.new(0, height * 0.55, 0) + lean * 0.35
		local p2 = p0 + Vector3.new(0, height, 0) + lean
		beam(parent, "Tronco da palmeira", p0, p1, 1.1, 1.1, rgb(86, 72, 60), M.Wood, true)
		beam(parent, "Tronco da palmeira", p1, p2, 0.85, 0.85, rgb(86, 72, 60), M.Wood)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2 + r.range(-0.25, 0.25)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			beam(parent, "Folha da palmeira", p2, p2 + dir * 8.5 + Vector3.new(0, -3.2, 0), 2.2, 0.14, rgb(44, 76, 50), M.Grass)
		end
		stats.props += 1
	end

	function props.tree(parent: Instance, x: number, z: number, r)
		rod(parent, "Tronco", x, CURB, CURB + 8, z, 0.9, rgb(62, 50, 44), M.Wood, true)
		piece(parent, "Copa", Vector3.new(9, 8, 9) * r.range(0.85, 1.15), CFrame.new(x, CURB + 11, z), rgb(38, 66, 50), M.Grass, false, Enum.PartType.Ball)
		box(parent, "Canteiro da árvore", x, CURB + 0.08, z, 4, 0.16, 4, rgb(40, 34, 30), M.Ground)
		stats.props += 1
	end

	function props.hydrant(parent: Instance, x: number, z: number)
		rod(parent, "Hidrante", x, CURB, CURB + 2.2, z, 1, rgb(176, 36, 38), M.Metal, true)
		piece(parent, "Tampa do hidrante", Vector3.new(1.1, 1.1, 1.1), CFrame.new(x, CURB + 2.25, z), rgb(150, 30, 32), M.Metal, false, Enum.PartType.Ball)
		stats.props += 1
	end

	function props.trash(parent: Instance, x: number, z: number, r)
		local tone = r.pick({ rgb(40, 62, 52), rgb(52, 54, 60), rgb(70, 46, 34) })
		rod(parent, "Lixeira", x, CURB, CURB + 2.6, z, 1.7, tone, M.Metal, true)
		rod(parent, "Tampa da lixeira", x, CURB + 2.6, CURB + 2.8, z, 1.9, tone:Lerp(PALETTE.ink, 0.3), M.Metal)
		stats.props += 1
	end

	function props.bench(parent: Instance, x: number, z: number, along: Vector3, out: Vector3)
		local pose = CFrame.lookAt(Vector3.new(x, CURB + 1.4, z), Vector3.new(x, CURB + 1.4, z) + out)
		piece(parent, "Banco", Vector3.new(6, 0.35, 1.8), pose, rgb(70, 58, 48), M.Wood, true)
		piece(parent, "Encosto do banco", Vector3.new(6, 1.4, 0.25), pose * CFrame.new(0, 0.9, 0.85), rgb(70, 58, 48), M.Wood)
		piece(parent, "Pés do banco", Vector3.new(5, 1.2, 1.2), pose * CFrame.new(0, -0.8, 0), PALETTE.iron, M.Metal)
		local _ = along
		stats.props += 1
	end

	function props.vending(parent: Instance, x: number, z: number, out: Vector3, color: Color3, r)
		local pose = CFrame.lookAt(Vector3.new(x, CURB + 3.5, z), Vector3.new(x, CURB + 3.5, z) + out)
		piece(parent, "Máquina de venda", Vector3.new(3.6, 7, 2.6), pose, rgb(30, 32, 40), M.Metal, true)
		local front = piece(parent, "Vitrine da máquina", Vector3.new(3.1, 5.8, 0.1), pose * CFrame.new(0, 0.3, -1.33), shade(color, 0.6))
		local gui = surface(front, N.Front, "Produtos", 20, 1.3, 220)
		local back = panel(gui, Color3.new(1, 1, 1), 0, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
		fade(back, color:Lerp(Color3.new(1, 1, 1), 0.5), shade(color, 0.5), 90)
		for row = 0, 3 do
			panel(back, PALETTE.ink, 0.35, UDim2.fromScale(0.06, 0.12 + row * 0.2), UDim2.fromScale(0.62, 0.012))
			for col = 0, 3 do
				panel(back, r.pick({ PALETTE.red, PALETTE.cyan, PALETTE.amber, PALETTE.white }), 0.1,
					UDim2.fromScale(0.08 + col * 0.15, 0.03 + row * 0.2), UDim2.fromScale(0.09, 0.085))
			end
		end
		panel(back, PALETTE.ink, 0.2, UDim2.fromScale(0.74, 0.1), UDim2.fromScale(0.2, 0.5))
		stats.props += 1
	end

	function props.newsbox(parent: Instance, x: number, z: number, out: Vector3, r)
		local pose = CFrame.lookAt(Vector3.new(x, CURB + 1.6, z), Vector3.new(x, CURB + 1.6, z) + out)
		piece(parent, "Caixa de jornal", Vector3.new(2, 3.2, 1.6), pose, r.pick({ rgb(40, 70, 130), rgb(170, 40, 40), rgb(200, 160, 40) }), M.Metal, true)
		stats.props += 1
	end

	function props.dumpster(parent: Instance, x: number, z: number, out: Vector3, r)
		local pose = CFrame.lookAt(Vector3.new(x, CURB + 2.3, z), Vector3.new(x, CURB + 2.3, z) + out)
		local tone = r.pick({ rgb(34, 70, 52), rgb(36, 52, 86), rgb(90, 50, 30) })
		piece(parent, "Caçamba", Vector3.new(8, 4.6, 4.4), pose, tone, M.Metal, true)
		piece(parent, "Tampa da caçamba", Vector3.new(8.2, 0.3, 4.6), pose * CFrame.new(0, 2.5, 0.2) * CFrame.Angles(math.rad(-6), 0, 0), tone:Lerp(PALETTE.ink, 0.4), M.Plastic)
		for k = 1, r.int(1, 3) do
			piece(parent, "Saco de lixo", Vector3.new(1.8, 1.6, 1.8) * r.range(0.8, 1.2), pose * CFrame.new(-5.2 + k * 1.3, -1.5, -1.6),
				rgb(18, 18, 22), M.Plastic, false, Enum.PartType.Ball)
		end
		stats.props += 1
	end

	function props.busStop(parent: Instance, x: number, z: number, out: Vector3, ad)
		local pose = CFrame.lookAt(Vector3.new(x, CURB, z), Vector3.new(x, CURB, z) + out)
		piece(parent, "Cobertura do ponto", Vector3.new(12, 0.3, 4.6), pose * CFrame.new(0, 7.6, 0.6), PALETTE.iron, M.Metal)
		local back = piece(parent, "Vidro do ponto", Vector3.new(11, 6.4, 0.2), pose * CFrame.new(0, 4, 2.6), rgb(60, 80, 100), M.Glass, true)
		back.Transparency = 0.55
		for _, side in { -1, 1 } do
			piece(parent, "Coluna do ponto", Vector3.new(0.3, 7.6, 0.3), pose * CFrame.new(side * 5.6, 3.8, 2.6), PALETTE.iron, M.Metal)
		end
		piece(parent, "Banco do ponto", Vector3.new(8, 0.35, 1.5), pose * CFrame.new(-1, 1.6, 1.8), PALETTE.steel, M.Metal, true)
		local screen = piece(parent, "Anúncio do ponto", Vector3.new(0.3, 6.4, 3.6), pose * CFrame.new(6, 4, 0.8), PALETTE.ink, M.SmoothPlastic, true)
		adScreen(surface(screen, N.Right, "Anúncio", 24, 1.3, 260), ad, true)
		adScreen(surface(screen, N.Left, "Anúncio", 24, 1.3, 260), ad, true)
		stats.props += 1
	end

	function props.cart(parent: Instance, x: number, z: number, out: Vector3, r, color: Color3)
		local pose = CFrame.lookAt(Vector3.new(x, CURB, z), Vector3.new(x, CURB, z) + out)
		piece(parent, "Carrinho de comida", Vector3.new(7, 3.4, 3.6), pose * CFrame.new(0, 2.1, 0), rgb(176, 178, 182), M.Metal, true)
		rod(parent, "Haste do guarda-sol", (pose * Vector3.new(0, 0, 0)).X, CURB + 3.8, CURB + 9, (pose * Vector3.new(0, 0, 0)).Z, 0.25, PALETTE.iron, M.Metal)
		piece(parent, "Guarda-sol", Vector3.new(0.3, 9, 9), CFrame.new(x, CURB + 9, z) * CFrame.Angles(0, 0, math.pi / 2),
			r.pick({ rgb(160, 40, 40), rgb(40, 110, 120), rgb(190, 140, 40) }), M.Fabric, false, Enum.PartType.Cylinder)
		local bulb = piece(parent, "Lâmpada do carrinho", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x, CURB + 8.3, z), shade(color, 0.85), M.Neon, false, Enum.PartType.Ball)
		if r.chance(0.5) then
			light(bulb, "PointLight", color, 0.9, 14)
		end
		stats.props += 1
	end

	-- Carro estacionado: carroceria, cabine de vidro escuro, teto, rodas e luzes; feito para cobertura em tiroteios.
	function props.car(parent: Instance, x: number, z: number, heading: Vector3, r)
		local paint = r.pick({ rgb(22, 24, 28), rgb(58, 62, 70), rgb(112, 20, 28), rgb(24, 38, 76), rgb(196, 196, 200), rgb(38, 58, 46),
			rgb(80, 72, 64), if r.chance(0.3) then rgb(208, 158, 36) else rgb(30, 30, 34) })
		local pose = CFrame.lookAt(Vector3.new(x, GROUND, z), Vector3.new(x, GROUND, z) + heading)
		local van = r.chance(0.18)
		local car = group(parent, if van then "Van estacionada" else "Carro estacionado")
		if van then
			local body = piece(car, "Carroceria", Vector3.new(5.4, 4.2, 13.4), pose * CFrame.new(0, 2.9, 0), paint, M.SmoothPlastic, true)
			body.Reflectance = 0.12
			local wind = piece(car, "Para-brisa", Vector3.new(5, 1.8, 0.2), pose * CFrame.new(0, 3.9, -6.62), rgb(18, 24, 32), M.Glass)
			wind.Reflectance = 0.3
		else
			local body = piece(car, "Carroceria", Vector3.new(5.1, 1.7, 12.8), pose * CFrame.new(0, 1.55, 0), paint, M.SmoothPlastic, true)
			body.Reflectance = 0.16
			local cabin = piece(car, "Cabine", Vector3.new(4.5, 1.55, 6.2), pose * CFrame.new(0, 3.15, 0.5), rgb(16, 22, 30), M.Glass)
			cabin.Reflectance = 0.32
			piece(car, "Teto", Vector3.new(4.4, 0.2, 5.4), pose * CFrame.new(0, 4.0, 0.6), paint, M.SmoothPlastic).Reflectance = 0.16
		end
		for _, wheel in { { -2.45, -4.1 }, { 2.45, -4.1 }, { -2.45, 4.2 }, { 2.45, 4.2 } } do
			piece(car, "Roda", Vector3.new(0.9, 2.3, 2.3), pose * CFrame.new(wheel[1], 1.15, wheel[2]), rgb(16, 16, 18), M.Rubber, false, Enum.PartType.Cylinder)
		end
		local on = r.chance(0.12)
		for _, side in { -1, 1 } do
			piece(car, "Farol", Vector3.new(0.9, 0.35, 0.2), pose * CFrame.new(side * 1.7, if van then 2.2 else 1.9, -6.5),
				if on then rgb(230, 236, 255) else rgb(120, 124, 130), if on then M.Neon else M.SmoothPlastic)
		end
		piece(car, "Lanterna", Vector3.new(4.4, 0.25, 0.2), pose * CFrame.new(0, if van then 2.4 else 2.0, 6.5),
			if on then rgb(220, 30, 40) else rgb(90, 20, 24), if on then M.Neon else M.SmoothPlastic)
		stats.cars += 1
	end

	-- Fio aéreo atravessando a rua, com caimento e, às vezes, lanternas penduradas.
	function props.cable(parent: Instance, a: Vector3, b: Vector3, sag: number, r, colors)
		local points = {}
		for k = 0, 3 do
			local t = k / 3
			points[k] = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		end
		for k = 1, 3 do
			beam(parent, "Fio aéreo", points[k - 1], points[k], 0.14, 0.14, PALETTE.ink, M.Metal)
		end
		if r.chance(0.35) then
			local color = r.pick(colors)
			for k = 1, 5 do
				local t = k / 6
				local p = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t) + 0.8, 0)
				piece(parent, "Lanterna pendurada", Vector3.new(0.7, 1, 0.7), CFrame.new(p), shade(color, 0.85), M.Neon)
			end
		end
	end

	local city = group(root, "Maré Baixa")
	city:SetAttribute("CityVersion", CITY_VERSION)

	local lines = {}
	for p = -HALF, HALF, STEP do
		table.insert(lines, p)
	end

	-- Poças: células da grade de 32 studs na sarjeta; o chão ganha um buraco ali e a poça fica no plano do asfalto.
	local streets = group(city, "Ruas")
	local puddleArt = true
	for _, key in POCAS do
		if not uri(art[key]) then
			puddleArt = false
		end
	end
	local holes, holeList = {}, {}
	local puddleRandom = random(SEED + 31)
	local function holeAt(ix: number, iz: number): boolean
		return holes[ix .. "," .. iz] == true
	end
	if puddleArt then
		for index = 1, #lines - 1 do
			local a, b = lines[index], lines[index + 1]
			for _, p in lines do
				for _, along in { "x", "z" } do
					local mid = (a + b) / 2
					local district = if along == "x" then districtAt(mid, p) else districtAt(p, mid)
					local near = math.abs(mid) <= 600 and math.abs(p) <= 600 and district.key ~= "docas"
					if near and puddleRandom.chance(0.34) then
						local side = if puddleRandom.chance(0.5) then -1 else 1
						local gutter = p + side * (roadWidth(p) / 2 - 5)
						local t = puddleRandom.range(a + roadWidth(a) / 2 + 30, b - roadWidth(b) / 2 - 30)
						local ix = math.floor((if along == "x" then t else gutter) / TILE)
						local iz = math.floor((if along == "x" then gutter else t) / TILE)
						if not holeAt(ix, iz) and math.abs(ix) < 31 and math.abs(iz) < 31 then
							holes[ix .. "," .. iz] = true
							table.insert(holeList, { ix, iz })
						end
					end
				end
			end
		end
		-- Duas poças garantidas perto do spawn, na rua ao norte da praça.
		for _, cell in { { 2, 0 }, { 4, 0 } } do
			if not holeAt(cell[1], cell[2]) then
				holes[cell[1] .. "," .. cell[2]] = true
				table.insert(holeList, cell)
			end
		end
	end
	-- Chão: faixas de células sem buraco unidas em grandes placas; linhas com poças viram trechos.
	local function groundSlab(x0: number, x1: number, z0: number, z1: number)
		local slab = span(streets, "Asfalto molhado", x0, x1, GROUND - 4, GROUND, z0, z1, PALETTE.asphalt, M.Asphalt, true)
		slab.Reflectance = 0.04
		pbr(slab, "asphalt", N.Top, TILE, rgb(150, 158, 182), 0.12)
	end
	for _, quadrant in { { -32, -1 }, { 0, 31 } } do
		for _, rows in { { -32, -1 }, { 0, 31 } } do
			local bandStart = nil
			for iz = rows[1], rows[2] do
				local holed = false
				for ix = quadrant[1], quadrant[2] do
					if holeAt(ix, iz) then
						holed = true
						break
					end
				end
				if holed then
					if bandStart then
						groundSlab(quadrant[1] * TILE, (quadrant[2] + 1) * TILE, bandStart * TILE, iz * TILE)
						bandStart = nil
					end
					local runStart = nil
					for ix = quadrant[1], quadrant[2] + 1 do
						local open = ix <= quadrant[2] and not holeAt(ix, iz)
						if open and not runStart then
							runStart = ix
						elseif not open and runStart then
							groundSlab(runStart * TILE, ix * TILE, iz * TILE, (iz + 1) * TILE)
							runStart = nil
						end
					end
				elseif not bandStart then
					bandStart = iz
				end
			end
			if bandStart then
				groundSlab(quadrant[1] * TILE, (quadrant[2] + 1) * TILE, bandStart * TILE, (rows[2] + 1) * TILE)
			end
		end
	end
	local puddles = Instance.new("Folder")
	puddles.Name = "Poças"
	puddles.Parent = streets
	for index, cell in holeList do
		local x0, z0 = cell[1] * TILE, cell[2] * TILE
		-- Fundo escuro bem abaixo do plano: o reflexo do cliente aparece entre ele e a água.
		local water = box(puddles, "Poça", x0 + TILE / 2, GROUND - 0.01, z0 + TILE / 2, TILE, 0.02, TILE, rgb(10, 16, 26), M.Glass)
		water.Transparency = 0.62
		water.Reflectance = 0.25
		water:SetAttribute("CyberOutlawPlano", GROUND)
		-- O asfalto em volta da água vem na própria imagem: mesma textura, mesma grade, sem emenda.
		pbr(water, POCAS[(index - 1) % #POCAS + 1], N.Top, TILE, rgb(150, 158, 182), 0)
		local rim = water:FindFirstChildOfClass("Texture")
		if rim and Content then
			for property, key in { NormalMapContent = "asphalt_normal", RoughnessMapContent = "asphalt_rough" } do
				local id = uri(art[key])
				if id then
					pcall(function()
						(rim :: any)[property] = Content.fromUri(id)
					end)
				end
			end
		end
		stats.puddles += 1
	end

	-- Pintura rente ao asfalto: alta o bastante para não piscar de longe, sem parecer um degrau.
	local function paint(parent: Instance, x0: number, x1: number, z0: number, z1: number, color: Color3?)
		-- Recorta a pintura nas células com poça, para não flutuar sobre a água.
		local cuts = {}
		if #holeList > 0 then
			for _, cell in holeList do
				local cx0, cz0 = cell[1] * TILE, cell[2] * TILE
				if x1 > cx0 and x0 < cx0 + TILE and z1 > cz0 and z0 < cz0 + TILE then
					table.insert(cuts, { cx0, cz0 })
				end
			end
		end
		if #cuts == 0 then
			local mark = box(parent, "Pintura", (x0 + x1) / 2, GROUND + 0.02, (z0 + z1) / 2, x1 - x0, 0.06, z1 - z0, color or PALETTE.paint)
			mark.Transparency = 0.12
			return
		end
		local cut = cuts[1]
		if x1 - x0 >= z1 - z0 then
			if x0 < cut[1] then
				paint(parent, x0, math.min(x1, cut[1]), z0, z1, color)
			end
			if x1 > cut[1] + TILE then
				paint(parent, math.max(x0, cut[1] + TILE), x1, z0, z1, color)
			end
		else
			if z0 < cut[2] then
				paint(parent, x0, x1, z0, math.min(z1, cut[2]), color)
			end
			if z1 > cut[2] + TILE then
				paint(parent, x0, x1, math.max(z0, cut[2] + TILE), z1, color)
			end
		end
	end

	local function laneMarks(model: Instance, p: number, along: string, from: number, to: number)
		-- along == "x": a via corre em X (eixo z = p); along == "z": corre em Z (eixo x = p)
		local function mark(offset: number, width: number, a: number, b: number, color: Color3?)
			if along == "x" then
				paint(model, a, b, p + offset - width / 2, p + offset + width / 2, color)
			else
				paint(model, p + offset - width / 2, p + offset + width / 2, a, b, color)
			end
		end
		local inner, outer = driveBand(p)
		for _, side in { -1, 1 } do
			mark(side * outer, 0.3, from + 4, to - 4) -- borda do estacionamento
			if isAvenue(p) then
				local lane = (inner + outer) / 2
				local dash = from + 14
				while dash + 9 < to - 14 do
					mark(side * lane, 0.35, dash, dash + 9)
					dash += 22
				end
			end
		end
		if isAvenue(p) then
			-- Canteiro central elevado, com meio-fio e palmeiras no Distrito Prisma e no Alto Vértice.
			local length = to - from
			local mid = (from + to) / 2
			local median
			if along == "x" then
				median = box(model, "Canteiro central", mid, (GROUND + CURB) / 2, p, length - 10, CURB - GROUND, MEDIAN, PALETTE.concrete, M.Concrete, true)
			else
				median = box(model, "Canteiro central", p, (GROUND + CURB) / 2, mid, MEDIAN, CURB - GROUND, length - 10, PALETTE.concrete, M.Concrete, true)
			end
			pbr(median, "concrete", N.Top, 12, rgb(170, 166, 184), 0.2)
		else
			mark(-0.35, 0.22, from + 4, to - 4, PALETTE.yellow)
			mark(0.35, 0.22, from + 4, to - 4, PALETTE.yellow)
		end
	end

	-- Faixa de pedestres: uma peça por travessia, com as listras desenhadas por cima.
	local function crosswalk(model: Instance, x: number, z: number)
		local wx, wz = roadWidth(x), roadWidth(z)
		for _, side in { -1, 1 } do
			for _, along in { "x", "z" } do
				local cx = if along == "x" then x + side * (wx / 2 + 5) else x
				local cz = if along == "x" then z else z + side * (wz / 2 + 5)
				local length = if along == "x" then wz - 2 else wx - 2
				local zebra = box(model, "Faixa de pedestres", cx, GROUND + 0.02, cz,
					if along == "x" then 6 else length, 0.06, if along == "x" then length else 6, PALETTE.asphalt)
				zebra.Transparency = 1
				local gui = surface(zebra, N.Top, "Listras", 4, 1, 600)
				gui.LightInfluence = 1
				local stripes = math.floor(length / 4.6)
				for k = 0, stripes - 1 do
					local t = (k + 0.5) / stripes
					if along == "x" then
						panel(gui, PALETTE.paint, 0.12, UDim2.fromScale(0.05, t - 0.24 / stripes), UDim2.fromScale(0.9, 0.48 / stripes))
					else
						panel(gui, PALETTE.paint, 0.12, UDim2.fromScale(t - 0.24 / stripes, 0.05), UDim2.fromScale(0.48 / stripes, 0.9))
					end
				end
				-- Faixa de retenção antes da travessia.
				if along == "x" then
					paint(model, cx + side * 4.2, cx + side * 4.6, z - wz / 2 + 1, z + wz / 2 - 1)
				else
					paint(model, x - wx / 2 + 1, x + wx / 2 - 1, cz + side * 4.2, cz + side * 4.6)
				end
			end
		end
	end

	local function trafficLight(model: Instance, x: number, z: number, out: Vector3, reach: number, r)
		rod(model, "Poste do semáforo", x, CURB, CURB + 18, z, 0.75, PALETTE.iron, M.Metal, true)
		local root0 = Vector3.new(x, CURB + 17.4, z)
		beam(model, "Braço do semáforo", root0, root0 + out * reach, 0.4, 0.4, PALETTE.iron, M.Metal)
		local state = r.int(1, 3)
		for _, t in { 0.55, 0.92 } do
			local head = root0 + out * reach * t
			local pose = CFrame.lookAt(head, head + Vector3.new(out.Z, 0, -out.X))
			piece(model, "Caixa do semáforo", Vector3.new(1.3, 3.8, 1.0), pose * CFrame.new(0, -2.2, 0), PALETTE.ink, M.Metal)
			for index, color in { PALETTE.red, PALETTE.amber, rgb(60, 220, 140) } do
				local on = index == state
				piece(model, "Lâmpada do semáforo", Vector3.new(0.75, 0.75, 0.1), pose * CFrame.new(0, -0.95 - index * 1.0, -0.52),
					if on then shade(color, 0.85) else shade(color, 0.2), if on then M.Neon else M.SmoothPlastic)
			end
		end
	end

	local roadRandom = random(SEED + 11)
	for _, p in lines do
		local roads = group(streets, (if isAvenue(p) then "Avenida " else "Rua ") .. tostring(p))
		for index = 1, #lines - 1 do
			local a, b = lines[index], lines[index + 1]
			local from, to = a + roadWidth(a) / 2, b - roadWidth(b) / 2
			laneMarks(roads, p, "x", from, to)
			laneMarks(roads, p, "z", from, to)
		end
	end
	local crossings = group(streets, "Cruzamentos")
	for _, x in lines do
		for _, z in lines do
			if math.abs(x) <= 600 and math.abs(z) <= 600 then
				crosswalk(crossings, x, z)
				local cx, cz = x - roadWidth(x) / 2 - 3, z - roadWidth(z) / 2 - 3
				trafficLight(crossings, cx, cz, Vector3.new(1, 0, 0), roadWidth(x) * 0.5, roadRandom)
				trafficLight(crossings, x + roadWidth(x) / 2 + 3, z + roadWidth(z) / 2 + 3, Vector3.new(-1, 0, 0), roadWidth(x) * 0.5, roadRandom)
			end
		end
	end

	-- Estacionamento: carros parados junto ao meio-fio, mais cheio no centro.
	local parked = group(streets, "Carros estacionados")
	local carRandom = random(SEED + 51)
	for _, p in lines do
		if math.abs(p) > 800 then
			continue
		end
		for index = 1, #lines - 1 do
			local a, b = lines[index], lines[index + 1]
			if math.abs(a) > 800 or math.abs(b) > 800 then
				continue
			end
			local from, to = a + roadWidth(a) / 2 + 16, b - roadWidth(b) / 2 - 16
			for _, along in { "x", "z" } do
				local mid = (a + b) / 2
				local district = if along == "x" then districtAt(mid, p) else districtAt(p, mid)
				local fill = ({ centro = 0.34, corporativo = 0.26, colmeia = 0.32, mercado = 0.34, docas = 0.08 })[district.key] or 0.2
				for _, side in { -1, 1 } do
					local lane = p + side * (roadWidth(p) / 2 - PARKING / 2)
					local t = from
					while t + 14 <= to do
						if carRandom.chance(fill) then
							local heading = if side > 0 then 1 else -1
							if along == "x" then
								props.car(parked, t + 7, lane, Vector3.new(heading, 0, 0), carRandom)
							else
								props.car(parked, lane, t + 7, Vector3.new(0, 0, -heading), carRandom)
							end
						end
						t += 16
					end
				end
			end
		end
	end

	-- Bueiros com vapor nos cruzamentos do centro (texturas do próprio cliente Roblox).
	local atmosphere = group(city, "Atmosfera")
	local function steam(part: BasePart, rate: number, tint: Color3?)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Vapor"
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(tint or rgb(206, 214, 238), rgb(150, 140, 190))
		emitter.LightEmission = 0.06
		emitter.LightInfluence = 0.9
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.7), NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 9) })
		emitter.Lifetime = NumberRange.new(3, 5.5)
		emitter.Rate = rate
		emitter.Speed = NumberRange.new(2.5, 5)
		emitter.SpreadAngle = Vector2.new(14, 14)
		emitter.Acceleration = Vector3.new(0.8, 1.4, 0)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-12, 12)
		emitter.Drag = 0.6
		emitter.Parent = part
		stats.emitters += 1
		return emitter
	end
	for _, x in lines do
		for _, z in lines do
			if math.abs(x) <= 600 and math.abs(z) <= 600 then
				local vx = x + roadWidth(x) / 2 + 26
				local vz = z + roadWidth(z) / 2 - 12
				local grate = piece(atmosphere, "Bueiro", Vector3.new(0.08, 3.4, 3.4), CFrame.new(vx, GROUND + 0.04, vz) * CFrame.Angles(0, 0, math.pi / 2),
					rgb(30, 32, 38), M.DiamondPlate, false, Enum.PartType.Cylinder)
				steam(grate, 4)
			end
		end
	end

	-- Quadras ----------------------------------------------------------------------------------
	local blocks = group(city, "Quadras")
	local districtGroups = {}
	for _, district in DISTRICTS do
		districtGroups[district.key] = group(blocks, district.name)
	end

	local function plaza(model: Instance, x0: number, x1: number, z0: number, z1: number)
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		local tile = box(model, "Piso da praça", cx, CURB + 0.06, cz, x1 - x0 - 24, 0.12, z1 - z0 - 24, rgb(48, 46, 56), M.Slate)
		tile.Reflectance = 0.08
		pbr(tile, "piso_hexagonal", N.Top, 12, rgb(170, 166, 184), 0)
		for _, ring in { { 34, PALETTE.pink }, { 22, PALETTE.cyan } } do
			piece(model, "Anel no piso", Vector3.new(0.14, ring[1] * 2, ring[1] * 2),
				CFrame.new(cx, CURB + 0.08, cz) * CFrame.Angles(0, 0, math.pi / 2), shade(ring[2], 0.75), M.Neon, false, Enum.PartType.Cylinder)
			piece(model, "Piso interno", Vector3.new(0.16, ring[1] * 2 - 1.4, ring[1] * 2 - 1.4),
				CFrame.new(cx, CURB + 0.09, cz) * CFrame.Angles(0, 0, math.pi / 2), rgb(38, 36, 46), M.Slate, false, Enum.PartType.Cylinder)
		end
		piece(model, "Base do monumento", Vector3.new(2.4, 20, 20), CFrame.new(cx, CURB + 1.2, cz) * CFrame.Angles(0, 0, math.pi / 2),
			PALETTE.steel, M.Metal, true, Enum.PartType.Cylinder)
		-- Torre do Sinal: lajes giradas que sobem do rosa ao ciano, com um anel preso ao mastro por tirantes.
		local levels = 14
		for k = 0, levels - 1 do
			local t = k / (levels - 1)
			local size = 9 - t * 4
			local pose = CFrame.new(cx, CURB + 4 + k * 3.1, cz) * CFrame.Angles(0, math.rad(k * 13), 0)
			piece(model, "Laje da Torre do Sinal", Vector3.new(size, 1.6, size), pose, PALETTE.iron, M.Metal, k < 4)
			piece(model, "Néon da Torre do Sinal", Vector3.new(size + 0.2, 0.25, size + 0.2), pose * CFrame.new(0, 0.92, 0),
				shade(PALETTE.pink:Lerp(PALETTE.cyan, t), 0.85), M.Neon)
		end
		rod(model, "Mastro da Torre do Sinal", cx, CURB + 2, CURB + 60, cz, 1.4, PALETTE.steel, M.Metal, true)
		local segments = 18
		local radius = 11
		for k = 0, segments - 1 do
			local a0, a1 = k / segments * math.pi * 2, (k + 0.62) / segments * math.pi * 2
			beam(model, "Anel da torre", Vector3.new(cx + math.cos(a0) * radius, CURB + 56, cz + math.sin(a0) * radius),
				Vector3.new(cx + math.cos(a1) * radius, CURB + 56, cz + math.sin(a1) * radius), 0.45, 0.45, shade(PALETTE.cyan, 0.85), M.Neon)
		end
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + 0.3
			beam(model, "Tirante do anel", Vector3.new(cx, CURB + 60, cz), Vector3.new(cx + math.cos(a) * radius, CURB + 56, cz + math.sin(a) * radius),
				0.2, 0.2, PALETTE.steel, M.Metal)
		end
		local core = box(model, "Núcleo do monumento", cx, CURB + 56, cz, 2.2, 2.2, 2.2, PALETTE.white, M.Neon)
		light(core, "PointLight", PALETTE.violet, 2, 50)
		local title = Instance.new("BillboardGui")
		title.Name = "Nome da praça"
		title.Size = UDim2.fromScale(46, 9)
		title.StudsOffsetWorldSpace = Vector3.new(0, 12, 0)
		title.LightInfluence = 0
		title.Brightness = 1.6
		title.MaxDistance = 700
		title.Parent = core
		label(title, "MARÉ BAIXA", FONTS.corporate, Color3.new(1, 1, 1), PALETTE.pink)
		stats.guis += 1
		local plazaRandom = random(SEED + 99)
		for _, spot in { { -40, -30 }, { 40, -30 }, { -40, 30 }, { 40, 30 } } do
			local bx, bz = cx + spot[1], cz + spot[2]
			local pz = bz + (if spot[2] > 0 then 4 else -4)
			box(model, "Banco", bx, CURB + 1.1, bz, 10, 0.6, 2.4, PALETTE.steel, M.Metal, true)
			box(model, "Floreira", bx, CURB + 1.4, pz, 12, 2.8, 4, PALETTE.concrete, M.Concrete, true)
			props.palm(model, bx, pz, plazaRandom, CURB + 2.8)
		end
		for _, kiosk in { { cx - 52, cz }, { cx + 52, cz } } do
			box(model, "Quiosque", kiosk[1], CURB + 4.5, kiosk[2], 8, 9, 6, PALETTE.iron, M.Metal, true)
			local screen = box(model, "Tela do quiosque", kiosk[1], CURB + 6, kiosk[2] + (if kiosk[1] > cx then -3.1 else 3.1), 6, 4, 0.2,
				shade(PALETTE.cyan, 0.6), M.Neon)
			light(screen, "PointLight", PALETTE.cyan, 1, 12)
		end
		adDrum(model, x1 - 18, z0 + 18, CURB, 26, 8, plazaRandom)
	end

	-- Calçada de uma face da quadra: postes, árvores ou palmeiras e objetos espalhados sem se sobrepor.
	local function sidewalk(model: Instance, side, theme, district, r, faceHasShops: boolean)
		-- side: from/to ao longo, curb (linha do meio-fio), out (direção da rua), along ("x"|"z"), avenue
		local occupied = {}
		local function free(t: number, radius: number): boolean
			for _, o in occupied do
				if math.abs(o[1] - t) < o[2] + radius then
					return false
				end
			end
			return true
		end
		local function at(t: number, inset: number): (number, number)
			local c = side.curb - side.out * inset
			if side.along == "x" then
				return t, c
			end
			return c, t
		end
		local outV = if side.along == "x" then Vector3.new(0, 0, side.out) else Vector3.new(side.out, 0, 0)
		local alongV = if side.along == "x" then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
		-- Postes: nas ruas, alternando os lados; nas avenidas, o canteiro central tem os postes.
		if not side.avenue then
			local start = side.from + (if side.parity then 18 else 44)
			local count = 0
			for t = start, side.to - 12, 52 do
				count += 1
				local x, z = at(t, 1.8)
				lamp(model, x, z, outV, theme.lamp, count % 2 == 1)
				table.insert(occupied, { t, 3 })
			end
		end
		if side.avenue and (district.key == "centro" or district.key == "corporativo") then
			for t = side.from + 24, side.to - 20, 48 do
				if free(t, 3) then
					local x, z = at(t, 3)
					props.palm(model, x, z, r)
					table.insert(occupied, { t, 3 })
				end
			end
		elseif district.key == "colmeia" or (side.avenue and district.key == "mercado") then
			for t = side.from + 30, side.to - 24, 56 do
				if free(t, 4) and r.chance(0.7) then
					local x, z = at(t, 3)
					props.tree(model, x, z, r)
					table.insert(occupied, { t, 4 })
				end
			end
		end
		local function place(radius: number, inset: number, build)
			for _ = 1, 6 do
				local t = r.range(side.from + 10, side.to - 10)
				if free(t, radius) then
					table.insert(occupied, { t, radius })
					local x, z = at(t, inset)
					build(x, z)
					return
				end
			end
		end
		if r.chance(0.5) then
			place(1.5, 1.6, function(x, z) props.hydrant(model, x, z) end)
		end
		for _ = 1, r.int(1, 2) do
			place(1.5, 1.8, function(x, z) props.trash(model, x, z, r) end)
		end
		if side.avenue and r.chance(0.5) then
			place(7, 3.2, function(x, z) props.busStop(model, x, z, -outV, r.pick(ADS)) end)
		elseif r.chance(0.35) then
			place(4, 2.2, function(x, z) props.bench(model, x, z, alongV, -outV) end)
		end
		if r.chance(0.3) then
			place(1.5, 1.8, function(x, z) props.newsbox(model, x, z, outV, r) end)
		end
		local inner = side.walk - 2.4 -- perto das vitrines
		if faceHasShops and r.chance(0.55) then
			place(2.5, inner, function(x, z) props.vending(model, x, z, outV, r.pick(theme.signs), r) end)
		end
		if (district.key == "mercado" or district.key == "centro") and r.chance(0.35) then
			place(5, inner - 1.5, function(x, z) props.cart(model, x, z, outV, r, r.pick(theme.signs)) end)
		end
	end

	local blockIndex = 0
	local cableRandom = random(SEED + 61)
	for i = 1, #lines - 1 do
		for j = 1, #lines - 1 do
			blockIndex += 1
			local a, b, c, e = lines[i], lines[i + 1], lines[j], lines[j + 1]
			local x0, x1 = a + roadWidth(a) / 2, b - roadWidth(b) / 2
			local z0, z1 = c + roadWidth(c) / 2, e - roadWidth(e) / 2
			local bx, bz = (a + b) / 2, (c + e) / 2
			local district = districtAt(bx, bz)
			local theme = THEMES[district.key]
			local r = random(SEED + i * 7919 + j * 104729)
			local model = group(districtGroups[district.key], string.format("Quadra %d,%d", bx, bz))
			-- A calçada fica logo abaixo do plano do asfalto, para não esconder o reflexo das poças.
			local slab = span(model, "Calçada", x0, x1, GROUND - 0.02, CURB, z0, z1, PALETTE.walk, M.Concrete, true)
			if district.key == "mercado" and uri(art.concreto_rachado) then
				pbr(slab, "concreto_rachado", N.Top, 14, rgb(176, 170, 180), 0.1)
			else
				pbr(slab, "concrete", N.Top, 12, rgb(170, 166, 184), 0.2)
			end
			for _, edge in { { x0, x1, z0, z0 + 0.6 }, { x0, x1, z1 - 0.6, z1 }, { x0, x0 + 0.6, z0, z1 }, { x1 - 0.6, x1, z0, z1 } } do
				span(model, "Meio-fio", edge[1], edge[2], CURB - 0.02, CURB + 0.08, edge[3], edge[4], rgb(104, 102, 108), M.Concrete)
			end
			local lx0, lx1 = x0 + walkWidth(a), x1 - walkWidth(b)
			local lz0, lz1 = z0 + walkWidth(c), z1 - walkWidth(e)
			local w, d = lx1 - lx0, lz1 - lz0
			local cx, cz = (lx0 + lx1) / 2, (lz0 + lz1) / 2
			local allFaces = { N.Front, N.Back, N.Left, N.Right }
			local shopsOn = { [N.Front] = true, [N.Back] = true, [N.Left] = true, [N.Right] = true }
			local key = string.format("%d,%d", bx, bz)
			if bx == 100 and bz == 100 then -- quadra da Praça da Maré
				plaza(model, x0, x1, z0, z1)
				shopsOn = {}
			elseif district.key == "centro" then
				local accent = r.pick(theme.accents)
				local landmark = LANDMARKS[key]
				if landmark then
					local podiumH = 36
					model.Name = landmark.name
					local core = box(model, "Embasamento", cx, CURB + GF + (podiumH - GF) / 2, cz, w - 6, podiumH - GF, d - 6, rgb(40, 42, 54), M.Concrete, true)
					podium(model, cx, cz, w - 6, d - 6, CURB, allFaces, { signs = theme.signs, fabric = theme.fabric, brand = landmark.brand }, r, "saguao")
					facade(model, core, "escritorio", allFaces, landmark.accent)
					local tw = 96
					tower(model, {
						x = cx, z = cz, w = tw, d = tw, base = CURB + podiumH, height = landmark.height - podiumH, style = "vidro",
						accent = landmark.accent, tiers = 3, led = true, faces = {},
					}, r, theme)
					for _, face in allFaces do
						local normal = Vector3.FromNormalId(face)
						local center = Vector3.new(cx, CURB + podiumH + (landmark.height - podiumH) * 0.3, cz) + normal * (tw / 2 + 0.6)
						local plate = piece(model, "Nome da torre", Vector3.new(tw * 0.8, 16, 0.4), CFrame.lookAt(center, center + normal), PALETTE.ink)
						label(surface(plate, N.Front, "Nome da torre", 4, 1.7, 3000), landmark.brand, FONTS.corporate, Color3.new(1, 1, 1), landmark.accent)
					end
				elseif r.chance(0.55) then
					local podiumH = math.floor(r.range(26, 38))
					local core = box(model, "Embasamento", cx, CURB + GF + (podiumH - GF) / 2, cz, w - 6, podiumH - GF, d - 6, rgb(44, 46, 56), M.Concrete, true)
					podium(model, cx, cz, w - 6, d - 6, CURB, allFaces, theme, r, "lojas")
					facade(model, core, "escritorio", allFaces, accent)
					relief(model, core, "escritorio", allFaces)
					tower(model, {
						x = cx + r.range(-5, 5), z = cz + r.range(-5, 5), w = r.range(64, 82), d = r.range(64, 82),
						base = CURB + podiumH, height = math.floor(r.range(420, 780) / FLOOR) * FLOOR, style = r.pick({ "vidro", "escritorio" }),
						accent = accent, tiers = r.int(2, 3), led = r.chance(0.6), faces = {},
					}, r, theme)
					local face = r.pick(allFaces)
					local front = faceFrame(cx, cz, w - 6, d - 6, CURB, face)
					billboard(model, front * CFrame.new(0, podiumH + 30, -1.2), 48, 27, r.pick(ADS))
				else
					for _, s in { -1, 1 } do
						tower(model, {
							x = cx + s * w / 4, z = cz, w = w / 2 - 8, d = d - 12,
							base = CURB, height = math.floor(r.range(300, 560) / FLOOR) * FLOOR, style = r.pick({ "vidro", "escritorio" }),
							accent = r.pick(theme.accents), tiers = r.int(1, 2), led = r.chance(0.5),
							faces = { if s < 0 then N.Left else N.Right, N.Front, N.Back }, ad = if r.chance(0.6) then r.pick(ADS) else nil,
						}, r, theme)
					end
				end
			elseif district.key == "corporativo" then
				local tw, td = r.range(60, 78), r.range(60, 78)
				local tx = cx + r.pick({ -1, 1 }) * (w - tw) / 2 * r.range(0.4, 0.9)
				local tz = cz + r.pick({ -1, 1 }) * (d - td) / 2 * r.range(0.4, 0.9)
				local faces = {}
				if tx - tw / 2 <= lx0 + 0.5 then table.insert(faces, N.Left) end
				if tx + tw / 2 >= lx1 - 0.5 then table.insert(faces, N.Right) end
				if tz - td / 2 <= lz0 + 0.5 then table.insert(faces, N.Front) end
				if tz + td / 2 >= lz1 - 0.5 then table.insert(faces, N.Back) end
				tower(model, {
					x = tx, z = tz, w = tw, d = td, base = CURB, height = math.floor(r.range(300, 640) / FLOOR) * FLOOR,
					style = r.pick({ "vidro", "vidro", "escritorio" }), accent = r.pick(theme.accents),
					tiers = r.int(1, 3), led = r.chance(0.6), faces = faces, ad = r.pick(ADS), lobby = true,
				}, r, { signs = theme.signs, fabric = theme.fabric, brand = r.pick({ "VÉRTICE", "LIMIAR", "ALVOR", "KAIROS" }) })
				-- Praça corporativa: piso de pedra, esculturas de luz e bancos.
				local yard = box(model, "Piso corporativo", cx, CURB + 0.05, cz, w - 2, 0.1, d - 2, rgb(56, 58, 66), M.Slate)
				yard.Reflectance = 0.06
				pbr(yard, "piso_hexagonal", N.Top, 12, rgb(176, 178, 190), 0)
				for _ = 1, 3 do
					local px, pz = r.range(lx0 + 8, lx1 - 8), r.range(lz0 + 8, lz1 - 8)
					if math.abs(px - tx) > tw / 2 + 8 or math.abs(pz - tz) > td / 2 + 8 then
						box(model, "Escultura de luz", px, CURB + 7, pz, 1.2, 14, 1.2, shade(PALETTE.ice, 0.8), M.Neon)
						box(model, "Base da escultura", px, CURB + 0.5, pz, 6, 1, 6, PALETTE.steel, M.Metal, true)
					end
				end
				shopsOn = {}
				for _, face in faces do
					shopsOn[face] = true
				end
			elseif district.key == "colmeia" then
				local mega = MEGABLOCKS[key]
				if mega then
					megablock(model, cx, cz, w, d, mega, allFaces, r, theme)
				else
					for _, qx in { -1, 1 } do
						for _, qz in { -1, 1 } do
							local px, pz = cx + qx * w / 4, cz + qz * d / 4
							local faces = { if qx < 0 then N.Left else N.Right, if qz < 0 then N.Front else N.Back }
							if r.chance(0.55) then
								tower(model, {
									x = px, z = pz, w = w / 2 - 6, d = d / 2 - 6, base = CURB,
									height = math.floor(r.range(170, 360) / FLOOR) * FLOOR, style = "residencial",
									accent = r.pick(theme.accents), tiers = 1, led = false, faces = faces,
								}, r, theme)
								local front = faceFrame(px, pz, w / 2 - 6, d / 2 - 6, CURB, faces[1])
								local _ = front
							else
								midrise(model, px, pz, w / 2 - 3, d / 2 - 3, r.range(70, 130), faces, r, "residencial", false, theme)
							end
						end
					end
				end
			elseif district.key == "mercado" then
				local columns, rows = 3, 2
				local gap = 6
				local pw, pd = (w - gap * (columns - 1)) / columns, (d - gap * (rows - 1)) / rows
				for ci = 1, columns do
					for ri = 1, rows do
						local px = lx0 + (ci - 1) * (pw + gap) + pw / 2
						local pz = lz0 + (ri - 1) * (pd + gap) + pd / 2
						local faces = {}
						if ci == 1 then table.insert(faces, N.Left) end
						if ci == columns then table.insert(faces, N.Right) end
						if ri == 1 then table.insert(faces, N.Front) end
						if ri == rows then table.insert(faces, N.Back) end
						midrise(model, px, pz, pw, pd, r.range(50, 190), faces, r, "residencial", true, theme)
					end
				end
				-- Beco central: fios cruzando, barril de fogo e respiro com vapor.
				local alley = lz0 + pd + gap / 2
				for _ = 1, 5 do
					local t = r.range(lx0 + 6, lx1 - 6)
					local y = CURB + r.range(18, 40)
					props.cable(model, Vector3.new(t, y, lz0 + pd), Vector3.new(t + r.range(-8, 8), y - r.range(0, 4), lz0 + pd + gap), 1.2, r, theme.signs)
				end
				local barrel = piece(atmosphere, "Barril de fogo", Vector3.new(3.4, 2.6, 2.6),
					CFrame.new(lx0 + w * 0.3, CURB + 1.7, alley) * CFrame.Angles(0, 0, math.pi / 2),
					rgb(70, 46, 38), M.CorrodedMetal, true, Enum.PartType.Cylinder)
				local fire = Instance.new("Fire")
				fire.Name = "Fogo"
				fire.Size = 3.2
				fire.Heat = 7
				fire.Color = rgb(255, 120, 40)
				fire.SecondaryColor = rgb(255, 210, 90)
				fire.Parent = barrel
				light(barrel, "PointLight", rgb(255, 140, 60), 1.8, 18)
				local vent = box(atmosphere, "Respiro do beco", lx0 + w * 0.72, CURB + 0.05, alley, 2.4, 0.08, 2.4, rgb(30, 32, 38), M.DiamondPlate)
				steam(vent, 3, rgb(230, 200, 210))
				props.dumpster(model, lx0 + w * 0.5, alley, Vector3.new(0, 0, -1), r)
				city:SetAttribute("BarrisDeFogo", (city:GetAttribute("BarrisDeFogo") or 0) + 1)
			else -- docas
				local roll = r.next()
				if roll < 0.55 then
					local half = d / 2 - 4
					warehouse(model, cx, lz0 + half / 2 + 2, w - 8, half, { N.Front, N.Left, N.Right }, r)
					warehouse(model, cx, lz1 - half / 2 - 2, w - 8, half, { N.Back, N.Left, N.Right }, r)
				elseif roll < 0.85 then
					containers(model, lx0, lx1, lz0, lz1, r)
					box(model, "Cabine da portaria", lx0 + 8, CURB + 5, lz0 + 8, 10, 10, 8, PALETTE.steel, M.Metal, true)
				else
					for _, spot in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
						local radius = r.range(16, 22)
						local height = r.range(30, 48)
						piece(model, "Tanque de combustível", Vector3.new(height, radius * 2, radius * 2),
							CFrame.new(cx + spot[1] * w / 4, CURB + height / 2, cz + spot[2] * d / 4) * CFrame.Angles(0, 0, math.pi / 2),
							rgb(170, 170, 176), M.Metal, true, Enum.PartType.Cylinder)
						box(model, "Faixa do tanque", cx + spot[1] * w / 4, CURB + height * 0.7, cz + spot[2] * d / 4 - radius, radius * 1.2, 2, 0.4,
							PALETTE.red, M.Neon)
					end
				end
				shopsOn = {}
			end
			-- Calçadas das quatro faces.
			local sides = {
				{ face = N.Front, along = "x", from = x0, to = x1, curb = z0 + 0.6, out = -1, walk = walkWidth(c), avenue = isAvenue(c), parity = j % 2 == 0 },
				{ face = N.Back, along = "x", from = x0, to = x1, curb = z1 - 0.6, out = 1, walk = walkWidth(e), avenue = isAvenue(e), parity = j % 2 == 1 },
				{ face = N.Left, along = "z", from = z0, to = z1, curb = x0 + 0.6, out = -1, walk = walkWidth(a), avenue = isAvenue(a), parity = i % 2 == 0 },
				{ face = N.Right, along = "z", from = z0, to = z1, curb = x1 - 0.6, out = 1, walk = walkWidth(b), avenue = isAvenue(b), parity = i % 2 == 1 },
			}
			for _, side in sides do
				sidewalk(model, side, theme, district, r, shopsOn[side.face] == true)
			end
			-- Fios aéreos atravessando as ruas da Colmeia e do Mercado.
			if district.key == "colmeia" or district.key == "mercado" then
				for _, side in { sides[2], sides[4] } do
					if side.avenue then
						continue
					end
					for _ = 1, 2 do
						local t = cableRandom.range(side.from + 20, side.to - 20)
						local y = CURB + cableRandom.range(26, 44)
						local across = roadWidth(if side.along == "x" then e else b) + 2 * walkWidth(if side.along == "x" then e else b)
						local p0 = side.curb - side.out * walkWidth(if side.along == "x" then e else b)
						local p1 = p0 + side.out * across
						local A = if side.along == "x" then Vector3.new(t, y, p0) else Vector3.new(p0, y, t)
						local B = if side.along == "x" then Vector3.new(t + cableRandom.range(-6, 6), y - cableRandom.range(0, 5), p1)
							else Vector3.new(p1, y - cableRandom.range(0, 5), t + cableRandom.range(-6, 6))
						props.cable(model, A, B, 2.4, cableRandom, theme.signs)
					end
				end
			end
		end
	end

	-- Postes duplos e palmeiras no canteiro central das avenidas.
	local medians = group(streets, "Canteiros")
	local medianRandom = random(SEED + 71)
	for _, p in lines do
		if not isAvenue(p) then
			continue
		end
		for index = 1, #lines - 1 do
			local a, b = lines[index], lines[index + 1]
			local from, to = a + roadWidth(a) / 2 + 10, b - roadWidth(b) / 2 - 10
			for _, along in { "x", "z" } do
				local mid = (a + b) / 2
				local district = if along == "x" then districtAt(mid, p) else districtAt(p, mid)
				local theme = THEMES[district.key]
				local count = 0
				local monorail = math.abs(p) == 400
				for t = from + 8, to - 8, 40 do
					count += 1
					local x, z = if along == "x" then t else p, if along == "x" then p else t
					local out = if along == "x" then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0)
					if count % 2 == 1 then
						if not (monorail and math.abs(((if along == "x" then t else t) + 400) % 200 - 100) < 12) then
							lamp(medians, x, z, out, theme.lamp, count % 4 == 1, true)
						end
					elseif (district.key == "centro" or district.key == "corporativo") and not monorail then
						props.palm(medians, x, z, medianRandom)
					end
				end
			end
		end
	end

	-- Calçadas externas e cais ---------------------------------------------------------------
	local edges = group(city, "Bordas")
	local outer = HALF + roadWidth(HALF) / 2
	span(edges, "Calçada externa norte", -outer - 10, outer + 10, GROUND - 1, CURB, -outer - 10, -outer, PALETTE.walk, M.Concrete, true)
	span(edges, "Calçada externa oeste", -outer - 10, -outer, GROUND - 1, CURB, -outer, outer, PALETTE.walk, M.Concrete, true)
	span(edges, "Calçada externa leste", outer, outer + 10, GROUND - 1, CURB, -outer, outer, PALETTE.walk, M.Concrete, true)
	local apron = span(edges, "Pátio do cais", -outer - 10, outer + 10, GROUND - 6, CURB, outer, QUAY, rgb(80, 78, 82), M.Concrete, true)
	pbr(apron, "concrete", N.Top, 14, rgb(160, 156, 170), 0.2)
	span(edges, "Muralha do cais", -outer - 10, outer + 10, WATER - 22, GROUND - 6, QUAY - 3, QUAY, rgb(60, 60, 64), M.Concrete, true)
	local dockRandom = random(SEED + 77)
	for x = -outer, outer, 32 do
		rod(edges, "Cabeço de amarração", x, CURB, CURB + 2.2, QUAY - 3, 1.8, PALETTE.ink, M.Metal, true)
		box(edges, "Defensa", x + 16, CURB - 4, QUAY + 0.6, 4, 5, 1.2, rgb(20, 20, 22), M.Rubber)
	end
	for x = -outer + 40, outer - 40, 120 do
		lamp(edges, x, QUAY - 8, Vector3.new(0, 0, 1), PALETTE.sodium, true)
	end

	local function crane(model: Instance, x: number)
		local legs = { { -16, outer + 8 }, { 16, outer + 8 }, { -16, QUAY - 6 }, { 16, QUAY - 6 } }
		local h = 96
		for _, leg in legs do
			box(model, "Perna do guindaste", x + leg[1], CURB + h / 2, leg[2], 3, h, 3, rgb(196, 142, 38), M.Metal, true)
		end
		for _, s in { -1, 1 } do
			box(model, "Viga do guindaste", x + s * 16, CURB + h + 2, (outer + QUAY) / 2 + 40, 3, 4, (QUAY - outer) + 200,
				rgb(196, 142, 38), M.Metal)
		end
		box(model, "Travessa do guindaste", x, CURB + h + 2, outer + 8, 35, 4, 3, rgb(196, 142, 38), M.Metal)
		box(model, "Travessa do guindaste", x, CURB + h + 2, QUAY - 6, 35, 4, 3, rgb(196, 142, 38), M.Metal)
		box(model, "Cabine do operador", x, CURB + h - 6, QUAY + 30, 10, 8, 10, PALETTE.steel, M.Metal)
		box(model, "Janela da cabine", x, CURB + h - 5, QUAY + 35.1, 8, 3, 0.2, shade(PALETTE.led, 0.75), M.Neon)
		for _, z in { outer + 20, QUAY - 14 } do
			local flood = box(model, "Holofote do guindaste", x, CURB + h - 1, z, 6, 1, 2.4, shade(PALETTE.sodium, 0.85), M.Neon)
			light(flood, "SpotLight", PALETTE.sodium, 2.8, 110, N.Bottom, 90)
		end
		local tip = box(model, "Luz da lança", x, CURB + h + 4.5, QUAY + 158, 2, 2, 2, PALETTE.red, M.Neon)
		light(tip, "PointLight", PALETTE.red, 1.2, 20)
		beam(model, "Cabo de carga", Vector3.new(x, CURB + h, QUAY + 60), Vector3.new(x, CURB + 40, QUAY + 60), 0.3, 0.3, PALETTE.ink, M.Metal)
		box(model, "Spreader", x, CURB + 39, QUAY + 60, 34, 2, 8, PALETTE.yellow, M.Metal)
	end
	local docks = group(city, "Docas")
	for _, x in { -560, -40, 480 } do
		crane(group(docks, "Guindaste de pórtico"), x)
	end

	local ship = group(docks, "Cargueiro Maré Alta 7")
	local sx0, sx1 = -460, -80
	local sz0, sz1 = QUAY + 10, QUAY + 58
	span(ship, "Casco", sx0, sx1, WATER - 10, WATER + 18, sz0, sz1, rgb(34, 40, 52), M.Metal, true)
	span(ship, "Faixa de flutuação", sx0, sx1, WATER - 0.6, WATER + 2, sz0 - 0.2, sz1 + 0.2, rgb(120, 32, 36), M.Metal)
	local bowLength = 40
	piece(ship, "Proa", Vector3.new(sz1 - sz0, 28, bowLength), CFrame.new(sx1 + bowLength / 2, WATER + 4, (sz0 + sz1) / 2)
		* CFrame.Angles(0, -math.pi / 2, 0), rgb(34, 40, 52), M.Metal, true, Enum.PartType.Wedge)
	span(ship, "Superestrutura", sx0 + 6, sx0 + 46, WATER + 18, WATER + 62, sz0 + 6, sz1 - 6, rgb(206, 206, 200), M.Metal, true)
	for level = 1, 4 do
		span(ship, "Janelas da ponte", sx0 + 45.9, sx0 + 46.2, WATER + 18 + level * 10, WATER + 21 + level * 10, sz0 + 8, sz1 - 8,
			shade(PALETTE.led, 0.7), M.Neon)
	end
	local funnel = span(ship, "Chaminé", sx0 + 12, sx0 + 22, WATER + 62, WATER + 76, (sz0 + sz1) / 2 - 5, (sz0 + sz1) / 2 + 5, rgb(40, 40, 44), M.Metal)
	steam(funnel, 3, rgb(120, 116, 130))
	span(ship, "Faixa da chaminé", sx0 + 11.8, sx0 + 22.2, WATER + 70, WATER + 72, (sz0 + sz1) / 2 - 5.2, (sz0 + sz1) / 2 + 5.2, shade(PALETTE.cyan, 0.85), M.Neon)
	for x = sx0 + 60, sx1 - 10, 40 do
		local deck = box(ship, "Luz do convés", x, WATER + 18.6, sz0 + 0.8, 1.6, 1, 1, shade(PALETTE.sodium, 0.85), M.Neon)
		if x % 120 == 0 then
			light(deck, "PointLight", PALETTE.sodium, 1.4, 26)
		end
	end
	for x = sx0 + 50, sx1 - 30, 9 do
		box(ship, "Vigia do casco", x, WATER + 9, sz0 - 0.1, 1.6, 1.6, 0.3, shade(PALETTE.amber, 0.6), M.Neon)
	end
	local shipColors = { rgb(160, 58, 44), rgb(40, 92, 128), rgb(196, 140, 40), rgb(46, 110, 76), rgb(140, 40, 90) }
	for x = sx0 + 64, sx1 - 24, 37 do
		for z = sz0 + 6, sz1 - 6, 8 do
			for level = 1, dockRandom.int(1, 4) do
				box(ship, "Contêiner no convés", x, WATER + 18 + (level - 0.5) * 7.5, z, 35, 7.4, 7.2, dockRandom.pick(shipColors), M.CorrodedMetal, true)
			end
		end
	end
	local name = piece(ship, "Nome do navio", Vector3.new(60, 6, 0.2), CFrame.new(sx1 - 50, WATER + 12, sz0 - 0.15), rgb(34, 40, 52))
	label(surface(name, N.Front, "Nome", 6, 1, 500), "MARÉ ALTA 7", FONTS.heavy, rgb(230, 230, 220))

	-- Água da baía: terreno no Roblox, peça espelhada na prévia.
	local terrain = options.terrain
	local wet = false
	if terrain then
		wet = pcall(function()
			terrain:FillBlock(CFrame.new(0, WATER - 20, QUAY + 1000), Vector3.new(4400, 40, 2000), M.Water)
			terrain:FillBlock(CFrame.new(0, WATER - 44, QUAY + 1000), Vector3.new(4400, 8, 2000), M.Ground)
			terrain.WaterColor = rgb(14, 32, 44)
			terrain.WaterTransparency = 0.15
			terrain.WaterReflectance = 1
			terrain.WaterWaveSize = 0.12
			terrain.WaterWaveSpeed = 8
		end)
	end
	if not wet then
		local sea = span(city, "Baía", -2048, 2048, WATER - 4, WATER, QUAY, QUAY + 2000, rgb(12, 28, 40), M.Glass, true)
		sea.Reflectance = 0.55
	end

	-- Monotrilho Linha Anel: viaduto de concreto amarelado, como os elevados da Maré ---------------
	local rail = group(city, "Monotrilho Linha Anel")
	local path = layoutData().monorail
	for index, point in path do
		local nextPoint = path[index % #path + 1]
		local a = Vector3.new(point[1], DECK - 2.5, point[2])
		local b = Vector3.new(nextPoint[1], DECK - 2.5, nextPoint[2])
		local pieces = math.max(1, math.floor((b - a).Magnitude / 170))
		for k = 0, pieces - 1 do
			local p0, p1 = a:Lerp(b, k / pieces), a:Lerp(b, (k + 1) / pieces)
			beam(rail, "Viga do trilho", p0, p1, 10, 5, PALETTE.monorail, M.Concrete, true)
			local direction = (p1 - p0).Unit
			local across = Vector3.new(-direction.Z, 0, direction.X)
			for _, s in { -1, 1 } do
				beam(rail, "Trilho", p0 + across * s * 2.6 + Vector3.new(0, 2.8, 0), p1 + across * s * 2.6 + Vector3.new(0, 2.8, 0),
					0.6, 0.6, PALETTE.steel, M.Metal)
				beam(rail, "Mureta do trilho", p0 + across * s * 4.7 + Vector3.new(0, 3.4, 0), p1 + across * s * 4.7 + Vector3.new(0, 3.4, 0),
					0.6, 1.8, PALETTE.monorail:Lerp(PALETTE.ink, 0.25), M.Concrete)
			end
			beam(rail, "Néon sob o trilho", p0 - Vector3.new(0, 2.7, 0), p1 - Vector3.new(0, 2.7, 0), 0.5, 0.25, shade(PALETTE.pink, 0.8), M.Neon)
		end
	end
	for _, axis in { 400, -400 } do
		for _, t in { -300, -100, 100, 300 } do
			for _, pillar in { { axis, t }, { t, axis } } do
				box(rail, "Pilar do monotrilho", pillar[1], (CURB + DECK - 5) / 2, pillar[2], 6, DECK - 5 - CURB, 6, PALETTE.monorail, M.Concrete, true)
				box(rail, "Capitel", pillar[1], DECK - 6, pillar[2], 12, 2, 12, PALETTE.monorail, M.Concrete, true)
			end
		end
	end
	local station = group(rail, "Estação Prisma")
	for _, s in { -1, 1 } do
		span(station, "Plataforma", 400 + s * 5.2, 400 + s * 13, DECK - 1.5, DECK, -64, 64, PALETTE.concrete, M.Concrete, true)
		span(station, "Faixa de segurança", 400 + s * 5.3, 400 + s * 6.3, DECK, DECK + 0.06, -64, 64, PALETTE.yellow, M.SmoothPlastic)
		span(station, "Guarda-corpo", 400 + s * 12.6, 400 + s * 13, DECK, DECK + 3.4, -64, 64, PALETTE.glass, M.Glass, true)
	end
	span(station, "Cobertura", 386, 414, DECK + 15, DECK + 16, -66, 66, PALETTE.iron, M.Metal, true)
	span(station, "Luz da cobertura", 390, 410, DECK + 14.8, DECK + 15, -60, 60, shade(PALETTE.led, 0.85), M.Neon)
	for _, z in { -60, -20, 20, 60 } do
		for _, s in { -1, 1 } do
			box(station, "Coluna da estação", 400 + s * 12, DECK + 7.5, z, 1, 15, 1, PALETTE.steel, M.Metal, true)
		end
	end
	local plate = box(station, "Placa da estação", 400, DECK + 12, 0, 0.4, 3, 26, PALETTE.ink)
	for _, face in { N.Left, N.Right } do
		label(surface(plate, face, "Nome da estação", 10, 1.6, 600), "ESTAÇÃO PRISMA · LINHA ANEL", FONTS.corporate, PALETTE.white, PALETTE.pink)
	end
	local train = group(station, "Trem parado")
	for car = -1, 1 do
		local z = car * 36
		box(train, "Carro do trem", 400, DECK + 5.5, z, 8, 8, 34, rgb(60, 66, 80), M.Metal, true)
		box(train, "Janelas do trem", 400, DECK + 6.5, z, 8.15, 2.6, 30, shade(PALETTE.led, 0.8), M.Neon)
		box(train, "Faixa do trem", 400, DECK + 3.2, z, 8.2, 0.5, 33, shade(PALETTE.pink, 0.85), M.Neon)
	end

	-- Horizonte: torres além dos muros e na outra margem da baía ------------------------------
	local skyline = group(city, "Horizonte")
	local far = random(SEED + 404)
	local function silhouette(x: number, z: number, w: number, d: number, h: number, faces)
		local style = far.pick({ "vidro", "escritorio", "residencial" })
		local core = box(skyline, "Torre distante", x, GROUND + h / 2, z, w, h, d,
			if style == "vidro" then PALETTE.glass else rgb(48, 50, 60), if style == "vidro" then M.Glass else M.Concrete)
		core.CanQuery = false
		facade(skyline, core, style, faces, far.pick({ PALETTE.pink, PALETTE.cyan, PALETTE.amber, PALETTE.violet }), 3)
		box(skyline, "Baliza distante", x, GROUND + h + 1, z, 3, 2, 3, PALETTE.red, M.Neon)
	end
	span(skyline, "Chão além do muro", -1500, 1500, GROUND - 1, GROUND - 0.05, -1500, -outer - 10, rgb(20, 22, 28), M.Asphalt)
	span(skyline, "Chão além do muro", -1500, -outer - 10, GROUND - 1, GROUND - 0.05, -outer - 10, QUAY, rgb(20, 22, 28), M.Asphalt)
	span(skyline, "Chão além do muro", outer + 10, 1500, GROUND - 1, GROUND - 0.05, -outer - 10, QUAY, rgb(20, 22, 28), M.Asphalt)
	for t = -1300, 1300, 150 do
		silhouette(t + far.range(-30, 30), -1180 - far.range(0, 200), far.range(70, 130), far.range(70, 130), far.range(220, 860), { N.Back })
		if t < QUAY - 60 then
			silhouette(-1180 - far.range(0, 200), t + far.range(-30, 30), far.range(70, 130), far.range(70, 130), far.range(220, 860), { N.Right })
			silhouette(1180 + far.range(0, 200), t + far.range(-30, 30), far.range(70, 130), far.range(70, 130), far.range(220, 860), { N.Left })
		end
	end
	span(skyline, "Outra margem", -1800, 1800, WATER - 4, GROUND + 2, 2300, 2700, rgb(22, 24, 30), M.Concrete)
	for t = -1600, 1600, 110 do
		silhouette(t + far.range(-25, 25), 2420 + far.range(0, 200), far.range(60, 120), far.range(60, 120), far.range(160, 980), { N.Front })
	end

	-- Limites do mapa ------------------------------------------------------------------------
	local limits = group(city, "Limites")
	for _, wall in {
		{ -LIMIT - 2, -LIMIT, -LIMIT, QUAY + 160 }, { LIMIT, LIMIT + 2, -LIMIT, QUAY + 160 },
		{ -LIMIT, LIMIT, -LIMIT - 2, -LIMIT }, { -LIMIT, LIMIT, QUAY + 160, QUAY + 162 },
	} do
		local barrier = span(limits, "Muro invisível", wall[1], wall[2], WATER - 30, 420, wall[3], wall[4], PALETTE.ink, M.SmoothPlastic, true)
		barrier.Transparency = 1
		barrier.CanQuery = false
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Chegada na Praça da Maré"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(SPAWN + Vector3.new(0, 0.2, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 3
	spawn.Parent = city

	return city, {
		spawn = spawn,
		stats = stats,
		layout = layoutData(),
	}
end

-- Céu da madrugada: brilho da cidade no horizonte (seis faces desenhadas por código), neblina azul-arroxeada
-- e bloom baixo para o néon não estourar.
local function applyLighting(lighting: Instance, art)
	art = if type(art) == "table" then art else {}
	local function child(class: string, name: string)
		local found = lighting:FindFirstChildOfClass(class)
		if found then
			return found
		end
		local created = Instance.new(class)
		created.Name = name
		created.Parent = lighting
		return created
	end
	local settings = {
		ClockTime = 0.6,
		Brightness = 1.2,
		Ambient = rgb(40, 36, 58),
		OutdoorAmbient = rgb(74, 70, 104),
		EnvironmentDiffuseScale = 0.4,
		EnvironmentSpecularScale = 1,
		GlobalShadows = true,
		ShadowSoftness = 0.35,
		ExposureCompensation = 0.1,
	}
	for key, value in settings do
		pcall(function()
			(lighting :: any)[key] = value
		end)
	end
	local haze = child("Atmosphere", "Névoa de Maré Baixa")
	haze.Density = 0.36
	haze.Offset = 0.22
	haze.Color = rgb(118, 104, 156)
	haze.Decay = rgb(150, 92, 120)
	haze.Glare = 0
	haze.Haze = 2.2
	local sky = child("Sky", "Céu de Maré Baixa")
	local faces = { SkyboxBk = "ceu_bk", SkyboxDn = "ceu_dn", SkyboxFt = "ceu_ft", SkyboxLf = "ceu_lf", SkyboxRt = "ceu_rt", SkyboxUp = "ceu_up" }
	local complete = true
	for _, key in faces do
		local id = art[key]
		if not (type(id) == "number" and id > 0) then
			complete = false
		end
	end
	pcall(function()
		if complete then
			for property, key in faces do
				(sky :: any)[property] = string.format("rbxassetid://%.0f", art[key])
			end
			sky.StarCount = 0
			sky.CelestialBodiesShown = false
		else
			sky.StarCount = 400
			sky.MoonAngularSize = 13
		end
	end)
	local bloom = lighting:FindFirstChild("CyberOutlawCityBloom") or Instance.new("BloomEffect")
	bloom.Name = "CyberOutlawCityBloom"
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.2
	bloom.Parent = lighting
	local grade = lighting:FindFirstChild("CyberOutlawCityGrade") or Instance.new("ColorCorrectionEffect")
	grade.Name = "CyberOutlawCityGrade"
	grade.Contrast = 0.1
	grade.Saturation = -0.06
	grade.TintColor = rgb(240, 236, 255)
	grade.Parent = lighting
end

local function main()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HttpService = game:GetService("HttpService")
	if workspace:FindFirstChild("CyberOutlawCity") then
		return
	end
	applyLighting(game:GetService("Lighting"), ART)
	-- Um Baseplate padrão ficaria entre o chão e o reflexo das poças: some sem deixar de existir.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child.Transparency = 1
			end
		end
	end
	local root = Instance.new("Model")
	root.Name = "CyberOutlawCity"
	root.Parent = workspace
	local started = os.clock()
	local city, info = buildCity(root, ART, {
		terrain = workspace.Terrain,
		yield = function()
			task.wait()
		end,
	})
	local spawn = info.spawn
	local function arrive(player: Player, character: Model)
		task.defer(function()
			if player:GetAttribute("CyberOutlawArrived") or player.Character ~= character then
				return
			end
			local rootPart = character:WaitForChild("HumanoidRootPart", 10)
			if not rootPart or player.Character ~= character then
				return
			end
			player:SetAttribute("CyberOutlawArrived", true)
			if (rootPart.Position - SPAWN).Magnitude > 120 then
				character:PivotTo(CFrame.lookAt(SPAWN + Vector3.new(0, 4, 0), PLAZA + Vector3.new(0, 4 + CURB, 0)))
			end
		end)
	end
	local function join(player: Player)
		player.RespawnLocation = spawn
		player.CharacterAdded:Connect(function(character)
			arrive(player, character)
		end)
		if player.Character then
			arrive(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	local board = ReplicatedStorage:FindFirstChild("CyberOutlawCityInfo") or Instance.new("Configuration")
	board.Name = "CyberOutlawCityInfo"
	board:SetAttribute("Layout", HttpService:JSONEncode(info.layout))
	board:SetAttribute("Version", CITY_VERSION)
	board.Parent = ReplicatedStorage
	print(string.format("[CyberOutlaw] Maré Baixa pronta: %d peças, %d luzes, %d letreiros, %d carros, %d poças em %.1fs",
		info.stats.parts, info.stats.lights, info.stats.signs, info.stats.cars, info.stats.puddles, os.clock() - started))
	local _ = city
end

if typeof(game) == "Instance" then
	main()
end

return buildCity, applyLighting, layoutData, districtAt
