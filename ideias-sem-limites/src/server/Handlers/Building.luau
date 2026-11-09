--!strict
-- Executor de construções. Algumas têm interação: portal teleporta, jaula
-- prende inimigos próximos, labirinto tem prêmio, estátua copia o jogador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builders = require(script.Parent.Parent.Builders)
local Fx = require(script.Parent.Parent.Core.Fx)
local Actors = require(script.Parent.Parent.Core.Actors)
local PropActions = require(script.Parent.Parent.Core.PropActions)
local Brain = require(script.Parent.Parent.Brains.Brain)
local MapLayout = require(ReplicatedStorage.IdeiasShared.MapLayout)
local Placement = require(script.Parent.Parent.Core.Placement)

local H = { name = "building" }

function H.estimate(spec: any): { [string]: number }
	local v = spec.params.variant
	local parts = if v == "city" or v == "maze" or v == "castle" then 600 else 260
	return { events = 1, parts = parts * spec.count, effects = 2 }
end

-- estátua do próprio jogador (cópia do avatar em mármore/ouro)
local function playerStatue(player: Player, origin: CFrame, folder: Instance, params: { [string]: any }): Model?
	local char = player.Character
	if not char then
		return nil
	end
	local old = char.Archivable
	char.Archivable = true
	local ok, copy = pcall(function()
		return char:Clone()
	end)
	char.Archivable = old
	if not ok or not copy then
		return nil
	end
	local statue = copy :: Model
	statue.Name = "Estátua de " .. player.DisplayName
	local mat = if params.material == "gold" then Enum.Material.Foil else Enum.Material.Marble
	local col = if params.material == "gold" then Color3.fromRGB(255, 200, 50) else Color3.fromRGB(235, 235, 230)
	for _, d in statue:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.Material = mat
			d.Color = col
			d.CanCollide = true
		elseif d:IsA("Decal") then
			d.Transparency = 0.6
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			d.PlatformStand = true
		end
	end
	local s = math.clamp(params.scale or 1, 1, 4) * 2.5
	pcall(function()
		statue:ScaleTo(s)
	end)
	local _, size = statue:GetBoundingBox()
	statue:PivotTo(origin * CFrame.new(0, 4 + size.Y / 2, 0))
	statue.Parent = folder
	return statue
end

function H.spawn(ctx: any): any
	local params = table.clone(ctx.params)
	params.rng = ctx.rng
	local results = {}
	for i = 1, ctx.count do
		local origin = ctx.origin
		if i > 1 then
			origin = ctx.origin * CFrame.new((i - 1) * 60 * (params.scale or 1), 0, 0)
		end
		local r = Builders.building(origin, params)
		r.model.Name = ctx.def.label
		r.model.Parent = ctx.folder
		table.insert(results, r)
		if params.elementMod and r.model.PrimaryPart then
			PropActions.elementize(r.model.PrimaryPart, params)
		end
	end
	local main = results[1]
	local variant = params.variant

	if variant == "statue" and ctx.owner then
		local st = playerStatue(ctx.owner, ctx.origin, ctx.folder, params)
		if st then
			-- a estátua genérica vira só o pedestal
			for _, d in main.model:GetDescendants() do
				if d:IsA("BasePart") and d.Position.Y > ctx.origin.Position.Y + 4 then
					d:Destroy()
				end
			end
		end
	elseif variant == "portal" then
		local disc = main.model:FindFirstChild("Vortice", true) :: BasePart?
		if disc then
			local p = Instance.new("ProximityPrompt")
			p.ActionText = "Atravessar"
			p.ObjectText = "Portal"
			p.MaxActivationDistance = 18
			p.RequiresLineOfSight = false
			p.Parent = disc
			p.Triggered:Connect(function(player)
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local regions = MapLayout.Regions
					local target = regions[math.random(1, #regions)]
					local cf = Placement.region(target.id, ctx.rng)
					root.CFrame = cf + Vector3.new(0, 5, 0)
					Fx.to(player, "toast", { t = "Portal → " .. target.label, c = Color3.fromRGB(190, 120, 255) })
				end
			end)
		end
	elseif variant == "cage" then
		-- prende até 3 inimigos próximos dentro da jaula
		local caught = 0
		for _, a in Actors.near(main.center, 70) do
			if a.kind == "npc" and a.faction == "hostile" and caught < 3 then
				caught += 1
				a.root.CFrame = CFrame.new(main.center + Vector3.new(caught * 3 - 6, 4, 0))
				a.riding = true
				a.humanoid.WalkSpeed = 0
				task.delay(ctx.lifetime - 1, function()
					a.riding = false
				end)
			end
		end
		if caught > 0 then
			Fx.near(main.center, 300, "toast", { t = caught .. " inimigo(s) preso(s)!", c = Color3.fromRGB(255, 220, 120) })
		end
	elseif variant == "maze" then
		local prize = main.model:FindFirstChild("Premio", true) :: BasePart?
		if prize then
			local p = Instance.new("ProximityPrompt")
			p.ActionText = "Pegar prêmio"
			p.ObjectText = "Centro do labirinto"
			p.RequiresLineOfSight = false
			p.Parent = prize
			p.Triggered:Connect(function(player)
				p.Enabled = false
				prize.Transparency = 1
				Fx.near(prize.Position, 300, "confetti", { p = prize.Position, gold = true })
				if PropActions.rewardHook then
					PropActions.rewardHook(player, "maze", 25)
				end
			end)
		end
	end

	Fx.near(ctx.origin.Position, 400, "build", { p = ctx.origin.Position, r = main.radius })
	Fx.shake(ctx.origin.Position, 0.25, 120)
	local _brain = Brain
	return {
		model = main.model,
		anchor = main.model.PrimaryPart,
		position = main.center,
		radius = main.radius,
		elements = { params.element },
		tags = ctx.def.tagSet,
	}
end

return H
