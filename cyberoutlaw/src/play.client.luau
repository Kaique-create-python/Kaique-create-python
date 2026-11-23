-- CyberOutlaw · gameplay (LocalScript in StarterPlayerScripts).
-- Shoulder camera with spring and collision, movement with sprint and stamina, smooth
-- turning and lean, weapons with a 3D wheel, crosshair only when aiming, and the
-- city's visual effects. Turns on after Jogar (attribute CyberOutlawMenuStarted).

local MEDIA = __CYBEROUTLAW_MEDIA__
local SOUNDS = if type(MEDIA) == "table" and type(MEDIA.sons) == "table" then MEDIA.sons else {}
-- 2D icon atlas (design/icones.py, drawn in Figma). Without approval, the 3D models are used.
local ATLAS = if type(MEDIA) == "table" and type(MEDIA.icones) == "number" and MEDIA.icones > 0
	then string.format("rbxassetid://%.0f", MEDIA.icones) else nil

local M = {}

-- Pure math (tested in tests/play_test.luau) ------------------------------------------------------
-- Critically damped spring, stable for any dt (implicit Euler).
local function spring(x, v, target, frequency: number, dt: number)
	local omega = frequency * 2 * math.pi
	local f = 1 + 2 * dt * omega
	local oo = omega * omega
	local hoo = dt * oo
	local hhoo = dt * hoo
	local inverse = 1 / (f + hhoo)
	return (f * x + dt * v + hhoo * target) * inverse, (v + hoo * (target - x)) * inverse
end
M.spring = spring

local function angleDelta(from: number, to: number): number
	return (to - from + math.pi) % (2 * math.pi) - math.pi
end
M.angleDelta = angleDelta

-- Wheel slot pointed to by a screen vector (y down). Slot 1 at the top, clockwise.
local function slotFromVector(x: number, y: number, count: number): number?
	if x * x + y * y < 1e-6 then
		return nil
	end
	local angle = math.deg(math.atan2(y, x)) + 90 -- 0 = top
	local step = 360 / count
	return math.floor(((angle + step / 2) % 360) / step) + 1
end
M.slotFromVector = slotFromVector

-- Screen position of the slot center (angle in degrees, 0 = right, slot 1 at the top).
local function slotAngle(index: number, count: number): number
	return -90 + (index - 1) * 360 / count
end
M.slotAngle = slotAngle

-- Stamina: drains while sprinting, refills after a short pause.
local function staminaStep(state, sprinting: boolean, dt: number)
	if sprinting then
		state.value = math.max(0, state.value - 0.13 * dt)
		state.rest = 0
		if state.value <= 0 then
			state.exhausted = true
		end
	else
		state.rest += dt
		if state.rest > 0.8 then
			state.value = math.min(1, state.value + 0.2 * dt)
		end
		if state.exhausted and state.value >= 0.3 then
			state.exhausted = false
		end
	end
	return state
end
M.staminaStep = staminaStep

