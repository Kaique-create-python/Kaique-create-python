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
			Font = roblox.Font, utf8 = utf8,
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
		end
		assert(wheel.cards[3].card.BackgroundTransparency < wheel.cards[1].card.BackgroundTransparency, "the selected slot is the solid one")
		local card = play.buildWeaponCard(root, touch, atlas)
		card.show(defs[3], nil, ammo.vespa, nil)
		assert(card.panel:FindFirstChild("Pente").Text:find("^9"), "the card shows the magazine")
		assert(card.panel:FindFirstChild("Reserva").Text == "/96")
		card.show(defs[4], nil, ammo.enxame, 0.5)
		assert(card.panel:FindFirstChild("Recarga").Visible, "the reload progress shows while reloading")
		card.show(defs[1], nil, nil, nil)
		assert(card.panel:FindFirstChild("Pente").Text == "", "fists have no ammo")
		for _, glyph in { "tiro", "mira", "recarga" } do
			local button = play.touchButton(root, "Botao", "", glyph, roblox.Vector2.new(80, 80), 30, atlas)
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
-- Layout: nada se sobrepõe nos aparelhos do padrão de interface (área segura em px do Roblox).
local V2 = roblox.Vector2
local devices = {
	{ "Galaxy A06", V2.new(705, 280), true }, { "iPhone 17 Pro", V2.new(750, 323), true },
	{ "Fire HD 10", V2.new(959, 541), true }, { "iPad 10", V2.new(1179, 761), true },
	{ "Windows 1366", V2.new(1365, 710), false }, { "HD 1080", V2.new(1919, 1021), false },
}
local function overlap(a, b)
	return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
end
for _, device in devices do
	local name, screen, touch = device[1], device[2], device[3]
	local l = play.hudLayout(screen, touch, nil)
	local rects = {}
	for _, key in { "minimap", "weapon", "toast" } do
		local x0, y0, x1, y1 = play.layoutRect(l[key], l.scale)
		rects[key] = { x0, y0, x1, y1 }
	end
	for key, b in l.buttons do
		rects[key] = { b.center.X - b.radius, b.center.Y - b.radius, b.center.X + b.radius, b.center.Y + b.radius }
		assert(b.radius * 2 >= 42, name .. ": " .. key .. " is too small to tap")
		local gap = (b.center - l.jump.center).Magnitude - b.radius - l.jump.radius
		assert(gap >= 4, name .. ": " .. key .. " touches the jump button")
	end
	for key, r in rects do
		assert(r[1] >= 0 and r[2] >= 0 and r[3] <= screen.X + 0.01 and r[4] <= screen.Y + 0.01, name .. ": " .. key .. " leaves the safe area")
		for other, q in rects do
			if key < other then
				assert(not overlap(r, q), string.format("%s: %s overlaps %s", name, key, other))
			end
		end
		-- Centro da tela livre e caixas reservadas do analógico e do pulo do Roblox.
		local cx, cy = screen.X / 2, screen.Y / 2
		if not l.buttons[key] then -- os botões de ação ficam perto do polegar; as leituras, longe do centro
			assert(not overlap(r, { cx - screen.X / 4, cy - screen.Y / 4, cx + screen.X / 4, cy + screen.Y / 4 }), name .. ": " .. key .. " covers the center")
		end
		if touch then
			local large = math.min(screen.X, screen.Y) > 500
			local stick = if large then { 0, screen.Y - 195, 215, screen.Y } else { 0, screen.Y - 100, 110, screen.Y }
			local jump = if large then { screen.X - 170, screen.Y - 210, screen.X, screen.Y } else { screen.X - 95, screen.Y - 90, screen.X, screen.Y }
			assert(not overlap(r, stick), name .. ": " .. key .. " sits on the thumbstick")
			assert(not overlap(r, jump), name .. ": " .. key .. " sits on the jump button")
		end
	end
	-- Orçamento do HUD fixo no celular (mapa e arma): até 16% da tela.
	if touch then
		local area = 0
		for _, key in { "minimap", "weapon" } do
			local r = rects[key]
			area += (r[3] - r[1]) * (r[4] - r[2])
		end
		assert(area / (screen.X * screen.Y) < 0.16, name .. ": the HUD covers too much of the screen")
	end
end

