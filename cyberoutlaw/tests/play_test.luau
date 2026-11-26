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
			Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence,
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

-- Stamina: empties in ~13 s of sprinting and only lets you sprint again with 30%.
do
	local state = { value = 1, rest = 0, exhausted = false }
	for _ = 1, 600 do
		play.staminaStep(state, true, 1 / 60)
	end
	assert(not state.exhausted, "10 s of sprint still left")
	for _ = 1, 220 do
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
local ammo = { glock = { 9, 102 }, deagle = { 7, 42 }, uzi = { 32, 192 }, ak47 = { 30, 150 }, m4 = { 30, 180 },
	escopeta = { 6, 40 }, sniper = { 5, 30 } }
for _, atlas in { nil, "rbxassetid://123" } do
	for _, touch in { false, true } do
		local wheel = play.buildWheel(root, defs, nil, touch, atlas)
		assert(wheel.gui:IsA("ScreenGui") and #wheel.cards == 9)
		wheel.select(3, ammo)
		wheel.animate(0.1, 1)
		assert(wheel.cards[3].pop.Scale > 1 and wheel.cards[1].pop.Scale == 1, "the selected card stands out")
		assert(wheel.cards[3].ammo.Text == "9/102")
		if atlas then
			for index, entry in wheel.cards do
				local offset, size = play.iconRect(defs[index].id)
				assert(entry.image.Image == atlas and entry.image.ImageRectOffset == offset and entry.image.ImageRectSize == size)
			end
		end
		assert(wheel.cards[3].card.BackgroundTransparency < wheel.cards[1].card.BackgroundTransparency, "the selected slot is the solid one")
		for _, glyph in { "tiro", "mira", "recarga" } do
			local button = play.touchButton(root, "Botao", "", glyph, roblox.Vector2.new(80, 80), 30, atlas)
			assert(button:IsA("TextButton"))
		end
		for _, glyph in { "arsenal", "implantes", "sandevistan" } do
			local entry = play.neonButton(root, "Neon", glyph, atlas, if touch then nil else "I", touch)
			assert(entry.button:IsA("TextButton") and entry.scale:IsA("UIScale"))
			assert((entry.image ~= nil) == (atlas ~= nil), "atlas symbol, or a Frame glyph while the atlas waits")
			entry.light(true, roblox.Color3.fromRGB(255, 72, 140))
			assert(entry.line.Thickness > 2 and entry.halo.Transparency < 0.6, "a lit button glows")
		end
	end
end
-- Atlas: cells inside the 1024 image and without overlap.
local seen = {}
for _, key in { "punhos", "faca", "glock", "deagle", "uzi", "ak47", "m4", "escopeta", "sniper",
	"tiro", "mira", "recarga", "arsenal", "correr", "golpe", "teleporte", "fechar",
	"implantes", "sandevistan", "psicose", "kiroshi", "louva", "gorila", "tendoes", "subdermal" } do
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
	local keys = if touch then { "minimap", "neon", "toast", "arsenal", "implants" } else { "minimap", "neon", "toast", "implants", "ability" }
	for _, key in keys do
		local x0, y0, x1, y1 = play.layoutRect(l[key], l.scale)
		rects[key] = { x0, y0, x1, y1 }
		if key ~= "minimap" and key ~= "toast" and key ~= "neon" then
			assert(l[key].size.X * l.scale >= 44 and l[key].size.Y * l.scale >= 44, name .. ": " .. key .. " is too small to tap")
		end
	end
	-- Barra de armas: no máximo 0,18 da altura no celular, e as caixas de toque com passo de 40 px ou mais.
	local barW, barH = l.neon.size.X * l.scale, l.neon.size.Y * l.scale
	assert(barW * play.BAR_HITS[2][1].X.Scale - barW * play.BAR_HITS[1][1].X.Scale >= 40, name .. ": weapon slots too close to tap")
	if touch then
		assert(barH / screen.Y <= 0.18, name .. ": the weapon bar is too tall")
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
	-- Orçamento do HUD fixo no celular (mapa e barra de armas): até 16% da tela.
	if touch then
		local area = 0
		for _, key in { "minimap", "neon" } do
			local r = rects[key]
			area += (r[3] - r[1]) * (r[4] - r[2])
		end
		assert(area / (screen.X * screen.Y) < 0.16, name .. ": the HUD covers too much of the screen")
	end
end

local city
do
	local normals = { Front = V3.new(0, 0, -1) }
	local worldSource = require("./support/world_source")()
	local _, _, layoutData = luau.load(worldSource, {
		debugName = "world.server.luau",
		environment = {
			Instance = roblox.Instance, CFrame = roblox.CFrame, Vector2 = roblox.Vector2, Color3 = roblox.Color3,
			Vector3 = setmetatable({ FromNormalId = function(face) return normals[face.Name] end }, { __index = roblox.Vector3 }),
			ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, Enum = roblox.Enum, UDim2 = roblox.UDim2, Font = roblox.Font, Content = roblox.Content,
		},
	})()
	city = layoutData()
end

-- As duas direções usam eixos próprios. O canal só pode ser cruzado nas pontes.
do
	local hud = play.buildHud(roblox.Instance.new("Folder"), true)
	local layout = table.clone(city)
	layout.lines = nil
	hud.setMap(layout)
	assert(not hud.gui:FindFirstChild("NoSignal", true).Visible, "the minimap accepts independent street axes")
	local map = hud.parts.map
	assert(map.Size.X.Offset == 512 and math.abs(map.Size.Y.Offset - 435.2) < 1, "the rectangular map keeps equal scale on both axes")
	local function covering(x, z)
		local px, py = (x + 1600) * 0.16, (z + 1360) * 0.16
		local hit
		for _, child in map:GetChildren() do
			local left, top = child.Position.X.Offset, child.Position.Y.Offset
			if (not hit or child.ZIndex > hit.ZIndex) and px >= left and px < left + child.Size.X.Offset
				and py >= top and py < top + child.Size.Y.Offset then
				hit = child
			end
		end
		return hit
	end
	assert(covering(-240, 120).Name == "Rua" and covering(120, 0).Name == "Avenida")
	assert(covering(0, 120).Name == "Canal", "the central grid line never becomes a street")
	local foot, road = covering(0, -480), covering(0, 0)
	assert(foot.Name == "Passarela" and road.Name == "Ponte" and foot.BackgroundColor3 ~= road.BackgroundColor3,
		"footbridges and road bridges are distinct")
	assert(foot.Size.Y.Offset < road.Size.Y.Offset and covering(0, -465).Name == "Canal",
		"the pedestrian crossing preserves the canal next to its narrower span")
end

-- HUD com o traçado real da cidade: minimapa, giro, distrito, hora, rastro de dano, fôlego e descanso.
do
	for _, touch in { false, true } do
		local folder = roblox.Instance.new("Folder")
		local hud = play.buildHud(folder, touch)
		local l = play.hudLayout(if touch then V2.new(705, 280) else V2.new(1919, 1021), touch, nil)
		hud.layout(l)
		assert(hud.gui.ScreenInsets == roblox.Enum.ScreenInsets.CoreUISafeInsets and hud.gui.ZIndexBehavior == roblox.Enum.ZIndexBehavior.Sibling)
		local view = hud.gui:FindFirstChild("Viewport", true)
		assert(view.ClipsDescendants and view.ClassName == "Frame", "the minimap clips without CanvasGroup")
		assert(hud.gui:FindFirstChild("NoSignal", true).Visible, "no map before the city publishes its layout")
		local map = hud.parts.map
		hud.setMap({ half = 1000, quay = 1070, lines = { { 0, 70, 12 } } })
		assert(map.Size.X.Offset == map.Size.Y.Offset and map:FindFirstChild("Agua"), "a legacy square layout still draws its bay")
		hud.setMap(city)
		assert(not hud.gui:FindFirstChild("NoSignal", true).Visible, "the minimap draws the published city")
		local state = {
			health = 100, maxHealth = 100, stamina = 1, exhausted = false, position = V3.new(city.spawn[1], 3, city.spawn[2]),
			cameraYaw = -math.pi / 2, facingYaw = 0, district = { name = "Distrito Prisma" }, clock = "00:36",
		}
		hud.update(state, 0.1)
		local scale = if touch then 0.16 else 0.22
		local extentX, extentZ = city.halfX + 400, city.halfZ + 400
		assert(math.abs(map.Position.X.Offset + (state.position.X + extentX) * scale) <= 1
			and math.abs(map.Position.Y.Offset + (state.position.Z + extentZ) * scale) <= 1)
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

-- Locomoção procedural: cadência, pernas opostas, passos, respiração parada, salto, aterrissagem e escalada.
do
	local g = play.newGait()
	local steps, last = 0, nil
	for _ = 1, 120 do
		local pose = play.gaitStep(g, { velocity = V3.new(0, 0, -17), state = "run", yawRate = 0, verticalSpeed = 0 }, 1 / 60)
		if pose.step ~= 0 then
			steps += 1
		end
		last = pose
	end
	assert(steps >= 5 and steps <= 7, "about three steps per second while running, got " .. steps)
	for _, dir in { last.rightLeg, last.leftLeg, last.rightArm, last.leftArm } do
		assert(math.abs(dir.Magnitude - 1) < 1e-4)
	end
	-- Pernas opostas: quando uma vai à frente (-Z), a outra vai atrás.
	local found = false
	for _ = 1, 60 do
		local pose = play.gaitStep(g, { velocity = V3.new(0, 0, -17), state = "run" }, 1 / 60)
		if math.abs(pose.rightLeg.Z) > 0.3 then
			assert(pose.rightLeg.Z * pose.leftLeg.Z < 0, "legs swing in opposite directions")
			assert(pose.rightArm.Z * pose.rightLeg.Z < 0, "the right arm counters the right leg")
			found = true
		end
	end
	assert(found)
	-- Correndo, o tronco inclina para a frente (rotação negativa em X).
	local rx = select(1, last.root:ToEulerAnglesXYZ())
	assert(rx < -0.05, "leans forward while running")
	-- Lateral (mirando e andando de lado): as pernas balançam em X.
	local side = play.newGait()
	local maxX = 0
	for _ = 1, 90 do
		local pose = play.gaitStep(side, { velocity = V3.new(11, 0, 0), state = "run" }, 1 / 60)
		maxX = math.max(maxX, math.abs(pose.rightLeg.X))
	end
	assert(maxX > 0.3, "strafing swings the legs sideways")
	-- Parado: pernas quase retas, respiração pequena.
	local idle = play.newGait()
	local pose
	for _ = 1, 120 do
		pose = play.gaitStep(idle, { velocity = V3.zero, state = "run" }, 1 / 60)
	end
	assert(pose.rightLeg.Y < -0.95 and pose.step == 0 and math.abs(pose.root.Position.Y) < 0.06)
	-- Salto e aterrissagem com mola.
	for _ = 1, 30 do
		pose = play.gaitStep(idle, { velocity = V3.new(0, -50, 0), state = "fall", verticalSpeed = -50 }, 1 / 60)
	end
	assert(pose.rightLeg.Z < -0.3 and pose.rightArm.X > 0.3, "in the air: one leg forward, arms out")
	local lowest = 0
	for _ = 1, 20 do
		pose = play.gaitStep(idle, { velocity = V3.zero, state = "run" }, 1 / 60)
		lowest = math.min(lowest, pose.root.Position.Y)
	end
	assert(lowest < -0.1, "landing squashes the body")
	for _ = 1, 90 do
		pose = play.gaitStep(idle, { velocity = V3.zero, state = "run" }, 1 / 60)
	end
	assert(math.abs(pose.root.Position.Y) < 0.06, "the body recovers after landing")
	-- Escada e nado: a pose procedural sai de cena para o Animate do Roblox.
	for _ = 1, 60 do
		pose = play.gaitStep(idle, { velocity = V3.new(0, 8, 0), state = "climb" }, 1 / 60)
	end
	assert(pose.weight < 0.05)
	-- RootJoint: o Transform leva o tronco ao deslocamento pedido no espaço do HumanoidRootPart.
	local c0 = CF.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	local offset = CF.new(0.1, -0.2, 0) * CF.Angles(-0.15, 0.05, 0.1)
	local torso = c0 * play.rootTransform(c0, offset) * c0:Inverse()
	local expected = offset * c0 * c0:Inverse()
	assert((torso.Position - expected.Position).Magnitude < 1e-5 and (torso.LookVector - expected.LookVector).Magnitude < 1e-5)
end

-- Reflexo planar: os cantos da peça espelhada são o espelho dos cantos da original (blocos e cunhas).
do
	local plane = 0.25
	local function corners(cf, size)
		local list = {}
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					table.insert(list, cf:PointToWorldSpace(V3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2)))
				end
			end
		end
		return list
	end
	local function sameSet(a, b)
		for _, p in a do
			local hit = false
			for _, q in b do
				if (p - q).Magnitude < 1e-3 then
					hit = true
				end
			end
			if not hit then
				return false
			end
		end
		return true
	end
	local size = V3.new(4, 30, 2)
	for _, cf in { CF.new(10, 20, -5), CF.new(3, 40, 7) * CF.Angles(0.3, 1.1, -0.4), CF.new(-8, 12, 2) * CF.Angles(0, 0, math.pi / 2) } do
		local mirrored = play.mirrorCFrame(cf, plane)
		local expected = {}
		for _, p in corners(cf, size) do
			table.insert(expected, V3.new(p.X, 2 * plane - p.Y, p.Z))
		end
		assert(sameSet(corners(mirrored, size), expected), "mirrored box corners")
		assert(math.abs(mirrored.Position.Y - (2 * plane - cf.Position.Y)) < 1e-5)
	end
	-- Cunha: o plano inclinado também precisa refletir (a cunha do Roblox desce de +Z para -Z).
	local wedge = CF.new(5, 6, 1) * CF.Angles(0.2, 0.7, 0)
	local function wedgePoints(cf, s)
		local local3 = { V3.new(-1, -1, -1), V3.new(1, -1, -1), V3.new(1, -1, 1), V3.new(-1, -1, 1), V3.new(-1, 1, 1), V3.new(1, 1, 1) }
		local list = {}
		for _, v in local3 do
			table.insert(list, cf:PointToWorldSpace(V3.new(v.X * s.X / 2, v.Y * s.Y / 2, v.Z * s.Z / 2)))
		end
		return list
	end
	local wsize = V3.new(3, 4, 6)
	local expected = {}
	for _, p in wedgePoints(wedge, wsize) do
		table.insert(expected, V3.new(p.X, 2 * plane - p.Y, p.Z))
	end
	assert(sameSet(wedgePoints(play.mirrorCFrame(wedge, plane, true), wsize), expected), "mirrored wedge keeps its slope")