-- Random direction inside a cone around `look` (radius in radians).
local function coneDirection(look: Vector3, radius: number, rng): Vector3
	if radius <= 0 then
		return look.Unit
	end
	local up = if math.abs(look.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local right = look:Cross(up).Unit
	local trueUp = right:Cross(look).Unit
	local angle = rng:NextNumber(0, 2 * math.pi)
	local spread = math.sqrt(rng:NextNumber()) * math.tan(radius)
	return (look.Unit + (right * math.cos(angle) + trueUp * math.sin(angle)) * spread).Unit
end
M.coneDirection = coneDirection

-- Joint Transform that puts Part1 at `rotation` (rotation only, in Part0 space).
local function jointTransform(c0: CFrame, c1: CFrame, rotation: CFrame): CFrame
	local r0 = c0 - c0.Position
	local r1 = c1 - c1.Position
	return r0:Inverse() * rotation * r1
end
M.jointTransform = jointTransform

-- Arm rotation in torso space: the arm (-Y) points to `direction`, the palm (-Z) toward `up`.
local function armRotation(direction: Vector3, up: Vector3): CFrame
	local y = -direction.Unit
	local z = -up
	z = (z - y * z:Dot(y))
	if z.Magnitude < 1e-3 then
		z = Vector3.zAxis - y * Vector3.zAxis:Dot(y)
	end
	z = z.Unit
	local x = y:Cross(z)
	return CFrame.fromMatrix(Vector3.zero, x, y, z)
end
M.armRotation = armRotation

-- Melee swing direction (torso space) at progress t in [0, 1].
local function swingDirection(kind: string, side: number, t: number): Vector3
	local strike = math.sin(math.min(t, 1) * math.pi)
	if kind == "lamina" then
		local a = Vector3.new(0.75 * side, 0.75, -0.35)
		local b = Vector3.new(-0.55 * side, -0.45, -0.75)
		return a:Lerp(b, math.clamp(t * 1.2, 0, 1)).Unit
	end
	local rest = Vector3.new(0.1 * side, -1, -0.15)
	local hit = Vector3.new(-0.12 * side, 0.08, -1)
	return rest:Lerp(hit, strike).Unit
end
M.swingDirection = swingDirection

-- Atlas cell: weapons at 384 x 192 in two columns, glyphs at 128 x 128 below them.
local ICON_ORDER = { "punhos", "lamina", "vespa", "enxame", "trovao", "agulha" }
local GLYPHS = { "tiro", "mira", "recarga", "arsenal" }
local function iconRect(key: string): (Vector2?, Vector2?)
	local weapon = table.find(ICON_ORDER, key)
	if weapon then
		return Vector2.new(((weapon - 1) % 2) * 384, ((weapon - 1) // 2) * 192), Vector2.new(384, 192)
	end
	local glyph = table.find(GLYPHS, key)
	if glyph then
		return Vector2.new((glyph - 1) * 128, 576), Vector2.new(128, 128)
	end
	return nil, nil
end
M.iconRect = iconRect

-- Interface (also built in the tests with real Instances) --------------------------------------------
local INK = Color3.fromRGB(8, 7, 12)
local FACE = Color3.fromRGB(16, 14, 25)
local EDGE = Color3.fromRGB(82, 52, 76)
local WHITE = Color3.fromRGB(249, 246, 255)
local MUTED = Color3.fromRGB(188, 179, 204)
local MAGENTA = Color3.fromRGB(255, 32, 133)
local CYAN = Color3.fromRGB(142, 222, 228)
local PINK_LABEL = Color3.fromRGB(255, 146, 191)
local DIM = Color3.fromRGB(44, 40, 54)
local CENTER = Vector2.new(0.5, 0.5)
local FULL = UDim2.fromScale(1, 1)
local function fonts()
	return {
		display = Font.fromEnum(Enum.Font.Michroma),
		bold = Font.fromEnum(Enum.Font.GothamBold),
		mono = Font.fromEnum(Enum.Font.RobotoMono),
	}
end

local function new(class: string, parent: Instance?, props)
	local item = Instance.new(class)
	for key, value in props or {} do
		(item :: any)[key] = value
	end
	item.Parent = parent
	return item
end

local function frame(parent, name, z, props)
	local base = { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z }
	for key, value in props or {} do
		base[key] = value
	end
	return new("Frame", parent, base)
end

local function label(parent, name, text, font, size, color, z, props)
	local base = {
		Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z, Text = text, FontFace = font,
		TextSize = size, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, Size = FULL,
	}
	for key, value in props or {} do
		base[key] = value
	end
	return new("TextLabel", parent, base)
end

local function round(parent, radius: UDim)
	new("UICorner", parent, { CornerRadius = radius })
end

local function atlasImage(parent, name: string, atlas: string, key: string, z: number, props)
	local offset, size = iconRect(key)
	local base = {
		Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z, Image = atlas,
		ImageRectOffset = offset or Vector2.zero, ImageRectSize = size or Vector2.zero, ScaleType = Enum.ScaleType.Fit,
	}
	for key2, value in props or {} do
		base[key2] = value
	end
	return new("ImageLabel", parent, base)
end

-- Chamfered panel (top-left and bottom-right corners), without images and without CanvasGroup.
local function bevel(parent, name, z, cut: number, color: Color3, transparency: number, inset: number)
	local plate = frame(parent, name, z, { Position = UDim2.fromOffset(inset, inset), Size = UDim2.new(1, -inset * 2, 1, -inset * 2) })
	local pieces = {}
	local function piece(container, partName, position, size, rotated)
		local child = frame(container, partName, z, {
			Position = position, Size = size, BackgroundTransparency = transparency, BackgroundColor3 = color,
		})
		if rotated then
			child.AnchorPoint = CENTER
			child.Rotation = 45
		end
		table.insert(pieces, child)
	end
	piece(plate, "Center", UDim2.fromOffset(0, cut), UDim2.new(1, 0, 1, -cut * 2))
	piece(plate, "Upper", UDim2.fromOffset(cut, 0), UDim2.new(1, -cut, 0, cut))
	piece(plate, "Lower", UDim2.new(0, 0, 1, -cut), UDim2.new(1, -cut, 0, cut))
	for _, corner in { "UpperLeft", "LowerRight" } do
		local upper = corner == "UpperLeft"
		local clip = frame(plate, corner, z, {
			Position = if upper then UDim2.fromOffset(0, 0) else UDim2.new(1, -cut, 1, -cut),
			Size = UDim2.fromOffset(cut, cut), ClipsDescendants = true,
		})
		piece(clip, "Diagonal", UDim2.fromOffset(cut, cut), UDim2.fromOffset(cut * math.sqrt(2), cut * math.sqrt(2)), true)
	end
	return pieces
end

local function paint(pieces, color: Color3, transparency: number?)
	for _, piece in pieces do
		piece.BackgroundColor3 = color
		if transparency then
			piece.BackgroundTransparency = transparency
		end
	end
end

local function rgb(list)
	return Color3.fromRGB(list[1], list[2], list[3])
end

-- Model inside a ViewportFrame, framed by its bounding box.
local function viewportModel(viewport: ViewportFrame, template: Model?)
	if not template then
		return nil
	end
	local model = template:Clone()
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
		end
	end
	local world = new("WorldModel", viewport, { Name = "Mundo" })
	model.Parent = world
	local box, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local offset = pivot:ToObjectSpace(box)
	local radius = math.max(size.X, size.Y, size.Z) * 0.5
	local camera = new("Camera", viewport, { Name = "Camera", FieldOfView = 30 })
	viewport.CurrentCamera = camera
	local distance = radius / math.tan(math.rad(15)) * 1.05
	camera.CFrame = CFrame.lookAt(Vector3.new(distance * 0.82, distance * 0.36, distance * 0.42), Vector3.zero)
	return { model = model, offset = offset }
end

local function poseViewport(entry, yaw: number)
	if entry then
		entry.model:PivotTo(CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(-6)) * entry.offset:Inverse())
	end
end

-- 3D weapon wheel. Returns the controls the script uses each frame.
local function buildWheel(parent: Instance, defs, templates, touch: boolean, atlas: string?)
	local f = fonts()
	local count = #defs
	local hubR = if touch then 70 else 112
	local ring = if touch then 136 else 236
	local cardW, cardH = if touch then 112 else 180, if touch then 72 else 116
	local gui = new("ScreenGui", parent, {
		Name = "CyberOutlawRoleta", ResetOnSpawn = false, DisplayOrder = 60, Enabled = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.None,
	})
	local shade = new("TextButton", gui, {
		Name = "Fundo", Size = FULL, BackgroundColor3 = Color3.fromRGB(6, 5, 10), BackgroundTransparency = 0.38,
		BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 1,
	})
	local root = frame(gui, "Roleta", 2, {
		AnchorPoint = CENTER, Position = UDim2.new(0.5, 0, 0.5, if touch then 13 else 24),
		Size = UDim2.fromOffset((ring + cardW) * 2, (ring + cardH) * 2),
	})
	local scale = new("UIScale", root, { Name = "Escala" })
	local header = label(gui, "Titulo", "ARSENAL", f.display, if touch then 10 else 14, WHITE, 3, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, if touch then 8 else 26),
		Size = UDim2.fromOffset(300, 20), TextXAlignment = Enum.TextXAlignment.Center,
	})
	local hint = label(gui, "Dica", if touch then "TOQUE NUMA ARMA PARA EQUIPAR" else "MOUSE ESCOLHE · 1–6 ATALHO · RODA TROCA",
		f.bold, if touch then 8 else 10, MUTED, 3, {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, if touch then 24 else 52),
			Size = UDim2.fromOffset(420, 14), TextXAlignment = Enum.TextXAlignment.Center,
		})
	local center = Vector2.new(ring + cardW, ring + cardH)
	local orbit = frame(root, "Orbita", 2, {
		AnchorPoint = CENTER, Position = UDim2.fromOffset(center.X, center.Y), Size = UDim2.fromOffset(ring * 2, ring * 2),
	})
	round(orbit, UDim.new(0.5, 0))
	new("UIStroke", orbit, { Color = MAGENTA, Transparency = 0.82, Thickness = 1 })

	-- Center: name, class, stats, and ammo.
	local hub = frame(root, "Centro", 6, {
		AnchorPoint = CENTER, Position = UDim2.fromOffset(center.X, center.Y), Size = UDim2.fromOffset(hubR * 2, hubR * 2),
		BackgroundTransparency = 0.06, BackgroundColor3 = Color3.fromRGB(11, 9, 18),
	})
	round(hub, UDim.new(0.5, 0))
	new("UIStroke", hub, { Color = WHITE, Transparency = 0.86, Thickness = 1 })
	local ringFrame = frame(hub, "Anel", 7, {
		AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(hubR * 2 - 14, hubR * 2 - 14),
	})
	round(ringFrame, UDim.new(0.5, 0))
	local ringStroke = new("UIStroke", ringFrame, { Color = MAGENTA, Thickness = 2 })
	local ticks = frame(root, "Marcas", 6, {
		AnchorPoint = CENTER, Position = UDim2.fromOffset(center.X, center.Y), Size = UDim2.fromOffset(0, 0),
	})
	for k = 0, 59 do
		local long = k % 5 == 0
		local a = math.rad(k * 6)
		local r = hubR + (if long then 8 else 6)
		frame(ticks, "Marca", 6, {
			AnchorPoint = CENTER, Position = UDim2.fromOffset(math.cos(a) * r, math.sin(a) * r),
			Size = UDim2.fromOffset(if long then 7 else 4, if long then 1.5 else 1), Rotation = k * 6,
			BackgroundTransparency = if long then 0.55 else 0.82, BackgroundColor3 = WHITE,
		})
	end
	local s = if touch then 0.62 else 1
	local class = label(hub, "Classe", "", f.bold, math.floor(8 * s + 0.5), MAGENTA, 8, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, -60 * s), Size = UDim2.fromOffset(hubR * 1.6, 12 * s),
		TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true,
	})
	local title = label(hub, "Nome", "", f.display, math.floor(15 * s + 0.5), WHITE, 8, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, -44 * s), Size = UDim2.fromOffset(hubR * 1.7, 20 * s),
		TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true,
	})
	local statNames = { "DANO", "CADÊNCIA", "ALCANCE", "CONTROLE" }
	local segments = {}
	for row, statName in statNames do
		local y = -12 * s + (row - 1) * 13 * s
		label(hub, "Rotulo" .. row, statName, f.bold, math.floor(8 * s + 0.5), MUTED, 8, {
			Position = UDim2.new(0.5, -62 * s, 0.5, y - 5 * s), Size = UDim2.fromOffset(58 * s, 10 * s),
		})
		segments[row] = {}
		for seg = 1, 10 do
			segments[row][seg] = frame(hub, "Segmento", 8, {
				Position = UDim2.new(0.5, (2 + (seg - 1) * 6.4) * s, 0.5, y - 2.5 * s), Size = UDim2.fromOffset(5 * s, 4.5 * s),
				BackgroundTransparency = 0, BackgroundColor3 = DIM,
			})
		end
	end
	local ammo = label(hub, "Municao", "", f.mono, math.floor(22 * s + 0.5), WHITE, 8, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 42 * s), Size = UDim2.fromOffset(hubR * 1.6, 26 * s),
		TextXAlignment = Enum.TextXAlignment.Center, RichText = true,
	})
	label(hub, "Instrucao", if touch then "TOQUE PARA EQUIPAR" else "SOLTE  Q  PARA EQUIPAR", f.bold, math.floor(7.5 * s + 0.5), MUTED, 8, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16 * s), Size = UDim2.fromOffset(hubR * 1.5, 10 * s),
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- Pointer: line from the center to the selected card and a diamond on the ring.
	local pointer = frame(root, "Ponteiro", 5, {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(center.X, center.Y), Size = UDim2.fromOffset(0, 2),
		BackgroundTransparency = 0.3, BackgroundColor3 = MAGENTA,
	})
	local tip = frame(root, "Ponta", 7, {
		AnchorPoint = CENTER, Size = UDim2.fromOffset(if touch then 8 else 11, if touch then 8 else 11), Rotation = 45,
		BackgroundTransparency = 0, BackgroundColor3 = MAGENTA,
	})

	local cards = {}
	for index, def in defs do
		local a = math.rad(slotAngle(index, count))
		local accent = rgb(def.accent)
		local card = new("TextButton", root, {
			Name = "Carta" .. index, AnchorPoint = CENTER, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Position = UDim2.fromOffset(center.X + math.cos(a) * ring, center.Y + math.sin(a) * ring),
			Size = UDim2.fromOffset(cardW, cardH), ZIndex = 10,
		})
		local pop = new("UIScale", card, { Name = "Destaque" })
		local glow = frame(card, "Brilho", 10, {
			AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 14, 1, 14),
			BackgroundColor3 = accent, BackgroundTransparency = 1,
		})
		round(glow, UDim.new(0, 10))
		local edge = bevel(card, "Borda", 11, if touch then 9 else 12, WHITE, 0.86, 0)
		bevel(card, "Face", 12, if touch then 8 else 11, FACE, 0.05, if touch then 1 else 1.5)
		frame(card, "Faixa", 13, {
			Position = UDim2.fromOffset(if touch then 9 else 12, 0), Size = UDim2.new(0.34, 0, 0, 2),
			BackgroundTransparency = 0, BackgroundColor3 = accent,
		})
		local model, image, halo
		if atlas then
			-- 2D icon from the Figma design, with a halo in the weapon's color behind it.
			halo = atlasImage(card, "IconeBrilho", atlas, def.id, 13, {
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, cardH * 0.1),
				Size = UDim2.new(0.86, 0, 0.6, 0), ImageColor3 = accent, ImageTransparency = 1,
			})
			image = atlasImage(card, "Icone", atlas, def.id, 14, {
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, cardH * 0.12),
				Size = UDim2.new(0.78, 0, 0.56, 0),
			})
		else
			local viewport = new("ViewportFrame", card, {
				Name = "Icone", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, cardH * 0.06),
				Size = UDim2.new(0.86, 0, 0.66, 0), BackgroundTransparency = 1, ZIndex = 13,
				Ambient = Color3.fromRGB(150, 140, 176), LightColor = Color3.fromRGB(255, 236, 250), LightDirection = Vector3.new(-0.6, -1, -0.4),
			})
			model = viewportModel(viewport, templates and templates[def.id])
		end
		if not touch then
			local key = frame(card, "Tecla", 14, {
				Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(15, 15), BackgroundTransparency = 0, BackgroundColor3 = INK,
			})
			new("UIStroke", key, { Color = WHITE, Transparency = 0.78, Thickness = 1 })
			label(key, "Numero", tostring(index), f.bold, 9, WHITE, 15, { TextXAlignment = Enum.TextXAlignment.Center })
		end
		local name = label(card, "Nome", string.upper(def.name), f.display, if touch then 7 else 10, Color3.fromRGB(217, 210, 230), 14, {
			Position = UDim2.new(0, if touch then 8 else 12, 1, if touch then -17 else -24), Size = UDim2.new(1, if touch then -16 else -24, 0, if touch then 12 else 16),
			TextScaled = true,
		})
		local count2 = label(card, "Municao", if def.kind == "gun" then "" else "∞", f.mono, if touch then 8 else 11, accent, 14, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, if touch then -8 else -12, 0, if touch then 6 else 9),
			Size = UDim2.fromOffset(70, 14), TextXAlignment = Enum.TextXAlignment.Right,
		})
		cards[index] = {
			card = card, pop = pop, glow = glow, edge = edge, name = name, ammo = count2, model = model, accent = accent,
			def = def, angle = a, image = image, halo = halo,
		}
	end

	local controls = { gui = gui, shade = shade, root = root, scale = scale, cards = cards, selected = 1, spin = 0 }
	function controls.select(index: number, ammoTable)
		controls.selected = index
		local def = defs[index]
		local accent = rgb(def.accent)
		for i, entry in cards do
			local on = i == index
			entry.pop.Scale = if on then 1.12 else 1
			entry.glow.BackgroundTransparency = if on then 0.72 else 1
			paint(entry.edge, if on then entry.accent else WHITE, if on then 0 else 0.86)
			entry.name.TextColor3 = if on then WHITE else Color3.fromRGB(217, 210, 230)
			if entry.image then
				entry.image.ImageTransparency = if on then 0 else 0.18
				entry.halo.ImageTransparency = if on then 0.55 else 1
			end
			local pair = ammoTable and ammoTable[entry.def.id]
			if entry.def.kind == "gun" and pair then
				entry.ammo.Text = string.format("%d/%d", pair[1], pair[2])
			end
		end
		class.Text = def.class or ""
		class.TextColor3 = accent
		title.Text = string.upper(def.name)
		ringStroke.Color = accent
		for row = 1, 4 do
			local value = def.stats and def.stats[row] or 0
			for seg = 1, 10 do
				segments[row][seg].BackgroundColor3 = if seg <= math.floor(value * 10 + 0.5) then accent else DIM
			end
		end
		local pair = ammoTable and ammoTable[def.id]
		ammo.Text = if def.kind == "gun" and pair then string.format('%d <font size="%d" color="#bcb3cc"> |  %d</font>', pair[1], math.floor(13 * s + 0.5), pair[2])
			else '<font color="#bcb3cc">CORPO A CORPO</font>'
		local a = cards[index].angle
		local from = hubR + 13
		local to = ring - (if touch then cardH * 0.6 else cardH * 0.62)
		pointer.Position = UDim2.fromOffset(center.X + math.cos(a) * from, center.Y + math.sin(a) * from)
		pointer.Size = UDim2.fromOffset(math.max(0, to - from), 2)
		pointer.Rotation = math.deg(a)
		pointer.BackgroundColor3 = accent
		tip.Position = UDim2.fromOffset(center.X + math.cos(a) * (hubR + 10), center.Y + math.sin(a) * (hubR + 10))
		tip.BackgroundColor3 = accent
	end
	function controls.animate(dt: number, opening: number)
		controls.spin += dt
		for i, entry in cards do
			local speed = if i == controls.selected then 1.6 else 0.35
			poseViewport(entry.model, controls.spin * speed + i)
			local a = entry.angle
			local radius = ring * (0.55 + 0.45 * opening)
			entry.card.Position = UDim2.fromOffset(center.X + math.cos(a) * radius, center.Y + math.sin(a) * radius)
		end
		ticks.Rotation = controls.spin * 6
		shade.BackgroundTransparency = 1 - 0.62 * opening
		header.TextTransparency = 1 - opening
		hint.TextTransparency = 1 - opening
	end
	controls.center = center
	controls.header = header
	return controls
