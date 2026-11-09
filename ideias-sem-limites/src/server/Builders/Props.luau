--!strict
-- Objetos, comidas e natureza. Tamanho "de brinquedo gigante": bem visível
-- no celular e engraçado (uma pizza de 6 studs, uma TV de 8 studs).
-- Também fornece árvores, pedras e cristais reutilizados pelo mapa.

local Kit = require(script.Parent.Kit)

local Props = {}

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

export type PropResult = { model: Model, height: number, radius: number, main: BasePart }

type Fn = (b: any, rng: any) -> (number, number)

local function screen(part: BasePart, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(320, 200)
	gui.LightInfluence = 0
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(color, Color3.fromRGB(40, 20, 90))
	grad.Rotation = 45
	grad.Parent = f
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Parent = f
	gui.Parent = part
	part:AddTag("IdeiasTela")
end

local OBJ: { [string]: Fn } = {}

OBJ.tv = function(b, rng)
	b:box(V(10, 6.4, 1), CF(0, 5.5, 0), rgb(25, 25, 30), { role = "primary" })
	local scr = b:box(V(9.2, 5.6, 0.1), CF(0, 5.5, -0.52), rgb(60, 180, 255), { role = "fixed", material = Enum.Material.Neon })
	screen(scr, rng:pick({ "IDEIAS TV", "AO VIVO", "📺", "NOTÍCIAS" }), rgb(40, 120, 255))
	b:box(V(1, 2, 1), CF(0, 1.5, 0), rgb(40, 40, 45), { role = "secondary" })
	b:box(V(5, 0.4, 3), CF(0, 0.2, 0), rgb(40, 40, 45), { role = "secondary" })
	return 9, 5
end
OBJ.computer = function(b, _rng)
	b:box(V(7, 4.6, 0.6), CF(0, 4.6, 0), rgb(30, 30, 35), { role = "primary" })
	local scr = b:box(V(6.4, 4, 0.1), CF(0, 4.6, -0.32), rgb(80, 255, 160), { role = "fixed", material = Enum.Material.Neon })
	screen(scr, "> criar ideia_", rgb(10, 40, 20))
	b:box(V(0.6, 1.6, 0.6), CF(0, 1.6, 0.2), rgb(50, 50, 55), { role = "secondary" })
	b:box(V(6, 0.3, 2), CF(0, 0.15, -2.6), rgb(220, 220, 225), { role = "secondary" })
	b:box(V(2.2, 5, 4.6), CF(5.6, 2.5, 0.8), rgb(35, 35, 40), { role = "primary" })
	b:box(V(0.1, 0.4, 0.4), CF(4.48, 4, -1), rgb(80, 200, 255), { role = "accent", material = Enum.Material.Neon })
	return 7, 6
end
OBJ.phone = function(b, rng)
	b:box(V(4, 8, 0.5), CF(0, 4.3, 0) * ANG(rad(-10), 0, 0), rgb(30, 30, 35), { role = "primary" })
	local scr = b:box(V(3.6, 7.2, 0.1), CF(0, 4.3, -0.28) * ANG(rad(-10), 0, 0), rgb(255, 120, 200), { role = "fixed", material = Enum.Material.Neon })
	screen(scr, rng:pick({ "😂", "📱", "♥ 999+", "OI!" }), rgb(255, 90, 180))
	b:part("cyl", V(0.1, 0.5, 0.5), CF(-1.2, 7.7, 0.32) * ANG(rad(-10), rad(90), 0), rgb(20, 20, 20), { role = "fixed" })
	b:box(V(0.15, 1, 0.3), CF(2.05, 6, 0) * ANG(rad(-10), 0, 0), rgb(60, 60, 65), { role = "fixed" })
	b:box(V(3, 0.3, 2), CF(0, 0.15, 0.8), rgb(40, 40, 45), { role = "secondary" })
	return 9, 3
end
OBJ.arcade = function(b, rng)
	local col = rng:pick({ rgb(220, 40, 120), rgb(40, 120, 230), rgb(250, 170, 30) })
	b:box(V(4, 8, 3.4), CF(0, 4, 0), col, { role = "primary" })
	local scr = b:box(V(3.2, 2.6, 0.1), CF(0, 5.4, -1.72), rgb(40, 255, 200), { role = "fixed", material = Enum.Material.Neon })
	screen(scr, "GAME", rgb(20, 30, 60))
	b:part("wedge", V(4, 1, 1.6), CF(0, 3.6, -2.4) * ANG(0, rad(180), 0), Kit.darker(col, 0.3), { role = "secondary" })
	b:ball(0.6, CF(-0.8, 4.3, -2.6), rgb(255, 40, 40), { role = "accent" })
	b:ball(0.4, CF(0.6, 4.2, -2.6), rgb(255, 230, 40), { role = "accent", material = Enum.Material.Neon })
	return 8, 3
end
OBJ.table = function(b, rng)
	local wood = rng:pick({ rgb(150, 100, 60), rgb(110, 75, 45), rgb(220, 200, 170) })
	b:box(V(9, 0.6, 6), CF(0, 4, 0), wood, { role = "primary", material = Enum.Material.WoodPlanks })
	for _, x in { -4, 4 } do
		for _, z in { -2.5, 2.5 } do
			b:box(V(0.6, 3.7, 0.6), CF(x, 1.85, z), Kit.darker(wood, 0.2), { role = "secondary" })
		end
	end
	return 4.5, 5
end
OBJ.chair = function(b, rng)
	local throne = rng:chance(0.25)
	local col = if throne then rgb(220, 180, 40) else rgb(140, 95, 55)
	b:box(V(4, 0.5, 4), CF(0, 2.8, 0), col, { role = "primary", material = if throne then Enum.Material.Foil else Enum.Material.WoodPlanks })
	b:box(V(4, if throne then 7 else 4.5, 0.5), CF(0, if throne then 6.3 else 5.2, 1.75), col, { role = "primary", material = if throne then Enum.Material.Foil else Enum.Material.WoodPlanks })
	for _, x in { -1.7, 1.7 } do
		for _, z in { -1.7, 1.7 } do
			b:box(V(0.4, 2.6, 0.4), CF(x, 1.3, z), Kit.darker(col, 0.2), { role = "secondary" })
		end
	end
	if throne then
		b:box(V(3.6, 0.6, 3.6), CF(0, 3.3, 0), rgb(170, 30, 50), { role = "accent", material = Enum.Material.Fabric })
	end
	return if throne then 10 else 7.5, 2.5
end
OBJ.sofa = function(b, rng)
	local col = rng:pick({ rgb(200, 60, 60), rgb(60, 110, 200), rgb(120, 170, 90), rgb(130, 100, 160) })
	b:box(V(10, 2, 4), CF(0, 1.5, 0), col, { role = "primary", material = Enum.Material.Fabric })
	b:box(V(10, 3.4, 1.2), CF(0, 3.2, 1.6), col, { role = "primary", material = Enum.Material.Fabric })
	for _, x in { -5.2, 5.2 } do
		b:box(V(1.2, 3, 4), CF(x, 2, 0), Kit.darker(col, 0.15), { role = "secondary", material = Enum.Material.Fabric })
	end
	return 5, 5.5
end
OBJ.bed = function(b, rng)
	local col = rng:pick({ rgb(90, 140, 230), rgb(240, 120, 170), rgb(120, 200, 140) })
	b:box(V(7, 1.6, 11), CF(0, 1.3, 0), rgb(150, 105, 65), { role = "secondary", material = Enum.Material.WoodPlanks })
	b:box(V(6.6, 1, 10.4), CF(0, 2.6, 0), rgb(250, 250, 250), { role = "fixed", material = Enum.Material.Fabric })
	b:box(V(6.8, 0.5, 6.5), CF(0, 3.2, 1.8), col, { role = "primary", material = Enum.Material.Fabric })
	b:box(V(4, 0.9, 2), CF(0, 3.4, -4), rgb(250, 250, 250), { role = "fixed", material = Enum.Material.Fabric })
	b:box(V(7, 4, 0.6), CF(0, 3, -5.4), rgb(150, 105, 65), { role = "secondary", material = Enum.Material.WoodPlanks })
	return 5, 6
end
OBJ.lamp = function(b, rng)
	local col = rng:pick({ rgb(255, 200, 120), rgb(255, 150, 200), rgb(150, 220, 255) })
	b:cylY(0.5, 3, CF(0, 0.25, 0), rgb(50, 50, 55), { role = "secondary" })
	b:cylY(8, 0.4, CF(0, 4.5, 0), rgb(60, 60, 65), { role = "secondary", material = Enum.Material.Metal })
	local shade = b:cone(3, 4, CF(0, 7.5, 0), col, 3, { role = "primary", material = Enum.Material.Fabric })
	local bulb = b:ball(1.4, CF(0, 8, 0), rgb(255, 250, 220), { role = "fixed", material = Enum.Material.Neon })
	b:light(bulb, col, 22, 2)
	local _ = shade
	return 10.5, 2
end
OBJ.fridge = function(b, _rng)
	b:box(V(5, 10, 4.4), CF(0, 5, 0), rgb(235, 240, 245), { role = "primary", material = Enum.Material.Metal })
	b:box(V(4.9, 0.15, 0.1), CF(0, 6.6, -2.25), rgb(150, 150, 160), { role = "fixed" })
	for _, y in { 4, 8 } do
		b:box(V(0.3, 1.6, 0.3), CF(1.8, y, -2.4), rgb(160, 160, 170), { role = "fixed", material = Enum.Material.Metal })
	end
	b:ball(0.8, CF(-1, 8.6, -2.25), rgb(255, 80, 80), { role = "accent" })
	return 10, 3
end
OBJ.piano = function(b, _rng)
	b:box(V(10, 5, 5), CF(0, 4, 1), rgb(20, 20, 25), { role = "primary", reflectance = 0.2 })
	b:box(V(9.6, 0.5, 1.6), CF(0, 4.2, -2.2), rgb(250, 250, 250), { role = "fixed" })
	for k = -6, 6 do
		if k % 7 ~= 2 and k % 7 ~= 6 then
			b:box(V(0.35, 0.3, 1), CF(k * 0.7 + 0.35, 4.55, -2.0), rgb(15, 15, 15), { role = "fixed" })
		end
	end
	for _, x in { -4.5, 4.5 } do
		b:box(V(0.6, 2, 0.6), CF(x, 1, -1.5), rgb(20, 20, 25), { role = "secondary" })
	end
	return 7, 5.5
end
OBJ.guitar = function(b, rng)
	local col = rng:pick({ rgb(200, 40, 40), rgb(230, 150, 50), rgb(40, 40, 45) })
	b:part("ball", V(4, 5, 1.2), CF(0, 3, 0), col, { role = "primary" })
	b:part("ball", V(3.2, 3.6, 1.2), CF(0, 5.5, 0), col, { role = "primary" })
	b:part("cyl", V(0.1, 1.2, 1.2), CF(0, 4.2, -0.62) * ANG(0, rad(90), 0), rgb(20, 20, 20), { role = "fixed" })
	b:box(V(0.8, 6, 0.4), CF(0, 9.6, 0), rgb(110, 75, 45), { role = "secondary" })
	b:box(V(1.4, 1.4, 0.5), CF(0, 13.2, 0), rgb(90, 60, 35), { role = "secondary" })
	return 14, 2.5
end
OBJ.drum = function(b, _rng)
	b:cylY(3, 5, CF(0, 1.5, 0), rgb(200, 40, 50), { role = "primary" })
	b:cylY(0.2, 5.1, CF(0, 3.05, 0), rgb(245, 245, 245), { role = "fixed" })
	for _, x in { -4, 4 } do
		b:cylY(2.4, 3, CF(x, 3.2, 1), rgb(200, 40, 50), { role = "primary" })
		b:cylY(5, 0.2, CF(x * 1.3, 2.5, -1.5), rgb(190, 190, 200), { role = "fixed", material = Enum.Material.Metal })
		b:cylY(0.1, 3.4, CF(x * 1.3, 5, -1.5), rgb(250, 210, 60), { role = "fixed", material = Enum.Material.Foil })
	end
	return 5, 6
end
OBJ.clock = function(b, _rng)
	b:part("cyl", V(1, 8, 8), CF(0, 6, 0) * ANG(0, rad(90), 0), rgb(160, 110, 60), { role = "primary", material = Enum.Material.Wood })
	b:part("cyl", V(0.2, 7, 7), CF(0, 6, -0.55) * ANG(0, rad(90), 0), rgb(250, 245, 230), { role = "fixed" })
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		b:box(V(0.3, 0.6, 0.1), CF(math.sin(a) * 3, 6 + math.cos(a) * 3, -0.7) * ANG(0, 0, -a), rgb(30, 30, 30), { role = "fixed" })
	end
	local hand = b:box(V(0.25, 2.6, 0.1), CF(0, 7.2, -0.75), rgb(20, 20, 20), { role = "fixed", name = "Ponteiro" })
	hand:AddTag("IdeiasGirar")
	hand:SetAttribute("GirarEixo", "Z")
	hand:SetAttribute("GirarVel", 1)
	hand:SetAttribute("GirarPivo", Vector3.new(0, -1.2, 0))
	b:box(V(2, 2, 2), CF(0, 1, 0), rgb(140, 95, 50), { role = "secondary" })
	return 10, 4
end
OBJ.book = function(b, rng)
	local col = rng:pick({ rgb(160, 40, 40), rgb(40, 80, 160), rgb(60, 130, 70), rgb(120, 60, 150) })
	b:box(V(6, 1.4, 8), CF(0, 0.7, 0), rgb(245, 240, 225), { role = "fixed" })
	b:box(V(6.4, 0.25, 8.4), CF(0, 0.12, 0), col, { role = "primary" })
	b:box(V(6.4, 0.25, 8.4), CF(0, 1.5, 0), col, { role = "primary" })
	b:box(V(0.4, 1.6, 8.4), CF(-3.2, 0.8, 0), col, { role = "primary" })
	b:box(V(2, 2, 0.1), CF(0, 1.65, 0) * ANG(rad(90), 0, 0), rgb(255, 215, 60), { role = "accent", material = Enum.Material.Neon })
	return 2, 4.5
end
OBJ.ball = function(b, rng)
	local kind = rng:int(1, 3)
	if kind == 1 then
		b:ball(5, CF(0, 2.5, 0), rgb(250, 250, 250), { role = "primary" })
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			b:ball(1.2, CF(math.cos(a) * 2.1, 2.5 + math.sin(a) * 2.1, -0.6), rgb(25, 25, 30), { role = "fixed" })
		end
	elseif kind == 2 then
		b:ball(5, CF(0, 2.5, 0), rgb(240, 120, 40), { role = "primary" })
		b:part("cyl", V(0.1, 5.05, 5.05), CF(0, 2.5, 0), rgb(30, 20, 15), { role = "fixed" })
		b:part("cyl", V(0.1, 5.05, 5.05), CF(0, 2.5, 0) * ANG(0, rad(90), 0), rgb(30, 20, 15), { role = "fixed" })
	else
		b:ball(5, CF(0, 2.5, 0), rgb(255, 80, 80), { role = "primary" })
		b:part("cyl", V(1.6, 5.05, 5.05), CF(0, 2.5, 0), rgb(255, 230, 60), { role = "fixed" })
		b:part("cyl", V(1.6, 5.05, 5.05), CF(0, 2.5, 0) * ANG(0, rad(90), 0), rgb(60, 140, 255), { role = "fixed" })
	end
	return 5, 2.5
end
OBJ.balloon = function(b, rng)
	local col = rng:pick(Kit.RainbowColors)
	b:part("ball", V(4, 4.8, 4), CF(0, 9, 0), col, { role = "primary", reflectance = 0.15 })
	b:part("wedge", V(0.6, 0.6, 0.6), CF(0, 6.4, 0) * ANG(rad(180), 0, 0), col, { role = "primary" })
	b:box(V(0.08, 6, 0.08), CF(0, 3.2, 0), rgb(240, 240, 240), { role = "fixed" })
	return 11.5, 2
end
OBJ.gift = function(b, rng)
	local col = rng:pick(Kit.RainbowColors)
	b:box(V(5, 5, 5), CF(0, 2.5, 0), col, { role = "primary" })
	b:box(V(5.1, 5.1, 1), CF(0, 2.5, 0), rgb(255, 230, 80), { role = "fixed" })
	b:box(V(1, 5.1, 5.1), CF(0, 2.5, 0), rgb(255, 230, 80), { role = "fixed" })
	b:box(V(5.4, 1, 5.4), CF(0, 5.3, 0), Kit.darker(col, 0.1), { role = "secondary" })
	for _, s in { -1, 1 } do
		b:part("ball", V(1.8, 1.2, 1.2), CF(s * 0.9, 6.2, 0) * ANG(0, 0, s * rad(30)), rgb(255, 230, 80), { role = "fixed" })
	end
	return 7, 3
end
OBJ.chest = function(b, _rng)
	local wood = rgb(130, 85, 45)
	b:box(V(7, 4, 4.6), CF(0, 2, 0), wood, { role = "primary", material = Enum.Material.WoodPlanks })
	b:part("cyl", V(7, 4.6, 4.6), CF(0, 4, 0), wood, { role = "primary", material = Enum.Material.WoodPlanks })
	for _, x in { -2.6, 2.6 } do
		b:box(V(0.5, 4.2, 4.8), CF(x, 2.1, 0), rgb(220, 180, 60), { role = "fixed", material = Enum.Material.Foil })
	end
	b:box(V(1, 1.2, 0.3), CF(0, 3.2, -2.4), rgb(240, 200, 60), { role = "fixed", material = Enum.Material.Foil })
	local glow = b:ball(2, CF(0, 4.4, 0), rgb(255, 215, 80), { role = "fixed", material = Enum.Material.Neon, transparency = 0.5, collide = false })
	b:light(glow, rgb(255, 210, 90), 14, 2)
	return 6.5, 4
end
OBJ.coin = function(b, _rng)
	b:part("cyl", V(0.5, 4, 4), CF(0, 2.2, 0) * ANG(0, rad(90), 0), rgb(255, 205, 50), { role = "primary", material = Enum.Material.Foil })
	b:box(V(1, 1.6, 0.6), CF(0, 2.2, 0), rgb(240, 180, 40), { role = "fixed", material = Enum.Material.Foil })
	b:part("cyl", V(0.6, 4.2, 4.2), CF(0, 2.2, 0) * ANG(0, rad(90), 0), rgb(230, 175, 40), { role = "fixed", material = Enum.Material.Foil, transparency = 0.6 })
	local glint = b:ball(0.5, CF(1.2, 3.3, -0.3), rgb(255, 250, 220), { role = "fixed", material = Enum.Material.Neon })
	local _ = glint
	return 4.2, 2
end
OBJ.gem = function(b, rng)
	local col = rng:pick({ rgb(120, 220, 255), rgb(255, 60, 90), rgb(60, 220, 120), rgb(70, 110, 255) })
	b:part("wedge", V(3, 3, 3), CF(0, 4.5, 0), col, { role = "primary", material = Enum.Material.Glass, transparency = 0.15, reflectance = 0.3 })
	b:part("wedge", V(3, 3, 3), CF(0, 4.5, 0) * ANG(0, rad(180), 0), col, { role = "primary", material = Enum.Material.Glass, transparency = 0.15, reflectance = 0.3 })
	b:part("wedge", V(3, 3, 3), CF(0, 1.5, 0) * ANG(rad(180), 0, 0), col, { role = "primary", material = Enum.Material.Glass, transparency = 0.15 })
	b:part("wedge", V(3, 3, 3), CF(0, 1.5, 0) * ANG(rad(180), rad(180), 0), col, { role = "primary", material = Enum.Material.Glass, transparency = 0.15 })
	local core = b:ball(1.2, CF(0, 3, 0), col, { role = "accent", material = Enum.Material.Neon })
	b:light(core, col, 14, 2)
	return 6, 2
end
OBJ.crown = function(b, _rng)
	local gold = rgb(255, 205, 50)
	b:part("cyl", V(1.6, 5, 5), CF(0, 0.8, 0) * ANG(0, 0, rad(90)), gold, { role = "primary", material = Enum.Material.Foil })
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		b:part("wedge", V(1.0, 2, 0.4), CF(math.cos(a) * 2.2, 2.6, math.sin(a) * 2.2) * ANG(0, -a + math.pi / 2, 0), gold, { role = "primary", material = Enum.Material.Foil })
		b:ball(0.5, CF(math.cos(a) * 2.4, 1, math.sin(a) * 2.4), Kit.RainbowColors[(k % 6) + 1], { role = "accent", material = Enum.Material.Neon })
	end
	return 3.6, 2.5
end
OBJ.trophy = function(b, _rng)
	local gold = rgb(255, 205, 50)
	b:box(V(3, 1.4, 3), CF(0, 0.7, 0), rgb(40, 40, 45), { role = "secondary" })
	b:cylY(2.6, 0.7, CF(0, 2.7, 0), gold, { role = "primary", material = Enum.Material.Foil })
	b:part("ball", V(3.4, 3.4, 3.4), CF(0, 5.4, 0), gold, { role = "primary", material = Enum.Material.Foil })
	for _, s in { -1, 1 } do
		b:part("cyl", V(0.4, 1.6, 1.6), CF(s * 2, 5.6, 0), gold, { role = "primary", material = Enum.Material.Foil })
	end
	return 7, 2
end
OBJ.barrel = function(b, _rng)
	b:cylY(5, 3.6, CF(0, 2.5, 0), rgb(200, 40, 35), { role = "primary" })
	for _, y in { 0.8, 4.2 } do
		b:cylY(0.4, 3.7, CF(0, y, 0), rgb(60, 60, 65), { role = "fixed", material = Enum.Material.Metal })
	end
	b:box(V(1.6, 1.6, 0.1), CF(0, 2.5, -1.82) * ANG(0, 0, rad(45)), rgb(255, 220, 40), { role = "fixed" })
	return 5, 2
end
OBJ.crate = function(b, _rng)
	local wood = rgb(170, 125, 70)
	b:box(V(5, 5, 5), CF(0, 2.5, 0), wood, { role = "primary", material = Enum.Material.WoodPlanks })
	for _, s in { -1, 1 } do
		b:box(V(5.1, 0.5, 0.5), CF(0, 2.5 + s * 2.2, -2.3), Kit.darker(wood, 0.25), { role = "secondary" })
	end
	b:box(V(0.5, 6.4, 0.5), CF(0, 2.5, -2.4) * ANG(0, 0, rad(45)), Kit.darker(wood, 0.25), { role = "secondary" })
	return 5, 2.5
end
OBJ.tnt = function(b, _rng)
	for k = -1, 1 do
		b:cylY(5, 1.6, CF(k * 1.6, 2.5, 0), rgb(220, 40, 35), { role = "primary" })
	end
	b:box(V(5, 1.2, 1.8), CF(0, 2.5, 0), rgb(245, 240, 230), { role = "fixed" })
	local fuse = b:box(V(0.15, 1.2, 0.15), CF(0, 5.5, 0), rgb(40, 40, 40), { role = "fixed", name = "Pavio" })
	local sp = Instance.new("Sparkles")
	sp.SparkleColor = rgb(255, 200, 80)
	sp.Parent = fuse
	return 6, 2.5
end
OBJ.cannon = function(b, _rng)
	b:box(V(4, 1.6, 6), CF(0, 1.4, 0), rgb(120, 80, 45), { role = "secondary", material = Enum.Material.WoodPlanks })
	for _, s in { -1, 1 } do
		b:part("cyl", V(0.6, 3, 3), CF(s * 2.2, 1.5, 0), rgb(90, 60, 35), { role = "secondary" })
	end
	b:part("cyl", V(7, 2, 2), CF(0, 3, -1.5) * ANG(rad(20), rad(90), 0), rgb(40, 40, 45), { role = "primary", material = Enum.Material.Metal })
	b:ball(2.4, CF(0, 2.6, 1.8), rgb(40, 40, 45), { role = "primary", material = Enum.Material.Metal })
	return 5, 4
end
OBJ.magnet = function(b, _rng)
	for _, s in { -1, 1 } do
		b:box(V(1.8, 6, 1.8), CF(s * 2.2, 4, 0), rgb(220, 40, 40), { role = "primary" })
		b:box(V(1.8, 1.4, 1.8), CF(s * 2.2, 0.7, 0), rgb(220, 220, 230), { role = "fixed", material = Enum.Material.Metal })
	end
	b:part("cyl", V(1.8, 6.2, 6.2), CF(0, 7, 0), rgb(220, 40, 40), { role = "primary" })
	return 10, 4
end
OBJ.disco_ball = function(b, _rng)
	b:box(V(0.2, 6, 0.2), CF(0, 13, 0), rgb(200, 200, 210), { role = "fixed" })
	local ball = b:ball(5, CF(0, 9, 0), rgb(220, 225, 235), { role = "primary", material = Enum.Material.Foil, reflectance = 0.6, name = "Globo" })
	ball:AddTag("IdeiasGirar")
	ball:SetAttribute("GirarEixo", "Y")
	ball:SetAttribute("GirarVel", 1)
	for k = 0, 3 do
		local l = Instance.new("SpotLight")
		l.Color = Kit.RainbowColors[k + 1]
		l.Brightness = 4
		l.Range = 40
		l.Angle = 30
		l.Face = ({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right })[k + 1]
		l.Parent = ball
	end
	b:cylY(0.6, 6, CF(0, 0.3, 0), rgb(40, 40, 50), { role = "secondary" })
	b:cylY(16, 0.3, CF(0, 8, 2), rgb(40, 40, 50), { role = "secondary" })
	return 16, 3
end
OBJ.campfire = function(b, _rng)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		b:ball(1.3, CF(math.cos(a) * 2.6, 0.5, math.sin(a) * 2.6), rgb(120, 120, 125), { role = "fixed", material = Enum.Material.Slate })
	end
	for k = 0, 3 do
		local a = k / 4 * math.pi
		b:box(V(0.7, 0.7, 4), CF(0, 0.6, 0) * ANG(0, a, 0), rgb(110, 70, 40), { role = "secondary", material = Enum.Material.Wood })
	end
	local core = b:ball(1.4, CF(0, 1.4, 0), rgb(255, 140, 40), { role = "fixed", material = Enum.Material.Neon, collide = false })
	local f = Instance.new("Fire")
	f.Size = 7
	f.Heat = 10
	f.Parent = core
	b:light(core, rgb(255, 150, 60), 26, 2.5)
	return 3, 3.5
end
OBJ.bench = function(b, _rng)
	local wood = rgb(150, 100, 60)
	for k = 0, 2 do
		b:box(V(9, 0.4, 0.9), CF(0, 2.4, -0.9 + k * 1), wood, { role = "primary", material = Enum.Material.WoodPlanks })
	end
	b:box(V(9, 1.6, 0.4), CF(0, 3.6, 1.3) * ANG(rad(-10), 0, 0), wood, { role = "primary", material = Enum.Material.WoodPlanks })
	for _, x in { -3.8, 3.8 } do
		b:box(V(0.5, 2.4, 3), CF(x, 1.2, 0.2), rgb(40, 40, 45), { role = "secondary", material = Enum.Material.Metal })
	end
	return 4.5, 4.5
end
OBJ.flag = function(b, _rng)
	b:cylY(14, 0.5, CF(0, 7, 0), rgb(220, 220, 225), { role = "fixed", material = Enum.Material.Metal })
	local cloth = b:box(V(0.2, 4, 6.4), CF(0, 11.6, -3.3), rgb(30, 160, 70), { role = "primary", material = Enum.Material.Fabric })
	b:box(V(0.25, 2.4, 3.6), CF(0, 11.6, -3.3) * ANG(rad(45), 0, 0), rgb(255, 220, 40), { role = "fixed", material = Enum.Material.Fabric })
	b:part("cyl", V(0.3, 1.6, 1.6), CF(0, 11.6, -3.3), rgb(40, 70, 170), { role = "fixed" })
	local _ = cloth
	return 14, 3.5
end
OBJ.toilet = function(b, rng)
	local gold = rng:chance(0.15)
	local col = if gold then rgb(255, 205, 50) else rgb(250, 250, 252)
	local mat = if gold then Enum.Material.Foil else Enum.Material.SmoothPlastic
	b:cylY(2.6, 3, CF(0, 1.3, -0.4), col, { role = "primary", material = mat })
	b:part("cyl", V(0.7, 4.4, 5.2), CF(0, 2.9, -0.8) * ANG(0, 0, rad(90)), col, { role = "primary", material = mat })
	b:part("cyl", V(0.2, 3.4, 4.2), CF(0, 3.3, -0.8) * ANG(0, 0, rad(90)), rgb(120, 190, 255), { role = "fixed", material = Enum.Material.Glass, transparency = 0.3 })
	b:box(V(4.4, 4, 1.8), CF(0, 4.4, 2.2), col, { role = "primary", material = mat })
	return 6.4, 3
end
OBJ.umbrella = function(b, rng)
	local col = rng:pick(Kit.RainbowColors)
	b:cylY(10, 0.35, CF(0, 5, 0), rgb(220, 220, 225), { role = "fixed", material = Enum.Material.Metal })
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		b:part("wedge", V(2.6, 1.6, 4.4), CF(math.cos(a) * 2, 9.6, math.sin(a) * 2) * ANG(0, -a - math.pi / 2, 0), if k % 2 == 0 then col else rgb(250, 250, 250), { role = "fixed", material = Enum.Material.Fabric })
	end
	return 11, 5
end
OBJ.rubber_duck = function(b, _rng)
	local y = rgb(255, 215, 40)
	b:part("ball", V(6, 4.4, 7), CF(0, 2.2, 0.5), y, { role = "primary" })
	b:ball(3.8, CF(0, 5.2, -1.4), y, { role = "primary" })
	b:box(V(1.8, 0.6, 1.6), CF(0, 4.9, -3.6), rgb(255, 130, 30), { role = "fixed" })
	for _, s in { -1, 1 } do
		b:ball(0.5, CF(s * 0.8, 5.8, -3.1), rgb(20, 20, 20), { role = "eye" })
	end
	b:part("wedge", V(2, 1.6, 1.6), CF(0, 3.4, 3.8) * ANG(rad(-30), 0, 0), y, { role = "primary" })
	return 7, 3.5
end
OBJ.teddy = function(b, rng)
	local col = rng:pick({ rgb(170, 120, 75), rgb(250, 180, 200), rgb(200, 200, 210) })
	local m = Enum.Material.Fabric
	b:part("ball", V(4, 4.6, 3.6), CF(0, 2.6, 0), col, { role = "primary", material = m })
	b:ball(3.4, CF(0, 6, 0), col, { role = "primary", material = m })
	for _, s in { -1, 1 } do
		b:ball(1.3, CF(s * 1.4, 7.4, 0), col, { role = "primary", material = m })
		b:ball(1.6, CF(s * 2.2, 3.2, -0.3), col, { role = "primary", material = m })
		b:ball(1.8, CF(s * 1.2, 0.8, -0.8), col, { role = "primary", material = m })
		b:ball(0.4, CF(s * 0.6, 6.4, -1.5), rgb(20, 20, 20), { role = "eye" })
	end
	b:ball(1.3, CF(0, 5.6, -1.4), Kit.lighter(col, 0.4), { role = "secondary", material = m })
	b:ball(0.4, CF(0, 5.9, -2.0), rgb(30, 20, 20), { role = "fixed" })
	b:part("wedge", V(2, 1, 0.4), CF(0, 4.6, -1.7), rgb(220, 40, 60), { role = "accent" })
	return 8, 3
end
OBJ.snowman = function(b, _rng)
	local snow = rgb(250, 252, 255)
	b:ball(6, CF(0, 3, 0), snow, { role = "primary", material = Enum.Material.Snow })
	b:ball(4.4, CF(0, 7.6, 0), snow, { role = "primary", material = Enum.Material.Snow })
	b:ball(3.2, CF(0, 10.9, 0), snow, { role = "primary", material = Enum.Material.Snow })
	b:cone(1.6, 0.5, CF(0, 10.9, -1.5) * ANG(rad(-90), 0, 0), rgb(255, 130, 30), 2, { role = "fixed" })
	for _, s in { -1, 1 } do
		b:ball(0.4, CF(s * 0.6, 11.4, -1.4), rgb(20, 20, 20), { role = "eye" })
		b:beam(V(s * 2, 8, 0), V(s * 4.4, 9.6, 0), 0.25, rgb(110, 70, 40), { role = "fixed" })
	end
	b:part("cyl", V(0.25, 3.6, 3.6), CF(0, 12.4, 0) * ANG(0, 0, rad(90)), rgb(25, 25, 30), { role = "fixed" })
	b:cylY(2, 2.4, CF(0, 13.5, 0), rgb(25, 25, 30), { role = "fixed" })
	b:part("cyl", V(4.6, 0.6, 0.6), CF(0, 9.3, 0) * ANG(0, 0, rad(90)), rgb(220, 40, 40), { role = "accent" })
	return 14.5, 3
end
OBJ.pumpkin = function(b, _rng)
	local o = rgb(250, 130, 30)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		b:part("ball", V(3, 5, 3), CF(math.cos(a) * 1.4, 2.5, math.sin(a) * 1.4), o, { role = "primary" })
	end
	b:cylY(1.4, 0.6, CF(0, 5.4, 0), rgb(70, 120, 40), { role = "fixed" })
	for _, s in { -1, 1 } do
		b:part("wedge", V(0.8, 0.8, 0.2), CF(s * 0.9, 3.2, -2.75), rgb(255, 230, 80), { role = "fixed", material = Enum.Material.Neon })
	end
	b:box(V(2.2, 0.5, 0.2), CF(0, 1.8, -2.8), rgb(255, 230, 80), { role = "fixed", material = Enum.Material.Neon })
	return 6, 3
end
OBJ.xmas_tree = function(b, _rng)
	b:cylY(2, 1.4, CF(0, 1, 0), rgb(110, 70, 40), { role = "fixed" })
	for k = 0, 3 do
		b:cone(5, 11 - k * 2.4, CF(0, 2 + k * 3.4, 0), rgb(40, 130, 60), 3, { role = "primary" })
	end
	for k = 0, 11 do
		local a = k * 1.7
		local y = 3 + (k % 6) * 2
		local r = 4.4 - (k % 6) * 0.7
		b:ball(0.8, CF(math.cos(a) * r, y, math.sin(a) * r), Kit.RainbowColors[(k % 6) + 1], { role = "accent", material = Enum.Material.Neon })
	end
	local star = b:ball(1.6, CF(0, 17.5, 0), rgb(255, 225, 60), { role = "fixed", material = Enum.Material.Neon })
	b:light(star, rgb(255, 220, 120), 20, 2)
	return 18.5, 5.5
end
OBJ.toy_car = function(b, rng)
	local col = rng:pick(Kit.RainbowColors)
	b:box(V(3, 1.2, 5), CF(0, 1.2, 0), col, { role = "primary" })
	b:box(V(2.6, 1, 2.4), CF(0, 2.3, 0.4), rgb(150, 210, 240), { role = "fixed", material = Enum.Material.Glass, transparency = 0.2 })
	for _, x in { -1.6, 1.6 } do
		for _, z in { -1.6, 1.6 } do
			b:part("cyl", V(0.6, 1.4, 1.4), CF(x, 0.7, z), rgb(30, 30, 35), { role = "fixed" })
		end
	end
	return 3, 2.5
end
OBJ.hat = function(b, rng)
	local col = rng:pick({ rgb(30, 30, 35), rgb(170, 40, 50), rgb(140, 95, 50) })
	b:part("cyl", V(0.4, 7, 7), CF(0, 0.2, 0) * ANG(0, 0, rad(90)), col, { role = "primary", material = Enum.Material.Fabric })
	b:cylY(4.4, 4, CF(0, 2.6, 0), col, { role = "primary", material = Enum.Material.Fabric })
	b:cylY(0.8, 4.1, CF(0, 1.2, 0), rgb(220, 40, 60), { role = "accent" })
	return 5, 3.5
end
OBJ.mirror = function(b, _rng)
	b:box(V(6, 10, 0.6), CF(0, 6, 0), rgb(220, 180, 60), { role = "primary", material = Enum.Material.Foil })
	b:box(V(5, 9, 0.1), CF(0, 6, -0.32), rgb(220, 235, 255), { role = "fixed", material = Enum.Material.Glass, reflectance = 0.9 })
	b:box(V(4, 1, 2), CF(0, 0.5, 0), rgb(220, 180, 60), { role = "primary", material = Enum.Material.Foil })
	return 11, 3
end
OBJ.vacuum = function(b, _rng)
	b:cylY(1.2, 5, CF(0, 0.6, 0), rgb(40, 40, 45), { role = "primary" })
	b:cylY(0.2, 4.4, CF(0, 1.25, 0), rgb(150, 150, 160), { role = "secondary", material = Enum.Material.Metal })
	b:ball(0.6, CF(0, 1.4, -1.5), rgb(80, 220, 255), { role = "accent", material = Enum.Material.Neon })
	return 1.4, 2.5
end
OBJ.fan = function(b, _rng)
	b:cylY(0.6, 4, CF(0, 0.3, 0), rgb(240, 240, 245), { role = "secondary" })
	b:cylY(7, 0.6, CF(0, 3.8, 0), rgb(240, 240, 245), { role = "secondary" })
	local hub = b:part("cyl", V(1, 1.4, 1.4), CF(0, 8, -0.6) * ANG(0, rad(90), 0), rgb(80, 160, 255), { role = "primary", name = "Helice" })
	hub:AddTag("IdeiasGirar")
	hub:SetAttribute("GirarEixo", "Z")
	hub:SetAttribute("GirarVel", 6)
	for k = 0, 2 do
		local blade = b:box(V(1.4, 3.4, 0.2), CF(0, 8, -0.8) * ANG(0, 0, k / 3 * math.pi * 2) * CF(0, 1.8, 0), rgb(80, 160, 255), { role = "primary" })
		blade.Parent = hub
	end
	return 10, 2.5
end
OBJ.speaker = function(b, _rng)
	b:box(V(5, 9, 4), CF(0, 4.5, 0), rgb(30, 30, 35), { role = "primary" })
	for _, y in { 2.6, 6.6 } do
		b:part("cyl", V(0.3, 3.2, 3.2), CF(0, y, -2.05) * ANG(0, rad(90), 0), rgb(60, 60, 70), { role = "secondary" })
		b:part("cyl", V(0.35, 1.2, 1.2), CF(0, y, -2.1) * ANG(0, rad(90), 0), rgb(255, 60, 200), { role = "accent", material = Enum.Material.Neon })
	end
	return 9, 3
end
OBJ.sign = function(b, rng)
	b:cylY(8, 0.5, CF(-3, 4, 0), rgb(200, 200, 205), { role = "fixed", material = Enum.Material.Metal })
	b:cylY(8, 0.5, CF(3, 4, 0), rgb(200, 200, 205), { role = "fixed", material = Enum.Material.Metal })
	local board = b:box(V(8, 4, 0.4), CF(0, 9, 0), rgb(40, 130, 70), { role = "primary" })
	screen(board, rng:pick({ "IDEIAS SEM LIMITES", "CUIDADO: DRAGÕES", "PROIBIDO ENTEDIAR", "CRIE ALGO!" }), rgb(30, 110, 60))
	return 11, 4
end

-- COMIDAS -------------------------------------------------------------------------
local FOOD: { [string]: Fn } = {}

FOOD.pizza = function(b, _rng)
	b:part("cyl", V(0.8, 9, 9), CF(0, 0.4, 0) * ANG(0, 0, rad(90)), rgb(230, 170, 90), { role = "secondary" })
	b:part("cyl", V(0.3, 8, 8), CF(0, 0.9, 0) * ANG(0, 0, rad(90)), rgb(250, 210, 90), { role = "primary" })
	for k = 0, 7 do
		local a = k * 0.8
		local r = 1.5 + (k % 3) * 1.1
		b:part("cyl", V(0.3, 1.4, 1.4), CF(math.cos(a) * r, 1.1, math.sin(a) * r) * ANG(0, 0, rad(90)), rgb(200, 50, 40), { role = "accent" })
	end
	return 1.3, 4.5
end
FOOD.burger = function(b, _rng)
	b:part("ball", V(7, 3.4, 7), CF(0, 4.6, 0), rgb(220, 150, 70), { role = "primary" })
	b:part("cyl", V(0.5, 7.2, 7.2), CF(0, 3.2, 0) * ANG(0, 0, rad(90)), rgb(250, 210, 60), { role = "fixed" })
	b:part("cyl", V(1.2, 6.8, 6.8), CF(0, 2.4, 0) * ANG(0, 0, rad(90)), rgb(110, 60, 35), { role = "secondary" })
	b:part("cyl", V(0.4, 7.4, 7.4), CF(0, 1.6, 0) * ANG(0, 0, rad(90)), rgb(90, 190, 60), { role = "fixed" })
	b:part("cyl", V(1.2, 6.8, 6.8), CF(0, 0.8, 0) * ANG(0, 0, rad(90)), rgb(220, 150, 70), { role = "primary" })
	for k = 0, 5 do
		local a = k * 1.05
		b:ball(0.3, CF(math.cos(a) * 1.8, 6.2, math.sin(a) * 1.8), rgb(250, 240, 210), { role = "fixed" })
	end
	return 6.3, 3.7
end
FOOD.hotdog = function(b, _rng)
	b:part("ball", V(3, 2.4, 9), CF(0, 1.2, 0), rgb(230, 170, 90), { role = "primary" })
	b:part("cyl", V(10, 1.6, 1.6), CF(0, 2.2, 0) * ANG(0, rad(90), 0), rgb(200, 80, 50), { role = "secondary" })
	for k = -3, 3 do
		b:box(V(0.3, 0.2, 1.2), CF(math.sin(k) * 0.3, 3.05, k * 1.1) * ANG(0, rad(30 * k), 0), rgb(250, 210, 40), { role = "fixed" })
	end
	return 3, 5
end
FOOD.cake = function(b, rng)
	local icing = rng:pick({ rgb(255, 170, 200), rgb(250, 250, 250), rgb(120, 70, 40) })
	b:cylY(3, 8, CF(0, 1.5, 0), rgb(240, 210, 160), { role = "secondary" })
	b:cylY(0.6, 8.3, CF(0, 3.2, 0), icing, { role = "primary" })
	b:cylY(2.6, 5.6, CF(0, 4.8, 0), rgb(240, 210, 160), { role = "secondary" })
	b:cylY(0.5, 5.9, CF(0, 6.3, 0), icing, { role = "primary" })
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		local c = b:cylY(1.6, 0.35, CF(math.cos(a) * 1.8, 7.3, math.sin(a) * 1.8), Kit.RainbowColors[k + 1], { role = "fixed" })
		local flame = b:ball(0.4, CF(math.cos(a) * 1.8, 8.3, math.sin(a) * 1.8), rgb(255, 200, 60), { role = "fixed", material = Enum.Material.Neon })
		local _ = c
		local _f = flame
	end
	b:ball(1.4, CF(0, 7.2, 0), rgb(220, 30, 50), { role = "accent" })
	return 8.5, 4.2
end
FOOD.donut = function(b, rng)
	local icing = rng:pick({ rgb(255, 140, 190), rgb(110, 60, 30), rgb(250, 250, 250) })
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		b:ball(2.6, CF(math.cos(a) * 2.6, 1.3, math.sin(a) * 2.6), rgb(220, 160, 80), { role = "secondary" })
		b:part("ball", V(2.4, 1.2, 2.4), CF(math.cos(a) * 2.6, 2.2, math.sin(a) * 2.6), icing, { role = "primary" })
		b:box(V(0.6, 0.15, 0.15), CF(math.cos(a) * 2.6, 2.85, math.sin(a) * 2.6) * ANG(0, a * 3, 0), Kit.RainbowColors[(k % 6) + 1], { role = "fixed" })
	end
	return 3, 4
end
FOOD.icecream = function(b, rng)
	b:cone(6, 3.4, CF(0, 6, 0) * ANG(rad(180), 0, 0), rgb(220, 170, 100), 4, { role = "secondary" })
	local flavors = { rgb(255, 180, 210), rgb(250, 245, 220), rgb(120, 70, 40), rgb(160, 230, 160) }
	for k = 0, 2 do
		b:ball(3.6 - k * 0.4, CF(0, 6.6 + k * 2.4, 0), rng:pick(flavors), { role = "primary" })
	end
	b:ball(1, CF(0, 12.4, 0), rgb(220, 30, 50), { role = "accent" })
	return 13, 2
end
FOOD.apple = function(b, _rng)
	b:ball(5, CF(0, 2.5, 0), rgb(220, 40, 40), { role = "primary", reflectance = 0.1 })
	b:cylY(1.2, 0.3, CF(0, 5.3, 0), rgb(100, 70, 40), { role = "fixed" })
	b:part("wedge", V(0.2, 0.8, 1.4), CF(0.6, 5.5, 0) * ANG(0, 0, rad(-40)), rgb(80, 170, 60), { role = "fixed" })
	return 6, 2.5
end
FOOD.banana = function(b, _rng)
	for k = 0, 4 do
		local a = (k - 2) * 0.32
		b:part("cyl", V(2.0, 1.2, 1.2), CF(math.sin(a) * 4, 1 + math.cos(a) * 1.5 - 1.5 + 0.6, 0) * ANG(0, 0, a), rgb(250, 220, 60), { role = "primary" })
	end
	b:box(V(0.4, 0.6, 0.4), CF(4 * math.sin(0.64) + 0.8, 1.2, 0), rgb(90, 70, 40), { role = "fixed" })
	return 2, 4
end
FOOD.watermelon = function(b, _rng)
	b:part("ball", V(6, 5, 8), CF(0, 2.5, 0), rgb(50, 140, 60), { role = "primary" })
	for k = -2, 2 do
		b:part("ball", V(0.3, 5.05, 8.05), CF(k * 1.1, 2.5, 0), rgb(30, 90, 40), { role = "secondary" })
	end
	return 5, 4
end
FOOD.orange = function(b, _rng)
	b:ball(4.4, CF(0, 2.2, 0), rgb(255, 150, 30), { role = "primary", material = Enum.Material.Sand })
	b:part("wedge", V(0.2, 0.6, 1), CF(0.3, 4.5, 0) * ANG(0, 0, rad(-30)), rgb(70, 150, 50), { role = "fixed" })
	b:cylY(0.5, 0.25, CF(0, 4.45, 0), rgb(100, 70, 40), { role = "fixed" })
	return 4.8, 2.2
end
FOOD.strawberry = function(b, _rng)
	b:part("ball", V(4, 4.6, 4), CF(0, 2.3, 0), rgb(230, 40, 60), { role = "primary" })
	b:part("wedge", V(3.4, 1.8, 3.4), CF(0, 0.8, 0) * ANG(rad(180), 0, 0), rgb(230, 40, 60), { role = "primary" })
	for k = 0, 9 do
		local a = k * 2.4
		b:ball(0.25, CF(math.cos(a) * 1.9, 1.6 + (k % 3) * 0.9, math.sin(a) * 1.9), rgb(255, 240, 160), { role = "fixed" })
	end
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		b:part("wedge", V(0.15, 0.5, 1.4), CF(math.cos(a) * 0.7, 4.7, math.sin(a) * 0.7) * ANG(0, -a, 0), rgb(70, 160, 50), { role = "fixed" })
	end
	return 5, 2
end
FOOD.carrot = function(b, _rng)
	b:cone(7, 2.4, CF(0, 7.5, 0) * ANG(rad(180), 0, 0), rgb(255, 130, 30), 4, { role = "primary" })
	for k = 0, 2 do
		b:part("wedge", V(0.2, 3, 1), CF((k - 1) * 0.4, 9, 0) * ANG(0, 0, rad((k - 1) * 20)), rgb(70, 170, 50), { role = "fixed" })
	end
	return 10, 1.2
end
FOOD.cookie = function(b, _rng)
	b:part("cyl", V(0.8, 6, 6), CF(0, 0.4, 0) * ANG(0, 0, rad(90)), rgb(200, 140, 70), { role = "primary" })
	for k = 0, 7 do
		local a = k * 1.9
		b:ball(0.6, CF(math.cos(a) * (1 + k % 3 * 0.8), 0.85, math.sin(a) * (1 + k % 3 * 0.8)), rgb(70, 40, 20), { role = "fixed" })
	end
	return 1, 3
end
FOOD.lollipop = function(b, _rng)
	b:cylY(6, 0.4, CF(0, 3, 0), rgb(250, 250, 250), { role = "fixed" })
	b:part("cyl", V(0.8, 5, 5), CF(0, 7.5, 0), rgb(255, 80, 160), { role = "primary" })
	for k = 0, 2 do
		b:part("cyl", V(0.85, 3.6 - k * 1.1, 3.6 - k * 1.1), CF(0, 7.5, 0), Kit.RainbowColors[(k * 2) + 1], { role = "accent" })
	end
	return 10, 2.5
end
FOOD.chocolate = function(b, _rng)
	for x = 0, 2 do
		for z = 0, 3 do
			b:box(V(1.8, 0.8, 1.8), CF((x - 1) * 1.9, 0.9, (z - 1.5) * 1.9), rgb(95, 55, 30), { role = "primary" })
		end
	end
	b:box(V(5.8, 0.5, 7.8), CF(0, 0.25, 0), rgb(85, 50, 28), { role = "secondary" })
	b:box(V(5.9, 0.4, 3.4), CF(0, 0.7, 2.4), rgb(200, 40, 50), { role = "accent" })
	return 1.3, 4
end
FOOD.bread = function(b, _rng)
	b:part("ball", V(4, 3, 9), CF(0, 1.5, 0), rgb(220, 160, 80), { role = "primary" })
	for k = -1, 1 do
		b:box(V(2.6, 0.2, 0.4), CF(0, 2.95, k * 2.2) * ANG(0, rad(30), 0), rgb(245, 225, 180), { role = "fixed" })
	end
	return 3, 4.5
end
FOOD.cheese = function(b, _rng)
	b:part("wedge", V(5, 3.4, 6), CF(0, 1.7, 0), rgb(250, 210, 60), { role = "primary" })
	for k = 0, 3 do
		b:part("cyl", V(0.3, 0.8, 0.8), CF(2.55, 0.8 + (k % 2) * 1.2, -1.5 + k), rgb(220, 170, 40), { role = "fixed" })
	end
	return 3.4, 3
end
FOOD.egg = function(b, rng)
	local easter = rng:chance(0.5)
	local base = if easter then rng:pick(Kit.RainbowColors) else rgb(250, 245, 235)
	b:part("ball", V(4, 5.2, 4), CF(0, 2.6, 0), base, { role = "primary" })
	if easter then
		for k = 0, 2 do
			b:part("cyl", V(0.35, 4.05 - math.abs(k - 1) * 0.3, 4.05 - math.abs(k - 1) * 0.3), CF(0, 1.8 + k * 0.8, 0) * ANG(0, 0, rad(90)), rgb(255, 255, 255), { role = "fixed" })
		end
	else
		b:part("cyl", V(0.3, 6, 6), CF(0, 0.15, 0) * ANG(0, 0, rad(90)), rgb(250, 250, 250), { role = "fixed" })
		b:part("ball", V(2.4, 0.4, 2.4), CF(0, 0.4, 0), rgb(255, 200, 40), { role = "fixed" })
	end
	return 5.2, 2
end
FOOD.popcorn = function(b, _rng)
	b:cylY(5, 4, CF(0, 2.5, 0), rgb(220, 40, 40), { role = "primary" })
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		b:box(V(0.6, 5.05, 0.6), CF(math.cos(a) * 1.85, 2.5, math.sin(a) * 1.85), rgb(250, 250, 250), { role = "fixed" })
	end
	for k = 0, 11 do
		local a = k * 2.1
		b:ball(1.1, CF(math.cos(a) * (k % 3) * 0.6, 5.3 + (k % 4) * 0.4, math.sin(a) * (k % 3) * 0.6), rgb(255, 245, 210), { role = "fixed" })
	end
	return 7, 2.2
end
FOOD.soda = function(b, rng)
	local col = rng:pick({ rgb(200, 30, 30), rgb(40, 160, 70), rgb(30, 80, 200) })
	b:cylY(6, 3.2, CF(0, 3, 0), col, { role = "primary", reflectance = 0.2 })
	b:cylY(0.4, 3, CF(0, 6.2, 0), rgb(200, 200, 210), { role = "fixed", material = Enum.Material.Metal })
	b:cylY(1.6, 3.25, CF(0, 3, 0), rgb(250, 250, 250), { role = "fixed" })
	return 6.4, 1.6
end
FOOD.coffee = function(b, _rng)
	b:cylY(3, 3.4, CF(0, 1.5, 0), rgb(250, 250, 250), { role = "primary" })
	b:cylY(0.2, 3, CF(0, 2.95, 0), rgb(100, 60, 30), { role = "fixed" })
	b:part("cyl", V(0.5, 1.8, 1.8), CF(2, 1.6, 0) * ANG(0, rad(90), 0), rgb(250, 250, 250), { role = "primary" })
	local steam = b:ball(0.5, CF(0, 3.4, 0), rgb(255, 255, 255), { role = "fixed", transparency = 1, collide = false })
	local s = Instance.new("Smoke")
	s.Color = rgb(255, 255, 255)
	s.Opacity = 0.15
	s.RiseVelocity = 3
	s.Size = 1
	s.Parent = steam
	return 3.5, 2.5
end
FOOD.fries = function(b, _rng)
	b:box(V(4, 4, 2.6), CF(0, 2, 0), rgb(220, 40, 40), { role = "primary" })
	for k = 0, 8 do
		b:box(V(0.5, 3.4, 0.5), CF((k % 3 - 1) * 1, 4.6 + (k % 2) * 0.4, (k // 3 - 1) * 0.6) * ANG(0, 0, rad((k - 4) * 4)), rgb(250, 210, 80), { role = "fixed" })
	end
	return 6.5, 2.2
end
FOOD.brigadeiro = function(b, _rng)
	b:part("cyl", V(0.6, 4.2, 4.2), CF(0, 0.3, 0) * ANG(0, 0, rad(90)), rgb(250, 250, 250), { role = "fixed" })
	b:ball(3.4, CF(0, 2.1, 0), rgb(70, 40, 25), { role = "primary" })
	for k = 0, 14 do
		local a = k * 2.4
		local el = (k % 5) / 5 * math.pi * 0.5
		b:box(V(0.35, 0.12, 0.12), CF(math.cos(a) * math.cos(el) * 1.7, 2.1 + math.sin(el) * 1.7, math.sin(a) * math.cos(el) * 1.7) * ANG(0, a, 0), rgb(40, 22, 14), { role = "fixed" })
	end
	return 3.8, 2
end
FOOD.coxinha = function(b, _rng)
	b:part("ball", V(4, 4, 4), CF(0, 2, 0), rgb(210, 140, 60), { role = "primary", material = Enum.Material.Sand })
	b:cone(3, 3.4, CF(0, 2.8, 0), rgb(210, 140, 60), 3, { role = "primary", material = Enum.Material.Sand })
	return 6, 2
end
FOOD.cheese_bread = function(b, _rng)
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		b:part("ball", V(3, 2.6, 3), CF(math.cos(a) * 1.8, 1.3, math.sin(a) * 1.8), rgb(240, 200, 120), { role = "primary", material = Enum.Material.Sand })
	end
	b:part("ball", V(3, 2.6, 3), CF(0, 2.9, 0), rgb(245, 210, 130), { role = "primary", material = Enum.Material.Sand })
	return 4.2, 3.4
end
FOOD.acai = function(b, _rng)
	b:part("cyl", V(3, 6, 6), CF(0, 1.5, 0) * ANG(0, 0, rad(90)), rgb(110, 70, 40), { role = "secondary", material = Enum.Material.Wood })
	b:part("cyl", V(0.5, 5.4, 5.4), CF(0, 3.1, 0) * ANG(0, 0, rad(90)), rgb(80, 20, 70), { role = "primary" })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		b:part("cyl", V(0.4, 1.2, 1.2), CF(math.cos(a) * 1.6, 3.4, math.sin(a) * 1.6) * ANG(0, 0, rad(90)), rgb(250, 230, 120), { role = "fixed" })
	end
	b:ball(1.2, CF(0, 3.6, 0), rgb(220, 40, 60), { role = "accent" })
	return 3.8, 3
end
FOOD.pastel = function(b, _rng)
	b:part("wedge", V(5, 1, 3), CF(0, 0.5, -1.5) * ANG(0, rad(180), 0), rgb(240, 190, 90), { role = "primary" })
	b:part("wedge", V(5, 1, 3), CF(0, 0.5, 1.5), rgb(240, 190, 90), { role = "primary" })
	for k = -4, 4 do
		b:box(V(0.35, 0.2, 0.5), CF(k * 0.55, 0.12, -3.1), rgb(225, 170, 75), { role = "secondary" })
	end
	return 1, 3
end
FOOD.sushi = function(b, _rng)
	b:part("cyl", V(2.6, 3, 3), CF(0, 1.5, 0) * ANG(0, 0, rad(90)), rgb(20, 40, 25), { role = "secondary" })
	b:part("cyl", V(2.62, 2.4, 2.4), CF(0, 1.5, 0) * ANG(0, 0, rad(90)), rgb(250, 250, 245), { role = "fixed" })
	b:part("cyl", V(2.64, 1, 1), CF(0, 1.5, 0) * ANG(0, 0, rad(90)), rgb(255, 120, 80), { role = "primary" })
	return 3, 1.5
end
FOOD.feijoada = function(b, _rng)
	b:part("cyl", V(3, 7, 7), CF(0, 1.5, 0) * ANG(0, 0, rad(90)), rgb(60, 60, 65), { role = "secondary", material = Enum.Material.Metal })
	b:part("cyl", V(0.4, 6.2, 6.2), CF(0, 3, 0) * ANG(0, 0, rad(90)), rgb(50, 25, 20), { role = "primary" })
	for k = 0, 5 do
		local a = k * 1.1
		b:ball(0.9, CF(math.cos(a) * 1.8, 3.3, math.sin(a) * 1.8), rgb(150, 60, 40), { role = "fixed" })
	end
	for _, s in { -1, 1 } do
		b:part("cyl", V(1, 0.5, 0.5), CF(s * 4, 2.5, 0), rgb(60, 60, 65), { role = "secondary" })
	end
	return 3.4, 4
end

-- NATUREZA --------------------------------------------------------------------------
local NAT: { [string]: Fn } = {}

NAT.tree = function(b, rng)
	local h = rng:range(9, 14)
	local bark = rgb(105, 72, 45)
	b:cylY(h, rng:range(1.6, 2.4), CF(0, h / 2, 0), bark, { role = "secondary", material = Enum.Material.Wood })
	local leaf = rng:pick({ rgb(70, 150, 60), rgb(90, 170, 70), rgb(60, 130, 55), rgb(110, 175, 80) })
	for k = 0, 4 do
		local a = k * 1.3
		local r = if k == 0 then 0 else 3
		b:ball(rng:range(6, 8), CF(math.cos(a) * r, h + rng:range(-1, 2), math.sin(a) * r), Kit.darker(leaf, k * 0.03), { role = "primary", material = Enum.Material.Grass, shadow = k == 0 })
	end
	b:beam(V(0, h * 0.6, 0), V(2.6, h * 0.8, 0.5), 0.8, bark, { role = "secondary" })
	return h + 4, 5
end
NAT.pine = function(b, rng)
	local h = rng:range(12, 18)
	b:cylY(h * 0.4, 1.4, CF(0, h * 0.2, 0), rgb(100, 70, 45), { role = "secondary", material = Enum.Material.Wood })
	local col = rgb(40, 110, 60)
	for k = 0, 3 do
		b:cone(h * 0.35, 9 - k * 2, CF(0, h * 0.25 + k * h * 0.18, 0), Kit.darker(col, k * 0.04), 3, { role = "primary", material = Enum.Material.Grass })
	end
	return h + 2, 4.5
end
NAT.palm = function(b, rng)
	local h = rng:range(12, 16)
	local lean = rng:range(-0.25, 0.25)
	local top = V(lean * h, h, 0)
	for k = 0, 5 do
		local p0 = V(lean * h * k / 6, h * k / 6, 0)
		local p1 = V(lean * h * (k + 1) / 6, h * (k + 1) / 6, 0)
		b:beam(p0, p1, 1.2 - k * 0.08, rgb(150, 110, 70), { role = "secondary", material = Enum.Material.Wood }, true)
	end
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		local tip = top + V(math.cos(a) * 6, -2.5, math.sin(a) * 6)
		b:beam(top, tip, 1.4, rgb(60, 160, 60), { role = "primary", material = Enum.Material.Grass })
	end
	for k = 0, 2 do
		b:ball(1, CF(top + V(math.cos(k * 2) * 0.8, -0.8, math.sin(k * 2) * 0.8)), rgb(120, 80, 40), { role = "fixed" })
	end
	return h + 1, 6
end
NAT.flowers = function(b, rng)
	for k = 0, 9 do
		local a = k * 2.3
		local r = rng:range(0.5, 5)
		local p = V(math.cos(a) * r, 0, math.sin(a) * r)
		local stem = rng:range(1.5, 3)
		b:cylY(stem, 0.2, CF(p + V(0, stem / 2, 0)), rgb(70, 150, 50), { role = "fixed" })
		local col = rng:pick({ rgb(255, 80, 120), rgb(255, 220, 60), rgb(160, 90, 255), rgb(255, 140, 40), rgb(250, 250, 250) })
		for pt = 0, 4 do
			local pa = pt / 5 * math.pi * 2
			b:ball(0.7, CF(p + V(math.cos(pa) * 0.45, stem, math.sin(pa) * 0.45)), col, { role = "primary" })
		end
		b:ball(0.5, CF(p + V(0, stem + 0.05, 0)), rgb(255, 210, 60), { role = "fixed" })
	end
	return 3.5, 5.5
end
NAT.mushroom = function(b, rng)
	local glow = rng:chance(0.5)
	local cap = rng:pick({ rgb(220, 40, 40), rgb(160, 80, 255), rgb(60, 200, 255) })
	b:cylY(4, 1.8, CF(0, 2, 0), rgb(245, 240, 225), { role = "fixed" })
	local top = b:part("ball", V(7, 3.6, 7), CF(0, 4.6, 0), cap, { role = "primary", material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic, name = "Chapeu" })
	for k = 0, 5 do
		local a = k * 1.05
		b:ball(0.8, CF(math.cos(a) * 2.2, 5.9, math.sin(a) * 2.2), rgb(250, 250, 250), { role = "fixed" })
	end
	if glow then
		b:light(top, cap, 16, 1.5)
	end
	return 6.5, 3.5
end
NAT.cactus = function(b, _rng)
	local g = rgb(80, 150, 70)
	b:cylY(10, 2.2, CF(0, 5, 0), g, { role = "primary" })
	b:ball(2.2, CF(0, 10, 0), g, { role = "primary" })
	for _, s in { -1, 1 } do
		b:beam(V(0, 4 + s, 0), V(s * 2.4, 4.5 + s, 0), 1.4, g, { role = "primary" }, true)
		b:cylY(3, 1.4, CF(s * 2.4, 6 + s, 0), g, { role = "primary" })
		b:ball(1.4, CF(s * 2.4, 7.5 + s, 0), g, { role = "primary" })
	end
	b:ball(0.9, CF(0, 11, 0), rgb(255, 120, 180), { role = "accent" })
	return 11.5, 3.5
end
NAT.rock = function(b, rng)
	local col = rng:pick({ rgb(120, 118, 115), rgb(100, 95, 90), rgb(140, 135, 125) })
	for k = 0, 3 do
		local a = k * 1.7
		local s = rng:range(3, 6)
		b:part("ball", V(s * 1.3, s, s * 1.1), CF(math.cos(a) * 1.4, s / 2 - 0.4, math.sin(a) * 1.4) * ANG(0, a, 0), Kit.darker(col, k * 0.04), { role = "primary", material = Enum.Material.Slate })
	end
	return 5, 4
end
NAT.crystal = function(b, rng)
	local col = rng:pick({ rgb(170, 120, 255), rgb(90, 220, 255), rgb(255, 120, 200), rgb(120, 255, 180) })
	for k = 0, 5 do
		local a = k * 1.2
		local h = rng:range(4, 9)
		local tilt = rng:range(0.1, 0.4)
		local base = V(math.cos(a) * 1.2, 0, math.sin(a) * 1.2)
		b:part("wedge", V(1.4, h, 1.4), CF(base + V(0, h / 2, 0)) * ANG(math.cos(a) * tilt, 0, math.sin(a) * tilt), col, { role = "primary", material = Enum.Material.Glass, transparency = 0.15, reflectance = 0.2 })
	end
	local core = b:ball(1.8, CF(0, 1.5, 0), col, { role = "accent", material = Enum.Material.Neon })
	b:light(core, col, 18, 2)
	return 9, 3
end
NAT.cloud = function(b, _rng)
	for k = 0, 5 do
		local a = k * 1.1
		b:ball(5 + (k % 3), CF(math.cos(a) * 3.5, 10 + (k % 2), math.sin(a) * 2), rgb(250, 252, 255), { role = "primary", collide = true })
	end
	return 14, 7
end
NAT.bush = function(b, rng)
	local col = rng:pick({ rgb(70, 140, 60), rgb(90, 160, 70) })
	for k = 0, 3 do
		local a = k * 1.6
		b:ball(rng:range(2.4, 3.6), CF(math.cos(a) * 1.2, 1.4, math.sin(a) * 1.2), col, { role = "primary", material = Enum.Material.Grass })
	end
	if rng:chance(0.5) then
		for k = 0, 3 do
			b:ball(0.5, CF(math.cos(k * 1.7) * 1.8, 2.4, math.sin(k * 1.7) * 1.8), rgb(220, 40, 60), { role = "accent" })
		end
	end
	return 3, 2.5
end
NAT.mountain = function(b, _rng)
	b:cone(40, 60, CF(0, 0, 0), rgb(120, 110, 100), 6, { role = "primary", material = Enum.Material.Slate })
	b:cone(10, 20, CF(0, 30, 0), rgb(250, 252, 255), 3, { role = "fixed", material = Enum.Material.Snow })
	return 40, 30
end
NAT.garden = function(b, rng)
	b:box(V(24, 0.4, 24), CF(0, 0.2, 0), rgb(90, 160, 70), { role = "fixed", material = Enum.Material.Grass })
	for k = 0, 15 do
		local x = (k % 4 - 1.5) * 5
		local z = (k // 4 - 1.5) * 5
		local col = rng:pick({ rgb(255, 80, 120), rgb(255, 220, 60), rgb(160, 90, 255), rgb(255, 140, 40) })
		b:cylY(1.6, 0.2, CF(x, 1, z), rgb(70, 150, 50), { role = "fixed" })
		b:ball(1.1, CF(x, 2, z), col, { role = "primary" })
	end
	b:cylY(1, 4, CF(0, 0.5, 0), rgb(200, 200, 205), { role = "fixed", material = Enum.Material.Marble })
	b:cylY(4, 0.8, CF(0, 2.5, 0), rgb(200, 200, 205), { role = "fixed", material = Enum.Material.Marble })
	return 4, 12
end

Props.Objects = OBJ
Props.Foods = FOOD
Props.Nature = NAT

function Props.build(origin: CFrame, params: { [string]: any }, model: string, variant: string): PropResult
	local p = table.clone(params)
	if p.physics then
		p.anchored = false
	end
	local b = Kit.new(variant, origin, p)
	local rng = params.rng
	local table_ = if model == "food" then FOOD elseif model == "nature" then NAT else OBJ
	local f = table_[variant] or OBJ.crate
	if variant == "forest" then
		f = NAT.tree
	end
	local h, r = f(b, rng)
	local m = b:finish()
	if p.physics then
		local main = m.PrimaryPart :: BasePart
		for _, part in b.parts do
			if part ~= main then
				part.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = main
				w.Part1 = part
				w.Parent = part
			end
			part.CanCollide = true
		end
	end
	return { model = m, height = h * b.s, radius = r * b.s, main = m.PrimaryPart :: BasePart }
end

return Props
