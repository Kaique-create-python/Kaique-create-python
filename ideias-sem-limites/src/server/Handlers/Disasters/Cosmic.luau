--!strict
-- Buraco negro e "fim do mundo" (vários desastres de uma vez).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local FxPaths = require(ReplicatedStorage.IdeiasShared.FxPaths)
local Combat = require(script.Parent.Parent.Parent.Core.Combat)
local Actors = require(script.Parent.Parent.Parent.Core.Actors)
local Fx = require(script.Parent.Parent.Parent.Core.Fx)
local Destruction = require(script.Parent.Parent.Parent.Core.Destruction)
local Placement = require(script.Parent.Parent.Parent.Core.Placement)

local Cosmic = {}

function Cosmic.black_hole(ctx: any): any
	local p = ctx.params
	local scale = math.min(p.scale or 1, 4)
	local center = ctx.origin.Position + Vector3.new(0, 34 * scale, 0)
	local dur = 26
	local spec = { pos = center, vel = Vector3.zero, t0 = Workspace:GetServerTimeNow() + 1.5, dur = dur, radius = 13 * scale, height = 0, seed = 0, power = scale }
	-- aviso: o céu escurece e o chão treme antes de abrir
	Fx.near(nil, nil, "toast", { t = "🕳️ Um buraco negro está se abrindo!", c = Color3.fromRGB(200, 160, 255) })
	Fx.near(center, 1500, "bh_warn", { p = center, d = 1.5 })
	Fx.shake(center, 1.2, 600)
	FxPaths.write(ctx.folder, "black_hole", spec, p.element)
	if p.payload then
		ctx.folder:SetAttribute("FxPayload", p.payload)
	end
	local reach = 150 * scale
	local running = true
	local TerrainScars = require(script.Parent.Parent.Parent.Core.TerrainScars)
	task.spawn(function()
		task.wait(1.5)
		local t0 = os.clock()
		-- pedaços do chão arrancados e sugados (até 40 blocos por vez)
		local debrisN = 0
		while running and ctx.folder.Parent and os.clock() - t0 < dur do
			local grow = math.min(1, (os.clock() - t0) / 4)
			if debrisN < 40 and grow > 0.3 then
				local a = ctx.rng:range(0, math.pi * 2)
				local r = ctx.rng:range(20, reach * 0.6)
				local gp = Placement.ground(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
				local chunk = Instance.new("Part")
				chunk.Size = Vector3.new(ctx.rng:range(3, 7), ctx.rng:range(2, 4), ctx.rng:range(3, 7))
				chunk.Color = Color3.fromRGB(95, 110, 70)
				chunk.Material = Enum.Material.Grass
				chunk.CFrame = CFrame.new(gp + Vector3.new(0, 1, 0)) * CFrame.Angles(ctx.rng:range(-0.3, 0.3), a, 0)
				chunk.CanCollide = false
				chunk.CanQuery = false
				chunk:SetAttribute("Sugado", true)
				chunk.Parent = ctx.folder
				chunk.AssemblyLinearVelocity = Vector3.new(0, 25, 0)
				debrisN += 1
				task.delay(6, function()
					if chunk.Parent then
						chunk:Destroy()
					end
				end)
			end
			for _, chunk in ctx.folder:GetChildren() do
				if chunk:IsA("BasePart") and chunk:GetAttribute("Sugado") then
					local to = center - chunk.Position
					if to.Magnitude < spec.radius * 0.9 then
						chunk:Destroy()
					else
						chunk.AssemblyLinearVelocity = to.Unit * 45 + Vector3.new(0, 8, 0)
					end
				end
			end
			for _, a in Actors.near(center, reach) do
				local to = center - a.root.Position
				local d = to.Magnitude
				if d < spec.radius * 0.8 then
					if a.kind == "npc" then
						a.humanoid.Health = 0
					else
						-- jogadores são "cuspidos" longe em vez de morrer em loop
						Combat.damage(a, 25, nil, nil)
						local out = Placement.ground(center + Vector3.new(math.random(-150, 150), 0, math.random(-150, 150)))
						a.root.CFrame = CFrame.new(out + Vector3.new(0, 6, 0))
						Fx.to(a.player, "toast", { t = "O buraco negro te cuspiu longe!", c = Color3.fromRGB(190, 150, 255) })
					end
				elseif d > 0.1 then
					local pull = (1 - d / reach) * 70 * grow * math.sqrt(scale)
					Combat.push(a, to.Unit * pull + Vector3.new(0, 4, 0))
				end
			end
			Destruction.blast(center, reach * 0.6, 60 * grow, true)
			task.wait(0.2)
		end
		if ctx.folder.Parent then
			-- colapso: clarão, onda, cratera e tremor
			Fx.near(center, 2000, "bh_collapse", { p = center, s = scale })
			Fx.flash(center, Color3.fromRGB(200, 160, 255), 90 * scale)
			Fx.shockwave(center, reach * 0.6, Color3.fromRGB(170, 120, 255))
			Fx.shake(center, 2.5, 800)
			TerrainScars.crater(Placement.ground(center), 22 * scale, nil, 60)
			Destruction.blast(Placement.ground(center), 60 * scale, 200, true)
			for _, a in Actors.near(center, reach * 0.6) do
				local away = a.root.Position - center
				Combat.push(a, (if away.Magnitude > 0.1 then away.Unit else Vector3.yAxis) * 90 + Vector3.new(0, 30, 0))
			end
		end
	end)
	return {
		position = center,
		radius = spec.radius,
		elements = { "shadow" },
		stop = function()
			running = false
		end,
		absorbs = true,
	}
end

local CHAOS_POOL = { "chuva de meteoros", "tornado de fogo", "raio", "terremoto", "tsunami", "chuva acida", "tempestade de lasers", "erupcao" }

function Cosmic.chaos(ctx: any): any
	local Planner = require(ReplicatedStorage.IdeiasShared.Planner)
	Fx.near(nil, nil, "toast", { t = "☄️ O FIM DO MUNDO COMEÇOU!", c = Color3.fromRGB(255, 90, 90) })
	Fx.near(nil, nil, "tint", { c = Color3.fromRGB(255, 120, 100), d = 3 })
	local picks = {}
	local pool = table.clone(CHAOS_POOL)
	ctx.rng:shuffle(pool)
	for i = 1, 3 do
		table.insert(picks, pool[i])
	end
	task.spawn(function()
		for _, word in picks do
			if not ctx.folder.Parent then
				break
			end
			local plan = Planner.plan(word)
			plan.location = nil
			ctx.manager.executePlan(plan, ctx.owner)
			task.wait(3)
		end
	end)
	return { position = ctx.origin.Position, radius = 0, elements = {}, done = function()
		return true
	end }
end

return Cosmic
