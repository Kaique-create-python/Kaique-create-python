--!strict
-- Animais e bestas procedurais. Cada família tem um construtor parametrizado
-- por espécie (proporções, cores e detalhes), o que dá variedade sem repetir
-- código e mantém cada criatura reconhecível.

local Rig = require(script.Parent.Rig)
local Kit = require(script.Parent.Kit)

local Beasts = {}

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

-- QUADRÚPEDES ------------------------------------------------------------------
type Quad = {
	body: Vector3,
	legH: number,
	legW: number,
	neck: number,
	head: Vector3,
	snout: Vector3?,
	ears: string?,
	tail: string?,
	color: Color3,
	color2: Color3?,
	mat: Enum.Material?,
	extras: { string }?,
	low: boolean?,
}

local QUAD: { [string]: Quad } = {
	dog = { body = V(1.7, 1.5, 3.0), legH = 1.5, legW = 0.55, neck = 0.7, head = V(1.2, 1.1, 1.2), snout = V(0.7, 0.55, 0.8), ears = "flop", tail = "up", color = rgb(205, 150, 85), color2 = rgb(245, 230, 210), extras = { "collar" } },
	cat = { body = V(1.3, 1.2, 2.6), legH = 1.3, legW = 0.4, neck = 0.5, head = V(1.1, 1.0, 1.0), snout = V(0.5, 0.35, 0.3), ears = "point", tail = "thin_up", color = rgb(240, 150, 60), color2 = rgb(250, 240, 230), extras = { "whiskers", "stripes_thin" } },
	wolf = { body = V(1.7, 1.6, 3.4), legH = 1.8, legW = 0.55, neck = 0.8, head = V(1.2, 1.1, 1.2), snout = V(0.6, 0.55, 1.0), ears = "point", tail = "bushy", color = rgb(120, 120, 130), color2 = rgb(210, 210, 215) },
	lion = { body = V(2.0, 1.9, 3.8), legH = 2.0, legW = 0.7, neck = 0.6, head = V(1.5, 1.4, 1.4), snout = V(0.8, 0.6, 0.7), ears = "round", tail = "tuft", color = rgb(220, 170, 90), color2 = rgb(240, 210, 150), extras = { "mane" } },
	tiger = { body = V(2.0, 1.8, 3.9), legH = 1.9, legW = 0.7, neck = 0.6, head = V(1.4, 1.3, 1.3), snout = V(0.8, 0.55, 0.6), ears = "round", tail = "thin", color = rgb(240, 130, 40), color2 = rgb(250, 245, 235), extras = { "stripes" } },
	jaguar = { body = V(1.8, 1.6, 3.6), legH = 1.7, legW = 0.6, neck = 0.5, head = V(1.3, 1.2, 1.2), snout = V(0.7, 0.5, 0.5), ears = "round", tail = "thin", color = rgb(235, 185, 80), color2 = rgb(250, 240, 220), extras = { "spots" } },
	bear = { body = V(2.6, 2.4, 3.6), legH = 1.6, legW = 0.95, neck = 0.4, head = V(1.6, 1.5, 1.5), snout = V(0.8, 0.6, 0.6), ears = "round", tail = "stub", color = rgb(110, 70, 40), color2 = rgb(150, 110, 70), mat = Enum.Material.Fabric },
	panda = { body = V(2.4, 2.3, 3.2), legH = 1.4, legW = 0.95, neck = 0.3, head = V(1.6, 1.5, 1.4), snout = V(0.6, 0.45, 0.4), ears = "round_black", tail = "stub", color = rgb(245, 245, 245), color2 = rgb(25, 25, 28), mat = Enum.Material.Fabric, extras = { "panda" } },
	cow = { body = V(2.4, 2.2, 4.0), legH = 2.0, legW = 0.7, neck = 0.6, head = V(1.3, 1.3, 1.5), snout = V(1.1, 0.7, 0.5), ears = "side", tail = "tuft", color = rgb(245, 245, 245), color2 = rgb(30, 30, 30), extras = { "cow_spots", "horns_small", "udder" } },
	pig = { body = V(2.0, 1.7, 3.0), legH = 1.0, legW = 0.6, neck = 0.2, head = V(1.3, 1.2, 1.1), snout = V(0.7, 0.6, 0.35), ears = "point", tail = "curl", color = rgb(250, 170, 180), color2 = rgb(240, 140, 155) },
	sheep = { body = V(2.0, 1.8, 2.8), legH = 1.3, legW = 0.45, neck = 0.4, head = V(0.9, 1.1, 1.2), snout = V(0.6, 0.6, 0.4), ears = "side", tail = "stub", color = rgb(245, 245, 240), color2 = rgb(40, 40, 45), extras = { "wool" } },
	horse = { body = V(1.9, 2.0, 4.0), legH = 2.8, legW = 0.6, neck = 1.6, head = V(0.9, 1.0, 2.0), snout = V(0.8, 0.8, 0.6), ears = "point", tail = "long", color = rgb(140, 90, 55), color2 = rgb(50, 35, 25), extras = { "mane_strip" } },
	unicorn = { body = V(1.9, 2.0, 4.0), legH = 2.8, legW = 0.6, neck = 1.6, head = V(0.9, 1.0, 2.0), snout = V(0.8, 0.8, 0.6), ears = "point", tail = "rainbow", color = rgb(250, 248, 255), color2 = rgb(255, 160, 220), extras = { "mane_rainbow", "horn_unicorn" } },
	headless_mule = { body = V(1.8, 1.9, 3.8), legH = 2.6, legW = 0.6, neck = 1.2, head = V(0, 0, 0), ears = nil, tail = "long", color = rgb(70, 50, 40), color2 = rgb(30, 25, 20), extras = { "headless_fire" } },
	elephant = { body = V(3.4, 3.2, 4.6), legH = 2.6, legW = 1.2, neck = 0.3, head = V(2.2, 2.2, 1.8), snout = nil, ears = "elephant", tail = "thin", color = rgb(140, 140, 150), color2 = rgb(120, 120, 130), extras = { "trunk", "tusks" } },
	giraffe = { body = V(1.9, 2.0, 3.4), legH = 4.0, legW = 0.5, neck = 5.0, head = V(0.8, 0.9, 1.6), snout = V(0.6, 0.6, 0.5), ears = "point", tail = "tuft", color = rgb(240, 200, 100), color2 = rgb(150, 90, 40), extras = { "giraffe_spots", "ossicones" } },
	rhino = { body = V(2.8, 2.5, 4.4), legH = 1.7, legW = 1.0, neck = 0.3, head = V(1.5, 1.5, 2.0), snout = V(1.2, 1.0, 0.6), ears = "point", tail = "thin", color = rgb(130, 130, 135), color2 = rgb(110, 110, 115), extras = { "rhino_horn", "armor_plates" } },
	deer = { body = V(1.5, 1.6, 3.0), legH = 2.3, legW = 0.4, neck = 1.2, head = V(0.8, 0.9, 1.3), snout = V(0.5, 0.5, 0.4), ears = "side", tail = "stub", color = rgb(170, 110, 60), color2 = rgb(240, 230, 210), extras = { "antlers", "fawn_spots" } },
	fox = { body = V(1.3, 1.2, 2.6), legH = 1.2, legW = 0.4, neck = 0.5, head = V(1.0, 0.9, 1.0), snout = V(0.45, 0.4, 0.8), ears = "point_big", tail = "fox", color = rgb(235, 110, 40), color2 = rgb(250, 245, 240) },
	rabbit = { body = V(1.2, 1.2, 1.7), legH = 0.6, legW = 0.4, neck = 0.2, head = V(1.0, 1.0, 1.0), snout = V(0.4, 0.3, 0.2), ears = "bunny", tail = "cotton", color = rgb(230, 225, 220), color2 = rgb(255, 255, 255) },
	mouse = { body = V(1.0, 0.9, 1.6), legH = 0.4, legW = 0.25, neck = 0.1, head = V(0.8, 0.7, 0.9), snout = V(0.3, 0.3, 0.4), ears = "mouse", tail = "thin_long", color = rgb(160, 160, 165), color2 = rgb(255, 190, 200) },
	zebra = { body = V(1.8, 1.9, 3.8), legH = 2.6, legW = 0.55, neck = 1.4, head = V(0.85, 0.95, 1.9), snout = V(0.75, 0.75, 0.5), ears = "point", tail = "tuft", color = rgb(248, 248, 248), color2 = rgb(25, 25, 28), extras = { "stripes", "mane_strip" } },
	hippo = { body = V(3.0, 2.4, 4.4), legH = 1.2, legW = 1.0, neck = 0.2, head = V(1.9, 1.5, 2.2), snout = V(1.8, 1.2, 0.8), ears = "tiny", tail = "stub", color = rgb(150, 120, 135), color2 = rgb(230, 170, 170) },
	koala = { body = V(1.6, 1.7, 1.8), legH = 0.9, legW = 0.5, neck = 0.2, head = V(1.5, 1.3, 1.2), snout = V(0.5, 0.6, 0.3), ears = "round", tail = "none", color = rgb(150, 150, 160), color2 = rgb(235, 235, 240), mat = Enum.Material.Fabric },
	camel = { body = V(2.0, 2.2, 4.0), legH = 3.0, legW = 0.55, neck = 2.0, head = V(0.9, 0.9, 1.9), snout = V(0.8, 0.7, 0.6), ears = "tiny", tail = "tuft", color = rgb(210, 170, 110), color2 = rgb(190, 150, 95), extras = { "back_ridges" } },
	llama = { body = V(1.6, 1.8, 3.0), legH = 2.4, legW = 0.45, neck = 2.4, head = V(0.8, 0.9, 1.3), snout = V(0.6, 0.6, 0.5), ears = "point_big", tail = "stub", color = rgb(245, 240, 225), color2 = rgb(180, 140, 100), mat = Enum.Material.Fabric, extras = { "wool" } },
	hyena = { body = V(1.7, 1.7, 3.2), legH = 1.8, legW = 0.55, neck = 0.6, head = V(1.2, 1.1, 1.2), snout = V(0.7, 0.6, 0.8), ears = "round", tail = "bushy", color = rgb(190, 160, 110), color2 = rgb(90, 70, 50), extras = { "spots" } },
	cheetah = { body = V(1.5, 1.4, 3.6), legH = 2.0, legW = 0.45, neck = 0.5, head = V(1.1, 1.0, 1.0), snout = V(0.6, 0.45, 0.4), ears = "round", tail = "thin", color = rgb(240, 200, 110), color2 = rgb(250, 245, 230), extras = { "spots" } },
	anteater = { body = V(1.7, 1.7, 3.4), legH = 1.3, legW = 0.55, neck = 0.5, head = V(0.7, 0.7, 1.0), snout = V(0.35, 0.35, 2.2), ears = "tiny", tail = "bushy", color = rgb(110, 90, 70), color2 = rgb(230, 225, 215) },
	armadillo = { body = V(1.6, 1.0, 2.4), legH = 0.5, legW = 0.4, neck = 0.3, head = V(0.6, 0.6, 0.9), snout = V(0.35, 0.3, 0.6), ears = "point", tail = "thin", color = rgb(160, 130, 100), color2 = rgb(120, 95, 70), low = true, extras = { "shell", "armor_plates" } },
	capybara = { body = V(2.0, 1.8, 3.0), legH = 0.9, legW = 0.6, neck = 0.3, head = V(1.3, 1.3, 1.7), snout = V(1.1, 0.9, 0.5), ears = "tiny", tail = "none", color = rgb(150, 105, 65), color2 = rgb(120, 85, 50), mat = Enum.Material.Fabric },
	sloth = { body = V(1.6, 1.8, 2.2), legH = 1.4, legW = 0.4, neck = 0.3, head = V(1.1, 1.0, 1.0), snout = V(0.5, 0.4, 0.3), ears = "none", tail = "stub", color = rgb(150, 125, 95), color2 = rgb(220, 200, 170), mat = Enum.Material.Fabric, extras = { "sloth_mask", "claws_long" } },
	crocodile = { body = V(1.9, 1.0, 4.2), legH = 0.7, legW = 0.5, neck = 0.1, head = V(1.2, 0.8, 1.2), snout = V(0.9, 0.5, 2.0), ears = "none", tail = "croc", color = rgb(70, 110, 60), color2 = rgb(170, 180, 120), low = true, extras = { "croc_teeth", "back_ridges" } },
	lizard = { body = V(1.0, 0.6, 2.0), legH = 0.4, legW = 0.25, neck = 0.1, head = V(0.7, 0.5, 0.8), snout = V(0.5, 0.35, 0.4), ears = "none", tail = "croc", color = rgb(90, 200, 90), color2 = rgb(220, 230, 120), low = true },
	turtle = { body = V(2.0, 1.0, 2.4), legH = 0.6, legW = 0.5, neck = 0.6, head = V(0.7, 0.6, 0.8), snout = nil, ears = "none", tail = "stub", color = rgb(120, 160, 90), color2 = rgb(110, 80, 50), low = true, extras = { "shell" } },
	frog = { body = V(1.4, 0.9, 1.4), legH = 0.4, legW = 0.4, neck = 0, head = V(1.3, 0.7, 0.9), snout = nil, ears = "none", tail = "none", color = rgb(90, 190, 70), color2 = rgb(230, 240, 150), extras = { "frog_eyes" } },
	monkey = { body = V(1.4, 1.7, 1.8), legH = 1.4, legW = 0.4, neck = 0.3, head = V(1.1, 1.1, 1.0), snout = V(0.8, 0.6, 0.4), ears = "monkey", tail = "curl_long", color = rgb(120, 80, 50), color2 = rgb(230, 200, 160), mat = Enum.Material.Fabric },
	triceratops = { body = V(3.0, 2.8, 5.0), legH = 2.0, legW = 1.1, neck = 0.3, head = V(1.8, 1.6, 2.2), snout = V(1.0, 0.9, 0.8), ears = "none", tail = "dino", color = rgb(110, 140, 90), color2 = rgb(200, 180, 120), extras = { "frill", "tri_horns" } },
	stegosaurus = { body = V(2.8, 2.6, 5.4), legH = 2.0, legW = 1.0, neck = 0.6, head = V(0.9, 0.8, 1.4), snout = nil, ears = "none", tail = "spiked", color = rgb(120, 140, 110), color2 = rgb(200, 120, 70), extras = { "back_plates" } },
	brachiosaurus = { body = V(3.6, 3.4, 6.0), legH = 4.2, legW = 1.3, neck = 9.0, head = V(1.1, 1.0, 1.8), snout = nil, ears = "none", tail = "dino", color = rgb(120, 150, 160), color2 = rgb(190, 200, 190) },
}

