-- Exporta quadros das 10 animações R6 originais, tocadas pelo mesmo motor do jogo (motionStep), para a
-- prévia em three.js (o mesmo formato do gait_preview). Uma linha extra mostra a AK na mão na pose de
-- "arma baixa" do jogo, para conferir se a arma aparece.
-- Uso: lune run tools/r6_clip_preview.luau <arquivo.json> [lado|frente|tres_quartos] [linhas, ex.: 1,7]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local env = {
	Instance = roblox.Instance, CFrame = roblox.CFrame, Vector2 = roblox.Vector2, Vector3 = roblox.Vector3,
	Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, Enum = roblox.Enum,
	UDim = roblox.UDim, UDim2 = roblox.UDim2, Font = roblox.Font, utf8 = utf8,
}
local play = luau.load(fs.readFile("src/play.client.luau"):gsub("__CYBEROUTLAW_MEDIA__", "{}"), { debugName = "play.client.luau", environment = env })()
local arsenal = luau.load(fs.readFile("src/arsenal.server.luau"), {
	debugName = "arsenal.server.luau",
	environment = { Instance = roblox.Instance, CFrame = roblox.CFrame, Vector3 = roblox.Vector3, Color3 = roblox.Color3, Enum = roblox.Enum },
})()
local CF, V3 = roblox.CFrame, roblox.Vector3
local R = { 0, 0, 1, 0, 1, 0, -1, 0, 0 }
local L = { 0, 0, -1, 0, 1, 0, 1, 0, 0 }
local ROOT = { -1, 0, 0, 0, 0, 1, 0, 1, 0 }
local function cf(x, y, z, m)
	return CF.new(x, y, z, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
end
-- C0 e C1 do R6 padrão, na ordem dos dados (tronco, cabeça, braços, pernas).
local JOINTS = {
	{ cf(0, 0, 0, ROOT), cf(0, 0, 0, ROOT) },
	{ cf(0, 1, 0, ROOT), cf(0, -0.5, 0, ROOT) },
	{ cf(1, 0.5, 0, R), cf(-0.5, 0.5, 0, R) },
	{ cf(-1, 0.5, 0, L), cf(0.5, 0.5, 0, L) },
	{ cf(1, -1, 0, R), cf(0.5, 1, 0, R) },
	{ cf(-1, -1, 0, L), cf(-0.5, 1, 0, L) },
}
local NAMES = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local SIZES = { { 2, 2, 1 }, { 2, 1, 1 }, { 1, 2, 1 }, { 1, 2, 1 }, { 1, 2, 1 }, { 1, 2, 1 } }
local COLORS = { { 52, 92, 150 }, { 230, 196, 160 }, { 230, 196, 160 }, { 230, 196, 160 }, { 30, 32, 40 }, { 30, 32, 40 } }

-- Peças do R6 para as 6 transforms: parte1 = parte0 * C0 * Transform * C1:Inverse().
local function rig(hrp, transforms)
	local parts = {}
	local torso = hrp * JOINTS[1][1] * transforms[1] * JOINTS[1][2]:Inverse()
	parts[1] = torso
	for index = 2, 6 do
		parts[index] = torso * JOINTS[index][1] * transforms[index] * JOINTS[index][2]:Inverse()
	end
	return parts
end

local VIEW = process.args[2] or "lado"
local YAW = ({ lado = -math.pi / 2, frente = math.pi, tres_quartos = math.pi * 0.75 })[VIEW] or -math.pi / 2
local rows, column = {}, 0
local only = {}
for item in string.gmatch(process.args[3] or "", "%d+") do
	only[tonumber(item)] = true
end
local function wanted(line: number): boolean
	return next(only) == nil or only[line] == true
end
local function emit(line, label, hrp, parts, extra)
	for index, part in parts do
		table.insert(rows, { n = NAMES[index], c = { part:GetComponents() }, s = SIZES[index], k = COLORS[index], line = line, label = label })
	end
	for _, item in extra or {} do
		table.insert(rows, item)
	end
	local _ = hrp
end
local sequences = {
	{ name = "Parado", move = V3.zero, speed = 0, frames = 3, gap = 1.2 },
	{ name = "Andar frente", move = V3.new(0, 0, -1), speed = play.MOTION.walk, frames = 6, gap = 0.07 },
	{ name = "Correr", move = V3.new(0, 0, -1), speed = play.MOTION.sprint, frames = 6, gap = 0.032 },
	{ name = "Direita (mirando)", move = V3.new(1, 0, 0), speed = play.strafeSpeed(1, 0), frames = 4, gap = 0.1 },
	{ name = "Trás", move = V3.new(0, 0, 1), speed = play.strafeSpeed(0, 1), frames = 4, gap = 0.1 },
	{ name = "Diagonal frente-esquerda", move = V3.new(-1, 0, -1).Unit, speed = play.strafeSpeed(-1, -1), frames = 4, gap = 0.1 },
}
for line, seq in sequences do
	if not wanted(line) then
		continue
	end
	local m = play.newMotion()
	for _ = 1, 120 do
		play.motionStep(m, { move = seq.move, speed = seq.speed }, 1 / 60)
	end
	for _ = 1, seq.frames do
		local pose
		for _ = 1, math.max(1, math.floor(seq.gap * 60)) do
			pose = play.motionStep(m, { move = seq.move, speed = seq.speed }, 1 / 60)
		end
		local hrp = CF.new(column * 3.6, 3, 0) * CF.Angles(0, YAW, 0)
		column += 1
		emit(line, seq.name, hrp, rig(hrp, pose))
	end
	column += 1
end

-- AK na mão: idle do pacote com o braço direito na pose de "arma baixa" do jogo e o esquerdo apoiando.
if wanted(#sequences + 1) then
	local def
	for _, weapon in arsenal.WEAPONS do
		if weapon.id == "ak47" then
			def = weapon
		end
	end
	local model = arsenal.buildModel(def)
	local m = play.newMotion()
	local pose
	for _ = 1, 60 do
		pose = play.motionStep(m, { move = V3.zero, speed = 0 }, 1 / 60)
	end
	for frame = 1, 2 do
		-- Mesma camada de ação do jogo: postura de tiro sobre o idle e braços compensando o tronco.
		local transforms = table.clone(pose)
		for _, index in { 1, 2, 5, 6 } do
			transforms[index] = transforms[index]:Lerp(play.aimStance(index, JOINTS[index][1], JOINTS[index][2]), 1)
		end
		local direction = if frame == 1 then V3.new(0.05, -0.55, -0.83).Unit else V3.new(0, 0, -1)
		local tilt = play.torsoTilt(JOINTS[1][1], transforms[1], JOINTS[1][2])
		transforms[3], transforms[4] = play.gunArms(tilt, JOINTS[3][1], JOINTS[3][2], JOINTS[4][1], JOINTS[4][2], direction, def.alcance or 2.45)
		local hrp = CF.new(column * 3.6, 3, 0) * CF.Angles(0, YAW, 0)
		column += 1
		local parts = rig(hrp, transforms)
		local grip = parts[3] * arsenal.gripOffset(def, { Size = V3.new(1, 2, 1) })
		local extra = {}
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				local c = item.Color
				table.insert(extra, {
					n = item.Name, c = { (grip * item.CFrame):GetComponents() }, s = { item.Size.X, item.Size.Y, item.Size.Z },
					k = { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) }, line = #sequences + 1, label = "AK na mão",
				})
			end
		end
		emit(#sequences + 1, "AK na mão", hrp, parts, extra)
	end
	column += 1
end
fs.writeFile(process.args[1] or "r6.json", serde.encode("json", { parts = rows, columns = column }))
print("quadros:", column)
