--!strict
-- Região Vulcânica: vulcão central com cratera de lava, rios de lava que
-- queimam, pedras negras, forja industrial com chaminés e canos, pontes de
-- metal resistentes e brasas no ar.

local MapKit = require(script.Parent.Parent.MapKit)

local Volcano = { id = "volcano" }

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

function Volcano.build(ctx: any)
	local rng = ctx.rng
	local c = ctx.center
	local M = Enum.Material
	MapKit.fillCylinder(CF(c.X, -1.5, c.Z), 3.2, 185, M.Basalt)
	-- vulcão
	local vx, vz = c.X - 40, c.Z
	MapKit.mountain(vx, vz, 95, 92, M.Basalt, M.Rock)
	MapKit.fillCylinder(CF(vx, 86, vz), 20, 18, M.Air)
	MapKit.fillCylinder(CF(vx, 78, vz), 4, 18, M.CrackedLava)
	-- rios de lava descendo e cruzando a região
	local rivers = {}
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2 + 0.6
		local dir = V(math.cos(a), 0, math.sin(a))
		table.insert(rivers, { a = a, dir = dir })
		for s = 0, 6 do
			local d = 30 + s * 16
			local p = V(vx, 0, vz) + dir * d
			local y = MapKit.heightAt(p.X, p.Z)
			MapKit.fillBlock(CF(p.X, y - 1, p.Z) * ANG(0, -a, 0), V(18, 4, 9), M.CrackedLava)
		end
	end
	ctx:build("LavaViva", CF(0, 0, 0), function(b)
		for _, r in rivers do
			for s = 7, 10 do
				local p = V(vx, 0, vz) + r.dir * (30 + s * 16)
				local part = b:box(V(18, 0.6, 10), CF(p.X, MapKit.heightAt(p.X, p.Z) + 0.3, p.Z) * ANG(0, -r.a + math.pi / 2, 0), rgb(255, 95, 25), { role = "fixed", material = M.Neon, collide = false, name = "Lava" })
				MapKit.hazard(part, "lava", 10)
				if s % 2 == 0 then
					b:light(part, rgb(255, 120, 40), 26, 2)
				end
			end
		end
		local crater = b:part("cyl", V(1, 34, 34), CF(vx, 80.6, vz) * ANG(0, 0, math.rad(90)), rgb(255, 100, 30), { role = "fixed", material = M.Neon, name = "Cratera" })
		MapKit.hazard(crater, "lava", 20)
		b:light(crater, rgb(255, 130, 40), 60, 4)
		local smoke = Instance.new("Smoke")
		smoke.Color = rgb(70, 60, 60)
		smoke.Size = 30
		smoke.RiseVelocity = 18
		smoke.Opacity = 0.35
		smoke.Parent = crater
		MapKit.emitter(crater, "rbxasset://textures/particles/fire_main.dds", rgb(255, 150, 60), 30, { speed = NumberRange.new(15, 30), spread = Vector2.new(30, 30), lifetime = NumberRange.new(1.5, 3), size = NumberSequence.new(3, 0), accel = V(0, -10, 0), light = 1 })
	end)
	-- pontes de metal sobre os rios
	for _, r in rivers do
		local p = V(vx, 0, vz) + r.dir * 150
		ctx:build("PonteMetal", CF(p.X, MapKit.heightAt(p.X, p.Z), p.Z) * ANG(0, -r.a, 0), function(b)
			local steel = rgb(110, 110, 120)
			b:box(V(26, 1, 8), CF(0, 2.5, 0), steel, { role = "fixed", material = M.DiamondPlate })
			for _, z in { -3.8, 3.8 } do
				b:box(V(26, 0.5, 0.5), CF(0, 5.5, z), rgb(200, 120, 40), { role = "fixed", material = M.Metal })
				for x = -12, 12, 6 do
					b:box(V(0.5, 3, 0.5), CF(x, 4, z), steel, { role = "fixed", material = M.Metal })
					b:beam(V(x, 2.5, z), V(x + 3, 5.5, z), 0.35, steel, { role = "fixed", material = M.Metal })
				end
			end
		end)
	end
	-- forja industrial
	ctx:build("Forja", ctx:at(90, -70), function(b)
		local wall = rgb(70, 66, 70)
		b:box(V(40, 1, 30), CF(0, 0.5, 0), rgb(50, 48, 52), { role = "fixed", material = M.DiamondPlate })
		b:box(V(36, 16, 26), CF(0, 9, 0), wall, { role = "fixed", material = M.CorrodedMetal })
		b:box(V(12, 10, 0.6), CF(0, 6, -13.2), rgb(255, 120, 30), { role = "fixed", material = M.Neon, transparency = 0.2 })
		for k = 0, 2 do
			local chimney = b:cylY(18, 3.4, CF(-12 + k * 12, 26, 6), rgb(80, 70, 70), { role = "fixed", material = M.Brick })
			local smoke = Instance.new("Smoke")
			smoke.Color = rgb(60, 55, 55)
			smoke.Size = 6
			smoke.RiseVelocity = 10
			smoke.Opacity = 0.3
			smoke.Parent = chimney
		end
		for k = 0, 3 do
			b:part("cyl", V(30, 1.6, 1.6), CF(0, 4 + k * 2.5, 14.5), rgb(150, 90, 40), { role = "fixed", material = M.Metal })
		end
	end)
	-- pedras negras espalhadas e brasas
	for k = 1, 20 do
		local x, z = rng:range(-170, 170), rng:range(-170, 170)
		if (V(c.X + x, 0, c.Z + z) - V(vx, 0, vz)).Magnitude > 100 then
			ctx:prop("nature", "rock", ctx:at(x, z), rng:range(0.8, 2.2), { color = { 0.18, 0.17, 0.2 }, material = "stone" })
		end
	end
	for k = 1, 3 do
		ctx:build("Brasas", ctx:at(rng:range(-120, 120), rng:range(-120, 120), 3), function(b)
			local p = b:box(V(60, 4, 60), CF(0, 0, 0), rgb(255, 255, 255), { role = "fixed", transparency = 1, collide = false, name = "Area" })
			p.CanQuery = false
			MapKit.emitter(p, "rbxasset://textures/particles/sparkles_main.dds", rgb(255, 140, 50), 8, { speed = NumberRange.new(2, 5), accel = V(0, 3, 0), size = NumberSequence.new(0.3), lifetime = NumberRange.new(3, 5), light = 1 })
		end)
	end
end

return Volcano
