-- HUD de jogo do CyberOutlaw (v2), desenhado em design/hud_v2.py.
-- Vida com retrato, minimapa de Maré Baixa, aviso de distrito, relógio e mira central.
local function mountCyberOutlawHud()
	if playerGui:FindFirstChild("CyberOutlawHealth") then
		return
	end

	local function optional(name)
		local ok, service = pcall(function()
			return game:GetService(name)
		end)
		return if ok then service else nil
	end
	local lighting = optional("Lighting")
	local world = optional("Workspace")
	local replicated = optional("ReplicatedStorage")
	local http = optional("HttpService")

	local touch = UserInputService.TouchEnabled
	local MONO = Font.fromEnum(Enum.Font.RobotoMono)
	local DISPLAY = Font.fromEnum(Enum.Font.Michroma)
	local FACE = Color3.fromRGB(16, 14, 25)
	local EDGE = Color3.fromRGB(82, 52, 76)
	local DANGER = Color3.fromRGB(255, 59, 92)
	local PINK_LABEL = Color3.fromRGB(255, 146, 191)

	local width, height = if touch then 194 else 268, if touch then 50 else 62
	local cut, portrait, pad = if touch then 7 else 9, if touch then 34 else 46, if touch then 8 else 9
	local mapW, mapH = if touch then 160 else 268, if touch then 116 else 174
	local footer = if touch then 20 else 24
	local scale = if touch then 0.22 else 0.30 -- pixels por stud no minimapa
	local left, right = pad + portrait + 10, width - 12

	-- Vida -----------------------------------------------------------------------------------
	local healthGui = screen("CyberOutlawHealth", 30, true)
	local panel = frame(healthGui, "Vitals", 1, {
		AnchorPoint = Vector2.new(0, if touch then 0 else 1),
		Position = if touch then UDim2.fromOffset(14, 8) else UDim2.new(0, 24, 1, -(24 + mapH + 10)),
		Size = UDim2.fromOffset(width, height),
	})
	local edge = polygon(panel, "BeveledEdge", 1, cut, EDGE, 0, 0)
	polygon(panel, "Faceplate", 2, cut - 1, FACE, 0, 1)
	frame(panel, "TopEdge", 3, {
		Position = UDim2.fromOffset(1, 0), Size = UDim2.fromOffset(if touch then 43 else 56, 1),
		BackgroundColor3 = MAGENTA, BackgroundTransparency = 0,
	})
	frame(panel, "BottomEdge", 3, {
		Position = UDim2.fromOffset(width - 30, height - 1), Size = UDim2.fromOffset(30, 1),
		BackgroundColor3 = CYAN, BackgroundTransparency = 0,
	})
	local bezel = frame(panel, "PortraitBezel", 3, {
		Position = UDim2.fromOffset(pad, pad), Size = UDim2.fromOffset(portrait, portrait),
		BackgroundColor3 = Color3.fromRGB(87, 50, 76), BackgroundTransparency = 0,
	})
	radius(bezel, 2)
	local portraitSize = portrait - 2
	make("ImageLabel", bezel, "CharacterFace", {
		Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(portraitSize, portraitSize),
		ZIndex = 4, BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(32, 17, 38),
		Image = if player.UserId > 0 then `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150` else "",
	})
	frame(bezel, "PortraitEdge", 5, {
		Position = UDim2.fromOffset(0, portrait - 1), Size = UDim2.fromOffset(12, 1),
		BackgroundColor3 = Color3.fromRGB(255, 110, 171), BackgroundTransparency = 0,
	})
	local labelY = if touch then 7 else 10
	local name = text(panel, "HealthLabel", "VIDA", 3, BOLD, if touch then 10 else 11, PINK_LABEL)
	name.Position = UDim2.fromOffset(left, labelY)
	name.Size = UDim2.fromOffset(40, 17)
	local value = text(panel, "HealthValue", "—", 3, MONO, if touch then 11 else 13, WHITE)
	value.Position = UDim2.fromOffset(right - 80, labelY)
	value.Size = UDim2.fromOffset(80, 17)
	value.TextXAlignment = Enum.TextXAlignment.Right
	local barHeight = if touch then 6 else 7
	local track = frame(panel, "HealthTrack", 3, {
		Position = UDim2.fromOffset(left, height - (if touch then 15 else 17)), Size = UDim2.fromOffset(right - left, barHeight),
		BackgroundColor3 = Color3.fromRGB(44, 32, 52), BackgroundTransparency = 0,
	})
	local trailBar = frame(track, "HealthTrail", 4, {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.45,
	})
	local fill = frame(track, "HealthFill", 5, {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0,
	})
	gradient(fill, 0, MAGENTA, Color3.fromRGB(255, 125, 168))
	for index = 1, 9 do
		frame(track, "Segment", 6, {
			Position = UDim2.new(index / 10, -1, 0, 0), Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = FACE, BackgroundTransparency = 0,
		})
	end

	-- Mira: só ela ignora os recortes, para ficar no centro exato da tela.
	local aimGui = screen("CyberOutlawAim", 31, false)
	local aimShadow = Color3.fromRGB(10, 10, 18)
	local shadow = frame(aimGui, "CrosshairOutline", 1, {
		AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14),
	})
	radius(shadow, 7)
	outline(shadow, aimShadow)
	local aim = frame(aimGui, "Crosshair", 2, {
		AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 12),
	})
	radius(aim, 6)
	outline(aim, WHITE)
	for _, mark in { { "DotShadow", 4, aimShadow }, { "Dot", 2, WHITE } } do
		local dot = frame(aim, mark[1], if mark[2] == 4 then 3 else 4, {
			AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(mark[2], mark[2]),
			BackgroundColor3 = mark[3], BackgroundTransparency = 0,
		})
		radius(dot, mark[2] / 2)
	end

	-- Minimapa ------------------------------------------------------------------------------
	local EXTENT, ORIGIN = 3200, -1600
	local function mapPoint(x, z)
		return Vector2.new((x - ORIGIN) * scale, (z - ORIGIN) * scale)
	end
	local mapGui = screen("CyberOutlawMap", 29, true)
	local mapBox = frame(mapGui, "Minimap", 1, {
		AnchorPoint = if touch then Vector2.new(1, 0) else Vector2.new(0, 1),
		Position = if touch then UDim2.new(1, -14, 0, 8) else UDim2.new(0, 24, 1, -24),
		Size = UDim2.fromOffset(mapW, mapH),
	})
	local view = make("CanvasGroup", mapBox, "Viewport", {
		Size = FULL, BackgroundColor3 = INK, BackgroundTransparency = 0.08, BorderSizePixel = 0, ZIndex = 1,
	})
	radius(view, 12)
	local border = outline(view, Color3.new(1, 1, 1))
	border.Transparency = 0.86
	local viewH = mapH - footer
	local center = Vector2.new(mapW / 2, math.floor(viewH * 0.55))
	local pivot = frame(view, "Pivot", 2, { Position = UDim2.fromOffset(center.X, center.Y), Size = UDim2.fromOffset(0, 0) })
	local map = frame(pivot, "Map", 2, {
		Size = UDim2.fromOffset(EXTENT * scale, EXTENT * scale), BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(7, 8, 15),
	})
	local noSignal = text(view, "NoSignal", "SEM SINAL DA CIDADE", 9, BOLD, if touch then 9 else 10, MUTED)
	noSignal.Size = UDim2.new(1, 0, 0, viewH)
	noSignal.TextXAlignment = Enum.TextXAlignment.Center
	local arrow = frame(view, "PlayerArrow", 8, {
		AnchorPoint = CENTER, Position = UDim2.fromOffset(center.X, center.Y), Size = UDim2.fromOffset(18, 18),
	})
	for _, side in { -1, 1 } do
		line(arrow, "ArrowEdge", 8, Vector2.new(9, 1), Vector2.new(9 + side * 7, 16), 2.6, WHITE)
	end
	local north = frame(view, "North", 8, {
		AnchorPoint = CENTER, Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 0, BackgroundColor3 = INK,
	})
	radius(north, 8)
	outline(north, Color3.fromRGB(170, 166, 184))
	local northLabel = text(north, "N", "N", 9, BOLD, 10, WHITE)
	northLabel.TextXAlignment = Enum.TextXAlignment.Center
	local strip = frame(view, "MapFooter", 7, {
		Position = UDim2.fromOffset(0, viewH), Size = UDim2.new(1, 0, 0, footer),
		BackgroundTransparency = 0.04, BackgroundColor3 = FACE,
	})
	frame(strip, "FooterEdge", 7, { Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.9, BackgroundColor3 = WHITE })
	local districtDot = frame(strip, "DistrictDot", 8, {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(6, 6),
		BackgroundTransparency = 0, BackgroundColor3 = MUTED,
	})
	radius(districtDot, 3)
	local districtLabel = text(strip, "DistrictName", "MARÉ BAIXA", 8, DISPLAY, if touch then 8 else 10, WHITE)
	districtLabel.Position = UDim2.fromOffset(21, 0)
	districtLabel.Size = UDim2.new(1, -74, 1, 0)
	districtLabel.TextTruncate = Enum.TextTruncate.AtEnd
	local clock = text(strip, "Clock", "--:--", 8, MONO, if touch then 10 else 12, PINK_LABEL)
	clock.AnchorPoint = Vector2.new(1, 0)
	clock.Position = UDim2.new(1, -10, 0, 0)
	clock.Size = UDim2.new(0, 50, 1, 0)
	clock.TextXAlignment = Enum.TextXAlignment.Right
	frame(mapBox, "CornerPink", 9, { Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(24, 2), BackgroundTransparency = 0, BackgroundColor3 = MAGENTA })
	frame(mapBox, "CornerPinkSide", 9, { Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(2, 12), BackgroundTransparency = 0, BackgroundColor3 = MAGENTA })
	frame(mapBox, "CornerCyan", 9, { Position = UDim2.new(1, -36, 1, -2), Size = UDim2.fromOffset(24, 2), BackgroundTransparency = 0, BackgroundColor3 = CYAN })
	frame(mapBox, "CornerCyanSide", 9, { Position = UDim2.new(1, -2, 1, -24), Size = UDim2.fromOffset(2, 12), BackgroundTransparency = 0, BackgroundColor3 = CYAN })

	-- Aviso de distrito ---------------------------------------------------------------------
	local toastW, toastH = if touch then 300 else 520, if touch then 58 else 84
	local toast = make("CanvasGroup", mapGui, "DistrictToast", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, if touch then 4 else 18),
		Size = UDim2.fromOffset(toastW, toastH), BackgroundTransparency = 1, BorderSizePixel = 0,
		GroupTransparency = 1, Visible = false, ZIndex = 10,
	})
	local band = frame(toast, "DistrictBand", 10, { Size = FULL, BackgroundTransparency = 0, BackgroundColor3 = INK })
	make("UIGradient", band, "Fade", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.28, 0.4),
			NumberSequenceKeypoint.new(0.72, 0.4), NumberSequenceKeypoint.new(1, 1),
		}),
	})
	local city = text(toast, "DistrictCity", "MARÉ BAIXA", 11, BOLD, if touch then 8 else 11, PINK_LABEL)
	city.Position = UDim2.fromOffset(0, if touch then 4 else 8)
	city.Size = UDim2.new(1, 0, 0, if touch then 10 else 14)
	city.TextXAlignment = Enum.TextXAlignment.Center
	local title = text(toast, "DistrictTitle", "", 11, DISPLAY, if touch then 17 else 28, WHITE)
	title.Position = UDim2.fromOffset(0, if touch then 15 else 24)
	title.Size = UDim2.new(1, 0, 0, if touch then 22 else 34)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local underline = frame(toast, "Underline", 11, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, toastH - (if touch then 10 else 14)),
		Size = UDim2.fromOffset(if touch then 200 else 280, 2), BackgroundTransparency = 0, BackgroundColor3 = MAGENTA,
	})
	make("UIGradient", underline, "Fade", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
		}),
	})
	local toastDot = frame(toast, "DistrictTitleDot", 12, {
		AnchorPoint = CENTER, Position = UDim2.new(0.5, 0, 0, toastH - (if touch then 9 else 13)),
		Size = UDim2.fromOffset(6, 6), BackgroundTransparency = 0, BackgroundColor3 = MAGENTA,
	})
	radius(toastDot, 3)

	local layout, district
	local toastTime = math.huge
	-- string.upper só conhece ASCII; os nomes de Maré Baixa têm acentos do português.
	local ACCENTS = {
		["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["é"] = "É", ["ê"] = "Ê",
		["í"] = "Í", ["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ", ["ú"] = "Ú", ["ç"] = "Ç",
	}
	local function upper(value)
		return (string.gsub(string.upper(value), "\xC3[\x80-\xBF]", function(char)
			return ACCENTS[char] or char
		end))
	end
	local function color(rgb)
		return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	end
	local function districtAt(x, z)
		for _, entry in layout.districts do
			local r = entry.rect
			if x >= r[1] and x <= r[3] and z >= r[2] and z <= r[4] then
				return entry
			end
		end
		return nil
	end
	local function rect(parent, name, x0, z0, x1, z1, tone, z)
		local a, b = mapPoint(x0, z0), mapPoint(x1, z1)
		return frame(parent, name, z, {
			Position = UDim2.fromOffset(a.X, a.Y), Size = UDim2.fromOffset(b.X - a.X, b.Y - a.Y),
			BackgroundTransparency = 0, BackgroundColor3 = tone,
		})
	end
	local function drawMap(data)
		local half, quay = data.half, data.quay
		rect(map, "Asfalto", -half - 14, -half - 14, half + 14, quay, Color3.fromRGB(44, 50, 73), 2)
		rect(map, "Baía", ORIGIN, quay, ORIGIN + EXTENT, ORIGIN + EXTENT, Color3.fromRGB(12, 42, 58), 2)
		local lines = data.lines
		for i = 1, #lines - 1 do
			for j = 1, #lines - 1 do
				local a, b, c, d = lines[i], lines[i + 1], lines[j], lines[j + 1]
				local x0, x1 = a[1] + a[2] / 2, b[1] - b[2] / 2
				local z0, z1 = c[1] + c[2] / 2, d[1] - d[2] / 2
				local entry = districtAt((a[1] + b[1]) / 2, (c[1] + d[1]) / 2)
				local tone = Color3.fromRGB(18, 20, 31)
				if entry then
					tone = tone:Lerp(color(entry.color), 0.16)
				end
				rect(map, "Quadra", x0, z0, x1, z1, tone, 3)
			end
		end
		for _, entry in lines do
			if entry[2] >= 56 then
				rect(map, "Eixo da avenida", -half - 14, entry[1] - 2, half + 14, entry[1] + 2, Color3.fromRGB(89, 98, 138), 3)
				rect(map, "Eixo da avenida", entry[1] - 2, -half - 14, entry[1] + 2, quay, Color3.fromRGB(89, 98, 138), 3)
			end
		end
		local ring = data.monorail
		for index, point in ring do
			local following = ring[index % #ring + 1]
			line(map, "Monotrilho", 4, mapPoint(point[1], point[2]), mapPoint(following[1], following[2]), math.max(2, 9 * scale), MAGENTA)
		end
		local station = data.station
		rect(map, "Estação", station[1] - 8, station[2] - 60, station[1] + 8, station[2] + 60, Color3.fromRGB(58, 231, 255), 5)
		local plaza = mapPoint(data.plaza[1], data.plaza[2])
		frame(map, "Praça", 5, {
			AnchorPoint = CENTER, Position = UDim2.fromOffset(plaza.X, plaza.Y), Size = UDim2.fromOffset(7, 7),
			Rotation = 45, BackgroundTransparency = 0, BackgroundColor3 = MAGENTA,
		})
		noSignal.Visible = false
	end
	local function readLayout()
		if layout or not replicated or not http then
			return
		end
		local info = replicated:FindFirstChild("CyberOutlawCityInfo")
		local raw = info and info:GetAttribute("Layout")
		if type(raw) ~= "string" then
			return
		end
		local ok, data = pcall(function()
			return http:JSONDecode(raw)
		end)
		if ok and type(data) == "table" and type(data.lines) == "table" and type(data.districts) == "table" then
			layout = data
			drawMap(data)
		end
	end
	local function yaw(look)
		return math.deg(math.atan2(look.X, -look.Z))
	end
	local function showDistrict(entry)
		district = entry
		local tint = if entry then color(entry.color) else MUTED
		districtLabel.Text = if entry then upper(entry.name) else "MARÉ BAIXA"
		districtDot.BackgroundColor3 = tint
		if entry then
			title.Text = upper(entry.name)
			toastDot.BackgroundColor3 = tint
			toast.Visible = true
			toastTime = 0
		end
	end
	local function updateMap()
		readLayout()
		if lighting then
			local minutes = math.floor((lighting.ClockTime % 24) * 60)
			clock.Text = string.format("%02d:%02d", minutes // 60, minutes % 60)
		end
		local camera = world and world.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not layout or not camera or not root then
			return
		end
		local position = root.Position
		local heading = yaw(camera.CFrame.LookVector)
		local corner = mapPoint(position.X, position.Z)
		map.Position = UDim2.fromOffset(-corner.X, -corner.Y)
		pivot.Rotation = -heading
		arrow.Rotation = yaw(root.CFrame.LookVector) - heading
		local angle = math.rad(-heading)
		local reach = Vector2.new(mapW / 2 - 10, viewH / 2 - 8)
		local direction = Vector2.new(math.sin(angle), -math.cos(angle))
		local stretch = math.min(reach.X / math.max(math.abs(direction.X), 0.001), (viewH - 8 - center.Y) / math.max(direction.Y, 0.001), (center.Y - 10) / math.max(-direction.Y, 0.001))
		local spot = center + direction * stretch
		north.Position = UDim2.fromOffset(spot.X, spot.Y)
		local entry = districtAt(position.X, position.Z)
		if entry ~= district and (not entry or not district or entry.key ~= district.key) then
			showDistrict(entry)
		end
	end
	north.Position = UDim2.fromOffset(center.X, 14)

	-- Vida: rastro do dano recente e pulso abaixo de 30% ---------------------------------------
	local currentCharacter
	local lifeConnections = {}
	local ratio, trail, trailHold = 0, 0, 0
	local function formatHealth(number)
		return if number == math.huge then "∞" else tostring(math.ceil(number))
	end

	local function paintHealth(humanoid)
		local maxHealth = if humanoid then math.max(0, humanoid.MaxHealth) else 0
		local health = if humanoid then math.clamp(humanoid.Health, 0, maxHealth) else 0
		local nextRatio = if maxHealth <= 0 then 0 elseif health == maxHealth then 1 else health / maxHealth
		if nextRatio < ratio and humanoid then
			trail = math.max(trail, ratio)
			trailHold = 0.4
		else
			trail = nextRatio
		end
		ratio = nextRatio
		fill.Size = UDim2.fromScale(ratio, 1)
		fill.Visible = health > 0
		trailBar.Size = UDim2.fromScale(math.max(trail, ratio), 1)
		value.Text = if humanoid then formatHealth(health) .. " / " .. formatHealth(maxHealth) else "—"
	end

	local function watchCharacter(character)
		for _, connection in lifeConnections do
			connection:Disconnect()
		end
		table.clear(lifeConnections)
		currentCharacter = character
		ratio, trail = 0, 0
		paintHealth(nil)
		if not character then
			return
		end
		local waiting
		local function watchHumanoid(humanoid)
			if not humanoid:IsA("Humanoid") then
				return
			end
			if waiting then
				waiting:Disconnect()
			end
			local function sync()
				paintHealth(humanoid)
			end
			table.insert(lifeConnections, humanoid.HealthChanged:Connect(sync))
			table.insert(lifeConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(sync))
			sync()
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			watchHumanoid(humanoid)
		else
			waiting = character.ChildAdded:Connect(watchHumanoid)
			table.insert(lifeConnections, waiting)
		end
	end

	local elapsed, mapClock = 0, 1
	local pulsing = false
	local onStep = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if trailHold > 0 then
			trailHold -= dt
		elseif trail > ratio then
			trail = math.max(ratio, trail - dt * 1.6)
			trailBar.Size = UDim2.fromScale(trail, 1)
		end
		local low = ratio > 0 and ratio < 0.3
		if low then
			paint(edge, EDGE:Lerp(DANGER, 0.55 + 0.45 * math.sin(elapsed * 6)))
			pulsing = true
		elseif pulsing then
			paint(edge, EDGE)
			pulsing = false
		end
		if toastTime < 4 then
			toastTime += dt
			local alpha = if toastTime < 0.3 then toastTime / 0.3 elseif toastTime > 3.3 then math.max(0, (4 - toastTime) / 0.7) else 1
			toast.GroupTransparency = 1 - alpha
			if toastTime >= 4 then
				toast.Visible = false
			end
		end
		mapClock += dt
		if mapClock >= 1 / 15 then
			mapClock = 0
			local ok, problem = pcall(updateMap)
			if not ok then
				warn("CyberOutlaw | Minimapa: " .. tostring(problem))
			end
		end
	end)

	local onSpawn = player.CharacterAdded:Connect(watchCharacter)
	local onDespawn = player.CharacterRemoving:Connect(function(character)
		if character == currentCharacter then
			watchCharacter(nil)
		end
	end)
	watchCharacter(player.Character)
	local starterGui = game:GetService("StarterGui")
	local hadCoreHealth = false
	pcall(function()
		hadCoreHealth = starterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Health)
		starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	script.Destroying:Once(function()
		onSpawn:Disconnect()
		onDespawn:Disconnect()
		onStep:Disconnect()
		watchCharacter(nil)
		aimGui:Destroy()
		healthGui:Destroy()
		mapGui:Destroy()
		if hadCoreHealth then
			pcall(function()
				starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true)
			end)
		end
	end)
	healthGui.Parent = playerGui
	aimGui.Parent = playerGui
	mapGui.Parent = playerGui
end
