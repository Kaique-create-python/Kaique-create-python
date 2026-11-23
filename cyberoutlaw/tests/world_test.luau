-- Monta Maré Baixa fora do Roblox e confere geometria, pistas, spawn e orçamento.
-- Uso: lune run tests/world_test.luau [arquivo.json para exportar a prévia]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local normals = {
	Front = roblox.Vector3.new(0, 0, -1), Back = roblox.Vector3.new(0, 0, 1),
	Left = roblox.Vector3.new(-1, 0, 0), Right = roblox.Vector3.new(1, 0, 0),
	Top = roblox.Vector3.new(0, 1, 0), Bottom = roblox.Vector3.new(0, -1, 0),
}
local Vector3 = setmetatable({
	FromNormalId = function(face)
		return normals[face.Name]
	end,
}, { __index = roblox.Vector3 })

local function load(art)
	local source = fs.readFile("src/world.server.luau")
	assert(select(2, source:gsub("__CYBEROUTLAW_ART__", "")) == 1, "o script deve ter um marcador de arte")
	source = source:gsub("__CYBEROUTLAW_ART__", art)
	local chunk = luau.load(source, {
		debugName = "world.server.luau",
		environment = {
			Instance = roblox.Instance, CFrame = roblox.CFrame, Vector2 = roblox.Vector2, Vector3 = Vector3,
			Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence, Enum = roblox.Enum, UDim2 = roblox.UDim2,
			Font = roblox.Font, Content = roblox.Content, NumberSequence = roblox.NumberSequence,
			NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, NumberRange = roblox.NumberRange,
		},
	})
	return chunk()
end

local ART = '{["asphalt"] = 1001, ["asphalt_normal"] = 1002, ["asphalt_rough"] = 1003, ["concrete"] = 1004, '
	.. '["concrete_normal"] = 1005, ["fachada_escritorio"] = 1006, ["fachada_residencial"] = 1007, ["fachada_vidro"] = 1008}'

local function bounds(part)
	local cf, size = part.CFrame, part.Size
	local r = { cf:GetComponents() }
	local half = size / 2
	local ex = math.abs(r[4]) * half.X + math.abs(r[5]) * half.Y + math.abs(r[6]) * half.Z
	local ey = math.abs(r[7]) * half.X + math.abs(r[8]) * half.Y + math.abs(r[9]) * half.Z
	local ez = math.abs(r[10]) * half.X + math.abs(r[11]) * half.Y + math.abs(r[12]) * half.Z
	local p = cf.Position
	return p.X - ex, p.X + ex, p.Y - ey, p.Y + ey, p.Z - ez, p.Z + ez
end

