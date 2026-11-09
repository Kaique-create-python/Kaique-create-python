--!strict
-- Tornados, tempestades elétricas, nevasca, chuva ácida, areia, vento,
-- gravidade e tsunami. Movimento por trajetória determinística (FxPaths).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local FxPaths = require(ReplicatedStorage.IdeiasShared.FxPaths)
local Combat = require(script.Parent.Parent.Parent.Core.Combat)
local Actors = require(script.Parent.Parent.Parent.Core.Actors)
local Status = require(script.Parent.Parent.Parent.Core.Status)
local Fx = require(script.Parent.Parent.Parent.Core.Fx)
local Destruction = require(script.Parent.Parent.Parent.Core.Destruction)
local Ambience = require(script.Parent.Parent.Parent.Core.Ambience)
local Placement = require(script.Parent.Parent.Parent.Core.Placement)
local Builders = require(script.Parent.Parent.Parent.Builders)

local Storms = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function addMold(ctx: any, payloadId: string?, scale: number)
	if not payloadId then
		return
	end
	local def = require(ReplicatedStorage.IdeiasShared.Catalog).ById[payloadId]
	if not def then
		return
	end
	local pp = table.clone(def.params)
	pp.scale = scale
	pp.rng = ctx.rng
	local ok, model = pcall(Builders.any, def, CFrame.new(0, -1000, 0), pp)
	if ok and model then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		model.Name = "Molde"
		model.Parent = ctx.folder
		ctx.folder:SetAttribute("FxPayload", payloadId)
	end
end

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

function Storms.tornado(ctx: any): any
	local p = ctx.params
	local scale = p.scale or 1
	local element = if p.elementMod then p.element else nil
	local dir = ctx.origin.LookVector
	local start = ctx.origin.Position - dir * 70
	local speed = 14 * (p.speedMul or 1)
	local spec = { pos = start, vel = dir * speed, t0 = now(), dur = 26, radius = 16 * scale, height = 90 * scale, seed = ctx.rng:range(0, 6), power = scale }
	FxPaths.write(ctx.folder, "tornado", spec, element or "wind")
	addMold(ctx, p.payload, 0.6)
	local stop = loop(ctx, 26, 0.15, function()
		local c = FxPaths.tornado(spec, now())
		for _, a in Actors.near(c, spec.radius * 1.6) do
			local rel = a.root.Position - c
			local flat = Vector3.new(rel.X, 0, rel.Z)
			local tangent = if flat.Magnitude > 0.1 then Vector3.new(-flat.Z, 0, flat.X).Unit else Vector3.xAxis
			local inward = if flat.Magnitude > 0.1 then -flat.Unit else Vector3.zero
			local lift = if a.root.Position.Y < c.Y + spec.height * 0.6 then 22 else -5
			Combat.push(a, tangent * 18 * math.min(scale, 3) + inward * 6 + Vector3.new(0, lift, 0))
			Combat.damage(a, 1.5 * scale, nil, element)
		end
		Destruction.blast(c, spec.radius * 1.4, 45 * math.min(scale, 3))
	end)
	return {
		position = start,
		radius = spec.radius,
		elements = { element or "wind" },
		positionAt = function()
			return FxPaths.tornado(spec, now())
		end,
		stop = stop,
	}
end

function Storms.tsunami(ctx: any): any
	local p = ctx.params
	local scale = p.scale or 1
	local dir = ctx.origin.LookVector * -1
	local start = ctx.origin.Position - dir * 150
	local speed = 32 * (p.speedMul or 1)
	local width = 260
	local spec = { pos = start, vel = dir * speed, t0 = now() + 1, dur = 12, radius = width / 2, height = 26 * scale, seed = 0, power = scale }
	FxPaths.write(ctx.folder, "tsunami", spec, p.element or "water")
	addMold(ctx, p.payload, 0.6)
	Fx.near(ctx.origin.Position, 600, "toast", { t = "🌊 Onda gigante chegando!", c = Color3.fromRGB(120, 200, 255) })
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local stop = loop(ctx, 14, 0.15, function()
		local front = FxPaths.wave(spec, now())
		for _, a in Actors.near(front, width * 0.6) do
			local rel = a.root.Position - front
			local along = rel:Dot(dir)
			local side = math.abs(rel:Dot(right))
			if along > -12 and along < 8 and side < width / 2 and a.root.Position.Y < front.Y + spec.height then
				Combat.push(a, dir * speed * 1.3 + Vector3.new(0, 26, 0))
				Combat.damage(a, 3 * scale, nil, "water")
			end
		end
		for k = -3, 3 do
			Destruction.blast(front + right * (k * 35), 20, 70)
		end
	end)
	return { position = ctx.origin.Position, radius = 60, elements = { "water" }, stop = stop }
end

