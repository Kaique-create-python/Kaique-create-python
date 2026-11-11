--!strict
-- Desastres de impacto: meteoros, chuva de pedras, lasers orbitais, explosões.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local FxPaths = require(ReplicatedStorage.IdeiasShared.FxPaths)
local Combat = require(script.Parent.Parent.Parent.Core.Combat)
local Actors = require(script.Parent.Parent.Parent.Core.Actors)
local Fx = require(script.Parent.Parent.Parent.Core.Fx)
local Destruction = require(script.Parent.Parent.Parent.Core.Destruction)
local Placement = require(script.Parent.Parent.Parent.Core.Placement)
local PropActions = require(script.Parent.Parent.Parent.Core.PropActions)
local Kit = require(script.Parent.Parent.Parent.Builders.Kit)
local Builders = require(script.Parent.Parent.Parent.Builders)

local Impact = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- cada meteoro é uma sub-pasta com atributos de trajetória (o cliente desenha)
local function meteorFolder(parent: Instance, from: Vector3, to: Vector3, t0: number, dur: number, radius: number, element: string?, seed: number): Folder
	local f = Instance.new("Folder")
	f.Name = "Meteoro"
	FxPaths.write(f, "meteor", { pos = from, vel = to - from, t0 = t0, dur = dur, radius = radius, height = 0, seed = seed, power = 1 }, element)
	f.Parent = parent
	return f
end

local function crater(ctx: any, pos: Vector3, radius: number, element: string?)
	local b = Kit.new("Cratera", CFrame.new(pos), { anchored = true, collide = true })
	local rock = Color3.fromRGB(70, 60, 55)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		b:part("wedge", Vector3.new(radius * 0.5, radius * 0.3, radius * 0.5), CFrame.new(math.cos(a) * radius * 0.8, radius * 0.1, math.sin(a) * radius * 0.8) * CFrame.Angles(0, -a + math.pi / 2, 0), rock, { role = "fixed", material = Enum.Material.Basalt })
	end
	local core = b:part("cyl", Vector3.new(0.4, radius * 1.2, radius * 1.2), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), if element == "ice" then Color3.fromRGB(150, 220, 255) else Color3.fromRGB(255, 90, 20), { role = "fixed", material = if element == "ice" then Enum.Material.Ice else Enum.Material.CrackedLava })
	local m = b:finish(core)
	m.Parent = ctx.folder
	if element ~= "ice" then
		local fire = Instance.new("Fire")
		fire.Size = radius * 0.6
		fire.Parent = core
	end
	task.delay(10, function()
		if m.Parent then
			m:Destroy()
		end
	end)
end

