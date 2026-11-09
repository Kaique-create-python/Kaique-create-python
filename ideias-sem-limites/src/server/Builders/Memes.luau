--!strict
-- Criaturas "meme" e personagens especiais com corpo próprio (versões originais):
-- Tronco Tum-Tum, Tubarão Patinador, Crocodilo Bombardeiro, Bailarina Cappuccino,
-- Macaco Banana, Elefante Cacto, Arbusto-Bomba, Privada Cantora, Monstro de
-- Pelúcia, Urso Animatrônico, Ouriço Veloz e Ratinho Elétrico.
-- Coordenadas locais: chão em y = 0, frente = -Z.

local Rig = require(script.Parent.Rig)
local Kit = require(script.Parent.Kit)

local Memes = {}

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new

type Builder = (CFrame, { [string]: any }) -> Rig.RigResult

-- olhos de desenho animado olhando para frente (-Z) a partir de `center`
local function eyes(b: any, center: Vector3, spread: number, size: number, pupil: Color3?)
	for _, side in { -1, 1 } do
		local p = center + V(side * spread, 0, 0)
		b:ball(size, CF(p), rgb(250, 250, 252), { role = "fixed" })
		b:ball(size * 0.55, CF(p + V(side * -0.03, -0.02, -size * 0.32)), pupil or rgb(20, 20, 25), { role = "eye" })
		b:ball(size * 0.18, CF(p + V(side * -0.1 * size, size * 0.12, -size * 0.47)), rgb(255, 255, 255), { role = "fixed", material = Enum.Material.Neon })
	end
end

-- pernas simples ligadas a `parent` (alternadas ao andar)
local function legs(R: any, parent: BasePart, xs: { number }, hipY: number, legH: number, thick: number, color: Color3, foot: Color3?, footLen: number?)
	local b = R.b
	for i, x in xs do
		local m = R:mark()
		b:box(V(thick, legH, thick), CF(x, hipY - legH / 2, 0), color, { role = "secondary" })
		if foot then
			b:box(V(thick * 1.2, 0.35, footLen or thick * 1.6), CF(x, 0.18, -0.15), foot, { role = "fixed" })
		end
		R:group(m, parent, V(x, hipY, 0), { kind = "leg", axis = "X", amp = 0.75, phase = if i % 2 == 0 then math.pi else 0 })
	end
end

local function arm(R: any, parent: BasePart, shoulder: Vector3, len: number, thick: number, color: Color3, hand: Color3?, side: number, pose: CFrame?): BasePart?
	local b = R.b
	local m = R:mark()
	local cf = CF(shoulder) * (pose or CFrame.identity) * CF(0, -len / 2, 0)
	b:box(V(thick, len, thick), cf, color, { role = "primary" })
	if hand then
		b:ball(thick * 1.25, cf * CF(0, -len / 2, 0), hand, { role = "fixed" })
	end
	return R:group(m, parent, shoulder, { kind = "arm", axis = "X", amp = 0.6, phase = if side < 0 then math.pi else 0 })
end

local B: { [string]: Builder } = {}

-- TRONCO TUM-TUM: tronco vivo com taco, toca "tum tum tum" -------------------------
B.tum_tum_log = function(origin, params)
	local R = Rig.new("TroncoTumTum", origin, params)
	local b = R.b
	local wood, bark = rgb(176, 124, 74), rgb(110, 72, 40)
	local legH, bodyH = 1.3, 4.4
	local cy = legH + bodyH / 2
	local root = R:makeRoot(V(2.2, bodyH, 2.2), cy)
	local body = b:cylY(bodyH, 2.3, CF(0, cy, 0), wood, { role = "primary", material = Enum.Material.Wood, name = "Tronco" })
	R:join(body, root)
	for k = 0, 3 do
		b:cylY(0.12, 2.36, CF(0, legH + 0.5 + k * 1.1, 0), bark, { role = "secondary", material = Enum.Material.Wood })
	end
	b:cylY(0.1, 2.0, CF(0, legH + bodyH + 0.04, 0), rgb(220, 180, 120), { role = "fixed", material = Enum.Material.Wood })
	b:cylY(0.11, 1.0, CF(0, legH + bodyH + 0.05, 0), rgb(190, 140, 90), { role = "fixed", material = Enum.Material.Wood })
	-- rosto entalhado
	eyes(b, V(0, cy + 1.0, -1.05), 0.45, 0.62)
	b:box(V(1.0, 0.35, 0.12), CF(0, cy + 0.15, -1.13), rgb(50, 30, 15), { role = "fixed" })
	b:box(V(0.8, 0.12, 0.13), CF(0, cy + 0.05, -1.14), rgb(240, 235, 225), { role = "fixed" })
	for _, side in { -1, 1 } do
		b:box(V(0.5, 0.1, 0.1), CF(side * 0.45, cy + 1.5, -1.12) * CFrame.Angles(0, 0, side * 0.35), rgb(60, 35, 18), { role = "fixed" })
	end
	R.head = body
	R:setMouth(body, V(0, 0.2, -1.2))
	-- braços e taco
	arm(R, body, V(-1.3, cy + 0.4, 0), 1.8, 0.45, wood, wood, -1)
	local m = R:mark()
	local shoulder = V(1.3, cy + 0.4, 0)
	b:box(V(0.45, 1.8, 0.45), CF(shoulder) * CF(0, -0.9, 0), wood, { role = "primary", material = Enum.Material.Wood })
	b:part("cyl", V(3.4, 0.35, 0.35), CF(shoulder + V(0.15, -1.2, -1.5)) * CFrame.Angles(0, math.rad(90), math.rad(20)), rgb(225, 200, 150), { role = "accent", material = Enum.Material.Wood })
	b:part("cyl", V(1.2, 0.55, 0.55), CF(shoulder + V(0.15, -0.6, -3.0)) * CFrame.Angles(0, math.rad(90), math.rad(20)), rgb(225, 200, 150), { role = "accent", material = Enum.Material.Wood })
	R:group(m, body, shoulder, { kind = "arm", axis = "X", amp = 0.9, phase = 0 })
	legs(R, body, { -0.55, 0.55 }, legH, legH, 0.55, wood, bark)
	return R:finish({ hp = params.hp or 400, speed = params.speed or 18, hipHeight = legH, height = legH + bodyH + 0.2, radius = 1.4 })