end
M.buildWheel = buildWheel

-- Equipped weapon card (bottom-right on PC; under the health panel on mobile).
local function buildWeaponCard(parent: Instance, touch: boolean, atlas: string?)
	local f = fonts()
	local w, h = if touch then 194 else 268, if touch then 50 else 74
	local gui = new("ScreenGui", parent, {
		Name = "CyberOutlawArmaAtual", ResetOnSpawn = false, DisplayOrder = 30, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ClipToDeviceSafeArea = true, SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
	})
	local panel = new("TextButton", gui, {
		Name = "Cartao", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
		AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(1, 1),
		Position = if touch then UDim2.fromOffset(14, 66) else UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(w, h), ZIndex = 1,
	})
	bevel(panel, "Borda", 1, if touch then 7 else 9, EDGE, 0, 0)
	bevel(panel, "Face", 2, if touch then 6 else 8, FACE, 0.06, 1)
	local accentBar = frame(panel, "Destaque", 3, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(56, 1.5),
		BackgroundTransparency = 0, BackgroundColor3 = MAGENTA,
	})
	frame(panel, "Base", 3, {
		Position = UDim2.new(0, 0, 1, -1.5), Size = UDim2.fromOffset(30, 1.5), BackgroundTransparency = 0, BackgroundColor3 = CYAN,
	})
	local iconW = h * 1.28
	local viewport = if atlas then nil else new("ViewportFrame", panel, {
		Name = "Icone", Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(iconW, h - 8), BackgroundTransparency = 1, ZIndex = 3,
		Ambient = Color3.fromRGB(150, 140, 176), LightColor = Color3.fromRGB(255, 236, 250), LightDirection = Vector3.new(-0.6, -1, -0.4),
	})
	local icon2d = if atlas then atlasImage(panel, "Icone", atlas, "punhos", 3, {
		Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(iconW, h - 8),
	}) else nil
	local name = label(panel, "Nome", "", f.display, if touch then 8 else 10, PINK_LABEL, 4, {
		Position = UDim2.fromOffset(iconW + 16, if touch then 4 else 8), Size = UDim2.new(1, -(iconW + 28), 0, if touch then 12 else 14),
		TextScaled = true,
	})
	local count = label(panel, "Pente", "", f.mono, if touch then 18 else 26, WHITE, 4, {
		Position = UDim2.fromOffset(iconW + 16, if touch then 15 else 24), Size = UDim2.new(1, -(iconW + 28), 0, if touch then 20 else 28),
		RichText = true,
	})
	local pipsHolder = frame(panel, "Balas", 4, {
		Position = UDim2.new(0, iconW + 16, 1, if touch then -10 else -13), Size = UDim2.new(1, -(iconW + 30), 0, 5),
	})
	local reloadBar = frame(pipsHolder, "Recarga", 6, { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, BackgroundColor3 = WHITE, Visible = false })
	local status = label(panel, "Estado", "", f.bold, 8, WHITE, 5, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, if touch then 4 else 8), Size = UDim2.fromOffset(110, 12),
		TextXAlignment = Enum.TextXAlignment.Right, Visible = false,
	})
	local controls = { gui = gui, panel = panel, viewport = viewport, model = nil, pips = {}, current = nil }
	function controls.show(def, template, pair, reloadProgress: number?)
		if controls.current ~= def.id then
			controls.current = def.id
			if icon2d then
				local offset, size = iconRect(def.id)
				icon2d.ImageRectOffset = offset or Vector2.zero
				icon2d.ImageRectSize = size or Vector2.zero
			elseif viewport then
				for _, child in viewport:GetChildren() do
					child:Destroy()
				end
				controls.model = viewportModel(viewport, template)
				poseViewport(controls.model, math.rad(-35))
			end
			for _, pip in controls.pips do
				pip:Destroy()
			end
			table.clear(controls.pips)
			if def.kind == "gun" then
				local size = def.mag
				for k = 1, size do
					controls.pips[k] = frame(pipsHolder, "Bala", 5, {
						Position = UDim2.new((k - 1) / size, 0, 0, 0), Size = UDim2.new(1 / size, -1.5, 1, 0),
						BackgroundTransparency = 0, BackgroundColor3 = DIM,
					})
				end
			end
		end
		local accent = rgb(def.accent)
		accentBar.BackgroundColor3 = accent
		name.Text = string.upper(def.name)
		if def.kind == "gun" and pair then
			count.Text = string.format('%d<font size="%d" color="#bcb3cc"> / %d</font>', pair[1], if touch then 9 else 12, pair[2])
			for k, pip in controls.pips do
				pip.BackgroundColor3 = if k <= pair[1] then accent else DIM
			end
		else
			count.Text = '<font size="12" color="#bcb3cc">CORPO A CORPO</font>'
		end
		reloadBar.Visible = reloadProgress ~= nil
		status.Visible = reloadProgress ~= nil
		status.Text = "RECARREGANDO"
		if reloadProgress then
			reloadBar.Size = UDim2.fromScale(math.clamp(reloadProgress, 0, 1), 1)
		end
	end
	return controls
