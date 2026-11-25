-- CyberOutlaw menu. Install as a LocalScript under StarterPlayerScripts.
-- Required Notice: Copyright 2026 Lachy (https://github.com/lachydotmcg)
-- Required Notice: Anyone who uses Capri's code, art, animations or any of its other assets must credit the Capri project (https://github.com/lachydotmcg/capri-desktop). Capri's art and animations are by her artist, who prefers to stay private. Parts made by others keep their own licences, listed in its README.
-- Capri Desktop assets: https://polyformproject.org/licenses/noncommercial/1.0.0
-- The cursor click animation is by mixmix312352.

local ASSETS = __CYBEROUTLAW_CONFIG__
-- __CYBEROUTLAW_CITY__
-- __CYBEROUTLAW_SCENE__

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("CyberOutlawMenu") then
	return
end

local TITLE = "CyberOutlaw"
local LOADER_SECONDS = 6
local EXIT_SECONDS = 0.34
local ACTION = "CyberOutlawMenuMovement"
local FULL = UDim2.fromScale(1, 1)
local CENTER = Vector2.new(0.5, 0.5)
local WHITE = Color3.fromRGB(249, 246, 255)
local INK = Color3.fromRGB(8, 7, 12)
local SURFACE = Color3.fromRGB(18, 15, 24)
local MUTED = Color3.fromRGB(188, 179, 204)
local MAGENTA = Color3.fromRGB(255, 32, 133)
local PINK_LIGHT = Color3.fromRGB(255, 132, 195)
local PINK_SHADOW = Color3.fromRGB(142, 9, 73)
local PLAY_FACE = Color3.fromRGB(215, 10, 101)
local SMOKE_EDGE = Color3.fromRGB(80, 60, 84)
local CYAN = Color3.fromRGB(142, 222, 228)
local BODY = Font.fromEnum(Enum.Font.GothamMedium)
local BOLD = Font.fromEnum(Enum.Font.GothamBold)
local WORDMARK = Font.fromEnum(Enum.Font.PermanentMarker)
local rng = Random.new()

local function asset(id)
	return if type(id) == "number" and id > 0 and id < math.huge then string.format("rbxassetid://%.0f", id) else ""
end

local function make(class, parent, name, properties)
	local item = Instance.new(class)
	item.Name = name
	for key, value in properties do
		item[key] = value
	end
	item.Parent = parent
	return item
end

local function frame(parent, name, z, properties)
	local base = { BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z }
	for key, value in properties do
		base[key] = value
	end
	return make("Frame", parent, name, base)
end

local function text(parent, name, message, z, font, size, color)
	return make("TextLabel", parent, name, {
		Size = FULL, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z,
		Text = message, FontFace = font, TextSize = size, TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
	})
end

local function radius(parent, px)
	make("UICorner", parent, "Corner", { CornerRadius = UDim.new(0, px) })
end

local function outline(parent, color)
	return make("UIStroke", parent, "Border", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = color, Thickness = 1,
	})
end

local function gradient(parent, rotation, from, to, opacity)
	local props = { Rotation = rotation, Color = ColorSequence.new(from, to) }
	if opacity then
		props.Transparency = opacity
	end
	make("UIGradient", parent, "Gradient", props)
end

local function screen(name, order, safe)
	return make("ScreenGui", nil, name, {
		ResetOnSpawn = false, DisplayOrder = order, ZIndexBehavior = Enum.ZIndexBehavior.Global,
		ClipToDeviceSafeArea = safe, SafeAreaCompatibility = Enum.SafeAreaCompatibility.None,
		ScreenInsets = if safe then Enum.ScreenInsets.CoreUISafeInsets else Enum.ScreenInsets.None,
	})
end

local function button(parent, name, z)
	return make("TextButton", parent, name, {
		AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z,
		Text = "", Active = true, Selectable = true,
	})
end

local function line(parent, name, z, from, to, thickness, color)
	local delta = to - from
	local midpoint = (from + to) / 2
	return frame(parent, name, z, {
		AnchorPoint = CENTER, Position = UDim2.fromOffset(midpoint.X, midpoint.Y),
		Size = UDim2.fromOffset(delta.Magnitude, thickness), Rotation = math.deg(math.atan2(delta.Y, delta.X)),
		BackgroundTransparency = 0, BackgroundColor3 = color,
	})
end

-- The two corners are clipped diamonds, so the slanted edge stays sharp at
-- any button width without relying on uploaded textures or a solid mask color.
local function polygon(parent, name, z, cut, color, alpha, inset)
	local plate = frame(parent, name, z, {
		Position = UDim2.fromOffset(inset, inset), Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
	})
	local pieces = {}
	local function piece(container, partName, position, size, rotated)
		local child = frame(container, partName, z, {
			Position = position, Size = size, BackgroundTransparency = alpha, BackgroundColor3 = color,
		})
		if rotated then
			child.AnchorPoint = CENTER
			child.Rotation = 45
		end
		table.insert(pieces, child)
	end
	piece(plate, "Center", UDim2.fromOffset(0, cut), UDim2.new(1, 0, 1, -cut * 2))
	piece(plate, "Upper", UDim2.fromOffset(0, 0), UDim2.new(1, -cut, 0, cut))
	piece(plate, "Lower", UDim2.new(0, cut, 1, -cut), UDim2.new(1, -cut, 0, cut))
	for _, corner in { "UpperRight", "LowerLeft" } do
		local upper = corner == "UpperRight"
		local clip = frame(plate, corner, z, {
			Position = if upper then UDim2.new(1, -cut, 0, 0) else UDim2.new(0, 0, 1, -cut),
			Size = UDim2.fromOffset(cut, cut), ClipsDescendants = true,
		})
		piece(clip, "Diagonal", UDim2.fromOffset(if upper then 0 else cut, if upper then cut else 0),
			UDim2.fromOffset(cut * math.sqrt(2), cut * math.sqrt(2)), true)
	end
	return pieces
end

local function paint(pieces, color)
	for _, piece in pieces do
		piece.BackgroundColor3 = color
	end
end

local function iconLine(holder, z, points, color)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		line(holder, "Stroke", z, Vector2.new(a[1], a[2]), Vector2.new(b[1], b[2]), 1.6, color)
	end
end

local function drawIcon(holder, kind, z, color)
	if kind == "Play" then
		iconLine(holder, z, { { 7, 4 }, { 19, 12 }, { 7, 20 }, { 7, 4 } }, color)
	elseif kind == "Settings" then
		for row, knob in { 8, 15, 11 } do
			local y = row * 5 + 2
			iconLine(holder, z, { { 4, y }, { 20, y } }, color)
			iconLine(holder, z, { { knob, y - 2.5 }, { knob, y + 2.5 } }, color)
		end
	elseif kind == "ProfileSettings" then
		iconLine(holder, z, { { 9, 4 }, { 15, 4 }, { 15, 6 }, { 19, 9 }, { 21, 9 }, { 21, 15 }, { 19, 15 },
			{ 15, 18 }, { 15, 20 }, { 9, 20 }, { 9, 18 }, { 5, 15 }, { 3, 15 }, { 3, 9 }, { 5, 9 }, { 9, 6 }, { 9, 4 } }, color)
		iconLine(holder, z, { { 11, 10 }, { 13, 10 }, { 14, 12 }, { 13, 14 }, { 11, 14 }, { 10, 12 }, { 11, 10 } }, color)
	else
		iconLine(holder, z, { { 4, 5 }, { 17, 5 }, { 20, 8 }, { 20, 18 }, { 7, 18 }, { 4, 15 }, { 4, 5 } }, color)
		for _, y in { 10, 13, 16 } do
			iconLine(holder, z, { { 8, y }, { 16, y } }, color)
		end
	end
end

-- __CYBEROUTLAW_HUD__
if player:GetAttribute("CyberOutlawMenuStarted") then
	mountCyberOutlawHud()
	return
end

local backdrop = screen("CyberOutlawBackdrop", 1200, false)
local safeGui = screen("CyberOutlawMenu", 1201, true)
local safe = frame(safeGui, "SafeArea", 1, { Size = FULL })
local background = frame(backdrop, "Backdrop", 1, {
	Size = FULL, BackgroundTransparency = 0, BackgroundColor3 = INK,
})
gradient(background, 34, Color3.fromRGB(7, 5, 13), Color3.fromRGB(37, 14, 40))
local view = make("ViewportFrame", backdrop, "CyberCity", {
	Size = FULL, ZIndex = 2, BackgroundTransparency = 1, ImageTransparency = 1,
	Ambient = Color3.fromRGB(123, 102, 146), LightColor = Color3.fromRGB(224, 221, 255),
	LightDirection = Vector3.new(-0.35, -0.8, -0.45),
})
local world = make("WorldModel", view, "CityWorld", {})
local camera = make("Camera", view, "MenuCamera", { FieldOfView = 44 })
view.CurrentCamera = camera