end

-- TUBARÃO PATINADOR: tubarão em pé sobre duas pernas com patins --------------------
B.skate_shark = function(origin, params)
	local R = Rig.new("TubaraoPatinador", origin, params)
	local b = R.b
	local top, belly = rgb(90, 130, 175), rgb(240, 242, 245)
	local legH = 3.0
	local cy = legH + 1.1
	local root = R:makeRoot(V(1.8, 2.2, 4.2), cy)
	local body = b:part("ball", V(1.9, 2.0, 5.2), CF(0, cy, 0), top, { role = "primary", name = "Corpo" })
	R:join(body, root)
	b:part("ball", V(1.6, 1.4, 4.4), CF(0, cy - 0.35, -0.2), belly, { role = "fixed" })
	b:part("wedge", V(0.25, 1.4, 1.4), CF(0, cy + 1.45, 0.3), top, { role = "primary" })
	-- boca com dentes e olhos
	b:box(V(1.2, 0.18, 0.5), CF(0, cy - 0.35, -2.25), rgb(60, 20, 25), { role = "fixed" })
	for k = -2, 2 do
		b:part("wedge", V(0.12, 0.22, 0.12), CF(k * 0.22, cy - 0.22, -2.42) * CFrame.Angles(math.rad(180), 0, 0), rgb(255, 255, 255), { role = "fixed" })
	end
	eyes(b, V(0, cy + 0.45, -1.95), 0.55, 0.42)
	R.head = body
	R:setMouth(body, V(0, -0.3, -2.6))
	-- cauda animada
	local m = R:mark()
	b:part("wedge", V(0.2, 1.6, 1.2), CF(0, cy + 0.6, 3.0) * CFrame.Angles(math.rad(-30), 0, 0), top, { role = "primary" })
	b:part("wedge", V(0.2, 1.2, 1.0), CF(0, cy - 0.5, 3.0) * CFrame.Angles(math.rad(210), 0, 0), top, { role = "primary" })
	R:group(m, body, V(0, cy, 2.5), { kind = "tail", axis = "Y", amp = 0.45, speed = 1.6 })
	-- nadadeiras como braços
	for _, side in { -1, 1 } do
		local mm = R:mark()
		b:part("wedge", V(0.15, 0.5, 1.1), CF(side * 1.05, cy - 0.4, -0.4) * CFrame.Angles(0, 0, side * 0.9), top, { role = "primary" })
		R:group(mm, body, V(side * 0.9, cy - 0.3, -0.4), { kind = "fin", axis = "Z", amp = 0.4, phase = if side < 0 then 0 else math.pi })
	end
	-- pernas com patins
	for i, x in { -0.5, 0.5 } do
		local mm = R:mark()
		b:box(V(0.55, legH, 0.55), CF(x, legH / 2 + 0.4, 0), belly, { role = "fixed" })
		b:box(V(0.75, 0.6, 1.3), CF(x, 0.55, -0.1), rgb(240, 70, 120), { role = "accent" })
		for _, z in { -0.5, 0.35 } do
			b:part("cyl", V(0.25, 0.4, 0.4), CF(x, 0.2, z), rgb(30, 30, 35), { role = "fixed" })
		end
		R:group(mm, body, V(x, legH + 0.4, 0), { kind = "leg", axis = "X", amp = 0.55, phase = if i == 2 then math.pi else 0 })
	end
	return R:finish({ hp = params.hp or 450, speed = params.speed or 34, hipHeight = legH + 0.0, height = cy + 1.6, radius = 2 })
