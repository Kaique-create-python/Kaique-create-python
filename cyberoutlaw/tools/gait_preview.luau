-- Exporta quadros da locomoção procedural (R6) para a prévia em three.js.
-- Uso: lune run tools/gait_preview.luau <arquivo.json>
-- Usa as mesmas juntas do R6 do Roblox: parte1 = parte0 * C0 * Transform * C1:Inverse().
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local source = fs.readFile("src/play.client.luau"):gsub("__CYBEROUTLAW_MEDIA__", "{}")
local play = luau.load(source, {
	debugName = "play.client.luau",
	environment = {
		Instance = roblox.Instance, CFrame = roblox.CFrame, Vector2 = roblox.Vector2, Vector3 = roblox.Vector3,
		Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, Enum = roblox.Enum, UDim = roblox.UDim, UDim2 = roblox.UDim2,
		Font = roblox.Font, utf8 = utf8,
	},
})()
local CF, V3 = roblox.CFrame, roblox.Vector3
local R = { 0, 0, 1, 0, 1, 0, -1, 0, 0 }
local L = { 0, 0, -1, 0, 1, 0, 1, 0, 0 }
local function cf(x, y, z, m)
	return CF.new(x, y, z, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
end
local ROOT = { -1, 0, 0, 0, 0, 1, 0, 1, 0 }
local joints = {
	root = { cf(0, 0, 0, ROOT), cf(0, 0, 0, ROOT) },
	neck = { cf(0, 1, 0, ROOT), cf(0, -0.5, 0, ROOT) },
	rightArm = { cf(1, 0.5, 0, R), cf(-0.5, 0.5, 0, R) },
	leftArm = { cf(-1, 0.5, 0, L), cf(0.5, 0.5, 0, L) },
	rightLeg = { cf(1, -1, 0, R), cf(0.5, 1, 0, R) },
	leftLeg = { cf(-1, -1, 0, L), cf(-0.5, 1, 0, L) },
}
local UP = V3.new(0, 1, 0)
local function rig(hrp: CFrame, pose)
	local function solve(joint, transform, parent)
		return parent * joint[1] * transform * joint[2]:Inverse()
	end
	local torso = solve(joints.root, play.rootTransform(joints.root[1], pose.root), hrp)
	local limb = function(key, direction)
		return solve(joints[key], play.jointTransform(joints[key][1], joints[key][2], play.armRotation(direction, UP)), torso)
	end
	return {
		{ "Torso", torso, { 2, 2, 1 }, { 52, 92, 150 } },
		{ "Head", solve(joints.neck, play.jointTransform(joints.neck[1], joints.neck[2], pose.headCompensation), torso), { 2, 1, 1 }, { 230, 196, 160 } },
		{ "Right Arm", limb("rightArm", pose.rightArm), { 1, 2, 1 }, { 230, 196, 160 } },
		{ "Left Arm", limb("leftArm", pose.leftArm), { 1, 2, 1 }, { 230, 196, 160 } },
		{ "Right Leg", limb("rightLeg", pose.rightLeg), { 1, 2, 1 }, { 30, 32, 40 } },
		{ "Left Leg", limb("leftLeg", pose.leftLeg), { 1, 2, 1 }, { 30, 32, 40 } },
	}
end

local rows = {}
local sequences = {
	{ name = "Parado", velocity = V3.zero, state = "run", frames = 2, gap = 0.9 },
	{ name = "Corrida", velocity = V3.new(0, 0, -17), state = "run", frames = 6, gap = 0.105 },
	{ name = "Sprint", velocity = V3.new(0, 0, -27), state = "run", frames = 6, gap = 0.095 },
	{ name = "Lateral mirando", velocity = V3.new(11, 0, 0), state = "run", frames = 4, gap = 0.18 },
	{ name = "Salto", velocity = V3.new(0, -45, -10), state = "fall", frames = 2, gap = 0.25 },
}
local column = 0
for line, seq in sequences do
	local g = play.newGait()
	for _ = 1, 90 do
		play.gaitStep(g, { velocity = seq.velocity, state = seq.state, verticalSpeed = seq.velocity.Y }, 1 / 60)
	end
	for frame = 1, seq.frames do
		local pose
		local steps = math.max(1, math.floor(seq.gap * 60))
		for _ = 1, steps do
			pose = play.gaitStep(g, { velocity = seq.velocity, state = seq.state, verticalSpeed = seq.velocity.Y }, 1 / 60)
		end
		local x = column * 3.6
		column += 1
		local hrp = CF.new(x, 3, 0) * CF.Angles(0, -math.pi / 2, 0) -- de perfil para a câmera
		for _, part in rig(hrp, pose) do
			table.insert(rows, { n = part[1], c = { part[2]:GetComponents() }, s = part[3], k = part[4], line = line, label = seq.name })
		end
	end
	column += 1
end
fs.writeFile(process.args[1] or "gait.json", serde.encode("json", { parts = rows, columns = column }))
print("quadros exportados:", #rows / 6)
