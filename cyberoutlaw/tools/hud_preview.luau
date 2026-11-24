-- Exporta o HUD real do CyberOutlawPlay (Instances de verdade) para a prévia em HTML.
-- Uso: lune run tools/hud_preview.luau <pasta de saída>
-- Para cada aparelho, monta HUD, mira, barra de armas, botões neon e de toque e a roleta aberta, resolve
-- UDim2, AnchorPoint e UIScale em pixels da tela e grava um JSON por cena. As placas 3D do jogo (barra de
-- armas e minimapa) saem como camadas "holo", com a inclinação que o jogo usa na frente da câmera.
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
			Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence,
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
		ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, Enum = roblox.Enum, UDim2 = roblox.UDim2, Font = roblox.Font, Content = roblox.Content,
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
		local strokeGradient = stroke:FindFirstChildOfClass("UIGradient")
		if strokeGradient and prop(strokeGradient, "Enabled", true) then
			local colors = {}
			for _, key in prop(strokeGradient, "Color", roblox.ColorSequence.new(roblox.Color3.new(1, 1, 1))).Keypoints do
				table.insert(colors, { key.Time, table.unpack(color(key.Value)) })
			end
			row.strokeGrad = { c = colors, rot = prop(strokeGradient, "Rotation", 0) }
		end
	end
	local gradient = node:FindFirstChildOfClass("UIGradient")
	if gradient and prop(gradient, "Enabled", true) then
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

-- Placa 3D: os itens de uma SurfaceGui (ou do bloco do mapa) no retângulo da âncora, com a inclinação do jogo.
local function holo(name: string, nodes, rect, scale: number, screen: Vector2)
	local rows = {}
	for _, node in nodes do
		if node:IsA("GuiObject") then
			table.insert(rows, export(node, rect[1], rect[2], rect[3], rect[4], scale))
		end
	end
	local nx = math.clamp((rect[1] + rect[3] / 2 - screen.X / 2) / (screen.X / 2), -1, 1)
	local ny = math.clamp((rect[2] + rect[4] / 2 - screen.Y / 2) / (screen.Y / 2), -1, 1)
	local fx, fy, pitch, yaw = play.holoTilt(nx, ny)
	-- CSS: rotateX positivo afasta a borda de cima, rotateY positivo afasta a borda direita (como o pitch e o yaw
	-- do jogo com o sinal do pitch trocado); a origem é a borda de fora, que fica parada.
	return { name = name, order = 29, enabled = true, items = rows,
		holo = { r = rect, rx = math.deg(-pitch), ry = math.deg(yaw), ox = 50 + fx * 50, oy = 50 + fy * 50 } }
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
		-- Barra de armas: na rua com os punhos (página 1), mirando com a AK (página 2, setas dos dois lados).
		local weapon = if scene == "rua" then defs[1] else defs[6]
		local bar = play.buildWeaponBar(defs, "rbxassetid://123")
		bar.resize(l.neon.size * l.scale)
		bar.setPage(bar.pageOf(weapon.id))
		bar.set(weapon, if weapon.kind == "gun" then { 24, 150 } else nil, if scene == "roleta" then 0.45 else nil)
		local state = {
			health = if scene == "mirando" then 46 else 82, maxHealth = 100, stamina = if scene == "rua" then 0.55 else 1,
			exhausted = false, position = V3.new(150, 3, 196), cameraYaw = math.rad(-35), facingYaw = math.rad(-20),
			district = { name = "Distrito Prisma" }, clock = "00:36", psychosis = if scene == "mirando" then 0.35 else 0.8,
		}
		hud.update(state, 0.2)
		if scene ~= "rua" then
			for _ = 1, 30 do
				hud.update(state, 0.2) -- o aviso de distrito já saiu
			end
		end
		local function placeButton(entry, item)
			entry.button.AnchorPoint = item.anchor
			entry.button.Position = roblox.UDim2.fromOffset(item.position.X, item.position.Y)
			entry.button.Size = roblox.UDim2.fromOffset(item.size.X, item.size.Y)
			entry.scale.Scale = l.scale
		end
		local implants = play.neonButton(hud.gui, "Implantes", "implantes", "rbxassetid://123", if device.touch then nil else "I", false)
		placeButton(implants, l.implants)
		local ability = play.neonButton(hud.gui, "Habilidade", "sandevistan", "rbxassetid://123", if device.touch then nil else "X", device.touch)
		ability.light(scene == "mirando")
		if device.touch then
			local arsenalButton = play.neonButton(hud.gui, "Arsenal", "arsenal", "rbxassetid://123", nil, false)
			placeButton(arsenalButton, l.arsenal)
			for key, spec in l.buttons do
				if key == "ability" then
					ability.button.Position = roblox.UDim2.fromOffset(spec.center.X, spec.center.Y)
					ability.button.Size = roblox.UDim2.fromOffset(spec.radius * 2, spec.radius * 2)
				else
					local glyph = ({ fire = weapon.id, aim = "mira", reload = "recarga" })[key]
					play.touchButton(hud.gui, key, "", glyph, spec.center, spec.radius, "rbxassetid://123")
				end
			end
		else
			placeButton(ability, l.ability)
		end
		-- O bloco do mapa vai para a placa 3D, como no jogo.
		local block = hud.parts.block
		block.Parent = nil
		combat.crosshair(scene == "mirando", 0.25)
		combat.step(1, if scene == "mirando" then 1 else 0, 0)
		local guis = { hud.gui, combat.gui }
		if scene == "roleta" then
			local wheel = play.buildWheel(folder, defs, nil, device.touch, "rbxassetid://123")
			wheel.gui.Enabled = true
			wheel.scale.Scale = l.wheel.scale
			wheel.select(6, { glock = { 9, 102 }, deagle = { 7, 42 }, uzi = { 32, 192 }, ak47 = { 30, 150 }, m4 = { 30, 180 }, escopeta = { 6, 40 }, sniper = { 5, 30 } })
			wheel.animate(1, 1)
			table.insert(guis, wheel.gui)
		end
		local exported = {}
		for _, gui in guis do
			table.insert(exported, screenGui(gui, device.screen, device.insets))
		end
		local function screenRect(item)
			local x0, y0, x1, y1 = play.layoutRect(item, l.scale)
			return { x0 + device.insets.left, y0 + device.insets.top, x1 - x0, y1 - y0 }
		end
		if scene ~= "roleta" then
			table.insert(exported, holo("MapaNeon", { block }, screenRect(l.minimap), l.scale, device.screen))
			table.insert(exported, holo("BarraNeon", bar.gui:GetChildren(), screenRect(l.neon), 1, device.screen))
		end
		local path = string.format("%s/%s_%s.json", output, device.name, scene)
		fs.writeFile(path, serde.encode("json", { screen = { device.screen.X, device.screen.Y }, insets = device.insets, guis = exported }))
		print("ok", path)
	end
end