end

-- CROCODILO BOMBARDEIRO: crocodilo-avião que voa e solta bombas ----------------------
B.croco_bomber = function(origin, params)
	local R = Rig.new("CrocodiloBombardeiro", origin, params)
	local b = R.b
	local green, belly = rgb(70, 130, 60), rgb(200, 210, 150)
	local cy = 2.2
	local root = R:makeRoot(V(2, 1.8, 6), cy)
	local body = b:box(V(1.9, 1.5, 6.4), CF(0, cy, 0), green, { role = "primary", name = "Fuselagem" })
	R:join(body, root)
	b:box(V(1.7, 0.4, 6.2), CF(0, cy - 0.7, 0), belly, { role = "fixed" })
	for k = -3, 3 do
		b:part("wedge", V(0.5, 0.35, 0.5), CF(0, cy + 0.9, k * 0.8), Kit.darker(green, 0.2), { role = "secondary" })
	end
	-- cabeça de crocodilo na frente
	local hm = R:mark()
	local head = b:box(V(1.6, 1.1, 2.8), CF(0, cy + 0.1, -4.4), green, { role = "primary" })
	b:box(V(1.5, 0.35, 2.6), CF(0, cy - 0.45, -4.5), Kit.darker(green, 0.1), { role = "secondary" })
	for k = -4, 4 do
		b:part("wedge", V(0.1, 0.2, 0.12), CF(0.7, cy - 0.25, -4.5 + k * 0.3) * CFrame.Angles(math.rad(180), 0, 0), rgb(255, 255, 255), { role = "fixed" })
		b:part("wedge", V(0.1, 0.2, 0.12), CF(-0.7, cy - 0.25, -4.5 + k * 0.3) * CFrame.Angles(math.rad(180), 0, 0), rgb(255, 255, 255), { role = "fixed" })
	end
	eyes(b, V(0, cy + 0.85, -3.6), 0.45, 0.5, rgb(230, 180, 40))
	R:group(hm, body, V(0, cy, -3.1), { kind = "head", axis = "Y", amp = 0.12, speed = 0.5 })
	R.head = head
	R:setMouth(head, V(0, -0.2, -1.5))
	-- asas, cauda e motores com hélices
	b:box(V(9, 0.25, 1.8), CF(0, cy + 0.2, 0.2), rgb(150, 160, 150), { role = "secondary", material = Enum.Material.Metal })
	b:box(V(3.5, 0.2, 1.1), CF(0, cy + 0.4, 3.2), rgb(150, 160, 150), { role = "secondary", material = Enum.Material.Metal })
	b:part("wedge", V(0.2, 1.4, 1.2), CF(0, cy + 1.2, 3.3), green, { role = "primary" })
	for _, side in { -1, 1 } do
		b:part("cyl", V(1.6, 0.8, 0.8), CF(side * 2.6, cy - 0.15, -0.2) * CFrame.Angles(0, math.rad(90), 0), rgb(90, 95, 100), { role = "fixed", material = Enum.Material.Metal })
		local pm = R:mark()
		b:box(V(2.2, 0.25, 0.1), CF(side * 2.6, cy - 0.15, -1.05), rgb(40, 40, 45), { role = "fixed" })
		b:box(V(0.25, 2.2, 0.1), CF(side * 2.6, cy - 0.15, -1.05), rgb(40, 40, 45), { role = "fixed" })
		R:group(pm, body, V(side * 2.6, cy - 0.15, -1.05), { kind = "spin", axis = "Z", speed = 6 })
	end
	-- bomba pendurada
	b:ball(0.9, CF(0, cy - 1.2, 0.4), rgb(30, 30, 35), { role = "fixed" })
	b:box(V(0.1, 0.4, 0.1), CF(0, cy - 0.85, 0.4), rgb(80, 80, 80), { role = "fixed" })
	return R:finish({ hp = params.hp or 700, speed = params.speed or 26, hipHeight = cy - 0.9, height = cy + 1.8, radius = 3.5, flying = true })
end

