--!strict
-- Personagens humanoides procedurais. Um corpo base (pernas, tronco, braços,
-- cabeça) + "traje" de dados + acessórios. Cada traje muda proporções, cores,
-- materiais e adiciona peças (chapéus, capas, asas, armas, barbas...).

local Rig = require(script.Parent.Rig)
local Kit = require(script.Parent.Kit)

local Figures = {}

local rgb = Color3.fromRGB
local SKIN = { rgb(255, 214, 170), rgb(224, 172, 128), rgb(176, 120, 82), rgb(120, 78, 50), rgb(92, 60, 40) }

type Outfit = {
	skin: Color3?,
	shirt: Color3,
	pants: Color3,
	shoes: Color3?,
	hair: Color3?,
	hairStyle: string?,
	mat: Enum.Material?,
	robe: Color3?,
	bulk: number?, -- largura extra
	tall: number?, -- altura extra
	headSize: number?,
	acc: { string }?, -- acessórios
	eye: Color3?,
	glowEyes: boolean?,
	pose: string?,
	accent: Color3?,
}

local OUTFITS: { [string]: Outfit } = {
	hero = { shirt = rgb(30, 90, 220), pants = rgb(25, 50, 140), shoes = rgb(200, 30, 40), hair = rgb(30, 25, 20), accent = rgb(255, 210, 40), acc = { "cape_red", "emblem", "mask" } },
	knight = { shirt = rgb(170, 175, 185), pants = rgb(140, 145, 155), shoes = rgb(90, 90, 95), mat = Enum.Material.DiamondPlate, acc = { "helmet_knight", "sword", "shield" } },
	ninja = { shirt = rgb(25, 25, 30), pants = rgb(25, 25, 30), shoes = rgb(20, 20, 20), hair = rgb(20, 20, 20), acc = { "ninja_mask", "headband", "katana_back" } },
	pirate = { shirt = rgb(235, 230, 220), pants = rgb(40, 40, 50), shoes = rgb(60, 40, 25), hair = rgb(60, 35, 20), accent = rgb(150, 30, 35), acc = { "tricorn", "eyepatch", "beard_brown", "cutlass", "vest" } },
	wizard = { shirt = rgb(70, 40, 160), pants = rgb(70, 40, 160), robe = rgb(70, 40, 160), hair = rgb(235, 235, 240), accent = rgb(255, 220, 60), acc = { "wizard_hat", "beard_white", "staff" } },
	witch = { skin = rgb(150, 200, 120), shirt = rgb(35, 25, 45), pants = rgb(35, 25, 45), robe = rgb(35, 25, 45), hair = rgb(60, 20, 70), hairStyle = "long", acc = { "witch_hat", "broom", "nose" } },
	vampire = { skin = rgb(230, 225, 235), shirt = rgb(25, 20, 30), pants = rgb(25, 20, 30), hair = rgb(15, 15, 20), accent = rgb(170, 20, 30), glowEyes = true, eye = rgb(255, 40, 40), acc = { "cape_vampire", "fangs", "collar" } },
	zombie = { skin = rgb(120, 170, 100), shirt = rgb(70, 110, 160), pants = rgb(80, 60, 45), hair = rgb(50, 60, 40), pose = "zombie", eye = rgb(220, 40, 40), acc = { "torn" } },
	skeleton = { skin = rgb(235, 232, 220), shirt = rgb(235, 232, 220), pants = rgb(235, 232, 220), shoes = rgb(235, 232, 220), bulk = -0.4, pose = "zombie", acc = { "ribs", "skull_eyes" } },
	mummy = { skin = rgb(210, 195, 160), shirt = rgb(210, 195, 160), pants = rgb(210, 195, 160), shoes = rgb(200, 185, 150), glowEyes = true, eye = rgb(120, 255, 200), pose = "zombie", acc = { "bandages" } },
	police = { shirt = rgb(40, 60, 120), pants = rgb(30, 40, 80), shoes = rgb(20, 20, 20), hair = rgb(40, 30, 20), accent = rgb(255, 200, 40), acc = { "police_cap", "badge", "pistol" } },
	soldier = { shirt = rgb(85, 100, 60), pants = rgb(75, 85, 55), shoes = rgb(45, 40, 30), acc = { "helmet_army", "rifle", "vest_army" } },
	firefighter = { shirt = rgb(200, 170, 80), pants = rgb(190, 160, 75), shoes = rgb(30, 30, 30), accent = rgb(230, 230, 80), acc = { "fire_helmet", "stripes", "extinguisher" } },
	doctor = { shirt = rgb(240, 245, 250), pants = rgb(70, 160, 140), shoes = rgb(240, 240, 240), hair = rgb(70, 45, 30), acc = { "coat", "stethoscope", "cross" } },
	clown = { shirt = rgb(255, 80, 160), pants = rgb(60, 140, 255), shoes = rgb(255, 60, 60), hair = rgb(60, 220, 90), hairStyle = "puffs", acc = { "clown_nose", "ruffle", "big_shoes" } },
	santa = { shirt = rgb(200, 25, 35), pants = rgb(200, 25, 35), shoes = rgb(25, 25, 25), hair = rgb(245, 245, 245), bulk = 0.5, acc = { "santa_hat", "beard_white", "belt", "trim" } },
	chef = { shirt = rgb(245, 245, 245), pants = rgb(50, 50, 55), shoes = rgb(30, 30, 30), hair = rgb(70, 40, 20), acc = { "toque", "apron", "mustache" } },
	astronaut = { shirt = rgb(240, 240, 245), pants = rgb(235, 235, 240), shoes = rgb(150, 150, 160), bulk = 0.35, acc = { "space_helmet", "backpack", "flag_patch" } },
	scientist = { shirt = rgb(245, 245, 250), pants = rgb(60, 70, 90), shoes = rgb(40, 40, 40), hair = rgb(200, 200, 205), hairStyle = "wild", acc = { "coat", "goggles", "flask" } },
	cowboy = { shirt = rgb(180, 90, 60), pants = rgb(60, 90, 150), shoes = rgb(110, 70, 40), hair = rgb(90, 60, 30), acc = { "cowboy_hat", "bandana", "pistol" } },
	king = { shirt = rgb(170, 30, 40), pants = rgb(120, 20, 30), robe = rgb(170, 30, 40), hair = rgb(120, 90, 50), accent = rgb(255, 200, 40), acc = { "crown", "ermine", "scepter", "beard_brown" } },
	princess = { shirt = rgb(255, 150, 200), pants = rgb(255, 150, 200), robe = rgb(255, 130, 190), hair = rgb(250, 220, 120), hairStyle = "long", acc = { "tiara", "dress" } },
	alien = { skin = rgb(140, 200, 140), shirt = rgb(150, 160, 175), pants = rgb(130, 140, 155), shoes = rgb(90, 95, 110), headSize = 1.7, bulk = -0.35, eye = rgb(10, 10, 15), acc = { "alien_eyes", "antenna", "raygun" } },
	demon = { skin = rgb(190, 40, 35), shirt = rgb(150, 30, 30), pants = rgb(60, 20, 20), shoes = rgb(40, 15, 15), glowEyes = true, eye = rgb(255, 220, 60), bulk = 0.3, acc = { "horns", "wings_bat", "tail_demon", "trident" } },
	angel = { shirt = rgb(250, 250, 255), pants = rgb(245, 245, 250), robe = rgb(250, 250, 255), hair = rgb(255, 225, 140), hairStyle = "long", acc = { "halo", "wings_feather" } },
	golem = { skin = rgb(120, 118, 115), shirt = rgb(110, 108, 105), pants = rgb(100, 98, 95), shoes = rgb(90, 88, 85), mat = Enum.Material.Slate, bulk = 0.9, headSize = 0.85, glowEyes = true, eye = rgb(90, 220, 255), acc = { "runes", "moss" } },
	yeti = { skin = rgb(130, 170, 220), shirt = rgb(240, 245, 250), pants = rgb(235, 240, 248), shoes = rgb(230, 235, 245), mat = Enum.Material.Fabric, bulk = 0.8, acc = { "fur_head", "horns_small" } },
	werewolf = { skin = rgb(110, 80, 55), shirt = rgb(100, 72, 50), pants = rgb(60, 70, 110), shoes = rgb(90, 65, 45), mat = Enum.Material.Fabric, glowEyes = true, eye = rgb(255, 220, 50), bulk = 0.3, acc = { "wolf_head", "claws", "torn" } },
	viking = { shirt = rgb(120, 85, 55), pants = rgb(80, 60, 45), shoes = rgb(70, 50, 35), hair = rgb(200, 90, 40), acc = { "viking_helmet", "beard_red", "axe", "round_shield", "fur_vest" } },
	villager = { shirt = rgb(90, 150, 90), pants = rgb(90, 80, 70), shoes = rgb(60, 45, 35), hair = rgb(80, 50, 30), acc = {} },
	footballer = { shirt = rgb(255, 220, 30), pants = rgb(30, 120, 220), shoes = rgb(20, 20, 20), hair = rgb(30, 25, 20), accent = rgb(30, 160, 70), acc = { "collar_green", "socks" } },
	goblin = { skin = rgb(110, 170, 70), shirt = rgb(110, 80, 50), pants = rgb(80, 60, 40), headSize = 1.2, acc = { "goblin_ears", "dagger", "nose" } },
	troll = { skin = rgb(120, 140, 110), shirt = rgb(100, 80, 60), pants = rgb(90, 70, 50), bulk = 1, headSize = 0.8, acc = { "club", "tusks", "belly" } },
	cyclops = { skin = rgb(200, 160, 120), shirt = rgb(120, 90, 60), pants = rgb(110, 80, 50), bulk = 0.8, eye = rgb(20, 20, 20), acc = { "cyclops_eye", "club", "loincloth" } },
	fairy = { skin = rgb(255, 225, 210), shirt = rgb(150, 230, 170), pants = rgb(150, 230, 170), robe = rgb(160, 235, 180), hair = rgb(255, 180, 220), hairStyle = "long", acc = { "wings_fairy", "flower" } },
	saci = { skin = rgb(110, 70, 45), shirt = rgb(110, 70, 45), pants = rgb(200, 40, 40), shoes = rgb(110, 70, 45), hair = rgb(20, 15, 10), acc = { "saci_cap", "pipe", "one_leg" } },
	curupira = { skin = rgb(150, 100, 60), shirt = rgb(70, 140, 60), pants = rgb(60, 120, 50), shoes = rgb(150, 100, 60), hair = rgb(255, 100, 20), hairStyle = "flame", acc = { "leaves", "backward_feet" } },
	cuca = { skin = rgb(90, 150, 70), shirt = rgb(110, 50, 140), pants = rgb(110, 50, 140), robe = rgb(110, 50, 140), hair = rgb(250, 220, 90), hairStyle = "long", acc = { "croc_snout", "staff" } },
}

