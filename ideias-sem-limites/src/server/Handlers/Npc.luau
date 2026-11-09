--!strict
-- Executor de criaturas e personagens: constrói o rig, aplica atributos de
-- combate escalados pelo tamanho, registra no Brain e cuida da morte/limpeza.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builders = require(script.Parent.Parent.Builders)
local Kit = Builders.Kit
local Actors = require(script.Parent.Parent.Core.Actors)
local Budget = require(script.Parent.Parent.Core.Budget)
local Fx = require(script.Parent.Parent.Core.Fx)
local PropActions = require(script.Parent.Parent.Core.PropActions)
local Brain = require(script.Parent.Parent.Brains.Brain)
local Config = require(ReplicatedStorage.IdeiasShared.Config)

local H = { name = "npc" }

function H.estimate(spec: any): { [string]: number }
	local s = spec.params.scale or 1
	local per = math.ceil(35 * math.clamp(s, 1, 3))
	return { events = 1, npcs = spec.count, effects = spec.count * 2, parts = per * spec.count }
end

local function healthBar(model: Model, root: BasePart, height: number, label: string, boss: boolean, hostile: boolean)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Barra"
	gui.Size = UDim2.fromOffset(if boss then 160 else 110, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height * 0.55 + 2, 0)
	gui.MaxDistance = if boss then 160 else 80
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.BackgroundTransparency = 1
	name.Text = label
	name.TextScaled = true
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = if hostile then Color3.fromRGB(255, 120, 110) else Color3.fromRGB(150, 255, 170)
	name.TextStrokeTransparency = 0.4
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0.3, 0)
	back.Position = UDim2.new(0, 0, 0.65, 0)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Vida"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = if hostile then Color3.fromRGB(240, 70, 60) else Color3.fromRGB(80, 220, 120)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local c2 = corner:Clone()
	c2.Parent = fill
	gui.Parent = root
	return fill
end

local function breathEmitter(mouth: Attachment?, element: string?, scale: number): ParticleEmitter?
	if not mouth then
		return nil
	end
	local e = Kit.Elements[element or "fire"] or Kit.Elements.fire
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sopro"
	emitter.Enabled = false
	emitter.Texture = if element == "ice" or element == "electric" or element == "light" then Config.Textures.Sparkle else Config.Textures.Fire
	emitter.Rate = 70
	emitter.Lifetime = NumberRange.new(0.5, 0.8)
	emitter.Speed = NumberRange.new(30 * math.sqrt(scale), 45 * math.sqrt(scale))
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 * scale), NumberSequenceKeypoint.new(1, 5 * scale) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Color = ColorSequence.new(e.color2, e.color)
	emitter.LightEmission = 0.8
	emitter.Parent = mouth
	return emitter
end

