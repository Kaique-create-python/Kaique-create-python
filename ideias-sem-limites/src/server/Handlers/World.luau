--!strict
-- Clima, céu e magia: noite, dia, pôr do sol, eclipse, chuva, neblina,
-- arco-íris, aurora, festa, fogos, lua gigante, estrelas, bênção, maldição,
-- invocação, desejo, tesouro, restaurar o mapa e limpar as próprias ideias.
-- Tudo é temporário (Ambience) e volta sozinho.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Ambience = require(script.Parent.Parent.Core.Ambience)
local Destruction = require(script.Parent.Parent.Core.Destruction)
local Combat = require(script.Parent.Parent.Core.Combat)
local Actors = require(script.Parent.Parent.Core.Actors)
local Status = require(script.Parent.Parent.Core.Status)
local Fx = require(script.Parent.Parent.Core.Fx)
local Kit = require(script.Parent.Parent.Builders.Kit)
local Builders = require(script.Parent.Parent.Builders)
local PropActions = require(script.Parent.Parent.Core.PropActions)

local H = { name = "world" }

function H.estimate(spec: any): { [string]: number }
	local k = spec.params.kind
	if k == "restore" or k == "clear" then
		return {}
	end
	return { events = 1, effects = 3, parts = 40 }
end

local function sky(ctx: any, props: { [string]: any }): () -> ()
	return Ambience.push(props, ctx.lifetime, 1)
end

local function rainbow(ctx: any)
	local b = Kit.new("ArcoIris", ctx.origin * CFrame.new(0, 0, -60), { anchored = true, collide = false })
	for band = 1, 6 do
		local r = 70 - band * 4
		for k = 0, 17 do
			local a = k / 17 * math.pi
			b:box(Vector3.new(4, 4, 12), CFrame.new(math.cos(a) * r, math.sin(a) * r, 0) * CFrame.Angles(0, 0, a + math.pi / 2), Kit.RainbowColors[band], { role = "fixed", material = Enum.Material.Neon, transparency = 0.3, collide = false, shadow = false })
		end
	end
	b:finish().Parent = ctx.folder
end

local function moon(ctx: any)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(160, 160, 160)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Slate
	p.Color = Color3.fromRGB(225, 225, 210)
	p.CFrame = CFrame.new(ctx.origin.Position + ctx.origin.LookVector * -450 + Vector3.new(0, 320, 0))
	p.Name = "Lua"
	p.Parent = ctx.folder
	for k = 1, 6 do
		local c = Instance.new("Part")
		c.Shape = Enum.PartType.Ball
		local s = math.random(18, 36)
		c.Size = Vector3.new(s, s, s)
		c.Anchored = true
		c.CanCollide = false
		c.CanQuery = false
		c.Material = Enum.Material.Slate
		c.Color = Color3.fromRGB(190, 190, 180)
		local dir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
		c.CFrame = CFrame.new(p.Position + dir * 76)
		c.Parent = ctx.folder
	end
end

local function circle(ctx: any, color: Color3): Model
	local b = Kit.new("Circulo", ctx.origin, { anchored = true, collide = false })
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		b:box(Vector3.new(4.2, 0.3, 0.8), CFrame.new(math.cos(a) * 10, 0.2, math.sin(a) * 10) * CFrame.Angles(0, -a + math.pi / 2, 0), color, { role = "fixed", material = Enum.Material.Neon })
	end
	for k = 0, 4 do
		local a1 = k / 5 * math.pi * 2
		local a2 = (k + 2) / 5 * math.pi * 2
		b:beam(Vector3.new(math.cos(a1) * 9, 0.25, math.sin(a1) * 9), Vector3.new(math.cos(a2) * 9, 0.25, math.sin(a2) * 9), 0.5, color, { role = "fixed", material = Enum.Material.Neon })
	end
	local m = b:finish()
	m.Parent = ctx.folder
	return m
end

local function child(ctx: any, text: string)
	local Planner = require(ReplicatedStorage.IdeiasShared.Planner)
	local plan = Planner.plan(text)
	plan.location = nil
	task.defer(function()
		ctx.manager.executePlan(plan, ctx.owner)
	end)
end

local SUMMONS = { "dragao", "fenix", "unicornio", "golem", "anjo", "lobo", "kraken", "mago", "fada", "robo gigante" }

