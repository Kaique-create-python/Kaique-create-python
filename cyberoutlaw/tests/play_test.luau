-- Tests CyberOutlawPlay outside Roblox: pure math, R6 poses, and the interface with real Instances.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function load(media: string)
	local source = fs.readFile("src/play.client.luau")
	assert(select(2, source:gsub("__CYBEROUTLAW_MEDIA__", "")) == 1, "the script needs one media marker")
	source = source:gsub("__CYBEROUTLAW_MEDIA__", media)
	return luau.load(source, {
		debugName = "play.client.luau",
		environment = {
			Instance = roblox.Instance, CFrame = roblox.CFrame, Vector2 = roblox.Vector2, Vector3 = roblox.Vector3,
			Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence,
			NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, Enum = roblox.Enum, UDim = roblox.UDim, UDim2 = roblox.UDim2,
			Font = roblox.Font,
		},
	})()
end

local play = load("{}")
local V3 = roblox.Vector3

-- Spring: converges without large overshoot even with a long frame.
do
	local x, v = 0, 0
	for _ = 1, 240 do
		x, v = play.spring(x, v, 10, 4, 1 / 60)
		assert(x <= 10.05, "critically damped spring does not overshoot")
	end
	assert(math.abs(x - 10) < 0.01)
	local y, w = 0, 0
	y, w = play.spring(y, w, 1, 4, 0.5)
	assert(y > 0 and y <= 1.0001, "stable at large dt")
end

-- Wheel: slot 1 at the top, clockwise, consistent with slotAngle.
for index = 1, 6 do
	local a = math.rad(play.slotAngle(index, 6))
	assert(play.slotFromVector(math.cos(a), math.sin(a), 6) == index, "angle and slot of slot " .. index)
end
assert(play.slotFromVector(0, -1, 6) == 1 and play.slotFromVector(0, 1, 6) == 4)
assert(play.slotFromVector(0, 0, 6) == nil)

-- Stamina: empties in ~7.7 s of sprinting and only lets you sprint again with 30%.
do
	local state = { value = 1, rest = 0, exhausted = false }
	for _ = 1, 480 do
		play.staminaStep(state, true, 1 / 60)
	end
	assert(state.exhausted and state.value == 0)
	for _ = 1, 60 do
		play.staminaStep(state, false, 1 / 60)
	end
	assert(state.exhausted, "the pause comes before the refill")
	for _ = 1, 120 do
		play.staminaStep(state, false, 1 / 60)
	end
	assert(not state.exhausted and state.value >= 0.3)
end

-- Spread cone: every direction inside the limit.
do
	-- Deterministic generator with the same interface as Random (NextNumber).
	local state = 7
	local rng = {}
	function rng:NextNumber(a, b)
		state = state * 48271 % 2147483647
		local t = state / 2147483647
		return if a then a + (b - a) * t else t
	end
	local look = V3.new(0.3, -0.2, -1).Unit
	for _ = 1, 300 do
		local d = play.coneDirection(look, math.rad(4), rng)
		assert(math.abs(d.Magnitude - 1) < 1e-6)
		assert(math.deg(math.acos(math.clamp(d:Dot(look), -1, 1))) <= 4.01, "spread inside the cone")
	end
	assert((play.coneDirection(look, 0, rng) - look).Magnitude < 1e-5, "no spread = the exact direction (float32)")
end

-- R6 poses: the arm points where we ask, using the real rig joints.
local CF = roblox.CFrame
local rightC0 = CF.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
local rightC1 = CF.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
local leftC0 = CF.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
local leftC1 = CF.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
local neckC0 = CF.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
local neckC1 = CF.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
local function rotation(c)
	return c - c.Position
end
local function armDown(c0, c1, transform)
	-- part1 = part0 * C0 * Transform * C1^-1 (rotation only in torso space)
	local r = rotation(c0) * transform * rotation(c1):Inverse()
	return r:VectorToWorldSpace(V3.new(0, -1, 0)), r:VectorToWorldSpace(V3.new(0, 0, -1))
