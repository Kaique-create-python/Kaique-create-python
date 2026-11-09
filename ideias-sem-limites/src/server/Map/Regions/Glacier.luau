--!strict
-- Região Glacial: montanhas nevadas, lago congelado, castelo de gelo,
-- cristais, iglus, pinheiros com neve, ponte de gelo sobre uma fenda e neve caindo.

local MapKit = require(script.Parent.Parent.MapKit)

local Glacier = { id = "glacier" }

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

function Glacier.build(ctx: any)
	local rng = ctx.rng
	local c = ctx.center
	local M = Enum.Material
	MapKit.fillCylinder(CF(c.X, -1.5, c.Z), 3.2, 180, M.Snow)
	-- montanhas ao fundo
	for k = 0, 4 do
		local a = math.pi * 0.15 + k / 4 * math.pi * 0.7
		local r = 150
		MapKit.mountain(c.X + math.cos(a) * r, c.Z + math.sin(a) * r, rng:range(45, 65), rng:range(50, 85), M.Rock, M.Snow)
	end
	MapKit.hill(c.X - 120, c.Z - 40, 50, 14, M.Snow)
	-- lago congelado
	MapKit.fillCylinder(CF(c.X + 70, -1.2, c.Z - 30), 2.6, 42, M.Glacier)
	MapKit.flat(c.X + 70, c.Z - 30, 42, 0.1)
	-- fenda com ponte de gelo
	MapKit.fillBlock(CF(c.X - 50, -6, c.Z + 30), V(14, 16, 90), M.Air)

	-- castelo de gelo
	ctx:building("castle", ctx:at(-20, 60, 0, math.pi), { scale = 0.9, material = "ice", color = { 0.75, 0.9, 1 } })

	ctx:build("PonteDeGelo", CF(c.X - 50, 0, c.Z + 30) * ANG(0, math.pi / 2, 0), function(b)
		for k = -2, 2 do
			b:box(V(6, 1, 3.6), CF(0, 0.5 + (4 - k * k) * 0.25, k * 3.6), rgb(190, 235, 255), { role = "fixed", material = M.Ice, transparency = 0.1 })
		end
		for _, x in { -2.8, 2.8 } do
			b:box(V(0.4, 1.4, 18), CF(x, 2.6, 0), rgb(200, 240, 255), { role = "fixed", material = M.Glass, transparency = 0.3 })
		end
	end)

	-- cristais de gelo e pinheiros nevados
	for k = 1, 14 do
		local x, z = rng:range(-150, 150), rng:range(-150, 150)
		if math.sqrt(x * x + z * z) > 40 then
			ctx:prop("nature", "crystal", ctx:at(x, z), rng:range(0.8, 1.8), { material = "ice" })
		end
	end
	for k = 1, 26 do
		local x, z = rng:range(-160, 160), rng:range(-160, 160)
		if math.sqrt(x * x + z * z) > 50 and not (math.abs(x - 70) < 46 and math.abs(z + 30) < 46) then
			local tree = ctx:prop("nature", "pine", ctx:at(x, z), rng:range(0.9, 1.4))
			local top = tree:GetExtentsSize()
			ctx:build("NeveNoPinheiro", ctx:at(x, z, top.Y * 0.55), function(b)
				b:part("ball", V(8, 2.5, 8), CF(0, 0, 0), rgb(250, 252, 255), { role = "fixed", material = M.Snow, collide = false })
			end)
		end
	end
	-- iglus e bonecos de neve
	ctx:building("igloo", ctx:at(90, 70, 0, -0.5))
	ctx:building("igloo", ctx:at(115, 40, 0, 0.8), { scale = 0.8 })
	for k = 1, 4 do
		ctx:prop("prop", "snowman", ctx:at(rng:range(-90, 90), rng:range(-20, 120)), rng:range(0.7, 1))
	end
	-- neve caindo sobre a região
	ctx:build("Neve", CF(c.X, 90, c.Z), function(b)
		for k = 0, 2 do
			local p = b:box(V(140, 1, 140), CF((k - 1) * 110, 0, 0), rgb(255, 255, 255), { role = "fixed", transparency = 1, collide = false, name = "Nuvem" })
			p.CanQuery = false
			MapKit.emitter(p, "rbxasset://textures/particles/sparkles_main.dds", rgb(255, 255, 255), 40, {
				speed = NumberRange.new(10, 16),
				spread = Vector2.new(10, 10),
				lifetime = NumberRange.new(6, 8),
				size = NumberSequence.new(0.45),
				accel = V(2, 0, 1),
				light = 0.3,
			}).EmissionDirection = Enum.NormalId.Bottom
		end
	end)
end

return Glacier
