-- Gera o cenário do servidor em Lune. Um caminho opcional exporta a cena para o renderizador de Maré Baixa.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local rbx = require("@lune/roblox")
local serde = require("@lune/serde")
local worldSource = require("./support/world_source")

local env = {
	Instance = rbx.Instance, CFrame = rbx.CFrame, Vector2 = rbx.Vector2, Vector3 = rbx.Vector3,
	Color3 = rbx.Color3, Enum = rbx.Enum, UDim2 = rbx.UDim2, Font = rbx.Font,
}
local vec = rbx.Vector3.new

local function artLiteral(art)
	local fields = {}
	for key, id in art do
		table.insert(fields, string.format("[%q]=%s", key, tostring(id)))
	end
	table.sort(fields)
	return "{" .. table.concat(fields, ",") .. "}"
end

local function bounds(part)
	local cf, size = part.CFrame, part.Size / 2
	local r = {cf:GetComponents()}
	local x = math.abs(r[4]) * size.X + math.abs(r[5]) * size.Y + math.abs(r[6]) * size.Z
	local y = math.abs(r[7]) * size.X + math.abs(r[8]) * size.Y + math.abs(r[9]) * size.Z
	local z = math.abs(r[10]) * size.X + math.abs(r[11]) * size.Y + math.abs(r[12]) * size.Z
	return {part = part, x0 = r[1] - x, x1 = r[1] + x, y0 = r[2] - y, y1 = r[2] + y, z0 = r[3] - z, z1 = r[3] + z}
end

local function verticalIntersection(part, x, z)
	local cf, size = part.CFrame, part.Size / 2
	local origin = cf:PointToObjectSpace(vec(x, 0, z))
	local up = cf:VectorToObjectSpace(rbx.Vector3.yAxis)
	local low, high = -math.huge, math.huge
	for _, axis in {"X", "Y", "Z"} do
		if math.abs(up[axis]) < 1e-6 then
			if math.abs(origin[axis]) > size[axis] then
				return nil
			end
		else
			local a = (-size[axis] - origin[axis]) / up[axis]
			local b = (size[axis] - origin[axis]) / up[axis]
			low, high = math.max(low, math.min(a, b)), math.min(high, math.max(a, b))
		end
	end
	if low < high then
		return low, high
	end
	return nil
end

local function supported(solids, name, at, radius)
	for _, offset in {{0, 0}, {-radius, 0}, {radius, 0}, {0, -radius}, {0, radius}} do
		local x, z = at.X + offset[1], at.Z + offset[2]
		local floor = false
		for _, box in solids do
			if x < box.x0 or x > box.x1 or z < box.z0 or z > box.z1 or box.y0 >= at.Y + 5.8 or box.y1 <= at.Y - 0.48 then
				continue
			end
			local bottom, top = verticalIntersection(box.part, x, z)
			if top and top > at.Y + 0.39 and bottom < at.Y + 5.8 then
				error(string.format("%s bloqueado por %s em (%.2f, %.2f)", name, box.part:GetFullName(), x, z))
			elseif top and top > at.Y - 0.48 then
				floor = true
			end
		end
		assert(floor, string.format("%s sem piso em (%.2f, %.2f)", name, x, z))
	end
end