local scrim = frame(backdrop, "Contrast", 3, {
	Size = FULL, BackgroundColor3 = INK, BackgroundTransparency = 0,
})
local veil = make("UIGradient", scrim, "Direction", {
	Color = ColorSequence.new(INK, INK),
})
local floor = frame(backdrop, "Vignette", 4, {
	Size = FULL, BackgroundColor3 = INK, BackgroundTransparency = 0,
})
gradient(floor, 90, INK, INK, NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.72),
	NumberSequenceKeypoint.new(0.22, 1),
	NumberSequenceKeypoint.new(0.65, 1),
	NumberSequenceKeypoint.new(0.87, 0.62),
	NumberSequenceKeypoint.new(1, 0.24),
}))
local inputShield = button(backdrop, "InputShield", 20)
inputShield.Size = FULL
inputShield.Selectable = false
inputShield.Modal = true

local stack = make("ScrollingFrame", safe, "MenuStack", {
	Visible = false, Active = true, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10,
	CanvasSize = UDim2.fromOffset(0, 0), ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 0, ElasticBehavior = Enum.ElasticBehavior.Never,
})
local brand = frame(stack, "Title", 11, {})
local ghostMagenta = text(brand, "Magenta", TITLE, 11, WORDMARK, 96, PINK_SHADOW)
local ghostCyan = text(brand, "Cyan", TITLE, 11, WORDMARK, 96, PINK_LIGHT)
local title = text(brand, "Wordmark", TITLE, 12, WORDMARK, 96, WHITE)
gradient(title, 82, Color3.fromRGB(255, 94, 177), Color3.fromRGB(255, 22, 116))
local marks = {
	{ a = Vector2.new(0.14, 0.97), b = Vector2.new(0.72, 0.69), weight = 0.025, color = MAGENTA, alpha = 0.08 },
	{ a = Vector2.new(0.28, 0.96), b = Vector2.new(0.81, 0.72), weight = 0.012, color = PINK_LIGHT, alpha = 0.50 },
	{ a = Vector2.new(0.04, 0.90), b = Vector2.new(0.28, 0.79), weight = 0.012, color = PINK_SHADOW, alpha = 0.15 },
	{ a = Vector2.new(0.78, 0.21), b = Vector2.new(0.95, 0.14), weight = 0.012, color = MAGENTA, alpha = 0.28 },
}
for _, mark in marks do
	mark.ink = frame(brand, "BrushStroke", 11, {
		AnchorPoint = CENTER, BackgroundColor3 = mark.color, BackgroundTransparency = mark.alpha,
	})
end
local titleUri = asset((ASSETS.art or {}).title)
local function logoLayer(name, z, color)
	return make("ImageLabel", brand, name, {
		Size = FULL, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z,
		Image = titleUri, ImageColor3 = color, ScaleType = Enum.ScaleType.Fit, Visible = false,
	})
end
local logoBack = logoLayer("LogoMagenta", 11, PINK_SHADOW)
local logoLight = logoLayer("LogoPink", 11, PINK_LIGHT)
local logo = logoLayer("Logo", 12, Color3.fromRGB(255, 255, 255))
logo.Visible = titleUri ~= ""
local titleFetched = false
local slices = {}
for index, relativeY in { 0.37, 0.63 } do
	local strip = frame(brand, "Slice" .. index, 13, {
		Visible = false, ClipsDescendants = true, BackgroundTransparency = 0.24, BackgroundColor3 = INK,
	})
	slices[index] = {
		strip = strip, y = relativeY,
		label = text(strip, "Title", TITLE, 14, WORDMARK, 96, if index == 1 then MAGENTA else CYAN),
	}
end
for _, label in { title, ghostMagenta, ghostCyan, slices[1].label, slices[2].label } do
	label.TextScaled = true
	make("UITextSizeConstraint", label, "SizeLimit", { MinTextSize = 14, MaxTextSize = 136 })
end

local function menuButton(name, message, primary)
	local item = button(stack, name, 15)
	item.Text = message
	item.TextTransparency = 1
	local stroke = polygon(item, "ChamferBorder", 15, if primary then 16 else 12, if primary then MAGENTA else SMOKE_EDGE, 0, 0)
	local face = polygon(item, "ChamferFace", 16, if primary then 15 else 11, if primary then PLAY_FACE else SURFACE, if primary then 0 else 0.05, 1)
	local messageLabel = text(item, "Label", message, 20, BOLD, 17, WHITE)
	local tint = text(item, "Ghost", message, 19, BOLD, 17, PINK_LIGHT)
	tint.Visible = false
	local icon = frame(item, "Icon", 18, {
		AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0, 19, 0.5, 0),
	})
	drawIcon(icon, name, 18, if primary then WHITE else Color3.fromRGB(209, 179, 203))
	local shine = frame(item, "TopBevel", 18, {
		Position = UDim2.fromOffset(3, 2), Size = UDim2.new(1, if primary then -22 else -18, 0, 1),
		BackgroundTransparency = if primary then 0.19 else 0.65,
		BackgroundColor3 = if primary then PINK_LIGHT else PINK_SHADOW,
	})
	gradient(shine, 0, WHITE, WHITE, NumberSequence.new(0, 1))
	local detail = frame(item, "CornerDetail", 18, {
		Position = UDim2.new(1, -15, 1, -6), Size = UDim2.fromOffset(10, 2),
		BackgroundTransparency = 0.05, BackgroundColor3 = if primary then PINK_LIGHT else MAGENTA,
	})
	local rail = frame(item, "Edge", 18, {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(2, 14), BackgroundTransparency = 1, BackgroundColor3 = PINK_LIGHT,
	})
	return { item = item, text = messageLabel, tint = tint, icon = icon, rail = rail, stroke = stroke, face = face,
		detail = detail, primary = primary, hovered = false }
end

local play = menuButton("Play", "Jogar", true)
local settings = menuButton("Settings", "Configurações", false)
local credits = menuButton("Credits", "Créditos", false)
local buttons = { play, settings, credits }
for index, config in buttons do
	config.item.NextSelectionUp = buttons[(index - 2) % #buttons + 1].item
	config.item.NextSelectionDown = buttons[index % #buttons + 1].item
end

local petLayer = frame(safe, "CapriLayer", 26, { Size = FULL, Visible = false, ClipsDescendants = true })
local sprite = make("ImageLabel", petLayer, "CapriSprite", {
	AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 27,
	ScaleType = Enum.ScaleType.Stretch, Visible = false,
})
local hit = button(petLayer, "CapriHitBox", 28)
hit.Selectable = false
hit.Visible = false
local clickSprite = make("ImageLabel", petLayer, "CapriClick", {
	AnchorPoint = CENTER, Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1, BorderSizePixel = 0,
	ZIndex = 29, Visible = false, ScaleType = Enum.ScaleType.Stretch,
})

local profile = frame(safe, "Profile", 30, { AnchorPoint = Vector2.new(1, 0), Visible = false })
polygon(profile, "ProfileBorder", 30, 8, SMOKE_EDGE, 0.14, 0)
polygon(profile, "ProfileFace", 31, 7, Color3.fromRGB(13, 11, 19), 0.06, 1)
frame(profile, "Signal", 32, {
	Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.31, 0, 0, 1),
	BackgroundColor3 = MAGENTA, BackgroundTransparency = 0,
})
local avatar = make("ImageLabel", profile, "Avatar", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = Color3.fromRGB(35, 26, 44), BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 33,
	ScaleType = Enum.ScaleType.Crop,
	Image = if player.UserId > 0 then "rbxthumb://type=AvatarHeadShot&id=" .. tostring(player.UserId) .. "&w=150&h=150" else "",
})
radius(avatar, 3)
outline(avatar, PINK_SHADOW)
local profileName = text(profile, "DisplayName", player.DisplayName, 33, BOLD, 14, WHITE)
profileName.TextTruncate = Enum.TextTruncate.AtEnd
profileName.Position = UDim2.fromOffset(53, 0)
profileName.Size = UDim2.new(1, -105, 1, 0)
local profileLevel = text(profile, "Level", "", 33, BODY, 11, MUTED)
profileLevel.Position = UDim2.fromOffset(53, 27)
profileLevel.Size = UDim2.new(1, -105, 0, 18)
profileLevel.TextTruncate = Enum.TextTruncate.AtEnd
profileLevel.Visible = false
local profileSettings = button(profile, "ProfileSettings", 34)
profileSettings.AnchorPoint = Vector2.new(1, 0.5)
profileSettings.Position = UDim2.new(1, -3, 0.5, 0)
profileSettings.Size = UDim2.fromOffset(44, 44)
profileSettings.Text = "Configurações"
profileSettings.TextTransparency = 1
profileSettings.BackgroundColor3 = Color3.fromRGB(54, 24, 43)
radius(profileSettings, 3)
frame(profile, "Divider", 32, {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -49, 0.5, 0), Size = UDim2.fromOffset(1, 25),
	BackgroundColor3 = PINK_SHADOW, BackgroundTransparency = 0.45,
})
local gear = frame(profileSettings, "Icon", 35, {
	AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 24),
})
drawIcon(gear, "ProfileSettings", 35, PINK_LIGHT)
for _, config in buttons do
	config.item.NextSelectionRight = profileSettings
