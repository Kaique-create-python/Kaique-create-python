--!strict
-- Construções procedurais ancoradas. Retornam o modelo, raio e altura.
-- Partes giratórias (moinho, roda-gigante, farol) recebem a tag "IdeiasGirar":
-- o cliente gira localmente, sem replicação a cada quadro.

local Kit = require(script.Parent.Kit)

local Buildings = {}

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

export type BuildingResult = { model: Model, radius: number, height: number, door: Vector3?, center: Vector3 }

local WALLS = { rgb(240, 230, 210), rgb(200, 220, 240), rgb(245, 210, 200), rgb(220, 240, 210), rgb(250, 240, 200) }
local ROOFS = { rgb(170, 60, 50), rgb(70, 80, 100), rgb(90, 60, 45), rgb(60, 120, 90) }

local function spinTag(part: BasePart, axis: string, speed: number)
	part:AddTag("IdeiasGirar")
	part:SetAttribute("GirarEixo", axis)
	part:SetAttribute("GirarVel", speed)
end

-- parede com aberturas: segmentos ao redor de uma porta e janelas (eixo X)
local function wall(b: any, width: number, height: number, cf: CFrame, color: Color3, door: boolean, windows: number, mat: Enum.Material)
	local t = 0.8
	local doorW, doorH = 4, 6
	if door then
		local side = (width - doorW) / 2
		b:box(V(side, height, t), cf * CF(-(doorW / 2 + side / 2), height / 2, 0), color, { role = "primary", material = mat })
		b:box(V(side, height, t), cf * CF(doorW / 2 + side / 2, height / 2, 0), color, { role = "primary", material = mat })
		b:box(V(doorW, height - doorH, t), cf * CF(0, doorH + (height - doorH) / 2, 0), color, { role = "primary", material = mat })
		b:box(V(doorW + 0.6, 0.4, t + 0.2), cf * CF(0, doorH + 0.2, 0), Kit.darker(color, 0.25), { role = "secondary" })
	else
		b:box(V(width, height, t), cf * CF(0, height / 2, 0), color, { role = "primary", material = mat })
	end
	for i = 1, windows do
		local x = (i - (windows + 1) / 2) * (width / (windows + 0.5))
		if not door or math.abs(x) > 3.5 then
			b:box(V(2.6, 2.6, t + 0.15), cf * CF(x, height * 0.6, 0), rgb(150, 205, 240), { role = "fixed", material = Enum.Material.Glass, transparency = 0.2 })
			b:box(V(3.0, 0.3, t + 0.3), cf * CF(x, height * 0.6 - 1.45, 0), Kit.darker(color, 0.3), { role = "secondary" })
		end
	end
end

local function house(b: any, rng: any, big: boolean): BuildingResult
	local w = if big then 30 else 20
	local d = if big then 22 else 16
	local h = if big then 9 else 9
	local floors = if big then 2 else 1
	local wallCol = rng:pick(WALLS)
	local roofCol = rng:pick(ROOFS)
	local mat = Enum.Material.SmoothPlastic
	b:box(V(w + 2, 1, d + 2), CF(0, 0.5, 0), rgb(150, 140, 130), { role = "secondary", material = Enum.Material.Concrete })
	for f = 0, floors - 1 do
		local y = 1 + f * h
		wall(b, w, h, CF(0, y, -d / 2), wallCol, f == 0, if big then 4 else 2, mat)
		wall(b, w, h, CF(0, y, d / 2), wallCol, false, if big then 4 else 2, mat)
		wall(b, d, h, CF(-w / 2, y, 0) * ANG(0, rad(90), 0), wallCol, false, if big then 3 else 2, mat)
		wall(b, d, h, CF(w / 2, y, 0) * ANG(0, rad(90), 0), wallCol, false, if big then 3 else 2, mat)
		b:box(V(w, 0.6, d), CF(0, y + h - 0.3, 0), Kit.darker(wallCol, 0.1), { role = "secondary" })
	end
	local top = 1 + floors * h
	b:roof(w + 2, d + 2, if big then 8 else 6, CF(0, top, 0) * ANG(0, rad(90), 0), roofCol, { role = "secondary" })
	b:box(V(2, 6, 2), CF(w * 0.25, top + 3, d * 0.2), rgb(150, 90, 70), { role = "fixed", material = Enum.Material.Brick })
	b:box(V(4, 7, 0.3), CF(0, 4.5, -d / 2 - 0.1), rgb(120, 75, 40), { role = "fixed", material = Enum.Material.WoodPlanks, transparency = 0.9, collide = false })
	if big then
		for _, x in { -w / 2 + 3, w / 2 - 3 } do
			b:cylY(h * 2, 1.4, CF(x, 1 + h, -d / 2 - 2.5), rgb(245, 245, 245), { role = "fixed", material = Enum.Material.Marble })
		end
		b:box(V(w * 0.6, 0.6, 4), CF(0, 1 + h, -d / 2 - 2), Kit.darker(wallCol, 0.1), { role = "secondary" })
	end
	return { model = b.model, radius = math.max(w, d) / 2 + 2, height = top + 8, door = V(0, 1, -d / 2 - 3), center = V(0, top / 2, 0) }
