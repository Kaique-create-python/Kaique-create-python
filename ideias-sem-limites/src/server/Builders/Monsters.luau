--!strict
-- Criaturas especiais: dragão (e hidra), fantasma, robôs (robô, mecha, drone)
-- e disco voador.

local Rig = require(script.Parent.Rig)
local Kit = require(script.Parent.Kit)

local Monsters = {}

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

-- DRAGÃO ----------------------------------------------------------------------------
function Monsters.dragon(origin: CFrame, params: { [string]: any }, variant: string): Rig.RigResult
	local hydra = variant == "hydra"
	local R = Rig.new(variant, origin, params)
	local b = R.b
	local element = params.element or "fire"
	local base = if hydra then rgb(60, 110, 70) else rgb(170, 35, 35)
	if element == "ice" then
		base = rgb(110, 170, 220)
	elseif element == "electric" then
		base = rgb(60, 70, 150)
	elseif element == "poison" then
		base = rgb(70, 130, 60)
	elseif element == "shadow" then
		base = rgb(45, 30, 60)
	elseif element == "light" then
		base = rgb(240, 225, 170)
	end
	local belly = rgb(235, 200, 130)
	local wingCol = Kit.darker(base, 0.25)
	local glow = (Kit.Elements[element] or Kit.Elements.fire).color
	local legH = 2.6
	local bodyY = legH + 1.4
	local root = R:makeRoot(V(3, 2.8, 5), bodyY)
	local torso = b:part("ball", V(3.2, 3.0, 5.6), CF(0, bodyY, 0), base, { role = "primary", name = "Corpo" })
	R:join(torso, root)
	local bel = b:part("ball", V(2.6, 2.2, 4.6), CF(0, bodyY - 0.6, -0.2), belly, { role = "fixed" })
	R:join(bel, torso)
	-- espinhos nas costas
	for k = 0, 5 do
		local sp = b:part("wedge", V(0.3, 0.9, 0.9), CF(0, bodyY + 1.6, -2 + k * 0.8), glow, { role = "accent", material = Enum.Material.Neon })
		R:join(sp, torso)
	end
	-- pernas
	local legPos = { { -1.2, -1.6, 0 }, { 1.2, -1.6, math.pi }, { -1.3, 1.7, math.pi }, { 1.3, 1.7, 0 } }
	for _, l in legPos do
		local m = R:mark()
		local x, z, ph = l[1], l[2], l[3]
		b:part("ball", V(1.1, 1.8, 1.3), CF(x, legH + 0.1, z), base, { role = "primary" })
		b:box(V(0.7, legH, 0.7), CF(x, legH / 2, z), base, { role = "primary" })
		for c = -1, 1 do
			b:part("wedge", V(0.2, 0.3, 0.5), CF(x + c * 0.25, 0.15, z - 0.55), rgb(30, 25, 25), { role = "fixed" })
		end
		R:group(m, torso, V(x, legH + 0.6, z), { kind = "leg", axis = "X", amp = 0.5, phase = ph })
	end
	-- asas (duas partes cada)
	if not hydra then
		for _, side in { -1, 1 } do
			local m = R:mark()
			local shoulder = V(side * 1.3, bodyY + 1.2, -0.8)
			b:beam(shoulder, shoulder + V(side * 3.2, 1.6, 0.4), 0.35, base, { role = "primary" })
			b:beam(shoulder + V(side * 3.2, 1.6, 0.4), shoulder + V(side * 6.4, 0.6, 1.4), 0.25, base, { role = "primary" })
			b:part("wedge", V(0.12, 3.2, 3.4), CF(shoulder + V(side * 1.8, 0.2, 1.4)) * ANG(rad(-90), side * rad(90), 0), wingCol, { role = "secondary" })
			b:part("wedge", V(0.12, 3.6, 3.0), CF(shoulder + V(side * 4.8, 0.3, 1.7)) * ANG(rad(-90), side * rad(90), 0), wingCol, { role = "secondary" })
			R:group(m, torso, shoulder, { kind = "wing", axis = "Z", amp = if params.fly ~= false then 0.6 else 0.15, phase = if side < 0 then 0 else math.pi, speed = 0.9 })
		end
	end
	-- pescoço(s) e cabeça(s)
	local heads = if hydra then { -1.2, 0, 1.2 } else { 0 }
	local firstHead: BasePart? = nil
	for _, hx in heads do
		local prev: BasePart = torso
		local p0 = V(hx * 0.6, bodyY + 0.8, -2.6)
		local dir = V(hx * 0.25, 0.75, -0.7).Unit
		local pos = p0
		for k = 1, 3 do
			local m = R:mark()
			pos = p0 + dir * (k * 1.1)
			b:part("ball", V(1.3 - k * 0.12, 1.3 - k * 0.12, 1.6), CF(pos, pos + dir), base, { role = "primary" })
			prev = R:group(m, prev, pos - dir * 0.6, { kind = "segment", axis = "Y", amp = 0.12, phase = k * 0.5 + hx, speed = 0.6 }) or prev
		end
		local hm = R:mark()
		local headPos = pos + V(0, 0.5, -1.1)
		local head = b:box(V(1.4, 1.2, 2.2), CF(headPos), base, { role = "primary", name = "Cabeca" })
		b:box(V(1.0, 0.7, 1.4), CF(headPos + V(0, -0.15, -1.4)), base, { role = "primary" })
		for _, side in { -1, 1 } do
			b:box(V(0.25, 0.22, 0.1), CF(headPos + V(side * 0.55, 0.3, -1.05)), glow, { role = "eye", material = Enum.Material.Neon })
			b:cone(1.4, 0.4, CF(headPos + V(side * 0.45, 0.5, 0.6)) * ANG(rad(70), 0, side * rad(-15)), rgb(240, 230, 200), 3, { role = "fixed" })
			b:box(V(0.15, 0.15, 0.1), CF(headPos + V(side * 0.3, 0.05, -2.12)), rgb(20, 15, 15), { role = "fixed" })
		end
		for k = 0, 3 do
			for _, side in { -1, 1 } do
				b:part("wedge", V(0.1, 0.25, 0.15), CF(headPos + V(side * 0.45, -0.55, -1.9 + k * 0.35)) * ANG(rad(180), 0, 0), rgb(250, 250, 240), { role = "fixed" })
			end
		end
		local hb = R:group(hm, prev, headPos + V(0, -0.3, 0.9), { kind = "head", axis = "X", amp = 0.15, speed = 0.7 })
		local jm = R:mark()
		b:box(V(0.95, 0.3, 1.8), CF(headPos + V(0, -0.65, -1.2)), belly, { role = "fixed", name = "Mandibula" })
		R:group(jm, hb or prev, headPos + V(0, -0.5, 0.2), { kind = "jaw", axis = "X", amp = 0.3, speed = 0.4 })
		if not firstHead then
			firstHead = head
			R.head = head
			R:setMouth(head, V(0, -0.3, -2.2))
		end
	end
	-- cauda com ponta em lança
	local prev: BasePart = torso
	local tb = V(0, bodyY + 0.2, 2.6)
	for k = 1, 5 do
		local m = R:mark()
		local th = 1.4 - k * 0.2
		local pos = tb + V(0, -k * 0.2, k * 1.2)
		b:part("ball", V(th, th, 1.6), CF(pos), base, { role = "primary" })
		if k == 5 then
			b:part("wedge", V(0.15, 1.2, 1.2), CF(pos + V(0, 0, 0.9)) * ANG(rad(90), 0, 0), glow, { role = "accent", material = Enum.Material.Neon })
		end
		prev = R:group(m, prev, pos - V(0, 0, 0.7), { kind = "tail", axis = "Y", amp = 0.2, phase = k * 0.6, speed = 0.8 }) or prev
	end
	return R:finish({ hp = params.hp or 900, speed = params.speed or 24, hipHeight = legH, height = bodyY + 4.5, flying = params.fly ~= false and not hydra, radius = 3.4 })