function H.spawn(ctx: any): any
	local def, params = ctx.def, ctx.params
	local npcs = {}
	local scale = params.scale or 1
	local size = (params.size or 1) * scale
	local faction = params.faction or "neutral"
	local hostile = faction == "hostile"
	local boss = params.boss == true
	local flying = params.fly == true or params.flying == true
	local count = ctx.count
	local deadCount = 0
	local released = 0

	local function release(n: number)
		-- devolve vagas de NPC ao orçamento quando morrem
		released += n
		ctx.record.cost.npcs = math.max(0, (ctx.record.cost.npcs or 0) - n)
		Budget.adjust("npcs", -n)
	end

	for i = 1, count do
		local ring = if count == 1 then 0 else 5 + size * 3
		local ang = (i / count) * math.pi * 2
		local offset = Vector3.new(math.cos(ang) * ring, 0, math.sin(ang) * ring)
		local origin = ctx.origin * CFrame.new(offset)
		if flying then
			origin += Vector3.new(0, 8 + 4 * size, 0)
		end
		local p2 = table.clone(params)
		p2.rng = ctx.rng:fork(i)
		local rig = Builders.creature(origin, p2)
		local model: Model = rig.model
		model.Name = def.label
		model:SetAttribute("Criatura", def.id)
		model:SetAttribute("Faccao", faction)
		model:SetAttribute("Voa", flying)
		model:AddTag("IdeiasNpc")
		local hp = math.floor((params.hp or 100) * (params.hpMul or 1) * math.max(1, size ^ 1.3))
		rig.humanoid.MaxHealth = hp
		rig.humanoid.Health = hp
		local speed = (params.speed or 16) * (params.speedMul or 1) * (if size > 1 then math.sqrt(size) else 1)
		rig.humanoid.WalkSpeed = speed
		model.Parent = ctx.folder
		pcall(function()
			rig.root:SetNetworkOwner(nil)
		end)
		if params.elementMod then
			Kit.elementEffects(rig.root, params.element, math.min(size, 2.5))
		end
		local attacks = params.attacks or { "melee" }
		local emitter = nil
		if table.find(attacks, "breath") then
			emitter = breathEmitter(rig.mouth, params.element, size)
		end
		local label = model.Name
		if boss then
			label = "👑 " .. label
		end
		local bar = healthBar(model, rig.root, rig.height, label, boss, hostile)
		local npc: any = {
			kind = "npc",
			eventId = ctx.id,
			model = model,
			root = rig.root,
			humanoid = rig.humanoid,
			faction = faction,
			owner = if faction == "pet" or faction == "ally" then ctx.owner else nil,
			params = params,
			def = def,
			flying = flying,
			speed = speed,
			dmg = (params.dmg or 8) * math.max(1, size ^ 0.8) * (if boss then 1.5 else 1),
			scale = size,
			attacks = attacks,
			element = params.element,
			mouth = rig.mouth,
			breathEmitter = emitter,
			hipHeight = rig.hipHeight,
			height = rig.height,
			radius = rig.radius,
			reach = rig.radius + 3 * math.max(1, size * 0.6),
			behavior = params.behavior,
			hover = if flying then 8 + 5 * size else nil,
			enemies = {},
		}
		if params.giftKind or table.find(attacks, "gift") then
			npc.spawnGift = function(_npc: any, near: Vector3)
				local kind = params.giftKind or "gift"
				local variant, model2 = "gift", "prop"
				if kind == "food" then
					variant, model2 = ctx.rng:pick({ "pizza", "cake", "burger", "donut", "brigadeiro", "coxinha" }), "food"
				elseif kind == "ball" then
					variant = "ball"
				end
				local pos = near + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
				local pp = { scale = 0.6, rng = ctx.rng, edible = kind == "food", physics = kind == "ball" }
				local ok, r = pcall(Builders.Props.build, CFrame.new(pos), pp, model2, variant)
				if ok and r then
					r.model.Parent = ctx.folder
					PropActions.attach(r.model, r.main, if kind == "gift" then "gift" else nil, pp, ctx)
					Debris:AddItem(r.model, 30)
				end
			end
		end
		Actors.register(npc)
		Brain.add(npc)
		table.insert(npcs, npc)

		rig.humanoid.HealthChanged:Connect(function(h)
			bar.Size = UDim2.fromScale(math.clamp(h / math.max(rig.humanoid.MaxHealth, 1), 0, 1), 1)
		end)
		rig.humanoid.Died:Connect(function()
			if npc.dead then
				return
			end
			npc.dead = true
			deadCount += 1
			Brain.remove(npc)
			Actors.unregister(npc)
			release(1)
			if npc.align then
				npc.align.Enabled = false
				npc.alignOri.Enabled = false
			end
			Fx.near(rig.root.Position, 300, "poof", { p = rig.root.Position, s = size })
			for _, d in model:GetDescendants() do
				if d:IsA("Motor6D") then
					d:SetAttribute("Anim", nil)
				elseif d:IsA("BasePart") then
					d.CanCollide = d == rig.root
				end
			end
			task.delay(2.5, function()
				if model.Parent then
					model:Destroy()
				end
			end)
		end)
	end

	Fx.near(ctx.origin.Position, 400, "spawn", { p = ctx.origin.Position, s = size, c = if hostile then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(120, 220, 255) })

	return {
		npcs = npcs,
		position = ctx.origin.Position,
		radius = 6 * size,
		elements = { params.element },
		stop = function()
			for _, npc in npcs do
				Brain.remove(npc)
				Actors.unregister(npc)
			end
		end,
		done = function()
			return deadCount >= count
		end,
	}
end

return H
