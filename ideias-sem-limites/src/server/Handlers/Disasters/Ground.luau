--!strict
-- Terremoto, vulcão, incêndio, congelamento e lago de lava.

local Workspace = game:GetService("Workspace")
local Combat = require(script.Parent.Parent.Parent.Core.Combat)
local Actors = require(script.Parent.Parent.Parent.Core.Actors)
local Status = require(script.Parent.Parent.Parent.Core.Status)
local Fx = require(script.Parent.Parent.Parent.Core.Fx)
local Destruction = require(script.Parent.Parent.Parent.Core.Destruction)
local Placement = require(script.Parent.Parent.Parent.Core.Placement)
local Kit = require(script.Parent.Parent.Parent.Builders.Kit)

local Ground = {}

local function loop(ctx: any, duration: number, interval: number, fn: (number) -> ()): () -> ()
	local running = true
	local t0 = os.clock()
	task.spawn(function()
		while running and ctx.folder.Parent and os.clock() - t0 < duration do
			local ok, err = pcall(fn, os.clock() - t0)
			if not ok then
				warn("[Ideias] desastre: " .. tostring(err))
			end
			task.wait(interval)
		end
	end)
	return function()
		running = false
	end
end

-- zona perigosa: queima/congela quem está dentro (checagem barata por distância)
local function hazard(ctx: any, pos: Vector3, radius: number, element: string, dps: number, duration: number): () -> ()
	return loop(ctx, duration, 0.5, function()
		for _, a in Actors.near(pos, radius) do
			if math.abs(a.root.Position.Y - pos.Y) < 8 then
				Combat.damage(a, dps * 0.5, nil, element)
			end
		end
	end)
end

function Ground.earthquake(ctx: any): any
	local center = ctx.origin.Position
	local scale = ctx.params.scale or 1
	Fx.near(center, 800, "toast", { t = "⚠️ Terremoto!", c = Color3.fromRGB(255, 200, 120) })
	-- rachaduras no chão
	local b = Kit.new("Rachaduras", CFrame.new(center), { anchored = true, collide = false })
	for k = 0, 9 do
		local a = ctx.rng:range(0, math.pi * 2)
		local r = ctx.rng:range(5, 40)
		b:box(Vector3.new(ctx.rng:range(0.8, 2), 0.3, ctx.rng:range(10, 24)), CFrame.new(math.cos(a) * r, 0.15, math.sin(a) * r) * CFrame.Angles(0, a, 0), Color3.fromRGB(30, 22, 18), { role = "fixed" })
	end
	-- placas de pedra levantadas ao redor
	for k = 0, 7 do
		local a = ctx.rng:range(0, math.pi * 2)
		local r = ctx.rng:range(10, 45)
		b:box(Vector3.new(ctx.rng:range(4, 9), ctx.rng:range(1.5, 3), ctx.rng:range(5, 10)), CFrame.new(math.cos(a) * r, 0.8, math.sin(a) * r) * CFrame.Angles(ctx.rng:range(-0.5, 0.5), a, ctx.rng:range(-0.4, 0.4)), Color3.fromRGB(95, 85, 75), { role = "fixed", material = Enum.Material.Slate })
	end
	b:finish().Parent = ctx.folder
	local TerrainScars = require(script.Parent.Parent.Parent.Core.TerrainScars)
	TerrainScars.cracks(center, 5, 55 * math.min(scale, 1.3), ctx.rng, 40)
	Fx.near(center, 800, "quake", { p = center, r = 60 * math.min(scale, 1.5), d = 14 })
	local stop = loop(ctx, 14, 0.4, function()
		Fx.shake(center, 1.1 * math.min(scale, 3), 350)
		local p = center + Vector3.new(ctx.rng:range(-80, 80), 0, ctx.rng:range(-80, 80))
		Destruction.blast(p, 25, 40)
		for _, a in Actors.near(center, 120) do
			if ctx.rng:chance(0.15) then
				Combat.push(a, Vector3.new(ctx.rng:range(-10, 10), 18, ctx.rng:range(-10, 10)))
			end
		end
	end)
	return { position = center, radius = 120, elements = {}, stop = stop }
end

function Ground.volcano(ctx: any): any
	local center = ctx.origin.Position
	local scale = ctx.params.scale or 1
	local b = Kit.new("Vulcao", ctx.origin, { anchored = true, collide = true, scale = scale })
	b:cone(26, 40, CFrame.new(0, 0, 0), Color3.fromRGB(70, 55, 50), 6, { role = "fixed", material = Enum.Material.Basalt })
	local lava = b:part("cyl", Vector3.new(1, 12, 12), CFrame.new(0, 24, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 90, 20), { role = "fixed", material = Enum.Material.Neon, name = "Cratera" })
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 0.4
		b:part("wedge", Vector3.new(2.5, 1, 18), CFrame.new(math.cos(a) * 12, 12, math.sin(a) * 12) * CFrame.Angles(0, -a - math.pi / 2, 0) * CFrame.Angles(math.rad(-50), 0, 0), Color3.fromRGB(255, 110, 30), { role = "fixed", material = Enum.Material.Neon, collide = false })
	end
	local m = b:finish(lava)
	m.Parent = ctx.folder
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(60, 55, 55)
	smoke.Size = 20
	smoke.RiseVelocity = 20
	smoke.Opacity = 0.4
	smoke.Parent = lava
	b:light(lava, Color3.fromRGB(255, 120, 40), 60, 3)
	local top = lava.Position
	Fx.shake(center, 1, 300)
	local stop = loop(ctx, 26, 0.5, function()
		-- bombas de lava
		local target = Placement.ground(center + Vector3.new(ctx.rng:range(-70, 70), 0, ctx.rng:range(-70, 70)))
		Fx.bolt(top, target, Color3.fromRGB(255, 100, 30), 70, 3)
		local d = (target - top).Magnitude
		task.delay(d / 70, function()
			if ctx.folder.Parent then
				Fx.near(target, 400, "boom", { p = target, s = 0.5 })
				Combat.area(target, 9, 22, nil, "lava", 40)
				Destruction.blast(target, 10, 50)
			end
		end)
		for _, a in Actors.near(center, 22 * scale) do
			Combat.damage(a, 4, nil, "lava")
		end
	end)
	return { position = center, radius = 20 * scale, elements = { "lava", "fire" }, model = m, stop = stop }