end
profileSettings.NextSelectionLeft = play.item
profileSettings.NextSelectionDown = play.item

local modal = frame(safe, "Modal", 40, { Size = FULL, Visible = false })
frame(modal, "Dimmer", 40, {
	Size = FULL, BackgroundTransparency = 0.23, BackgroundColor3 = INK, Active = true,
})
local card = frame(modal, "Card", 41, {
	AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5),
	Active = true, Selectable = false,
})
polygon(card, "PanelBorder", 41, 16, Color3.fromRGB(117, 54, 92), 0, 0)
polygon(card, "PanelFace", 42, 15, SURFACE, 0, 1)
frame(card, "Accent", 42, {
	Size = UDim2.fromOffset(46, 2), Position = UDim2.fromOffset(19, 0), BackgroundTransparency = 0, BackgroundColor3 = MAGENTA,
})
local heading = text(card, "Heading", "", 43, BOLD, 25, WHITE)
heading.Position = UDim2.fromOffset(20, 5)
heading.Size = UDim2.new(1, -77, 0, 49)
local close = button(card, "Close", 44)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -8, 0, 7)
close.Size = UDim2.fromOffset(44, 44)
close.BackgroundColor3 = Color3.fromRGB(42, 32, 55)
close.BackgroundTransparency = 0.2
radius(close, 4)
local closeText = text(close, "Label", "×", 45, BODY, 25, WHITE)
closeText.TextXAlignment = Enum.TextXAlignment.Center
local cardBody = make("ScrollingFrame", card, "Body", {
	Position = UDim2.fromOffset(14, 61), Size = UDim2.new(1, -28, 1, -72),
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 43, Active = true,
	ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3,
	ScrollBarImageColor3 = Color3.fromRGB(133, 94, 149), ElasticBehavior = Enum.ElasticBehavior.Never,
	CanvasSize = UDim2.fromOffset(0, 0),
})
local preferences = frame(cardBody, "Preferences", 44, { Size = UDim2.new(1, -7, 0, 112) })
local notice = frame(cardBody, "Attribution", 44, { Size = UDim2.new(1, -7, 0, 209) })

local function toggle(name, message, y)
	local entry = button(preferences, name, 45)
	entry.BackgroundTransparency = 0
	entry.BackgroundColor3 = Color3.fromRGB(33, 26, 47)
	entry.Position = UDim2.fromOffset(0, y)
	entry.Size = UDim2.new(1, 0, 0, 50)
	radius(entry, 4)
	outline(entry, Color3.fromRGB(76, 60, 93))
	local label = text(entry, "Label", message, 46, BODY, 16, WHITE)
	label.Position = UDim2.fromOffset(12, 0)
	label.Size = UDim2.new(0.55, -10, 1, 0)
	local status = text(entry, "Status", "", 46, BOLD, 13, PINK_LIGHT)
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.Position = UDim2.fromScale(0.53, 0)
	status.Size = UDim2.new(0.47, -10, 1, 0)
	return entry, status
end

local soundToggle, soundStatus = toggle("SoundToggle", "Som do menu", 0)
local motionToggle, motionStatus = toggle("MotionToggle", "Animações", 59)
local creditName = text(notice, "Capri", "Capri Desktop", 45, BOLD, 18, WHITE)
creditName.Position = UDim2.fromOffset(6, 1)
creditName.Size = UDim2.new(1, -10, 0, 29)
local creditText = text(notice, "License", "© 2026 Lachy\nArte e animações por artista anônima.\nAnimação de clique por mixmix312352.\nPolyForm Noncommercial 1.0.0\nCliques do menu · ElevenLabs", 45, BODY, 14, MUTED)
creditText.TextWrapped = true
creditText.TextYAlignment = Enum.TextYAlignment.Top
creditText.Position = UDim2.fromOffset(6, 37)
creditText.Size = UDim2.new(1, -10, 0, 98)
local creditSource = text(notice, "Source", "github.com/lachydotmcg/capri-desktop\npolyformproject.org/licenses/noncommercial/1.0.0", 45, BODY, 12, CYAN)
creditSource.TextWrapped = true
creditSource.TextYAlignment = Enum.TextYAlignment.Top
creditSource.Position = UDim2.fromOffset(6, 141)
creditSource.Size = UDim2.new(1, -10, 0, 63)

for _, group in { stack, card } do
	group.SelectionGroup = true
	group.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
	group.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
	group.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
	group.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
end

local setFolder = make("Folder", SoundService, "CyberOutlawMenuAudio", {})
local sounds = {}
local cooldowns = {}
local preloadAssets = {}
local preloadImages = {}
local levels = { click = 0.26, confirm = 0.36, glitch = 0.16, react = 0.23, hello_morning = 0.40, hello_late = 0.40, hello_miss = 0.40 }
-- Cliques e transições do menu vêm da biblioteca de interface do próprio Roblox (pública em qualquer jogo):
-- som de estúdio no lugar dos bipes sintéticos, e funciona mesmo antes do midia.
local LIBRARY = { click = 15675059323, confirm = 17208396156, glitch = 15675046931 }
for key, level in levels do
	local uri = if LIBRARY[key] then string.format("rbxassetid://%d", LIBRARY[key]) else asset((ASSETS.sounds or {})[key])
	if uri ~= "" then
		sounds[key] = make("Sound", setFolder, key, { SoundId = uri, Volume = level })
		table.insert(preloadAssets, sounds[key])
	end
end

-- Música do menu (enviada pelo dono com o comando musica): toca em loop; o botão ♪ liga e desliga.
local musicUri = asset((ASSETS.sounds or {}).musica_menu)
local music = if musicUri ~= "" then make("Sound", setFolder, "musica_menu", { SoundId = musicUri, Volume = 0.32, Looped = true }) else nil
if music then
	table.insert(preloadAssets, music)
end
local musicOn = true

local clips = {}
for name, inputClip in ASSETS.clips or {} do
	local images = {}
	for _, source in inputClip.frames or {} do
		local uri = asset(source.id)
		if uri ~= "" and source.w > 0 and source.h > 0 then
			if not preloadImages[uri] then
				local probe = make("ImageLabel", nil, "Atlas", { Image = uri })
				preloadImages[uri] = probe
				table.insert(preloadAssets, probe)
			end
			table.insert(images, {
				uri = uri,
				offset = Vector2.new(source.x, source.y),
				size = Vector2.new(source.w, source.h),
			})
		end
	end
	if #images > 0 then
		clips[name] = { frames = images, fps = math.clamp(inputClip.fps or 15, 1, 60) }
	end
end

local alive = true
local state = "loading"
local soundOn = true
local animate = true
local motionOn = animate and not GuiService.ReducedMotionEnabled
local connections = {}
local loader, loaderShade, loaderBar, loaderBrand, video
local loaderAt, loaderJob
local cityJob, cityPath, cityAnimation, stageStep, stageClose
local preloadJob, titleJob
local hidTouchControls = false
local elapsed, cityClock = 0, 0
local closingAt
local selectedBeforeModal
local lastVoice = -math.huge
local voiceAt = math.huge
local glitchAt = -math.huge
local shownPhase = -1
local glitchTarget
local safeWidth, safeHeight, margin = 0, 0, 0
local stackX, stackY, stackW, stackH, titleH, titleY, buttonY, buttonW, rowH, firstH, gap
local profileX, profileY, profileW, profileH = 0, 0, 0, 0
local pet = { scale = 1, w = 142, h = 200, position = Vector2.new(), mode = "stand", spot = 1, active = false, reactAt = -math.huge }