end
-- Animações do catálogo no R6: a pose do esqueleto R15 vira a pose do R6.
do
	local CF, V3 = roblox.CFrame, roblox.Vector3
	local function near(a, b, tolerance)
		return (a - b).Magnitude < (tolerance or 0.02)
	end
	local rest = play.retargetPose({})
	for _, key in { "rightArm", "leftArm", "rightLeg", "leftLeg" } do
		assert(near(rest[key], V3.new(0, -1, 0)), key .. " hangs straight at rest")
		assert(near(rest[key .. "Up"], V3.new(0, 0, -1)), key .. " faces forward at rest")
	end
	assert(near(rest.root.Position, V3.zero) and near(rest.root.LookVector, V3.new(0, 0, -1)), "torso at rest")
	-- Braço do R15 levantado para a frente: o braço do R6 aponta para a frente.
	local raised = play.retargetPose({ RightShoulder = CF.Angles(math.rad(90), 0, 0) })
	assert(raised.rightArm.Z < -0.95 and math.abs(raised.rightArm.Y) < 0.2, "arm forward: " .. tostring(raised.rightArm))
	assert(near(raised.leftArm, V3.new(0, -1, 0)), "the other arm stays down")
	-- Cotovelo dobrado 90° com o braço para baixo: o R6 aponta na diagonal, para a frente e para baixo.
	local bent = play.retargetPose({ RightElbow = CF.Angles(math.rad(90), 0, 0) })
	assert(bent.rightArm.Z < -0.3 and bent.rightArm.Y < -0.6, "bent elbow: " .. tostring(bent.rightArm))
	-- Perna 30° para a frente.
	local step = play.retargetPose({ LeftHip = CF.Angles(math.rad(30), 0, 0) })
	assert(math.abs(math.deg(math.atan2(-step.leftLeg.Z, -step.leftLeg.Y)) - 30) < 3, "leg forward 30°")
	-- Tronco: giro da cintura passa pela metade (mistura dos dois troncos).
	local twist = play.retargetPose({ Waist = CF.Angles(0, math.rad(20), 0) })
	local yaw = math.deg(math.atan2(-twist.root.LookVector.X, -twist.root.LookVector.Z))
	assert(yaw > 8 and yaw < 18, "torso twist " .. yaw)
	-- Pernas giram com o movimento lateral (mirando e andando de lado).
	local side = play.retargetPose({ LeftHip = CF.Angles(math.rad(30), 0, 0) }, math.rad(-90))
	assert(side.leftLeg.X > 0.2 and math.abs(side.leftLeg.Z) < 0.15, "strafe turns the step: " .. tostring(side.leftLeg))
	-- Andando de costas: o passo inverte, mas a perna não torce (torcer abria as pernas no R6).
	local back = play.retargetPose({ LeftHip = CF.Angles(math.rad(30), 0, 0) }, math.pi)
	assert(back.leftLeg.Z > 0.4, "backward step goes back: " .. tostring(back.leftLeg))
	for _, pose in { side, back } do
		assert(pose.leftLegUp.Z < -0.8 and pose.rightLegUp.Z < -0.8, "legs keep facing forward (no twist)")
	end
	-- Pesos de locomoção como no Animate do R15.
	local w = play.locomotionWeights("run", 0, 0)
	assert(w.idle == 1 and w.walk == 0)
	w = play.locomotionWeights("run", 12, 0)
	assert(w.walk > 0 and w.run > 0 and math.abs(w.walk + w.run - 1) < 1e-6)
	local w2, r2 = play.locomotionWeights("run", 27, 0)
	assert(w2.run == 1 and r2.run <= 1.35)
	assert(play.locomotionWeights("fall", 10, -30).fall == 1)
	for _, id in play.PACK_ORDER do
		assert(type(id) == "string")
	end
	assert(play.ANIMATION_PACKS.realista.walk == 2510202577, "Rthro walk from the official docs")