function Impact.meteor(ctx: any): any
	local p = ctx.params
	local n = math.clamp((p.count or 1) * (if ctx.count > 1 then ctx.count else 1), 1, 14)
	local scale = p.scale or 1
	local element = p.element or "fire"
	local center = ctx.origin.Position
	local t0 = now() + 0.5
	local radius = 10 * scale
	local payloadDef = p.payload and require(ReplicatedStorage.IdeiasShared.Catalog).ById[p.payload]
	-- molde do "recheio" para o cliente usar no lugar da rocha
	if payloadDef then
		local pp = table.clone(payloadDef.params)
		pp.scale = 0.8 * scale
		pp.rng = ctx.rng
		local ok, model = pcall(Builders.any, payloadDef, CFrame.new(0, -1000, 0), pp)
		if ok and model then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			model.Name = "Molde"
			model.Parent = ctx.folder
		end
	end
	for i = 1, n do
		local spread = if n == 1 then 0 else 55
		local target = center + Vector3.new(ctx.rng:range(-spread, spread), 0, ctx.rng:range(-spread, spread))
		-- meteoros miram perto dos jogadores próximos às vezes
		local players = Actors.players()
		if #players > 0 and ctx.rng:chance(0.35) then
			local a = players[ctx.rng:int(1, #players)]
			if (a.root.Position - center).Magnitude < 160 then
				target = a.root.Position + Vector3.new(ctx.rng:range(-12, 12), 0, ctx.rng:range(-12, 12))
			end
		end
		target = Placement.ground(target)
		local from = target + Vector3.new(ctx.rng:range(-120, 120), 260, ctx.rng:range(-120, 120))
		local start = t0 + (i - 1) * ctx.rng:range(0.6, 1.2)
		local dur = 2.4
		meteorFolder(ctx.folder, from, target, start, dur, radius, element, i)
		Fx.near(target, 500, "warn", { p = target, r = radius, d = start - now() + dur })
		task.delay(start - now() + dur, function()
			if not ctx.folder.Parent then
				return
			end
			Fx.flash(target, (Kit.Elements[element] or Kit.Elements.fire).color, radius * 2)
			Fx.shockwave(target, radius * 2.2, Color3.fromRGB(255, 160, 80))
			Fx.shake(target, 1.4 * math.min(scale, 3), 260)
			Fx.near(target, 600, "boom", { p = target, s = scale })
			Combat.area(target, radius * 1.6, 45 * scale, nil, element, 80 * math.min(scale, 3))
			Destruction.blast(target, radius * 2, 100 * math.min(scale, 3))
			crater(ctx, target, radius, element)
			local TerrainScars = require(script.Parent.Parent.Parent.Core.TerrainScars)
			TerrainScars.crater(target, radius * 0.9, element, 45)
			if payloadDef and payloadDef.handler == "prop" and ctx.rng:chance(0.6) then
				local pp = table.clone(payloadDef.params)
				pp.scale = 0.7
				pp.rng = ctx.rng
				pp.physics = true
				local ok, r = pcall(Builders.Props.build, CFrame.new(target + Vector3.new(0, 4, 0)), pp, pp.model or "prop", pp.variant)
				if ok and r then
					r.model.Parent = ctx.folder
				end
			end
		end)
	end
	local last = t0 + n * 1.2 + 3
	-- chuva de meteoros termina com UM meteoro gigante (o "grande final")
	if n >= 5 then
		local bigTarget = Placement.ground(center)
		local bigStart = last - 1
		local bigR = radius * 2.6
		local bigFrom = bigTarget + Vector3.new(ctx.rng:range(-80, 80), 420, ctx.rng:range(-80, 80))
		meteorFolder(ctx.folder, bigFrom, bigTarget, bigStart, 3.4, bigR, element, 99)
		Fx.near(nil, nil, "toast", { t = "☄️ METEORO GIGANTE A CAMINHO!", c = Color3.fromRGB(255, 160, 80) })
		Fx.near(bigTarget, 1500, "warn", { p = bigTarget, r = bigR * 1.5, d = bigStart - now() + 3.4 })
		task.delay(bigStart - now() + 3.4, function()
			if not ctx.folder.Parent then
				return
			end
			Fx.flash(bigTarget, (Kit.Elements[element] or Kit.Elements.fire).color, bigR * 3)
			Fx.shockwave(bigTarget, bigR * 3, Color3.fromRGB(255, 160, 80))
			Fx.shake(bigTarget, 3, 900)
			Fx.near(bigTarget, 2500, "boom", { p = bigTarget, s = scale * 3 })
			Fx.near(bigTarget, 2500, "nuke", { p = bigTarget, s = 2.2 })
			Combat.area(bigTarget, bigR * 2, 120 * scale, nil, element, 140)
			Destruction.blast(bigTarget, bigR * 3, 250, true)
			crater(ctx, bigTarget, bigR, element)
			local TerrainScars = require(script.Parent.Parent.Parent.Core.TerrainScars)
			TerrainScars.crater(bigTarget, bigR * 1.1, element, 70)
		end)
		last += 5
	end
	return {
		position = center,
		radius = 50,
		elements = { element },
		done = function()
			return now() > last + 4
		end,
	}
end

function Impact.rockfall(ctx: any): any
	local p = ctx.params
	local element = p.element
	local center = ctx.origin.Position
	local running = true
	local t0 = os.clock()
	task.spawn(function()
		while running and ctx.folder.Parent and os.clock() - t0 < 14 do
			local players = Actors.players()
			local base = center
			if #players > 0 and ctx.rng:chance(0.5) then
				local a = players[ctx.rng:int(1, #players)]
				if (a.root.Position - center).Magnitude < 150 then
					base = a.root.Position
				end
			end
			local target = Placement.ground(base + Vector3.new(ctx.rng:range(-35, 35), 0, ctx.rng:range(-35, 35)))
			local size = ctx.rng:range(3, 6) * (p.scale or 1)
			local from = target + Vector3.new(0, 120, 0)
			meteorFolder(ctx.folder, from, target, now() + 0.2, 1.8, size, element or "stone", ctx.rng:int(1, 999))
			Fx.near(target, 400, "warn", { p = target, r = size, d = 2 })
			task.delay(2, function()
				if ctx.folder.Parent then
					Fx.near(target, 400, "dust", { p = target, s = size })
					Combat.area(target, size * 1.3, 18, nil, element, 30)
					Destruction.blast(target, size * 1.5, 50)
				end
			end)
			task.wait(0.45)
		end
	end)
	return {
		position = center,
		radius = 40,
		elements = { element },
		stop = function()
			running = false
		end,
	}
end

function Impact.laser_storm(ctx: any): any
	local center = ctx.origin.Position
	local running = true
	local t0 = os.clock()
	local color = Color3.fromRGB(255, 60, 90)
	task.spawn(function()
		while running and ctx.folder.Parent and os.clock() - t0 < 14 do
			local players = Actors.players()
			local target = center + Vector3.new(ctx.rng:range(-60, 60), 0, ctx.rng:range(-60, 60))
			if #players > 0 and ctx.rng:chance(0.45) then
				local a = players[ctx.rng:int(1, #players)]
				if (a.root.Position - center).Magnitude < 150 then
					target = a.root.Position
				end
			end
			target = Placement.ground(target)
			Fx.near(target, 400, "warn", { p = target, r = 7, d = 1.2 })
			task.delay(1.2, function()
				if ctx.folder.Parent then
					Fx.near(target, 600, "laser", { p = target, c = color })
					Combat.area(target, 8, 30, nil, "electric", 40)
					Destruction.blast(target, 10, 60)
				end
			end)
			task.wait(0.5)
		end
	end)
	return {
		position = center,
		radius = 60,
		elements = { "electric" },
		stop = function()
			running = false
		end,
	}
end

function Impact.explosion(ctx: any): any
	local p = ctx.params
	local power = (p.power or 1) * (p.scale or 1)
	local pos = ctx.origin.Position + Vector3.new(0, 2, 0)
	local element = p.element or "fire"
	ctx.folder:SetAttribute("FxKind", "explosion")
	ctx.folder:SetAttribute("FxPos", pos)
	ctx.folder:SetAttribute("FxPower", power)
	ctx.folder:SetAttribute("FxT0", now() + 1)
	ctx.folder:SetAttribute("FxElement", element)
	if p.payload then
		ctx.folder:SetAttribute("FxPayload", p.payload)
	end
	Fx.near(pos, 400, "warn", { p = pos, r = 12 * power, d = 1 })
	task.delay(1, function()
		if ctx.folder.Parent then
			PropActions.explode(pos, power, nil)
			if power >= 1.5 then
				local TerrainScars = require(script.Parent.Parent.Parent.Core.TerrainScars)
				TerrainScars.crater(pos - Vector3.new(0, 2, 0), math.min(8 * power, 48), element, 60)
			end
			if power >= 3 then
				Fx.near(pos, 3000, "nuke", { p = pos, s = power })
				Fx.shake(pos, 4, 1200)
				-- onda de choque que empurra tudo e derruba o mapa destrutível em anel
				for ring = 1, 4 do
					task.delay(ring * 0.35, function()
						if ctx.folder.Parent then
							Destruction.blast(pos, 30 * power * ring, 180, true)
							Combat.area(pos, 24 * power * ring, 30, nil, "fire", 90)
						end
					end)
				end
				-- chão queimado ao redor
				local burnt = Kit.new("ChaoQueimado", CFrame.new(pos), { anchored = true, collide = false })
				for k = 0, 11 do
					local a = k / 12 * math.pi * 2
					local r = ctx.rng:range(14, 30) * power
					burnt:part("cyl", Vector3.new(0.3, ctx.rng:range(8, 16), ctx.rng:range(8, 16)), CFrame.new(math.cos(a) * r, -1.6, math.sin(a) * r) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(25, 20, 18), { role = "fixed", material = Enum.Material.Basalt })
				end
				local bm = burnt:finish()
				bm.Parent = ctx.folder
				task.delay(45, function()
					if bm.Parent then
						bm:Destroy()
					end
				end)
			end
		end
	end)
	return {
		position = pos,
		radius = 20 * power,
		elements = { element },
		done = function()
			return false
		end,
	}
end

return Impact
