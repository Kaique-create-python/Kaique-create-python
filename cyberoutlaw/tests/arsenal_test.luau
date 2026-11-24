-- Tests the CyberOutlawArsenal rules and models outside Roblox.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local arsenal = luau.load(fs.readFile("src/arsenal.server.luau"), {
	debugName = "arsenal.server.luau",
	environment = { Instance = roblox.Instance, CFrame = roblox.CFrame, Vector3 = roblox.Vector3, Color3 = roblox.Color3, Enum = roblox.Enum },
})()
local V3 = roblox.Vector3

-- Definitions: nine weapons in wheel order, with complete rules.
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
assert(table.concat(ids, ",") == "punhos,faca,glock,deagle,uzi,ak47,m4,escopeta,sniper")
-- Real weapons: every gun names its own shot sound, reload and class; no neon anywhere.
for _, def in arsenal.WEAPONS do
	assert(type(def.tipo) == "string" and type(def.som) == "string", def.id .. " without type or sound")
	if def.kind == "gun" then
		assert(type(def.recarga) == "string" and type(def.alcance) == "number", def.id .. " without reload or reach")
	end
end

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
	assert(parts <= 40, def.id .. " too heavy for the wheel and the hand")
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			assert(item.Material ~= roblox.Enum.Material.Neon, def.id .. ": real weapons have no neon")
		end
	end
	if def.kind == "gun" then
		local muzzle = grip.CFrame:PointToWorldSpace(grip:FindFirstChild("Cano").Position)
		assert(muzzle.Z < -0.7, def.id .. ": the barrel points at -Z")
	end
end

-- Grip: the gun's -Z follows the arm down (forward when aiming); the blade points forward.
do
	local arm = roblox.Instance.new("Part")
	arm.Size = V3.new(1, 2, 1)
	local gun = arsenal.gripOffset(byId.glock, arm)
	assert((gun:VectorToWorldSpace(V3.new(0, 0, -1)) - V3.new(0, -1, 0)).Magnitude < 1e-5)
	assert((gun:VectorToWorldSpace(V3.new(0, 1, 0)) - V3.new(0, 0, -1)).Magnitude < 1e-5)
	assert(gun.Position.Y < -0.5 and gun.Position.Y > -1.05, "the grip sits in the hand (end of the arm)")
	-- The gun body (receiver above the grip) stays outside the R6 arm block, so it is visible when aiming.
	local receiver = gun:PointToWorldSpace(V3.new(0, 0.38, -0.2))
	assert(math.abs(receiver.Z) > arm.Size.Z / 2, "receiver outside the arm: " .. tostring(receiver))
	local blade = arsenal.gripOffset(byId.faca, arm)
	assert((blade:VectorToWorldSpace(V3.new(0, 0, -1)) - V3.new(0, 0, -1)).Magnitude < 1e-5)
end

-- Safe zone at Praça da Maré.
assert(arsenal.inSafeZone(V3.new(107, 3, 139)))
assert(not arsenal.inSafeZone(V3.new(107 + 100, 3, 107)))

-- Damage: full up to 60% of range, half at the end, headshot x1.5.
local glock = byId.glock
assert(arsenal.damageFor(glock, 10, false) == glock.damage)
assert(math.abs(arsenal.damageFor(glock, glock.range, false) - glock.damage * 0.5) < 1e-6)
assert(math.abs(arsenal.damageFor(glock, 10, true) - glock.damage * 1.5) < 1e-6)

-- Shot validation.
local head = V3.new(0, 5, 0)
local forward = { V3.new(0, 0, -1) }
local function fresh()
	return arsenal.newState()