local function connect(signal, handler)
	local connection = signal:Connect(handler)
	table.insert(connections, connection)
	return connection
end

local function sound(key, cooldown)
	local item = sounds[key]
	local now = os.clock()
	if not soundOn or not item or now < (cooldowns[key] or 0) then
		return false
	end
	cooldowns[key] = now + cooldown
	item.TimePosition = 0
	item:Play()
	return true
end

local function greet()
	if not soundOn or os.clock() < lastVoice + 27 then
		return
	end
	for _, key in { "hello_morning", "hello_late", "hello_miss" } do
		if sounds[key] and sounds[key].IsPlaying then
			return
		end
	end
	local hour = os.date("*t").hour
	local preferred = if hour >= 5 and hour < 12 then "hello_morning" elseif hour >= 22 or hour < 5 then "hello_late" else "hello_miss"
	for _, key in { preferred, "hello_miss", "hello_late", "hello_morning" } do
		if sounds[key] then
			lastVoice = os.clock()
			sound(key, 27)
			local length = sounds[key].TimeLength
			return key, if type(length) == "number" and length > 0.3 then length else 2.6
		end
	end
	return nil
end

local function changeStatus()
	soundStatus.Text = if soundOn then "Ativado" else "Silenciado"
	soundStatus.TextColor3 = if soundOn then PINK_LIGHT else MUTED
	motionStatus.Text = if motionOn then "Ativadas" else "Reduzidas"
	motionStatus.TextColor3 = if motionOn then PINK_LIGHT else MUTED
	local systemMotionLimit = GuiService.ReducedMotionEnabled
	motionToggle.Interactable = not systemMotionLimit
	motionToggle.Selectable = not systemMotionLimit
	close.NextSelectionUp = if state ~= "settings" then close elseif systemMotionLimit then soundToggle else motionToggle
	soundToggle.NextSelectionDown = if systemMotionLimit then close else motionToggle
	if systemMotionLimit and GuiService.SelectedObject == motionToggle then
		GuiService.SelectedObject = soundToggle
	end
end

local function refreshProfile()
	profileName.Text = player.DisplayName
	local level = player:GetAttribute("Level")
	if type(level) ~= "number" then
		local stats = player:FindFirstChild("leaderstats")
		local stored = stats and stats:FindFirstChild("Level")
		if stored and (stored:IsA("IntValue") or stored:IsA("NumberValue")) then
			level = stored.Value
		end
	end
	local validLevel = type(level) == "number" and level >= 0 and level <= 99999999
	profileLevel.Visible = validLevel
	profileLevel.Text = if validLevel then "Nível " .. math.floor(level) else ""
	profileName.Position = UDim2.fromOffset(53, if validLevel then 6 else 0)
	profileName.Size = UDim2.new(1, -105, validLevel and 0 or 1, if validLevel then 22 else 0)
end

local function rectOverlaps(x, y, w, h, x2, y2, w2, h2)
	return x < x2 + w2 and x + w > x2 and y < y2 + h2 and y + h > y2
end

local function clampPet(position)
	return Vector2.new(
		math.clamp(position.X, margin + pet.w / 2, math.max(margin + pet.w / 2, safeWidth - margin - pet.w / 2)),
		math.clamp(position.Y, margin + pet.h, math.max(margin + pet.h, safeHeight - margin))
	)
end

local function petFits(position)
	local left, top = position.X - pet.w / 2 - 4, position.Y - pet.h - 4
	local w, h = pet.w + 8, pet.h + 8
	if rectOverlaps(left, top, w, h, profileX, profileY, profileW, profileH) then
		return false
	end
	local scrolls = stack.CanvasSize.Y.Offset > stackH
	if scrolls then
		return not rectOverlaps(left, top, w, h, stackX, stackY, stackW, stackH)
	end
	return not rectOverlaps(left, top, w, h, stackX, stackY + titleY, stackW, titleH)
		and not rectOverlaps(left, top, w, h, stackX, stackY + buttonY, buttonW, firstH + 2 * rowH + 2 * gap)
end