-- BAILARINA CAPPUCCINO: bailarina com cabeça de xícara -------------------------------
B.coffee_ballerina = function(origin, params)
	local R = Rig.new("BailarinaCappuccino", origin, params)
	local b = R.b
	local pink, skin = rgb(255, 160, 200), rgb(250, 215, 190)
	local legH = 2.4
	local torsoY = legH + 0.9
	local root = R:makeRoot(V(1.4, 1.8, 0.9), torsoY)
	local torso = b:box(V(1.3, 1.8, 0.8), CF(0, torsoY, 0), pink, { role = "primary", name = "Tronco" })
	R:join(torso, root)
	b:part("cyl", V(0.35, 3.6, 3.6), CF(0, legH + 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 200, 225), { role = "secondary", material = Enum.Material.Fabric })
	b:part("cyl", V(0.25, 3.0, 3.0), CF(0, legH + 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 225, 240), { role = "fixed", material = Enum.Material.Fabric })
	for i, x in { -0.35, 0.35 } do
		local m = R:mark()
		b:box(V(0.42, legH, 0.42), CF(x, legH / 2, 0), skin, { role = "fixed" })
		b:box(V(0.45, 0.3, 0.7), CF(x, 0.15, -0.1), rgb(255, 120, 170), { role = "accent" })
		R:group(m, torso, V(x, legH, 0), { kind = "leg", axis = "X", amp = 0.5, phase = if i == 2 then math.pi else 0 })
	end
	-- braços em pose de balé (para cima)
	for _, side in { -1, 1 } do
		arm(R, torso, V(side * 0.85, torsoY + 0.75, 0), 1.7, 0.32, skin, skin, side, CFrame.Angles(0, 0, side * math.rad(150)))
	end
	-- cabeça: xícara de cappuccino com rostinho
	local hm = R:mark()
	local cupY = torsoY + 1.9
	local cup = b:cylY(1.5, 1.8, CF(0, cupY, 0), rgb(250, 250, 250), { role = "fixed", name = "Xicara" })
	b:cylY(0.12, 1.65, CF(0, cupY + 0.72, 0), rgb(150, 95, 55), { role = "fixed" })
	b:ball(0.7, CF(-0.3, cupY + 0.82, 0.1), rgb(250, 235, 210), { role = "fixed" })
	b:ball(0.55, CF(0.35, cupY + 0.8, -0.2), rgb(250, 235, 210), { role = "fixed" })
	b:part("cyl", V(0.25, 0.9, 0.9), CF(1.05, cupY, 0) * CFrame.Angles(0, math.rad(90), 0), rgb(250, 250, 250), { role = "fixed" })
	eyes(b, V(0, cupY + 0.15, -0.88), 0.32, 0.38)
	b:box(V(0.35, 0.08, 0.05), CF(0, cupY - 0.3, -0.91), rgb(200, 80, 110), { role = "fixed" })
	b:cylY(0.12, 2.2, CF(0, cupY - 0.8, 0), rgb(250, 250, 250), { role = "fixed" })
	R:group(hm, torso, V(0, torsoY + 0.9, 0), { kind = "head", axis = "Y", amp = 0.2, speed = 0.6 })
	R.head = cup
	R:setMouth(cup, V(0, -0.3, -0.95))
	return R:finish({ hp = params.hp or 300, speed = params.speed or 22, hipHeight = legH, height = cupY + 1, radius = 1.6 })
end

-- MACACO BANANA: macaquinho saindo de uma banana --------------------------------------
B.banana_monkey = function(origin, params)
	local R = Rig.new("MacacoBanana", origin, params)
	local b = R.b
	local yellow, brown, face = rgb(250, 215, 60), rgb(120, 80, 45), rgb(235, 200, 160)
	local legH = 1.0
	local cy = legH + 1.6
	local root = R:makeRoot(V(1.6, 3.2, 1.6), cy)
	local peel = b:cylY(3.2, 1.7, CF(0, cy, 0), yellow, { role = "primary", name = "Banana" })
	R:join(peel, root)
	b:cylY(0.5, 0.5, CF(0, legH + 3.4, 0.3) * CFrame.Angles(math.rad(25), 0, 0), rgb(110, 90, 40), { role = "fixed" })
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 0.4
		b:part("wedge", V(0.15, 1.3, 0.9), CF(math.cos(a) * 0.95, cy + 0.9, math.sin(a) * 0.95) * CFrame.Angles(0, -a + math.pi / 2, math.rad(180)), yellow, { role = "primary" })
	end
	-- cabeça do macaco saindo da banana
	local hm = R:mark()
	local hy = cy + 0.9
	local head = b:ball(1.35, CF(0, hy, -0.55), brown, { role = "secondary" })
	b:part("ball", V(1.0, 0.75, 0.4), CF(0, hy - 0.15, -1.1), face, { role = "fixed" })
	eyes(b, V(0, hy + 0.2, -1.12), 0.24, 0.32)
	b:box(V(0.4, 0.07, 0.05), CF(0, hy - 0.3, -1.3), rgb(80, 40, 30), { role = "fixed" })
	for _, side in { -1, 1 } do
		b:part("cyl", V(0.15, 0.55, 0.55), CF(side * 0.72, hy + 0.05, -0.55) * CFrame.Angles(0, 0, 0), face, { role = "fixed" })
	end
	R:group(hm, peel, V(0, hy - 0.4, -0.5), { kind = "head", axis = "Y", amp = 0.25, speed = 0.8 })
	R.head = head
	R:setMouth(head, V(0, -0.3, -0.8))
	for _, side in { -1, 1 } do
		arm(R, peel, V(side * 0.9, cy + 0.4, -0.2), 1.3, 0.3, brown, face, side)
	end
	legs(R, peel, { -0.4, 0.4 }, legH, legH, 0.35, brown, face)
	return R:finish({ hp = params.hp or 260, speed = params.speed or 22, hipHeight = legH, height = hy + 0.8, radius = 1.2 })
