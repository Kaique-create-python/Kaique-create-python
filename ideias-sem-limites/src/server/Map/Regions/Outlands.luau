--!strict
-- Áreas adicionais: Deserto das Ruínas, Praia dos Coqueiros, Ilhas Flutuantes
-- e Arena Subterrânea.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapLayout = require(ReplicatedStorage.IdeiasShared.MapLayout)
local MapKit = require(script.Parent.Parent.MapKit)

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

local Desert = { id = "desert" }
function Desert.build(ctx: any)
	local rng = ctx.rng
	local c = ctx.center
	local M = Enum.Material
	MapKit.fillCylinder(CF(c.X, -1.5, c.Z), 3.2, 130, M.Sand)
	for k = 1, 7 do
		MapKit.hill(c.X + rng:range(-110, 110), c.Z + rng:range(-110, 110), rng:range(25, 45), rng:range(5, 12), M.Sand)
	end
	-- oásis
	MapKit.fillCylinder(CF(c.X + 50, -2, c.Z + 40), 4, 18, M.Air)
	MapKit.fillCylinder(CF(c.X + 50, -3.5, c.Z + 40), 2, 18, M.Water)
	ctx:building("pyramid", ctx:at(-30, -40, 0, 0.3), { scale = 1.3 })
	ctx:building("pyramid", ctx:at(40, -80, 0, -0.2), { scale = 0.7 })
	-- obeliscos e colunas quebradas
	for k = 1, 4 do
		ctx:build("Obelisco", ctx:at(rng:range(-90, 90), rng:range(-90, 90)), function(b)
			local h = rng:range(14, 24)
			b:box(V(3, h, 3), CF(0, h / 2, 0), rgb(215, 185, 125), { role = "fixed", material = M.Sandstone })
			b:part("wedge", V(3, 2, 1.5), CF(0, h + 1, -0.75), rgb(255, 215, 90), { role = "fixed", material = M.Foil })
			b:part("wedge", V(3, 2, 1.5), CF(0, h + 1, 0.75) * ANG(0, math.pi, 0), rgb(255, 215, 90), { role = "fixed", material = M.Foil })
		end)
	end
	for k = 1, 8 do
		local m = ctx:build("Coluna", ctx:at(rng:range(-100, 100), rng:range(-100, 100), 0, rng:range(0, 6)), function(b)
			local h = rng:range(3, 9)
			b:cylY(h, 2.6, CF(0, h / 2, 0), rgb(220, 200, 160), { role = "fixed", material = M.Sandstone })
		end)
		if k % 2 == 0 then
			ctx:destructible(m)
		end
	end
	for k = 1, 12 do
		ctx:prop("nature", "cactus", ctx:at(rng:range(-110, 110), rng:range(-110, 110)), rng:range(0.7, 1.3))
	end
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2
		ctx:prop("nature", "palm", ctx:at(50 + math.cos(a) * 24, 40 + math.sin(a) * 24), rng:range(0.9, 1.2))
	end
end

