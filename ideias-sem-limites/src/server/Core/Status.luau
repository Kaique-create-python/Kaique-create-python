--!strict
-- Efeitos de status em Humanoids (jogadores e NPCs): queimadura, congelamento,
-- choque, veneno, lentidão, pressa, pulo, escudo. A velocidade final é sempre
-- recalculada a partir do valor base, então efeitos acumulados nunca "vazam".

local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").IdeiasShared.Config)

local Status = {}

type Effect = { kind: string, expires: number, power: number, visual: Instance? }
type Entry = { humanoid: Humanoid, effects: { [string]: Effect }, baseSpeed: number, baseJump: number }

local entries: { [Humanoid]: Entry } = {}

-- multiplicadores de velocidade por efeito
local SPEED = { freeze = 0.25, shock = 0, slow = 0.5, haste = 1.9, poison = 0.85, wet = 0.9, root = 0.15 }
local JUMP = { freeze = 0.4, shock = 0, superjump = 2.6, root = 0 }
local DOT = { burn = 6, poison = 4, acid = 5 }

local ELEMENT_STATUS = {
	fire = { "burn", 3 },
	lava = { "burn", 4.5 },
	ice = { "freeze", 2.5 },
	electric = { "shock", 0.9 },
	poison = { "poison", 5 },
	water = { "wet", 4 },
	nature = { "root", 1.5 },
	shadow = { "slow", 3 },
}

local function entryFor(h: Humanoid): Entry
	local e = entries[h]
	if not e then
		local baseSpeed = h:GetAttribute("BaseWalkSpeed")
		if type(baseSpeed) ~= "number" then
			baseSpeed = h.WalkSpeed
			h:SetAttribute("BaseWalkSpeed", baseSpeed)
		end
		local baseJump = h:GetAttribute("BaseJump")
		if type(baseJump) ~= "number" then
			baseJump = if h.UseJumpPower then h.JumpPower else h.JumpHeight
			h:SetAttribute("BaseJump", baseJump)
		end
		e = { humanoid = h, effects = {}, baseSpeed = baseSpeed :: number, baseJump = baseJump :: number }
		entries[h] = e
	end
	return e
end

local function recompute(e: Entry)
	local h = e.humanoid
	local sm, jm = 1, 1
	for kind, _ in e.effects do
		sm *= SPEED[kind] or 1
		jm *= JUMP[kind] or 1
	end
	h.WalkSpeed = e.baseSpeed * sm
	if h.UseJumpPower then
		h.JumpPower = e.baseJump * jm
	else
		h.JumpHeight = e.baseJump * jm
	end
end

local function makeVisual(kind: string, h: Humanoid): Instance?
	local model = h.Parent
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart"))
	if not root then
		return nil
	end
	if kind == "burn" then
		local f = Instance.new("Fire")
		f.Size = 4
		f.Heat = 6
		f.Parent = root
		return f
	elseif kind == "poison" or kind == "acid" then
		local s = Instance.new("Smoke")
		s.Color = Color3.fromRGB(120, 230, 60)
		s.Opacity = 0.25
		s.RiseVelocity = 2
		s.Size = 2
		s.Parent = root
		return s
	elseif kind == "shock" then
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Color3.fromRGB(255, 240, 90)
		sp.Parent = root
		return sp
	elseif kind == "freeze" or kind == "shield" or kind == "haste" then
		local hl = Instance.new("Highlight")
		hl.FillColor = if kind == "freeze" then Color3.fromRGB(150, 220, 255) elseif kind == "shield" then Color3.fromRGB(255, 230, 120) else Color3.fromRGB(120, 255, 200)
		hl.FillTransparency = 0.55
		hl.OutlineTransparency = 0.3
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = model
		return hl
	end
	return nil
end

function Status.apply(h: Humanoid?, kind: string, duration: number, power: number?)
	if not h or h.Health <= 0 then
		return
	end
	local e = entryFor(h)
	local existing = e.effects[kind]
	local expires = os.clock() + duration
	if existing then
		existing.expires = math.max(existing.expires, expires)
		existing.power = math.max(existing.power, power or 1)
	else
		-- molhado apaga queimadura; fogo descongela
		if kind == "wet" and e.effects.burn then
			Status.clear(h, "burn")
		elseif kind == "burn" and e.effects.freeze then
			Status.clear(h, "freeze")
		end
		e.effects[kind] = { kind = kind, expires = expires, power = power or 1, visual = makeVisual(kind, h) }
	end
	if kind == "shield" then
		local model = h.Parent
		if model and not model:FindFirstChildWhichIsA("ForceField") then
			local ff = Instance.new("ForceField")
			ff.Visible = false
			ff.Name = "EscudoIdeias"
			ff.Parent = model
		end
	end
	recompute(e)
end

function Status.applyElement(h: Humanoid?, element: string?, scale: number?)
	if not element then
		return
	end
	local s = ELEMENT_STATUS[element]
	if s then
		Status.apply(h, s[1], s[2] * math.clamp(scale or 1, 0.5, 2))
	end
end

function Status.clear(h: Humanoid, kind: string)
	local e = entries[h]
	if not e then
		return
	end
	local eff = e.effects[kind]
	if eff then
		if eff.visual then
			eff.visual:Destroy()
		end
		e.effects[kind] = nil
		if kind == "shield" and h.Parent then
			local ff = h.Parent:FindFirstChild("EscudoIdeias")
			if ff then
				ff:Destroy()
			end
		end
	end
	recompute(e)
end

function Status.clearAll(h: Humanoid)
	local e = entries[h]
	if e then
		for kind in e.effects do
			Status.clear(h, kind)
		end
		entries[h] = nil
	end
end

function Status.has(h: Humanoid, kind: string): boolean
	local e = entries[h]
	return e ~= nil and e.effects[kind] ~= nil
end

local function tick(dt: number)
	local t = os.clock()
	for h, e in entries do
		if not h.Parent or h.Health <= 0 then
			for _, eff in e.effects do
				if eff.visual then
					eff.visual:Destroy()
				end
			end
			entries[h] = nil
		else
			local changed = false
			for kind, eff in e.effects do
				local dps = DOT[kind]
				if dps then
					h:TakeDamage(dps * eff.power * dt)
				end
				if t >= eff.expires then
					if eff.visual then
						eff.visual:Destroy()
					end
					e.effects[kind] = nil
					if kind == "shield" and h.Parent then
						local ff = h.Parent:FindFirstChild("EscudoIdeias")
						if ff then
							ff:Destroy()
						end
					end
					changed = true
				end
			end
			if changed then
				recompute(e)
			end
		end
	end
end

local started = false
function Status.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.5)
			local t = os.clock()
			tick(t - last)
			last = t
		end
	end)
	-- personagens novos sempre começam limpos e com valores base corretos
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			local h = char:WaitForChild("Humanoid", 10) :: Humanoid?
			if h then
				h:SetAttribute("BaseWalkSpeed", game:GetService("StarterPlayer").CharacterWalkSpeed)
			end
		end)
	end)
end

Status.ElementStatus = ELEMENT_STATUS
Status._config = Config

return Status
