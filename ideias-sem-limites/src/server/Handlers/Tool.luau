--!strict
-- Ferramentas na mochila: espada, martelo, varinha, blaster, arco, bolas de
-- neve, pistola d'água, lança-chamas e gancho. Mira automática no inimigo mais
-- próximo à frente (ótimo no celular). O servidor valida cada golpe.

local Debris = game:GetService("Debris")
local Kit = require(script.Parent.Parent.Builders.Kit)
local Combat = require(script.Parent.Parent.Core.Combat)
local Actors = require(script.Parent.Parent.Core.Actors)
local Factions = require(script.Parent.Parent.Core.Factions)
local Fx = require(script.Parent.Parent.Core.Fx)

local H = { name = "tool" }

local COOLDOWN = { sword = 0.5, hammer = 1.2, wand = 0.6, blaster = 0.35, bow = 0.8, snowball = 0.4, water_gun = 0.15, flamethrower = 0.25, grapple = 1.5 }
local RANGE = { wand = 120, blaster = 110, bow = 140, snowball = 70, water_gun = 45, flamethrower = 22, grapple = 150 }

function H.estimate(_spec: any): { [string]: number }
	return { events = 1, parts = 10 }
end

local function buildHandle(kind: string, params: { [string]: any }): (Tool, BasePart)
	local tool = Instance.new("Tool")
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	local b = Kit.new("Ferramenta", CFrame.identity, { anchored = false, collide = false, scale = 1, material = params.material, color = params.color, element = params.element, elementMod = params.elementMod })
	local handle: BasePart
	local metal = Color3.fromRGB(210, 215, 225)
	if kind == "sword" then
		handle = b:box(Vector3.new(0.3, 1.2, 0.3), CFrame.new(), Color3.fromRGB(110, 75, 40), { role = "fixed" })
		b:box(Vector3.new(1.4, 0.25, 0.3), CFrame.new(0, 0.7, 0), Color3.fromRGB(255, 200, 50), { role = "fixed", material = Enum.Material.Foil })
		b:box(Vector3.new(0.2, 3.6, 0.5), CFrame.new(0, 2.6, 0), metal, { role = "accent", material = Enum.Material.Metal })
	elseif kind == "hammer" then
		handle = b:box(Vector3.new(0.35, 3, 0.35), CFrame.new(), Color3.fromRGB(110, 75, 40), { role = "fixed" })
		b:box(Vector3.new(1.4, 1.2, 2.2), CFrame.new(0, 1.9, 0), Color3.fromRGB(120, 125, 135), { role = "primary", material = Enum.Material.Metal })
	elseif kind == "wand" then
		handle = b:box(Vector3.new(0.2, 2.4, 0.2), CFrame.new(), Color3.fromRGB(90, 60, 40), { role = "fixed" })
		b:ball(0.6, CFrame.new(0, 1.4, 0), Color3.fromRGB(255, 230, 120), { role = "accent", material = Enum.Material.Neon })
	elseif kind == "bow" then
		handle = b:box(Vector3.new(0.3, 1, 0.3), CFrame.new(), Color3.fromRGB(110, 75, 40), { role = "fixed" })
		b:box(Vector3.new(0.2, 4, 0.3), CFrame.new(0, 0, -0.6), Color3.fromRGB(140, 95, 50), { role = "primary" })
	else
		handle = b:box(Vector3.new(0.4, 1, 0.4), CFrame.new(), Color3.fromRGB(40, 40, 45), { role = "fixed" })
		local col = if kind == "water_gun" then Color3.fromRGB(60, 160, 255) elseif kind == "flamethrower" then Color3.fromRGB(220, 60, 30) elseif kind == "snowball" then Color3.fromRGB(240, 245, 255) else Color3.fromRGB(80, 230, 255)
		b:box(Vector3.new(0.6, 0.7, 2.4), CFrame.new(0, 0.6, -0.9), col, { role = "accent", material = if kind == "blaster" then Enum.Material.Neon else Enum.Material.SmoothPlastic })
	end
	handle.Name = "Handle"
	local model = b:finish(handle)
	for _, p in b.parts do
		p.Massless = true
		p.CanCollide = false
		if p ~= handle then
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
		end
		p.Parent = tool
	end
	model:Destroy()
	tool.Grip = CFrame.new(0, -0.3, 0)
	return tool, handle
end

-- inimigo mais próximo à frente do jogador
local function autoAim(player: Player, root: BasePart, range: number): any?
	local me = Actors.playerActor(player)
	local look = root.CFrame.LookVector
	local best, bestScore = nil, math.huge
	for _, a in Actors.near(root.Position, range) do
		if a.kind == "npc" and a.owner ~= player and (a.faction == "hostile" or Factions.hostileTo(a, me) or (a.provokedBy ~= nil)) then
			local to = a.root.Position - root.Position
			local d = to.Magnitude
			local dot = if d > 0.1 then look:Dot(to.Unit) else 1
			if dot > 0.45 then
				local score = d * (1.6 - dot)
				if score < bestScore then
					best, bestScore = a, score
				end
			end
		end
	end
	return best