end
assert(fresh().ammo.glock.mag == glock.mag and fresh().ammo.punhos == nil)
assert(arsenal.checkShot(fresh(), glock, 10, head + V3.new(2, 1, 10), forward, head) == true)
local state = fresh()
state.reloadUntil = 20
assert(select(2, arsenal.checkShot(state, glock, 10, head, forward, head)) == "recarregando")
state = fresh()
state.ammo.glock.mag = 0
assert(select(2, arsenal.checkShot(state, glock, 10, head, forward, head)) == "pente vazio")
state = fresh()
state.nextShot = 11
assert(select(2, arsenal.checkShot(state, glock, 10, head, forward, head)) == "cadência")
assert(select(2, arsenal.checkShot(fresh(), glock, 10, head + V3.new(0, 0, 60), forward, head)) == "origem")
assert(select(2, arsenal.checkShot(fresh(), glock, 10, head, { forward[1], forward[1] }, head)) == "projéteis")
assert(select(2, arsenal.checkShot(fresh(), glock, 10, head, { V3.new(0, 0, -3) }, head)) == "direção")
assert(select(2, arsenal.checkShot(fresh(), byId.punhos, 10, head, forward, head)) == "sem arma de fogo")
local pellets = {}
for index = 1, byId.escopeta.pellets do
	pellets[index] = V3.new(0, 0, -1)
end
assert(arsenal.checkShot(fresh(), byId.escopeta, 10, head, pellets, head) == true, "the shotgun sends nine pellets")

