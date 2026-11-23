-- Exporta o HUD real do CyberOutlawPlay (Instances de verdade) para a prévia em HTML.
-- Uso: lune run tools/hud_preview.luau <pasta de saída>
-- Para cada aparelho, monta HUD, mira, cartão da arma, botões de toque e a roleta aberta, resolve
-- UDim2, AnchorPoint e UIScale em pixels da tela e grava um JSON por cena.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local output = process.args[1] or "hud_preview"
local V2, V3 = roblox.Vector2, roblox.Vector3

local function load(media: string)
	local source = fs.readFile("src/play.client.luau"):gsub("__CYBEROUTLAW_MEDIA__", media)
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
local play = load("{icones = 123}")
local arsenal = luau.load(fs.readFile("src/arsenal.server.luau"), {
	debugName = "arsenal.server.luau",
	environment = { Instance = roblox.Instance, CFrame = roblox.CFrame, Vector3 = roblox.Vector3, Color3 = roblox.Color3, Enum = roblox.Enum },
})()
local normals = { Front = V3.new(0, 0, -1) }
local _, _, layoutData = luau.load(fs.readFile("src/world.server.luau"):gsub("__CYBEROUTLAW_ART__", "{}"), {
	debugName = "world.server.luau",
	environment = {
		Instance = roblox.Instance, CFrame = roblox.CFrame, Vector2 = roblox.Vector2, Color3 = roblox.Color3,
		Vector3 = setmetatable({ FromNormalId = function(face) return normals[face.Name] end }, { __index = roblox.Vector3 }),
		ColorSequence = roblox.ColorSequence, Enum = roblox.Enum, UDim2 = roblox.UDim2, Font = roblox.Font, Content = roblox.Content,
	},
})()
local city = layoutData()
local defs = {}
for _, def in arsenal.WEAPONS do
	table.insert(defs, def)
end

-- Lune só lê propriedades que foram definidas ou têm padrão conhecido.
local function prop(node, key: string, default)
	local ok, value = pcall(function()
		return node[key]
	end)
	return if ok and value ~= nil then value else default
end

