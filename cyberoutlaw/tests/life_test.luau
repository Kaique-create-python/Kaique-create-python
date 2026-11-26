-- Monta os móveis, pedestres e lixo do life.server.luau fora do Roblox e confere que nada quebra.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local source = fs.readFile("src/life.server.luau")
if not source:find("\nreturn M%s*$") then
	source ..= "\nreturn M\n"
end
local env = {
	Instance = roblox.Instance, CFrame = roblox.CFrame, Vector2 = roblox.Vector2, Vector3 = roblox.Vector3, Color3 = roblox.Color3,
	ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, NumberRange = roblox.NumberRange, Enum = roblox.Enum, UDim2 = roblox.UDim2, UDim = roblox.UDim,
}
local L = luau.load(source, { debugName = "life.server.luau", environment = env })()
local total = 0
for _, def in L.FURNITURE do
	local model, size = L.buildFurniture(def)
	local n = 0
	for _, d in model:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	total += n
	print(string.format("%-16s %5d €$  %2d peças  %.1f x %.1f x %.1f", def.id, def.preco, n, size.X, size.Y, size.Z))
end
print("móveis", #L.FURNITURE, "peças", total)
for _, kind in { "civil", "civil", "civil", "gangue", "alvo", "policia", "camelo", "contato", "swat" } do
	local model, spec = L.buildPedestrian(math.random(1, 1e6), kind, if kind == "gangue" or kind == "alvo" then "vudu" else nil)
	local n = 0
	for _, d in model:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	print(kind, spec.style, n)
end
for _, def in L.TRASH do
	local m = L.buildTrash(def)
	print("lixo", def.id, #m:GetChildren())
end
print("CyberOutlawVida: móveis, pedestres, lixo e regras montados")

-- Polícia de 7 estrelas: viaturas montam com corpo, arma e grupos que giram; SWAT veste a farda; rota pelas faixas.
assert(L.WANTED.max == 7 and #L.WANTED.decay == 7 and #L.WANTED.cops == 7, "procurado com 7 estrelas")
assert(L.wantedAfter(6, "policia") == 7 and L.wantedAfter(7, "tanque") == 7 and L.wantedAfter(0, "swat") == 2)
for name, build in { helicoptero = L.buildHeli, av = L.buildAV, tanque = L.buildTank } do
	local model = build()
	local parts, groups = 0, {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			parts += 1
			local group = item:GetAttribute("Grupo")
			if group then
				groups[group] = (groups[group] or 0) + 1
			end
		end
	end
	local gun = model:FindFirstChild("CyberOutlawArma")
	assert(model.PrimaryPart and model.PrimaryPart.Name == "Corpo", name .. " sem Corpo")
	assert(gun and gun.PrimaryPart and gun.PrimaryPart:FindFirstChild("Cano"), name .. " sem cano")
	if name == "helicoptero" then
		assert(groups.rotor == 5 and groups.cauda == 3, "rotores do helicóptero")
	elseif name == "tanque" then
		assert((groups.torre or 0) >= 6, "torre do tanque")
	else
		assert(model.PrimaryPart:FindFirstChild("Porta1") and model.PrimaryPart:FindFirstChild("Porta2"), "portas do AV")
	end
	print("viatura", name, parts, "peças")
end
local swat, swatSpec = L.buildPedestrian(4242, "swat", nil)
assert(swatSpec.style == "swat" and swat:FindFirstChild("Balaclava", true) and swat:FindFirstChild("Placa do colete", true), "farda da SWAT")
local lines = {}
for p = -1000, 1000, 200 do
	table.insert(lines, { p, if p % 400 == 0 then 76 else 44, 14 })
end
local route = L.streetRoute(lines, Vector3.new(400, 0, -200), Vector3.new(-130, 0, 175), 3.6)
for index, point in route do
	local x, xw = L.nearestLine(lines, point.X)
	local z, zw = L.nearestLine(lines, point.Z)
	local onX = math.abs(math.abs(point.X - x) - L.laneOffset(xw)) < 0.01
	local onZ = math.abs(math.abs(point.Z - z) - L.laneOffset(zw)) < 0.01
	assert(onX or onZ, "ponto " .. index .. " fora da faixa")
	assert(math.abs(point.Y - 3.6) < 1e-3, "altura da rota")
end
assert((route[#route] - Vector3.new(-130, 3.6, 175)).Magnitude < 40, "a rota termina perto do alvo")
print("CyberOutlawVida: polícia com helicóptero, AV, tanque e SWAT montada; rota do tanque nas faixas", #route)

local mare = {
	xLines = {}, zLines = {}, halfX = 1200, halfZ = 960,
	roadY = -0.266, walkY = 0.04, canal = { x = 0, width = 52 },
	safeZone = { -120, -120, 95 },
	bridges = {
		{ -960, 34, "road" }, { -720, 34, "road" }, { -480, 14, "foot" },
		{ -240, 34, "road" }, { 0, 50, "road" }, { 240, 14, "foot" },
		{ 480, 44, "road" }, { 720, 14, "foot" }, { 960, 34, "road" },
	},
}
for x = -1200, 1200, 240 do
	table.insert(mare.xLines, { x, if x == 0 then 56 elseif math.abs(x) == 720 then 44 else 34, if x == 0 then 12.8 else 12.2 })
end
for z = -960, 960, 240 do
	table.insert(mare.zLines, { z, if z == 0 then 50 elseif math.abs(z) == 480 then 44 else 34, 12.2 })
end
mare.lines = mare.xLines

local blocks, blockList = L.cityBlocks(mare)
assert(#blockList == 80 and not blocks["1,9"], "os eixos independentes formam 10 x 8 quadras")
local westBank, eastBank = blocks["5,4"], blocks["6,4"]
assert(westBank.bank == -1 and eastBank.bank == 1, "a orla separa os anéis por margem")
for _, case in { { westBank, 2, -1 }, { eastBank, 1, 1 } } do
	local point = L.corner(case[1], case[2], 1)
	assert(point.X * case[3] > 31 and point.X * case[3] < 41, "canto no passeio ribeirinho")
	assert(point.Z > -218 and point.Z < -210 and math.abs(point.Y - 0.04) < 1e-4, "canto no passeio do eixo Z")
	local mid = L.ringPoint(case[1], case[2], 0.5, 1)
	local cf = L.corridor(point, mid, 2)
	assert(math.abs(cf.Position.Y - 3.24) < 1e-4, "corredor usa o piso da calçada")
end

local roads = L.roadNetwork(mare)
local function checkRoute(points)
	assert(#points >= 2, "o tanque deve chegar ao outro lado")
	local crossing, totalDistance = nil, 0
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local dx, dz = b.X - a.X, b.Z - a.Z
		assert(math.abs(a.Y - 3.134) < 1e-4 and math.abs(b.Y - a.Y) < 1e-4, "a altura segue o asfalto")
		assert((dx == 0 and dz ~= 0) or (dz == 0 and dx ~= 0), "trajeto sem diagonais")
		totalDistance += (b - a).Magnitude
		if dz == 0 then
			local axis, width = L.nearestLine(mare.zLines, a.Z)
			local offset = (a.Z - axis) * math.sign(dx)
			assert(offset > 6 and offset < width / 2 - 5.6, "tanque deve caber na faixa direita da avenida")
			if a.X * b.X < 0 then
				assert(axis == -960 or axis == -720 or axis == -240 or axis == 0 or axis == 480 or axis == 960, "o tanque só cruza em pontes viárias")
				crossing = axis
			end
			assert(axis ~= 0 or offset > 9.1, "a carcaça não alcança as bases dos pilares da linha aérea")
		else
			local axis, width = L.nearestLine(mare.xLines, a.X)
			local offset = (axis - a.X) * math.sign(dz)
			assert(axis ~= 0 and offset > 6 and offset < width / 2 - 5.6, "tanque deve caber na faixa direita da rua")
		end
	end
	assert(totalDistance < 1100, "rota de chegada limitada")
	return crossing
end
local detourTarget = Vector3.new(95, 0, -480)
local detour = L.streetRoute(roads, Vector3.new(-240, 0, -480), detourTarget, 3.134)
local detourRow = checkRoute(detour)
assert(detourRow == -720 or detourRow == -240, "a passarela exige um desvio pela ponte viária vizinha")
assert((detour[#detour] - detourTarget).Magnitude < 15, "o desvio termina na rua do alvo")
local viaductRoute = L.streetRoute(roads, Vector3.new(-240, 0, 0), Vector3.new(160, 0, 0), 3.134)
assert(checkRoute(viaductRoute) == 0, "o tanque usa as faixas livres da ponte sob o viaduto")

local disconnected = table.clone(mare)
disconnected.bridges = { { -480, 14, "foot" } }
assert(#L.streetRoute(disconnected, Vector3.new(-240, 0, -480), detourTarget, 3.134) == 0, "rota inexistente entre margens sem ponte viária")
assert(#L.streetRoute(roads, Vector3.new(-1200, 0, -960), Vector3.new(1200, 0, 960), 3.134) == 0, "o tanque não planeja uma travessia longa da cidade inteira")

local drop = L.roadDropPoint(roads, Vector3.new(-10, 5, 240), function(point)
	assert(point.X <= -56 and math.abs(point.Z - 240) < 12, "rapel a oeste da passarela, na pista")
	return -0.266
end)
assert(drop and math.abs(drop.Y + 0.266) < 1e-4, "rapel usa o piso confirmado")
assert(not L.roadDropPoint(roads, Vector3.new(-10, 5, 240), function() return nil end), "sem descida com céu obstruído")
assert(not L.roadDropPoint(roads, Vector3.new(-10, 5, 240), function() return -3.28 end), "sem descida sobre o canal")
local middleOfBlock = Vector3.new(-360, 0, -360)
local outerDrop = L.roadDropPoint(roads, middleOfBlock, function() return -0.266 end)
assert(outerDrop and (outerDrop - middleOfBlock).Magnitude < 145, "a SWAT consegue chegar às quadras de 240 studs")

local safe, far = blocks["5,4"], blocks["1,1"]
local offer = L.missionOffer(4242, "cidinha", "entrega", {
	origin = Vector3.new(-120, 0, -120), blocks = { safe, far }, safeZone = mare.safeZone,
})
assert(offer and offer.bloco == far.key and offer.blocoDestino == far.key, "missões continuam fora da nova zona segura quando caem no destino alternativo")
local atm = Vector3.new(-360, 0.04, -450)
local robbery = L.missionOffer(4242, "cidinha", "roubo", {
	origin = Vector3.new(-120, 0, -120), blocks = { safe, far }, safeZone = mare.safeZone,
	atms = { Vector3.new(-120, 0.04, -120), atm },
})
assert(robbery and robbery.alvo == atm, "o assalto usa um caixa fora da zona segura")
print("CyberOutlawVida: quadras retangulares, rotas sobre as pontes viárias, rapel fora do canal e missões fora da praça")

-- Cliente: regras puras (dinheiro, relógio e se o móvel cabe, igual ao servidor).
local client = luau.load(fs.readFile("src/life.client.luau"):gsub("__CYBEROUTLAW_MEDIA__", "{}"), { debugName = "life.client.luau", environment = env })()
assert(client.money(1250) == "€$ 1.250" and client.money(250) == "€$ 250" and client.money(-1234567) == "-€$ 1.234.567", client.money(1250))
assert(client.clock(125) == "2:05")
local unit = { meia = { 26, 21 }, livre = { 12, 26, 8, 21 } }
local sizes, floors = {}, {}
for _, def in L.FURNITURE do
	local _, size = L.buildFurniture(def)
	sizes[def.id] = size
	floors[def.id] = def.chao == true
end
for _, case in { { "sofa_couro", 0, 0, 0, {} }, { "sofa_couro", 30, 0, 0, {} }, { "sofa_couro", 20, 15, 0, {} }, { "sofa_couro", 0, 0, 0, { { u = 1, id = "cama_neon", x = 0, z = 0, r = 0 } } },
	{ "tapete_holo", 0, 0, 1, { { u = 1, id = "cama_neon", x = 0, z = 0, r = 0 } } } } do
	local a = client.fits(unit, sizes, floors, case[5], case[1], case[2], case[3], case[4], nil)
	local b = L.canPlace(sizes, case[5], case[1], case[2], case[3], case[4], nil)
	assert(a == b, "cliente e servidor discordam em " .. case[1])
end
print("CyberOutlawVida cliente: dinheiro, prazo e encaixe dos móveis iguais ao servidor")