function Storms.lightning(ctx: any): any
	local center = ctx.origin.Position
	local heavy = ctx.spec.heavy or (ctx.params.scale or 1) > 1.5
	local restore = Ambience.push({ Brightness = 0.9, OutdoorAmbient = Color3.fromRGB(70, 75, 95), AtmosphereDensity = 0.45, Clima = "tempestade" }, 18, 2)
	ctx.folder:SetAttribute("FxKind", "storm")
	ctx.folder:SetAttribute("FxPos", center)
	local stop = loop(ctx, 17, if heavy then 0.45 else 0.8, function()
		local players = Actors.players()
		local target = center + Vector3.new(ctx.rng:range(-70, 70), 0, ctx.rng:range(-70, 70))
		if #players > 0 and ctx.rng:chance(0.4) then
			local a = players[ctx.rng:int(1, #players)]
			if (a.root.Position - center).Magnitude < 160 then
				target = a.root.Position
			end
		end
		target = Placement.ground(target)
		Fx.near(target, 500, "warn", { p = target, r = 7, d = 0.8 })
		task.delay(0.8, function()
			if ctx.folder.Parent then
				Fx.near(target, 900, "lightning", { p = target })
				Combat.area(target, 9, 28, nil, "electric", 35)
				Destruction.blast(target, 10, 50)
			end
		end)
	end)
	return {
		position = center,
		radius = 70,
		elements = { "electric" },
		stop = function()
			stop()
			restore()
		end,
	}
end

local function weather(ctx: any, clima: string, props: { [string]: any }, duration: number, tick: (number) -> ()): any
	local merged = table.clone(props)
	merged.Clima = clima
	local restore = Ambience.push(merged, duration, 2)
	local stop = loop(ctx, duration, 1, tick)
	return {
		position = ctx.origin.Position,
		radius = 200,
		elements = {},
		stop = function()
			stop()
			restore()
		end,
	}
end

local function sheltered(a: any): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { a.model :: Instance }
	return Workspace:Raycast(a.root.Position + Vector3.new(0, 3, 0), Vector3.new(0, 80, 0), params) ~= nil
end

function Storms.blizzard(ctx: any): any
	local h = weather(ctx, "nevasca", { Brightness = 1.4, AtmosphereDensity = 0.55, AtmosphereColor = Color3.fromRGB(220, 235, 255), AtmosphereHaze = 3 }, 26, function()
		for _, a in Actors.players() do
			if not sheltered(a) then
				Status.apply(a.humanoid, "slow", 1.5)
			end
		end
	end)
	h.elements = { "ice" }
	return h
end

function Storms.acid_rain(ctx: any): any
	local h = weather(ctx, "chuva_acida", { Brightness = 1.2, OutdoorAmbient = Color3.fromRGB(110, 140, 90), AtmosphereColor = Color3.fromRGB(170, 220, 140), AtmosphereDensity = 0.42 }, 20, function()
		for _, a in Actors.near(ctx.origin.Position, 220) do
			if not sheltered(a) then
				Combat.damage(a, 3, nil, nil)
				Status.apply(a.humanoid, "poison", 1.2)
			end
		end
	end)
	h.elements = { "poison" }
	return h
end

function Storms.sandstorm(ctx: any): any
	local dir = ctx.origin.RightVector
	local h = weather(ctx, "areia", { Brightness = 1.6, AtmosphereColor = Color3.fromRGB(230, 190, 120), AtmosphereDecay = Color3.fromRGB(200, 150, 90), AtmosphereDensity = 0.6, AtmosphereHaze = 4 }, 24, function()
		for _, a in Actors.near(ctx.origin.Position, 250) do
			if not sheltered(a) then
				Combat.push(a, dir * 22)
			end
		end
	end)
	h.elements = { "wind" }
	return h
end

function Storms.wind(ctx: any): any
	local dir = ctx.origin.LookVector * -1
	ctx.folder:SetAttribute("FxKind", "wind")
	ctx.folder:SetAttribute("FxVel", dir)
	local stop = loop(ctx, 15, 0.5, function()
		for _, a in Actors.near(ctx.origin.Position, 220) do
			Combat.push(a, dir * 28 + Vector3.new(0, 4, 0))
		end
		Destruction.blast(ctx.origin.Position + dir * 30, 60, 25)
	end)
	return { position = ctx.origin.Position, radius = 200, elements = { "wind" }, stop = stop }
end

function Storms.gravity(ctx: any): any
	local restore = Ambience.push({ Gravity = 38 }, 20, 3)
	Fx.near(nil, nil, "toast", { t = "🪐 Gravidade baixa por 20 segundos!", c = Color3.fromRGB(200, 170, 255) })
	return {
		position = ctx.origin.Position,
		radius = 0,
		elements = {},
		stop = restore,
	}
end

return Storms