end

local function skyscraper(b: any, rng: any): BuildingResult
	local w = 16
	local floors = rng:int(8, 13)
	local fh = 5
	local col = rng:pick({ rgb(70, 80, 100), rgb(210, 215, 225), rgb(40, 50, 70), rgb(160, 140, 120) })
	local glassC = rng:pick({ rgb(120, 200, 255), rgb(255, 200, 120), rgb(160, 255, 220) })
	b:box(V(w + 4, 1, w + 4), CF(0, 0.5, 0), rgb(120, 120, 125), { role = "secondary", material = Enum.Material.Concrete })
	b:box(V(w, floors * fh, w), CF(0, 1 + floors * fh / 2, 0), col, { role = "primary", material = Enum.Material.Concrete })
	for f = 1, floors do
		b:box(V(w + 0.3, 1.6, w + 0.3), CF(0, 1 + (f - 0.5) * fh, 0), glassC, { role = "accent", material = Enum.Material.Glass, transparency = 0.15, reflectance = 0.2 })
	end
	local top = 1 + floors * fh
	b:box(V(w * 0.6, 4, w * 0.6), CF(0, top + 2, 0), col, { role = "primary" })
	b:cylY(10, 0.5, CF(0, top + 9, 0), rgb(180, 180, 190), { role = "fixed", material = Enum.Material.Metal })
	local l = b:ball(1, CF(0, top + 14.5, 0), rgb(255, 40, 40), { role = "fixed", material = Enum.Material.Neon })
	b:light(l, rgb(255, 60, 60), 20, 2)
	b:box(V(5, 7, 0.4), CF(0, 4.5, -w / 2 - 0.1), rgb(30, 30, 35), { role = "fixed", material = Enum.Material.Glass, transparency = 0.3, collide = false })
	return { model = b.model, radius = w / 2 + 3, height = top + 15, center = V(0, top / 2, 0) }
end

local function tower(b: any, _rng: any): BuildingResult
	local stone = rgb(150, 145, 140)
	b:cylY(30, 12, CF(0, 15, 0), stone, { role = "primary", material = Enum.Material.Cobblestone })
	b:cylY(2, 14, CF(0, 31, 0), Kit.darker(stone, 0.15), { role = "secondary", material = Enum.Material.Cobblestone })
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		b:box(V(2, 2.4, 2), CF(math.cos(a) * 6.2, 33.2, math.sin(a) * 6.2) * ANG(0, -a, 0), stone, { role = "primary", material = Enum.Material.Cobblestone })
	end
	b:cone(10, 13, CF(0, 32, 0), rgb(60, 70, 130), 5, { role = "secondary" })
	for k = 0, 3 do
		b:box(V(1.6, 3, 0.6), CF(0, 8 + k * 6, -6) * ANG(0, 0, 0), rgb(255, 210, 120), { role = "fixed", material = Enum.Material.Neon })
	end
	b:box(V(4, 6, 1.5), CF(0, 3, -6), rgb(110, 70, 40), { role = "fixed", material = Enum.Material.WoodPlanks })
	return { model = b.model, radius = 7, height = 44, center = V(0, 15, 0) }
end

local function castle(b: any, rng: any): BuildingResult
	local stone = rgb(165, 160, 150)
	local roof = rgb(60, 70, 140)
	local s = 44
	local h = 14
	local mat = Enum.Material.Cobblestone
	b:box(V(s + 8, 1, s + 8), CF(0, 0.5, 0), rgb(120, 115, 110), { role = "secondary", material = Enum.Material.Slate })
	for _, side in { { 0, -s / 2, 0 }, { 0, s / 2, 0 }, { -s / 2, 0, 90 }, { s / 2, 0, 90 } } do
		local cf = CF(side[1], 1, side[2]) * ANG(0, rad(side[3]), 0)
		if side[2] < 0 and side[3] == 0 then
			-- muralha da frente com portão
			b:box(V((s - 10) / 2, h, 3), cf * CF(-(5 + (s - 10) / 4), h / 2, 0), stone, { role = "primary", material = mat })
			b:box(V((s - 10) / 2, h, 3), cf * CF(5 + (s - 10) / 4, h / 2, 0), stone, { role = "primary", material = mat })
			b:box(V(10, h - 9, 3), cf * CF(0, 9 + (h - 9) / 2, 0), stone, { role = "primary", material = mat })
			b:box(V(9, 8.6, 0.5), cf * CF(0, 4.3, -1.6), rgb(90, 60, 35), { role = "fixed", material = Enum.Material.WoodPlanks, transparency = 0.6, collide = false })
		else
			b:box(V(s, h, 3), cf * CF(0, h / 2, 0), stone, { role = "primary", material = mat })
		end
		for k = -5, 5 do
			b:box(V(2, 2, 3.4), cf * CF(k * 4, h + 1, 0), stone, { role = "primary", material = mat })
		end
	end
	for _, x in { -s / 2, s / 2 } do
		for _, z in { -s / 2, s / 2 } do
			b:cylY(h + 8, 10, CF(x, 1 + (h + 8) / 2, z), stone, { role = "primary", material = mat })
			b:cone(9, 11, CF(x, 1 + h + 8, z), roof, 4, { role = "secondary" })
			local pole = b:cylY(4, 0.3, CF(x, 1 + h + 19, z), rgb(80, 60, 40), { role = "fixed" })
			local flagCol = rng:pick({ rgb(220, 40, 40), rgb(250, 200, 40), rgb(60, 120, 230) })
			b:box(V(0.1, 1.6, 2.6), CF(x, 1 + h + 20.2, z + 1.3), flagCol, { role = "accent" })
			local _ = pole
		end
	end
	-- torre central
	b:box(V(16, h + 14, 16), CF(0, 1 + (h + 14) / 2, 6), Kit.lighter(stone, 0.05), { role = "primary", material = mat })
	b:cone(12, 18, CF(0, 1 + h + 14, 6), roof, 5, { role = "secondary" })
	for k = -1, 1 do
		b:box(V(2, 4, 0.5), CF(k * 4, h + 6, -2.2), rgb(255, 200, 100), { role = "fixed", material = Enum.Material.Neon })
	end
	return { model = b.model, radius = s / 2 + 6, height = h + 30, door = V(0, 1, -s / 2 - 4), center = V(0, 10, 0) }