end
M.buildWeaponCard = buildWeaponCard

-- Round touch button with a drawn icon (no image).
local function touchButton(parent, name: string, caption: string, icon: string, center: Vector2, radius: number, color: Color3, atlas: string?)
	local f = fonts()
	local button = new("TextButton", parent, {
		Name = name, AnchorPoint = CENTER, Position = UDim2.new(1, center.X, 1, center.Y), Size = UDim2.fromOffset(radius * 2, radius * 2),
		BackgroundColor3 = INK, BackgroundTransparency = 0.22, Text = "", AutoButtonColor = false, ZIndex = 5,
	})
	round(button, UDim.new(0.5, 0))
	local ring = new("UIStroke", button, { Color = color, Thickness = if radius > 30 then 2 else 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	local glyph = if icon == "R" then "recarga" else icon
	if atlas and iconRect(glyph) then
		atlasImage(button, "Glifo", atlas, glyph, 6, {
			AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(radius * 1.1, radius * 1.1),
		})
	elseif icon == "tiro" then
		local circle = frame(button, "Alvo", 6, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(radius * 0.72, radius * 0.72) })
		round(circle, UDim.new(0.5, 0))
		new("UIStroke", circle, { Color = WHITE, Thickness = 2 })
		local dot = frame(button, "Ponto", 6, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundTransparency = 0, BackgroundColor3 = WHITE })
		round(dot, UDim.new(0.5, 0))
	elseif icon == "mira" then
		local circle = frame(button, "Alvo", 6, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(radius * 0.56, radius * 0.56) })
		round(circle, UDim.new(0.5, 0))
		new("UIStroke", circle, { Color = WHITE, Thickness = 1.5 })
		frame(button, "Horizontal", 6, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(radius * 0.96, 1.5), BackgroundTransparency = 0, BackgroundColor3 = WHITE })
		frame(button, "Vertical", 6, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1.5, radius * 0.96), BackgroundTransparency = 0, BackgroundColor3 = WHITE })
	else
		label(button, "Letra", icon, f.display, math.floor(radius * 0.6), WHITE, 6, { TextXAlignment = Enum.TextXAlignment.Center })
	end
	if caption ~= "" then
		label(button, "Legenda", caption, f.bold, 8, WHITE, 6, {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.fromOffset(80, 10),
			TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6,
		})
	end
	return button, ring
end
M.touchButton = touchButton