-- Implantes: nomes do Cyberpunk, um lugar do corpo cada, só o Sandevistan pronto por enquanto.
local implantIds, slots = {}, { coluna = true, olhos = true, bracos = true, pernas = true, pele = true }
for _, def in arsenal.IMPLANTS do
	assert(not implantIds[def.id], "repeated implant " .. def.id)
	implantIds[def.id] = def
	assert(type(def.name) == "string" and type(def.sistema) == "string" and type(def.desc) == "string" and #def.desc > 20)
	assert(slots[def.slot], def.id .. " has a body slot")
end
assert(implantIds.sandevistan.pronto and implantIds.sandevistan.slot == "coluna", "the Sandevistan sits on the spine")
for id, def in implantIds do
	assert(def.pronto, id .. " works")
end
assert(implantIds.subdermal.stats.reducao > 0 and implantIds.louva.stats.dano > 30 and implantIds.gorila.stats.empurrao > 0)
-- Modelos: uma peça por parte do corpo, base como PrimaryPart, tudo soldado nela, dentro do lugar certo.
local BODY = { Torso = V3.new(1, 1, 0.5), Head = V3.new(1, 0.6, 0.6), ["Right Arm"] = V3.new(0.5, 1, 0.5),
	["Left Arm"] = V3.new(0.5, 1, 0.5), ["Right Leg"] = V3.new(0.5, 1, 0.5), ["Left Leg"] = V3.new(0.5, 1, 0.5) }
for id, def in implantIds do
	local model = arsenal.buildImplant(def)
	local pieces = model:GetChildren()
	assert(#pieces == #arsenal.IMPLANT_PARTS[id], id .. " has one piece per body part")
	local lights = 0
	for _, piece in pieces do
		assert(BODY[piece.Name], id .. ": piece on a real R6 part")
		local base = piece.PrimaryPart
		assert(base and base.Name == "Base", id .. " without base")
		local parts, welds = 0, 0
		for _, item in piece:GetDescendants() do
			if item:IsA("BasePart") then
				parts += 1
				assert(not item.CanCollide and not item.CanQuery and not item.CanTouch and item.Massless)
				if item.Name == "Luz" then
					lights += 1
					assert(item.Material == roblox.Enum.Material.Neon)
				end
				-- Encostado na parte do corpo: o centro de cada peça fica até 1,5 stud da superfície dela.
				local p = item.CFrame.Position
				local half = BODY[piece.Name]
				local outside = V3.new(math.max(0, math.abs(p.X) - half.X), math.max(0, math.abs(p.Y) - half.Y), math.max(0, math.abs(p.Z) - half.Z))
				assert(outside.Magnitude < 1.5, id .. ": " .. item.Name .. " too far from " .. piece.Name)
			elseif item:IsA("WeldConstraint") then
				welds += 1
				assert(item.Part0 == base)
			end
		end
		assert(welds == parts - 1 and parts <= 40, id .. ": every piece welded to its base")
	end
	assert(lights >= 1, id .. " has a light")
end
do
	-- A coluna fica nas costas; as lentes na frente do rosto.
	for _, item in arsenal.buildImplant(implantIds.sandevistan).Torso:GetDescendants() do
		if item:IsA("BasePart") then
			assert(item.CFrame.Position.Z > 0.45, item.Name .. " stays on the back")
		end
	end
	local lens = 0
	for _, item in arsenal.buildImplant(implantIds.kiroshi).Head:GetDescendants() do
		if item.Name == "Lente" then
			lens += 1
			assert(item.CFrame.Position.Z < -0.5, "lenses in front of the face")
		end
	end
	assert(lens == 2)
end
-- Regras do Sandevistan: usa quantas vezes quiser, cada uso gasta estabilidade; a zero, surto de 2 s.
do
	local rules = arsenal.SANDEVISTAN
	local mind = arsenal.newMind()
	assert(select(2, arsenal.useSandevistan(mind, 0)) == "sem implante")
	assert(select(2, arsenal.setImplant(mind, "nao-existe", true, 0)) == "implante", "unknown implants are refused")
	assert(arsenal.setImplant(mind, "sandevistan", true, 0) == true and mind.implants.sandevistan)
	local t = 10
	assert(arsenal.useSandevistan(mind, t) == true and mind.psy == 100 - rules.custo)
	assert(mind.activeUntil == t + rules.duracao)
	assert(select(2, arsenal.useSandevistan(mind, t + 1)) == "ativo")
	assert(select(2, arsenal.setImplant(mind, "sandevistan", false, t + 1)) == "em uso", "no swapping mid-effect")
	assert(select(2, arsenal.useSandevistan(mind, t + rules.duracao + 0.5)) == "recarga")
	local uses = 1
	while mind.frenzyUntil == 0 do
		t = mind.abilityReady
		assert(arsenal.useSandevistan(mind, t) == true)
		uses += 1
	end
	assert(uses == math.ceil(100 / rules.custo) and mind.psy == 0, "the bar empties after a few uses")
	assert(rules.surto == 30 and mind.frenzyUntil == t + rules.surto, "zero stability starts a 30 s cyberpsychosis")
	assert(select(2, arsenal.useSandevistan(mind, t + 1)) == "surto")
	assert(not arsenal.regenMind(mind, t + 1, 0.5), "no recovery during the episode")
	assert(arsenal.regenMind(mind, t + rules.surto, 0.5) and mind.frenzyUntil == 0 and mind.psy == rules.aposSurto)
	-- Sem usar por um tempo, a estabilidade volta devagar até 100.
	local now = t + rules.surto
	assert(not arsenal.regenMind(mind, now + 1, 0.5), "waits before regenerating")
	now += rules.espera + 1
	for _ = 1, 200 do
		arsenal.regenMind(mind, now, 0.5)
		now += 0.5
	end
	assert(mind.psy == 100)
	-- Um implante por lugar do corpo: o novo tira o antigo.
	local arms = arsenal.newMind()
	assert(arsenal.setImplant(arms, "louva", true, 0) and arms.implants.louva)
	assert(arsenal.setImplant(arms, "gorila", true, 0) and arms.implants.gorila and not arms.implants.louva, "one arm implant at a time")
	assert(arsenal.setImplant(arms, "tendoes", true, 0) and arms.implants.tendoes and arms.implants.gorila, "other body parts stay")
	assert(arsenal.setImplant(arms, "gorila", false, 0) and not arms.implants.gorila)
end
print("CyberOutlawArsenal: 9 real weapons, welded models without neon, grip, safe zone, damage, validation, implants and the Sandevistan rules passed")