-- Constrói um personagem; retorna RigResult
function Figures.build(origin: CFrame, params: { [string]: any }, variant: string): Rig.RigResult
	local o = OUTFITS[variant] or OUTFITS.villager
	local rng = params.rng
	local R = Rig.new(variant, origin, params)
	local b = R.b
	local bulk = 1 + (o.bulk or 0)
	local headS = o.headSize or 1
	local skin = o.skin or (if rng then rng:pick(SKIN) else SKIN[2])
	local mat = o.mat or Enum.Material.SmoothPlastic
	local shirt = o.shirt
	if variant == "villager" and rng then
		shirt = Color3.fromHSV(rng:float(), 0.55, 0.85)
	end
	local acc = {}
	for _, a in o.acc or {} do
		acc[a] = true
	end

	local legH, torsoH = 2, 2
	local hipY = legH
	local torsoY = hipY + torsoH / 2
	local shoulderY = hipY + torsoH * 0.9
	local headY = hipY + torsoH + 0.65 * headS
	local root = R:makeRoot(Vector3.new(2 * bulk, 2, 1), torsoY)

	-- tronco
	local torso = b:box(Vector3.new(2 * bulk, torsoH, 1 * bulk), CFrame.new(0, torsoY, 0), shirt, { role = "primary", material = mat, name = "Tronco" })
	R:join(torso, root)

	-- pernas
	local legs = {}
	for i, side in { -1, 1 } do
		if acc.one_leg and side == 1 then
			continue
		end
		local m = R:mark()
		local x = side * 0.5 * bulk
		b:box(Vector3.new(0.95 * bulk, legH, 0.95 * bulk), CFrame.new(x, legH / 2, 0), o.pants, { role = "secondary", material = mat, name = "Perna" })
		local footZ = if acc.backward_feet then 0.35 else -0.2
		b:box(Vector3.new(1 * bulk, 0.35, 1.3), CFrame.new(x, 0.18, footZ), o.shoes or Kit.darker(o.pants, 0.3), { role = "secondary", material = mat })
		if acc.big_shoes then
			b:box(Vector3.new(1.2, 0.5, 2.2), CFrame.new(x, 0.25, -0.5), o.shoes or rgb(255, 60, 60), { role = "accent" })
		end
		if acc.socks then
			b:box(Vector3.new(1, 0.7, 1), CFrame.new(x, 0.75, 0), rgb(245, 245, 245), { role = "fixed" })
		end
		legs[i] = R:group(m, torso, Vector3.new(x, hipY, 0), { kind = "leg", axis = "X", amp = 0.7, phase = if side < 0 then 0 else math.pi })
	end
	if acc.one_leg then
		-- o saci pula numa perna só: a perna fica centralizada
		local m = R:mark()
		b:box(Vector3.new(0.95, legH, 0.95), CFrame.new(0, legH / 2, 0), skin, { role = "fixed" })
		R:group(m, torso, Vector3.new(0, hipY, 0), { kind = "bob", axis = "Y", amp = 0.6, speed = 2 })
	end

	-- braços
	local armPose = if o.pose == "zombie" then CFrame.Angles(math.rad(-80), 0, 0) else CFrame.identity
	local arms = {}
	for i, side in { -1, 1 } do
		local m = R:mark()
		local x = side * (1 + 0.5) * bulk
		local shoulder = Vector3.new(x, shoulderY, 0)
		local armCf = CFrame.new(shoulder) * armPose * CFrame.new(0, -0.9, 0)
		b:box(Vector3.new(0.9 * bulk, 1.9, 0.9 * bulk), armCf, shirt, { role = "primary", material = mat, name = "Braco" })
		b:box(Vector3.new(0.85 * bulk, 0.5, 0.85 * bulk), armCf * CFrame.new(0, -1, 0), skin, { role = "fixed", material = mat })
		if acc.claws then
			b:part("wedge", Vector3.new(0.3, 0.6, 0.4), armCf * CFrame.new(0, -1.4, -0.3), rgb(240, 240, 230), { role = "fixed" })
		end
		arms[i] = R:group(m, torso, shoulder, { kind = "arm", axis = "X", amp = if o.pose == "zombie" then 0.15 else 0.6, phase = if side < 0 then math.pi else 0 })
	end
	local rightHand = Vector3.new(1.5 * bulk, shoulderY - 2, -0.2)
	if o.pose == "zombie" then
		rightHand = Vector3.new(1.5 * bulk, shoulderY - 0.2, -1.9)
	end

	-- cabeça
	local hm = R:mark()
	local head = b:box(Vector3.new(1.2 * headS, 1.2 * headS, 1.2 * headS), CFrame.new(0, headY, 0), skin, { role = "fixed", material = mat, name = "Cabeca" })
	R.head = head
	local eyeColor = o.eye or rgb(25, 25, 30)
	local eyeMat = if o.glowEyes then Enum.Material.Neon else Enum.Material.SmoothPlastic
	if acc.cyclops_eye then
		b:ball(0.7 * headS, CFrame.new(0, headY + 0.15, -0.6 * headS), rgb(250, 250, 250), { role = "fixed" })
		b:ball(0.32 * headS, CFrame.new(0, headY + 0.15, -0.9 * headS), eyeColor, { role = "eye" })
	elseif acc.alien_eyes then
		for _, side in { -1, 1 } do
			b:part("ball", Vector3.new(0.5, 0.7, 0.3) * headS, CFrame.new(side * 0.3 * headS, headY, -0.58 * headS) * CFrame.Angles(0, 0, side * 0.4), eyeColor, { role = "eye" })
		end
	elseif not acc.space_helmet then
		for _, side in { -1, 1 } do
			b:box(Vector3.new(0.2, 0.25, 0.08) * headS, CFrame.new(side * 0.28 * headS, headY + 0.1, -0.61 * headS), eyeColor, { role = "eye", material = eyeMat })
		end
		if not acc.ninja_mask and not acc.skull_eyes then
			b:box(Vector3.new(0.5, 0.08, 0.05) * headS, CFrame.new(0, headY - 0.28 * headS, -0.61 * headS), Kit.darker(skin, 0.45), { role = "fixed" })
		end
	end
	-- cabelo
	if o.hair and not acc.space_helmet then
		local hairStyle = o.hairStyle or "short"
		if hairStyle == "short" then
			b:box(Vector3.new(1.3, 0.35, 1.3) * headS, CFrame.new(0, headY + 0.6 * headS, 0.05), o.hair, { role = "fixed" })
		elseif hairStyle == "long" then
			b:box(Vector3.new(1.3, 0.35, 1.3) * headS, CFrame.new(0, headY + 0.6 * headS, 0.05), o.hair, { role = "fixed" })
			b:box(Vector3.new(1.3, 1.5, 0.35) * headS, CFrame.new(0, headY - 0.1, 0.62 * headS), o.hair, { role = "fixed" })
		elseif hairStyle == "wild" then
			for k = 0, 5 do
				local a = k / 6 * math.pi * 2
				b:ball(0.6 * headS, CFrame.new(math.cos(a) * 0.55, headY + 0.55, math.sin(a) * 0.55 + 0.1), o.hair, { role = "fixed" })
			end
		elseif hairStyle == "puffs" then
			for _, side in { -1, 1 } do
				b:ball(0.95 * headS, CFrame.new(side * 0.75 * headS, headY + 0.2, 0.1), o.hair, { role = "fixed" })
			end
		elseif hairStyle == "flame" then
			for k = -2, 2 do
				b:part("wedge", Vector3.new(0.3, 0.9, 0.5), CFrame.new(k * 0.25, headY + 0.85 * headS, 0.1 + math.abs(k) * 0.1), o.hair, { role = "fixed", material = Enum.Material.Neon })
			end
		end
	end

	local accent = o.accent or rgb(255, 210, 60)
	-- acessórios da cabeça ---------------------------------------------------
	local top = headY + 0.6 * headS
	if acc.mask then
		b:box(Vector3.new(1.25, 0.3, 0.1) * headS, CFrame.new(0, headY + 0.1, -0.62 * headS), rgb(20, 30, 90), { role = "fixed" })
	end
	if acc.helmet_knight then
		b:box(Vector3.new(1.4, 1.4, 1.4) * headS, CFrame.new(0, headY + 0.05, 0), rgb(175, 180, 190), { role = "primary", material = Enum.Material.DiamondPlate })
		b:box(Vector3.new(1.0, 0.12, 0.05), CFrame.new(0, headY + 0.1, -0.72 * headS), rgb(15, 15, 20), { role = "fixed" })
		b:part("wedge", Vector3.new(0.25, 0.8, 1.2), CFrame.new(0, top + 0.45, 0.2), rgb(200, 30, 40), { role = "accent" })
	end
	if acc.ninja_mask then
		b:box(Vector3.new(1.25, 0.75, 1.25) * headS, CFrame.new(0, headY - 0.25, 0), rgb(25, 25, 30), { role = "fixed" })
		b:box(Vector3.new(1.25, 0.4, 1.25) * headS, CFrame.new(0, headY + 0.45, 0), rgb(25, 25, 30), { role = "fixed" })
	end
	if acc.headband then
		b:box(Vector3.new(1.26, 0.18, 1.26) * headS, CFrame.new(0, headY + 0.28, 0), rgb(200, 30, 40), { role = "accent" })
		b:box(Vector3.new(0.12, 0.15, 0.9), CFrame.new(0.2, headY + 0.25, 0.95), rgb(200, 30, 40), { role = "accent" })
	end
	if acc.tricorn then
		b:part("cyl", Vector3.new(0.2, 2.0, 2.0), CFrame.new(0, top + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(25, 25, 30), { role = "fixed" })
		b:box(Vector3.new(1.2, 0.6, 1.2), CFrame.new(0, top + 0.45, 0), rgb(25, 25, 30), { role = "fixed" })
		b:box(Vector3.new(0.3, 0.3, 0.05), CFrame.new(0, top + 0.5, -0.62), rgb(240, 240, 240), { role = "fixed" })
	end
	if acc.eyepatch then
		b:box(Vector3.new(0.35, 0.35, 0.08), CFrame.new(0.28, headY + 0.1, -0.64 * headS), rgb(15, 15, 15), { role = "fixed" })
	end
	if acc.wizard_hat or acc.witch_hat then
		local col = if acc.wizard_hat then (o.robe or shirt) else rgb(25, 20, 30)
		b:part("cyl", Vector3.new(0.15, 2.2, 2.2), CFrame.new(0, top + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), col, { role = "primary" })
		b:cone(2.4, 1.3, CFrame.new(0, top + 0.1, 0) * CFrame.Angles(math.rad(-8), 0, 0), col, 4, { role = "primary" })
		if acc.wizard_hat then
			b:ball(0.35, CFrame.new(0.2, top + 1.1, -0.5), accent, { role = "accent", material = Enum.Material.Neon })
		end
	end
	if acc.nose then
		b:part("wedge", Vector3.new(0.25, 0.5, 0.5), CFrame.new(0, headY, -0.8 * headS) * CFrame.Angles(math.rad(180), 0, 0), Kit.darker(skin, 0.1), { role = "fixed" })
	end
	if acc.fangs then
		for _, side in { -1, 1 } do
			b:part("wedge", Vector3.new(0.1, 0.2, 0.06), CFrame.new(side * 0.12, headY - 0.38, -0.62) * CFrame.Angles(math.rad(180), 0, 0), rgb(255, 255, 255), { role = "fixed" })
		end
	end
	if acc.police_cap then
		b:part("cyl", Vector3.new(0.45, 1.35, 1.35), CFrame.new(0, top + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(30, 40, 90), { role = "fixed" })
		b:box(Vector3.new(1.1, 0.1, 0.5), CFrame.new(0, top - 0.05, -0.75), rgb(20, 20, 20), { role = "fixed" })
		b:box(Vector3.new(0.3, 0.3, 0.05), CFrame.new(0, top + 0.15, -0.68), accent, { role = "accent" })
	end
	if acc.helmet_army or acc.fire_helmet then
		local col = if acc.fire_helmet then rgb(200, 30, 30) else rgb(80, 95, 55)
		b:part("ball", Vector3.new(1.55, 1.2, 1.55) * headS, CFrame.new(0, top - 0.05, 0), col, { role = "fixed" })
		b:part("cyl", Vector3.new(0.12, 1.9, 1.9), CFrame.new(0, top - 0.25, 0.05) * CFrame.Angles(0, 0, math.rad(90)), col, { role = "fixed" })
	end
	if acc.santa_hat then
		b:part("cyl", Vector3.new(0.35, 1.35, 1.35), CFrame.new(0, top + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(250, 250, 250), { role = "fixed" })
		b:cone(1.6, 1.25, CFrame.new(0, top + 0.15, 0.1) * CFrame.Angles(math.rad(25), 0, 0), rgb(200, 25, 35), 3, { role = "fixed" })
		b:ball(0.4, CFrame.new(0, top + 1.45, 0.75), rgb(250, 250, 250), { role = "fixed" })
	end
	if acc.toque then
		b:part("cyl", Vector3.new(1.3, 1.25, 1.25), CFrame.new(0, top + 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(250, 250, 250), { role = "fixed" })
		b:ball(1.5, CFrame.new(0, top + 1.3, 0), rgb(250, 250, 250), { role = "fixed" })
	end
	if acc.space_helmet then
		b:ball(2.0 * headS, CFrame.new(0, headY, 0), rgb(240, 240, 245), { role = "fixed" })
		b:part("ball", Vector3.new(1.5, 1.1, 0.6), CFrame.new(0, headY + 0.05, -0.75), rgb(255, 190, 60), { role = "fixed", material = Enum.Material.Glass, reflectance = 0.4 })
	end
	if acc.goggles then
		for _, side in { -1, 1 } do
			b:part("cyl", Vector3.new(0.15, 0.4, 0.4), CFrame.new(side * 0.3, headY + 0.12, -0.65) * CFrame.Angles(0, math.rad(90), 0), rgb(120, 200, 255), { role = "fixed", material = Enum.Material.Glass })
		end
	end
	if acc.cowboy_hat then
		b:part("cyl", Vector3.new(0.12, 2.4, 2.4), CFrame.new(0, top + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(140, 95, 50), { role = "fixed" })
		b:box(Vector3.new(1.2, 0.7, 1.2), CFrame.new(0, top + 0.4, 0), rgb(140, 95, 50), { role = "fixed" })
	end
	if acc.bandana then
		b:part("wedge", Vector3.new(1.25, 0.6, 0.4), CFrame.new(0, headY - 0.45, -0.5) * CFrame.Angles(math.rad(180), 0, 0), rgb(200, 30, 40), { role = "accent" })
	end
	if acc.crown or acc.tiara then
		local n = if acc.crown then 6 else 5
		local r = if acc.crown then 0.55 else 0.5
		for k = 0, n - 1 do
			local a = k / n * math.pi * 2
			b:part("wedge", Vector3.new(0.25, if acc.crown then 0.55 else 0.35, 0.18), CFrame.new(math.cos(a) * r, top + 0.25, math.sin(a) * r) * CFrame.Angles(0, -a + math.pi / 2, 0), rgb(255, 205, 50), { role = "fixed", material = Enum.Material.Foil })
		end
		b:part("cyl", Vector3.new(0.25, r * 2.2, r * 2.2), CFrame.new(0, top + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 205, 50), { role = "fixed", material = Enum.Material.Foil })
		b:ball(0.2, CFrame.new(0, top + 0.1, -r - 0.05), rgb(220, 30, 60), { role = "fixed", material = Enum.Material.Neon })
	end
	if acc.antenna then
		for _, side in { -1, 1 } do
			b:beam(Vector3.new(side * 0.3, top, 0), Vector3.new(side * 0.5, top + 0.9, 0), 0.08, skin, { role = "fixed" })
			b:ball(0.25, CFrame.new(side * 0.5, top + 0.95, 0), rgb(255, 80, 200), { role = "accent", material = Enum.Material.Neon })
		end
	end
	if acc.horns or acc.horns_small or acc.viking_helmet then
		local hs = if acc.horns_small then 0.6 else 1
		local hc = if acc.viking_helmet then rgb(240, 235, 220) else rgb(40, 30, 30)
		if acc.viking_helmet then
			b:part("ball", Vector3.new(1.5, 1.1, 1.5), CFrame.new(0, top - 0.1, 0), rgb(150, 150, 160), { role = "fixed", material = Enum.Material.Metal })
		end
		for _, side in { -1, 1 } do
			b:part("wedge", Vector3.new(0.3, 0.9 * hs, 0.5), CFrame.new(side * 0.6 * headS, top + 0.3, 0) * CFrame.Angles(0, 0, side * -0.5), hc, { role = "fixed" })
		end
	end
	if acc.halo then
		for k = 0, 9 do
			local a = k / 10 * math.pi * 2
			b:box(Vector3.new(0.3, 0.1, 0.18), CFrame.new(math.cos(a) * 0.7, top + 0.6, math.sin(a) * 0.7) * CFrame.Angles(0, -a, 0), rgb(255, 225, 90), { role = "fixed", material = Enum.Material.Neon })
		end
	end
	if acc.wolf_head then
		b:box(Vector3.new(0.7, 0.55, 0.8), CFrame.new(0, headY - 0.1, -0.9), Kit.darker(skin, 0.05), { role = "fixed", material = Enum.Material.Fabric })
		b:box(Vector3.new(0.25, 0.2, 0.2), CFrame.new(0, headY + 0.05, -1.3), rgb(20, 20, 20), { role = "fixed" })
		for _, side in { -1, 1 } do
			b:part("wedge", Vector3.new(0.2, 0.6, 0.4), CFrame.new(side * 0.4, top + 0.25, 0.1), skin, { role = "fixed" })
		end
	end
	if acc.fur_head then
		b:ball(1.7 * headS, CFrame.new(0, headY + 0.1, 0.15), rgb(240, 245, 250), { role = "primary", material = Enum.Material.Fabric })
	end
	if acc.goblin_ears then
		for _, side in { -1, 1 } do
			b:part("wedge", Vector3.new(0.15, 0.5, 1.0), CFrame.new(side * 0.85 * headS, headY + 0.1, 0) * CFrame.Angles(0, side * math.rad(90), 0), skin, { role = "fixed" })
		end
	end
	if acc.tusks then
		for _, side in { -1, 1 } do
			b:part("wedge", Vector3.new(0.15, 0.35, 0.15), CFrame.new(side * 0.3, headY - 0.35, -0.55), rgb(250, 245, 230), { role = "fixed" })
		end
	end
	if acc.croc_snout then
		b:box(Vector3.new(0.8, 0.5, 1.4), CFrame.new(0, headY - 0.15, -1.1), skin, { role = "fixed" })
		for k = -2, 2 do
			b:part("wedge", Vector3.new(0.1, 0.15, 0.1), CFrame.new(0.38, headY - 0.42, -1.1 + k * 0.25) * CFrame.Angles(math.rad(180), 0, 0), rgb(255, 255, 255), { role = "fixed" })
		end
	end
	if acc.saci_cap then
		b:cone(1.2, 1.3, CFrame.new(0, top - 0.05, 0.1) * CFrame.Angles(math.rad(-20), 0, 0), rgb(220, 30, 30), 3, { role = "fixed" })
	end
	if acc.pipe then
		b:box(Vector3.new(0.12, 0.12, 0.6), CFrame.new(0.2, headY - 0.3, -0.85), rgb(90, 55, 30), { role = "fixed" })
		b:part("cyl", Vector3.new(0.35, 0.25, 0.25), CFrame.new(0.2, headY - 0.18, -1.15) * CFrame.Angles(0, 0, math.rad(90)), rgb(90, 55, 30), { role = "fixed" })
	end
	if acc.beard_white or acc.beard_brown or acc.beard_red then
		local bc = if acc.beard_white then rgb(240, 240, 245) elseif acc.beard_red then rgb(200, 90, 40) else rgb(90, 60, 35)
		b:part("wedge", Vector3.new(1.1, 1.0, 0.45), CFrame.new(0, headY - 0.75, -0.45) * CFrame.Angles(0, math.rad(180), math.rad(180)), bc, { role = "fixed" })
	end
	if acc.mustache then
		b:box(Vector3.new(0.7, 0.15, 0.1), CFrame.new(0, headY - 0.18, -0.64), rgb(70, 40, 20), { role = "fixed" })
	end
	if acc.clown_nose then
		b:ball(0.35, CFrame.new(0, headY - 0.02, -0.7), rgb(255, 30, 40), { role = "fixed" })
	end
	if acc.skull_eyes then
		for _, side in { -1, 1 } do
			b:box(Vector3.new(0.3, 0.3, 0.06), CFrame.new(side * 0.28, headY + 0.1, -0.62), rgb(10, 10, 10), { role = "fixed" })
		end
		b:box(Vector3.new(0.6, 0.15, 0.06), CFrame.new(0, headY - 0.3, -0.62), rgb(20, 20, 20), { role = "fixed" })
	end
	R:group(hm, torso, Vector3.new(0, hipY + torsoH, 0), { kind = "head", axis = "Y", amp = 0.15, speed = 0.4 })
	R:setMouth(head, Vector3.new(0, -0.2, -0.7 * headS))

	-- acessórios do corpo ----------------------------------------------------
	local back = 0.5 * bulk + 0.05
	if acc.cape_red or acc.cape_vampire then
		local m = R:mark()
		local col = if acc.cape_red then rgb(200, 25, 35) else rgb(25, 20, 30)
		b:box(Vector3.new(2.1 * bulk, 3.6, 0.12), CFrame.new(0, shoulderY - 1.7, back + 0.1), col, { role = "fixed", name = "Capa" })
		if acc.cape_vampire then
			b:box(Vector3.new(2.0 * bulk, 3.5, 0.05), CFrame.new(0, shoulderY - 1.7, back + 0.03), o.accent or rgb(170, 20, 30), { role = "accent" })
		end
		R:group(m, torso, Vector3.new(0, shoulderY, back), { kind = "cape", axis = "X", amp = 0.25, speed = 0.8 })
	end
	if acc.collar then
		b:part("wedge", Vector3.new(2.2, 0.9, 0.3), CFrame.new(0, shoulderY + 0.4, back + 0.15), rgb(25, 20, 30), { role = "fixed" })
	end
	if acc.emblem then
		b:box(Vector3.new(0.9, 0.9, 0.08), CFrame.new(0, torsoY + 0.2, -0.54 * bulk) * CFrame.Angles(0, 0, math.rad(45)), accent, { role = "accent" })
	end
	if acc.badge then
		b:box(Vector3.new(0.35, 0.4, 0.06), CFrame.new(-0.5, torsoY + 0.45, -0.53), accent, { role = "fixed", material = Enum.Material.Foil })
	end
	if acc.vest or acc.fur_vest or acc.vest_army then
		local vc = if acc.fur_vest then rgb(150, 120, 90) elseif acc.vest_army then rgb(60, 70, 45) else (o.accent or rgb(120, 40, 40))
		b:box(Vector3.new(2.1 * bulk, 1.9, 1.1 * bulk), CFrame.new(0, torsoY, 0), vc, { role = "secondary", material = if acc.fur_vest then Enum.Material.Fabric else Enum.Material.SmoothPlastic })
		b:box(Vector3.new(0.5, 1.92, 1.12 * bulk), CFrame.new(0, torsoY, 0), shirt, { role = "primary" })
	end
	if acc.belt then
		b:box(Vector3.new(2.05 * bulk, 0.3, 1.05 * bulk), CFrame.new(0, hipY + 0.25, 0), rgb(20, 20, 20), { role = "fixed" })
		b:box(Vector3.new(0.45, 0.32, 1.07 * bulk), CFrame.new(0, hipY + 0.25, 0), rgb(255, 205, 50), { role = "fixed", material = Enum.Material.Foil })
	end
	if acc.trim or acc.ermine then
		b:box(Vector3.new(2.1 * bulk, 0.3, 1.1 * bulk), CFrame.new(0, hipY + 0.05, 0), rgb(250, 250, 250), { role = "fixed", material = Enum.Material.Fabric })
		b:box(Vector3.new(0.3, 2, 1.1 * bulk), CFrame.new(0, torsoY, -0.02), rgb(250, 250, 250), { role = "fixed", material = Enum.Material.Fabric })
	end
	if acc.coat then
		b:box(Vector3.new(2.15 * bulk, 3, 1.1 * bulk), CFrame.new(0, hipY + 0.5, 0), rgb(245, 245, 250), { role = "fixed" })
	end
	if acc.stethoscope then
		b:box(Vector3.new(0.1, 1.0, 0.1), CFrame.new(0.3, torsoY + 0.3, -0.55), rgb(40, 40, 50), { role = "fixed" })
		b:ball(0.25, CFrame.new(0.3, torsoY - 0.25, -0.6), rgb(190, 190, 200), { role = "fixed", material = Enum.Material.Metal })
	end
	if acc.cross then
		b:box(Vector3.new(0.5, 0.15, 0.06), CFrame.new(-0.5, torsoY + 0.45, -0.58), rgb(220, 30, 40), { role = "fixed" })
		b:box(Vector3.new(0.15, 0.5, 0.06), CFrame.new(-0.5, torsoY + 0.45, -0.58), rgb(220, 30, 40), { role = "fixed" })
	end
	if acc.apron then
		b:box(Vector3.new(1.7, 2.6, 0.08), CFrame.new(0, hipY + 0.3, -0.54), rgb(250, 250, 250), { role = "fixed" })
	end
	if acc.ruffle then
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			b:ball(0.55, CFrame.new(math.cos(a) * 0.8, hipY + torsoH + 0.05, math.sin(a) * 0.5), rgb(250, 250, 250), { role = "fixed" })
		end
	end
	if acc.collar_green then
		b:box(Vector3.new(0.8, 0.25, 0.08), CFrame.new(0, shoulderY + 0.05, -0.54), accent, { role = "accent" })
		b:box(Vector3.new(2.02 * bulk, 0.25, 1.02 * bulk), CFrame.new(0, hipY + 0.1, 0), accent, { role = "accent" })
	end
	if acc.stripes then
		for _, y in { torsoY - 0.4, hipY - 0.6 } do
			b:box(Vector3.new(2.06 * bulk, 0.18, 1.06 * bulk), CFrame.new(0, y, 0), accent, { role = "fixed", material = Enum.Material.Neon })
		end
	end
	if acc.ribs then
		for k = 0, 3 do
			b:box(Vector3.new(1.9, 0.14, 0.15), CFrame.new(0, torsoY + 0.6 - k * 0.38, -0.5), rgb(30, 30, 30), { role = "fixed" })
		end
	end
	if acc.bandages then
		for k = 0, 6 do
			b:box(Vector3.new(2.05 * bulk, 0.1, 1.05 * bulk), CFrame.new(0, 0.4 + k * 0.6, 0) * CFrame.Angles(0, 0, math.rad(if k % 2 == 0 then 6 else -6)), rgb(180, 165, 130), { role = "fixed" })
		end
	end
	if acc.torn then
		b:box(Vector3.new(0.6, 0.5, 0.06), CFrame.new(0.4, torsoY - 0.3, -0.53), skin, { role = "fixed" })
		b:box(Vector3.new(0.5, 0.4, 0.06), CFrame.new(-0.5, hipY - 0.8, -0.5), skin, { role = "fixed" })
	end
	if acc.runes then
		for k = 0, 2 do
			b:box(Vector3.new(0.5, 0.12, 0.06), CFrame.new(0, torsoY + 0.4 - k * 0.4, -0.52 * bulk), rgb(90, 220, 255), { role = "accent", material = Enum.Material.Neon })
		end
	end
	if acc.moss then
		b:box(Vector3.new(1.2, 0.3, 1.1), CFrame.new(-0.6 * bulk, shoulderY + 0.25, 0), rgb(80, 140, 60), { role = "fixed", material = Enum.Material.Grass })
	end
	if acc.belly then
		b:ball(2.0, CFrame.new(0, torsoY - 0.3, -0.45), o.skin or skin, { role = "fixed" })
	end
	if acc.loincloth then
		b:box(Vector3.new(2.0 * bulk, 0.9, 1.1 * bulk), CFrame.new(0, hipY - 0.2, 0), rgb(120, 80, 45), { role = "fixed" })
	end
	if acc.leaves then
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			b:part("wedge", Vector3.new(0.5, 0.8, 0.3), CFrame.new(math.cos(a) * 0.9, hipY - 0.2, math.sin(a) * 0.5) * CFrame.Angles(math.rad(180), a, 0), rgb(60, 160, 60), { role = "fixed", material = Enum.Material.Grass })
		end
	end
	if acc.flower then
		b:ball(0.4, CFrame.new(0.5, top, -0.2), rgb(255, 120, 180), { role = "accent", material = Enum.Material.Neon })
	end
	if acc.backpack then
		b:box(Vector3.new(1.6 * bulk, 1.8, 0.8), CFrame.new(0, torsoY, back + 0.4), rgb(200, 200, 210), { role = "fixed" })
	end
	if acc.flag_patch then
		b:box(Vector3.new(0.5, 0.35, 0.05), CFrame.new(-0.6 * bulk, torsoY + 0.5, -0.54 * bulk), rgb(40, 160, 70), { role = "fixed" })
		b:box(Vector3.new(0.25, 0.18, 0.06), CFrame.new(-0.6 * bulk, torsoY + 0.5, -0.55 * bulk), rgb(255, 220, 40), { role = "fixed" })
	end
	if acc.dress or o.robe then
		local col = o.robe or shirt
		b:part("cyl", Vector3.new(2.3, 2.6 * bulk, 2.6 * bulk), CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.rad(90)), col, { role = "primary" })
		b:part("cyl", Vector3.new(1, 2.2 * bulk, 2.2 * bulk), CFrame.new(0, 2.4, 0) * CFrame.Angles(0, 0, math.rad(90)), col, { role = "primary" })
	end

	-- asas e cauda -----------------------------------------------------------
	if acc.wings_bat or acc.wings_feather or acc.wings_fairy then
		for _, side in { -1, 1 } do
			local m = R:mark()
			local col = if acc.wings_bat then rgb(60, 20, 25) elseif acc.wings_fairy then rgb(200, 240, 255) else rgb(250, 250, 255)
			local matW = if acc.wings_fairy then Enum.Material.Glass else Enum.Material.SmoothPlastic
			local span = if acc.wings_fairy then 2.2 else 3.2
			b:part("wedge", Vector3.new(0.1, 2.4, span), CFrame.new(side * (0.6 + span / 2), shoulderY - 0.4, back + 0.3) * CFrame.Angles(0, side * math.rad(90), 0), col, { role = "fixed", material = matW, transparency = if acc.wings_fairy then 0.35 else 0 })
			b:part("wedge", Vector3.new(0.1, 1.2, span * 0.8), CFrame.new(side * (0.6 + span * 0.4), shoulderY - 1.6, back + 0.3) * CFrame.Angles(math.rad(180), side * math.rad(90), 0), col, { role = "fixed", material = matW, transparency = if acc.wings_fairy then 0.35 else 0 })
			R:group(m, torso, Vector3.new(side * 0.5, shoulderY - 0.4, back), { kind = "wing", axis = "Y", amp = 0.45, phase = if side < 0 then 0 else math.pi, speed = if acc.wings_fairy then 3 else 1.2 })
		end
	end
	if acc.tail_demon then
		local m = R:mark()
		b:beam(Vector3.new(0, hipY + 0.2, back), Vector3.new(0, hipY - 0.6, back + 2), 0.2, skin, { role = "fixed" })
		b:part("wedge", Vector3.new(0.1, 0.5, 0.5), CFrame.new(0, hipY - 0.6, back + 2.2), skin, { role = "fixed" })
		R:group(m, torso, Vector3.new(0, hipY + 0.2, back), { kind = "tail", axis = "Y", amp = 0.5 })
	end

	-- itens nas mãos ---------------------------------------------------------
	local rh = arms[2] or torso
	local hand = rightHand
	local function inHand(fn: () -> ())
		local m = R:mark()
		fn()
		local g = R:group(m, rh)
		return g
	end
	if acc.sword or acc.katana_back or acc.cutlass or acc.dagger then
		inHand(function()
			local len = if acc.dagger then 1.2 elseif acc.cutlass then 2.4 else 3.2
			local cf = if acc.katana_back then CFrame.new(0, torsoY + 0.3, back + 0.15) * CFrame.Angles(0, 0, math.rad(40)) else CFrame.new(hand) * CFrame.new(0, 0, -len / 2)
			b:box(Vector3.new(0.18, 0.4, len), cf, rgb(220, 225, 235), { role = "accent", material = Enum.Material.Metal })
			b:box(Vector3.new(0.9, 0.18, 0.2), cf * CFrame.new(0, 0, len / 2), rgb(120, 90, 40), { role = "fixed" })
		end)
	end
	if acc.shield or acc.round_shield then
		local lh = arms[1] or torso
		local m = R:mark()
		local x = -1.5 * bulk - 0.5
		if acc.round_shield then
			b:part("cyl", Vector3.new(0.25, 2.2, 2.2), CFrame.new(x, shoulderY - 1.4, -0.2), rgb(150, 90, 50), { role = "fixed", material = Enum.Material.WoodPlanks })
			b:part("cyl", Vector3.new(0.3, 0.6, 0.6), CFrame.new(x - 0.05, shoulderY - 1.4, -0.2), rgb(170, 170, 180), { role = "fixed", material = Enum.Material.Metal })
		else
			b:box(Vector3.new(0.25, 2.2, 1.7), CFrame.new(x, shoulderY - 1.4, -0.2), rgb(40, 70, 160), { role = "accent" })
			b:box(Vector3.new(0.3, 1.2, 0.3), CFrame.new(x - 0.03, shoulderY - 1.4, -0.2), rgb(255, 210, 50), { role = "fixed" })
		end
		R:group(m, lh)
	end
	if acc.staff or acc.scepter or acc.trident then
		inHand(function()
			local len = if acc.scepter then 2.2 else 4.5
			b:part("cyl", Vector3.new(len, 0.25, 0.25), CFrame.new(hand + Vector3.new(0, len / 2 - 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(120, 80, 40), { role = "fixed" })
			if acc.trident then
				for k = -1, 1 do
					b:part("wedge", Vector3.new(0.12, 0.8, 0.2), CFrame.new(hand + Vector3.new(k * 0.35, len - 0.2, 0)), rgb(30, 30, 30), { role = "fixed" })
				end
			else
				b:ball(0.7, CFrame.new(hand + Vector3.new(0, len - 0.4, 0)), accent, { role = "accent", material = Enum.Material.Neon })
			end
		end)
	end
	if acc.pistol or acc.raygun or acc.rifle or acc.extinguisher then
		inHand(function()
			if acc.extinguisher then
				b:cylY(1.4, 0.6, CFrame.new(hand + Vector3.new(0, 0.1, -0.3)), rgb(220, 30, 30), { role = "fixed" })
			else
				local len = if acc.rifle then 2.6 else 1.1
				local col = if acc.raygun then rgb(120, 230, 255) else rgb(40, 40, 45)
				b:box(Vector3.new(0.25, 0.35, len), CFrame.new(hand + Vector3.new(0, 0.1, -len / 2)), col, { role = if acc.raygun then "accent" else "fixed", material = if acc.raygun then Enum.Material.Neon else Enum.Material.Metal })
			end
		end)
	end
	if acc.club or acc.axe then
		inHand(function()
			b:part("cyl", Vector3.new(3, 0.35, 0.35), CFrame.new(hand + Vector3.new(0, 0.6, -0.4)) * CFrame.Angles(0, 0, math.rad(90)), rgb(110, 75, 40), { role = "fixed", material = Enum.Material.Wood })
			if acc.axe then
				b:part("wedge", Vector3.new(0.15, 0.9, 1), CFrame.new(hand + Vector3.new(0, 1.8, -0.9)), rgb(190, 190, 200), { role = "fixed", material = Enum.Material.Metal })
			else
				b:ball(1.1, CFrame.new(hand + Vector3.new(0, 2.1, -0.4)), rgb(110, 75, 40), { role = "fixed", material = Enum.Material.Wood })
			end
		end)
	end
	if acc.flask then
		inHand(function()
			b:ball(0.6, CFrame.new(hand + Vector3.new(0, 0.2, -0.2)), rgb(120, 255, 90), { role = "accent", material = Enum.Material.Neon, transparency = 0.2 })
		end)
	end
	if acc.broom then
		local m = R:mark()
		b:part("cyl", Vector3.new(4, 0.22, 0.22), CFrame.new(0, hipY - 0.3, 0) * CFrame.Angles(0, math.rad(90), 0), rgb(120, 80, 40), { role = "fixed" })
		b:part("cyl", Vector3.new(1, 0.8, 0.8), CFrame.new(0, hipY - 0.3, 2.2) * CFrame.Angles(0, math.rad(90), 0), rgb(200, 170, 90), { role = "fixed" })
		R:group(m, torso)
	end

	local result = R:finish({
		hp = params.hp or 100,
		speed = params.speed or 16,
		hipHeight = legH,
		height = headY + 0.6 * headS,
		radius = 1.2 * bulk,
		flying = params.fly == true,
	})
	return result
end

Figures.Outfits = OUTFITS

return Figures
