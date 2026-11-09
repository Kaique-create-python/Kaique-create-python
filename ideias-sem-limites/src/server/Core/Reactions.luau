--!strict
-- Interações entre acontecimentos ativos no mundo, por elemento e proximidade.
-- Ex.: tornado de fogo encontra explosão de gelo -> vapor e os dois enfraquecem;
-- chuva/tsunami apaga incêndios; eletricidade perto de água eletrifica a área;
-- lava + água vira obsidiana; fogo perto de natureza espalha chamas.
-- Regras são dados: novas reações não exigem mudar o laço.

local Combat = require(script.Parent.Combat)
local Fx = require(script.Parent.Fx)
local Kit = require(script.Parent.Parent.Builders.Kit)

local Reactions = {}

local function elementsOf(rec: any): { [string]: boolean }
	local set = {}
	local h = rec.handle
	if h and h.elements then
		for _, e in h.elements do
			if e then
				set[e] = true
			end
		end
	end
	local tags = rec.def.tagSet
	for _, t in { "fire", "ice", "water", "nature", "electric", "lava", "wind" } do
		if tags[t] then
			set[t] = true
		end
	end
	return set
end

local function positionOf(rec: any): Vector3?
	local h = rec.handle
	if not h then
		return nil
	end
	if h.positionAt then
		return h.positionAt()
	end
	return h.position
end

type Rule = { a: string, b: string, text: string, color: Color3, act: (ra: any, rb: any, pos: Vector3, manager: any) -> () }

local RULES: { Rule } = {
	{
		a = "fire",
		b = "ice",
		text = "Fogo + Gelo = Vapor!",
		color = Color3.fromRGB(230, 240, 255),
		act = function(ra, rb, pos, manager)
			Fx.near(pos, 400, "steam", { p = pos, s = 2 })
			ra.expiresAt = math.min(ra.expiresAt, os.clock() + 4)
			rb.expiresAt = math.min(rb.expiresAt, os.clock() + 4)
		end,
	},
	{
		a = "water",
		b = "fire",
		text = "A água apagou o fogo!",
		color = Color3.fromRGB(150, 210, 255),
		act = function(_ra, rb, pos, manager)
			Fx.near(pos, 400, "steam", { p = pos, s = 1.5 })
			if rb.handle and rb.handle.extinguish then
				rb.handle.extinguish()
			end
			rb.expiresAt = math.min(rb.expiresAt, os.clock() + 2)
		end,
	},
	{
		a = "electric",
		b = "water",
		text = "Água eletrificada!",
		color = Color3.fromRGB(255, 240, 120),
		act = function(_ra, _rb, pos)
			for i = 1, 5 do
				local p = pos + Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
				Fx.zap(p + Vector3.new(0, 30, 0), p, Color3.fromRGB(255, 240, 120))
				task.delay(i * 0.2, function()
					Combat.area(p, 10, 15, nil, "electric", 20)
				end)
			end
		end,
	},
	{
		a = "lava",
		b = "water",
		text = "Lava + Água = Obsidiana!",
		color = Color3.fromRGB(120, 90, 160),
		act = function(ra, _rb, pos)
			Fx.near(pos, 400, "steam", { p = pos, s = 2.5 })
			local b = Kit.new("Obsidiana", CFrame.new(pos), { anchored = true, collide = true })
			for k = 0, 6 do
				local a = k * 0.9
				b:part("wedge", Vector3.new(3, math.random(3, 7), 3), CFrame.new(math.cos(a) * 6, 2, math.sin(a) * 6) * CFrame.Angles(0, a, 0.2), Color3.fromRGB(35, 25, 45), { role = "fixed", material = Enum.Material.Glass, reflectance = 0.3 })
			end
			b:finish().Parent = ra.folder
		end,
	},
	{
		a = "ice",
		b = "water",
		text = "A água congelou!",
		color = Color3.fromRGB(180, 230, 255),
		act = function(_ra, rb, pos)
			Fx.shockwave(pos, 30, Color3.fromRGB(180, 230, 255))
			rb.expiresAt = math.min(rb.expiresAt, os.clock() + 1)
			for _, a in require(script.Parent.Actors).near(pos, 30) do
				require(script.Parent.Status).apply(a.humanoid, "freeze", 3)
			end
		end,
	},
	{
		a = "fire",
		b = "nature",
		text = "As chamas se espalharam!",
		color = Color3.fromRGB(255, 150, 60),
		act = function(_ra, rb, _pos)
			local n = 0
			for _, d in rb.folder:GetDescendants() do
				if d:IsA("BasePart") and n < 6 and math.random() < 0.3 then
					n += 1
					local f = Instance.new("Fire")
					f.Size = 6
					f.Parent = d
				end
			end
		end,
	},
	{
		a = "wind",
		b = "fire",
		text = "O vento alimentou o fogo!",
		color = Color3.fromRGB(255, 180, 90),
		act = function(_ra, rb, pos)
			Fx.shockwave(pos, 20, Color3.fromRGB(255, 160, 60))
			rb.expiresAt += 8
		end,
	},
	{
		a = "light",
		b = "shadow",
		text = "Luz e sombra se anularam!",
		color = Color3.fromRGB(255, 255, 230),
		act = function(_ra, _rb, pos)
			Fx.flash(pos, Color3.fromRGB(255, 255, 230), 40)
		end,
	},
}

Reactions.Rules = RULES
Reactions.count = 0

local done: { [string]: boolean } = {}

function Reactions.check(active: { any }, manager: any)
	for i = 1, #active do
		local ra = active[i]
		local pa = positionOf(ra)
		if pa and ra.alive then
			local ea = elementsOf(ra)
			for j = 1, #active do
				if i ~= j then
					local rb = active[j]
					local pb = positionOf(rb)
					if pb and rb.alive then
						local key = ra.id .. ":" .. rb.id
						if not done[key] then
							local reach = (ra.handle.radius or 10) + (rb.handle.radius or 10) + 10
							if (pa - pb).Magnitude <= reach then
								local eb = elementsOf(rb)
								for _, rule in RULES do
									if ea[rule.a] and eb[rule.b] then
										done[key] = true
										done[rb.id .. ":" .. ra.id] = true
										local mid = (pa + pb) / 2
										Reactions.count += 1
										Fx.near(mid, 600, "toast", { t = "✨ " .. rule.text, c = rule.color })
										local ok, err = pcall(rule.act, ra, rb, mid, manager)
										if not ok then
											warn("[Ideias] reação: " .. tostring(err))
										end
										break
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

function Reactions.start(manager: any)
	task.spawn(function()
		while true do
			task.wait(0.75)
			local ok, err = pcall(Reactions.check, manager.active(), manager)
			if not ok then
				warn("[Ideias] reações: " .. tostring(err))
			end
		end
	end)
	manager.onRemoved(function(rec)
		for key in done do
			if string.find(key, "^" .. rec.id .. ":") or string.find(key, ":" .. rec.id .. "$") then
				done[key] = nil
			end
		end
	end)
end

return Reactions
