--!strict
-- Vínculos entre acontecimentos do mesmo pedido.
--   rivals    os NPCs de A e B lutam entre si
--   guard     NPCs de A protegem a posição de B (atacam quem se aproxima)
--   bodyguard NPCs de A seguem e defendem o jogador que pediu
--   ride      NPC de A monta/dirige B (veículo ou criatura)
--   at        A aparece dentro/perto de B
--   hunt      A persegue B; B foge de A

local Links = {}

local function npcsOf(rec: any): { any }
	return rec and rec.handle and rec.handle.npcs or {}
end

local function centerOf(rec: any): Vector3
	local h = rec.handle
	if h then
		if h.position then
			return h.position
		end
		if h.anchor and h.anchor.Parent then
			return h.anchor.Position
		end
		if h.model and h.model.PrimaryPart then
			return h.model.PrimaryPart.Position
		end
	end
	return rec.origin.Position
end

local function radiusOf(rec: any): number
	return rec.handle and rec.handle.radius or 25
end

local apply = {}

function apply.rivals(a: any, b: any)
	for _, n in npcsOf(a) do
		n.enemies = n.enemies or {}
		n.enemies[b.id] = true
	end
	for _, n in npcsOf(b) do
		n.enemies = n.enemies or {}
		n.enemies[a.id] = true
	end
	-- aproxima os grupos para a luta começar logo
	local ca, cb = centerOf(a), centerOf(b)
	local mid = (ca + cb) / 2
	for _, n in npcsOf(b) do
		if n.root and n.root.Parent and (n.root.Position - mid).Magnitude > 60 then
			n.root.CFrame = CFrame.new(mid + Vector3.new(math.random(-8, 8), 6, math.random(-8, 8)))
		end
	end
end

function apply.guard(a: any, b: any)
	local pos = centerOf(b)
	local radius = radiusOf(b) + 12
	for _, n in npcsOf(a) do
		n.guard = { position = pos, radius = radius }
		n.home = pos
	end
	-- a construção vive enquanto o guardião viver
	if a.expiresAt > b.expiresAt then
		b.expiresAt = a.expiresAt
	end
end

function apply.bodyguard(a: any, _b: any, owner: Player?)
	for _, n in npcsOf(a) do
		n.faction = "pet"
		n.owner = owner
	end
end

function apply.ride(a: any, b: any)
	local riders = npcsOf(a)
	local rider = riders[1]
	if not rider or not b then
		return
	end
	local seat = b.handle and b.handle.seat
	if seat and seat.Parent then
		rider.riding = true
		rider.root.CFrame = seat.CFrame + Vector3.new(0, 3, 0)
		task.defer(function()
			if seat.Parent and rider.humanoid.Parent then
				(seat :: any):Sit(rider.humanoid)
			end
		end)
		b.handle.autopilot = true
		return
	end
	local mounts = npcsOf(b)
	local mount = mounts[1]
	if mount and mount.root and rider.root then
		rider.riding = true
		rider.humanoid.PlatformStand = true
		local top = mount.height or 6
		rider.root.CFrame = mount.root.CFrame * CFrame.new(0, top * 0.6, 0)
		for _, d in rider.model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Massless = true
				d.CanCollide = false
			end
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = mount.root
		weld.Part1 = rider.root
		weld.Parent = rider.root
		-- montaria e cavaleiro lutam do mesmo lado
		mount.faction = rider.faction
		mount.owner = rider.owner
	end
end

function apply.at(a: any, b: any)
	local pos = centerOf(b)
	local i = 0
	for _, n in npcsOf(a) do
		i += 1
		if n.root and n.root.Parent then
			local ang = i * 2.3
			n.root.CFrame = CFrame.new(pos + Vector3.new(math.cos(ang) * 6, 5, math.sin(ang) * 6))
			n.home = pos
		end
	end
	local model = a.handle and a.handle.model
	if model and model.Parent and #npcsOf(a) == 0 then
		model:PivotTo(CFrame.new(pos + Vector3.new(0, 4, 0)))
	end
end

function apply.hunt(a: any, b: any)
	for _, n in npcsOf(a) do
		n.prey = n.prey or {}
		n.prey[b.id] = true
	end
	for _, n in npcsOf(b) do
		n.fleeFrom = n.fleeFrom or {}
		n.fleeFrom[a.id] = true
	end
end

function Links.apply(kind: string, a: any, b: any, owner: Player?)
	local f = apply[kind]
	if f then
		f(a, b, owner)
	end
end

return Links