-- Runtime --------------------------------------------------------------------------------------
local function start()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GuiService = game:GetService("GuiService")
	local HttpService = game:GetService("HttpService")
	local SoundService = game:GetService("SoundService")
	local StarterGui = game:GetService("StarterGui")
	local Workspace = game:GetService("Workspace")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local quality = 10
	pcall(function()
		local saved = UserSettings():GetService("UserGameSettings").SavedQualityLevel
		quality = if saved == Enum.SavedQualitySetting.Automatic then 7 else saved.Value
	end)

	if not player:GetAttribute("CyberOutlawMenuStarted") then
		player:GetAttributeChangedSignal("CyberOutlawMenuStarted"):Wait()
	end
	local arsenal = ReplicatedStorage:WaitForChild("CyberOutlawArsenal", 30)
	local defs, byId, templates = {}, {}, {}
	local action, effectEvent, aimEvent
	local safeZone
	if arsenal then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(arsenal:GetAttribute("Armas"))
		end)
		if ok and type(decoded) == "table" then
			defs = decoded
			table.sort(defs, function(a, b)
				return a.order < b.order
			end)
		end
		for _, def in defs do
			byId[def.id] = def
		end
		local models = arsenal:WaitForChild("Modelos", 10)
		for _, def in defs do
			templates[def.id] = models and models:FindFirstChild(def.id)
		end
		action = arsenal:WaitForChild("Acao", 10)
		effectEvent = arsenal:WaitForChild("Efeito", 10)
		aimEvent = arsenal:WaitForChild("Mira", 10)
		pcall(function()
			safeZone = HttpService:JSONDecode(arsenal:GetAttribute("ZonaSegura"))
		end)
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	local camera = Workspace.CurrentCamera
	local effects = Instance.new("Folder")
	effects.Name = "CyberOutlawEfeitos"
	effects.Parent = camera
	local rng = Random.new()

	local function sound(key: string, parent: Instance?, volume: number?)
		local id = SOUNDS[key]
		if type(id) ~= "number" or id <= 0 then
			return
		end
		local item = Instance.new("Sound")
		item.SoundId = string.format("rbxassetid://%.0f", id)
		item.Volume = volume or 0.6
		item.RollOffMaxDistance = 260
		if parent then
			item.Parent = parent
			item:Play()
			item.Ended:Once(function()
				item:Destroy()
			end)
			task.delay(4, function()
				if item.Parent then
					item:Destroy()
				end
			end)
		else
			SoundService:PlayLocalSound(item)
			item:Destroy()
		end
	end

	-- Character state ---------------------------------------------------------------------------
	local character, humanoid, root, torso, head
	local align, alignAttachment
	local joints = {}
	local facingYaw = 0
	local controls
	pcall(function()
		local module = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10))
		controls = module:GetControls()
	end)

	local function bindCharacter(model: Model)
		character = model
		humanoid = model:WaitForChild("Humanoid", 10)
		root = model:WaitForChild("HumanoidRootPart", 10)
		torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
		head = model:FindFirstChild("Head")
		table.clear(joints)
		if root then
			joints.root = root:FindFirstChild("RootJoint")
			joints.rootC0 = joints.root and joints.root.C0
			facingYaw = math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z)
			alignAttachment = Instance.new("Attachment")
			alignAttachment.Name = "CyberOutlawFacing"
			alignAttachment.Parent = root
			align = Instance.new("AlignOrientation")
			align.Name = "CyberOutlawFacing"
			align.Mode = Enum.OrientationAlignmentMode.OneAttachment
			align.Attachment0 = alignAttachment
			align.MaxTorque = 1e7
			align.MaxAngularVelocity = 30
			align.Responsiveness = 16
			align.RigidityEnabled = false
			align.CFrame = CFrame.Angles(0, facingYaw, 0)
			align.Parent = root
		end
		if torso then
			joints.neck = torso:FindFirstChild("Neck")
		end
		if humanoid then
			humanoid.AutoRotate = false
		end
	end

	-- Camera --------------------------------------------------------------------------------------
	local cam = {
		yaw = 0, pitch = math.rad(-10), focus = nil, focusVel = Vector3.zero, height = 0, heightVel = 0,
		distance = 11.5, distanceVel = 0, shoulder = 1.35, shoulderVel = 0, fov = 70, fovVel = 0,
		lastInput = 0, trauma = 0, kick = 0, kickYaw = 0, side = 1, deathSpin = 0,
	}
	local touchCamera: { [InputObject]: Vector3 } = {}
	local stick = Vector2.zero
	local sensitivity = 1
	pcall(function()
		sensitivity = UserSettings():GetService("UserGameSettings").MouseSensitivity
	end)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	local filterAt = 0
	local function refreshFilter()
		local list = { effects }
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(list, other.Character)
			end
		end
		rayParams.FilterDescendantsInstances = list
	end

	-- Movement and combat state ----------------------------------------------------------------------
	local stamina = { value = 1, rest = 0, exhausted = false }
	local sprintHeld, sprintToggle, sprinting = false, false, false
	local pushTime = 0
	local speed = 16
	local lean, leanVel, forwardLean = 0, 0, 0
	local current = "punhos"
	local aiming, aimToggle = false, false
	local triggerHeld = false
	local nextShot, nextMelee = 0, 0
	local hipFireUntil = 0
	local bloom = 0
	local meleeSide = 1
	local wheelOpen = false
	local wheelOpenAmount = 0
	local wheelSelection = 1
	local ammoTable = {}
	local lastPitchSent, pitchSentAt = 999, 0
	local poses = {} -- [character] = { swingStart, swingKind, swingSide, firedAt }
	local dead = false

	local function def(): any
		return byId[current] or byId.punhos or { id = "punhos", kind = "melee", name = "Punhos", accent = { 255, 166, 94 }, rate = 2.6 }
	end

	local function readAmmo()
		local raw = player:GetAttribute("CyberOutlawMunicao")
		if type(raw) == "string" then
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(raw)
			end)
			if ok and type(decoded) == "table" then
				ammoTable = decoded
			end
		end
	end
	player:GetAttributeChangedSignal("CyberOutlawMunicao"):Connect(readAmmo)
	readAmmo()

	local function inSafeZone(position: Vector3): boolean
		if type(safeZone) ~= "table" then
			return false
		end
		local dx, dz = position.X - safeZone[1], position.Z - safeZone[2]
		return dx * dx + dz * dz < safeZone[3] * safeZone[3]
	end

	-- Interface ----------------------------------------------------------------------------------
	local wheel = if #defs > 0 then buildWheel(playerGui, defs, templates, touch, ATLAS) else nil
	local card = if #defs > 0 then buildWeaponCard(playerGui, touch, ATLAS) else nil
	local blur = Instance.new("BlurEffect")
	blur.Name = "CyberOutlawRoletaBlur"
	blur.Size = 0
	blur.Parent = camera
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "CyberOutlawRoletaCor"
	grade.Parent = camera
	local depth = Instance.new("DepthOfFieldEffect")
	depth.Name = "CyberOutlawMiraFoco"
	depth.Enabled = false
	depth.FarIntensity = 0.28
	depth.NearIntensity = 0
	depth.InFocusRadius = 40
	depth.Parent = camera

	local combatGui = Instance.new("ScreenGui")
	combatGui.Name = "CyberOutlawCombate"
	combatGui.ResetOnSpawn = false
	combatGui.DisplayOrder = 32
	combatGui.IgnoreGuiInset = true
	combatGui.ScreenInsets = Enum.ScreenInsets.None
	combatGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	combatGui.Parent = playerGui
	local hitmarker = frame(combatGui, "Acerto", 5, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(28, 28), Visible = false })
	local hitLines = {}
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		table.insert(hitLines, frame(hitmarker, "Traço", 5, {
			AnchorPoint = CENTER, Position = UDim2.new(0.5, corner[1] * 9, 0.5, corner[2] * 9), Size = UDim2.fromOffset(9, 2),
			Rotation = if corner[1] * corner[2] > 0 then 45 else -45, BackgroundTransparency = 0, BackgroundColor3 = WHITE,
		}))
	end
	local hitUntil = 0
	local vignette = frame(combatGui, "Vinheta", 1, { Size = FULL })
	local vignettePieces = {}
	for _, side in { { 0, 0, 1, 0.16, 90 }, { 0, 0.84, 1, 0.16, -90 }, { 0, 0, 0.12, 1, 0 }, { 0.88, 0, 0.12, 1, 180 } } do
		local piece = frame(vignette, "Borda", 1, {
			Position = UDim2.fromScale(side[1], side[2]), Size = UDim2.fromScale(side[3], side[4]), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(0, 0, 0),
		})
		new("UIGradient", piece, {
			Rotation = side[5], Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		})
		table.insert(vignettePieces, piece)
	end
	local damageFlash = 0
	local safeChip = label(combatGui, "ZonaSegura", "ZONA SEGURA · ARMAS TRAVADAS", Font.fromEnum(Enum.Font.GothamBold), 10, CYAN, 4, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, if touch then 70 else 104), Size = UDim2.fromOffset(260, 14),
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5, Visible = false,
	})
	local deathScreen = frame(combatGui, "SinalPerdido", 20, { Size = FULL, BackgroundColor3 = Color3.fromRGB(10, 0, 6), BackgroundTransparency = 1, Visible = false })
	local deathTitle = label(deathScreen, "Titulo", "SINAL PERDIDO", Font.fromEnum(Enum.Font.Michroma), if touch then 26 else 40, Color3.fromRGB(255, 70, 110), 21, {
		AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(700, 60), TextXAlignment = Enum.TextXAlignment.Center,
	})
	local deathHint = label(deathScreen, "Dica", "RECONECTANDO AO CORPO…", Font.fromEnum(Enum.Font.GothamBold), 11, MUTED, 21, {
		AnchorPoint = CENTER, Position = UDim2.new(0.5, 0, 0.45, 40), Size = UDim2.fromOffset(400, 16), TextXAlignment = Enum.TextXAlignment.Center,
	})
	local deathGrade = Instance.new("ColorCorrectionEffect")
	deathGrade.Name = "CyberOutlawSinalPerdido"
	deathGrade.Enabled = false
	deathGrade.Saturation = -0.85
	deathGrade.TintColor = Color3.fromRGB(255, 200, 210)
	deathGrade.Parent = camera

	local touchGui, fireButton, aimButton, reloadButton, aimRing
	if touch then
		touchGui = Instance.new("ScreenGui")
		touchGui.Name = "CyberOutlawToque"
		touchGui.ResetOnSpawn = false
		touchGui.DisplayOrder = 33
		touchGui.ScreenInsets = Enum.ScreenInsets.None
		touchGui.IgnoreGuiInset = true
		touchGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		touchGui.Parent = playerGui
		local small = math.min(camera.ViewportSize.X, camera.ViewportSize.Y) <= 500
		local k = if small then 1 else 1.55
		fireButton = touchButton(touchGui, "Atirar", "ATIRAR", "tiro", Vector2.new(-165 * k, -82 * k), 36 * k, MAGENTA, ATLAS)
		aimButton, aimRing = touchButton(touchGui, "Mirar", "MIRAR", "mira", Vector2.new(-76 * k, -166 * k), 25 * k, CYAN, ATLAS)
		reloadButton = touchButton(touchGui, "Recarregar", "", "R", Vector2.new(-154 * k, -164 * k), 19 * k, Color3.fromRGB(170, 166, 184), ATLAS)
	end

	local function aimGui()
		return playerGui:FindFirstChild("CyberOutlawAim")
	end

	-- Local effects ----------------------------------------------------------------------------------
	local function fadePart(part: BasePart, life: number, grow: Vector3?)
		local start = os.clock()
		local base = part.Transparency
		local size = part.Size
		local connection
		connection = RunService.Heartbeat:Connect(function()
			local t = (os.clock() - start) / life
			if t >= 1 or not part.Parent then
				connection:Disconnect()
				part:Destroy()
				return
			end
			part.Transparency = base + (1 - base) * t
			if grow then
				part.Size = size + grow * t
			end
		end)
	end

	local function spark(position: Vector3, color: Color3, count: number, normal: Vector3?)
		for _ = 1, count do
			local shard = Instance.new("Part")
			shard.Anchored = true
			shard.CanCollide = false
			shard.CanQuery = false
			shard.CanTouch = false
			shard.CastShadow = false
			shard.Material = Enum.Material.Neon
			shard.Color = color
			shard.Size = Vector3.new(0.08, 0.08, rng:NextNumber(0.2, 0.45))
			local direction = ((normal or Vector3.yAxis) + Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.3, 0.9), rng:NextNumber(-0.8, 0.8))).Unit
			shard.CFrame = CFrame.lookAt(position, position + direction)
			shard.Parent = effects
			local velocity = direction * rng:NextNumber(14, 26)
			local born = os.clock()
			local connection
			connection = RunService.Heartbeat:Connect(function(dt)
				local age = os.clock() - born
				if age > 0.28 or not shard.Parent then
					connection:Disconnect()
					shard:Destroy()
					return
				end
				velocity += Vector3.new(0, -60 * dt, 0)
				local p = shard.Position + velocity * dt
				shard.CFrame = CFrame.lookAt(p, p + velocity)
				shard.Transparency = age / 0.28
			end)
		end
		local flash = Instance.new("Part")
		flash.Anchored = true
		flash.CanCollide = false
		flash.CanQuery = false
		flash.CanTouch = false
		flash.Transparency = 1
		flash.Size = Vector3.new(0.2, 0.2, 0.2)
		flash.CFrame = CFrame.new(position)
		flash.Parent = effects
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 2.4
		light.Range = 10
		light.Shadows = false
		light.Parent = flash
		task.delay(0.07, function()
			flash:Destroy()
		end)
	end

	local function tracer(from: Vector3, to: Vector3, color: Color3)
		local length = (to - from).Magnitude
		if length < 0.5 then
			return
		end
		local beam = Instance.new("Part")
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Material = Enum.Material.Neon
		beam.Color = color:Lerp(Color3.new(1, 1, 1), 0.55)
		beam.Transparency = 0.25
		beam.Size = Vector3.new(0.07, 0.07, length)
		beam.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
		beam.Parent = effects
		fadePart(beam, 0.09)
	end

	local function muzzleOf(model: Model?): Vector3?
		local weapon = model and model:FindFirstChild("CyberOutlawArma")
		local attachment = weapon and weapon.PrimaryPart and weapon.PrimaryPart:FindFirstChild("Cano")
		return if attachment then attachment.WorldPosition else nil
	end

	local function muzzleFlash(position: Vector3, color: Color3, look: Vector3)
		for _, angle in { 0, 90 } do
			local blade = Instance.new("Part")
			blade.Anchored = true
			blade.CanCollide = false
			blade.CanQuery = false
			blade.CanTouch = false
			blade.CastShadow = false
			blade.Material = Enum.Material.Neon
			blade.Color = Color3.fromRGB(255, 226, 170):Lerp(color, 0.3)
			blade.Size = Vector3.new(0.08, 0.5, 0.9)
			blade.CFrame = CFrame.lookAt(position + look * 0.4, position + look) * CFrame.Angles(0, 0, math.rad(angle + rng:NextNumber(-20, 20)))
			blade.Parent = effects
			fadePart(blade, 0.05, Vector3.new(0, 0.3, 0.4))
		end
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.new(position)
		holder.Parent = effects
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Brightness = 3
		light.Range = 16
		light.Shadows = false
		light.Parent = holder
		task.delay(0.05, function()
			holder:Destroy()
		end)
	end

	local function showHit()
		hitUntil = os.clock() + 0.14
		hitmarker.Visible = true
	end

	-- Weapons ------------------------------------------------------------------------------------
	local function equip(id: string)
		if not byId[id] or (dead) then
			return
		end
		if id ~= current then
			current = id
			sound("arma_troca")
			if action then
				action:FireServer("equipar", id)
			end
		end
		if byId[id].kind ~= "gun" then
			aimToggle = false
		end
	end

	local function cycle(step: number)
		local index = (byId[current] and byId[current].order) or 1
		local nextIndex = (index - 1 + step) % #defs + 1
		equip(defs[nextIndex].id)
	end

	local function reload()
		local weapon = def()
		local pair = ammoTable[weapon.id]
		if weapon.kind == "gun" and pair and pair[1] < weapon.mag and pair[2] > 0 and action then
			action:FireServer("recarregar")
			sound("arma_recarga", nil, 0.5)
		end
	end

	local function melee()
		local weapon = def()
		local now = os.clock()
		if now < nextMelee or not character then
			return
		end
		nextMelee = now + 1 / weapon.rate
		meleeSide = -meleeSide
		poses[character] = poses[character] or {}
		poses[character].swingStart = now
		poses[character].swingKind = weapon.id
		poses[character].swingSide = meleeSide
		sound(if weapon.id == "lamina" then "arma_lamina" else "arma_soco", nil, 0.55)
		cam.trauma = math.min(1, cam.trauma + 0.08)
		if action then
			action:FireServer("golpe", meleeSide)
		end
	end

	local function shoot()
		local weapon = def()
		if weapon.kind ~= "gun" then
			melee()
			return
		end
		if not character or not head or dead then
			return
		end
		local now = os.clock()
		if now < nextShot then
			return
		end
		if root and inSafeZone(root.Position) then
			safeChip.Visible = true
			return
		end
		local pair = ammoTable[weapon.id]
		local reloadAt = player:GetAttribute("CyberOutlawRecargaAte")
		if type(reloadAt) == "number" and reloadAt > Workspace:GetServerTimeNow() then
			return
		end
		if not pair or pair[1] <= 0 then
			nextShot = now + 0.25
			sound("arma_vazia", nil, 0.5)
			reload()
			return
		end
		nextShot = now + 1 / weapon.rate
		hipFireUntil = now + 0.7
		local view = camera.CFrame
		local look = view.LookVector
		local skip = math.max(0, (head.Position - view.Position):Dot(look) - 1)
		local origin = view.Position + look * skip
		local moving = humanoid and humanoid.MoveDirection.Magnitude > 0.1
		local spread = weapon.spread * (if aiming then 1 else 1.8) * (if moving then 1.25 else 1) + bloom
		local directions = {}
		for index = 1, weapon.pellets or 1 do
			directions[index] = coneDirection(look, math.rad(spread), rng)
		end
		refreshFilter()
		local from = muzzleOf(character) or head.Position
		local accent = rgb(weapon.accent)
		for _, direction in directions do
			local result = Workspace:Raycast(origin, direction * weapon.range, rayParams)
			local point = if result then result.Position else origin + direction * weapon.range
			tracer(from, point, accent)
			if result then
				spark(point, Color3.fromRGB(255, 210, 150), 4, result.Normal)
			end
		end
		muzzleFlash(from, accent, look)
		sound("arma_" .. weapon.id, nil, 0.7)
		pair[1] -= 1
		-- Recoil: part of the kick stays (the climb), part returns on its own.
		local kick = math.rad(weapon.recoil or 1)
		cam.pitch += kick * 0.3
		cam.kick += kick * 0.7
		cam.kickYaw += kick * rng:NextNumber(-0.35, 0.35)
		cam.trauma = math.min(1, cam.trauma + 0.04 * (weapon.recoil or 1))
		bloom = math.min(weapon.spread * 3, bloom + weapon.recoil * 0.35)
		poses[character] = poses[character] or {}
		poses[character].firedAt = now
		if action then
			action:FireServer("atirar", origin, directions)
		end
	end

	if effectEvent then
		effectEvent.OnClientEvent:Connect(function(kind, who, id, a, b)
			if typeof(who) ~= "Instance" or not who:IsA("Player") then
				return
			end
			local model = who.Character
			local weapon = byId[id]
			if kind == "tiro" and type(b) == "table" then
				if who == player then
					for _, hit in b do
						if hit[3] then
							showHit()
							sound("click", nil, 0.35)
							break
						end
					end
					return
				end
				if model then
					poses[model] = poses[model] or {}
					poses[model].firedAt = os.clock()
				end
				local from = muzzleOf(model) or a
				local accent = if weapon then rgb(weapon.accent) else WHITE
				if typeof(from) == "Vector3" then
					for _, hit in b do
						if typeof(hit[1]) == "Vector3" then
							tracer(from, hit[1], accent)
							spark(hit[1], if hit[3] then Color3.fromRGB(255, 60, 80) else Color3.fromRGB(255, 210, 150), 3, hit[2])
						end
					end
					local look = if b[1] and typeof(b[1][1]) == "Vector3" then (b[1][1] - from).Unit else Vector3.zAxis
					muzzleFlash(from, accent, look)
					local weaponModel = model and model:FindFirstChild("CyberOutlawArma")
					sound("arma_" .. tostring(id), weaponModel and weaponModel.PrimaryPart, 0.8)
				end
			elseif kind == "golpe" and model and who ~= player then
				poses[model] = poses[model] or {}
				poses[model].swingStart = os.clock()
				poses[model].swingKind = id
				poses[model].swingSide = if a == -1 then -1 else 1
				if typeof(b) == "Vector3" then
					spark(b, Color3.fromRGB(255, 120, 90), 5)
				end
			elseif kind == "golpe" and who == player and typeof(b) == "Vector3" then
				showHit()
				spark(b, Color3.fromRGB(255, 120, 90), 6)
			elseif kind == "troca" and who == player and type(id) == "string" then
				current = id
			end
		end)
	end

	-- Wheel ----------------------------------------------------------------------------------------
	local function openWheel()
		if not wheel or wheelOpen or dead then
			return
		end
		wheelOpen = true
		wheel.gui.Enabled = true
		wheelSelection = (byId[current] and byId[current].order) or 1
		wheel.select(wheelSelection, ammoTable)
		sound("glitch", nil, 0.3)
	end

	local function closeWheel(equipSelected: boolean)
		if not wheelOpen then
			return
		end
		wheelOpen = false
		if equipSelected and defs[wheelSelection] then
			equip(defs[wheelSelection].id)
			sound("confirm", nil, 0.4)
		end
	end

	if wheel then
		for index, entry in wheel.cards do
			entry.card.MouseEnter:Connect(function()
				if wheelOpen and wheelSelection ~= index then
					wheelSelection = index
					wheel.select(index, ammoTable)
					sound("click", nil, 0.25)
				end
			end)
			entry.card.Activated:Connect(function()
				wheelSelection = index
				wheel.select(index, ammoTable)
				closeWheel(true)
			end)
		end
		wheel.shade.Activated:Connect(function()
			closeWheel(false)
		end)
	end
	if card then
		card.panel.Activated:Connect(function()
			if wheelOpen then
				closeWheel(false)
			else
				openWheel()
			end
		end)
	end

	-- Input ----------------------------------------------------------------------------------------
	local function typing()
		return UserInputService:GetFocusedTextBox() ~= nil
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			if not processed and not wheelOpen and input.Position.X > camera.ViewportSize.X * 0.35 then
				touchCamera[input] = input.Position
			end
			return
		end
		if processed or typing() then
			return
		end
		local key = input.KeyCode
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if not wheelOpen then
				triggerHeld = true
				shoot()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			aiming = def().kind == "gun"
		elseif key == Enum.KeyCode.LeftShift then
			sprintHeld = true
		elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.ButtonL1 then
			openWheel()
		elseif key == Enum.KeyCode.R or key == Enum.KeyCode.ButtonX then
			reload()
		elseif key == Enum.KeyCode.G or key == Enum.KeyCode.ButtonY then
			equip("punhos")
		elseif key == Enum.KeyCode.V then
			cam.side = -cam.side
		elseif key == Enum.KeyCode.ButtonR2 then
			triggerHeld = true
			shoot()
		elseif key == Enum.KeyCode.ButtonL2 then
			aiming = def().kind == "gun"
		elseif key == Enum.KeyCode.ButtonL3 then
			sprintToggle = not sprintToggle
		elseif key == Enum.KeyCode.DPadRight then
			cycle(1)
		elseif key == Enum.KeyCode.DPadLeft then
			cycle(-1)
		else
			local numbers = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }
			local index = table.find(numbers, key)
			if index and defs[index] then
				equip(defs[index].id)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchCamera[input] = nil
			return
		end
		local key = input.KeyCode
		if input.UserInputType == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.ButtonR2 then
			triggerHeld = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or key == Enum.KeyCode.ButtonL2 then
			aiming = false
		elseif key == Enum.KeyCode.LeftShift then
			sprintHeld = false
		elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.ButtonL1 then
			closeWheel(true)
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if wheelOpen and wheel then
				local mouse = UserInputService:GetMouseLocation()
				local size = camera.ViewportSize
				local offset = mouse - size / 2 - Vector2.new(0, if touch then 13 else 24) * wheel.scale.Scale
				if offset.Magnitude > 40 then
					local index = slotFromVector(offset.X, offset.Y, #defs)
					if index and index ~= wheelSelection then
						wheelSelection = index
						wheel.select(index, ammoTable)
						sound("click", nil, 0.25)
					end
				end
			elseif not processed and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
				local factor = 0.0042 * sensitivity * (if aiming then 0.62 else 1)
				cam.yaw -= input.Delta.X * factor
				cam.pitch -= input.Delta.Y * factor
				cam.lastInput = os.clock()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed and not wheelOpen then
			cycle(if input.Position.Z > 0 then -1 else 1)
		elseif input.UserInputType == Enum.UserInputType.Touch and touchCamera[input] then
			local previous = touchCamera[input]
			local delta = input.Position - previous
			touchCamera[input] = input.Position
			local factor = 0.0065 * (if aiming then 0.6 else 1)
			cam.yaw -= delta.X * factor
			cam.pitch -= delta.Y * factor
			cam.lastInput = os.clock()
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.new(input.Position.X, input.Position.Y)
			if wheelOpen and stick.Magnitude > 0.5 then
				local index = slotFromVector(stick.X, -stick.Y, #defs)
				if index and index ~= wheelSelection then
					wheelSelection = index
					wheel.select(index, ammoTable)
				end
			end
		end
	end)
	if touch and fireButton then
		fireButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				triggerHeld = true
				shoot()
			end
		end)
		fireButton.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				triggerHeld = false
			end
		end)
		aimButton.Activated:Connect(function()
			aimToggle = not aimToggle and def().kind == "gun"
		end)
		reloadButton.Activated:Connect(reload)
	end

	-- Frame loop ---------------------------------------------------------------------------------
	local playTime = 0
	local function cameraStep(dt: number)
		if not character or not root or not root.Parent then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		local weapon = def()
		local alive = humanoid and humanoid.Health > 0
		local gun = weapon.kind == "gun"
		local aimingNow = alive and gun and (aiming or aimToggle)
		local raised = alive and gun and (aimingNow or os.clock() < hipFireUntil)
		local moving = humanoid and humanoid.MoveDirection.Magnitude > 0.1

		-- Gamepad: right stick turns the camera.
		if stick.Magnitude > 0.15 and not wheelOpen then
			local curve = stick * stick.Magnitude
			local rate = if aimingNow then 1.4 else 2.7
			cam.yaw -= curve.X * rate * dt
			cam.pitch += curve.Y * rate * 0.75 * dt
			cam.lastInput = os.clock()
		end
		-- Automatic follow: with no camera input, the camera slowly returns behind the character.
		if alive and not aimingNow and moving and os.clock() - cam.lastInput > 1.6 then
			local look = root.CFrame.LookVector
			local target = math.atan2(-look.X, -look.Z)
			local pull = math.clamp(root.AssemblyLinearVelocity.Magnitude / 26, 0, 1) * 1.1 * dt
			cam.yaw += angleDelta(cam.yaw, target) * pull
			cam.pitch += (math.rad(-10) - cam.pitch) * pull * 0.6
		end
		if not alive then
			cam.deathSpin += dt * 0.22
			cam.yaw += dt * 0.22
			cam.pitch += (math.rad(-28) - cam.pitch) * math.min(1, dt * 2)
		end
		cam.pitch = math.clamp(cam.pitch, math.rad(-72), math.rad(62))

		local targetDistance = if not alive then 16 elseif aimingNow then (if weapon.id == "agulha" then 4.6 else 5.6) elseif sprinting then 13 else 11.5
		local targetShoulder = (if aimingNow or raised then 2.1 else 1.35) * cam.side
		local targetFov = if aimingNow then (weapon.fov or 54) elseif sprinting then 77 else 70
		if wheelOpen then
			targetFov -= 6
		end
		cam.shoulder, cam.shoulderVel = spring(cam.shoulder, cam.shoulderVel, targetShoulder, 3.2, dt)
		cam.fov, cam.fovVel = spring(cam.fov, cam.fovVel, targetFov, 2.6, dt)

		-- Focus with lag: horizontal faster than vertical (jumps and stairs don't jerk).
		local anchor = root.Position + Vector3.new(0, 1.6, 0)
		if not cam.focus then
			cam.focus = Vector3.new(anchor.X, 0, anchor.Z)
			cam.height = anchor.Y
		end
		local flat = Vector3.new(anchor.X, 0, anchor.Z)
		cam.focus, cam.focusVel = spring(cam.focus, cam.focusVel, flat, if aimingNow then 9 else 6, dt)
		cam.height, cam.heightVel = spring(cam.height, cam.heightVel, anchor.Y, 3.4, dt)
		if (cam.focus - flat).Magnitude > 30 then
			cam.focus, cam.focusVel = flat, Vector3.zero
		end
		local focus = Vector3.new(cam.focus.X, cam.height, cam.focus.Z)

		-- Recoil that returns, plus shake with intensity (trauma).
		cam.kick *= math.exp(-dt * 9)
		cam.kickYaw *= math.exp(-dt * 9)
		cam.trauma = math.max(0, cam.trauma - dt * 1.6)
		bloom = math.max(0, bloom - dt * 3)
		playTime += dt
		local shake = cam.trauma * cam.trauma
		local shakePitch = shake * math.rad(2.2) * math.noise(playTime * 22, 0.3)
		local shakeYaw = shake * math.rad(2.2) * math.noise(playTime * 22, 7.1)
		local bob = if sprinting and moving then math.sin(playTime * 11) * 0.06 else 0

		local rotation = CFrame.Angles(0, cam.yaw + cam.kickYaw + shakeYaw, 0) * CFrame.Angles(cam.pitch + cam.kick + shakePitch, 0, 0)
		refreshFilter()
		local sideOffset = rotation.RightVector * cam.shoulder + Vector3.new(0, 0.55 + bob, 0)
		local pivot = focus + sideOffset
		local sideHit = Workspace:Spherecast(focus, 0.4, sideOffset, rayParams)
		if sideHit then
			pivot = focus + sideOffset.Unit * math.max(0, sideHit.Distance - 0.1)
		end
		local back = -rotation.LookVector * targetDistance
		local hit = Workspace:Spherecast(pivot, 0.45, back, rayParams)
		local allowed = if hit then math.max(1.1, hit.Distance - 0.12) else targetDistance
		if allowed < cam.distance then
			cam.distance, cam.distanceVel = allowed, 0
		else
			cam.distance, cam.distanceVel = spring(cam.distance, cam.distanceVel, allowed, 2.2, dt)
		end
		camera.FieldOfView = cam.fov
		camera.CFrame = CFrame.new(pivot - rotation.LookVector * cam.distance) * rotation
		camera.Focus = CFrame.new(focus)

		-- Body almost transparent when the camera gets inside it.
		local fade = if cam.distance < 2.2 then 0.7 else 0
		for _, item in character:GetDescendants() do
			if item:IsA("BasePart") or item:IsA("Decal") then
				item.LocalTransparencyModifier = fade
			end
		end

		-- Focus blur while aiming (subtle cinematic depth).
		depth.Enabled = aimingNow and quality >= 5
		if depth.Enabled then
			local result = Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 400, rayParams)
			depth.FocusDistance = if result then result.Distance else 200
		end
		return aimingNow, raised
	end

	local function movementStep(dt: number, aimingNow: boolean, raised: boolean)
		if not humanoid or not root or not align then
			return
		end
		local alive = humanoid.Health > 0
		local seated = humanoid.SeatPart ~= nil
		align.Enabled = alive and not seated
		humanoid.AutoRotate = seated
		local moveDirection = humanoid.MoveDirection
		local moving = moveDirection.Magnitude > 0.1
		-- Mobile: stick pushed all the way for a moment = sprint.
		local analog = 0
		if controls then
			local ok, vector = pcall(function()
				return controls:GetMoveVector()
			end)
			if ok and typeof(vector) == "Vector3" then
				analog = vector.Magnitude
			end
		end
		if touch and analog > 0.92 then
			pushTime += dt
		else
			pushTime = 0
		end
		if not moving then
			sprintToggle = false
		end
		local wants = sprintHeld or sprintToggle or pushTime > 0.3
		sprinting = alive and moving and wants and not stamina.exhausted and not raised
		staminaStep(stamina, sprinting, dt)
		player:SetAttribute("CyberOutlawFolego", stamina.value)
		player:SetAttribute("CyberOutlawExausto", stamina.exhausted)
		local target = if raised then 11 elseif sprinting then 27 else 17
		speed += (target - speed) * math.min(1, dt * 6)
		humanoid.WalkSpeed = speed
		-- Facing: when aiming, the body follows the camera; otherwise it turns smoothly toward the movement.
		if raised then
			facingYaw = cam.yaw
			align.Responsiveness = 45
		elseif moving then
			facingYaw = math.atan2(-moveDirection.X, -moveDirection.Z)
			align.Responsiveness = if sprinting then 11 else 16
		end
		align.CFrame = CFrame.Angles(0, facingYaw, 0)
		-- Lean into turns and forward during the sprint (local only, cosmetic).
		if joints.root and joints.rootC0 then
			local turn = root.AssemblyAngularVelocity.Y
			local targetLean = math.clamp(turn * 0.05 * (speed / 27), -0.24, 0.24)
			lean, leanVel = spring(lean, leanVel, if moving then targetLean else 0, 2.4, dt)
			forwardLean += ((if sprinting then 0.13 elseif moving then 0.04 else 0) - forwardLean) * math.min(1, dt * 5)
			joints.root.C0 = CFrame.Angles(-forwardLean, 0, lean) * joints.rootC0
		end
	end

	-- Arm and head pose (PreSimulation: after the animation, before the physics).
	local SWING = { punhos = 0.26, lamina = 0.42 }
	local TWO_HANDS = { enxame = true, trovao = true, agulha = true, vespa = true }
	local function poseCharacter(model: Model, now: number)
		local body = model:FindFirstChild("Torso")
		if not body then
			return
		end
		local right = body:FindFirstChild("Right Shoulder")
		local left = body:FindFirstChild("Left Shoulder")
		if not right or not left then
			return
		end
		local id = model:GetAttribute("CyberOutlawArma")
		local weapon = byId[id]
		local state = poses[model]
		local isLocal = model == character
		local pitch = if isLocal then cam.pitch else math.rad(model:GetAttribute("CyberOutlawPitch") or 0)
		local aimed = if isLocal then (aiming or aimToggle) else model:GetAttribute("CyberOutlawMirando") == true
		local firedRecently = state and state.firedAt and now - state.firedAt < 0.7
		if state and state.swingStart then
			local duration = SWING[state.swingKind] or 0.3
			local t = (now - state.swingStart) / duration
			if t < 1 then
				local arm = if state.swingSide == -1 and state.swingKind == "punhos" then left else right
				local side = if arm == left then -1 else 1
				local direction = swingDirection(state.swingKind, side, t)
				arm.Transform = jointTransform(arm.C0, arm.C1, armRotation(direction, Vector3.new(0, 1, 0)))
				return
			end
			state.swingStart = nil
		end
		if not weapon or weapon.kind ~= "gun" then
			if weapon and weapon.id == "lamina" then
				right.Transform = jointTransform(right.C0, right.C1, armRotation(Vector3.new(0.12, -0.72, -0.68), Vector3.new(0, 1, 0)))
			end
			return
		end
		local up = Vector3.new(0, 1, 0)
		local direction
		if aimed or firedRecently then
			direction = Vector3.new(0, math.sin(pitch), -math.cos(pitch))
		else
			direction = Vector3.new(0.05, -0.55, -0.83).Unit
		end
		right.Transform = jointTransform(right.C0, right.C1, armRotation(direction, up))
		if TWO_HANDS[weapon.id] then
			local shoulderRight = right.C0.Position
			local shoulderLeft = left.C0.Position
			local reach = if weapon.id == "vespa" then 1.85 else 2.45
			local hand = shoulderRight + Vector3.new(0.5, 0, 0) + direction * reach
			local support = hand + Vector3.new(-0.35, -0.12, 0)
			left.Transform = jointTransform(left.C0, left.C1, armRotation((support - shoulderLeft).Unit, up))
		end
	end

	local function headStep(dt: number)
		if not joints.neck or not torso or not humanoid or humanoid.Health <= 0 then
			return
		end
		local look = torso.CFrame:VectorToObjectSpace(camera.CFrame.LookVector)
		local yaw = math.clamp(math.atan2(-look.X, -look.Z), math.rad(-65), math.rad(65))
		local pitch = math.clamp(math.asin(math.clamp(look.Y, -1, 1)), math.rad(-35), math.rad(35))
		local direction = Vector3.new(-math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
		local rotation = CFrame.lookAt(Vector3.zero, direction)
		joints.neck.Transform = jointTransform(joints.neck.C0, joints.neck.C1, rotation)
		local _ = dt
	end

	local function onPreSimulation(dt: number)
		local now = os.clock()
		for _, other in Players:GetPlayers() do
			local model = other.Character
			if model then
				local ok = pcall(poseCharacter, model, now)
				local _ = ok
			end
		end
		pcall(headStep, dt)
	end
	local preSimulation = if (RunService :: any).PreSimulation then (RunService :: any).PreSimulation else RunService.Stepped
	preSimulation:Connect(function(a, b)
		onPreSimulation(if type(b) == "number" then b else a)
	end)

	local function interfaceStep(dt: number, aimingNow: boolean, raised: boolean)
		local weapon = def()
		local reloadAt = player:GetAttribute("CyberOutlawRecargaAte")
		local reloading = type(reloadAt) == "number" and reloadAt > Workspace:GetServerTimeNow()
		if card then
			local progress = nil
			if reloading then
				progress = 1 - (reloadAt - Workspace:GetServerTimeNow()) / (weapon.reload or 1)
			end
			card.show(weapon, templates[weapon.id], ammoTable[weapon.id], progress)
			card.gui.Enabled = not dead
		end
		-- Crosshair: only with a gun, when aiming or right after a shot; on mobile, whenever armed.
		local aimScreen = aimGui()
		if aimScreen then
			aimScreen.Enabled = not dead and not wheelOpen and weapon.kind == "gun" and (aimingNow or raised or touch)
			local crosshair = aimScreen:FindFirstChild("Crosshair")
			if crosshair then
				local scale = crosshair:FindFirstChildOfClass("UIScale") or new("UIScale", crosshair, {})
				scale.Scale = (if aimingNow then 0.85 else 1.15) + bloom * 0.12
			end
		end
		if touch and fireButton then
			aimButton.Visible = weapon.kind == "gun"
			reloadButton.Visible = weapon.kind == "gun"
			aimRing.Color = if aimToggle then WHITE else CYAN
		end
		hitmarker.Visible = os.clock() < hitUntil
		safeChip.Visible = root ~= nil and inSafeZone(root.Position) and weapon.kind == "gun"
		-- Red vignette on taking damage; it pulses with low health.
		local health = if humanoid then humanoid.Health / math.max(1, humanoid.MaxHealth) else 1
		damageFlash = math.max(0, damageFlash - dt * 1.8)
		local low = if health < 0.3 and health > 0 then 0.25 + 0.2 * math.sin(os.clock() * 5) else 0
		local red = math.max(damageFlash, low)
		for _, piece in vignettePieces do
			piece.BackgroundColor3 = Color3.new(0, 0, 0):Lerp(Color3.fromRGB(160, 0, 30), red)
		end
		-- Wheel: opening with easing, blur, and desaturation.
		wheelOpenAmount = math.clamp(wheelOpenAmount + (if wheelOpen then dt * 7 else -dt * 9), 0, 1)
		if wheel then
			local eased = 1 - (1 - wheelOpenAmount) ^ 3
			wheel.gui.Enabled = wheelOpenAmount > 0.01
			if wheel.gui.Enabled then
				local viewport = camera.ViewportSize
				wheel.scale.Scale = math.clamp(viewport.Y / (if touch then 390 else 720), 0.7, 1.5)
				wheel.animate(dt, eased)
			end
			blur.Size = 16 * eased
			grade.Saturation = -0.3 * eased
			grade.Brightness = -0.04 * eased
		end
	end

	local function pitchStep()
		local weapon = def()
		local now = os.clock()
		if weapon.kind ~= "gun" or not aimEvent or now - pitchSentAt < 0.1 then
			return
		end
		local pitch = math.deg(cam.pitch)
		if math.abs(pitch - lastPitchSent) >= 2 then
			pitchSentAt = now
			lastPitchSent = pitch
			aimEvent:FireServer(pitch)
		end
	end

	local lastAimSent = false
	RunService:BindToRenderStep("CyberOutlawCamera", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local ok, aimingNow, raised = pcall(cameraStep, dt)
		if not ok then
			warn("CyberOutlaw | Câmera: " .. tostring(aimingNow))
			aimingNow, raised = false, false
		end
		aimingNow, raised = aimingNow == true, raised == true
		if aimingNow ~= lastAimSent and action then
			lastAimSent = aimingNow
			action:FireServer("mirar", aimingNow)
		end
		local moved, problem = pcall(movementStep, dt, aimingNow, raised)
		if not moved then
			warn("CyberOutlaw | Movimento: " .. tostring(problem))
		end
		pcall(interfaceStep, dt, aimingNow, raised)
		pcall(pitchStep)
		-- Automatic fire while the trigger is held.
		if triggerHeld and def().auto and not wheelOpen then
			shoot()
		end
		-- Mouse locked while playing (like third-person shooters), free in the wheel and menus.
		if not touch then
			local free = wheelOpen or GuiService.MenuIsOpen or UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
			UserInputService.MouseBehavior = if free then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = free
		end
	end)

	local function onCharacter(model: Model)
		dead = false
		deathScreen.Visible = false
		deathGrade.Enabled = false
		current = "punhos"
		aiming, aimToggle, triggerHeld = false, false, false
		stamina.value, stamina.exhausted = 1, false
		cam.focus = nil
		cam.trauma = 0
		bindCharacter(model)
		if humanoid then
			local lastHealth = humanoid.Health
			humanoid.HealthChanged:Connect(function(health)
				if health < lastHealth - 0.5 then
					damageFlash = math.min(0.85, damageFlash + (lastHealth - health) / 40)
					cam.trauma = math.min(1, cam.trauma + 0.18)
				end
				lastHealth = health
			end)
			humanoid.StateChanged:Connect(function(_, state)
				if state == Enum.HumanoidStateType.Landed and root then
					local fall = math.abs(root.AssemblyLinearVelocity.Y)
					cam.trauma = math.min(1, cam.trauma + math.clamp((fall - 30) / 90, 0, 0.45))
				end
			end)
			humanoid.Died:Connect(function()
				dead = true
				wheelOpen = false
				deathScreen.Visible = true
				deathGrade.Enabled = true
				deathScreen.BackgroundTransparency = 0.7
				deathTitle.Text = "SINAL PERDIDO"
				deathHint.Text = "RECONECTANDO AO CORPO…"
			end)
		end
		model:GetAttributeChangedSignal("CyberOutlawArma"):Connect(function()
			local id = model:GetAttribute("CyberOutlawArma")
			if type(id) == "string" and byId[id] then
				current = id
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
	local look = camera.CFrame.LookVector
	cam.yaw = math.atan2(-look.X, -look.Z)
end

if typeof(game) == "Instance" then
	task.spawn(start)
end

return M