local Beach = { id = "beach" }
function Beach.build(ctx: any)
	local rng = ctx.rng
	local c = ctx.center
	local M = Enum.Material
	-- areia descendo até o mar
	for k = 0, 4 do
		local off = V(-1, 0, 1).Unit * (k * 26)
		MapKit.fillCylinder(CF(c.X + off.X, -1.5 - k * 0.6, c.Z + off.Z), 3.2, 110 - k * 8, M.Sand)
	end
	MapKit.flat(c.X, c.Z, 100, 0)
	for k = 1, 14 do
		ctx:prop("nature", "palm", ctx:at(rng:range(-90, 70), rng:range(-70, 90)), rng:range(0.9, 1.4))
	end
	for k = 1, 6 do
		local x, z = rng:range(-60, 60), rng:range(-40, 60)
		ctx:prop("prop", "umbrella", ctx:at(x, z), 0.9)
		ctx:build("Toalha", ctx:at(x + 4, z), function(b)
			b:box(V(4, 0.15, 7), CF(0, 0.08, 0), rng:pick({ rgb(255, 90, 90), rgb(90, 160, 255), rgb(255, 220, 80) }), { role = "fixed", material = M.Fabric, collide = false })
		end)
	end
	-- castelo de areia e píer
	ctx:building("castle", ctx:at(20, -30, 0, 0.4), { scale = 0.18, material = "stone", color = { 0.9, 0.8, 0.55 } })
	ctx:build("Pier", ctx:at(-70, 70, 0, -math.pi / 4), function(b)
		local wood = rgb(150, 110, 70)
		for k = 0, 11 do
			b:box(V(8, 0.6, 4), CF(0, 1.5, -k * 4.2), wood, { role = "fixed", material = M.WoodPlanks })
			if k % 3 == 0 then
				for _, x in { -3.6, 3.6 } do
					b:cylY(8, 0.8, CF(x, -1.5, -k * 4.2), rgb(110, 80, 50), { role = "fixed", material = M.Wood })
				end
			end
		end
	end)
	ctx:build("Salvavidas", ctx:at(-30, 30), function(b)
		for _, x in { -2, 2 } do
			for _, z in { -2, 2 } do
				b:cylY(8, 0.5, CF(x, 4, z), rgb(250, 250, 250), { role = "fixed" })
			end
		end
		b:box(V(6, 0.6, 6), CF(0, 8.3, 0), rgb(230, 60, 60), { role = "fixed" })
		b:roof(6.6, 6.6, 2.4, CF(0, 11.5, 0), rgb(230, 60, 60), { role = "fixed" })
		b:box(V(6, 3, 0.3), CF(0, 9.8, -3), rgb(250, 250, 250), { role = "fixed" })
	end)
end

local Sky = { id = "sky" }
function Sky.build(ctx: any)
	local rng = ctx.rng
	local c = ctx.center
	local M = Enum.Material
	local islands = {
		{ V(0, 0, 0), 46 },
		{ V(80, 20, 40), 26 },
		{ V(-70, 35, 50), 22 },
		{ V(40, 50, -80), 24 },
		{ V(-60, -15, -60), 20 },
	}
	for i, isl in islands do
		local pos, r = c + isl[1], isl[2]
		ctx:build("Ilha", CF(pos), function(b)
			b:cylY(5, r * 2, CF(0, 0, 0), rgb(110, 190, 90), { role = "fixed", material = M.Grass })
			b:cylY(3, r * 2 - 2, CF(0, -3.5, 0), rgb(130, 100, 75), { role = "fixed", material = M.Ground })
			b:cone(r * 1.1, r * 1.9, CF(0, -4, 0) * ANG(math.pi, 0, 0), rgb(120, 105, 95), 5, { role = "fixed", material = M.Slate })
			for k = 1, math.floor(r / 8) do
				local a = rng:range(0, math.pi * 2)
				local d = rng:range(4, r * 0.7)
				local col = rng:pick({ rgb(255, 160, 220), rgb(160, 230, 255), rgb(200, 255, 170) })
				b:cylY(rng:range(6, 9), 1.4, CF(math.cos(a) * d, 6, math.sin(a) * d), rgb(110, 80, 60), { role = "fixed", material = M.Wood })
				b:ball(rng:range(7, 10), CF(math.cos(a) * d, 11, math.sin(a) * d), col, { role = "fixed", material = M.Grass })
			end
			if i == 1 then
				-- templo do cristal no topo da ilha principal
				for k = 0, 5 do
					local a = k / 6 * math.pi * 2
					b:cylY(14, 2, CF(math.cos(a) * 12, 9.5, math.sin(a) * 12), rgb(245, 240, 255), { role = "fixed", material = M.Marble })
				end
				b:cylY(1.4, 30, CF(0, 17, 0), rgb(245, 240, 255), { role = "fixed", material = M.Marble })
				local crystal = b:part("wedge", V(6, 14, 6), CF(0, 10, 0), rgb(200, 150, 255), { role = "fixed", material = M.Neon, transparency = 0.15, name = "Cristal" })
				MapKit.spin(crystal, "Y", 0.4)
				b:light(crystal, rgb(200, 150, 255), 50, 3)
				local fall = b:box(V(6, 60, 1.6), CF(r - 2, -28, 0), rgb(160, 220, 255), { role = "fixed", material = M.Glass, transparency = 0.45, collide = false })
				MapKit.emitter(fall, "rbxasset://textures/particles/smoke_main.dds", rgb(235, 245, 255), 4, { speed = NumberRange.new(0, 1), size = NumberSequence.new(4, 8) })
			end
		end)
	end
	-- trilha de nuvens entre as ilhas
	for i = 2, #islands do
		local a, bpos = c + islands[1][1], c + islands[i][1]
		for k = 1, 4 do
			local p = a:Lerp(bpos, k / 5) + V(0, 3, 0)
			ctx:build("Nuvem", CF(p), function(b)
				for j = 0, 3 do
					b:ball(rng:range(5, 7), CF(math.cos(j * 1.6) * 2.6, 0, math.sin(j * 1.6) * 2.6), rgb(250, 252, 255), { role = "fixed", collide = true })
				end
			end)
		end
	end
	-- volta ao chão
	local hub = MapLayout.ById.hub
	ctx:teleportPad(CF(c + V(-20, 3, 20)), CF(hub.center + V(0, 8, 40)), "Voltar ao Centro", rgb(120, 220, 255))
