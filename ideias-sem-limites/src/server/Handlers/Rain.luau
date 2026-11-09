--!strict
-- "Chuva de X": qualquer coisa física cai do céu (pizzas, gatos, carros...).
-- Os itens são modelos reais com física, limitados por um teto de itens vivos
-- e removidos automaticamente depois de alguns segundos.

local Debris = game:GetService("Debris")
local Builders = require(script.Parent.Parent.Builders)
local Fx = require(script.Parent.Parent.Core.Fx)
local Actors = require(script.Parent.Parent.Core.Actors)
local PropActions = require(script.Parent.Parent.Core.PropActions)

local H = { name = "rain" }

function H.estimate(spec: any): { [string]: number }
	return { events = 1, dynamic = if spec.heavy then 70 else 45, effects = 2, parts = 300 }
end

function H.spawn(ctx: any): any
	local def = ctx.def
	local params = table.clone(ctx.params)
	local heavy = ctx.spec.heavy
	local maxAlive = if heavy then 16 else 11
	local rate = if heavy then 0.18 else 0.3
	local itemScale = 0.55
	if def.handler == "building" or def.handler == "vehicle" then
		itemScale = 0.18
		maxAlive = 6
		rate = 0.6
	elseif def.handler == "npc" then
		itemScale = 0.75
		maxAlive = 8
	end
	local alive = 0
	local running = true
	local center = ctx.origin.Position
	local duration = math.min(ctx.lifetime - 4, if heavy then 24 else 18)
	ctx.folder:SetAttribute("FxKind", "rain_items")
	Fx.near(center, 500, "toast", { t = "☁️ " .. ctx.spec.label .. "!", c = Color3.fromRGB(200, 230, 255) })

	task.spawn(function()
		local t0 = os.clock()
		while running and ctx.folder.Parent and os.clock() - t0 < duration do
			if alive < maxAlive then
				-- cai perto dos jogadores próximos (ou do centro)
				local near = Actors.players()
				local base = center
				if #near > 0 and math.random() < 0.6 then
					local a = near[math.random(1, #near)]
					if (a.root.Position - center).Magnitude < 150 then
						base = a.root.Position
					end
				end
				local pos = base + Vector3.new(math.random(-40, 40), 70 + math.random() * 30, math.random(-40, 40))
				local p2 = table.clone(params)
				p2.scale = (params.scale or 1) * itemScale
				p2.rng = ctx.rng:fork(math.floor(os.clock() * 100))
				p2.physics = true
				p2.anchored = false
				local cf = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
				local ok, model = pcall(Builders.any, def, cf, p2)
				if ok and model then
					local m = model :: Model
					for _, d in m:GetDescendants() do
						if d:IsA("BasePart") then
							d.Anchored = false
							d.CanCollide = true
						elseif d:IsA("Humanoid") then
							d.PlatformStand = true
							d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
						end
					end
					local main = m.PrimaryPart
					if main then
						for _, d in m:GetDescendants() do
							if d:IsA("BasePart") and d ~= main and not d:FindFirstChildWhichIsA("WeldConstraint") then
								local hasJoint = false
								for _, j in d:GetJoints() do
									hasJoint = true
									break
								end
								if not hasJoint then
									local w = Instance.new("WeldConstraint")
									w.Part0 = main
									w.Part1 = d
									w.Parent = d
								end
							end
						end
						main.AssemblyLinearVelocity = Vector3.new(0, -40, 0)
					end
					m.Name = def.label
					m.Parent = ctx.folder
					if main then
						pcall(function()
							main:SetNetworkOwner(nil)
						end)
					end
					if params.edible and main then
						PropActions.attach(m, main, nil, { edible = true }, ctx)
					end
					alive += 1
					task.delay(7, function()
						alive -= 1
						if m.Parent then
							m:Destroy()
						end
					end)
				end
			end
			task.wait(rate)
		end
	end)

	return {
		position = center,
		radius = 50,
		elements = { params.element },
		stop = function()
			running = false
		end,
	}
end

H._debris = Debris

return H