end

-- ELEFANTE CACTO: cabeça de elefante num corpo de cacto, de sandálias ----------------
B.cactus_elephant = function(origin, params)
	local R = Rig.new("ElefanteCacto", origin, params)
	local b = R.b
	local cactus, grey = rgb(80, 160, 70), rgb(150, 150, 160)
	local legH = 1.2
	local cy = legH + 1.8
	local root = R:makeRoot(V(2, 3.6, 2), cy)
	local body = b:cylY(3.6, 2.2, CF(0, cy, 0), cactus, { role = "primary", name = "Cacto" })
	R:join(body, root)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		b:box(V(0.12, 3.4, 0.2), CF(math.cos(a) * 1.1, cy, math.sin(a) * 1.1) * CFrame.Angles(0, -a, 0), Kit.darker(cactus, 0.2), { role = "secondary" })
		for j = 0, 2 do
			b:part("wedge", V(0.06, 0.25, 0.12), CF(math.cos(a) * 1.18, cy - 1 + j, math.sin(a) * 1.18) * CFrame.Angles(0, -a + math.pi / 2, math.rad(90)), rgb(250, 250, 230), { role = "fixed" })
		end
	end
	for _, side in { -1, 1 } do
		local m = R:mark()
		b:cylY(1.2, 0.7, CF(side * 1.5, cy + 0.2, 0) * CFrame.Angles(0, 0, side * math.rad(-70)), cactus, { role = "primary" })
		b:cylY(1.3, 0.7, CF(side * 2.0, cy + 1.0, 0), cactus, { role = "primary" })
		R:group(m, body, V(side * 1.1, cy, 0), { kind = "arm", axis = "Z", amp = 0.15, phase = if side < 0 then 0 else math.pi })
	end
	-- cabeça de elefante
	local hm = R:mark()
	local hy = cy + 2.5
	local head = b:ball(2.0, CF(0, hy, -0.2), grey, { role = "secondary" })
	eyes(b, V(0, hy + 0.3, -1.05), 0.45, 0.42)
	for _, side in { -1, 1 } do
		b:part("wedge", V(0.12, 1.7, 1.4), CF(side * 1.15, hy, 0.1) * CFrame.Angles(0, side * math.rad(-60), 0), Kit.darker(grey, 0.1), { role = "secondary" })
	end
	R:group(hm, body, V(0, cy + 1.8, 0), { kind = "head", axis = "Y", amp = 0.15, speed = 0.4 })
	R.head = head
	local tm = R:mark()
	b:part("cyl", V(1.6, 0.5, 0.5), CF(0, hy - 0.8, -1.1) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, 0, math.rad(15)), grey, { role = "secondary" })
	R:group(tm, head, V(0, hy - 0.2, -1.0), { kind = "tail", axis = "X", amp = 0.3, speed = 0.8 })
	R:setMouth(head, V(0, -1.2, -1.1))
	-- pernas com sandálias
	for i, x in { -0.55, 0.55 } do
		local m = R:mark()
		b:box(V(0.6, legH, 0.6), CF(x, legH / 2 + 0.15, 0), cactus, { role = "primary" })
		b:box(V(0.9, 0.15, 1.3), CF(x, 0.08, -0.1), rgb(150, 100, 60), { role = "fixed" })
		b:box(V(0.9, 0.12, 0.15), CF(x, 0.3, -0.45), rgb(150, 100, 60), { role = "fixed" })
		R:group(m, body, V(x, legH, 0), { kind = "leg", axis = "X", amp = 0.6, phase = if i == 2 then math.pi else 0 })
	end
	return R:finish({ hp = params.hp or 800, speed = params.speed or 12, hipHeight = legH, height = hy + 1, radius = 1.6 })
end