end

local function bridge(b: any, _rng: any): BuildingResult
	local len = 70
	local wood = rgb(150, 105, 65)
	b:box(V(10, 1, len), CF(0, 6, -len / 2 - 4), wood, { role = "primary", material = Enum.Material.WoodPlanks })
	for k = 0, 9 do
		local z = -4 - k * len / 9
		for _, side in { -1, 1 } do
			b:cylY(9, 0.8, CF(side * 5, 2.5, z), Kit.darker(wood, 0.2), { role = "secondary" })
			b:cylY(3, 0.4, CF(side * 4.8, 8, z), wood, { role = "primary" })
		end
	end
	for _, side in { -1, 1 } do
		b:box(V(0.5, 0.5, len), CF(side * 4.8, 9.3, -len / 2 - 4), wood, { role = "primary" })
	end
	b:part("wedge", V(10, 6, 8), CF(0, 3, 0) * ANG(0, rad(180), 0), wood, { role = "primary", material = Enum.Material.WoodPlanks })
	return { model = b.model, radius = len / 2, height = 10, center = V(0, 6, -len / 2) }
end

local function wallB(b: any, _rng: any): BuildingResult
	local stone = rgb(160, 150, 140)
	b:box(V(60, 12, 4), CF(0, 6, 0), stone, { role = "primary", material = Enum.Material.Brick })
	for k = -7, 7 do
		b:box(V(2.4, 2.4, 4.4), CF(k * 4, 13.2, 0), stone, { role = "primary", material = Enum.Material.Brick })
	end
	return { model = b.model, radius = 30, height = 15, center = V(0, 6, 0) }
end