local function spot(index)
	local right = safeWidth - margin - pet.w * 0.54
	local bottom = safeHeight - margin
	local nearButtons = stackX + buttonW + pet.w / 2 + 15
	local nearTitle = stackX + stackW + pet.w / 2 + 15
	local buttonsEnd = stackY + buttonY + firstH + 2 * rowH + 2 * gap
	local besideButtons = nearButtons + pet.w / 2 + margin <= safeWidth
	local options = {
		Vector2.new(right, bottom),
		if besideButtons then Vector2.new(nearButtons, buttonsEnd + 5)
			else Vector2.new(stackX + buttonW * 0.63, buttonsEnd + pet.h + 8),
		Vector2.new(right, safeHeight * 0.65),
		Vector2.new(nearTitle, safeHeight * 0.74),
		Vector2.new(math.max(safeWidth * 0.55, margin), bottom),
	}
	for offset = 0, #options - 1 do
		local candidate = clampPet(options[(index + offset - 1) % #options + 1])
		if not petFits(candidate) then
			continue
		end
		return candidate
	end
	return nil
end

local function poseBounds()
	local pose = pet.mode
	if pose == "resting" or pose == "asleep" then
		return 0.03, 0.45, 0.97, 0.51
	end
	if pose == "seated" then
		return 0.13, 0.20, 0.64, 0.80
	end
	return 0.26, 0.04, 0.53, 0.90
end

local function positionPet(position)
	pet.position = position
	sprite.Position = UDim2.fromOffset(position.X, position.Y)
	local x, y, w, h = poseBounds()
	local width, height = math.max(44, pet.w * w), math.max(44, pet.h * h)
	hit.Size = UDim2.fromOffset(width, height)
	hit.Position = UDim2.fromOffset(position.X + (x - 0.5) * pet.w + (pet.w * w - width) / 2, position.Y + (y - 1) * pet.h)
	sprite.Visible = pet.active and pet.body ~= nil
	hit.Visible = sprite.Visible and state == "main" and pet.mode ~= "travel"
end

local function drawSprite(label, frameData)
	label.ImageRectOffset = frameData.offset
	label.ImageRectSize = frameData.size
	if label.Image ~= frameData.uri then
		label.Image = frameData.uri
	end
end

local function body(name, looped, after)
	local clip = clips[name]
	if not clip then
		if after then
			after()
		end
		return
	end
	pet.body = { clip = clip, started = os.clock(), looping = looped, after = after, index = 1 }
	drawSprite(sprite, clip.frames[1])
	sprite.Size = UDim2.fromOffset(clip.frames[1].size.X * pet.scale, clip.frames[1].size.Y * pet.scale)
	positionPet(pet.position)
end

local function pose(name)
	pet.mode = name
	local desired = ({ stand = "idle", seated = "perch", resting = "laydown", asleep = "laydown_sleep", drag = "dangle" })[name]
	if not clips[desired] then
		desired = if name == "asleep" and clips.sleep then "sleep" else "idle"
	end
	body(desired, true)
	positionPet(pet.position)
	pet.blinkAt = os.clock() + rng:NextNumber(2.2, 4.9)
	pet.actAt = os.clock() + rng:NextNumber(6, 10)
end

local function goToSpot(index, nextPose)
	local nextPosition = spot(index)
	if not nextPosition or (nextPosition - pet.position).Magnitude < 14 then
		pose(nextPose)
		return
	end
	local leaving = if pet.mode == "seated" and clips.perch_leave then "perch_leave"
		elseif pet.mode == "resting" and clips.laydown_leave then "laydown_leave" else "leave"
	local arriving = if nextPose == "seated" and clips.perch_arrive then "perch_arrive" else "arrive"
	pet.mode = "travel"
	positionPet(pet.position)
	body(leaving, false, function()
		pet.spot = index
		local currentSpot = spot(index)
		if not currentSpot then
			pose(nextPose)
			return
		end
		positionPet(currentSpot)
		sound("glitch", 1.7)
		body(arriving, false, function()
			pose(nextPose)
		end)
	end)
end

local function react(tapped)
	local now = os.clock()
	if not pet.active or not motionOn or pet.mode == "travel" or pet.mode == "drag" or now < pet.reactAt + 0.57 then
		return
	end
	pet.reactAt = now
	local previous = pet.resume or pet.mode
	pet.resume = previous
	if previous == "resting" and tapped and clips.laydown_glitch and rng:NextNumber(0, 1) < 0.5 then
		sound("glitch", 1.7)
		body("laydown_glitch", false, function()
			pet.resume = nil
			pose(previous)
		end)
	elseif previous == "asleep" or previous == "resting" then
		body("wake", false, function()
			pet.resume = nil
			pose("stand")
		end)
	else
		local name
		pet.taps = (pet.taps or 0) + (if tapped then 1 else 0)
		if tapped and previous == "seated" and clips.perch_glitch then
			name = "perch_glitch"
			sound("glitch", 1.7)
		elseif tapped and pet.taps % 3 == 0 and clips.glitch then
			name = "glitch"
			sound("glitch", 1.7)
		elseif tapped then
			pet.danceNext = not pet.danceNext
			name = if pet.danceNext and clips.grin then "grin" else "dance"
		else
			name = if previous == "seated" and clips.perch_blink then "perch_blink" elseif clips.idle_blink then "idle_blink" else "blink"
		end
		body(name, false, function()
			pet.resume = nil
			pose(previous)
		end)
	end
end

local function layout()
	local measured = safe.AbsoluteSize
	if measured.X < 80 or measured.Y < 80 then
		return
	end
	safeWidth, safeHeight = measured.X, measured.Y
	local wide = safeWidth >= 520 and safeWidth / safeHeight >= 1.18
	local low = safeHeight < 390
	margin = math.floor(math.clamp(math.min(safeWidth, safeHeight) * 0.046, 10, 52))
	profileW = if wide and not low then math.floor(math.clamp(safeWidth * 0.17, 204, 246)) else math.floor(math.clamp(safeWidth * 0.46, 146, 190))
	profileH = if wide and not low then 54 else 48
	profileX = safeWidth - margin - profileW
	profileY = margin
	profile.Position = UDim2.fromOffset(safeWidth - margin, profileY)
	profile.Size = UDim2.fromOffset(profileW, profileH)

	stackX = if wide then math.floor(math.clamp(safeWidth * 0.0375, 16, 96)) else margin
	stackW = math.floor(math.min(safeWidth - stackX - margin, if wide then safeWidth * 0.39 else 480, 584))
	titleH = math.floor(math.clamp(stackW * 0.276, if low then 48 else 58, 160))
	titleY = 0
	firstH = if low then 46 else math.floor(math.clamp(safeHeight * 0.087, 47, 70))
	rowH = if low then 44 else math.floor(math.clamp(firstH - 8, 44, 62))
	gap = if low then 6 else 11
	buttonY = titleH + (if low then 8 elseif wide then 24 else 14)
	buttonW = math.floor(math.min(stackW, if wide then math.clamp(safeWidth * 0.258, 196, 386) else 328))
	local fullHeight = buttonY + firstH + 2 * rowH + 2 * gap + 2
	local minTop = if wide then margin else math.min(profileY + profileH + 14, safeHeight - 60)
	stackH = math.min(safeHeight - minTop - margin, fullHeight)
	local preferredY = if wide then safeHeight * 0.086 else minTop
	stackY = math.floor(math.clamp(preferredY, minTop, math.max(minTop, safeHeight - stackH - margin)))
	stack.Position = UDim2.fromOffset(stackX, stackY)
	stack.Size = UDim2.fromOffset(stackW + 2, stackH)
	stack.CanvasSize = UDim2.fromOffset(0, fullHeight)
	stack.ScrollingEnabled = stackH < fullHeight
	stack.ScrollBarThickness = if stack.ScrollingEnabled then 3 else 0
	brand.Position = UDim2.fromOffset(0, titleY)
	brand.Size = UDim2.fromOffset(stackW, titleH)
	title.Position = UDim2.fromScale(0.01, 0.09)
	title.Size = UDim2.fromScale(0.97, 0.82)
	title.Rotation = -5
	for _, mark in marks do
		local delta = mark.b - mark.a
		local slope = Vector2.new(delta.X * stackW, delta.Y * titleH)
		local midpoint = (mark.a + mark.b) / 2
		mark.ink.Position = UDim2.fromScale(midpoint.X, midpoint.Y)
		mark.ink.Size = UDim2.fromOffset(slope.Magnitude, math.max(1, titleH * mark.weight))
		mark.ink.Rotation = math.deg(math.atan2(slope.Y, slope.X))
	end
	for _, ghost in { ghostMagenta, ghostCyan } do
		ghost.Size = title.Size
		ghost.Rotation = title.Rotation
	end
	local y = buttonY
	for index, config in buttons do
		local h = if index == 1 then firstH else rowH
		config.item.Size = UDim2.fromOffset(buttonW, h)
		config.item.Position = UDim2.fromOffset(0, y)
		config.text.Position = UDim2.fromOffset(if low then 46 else 55, 0)
		config.text.Size = UDim2.new(1, if low then -61 else -69, 1, 0)
		config.text.TextSize = if config.primary then (if low then 18 else 22) elseif low then 15 else 17
		config.tint.Position = config.text.Position
		config.tint.Size = config.text.Size
		config.tint.TextSize = config.text.TextSize
		y += h + gap
	end
	local cardWidth = math.min(safeWidth - margin * 2, 435)
	local cardHeight = math.min(safeHeight - margin * 2, if state == "credits" then 283 else 191)
	card.Size = UDim2.fromOffset(cardWidth, cardHeight)
	if loaderBrand then
		loaderBrand.Size = UDim2.fromOffset(math.min(420, safeWidth - margin * 3), 60)
	end

	veil.Rotation = if wide then 0 else 90
	veil.Transparency = if wide then NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(0.29, 0.15),
		NumberSequenceKeypoint.new(0.45, 0.50), NumberSequenceKeypoint.new(0.64, 0.90),
		NumberSequenceKeypoint.new(1, 0.98),
	}) else NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.21), NumberSequenceKeypoint.new(0.38, 0.20),
		NumberSequenceKeypoint.new(0.56, 0.58), NumberSequenceKeypoint.new(1, 0.93),
	})

	pet.h = math.min(470, safeHeight * (if wide then 0.65 else 0.53), safeWidth * 0.82)
	local roomBelowButtons = safeHeight - margin - stackY - stackH - 8
	if not wide and roomBelowButtons >= 56 then
		pet.h = math.min(pet.h, roomBelowButtons)
	end
	pet.w = pet.h * 0.71
	pet.scale = pet.h / 200
	local previous = clampPet(pet.position)
	local place = if pet.active and petFits(previous) then previous else spot(pet.spot)
	pet.active = clips.idle ~= nil and place ~= nil
	if place then
		positionPet(place)
	end
	if pet.body then
		local size = pet.body.clip.frames[pet.body.index].size
		sprite.Size = UDim2.fromOffset(size.X * pet.scale, size.Y * pet.scale)
	end
	if not pet.active then
		hit.Visible = false
		sprite.Visible = false
	end
	shownPhase = -1
end

local function applyGlitch(phase)
	local ax, ay, bx, by, cut = 1, 1, -1, 0, 0
	if phase == 1 then
		ax, ay, bx, by, cut = 6, -2, -4, 2, -8
	elseif phase == 2 then
		ax, ay, bx, by, cut = -3, 2, 4, -1, 6
	elseif phase == 3 then
		ax, ay, bx, by, cut = 2, 0, -2, 1, -3
	end
	local hasArt = titleUri ~= "" and (logo.IsLoaded or titleFetched)
	logoBack.Visible = hasArt and phase ~= 0
	logoLight.Visible = hasArt and phase ~= 0
	logoBack.Position = UDim2.fromOffset(ax, ay)
	logoLight.Position = UDim2.fromOffset(bx, by)
	logoBack.ImageTransparency = 0.26
	logoLight.ImageTransparency = 0.51
	title.Visible = not hasArt
	ghostMagenta.Visible = not hasArt
	ghostCyan.Visible = not hasArt
	for _, mark in marks do
		mark.ink.Visible = not hasArt
	end
	ghostMagenta.Position = title.Position + UDim2.fromOffset(ax, ay)
	ghostCyan.Position = title.Position + UDim2.fromOffset(bx, by)
	ghostMagenta.TextTransparency = if phase == 0 then 0.48 else 0.12
	ghostCyan.TextTransparency = if phase == 0 then 0.62 else 0.23
	for index, slice in slices do
		local y = math.floor((titleH or 0) * slice.y)
		slice.strip.Visible = cut ~= 0 and not hasArt
		slice.strip.Position = UDim2.fromOffset(0, y)
		slice.strip.Size = UDim2.new(1, 0, 0, if index == 1 then 4 else 3)
		slice.label.Position = UDim2.fromOffset(cut * (if index == 1 then 1 else -1), -y)
		slice.label.Size = UDim2.new(1, 0, 0, titleH or 0)
	end
	for _, config in buttons do
		local active = config == glitchTarget and phase ~= 0
		config.tint.Visible = active
		config.tint.Position = config.text.Position + UDim2.fromOffset(if active then ax / 2 else 0, 0)
		config.rail.BackgroundTransparency = if active or config.hovered then 0 else 1
	end