local function color(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

-- Resolve um GuiObject: retângulo absoluto (com UIScale em volta do AnchorPoint) e estilo.
local function export(node, parentX, parentY, parentW, parentH, inherited)
	local own = node:FindFirstChildOfClass("UIScale")
	local s = if own then own.Scale else 1
	local size, pos, anchor = prop(node, "Size", roblox.UDim2.new()), prop(node, "Position", roblox.UDim2.new()), prop(node, "AnchorPoint", V2.zero)
	local w = (parentW * size.X.Scale + size.X.Offset * inherited) * s
	local h = (parentH * size.Y.Scale + size.Y.Offset * inherited) * s
	local x = parentX + parentW * pos.X.Scale + pos.X.Offset * inherited - anchor.X * w
	local y = parentY + parentH * pos.Y.Scale + pos.Y.Offset * inherited - anchor.Y * h
	local scale = inherited * s
	local row = { k = node.ClassName, n = node.Name, r = { x, y, w, h }, z = prop(node, "ZIndex", 1), rot = prop(node, "Rotation", 0),
		v = prop(node, "Visible", true), clip = prop(node, "ClipsDescendants", false) }
	local bt = prop(node, "BackgroundTransparency", 0)
	if bt < 1 then
		row.bg, row.bt = color(prop(node, "BackgroundColor3", roblox.Color3.new(0.64, 0.64, 0.64))), bt
	end
	local corner = node:FindFirstChildOfClass("UICorner")
	if corner then
		row.radius = corner.CornerRadius.Scale * math.min(w, h) + corner.CornerRadius.Offset * scale
	end
	local stroke = node:FindFirstChildOfClass("UIStroke")
	if stroke and prop(stroke, "Enabled", true) then
		row.stroke = { color(prop(stroke, "Color", roblox.Color3.new())), prop(stroke, "Transparency", 0), prop(stroke, "Thickness", 1) * scale }
	end
	local gradient = node:FindFirstChildOfClass("UIGradient")
	if gradient then
		local colors, alphas = {}, {}
		local colorSeq = prop(gradient, "Color", roblox.ColorSequence.new(roblox.Color3.new(1, 1, 1)))
		local alphaSeq = prop(gradient, "Transparency", roblox.NumberSequence.new(0))
		for _, key in colorSeq.Keypoints do
			table.insert(colors, { key.Time, table.unpack(color(key.Value)) })
		end
		for _, key in alphaSeq.Keypoints do
			table.insert(alphas, { key.Time, key.Value })
		end
		row.grad = { c = colors, t = alphas, rot = prop(gradient, "Rotation", 0) }
	end
	if node:IsA("TextLabel") or node:IsA("TextButton") then
		local text = prop(node, "Text", "")
		if text ~= "" then
			local face = prop(node, "FontFace", roblox.Font.fromEnum(roblox.Enum.Font.SourceSans))
			row.text = text
			row.font = { face.Family, face.Weight.Value }
			row.ts = prop(node, "TextSize", 14) * scale
			row.tc, row.tt = color(prop(node, "TextColor3", roblox.Color3.new())), prop(node, "TextTransparency", 0)
			row.ax = prop(node, "TextXAlignment", roblox.Enum.TextXAlignment.Center).Name
			row.ay = prop(node, "TextYAlignment", roblox.Enum.TextYAlignment.Center).Name
			row.rich = prop(node, "RichText", false)
			row.scaled = prop(node, "TextScaled", false)
			local tst = prop(node, "TextStrokeTransparency", 1)
			if tst < 1 then
				row.tsc, row.tst = color(prop(node, "TextStrokeColor3", roblox.Color3.new())), tst
			end
		end
	elseif node:IsA("ImageLabel") or node:IsA("ImageButton") then
		local offset, rect = prop(node, "ImageRectOffset", V2.zero), prop(node, "ImageRectSize", V2.zero)
		row.img = prop(node, "Image", "")
		row.io = { offset.X, offset.Y, rect.X, rect.Y }
		row.ic, row.it = color(prop(node, "ImageColor3", roblox.Color3.new(1, 1, 1))), prop(node, "ImageTransparency", 0)
	elseif node:IsA("ViewportFrame") then
		row.viewport = true
	end
	row.children = {}
	for _, child in node:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(row.children, export(child, x, y, w, h, scale))
		end
	end
	return row
end

local function screenGui(gui, screen: Vector2, insets)
	local x, y, w, h = 0, 0, screen.X, screen.Y
	if not prop(gui, "IgnoreGuiInset", false) and prop(gui, "ScreenInsets", roblox.Enum.ScreenInsets.CoreUISafeInsets) ~= roblox.Enum.ScreenInsets.None then
		x, y = insets.left, insets.top
		w, h = screen.X - insets.left - insets.right, screen.Y - insets.top - insets.bottom
	end
	local rows = {}
	for _, child in gui:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(rows, export(child, x, y, w, h, 1))
		end
	end
	return { name = gui.Name, order = prop(gui, "DisplayOrder", 0), enabled = prop(gui, "Enabled", true), items = rows }
end

local devices = {
	{ name = "pc_1080", screen = V2.new(1920, 1080), insets = { top = 58, left = 0, right = 0, bottom = 0 }, touch = false },
	{ name = "celular_a06", screen = V2.new(800, 360), insets = { top = 58, left = 47, right = 48, bottom = 22 }, touch = true },
	{ name = "iphone_17_pro", screen = V2.new(874, 402), insets = { top = 58, left = 62, right = 62, bottom = 21 }, touch = true },
}
if not fs.isDir(output) then
	fs.writeDir(output)
end
for _, device in devices do
	for _, scene in { "rua", "mirando", "roleta" } do
		local folder = roblox.Instance.new("Folder")
		local safe = V2.new(device.screen.X - device.insets.left - device.insets.right, device.screen.Y - device.insets.top - device.insets.bottom)
		local l = play.hudLayout(safe, device.touch, nil)
		local hud = play.buildHud(folder, device.touch)
		hud.layout(l)
		hud.setMap(city)
		local combat = play.buildCombat(folder, device.touch)
		local card = play.buildWeaponCard(folder, device.touch, "rbxassetid://123")
		card.layout(l)
		local weapon = if scene == "rua" then defs[1] else defs[3]
		card.show(weapon, nil, if weapon.kind == "gun" then { 9, 96 } else nil, nil)
		local state = {
			health = if scene == "mirando" then 46 else 82, maxHealth = 100, stamina = if scene == "rua" then 0.55 else 1,
			exhausted = false, position = V3.new(150, 3, 196), cameraYaw = math.rad(-35), facingYaw = math.rad(-20),
			district = { name = "Distrito Prisma" }, clock = "00:36",
		}
		hud.update(state, 0.2)
		if scene ~= "rua" then
			for _ = 1, 30 do
				hud.update(state, 0.2) -- o aviso de distrito já saiu
			end
		end
		if device.touch then
			for key, spec in l.buttons do
				local glyph = ({ fire = weapon.id, aim = "mira", reload = "recarga" })[key]
				play.touchButton(hud.gui, key, "", glyph, spec.center, spec.radius, "rbxassetid://123")
			end
		end
		combat.crosshair(scene == "mirando", 0.25)
		combat.step(1, if scene == "mirando" then 1 else 0, 0)
		local guis = { hud.gui, combat.gui, card.gui }
		if scene == "roleta" then
			local wheel = play.buildWheel(folder, defs, nil, device.touch, "rbxassetid://123")
			wheel.gui.Enabled = true
			wheel.scale.Scale = l.wheel.scale
			wheel.select(3, { vespa = { 9, 96 }, enxame = { 32, 192 }, trovao = { 6, 36 }, agulha = { 28, 140 } })
			wheel.animate(1, 1)
			table.insert(guis, wheel.gui)
		end
		local exported = {}
		for _, gui in guis do
			table.insert(exported, screenGui(gui, device.screen, device.insets))
		end
		local path = string.format("%s/%s_%s.json", output, device.name, scene)
		fs.writeFile(path, serde.encode("json", { screen = { device.screen.X, device.screen.Y }, insets = device.insets, guis = exported }))
		print("ok", path)
	end
end