-- ARBUSTO-BOMBA: moita com pavio que explode perto de você ---------------------------
B.boom_bush = function(origin, params)
	local R = Rig.new("ArbustoBomba", origin, params)
	local b = R.b
	local leaf = rgb(60, 150, 60)
	local legH = 0.8
	local cy = legH + 1.3
	local root = R:makeRoot(V(2.2, 2.4, 2.2), cy)
	local body = b:ball(2.6, CF(0, cy, 0), leaf, { role = "primary", material = Enum.Material.Grass, name = "Moita" })
	R:join(body, root)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		b:ball(1.2, CF(math.cos(a) * 1.0, cy + 0.3 + (k % 2) * 0.4, math.sin(a) * 1.0), Kit.lighter(leaf, (k % 3) * 0.08), { role = "secondary", material = Enum.Material.Grass })
	end
	eyes(b, V(0, cy + 0.35, -1.25), 0.45, 0.45, rgb(200, 20, 20))
	for _, side in { -1, 1 } do
		b:box(V(0.5, 0.12, 0.1), CF(side * 0.45, cy + 0.8, -1.3) * CFrame.Angles(0, 0, side * 0.45), rgb(20, 40, 20), { role = "fixed" })
	end
	b:box(V(0.8, 0.2, 0.1), CF(0, cy - 0.35, -1.32), rgb(30, 20, 10), { role = "fixed" })
	b:cylY(0.8, 0.2, CF(0, cy + 1.6, 0), rgb(90, 70, 50), { role = "fixed" })
	local spark = b:ball(0.4, CF(0, cy + 2.05, 0), rgb(255, 180, 40), { role = "accent", material = Enum.Material.Neon, name = "Faisca" })
	b:light(spark, rgb(255, 170, 60), 8, 2)
	R.head = body
	R:setMouth(body, V(0, 0, -1.3))
	legs(R, body, { -0.5, 0.5 }, legH, legH, 0.4, rgb(90, 70, 50))
	return R:finish({ hp = params.hp or 80, speed = params.speed or 15, hipHeight = legH, height = cy + 2.2, radius = 1.4 })
end

-- PRIVADA CANTORA: privada com cabeça cantando ------------------------------------------
B.singing_toilet = function(origin, params)
	local R = Rig.new("PrivadaCantora", origin, params)
	local b = R.b
	local white = rgb(245, 245, 250)
	local cy = 1.2
	local root = R:makeRoot(V(2.2, 2.4, 2.6), cy)
	local bowl = b:cylY(1.6, 2.2, CF(0, 0.9, 0), white, { role = "primary", name = "Privada" })
	R:join(bowl, root)
	b:cylY(0.25, 2.4, CF(0, 1.8, 0), white, { role = "primary" })
	b:box(V(2.0, 2.2, 0.8), CF(0, 2.3, 1.2), white, { role = "primary" })
	b:box(V(0.5, 0.15, 0.2), CF(0.6, 3.2, 0.85), rgb(190, 190, 200), { role = "fixed", material = Enum.Material.Metal })
	local hm = R:mark()
	local hy = 3.0
	local head = b:ball(1.7, CF(0, hy, -0.1), rgb(240, 200, 170), { role = "fixed" })
	eyes(b, V(0, hy + 0.3, -0.85), 0.32, 0.38)
	b:part("ball", V(0.55, 0.5, 0.2), CF(0, hy - 0.35, -0.85), rgb(120, 30, 40), { role = "fixed" })
	b:box(V(1.4, 0.35, 1.4), CF(0, hy + 0.85, 0), rgb(60, 40, 25), { role = "fixed" })
	R:group(hm, bowl, V(0, 1.9, 0), { kind = "bob", axis = "Y", amp = 0.5, speed = 2.5 })
	R.head = head
	R:setMouth(head, V(0, -0.35, -0.9))
	return R:finish({ hp = params.hp or 200, speed = params.speed or 14, hipHeight = 0.0, height = hy + 1, radius = 1.4 })
end