end

-- FANTASMA --------------------------------------------------------------------------
function Monsters.ghost(origin: CFrame, params: { [string]: any }, _variant: string): Rig.RigResult
	local R = Rig.new("ghost", origin, params)
	local b = R.b
	local col = rgb(235, 240, 255)
	local root = R:makeRoot(V(2, 3, 2), 3)
	local m = R:mark()
	b:ball(2.4, CF(0, 4.2, 0), col, { role = "primary", material = Enum.Material.ForceField, transparency = 0.35, name = "Cabeca" })
	b:part("cyl", V(2.2, 2.4, 2.4), CF(0, 2.9, 0) * ANG(0, 0, rad(90)), col, { role = "primary", material = Enum.Material.ForceField, transparency = 0.35 })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		b:part("wedge", V(0.6, 0.9, 0.4), CF(math.cos(a) * 0.95, 1.4, math.sin(a) * 0.95) * ANG(rad(180), -a, 0), col, { role = "primary", material = Enum.Material.ForceField, transparency = 0.35 })
	end
	for _, side in { -1, 1 } do
		b:part("ball", V(0.45, 0.7, 0.2), CF(side * 0.45, 4.4, -1.1), rgb(10, 10, 15), { role = "eye" })
		b:part("ball", V(0.6, 0.9, 0.8), CF(side * 1.3, 3.2, -0.3), col, { role = "primary", material = Enum.Material.ForceField, transparency = 0.35 })
	end
	b:part("ball", V(0.6, 0.8, 0.2), CF(0, 3.7, -1.15), rgb(10, 10, 15), { role = "fixed" })
	local body = R:group(m, root, V(0, 2, 0), { kind = "bob", axis = "Y", amp = 0.5, speed = 0.7 })
	R.head = body
	if body then
		R:setMouth(body, V(0, 0.8, -1.2))
	end
	local light = Instance.new("PointLight")
	light.Color = rgb(180, 200, 255)
	light.Range = 10
	light.Brightness = 1
	light.Parent = root
	return R:finish({ hp = params.hp or 120, speed = params.speed or 14, hipHeight = 1.5, height = 5.4, flying = true, radius = 1.4 })
