--!strict
-- Poderes aplicados a quem pediu: cura, velocidade, pulo, voo, crescer,
-- encolher, invisibilidade, escudo, teletransporte, clones, parar o tempo...

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapLayout = require(ReplicatedStorage.IdeiasShared.MapLayout)

local Status = require(script.Parent.Parent.Core.Status)
local Combat = require(script.Parent.Parent.Core.Combat)
local Actors = require(script.Parent.Parent.Core.Actors)
local Fx = require(script.Parent.Parent.Core.Fx)
local Placement = require(script.Parent.Parent.Core.Placement)
local Kit = require(script.Parent.Parent.Builders.Kit)
local Brain = require(script.Parent.Parent.Brains.Brain)

local H = { name = "power" }

local SCALE_VALUES = { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }

local function humanoidOf(player: Player): (Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil
	end
	return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function resize(player: Player, factor: number, duration: number)
	local h = humanoidOf(player)
	if not h or h.RigType ~= Enum.HumanoidRigType.R15 then
		Fx.to(player, "toast", { t = "Seu avatar não suporta mudar de tamanho (precisa ser R15)", c = Color3.fromRGB(255, 200, 120) })
		return
	end
	local originals = {}
	for _, name in SCALE_VALUES do
		local v = h:FindFirstChild(name) :: NumberValue?
		if v then
			originals[name] = v.Value
			v.Value = v.Value * factor
		end
	end
	local base = h:GetAttribute("BaseWalkSpeed") or h.WalkSpeed
	h:SetAttribute("BaseWalkSpeed", base * (if factor > 1 then 1.25 else 0.8))
	Status.apply(h, "haste", 0.01) -- força recálculo da velocidade
	task.delay(duration, function()
		if h.Parent then
			for name, value in originals do
				local v = h:FindFirstChild(name) :: NumberValue?
				if v then
					v.Value = value
				end
			end
			h:SetAttribute("BaseWalkSpeed", base)
			Status.apply(h, "haste", 0.01)
		end
	end)
end

local function invisible(player: Player, duration: number)
	local char = player.Character
	if not char then
		return
	end
	local saved = {}
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			saved[d] = d.Transparency
			d.Transparency = 0.92
		elseif d:IsA("Decal") then
			saved[d] = d.Transparency
			d.Transparency = 1
		end
	end
	char:SetAttribute("Invisivel", true)
	task.delay(duration, function()
		for inst, t in saved do
			if inst.Parent then
				(inst :: any).Transparency = t
			end
		end
		if char.Parent then
			char:SetAttribute("Invisivel", nil)
		end
	end)
end

local function aura(root: BasePart, element: string?, duration: number)
	local fx = Kit.elementEffects(root, element or "light", 1.6)
	task.delay(duration, function()
		for _, i in fx do
			i:Destroy()
		end
	end)
end

local function cape(player: Player, duration: number)
	local char = player.Character
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return
	end
	local c = Instance.new("Part")
	c.Name = "CapaIdeias"
	c.Size = Vector3.new(2, 3.4, 0.15)
	c.Color = Color3.fromRGB(200, 25, 35)
	c.Material = Enum.Material.Fabric
	c.CanCollide = false
	c.Massless = true
	c.CFrame = torso.CFrame * CFrame.new(0, -1.1, torso.Size.Z / 2 + 0.15) * CFrame.Angles(math.rad(8), 0, 0)
	local w = Instance.new("WeldConstraint")
	w.Part0 = torso
	w.Part1 = c
	w.Parent = c
	c.Parent = char
	task.delay(duration, function()
		c:Destroy()
	end)
end

-- aplica um poder diretamente (também usado por presentes e poções)
function H.apply(player: Player, kind: string, ctx: any?)
	local h, root = humanoidOf(player)
	if not h or not root then
		return
	end
	local actor = Actors.playerActor(player)
	local dur = 20
	if kind == "heal" then
		h.Health = h.MaxHealth
		for _, k in { "burn", "poison", "freeze", "shock", "slow" } do
			Status.clear(h, k)
		end
		Fx.shockwave(root.Position, 10, Color3.fromRGB(120, 255, 160))
	elseif kind == "speed" then
		Status.apply(h, "haste", dur)
	elseif kind == "jump" then
		Status.apply(h, "superjump", dur)
	elseif kind == "fly" then
		Fx.to(player, "fly", { d = dur })
		aura(root, "wind", dur)
	elseif kind == "giant" then
		resize(player, 2.2, dur)
	elseif kind == "tiny" then
		resize(player, 0.45, dur)
	elseif kind == "invisible" then
		invisible(player, 15)
	elseif kind == "shield" then
		Status.apply(h, "shield", 12)
	elseif kind == "teleport" then
		local regionId = ctx and ctx.params.region
		if not regionId then
			local regions = MapLayout.Regions
			regionId = regions[math.random(1, #regions)].id
		end
		local rng = ctx and ctx.rng or require(ReplicatedStorage.IdeiasShared.Util.Rng).new(os.time())
		local cf = Placement.region(regionId, rng)
		Fx.near(root.Position, 300, "poof", { p = root.Position, s = 1 })
		root.CFrame = cf + Vector3.new(0, 5, 0)
		Fx.to(player, "toast", { t = "Teletransporte: " .. (MapLayout.ById[regionId] and MapLayout.ById[regionId].label or regionId), c = Color3.fromRGB(190, 140, 255) })
	elseif kind == "time_stop" then
		Brain.freezeUntil = os.clock() + 6
		Fx.near(nil, nil, "tint", { c = Color3.fromRGB(150, 150, 160), d = 6, gray = true })
	elseif kind == "slowmo" then
		Brain.slowUntil = os.clock() + 10
		Fx.near(nil, nil, "tint", { c = Color3.fromRGB(120, 170, 255), d = 10 })
	elseif kind == "aura" then
		aura(root, ctx and ctx.params.element, 30)
		Status.apply(h, "haste", 8)
	elseif kind == "cape" then
		cape(player, 60)
		Status.apply(h, "haste", 12)
	elseif kind == "potion" then
		local options = { "heal", "speed", "jump", "giant", "tiny", "invisible", "shield", "fly" }
		local pick = options[math.random(1, #options)]
		Fx.to(player, "toast", { t = "A poção fez efeito: " .. pick, c = Color3.fromRGB(200, 120, 255) })
		H.apply(player, pick, ctx)
		return
	end
	Fx.near(root.Position, 200, "power", { p = root.Position, kind = kind })
	local _ = actor
	local _c = Combat
end

local function spawnClones(ctx: any)
	local player: Player = ctx.owner
	local char = player.Character
	if not char then
		return {}
	end
	local Npc = require(script.Parent.Npc)
	local _ = Npc
	local npcs = {}
	local old = char.Archivable
	char.Archivable = true
	for i = 1, 3 do
		local ok, clone = pcall(function()
			return char:Clone()
		end)
		if ok and clone then
			local model = clone :: Model
			for _, d in model:GetDescendants() do
				if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Tool") then
					d:Destroy()
				elseif d:IsA("BasePart") then
					d.Transparency = math.max(d.Transparency, if d.Name == "HumanoidRootPart" then 1 else 0.25)
				end
			end
			model.Name = "Clone de " .. player.DisplayName
			local h = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if h and root then
				model:PivotTo(char:GetPivot() * CFrame.new((i - 2) * 5, 0, 5))
				model.Parent = ctx.folder
				h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				h.MaxHealth = 150
				h.Health = 150
				pcall(function()
					root:SetNetworkOwner(nil)
				end)
				local npc: any = {
					kind = "npc",
					eventId = ctx.id,
					model = model,
					root = root,
					humanoid = h,
					faction = "pet",
					owner = player,
					params = {},
					def = ctx.def,
					speed = 18,
					dmg = 12,
					scale = 1,
					attacks = { "melee" },
					reach = 5,
					hipHeight = h.HipHeight,
					height = 5,
					radius = 2,
					enemies = {},
				}
				Actors.register(npc)
				Brain.add(npc)
				h.Died:Connect(function()
					npc.dead = true
					Brain.remove(npc)
					Actors.unregister(npc)
				end)
				table.insert(npcs, npc)
			end
		end
	end
	char.Archivable = old
	return npcs
end

function H.estimate(spec: any): { [string]: number }
	if spec.params.kind == "clone" then
		return { events = 1, npcs = 3, effects = 2 }
	end
	return { events = 1, effects = 2 }
end

function H.spawn(ctx: any): any
	local player: Player? = ctx.owner
	if not player then
		return { position = ctx.origin.Position, done = function()
			return true
		end }
	end
	local kind = ctx.params.kind
	if kind == "clone" then
		local npcs = spawnClones(ctx)
		return {
			npcs = npcs,
			position = ctx.origin.Position,
			stop = function()
				for _, n in npcs do
					Brain.remove(n)
					Actors.unregister(n)
				end
			end,
		}
	elseif kind == "pet" then
		local Planner = require(ReplicatedStorage.IdeiasShared.Planner)
		local pets = { "cachorro", "gato", "coelho", "raposa", "pinguim", "capivara", "panda", "dragao pequeno" }
		local plan = Planner.plan(pets[math.random(1, #pets)] .. " de estimacao")
		task.defer(function()
			ctx.manager.executePlan(plan, player)
		end)
		return { position = ctx.origin.Position, done = function()
			return true
		end }
	end
	H.apply(player, kind, ctx)
	return { position = ctx.origin.Position, elements = { ctx.params.element } }
end

H._players = Players

return H
