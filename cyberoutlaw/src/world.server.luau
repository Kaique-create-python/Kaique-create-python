-- Maré Baixa. O servidor monta as quadras nativas e publica o layout para a vida e o HUD.
local ART = __CYBEROUTLAW_ART__
-- __CYBEROUTLAW_MARE_MODULES__

local CITY_VERSION = 3
local SAFE_RADIUS = 95
local Layout = Mare.Layout
local rgb = Color3.fromRGB
local plazaX, plazaZ = Layout.cell(5, 4)
local colmeiaX, colmeiaZ = -139, 187
local SPAWN = Vector3.new(Layout.spawnX, Layout.walkY, Layout.spawnZ)

-- A ordem resolve os encontros entre os bairros usados pelo HUD, pelas gangues e pelas missões.
local DISTRICTS = {
	{ key = "docas", name = "Docas da Maré", color = {112, 226, 136}, rect = {-1200, 480, 1200, 960} },
	{ key = "centro", name = "Distrito Prisma", color = {236, 52, 146}, rect = {-240, -240, 240, 240} },
	{ key = "mercado", name = "Mercado do Sódio", color = {255, 152, 72}, rect = {-1200, -480, -240, 480} },
	{ key = "corporativo", name = "Alto Vértice", color = {44, 206, 240}, rect = {240, -960, 1200, 480} },
	{ key = "colmeia", name = "Colmeia", color = {156, 86, 240}, rect = {-1200, -960, 240, 480} },
}

local BLOCK_NAMES = {
	apartments = "Apartamentos", towers = "Residencial vertical", mixed = "Uso misto",
	finance = "Vértice financeiro", hotel = "Hotel e comércio", tech = "Pesquisa e escritórios",
	vertice = "Torre Vértice", grid = "Subestação do anel", warehouse = "Armazéns", docks = "Doca do Sal",
	arcade = "Galeria de comércio", sodio = "Mercado Sódio", park = "Praça de bairro",
	levee = "Mirante da orla", spawn = "Praça do Dique", station = "Estação do Dique",
}
local TOWER_TYPES = {vertice = true, finance = true, hotel = true, tech = true}
local RESIDENTIAL_TYPES = {towers = true, mixed = true, apartments = true}

