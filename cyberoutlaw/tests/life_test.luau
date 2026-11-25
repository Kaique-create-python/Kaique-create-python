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