end

-- ROBÔS -----------------------------------------------------------------------------
function Monsters.robot(origin: CFrame, params: { [string]: any }, variant: string): Rig.RigResult
	if variant == "drone" then
		return Monsters.drone(origin, params)
	end
	local mech = variant == "mech"
	local R = Rig.new(variant, origin, params)
	local b = R.b
	local metal = if mech then rgb(70, 75, 85) else rgb(170, 180, 195)
	local dark = rgb(45, 48, 55)
	local glow = if mech then rgb(255, 60, 60) else rgb(80, 220, 255)
	local legH = 2.4
	local torsoY = legH + 1.3
	local root = R:makeRoot(V(2.6, 2.6, 1.6), torsoY)
	local torso = b:box(V(2.6, 2.6, 1.6), CF(0, torsoY, 0), metal, { role = "primary", material = Enum.Material.DiamondPlate, name = "Tronco" })
	R:join(torso, root)
	local panel = b:box(V(1.4, 0.9, 0.1), CF(0, torsoY + 0.3, -0.82), dark, { role = "secondary" })
	R:join(panel, torso)
	for k = -1, 1 do
		local l = b:box(V(0.25, 0.25, 0.08), CF(k * 0.4, torsoY + 0.3, -0.88), if k == 0 then rgb(255, 220, 60) else glow, { role = "accent", material = Enum.Material.Neon })
		R:join(l, torso)
	end
	if mech then
		local cockpit = b:part("ball", V(1.8, 1.4, 1.2), CF(0, torsoY + 1.2, -0.6), rgb(120, 200, 255), { role = "fixed", material = Enum.Material.Glass, transparency = 0.3 })
		R:join(cockpit, torso)
		for _, side in { -1, 1 } do
			local cannon = b:part("cyl", V(2.2, 0.6, 0.6), CF(side * 1.0, torsoY + 1.8, -0.4) * ANG(0, rad(90), 0), dark, { role = "secondary" })
			R:join(cannon, torso)
		end
	end
	for _, side in { -1, 1 } do
		local m = R:mark()
		local x = side * 0.75
		b:box(V(0.9, legH, 0.9), CF(x, legH / 2, 0), dark, { role = "secondary" })
		b:box(V(1.0, 0.5, 1.0), CF(x, legH * 0.55, 0), metal, { role = "primary" })
		b:box(V(1.1, 0.4, 1.5), CF(x, 0.2, -0.2), metal, { role = "primary" })
		R:group(m, torso, V(x, legH, 0), { kind = "leg", axis = "X", amp = 0.5, phase = if side < 0 then 0 else math.pi })
		local am = R:mark()
		local sx = side * 1.75
		b:ball(1.0, CF(sx, torsoY + 1.0, 0), metal, { role = "primary" })
		b:box(V(0.7, 2.2, 0.7), CF(sx, torsoY - 0.3, 0), dark, { role = "secondary" })
		b:box(V(0.9, 0.7, 0.9), CF(sx, torsoY - 1.6, 0), metal, { role = "primary" })
		if side == 1 then
			b:part("cyl", V(0.9, 0.35, 0.35), CF(sx, torsoY - 1.7, -0.6) * ANG(0, rad(90), 0), glow, { role = "accent", material = Enum.Material.Neon })
		end
		R:group(am, torso, V(sx, torsoY + 1.0, 0), { kind = "arm", axis = "X", amp = 0.4, phase = if side < 0 then math.pi else 0 })
	end
	local hm = R:mark()
	local headY = torsoY + 1.3 + 0.75
	local head = b:box(V(1.5, 1.3, 1.3), CF(0, headY, 0), metal, { role = "primary", material = Enum.Material.DiamondPlate, name = "Cabeca" })
	b:box(V(1.2, 0.35, 0.1), CF(0, headY + 0.1, -0.66), glow, { role = "eye", material = Enum.Material.Neon })
	b:beam(V(0, headY + 0.65, 0), V(0, headY + 1.4, 0), 0.1, dark, { role = "fixed" })
	b:ball(0.3, CF(0, headY + 1.45, 0), rgb(255, 60, 60), { role = "accent", material = Enum.Material.Neon })
	R.head = head
	R:group(hm, torso, V(0, torsoY + 1.3, 0), { kind = "head", axis = "Y", amp = 0.25, speed = 0.5 })
	R:setMouth(head, V(0, 0, -0.7))
	return R:finish({ hp = params.hp or 380, speed = params.speed or 16, hipHeight = legH, height = headY + 1.6, radius = 1.6 })