-- MONSTRO DE PELÚCIA: braços compridos e sorriso cheio de dentes ----------------------
B.plush_monster = function(origin, params)
	local R = Rig.new("MonstroPelucia", origin, params)
	local b = R.b
	local fur = rgb(230, 110, 170)
	local legH = 3.2
	local torsoY = legH + 1.3
	local root = R:makeRoot(V(1.6, 2.6, 1), torsoY)
	local torso = b:box(V(1.6, 2.6, 1), CF(0, torsoY, 0), fur, { role = "primary", material = Enum.Material.Fabric, name = "Tronco" })
	R:join(torso, root)
	legs(R, torso, { -0.45, 0.45 }, legH, legH, 0.6, fur, rgb(255, 230, 120), 1.3)
	for _, side in { -1, 1 } do
		arm(R, torso, V(side * 1.1, torsoY + 1.0, 0), 4.2, 0.5, fur, rgb(255, 230, 120), side)
	end
	local hm = R:mark()
	local hy = torsoY + 2.4
	local head = b:ball(2.4, CF(0, hy, 0), fur, { role = "primary", material = Enum.Material.Fabric })
	eyes(b, V(0, hy + 0.4, -1.05), 0.55, 0.6)
	b:part("ball", V(1.8, 0.6, 0.4), CF(0, hy - 0.45, -1.0), rgb(250, 60, 80), { role = "fixed" })
	for k = -3, 3 do
		b:part("wedge", V(0.15, 0.25, 0.1), CF(k * 0.22, hy - 0.3, -1.2) * CFrame.Angles(math.rad(180), 0, 0), rgb(255, 255, 255), { role = "fixed" })
	end
	R:group(hm, torso, V(0, torsoY + 1.3, 0), { kind = "head", axis = "Y", amp = 0.2, speed = 0.5 })
	R.head = head
	R:setMouth(head, V(0, -0.4, -1.2))
	return R:finish({ hp = params.hp or 600, speed = params.speed or 18, hipHeight = legH, height = hy + 1.2, radius = 1.4 })
end

-- URSO ANIMATRÔNICO: urso de metal com olhos brilhantes --------------------------------
B.animatronic_bear = function(origin, params)
	local R = Rig.new("UrsoAnimatronico", origin, params)
	local b = R.b
	local metal, dark = rgb(140, 105, 80), rgb(60, 60, 65)
	local legH = 2.2
	local torsoY = legH + 1.3
	local root = R:makeRoot(V(2.4, 2.6, 1.6), torsoY)
	local torso = b:box(V(2.4, 2.6, 1.6), CF(0, torsoY, 0), metal, { role = "primary", material = Enum.Material.Metal, name = "Tronco" })
	R:join(torso, root)
	b:part("ball", V(1.8, 1.8, 0.4), CF(0, torsoY - 0.1, -0.75), Kit.lighter(metal, 0.25), { role = "secondary" })
	legs(R, torso, { -0.6, 0.6 }, legH, legH, 0.8, metal, dark)
	for _, side in { -1, 1 } do
		arm(R, torso, V(side * 1.55, torsoY + 1.0, 0), 2.2, 0.65, metal, dark, side)
	end
	local hm = R:mark()
	local hy = torsoY + 2.2
	local head = b:box(V(1.9, 1.7, 1.7), CF(0, hy, 0), metal, { role = "primary", material = Enum.Material.Metal })
	b:box(V(1.0, 0.7, 0.6), CF(0, hy - 0.35, -1.0), Kit.lighter(metal, 0.2), { role = "secondary" })
	b:ball(0.35, CF(0, hy - 0.15, -1.32), rgb(25, 20, 20), { role = "fixed" })
	for _, side in { -1, 1 } do
		b:ball(0.3, CF(side * 0.45, hy + 0.3, -0.86), rgb(255, 230, 120), { role = "eye", material = Enum.Material.Neon })
		b:part("cyl", V(0.25, 0.7, 0.7), CF(side * 0.8, hy + 1.0, 0) * CFrame.Angles(0, math.rad(90), 0), metal, { role = "primary" })
	end
	local jm = R:mark()
	b:box(V(0.9, 0.25, 0.55), CF(0, hy - 0.85, -0.95), dark, { role = "fixed" })
	R.head = head
	R:group(hm, torso, V(0, torsoY + 1.3, 0), { kind = "head", axis = "Y", amp = 0.25, speed = 0.3 })
	R:group(jm, head, V(0, hy - 0.7, -0.7), { kind = "jaw", axis = "X", amp = 0.35 })
	R:setMouth(head, V(0, -0.6, -1.1))
	return R:finish({ hp = params.hp or 500, speed = params.speed or 14, hipHeight = legH, height = hy + 1.4, radius = 1.6 })
end