end
-- Painel do dono: lista os pontos de teleporte e os pacotes, abre e fecha, e marca o pacote atual.
do
	local folder = roblox.Instance.new("Folder")
	local picks = {}
	local points = { { k = "praca", n = "Praça (início)" }, { k = "poca_1", n = "Poça com reflexo 1" } }
	local packs = { { k = "realista", n = "Realista (Rthro)" }, { k = "estiloso", n = "Estiloso (Stylish)" } }
	for _, touch in { false, true } do
		local panel = play.buildAdminPanel(folder, touch, points, packs, function(kind, key)
			table.insert(picks, kind .. ":" .. key)
		end)
		assert(panel.gui.Enabled == false and panel.top.ScreenInsets == roblox.Enum.ScreenInsets.TopbarSafeInsets)
		assert(panel.buttons.tp_praca and panel.buttons.tp_poca_1 and panel.buttons.pacote_estiloso, "every point and pack has a button")
		panel.toggle()
		assert(panel.gui.Enabled)
		panel.mark("pacote", "estiloso")
		assert(panel.buttons.pacote_estiloso.edge.Thickness == 2 and panel.buttons.pacote_realista.edge.Thickness == 1)
		panel.toggle(false)
		assert(not panel.gui.Enabled)
		for _, entry in panel.buttons do
			assert(entry.button.Size.Y.Offset >= 36, "touch-friendly rows")
		end
	end