end

local function glitch(target)
	if motionOn and os.clock() >= glitchAt + 0.37 then
		glitchAt = os.clock()
		glitchTarget = target
	end
end

local function refreshButton(config)
	local hovered = config.hovered or GuiService.SelectedObject == config.item
	paint(config.stroke, if hovered then PINK_LIGHT elseif config.primary then MAGENTA else SMOKE_EDGE)
	paint(config.face, if config.primary then (if hovered then Color3.fromRGB(226, 16, 111) else PLAY_FACE)
		elseif hovered then Color3.fromRGB(36, 21, 35) else SURFACE)
	config.rail.BackgroundTransparency = if hovered then 0 else 1
	config.icon.Position = UDim2.new(0, if hovered and motionOn then 21 else 19, 0.5, 0)
	config.detail.Size = UDim2.fromOffset(if hovered then 13 else 10, 2)
end

local function focusMain(preferred)
	if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
		GuiService.SelectedObject = preferred or play.item
	end
end

local function cancelDrag()
	local pointer = pet.pointer
	pet.pointer = nil
	if pointer and pointer.moved then
		pet.resume = nil
		pose("stand")
	end
end

local function panel(kind, source)
	if state ~= "main" then
		return
	end
	cancelDrag()
	react(false)
	state = kind
	selectedBeforeModal = source
	modal.Visible = true
	heading.Text = if kind == "settings" then "Configurações" else "Créditos"
	preferences.Visible = kind == "settings"
	notice.Visible = kind == "credits"
	close.NextSelectionDown = if kind == "settings" then soundToggle else close
	soundToggle.NextSelectionUp = close
	motionToggle.NextSelectionUp = soundToggle
	motionToggle.NextSelectionDown = close
	changeStatus()
	for _, config in buttons do
		config.item.Selectable = false
	end
	profileSettings.Selectable = false
	cardBody.CanvasSize = UDim2.fromOffset(0, if kind == "settings" then 112 else 209)
	cardBody.CanvasPosition = Vector2.new()
	layout()
	positionPet(pet.position)
	if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
		GuiService.SelectedObject = if kind == "settings" then soundToggle else close
	end
end

local function closePanel()
	if not modal.Visible then
		return
	end
	modal.Visible = false
	state = "main"
	for _, config in buttons do
		config.item.Selectable = true
	end
	profileSettings.Selectable = true
	changeStatus()
	positionPet(pet.position)
	focusMain(selectedBeforeModal)
end

local function startVideo()
	if not alive or not video or not video.IsLoaded or state ~= "loading" or not motionOn or not loaderAt then
		return
	end
	if os.clock() - loaderAt < LOADER_SECONDS - 0.30 then
		video.Visible = true
		video:Play()
	end
end

local function changeMotion()
	local earlier = motionOn
	motionOn = animate and not GuiService.ReducedMotionEnabled
	changeStatus()
	if earlier == motionOn then
		return
	end
	if video and not motionOn then
		video:Pause()
		video.Visible = false
	elseif video then
		startVideo()
	end
	glitchAt = -math.huge
	applyGlitch(0)
	cityClock = 0
	if pet.active and not motionOn then
		pet.resume = nil
		pet.effect = nil
		clickSprite.Visible = false
		pose("stand")
	end
	if pet.body then
		pet.body.started = os.clock()
	end
end

local function finishLoader()
	if not alive or state ~= "loading" then
		return
	end
	loaderJob = nil
	if video then
		video:Pause()
		video:Destroy()
		video = nil
	end
	if loader then
		loader:Destroy()
		loaderShade:Destroy()
		loader, loaderShade, loaderBrand, loaderBar = nil, nil, nil, nil
	end
	state = "main"
	if music and musicOn and soundOn and not music.IsPlaying then
		music:Play()
	end
	stack.Visible = true
	petLayer.Visible = true
	profile.Visible = true
	refreshProfile()
	layout()
	pose("stand")
	if pet.active and motionOn then
		pet.mode = "travel"
		body("arrive", false, function()
			pose("stand")
		end)
	end
	glitch(nil)
	voiceAt = os.clock() + 1.4
	focusMain()
end

local function freePreloadImages()
	for _, probe in preloadImages do
		probe:Destroy()
	end
	table.clear(preloadImages)
	table.clear(preloadAssets)
end

local function cleanup(started)
	if not alive then
		return
	end
	alive = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if loaderJob then
		task.cancel(loaderJob)
	end
	if cityJob then
		task.cancel(cityJob)
	end
	if preloadJob then
		task.cancel(preloadJob)
	end
	if titleJob then
		task.cancel(titleJob)
	end
	freePreloadImages()
	if video then
		video:Pause()
	end
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(safeGui) then
		GuiService.SelectedObject = nil
	end
	if stageClose then
		pcall(stageClose)
		stageClose = nil
	end
	if hidTouchControls then
		pcall(function() GuiService.TouchControlsEnabled = true end)
	end
	ContextActionService:UnbindAction(ACTION)
	if started then
		player:SetAttribute("CyberOutlawMenuStarted", true)
	end
	player:SetAttribute("CyberOutlawMenuOpen", false)
	setFolder:Destroy()
	safeGui:Destroy()
	backdrop:Destroy()
	if started then
		mountCyberOutlawHud()
	end
end

local function activate(config)
	if state ~= "main" then
		return
	end
	glitch(config)
	if config == play then
		local played = sound("confirm", 1)
		cancelDrag()
		react(true)
		state = "closing"
		for _, entry in buttons do
			entry.item.Selectable = false
		end
		profileSettings.Selectable = false
		hit.Visible = false
		if not (motionOn or played) then
			cleanup(true)
		else
			closingAt = os.clock() + EXIT_SECONDS
		end
	else
		sound("click", 0.08)
		panel(if config == settings then "settings" else "credits", config.item)
	end
end

for _, config in buttons do
	connect(config.item.Activated, function()
		activate(config)
	end)
	connect(config.item.MouseEnter, function()
		if state == "main" then
			config.hovered = true
			refreshButton(config)
			glitch(config)
			react(false)
		end
	end)
	connect(config.item.MouseLeave, function()
		config.hovered = false
		refreshButton(config)
	end)
	connect(config.item.SelectionGained, function()
		refreshButton(config)
		glitch(config)
	end)
	connect(config.item.SelectionLost, function()
		refreshButton(config)
	end)
end

connect(profileSettings.Activated, function()
	if state == "main" then
		sound("click", 0.08)
		glitch(settings)
		panel("settings", profileSettings)
	end
end)
for _, event in { profileSettings.MouseEnter, profileSettings.SelectionGained } do
	connect(event, function()
		if state == "main" then
			profileSettings.BackgroundTransparency = 0.30
		end
	end)
end
for _, event in { profileSettings.MouseLeave, profileSettings.SelectionLost } do
	connect(event, function()
		profileSettings.BackgroundTransparency = 1
	end)
end

connect(soundToggle.Activated, function()
	if state ~= "settings" then
		return
	end
	soundOn = not soundOn
	if soundOn then
		sound("click", 0)
		if music and musicOn and state ~= "loading" then
			music:Play()
		end
	else
		for _, item in sounds do
			item:Stop()
		end
		if music then
			music:Stop()
		end
	end
	changeStatus()
end)