-- OURIÇO VELOZ: ouriço de tênis que corre muito ---------------------------------------
B.speed_hedgehog = function(origin, params)
	local R = Rig.new("OuricoVeloz", origin, params)
	local b = R.b
	local quills, belly = rgb(120, 90, 60), rgb(240, 215, 170)
	local legH = 1.1
	local cy = legH + 1.0
	local root = R:makeRoot(V(1.6, 2, 1.6), cy)
	local body = b:ball(2.1, CF(0, cy, 0), quills, { role = "primary", name = "Corpo" })
	R:join(body, root)
	b:part("ball", V(1.5, 1.6, 0.6), CF(0, cy - 0.1, -0.75), belly, { role = "fixed" })
	for k = 0, 8 do
		local a = (k / 9 - 0.5) * math.pi * 1.4
		b:part("wedge", V(0.3, 1.4, 0.6), CF(math.sin(a) * 0.8, cy + math.cos(a) * 0.6, 0.7) * CFrame.Angles(math.rad(-120), 0, -a * 0.6), Kit.darker(quills, 0.1), { role = "secondary" })
	end
	eyes(b, V(0, cy + 0.4, -0.95), 0.3, 0.42, rgb(40, 140, 60))
	b:ball(0.25, CF(0, cy + 0.05, -1.08), rgb(20, 20, 20), { role = "fixed" })
	R.head = body
	R:setMouth(body, V(0, -0.2, -1.1))
	for _, side in { -1, 1 } do
		arm(R, body, V(side * 0.95, cy, -0.2), 0.9, 0.28, belly, rgb(250, 250, 250), side)
	end
	for i, x in { -0.4, 0.4 } do
		local m = R:mark()
		b:box(V(0.35, legH, 0.35), CF(x, legH / 2 + 0.3, 0), belly, { role = "fixed" })
		b:box(V(0.6, 0.5, 1.3), CF(x, 0.25, -0.25), rgb(240, 240, 245), { role = "fixed" })
		b:box(V(0.62, 0.18, 1.32), CF(x, 0.35, -0.25), rgb(40, 170, 90), { role = "accent" })
		R:group(m, body, V(x, legH + 0.3, 0), { kind = "leg", axis = "X", amp = 1.0, speed = 1.8, phase = if i == 2 then math.pi else 0 })
	end
	return R:finish({ hp = params.hp or 300, speed = params.speed or 48, hipHeight = legH, height = cy + 1.2, radius = 1.1 })
end

-- RATINHO ELÉTRICO: ratinho azul de bochechas elétricas --------------------------------
B.electric_mouse = function(origin, params)
	local R = Rig.new("RatinhoEletrico", origin, params)
	local b = R.b
	local fur = rgb(120, 180, 240)
	local legH = 0.9
	local cy = legH + 1.0
	local root = R:makeRoot(V(1.6, 2, 1.4), cy)
	local body = b:part("ball", V(1.7, 2.0, 1.5), CF(0, cy, 0), fur, { role = "primary", name = "Corpo" })
	R:join(body, root)
	local hm = R:mark()
	local hy = cy + 1.5
	local head = b:ball(1.7, CF(0, hy, -0.1), fur, { role = "primary" })
	eyes(b, V(0, hy + 0.15, -0.9), 0.35, 0.4)
	for _, side in { -1, 1 } do
		b:ball(0.4, CF(side * 0.58, hy - 0.3, -0.72), rgb(255, 230, 60), { role = "accent", material = Enum.Material.Neon })
		b:part("wedge", V(0.2, 1.4, 0.7), CF(side * 0.55, hy + 1.2, 0) * CFrame.Angles(0, 0, side * -0.3), fur, { role = "primary" })
		b:part("wedge", V(0.22, 0.45, 0.72), CF(side * 0.75, hy + 1.75, 0) * CFrame.Angles(0, 0, side * -0.3), rgb(30, 30, 40), { role = "fixed" })
	end
	R:group(hm, body, V(0, cy + 0.9, 0), { kind = "head", axis = "Y", amp = 0.2, speed = 0.7 })
	R.head = head
	R:setMouth(head, V(0, -0.35, -0.9))
	-- cauda em zigue-zague (raio)
	local tm = R:mark()
	b:box(V(0.25, 1.0, 0.25), CF(0, cy - 0.1, 1.0) * CFrame.Angles(math.rad(40), 0, 0), rgb(255, 230, 60), { role = "accent", material = Enum.Material.Neon })
	b:box(V(0.6, 0.25, 0.25), CF(0.2, cy + 0.4, 1.4), rgb(255, 230, 60), { role = "accent", material = Enum.Material.Neon })
	b:box(V(0.25, 1.1, 0.25), CF(0.45, cy + 0.95, 1.5) * CFrame.Angles(math.rad(-25), 0, 0), rgb(255, 230, 60), { role = "accent", material = Enum.Material.Neon })
	R:group(tm, body, V(0, cy - 0.4, 0.7), { kind = "tail", axis = "Y", amp = 0.35, speed = 1.4 })
	for _, side in { -1, 1 } do
		arm(R, body, V(side * 0.85, cy + 0.3, -0.1), 0.8, 0.3, fur, fur, side)
	end
	legs(R, body, { -0.4, 0.4 }, legH, legH, 0.4, fur, fur)
	return R:finish({ hp = params.hp or 260, speed = params.speed or 24, hipHeight = legH, height = hy + 2, radius = 1.1 })
end

Memes.Variants = B

function Memes.build(origin: CFrame, params: { [string]: any }, variant: string): Rig.RigResult
	local f = B[variant] or B.tum_tum_log
	return f(origin, params)
end

return Memes