end
for _, direction in { V3.new(0, 0, -1), V3.new(0, math.sin(math.rad(30)), -math.cos(math.rad(30))), V3.new(0.05, -0.55, -0.83).Unit, V3.new(-0.4, 0.1, -0.9).Unit } do
	for _, joint in { { rightC0, rightC1 }, { leftC0, leftC1 } } do
		local t = play.jointTransform(joint[1], joint[2], play.armRotation(direction, V3.new(0, 1, 0)))
		local down, palm = armDown(joint[1], joint[2], t)
		assert((down - direction.Unit).Magnitude < 1e-4, "the arm points in the requested direction")
		assert(palm.Y >= -1e-4, "the palm stays facing up/forward")
	end
end
do
	local look = V3.new(-0.5, 0.2, -0.84).Unit
	local t = play.jointTransform(neckC0, neckC1, CF.lookAt(V3.zero, look))
	local r = rotation(neckC0) * t * rotation(neckC1):Inverse()
	assert((r.LookVector - look).Magnitude < 1e-4, "the head looks where the camera looks")
end
for _, kind in { "punhos", "lamina" } do
	for t = 0, 1, 0.1 do
		local d = play.swingDirection(kind, 1, t)
		assert(math.abs(d.Magnitude - 1) < 1e-6)
	end
end
assert(play.swingDirection("punhos", 1, 0.5).Z < -0.9, "the jab reaches forward")

-- Interface with real Instances (validates names and properties).
local arsenal = luau.load(fs.readFile("src/arsenal.server.luau"), {
	debugName = "arsenal.server.luau",
	environment = { Instance = roblox.Instance, CFrame = roblox.CFrame, Vector3 = roblox.Vector3, Color3 = roblox.Color3, Enum = roblox.Enum },
})()
local defs = {}
for _, def in arsenal.WEAPONS do
	table.insert(defs, def)
end
local root = roblox.Instance.new("Folder")
local ammo = { vespa = { 9, 96 }, enxame = { 32, 192 }, trovao = { 6, 36 }, agulha = { 28, 140 } }
for _, atlas in { nil, "rbxassetid://123" } do
	for _, touch in { false, true } do
		local wheel = play.buildWheel(root, defs, nil, touch, atlas)
		assert(wheel.gui:IsA("ScreenGui") and #wheel.cards == 6)
		wheel.select(3, ammo)
		wheel.animate(0.1, 1)
		assert(wheel.cards[3].pop.Scale > 1 and wheel.cards[1].pop.Scale == 1, "the selected card stands out")
		assert(wheel.cards[3].ammo.Text == "9/96")
		if atlas then
			for index, entry in wheel.cards do
				local offset, size = play.iconRect(defs[index].id)
				assert(entry.image.Image == atlas and entry.image.ImageRectOffset == offset and entry.image.ImageRectSize == size)
			end
			assert(wheel.cards[3].halo.ImageTransparency < 1 and wheel.cards[1].halo.ImageTransparency == 1)
		end
		local card = play.buildWeaponCard(root, touch, atlas)
		card.show(defs[3], nil, ammo.vespa, nil)
		assert(card.panel:FindFirstChild("Pente").Text:find("^9"), "the card shows the magazine")
		card.show(defs[4], nil, ammo.enxame, 0.5)
		assert(#card.pips == 32)
		card.show(defs[1], nil, nil, nil)
		for _, glyph in { "tiro", "mira", "R" } do
			local button = play.touchButton(root, "Botao", "", glyph, roblox.Vector2.new(-80, -80), 30, roblox.Color3.new(1, 1, 1), atlas)
			assert(button:IsA("TextButton"))
		end
	end
end
-- Atlas: cells inside the 1024 image and without overlap.
local seen = {}
for _, key in { "punhos", "lamina", "vespa", "enxame", "trovao", "agulha", "tiro", "mira", "recarga", "arsenal" } do
	local offset, size = play.iconRect(key)
	assert(offset and offset.X + size.X <= 1024 and offset.Y + size.Y <= 1024, key)
	for _, other in seen do
		local overlap = offset.X < other[1].X + other[2].X and other[1].X < offset.X + size.X
			and offset.Y < other[1].Y + other[2].Y and other[1].Y < offset.Y + size.Y
		assert(not overlap, "atlas cells overlap: " .. key)
	end
	table.insert(seen, { offset, size })
end
print("CyberOutlawPlay: spring, wheel, stamina, cone, R6 poses, and interface with 2D and 3D icons passed")