-- Botão ♪ (só aparece com a música aprovada): liga e desliga a música; ao ligar, a Capri reage.
if music then
	local musicButton = make("TextButton", safe, "MusicaDoMenu", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -16), Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = INK, BackgroundTransparency = 0.18, BorderSizePixel = 0, AutoButtonColor = true,
		Text = "♪", FontFace = BOLD, TextSize = 24, TextColor3 = PINK_LIGHT, ZIndex = 30,
	})
	make("UICorner", musicButton, "Canto", { CornerRadius = UDim.new(1, 0) })
	local musicEdge = make("UIStroke", musicButton, "Borda", { Color = PINK_LIGHT, Thickness = 1.5, Transparency = 0.2 })
	local function showMusic()
		musicButton.TextTransparency = if musicOn then 0 else 0.55
		musicEdge.Transparency = if musicOn then 0.2 else 0.7
	end
	connect(musicButton.Activated, function()
		musicOn = not musicOn
		sound("click", 0)
		if musicOn and soundOn and state ~= "loading" then
			music:Play()
			-- Ela curte a música: sentada fica ouvindo, em pé dança um pouco.
			if pet.active and motionOn and not pet.resume and pet.mode ~= "travel" and pet.mode ~= "drag" then
				local returnPose = pet.mode
				local name = if returnPose == "seated" and clips.perch_music then "perch_music"
					elseif returnPose == "stand" and clips.dance then "dance" else nil
				if name then
					pet.resume = returnPose
					body(name, true)
					task.delay(if name == "dance" then 5 else 9, function()
						if pet.resume == returnPose and pet.body and pet.body.clip == clips[name] then
							pet.resume = nil
							pose(returnPose)
						end
					end)
				end
			end
		else
			music:Stop()
		end
		showMusic()
	end)
	showMusic()
end

connect(motionToggle.Activated, function()
	if state == "settings" and not GuiService.ReducedMotionEnabled then
		animate = not animate
		sound("click", 0.08)
		changeMotion()
	end
end)

connect(close.Activated, function()
	if modal.Visible then
		sound("click", 0.08)
		closePanel()
	end
end)

local function cursor(input)
	return Vector2.new(input.Position.X, input.Position.Y)
end

connect(hit.InputBegan, function(input)
	local kind = input.UserInputType
	if state ~= "main" or not hit.Visible or pet.pointer or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) then
		return
	end
	pet.pointer = { input = input, start = cursor(input), bodyStart = pet.position, moved = false }
end)

connect(hit.MouseEnter, function()
	if state == "main" and not pet.pointer then
		react(false)
	end
end)

local function endDrag(cancelled)
	local pointer = pet.pointer
	if not pointer then
		return
	end
	pet.pointer = nil
	if pointer.moved then
		pet.resume = nil
		pose("stand")
	elseif not cancelled and state == "main" then
		local effect = clips.click
		if effect and motionOn then
			pet.effect = { clip = effect, started = os.clock(), index = 1 }
			clickSprite.Position = hit.Position + UDim2.fromOffset(hit.Size.X.Offset / 2, hit.Size.Y.Offset / 3)
			clickSprite.Visible = true
			drawSprite(clickSprite, effect.frames[1])
		end
		sound("react", 0.55)
		greet()
		react(true)
	end
end

connect(UserInputService.InputChanged, function(input)
	local pointer = pet.pointer
	if not pointer then
		return
	end
	local touch = pointer.input.UserInputType == Enum.UserInputType.Touch
	if (touch and input ~= pointer.input) or (not touch and input.UserInputType ~= Enum.UserInputType.MouseMovement) then
		return
	end
	if input.UserInputState == Enum.UserInputState.Cancel then
		endDrag(true)
		return
	end
	local delta = cursor(input) - pointer.start
	if not pointer.moved and delta.Magnitude >= 7 then
		pointer.moved = true
		pet.resume = nil
		if motionOn then
			pose("drag")
		end
	end
	if not pointer.moved then
		return
	end
	local position = clampPet(pointer.bodyStart + delta)
	if not petFits(position) then
		local alongX = Vector2.new(position.X, pet.position.Y)
		local alongY = Vector2.new(pet.position.X, position.Y)
		position = if petFits(alongX) then alongX elseif petFits(alongY) then alongY else pet.position
	end
	positionPet(position)
end)

connect(UserInputService.InputEnded, function(input)
	local pointer = pet.pointer
	if not pointer then
		return
	end
	local sameMouse = pointer.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
	if input == pointer.input or sameMouse then
		endDrag(input.UserInputState == Enum.UserInputState.Cancel)
	end
end)

connect(UserInputService.WindowFocusReleased, function()
	endDrag(true)
end)

connect(UserInputService.InputBegan, function(input, processed)
	if modal.Visible and (input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.Escape)) then
		closePanel()
	end
end)

connect(UserInputService:GetPropertyChangedSignal("PreferredInput"), function()
	if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
		endDrag(true)
		if modal.Visible then
			GuiService.SelectedObject = if state == "settings" then soundToggle else close
		elseif state == "main" then
			focusMain()
		end
	else
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(safeGui) then
			GuiService.SelectedObject = nil
		end
	end
end)