end

function Ground.fire(ctx: any): any
	local center = ctx.origin.Position
	local patches: { BasePart } = {}
	local scale = ctx.params.scale or 1
	local stops = {}
	local running = true
	task.spawn(function()
		for i = 1, math.floor(10 * math.min(scale, 2)) do
			if not running or not ctx.folder.Parent then
				break
			end
			local ang = i * 2.4
			local r = 4 + i * 2.2
			local pos = Placement.ground(center + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r))
			local patch = Instance.new("Part")
			patch.Anchored = true
			patch.CanCollide = false
			patch.CanQuery = false
			patch.Size = Vector3.new(7, 0.4, 7)
			patch.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0))
			patch.Material = Enum.Material.CrackedLava
			patch.Color = Color3.fromRGB(80, 30, 15)
			patch.Name = "Fogo"
			local f = Instance.new("Fire")
			f.Size = 9
			f.Heat = 14
			f.Parent = patch
			patch.Parent = ctx.folder
			table.insert(patches, patch)
			table.insert(stops, hazard(ctx, pos, 6, "fire", 10, 22))
			Destruction.blast(pos, 8, 15)
			task.wait(0.6)
		end
	end)
	return {
		position = center,
		radius = 25,
		elements = { "fire" },
		patches = patches,
		stop = function()
			running = false
			for _, s in stops do
				s()
			end
		end,
		extinguish = function()
			for _, p in patches do
				p:Destroy()
			end
			running = false
			for _, s in stops do
				s()
			end
		end,
	}
end

function Ground.ice(ctx: any): any
	local center = ctx.origin.Position
	local scale = ctx.params.scale or 1
	local radius = 30 * math.min(scale, 3)
	local b = Kit.new("Gelo", CFrame.new(center), { anchored = true, collide = true })
	for i = 1, 22 do
		local ang = ctx.rng:range(0, math.pi * 2)
		local r = ctx.rng:range(3, radius)
		local h = ctx.rng:range(4, 12) * math.min(scale, 2)
		local tilt = ctx.rng:range(-0.4, 0.4)
		b:part("wedge", Vector3.new(2.2, h, 2.2), CFrame.new(math.cos(ang) * r, h / 2 - 0.5, math.sin(ang) * r) * CFrame.Angles(tilt, ang, tilt), Color3.fromRGB(170, 225, 255), { role = "fixed", material = Enum.Material.Ice, transparency = 0.15 })
		if i % 4 == 0 then
			b:part("wedge", Vector3.new(2.2, h, 2.2), CFrame.new(math.cos(ang) * r, h / 2 - 0.5, math.sin(ang) * r) * CFrame.Angles(tilt, ang + math.pi, tilt), Color3.fromRGB(200, 240, 255), { role = "fixed", material = Enum.Material.Glass, transparency = 0.3 })
		end
	end
	local floor = b:part("cyl", Vector3.new(0.3, radius * 2, radius * 2), CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 235, 255), { role = "fixed", material = Enum.Material.Glacier })
	local m = b:finish(floor)
	m.Parent = ctx.folder
	Fx.shockwave(center, radius, Color3.fromRGB(170, 230, 255))
	for _, a in Actors.near(center, radius) do
		Combat.damage(a, 12, nil, "ice")
		Status.apply(a.humanoid, "freeze", 3.5)
	end
	return { position = center, radius = radius, elements = { "ice" }, model = m }
end

function Ground.lava(ctx: any): any
	local center = ctx.origin.Position
	local scale = ctx.params.scale or 1
	local pool = Instance.new("Part")
	pool.Anchored = true
	pool.CanCollide = false
	pool.Shape = Enum.PartType.Cylinder
	pool.Material = Enum.Material.Neon
	pool.Color = Color3.fromRGB(255, 90, 20)
	pool.Size = Vector3.new(0.6, 6, 6)
	pool.CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pool.Name = "Lava"
	pool.Parent = ctx.folder
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 40)
	light.Range = 40
	light.Parent = pool
	local maxD = 50 * math.min(scale, 2.5)
	local stop = loop(ctx, 20, 0.25, function(t)
		local d = math.min(6 + t * 6, maxD)
		pool.Size = Vector3.new(0.6, d, d)
		for _, a in Actors.near(center, d / 2) do
			if math.abs(a.root.Position.Y - center.Y) < 7 then
				Combat.damage(a, 3, nil, "lava")
			end
		end
	end)
	return {
		position = center,
		radius = maxD / 2,
		elements = { "lava", "fire" },
		stop = function()
			stop()
			pool.Material = Enum.Material.Basalt
			pool.Color = Color3.fromRGB(30, 28, 32)
		end,
	}
end

Ground._ws = Workspace

return Ground