end

function Monsters.drone(origin: CFrame, params: { [string]: any }): Rig.RigResult
	local R = Rig.new("drone", origin, params)
	local b = R.b
	local root = R:makeRoot(V(1.6, 0.6, 1.6), 1)
	local body = b:box(V(1.4, 0.5, 1.4), CF(0, 1, 0), rgb(40, 42, 48), { role = "primary", name = "Corpo" })
	R:join(body, root)
	local cam = b:ball(0.5, CF(0, 0.7, -0.6), rgb(20, 20, 20), { role = "fixed" })
	R:join(cam, body)
	local lens = b:ball(0.25, CF(0, 0.7, -0.85), rgb(255, 60, 60), { role = "eye", material = Enum.Material.Neon })
	R:join(lens, body)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local tip = V(math.cos(a) * 1.4, 1.1, math.sin(a) * 1.4)
		local arm = b:beam(V(0, 1, 0), tip, 0.18, rgb(60, 62, 70), { role = "secondary" })
		R:join(arm, body)
		local m = R:mark()
		b:part("cyl", V(0.05, 1.2, 1.2), CF(tip + V(0, 0.15, 0)) * ANG(0, 0, rad(90)), rgb(200, 220, 255), { role = "fixed", material = Enum.Material.Glass, transparency = 0.5 })
		b:box(V(1.2, 0.06, 0.15), CF(tip + V(0, 0.18, 0)), rgb(30, 30, 30), { role = "fixed" })
		R:group(m, body, tip + V(0, 0.15, 0), { kind = "spin", axis = "Y", amp = 1, speed = 8 })
	end
	R.head = body
	R:setMouth(body, V(0, -0.3, -0.8))
	return R:finish({ hp = params.hp or 60, speed = params.speed or 24, hipHeight = 0.7, height = 1.5, flying = true, radius = 1.6 })
end

-- DISCO VOADOR -----------------------------------------------------------------------
function Monsters.ufo(origin: CFrame, params: { [string]: any }, _variant: string): Rig.RigResult
	local R = Rig.new("ufo", origin, params)
	local b = R.b
	local metal = rgb(170, 180, 190)
	local root = R:makeRoot(V(6, 1.6, 6), 2)
	local m = R:mark()
	b:part("cyl", V(0.9, 9, 9), CF(0, 2, 0) * ANG(0, 0, rad(90)), metal, { role = "primary", material = Enum.Material.DiamondPlate, name = "Corpo" })
	b:part("cyl", V(0.7, 6.5, 6.5), CF(0, 1.5, 0) * ANG(0, 0, rad(90)), Kit.darker(metal, 0.3), { role = "secondary" })
	b:part("ball", V(4, 3, 4), CF(0, 3, 0), rgb(140, 230, 255), { role = "fixed", material = Enum.Material.Glass, transparency = 0.35 })
	-- piloto alienígena dentro da cúpula
	b:ball(1.1, CF(0, 3.3, 0), rgb(140, 200, 140), { role = "fixed" })
	for _, side in { -1, 1 } do
		b:part("ball", V(0.3, 0.45, 0.2), CF(side * 0.2, 3.4, -0.5), rgb(10, 10, 10), { role = "fixed" })
	end
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		b:ball(0.5, CF(math.cos(a) * 4.3, 2, math.sin(a) * 4.3), Kit.RainbowColors[(k % 6) + 1], { role = "accent", material = Enum.Material.Neon })
	end
	b:part("cyl", V(0.3, 2, 2), CF(0, 1.05, 0) * ANG(0, 0, rad(90)), rgb(120, 255, 160), { role = "accent", material = Enum.Material.Neon })
	local body = R:group(m, root, V(0, 2, 0), { kind = "spin", axis = "Y", amp = 1, speed = 0.4 })
	R.head = body
	if body then
		R:setMouth(body, V(0, -1, 0))
	end
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Color = rgb(120, 255, 160)
	light.Range = 40
	light.Angle = 50
	light.Brightness = 3
	light.Parent = root
	return R:finish({ hp = params.hp or 700, speed = params.speed or 24, hipHeight = 1.2, height = 4.5, flying = true, radius = 4.5 })
end

return Monsters
