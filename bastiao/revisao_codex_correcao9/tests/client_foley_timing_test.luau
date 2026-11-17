-- Pure timing/validation behavior; playback has a separate service harness.
local fs = require("@lune/fs")
local Foley = if fs.isFile("src/client/Foley.luau") then require("../src/client/Foley") else {}
local Timing = Foley.Timing
assert(Timing, "Foley must validate loaded assets and pace grounded travel before replacing legacy steps")
local cases = 0
local function test(name, fn) fn(); cases += 1; print("PASS", name) end
test("Foley accepts only published numeric IDs and its supported sound categories", function()
	assert(Timing.asset({ id = 4212345678, duration = 1.5, category = "Foley", spatial = true }).id == 4212345678)
	for _, id in { 0, -1, 1.25, "rbxassetid://5", math.huge, 0 / 0 } do
		assert(Timing.asset({ id = id, duration = 1, category = "Foley" }) == nil)
	end
	for _, category in { "Voice", "Ambience", "Other" } do assert(Timing.asset({ id = 5, duration = 1, category = category }) == nil) end
	assert(Timing.asset({ id = 5, duration = 0, category = "Foley" }) == nil)
	assert(Timing.asset({ id = 5, duration = math.huge, category = "Foley" }) == nil)
	assert(Timing.asset({ id = 5, duration = 1, category = "Foley", spatial = "false" }) == nil)
	assert(Timing.asset(nil) == nil)
end)
test("atlas boundaries must match duration and stay inside a finite asset", function()
	local entry = Timing.asset({ id = 5, start = 12, finish = 14.5, duration = 2.5, category = "UI" })
	assert(entry.start == 12 and entry.finish == 14.5)
	for _, bad in { { start = 4, finish = 3, duration = 1 }, { start = -1, finish = 1, duration = 2 }, { start = 4, finish = 6, duration = 3 }, { start = 0 / 0, finish = 2, duration = 2 }, { start = 1, duration = 2 } } do
		bad.id, bad.category = 5, "Foley"
		assert(Timing.asset(bad) == nil)
	end
	assert(Timing.asset({ id = 5, duration = 1, category = "UI", volume = 9 }).volume == 1)
	assert(Timing.asset({ id = 5, duration = 1, category = "UI", volume = -9 }).volume == 0)
end)
test("regions stop one shots and loop only their own segment", function()
	local shot = { start = 12, finish = 14.5, loop = false }
	local position, finished = Timing.segment(14.4, shot)
	assert(position == nil and finished == false)
	position, finished = Timing.segment(14.5, shot)
	assert(position == nil and finished == true)
	for _ = 1, 20 do
		position, finished = Timing.segment(9, { start = 7, finish = 9, loop = true })
		assert(position == 7 and finished == false)
	end
	assert(Timing.deadline(10, 2, false) > 12 and Timing.deadline(10, 2, false) <= 16)
	assert(Timing.deadline(10, 2, true) == math.huge)
end)
local function sample(x, extra)
	local s = { x = x, z = 0, dt = 0.1, alive = true, grounded = true, walking = true }
	for key, value in extra or {} do s[key] = value end
	return s
end
test("steps use real horizontal travel and faster running cadence", function()
	local walk, run = Timing.newStep(), Timing.newStep()
	Timing.step(walk, sample(0)); Timing.step(run, sample(0))
	local a, b = 0, 0
	for i = 1, 20 do
		if Timing.step(walk, sample(i)) then a += 1 end
		local step = Timing.step(run, sample(i * 1.8))
		if step then b += 1; assert(step.running and step.gain <= 1) end
	end
	assert(a == 4 and b >= 6 and b <= 7)
end)
test("air dead stationary and uncommanded motion cannot make footsteps", function()
	for _, blocked in { { grounded = false }, { alive = false }, { walking = false } } do
		local state = Timing.newStep(); Timing.step(state, sample(0))
		for i = 1, 12 do assert(Timing.step(state, sample(i, blocked)) == nil) end
	end
	local still = Timing.newStep(); Timing.step(still, sample(0))
	for _ = 1, 200 do assert(Timing.step(still, sample(0)) == nil) end
end)
test("teleports and long frames reset cadence without catch up", function()
	local state = Timing.newStep(); Timing.step(state, sample(0))
	assert(Timing.step(state, sample(100)) == nil)
	assert(Timing.step(state, sample(101)) == nil)
	assert(Timing.step(state, sample(120, { dt = 1.5 })) == nil)
	assert(Timing.step(state, sample(121)) == nil)
	assert(Timing.step(state, sample(0 / 0)) == nil)
end)
test("material families and dormant creature states cannot leak effects", function()
	assert(Timing.surface("Metal") == "metal" and Timing.surface("DiamondPlate") == "metal")
	assert(Timing.surface("CorrodedMetal") == "metal" and Timing.surface("Foil") == "metal")
	assert(Timing.surface("Concrete") == "concrete" and Timing.surface(nil) == "concrete")
	assert(not Timing.creatureAudible(nil) and not Timing.creatureAudible("dormant") and not Timing.creatureAudible("disabled"))
	assert(Timing.creatureAudible("idle") and Timing.creatureAudible("chase") and Timing.creatureAudible("roar"))
	assert(Timing.creatureAudible("roam") and Timing.creatureAudible("alert"), "native creature roam/alert states must match its server state machine")
end)
test("effect caps preserve persistent breath while evicting oldest one shot", function()
	local records = { { category = "Foley", serial = 1, looped = true }, { category = "Foley", serial = 7, looped = false }, { category = "Foley", serial = 4, looped = false } }
	assert(Timing.pickVictim(records, "Foley", 4) == nil)
	assert(Timing.pickVictim(records, "Foley", 3) == 3)
	assert(Timing.pickVictim({ records[1] }, "Foley", 1) == false)
end)
print(`PASS {cases} Foley timing/validation cases (no Roblox engine)`)