-- labirinto gerado por backtracking recursivo
local function maze(b: any, rng: any): BuildingResult
	local n = 9
	local cell = 10
	local h = 8
	local hedge = rgb(60, 130, 55)
	local visited = {}
	local walls = {}
	local function key(x, y)
		return x .. ":" .. y
	end
	for x = 1, n do
		for y = 1, n do
			walls[key(x, y)] = { N = true, S = true, E = true, W = true }
		end
	end
	local stack = { { 1, 1 } }
	visited[key(1, 1)] = true
	local dirs = { { 0, -1, "N", "S" }, { 0, 1, "S", "N" }, { 1, 0, "E", "W" }, { -1, 0, "W", "E" } }
	while #stack > 0 do
		local cur = stack[#stack]
		local options = {}
		for _, d in dirs do
			local nx, ny = cur[1] + d[1], cur[2] + d[2]
			if nx >= 1 and nx <= n and ny >= 1 and ny <= n and not visited[key(nx, ny)] then
				table.insert(options, d)
			end
		end
		if #options == 0 then
			table.remove(stack)
		else
			local d = rng:pick(options)
			local nx, ny = cur[1] + d[1], cur[2] + d[2]
			walls[key(cur[1], cur[2])][d[3]] = false
			walls[key(nx, ny)][d[4]] = false
			visited[key(nx, ny)] = true
			table.insert(stack, { nx, ny })
		end
	end
	walls[key(math.ceil(n / 2), 1)].N = false -- entrada
	walls[key(math.ceil(n / 2), n)].S = false -- saída
	local off = -(n * cell) / 2
	b:box(V(n * cell + 2, 0.6, n * cell + 2), CF(0, 0.3, -n * cell / 2 - 6), rgb(190, 170, 120), { role = "secondary", material = Enum.Material.Sand })
	for x = 1, n do
		for y = 1, n do
			local w = walls[key(x, y)]
			local cx = off + (x - 0.5) * cell
			local cz = -6 - (y - 0.5) * cell
			if w.N then
				b:box(V(cell + 1, h, 1), CF(cx, h / 2, cz + cell / 2), hedge, { role = "primary", material = Enum.Material.Grass })
			end
			if w.W then
				b:box(V(1, h, cell + 1), CF(cx - cell / 2, h / 2, cz), hedge, { role = "primary", material = Enum.Material.Grass })
			end
			if y == n and w.S then
				b:box(V(cell + 1, h, 1), CF(cx, h / 2, cz - cell / 2), hedge, { role = "primary", material = Enum.Material.Grass })
			end
			if x == n and w.E then
				b:box(V(1, h, cell + 1), CF(cx + cell / 2, h / 2, cz), hedge, { role = "primary", material = Enum.Material.Grass })
			end
		end
	end
	local prize = b:ball(2.5, CF(0, 3, -6 - n * cell / 2), rgb(255, 210, 50), { role = "fixed", material = Enum.Material.Neon, collide = false })
	prize.Name = "Premio"
	return { model = b.model, radius = n * cell / 2 + 4, height = h, center = V(0, 2, -6 - n * cell / 2) }
end

local function pyramid(b: any, _rng: any): BuildingResult
	local sand = rgb(225, 195, 130)
	for k = 0, 9 do
		local s = 50 - k * 5
		b:box(V(s, 3, s), CF(0, 1.5 + k * 3, 0), Kit.darker(sand, (k % 2) * 0.05), { role = "primary", material = Enum.Material.Sandstone })
	end
	b:box(V(5, 6, 6), CF(0, 3, -24), rgb(30, 25, 20), { role = "fixed" })
	b:ball(2, CF(0, 31, 0), rgb(255, 215, 80), { role = "fixed", material = Enum.Material.Neon })
	return { model = b.model, radius = 26, height = 32, center = V(0, 10, 0) }
end

local function lighthouse(b: any, _rng: any): BuildingResult
	for k = 0, 5 do
		b:cylY(6, 9 - k * 0.6, CF(0, 3 + k * 6, 0), if k % 2 == 0 then rgb(240, 240, 240) else rgb(220, 40, 40), { role = if k % 2 == 0 then "primary" else "secondary" })
	end
	b:cylY(5, 6, CF(0, 38.5, 0), rgb(200, 240, 255), { role = "fixed", material = Enum.Material.Glass, transparency = 0.4 })
	b:cone(4, 7, CF(0, 41, 0), rgb(220, 40, 40), 3, { role = "secondary" })
	local lamp = b:ball(3, CF(0, 38.5, 0), rgb(255, 250, 200), { role = "fixed", material = Enum.Material.Neon })
	local beam = b:part("wedge", V(0.2, 6, 40), CF(0, 38.5, -21), rgb(255, 250, 200), { role = "fixed", material = Enum.Material.Neon, transparency = 0.75, collide = false })
	local pivot = b:box(V(1, 1, 1), CF(0, 38.5, 0), rgb(255, 255, 255), { role = "fixed", transparency = 1, collide = false, name = "PivoFarol" })
	beam:SetAttribute("GirarCentro", true)
	spinTag(pivot, "Y", 1.2)
	beam.Parent = pivot
	b:light(lamp, rgb(255, 245, 200), 40, 3)
	return { model = b.model, radius = 6, height = 45, center = V(0, 18, 0) }
end

local function windmill(b: any, _rng: any): BuildingResult
	local wall = rgb(235, 225, 205)
	b:cone(26, 12, CF(0, 0, 0), wall, 6, { role = "primary" })
	b:cone(6, 8, CF(0, 25, 0), rgb(130, 70, 50), 3, { role = "secondary" })
	local hub = b:part("cyl", V(2, 2.2, 2.2), CF(0, 22, -5) * ANG(0, rad(90), 0), rgb(90, 60, 40), { role = "fixed", name = "Eixo" })
	spinTag(hub, "Z", 0.6)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		local blade = b:box(V(2.6, 14, 0.3), CF(0, 22, -6) * ANG(0, 0, a) * CF(0, 7.5, 0), rgb(240, 240, 235), { role = "fixed", material = Enum.Material.Fabric })
		blade.Parent = hub
	end
	b:box(V(3, 5, 1), CF(0, 2.5, -5.5), rgb(110, 70, 40), { role = "fixed", material = Enum.Material.WoodPlanks })
	return { model = b.model, radius = 9, height = 32, center = V(0, 12, 0) }
end

local function ferris(b: any, _rng: any): BuildingResult
	local steel = rgb(200, 205, 215)
	for _, side in { -1, 1 } do
		b:beam(V(side * 3, 0, -12), V(side * 3, 24, 0), 1, steel, { role = "primary" })
		b:beam(V(side * 3, 0, 12), V(side * 3, 24, 0), 1, steel, { role = "primary" })
	end
	local hub = b:part("cyl", V(7, 3, 3), CF(0, 24, 0), rgb(255, 210, 60), { role = "fixed", name = "Eixo" })
	spinTag(hub, "X", 0.25)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		local spoke = b:box(V(0.5, 20, 0.5), CF(0, 24, 0) * ANG(a, 0, 0) * CF(0, 10, 0), steel, { role = "primary" })
		spoke.Parent = hub
		local cab = b:box(V(4, 3, 3), CF(0, 24, 0) * ANG(a, 0, 0) * CF(0, 20, 0), Kit.RainbowColors[(k % 6) + 1], { role = "accent" })
		cab.Parent = hub
		local bulb = b:ball(0.8, CF(0, 24, 0) * ANG(a + 0.3, 0, 0) * CF(0, 20, 0), rgb(255, 250, 200), { role = "fixed", material = Enum.Material.Neon })
		bulb.Parent = hub
	end
	return { model = b.model, radius = 22, height = 46, center = V(0, 24, 0) }
end

local function igloo(b: any, _rng: any): BuildingResult
	local ice = rgb(230, 245, 255)
	for ring = 0, 4 do
		local y = ring * 2.2
		local r = 9 * math.cos(math.asin(math.min(y / 11, 0.99)))
		local n = math.max(6, math.floor(r * 1.4))
		for k = 0, n - 1 do
			local a = k / n * math.pi * 2 + ring * 0.2
			if not (ring < 2 and math.abs(a - math.pi * 1.5) < 0.35) then
				b:box(V(r * 6.3 / n + 0.3, 2.2, 1.6), CF(math.cos(a) * r, y + 1.1, math.sin(a) * r) * ANG(0, -a + math.pi / 2, 0), ice, { role = "primary", material = Enum.Material.Ice })
			end
		end
	end
	b:part("ball", V(9, 4, 9), CF(0, 10, 0), ice, { role = "primary", material = Enum.Material.Ice })
	b:box(V(4, 4, 5), CF(0, 2, -10), ice, { role = "primary", material = Enum.Material.Ice, transparency = 0.0 })
	return { model = b.model, radius = 11, height = 12, center = V(0, 4, 0) }
end

local function tent(b: any, rng: any): BuildingResult
	local col = rng:pick({ rgb(230, 120, 40), rgb(60, 150, 90), rgb(60, 110, 200) })
	b:part("wedge", V(10, 7, 6), CF(0, 3.5, 3), col, { role = "primary", material = Enum.Material.Fabric })
	b:part("wedge", V(10, 7, 6), CF(0, 3.5, -3) * ANG(0, rad(180), 0), col, { role = "primary", material = Enum.Material.Fabric })
	local fire = b:ball(1.4, CF(0, 0.8, -9), rgb(255, 140, 40), { role = "fixed", material = Enum.Material.Neon, collide = false })
	local f = Instance.new("Fire")
	f.Size = 4
	f.Parent = fire
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		b:box(V(0.6, 0.6, 2.4), CF(math.cos(a) * 1.6, 0.3, -9 + math.sin(a) * 1.6) * ANG(0, -a, 0), rgb(110, 70, 40), { role = "fixed" })
	end
	return { model = b.model, radius = 9, height = 8, center = V(0, 3, 0) }
end

local function temple(b: any, _rng: any): BuildingResult
	local marble = rgb(240, 238, 230)
	for k = 0, 2 do
		b:box(V(40 - k * 3, 1.2, 28 - k * 3), CF(0, 0.6 + k * 1.2, 0), marble, { role = "primary", material = Enum.Material.Marble })
	end
	for _, z in { -11, 11 } do
		for k = -4, 4 do
			b:cylY(14, 2, CF(k * 4, 3.6 + 7, z), marble, { role = "primary", material = Enum.Material.Marble })
		end
	end
	b:box(V(38, 2, 26), CF(0, 18.6, 0), marble, { role = "primary", material = Enum.Material.Marble })
	b:roof(38, 26, 6, CF(0, 19.6, 0) * ANG(0, rad(90), 0), Kit.darker(marble, 0.08), { role = "secondary", material = Enum.Material.Marble })
	b:ball(2.4, CF(0, 6, 0), rgb(255, 210, 90), { role = "fixed", material = Enum.Material.Neon })
	return { model = b.model, radius = 21, height = 26, center = V(0, 8, 0) }
end

local function sign(part: BasePart, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 100)
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui
	gui.Parent = part
end

local function shopOrSchool(b: any, rng: any, kind: string): BuildingResult
	local w, d, h = 26, 18, 10
	local col = if kind == "school" then rgb(230, 180, 120) else rng:pick(WALLS)
	b:box(V(w + 2, 1, d + 2), CF(0, 0.5, 0), rgb(150, 150, 150), { role = "secondary", material = Enum.Material.Concrete })
	wall(b, w, h, CF(0, 1, -d / 2), col, true, 4, Enum.Material.Brick)
	wall(b, w, h, CF(0, 1, d / 2), col, false, 4, Enum.Material.Brick)
	wall(b, d, h, CF(-w / 2, 1, 0) * ANG(0, rad(90), 0), col, false, 2, Enum.Material.Brick)
	wall(b, d, h, CF(w / 2, 1, 0) * ANG(0, rad(90), 0), col, false, 2, Enum.Material.Brick)
	b:box(V(w + 1, 1, d + 1), CF(0, h + 1.5, 0), Kit.darker(col, 0.25), { role = "secondary" })
	local board = b:box(V(16, 3.2, 0.5), CF(0, h + 3.6, -d / 2 - 0.2) * ANG(0, rad(180), 0), rgb(30, 30, 40), { role = "fixed" })
	sign(board, if kind == "school" then "ESCOLA" else "LOJA", if kind == "school" then rgb(255, 230, 120) else rgb(120, 255, 220))
	for k = -3, 3 do
		b:box(V(3.6, 0.3, 4), CF(k * 3.6, 8.3, -d / 2 - 2) * ANG(rad(-15), 0, 0), if k % 2 == 0 then rgb(230, 60, 60) else rgb(250, 250, 250), { role = "fixed", material = Enum.Material.Fabric })
	end
	return { model = b.model, radius = w / 2 + 3, height = h + 6, door = V(0, 1, -d / 2 - 3), center = V(0, 5, 0) }
end

local function farm(b: any, _rng: any): BuildingResult
	local red = rgb(180, 45, 40)
	local white = rgb(245, 245, 240)
	b:box(V(22, 14, 18), CF(0, 7, 10), red, { role = "primary", material = Enum.Material.WoodPlanks })
	b:roof(24, 20, 8, CF(0, 14, 10) * ANG(0, rad(90), 0), rgb(90, 90, 95), { role = "secondary" })
	b:box(V(8, 9, 0.4), CF(0, 4.5, 0.9), white, { role = "fixed" })
	b:box(V(0.6, 11, 0.5), CF(0, 4.5, 0.7) * ANG(0, 0, rad(40)), white, { role = "fixed" })
	b:box(V(0.6, 11, 0.5), CF(0, 4.5, 0.7) * ANG(0, 0, rad(-40)), white, { role = "fixed" })
	b:cylY(20, 7, CF(16, 10, 14), rgb(200, 200, 210), { role = "fixed", material = Enum.Material.Metal })
	b:part("ball", V(7, 4, 7), CF(16, 20, 14), rgb(180, 45, 40), { role = "secondary" })
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		local p = V(math.cos(a) * 30, 1.5, math.sin(a) * 30 - 6)
		b:box(V(0.6, 3, 0.6), CF(p), rgb(150, 105, 60), { role = "fixed", material = Enum.Material.Wood })
		local p2 = V(math.cos(a + math.pi / 16 * 2) * 30, 2.2, math.sin(a + math.pi / 16 * 2) * 30 - 6)
		b:beam(p + V(0, 0.7, 0), p2, 0.3, rgb(150, 105, 60), { role = "fixed" })
	end
	for k = 0, 2 do
		b:part("cyl", V(3, 3, 3), CF(-14 + k * 3.4, 1.5, -4) * ANG(0, rad(90), 0), rgb(230, 200, 90), { role = "fixed", material = Enum.Material.Fabric })
	end
	return { model = b.model, radius = 31, height = 22, center = V(0, 5, 4) }
end

local function treehouse(b: any, _rng: any): BuildingResult
	local bark = rgb(110, 75, 45)
	b:cylY(26, 5, CF(0, 13, 0), bark, { role = "fixed", material = Enum.Material.Wood })
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		b:ball(12, CF(math.cos(a) * 7, 30 + (k % 2) * 3, math.sin(a) * 7), rgb(70, 150, 60), { role = "fixed", material = Enum.Material.Grass })
	end
	b:ball(14, CF(0, 34, 0), rgb(80, 165, 65), { role = "fixed", material = Enum.Material.Grass })
	b:box(V(16, 1, 16), CF(0, 16, 0), rgb(150, 105, 65), { role = "primary", material = Enum.Material.WoodPlanks })
	b:box(V(10, 7, 10), CF(4, 20, 2), rgb(170, 120, 75), { role = "primary", material = Enum.Material.WoodPlanks })
	b:roof(11, 11, 4, CF(4, 23.5, 2) * ANG(0, rad(90), 0), rgb(150, 60, 45), { role = "secondary" })
	for k = 0, 7 do
		b:box(V(3, 0.4, 0.6), CF(0, 1 + k * 2, -3), rgb(150, 105, 65), { role = "fixed", material = Enum.Material.Wood })
	end
	return { model = b.model, radius = 10, height = 40, center = V(0, 16, 0) }
end

local function portal(b: any, _rng: any): BuildingResult
	local stone = rgb(90, 85, 100)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		b:box(V(3.4, 3.4, 2.4), CF(math.cos(a) * 9, 10 + math.sin(a) * 9, 0) * ANG(0, 0, a), stone, { role = "primary", material = Enum.Material.Slate })
		if k % 3 == 0 then
			b:ball(1.2, CF(math.cos(a) * 9, 10 + math.sin(a) * 9, -1.3), rgb(180, 90, 255), { role = "accent", material = Enum.Material.Neon })
		end
	end
	local disc = b:part("cyl", V(0.5, 16, 16), CF(0, 10, 0) * ANG(0, rad(90), 0), rgb(170, 90, 255), { role = "accent", material = Enum.Material.Neon, transparency = 0.35, collide = false, name = "Vortice" })
	spinTag(disc, "X", 1.5)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = 20
	e.Lifetime = NumberRange.new(1, 2)
	e.Speed = NumberRange.new(2, 6)
	e.Color = ColorSequence.new(rgb(200, 130, 255), rgb(90, 200, 255))
	e.Parent = disc
	b:box(V(22, 1, 8), CF(0, 0.5, 0), stone, { role = "secondary", material = Enum.Material.Slate })
	return { model = b.model, radius = 11, height = 20, center = V(0, 10, 0) }
end

local function cage(b: any, _rng: any): BuildingResult
	local steel = rgb(110, 110, 120)
	local s = 14
	b:box(V(s + 2, 1, s + 2), CF(0, 0.5, 0), steel, { role = "primary", material = Enum.Material.DiamondPlate })
	b:box(V(s + 2, 1, s + 2), CF(0, 14.5, 0), steel, { role = "primary", material = Enum.Material.DiamondPlate })
	for k = 0, 23 do
		local side = k // 6
		local t = (k % 6) / 6 * s - s / 2 + s / 12
		local x, z = 0, 0
		if side == 0 then
			x, z = t, -s / 2
		elseif side == 1 then
			x, z = s / 2, t
		elseif side == 2 then
			x, z = -t, s / 2
		else
			x, z = -s / 2, -t
		end
		b:cylY(13, 0.6, CF(x, 7.5, z), steel, { role = "primary", material = Enum.Material.Metal })
	end
	return { model = b.model, radius = s / 2 + 1, height = 15, center = V(0, 3, 0) }
end

local function ring(b: any, _rng: any): BuildingResult
	local s = 34
	b:box(V(s, 2, s), CF(0, 1, 0), rgb(40, 60, 140), { role = "primary" })
	b:box(V(s - 2, 0.2, s - 2), CF(0, 2.1, 0), rgb(240, 240, 245), { role = "fixed", material = Enum.Material.Fabric })
	for _, x in { -s / 2, s / 2 } do
		for _, z in { -s / 2, s / 2 } do
			b:cylY(8, 1, CF(x, 5, z), rgb(200, 200, 210), { role = "fixed", material = Enum.Material.Metal })
		end
	end
	for k = 1, 3 do
		local y = 2 + k * 1.8
		for _, e in { { 0, -s / 2, 0 }, { 0, s / 2, 0 }, { -s / 2, 0, 90 }, { s / 2, 0, 90 } } do
			b:box(V(s, 0.3, 0.3), CF(e[1], y, e[2]) * ANG(0, rad(e[3]), 0), if k == 2 then rgb(250, 250, 250) else rgb(220, 40, 40), { role = "accent" })
		end
	end
	return { model = b.model, radius = s / 2 + 2, height = 9, center = V(0, 4, 0) }
end

local function stairs(b: any, _rng: any): BuildingResult
	for k = 0, 24 do
		local a = k * 0.35
		b:box(V(8, 1, 4), CF(math.cos(a) * 8, 1 + k * 2, -12 + math.sin(a) * 8) * ANG(0, -a, 0), Kit.RainbowColors[(k % 6) + 1], { role = "accent" })
	end
	b:cylY(52, 3, CF(0, 26, -12), rgb(240, 240, 250), { role = "fixed", material = Enum.Material.Marble })
	b:ball(6, CF(0, 54, -12), rgb(255, 230, 120), { role = "fixed", material = Enum.Material.Neon })
	return { model = b.model, radius = 12, height = 56, center = V(0, 2, -12) }
end

local function slide(b: any, _rng: any): BuildingResult
	local col = rgb(250, 180, 40)
	for _, x in { -3, 3 } do
		for _, z in { -3, 3 } do
			b:cylY(16, 0.8, CF(x, 8, z), rgb(220, 60, 60), { role = "secondary" })
		end
	end
	b:box(V(7, 1, 7), CF(0, 16, 0), rgb(60, 140, 230), { role = "primary" })
	for k = 0, 7 do
		b:box(V(4, 0.4, 0.6), CF(0, 1.5 + k * 2, 4), rgb(200, 200, 210), { role = "fixed", material = Enum.Material.Metal })
	end
	b:part("wedge", V(5, 16, 26), CF(0, 8, -16.5) * ANG(0, rad(180), 0), col, { role = "accent", material = Enum.Material.SmoothPlastic })
	return { model = b.model, radius = 15, height = 18, center = V(0, 8, -8) }
end

local function trampoline(b: any, _rng: any): BuildingResult
	b:cylY(2, 18, CF(0, 1, 0), rgb(40, 40, 50), { role = "secondary" })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		b:cylY(1.4, 0.8, CF(math.cos(a) * 8, 0.7, math.sin(a) * 8), rgb(200, 200, 210), { role = "fixed", material = Enum.Material.Metal })
	end
	local pad = b:cylY(0.4, 16, CF(0, 2.1, 0), rgb(60, 200, 255), { role = "accent", material = Enum.Material.Neon, name = "Pulo" })
	pad:AddTag("IdeiasPulo")
	pad:SetAttribute("Forca", 140)
	return { model = b.model, radius = 9, height = 3, center = V(0, 2, 0) }
end

local function pool(b: any, _rng: any): BuildingResult
	local tile = rgb(240, 240, 245)
	b:box(V(30, 1, 20), CF(0, 0.5, 0), tile, { role = "primary", material = Enum.Material.Marble })
	for _, e in { { 0, -10.5, 30, 1 }, { 0, 10.5, 30, 1 }, { -15.5, 0, 1, 22 }, { 15.5, 0, 1, 22 } } do
		b:box(V(e[3], 3, e[4]), CF(e[1], 1.5, e[2]), tile, { role = "primary", material = Enum.Material.Marble })
	end
	b:box(V(30, 2, 20), CF(0, 2, 0), rgb(70, 170, 255), { role = "fixed", material = Enum.Material.Glass, transparency = 0.45, collide = false, name = "Agua" })
	return { model = b.model, radius = 16, height = 4, center = V(0, 2, 0) }
end

local function island(b: any, _rng: any): BuildingResult
	local y = 40
	b:cylY(4, 30, CF(0, y, 0), rgb(90, 170, 70), { role = "primary", material = Enum.Material.Grass })
	b:cone(22, 30, CF(0, y - 2, 0) * ANG(rad(180), 0, 0), rgb(120, 95, 75), 5, { role = "secondary", material = Enum.Material.Slate })
	b:cylY(10, 2, CF(5, y + 7, 3), rgb(110, 75, 45), { role = "fixed", material = Enum.Material.Wood })
	b:ball(9, CF(5, y + 14, 3), rgb(255, 160, 210), { role = "fixed", material = Enum.Material.Grass })
	local fall = b:box(V(4, 30, 1), CF(-12, y - 14, -6), rgb(120, 200, 255), { role = "fixed", material = Enum.Material.Glass, transparency = 0.4, collide = false })
	local _ = fall
	for k = 0, 6 do
		b:box(V(6, 1, 6), CF(-20 + k * 2, 2 + k * 5.5, 26 - k * 4), rgb(240, 240, 255), { role = "fixed", material = Enum.Material.SmoothPlastic })
	end
	return { model = b.model, radius = 16, height = y + 20, center = V(0, y + 2, 0) }
end

local BUILDERS: { [string]: (any, any) -> BuildingResult } = {
	house = function(b, rng)
		return house(b, rng, false)
	end,
	mansion = function(b, rng)
		return house(b, rng, true)
	end,
	skyscraper = skyscraper,
	tower = tower,
	castle = castle,
	bridge = bridge,
	wall = wallB,
	maze = maze,
	pyramid = pyramid,
	lighthouse = lighthouse,
	windmill = windmill,
	ferris_wheel = ferris,
	igloo = igloo,
	tent = tent,
	temple = temple,
	school = function(b, rng)
		return shopOrSchool(b, rng, "school")
	end,
	shop = function(b, rng)
		return shopOrSchool(b, rng, "shop")
	end,
	farm = farm,
	treehouse = treehouse,
	portal = portal,
	cage = cage,
	ring = ring,
	stairs = stairs,
	slide = slide,
	trampoline = trampoline,
	pool = pool,
	floating_island = island,
}

-- cidade: várias construções menores lado a lado com ruas
local function city(origin: CFrame, params: { [string]: any }, rng: any): BuildingResult
	local b = Kit.new("city", origin, params)
	b:box(V(110, 0.4, 110), CF(0, 0.2, -55), rgb(60, 60, 65), { role = "fixed", material = Enum.Material.Asphalt })
	for _, z in { -55 } do
		b:box(V(110, 0.45, 2), CF(0, 0.25, z), rgb(250, 220, 60), { role = "fixed" })
		b:box(V(2, 0.45, 110), CF(0, 0.25, z), rgb(250, 220, 60), { role = "fixed" })
	end
	local model = b:finish()
	local kinds = { "skyscraper", "house", "shop", "skyscraper", "school", "house" }
	local spots = { V(-30, 0, -25), V(30, 0, -25), V(-30, 0, -85), V(30, 0, -85), V(-30, 0, -55 + 0.01), V(30, 0, -55) }
	for i = 1, 4 do
		local kind = kinds[((i + rng:int(0, 5)) % #kinds) + 1]
		local sub = Kit.new(kind, origin * CF(spots[i] * b.s), params)
		local r = BUILDERS[kind](sub, rng)
		sub:finish()
		r.model.Parent = model
	end
	return { model = model, radius = 56 * b.s, height = 70 * b.s, center = (origin * CF(V(0, 10, -55) * b.s)).Position }
end

function Buildings.build(origin: CFrame, params: { [string]: any }, variant: string): BuildingResult
	local rng = params.rng
	if variant == "city" then
		return city(origin, params, rng)
	end
	local b = Kit.new(variant, origin, params)
	local f = BUILDERS[variant] or BUILDERS.house
	local r = f(b, rng)
	b:finish()
	r.radius *= b.s
	r.height *= b.s
	r.center = (origin * CF(r.center * b.s)).Position
	if r.door then
		r.door = (origin * CF(r.door * b.s)).Position
	end
	return r
end

Buildings.Variants = BUILDERS
Buildings.sign = sign

return Buildings
