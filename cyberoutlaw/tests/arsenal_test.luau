-- Tests the CyberOutlawArsenal rules and models outside Roblox.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local arsenal = luau.load(fs.readFile("src/arsenal.server.luau"), {
	debugName = "arsenal.server.luau",
	environment = { Instance = roblox.Instance, CFrame = roblox.CFrame, Vector3 = roblox.Vector3, Color3 = roblox.Color3, Enum = roblox.Enum },
})()
local V3 = roblox.Vector3

-- Definitions: six weapons in wheel order, with complete rules.
local ids, byId = {}, {}
for index, def in arsenal.WEAPONS do
	assert(def.order == index, "the order follows the list")
	assert(not byId[def.id], "repeated id " .. def.id)
	byId[def.id] = def
	table.insert(ids, def.id)
	assert(type(def.name) == "string" and #def.accent == 3 and #def.stats == 4)
	if def.kind == "gun" then
		for _, key in { "damage", "rate", "mag", "reserve", "spread", "range", "pellets", "reload", "recoil", "fov" } do
			assert(type(def[key]) == "number" and def[key] > 0, def.id .. " missing " .. key)
		end
	else
		assert(def.kind == "melee" and def.rate > 0 and def.range > 0 and def.damage > 0)
	end
end
assert(table.concat(ids, ",") == "punhos,lamina,vespa,enxame,trovao,agulha")

-- Models: grip as PrimaryPart, muzzle in the right place, parts welded and with no collision.
for _, def in arsenal.WEAPONS do
	local model = arsenal.buildModel(def)
	local grip = model.PrimaryPart
	assert(grip and grip.Name == "Empunhadura", def.id .. " without grip")
	assert(grip:FindFirstChild("Cano"), def.id .. " without muzzle")
	local parts, welds = 0, 0
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			parts += 1
			assert(not item.CanCollide and not item.CanQuery and not item.CanTouch and item.Massless and item.Anchored)
		elseif item:IsA("WeldConstraint") then
			welds += 1
			assert(item.Part0 == grip, "every weld goes to the grip")
		end
	end
	assert(welds == parts - 1, def.id .. ": every piece welded to the grip")
	assert(parts <= 20, def.id .. " too heavy for the wheel and the hand")
	if def.kind == "gun" then
		local muzzle = grip.CFrame:PointToWorldSpace(grip:FindFirstChild("Cano").Position)
		assert(muzzle.Z < -1, def.id .. ": the barrel points at -Z")
	end
end

-- Grip: the gun's -Z follows the arm down (forward when aiming); the blade points forward.
do
	local arm = roblox.Instance.new("Part")
	arm.Size = V3.new(1, 2, 1)
	local gun = arsenal.gripOffset(byId.vespa, arm)
	assert((gun:VectorToWorldSpace(V3.new(0, 0, -1)) - V3.new(0, -1, 0)).Magnitude < 1e-5)
	assert((gun:VectorToWorldSpace(V3.new(0, 1, 0)) - V3.new(0, 0, -1)).Magnitude < 1e-5)
	assert(math.abs(gun.Position.Y + 1.05) < 1e-5, "the grip sits in the hand")
	local blade = arsenal.gripOffset(byId.lamina, arm)
	assert((blade:VectorToWorldSpace(V3.new(0, 0, -1)) - V3.new(0, 0, -1)).Magnitude < 1e-5)
end

-- Safe zone at Praça da Maré.
assert(arsenal.inSafeZone(V3.new(107, 3, 139)))
assert(not arsenal.inSafeZone(V3.new(107 + 100, 3, 107)))

-- Damage: full up to 60% of range, half at the end, headshot x1.5.
local vespa = byId.vespa
assert(arsenal.damageFor(vespa, 10, false) == vespa.damage)
assert(math.abs(arsenal.damageFor(vespa, vespa.range, false) - vespa.damage * 0.5) < 1e-6)
assert(math.abs(arsenal.damageFor(vespa, 10, true) - vespa.damage * 1.5) < 1e-6)

-- Shot validation.
local head = V3.new(0, 5, 0)
local forward = { V3.new(0, 0, -1) }
local function fresh()
	return arsenal.newState()
end
assert(fresh().ammo.vespa.mag == vespa.mag and fresh().ammo.punhos == nil)
assert(arsenal.checkShot(fresh(), vespa, 10, head + V3.new(2, 1, 10), forward, head) == true)
local state = fresh()
state.reloadUntil = 20
assert(select(2, arsenal.checkShot(state, vespa, 10, head, forward, head)) == "recarregando")
state = fresh()
state.ammo.vespa.mag = 0
assert(select(2, arsenal.checkShot(state, vespa, 10, head, forward, head)) == "pente vazio")
state = fresh()
state.nextShot = 11
assert(select(2, arsenal.checkShot(state, vespa, 10, head, forward, head)) == "cadência")
assert(select(2, arsenal.checkShot(fresh(), vespa, 10, head + V3.new(0, 0, 60), forward, head)) == "origem")
assert(select(2, arsenal.checkShot(fresh(), vespa, 10, head, { forward[1], forward[1] }, head)) == "projéteis")
assert(select(2, arsenal.checkShot(fresh(), vespa, 10, head, { V3.new(0, 0, -3) }, head)) == "direção")
assert(select(2, arsenal.checkShot(fresh(), byId.punhos, 10, head, forward, head)) == "sem arma de fogo")
local pellets = {}
for index = 1, byId.trovao.pellets do
	pellets[index] = V3.new(0, 0, -1)
end
assert(arsenal.checkShot(fresh(), byId.trovao, 10, head, pellets, head) == true, "the shotgun sends nine pellets")
print("CyberOutlawArsenal: 6 weapons, welded models, grip, safe zone, damage, and validation passed")