end

local Arena = { id = "arena" }
function Arena.build(ctx: any)
	local c = ctx.center
	local M = Enum.Material
	ctx:build("Arena", CF(c), function(b)
		local stone = rgb(90, 80, 75)
		b:box(V(150, 4, 150), CF(0, -2, 0), rgb(120, 100, 80), { role = "fixed", material = M.Sand })
		b:box(V(150, 4, 150), CF(0, 44, 0), stone, { role = "fixed", material = M.Slate })
		for _, w in { { 0, -75, 150, 4 }, { 0, 75, 150, 4 }, { -75, 0, 4, 150 }, { 75, 0, 4, 150 } } do
			b:box(V(w[3], 46, w[4]), CF(w[1], 21, w[2]), stone, { role = "fixed", material = M.Cobblestone })
		end
		-- arquibancadas
		for k = 0, 3 do
			for _, side in { -1, 1 } do
				b:box(V(140, 2, 5), CF(0, 1 + k * 2.4, side * (70 - k * 5)), rgb(130, 115, 100), { role = "fixed", material = M.Concrete })
			end
		end
		-- marcações neon no chão
		b:cylY(0.2, 60, CF(0, 0.1, 0), rgb(255, 70, 70), { role = "fixed", material = M.Neon })
		b:cylY(0.25, 57, CF(0, 0.12, 0), rgb(120, 100, 80), { role = "fixed", material = M.Sand })
		-- tochas
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local p = V(math.cos(a) * 66, 10, math.sin(a) * 66)
			local torch = b:box(V(1, 3, 1), CF(p), rgb(90, 60, 40), { role = "fixed" })
			local flame = b:ball(1.2, CF(p + V(0, 2, 0)), rgb(255, 150, 50), { role = "fixed", material = M.Neon, collide = false })
			local f = Instance.new("Fire")
			f.Size = 4
			f.Parent = flame
			b:light(flame, rgb(255, 150, 60), 40, 2)
			local _ = torch
		end
		local banner = b:box(V(40, 8, 1), CF(0, 30, 73), rgb(140, 20, 30), { role = "fixed", name = "Faixa" })
		MapKit.sign(banner, "ARENA SUBTERRÂNEA", rgb(255, 220, 120), Enum.NormalId.Front)
	end)
	local hub = MapLayout.ById.hub
	ctx:teleportPad(CF(c + V(0, 0.9, 55)), CF(hub.center + V(0, 8, 40)), "Voltar ao Centro", rgb(120, 220, 255))
end

return { Desert = Desert, Beach = Beach, Sky = Sky, Arena = Arena }