local function verifyLayout(layout, districtAt)
	assert(layout.monorailMode == "shuttle", "a Linha 07 precisa ser publicada como vaivém")
	assert(layout.halfX == 1200 and layout.halfZ == 960 and layout.quay == 960, "dimensões incorretas")
	assert(#layout.xLines == 11 and #layout.zLines == 9 and layout.lines == layout.xLines)
	assert(layout.xLines[6][1] == 0 and layout.xLines[6][2] == 56 and layout.xLines[6][3] == 12.8)
	assert(layout.canal.x == 0 and layout.canal.width == 52 and layout.canal.bank == 42)
	assert(layout.safeZone[1] == -120 and layout.safeZone[2] == -120 and layout.safeZone[3] == 95)
	assert(layout.spawn[1] == -115 and layout.spawn[2] == -83)
	assert(math.abs(layout.roadY + 0.266) < 0.001 and math.abs(layout.walkY - 0.04) < 0.001)
	assert(layout.station[1] == 125 and layout.station[2] == -4.6 and layout.deck == 27)
	assert(#layout.monorail == 2 and layout.monorail[1][1] == -1170 and layout.monorail[2][1] == 1170)
	assert(layout.monorail[1][2] == -4.6 and layout.monorail[2][2] == -4.6)
	local expected = {"road", "road", "foot", "road", "road", "foot", "road", "foot", "road"}
	assert(#layout.bridges == #expected)
	for index, line in layout.zLines do
		local bridge = layout.bridges[index]
		assert(bridge[1] == line[1] and bridge[3] == expected[index], "ordem ou uso da travessia incorretos")
		assert(bridge[2] == (if bridge[3] == "road" then line[2] else 14), "largura divergente da travessia")
	end
	assert(districtAt(-360, -120).key == "mercado")
	assert(districtAt(360, -360).key == "corporativo")
	assert(districtAt(-840, 600).key == "docas")
	assert(districtAt(-120, -600).key == "colmeia")
	assert(districtAt(-115, -83).key == "centro")
	assert(#serde.encode("json", layout) < 4000, "layout acima do tamanho esperado para o minimapa")
end

local function verifyLighting(applyLighting, lighting, art)
	applyLighting(lighting)
	local bloom = lighting:FindFirstChild("CyberOutlawCityBloom")
	local grade = lighting:FindFirstChild("CyberOutlawCityGrade")
	assert(bloom and grade, "o ciclo visual do cliente precisa dos pós-efeitos nomeados")
	assert(lighting.ClockTime > 1 and lighting.ClockTime < 2 and lighting.Brightness > 2)
	assert(lighting:FindFirstChildOfClass("Atmosphere").Density < 0.4)
	local sky = lighting:FindFirstChildOfClass("Sky")
	if art.ceu_up then
		assert(sky.SkyboxUp == "rbxassetid://" .. art.ceu_up and sky.StarCount == 0 and not sky.CelestialBodiesShown)
	else
		assert(sky.StarCount == 400)
	end
end

local function check(art)
	local buildCity, applyLighting, layoutData, districtAt = luau.load(worldSource(artLiteral(art)), {
		debugName = "world.server.luau",
		environment = env,
	})()
	verifyLayout(layoutData(), districtAt)
	local place = rbx.Instance.new("DataModel")
	local workspace = place:GetService("Workspace")
	local materials = place:GetService("MaterialService")
	verifyLighting(applyLighting, place:GetService("Lighting"), art)
	local root = rbx.Instance.new("Model")
	root.Name = "CyberOutlawCity"
	root.Parent = workspace
	local spawn, batches = nil, 0
	local start = os.clock()
	local city, info = buildCity(root, nil, {
		materialService = materials,
		onSpawn = function(entry)
			assert(batches == 0, "o spawn deve ser publicado antes da primeira pausa")
			spawn = entry
			local early = {}
			for _, part in root:GetDescendants() do
				if part:IsA("BasePart") and part.CanCollide then
					table.insert(early, bounds(part))
				end
			end
			supported(early, "chegada inicial", spawn.CFrame.Position, 4)
			assert(not spawn.Parent.Parent:GetAttribute("Ready"), "o cenário ainda está em montagem")
		end,
		yield = function()
			assert(spawn, "a primeira pausa da montagem precisa de spawn seguro")
			batches += 1
		end,
	})
	assert(spawn == info.spawn and spawn.Neutral and spawn:IsA("SpawnLocation"))
	assert(city.Parent == root and city:GetAttribute("Ready") and #city:FindFirstChild("Quadras"):GetChildren() == 80)
	assert(batches > 50 and batches < 85, "montagem deve dividir as quadras em lotes")
	local parts, solids, lamps, signs, variants = {}, {}, 0, 0, 0
	local top, puddles, atms, vending, vendors = -math.huge, 0, 0, 0, {}
	for _, node in city:GetDescendants() do
		if node:IsA("BasePart") and not node:IsA("SpawnLocation") then
			assert(node.Anchored and (node.CanCollide or not node.CanQuery), node:GetFullName())
			local box = bounds(node)
			local size = node.Size
			assert(math.min(size.X, size.Y, size.Z) > 0 and math.max(size.X, size.Y, size.Z) <= 2048, node.Name)
			assert(box.x0 >= -1232.6 and box.x1 <= 1232.6 and box.z0 >= -996.1 and box.z1 <= 996.1, node:GetFullName())
			assert(box.y0 > -11 and box.y1 < 576, node:GetFullName())
			table.insert(parts, node)
			top = math.max(top, box.y1)
			if node.CanCollide then
				table.insert(solids, box)
			end
			if node.MaterialVariant ~= "" then
				variants += 1
				assert(materials:FindFirstChild(node.MaterialVariant).BaseMaterial == node.Material)
			end
			if node.Name == "Carrinho de comida" then
				table.insert(vendors, (node.CFrame * rbx.CFrame.new(4.4, 0, 0)).Position)
			elseif node.Name == "Máquina de venda" then
				vending += 1
			elseif node:GetAttribute("CyberOutlawRoubo") == "caixa" then
				atms += 1
				assert(node:FindFirstChild("Tela", true):FindFirstChildOfClass("TextLabel"))
			elseif node.Name == "Poça" then
				puddles += 1
				assert(math.abs(node:GetAttribute("CyberOutlawPlano") + 0.266) < 0.001 and node.Transparency > 0.5)
			end
		elseif node:IsA("Light") then
			assert(not node.Shadows)
			lamps += 1
		elseif node:IsA("SurfaceGui") then
			signs += 1
		end
	end
	assert(#parts == info.stats.parts and #solids == info.stats.colliders and lamps == info.stats.lights and signs == info.stats.signs)
	assert(#parts < 49000 and #solids < 21000 and lamps < 1000, "orçamento de cena excedido")
	assert(top >= 570 and atms == 5 and vending >= 3 and #vendors >= 10 and puddles >= 3)
	assert(city:FindFirstChild("Galpão da Doca do Sal", true) and city:FindFirstChild("Subestação da Maré", true))
	local plots = city:FindFirstChild("Quadras")
	local ids, types = {}, {}
	for _, plot in plots:GetChildren() do
		local id, kind = plot:GetAttribute("Quadra"), plot:GetAttribute("Tipo")
		assert(not ids[id] and plot:FindFirstChild("Base transitável da quadra"))
		ids[id], types[kind] = plot, true
	end
	local uniqueTypes = 0
	for _ in types do
		uniqueTypes += 1
	end
	assert(uniqueTypes >= 16 and ids.E4:GetAttribute("Tipo") == "spawn" and ids.G3:GetAttribute("Tipo") == "vertice")
	assert(ids.B7:GetAttribute("Tipo") == "docks" and ids.D4:GetAttribute("Tipo") == "sodio")
	assert(ids.G3:FindFirstChild("Torre Vértice", true) and ids.E4:FindFirstChild("Praça do Dique"))
	assert(ids.D4:FindFirstChild("Mercado do Sódio", true), "o mercado precisa manter sua quadra")

	for _, point in info.points do
		supported(solids, point.key, point.position, 1.3)
	end
	assert(#info.points == 12, "destinos do dono incompletos")
	for _, position in vendors do
		supported(solids, "camelô", vec(position.X, 0.25, position.Z), 0.8)
	end
	supported(solids, "chegada", spawn.CFrame.Position, 4)
	local bridgeGroups = city:FindFirstChild("Canal e pontes")
	for _, bridge in info.layout.bridges do
		local z, width, use = table.unpack(bridge)
		local crossing = bridgeGroups:FindFirstChild((if use == "road" then "Ponte " else "Passarela ") .. z)
		assert(crossing and crossing:FindFirstChild("Laje da travessia").Size.Z == width)
		for _, x in {-17, 0, 17} do
			supported(solids, "travessia " .. z, vec(x, -0.27, z), 1.2)
		end
	end

	local colmeia = city:FindFirstChild("Edifício Colmeia", true)
	assert(colmeia and colmeia:IsDescendantOf(ids.E5))
	assert(colmeia:FindFirstChild("Painel do elevador"):GetAttribute("CyberOutlawElevador") == "saguao")
	local floors, doors = {}, {}
	for _, part in colmeia:GetChildren() do
		if part.Name == "Unidade" then
			local floor = part:GetAttribute("Unidade")
			assert(not floors[floor], "marcadores duplicados")
			assert(part.Size == vec(52, 12, 42) and part.Transparency == 1 and not part.CanCollide)
			local at = part:GetAttribute("Chegada")
			assert(typeof(at) == "Vector3" and (at - part.CFrame.Position - vec(22, -6, 12)).Magnitude < 0.002)
			supported(solids, "apartamento " .. floor, at, 1.2)
			floors[floor] = at.Y
		elseif part.Name == "Porta do elevador" then
			doors[part:GetAttribute("Unidade")] = part:GetAttribute("CyberOutlawElevador")
		end
	end
	for floor = 1, 12 do
		assert(floors[floor] and doors[floor] == "andar")
		if floor > 1 then
			assert(math.abs(floors[floor] - floors[floor - 1] - 14) < 0.002)
		end
	end
	for z = 138, 185, 2 do
		supported(solids, "entrada do Colmeia", vec(-139, 0.15, z), 1.4)
	end

	local train = city:FindFirstChild("Monotrilho · Linha 07")
	assert(train and not train:FindFirstChild("Composição Linha 07", true), "o trem em movimento é criado pelo cliente")
	assert(#info.liftPads == 2)
	for _, pad in info.liftPads do
		assert(pad.CanTouch and pad:IsDescendantOf(train))
		local destination = pad:GetAttribute("Destino")
		supported(solids, "elevador", destination - vec(0, 3.5, 0), 1.2)
	end
	for x = 66, 183, 9 do
		supported(solids, "soleira de embarque", vec(x, 27.88, -9.6), 0.15)
	end
	for _, part in parts do
		local box = bounds(part)
		if box.x1 > -1197 and box.x0 < 1197 and box.z1 > -8.42 and box.z0 < -0.75 then
			assert(box.y1 < 27.95 or box.y0 > 39.1, "invasão do corredor do trem por " .. part:GetFullName())
		end
	end

	if next(art) == nil then
		assert(variants == 0 and #materials:GetChildren() == 0, "sem mídia aprovada o cenário usa materiais nativos")
	else
		assert(variants > 3000, "variantes devem ser aplicadas às peças nativas")
		local asphalt = materials:FindFirstChild("MareBaixa_asphalt")
		assert(asphalt.ColorMap == "rbxassetid://2001" and asphalt.NormalMap == "rbxassetid://2002")
		assert(asphalt.RoughnessMap == "rbxassetid://2003" and asphalt.BaseMaterial == rbx.Enum.Material.Asphalt)
		local cement = materials:FindFirstChild("MareBaixa_cement")
		assert(cement.ColorMap == "rbxassetid://1004" and cement.NormalMap == "rbxassetid://1005")
		local glass = materials:FindFirstChild("MareBaixa_glass")
		local hasColor, colorMap = pcall(function()
			return glass.ColorMap
		end)
		assert(glass.MetalnessMap == "rbxassetid://2004" and (not hasColor or colorMap == ""))
		assert(not materials:FindFirstChild("MareBaixa_roof"), "não deve usar IDs inválidos")
	end
	print(string.format("Maré Baixa · %d peças (%d sólidas), %d luzes, %d letreiros, %d bancas, %d pausas, %.2fs",
		#parts, #solids, lamps, signs, #vendors, batches, os.clock() - start))
	return parts
end

local plain = check({})
check({
	asphalt = 1001, asphalt_normal = 1002, asphalt_rough = 1003,
	concrete = 1004, concrete_normal = 1005, tijolo = 1006, tijolo_normal = 1007,
	mare_asphalt_color = 2001, mare_asphalt_normal = 2002, mare_asphalt_roughness = 2003,
	mare_glass_metalness = 2004, mare_roof_color = -1,
	ceu_bk = 3001, ceu_dn = 3002, ceu_ft = 3003, ceu_lf = 3004, ceu_rt = 3005, ceu_up = 3006,
})

local path = process.args[1]
if path then
	local function color(c)
		return {c.R, c.G, c.B}
	end
	local parts, lights, signs = {}, {}, {}
	for index, node in plain do
		local size = node.Size
		parts[index] = {
			name = node.Name, cf = {node.CFrame:GetComponents()}, size = {size.X, size.Y, size.Z}, color = color(node.Color),
			material = node:GetAttribute("MareMaterial"), transparency = node.Transparency, reflectance = node.Reflectance,
			collision = node.CanCollide,
			shape = if node:IsA("WedgePart") then "Wedge" elseif node:IsA("Part") then node.Shape.Name else "Block",
		}
		for _, child in node:GetChildren() do
			if child:IsA("Light") then
				table.insert(lights, {part = index, face = if child:IsA("SurfaceLight") then child.Face.Name else nil,
					color = color(child.Color), range = child.Range, brightness = child.Brightness})
			elseif child:IsA("SurfaceGui") then
				local label = child:FindFirstChildOfClass("TextLabel")
				if label then
					table.insert(signs, {part = index, face = child.Face.Name, text = label.Text, color = color(label.TextColor3)})
				end
			end
		end
	end
	local shots = {
		{name = "Canal", position = {-11, 14, 366}, look = {5, 27, -245}, fov = 57},
		{name = "Avenida", position = {229, 7.7, -17.76}, look = {229, 20, -450}, fov = 62},
		{name = "Mercado", position = {-365.5, 6.2, -213}, look = {-359.5, 10.2, -125}, fov = 59},
		{name = "Estacao", position = {37, 10.5, -49}, look = {138, 23.5, -2}, fov = 65},
		{name = "Doca", position = {-896, 20, 474}, look = {-840, 18, 591}, fov = 65},
		{name = "Panorama", position = {-975, 475, 1222}, look = {16, 66, -90}, fov = 54},
		{name = "Praca", position = {-111, 7.1, -208}, look = {-147, 7.5, -155}, fov = 59},
		{name = "Vertice", position = {196, 23, -531}, look = {360, 225, -351}, fov = 65},
		{name = "Colmeia", position = {-141, 7.7, 119}, look = {-139, 30, 185}, fov = 62},
	}
	fs.writeFile(path, serde.encode("json", {parts = parts, lights = lights, signs = signs, shots = shots}))
	print(string.format("Prévia exportada para %s", path))
end