-- HUD com o traçado real da cidade: minimapa, giro, distrito, hora, rastro de dano, fôlego e descanso.
do
	local normals = { Front = V3.new(0, 0, -1) }
	local worldSource = string.gsub(fs.readFile("src/world.server.luau"), "__CYBEROUTLAW_ART__", "{}")
	local _, _, layoutData = luau.load(worldSource, {
		debugName = "world.server.luau",
		environment = {
			Instance = roblox.Instance, CFrame = roblox.CFrame, Vector2 = roblox.Vector2, Color3 = roblox.Color3,
			Vector3 = setmetatable({ FromNormalId = function(face) return normals[face.Name] end }, { __index = roblox.Vector3 }),
			ColorSequence = roblox.ColorSequence, Enum = roblox.Enum, UDim2 = roblox.UDim2, Font = roblox.Font, Content = roblox.Content,
		},
	})()
	local city = layoutData()
	for _, touch in { false, true } do
		local folder = roblox.Instance.new("Folder")
		local hud = play.buildHud(folder, touch)
		local l = play.hudLayout(if touch then V2.new(705, 280) else V2.new(1919, 1021), touch, nil)
		hud.layout(l)
		assert(hud.gui.ScreenInsets == roblox.Enum.ScreenInsets.CoreUISafeInsets and hud.gui.ZIndexBehavior == roblox.Enum.ZIndexBehavior.Sibling)
		local view = hud.gui:FindFirstChild("Viewport", true)
		assert(view.ClipsDescendants and view.ClassName == "Frame", "the minimap clips without CanvasGroup")
		assert(hud.gui:FindFirstChild("NoSignal", true).Visible, "no map before the city publishes its layout")
		hud.setMap(city)
		assert(not hud.gui:FindFirstChild("NoSignal", true).Visible, "the minimap draws the published city")
		local state = {
			health = 100, maxHealth = 100, stamina = 1, exhausted = false, position = V3.new(108, 3, 140),
			cameraYaw = -math.pi / 2, facingYaw = 0, district = { name = "Distrito Prisma" }, clock = "00:36",
		}
		hud.update(state, 0.1)
		local scale = if touch then 0.16 else 0.22
		local extent = city.half + 400
		local map = hud.parts.map
		assert(math.abs(map.Position.X.Offset + (108 + extent) * scale) <= 1 and math.abs(map.Position.Y.Offset + (140 + extent) * scale) <= 1)
		assert(math.abs(hud.parts.pivot.Rotation + 90) < 0.001, "looking east turns the map")
		assert(math.abs(hud.parts.arrow.Rotation + 90) < 0.001, "the player faces north, left of the camera")
		assert(hud.gui:FindFirstChild("DistrictName", true).Text == "DISTRITO PRISMA" and hud.gui:FindFirstChild("Clock", true).Text == "00:36")
		assert(hud.parts.toast.Visible and hud.gui:FindFirstChild("DistrictTitle", true).Text == "DISTRITO PRISMA")
		state.district = { name = "Docas da Maré" }
		hud.update(state, 0.1)
		assert(hud.gui:FindFirstChild("DistrictName", true).Text == "DOCAS DA MARÉ", "accented capitals")
		for _ = 1, 50 do
			hud.update(state, 0.1)
		end
		assert(not hud.parts.toast.Visible, "the toast leaves after a few seconds")
		assert(not hud.gui:FindFirstChild("StaminaTrack", true).Visible, "stamina hides while full")
		state.stamina = 0.4
		hud.update(state, 0.1)
		local fillBreath = hud.gui:FindFirstChild("StaminaFill", true)
		assert(hud.gui:FindFirstChild("StaminaTrack", true).Visible and math.abs(fillBreath.Size.X.Scale - 0.4) < 0.001)
		state.stamina = 1
		state.health = 50
		hud.update(state, 0.1)
		assert(hud.parts.trail.Size.X.Scale == 1 and hud.parts.fill.Size.X.Scale == 0.5, "the damage trail waits")
		for _ = 1, 15 do
			hud.update(state, 0.1)
		end
		assert(math.abs(hud.parts.trail.Size.X.Scale - 0.5) < 0.001, "the trail catches up with the health")
		state.health = 20
		hud.update(state, 0.1)
		assert(hud.parts.fill.BackgroundColor3 ~= roblox.Color3.fromRGB(98, 212, 148), "low health turns the bar red")
		state.health = 100
		for _ = 1, 140 do
			hud.update(state, 0.1)
		end
		assert(hud.parts.fill.BackgroundTransparency > 0.4, "the vitals rest when nothing happens")
		state.safe = true
		hud.update(state, 0.1)
		assert(hud.parts.safe.Visible)
		local combat = play.buildCombat(folder, touch)
		combat.crosshair(false, 0)
		assert(not combat.parts.cross.Visible, "no crosshair without aiming a gun")
		combat.crosshair(true, 0.5)
		combat.hit(true)
		combat.step(0.05, 1, 0)
		assert(combat.parts.cross.Visible and combat.parts.hit.Visible and combat.parts.aimEdges[1].piece.Visible)
		combat.step(1, 0, 0)
		assert(not combat.parts.hit.Visible)
		combat.death(true, "SINAL PERDIDO")
		assert(combat.parts.death.Visible)
	end
end
assert(play.upper("maré baixa, ação") == "MARÉ BAIXA, AÇÃO")
print("CyberOutlawPlay: spring, wheel, stamina, cone, R6 poses, layout on 6 screens, HUD, combat layer, 2D and 3D icons passed")
