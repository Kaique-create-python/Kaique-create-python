-- Maré Baixa · cidade jogável do CyberOutlaw (Script em ServerScriptService).
-- O servidor monta a cidade por código ao iniciar, sempre igual (semente fixa).
-- Arte sem IA: asfalto e concreto são digitalizações Poly Haven (CC0) e as janelas
-- vêm de tools/draw_city_textures.py. Sem essas imagens, viram faixas de luz em geometria.

local ART = __CYBEROUTLAW_ART__

local CITY_VERSION = 1
local SEED = 20261123
local GROUND = 0.25 -- topo do asfalto, acima de um Baseplate padrão
local CURB = 0.85 -- topo das calçadas e quadras
local HALF = 1000 -- área jogável de -1000 a 1000 em X e Z
local STEP = 200 -- distância entre os eixos das ruas
local FLOOR = 14 -- altura de um andar
local QUAY = 1070 -- borda do cais, ao sul
local WATER = -3
local DECK = 66 -- topo do viaduto do monotrilho
local LIMIT = 1036 -- muros invisíveis do mapa
local PLAZA = Vector3.new(107, 0, 107) -- centro da quadra entre os eixos 0 e 200
local SPAWN = Vector3.new(107, CURB, 139)

local rgb = Color3.fromRGB
local M = Enum.Material
local N = Enum.NormalId
local PALETTE = {
	ink = rgb(9, 11, 18),
	iron = rgb(26, 30, 40),
	steel = rgb(58, 64, 76),
	concrete = rgb(74, 72, 80),
	walk = rgb(66, 66, 74),
	asphalt = rgb(26, 28, 34),
	glass = rgb(26, 38, 56),
	pink = rgb(255, 41, 144),
	violet = rgb(180, 86, 250),
	cyan = rgb(58, 231, 255),
	amber = rgb(255, 166, 94),
	lime = rgb(140, 255, 150),
	red = rgb(255, 54, 70),
	sodium = rgb(255, 176, 98),
	led = rgb(196, 226, 255),
	white = rgb(222, 224, 214),
	yellow = rgb(236, 184, 64),
}
local NEON = { PALETTE.pink, PALETTE.violet, PALETTE.cyan, PALETTE.amber, PALETTE.red, PALETTE.lime }
local FONTS = {
	street = Font.fromEnum(Enum.Font.Sarpanch),
	corporate = Font.fromEnum(Enum.Font.Michroma),
	arcade = Font.fromEnum(Enum.Font.Arcade),
	heavy = Font.fromEnum(Enum.Font.GothamBlack),
}
local SHOPS = {
	"LÁMEN 24H", "BAR CROMO", "FARMÁCIA VIVA", "IMPLANTES NOVA", "MOTEL ÓRBITA", "KARAOKÊ NÉVOA",
	"PEÇAS VOLT", "SUSHI DOCA 7", "OFICINA ROTOR", "CÂMBIO 3X", "HOTEL ESTUÁRIO", "CYBERCAFÉ PIXEL",
	"TATUAGEM LÚMEN", "CLÍNICA KOI", "FLIPERAMA ZERO", "PENHORES ÔMEGA", "LAVANDERIA AZUL",
	"DELIVERY RAIO", "BOATE SINAL", "NOODLES DA MARÉ", "ARMARIA FAROL", "BANCO ALVOR",
}
local ADS = {
	{ "ALVOR", "ENERGIA QUE NÃO DORME", PALETTE.pink, rgb(54, 8, 58) },
	{ "LIMIAR", "SEGUROS PARA CORPOS NOVOS", PALETTE.cyan, rgb(6, 30, 58) },
	{ "ESTUÁRIO NET", "9G EM TODA A MARÉ", PALETTE.violet, rgb(22, 8, 44) },
	{ "KAIROS", "IMPLANTES NEURAIS · 0% DE JUROS", PALETTE.amber, rgb(54, 18, 6) },
	{ "VÉRTICE", "MOTORES ELÉTRICOS", PALETTE.lime, rgb(6, 40, 30) },
	{ "NOVA CHUVA", "REFRIGERANTE SINTÉTICO", PALETTE.red, rgb(44, 6, 14) },
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
local WINDOW_ART = { residencial = "fachada_residencial", escritorio = "fachada_escritorio", vidro = "fachada_vidro" }
-- Um quadro de janelas cobre 16 colunas de 6 studs e 8 andares de 14 studs.
local TILE_STUDS = Vector2.new(96, 112)

local function isAvenue(p: number): boolean
	return p % 400 == 0
end

local function roadWidth(p: number): number
	return if isAvenue(p) then 56 else 28
end

local function walkWidth(p: number): number
	return if isAvenue(p) then 12 else 10
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
	local stats = { parts = 0, lights = 0, guis = 0, towers = 0, signs = 0, emitters = 0 }
	local pause = options.yield

	local function uri(id): string?
		return if type(id) == "number" and id > 0 and id % 1 == 0 then string.format("rbxassetid://%.0f", id) else nil
	end

	local function group(parent: Instance, name: string): Model
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = parent
		return model
	end

	-- Peças decorativas não colidem nem recebem consultas; o chão, as quadras e os prédios sim.
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
			t.TextStrokeTransparency = 0.35
		end
		t.Parent = parent
		return t
	end

	-- Janelas por quadro desenhado por código; sem a imagem, faixas de andar em geometria.
	local function facade(model: Instance, core: BasePart, style: string, faces, _, accent: Color3, floorsPerBand: number?)
		local id = uri(art[WINDOW_ART[style]])
		local size = core.Size
		local x, z = core.CFrame.Position.X, core.CFrame.Position.Z
		local y0, y1 = core.CFrame.Position.Y - size.Y / 2, core.CFrame.Position.Y + size.Y / 2
		-- Sorteio próprio da fachada: a cidade fica igual com ou sem as imagens aprovadas.
		local r = random(math.floor(math.abs(x * 31 + z * 17 + y0 * 7 + size.Y)) + SEED)
		if id then
			local shiftX, shiftY = r.int(0, 15) * 6, r.int(0, 7) * FLOOR
			for _, face in faces do
				local gui = surface(core, face, "Janelas", 2, if style == "residencial" then 1.25 else 1.05, 2600)
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
			for y = y0 + FLOOR * 8, y1 - FLOOR, FLOOR * 8 do
				box(model, "Laje aparente", x, y, z, size.X + 1.2, 1.4, size.Z + 1.2, PALETTE.concrete:Lerp(PALETTE.ink, 0.35), M.Concrete)
			end
			return
		end
		local warm = { rgb(150, 96, 52), rgb(132, 84, 46), rgb(110, 120, 140), rgb(96, 64, 40) }
		local cool = { rgb(104, 124, 150), rgb(86, 110, 140), rgb(120, 136, 160) }
		for y = y0 + FLOOR, y1 - 3, FLOOR * (floorsPerBand or 1) do
			box(model, "Peitoril", x, y - 1.2, z, size.X + 0.7, 2.4, size.Z + 0.7, PALETTE.concrete:Lerp(PALETTE.ink, 0.25), M.Concrete)
			if r.chance(if style == "residencial" then 0.34 else 0.27) then
				local tone = if style == "residencial" then r.pick(warm) else r.pick(cool)
				box(model, "Andar aceso", x, y + 5, z, size.X + 0.2, 4.6, size.Z + 0.2, tone, M.Neon)
			end
		end
		if r.chance(0.5) then
			box(model, "Faixa de destaque", x, y1 - FLOOR * 0.5, z, size.X + 0.25, 1.2, size.Z + 0.25, shade(accent, 0.8), M.Neon)
		end
	end

	local function streetSign(parent: Instance, text: string, pose: CFrame, w: number, h: number, color: Color3, r, vertical: boolean?)
		-- A moldura de néon é mais fina que o painel e aparece só na borda, dos dois lados.
		piece(parent, "Moldura de néon", Vector3.new(w + 0.5, h + 0.5, 0.3), pose, color, M.Neon)
		local panel = piece(parent, "Letreiro", Vector3.new(w, h, 0.5), pose, shade(color, 0.16))
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
		local font = if r.chance(0.25) then FONTS.arcade else FONTS.street
		for _, face in if vertical then { N.Front, N.Back } else { N.Front } do
			local gui = surface(panel, face, "Letreiro", if vertical then 14 else 10, 2.6, 420)
			label(gui, copy, font, color:Lerp(Color3.new(1, 1, 1), 0.55), color, UDim2.fromScale(0.06, 0.06), UDim2.fromScale(0.88, 0.88))
		end
		if r.chance(0.55) then
			light(panel, "SurfaceLight", color, 1.7, 20, N.Front, 120)
		end
		stats.signs += 1
		return panel
	end

	local function billboard(parent: Instance, pose: CFrame, w: number, h: number, ad)
		local brand, tagline, glow, deep = ad[1], ad[2], ad[3], ad[4]
		piece(parent, "Estrutura do painel", Vector3.new(w + 2, h + 2, 1.6), pose * CFrame.new(0, 0, -1.1), PALETTE.iron, M.Metal)
		local screen = piece(parent, "Painel de LED", Vector3.new(w, h, 0.4), pose, deep)
		local gui = surface(screen, N.Front, "Anúncio", math.clamp(260 / w, 3, 9), 2.4, 2200)
		local back = Instance.new("Frame")
		back.Size = UDim2.fromScale(1, 1)
		back.BorderSizePixel = 0
		back.BackgroundColor3 = Color3.new(1, 1, 1)
		back.Parent = gui
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(deep:Lerp(glow, 0.35), deep)
		gradient.Rotation = 90
		gradient.Parent = back
		for index = 1, 4 do
			local stripe = Instance.new("Frame")
			stripe.BorderSizePixel = 0
			stripe.BackgroundColor3 = glow
			stripe.BackgroundTransparency = 0.15 + index * 0.17
			stripe.Position = UDim2.fromScale(0, 0.62 + index * 0.05)
			stripe.Size = UDim2.fromScale(1, 0.012)
			stripe.Parent = back
		end
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = glow
		bar.Position = UDim2.fromScale(0.08, 0.17)
		bar.Size = UDim2.fromScale(0.16, 0.025)
		bar.Parent = back
		label(back, brand, FONTS.corporate, Color3.new(1, 1, 1), glow, UDim2.fromScale(0.08, 0.24), UDim2.fromScale(0.84, 0.34))
		label(back, tagline, FONTS.street, glow:Lerp(Color3.new(1, 1, 1), 0.45), nil, UDim2.fromScale(0.08, 0.58), UDim2.fromScale(0.84, 0.1))
		return screen
	end

	local function lamp(parent: Instance, x: number, z: number, dx: number, dz: number, color: Color3, lit: boolean)
		rod(parent, "Poste", x, CURB, CURB + 22, z, 0.9, PALETTE.iron, M.Metal, true)
		local ax, az = x + dx * 3.2, z + dz * 3.2
		box(parent, "Braço do poste", ax, CURB + 21.7, az, if dx ~= 0 then 6.4 else 0.5, 0.5, if dz ~= 0 then 6.4 else 0.5,
			PALETTE.iron, M.Metal)
		local head = box(parent, "Luminária", x + dx * 6, CURB + 21.3, z + dz * 6, if dx ~= 0 then 2.6 else 1.1, 0.45,
			if dz ~= 0 then 2.6 else 1.1, color, M.Neon)
		if lit then
			light(head, "SpotLight", color, 2.6, 40, N.Bottom, 115)
		end
	end

	local city = group(root, "Maré Baixa")
	city:SetAttribute("CityVersion", CITY_VERSION)

	-- Chão, ruas e calçadas ----------------------------------------------------------------
	local streets = group(city, "Ruas")
	for _, qx in { -1, 1 } do
		for _, qz in { -1, 1 } do
			local slab = box(streets, "Asfalto molhado", qx * 512, GROUND - 2, qz * 512, 1024, 4, 1024, PALETTE.asphalt, M.Asphalt, true)
			slab.Reflectance = 0.04
			pbr(slab, "asphalt", N.Top, 26, rgb(150, 158, 182), 0.12)
		end
	end

	local lines = {}
	for p = -HALF, HALF, STEP do
		table.insert(lines, p)
	end

	local function laneMarks(model: Instance, p: number, along: string, from: number, to: number, r)
		-- along == "x": a via corre em X (eixo z = p); along == "z": corre em Z (eixo x = p)
		local length = to - from
		local mid = (from + to) / 2
		local function mark(offset: number, width: number, color: Color3, a: number, b: number)
			if along == "x" then
				box(model, "Faixa pintada", (a + b) / 2, GROUND + 0.04, p + offset, b - a, 0.12, width, color)
			else
				box(model, "Faixa pintada", p + offset, GROUND + 0.04, (a + b) / 2, width, 0.12, b - a, color)
			end
		end
		if isAvenue(p) then
			for _, side in { -1, 1 } do
				-- Faixa tracejada entre as duas pistas de cada sentido.
				local dash = from + 14
				while dash + 9 < to - 6 do
					mark(side * 16, 0.45, PALETTE.white, dash, dash + 9)
					dash += 21
				end
				mark(side * 26.6, 0.4, PALETTE.white, from + 2, to - 2)
			end
			-- Canteiro central elevado com néon nas bordas.
			if along == "x" then
				box(model, "Canteiro central", mid, (GROUND + CURB) / 2, p, length - 24, CURB - GROUND, 8, PALETTE.concrete, M.Concrete, true)
				for _, side in { -1, 1 } do
					box(model, "Néon do canteiro", mid, CURB + 0.06, p + side * 3.75, length - 25, 0.12, 0.35, shade(PALETTE.cyan, 0.75), M.Neon)
				end
			else
				box(model, "Canteiro central", p, (GROUND + CURB) / 2, mid, 8, CURB - GROUND, length - 24, PALETTE.concrete, M.Concrete, true)
				for _, side in { -1, 1 } do
					box(model, "Néon do canteiro", p + side * 3.75, CURB + 0.06, mid, 0.35, 0.12, length - 25, shade(PALETTE.cyan, 0.75), M.Neon)
				end
			end
		else
			mark(-0.45, 0.35, PALETTE.yellow, from + 2, to - 2)
			mark(0.45, 0.35, PALETTE.yellow, from + 2, to - 2)
		end
		for _ = 1, if length > 100 then 2 else 1 do
			local t = r.range(from + 8, to - 8)
			local w = r.range(3, 9)
			local across = r.range(-roadWidth(p) / 2 + 3, roadWidth(p) / 2 - 3)
			local puddle
			if along == "x" then
				puddle = box(model, "Poça", t, GROUND + 0.03, p + across, w * 1.6, 0.06, w, rgb(18, 24, 36), M.Glass)
			else
				puddle = box(model, "Poça", p + across, GROUND + 0.03, t, w, 0.06, w * 1.6, rgb(18, 24, 36), M.Glass)
			end
			puddle.Reflectance = 0.42
			puddle.Transparency = 0.18
		end
	end

	local function crosswalk(model: Instance, x: number, z: number)
		local wx, wz = roadWidth(x), roadWidth(z)
		for _, side in { -1, 1 } do
			-- faixas que atravessam a via em X (eixo z) ao lado do cruzamento
			local cx = x + side * (wx / 2 + 5)
			for k = 0, math.floor(wz / 5) - 1 do
				box(model, "Faixa de pedestres", cx, GROUND + 0.04, z - wz / 2 + 2.5 + k * 5, 6, 0.12, 2.4, PALETTE.white)
			end
			local cz = z + side * (wz / 2 + 5)
			for k = 0, math.floor(wx / 5) - 1 do
				box(model, "Faixa de pedestres", x - wx / 2 + 2.5 + k * 5, GROUND + 0.04, cz, 2.4, 0.12, 6, PALETTE.white)
			end
		end
	end

	local function trafficLight(model: Instance, x: number, z: number, dx: number, dz: number, r)
		rod(model, "Poste do semáforo", x, CURB, CURB + 17, z, 0.8, PALETTE.iron, M.Metal, true)
		local reach = 10
		box(model, "Braço do semáforo", x + dx * reach / 2, CURB + 16.5, z + dz * reach / 2,
			if dx ~= 0 then reach else 0.45, 0.45, if dz ~= 0 then reach else 0.45, PALETTE.iron, M.Metal)
		local hx, hz = x + dx * reach, z + dz * reach
		box(model, "Caixa do semáforo", hx, CURB + 14.6, hz, 1.4, 4.2, 1.4, PALETTE.ink, M.Metal)
		local state = r.int(1, 3)
		for index, color in { PALETTE.red, PALETTE.amber, PALETTE.lime } do
			local on = index == state
			local bulb = box(model, "Lâmpada do semáforo", hx, CURB + 16 - index * 1.3, hz, 1.5, 0.9, 1.5,
				if on then color else shade(color, 0.22), if on then M.Neon else M.SmoothPlastic)
			if on then
				light(bulb, "PointLight", color, 1.4, 14)
			end
		end
	end

	local roadRandom = random(SEED + 11)
	for _, p in lines do
		local roads = group(streets, (if isAvenue(p) then "Avenida " else "Rua ") .. tostring(p))
		for index = 1, #lines - 1 do
			local a, b = lines[index], lines[index + 1]
			local from, to = a + roadWidth(a) / 2, b - roadWidth(b) / 2
			laneMarks(roads, p, "x", from, to, roadRandom)
			laneMarks(roads, p, "z", from, to, roadRandom)
		end
	end
	local crossings = group(streets, "Cruzamentos")
	for _, x in lines do
		for _, z in lines do
			if math.abs(x) <= 400 and math.abs(z) <= 400 then
				crosswalk(crossings, x, z)
				trafficLight(crossings, x - roadWidth(x) / 2 - 3, z - roadWidth(z) / 2 - 3, 1, 0, roadRandom)
				trafficLight(crossings, x + roadWidth(x) / 2 + 3, z + roadWidth(z) / 2 + 3, -1, 0, roadRandom)
			end
		end
	end

	-- Prédios -------------------------------------------------------------------------------
	local function crown(model: Instance, x: number, top: number, z: number, w: number, d: number, accent: Color3, r)
		local kind = r.int(1, 4)
		box(model, "Casa de máquinas", x + r.range(-0.2, 0.2) * w, top + 4, z + r.range(-0.2, 0.2) * d,
			w * r.range(0.3, 0.45), 8, d * r.range(0.3, 0.45), PALETTE.iron, M.Metal, true)
		for _, edge in { { 0, d / 2 }, { 0, -d / 2 }, { w / 2, 0 }, { -w / 2, 0 } } do
			box(model, "Anel de néon da cobertura", x + edge[1], top + 0.9, z + edge[2],
				if edge[1] == 0 then w + 0.6 else 0.6, 1.2, if edge[2] == 0 then d + 0.6 else 0.6, shade(accent, 0.9), M.Neon)
		end
		if kind == 1 then
			local height = r.range(50, 130)
			rod(model, "Agulha", x, top, top + height, z, 2.2, PALETTE.steel, M.Metal)
			box(model, "Baliza de aviação", x, top + height + 1, z, 2.4, 2, 2.4, PALETTE.red, M.Neon)
		elseif kind == 2 then
			local radius = math.min(w, d) * 0.36
			piece(model, "Heliponto", Vector3.new(1.2, radius * 2, radius * 2), CFrame.new(x, top + 9, z) * CFrame.Angles(0, 0, math.pi / 2),
				PALETTE.steel, M.Concrete, true, Enum.PartType.Cylinder)
			box(model, "Marca do heliponto", x, top + 9.65, z, radius * 0.18, 0.1, radius * 0.9, PALETTE.white, M.Neon)
			box(model, "Marca do heliponto", x, top + 9.65, z, radius * 0.6, 0.1, radius * 0.18, PALETTE.white, M.Neon)
			for _, side in { -1, 1 } do
				box(model, "Marca do heliponto", x + side * radius * 0.3, top + 9.65, z, radius * 0.18, 0.1, radius * 0.9, PALETTE.white, M.Neon)
			end
		elseif kind == 3 then
			local cw, cd = w * 0.62, d * 0.62
			box(model, "Coroa escalonada", x, top + 9, z, cw, 18, cd, PALETTE.glass, M.Glass, true).Reflectance = 0.25
			for _, edge in { { 0, cd / 2 }, { 0, -cd / 2 }, { cw / 2, 0 }, { -cw / 2, 0 } } do
				box(model, "Contorno da coroa", x + edge[1], top + 18.3, z + edge[2],
					if edge[1] == 0 then cw + 0.5 else 0.5, 0.8, if edge[2] == 0 then cd + 0.5 else 0.5, accent, M.Neon)
			end
		else
			for _, side in { -1, 1 } do
				local height = r.range(20, 44)
				rod(model, "Antena", x + side * w * 0.3, top, top + height, z - side * d * 0.25, 0.8, PALETTE.steel, M.Metal)
				box(model, "Luz da antena", x + side * w * 0.3, top + height + 0.6, z - side * d * 0.25, 1.2, 1.2, 1.2, PALETTE.red, M.Neon)
			end
		end
	end

	local function streetFront(model: Instance, x: number, z: number, w: number, d: number, base: number, faces, r, signs: number)
		-- Lojas no térreo das faces voltadas para a rua.
		for _, face in faces do
			local normal = Vector3.FromNormalId(face)
			local width = if normal.X ~= 0 then d else w
			local center = Vector3.new(x, base, z) + Vector3.new(normal.X * w / 2, 0, normal.Z * d / 2)
			local front = CFrame.lookAt(center, center + normal)
			-- Duas a quatro lojas por fachada: vitrines acesas em tons diferentes ou portas de aço fechadas.
			local units = math.clamp(math.floor(width / 24), 1, 4)
			for unit = 1, units do
				local unitWidth = (width - 2) / units
				local offset = (unit - (units + 1) / 2) * unitWidth
				if r.chance(0.22) then
					piece(model, "Porta de aço", Vector3.new(unitWidth - 1.2, 9, 0.4), front * CFrame.new(offset, 5.5, -0.15),
						rgb(40, 44, 52), M.CorrodedMetal)
				else
					local tone = r.pick({ rgb(255, 196, 140), rgb(214, 232, 255), rgb(255, 150, 200), rgb(150, 240, 255) })
					piece(model, "Vitrine", Vector3.new(unitWidth - 1.2, 7.4, 0.4), front * CFrame.new(offset, 6.3, -0.15),
						tone:Lerp(PALETTE.ink, r.range(0.68, 0.86)), M.Neon)
					piece(model, "Rodapé da vitrine", Vector3.new(unitWidth - 1.2, 1.6, 0.5), front * CFrame.new(offset, 1.8, -0.2), PALETTE.iron, M.Metal)
					piece(model, "Caixilho da vitrine", Vector3.new(0.5, 7.4, 0.5), front * CFrame.new(offset, 6.3, -0.2), PALETTE.iron, M.Metal)
				end
			end
			piece(model, "Marquise", Vector3.new(width - 1, 0.7, 4.5), front * CFrame.new(0, 11.2, -2.2), PALETTE.iron, M.Metal)
			piece(model, "Luz da marquise", Vector3.new(width - 2, 0.2, 0.3), front * CFrame.new(0, 10.75, -4.3),
				shade(r.pick(NEON), 0.85), M.Neon)
			for k = 1, signs do
				local offset = (k - (signs + 1) / 2) * (width / (signs + 0.5))
				local color = r.pick(NEON)
				if r.chance(0.45) then
					-- Placa vertical em bandeira, perpendicular à fachada.
					local pose = front * CFrame.new(offset, 22 + r.range(0, 10), -3.4) * CFrame.Angles(0, math.pi / 2, 0)
					streetSign(model, r.pick(SHOPS), pose, 3.2, r.range(11, 16), color, r, true)
				else
					local pose = front * CFrame.new(offset, 14.6, -0.7)
					streetSign(model, r.pick(SHOPS), pose, math.min(width / signs - 3, r.range(12, 20)), 3.4, color, r)
				end
			end
		end
	end

	local function tower(model: Instance, spec, r)
		-- spec: x, z, w, d, base, height, style, accent, faces (faces de rua), tiers
		local x, z, w, d = spec.x, spec.z, spec.w, spec.d
		local y, top = spec.base, spec.base + spec.height
		local tiers = spec.tiers or 1
		local style = spec.style
		local material = if style == "vidro" then M.Glass elseif style == "escritorio" then M.Concrete else M.Concrete
		local color = if style == "vidro" then PALETTE.glass elseif style == "escritorio" then rgb(54, 58, 70) else rgb(70, 64, 66)
		local tierW, tierD = w, d
		local remaining = spec.height
		for tier = 1, tiers do
			local h = if tier == tiers then remaining else math.floor(remaining * r.range(0.45, 0.6) / FLOOR) * FLOOR
			remaining -= h
			local core = box(model, if tier == 1 then "Torre" else "Recuo da torre", x, y + h / 2, z, tierW, h, tierD, color, material, true)
			if style == "vidro" then
				core.Reflectance = 0.2
			end
			facade(model, core, style, { N.Front, N.Back, N.Left, N.Right }, r, spec.accent)
			if spec.led and tier == 1 then
				for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
					box(model, "Fita de LED", x + corner[1] * (tierW / 2 + 0.2), y + h / 2, z + corner[2] * (tierD / 2 + 0.2),
						0.7, h, 0.7, shade(spec.accent, 0.85), M.Neon)
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
		if spec.faces and #spec.faces > 0 and spec.base <= CURB + 0.01 then
			streetFront(model, x, z, w, d, spec.base, spec.faces, r, if spec.height > 200 then 1 else 2)
		end
		if spec.ad and spec.faces and #spec.faces > 0 then
			local face = spec.faces[1]
			local normal = Vector3.FromNormalId(face)
			local width = if normal.X ~= 0 then d else w
			local center = Vector3.new(x, spec.base + spec.height * r.range(0.25, 0.45), z)
				+ Vector3.new(normal.X * (w / 2 + 1.8), 0, normal.Z * (d / 2 + 1.8))
			local bw = width * 0.72
			billboard(model, CFrame.lookAt(center, center + normal), bw, bw * 0.56, spec.ad)
		end
		stats.towers += 1
	end

	local function midrise(model: Instance, x: number, z: number, w: number, d: number, height: number, faces, r, style: string, dense: boolean)
		local base = CURB
		local accent = r.pick(NEON)
		local volumes = if dense then r.int(2, 4) else r.int(1, 2)
		local y = base
		local cw, cd, cx, cz = w, d, x, z
		for index = 1, volumes do
			local h = if index == volumes then math.max(FLOOR * 2, base + height - y)
				else math.max(FLOOR * 2, math.floor(height / volumes / FLOOR) * FLOOR)
			local core = box(model, if index == 1 then "Bloco" else "Bloco empilhado", cx, y + h / 2, cz, cw, h, cd,
				rgb(62, 58, 62):Lerp(r.pick({ PALETTE.violet, PALETTE.amber, PALETTE.cyan, PALETTE.red }), 0.08), M.Concrete, true)
			-- Nos becos as paredes ficam cegas; as janelas vão para as faces de rua.
			facade(model, core, style, if #faces > 0 then faces else { N.Front }, r, accent)
			y += h
			if index < volumes then
				cw *= r.range(0.7, 0.95)
				cd *= r.range(0.7, 0.95)
				cx += r.range(-0.12, 0.12) * w
				cz += r.range(-0.12, 0.12) * d
			end
		end
		box(model, "Caixa d'água", cx + cw * 0.2, y + 5, cz - cd * 0.2, 7, 10, 7, PALETTE.steel, M.CorrodedMetal, true)
		if r.chance(0.6) then
			for _, edge in { { 0, cd / 2 }, { 0, -cd / 2 } } do
				box(model, "Néon do topo", cx, y + 0.5, cz + edge[2], cw + 0.4, 0.8, 0.5, shade(accent, 0.85), M.Neon)
			end
		end
		if #faces > 0 then
			streetFront(model, x, z, w, d, base, faces, r, if dense and r.chance(0.35) then 2 else 1)
		end
	end

	local function warehouse(model: Instance, x: number, z: number, w: number, d: number, faces, r)
		local h = r.range(30, 46)
		local tone = r.pick({ rgb(52, 70, 74), rgb(84, 58, 48), rgb(66, 66, 72), rgb(44, 54, 76) })
		box(model, "Galpão", x, CURB + h / 2, z, w, h, d, tone, M.CorrodedMetal, true)
		box(model, "Cumeeira", x, CURB + h + 2, z, w * 0.96, 4, d * 0.5, tone:Lerp(PALETTE.ink, 0.3), M.Metal, true)
		for _, face in faces do
			local normal = Vector3.FromNormalId(face)
			local width = if normal.X ~= 0 then d else w
			local center = Vector3.new(x + normal.X * w / 2, CURB, z + normal.Z * d / 2)
			local front = CFrame.lookAt(center, center + normal)
			local doors = math.max(1, math.floor(width / 34))
			for k = 1, doors do
				local offset = (k - (doors + 1) / 2) * (width / doors)
				piece(model, "Porta de enrolar", Vector3.new(16, 18, 0.6), front * CFrame.new(offset, 9, -0.2), PALETTE.steel, M.Metal)
				local lampPart = piece(model, "Refletor", Vector3.new(2.4, 0.8, 1.2), front * CFrame.new(offset, 21, -0.8), PALETTE.sodium, M.Neon)
				if k == 1 then
					light(lampPart, "SpotLight", PALETTE.sodium, 2.2, 34, N.Bottom, 120)
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

	local function plaza(model: Instance, x0: number, x1: number, z0: number, z1: number)
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		local tile = box(model, "Piso da praça", cx, CURB + 0.06, cz, x1 - x0 - 24, 0.12, z1 - z0 - 24, rgb(48, 46, 56), M.Slate)
		tile.Reflectance = 0.08
		for _, ring in { { 34, PALETTE.pink }, { 22, PALETTE.cyan } } do
			piece(model, "Anel no piso", Vector3.new(0.14, ring[1] * 2, ring[1] * 2),
				CFrame.new(cx, CURB + 0.08, cz) * CFrame.Angles(0, 0, math.pi / 2), shade(ring[2], 0.85), M.Neon, false, Enum.PartType.Cylinder)
			piece(model, "Piso interno", Vector3.new(0.16, ring[1] * 2 - 1.4, ring[1] * 2 - 1.4),
				CFrame.new(cx, CURB + 0.09, cz) * CFrame.Angles(0, 0, math.pi / 2), rgb(38, 36, 46), M.Slate, false, Enum.PartType.Cylinder)
		end
		piece(model, "Base do monumento", Vector3.new(2.4, 20, 20), CFrame.new(cx, CURB + 1.2, cz) * CFrame.Angles(0, 0, math.pi / 2),
			PALETTE.steel, M.Metal, true, Enum.PartType.Cylinder)
		-- Torre do Sinal: lajes giradas que sobem do rosa ao ciano, com um anel flutuante no topo.
		local levels = 14
		for k = 0, levels - 1 do
			local t = k / (levels - 1)
			local size = 9 - t * 4
			local pose = CFrame.new(cx, CURB + 4 + k * 3.1, cz) * CFrame.Angles(0, math.rad(k * 13), 0)
			piece(model, "Laje da Torre do Sinal", Vector3.new(size, 1.6, size), pose, PALETTE.iron, M.Metal, k < 4)
			piece(model, "Néon da Torre do Sinal", Vector3.new(size + 0.3, 0.35, size + 0.3), pose * CFrame.new(0, 0.95, 0),
				PALETTE.pink:Lerp(PALETTE.cyan, t), M.Neon)
		end
		rod(model, "Mastro da Torre do Sinal", cx, CURB + 2, CURB + 52, cz, 1.4, PALETTE.steel, M.Metal, true)
		local segments = 18
		for k = 0, segments - 1 do
			local a0, a1 = k / segments * math.pi * 2, (k + 0.62) / segments * math.pi * 2
			local radius = 11
			beam(model, "Anel flutuante", Vector3.new(cx + math.cos(a0) * radius, CURB + 56, cz + math.sin(a0) * radius),
				Vector3.new(cx + math.cos(a1) * radius, CURB + 56, cz + math.sin(a1) * radius), 0.5, 0.5, PALETTE.cyan, M.Neon)
		end
		local core = box(model, "Núcleo do monumento", cx, CURB + 56, cz, 2.2, 2.2, 2.2, PALETTE.white, M.Neon)
		light(core, "PointLight", PALETTE.violet, 2.2, 50)
		local title = Instance.new("BillboardGui")
		title.Name = "Nome da praça"
		title.Size = UDim2.fromScale(46, 9)
		title.StudsOffsetWorldSpace = Vector3.new(0, 12, 0)
		title.LightInfluence = 0
		title.Brightness = 2.2
		title.MaxDistance = 700
		title.Parent = core
		label(title, "MARÉ BAIXA", FONTS.corporate, Color3.new(1, 1, 1), PALETTE.pink)
		stats.guis += 1
		for _, spot in { { -40, -30 }, { 40, -30 }, { -40, 30 }, { 40, 30 } } do
			local bx, bz = cx + spot[1], cz + spot[2]
			box(model, "Banco", bx, CURB + 1.1, bz, 10, 0.6, 2.4, PALETTE.steel, M.Metal, true)
			box(model, "Floreira", bx, CURB + 1.4, bz + (if spot[2] > 0 then 4 else -4), 12, 2.8, 4, PALETTE.concrete, M.Concrete, true)
			local canopy = piece(model, "Copa iluminada", Vector3.new(9, 9, 9), CFrame.new(bx, CURB + 12, bz + (if spot[2] > 0 then 4 else -4)),
				rgb(40, 92, 82), M.LeafyGrass, false, Enum.PartType.Ball)
			light(canopy, "PointLight", PALETTE.cyan, 0.9, 14)
			rod(model, "Tronco", bx, CURB + 2.8, CURB + 9, bz + (if spot[2] > 0 then 4 else -4), 1.1, rgb(44, 36, 34), M.Wood)
		end
		for _, kiosk in { { cx - 52, cz }, { cx + 52, cz } } do
			box(model, "Quiosque", kiosk[1], CURB + 4.5, kiosk[2], 8, 9, 6, PALETTE.iron, M.Metal, true)
			local screen = box(model, "Tela do quiosque", kiosk[1], CURB + 6, kiosk[2] + (if kiosk[1] > cx then -3.1 else 3.1), 6, 4, 0.2,
				shade(PALETTE.cyan, 0.7), M.Neon)
			light(screen, "PointLight", PALETTE.cyan, 1.2, 12)
		end
	end

	local blocks = group(city, "Quadras")
	local districtGroups = {}
	for _, district in DISTRICTS do
		districtGroups[district.key] = group(blocks, district.name)
	end

	local blockIndex = 0
	for i = 1, #lines - 1 do
		for j = 1, #lines - 1 do
			blockIndex += 1
			local a, b, c, e = lines[i], lines[i + 1], lines[j], lines[j + 1]
			local x0, x1 = a + roadWidth(a) / 2, b - roadWidth(b) / 2
			local z0, z1 = c + roadWidth(c) / 2, e - roadWidth(e) / 2
			local bx, bz = (a + b) / 2, (c + e) / 2
			local district = districtAt(bx, bz)
			local r = random(SEED + i * 7919 + j * 104729)
			local model = group(districtGroups[district.key], string.format("Quadra %d,%d", bx, bz))
			local slab = span(model, "Calçada", x0, x1, GROUND - 1, CURB, z0, z1, PALETTE.walk, M.Concrete, true)
			pbr(slab, "concrete", N.Top, 12, rgb(170, 166, 184), 0.2)
			for _, edge in { { x0, x1, z0, z0 + 0.6 }, { x0, x1, z1 - 0.6, z1 }, { x0, x0 + 0.6, z0, z1 }, { x1 - 0.6, x1, z0, z1 } } do
				span(model, "Meio-fio", edge[1], edge[2], CURB - 0.02, CURB + 0.08, edge[3], edge[4], rgb(98, 96, 104), M.Concrete)
			end
			local lx0, lx1 = x0 + walkWidth(a), x1 - walkWidth(b)
			local lz0, lz1 = z0 + walkWidth(c), z1 - walkWidth(e)
			-- Postes no meio-fio, a cada 64 studs, com luz em postes alternados.
			local lampColor = if district.key == "docas" or district.key == "mercado" then PALETTE.sodium else PALETTE.led
			local count = 0
			for t = x0 + 18, x1 - 18, 64 do
				count += 1
				lamp(model, t, z0 + 1.6, 0, -1, lampColor, count % 2 == 1)
				lamp(model, t, z1 - 1.6, 0, 1, lampColor, count % 2 == 0)
			end
			for t = z0 + 50, z1 - 50, 64 do
				count += 1
				lamp(model, x0 + 1.6, t, -1, 0, lampColor, count % 2 == 1)
				lamp(model, x1 - 1.6, t, 1, 0, lampColor, count % 2 == 0)
			end

			local w, d = lx1 - lx0, lz1 - lz0
			local cx, cz = (lx0 + lx1) / 2, (lz0 + lz1) / 2
			local allFaces = { N.Front, N.Back, N.Left, N.Right }
			if bx == 100 and bz == 100 then -- quadra da Praça da Maré
				plaza(model, x0, x1, z0, z1)
			elseif district.key == "centro" then
				local accent = r.pick(NEON)
				local landmark = LANDMARKS[string.format("%d,%d", bx, bz)]
				if landmark then
					local podium = 36
					model.Name = landmark.name
					local core = box(model, "Embasamento", cx, CURB + podium / 2, cz, w - 6, podium, d - 6, rgb(40, 42, 54), M.Concrete, true)
					facade(model, core, "escritorio", allFaces, r, landmark.accent)
					streetFront(model, cx, cz, w - 6, d - 6, CURB, allFaces, r, 2)
					local tw = 96
					tower(model, {
						x = cx, z = cz, w = tw, d = tw, base = CURB + podium, height = landmark.height - podium, style = "vidro",
						accent = landmark.accent, tiers = 3, led = true, faces = {},
					}, r)
					-- Nome da torre nas quatro faces, perto do topo.
					for _, face in allFaces do
						local normal = Vector3.FromNormalId(face)
						local center = Vector3.new(cx, CURB + podium + (landmark.height - podium) * 0.3, cz) + normal * (tw / 2 + 0.6)
						local plate = piece(model, "Nome da torre", Vector3.new(tw * 0.8, 16, 0.4), CFrame.lookAt(center, center + normal), PALETTE.ink)
						label(surface(plate, N.Front, "Nome da torre", 4, 2.6, 3000), landmark.brand, FONTS.corporate, Color3.new(1, 1, 1), landmark.accent)
					end
				elseif r.chance(0.55) then
					local podium = r.range(26, 38)
					local core = box(model, "Embasamento", cx, CURB + podium / 2, cz, w - 6, podium, d - 6, rgb(44, 46, 56), M.Concrete, true)
					facade(model, core, "escritorio", allFaces, r, accent)
					streetFront(model, cx, cz, w - 6, d - 6, CURB, allFaces, r, 2)
					tower(model, {
						x = cx + r.range(-6, 6), z = cz + r.range(-6, 6), w = r.range(74, 92), d = r.range(74, 92),
						base = CURB + podium, height = math.floor(r.range(420, 780) / FLOOR) * FLOOR, style = r.pick({ "vidro", "escritorio" }),
						accent = accent, tiers = r.int(2, 3), led = r.chance(0.6), faces = {},
					}, r)
					local face = r.pick(allFaces)
					local normal = Vector3.FromNormalId(face)
					local center = Vector3.new(cx + normal.X * (w / 2 - 1), CURB + podium + 30, cz + normal.Z * (d / 2 - 1))
					billboard(model, CFrame.lookAt(center, center + normal), 48, 27, r.pick(ADS))
				else
					for _, side in { -1, 1 } do
						tower(model, {
							x = cx + side * w / 4, z = cz, w = w / 2 - 10, d = d - 18,
							base = CURB, height = math.floor(r.range(300, 560) / FLOOR) * FLOOR, style = r.pick({ "vidro", "escritorio" }),
							accent = r.pick(NEON), tiers = r.int(1, 2), led = r.chance(0.5),
							faces = { if side < 0 then N.Left else N.Right, N.Front, N.Back }, ad = if r.chance(0.6) then r.pick(ADS) else nil,
						}, r)
					end
				end
			elseif district.key == "corporativo" then
				local tw, td = r.range(64, 84), r.range(64, 84)
				local tx = cx + r.pick({ -1, 1 }) * (w - tw) / 2 * r.range(0.4, 0.9)
				local tz = cz + r.pick({ -1, 1 }) * (d - td) / 2 * r.range(0.4, 0.9)
				tower(model, {
					x = tx, z = tz, w = tw, d = td, base = CURB, height = math.floor(r.range(300, 640) / FLOOR) * FLOOR,
					style = r.pick({ "vidro", "vidro", "escritorio" }), accent = r.pick({ PALETTE.cyan, PALETTE.violet, PALETTE.pink }),
					tiers = r.int(1, 3), led = r.chance(0.7), faces = { N.Front, N.Back, N.Left, N.Right }, ad = r.pick(ADS),
				}, r)
				for _ = 1, 3 do
					local px, pz = r.range(lx0 + 8, lx1 - 8), r.range(lz0 + 8, lz1 - 8)
					if math.abs(px - tx) > tw / 2 + 8 or math.abs(pz - tz) > td / 2 + 8 then
						box(model, "Escultura de luz", px, CURB + 7, pz, 2, 14, 2, shade(PALETTE.cyan, 0.9), M.Neon)
						box(model, "Base da escultura", px, CURB + 0.5, pz, 6, 1, 6, PALETTE.steel, M.Metal, true)
					end
				end
			elseif district.key == "colmeia" then
				for _, qx in { -1, 1 } do
					for _, qz in { -1, 1 } do
						local px, pz = cx + qx * w / 4, cz + qz * d / 4
						local faces = { if qx < 0 then N.Left else N.Right, if qz < 0 then N.Front else N.Back }
						if r.chance(0.6) then
							tower(model, {
								x = px, z = pz, w = w / 2 - 12, d = d / 2 - 12, base = CURB,
								height = math.floor(r.range(170, 360) / FLOOR) * FLOOR, style = "residencial",
								accent = r.pick(NEON), tiers = 1, led = false, faces = faces,
							}, r)
						else
							midrise(model, px, pz, w / 2 - 6, d / 2 - 6, r.range(70, 130), faces, r, "residencial", false)
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
						midrise(model, px, pz, pw, pd, r.range(50, 190), faces, r, "residencial", true)
					end
				end
				-- Cabos atravessando o beco central.
				for _ = 1, 6 do
					local t = r.range(lx0 + 6, lx1 - 6)
					local y = CURB + r.range(18, 40)
					beam(model, "Cabo do beco", Vector3.new(t, y, lz0 + pd), Vector3.new(t + r.range(-8, 8), y - r.range(0, 4), lz0 + pd + gap),
						0.25, 0.25, PALETTE.ink, M.Metal)
				end
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
			end
		end
	end

	-- Atmosfera: vapor dos bueiros, barris de fogo nos becos (texturas do próprio cliente Roblox) --------
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
				-- Bueiro na faixa da direita, depois da faixa de pedestres.
				local vx = x + roadWidth(x) / 2 + 24
				local vz = z + roadWidth(z) / 2 - 7
				local grate = box(atmosphere, "Bueiro", vx, GROUND + 0.05, vz, 3.4, 0.08, 3.4, rgb(30, 32, 38), M.DiamondPlate)
				steam(grate, 4)
			end
		end
	end
	local barrels = 0
	for i = 1, #lines - 1 do
		for j = 1, #lines - 1 do
			local a, b, c, e = lines[i], lines[i + 1], lines[j], lines[j + 1]
			local bx, bz = (a + b) / 2, (c + e) / 2
			if districtAt(bx, bz).key == "mercado" then
				-- Beco entre as duas fileiras de prédios do mercado (mesma conta da quadra).
				local lx0 = a + roadWidth(a) / 2 + walkWidth(a)
				local lx1 = b - roadWidth(b) / 2 - walkWidth(b)
				local lz0 = c + roadWidth(c) / 2 + walkWidth(c)
				local lz1 = e - roadWidth(e) / 2 - walkWidth(e)
				local alley = lz0 + ((lz1 - lz0) - 6) / 2 + 3
				local barrel = piece(atmosphere, "Barril de fogo", Vector3.new(3.4, 2.6, 2.6),
					CFrame.new(lx0 + (lx1 - lx0) * 0.3, CURB + 1.7, alley) * CFrame.Angles(0, 0, math.pi / 2),
					rgb(70, 46, 38), M.CorrodedMetal, true, Enum.PartType.Cylinder)
				local fire = Instance.new("Fire")
				fire.Name = "Fogo"
				fire.Size = 3.2
				fire.Heat = 7
				fire.Color = rgb(255, 120, 40)
				fire.SecondaryColor = rgb(255, 210, 90)
				fire.Parent = barrel
				light(barrel, "PointLight", rgb(255, 140, 60), 1.8, 18)
				local vent = box(atmosphere, "Respiro do beco", lx0 + (lx1 - lx0) * 0.72, CURB + 0.05, alley, 2.4, 0.08, 2.4, rgb(30, 32, 38), M.DiamondPlate)
				steam(vent, 3, rgb(230, 200, 210))
				barrels += 1
			end
		end
	end
	city:SetAttribute("BarrisDeFogo", barrels)

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
		lamp(edges, x, QUAY - 8, 0, 1, PALETTE.sodium, true)
	end

	local function crane(model: Instance, x: number)
		local legs = { { -16, outer + 8 }, { 16, outer + 8 }, { -16, QUAY - 6 }, { 16, QUAY - 6 } }
		local h = 96
		for _, leg in legs do
			box(model, "Perna do guindaste", x + leg[1], CURB + h / 2, leg[2], 3, h, 3, rgb(196, 142, 38), M.Metal, true)
		end
		for _, side in { -1, 1 } do
			box(model, "Viga do guindaste", x + side * 16, CURB + h + 2, (outer + QUAY) / 2 + 40, 3, 4, (QUAY - outer) + 200,
				rgb(196, 142, 38), M.Metal)
		end
		box(model, "Travessa do guindaste", x, CURB + h + 2, outer + 8, 35, 4, 3, rgb(196, 142, 38), M.Metal)
		box(model, "Travessa do guindaste", x, CURB + h + 2, QUAY - 6, 35, 4, 3, rgb(196, 142, 38), M.Metal)
		box(model, "Cabine do operador", x, CURB + h - 6, QUAY + 30, 10, 8, 10, PALETTE.steel, M.Metal)
		box(model, "Janela da cabine", x, CURB + h - 5, QUAY + 35.1, 8, 3, 0.2, shade(PALETTE.led, 0.8), M.Neon)
		for _, z in { outer + 20, QUAY - 14 } do
			local flood = box(model, "Holofote do guindaste", x, CURB + h - 1, z, 6, 1, 2.4, PALETTE.sodium, M.Neon)
			light(flood, "SpotLight", PALETTE.sodium, 3.2, 110, N.Bottom, 90)
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
			shade(PALETTE.led, 0.75), M.Neon)
	end
	local funnel = span(ship, "Chaminé", sx0 + 12, sx0 + 22, WATER + 62, WATER + 76, (sz0 + sz1) / 2 - 5, (sz0 + sz1) / 2 + 5, rgb(40, 40, 44), M.Metal)
	steam(funnel, 3, rgb(120, 116, 130))
	span(ship, "Faixa da chaminé", sx0 + 11.8, sx0 + 22.2, WATER + 70, WATER + 72, (sz0 + sz1) / 2 - 5.2, (sz0 + sz1) / 2 + 5.2, PALETTE.cyan, M.Neon)
	for x = sx0 + 60, sx1 - 10, 40 do
		local deck = box(ship, "Luz do convés", x, WATER + 18.6, sz0 + 0.8, 1.6, 1, 1, PALETTE.sodium, M.Neon)
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

	-- Monotrilho Linha Anel ----------------------------------------------------------------
	local rail = group(city, "Monotrilho Linha Anel")
	local path = layoutData().monorail
	for index, point in path do
		local nextPoint = path[index % #path + 1]
		local a = Vector3.new(point[1], DECK - 2.5, point[2])
		local b = Vector3.new(nextPoint[1], DECK - 2.5, nextPoint[2])
		local pieces = math.max(1, math.floor((b - a).Magnitude / 170))
		for k = 0, pieces - 1 do
			local p0, p1 = a:Lerp(b, k / pieces), a:Lerp(b, (k + 1) / pieces)
			beam(rail, "Viga do trilho", p0, p1, 10, 5, PALETTE.concrete, M.Concrete, true)
			local direction = (p1 - p0).Unit
			local across = Vector3.new(-direction.Z, 0, direction.X)
			for _, side in { -1, 1 } do
				beam(rail, "Trilho", p0 + across * side * 2.6 + Vector3.new(0, 2.8, 0), p1 + across * side * 2.6 + Vector3.new(0, 2.8, 0),
					0.6, 0.6, PALETTE.steel, M.Metal)
			end
			beam(rail, "Néon sob o trilho", p0 - Vector3.new(0, 2.7, 0), p1 - Vector3.new(0, 2.7, 0), 0.8, 0.3, PALETTE.pink, M.Neon)
		end
	end
	for _, axis in { 400, -400 } do
		for _, t in { -300, -100, 100, 300 } do
			for _, pillar in { { axis, t }, { t, axis } } do
				box(rail, "Pilar do monotrilho", pillar[1], (CURB + DECK - 5) / 2, pillar[2], 6, DECK - 5 - CURB, 6, PALETTE.concrete, M.Concrete, true)
				box(rail, "Capitel", pillar[1], DECK - 6, pillar[2], 12, 2, 12, PALETTE.concrete, M.Concrete, true)
			end
		end
	end
	local station = group(rail, "Estação Prisma")
	for _, side in { -1, 1 } do
		span(station, "Plataforma", 400 + side * 5.2, 400 + side * 13, DECK - 1.5, DECK, -64, 64, PALETTE.concrete, M.Concrete, true)
		span(station, "Faixa de segurança", 400 + side * 5.3, 400 + side * 6.3, DECK, DECK + 0.06, -64, 64, PALETTE.yellow, M.Neon)
		span(station, "Guarda-corpo", 400 + side * 12.6, 400 + side * 13, DECK, DECK + 3.4, -64, 64, PALETTE.glass, M.Glass, true)
	end
	span(station, "Cobertura", 386, 414, DECK + 15, DECK + 16, -66, 66, PALETTE.iron, M.Metal, true)
	span(station, "Luz da cobertura", 390, 410, DECK + 14.8, DECK + 15, -60, 60, shade(PALETTE.led, 0.9), M.Neon)
	for _, z in { -60, -20, 20, 60 } do
		for _, side in { -1, 1 } do
			box(station, "Coluna da estação", 400 + side * 12, DECK + 7.5, z, 1, 15, 1, PALETTE.steel, M.Metal, true)
		end
	end
	local plate = box(station, "Placa da estação", 400, DECK + 12, 0, 0.4, 3, 26, PALETTE.ink)
	for _, face in { N.Left, N.Right } do
		label(surface(plate, face, "Nome da estação", 10, 2.4, 600), "ESTAÇÃO PRISMA · LINHA ANEL", FONTS.corporate, PALETTE.white, PALETTE.pink)
	end
	local train = group(station, "Trem parado")
	for car = -1, 1 do
		local z = car * 36
		box(train, "Carro do trem", 400, DECK + 5.5, z, 8, 8, 34, rgb(60, 66, 80), M.Metal, true)
		box(train, "Janelas do trem", 400, DECK + 6.5, z, 8.15, 2.6, 30, shade(PALETTE.led, 0.85), M.Neon)
		box(train, "Faixa do trem", 400, DECK + 3.2, z, 8.2, 0.5, 33, PALETTE.pink, M.Neon)
	end

	-- Horizonte: torres além dos muros e na outra margem da baía ------------------------------
	local skyline = group(city, "Horizonte")
	local far = random(SEED + 404)
	local function silhouette(x: number, z: number, w: number, d: number, h: number, faces)
		local style = far.pick({ "vidro", "escritorio", "residencial" })
		local core = box(skyline, "Torre distante", x, GROUND + h / 2, z, w, h, d,
			if style == "vidro" then PALETTE.glass else rgb(48, 50, 60), if style == "vidro" then M.Glass else M.Concrete)
		core.CanQuery = false
		facade(skyline, core, style, faces, far, far.pick(NEON), 3)
		box(skyline, "Baliza distante", x, GROUND + h + 1, z, 3, 2, 3, far.pick({ PALETTE.red, PALETTE.pink, PALETTE.cyan }), M.Neon)
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

local function applyLighting(lighting: Instance)
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
		Brightness = 1.4,
		Ambient = rgb(44, 36, 64),
		OutdoorAmbient = rgb(62, 64, 96),
		EnvironmentDiffuseScale = 0.32,
		EnvironmentSpecularScale = 1,
		GlobalShadows = true,
		ShadowSoftness = 0.35,
		ExposureCompensation = 0.12,
	}
	for key, value in settings do
		pcall(function()
			(lighting :: any)[key] = value
		end)
	end
	local haze = child("Atmosphere", "Névoa de Maré Baixa")
	haze.Density = 0.3
	haze.Offset = 0.08
	haze.Color = rgb(112, 122, 176)
	haze.Decay = rgb(62, 30, 92)
	haze.Glare = 0.1
	haze.Haze = 1.4
	local sky = child("Sky", "Céu de Maré Baixa")
	pcall(function()
		sky.StarCount = 600
		sky.MoonAngularSize = 13
	end)
	local bloom = lighting:FindFirstChild("CyberOutlawCityBloom") or Instance.new("BloomEffect")
	bloom.Name = "CyberOutlawCityBloom"
	bloom.Intensity = 0.85
	bloom.Size = 30
	bloom.Threshold = 0.86
	bloom.Parent = lighting
	local grade = lighting:FindFirstChild("CyberOutlawCityGrade") or Instance.new("ColorCorrectionEffect")
	grade.Name = "CyberOutlawCityGrade"
	grade.Contrast = 0.12
	grade.Saturation = 0.1
	grade.TintColor = rgb(234, 230, 255)
	grade.Parent = lighting
end

local function main()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HttpService = game:GetService("HttpService")
	if workspace:FindFirstChild("CyberOutlawCity") then
		return
	end
	applyLighting(game:GetService("Lighting"))
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
	print(string.format("[CyberOutlaw] Maré Baixa pronta: %d peças, %d luzes, %d letreiros em %.1fs",
		info.stats.parts, info.stats.lights, info.stats.signs, os.clock() - started))
	local _ = city
end

if typeof(game) == "Instance" then
	main()
end

return buildCity, applyLighting, layoutData, districtAt