local function quadruped(origin: CFrame, params: { [string]: any }, variant: string): Rig.RigResult
	local q = QUAD[variant] or QUAD.dog
	local ex = {}
	for _, e in q.extras or {} do
		ex[e] = true
	end
	local R = Rig.new(variant, origin, params)
	local b = R.b
	local mat = q.mat or Enum.Material.SmoothPlastic
	local c1, c2 = q.color, q.color2 or Kit.lighter(q.color, 0.4)
	local body = q.body
	local legH = q.legH
	local bodyY = legH + body.Y / 2 - (if q.low then 0.2 else 0)
	local root = R:makeRoot(V(body.X, body.Y, body.Z), bodyY)

	local torso = b:blob(body, CF(0, bodyY, 0), c1, { role = "primary", material = mat, name = "Corpo" })
	R:weld(R:since(0), root)
	if ex.cow_spots or ex.giraffe_spots or ex.spots or ex.fawn_spots then
		local col = c2
		for k = 1, 7 do
			local ang = k * 2.39
			local p = V(math.cos(ang) * body.X * 0.48, bodyY + math.sin(k * 1.3) * body.Y * 0.25, (k / 7 - 0.5) * body.Z * 0.8)
			local d = if ex.cow_spots then 0.9 else 0.45
			local spot = b:ball(d, CF(p), col, { role = "secondary" })
			R:join(spot, torso)
		end
	end
	if ex.stripes or ex.stripes_thin then
		local stripeCol = if ex.stripes then rgb(25, 20, 20) else Kit.darker(c1, 0.35)
		for k = -3, 3 do
			local s = b:box(V(body.X * 1.03, body.Y * 0.45, if ex.stripes then 0.2 else 0.12), CF(0, bodyY + body.Y * 0.28, k * body.Z * 0.12), stripeCol, { role = "secondary" })
			R:join(s, torso)
		end
	end
	if ex.wool then
		for k = 0, 9 do
			local ang = k * 2.4
			local w = b:ball(1.1, CF(math.cos(ang) * body.X * 0.4, bodyY + 0.3 + math.sin(k) * 0.3, (k / 9 - 0.5) * body.Z * 0.8), c1, { role = "primary", material = Enum.Material.Fabric })
			R:join(w, torso)
		end
	end
	if ex.shell then
		local s = b:part("ball", V(body.X * 1.25, body.Y * 1.5, body.Z * 1.15), CF(0, bodyY + body.Y * 0.35, 0), c2, { role = "secondary", material = Enum.Material.Slate })
		R:join(s, torso)
	end
	if ex.back_plates or ex.back_ridges then
		local n = if ex.back_plates then 7 else 6
		for k = 1, n do
			local z = (k / (n + 1) - 0.5) * body.Z
			local h = if ex.back_plates then 1.2 + math.sin(k / n * math.pi) * 0.8 else 0.4
			local plate = b:part("wedge", V(0.25, h, h), CF(0, bodyY + body.Y / 2 + h / 2 - 0.1, z), c2, { role = "accent" })
			R:join(plate, torso)
		end
	end
	if ex.udder then
		local u = b:ball(0.7, CF(0, legH + 0.1, body.Z * 0.25), rgb(255, 170, 180), { role = "fixed" })
		R:join(u, torso)
	end
	if ex.armor_plates then
		for _, z in { -0.8, 0.8 } do
			local a = b:box(V(body.X * 1.03, 0.15, 0.6), CF(0, bodyY + 0.2, z), Kit.darker(c1, 0.15), { role = "secondary" })
			R:join(a, torso)
		end
	end
	if ex.collar then
		local col = b:part("cyl", V(0.3, 1.3, 1.3), CF(0, bodyY + body.Y * 0.3, -body.Z / 2 + 0.1) * ANG(0, rad(90), 0), rgb(220, 40, 50), { role = "accent" })
		R:join(col, torso)
	end

	-- pernas
	local lx = body.X / 2 - q.legW / 2
	local lz = body.Z / 2 - q.legW * 0.8
	local legs = { { -lx, -lz, 0 }, { lx, -lz, math.pi }, { -lx, lz, math.pi }, { lx, lz, 0 } }
	for _, l in legs do
		local m = R:mark()
		local x, z, ph = l[1], l[2], l[3]
		local legCol = if variant == "panda" or variant == "sheep" then c2 else c1
		b:box(V(q.legW, legH, q.legW), CF(x, legH / 2, z), legCol, { role = "primary", material = mat })
		b:box(V(q.legW * 1.1, 0.25, q.legW * 1.2), CF(x, 0.12, z - 0.05), Kit.darker(legCol, 0.35), { role = "secondary" })
		if ex.claws_long then
			b:part("wedge", V(0.2, 0.4, 0.5), CF(x, 0.3, z - 0.45), rgb(240, 235, 220), { role = "fixed" })
		end
		R:group(m, torso, V(x, legH, z), { kind = "leg", axis = "X", amp = if q.low then 0.4 else 0.6, phase = ph })
	end

	-- pescoço + cabeça
	local neckBase = V(0, bodyY + body.Y * 0.25, -body.Z / 2 + 0.3)
	local tall = variant == "giraffe" or variant == "brachiosaurus" or variant == "horse" or variant == "unicorn" or variant == "deer" or variant == "headless_mule"
	local neckDir = if tall then V(0, 0.85, -0.5).Unit else V(0, 0.35, -1).Unit
	local headPos = neckBase + neckDir * (q.neck + q.head.Z * 0.3)
	if q.low then
		headPos = V(0, bodyY, -body.Z / 2 - q.head.Z / 2 + 0.2)
	end
	local hm = R:mark()
	local headPart: BasePart
	if variant == "headless_mule" then
		headPart = b:part("cyl", V(q.neck, 0.9, 0.9), CF((neckBase + headPos) / 2) * CFrame.lookAt(V(), neckDir).Rotation * ANG(0, rad(90), 0), c1, { role = "primary" })
		local fire = Instance.new("Fire")
		fire.Size = 6
		fire.Heat = 12
		fire.Color = rgb(255, 120, 30)
		fire.SecondaryColor = rgb(255, 220, 80)
		fire.Parent = headPart
	else
		if q.neck > 0.3 then
			b:beam(neckBase, headPos, math.min(q.head.X, 1.1) * 0.75, c1, { role = "primary", material = mat })
			if variant == "giraffe" then
				for k = 1, 4 do
					b:ball(0.4, CF(neckBase:Lerp(headPos, k / 5) + V(0.3, 0, 0)), c2, { role = "secondary" })
				end
			end
		end
		headPart = b:box(q.head, CF(headPos), if variant == "panda" then c1 else c1, { role = "primary", material = mat, name = "Cabeca" })
		local front = headPos.Z - q.head.Z / 2
		local snoutPos = V(0, headPos.Y - q.head.Y * 0.15, front)
		if q.snout then
			local sn = q.snout
			snoutPos = V(0, headPos.Y - q.head.Y * 0.2, front - sn.Z / 2 + 0.05)
			b:box(sn, CF(snoutPos), if variant == "pig" or variant == "cow" then c2 else Kit.lighter(c1, 0.15), { role = "secondary", material = mat })
			b:box(V(sn.X * 0.5, sn.Y * 0.35, 0.1), CF(0, snoutPos.Y + sn.Y * 0.2, snoutPos.Z - sn.Z / 2), rgb(30, 25, 25), { role = "fixed", name = "Nariz" })
		end
		-- olhos
		for _, side in { -1, 1 } do
			local eyeX = side * q.head.X * 0.32
			if ex.frog_eyes then
				b:ball(0.55, CF(side * 0.45, headPos.Y + 0.4, front + 0.2), rgb(240, 240, 220), { role = "fixed" })
				b:ball(0.28, CF(side * 0.45, headPos.Y + 0.45, front - 0.02), rgb(15, 15, 15), { role = "eye" })
			else
				if variant == "panda" then
					b:part("ball", V(0.45, 0.5, 0.2), CF(eyeX, headPos.Y + 0.1, front + 0.02), c2, { role = "fixed" })
				end
				b:box(V(0.18, 0.2, 0.08), CF(eyeX, headPos.Y + q.head.Y * 0.15, front - 0.03), if variant == "panda" then rgb(240, 240, 240) else rgb(20, 20, 25), { role = "eye" })
			end
		end
		-- orelhas
		local ears = q.ears
		local earY = headPos.Y + q.head.Y / 2
		for _, side in { -1, 1 } do
			local ex2 = side * q.head.X * 0.32
			local earCol = if ears == "round_black" then c2 else c1
			if ears == "point" or ears == "point_big" then
				local s = if ears == "point_big" then 1.4 else 1
				b:part("wedge", V(0.2, 0.55 * s, 0.4 * s), CF(ex2, earY + 0.25 * s, headPos.Z + 0.1), earCol, { role = "primary" })
			elseif ears == "round" or ears == "round_black" or ears == "mouse" or ears == "monkey" then
				local d = if ears == "mouse" then 0.6 else 0.45
				b:part("cyl", V(0.15, d, d), CF(ex2 * (if ears == "monkey" then 1.5 else 1), if ears == "monkey" then headPos.Y else earY + 0.1, headPos.Z) * ANG(0, rad(90), 0), earCol, { role = "secondary" })
			elseif ears == "flop" or ears == "side" then
				b:box(V(0.2, 0.7, 0.45), CF(side * (q.head.X / 2 + 0.1), headPos.Y + 0.05, headPos.Z) * ANG(0, 0, side * rad(25)), Kit.darker(c1, 0.25), { role = "secondary" })
			elseif ears == "bunny" then
				b:box(V(0.22, 1.4, 0.35), CF(side * 0.22, earY + 0.65, headPos.Z + 0.1) * ANG(rad(-10), 0, side * rad(8)), c1, { role = "primary" })
			elseif ears == "elephant" then
				b:box(V(0.15, 2.0, 1.8), CF(side * (q.head.X / 2 + 0.3), headPos.Y, headPos.Z + 0.4) * ANG(0, side * rad(25), 0), c2, { role = "secondary" })
			elseif ears == "tiny" then
				b:ball(0.3, CF(ex2, earY + 0.05, headPos.Z + 0.3), Kit.darker(c1, 0.2), { role = "secondary" })
			end
		end
		if ex.mane then
			b:ball(q.head.X * 1.7, CF(headPos + V(0, 0.1, 0.35)), rgb(140, 80, 30), { role = "secondary", material = Enum.Material.Fabric })
		end
		if ex.horns_small then
			for _, side in { -1, 1 } do
				b:part("wedge", V(0.15, 0.45, 0.25), CF(side * q.head.X * 0.45, earY + 0.15, headPos.Z + 0.1), rgb(240, 230, 210), { role = "fixed" })
			end
		end
		if ex.horn_unicorn then
			b:cone(1.4, 0.35, CF(0, earY - 0.05, front + 0.3) * ANG(rad(-35), 0, 0), rgb(255, 215, 80), 3, { role = "fixed", material = Enum.Material.Neon })
		end
		if ex.antlers then
			for _, side in { -1, 1 } do
				local base = V(side * 0.3, earY, headPos.Z + 0.2)
				local tip = base + V(side * 0.8, 1.4, 0.3)
				b:beam(base, tip, 0.15, rgb(200, 180, 140), { role = "fixed" })
				b:beam(base:Lerp(tip, 0.5), base:Lerp(tip, 0.5) + V(side * 0.1, 0.6, -0.4), 0.12, rgb(200, 180, 140), { role = "fixed" })
			end
		end
		if ex.ossicones then
			for _, side in { -1, 1 } do
				b:beam(V(side * 0.2, earY, headPos.Z + 0.3), V(side * 0.25, earY + 0.6, headPos.Z + 0.35), 0.15, c2, { role = "fixed" })
			end
		end
		if ex.trunk then
			local base = V(0, headPos.Y - 0.3, front)
			for k = 1, 4 do
				local seg = base + V(0, -k * 0.55, -0.15 * k)
				b:ball(0.75 - k * 0.08, CF(seg), c1, { role = "primary" })
			end
		end
		if ex.tusks then
			for _, side in { -1, 1 } do
				b:beam(V(side * 0.5, headPos.Y - 0.6, front), V(side * 0.6, headPos.Y - 0.9, front - 1.2), 0.22, rgb(250, 245, 230), { role = "fixed" }, true)
			end
		end
		if ex.rhino_horn and q.snout then
			b:cone(1.2, 0.6, CF(0, snoutPos.Y + q.snout.Y / 2, snoutPos.Z) * ANG(rad(-15), 0, 0), rgb(200, 195, 185), 3, { role = "fixed" })
		end
		if ex.frill then
			b:part("cyl", V(0.3, 3.0, 3.0), CF(0, headPos.Y + 0.5, headPos.Z + q.head.Z / 2) * ANG(rad(20), rad(90), 0), c2, { role = "secondary" })
		end
		if ex.tri_horns then
			for _, side in { -1, 1 } do
				b:cone(1.5, 0.35, CF(side * 0.45, headPos.Y + 0.5, front + 0.3) * ANG(rad(-60), 0, 0), rgb(240, 235, 220), 3, { role = "fixed" })
			end
			if q.snout then
				b:cone(0.7, 0.35, CF(0, snoutPos.Y + q.snout.Y / 2, snoutPos.Z) * ANG(rad(-30), 0, 0), rgb(240, 235, 220), 2, { role = "fixed" })
			end
		end
		if ex.croc_teeth and q.snout then
			for k = 0, 5 do
				for _, side in { -1, 1 } do
					b:part("wedge", V(0.08, 0.2, 0.12), CF(side * q.snout.X * 0.45, snoutPos.Y - q.snout.Y / 2 - 0.05, snoutPos.Z - q.snout.Z / 2 + 0.25 + k * 0.3) * ANG(rad(180), 0, 0), rgb(250, 250, 240), { role = "fixed" })
				end
			end
		end
		if ex.whiskers and q.snout then
			for _, side in { -1, 1 } do
				b:box(V(0.9, 0.04, 0.04), CF(side * 0.45, snoutPos.Y, snoutPos.Z), rgb(250, 250, 250), { role = "fixed" })
			end
		end
		if ex.sloth_mask then
			b:box(V(q.head.X * 0.8, q.head.Y * 0.5, 0.06), CF(0, headPos.Y + 0.05, front - 0.01), c2, { role = "fixed" })
		end
		if ex.mane_strip or ex.mane_rainbow then
			for k = 0, 5 do
				local p = neckBase:Lerp(headPos, k / 6) + V(0, 0.45, 0.2)
				local col = if ex.mane_rainbow then Kit.RainbowColors[(k % #Kit.RainbowColors) + 1] else c2
				b:box(V(0.25, 0.6, 0.45), CF(p), col, { role = if ex.mane_rainbow then "fixed" else "secondary", material = if ex.mane_rainbow then Enum.Material.Neon else mat })
			end
		end
		R.head = headPart
	end
	R:group(hm, torso, neckBase, { kind = "head", axis = "X", amp = 0.12, speed = 0.6 })
	if R.head then
		R:setMouth(R.head, V(0, -0.2, -(q.head.Z / 2 + (q.snout and q.snout.Z or 0))))
	end

	-- cauda
	local tailBase = V(0, bodyY + body.Y * 0.2, body.Z / 2)
	local tail = q.tail
	if tail and tail ~= "none" then
		local tm = R:mark()
		local tcol = if tail == "fox" then c1 else c1
		if tail == "up" or tail == "thin_up" then
			b:beam(tailBase, tailBase + V(0, 1.2, 0.8), if tail == "up" then 0.35 else 0.2, tcol, { role = "primary" })
		elseif tail == "thin" or tail == "tuft" or tail == "thin_long" then
			local len = if tail == "thin_long" then 2.2 else 1.6
			b:beam(tailBase, tailBase + V(0, -0.6, len), 0.2, tcol, { role = "primary" })
			if tail == "tuft" then
				b:ball(0.5, CF(tailBase + V(0, -0.65, len)), rgb(60, 40, 25), { role = "secondary" })
			end
		elseif tail == "bushy" or tail == "fox" then
			b:part("ball", V(0.8, 0.8, 2.0), CF(tailBase + V(0, -0.2, 1.0)) * ANG(rad(-20), 0, 0), tcol, { role = "primary", material = Enum.Material.Fabric })
			if tail == "fox" then
				b:ball(0.6, CF(tailBase + V(0, -0.45, 1.9)), rgb(250, 250, 250), { role = "fixed" })
			end
		elseif tail == "curl" then
			b:part("cyl", V(0.15, 0.5, 0.5), CF(tailBase + V(0, 0.2, 0.25)) * ANG(0, 0, 0), tcol, { role = "primary" })
		elseif tail == "curl_long" then
			b:beam(tailBase, tailBase + V(0, 1.6, 1.0), 0.18, tcol, { role = "primary" })
			b:beam(tailBase + V(0, 1.6, 1.0), tailBase + V(0, 2.0, 0.6), 0.18, tcol, { role = "primary" })
		elseif tail == "stub" then
			b:ball(0.5, CF(tailBase), tcol, { role = "primary" })
		elseif tail == "cotton" then
			b:ball(0.55, CF(tailBase), rgb(255, 255, 255), { role = "fixed" })
		elseif tail == "long" or tail == "rainbow" then
			for k = 0, 3 do
				local col = if tail == "rainbow" then Kit.RainbowColors[k + 1] else q.color2 or c1
				b:box(V(0.35, 2.4, 0.3), CF(tailBase + V((k - 1.5) * 0.12, -1.1, 0.4)) * ANG(rad(15), 0, 0), col, { role = "fixed", material = if tail == "rainbow" then Enum.Material.Neon else mat })
			end
		elseif tail == "croc" or tail == "dino" or tail == "spiked" then
			local len = if tail == "croc" then body.Z * 0.9 else body.Z * 0.8
			local th = if tail == "croc" then body.Y * 0.6 else body.Y * 0.55
			b:part("wedge", V(th, th, len), CF(tailBase + V(0, -th * 0.3, len / 2)) * ANG(0, rad(180), 0), c1, { role = "primary" })
			if tail == "spiked" then
				for _, side in { -1, 1 } do
					b:cone(1.0, 0.3, CF(tailBase + V(side * 0.3, 0, len * 0.85)) * ANG(0, 0, side * rad(-70)), rgb(230, 220, 200), 2, { role = "fixed" })
				end
			end
		end
		R:group(tm, torso, tailBase, { kind = "tail", axis = "Y", amp = if tail == "croc" or tail == "dino" then 0.25 else 0.45, speed = 1.2 })
	end

	local height = math.max(bodyY + body.Y / 2, headPos.Y + q.head.Y / 2)
	return R:finish({ hp = params.hp or 100, speed = params.speed or 16, hipHeight = legH - body.Y * 0 , height = height, radius = math.max(body.X, body.Z) / 2 })
end

-- DINOSSAUROS BÍPEDES -------------------------------------------------------------
local THERO = {
	trex = { s = 1.6, color = rgb(90, 120, 70), color2 = rgb(190, 170, 110), arms = 0.5, spikes = false },
	raptor = { s = 0.75, color = rgb(160, 120, 70), color2 = rgb(230, 200, 150), arms = 0.9, spikes = false, stripe = rgb(120, 60, 40) },
	kaiju = { s = 2.0, color = rgb(60, 70, 75), color2 = rgb(90, 100, 105), arms = 1.0, spikes = true },
}

local function theropod(origin: CFrame, params: { [string]: any }, variant: string): Rig.RigResult
	local t = THERO[variant] or THERO.trex
	local p2 = table.clone(params)
	p2.size = (params.size or 1) * t.s
	local R = Rig.new(variant, origin, p2)
	local b = R.b
	local c1, c2 = t.color, t.color2
	local legH = 3.2
	local bodyY = legH + 1.2
	local root = R:makeRoot(V(2.4, 2.4, 3.6), bodyY)
	local torso = b:part("ball", V(2.6, 2.6, 4.2), CF(0, bodyY, 0) * ANG(rad(-12), 0, 0), c1, { role = "primary", name = "Corpo" })
	R:join(torso, root)
	local belly = b:part("ball", V(2.0, 1.8, 3.4), CF(0, bodyY - 0.5, -0.3), c2, { role = "secondary" })
	R:join(belly, torso)
	if t.stripe then
		for k = -1, 1 do
			local s = b:box(V(2.65, 0.5, 0.3), CF(0, bodyY + 0.6, k * 0.9), t.stripe, { role = "fixed" })
			R:join(s, torso)
		end
	end
	-- pernas fortes
	for _, side in { -1, 1 } do
		local m = R:mark()
		b:part("ball", V(1.3, 2.2, 1.6), CF(side * 1.1, legH + 0.2, 0.4), c1, { role = "primary" })
		b:box(V(0.7, legH - 0.6, 0.7), CF(side * 1.15, legH / 2 - 0.2, 0.7) * ANG(rad(-10), 0, 0), c1, { role = "primary" })
		b:box(V(1.0, 0.4, 1.8), CF(side * 1.15, 0.2, 0.3), Kit.darker(c1, 0.3), { role = "secondary" })
		for k = -1, 1 do
			b:part("wedge", V(0.2, 0.3, 0.4), CF(side * 1.15 + k * 0.3, 0.2, -0.8), rgb(240, 235, 220), { role = "fixed" })
		end
		R:group(m, torso, V(side * 1.1, legH + 0.6, 0.4), { kind = "leg", axis = "X", amp = 0.55, phase = if side < 0 then 0 else math.pi })
	end
	-- bracinhos
	for _, side in { -1, 1 } do
		local m = R:mark()
		b:beam(V(side * 0.9, bodyY - 0.2, -1.6), V(side * 1.0, bodyY - 1.0 * t.arms, -2.2), 0.35, c1, { role = "primary" })
		R:group(m, torso, V(side * 0.9, bodyY - 0.2, -1.6), { kind = "arm", axis = "X", amp = 0.3 })
	end
	-- cabeça com mandíbula
	local headPos = V(0, bodyY + 1.6, -3.0)
	local hm = R:mark()
	local head = b:box(V(1.8, 1.1, 2.6), CF(headPos + V(0, -0.15, 0)), c1, { role = "primary", name = "Cabeca" })
	b:part("wedge", V(1.8, 0.7, 1.6), CF(headPos + V(0, 0.75, 0.5)), c1, { role = "primary" })
	b:box(V(1.4, 0.5, 1.0), CF(headPos + V(0, 0.55, -0.8)), c1, { role = "primary" })
	b:box(V(1.2, 1.0, 1.4), CF(headPos + V(0, -0.6, 0.6)), c1, { role = "primary" })
	for _, side in { -1, 1 } do
		b:box(V(0.25, 0.25, 0.1), CF(headPos + V(side * 0.7, 0.35, -0.6)), rgb(250, 200, 40), { role = "eye", material = Enum.Material.Neon })
		b:box(V(0.3, 0.15, 0.6), CF(headPos + V(side * 0.6, 0.55, -0.5)), Kit.darker(c1, 0.2), { role = "secondary" })
	end
	for k = 0, 4 do
		for _, side in { -1, 1 } do
			b:part("wedge", V(0.12, 0.3, 0.18), CF(headPos + V(side * 0.75, -0.8, -1.2 + k * 0.4)) * ANG(rad(180), 0, 0), rgb(250, 250, 240), { role = "fixed" })
		end
	end
	R.head = head
	local headBase = R:group(hm, torso, V(0, bodyY + 0.9, -1.8), { kind = "head", axis = "Y", amp = 0.2, speed = 0.5 })
	local jm = R:mark()
	b:box(V(1.6, 0.45, 2.2), CF(headPos + V(0, -0.95, -0.25)), c2, { role = "secondary", name = "Mandibula" })
	R:group(jm, headBase or torso, headPos + V(0, -0.8, 1.0), { kind = "jaw", axis = "X", amp = 0.35, speed = 0.5 })
	R:setMouth(head, V(0, -0.6, -1.6))
	if t.spikes then
		for k = 0, 6 do
			local sp = b:part("wedge", V(0.3, 1.2 - k * 0.1, 1.0), CF(0, bodyY + 1.4 - k * 0.15, -1.2 + k * 0.8), rgb(110, 200, 255), { role = "accent", material = Enum.Material.Neon })
			R:join(sp, torso)
		end
	end
	-- cauda em segmentos
	local prev = torso
	local base = V(0, bodyY + 0.2, 1.8)
	for k = 1, 4 do
		local m = R:mark()
		local th = 1.6 - k * 0.3
		local pos = base + V(0, -k * 0.15, k * 1.3)
		b:part("ball", V(th, th, 1.8), CF(pos), c1, { role = "primary" })
		prev = R:group(m, prev, pos - V(0, 0, 0.8), { kind = "tail", axis = "Y", amp = 0.18, phase = k * 0.6, speed = 0.8 }) or prev
	end
	return R:finish({ hp = params.hp or 600, speed = params.speed or 18, hipHeight = legH, height = headPos.Y + 0.8, radius = 2.2 })
end

-- AVES -------------------------------------------------------------------------
local BIRDS = {
	bird = { body = V(1.0, 1.0, 1.6), color = rgb(140, 100, 70), color2 = rgb(230, 200, 160), beak = rgb(240, 180, 50), wing = 2.4, legs = false },
	eagle = { body = V(1.4, 1.4, 2.4), color = rgb(100, 70, 40), color2 = rgb(250, 250, 250), beak = rgb(250, 200, 40), wing = 4.4, headColor = rgb(250, 250, 250) },
	parrot = { body = V(1.0, 1.2, 1.6), color = rgb(220, 40, 40), color2 = rgb(40, 120, 230), beak = rgb(240, 230, 210), wing = 2.6, wingColor = rgb(40, 120, 230), tailColor = rgb(250, 210, 40) },
	woodpecker = { body = V(1.0, 1.3, 1.6), color = rgb(40, 90, 200), color2 = rgb(250, 250, 245), beak = rgb(250, 200, 40), wing = 2.4, wingColor = rgb(40, 90, 200), tailColor = rgb(250, 60, 40) },
	toucan = { body = V(1.1, 1.3, 1.6), color = rgb(25, 25, 30), color2 = rgb(250, 250, 240), beak = rgb(255, 140, 20), wing = 2.4, bigBeak = true },
	owl = { body = V(1.4, 1.6, 1.4), color = rgb(150, 110, 70), color2 = rgb(230, 210, 170), beak = rgb(240, 200, 60), wing = 2.6, owl = true },
	chicken = { body = V(1.3, 1.3, 1.8), color = rgb(250, 250, 245), color2 = rgb(240, 240, 235), beak = rgb(250, 180, 40), wing = 1.2, legs = true, comb = true },
	duck = { body = V(1.3, 1.1, 2.0), color = rgb(250, 250, 250), color2 = rgb(240, 240, 240), beak = rgb(255, 150, 30), wing = 1.4, legs = true, flatBeak = true },
	penguin = { body = V(1.4, 2.2, 1.3), color = rgb(25, 25, 30), color2 = rgb(250, 250, 250), beak = rgb(255, 150, 30), wing = 1.0, legs = true, upright = true },
	flamingo = { body = V(1.1, 1.0, 1.8), color = rgb(255, 130, 170), color2 = rgb(255, 160, 190), beak = rgb(30, 30, 30), wing = 3.0, legs = true, longLegs = true },
	phoenix = { body = V(1.6, 1.6, 2.6), color = rgb(255, 110, 30), color2 = rgb(255, 210, 60), beak = rgb(255, 230, 120), wing = 3.6, glow = true },
	bat = { body = V(0.9, 0.9, 1.2), color = rgb(45, 35, 45), color2 = rgb(70, 50, 60), beak = rgb(45, 35, 45), wing = 2.8, bat = true },
	pterodactyl = { body = V(1.4, 1.2, 2.6), color = rgb(150, 110, 80), color2 = rgb(200, 170, 130), beak = rgb(200, 170, 120), wing = 6.0, ptero = true },
}

local function bird(origin: CFrame, params: { [string]: any }, variant: string): Rig.RigResult
	local d = BIRDS[variant] or BIRDS.bird
	local R = Rig.new(variant, origin, params)
	local b = R.b
	local body = d.body
	local legH = if d.longLegs then 3 elseif d.legs then 0.8 else 0.6
	local bodyY = legH + body.Y / 2
	local root = R:makeRoot(body, bodyY)
	local tilt = if d.upright then CFrame.identity else ANG(rad(-10), 0, 0)
	local torso = b:part("ball", body, CF(0, bodyY, 0) * tilt, d.color, { role = "primary", name = "Corpo" })
	R:join(torso, root)
	local belly = b:part("ball", body * V(0.8, 0.8, 0.8), CF(0, bodyY - body.Y * 0.12, -body.Z * 0.12), d.color2, { role = "secondary" })
	R:join(belly, torso)
	if d.glow then
		local fire = Instance.new("Fire")
		fire.Size = 5
		fire.Heat = 8
		fire.Parent = torso
	end
	-- cabeça
	local hm = R:mark()
	local hs = if d.owl then 1.2 else body.X * 0.8
	local headPos = if d.upright then V(0, bodyY + body.Y * 0.55, -0.1) else V(0, bodyY + body.Y * 0.45, -body.Z * 0.45)
	local head = b:ball(hs, CF(headPos), d.headColor or d.color, { role = "primary", name = "Cabeca" })
	R.head = head
	local front = headPos.Z - hs / 2
	if d.bigBeak then
		b:part("wedge", V(0.5, 0.7, 2.0), CF(0, headPos.Y, front - 0.9) * ANG(0, rad(180), 0), d.beak, { role = "fixed" })
	elseif d.flatBeak then
		b:box(V(0.6, 0.18, 0.7), CF(0, headPos.Y - 0.1, front - 0.3), d.beak, { role = "fixed" })
	elseif d.ptero then
		b:part("wedge", V(0.3, 0.4, 2.4), CF(0, headPos.Y, front - 1.1) * ANG(0, rad(180), 0), d.beak, { role = "fixed" })
		b:part("wedge", V(0.15, 0.9, 1.4), CF(0, headPos.Y + 0.4, headPos.Z + 0.7), d.color2, { role = "secondary" })
	else
		b:part("wedge", V(0.3, 0.3, 0.6), CF(0, headPos.Y - 0.05, front - 0.25) * ANG(0, rad(180), 0), d.beak, { role = "fixed" })
	end
	for _, side in { -1, 1 } do
		if d.owl then
			b:part("cyl", V(0.1, 0.55, 0.55), CF(side * 0.28, headPos.Y + 0.1, front + 0.05) * ANG(0, rad(90), 0), rgb(255, 220, 60), { role = "fixed" })
			b:part("cyl", V(0.12, 0.25, 0.25), CF(side * 0.28, headPos.Y + 0.1, front) * ANG(0, rad(90), 0), rgb(10, 10, 10), { role = "eye" })
		else
			b:box(V(0.15, 0.15, 0.08), CF(side * hs * 0.32, headPos.Y + 0.08, front + 0.12), rgb(15, 15, 15), { role = "eye" })
		end
	end
	if d.comb then
		b:part("wedge", V(0.15, 0.4, 0.5), CF(0, headPos.Y + hs * 0.55, headPos.Z), rgb(230, 40, 40), { role = "fixed" })
	end
	if d.bat then
		for _, side in { -1, 1 } do
			b:part("wedge", V(0.12, 0.6, 0.35), CF(side * 0.25, headPos.Y + 0.5, headPos.Z), d.color, { role = "primary" })
		end
	end
	local neck = if d.longLegs then V(0, bodyY + 1.4, -0.9) else headPos
	if d.longLegs then
		b:beam(V(0, bodyY + 0.3, -body.Z * 0.4), neck, 0.3, d.color, { role = "primary" })
	end
	R:group(hm, torso, V(0, bodyY + body.Y * 0.3, -body.Z * 0.3), { kind = "head", axis = "Y", amp = 0.25, speed = 0.8 })
	R:setMouth(head, V(0, 0, -hs / 2 - 0.3))
	-- asas
	for _, side in { -1, 1 } do
		local m = R:mark()
		local span = d.wing
		local wcol = d.wingColor or d.color
		local wmat = Enum.Material.SmoothPlastic
		if d.bat or d.ptero then
			b:part("wedge", V(0.1, body.Z * 0.9, span), CF(side * (body.X / 2 + span / 2), bodyY + 0.1, 0) * ANG(rad(90), side * rad(90), 0), wcol, { role = "primary", material = wmat })
		else
			b:box(V(span, 0.15, body.Z * 0.7), CF(side * (body.X / 2 + span / 2 - 0.1), bodyY + 0.15, 0.1), wcol, { role = "primary" })
			b:box(V(span * 0.5, 0.12, body.Z * 0.45), CF(side * (body.X / 2 + span * 0.85), bodyY + 0.15, 0.3), Kit.darker(wcol, 0.15), { role = "secondary" })
			if d.glow then
				b:box(V(span * 0.8, 0.1, 0.3), CF(side * (body.X / 2 + span / 2), bodyY + 0.2, body.Z * 0.35), d.color2, { role = "accent", material = Enum.Material.Neon })
			end
		end
		R:group(m, torso, V(side * body.X / 2, bodyY + 0.15, 0), { kind = "wing", axis = "Z", amp = if params.fly then 0.75 else 0.2, phase = if side < 0 then 0 else math.pi, speed = if d.bat then 2.4 else 1.4 })
	end
	-- cauda
	local tm = R:mark()
	local tailCol = d.tailColor or d.color
	if d.glow then
		for k = -1, 1 do
			b:box(V(0.3, 0.1, 3.0), CF(k * 0.35, bodyY - 0.1, body.Z / 2 + 1.4) * ANG(rad(-15), rad(k * 12), 0), rgb(255, 180, 40), { role = "accent", material = Enum.Material.Neon })
		end
	else
		b:part("wedge", V(body.X * 0.8, 0.15, 1.0), CF(0, bodyY, body.Z / 2 + 0.4) * ANG(0, 0, 0), tailCol, { role = "primary" })
	end
	R:group(tm, torso, V(0, bodyY, body.Z / 2), { kind = "tail", axis = "X", amp = 0.15 })
	-- pernas
	if d.legs then
		for _, side in { -1, 1 } do
			local m = R:mark()
			b:box(V(0.15, legH, 0.15), CF(side * 0.3, legH / 2, 0), rgb(240, 160, 50), { role = "fixed" })
			b:box(V(0.5, 0.1, 0.6), CF(side * 0.3, 0.05, -0.15), rgb(240, 160, 50), { role = "fixed" })
			R:group(m, torso, V(side * 0.3, legH, 0), { kind = "leg", axis = "X", amp = 0.6, phase = if side < 0 then 0 else math.pi, speed = 1.5 })
		end
	end
	return R:finish({ hp = params.hp or 40, speed = params.speed or 16, hipHeight = legH, height = headPos.Y + hs / 2, flying = params.fly, radius = body.X })
end

-- PEIXES (nadam no ar) -----------------------------------------------------------
local FISH = {
	fish = { body = V(0.9, 1.2, 2.2), color = rgb(255, 140, 40), color2 = rgb(255, 250, 240), fin = rgb(255, 100, 30) },
	shark = { body = V(1.6, 1.8, 5.0), color = rgb(110, 125, 140), color2 = rgb(240, 240, 245), fin = rgb(100, 115, 130), shark = true },
	whale = { body = V(3.2, 3.0, 8.0), color = rgb(60, 90, 140), color2 = rgb(200, 210, 220), fin = rgb(55, 80, 125), whale = true },
	dolphin = { body = V(1.2, 1.4, 4.0), color = rgb(120, 150, 190), color2 = rgb(230, 235, 245), fin = rgb(110, 140, 180), dolphin = true },
	piranha = { body = V(0.8, 1.4, 1.6), color = rgb(160, 170, 180), color2 = rgb(230, 60, 40), fin = rgb(150, 160, 170), teeth = true },
}

local function fish(origin: CFrame, params: { [string]: any }, variant: string): Rig.RigResult
	local d = FISH[variant] or FISH.fish
	local R = Rig.new(variant, origin, params)
	local b = R.b
	local body = d.body
	local y = body.Y / 2 + 0.5
	local root = R:makeRoot(body, y)
	local torso = b:part("ball", body, CF(0, y, 0), d.color, { role = "primary", name = "Corpo" })
	R:join(torso, root)
	local belly = b:part("ball", body * V(0.85, 0.6, 0.9), CF(0, y - body.Y * 0.2, -0.1), d.color2, { role = "secondary" })
	R:join(belly, torso)
	local front = -body.Z / 2
	for _, side in { -1, 1 } do
		local eye = b:ball(0.18 * math.max(1, body.Y), CF(side * body.X * 0.42, y + body.Y * 0.12, front + body.Z * 0.18), rgb(15, 15, 15), { role = "eye" })
		R:join(eye, torso)
		local fin = b:part("wedge", V(0.1, body.Y * 0.35, body.Z * 0.2), CF(side * body.X * 0.5, y - body.Y * 0.2, front + body.Z * 0.35) * ANG(0, 0, side * rad(60)), d.fin, { role = "primary" })
		R:join(fin, torso, V(side * body.X * 0.45, y - body.Y * 0.2, front + body.Z * 0.3), { kind = "fin", axis = "Z", amp = 0.35, phase = if side < 0 then 0 else math.pi, speed = 1.5 })
	end
	local dorsal = b:part("wedge", V(0.15, body.Y * (if d.shark then 0.7 else 0.4), body.Z * 0.25), CF(0, y + body.Y * 0.55, body.Z * 0.05), d.fin, { role = "primary" })
	R:join(dorsal, torso)
	if d.shark or d.teeth then
		for k = -2, 2 do
			local tooth = b:part("wedge", V(0.12, 0.25, 0.12), CF(k * 0.18 * body.X, y - body.Y * 0.18, front + 0.15) * ANG(rad(180), 0, 0), rgb(255, 255, 255), { role = "fixed" })
			R:join(tooth, torso)
		end
	end
	if d.shark then
		for k = 0, 2 do
			local g = b:box(V(0.05, body.Y * 0.4, 0.06), CF(body.X * 0.48, y, front + body.Z * 0.28 + k * 0.25), Kit.darker(d.color, 0.3), { role = "fixed" })
			R:join(g, torso)
		end
	end
	if d.dolphin then
		local beak = b:box(V(0.4, 0.35, 0.8), CF(0, y - 0.1, front - 0.3), d.color, { role = "primary" })
		R:join(beak, torso)
	end
	-- cauda
	local tm = R:mark()
	if d.whale or d.dolphin then
		b:part("wedge", V(body.X * 1.8, 0.2, body.Z * 0.18), CF(0, y, body.Z / 2 + body.Z * 0.08), d.fin, { role = "primary" })
	else
		b:part("wedge", V(0.15, body.Y * 1.1, body.Z * 0.3), CF(0, y, body.Z / 2 + body.Z * 0.12) * ANG(0, rad(180), 0), d.fin, { role = "primary" })
	end
	R:group(tm, torso, V(0, y, body.Z / 2), { kind = "tail", axis = if (d.whale or d.dolphin) then "X" else "Y", amp = 0.45, speed = 1.3 })
	R.head = torso
	R:setMouth(torso, V(0, 0, front))
	return R:finish({ hp = params.hp or 40, speed = params.speed or 14, hipHeight = 0.5, height = body.Y + 0.5, flying = true, radius = body.Z / 2 })
end

-- POLVO / KRAKEN -------------------------------------------------------------------
local function octopus(origin: CFrame, params: { [string]: any }, variant: string): Rig.RigResult
	local kraken = variant == "kraken"
	local R = Rig.new(variant, origin, params)
	local b = R.b
	local c1 = if kraken then rgb(140, 30, 50) else rgb(230, 110, 150)
	local c2 = Kit.lighter(c1, 0.3)
	local y = 3
	local root = R:makeRoot(V(2.4, 2.4, 2.4), y)
	local mantle = b:part("ball", V(2.6, 3.2, 2.8), CF(0, y + 0.8, 0.2), c1, { role = "primary", name = "Cabeca" })
	R:join(mantle, root)
	R.head = mantle
	for _, side in { -1, 1 } do
		local e = b:ball(0.7, CF(side * 0.75, y + 0.2, -1.2), rgb(250, 250, 230), { role = "fixed" })
		R:join(e, mantle)
		local p = b:box(V(0.45, 0.2, 0.1), CF(side * 0.75, y + 0.2, -1.55), rgb(10, 10, 10), { role = "eye" })
		R:join(p, mantle)
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local dir = V(math.cos(a), 0, math.sin(a))
		local prev = mantle
		local base = V(0, y - 0.4, 0) + dir * 0.9
		local pos = base
		for s = 1, 4 do
			local m = R:mark()
			local stepDir = (dir * 0.75 + V(0, -0.65 + s * 0.12, 0)).Unit
			local nextPos = pos + stepDir * 1.15
			local mid = (pos + nextPos) / 2
			local th = 1.0 - s * 0.16
			b:part("ball", V(th, th, 1.7), CF(mid, nextPos), if s % 2 == 1 then c1 else c2, { role = if s % 2 == 1 then "primary" else "secondary" })
			if s == 2 then
				b:ball(0.3, CF(mid + V(0, -th * 0.45, 0)), Kit.lighter(c2, 0.4), { role = "fixed" })
			end
			prev = R:group(m, prev, pos, { kind = "tentacle", axis = "X", amp = 0.25, phase = k * 0.8 + s * 0.6, speed = 0.9 }) or prev
			pos = nextPos
		end
	end
	R:setMouth(mantle, V(0, -1.4, -0.5))
	return R:finish({ hp = params.hp or 200, speed = params.speed or 12, hipHeight = 2, height = y + 2.4, flying = true, radius = 3 })
end

-- SERPENTES --------------------------------------------------------------------------
local SERP = {
	snake = { n = 8, d = 0.8, color = rgb(80, 150, 60), color2 = rgb(220, 210, 90), pattern = "bands" },
	anaconda = { n = 10, d = 1.0, color = rgb(100, 110, 50), color2 = rgb(30, 30, 20), pattern = "spots" },
	worm = { n = 9, d = 1.6, color = rgb(220, 140, 150), color2 = rgb(190, 110, 120), pattern = "rings", worm = true },
	boitata = { n = 10, d = 1.0, color = rgb(255, 120, 30), color2 = rgb(255, 220, 80), pattern = "glow", glow = true },
	sea_serpent = { n = 10, d = 1.3, color = rgb(40, 120, 130), color2 = rgb(160, 220, 200), pattern = "fins" },
}

local function serpent(origin: CFrame, params: { [string]: any }, variant: string): Rig.RigResult
	local d = SERP[variant] or SERP.snake
	local R = Rig.new(variant, origin, params)
	local b = R.b
	local seg = d.d
	local y = seg / 2
	local root = R:makeRoot(V(seg * 1.2, seg, seg * 1.6), y + 0.3)
	local headPos = V(0, y + 0.4, -seg)
	local hm = R:mark()
	local head = b:part("ball", V(seg * 1.3, seg * 0.9, seg * 1.7), CF(headPos), d.color, { role = "primary", name = "Cabeca", material = if d.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic })
	for _, side in { -1, 1 } do
		b:ball(seg * 0.28, CF(headPos + V(side * seg * 0.4, seg * 0.25, -seg * 0.5)), if d.glow then rgb(255, 255, 220) else rgb(240, 210, 40), { role = "eye", material = Enum.Material.Neon })
	end
	if d.worm then
		b:part("cyl", V(0.2, seg * 1.1, seg * 1.1), CF(headPos + V(0, 0, -seg * 0.85)) * ANG(0, rad(90), 0), rgb(60, 20, 30), { role = "fixed" })
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			b:part("wedge", V(0.15, 0.4, 0.2), CF(headPos + V(math.cos(a) * seg * 0.45, math.sin(a) * seg * 0.45, -seg * 0.85)), rgb(250, 245, 230), { role = "fixed" })
		end
	else
		b:box(V(0.08, 0.05, seg * 0.6), CF(headPos + V(0, -seg * 0.15, -seg * 1.05)), rgb(220, 40, 60), { role = "fixed" })
	end
	R.head = head
	R:group(hm, root, headPos + V(0, 0, seg * 0.5), { kind = "head", axis = "Y", amp = 0.3, speed = 1 })
	local prev: BasePart = root
	for k = 1, d.n do
		local m = R:mark()
		local th = seg * (1 - k / (d.n + 4))
		local pos = V(0, th / 2 + 0.1, k * seg * 0.9)
		local col = if d.pattern == "bands" and k % 2 == 0 then d.color2 elseif d.pattern == "rings" and k % 2 == 0 then d.color2 else d.color
		b:ball(th * 1.15, CF(pos), col, { role = if col == d.color then "primary" else "secondary", material = if d.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic })
		if d.pattern == "spots" and k % 2 == 1 then
			b:ball(th * 0.4, CF(pos + V(th * 0.45, th * 0.2, 0)), d.color2, { role = "secondary" })
		elseif d.pattern == "fins" and k % 2 == 1 then
			b:part("wedge", V(0.12, th * 0.7, th * 0.8), CF(pos + V(0, th * 0.6, 0)), d.color2, { role = "secondary" })
		end
		prev = R:group(m, prev, pos - V(0, 0, seg * 0.45), { kind = "segment", axis = "Y", amp = 0.22, phase = k * 0.7, speed = 1.2 }) or prev
	end
	if d.glow then
		Kit.elementEffects(head, "fire", 1)
	end
	R:setMouth(head, V(0, 0, -seg * 0.9))
	return R:finish({ hp = params.hp or 100, speed = params.speed or 14, hipHeight = 0.3, height = seg * 1.4, flying = params.fly, radius = seg * 2 })
end

-- INSETOS E ARACNÍDEOS -------------------------------------------------------------
local BUGS = {
	spider = { legs = 8, color = rgb(40, 35, 35), color2 = rgb(180, 30, 30), body = V(1.6, 1.0, 1.4), abdomen = V(2.2, 1.8, 2.4), eyes = 6 },
	scorpion = { legs = 8, color = rgb(70, 50, 30), color2 = rgb(120, 85, 50), body = V(1.6, 0.8, 2.0), abdomen = V(1.4, 0.7, 2.2), claws = true, stinger = true },
	ant = { legs = 6, color = rgb(160, 40, 30), color2 = rgb(120, 30, 25), body = V(0.8, 0.8, 1.0), abdomen = V(1.3, 1.2, 1.6), antenna = true },
	bee = { legs = 6, color = rgb(250, 200, 30), color2 = rgb(30, 25, 20), body = V(0.9, 0.9, 1.0), abdomen = V(1.2, 1.2, 1.6), wings = true, stripes = true, antenna = true },
	butterfly = { legs = 0, color = rgb(60, 40, 40), color2 = rgb(255, 120, 200), body = V(0.4, 0.4, 0.9), abdomen = V(0.4, 0.4, 1.0), bigWings = true, antenna = true },
	beetle = { legs = 6, color = rgb(40, 120, 90), color2 = rgb(30, 90, 70), body = V(1.0, 0.8, 0.9), abdomen = V(1.8, 1.2, 2.0), shell = true, antenna = true },
	mosquito = { legs = 6, color = rgb(70, 70, 75), color2 = rgb(120, 110, 100), body = V(0.5, 0.5, 0.7), abdomen = V(0.4, 0.4, 1.4), wings = true, proboscis = true },
}

local function bug(origin: CFrame, params: { [string]: any }, variant: string): Rig.RigResult
	local d = BUGS[variant] or BUGS.ant
	local R = Rig.new(variant, origin, params)
	local b = R.b
	local legH = if d.legs > 0 then 0.9 else 0.3
	local y = legH + d.body.Y / 2
	local root = R:makeRoot(V(d.body.X, d.body.Y, d.body.Z + d.abdomen.Z), y)
	local thorax = b:part("ball", d.body, CF(0, y, 0), d.color, { role = "primary", name = "Corpo" })
	R:join(thorax, root)
	local abd = b:part("ball", d.abdomen, CF(0, y + d.abdomen.Y * 0.15, d.body.Z / 2 + d.abdomen.Z / 2 - 0.1), if variant == "spider" or variant == "bee" then d.color else d.color2, { role = "primary" })
	R:join(abd, thorax, V(0, y, d.body.Z / 2), { kind = "tail", axis = "X", amp = 0.08 })
	if d.stripes then
		for k = -1, 1 do
			local s = b:part("cyl", V(0.2, d.abdomen.Y * 1.02, d.abdomen.Y * 1.02), CF(0, y + d.abdomen.Y * 0.15, d.body.Z / 2 + d.abdomen.Z / 2 + k * 0.4) * ANG(0, rad(90), 0), d.color2, { role = "secondary" })
			R:join(s, abd)
		end
	end
	if d.shell then
		local s = b:part("ball", d.abdomen * V(1.08, 1.05, 1.02), CF(0, y + d.abdomen.Y * 0.25, d.body.Z / 2 + d.abdomen.Z / 2 - 0.1), d.color, { role = "primary", reflectance = 0.2 })
		R:join(s, abd)
	end
	if variant == "spider" then
		local mark = b:box(V(0.5, 0.06, 0.8), CF(0, y + d.abdomen.Y * 0.62, d.body.Z / 2 + d.abdomen.Z / 2), d.color2, { role = "accent" })
		R:join(mark, abd)
	end
	-- cabeça
	local hm = R:mark()
	local headPos = V(0, y + 0.1, -d.body.Z / 2 - 0.35)
	local head = b:ball(math.max(d.body.X * 0.7, 0.4), CF(headPos), d.color, { role = "primary", name = "Cabeca" })
	R.head = head
	local eyes = d.eyes or 2
	for k = 1, eyes do
		local col = if variant == "spider" then rgb(220, 30, 30) else rgb(15, 15, 15)
		local x = (k - (eyes + 1) / 2) * 0.18
		b:ball(0.18, CF(headPos + V(x, 0.12 + (if k % 2 == 0 then 0.1 else 0), -0.3)), col, { role = "eye", material = if variant == "spider" then Enum.Material.Neon else Enum.Material.SmoothPlastic })
	end
	if d.antenna then
		for _, side in { -1, 1 } do
			b:beam(headPos + V(side * 0.12, 0.2, -0.2), headPos + V(side * 0.45, 0.9, -0.6), 0.06, d.color, { role = "fixed" })
		end
	end
	if d.proboscis then
		b:box(V(0.06, 0.06, 0.8), CF(headPos + V(0, -0.1, -0.6)), d.color, { role = "fixed" })
	end
	R:group(hm, thorax, headPos + V(0, 0, 0.3), { kind = "head", axis = "Y", amp = 0.2 })
	R:setMouth(head, V(0, -0.1, -0.4))
	if d.claws then
		for _, side in { -1, 1 } do
			local m = R:mark()
			b:beam(V(side * 0.6, y, -d.body.Z / 2), V(side * 1.2, y, -d.body.Z / 2 - 1.2), 0.3, d.color, { role = "primary" })
			b:part("wedge", V(0.5, 0.35, 0.8), CF(side * 1.25, y, -d.body.Z / 2 - 1.6), d.color2, { role = "secondary" })
			R:group(m, thorax, V(side * 0.6, y, -d.body.Z / 2), { kind = "arm", axis = "Y", amp = 0.3, phase = if side < 0 then 0 else math.pi })
		end
	end
	if d.stinger then
		local prev: BasePart = abd
		local base = V(0, y + 0.2, d.body.Z / 2 + d.abdomen.Z)
		for k = 1, 4 do
			local m = R:mark()
			local pos = base + V(0, k * 0.55, -k * 0.25 + (if k > 2 then -0.4 else 0))
			b:ball(0.5 - k * 0.05, CF(pos), d.color2, { role = "secondary" })
			if k == 4 then
				b:part("wedge", V(0.15, 0.5, 0.3), CF(pos + V(0, 0, -0.35)) * ANG(rad(-90), 0, 0), rgb(30, 20, 15), { role = "fixed" })
			end
			prev = R:group(m, prev, pos - V(0, 0.25, 0), { kind = "tail", axis = "X", amp = 0.15, phase = k * 0.5 }) or prev
		end
	end
	-- pernas
	local pairs = d.legs // 2
	for i = 1, pairs do
		for _, side in { -1, 1 } do
			local m = R:mark()
			local z = (i - (pairs + 1) / 2) * (d.body.Z / pairs) * 0.9
			local hip = V(side * d.body.X * 0.45, y, z)
			local knee = hip + V(side * 1.0, 0.5, z * 0.2)
			local foot = V(side * (d.body.X * 0.45 + 1.6), 0, z * 1.4)
			b:beam(hip, knee, 0.14, d.color, { role = "primary" })
			b:beam(knee, foot, 0.12, d.color, { role = "primary" })
			R:group(m, thorax, hip, { kind = "leg", axis = "Y", amp = 0.35, phase = (i + (if side < 0 then 0 else 1)) * math.pi, speed = 1.8 })
		end
	end
	-- asas
	if d.wings or d.bigWings then
		for _, side in { -1, 1 } do
			local m = R:mark()
			local span = if d.bigWings then 2.4 else 1.2
			local col = if d.bigWings then d.color2 else rgb(220, 235, 255)
			b:part("ball", V(span, 0.08, span * 0.8), CF(side * (d.body.X / 2 + span / 2), y + 0.5, 0), col, { role = if d.bigWings then "accent" else "fixed", material = if d.bigWings then Enum.Material.SmoothPlastic else Enum.Material.Glass, transparency = if d.bigWings then 0 else 0.4 })
			if d.bigWings then
				b:part("ball", V(span * 0.8, 0.08, span * 0.6), CF(side * (d.body.X / 2 + span * 0.4), y + 0.45, span * 0.55), Kit.lighter(col, 0.3), { role = "accent" })
				b:ball(0.4, CF(side * (d.body.X / 2 + span * 0.6), y + 0.55, 0), rgb(30, 30, 40), { role = "fixed" })
			end
			R:group(m, thorax, V(side * d.body.X / 2, y + 0.4, 0), { kind = "wing", axis = "Z", amp = if d.bigWings then 0.7 else 0.5, phase = if side < 0 then 0 else math.pi, speed = if d.bigWings then 1.2 else 5 })
		end
	end
	return R:finish({ hp = params.hp or 60, speed = params.speed or 16, hipHeight = legH, height = y + 1, flying = params.fly, radius = 1.6 })
end

-- SLIME ----------------------------------------------------------------------------
local function slime(origin: CFrame, params: { [string]: any }, _variant: string): Rig.RigResult
	local R = Rig.new("slime", origin, params)
	local b = R.b
	local col = rgb(90, 220, 110)
	local root = R:makeRoot(V(2.6, 2.4, 2.6), 1.4)
	local m = R:mark()
	b:box(V(2.6, 2.4, 2.6), CF(0, 1.4, 0), col, { role = "primary", material = Enum.Material.Glass, transparency = 0.25, name = "Corpo" })
	b:box(V(1.6, 1.4, 1.6), CF(0, 1.3, 0), Kit.darker(col, 0.25), { role = "secondary" })
	for _, side in { -1, 1 } do
		b:box(V(0.35, 0.5, 0.1), CF(side * 0.55, 1.8, -1.32), rgb(15, 30, 15), { role = "eye" })
	end
	b:box(V(0.9, 0.15, 0.1), CF(0, 1.2, -1.32), rgb(20, 60, 25), { role = "fixed" })
	local body = R:group(m, root, V(0, 0.4, 0), { kind = "bob", axis = "Y", amp = 0.35, speed = 1.6 })
	R.head = body
	if body then
		R:setMouth(body, V(0, -0.2, -1.3))
	end
	return R:finish({ hp = params.hp or 100, speed = params.speed or 12, hipHeight = 0.2, height = 2.6, radius = 1.4 })
end

Beasts.quadruped = quadruped
Beasts.theropod = theropod
Beasts.bird = bird
Beasts.fish = fish
Beasts.octopus = octopus
Beasts.serpent = serpent
Beasts.bug = bug
Beasts.slime = slime
Beasts.Quadrupeds = QUAD

return Beasts