connect(GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"), changeMotion)
connect(safe:GetPropertyChangedSignal("AbsoluteSize"), layout)
connect(logo:GetPropertyChangedSignal("IsLoaded"), function()
	shownPhase = -1
end)
connect(player:GetPropertyChangedSignal("DisplayName"), refreshProfile)
connect(player:GetAttributeChangedSignal("Level"), refreshProfile)
connect(view:GetAttributeChangedSignal("CyberOutlawWorkspaceStage"), function()
	background.BackgroundTransparency = if view:GetAttribute("CyberOutlawWorkspaceStage") == true then 1 else 0
end)
connect(script.Destroying, function()
	cleanup(false)
end)
connect(backdrop.Destroying, function()
	cleanup(false)
end)
connect(safeGui.Destroying, function()
	cleanup(false)
end)

local function stepSprite(animation, label, now)
	local nextIndex = math.floor((now - animation.started) * animation.clip.fps) + 1
	local count = #animation.clip.frames
	if nextIndex > count then
		if not animation.looping then
			return false
		end
		nextIndex = (nextIndex - 1) % count + 1
	end
	if nextIndex ~= animation.index then
		animation.index = nextIndex
		drawSprite(label, animation.clip.frames[nextIndex])
	end
	return true
end

local function updatePet(now)
	local animation = pet.body
	if animation and not stepSprite(animation, sprite, now) then
		if animation.after then
			animation.after()
		else
			pet.body = nil
		end
	end
	if pet.effect and not stepSprite(pet.effect, clickSprite, now) then
		pet.effect = nil
		clickSprite.Visible = false
	end
	if state ~= "main" or pet.pointer or pet.mode == "travel" or pet.resume then
		return
	end
	if now >= voiceAt then
		voiceAt = math.huge
		local voice, length = greet()
		-- Enquanto a voz toca, ela fala na pose em que está (boca mexendo sentada, deitada ou em pé).
		local talk = ({ seated = "perch_talk", resting = "laydown_talk", stand = "idle_mouth" })[pet.mode]
		if voice and talk and clips[talk] and motionOn then
			local returnPose, actionTime = pet.mode, pet.actAt
			pet.resume = returnPose
			body(talk, true)
			task.delay(length, function()
				if pet.resume == returnPose and pet.body and pet.body.clip == clips[talk] then
					pet.resume = nil
					pose(returnPose)
					pet.actAt = actionTime
				end
			end)
			return
		end
	end
	if now >= (pet.actAt or math.huge) then
		if pet.mode == "stand" then
			goToSpot(if pet.spot == 2 then 3 else 2, "seated")
		elseif pet.mode == "seated" and clips.perch_music and not pet.listened
			and rng:NextNumber(0, 1) < (if music and music.IsPlaying then 0.9 else 0.45) then
			-- Sentada, às vezes ela coloca uma música e fica curtindo antes de deitar.
			pet.listened = true
			pet.resume = "seated"
			body("perch_music", true)
			task.delay(rng:NextNumber(6, 9), function()
				if pet.resume == "seated" and pet.body and pet.body.clip == clips.perch_music then
					pet.resume = nil
					pose("seated")
				end
			end)
		elseif pet.mode == "seated" then
			pet.listened = false
			goToSpot(1, "resting")
		elseif pet.mode == "resting" then
			pose("asleep")
		elseif pet.mode == "asleep" then
			react(false)
		end
	elseif now >= (pet.blinkAt or math.huge) then
		pet.blinkAt = now + rng:NextNumber(3, 5.6)
		local name = if pet.mode == "seated" then "perch_blink"
			elseif pet.mode == "resting" then "laydown_blink" elseif pet.mode == "stand" then (if clips.idle_blink then "idle_blink" else "blink") else nil
		-- De vez em quando a piscada sai com glitch (as versões glitch de cada pose).
		if name and rng:NextNumber(0, 1) < 0.22 then
			local glitchy = ({ perch_blink = "perch_blink_glitch", laydown_blink = "laydown_blink_glitch",
				idle_blink = "idle_blink_glitch", blink = "blink_glitch" })[name]
			if glitchy and clips[glitchy] then
				name = glitchy
			end
		end
		if name and clips[name] then
			local returnPose = pet.mode
			local actionTime = pet.actAt
			body(name, false, function()
				pose(returnPose)
				pet.actAt = actionTime
			end)
		end
	end
end

local function fallbackCity()
	if type(createCyberCity) ~= "function" then
		return
	end
	local ok, _, path, animateCity = pcall(createCyberCity, world, {})
	if alive and ok and type(path) == "function" then
		cityPath = path
		cityAnimation = if type(animateCity) == "function" then animateCity else nil
	end
end

local function updateCity(seconds)
	if stageStep then
		local ok = pcall(stageStep, seconds)
		if ok then
			return
		end
		stageStep = nil
		if stageClose then
			pcall(stageClose)
			stageClose = nil
		end
		view:SetAttribute("CyberOutlawWorkspaceStage", false)
		fallbackCity()
	end
	if not cityPath then
		return
	end
	local size = view.AbsoluteSize
	local ratio = if size.X > 0 and size.Y > 0 then size.X / size.Y else 16 / 9
	local ok, transform = pcall(cityPath, seconds, ratio)
	if ok and typeof(transform) == "CFrame" then
		camera.CFrame = transform
		view.ImageTransparency = 0
		if cityAnimation then
			pcall(cityAnimation, seconds)
		end
	else
		cityPath = nil
		view.ImageTransparency = 1
	end
end

local exit = frame(backdrop, "Exit", 50, { Size = FULL, BackgroundColor3 = INK, BackgroundTransparency = 1 })
local nextGlitchAt = math.huge
connect(RunService.Heartbeat, function(dt)
	local now = os.clock()
	if motionOn then
		elapsed += dt
		cityClock += dt
		if cityClock >= 1 / 30 then
			cityClock %= 1 / 30
			updateCity(elapsed)
		end
	elseif (cityPath or stageStep) and elapsed ~= 0 then
		elapsed = 0
		updateCity(0)
	end
	if state == "loading" then
		if loaderBar and loaderAt then
			loaderBar.Size = UDim2.fromScale(math.clamp((now - loaderAt) / LOADER_SECONDS, 0, 1), 1)
		end
		return
	end
	if state == "closing" and closingAt then
		if motionOn then
			local alpha = math.clamp(1 - (closingAt - now) / EXIT_SECONDS, 0, 1)
			exit.BackgroundTransparency = 1 - alpha
			if alpha > 0.76 then
				stack.Visible = false
				petLayer.Visible = false
				profile.Visible = false
			end
		end
		if now >= closingAt then
			cleanup(true)
			return
		end
	elseif state == "main" and motionOn then
		if nextGlitchAt == math.huge then
			nextGlitchAt = now + rng:NextNumber(11, 17)
		elseif now >= nextGlitchAt then
			glitch(nil)
			nextGlitchAt = now + rng:NextNumber(18, 27)
		end
	end
	local progress = now - glitchAt
	local phase = if motionOn and progress < 0.20 then math.min(3, math.floor(progress / 0.065) + 1) else 0
	if phase ~= shownPhase then
		shownPhase = phase
		applyGlitch(phase)
	end
	if motionOn and pet.active then
		updatePet(now)
	elseif state == "main" and now >= voiceAt then
		voiceAt = math.huge
		greet()
	end
end)

if not player:GetAttribute("CyberOutlawLoaderSeen") then
	loaderShade = frame(backdrop, "LoaderShade", 6, {
		Size = FULL, BackgroundTransparency = 0.31, BackgroundColor3 = INK,
	})
	local movie = asset(ASSETS.video)
	if movie ~= "" then
		video = make("VideoFrame", loaderShade, "LoadingVideo", {
			ZIndex = 8, Video = movie, Volume = 0, Looped = false, Playing = false, Visible = false,
			AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = FULL,
			BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0, BorderSizePixel = 0,
		})
		make("UIAspectRatioConstraint", video, "VideoAspect", { AspectRatio = 16 / 9, AspectType = Enum.AspectType.FitWithinMaxSize })
		connect(video.Loaded, startVideo)
		connect(video.Ended, function()
			if video and video.TimeLength > 0 then
				video:Pause()
				video.TimePosition = math.max(0, video.TimeLength - 0.04)
			end
		end)
	end
	loader = frame(safe, "Loader", 60, { Size = FULL })
	loaderBrand = text(loader, "Title", TITLE, 62, WORDMARK, 50, MAGENTA)
	loaderBrand.AnchorPoint = Vector2.new(0, 1)
	loaderBrand.Position = UDim2.new(0.065, 0, 0.90, -30)
	loaderBrand.Size = UDim2.fromOffset(348, 60)
	loaderBrand.TextScaled = true
	loaderBrand.TextStrokeColor3 = INK
	loaderBrand.TextStrokeTransparency = 0.36
	make("UITextSizeConstraint", loaderBrand, "SizeLimit", { MinTextSize = 18, MaxTextSize = 52 })
	local loadingText = text(loader, "Message", "Carregando", 62, BOLD, 14, WHITE)
	loadingText.TextStrokeColor3 = INK
	loadingText.TextStrokeTransparency = 0.24
	loadingText.Position = UDim2.new(0.065, 0, 0.90, -26)
	loadingText.Size = UDim2.fromOffset(202, 22)
	local track = frame(loader, "LoadingLine", 62, {
		Size = UDim2.fromScale(0.87, 0), Position = UDim2.fromScale(0.065, 0.90),
		BackgroundColor3 = SURFACE, BackgroundTransparency = 0,
	})
	track.Size = UDim2.new(0.87, 0, 0, 3)
	loaderBar = frame(track, "Progress", 63, {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = MAGENTA, BackgroundTransparency = 0,
	})
	gradient(loaderBar, 0, PINK_SHADOW, PINK_LIGHT)
end

changeStatus()
backdrop.Parent = playerGui
safeGui.Parent = playerGui
player:SetAttribute("CyberOutlawMenuOpen", true)
pcall(function()
	if GuiService.TouchControlsEnabled then
		GuiService.TouchControlsEnabled = false
		hidTouchControls = true
	end
end)
ContextActionService:BindActionAtPriority(ACTION, function()
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, table.unpack(Enum.PlayerActions:GetEnumItems()))
layout()

if loader then
	loaderAt = os.clock()
	player:SetAttribute("CyberOutlawLoaderSeen", true)
	loaderJob = task.delay(LOADER_SECONDS, finishLoader)
	startVideo()
else
	finishLoader()
end

-- Start the local stage after the loader mounts, with the viewport as fallback.
if type(openCyberOutlawScene) == "function" or type(createCyberCity) == "function" then
	cityJob = task.defer(function()
		cityJob = nil
		if type(openCyberOutlawScene) == "function" then
			local ok, step, closeScene = pcall(openCyberOutlawScene, ASSETS, view, world, camera)
			if ok and type(step) == "function" and type(closeScene) == "function" then
				if alive then
					stageStep, stageClose = step, closeScene
					updateCity(0)
				else
					pcall(closeScene)
				end
				return
			elseif ok and type(closeScene) == "function" then
				pcall(closeScene)
			end
		end
		if alive then
			view:SetAttribute("CyberOutlawWorkspaceStage", false)
			fallbackCity()
			updateCity(0)
		end
	end)
end
if titleUri ~= "" then
	titleJob = task.defer(function()
		pcall(function()
			ContentProvider:PreloadAsync({ titleUri }, function(_, status)
				if alive and status == Enum.AssetFetchStatus.Success then
					titleFetched = true
					shownPhase = -1
				end
			end)
		end)
		titleJob = nil
	end)
end
if #preloadAssets > 0 then
	preloadJob = task.defer(function()
		pcall(function()
			ContentProvider:PreloadAsync(preloadAssets)
		end)
		preloadJob = nil
		freePreloadImages()
	end)
end