end
-- Barra neon 3D: placa com SurfaceGui brilhante, quatro armas por página, setas e munição.
do
	assert(#defs == 9 and play.BAR_PER_PAGE == 4)
	-- As áreas de toque (escala da placa) não se encostam e ficam dentro da placa.
	local boxes = {}
	for key, hit in play.BAR_HITS do
		local x0, y0 = hit[1].X.Scale, hit[1].Y.Scale
		local box = { x0, y0, x0 + hit[2].X.Scale, y0 + hit[2].Y.Scale }
		assert(box[1] >= 0 and box[3] <= 0.77 and box[2] >= 0 and box[4] <= 1, "bar box inside the plate: " .. tostring(key))
		for other, q in boxes do
			assert(not overlap(box, q), "bar boxes overlap: " .. tostring(key) .. " " .. tostring(other))
		end
		boxes[key] = box
	end
	for _, atlas in { nil, "rbxassetid://123" } do
		local bar = play.buildWeaponBar(defs, atlas)
		assert(bar.part:IsA("Part") and not bar.part.CanQuery and not bar.part.CanCollide and not bar.part.CanTouch)
		assert(bar.gui.AlwaysOnTop and bar.gui.Brightness > 1 and bar.gui.LightInfluence == 0, "neon glows with bloom")
		assert(bar.pages == 3 and #bar.slots == 4)
		assert(not bar.arrows.left.box.Visible and bar.arrows.right.box.Visible, "page 1 only points right")
		assert(bar.slots[1].id == "punhos" and bar.slots[4].id == "deagle")
		bar.setPage(3)
		assert(bar.slots[1].id == "sniper" and bar.slots[2].id == nil and not bar.slots[2].box.Visible, "the last page has one weapon")
		assert(bar.arrows.left.box.Visible and not bar.arrows.right.box.Visible)
		bar.setPage(9)
		assert(bar.page == 3, "pages clamp")
		assert(bar.pageOf("ak47") == 2 and bar.pageOf("punhos") == 1 and bar.pageOf("sniper") == 3)
		bar.setPage(bar.pageOf("ak47"))
		local ak = defs[6]
		assert(ak.id == "ak47")
		bar.set(ak, { 30, 150 }, nil)
		local on = 0
		for _, slot in bar.slots do
			if slot.glow.Visible then
				on += 1
				assert(slot.id == "ak47")
			end
		end
		assert(on == 1, "only the current weapon lights up")
		assert(bar.mag.Text == "30" and bar.reserve.Text == "/150" and bar.name.Text == "AK-47", "magazine, reserve and name")
		assert(not bar.reload.Visible)
		bar.set(ak, { 2, 150 }, 0.4)
		assert(bar.reload.Visible and bar.mag.TextColor3 ~= bar.reserve.TextColor3, "low magazine turns pink while reloading")
		bar.set(defs[1], nil, nil)
		assert(bar.mag.Text == "∞" and bar.reserve.Text == "", "fists never run out")
		-- A tela da placa segue o retângulo do layout e o texto acompanha (nunca abaixo de 9).
		bar.resize(roblox.Vector2.new(560, 92))
		assert(bar.gui.CanvasSize == roblox.Vector2.new(560, 92) and bar.name.TextSize >= 9)
		local small = bar.name.TextSize
		bar.resize(roblox.Vector2.new(840, 152))
		assert(bar.name.TextSize > small, "bigger plate, bigger text")
		if atlas then
			local offset = play.iconRect("ak47")
			for _, slot in bar.slots do
				if slot.id == "ak47" then
					assert(slot.icon.ImageRectOffset == offset)
				end
			end
		else
			assert(bar.slots[1].short.Visible and bar.slots[1].short.Text ~= "", "short names while the atlas waits")
		end
	end
	-- Inclinação: placas dos cantos giram em volta da borda de fora; a barra embaixo no centro deita para trás.
	local fx, fy, pitch, yaw = play.holoTilt(-0.8, -0.5)
	assert(fx == -1 and fy == -1 and pitch > 0 and yaw > 0, "top-left plate pivots on its outer corner and faces the center")
	fx, fy, pitch, yaw = play.holoTilt(0, 0.85)
	assert(fx == 0 and fy == 1 and pitch < 0 and math.abs(yaw) < 1e-9, "the bottom bar leans back around its bottom edge")
	-- Minimapa neon: a mesma placa 3D recebe o bloco do mapa no tamanho natural dele.
	local folder = roblox.Instance.new("Folder")
	for _, touch in { false, true } do
		local hud = play.buildHud(folder, touch)
		local part, gui = play.holoSurface("Mapa", hud.canvas)
		hud.parts.block.Parent = gui
		assert(gui.CanvasSize == hud.canvas and hud.parts.block.Size.X.Offset == hud.canvas.X and hud.parts.block.Size.Y.Offset == hud.canvas.Y)
		assert(part.Transparency == 1 and gui.Adornee == part)
	end
end
-- Implantes: projeção das marcas, boneco holograma e o terminal (lista, boneco que gira, encaixar).
do
	local CF = roblox.CFrame
	local x, y, depth = play.projectPoint(CF.lookAt(V3.new(0, 0, -10), V3.zero), 30, 1, V3.zero)
	assert(math.abs(x - 0.5) < 1e-6 and math.abs(y - 0.5) < 1e-6 and math.abs(depth - 10) < 1e-6, "the target sits in the middle")
	local top = 10 * math.tan(math.rad(15))
	x, y = play.projectPoint(CF.lookAt(V3.new(0, 0, -10), V3.zero), 30, 1, V3.new(0, top, 0))
	assert(math.abs(y) < 1e-6, "the top edge of the view is y = 0")
	x = play.projectPoint(CF.lookAt(V3.new(0, 0, -10), V3.zero), 30, 2, V3.new(-top * 2, 0, 0))
	assert(math.abs(x - 1) < 1e-6, "looking at +Z from -Z, world -X is screen right")
	local _, _, behind = play.projectPoint(CF.lookAt(V3.new(0, 0, -10), V3.zero), 30, 1, V3.new(0, 0, -20))
	assert(behind < 0, "points behind the camera are flagged")
	assert(play.abilitySpeed(true, true, false, { velocidade = 2.2, lento = 0.3 }) == 2.2, "two Sandevistans see each other at full speed")
	assert(play.abilitySpeed(false, true, false, { velocidade = 2.2, lento = 0.3 }) == 0.3)
	assert(play.abilitySpeed(true, false, true, nil) > 1, "in the episode the body runs on its own")
	local mannequin, torso = play.buildMannequin()
	assert(mannequin.PrimaryPart == torso and mannequin:FindFirstChild("Head") and mannequin:FindFirstChild("Left Leg"))
	-- Terminal com os implantes publicados pelo servidor (com os números do Sandevistan).
	local implants = {}
	for _, def in arsenal.IMPLANTS do
		local copy = table.clone(def)
		if def.id == "sandevistan" then
			copy.stats = { duracao = 4, recarga = 1.5, custo = 25, velocidade = 2.2, lento = 0.3, cadencia = 2 }
		end
		table.insert(implants, copy)
	end
	local models = roblox.Instance.new("Folder")
	for _, def in implants do
		arsenal.buildImplant(def).Parent = models
	end
	for _, atlas in { nil, "rbxassetid://123" } do
		local panel = play.buildImplantPanel(implants, atlas, models)
		assert(panel.part:IsA("Part") and panel.gui.AlwaysOnTop and panel.gui.LightInfluence == 0)
		-- Áreas de toque: dentro da placa e sem encostar umas nas outras.
		local seen, keys = {}, {}
		for _, hit in panel.hits do
			local box = { hit.position.X.Scale, hit.position.Y.Scale, hit.position.X.Scale + hit.size.X.Scale, hit.position.Y.Scale + hit.size.Y.Scale }
			assert(box[1] >= 0 and box[2] >= 0 and box[3] <= 1 and box[4] <= 1, "terminal hit inside the plate: " .. hit.key)
			for other, q in seen do
				assert(not overlap(box, q), "terminal hits overlap: " .. hit.key .. " " .. other)
			end
			seen[hit.key] = box
			keys[hit.key] = true
		end
		assert(keys.fechar and keys.acao and keys.boneco and keys["linha:sandevistan"] and keys["linha:subdermal"])
		-- Escolher e encaixar: todos os implantes funcionam; cada um mostra a sua ficha.
		panel.select("sandevistan")
		assert(panel.actionFor("sandevistan") == "encaixar" and panel.actionText.Text == "ENCAIXAR")
		assert(panel.title.Text == "SANDEVISTAN MILITAR" and panel.desc.Text:find("coluna"))
		for _, def in implants do
			local facts = play.implantFacts(def)
			assert(#facts == 3, def.id .. " has a 3-line sheet")
			for _, fact in facts do
				assert(type(fact[1]) == "string" and fact[1] ~= "" and type(fact[2]) == "string" and fact[2] ~= "")
			end
		end
		panel.select("kiroshi")
		assert(panel.actionFor("kiroshi") == "encaixar" and panel.actionText.Text == "ENCAIXAR")
		-- Braços de Gorila: uma peça em cada braço do boneco.
		panel.setState({ gorila = true }, 100, false)
		local gorilla = panel.doll:FindFirstChild("Implante_gorila")
		assert(gorilla and gorilla:FindFirstChild("Right Arm") and gorilla:FindFirstChild("Left Arm"), "gorilla arms on both arms")
		panel.setState({}, 100, false)
		panel.select("sandevistan")
		panel.setState({ sandevistan = true }, 75, false)
		assert(panel.actionFor("sandevistan") == "tirar" and panel.actionText.Text == "DESENCAIXAR")
		assert(panel.doll:FindFirstChild("Implante_sandevistan"), "the spine shows on the doll")
		assert(panel.rows.sandevistan.status.Text == "ENCAIXADO")
		panel.setState({ sandevistan = true }, 75, true)
		assert(panel.actionFor("sandevistan") == nil and panel.actionText.Text == "EM USO", "no swapping mid-effect")
		panel.setState({}, 100, false)
		assert(not panel.doll:FindFirstChild("Implante_sandevistan"), "the spine leaves the doll")
		-- Girar: de frente a coluna (costas) some; de costas ela aparece.
		panel.setState({ sandevistan = true }, 100, false)
		panel.rotate(0)
		assert(not panel.markers.coluna.tag.Visible and panel.markers.olhos.tag.Visible, "front view hides the spine marker")
		panel.rotate(math.pi)
		assert(panel.markers.coluna.tag.Visible and not panel.markers.olhos.tag.Visible, "back view shows the spine marker")
		local spine = panel.doll:FindFirstChild("Implante_sandevistan").Torso.PrimaryPart
		assert(spine.CFrame.Position.Z < 0, "the spine turns with the doll")
		local before = panel.markers.coluna.mark.Position
		panel.step(0.5, false)
		assert(panel.markers.coluna.mark.Position ~= before, "the doll keeps turning slowly")
		-- Texto acompanha o tamanho da placa e nunca fica abaixo do mínimo.
		panel.resize(roblox.Vector2.new(1130, 526))
		local small = panel.actionText.TextSize
		assert(small >= 22, "action text at least 11 px on a phone")
		panel.resize(roblox.Vector2.new(2360, 1276))
		assert(panel.actionText.TextSize > small)
	end
end
-- Monotrilho: caminho do viaduto publicado pela cidade, horário com parada e carros nas curvas.
do
	local monorail = { { 400, -340 }, { 400, 340 }, { 340, 400 }, { -340, 400 }, { -400, 340 },
		{ -400, -340 }, { -340, -400 }, { 340, -400 } }
	local track = play.trainTrack(monorail, 66)
	assert(math.abs(track.total - (4 * 680 + 4 * math.sqrt(2) * 60)) < 0.01, "ring length")
	local station = play.trackDistance(track, 400, 0)
	assert(math.abs(station - 340) < 1e-6, "the station sits 340 studs along the first side")
	local at, dir = play.trackPoint(track, station)
	assert((at - V3.new(400, 66, 0)).Magnitude < 1e-6 and (dir - V3.new(0, 0, 1)).Magnitude < 1e-6)
	local wrapped = play.trackPoint(track, station + track.total)
	assert((wrapped - at).Magnitude < 1e-6, "the ring wraps")
	-- Horário: parado com as portas abertas, sai, faz a volta e para de novo no mesmo lugar.
	local TRAIN = play.TRAIN
	local s0, v0, doors0 = play.trainSchedule(0.1, track.total)
	assert(s0 == 0 and v0 == 0 and doors0 == 0, "doors start closed")
	local _, _, doors = play.trainSchedule(4, track.total)
	assert(doors == 1, "doors open at the platform")
	local _, _, closing = play.trainSchedule(TRAIN.dwell - 0.5, track.total)
	assert(closing == 0, "doors close before leaving")
	local s1, v1 = play.trainSchedule(TRAIN.dwell + 2, track.total)
	assert(s1 > 0 and v1 > 0 and v1 < TRAIN.speed, "it accelerates out of the station")
	local ramp = TRAIN.speed / TRAIN.accel
	local cruise = (track.total - TRAIN.speed * ramp) / TRAIN.speed
	local cycle = TRAIN.dwell + 2 * ramp + cruise
	local last, lastV = play.trainSchedule(cycle - 1e-3, track.total)
	assert(math.abs(last - track.total) < 0.01 and lastV < 0.05, "one full lap, braking to a stop")
	local previous = 0
	for step = 0, 399 do -- a volta seguinte recomeça do zero
		local s = play.trainSchedule(step * cycle / 400, track.total)
		assert(s >= previous - 1e-6 or step * cycle / 400 < TRAIN.dwell + 1e-6, "the train never goes backwards")
		previous = s
	end
	-- Carro: anda olhando para a frente no reto e vira aos poucos na curva.
	local straight = play.carCFrame(track, station)
	assert((straight.LookVector - V3.new(0, 0, 1)).Magnitude < 1e-6 and math.abs(straight.Position.Y - (66 + TRAIN.floor)) < 1e-6)
	local corner = play.carCFrame(track, 680 + 5) -- na curva de 45 graus
	assert(corner.LookVector.X < -0.05 and corner.LookVector.Z > 0.5, "the car turns gradually in the corner")
	local model, parts = play.buildTrainCar(1, true, false)
	assert(#parts >= 40 and #parts <= 120)
	local doorsFound, floor, headlight = 0, nil, nil
	for _, entry in parts do
		assert(entry.part.Anchored)
		if entry.part.Name == "Porta" then
			doorsFound += 1
			assert(entry.slide and entry.slide.Magnitude > 1, "door leaves slide open")
		elseif entry.part.Name == "Piso" then
			floor = entry.part
		elseif entry.part.Name == "Farol" then
			headlight = entry.part
		end
	end
	assert(doorsFound == 8 and floor and floor.CanCollide and headlight and headlight:FindFirstChildOfClass("SpotLight"))
	assert(model:FindFirstChild("Sanfona") and not model:FindFirstChild("Lanterna"), "the head car joins the next one at the back")
	local _, tailParts = play.buildTrainCar(3, false, true)
	local lamps = 0
	for _, entry in tailParts do
		if entry.part.Name == "Lanterna" then
			lamps += 1
		end
	end
	assert(lamps == 2, "red lamps at the back of the last car")
end
-- Linha 07: paradas para embarque nos dois sentidos e retorno sem virar os carros.
do
	local track = play.trainTrack(city.monorail, city.deck, city.monorailMode)
	assert(track.total == 2340, "a shuttle does not close the route back to its first point")
	local first = play.trackPoint(track, -1)
	local last = play.trackPoint(track, 2341)
	assert(first.X == -1170 and last.X == 1170, "the route ends at the viaduct limits")
	local station = play.trackDistance(track, city.station[1], city.station[2])
	assert(station == 1295, "the middle car lines up with Estação do Dique")
	local schedule = play.shuttleSchedule(track.total, station)
	local _, parts = play.buildTrainCar(1, true, false, -1)
	local floor, slidingDoors = nil, 0
	for _, entry in parts do
		if entry.part.Name == "Piso" then
			floor = entry
		elseif entry.part.Name == "Porta" and entry.slide then
			assert(entry.offset.Position.X < 0, "only the platform side opens")
			slidingDoors += 1
		end
	end
	assert(floor and slidingDoors == 4, "there are two boarding doors on the platform side")
	local train = play.TRAIN
	local endOffset = train.pitch + floor.part.Size.Z / 2
	local openedAfter, westStop, eastStop = {}, nil, nil
	local previous, previousSpeed, direction = station, 0, 0
	for step = 0, 1800 do
		local center, speed, open = schedule(step / 10)
		assert(center >= endOffset - 1e-6 and center <= track.total - endOffset + 1e-6, "the entire train remains on the track")
		assert(math.abs(center - previous) <= train.speed / 10 + 1e-4, "no jump in position at a stop or reversal")
		assert(math.abs(speed - previousSpeed) <= train.accel / 10 + 1e-4, "the shuttle changes speed continuously")
		if speed ~= 0 then
			direction = math.sign(speed)
		end
		if open > 0 then
			assert(speed == 0 and center == station, "passengers board only at the station")
		end
		if open == 1 then
			openedAfter[direction] = true
		end
		if speed == 0 and center < endOffset + 0.5 then westStop = center end
		if speed == 0 and center > track.total - endOffset - 0.5 then eastStop = center end
		previous, previousSpeed = center, speed
	end
	assert(openedAfter[-1] and openedAfter[1] and westStop and eastStop, "both turnarounds serve the station")
	for _, center in { westStop, station, eastStop } do
		local pose = play.carCFrame(track, center)
		assert((pose.LookVector - V3.new(1, 0, 0)).Magnitude < 1e-6, "the car keeps its orientation at a turnaround")
		local floorTop = (pose * floor.offset).Position.Y + floor.part.Size.Y / 2
		assert(math.abs(floorTop - 27.9) <= 0.15, "the train floor lines up with the station platform")
	end
	local floorPose = play.carCFrame(track, station) * floor.offset
	local northEdge = floorPose:PointToWorldSpace(V3.new(-floor.part.Size.X / 2, 0, 0)).Z
	assert(northEdge > -8.55 and northEdge < -8.3, "the north platform edge is within stepping distance")
end
-- Dia e noite: 24 minutos por dia, a noite de antes à meia-noite, sol forte ao meio-dia, sem salto.
do
	assert(math.abs(play.dayClock(0) - 20.5) < 1e-9 and math.abs(play.dayClock(60) - 21.5) < 1e-9, "one game hour per real minute")
	local midnight, noon = play.dayLight(0), play.dayLight(12.5)
	assert(midnight.brightness == 2.3 and midnight.lamps == 1 and noon.brightness > 3 and noon.lamps < 0.5)
	local late = play.dayLight(23.999)
	assert(math.abs(late.brightness - midnight.brightness) < 0.01, "no jump at midnight")
	local before = play.dayLight(0)
	for step = 1, 480 do
		local now = play.dayLight(step * 0.05)
		assert(math.abs(now.brightness - before.brightness) < 0.08, "light changes slowly")
		before = now
	end
	assert(play.nightSky(2) and play.nightSky(21) and not play.nightSky(12) and not play.nightSky(7))
end

-- A iluminação próxima e as poças seguem o nível manual ou a estabilidade dos quadros no móvel.
do
	local quality = { touch = true }
	local function sample(count: number, dt: number)
		for _ = 1, count do
			play.sampleVisualQuality(quality, dt)
		end
	end
	play.setVisualQuality(quality, 0)
	assert(quality.tier == 1 and not quality.manual)
	sample(122, 1 / 60)
	play.sampleVisualQuality(quality, 0.5)
	assert(quality.fast == 0 and quality.tier == 1, "suspender o app descarta as amostras anteriores")
	sample(780, 1 / 60)
	assert(quality.tier == 2)
	sample(780, 1 / 60)
	assert(quality.tier == 2, "o perfil máximo espera quadros rápidos sustentados no celular")
	sample(780, 1 / 60)
	assert(quality.tier == 3)
	sample(96, 1 / 24)
	assert(quality.tier == 2, "o perfil automático reduz a carga quando a cadência cai")
	for _, level in {1, 4, 5, 7, 8, 10} do
		play.setVisualQuality(quality, level)
		local tier = if level <= 4 then 1 elseif level <= 7 then 2 else 3
		assert(quality.manual and quality.tier == tier and quality.value == level)
		sample(120, 1 / 24)
		assert(quality.tier == tier)
	end
	local night = play.visualDayLight(0, true, 3)
	local lightMobile = play.visualDayLight(0, true, 1)
	local day = play.visualDayLight(13, true, 3)
	assert(night.lamps == 1 and night.bloom > day.bloom and night.ambient.B > night.ambient.R)
	assert(day.lamps < 0.5 and day.brightness > night.brightness)
	assert(lightMobile.exposure > night.exposure and lightMobile.bloom < night.bloom)
	assert(play.CITY_VISUAL_BUDGETS[1].puddles == 1 and play.CITY_VISUAL_BUDGETS[3].puddles == 3)
end

-- Reflexos de fachadas e letreiros, com recorte no plano da rua e seleção pela abertura.
do
	local part = roblox.Instance.new("Part")
	part.Name, part.Anchored, part.Transparency = "Fachada", true, 0
	part.Shape, part.Material = roblox.Enum.PartType.Block, roblox.Enum.Material.Glass
	part.CFrame, part.Size, part.Color = CF.new(0, 1, -8), V3.new(3, 6, 0.5), roblox.Color3.fromRGB(80, 119, 150)
	local source = play.mirrorSource(part)
	local pose, size = play.mirrorSourcePose(source, 0)
	assert(not source.emitted and size.Y < part.Size.Y)
	assert(math.abs(pose.Position.Y + size.Y / 2 + 0.045) < 1e-5, "a fachada espelhada acaba sob a rua")
	part:SetAttribute("MareBrilhoPiso", true)
	assert(play.mirrorSource(part) == nil, "o brilho do piso não vira uma fonte")
	part:SetAttribute("MareBrilhoPiso", nil)
	part:SetAttribute("MareReflexoCor", roblox.Color3.fromRGB(250, 100, 128))
	assert(play.mirrorSource(part).emitted)
	local opening = { eye = V3.new(0, 6, 8), height = 6, puddle = { frame = CF.new(), size = V3.new(4, 0.02, 3), plane = 0 } }
	part.CFrame = CF.new(0, 6, -8)
	assert(play.mirrorMiss(opening, play.mirrorSource(part)) == 0)
	part.CFrame = CF.new(55, 6, -8)
	assert(play.mirrorMiss(opening, play.mirrorSource(part)) > 11 ^ 2)
	part:Destroy()
end

-- Animações R6 originais: os dados do jogo batem com cada keyframe dos .rbxmx do usuário.
do
	assert(roblox.deserializeModel, "Lune com leitura de rbxmx")
	local decoded = play.decodeBase64("TWFu")
	assert(buffer.len(decoded) == 3 and buffer.tostring(decoded) == "Man", "base64")
	local clips = play.r6Clips()
	local files = {
		idle = "Idle_Okarun_R6", frente = "Walk_Forward_R6", frente_direita = "Walk_ForwardRight_R6", direita = "Walk_Right_R6",
		tras_direita = "Walk_BackwardRight_R6", tras = "Walk_Backward_R6", tras_esquerda = "Walk_BackwardLeft_R6",
		esquerda = "Walk_Left_R6", frente_esquerda = "Walk_ForwardLeft_R6", corrida = "Sprint_Forward_Okarun_R6",
	}
	local count, worst = 0, 0
	for key, file in files do
		local clip = clips[key]
		assert(clip, "clip " .. key)
		-- O leitor do Lune espera o documento começando em <roblox; o Studio aceita a declaração XML.
		local xml = string.gsub(fs.readFile("animacoes_r6/" .. file .. ".rbxmx"), "^<%?xml[^>]*%?>%s*", "")
		local sequence = roblox.deserializeModel(xml)[1]
		assert(sequence.ClassName == "KeyframeSequence")
		local keyframes = sequence:GetChildren()
		table.sort(keyframes, function(a, b)
			return a.Time < b.Time
		end)
		assert(#keyframes == clip.count, key .. " keyframes")
		for index, keyframe in keyframes do
			local poses = {}
			for _, pose in keyframe:GetDescendants() do
				poses[pose.Name] = pose.CFrame
			end
			for joint, info in play.R6_JOINTS do
				local original, ours = poses[info.pose], clip.frames[index][joint]
				local tip = (original * V3.new(0, -2, 0) - ours * V3.new(0, -2, 0)).Magnitude
				worst = math.max(worst, tip)
				count += 1
			end
		end
		-- Laço: a primeira pose é a última.
		for joint = 1, 6 do
			assert((clip.frames[1][joint].Position - clip.frames[clip.count][joint].Position).Magnitude < 1e-3)
		end
	end
	assert(count == (151 + 8 * 73 + 31) * 6 and worst < 1e-3, "every keyframe of every joint matches the originals")
	-- Interpolação linear entre keyframes vizinhos (o que o Animator faz com easing Linear).
	local walk = clips.frente
	local out = {}
	play.clipPose(walk, 0, out)
	assert(out[5] == walk.frames[1][5], "phase 0 is the first keyframe")
	play.clipPose(walk, 0.5 / (walk.count - 1), out)
	local expected = walk.frames[1][5]:Lerp(walk.frames[2][5], 0.5)
	assert((out[5].Position - expected.Position).Magnitude < 1e-6)
	-- Setores de 45 graus (X+ direita, Z- frente) com histerese de 10 graus.
	assert(play.moveSector(0, -1) == 1 and play.moveSector(1, -1) == 2 and play.moveSector(1, 0) == 3 and play.moveSector(0, 1) == 5)
	assert(play.moveSector(-1, 0) == 7 and play.moveSector(-1, -1) == 8)
	local function dir(deg)
		return math.sin(math.rad(deg)), -math.cos(math.rad(deg))
	end
	local x, z = dir(28)
	assert(play.moveSector(x, z, 1) == 1 and play.moveSector(x, z, nil) == 2, "28 degrees stays forward until the hysteresis passes")
	x, z = dir(34)
	assert(play.moveSector(x, z, 1) == 2)
	-- Locomoção: parado -> andando para a frente -> correndo -> de lado mirando.
	local m = play.newMotion()
	local MOTION = play.MOTION
	local pose, step
	for _ = 1, 30 do
		pose = play.motionStep(m, { move = V3.zero, speed = 0, sprint = false }, 1 / 60)
	end
	assert(m.weights.idle > 0.99 and not m.moving, "idle when stopped")
	local steps = { 0, 0 }
	local phase0 = m.phase
	for frame = 1, 120 do
		pose, step = play.motionStep(m, { move = V3.new(0, 0, -1), speed = MOTION.walk, sprint = false }, 1 / 60)
		if step > 0 then
			steps[step] += 1
		end
		local _ = frame
	end
	assert(m.sector == 1 and m.weights.frente > 0.99 and m.weights.idle < 0.01, "walking forward after the crossfade")
	local rate = MOTION.walk / clips.frente.reference
	assert(rate <= MOTION.maxWalkRate and rate >= 2, "walk plays near its reference cadence")
	-- Já andando: em 0,25 s a fase avança velocidade / referência / duração do ciclo.
	local start = m.phase
	for _ = 1, 15 do
		play.motionStep(m, { move = V3.new(0, 0, -1), speed = MOTION.walk, sprint = false }, 1 / 60)
	end
	local expectedAdvance = 0.25 * rate / clips.frente.duration
	assert(math.abs(((m.phase - start) % 1) - expectedAdvance) < 0.01, "phase follows speed / reference")
	local _ = phase0
	assert(steps[1] >= 3 and steps[2] >= 3 and math.abs(steps[1] - steps[2]) <= 1, "both feet step every cycle")
	-- Sem escorregar: o pé de apoio anda para trás na velocidade do personagem (referência x taxa).
	assert(math.abs(clips.frente.reference * rate - MOTION.walk) < 1e-6)
	for _ = 1, 90 do
		pose = play.motionStep(m, { move = V3.new(0, 0, -1), speed = MOTION.sprint, sprint = true }, 1 / 60)
	end
	assert(m.sprinting and m.weights.corrida > 0.99, "forward sprint uses the anime run")
	assert(MOTION.sprint / clips.corrida.reference <= MOTION.maxSprintRate, "sprint near the 2x cadence")
	-- De lado (mirando): troca de setor sem pular a fase e sem corrida lateral.
	local before = m.phase
	pose = play.motionStep(m, { move = V3.new(1, 0, 0), speed = play.strafeSpeed(1, 0), sprint = true }, 1 / 60)
	assert(((m.phase - before) % 1) < 0.1, "the phase never jumps on a direction change")
	for _ = 1, 90 do
		pose = play.motionStep(m, { move = V3.new(1, 0, 0), speed = play.strafeSpeed(1, 0), sprint = true }, 1 / 60)
	end
	assert(m.sector == 3 and m.weights.direita > 0.99 and m.weights.corrida < 0.01, "no side sprint: walks right")
	assert(play.strafeSpeed(1, 0) / clips.direita.reference <= MOTION.maxWalkRate + 1e-6, "side walk not forced")
	assert(play.strafeSpeed(0, -1) > play.strafeSpeed(1, 0), "slower sideways than forward")
	assert(#pose == 6)
end
print("CyberOutlawPlay: spring, wheel, stamina, cone, R6 poses, procedural gait, puddle mirror, layout on 6 screens, HUD, paged neon weapon bar, neon minimap, implant terminal, monorail train, day and night, original R6 animations, combat layer, 2D and 3D icons, catalog animations on R6 and the owner panel passed")
