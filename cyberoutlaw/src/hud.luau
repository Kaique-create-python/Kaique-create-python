local function mountCyberOutlawHud()
	if playerGui:FindFirstChild("CyberOutlawHealth") then
		return
	end

	local touch = UserInputService.TouchEnabled
	local width, height = if touch then 194 else 232, if touch then 50 else 60
	local cut, portrait, pad = if touch then 7 else 9, if touch then 34 else 42, if touch then 8 else 9
	local left, right = pad + portrait + 10, width - 12
	local healthGui = screen("CyberOutlawHealth", 30, true)
	local panel = frame(healthGui, "Vitals", 1, {
		AnchorPoint = Vector2.new(0, if touch then 0 else 1),
		Position = if touch then UDim2.fromOffset(14, 8) else UDim2.new(0, 28, 1, -24),
		Size = UDim2.fromOffset(width, height),
	})
	polygon(panel, "BeveledEdge", 1, cut, Color3.fromRGB(82, 52, 76), 0, 0)
	polygon(panel, "Faceplate", 2, cut - 1, Color3.fromRGB(16, 14, 25), 0, 1)
	frame(panel, "TopEdge", 3, {
		Position = UDim2.fromOffset(1, 0), Size = UDim2.fromOffset(if touch then 43 else 55, 1),
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
		Position = UDim2.fromOffset(0, portrait - 1), Size = UDim2.fromOffset(11, 1),
		BackgroundColor3 = Color3.fromRGB(255, 110, 171), BackgroundTransparency = 0,
	})
	local labelY = if touch then 7 else 10
	local name = text(panel, "HealthLabel", "VIDA", 3, BOLD, if touch then 10 else 11, Color3.fromRGB(255, 146, 191))
	name.Position = UDim2.fromOffset(left, labelY)
	name.Size = UDim2.fromOffset(38, 17)
	local value = text(panel, "HealthValue", "—", 3, Font.fromEnum(Enum.Font.RobotoMono), if touch then 11 else 13, WHITE)
	value.Position = UDim2.fromOffset(right - 74, labelY)
	value.Size = UDim2.fromOffset(74, 17)
	value.TextXAlignment = Enum.TextXAlignment.Right
	local track = frame(panel, "HealthTrack", 3, {
		Position = UDim2.fromOffset(left, height - 16), Size = UDim2.fromOffset(right - left, 5),
		BackgroundColor3 = Color3.fromRGB(44, 32, 52), BackgroundTransparency = 0,
	})
	radius(track, 1)
	local fill = frame(track, "HealthFill", 4, {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0,
	})
	radius(fill, 1)
	gradient(fill, 0, MAGENTA, Color3.fromRGB(255, 125, 168))

	-- Only the crosshair ignores insets. The health panel respects cutouts and the Roblox top bar.
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

	local currentCharacter
	local lifeConnections = {}
	local function formatHealth(number)
		return if number == math.huge then "∞" else tostring(math.ceil(number))
	end

	local function paintHealth(humanoid)
		local maxHealth = if humanoid then math.max(0, humanoid.MaxHealth) else 0
		local health = if humanoid then math.clamp(humanoid.Health, 0, maxHealth) else 0
		local ratio = if maxHealth <= 0 then 0 elseif health == maxHealth then 1 else health / maxHealth
		fill.Size = UDim2.fromScale(ratio, 1)
		fill.Visible = health > 0
		value.Text = if humanoid then formatHealth(health) .. " / " .. formatHealth(maxHealth) else "—"
	end

	local function watchCharacter(character)
		for _, connection in lifeConnections do
			connection:Disconnect()
		end
		table.clear(lifeConnections)
		currentCharacter = character
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
		watchCharacter(nil)
		aimGui:Destroy()
		healthGui:Destroy()
		if hadCoreHealth then
			pcall(function()
				starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true)
			end)
		end
	end)
	healthGui.Parent = playerGui
	aimGui.Parent = playerGui
end
