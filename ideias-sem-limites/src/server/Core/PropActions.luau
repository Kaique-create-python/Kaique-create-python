--!strict
-- Interações dos objetos criados (comer, abrir presente, acender dinamite,
-- disparar canhão, vestir chapéu, fogueira que cura...). Usa ProximityPrompt:
-- funciona igual no celular (toque) e no computador (tecla E).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Combat = require(script.Parent.Combat)
local Actors = require(script.Parent.Actors)
local Status = require(script.Parent.Status)
local Fx = require(script.Parent.Fx)
local Destruction = require(script.Parent.Destruction)
local Kit = require(script.Parent.Parent.Builders.Kit)
local Config = require(ReplicatedStorage.IdeiasShared.Config)

local PropActions = {}

PropActions.rewardHook = nil :: ((Player, string, number) -> ())?

local function prompt(part: BasePart, action: string, object: string, hold: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.Parent = part
	return p
end

local function sound(parent: Instance, id: string, volume: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 4)
end

function PropActions.explode(pos: Vector3, power: number, attacker: any?)
	Fx.flash(pos, Color3.fromRGB(255, 170, 60), 18 * power)
	Fx.shockwave(pos, 22 * power, Color3.fromRGB(255, 140, 40))
	Fx.shake(pos, 1.2 * power, 160)
	Fx.near(pos, 500, "boom", { p = pos, s = power })
	Combat.area(pos, 18 * power, 40 * power, attacker, "fire", 80 * power)
	Destruction.blast(pos, 24 * power, 110 * power)
end

local RANDOM_POWERS = { "heal", "speed", "jump", "shield", "aura", "giant", "tiny" }

function PropActions.attach(model: Model, main: BasePart, kind: string?, params: { [string]: any }, ctx: any)
	local label = ctx.def.label
	if params.edible then
		local p = prompt(main, "Comer", label)
		p.Triggered:Connect(function(player)
			local a = Actors.playerActor(player)
			if Actors.alive(a) then
				Combat.heal(a, 25)
				Fx.to(player, "toast", { t = "Nham! +25 de vida", c = Color3.fromRGB(120, 255, 140) })
				if params.element then
					Status.applyElement(a.humanoid, params.element)
				end
				if PropActions.rewardHook then
					PropActions.rewardHook(player, "eat", 1)
				end
			end
			sound(main, Config.Sounds.Splat, 0.5)
			model:Destroy()
		end)
	end
	if kind == "gift" then
		local p = prompt(main, "Abrir", label)
		p.Triggered:Connect(function(player)
			Fx.near(main.Position, 300, "confetti", { p = main.Position })
			local power = RANDOM_POWERS[math.random(1, #RANDOM_POWERS)]
			local Power = require(script.Parent.Parent.Handlers.Power)
			pcall(Power.apply, player, power, nil)
			if PropActions.rewardHook then
				PropActions.rewardHook(player, "gift", 1)
			end
			model:Destroy()
		end)
	elseif kind == "treasure" then
		local p = prompt(main, "Abrir", label, 0.5)
		p.Triggered:Connect(function(player)
			Fx.near(main.Position, 300, "confetti", { p = main.Position, gold = true })
			Fx.to(player, "toast", { t = "Tesouro! +10 Faíscas", c = Color3.fromRGB(255, 215, 80) })
			if PropActions.rewardHook then
				PropActions.rewardHook(player, "treasure", 10)
			end
			p.Enabled = false
		end)
	elseif kind == "explode" then
		local fuse = params.fuse
		local function boom(player: Player?)
			if not model.Parent then
				return
			end
			local pos = main.Position
			model:Destroy()
			PropActions.explode(pos, 1.2 * (params.scale or 1), if player then Actors.playerActor(player) else nil)
		end
		if fuse then
			task.delay(fuse, function()
				boom(ctx.owner)
			end)
		else
			local p = prompt(main, "Acender", label)
			p.Triggered:Connect(function(player)
				p.Enabled = false
				local sp = Instance.new("Sparkles")
				sp.Parent = main
				task.delay(2.5, function()
					boom(player)
				end)
			end)
		end
	elseif kind == "cannon" then
		local p = prompt(main, "Disparar", label)
		local cooldown = 0
		p.Triggered:Connect(function(player)
			if os.clock() < cooldown then
				return
			end
			cooldown = os.clock() + 2
			local dir = main.CFrame.LookVector
			local from = main.Position + Vector3.new(0, 3, 0) + dir * 4
			local to = from + dir * 140 + Vector3.new(0, -20, 0)
			Fx.bolt(from, to, Color3.fromRGB(40, 40, 45), 140, 2)
			sound(main, Config.Sounds.Rocket, 0.8)
			task.delay(1, function()
				PropActions.explode(to, 1, Actors.playerActor(player))
			end)
		end)
	elseif kind == "magnet" then
		task.spawn(function()
			while model.Parent do
				Destruction.blast(main.Position, 40, 30, true)
				for _, a in Actors.near(main.Position, 40) do
					if a.kind == "npc" then
						local d = main.Position - a.root.Position
						if d.Magnitude > 5 then
							Combat.push(a, d.Unit * 18)
						end
					end
				end
				task.wait(0.6)
			end
		end)
	elseif kind == "party" then
		model:SetAttribute("Festa", true)
		task.spawn(function()
			while model.Parent do
				for _, a in Actors.near(main.Position, 60) do
					if a.kind == "npc" and a.faction ~= "hostile" then
						a.behavior = "dance"
					end
				end
				task.wait(2)
			end
		end)
	elseif kind == "heal" then
		task.spawn(function()
			while model.Parent do
				for _, a in Actors.near(main.Position, 16) do
					if a.kind == "player" then
						Combat.heal(a, 6)
						Status.clear(a.humanoid, "freeze")
					end
				end
				task.wait(1.5)
			end
		end)
	elseif kind == "bounce" then
		local top = model:FindFirstChild("Chapeu") :: BasePart?
		if top then
			top:AddTag("IdeiasPulo")
			top:SetAttribute("Forca", 120)
		end
	elseif kind == "wind" then
		task.spawn(function()
			while model.Parent do
				local look = main.CFrame.LookVector
				for _, a in Actors.near(main.Position, 45) do
					local to = a.root.Position - main.Position
					if to.Magnitude > 0.1 and look:Dot(to.Unit) > 0.6 then
						Combat.push(a, look * 35)
					end
				end
				task.wait(0.5)
			end
		end)
	elseif kind == "wear" then
		local p = prompt(main, "Vestir", label)
		p.Triggered:Connect(function(player)
			local char = player.Character
			local head = char and char:FindFirstChild("Head") :: BasePart?
			if not head then
				return
			end
			local old = char:FindFirstChild("ChapeuIdeias")
			if old then
				old:Destroy()
			end
			local hat = model:Clone()
			hat.Name = "ChapeuIdeias"
			local hb = hat.PrimaryPart :: BasePart
			local scale = 1.4 / math.max(hb.Size.X, 0.5)
			for _, d in hat:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = false
					d.CanCollide = false
					d.Massless = true
					d.Size *= scale
				elseif d:IsA("ProximityPrompt") then
					d:Destroy()
				end
			end
			hat:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y * 0.55, 0))
			for _, d in hat:GetDescendants() do
				if d:IsA("BasePart") then
					local w = Instance.new("WeldConstraint")
					w.Part0 = head
					w.Part1 = d
					w.Parent = d
				end
			end
			hat.Parent = char
			Debris:AddItem(hat, 120)
		end)
	end
end

function PropActions.elementize(main: BasePart, params: { [string]: any })
	if params.elementMod and params.element then
		Kit.elementEffects(main, params.element, math.min(params.scale or 1, 2))
	end
end

PropActions._players = Players

return PropActions