local function districtAt(x: number, z: number)
	for _, district in DISTRICTS do
		local rect = district.rect
		if x >= rect[1] and x <= rect[3] and z >= rect[2] and z <= rect[4] then
			return district
		end
	end
	return DISTRICTS[#DISTRICTS]
end

local function layoutData()
	local xLines, zLines, bridges = {}, {}, {}
	for index = 0, Layout.columns do
		local x = -Layout.halfX + index * Layout.pitch
		-- O eixo do canal serve como limite das quadras de margem no anel de pedestres.
		local width = if x == 0 then 56 else Layout.streetWidth(x)
		table.insert(xLines, {x, width, Layout.sidewalkWidth})
	end
	for index = 0, Layout.rows do
		local z = -Layout.halfZ + index * Layout.pitch
		local width = Layout.avenueWidth(z)
		table.insert(zLines, {z, width, Layout.sidewalkWidth})
		local kind = Layout.bridgeRows[z]
		table.insert(bridges, {z, if kind == "foot" then Layout.footWidth else width, kind})
	end
	return {
		version = CITY_VERSION,
		half = Layout.halfX,
		halfX = Layout.halfX,
		halfZ = Layout.halfZ,
		lines = xLines,
		xLines = xLines,
		zLines = zLines,
		quay = Layout.halfZ,
		bridges = bridges,
		canal = {x = 0, width = Layout.canalWidth, bank = Layout.bank},
		districts = DISTRICTS,
		walkY = Layout.walkY,
		roadY = Layout.roadY,
		spawn = {SPAWN.X, SPAWN.Z},
		plaza = {plazaX, plazaZ},
		safeZone = {plazaX, plazaZ, SAFE_RADIUS},
		monorail = {{-Layout.turnaround, Layout.stationZ}, {Layout.turnaround, Layout.stationZ}},
		monorailMode = "shuttle",
		station = {Layout.stationX, Layout.stationZ},
		deck = Layout.deck,
	}
end

local function spawnAt(root: Instance): SpawnLocation
	local entry = Instance.new("Model")
	entry.Name = "Ponto de entrada"
	entry.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	-- O piso de chegada existe desde o início, inclusive se o envio das quadras para o cliente atrasar.
	local floor = Instance.new("Part")
	floor.Name = "Piso de chegada"
	floor.Size = Vector3.new(172, 1, 170)
	floor.CFrame = CFrame.new(plazaX, Layout.walkY - 0.58, plazaZ)
	floor.Anchored = true
	floor.CanCollide = true
	floor.CanTouch = false
	floor.Transparency = 1
	floor.CastShadow = false
	floor.Parent = entry
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Chegada na Praça do Dique"
	spawn.Size = Vector3.new(8, 0.2, 8)
	local p = SPAWN + Vector3.new(0, 0.1, 0)
	spawn.CFrame = CFrame.lookAt(p, Vector3.new(30, p.Y, -33))
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.CanTouch = false
	spawn.CastShadow = false
	spawn.Neutral = true
	spawn.Duration = 3
	spawn.Transparency = 1
	spawn.Parent = entry
	entry.Parent = root
	return spawn
end

local function buildCity(root: Instance, art, options)
	options = options or {}
	local spawn = options.spawn or spawnAt(root)
	if options.onSpawn then
		options.onSpawn(spawn)
	end
	local ctx = Mare.Context.new(options.materialService, if type(art) == "table" then art else ART, options)
	local city = ctx.group(root, "Maré Baixa")
	city.WorldPivot = CFrame.new()
	city:SetAttribute("CityVersion", CITY_VERSION)
	city:SetAttribute("MareBaixaVersion", 1)
	city:SetAttribute("LarguraEmStuds", Layout.halfX * 2)
	city:SetAttribute("ComprimentoEmStuds", Layout.halfZ * 2)
	city:SetAttribute("PassoDaQuadra", Layout.pitch)
	local plots = ctx.group(city, "Quadras")
	local plaza = Mare.PublicSpace.new(ctx)
	local points = {}
	local function point(key: string, name: string, position: Vector3)
		table.insert(points, {key = key, name = name, position = position})
	end
	point("praca", "Praça do Dique (início)", SPAWN)

	local function blockAt(column: number, row: number)
		local kind = Layout.blocks[row][column]
		local x, z = Layout.cell(column, row)
		local id = string.char(64 + column) .. row
		local plot = ctx.group(plots, id .. " · " .. BLOCK_NAMES[kind])
		plot.WorldPivot = CFrame.new(x, 0, z)
		plot:SetAttribute("Quadra", id)
		plot:SetAttribute("Tipo", kind)
		local seed = 202607 + row * 941 + column * 1651
		local tone = if kind == "docks" or kind == "grid" or kind == "warehouse" then rgb(69, 71, 83) else rgb(76, 81, 95)
		local x0, x1 = x - 99, x + 99
		if column == 5 then
			x1 = -29
		elseif column == 6 then
			x0 = 29
		end
		ctx.box(plot, "Base transitável da quadra", (x0 + x1) / 2, -1.02, z, x1 - x0, 2.02, 198, tone, "cement", {shadow = false})
		if TOWER_TYPES[kind] then
			Mare.Buildings.tower(ctx, plot, x, z, seed, kind)
		elseif RESIDENTIAL_TYPES[kind] then
			Mare.Buildings.residential(ctx, plot, x, z, seed, kind)
		elseif kind == "arcade" or kind == "sodio" then
			Mare.Commerce.market(ctx, plot, x, z, seed, kind)
		elseif kind == "warehouse" or kind == "docks" then
			Mare.Commerce.industrial(ctx, plot, x, z, seed, kind)
		elseif kind == "grid" then
			Mare.Commerce.utility(ctx, plot, x, z, seed, kind)
		else
			plaza.plaza(plot, x, z, seed, kind)
		end
		plaza.furniture(plot, x, z, seed + 3, row * 10 + column)
		if id == "E5" then
			point("colmeia", "Edifício Colmeia (apartamentos)", plaza.colmeia(plot, colmeiaX, colmeiaZ, Layout.walkY))
		end
	end

	-- Os pavers visíveis são as primeiras peças do cenário detalhado.
	blockAt(5, 4)
	local mirrors = Mare.Streets.build(ctx, city, Layout)
	local liftPads = Mare.Transit.build(ctx, city, Layout)
	for row, cells in Layout.blocks do
		for column in cells do
			if column ~= 5 or row ~= 4 then
				blockAt(column, row)
			end
		end
	end

	local storefronts = ctx.group(city, "Bancas e caixas da Maré")
	for _, site in {
		{-385, -197, 0.09}, {391, -437, 0.24}, {-818, 520, 0.09},
		{68, -50, 0.034}, {-126, 141, 0.034},
	} do
		Mare.Commerce.atm(ctx, storefronts, table.unpack(site))
	end
	for _, site in {{-148, -62, 0.034}, {-90, 184, 0.034}, {120, 200, 0.09}} do
		Mare.Commerce.cart(ctx, storefronts, table.unpack(site))
	end
	local parking = ctx.group(city, "Carros estacionados")
	Mare.Commerce.parkedCar(ctx, parking, -195, 116, 0.034, rgb(89, 34, 38))
	Mare.Commerce.parkedCar(ctx, parking, -894, 523, 0.09, rgb(48, 56, 73))
	Mare.Commerce.parkedCar(ctx, parking, 186, 200, 0.09, rgb(125, 93, 57))
	local way = ctx.group(city, "Caminho para o Colmeia")
	local sign = ctx.box(way, "Placa para os apartamentos", -130, 7.2, -43, 13, 3.6, 0.3, rgb(22, 27, 41), "metal",
		{collision = false})
	ctx.box(way, "Suporte da placa", -136, 3.7, -43, 0.5, 7.4, 0.5, rgb(59, 65, 78), "steel")
	ctx.sign(sign, "Front", "COLMEIA\nATRAVESSE A AVENIDA", rgb(219, 176, 253))

	local districtPoints = {
		docas = Vector3.new(-840, 0.07, 516),
		centro = Vector3.new(-115, 0.034, -115),
		mercado = Vector3.new(-360, 0.09, -192),
		corporativo = Vector3.new(360, 0.24, -438),
		colmeia = Vector3.new(-120, 0.034, -600),
	}
	for _, district in DISTRICTS do
		point("bairro_" .. district.key, district.name, districtPoints[district.key])
	end
	point("estacao", "Estação do Dique (monotrilho)", Vector3.new(Layout.stationX, Layout.deck + 0.8, -15.75))
	point("viaduto", "Ponte da Avenida Central", Vector3.new(0, 0.065, -28.45))
	table.sort(mirrors, function(a, b)
		return (a.CFrame.Position - SPAWN).Magnitude < (b.CFrame.Position - SPAWN).Magnitude
	end)
	for index = 1, math.min(3, #mirrors) do
		local position = mirrors[index].CFrame.Position
		point("poca_" .. index, "Poça com reflexo " .. index, Vector3.new(position.X, Layout.roadY, position.Z))
	end

	ctx.finish()
	city:SetAttribute("Ready", true)
	return city, {spawn = spawn, stats = ctx.stats, layout = layoutData(), points = points, liftPads = liftPads}
end

local function applyLighting(lighting: Lighting, art)
	art = if type(art) == "table" then art else ART
	local function effect(class: string, name: string, reuseClass: boolean?)
		local existing = lighting:FindFirstChild(name)
		if reuseClass and not existing then
			existing = lighting:FindFirstChildOfClass(class)
		end
		local item = existing or Instance.new(class)
		item.Name = name
		item.Parent = lighting
		return item
	end
	lighting.ClockTime = 1.15
	lighting.Brightness = 2.15
	lighting.GlobalShadows = true
	lighting.ShadowSoftness = 0.38
	lighting.ExposureCompensation = 0.18
	lighting.GeographicLatitude = 25
	lighting.Ambient = rgb(69, 70, 91)
	lighting.OutdoorAmbient = rgb(82, 92, 121)
	lighting.EnvironmentDiffuseScale = 0.70
	lighting.EnvironmentSpecularScale = 0.92

	local haze = effect("Atmosphere", "Névoa de Maré Baixa", true)
	haze.Density = 0.21
	haze.Offset = 0
	haze.Color = rgb(123, 144, 188)
	haze.Decay = rgb(55, 65, 103)
	haze.Haze = 1.55
	haze.Glare = 0
	local bloom = effect("BloomEffect", "CyberOutlawCityBloom")
	bloom.Intensity = 0.26
	bloom.Size = 25
	bloom.Threshold = 0.86
	local grade = effect("ColorCorrectionEffect", "CyberOutlawCityGrade")
	grade.Brightness = 0.024
	grade.Contrast = 0.075
	grade.Saturation = -0.12
	grade.TintColor = rgb(231, 235, 255)

	local sky = effect("Sky", "Céu de Maré Baixa", true)
	local faceIds = {}
	for _, face in {"Bk", "Dn", "Ft", "Lf", "Rt", "Up"} do
		faceIds["Skybox" .. face] = Mare.Context.imageId(art["ceu_" .. string.lower(face)])
	end
	local faceCount = 0
	for _ in faceIds do
		faceCount += 1
	end
	if faceCount == 6 then
		for property, id in faceIds do
			sky[property] = id
		end
		sky.StarCount = 0
		sky.CelestialBodiesShown = false
	else
		sky.StarCount = 400
		sky.MoonAngularSize = 13
	end
end

local function publishPoints(replication: ReplicatedStorage, http: HttpService, points)
	local folder = replication:FindFirstChild("CyberOutlawPontos") or Instance.new("Folder")
	folder.Name = "CyberOutlawPontos"
	local list = {}
	for _, item in points do
		folder:SetAttribute(item.key, item.position)
		table.insert(list, {k = item.key, n = item.name})
	end
	folder:SetAttribute("Lista", http:JSONEncode(list))
	folder.Parent = replication
end

local function assignSpawn(players: Players, spawn: SpawnLocation)
	local joined = setmetatable({}, {__mode = "k"})
	local function arrive(player: Player, character: Model)
		task.defer(function()
			if player:GetAttribute("CyberOutlawArrived") or player.Character ~= character then
				return
			end
			local rootPart = character:WaitForChild("HumanoidRootPart", 10)
			if not rootPart or player.Character ~= character then
				return
			end
			if (rootPart.Position - spawn.Position).Magnitude > 8 then
				character:PivotTo(spawn.CFrame + Vector3.new(0, 3.5, 0))
				rootPart.AssemblyLinearVelocity = Vector3.zero
			end
			player:SetAttribute("CyberOutlawArrived", true)
		end)
	end
	local function join(player: Player)
		if joined[player] then
			return
		end
		joined[player] = true
		player.RespawnLocation = spawn
		player.CharacterAdded:Connect(function(character)
			arrive(player, character)
		end)
		if player.Character then
			arrive(player, player.Character)
		end
	end
	players.PlayerAdded:Connect(join)
	for _, player in players:GetPlayers() do
		join(player)
	end
end

local function wireLifts(pads)
	local lastRide = setmetatable({}, {__mode = "k"})
	for _, pad in pads do
		local destination = pad:GetAttribute("Destino")
		pad.Touched:Connect(function(hit)
			local character = hit.Parent
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or humanoid.Health <= 0 or not root then
				return
			end
			local now = os.clock()
			if now - (lastRide[character] or -math.huge) < 2 then
				return
			end
			lastRide[character] = now
			local look = root.CFrame.LookVector
			character:PivotTo(CFrame.lookAt(destination, destination + Vector3.new(look.X, 0, look.Z)))
			root.AssemblyLinearVelocity = Vector3.zero
		end)
	end
end

local function concealTemplate()
	local function conceal(part: BasePart)
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		for _, child in part:GetChildren() do
			if child:IsA("Decal") or child:IsA("Texture") then
				child.Transparency = 1
			end
		end
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		conceal(baseplate)
	end
	for _, item in workspace:GetChildren() do
		if item:IsA("SpawnLocation") then
			item.Enabled = false
			conceal(item)
		end
	end
end

local function main()
	local players = game:GetService("Players")
	local replication = game:GetService("ReplicatedStorage")
	local http = game:GetService("HttpService")
	if workspace:FindFirstChild("CyberOutlawCity") then
		return
	end
	local root = Instance.new("Model")
	root.Name = "CyberOutlawCity"
	root:SetAttribute("SafeZoneCenter", Vector3.new(plazaX, 0, plazaZ))
	root:SetAttribute("SafeZoneRadius", SAFE_RADIUS)
	local spawn = spawnAt(root)
	root.Parent = workspace
	assignSpawn(players, spawn)
	local lightingReady, lightingError = pcall(applyLighting, game:GetService("Lighting"), ART)
	if not lightingReady then
		warn("[CyberOutlaw] Configuração da iluminação da cidade:", lightingError)
	end
	local started = os.clock()
	local _, info = buildCity(root, ART, {
		materialService = game:GetService("MaterialService"),
		spawn = spawn,
		yield = task.wait,
	})
	concealTemplate()
	wireLifts(info.liftPads)
	publishPoints(replication, http, info.points)
	local board = replication:FindFirstChild("CyberOutlawCityInfo") or Instance.new("Configuration")
	board.Name = "CyberOutlawCityInfo"
	board:SetAttribute("Layout", http:JSONEncode(info.layout))
	board:SetAttribute("Version", CITY_VERSION)
	board.Parent = replication
	print(string.format("[CyberOutlaw] Maré Baixa pronta: %d peças, %d luzes e %d letreiros em %.1fs",
		info.stats.parts, info.stats.lights, info.stats.signs, os.clock() - started))
end

if typeof(game) == "Instance" then
	main()
end

return buildCity, applyLighting, layoutData, districtAt