local function check(art)
	local buildCity, applyLighting, layoutData, districtAt = load(art)
	assert(type(buildCity) == "function" and type(applyLighting) == "function")
	local world = roblox.Instance.new("WorldModel")
	local started = os.clock()
	local city, info = buildCity(world, if art == "{}" then {} else serde.decode("json", "{}"), nil)
	if art ~= "{}" then
		-- O teste com arte reconstrói pela tabela real, como o instalador grava.
		world = roblox.Instance.new("WorldModel")
		local artTable = {}
		for key, value in art:gmatch('%["([%w_]+)"%] = (%d+)') do
			artTable[key] = tonumber(value)
		end
		city, info = buildCity(world, artTable, nil)
	end
	local seconds = os.clock() - started
	local parts, solids, guis, lights, windows = {}, {}, 0, 0, 0
	for _, node in city:GetDescendants() do
		if node:IsA("BasePart") and not node:IsA("SpawnLocation") then
			assert(node.Anchored, "peça solta: " .. node:GetFullName())
			local s = node.Size
			assert(s.X <= 2048 and s.Y <= 2048 and s.Z <= 2048, "peça acima de 2048: " .. node.Name)
			assert(s.X >= 0.05 and s.Y >= 0.05 and s.Z >= 0.05, "peça fina demais: " .. node.Name)
			local p = node.CFrame.Position
			assert(p.X == p.X and p.Y == p.Y and p.Z == p.Z, "posição inválida: " .. node.Name)
			table.insert(parts, node)
			if node.CanCollide then
				table.insert(solids, node)
			end
		elseif node:IsA("SurfaceGui") or node:IsA("BillboardGui") then
			guis += 1
			if node.Name == "Janelas" then
				windows += 1
			end
		elseif node:IsA("Light") then
			lights += 1
		end
	end
	assert(#parts == info.stats.parts, string.format("contagem de peças divergente: %d e %d", #parts, info.stats.parts))

	-- Pistas livres para veículos futuros: nada sólido abaixo de 14 studs sobre as faixas de rolamento.
	local layout = layoutData()
	local lanes = {}
	for index, line in layout.lines do
		local p, width = line[1], line[2]
		local inner = if width == 56 then 4 else 0
		for k = 1, #layout.lines - 1 do
			local a, b = layout.lines[k], layout.lines[k + 1]
			local from, to = a[1] + a[2] / 2 + 1, b[1] - b[2] / 2 - 1
			for _, side in { -1, 1 } do
				local o0, o1 = side * (inner + 0.5), side * (width / 2 - 0.5)
				local lo, hi = math.min(o0, o1), math.max(o0, o1)
				table.insert(lanes, { from, to, p + lo, p + hi }) -- via em X, eixo z = p
				table.insert(lanes, { p + lo, p + hi, from, to }) -- via em Z, eixo x = p
			end
		end
		local _ = index
	end
	local ground = { ["Asfalto molhado"] = true }
	for _, part in solids do
		if ground[part.Name] then
			continue
		end
		local x0, x1, y0, y1, z0, z1 = bounds(part)
		if y0 > 14 or y1 < 0.3 then
			continue
		end
		for _, lane in lanes do
			if x0 < lane[2] - 0.01 and x1 > lane[1] + 0.01 and z0 < lane[4] - 0.01 and z1 > lane[3] + 0.01 then
				error(string.format("%s bloqueia a pista em (%.1f, %.1f)", part:GetFullName(), part.CFrame.Position.X, part.CFrame.Position.Z))
			end
		end
	end

	-- Spawn com chão firme e espaço livre acima.
	local spawn = info.spawn
	assert(spawn and spawn:IsA("SpawnLocation") and spawn.Neutral)
	local sp = spawn.CFrame.Position
	local floor = false
	for _, part in solids do
		local x0, x1, y0, y1, z0, z1 = bounds(part)
		if sp.X > x0 and sp.X < x1 and sp.Z > z0 and sp.Z < z1 then
			if y1 > sp.Y - 0.6 and y1 < sp.Y + 0.3 then
				floor = true
			elseif y1 > sp.Y + 0.3 and y0 < sp.Y + 7 then
				error("obstáculo no spawn: " .. part:GetFullName())
			end
		end
	end
	assert(floor, "spawn sem chão")
	assert(districtAt(sp.X, sp.Z).key == "centro", "o spawn deve ficar no Distrito Prisma")

	-- Monotrilho livre: nenhum sólido fora do próprio monotrilho no corredor do viaduto.
	local ring = layout.monorail
	local rail = city:FindFirstChild("Monotrilho Linha Anel")
	for index, point in ring do
		local nextPoint = ring[index % #ring + 1]
		local a, b = roblox.Vector3.new(point[1], 63.5, point[2]), roblox.Vector3.new(nextPoint[1], 63.5, nextPoint[2])
		for t = 0, 1, 0.02 do
			local q = a:Lerp(b, t)
			for _, part in solids do
				if part:IsDescendantOf(rail) then
					continue
				end
				local x0, x1, y0, y1, z0, z1 = bounds(part)
				if q.X > x0 - 5 and q.X < x1 + 5 and q.Z > z0 - 5 and q.Z < z1 + 5 and q.Y > y0 - 3 and q.Y < y1 + 3 then
					error("obstáculo no viaduto: " .. part:GetFullName())
				end
			end
		end
	end

	for _, line in layout.lines do
		for _, other in layout.lines do
			assert(districtAt(line[1], other[1]), "ponto sem distrito")
		end
	end
	assert(#serde.encode("json", layout) < 4000, "o layout do minimapa deve ser compacto")
	return {
		parts = #parts, solids = #solids, guis = guis, windows = windows, lights = lights,
		towers = info.stats.towers, signs = info.stats.signs, emitters = info.stats.emitters, seconds = seconds, city = city,
	}
end

local plain = check("{}")
local dressed = check(ART)
for label, result in { ["sem janelas"] = plain, ["com janelas"] = dressed } do
	print(string.format("Maré Baixa %s: %d peças (%d sólidas), %d torres, %d letreiros, %d GUIs (%d de janelas), %d luzes, %d emissores, %.2fs",
		label, result.parts, result.solids, result.towers, result.signs, result.guis, result.windows, result.lights, result.emitters, result.seconds))
	assert(result.parts < 26000, "peças acima do orçamento")
	assert(result.lights < 1100, "luzes acima do orçamento")
	assert(result.guis < 2600, "superfícies acima do orçamento")
	assert(result.towers >= 60, "a cidade precisa de prédios altos")
	assert(result.city:GetAttribute("BarrisDeFogo") >= 20, "the market has fire barrels")
	assert(result.emitters < 120, "too many particle emitters for a phone")
end

-- Exporta a prévia: peças, superfícies e luzes da versão com janelas.
local output = process.args[1]
if output then
	local function color(c)
		return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
	end
	local rows, panels, lamps = {}, {}, {}
	local index = 0
	for _, node in dressed.city:GetDescendants() do
		if not node:IsA("BasePart") or node:IsA("SpawnLocation") then
			continue
		end
		index += 1
		local shape = if node:IsA("Part") then node.Shape.Name else "Block"
		table.insert(rows, {
			n = node.Name, c = { node.CFrame:GetComponents() }, s = { node.Size.X, node.Size.Y, node.Size.Z },
			k = color(node.Color), m = node.Material.Name, t = node.Transparency, r = node.Reflectance, h = shape,
		})
		for _, inner in node:GetChildren() do
			if inner:IsA("SurfaceGui") then
				local row = { p = index, f = inner.Face.Name, g = inner.Name }
				local image = inner:FindFirstChildOfClass("ImageLabel")
				if image then
					row.i = image.Image
					row.o = { image.Position.X.Offset / 2, image.Position.Y.Offset / 2 }
				end
				local text = inner:FindFirstChildWhichIsA("TextLabel", true)
				if text then
					row.x = text.Text
					row.tc = color(text.TextColor3)
				end
				local back = inner:FindFirstChildOfClass("Frame")
				if back then
					local gradient = back:FindFirstChildOfClass("UIGradient")
					if gradient then
						row.bg = { color(gradient.Color.Keypoints[1].Value), color(gradient.Color.Keypoints[#gradient.Color.Keypoints].Value) }
					end
				end
				table.insert(panels, row)
			elseif inner:IsA("Light") then
				table.insert(lamps, { p = index, k = color(inner.Color), b = inner.Brightness, r = inner.Range, y = inner.ClassName })
			end
		end
	end
	fs.writeFile(output, serde.encode("json", { parts = rows, panels = panels, lights = lamps }))
	print(string.format("Prévia exportada: %d peças, %d superfícies, %d luzes em %s", #rows, #panels, #lamps, output))
end