end

function H.spawn(ctx: any): any
	local player: Player? = ctx.owner
	if not player then
		return { position = ctx.origin.Position, done = function()
			return true
		end }
	end
	local kind = ctx.params.kind
	local params = ctx.params
	local tool, handle = buildHandle(kind, params)
	tool.Name = ctx.def.label
	tool.ToolTip = ctx.def.label
	local backpack = player:FindFirstChildOfClass("Backpack")
	tool.Parent = backpack or player.Character
	local dmg = (params.dmg or 20) * math.max(1, (params.scale or 1) ^ 0.5)
	local element = params.element
	local color = (element and Kit.Elements[element] and Kit.Elements[element].color) or Color3.fromRGB(255, 255, 255)
	local cd = COOLDOWN[kind] or 0.6
	local nextUse = 0

	tool.Activated:Connect(function()
		local now = os.clock()
		if now < nextUse then
			return
		end
		nextUse = now + cd
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum or hum.Health <= 0 or tool.Parent ~= char then
			return
		end
		local me = Actors.playerActor(player)
		if kind == "sword" or kind == "hammer" then
			local reach = if kind == "sword" then 8 else 11
			local center = root.Position + root.CFrame.LookVector * (reach * 0.6)
			local hits = 0
			for _, a in Actors.near(center, reach) do
				if a.kind == "npc" and a.owner ~= player and a.faction ~= "pet" then
					Combat.damage(a, dmg, me, element)
					if kind == "hammer" then
						Combat.push(a, (root.CFrame.LookVector + Vector3.new(0, 0.7, 0)).Unit * 70)
					end
					hits += 1
				end
			end
			if kind == "hammer" then
				Fx.shockwave(center - Vector3.new(0, 2.5, 0), 10, Color3.fromRGB(220, 220, 255))
				Fx.shake(center, 0.4, 60)
			else
				Fx.near(root.Position, 200, "slash", { p = center, c = color })
			end
		elseif kind == "grapple" then
			local origin = root.Position + Vector3.new(0, 1.5, 0)
			local params2 = RaycastParams.new()
			params2.FilterType = Enum.RaycastFilterType.Exclude
			params2.FilterDescendantsInstances = { char :: Instance }
			local look = (root.CFrame.LookVector + Vector3.new(0, 0.35, 0)).Unit
			local hit = workspace:Raycast(origin, look * RANGE.grapple, params2)
			if hit then
				Fx.zap(origin, hit.Position, Color3.fromRGB(240, 240, 240))
				local to = hit.Position - root.Position
				Fx.impulse(player, to.Unit * math.min(to.Magnitude * 1.6, 160) + Vector3.new(0, 25, 0), "set")
			end
		else
			local range = RANGE[kind] or 100
			local target = autoAim(player, root, range)
			local from = handle.Position
			local to = if target then target.root.Position else root.Position + root.CFrame.LookVector * range
			if kind == "flamethrower" then
				Fx.near(from, 200, "cone", { a = from, b = root.Position + root.CFrame.LookVector * range, c = Color3.fromRGB(255, 120, 30) })
				for _, a in Actors.near(root.Position + root.CFrame.LookVector * (range / 2), range / 2 + 2) do
					if a.kind == "npc" and a.owner ~= player and a.faction ~= "pet" then
						Combat.damage(a, dmg * 0.6, me, "fire")
					end
				end
			else
				local speed = if kind == "bow" then 160 elseif kind == "snowball" then 90 else 180
				local boltColor = if kind == "water_gun" then Color3.fromRGB(80, 170, 255) elseif kind == "snowball" then Color3.fromRGB(245, 250, 255) else color
				Fx.bolt(from, to, boltColor, speed, if kind == "snowball" then 1.2 else 0.5)
				if target then
					local d = (to - from).Magnitude
					local el = if kind == "snowball" then "ice" elseif kind == "water_gun" then "water" else element
					task.delay(d / speed, function()
						if Actors.alive(target) then
							Combat.damage(target, dmg, me, el)
						end
					end)
				end
			end
		end
	end)

	Fx.to(player, "toast", { t = "🎒 " .. ctx.def.label .. " na mochila! Toque para usar.", c = Color3.fromRGB(255, 230, 140) })
	return {
		position = ctx.origin.Position,
		elements = { element },
		stop = function()
			if tool.Parent then
				tool:Destroy()
			end
		end,
		done = function()
			return tool.Parent == nil
		end,
	}
end

H._debris = Debris

return H