function H.spawn(ctx: any): any
	local k = ctx.params.kind
	local handle: any = { position = ctx.origin.Position, radius = 0, elements = {} }
	local restore: (() -> ())? = nil
	if k == "night" then
		restore = sky(ctx, { ClockTime = 0.2, Brightness = 1.2 })
	elseif k == "day" then
		restore = sky(ctx, { ClockTime = 13, Brightness = 2.8 })
	elseif k == "sunset" then
		restore = sky(ctx, { ClockTime = 18.1, AtmosphereColor = Color3.fromRGB(255, 190, 150), AtmosphereDecay = Color3.fromRGB(190, 90, 70) })
	elseif k == "eclipse" then
		restore = sky(ctx, { ClockTime = 12.5, Brightness = 0.25, OutdoorAmbient = Color3.fromRGB(90, 40, 40), AtmosphereColor = Color3.fromRGB(140, 60, 50), AtmosphereDensity = 0.45 })
	elseif k == "rain" then
		restore = sky(ctx, { Brightness = 1.4, OutdoorAmbient = Color3.fromRGB(90, 95, 110), AtmosphereDensity = 0.42, Clima = "chuva" })
		handle.elements = { "water" }
		handle.radius = 300
		task.spawn(function()
			while ctx.folder.Parent do
				for _, a in Actors.players() do
					Status.apply(a.humanoid, "wet", 3)
				end
				task.wait(2)
			end
		end)
	elseif k == "fog" then
		restore = sky(ctx, { AtmosphereDensity = 0.7, AtmosphereHaze = 6, Brightness = 1.6 })
	elseif k == "rainbow" then
		rainbow(ctx)
		restore = sky(ctx, { Clima = "arco_iris" })
	elseif k == "aurora" then
		restore = sky(ctx, { ClockTime = 23, Brightness = 1, Clima = "aurora" })
	elseif k == "party" then
		restore = sky(ctx, { ClockTime = 21, Brightness = 1.1, Clima = "festa" })
		task.spawn(function()
			while ctx.folder.Parent do
				for _, a in Actors.near(ctx.origin.Position, 120) do
					if a.kind == "npc" and a.faction ~= "hostile" then
						a.behavior = "dance"
					end
				end
				task.wait(2)
			end
		end)
	elseif k == "fireworks" then
		task.spawn(function()
			for _ = 1, 10 do
				if not ctx.folder.Parent then
					break
				end
				Fx.near(ctx.origin.Position, 1500, "fireworks", { p = ctx.origin.Position + Vector3.new(math.random(-60, 60), 0, math.random(-60, 60)), n = 4 })
				task.wait(1.6)
			end
		end)
	elseif k == "moon" then
		moon(ctx)
		restore = sky(ctx, { ClockTime = 22.5, Brightness = 1.3, Gravity = 110 })
	elseif k == "stars" then
		restore = sky(ctx, { ClockTime = 0, Brightness = 1, Clima = "estrelas" })
	elseif k == "restore" then
		Destruction.restoreAll()
		Fx.near(nil, nil, "toast", { t = "🔧 Mapa restaurado!", c = Color3.fromRGB(150, 255, 190) })
		handle.done = function()
			return true
		end
	elseif k == "clear" then
		local n = 0
		if ctx.owner then
			for _, rec in table.clone(ctx.manager.active()) do
				if rec.owner == ctx.owner and rec.id ~= ctx.id then
					ctx.manager.remove(rec, "clear")
					n += 1
				end
			end
			Fx.to(ctx.owner, "toast", { t = "🧹 " .. n .. " ideia(s) removida(s)", c = Color3.fromRGB(200, 230, 255) })
		end
		handle.done = function()
			return true
		end
	elseif k == "magic" then
		local options = { "arco iris", "fogos", "bencao", "invocacao", "estrelas", "chuva de presentes" }
		child(ctx, options[ctx.rng:int(1, #options)])
		handle.done = function()
			return true
		end
	elseif k == "blessing" then
		Fx.near(nil, nil, "tint", { c = Color3.fromRGB(255, 240, 180), d = 2 })
		for _, a in Actors.players() do
			Combat.heal(a, 1000)
			Status.apply(a.humanoid, "shield", 6)
		end
		Fx.shockwave(ctx.origin.Position, 60, Color3.fromRGB(255, 230, 140))
		restore = sky(ctx, { Brightness = 3.2, AtmosphereColor = Color3.fromRGB(255, 240, 200) })
	elseif k == "curse" then
		restore = sky(ctx, { ClockTime = 0.5, Brightness = 0.7, OutdoorAmbient = Color3.fromRGB(70, 40, 90), AtmosphereColor = Color3.fromRGB(110, 60, 140) })
		for _, a in Actors.near(ctx.origin.Position, 400) do
			if a.kind == "npc" and a.faction == "hostile" then
				a.speed *= 1.3
				a.dmg *= 1.3
			end
		end
		child(ctx, "3 fantasmas")
	elseif k == "summon" then
		local m = circle(ctx, Color3.fromRGB(190, 110, 255))
		Fx.shockwave(ctx.origin.Position, 14, Color3.fromRGB(190, 110, 255))
		task.delay(2, function()
			if ctx.folder.Parent then
				child(ctx, SUMMONS[ctx.rng:int(1, #SUMMONS)] .. " aliado")
			end
		end)
		handle.model = m
	elseif k == "wish" then
		Fx.near(ctx.origin.Position, 800, "fireworks", { p = ctx.origin.Position, n = 6 })
		local pp = { scale = 1, rng = ctx.rng }
		local ok, r = pcall(Builders.Props.build, ctx.origin, pp, "prop", "chest")
		if ok and r then
			r.model.Parent = ctx.folder
			PropActions.attach(r.model, r.main, "treasure", pp, ctx)
		end
		if ctx.owner then
			local Power = require(script.Parent.Power)
			Power.apply(ctx.owner, ({ "shield", "speed", "jump", "aura" })[ctx.rng:int(1, 4)], ctx)
		end
	elseif k == "treasure" then
		child(ctx, "chuva de moedas")
		local pp = { scale = 1.2, rng = ctx.rng }
		local ok, r = pcall(Builders.Props.build, ctx.origin, pp, "prop", "chest")
		if ok and r then
			r.model.Parent = ctx.folder
			PropActions.attach(r.model, r.main, "treasure", pp, ctx)
		end
	end
	if restore then
		handle.stop = restore
	end
	Workspace:SetAttribute("UltimoClima", k)
	return handle
end

return H
