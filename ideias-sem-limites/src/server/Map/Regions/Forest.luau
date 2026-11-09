--!strict
-- Floresta Encantada: morros, árvores variadas, árvore mágica gigante,
-- cogumelos luminosos, ruínas, cachoeira com lago, rio com ponte de pedra,
-- caverna, trilha e casa na árvore.

local MapKit = require(script.Parent.Parent.MapKit)

local Forest = { id = "forest" }

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

function Forest.build(ctx: any)
	local rng = ctx.rng
	local c = ctx.center
	local M = Enum.Material
	-- relevo: morros nas bordas
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + 0.3
		local r = 150 + rng:range(-10, 20)
		MapKit.hill(c.X + math.cos(a) * r, c.Z + math.sin(a) * r, rng:range(45, 70), rng:range(12, 24), if k % 2 == 0 then M.Grass else M.LeafyGrass)
	end
	MapKit.hill(c.X - 70, c.Z + 40, 40, 9, M.LeafyGrass)
	-- penhasco com cachoeira ao fundo
	local cliffX, cliffZ = c.X + 40, c.Z - 150
	MapKit.fillBlock(CF(cliffX, 22, cliffZ), V(110, 48, 34), M.Rock)
	MapKit.fillBlock(CF(cliffX, 47, cliffZ + 4), V(110, 4, 30), M.Grass)
	MapKit.fillBlock(CF(cliffX, 23, cliffZ + 18), V(12, 44, 3), M.Water)
	-- lago e rio até o mar
	MapKit.fillCylinder(CF(cliffX, -3, cliffZ + 40), 6, 26, M.Air)
	MapKit.fillCylinder(CF(cliffX, -4.5, cliffZ + 40), 3, 26, M.Water)
	MapKit.fillBlock(CF(cliffX + 70, -3, cliffZ + 40) * ANG(0, 0.25, 0), V(130, 6, 14), M.Air)
	MapKit.fillBlock(CF(cliffX + 70, -4.5, cliffZ + 40) * ANG(0, 0.25, 0), V(130, 3, 14), M.Water)
	-- caverna: morro de pedra com túnel
	MapKit.hill(c.X - 110, c.Z - 60, 38, 26, M.Slate)
	MapKit.fillCylinder(CF(c.X - 110, 6, c.Z - 60) * ANG(0, 0, math.rad(90)), 90, 7, M.Air)

	-- espuma da cachoeira
	ctx:build("Cachoeira", CF(cliffX, 0, cliffZ + 22), function(b)
		local mist = b:box(V(14, 1, 4), CF(0, 0.5, 0), rgb(220, 240, 255), { role = "fixed", transparency = 0.9, collide = false, name = "Nevoa" })
		MapKit.emitter(mist, "rbxasset://textures/particles/smoke_main.dds", rgb(235, 245, 255), 14, { speed = NumberRange.new(2, 5), size = NumberSequence.new(4, 9), lifetime = NumberRange.new(1.5, 2.5) })
	end)

	-- árvore mágica gigante no centro
	ctx:build("ArvoreMagica", ctx:at(0, 0), function(b)
		local bark = rgb(95, 68, 52)
		b:cylY(48, 12, CF(0, 24, 0), bark, { role = "fixed", material = M.Wood })
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			b:beam(V(math.cos(a) * 4, 4, math.sin(a) * 4), V(math.cos(a) * 12, 0, math.sin(a) * 12), 3.2, bark, { role = "fixed", material = M.Wood }, true)
			b:beam(V(0, 34 + k, 0), V(math.cos(a) * 20, 44 + k * 1.5, math.sin(a) * 20), 2.4, bark, { role = "fixed", material = M.Wood }, true)
		end
		for k = 0, 9 do
			local a = k / 10 * math.pi * 2
			local r = if k % 2 == 0 then 20 else 12
			b:ball(22, CF(math.cos(a) * r, 50 + (k % 3) * 4, math.sin(a) * r), rgb(70, 170, 120), { role = "fixed", material = M.Grass, shadow = k < 4 })
		end
		b:ball(26, CF(0, 60, 0), rgb(80, 185, 130), { role = "fixed", material = M.Grass })
		for k = 0, 13 do
			local a = k * 2.3
			local fruit = b:ball(2, CF(math.cos(a) * 21, 44 + (k % 4) * 3, math.sin(a) * 21), rgb(255, 120, 210), { role = "fixed", material = M.Neon, collide = false })
			if k % 4 == 0 then
				b:light(fruit, rgb(255, 140, 220), 18, 1.2)
			end
		end
	end)

	-- árvores espalhadas (evita o centro e o lago)
	local placed = 0
	local tries = 0
	while placed < 60 and tries < 300 do
		tries += 1
		local x, z = rng:range(-160, 160), rng:range(-160, 160)
		local d = math.sqrt(x * x + z * z)
		local nearLake = math.abs(x - 40) < 40 and math.abs(z + 110) < 40
		if d > 34 and d < 165 and not nearLake and math.abs(x) > 8 then
			placed += 1
			local kind = rng:pick({ "tree", "tree", "pine", "pine", "tree" })
			ctx:prop("nature", kind, ctx:at(x, z, 0, rng:range(0, 6)), rng:range(0.9, 1.5))
		end
	end
	-- cogumelos luminosos, flores, arbustos e pedras
	for k = 1, 22 do
		local x, z = rng:range(-150, 150), rng:range(-150, 150)
		if math.sqrt(x * x + z * z) > 30 then
			local pick = k % 4
			if pick == 0 then
				ctx:prop("nature", "mushroom", ctx:at(x, z), rng:range(0.6, 1.3), { collide = true })
			elseif pick == 1 then
				ctx:prop("nature", "flowers", ctx:at(x, z), 0.8)
			elseif pick == 2 then
				ctx:prop("nature", "bush", ctx:at(x, z), rng:range(0.9, 1.4))
			else
				ctx:prop("nature", "rock", ctx:at(x, z), rng:range(0.7, 1.6))
			end
		end
	end

	-- ruínas antigas
	ctx:build("Ruinas", ctx:at(-60, 70), function(b)
		local stone = rgb(170, 165, 150)
		b:box(V(30, 1.2, 22), CF(0, 0.6, 0), stone, { role = "fixed", material = M.Cobblestone })
		for k = 0, 5 do
			local h = if k % 2 == 0 then 14 else rng:range(4, 9)
			b:cylY(h, 2.4, CF(-12 + k * 4.8, 1.2 + h / 2, -8), stone, { role = "fixed", material = M.Marble })
		end
		b:box(V(10, 2, 3), CF(-9.6, 16, -8), stone, { role = "fixed", material = M.Marble })
		b:box(V(4, 3, 3), CF(8, 2.7, 6) * ANG(0.3, 0.6, 0.2), stone, { role = "fixed", material = M.Marble })
		b:box(V(3, 2, 6), CF(-4, 2.2, 7) * ANG(0, 0.4, 1.2), stone, { role = "fixed", material = M.Marble })
		local rune = b:box(V(6, 6, 0.6), CF(0, 4, 9) * ANG(0, 0, math.rad(45)), rgb(120, 255, 200), { role = "fixed", material = M.Neon, transparency = 0.3 })
		b:light(rune, rgb(120, 255, 200), 16, 1)
	end)

	-- ponte de pedra sobre o rio
	ctx:build("PonteRio", CF(cliffX + 60, 0, cliffZ + 36) * ANG(0, 0.25 + math.pi / 2, 0), function(b)
		local stone = rgb(150, 145, 140)
		for k = -4, 4 do
			local y = 3 - (k * k) * 0.12
			b:box(V(6, 1, 4.2), CF(0, y, k * 4), stone, { role = "fixed", material = M.Cobblestone })
		end
		for _, x in { -3.2, 3.2 } do
			for k = -4, 4, 2 do
				b:cylY(2, 0.6, CF(x, 4.4 - (k * k) * 0.12, k * 4), stone, { role = "fixed", material = M.Cobblestone })
			end
		end
	end)

	-- casa na árvore reaproveitando o construtor de construções
	ctx:building("treehouse", ctx:at(90, 60, 0, -0.8), { scale = 1 })

	-- vagalumes (partículas suaves) em pontos da floresta
	for k = 1, 5 do
		local x, z = rng:range(-120, 120), rng:range(-120, 120)
		ctx:build("Vagalumes", ctx:at(x, z, 6), function(b)
			local p = b:box(V(30, 8, 30), CF(0, 0, 0), rgb(255, 255, 255), { role = "fixed", transparency = 1, collide = false, name = "Area" })
			p.CanQuery = false
			MapKit.emitter(p, "rbxasset://textures/particles/sparkles_main.dds", rgb(220, 255, 140), 5, { speed = NumberRange.new(0.3, 1), size = NumberSequence.new(0.25), lifetime = NumberRange.new(3, 6), light = 1 })
		end)
	end

	-- trilha de pedras até o hub
	ctx:build("Trilha", CF(c.X, 0, c.Z), function(b)
		for k = 0, 24 do
			local z = 30 + k * 7
			local x = math.sin(k * 0.4) * 6
			b:part("cyl", V(0.4, rng:range(3, 4.5), rng:range(3, 4.5)), CF(x, MapKit.heightAt(c.X + x, c.Z + z) + 0.15, z) * ANG(0, 0, math.rad(90)), rgb(160, 150, 135), { role = "fixed", material = M.Slate, collide = false })
		end
	end)
end

return Forest
