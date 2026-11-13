--!nonstrict
-- SETOR 7 client: presentation and input only. Movement and gameplay live on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local package = ReplicatedStorage:WaitForChild("Sector7")
local Config = require(package:WaitForChild("Config"))
local remotes = package:WaitForChild("Remotes")
local sprintRemote = remotes:WaitForChild("Sprint")
local flashlightRemote = remotes:WaitForChild("Flashlight")
local feedbackRemote = remotes:WaitForChild("Feedback")
local cameraConfig = Config.Camera or {}
local maxStamina = math.max(1, Config.MaxStamina or 100)
local baseFov = cameraConfig.BaseFov or 74
local sprintFov = cameraConfig.SprintFov or 80
local maxBlur = math.clamp(cameraConfig.MaxBlur or 4, 0, 4)
local bobStrength = math.clamp(cameraConfig.BobStrength or 0.045, 0, 0.08)

local colors = {
	background = Color3.fromRGB(15, 19, 19),
	panel = Color3.fromRGB(24, 30, 29),
	ink = Color3.fromRGB(233, 236, 221),
	muted = Color3.fromRGB(165, 177, 164),
	green = Color3.fromRGB(175, 198, 147),
	amber = Color3.fromRGB(229, 182, 104),
	red = Color3.fromRGB(218, 114, 101),
	line = Color3.fromRGB(73, 86, 75),
}

local connections = {}
local characterConnections = {}
local humanoid = nil
local rootPart = nil
local characterVersion = 0
local alive = false
local destroyed = false
local modalKind = nil
local coreMenuOpen = false
local keyboardSprint = false
local gamepadSprint = false
local touchSprint = false
local lastSprintRequest = false
local displayedStamina = maxStamina
local scarePulse = 0
local toastVersion = 0
local originalCameraMode = player.CameraMode
local originalMouseIcon = UserInputService.MouseIconEnabled
local cameraFovs = {}
local runTrack = nil

if player:GetAttribute("ReducedMotion") == nil then
	player:SetAttribute("ReducedMotion", false)
end
if player:GetAttribute("CameraBlurEnabled") == nil then
	player:SetAttribute("CameraBlurEnabled", true)
end
player.CameraMode = Enum.CameraMode.LockFirstPerson

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function make(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function corner(parent, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

local function outline(parent)
	make("UIStroke", { Color = colors.line, Thickness = 1, Transparency = 0.25 }, parent)
end

local function label(parent, properties)
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextColor3 = colors.ink,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = false,
	}
	for key, value in pairs(properties) do
		defaults[key] = value
	end
	return make("TextLabel", defaults, parent)
end

local function button(parent, properties)
	local defaults = {
		BackgroundColor3 = colors.panel,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Font = Enum.Font.GothamMedium,
		TextColor3 = colors.ink,
		TextSize = 14,
		Selectable = true,
	}
	for key, value in pairs(properties) do
		defaults[key] = value
	end
	local object = make("TextButton", defaults, parent)
	corner(object, 6)
	outline(object)
	return object
end

for _, name in ipairs({ "Sector7Effects", "Sector7HUD" }) do
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

-- Only noninteractive ambience ignores screen insets. HUD controls stay in the safe area.
local effectsGui = make("ScreenGui", {
	Name = "Sector7Effects",
	ResetOnSpawn = false,
	DisplayOrder = 1,
	ScreenInsets = Enum.ScreenInsets.None,
	ClipToDeviceSafeArea = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local effectsRoot = make("Frame", {
	Name = "FullBleed",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Active = false,
}, effectsGui)

-- Gentle edge shade; no flicker, grain animation, or image asset dependency.
for _, side in ipairs({ "Top", "Bottom" }) do
	local top = side == "Top"
	local edge = make("Frame", {
		Name = side .. "Shade",
		Size = UDim2.fromScale(1, 0.14),
		Position = UDim2.fromScale(0, top and 0 or 1),
		AnchorPoint = Vector2.new(0, top and 0 or 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Active = false,
	}, effectsRoot)
	make("UIGradient", {
		Rotation = top and 90 or 270,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
	}, edge)
end
local scareShade = make("Frame", {
	Name = "ThreatShade",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(63, 15, 13),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Active = false,
}, effectsRoot)

local hud = make("ScreenGui", {
	Name = "Sector7HUD",
	ResetOnSpawn = false,
	DisplayOrder = 10,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	ClipToDeviceSafeArea = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local safeRoot = make("Frame", {
	Name = "SafeArea",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, hud)

local objective = make("Frame", {
	Name = "Mission",
	Position = UDim2.fromOffset(16, 54),
	Size = UDim2.new(0.73, -20, 0, 104),
	BackgroundColor3 = colors.background,
	BackgroundTransparency = 0.16,
	BorderSizePixel = 0,
}, safeRoot)
make("UISizeConstraint", { MinSize = Vector2.new(190, 104), MaxSize = Vector2.new(380, 104) }, objective)
corner(objective)
outline(objective)
label(objective, {
	Position = UDim2.fromOffset(13, 9),
	Size = UDim2.new(1, -26, 0, 18),
	Text = "СЕКТОР 7  /  SETOR 7",
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	TextColor3 = colors.green,
})
local objectiveText = label(objective, {
	Position = UDim2.fromOffset(13, 31),
	Size = UDim2.new(1, -26, 0, 40),
	Text = "Localize os três fusíveis.",
	TextSize = 15,
	TextWrapped = true,
})
local progressText = label(objective, {
	Position = UDim2.fromOffset(13, 77),
	Size = UDim2.new(1, -26, 0, 16),
	Text = "FUSÍVEIS 0/3  •  ENERGIA OFF",
	TextSize = 11,
	TextColor3 = colors.muted,
})

local settingsButton = button(safeRoot, {
	Name = "Options",
	Position = UDim2.new(1, -16, 0, 54),
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromOffset(52, 44),
	Text = "MENU",
	TextSize = 11,
})

local staminaPanel = make("Frame", {
	Name = "Stamina",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -15),
	Size = UDim2.new(0.62, 0, 0, 58),
	BackgroundColor3 = colors.background,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
}, safeRoot)
make("UISizeConstraint", { MinSize = Vector2.new(205, 58), MaxSize = Vector2.new(560, 58) }, staminaPanel)
corner(staminaPanel)
outline(staminaPanel)
local staminaText = label(staminaPanel, {
	Position = UDim2.fromOffset(12, 7),
	Size = UDim2.new(1, -65, 0, 18),
	Text = "FÔLEGO",
	TextSize = 11,
	Font = Enum.Font.GothamBold,
	TextColor3 = colors.muted,
})
local staminaNumber = label(staminaPanel, {
	Position = UDim2.new(1, -57, 0, 7),
	Size = UDim2.fromOffset(45, 18),
	Text = "100%",
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Right,
})
local staminaTrack = make("Frame", {
	Position = UDim2.fromOffset(12, 33),
	Size = UDim2.new(1, -24, 0, 7),
	BackgroundColor3 = Color3.fromRGB(46, 55, 47),
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, staminaPanel)
corner(staminaTrack, 3)
local staminaFill = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = colors.green,
	BorderSizePixel = 0,
}, staminaTrack)
corner(staminaFill, 3)
local controlHint = label(safeRoot, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -82),
	Size = UDim2.new(0.8, 0, 0, 20),
	Text = "SHIFT correr  ·  F lanterna  ·  E interagir  ·  M opções",
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = colors.muted,
})
local flashlightButton = button(safeRoot, {
	Name = "TouchFlashlight",
	Position = UDim2.new(1, -18, 0.43, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	Size = UDim2.fromOffset(64, 54),
	Text = "LUZ\nOFF",
	TextSize = 11,
	Visible = UserInputService.TouchEnabled,
})
local sprintButton = button(safeRoot, {
	Name = "TouchSprint",
	Position = UDim2.new(1, -18, 0.62, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	Size = UDim2.fromOffset(64, 54),
	Text = "CORRER",
	TextSize = 11,
	Visible = UserInputService.TouchEnabled,
})

local toast = make("Frame", {
	Name = "Notice",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.31),
	Size = UDim2.new(0.78, 0, 0, 100),
	BackgroundColor3 = colors.background,
	BackgroundTransparency = 0.06,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 5,
}, safeRoot)
make("UISizeConstraint", { MaxSize = Vector2.new(510, 100) }, toast)
corner(toast)
outline(toast)
local toastTitle = label(toast, {
	Position = UDim2.fromOffset(14, 9),
	Size = UDim2.new(1, -28, 0, 21),
	Text = "SINAL RECEBIDO",
	TextSize = 12,
	TextColor3 = colors.green,
	Font = Enum.Font.GothamBold,
	ZIndex = 6,
})
local toastText = label(toast, {
	Position = UDim2.fromOffset(14, 32),
	Size = UDim2.new(1, -28, 1, -40),
	Text = "",
	TextWrapped = true,
	TextSize = 14,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 6,
})

local modalOverlay = make("Frame", {
	Name = "Modal",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.34,
	BorderSizePixel = 0,
	Visible = false,
	Active = true,
	ZIndex = 20,
}, safeRoot)
local modal = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromScale(0.86, 0.78),
	BackgroundColor3 = colors.background,
	BorderSizePixel = 0,
	ZIndex = 21,
}, modalOverlay)
make("UISizeConstraint", { MaxSize = Vector2.new(590, 460), MinSize = Vector2.new(230, 240) }, modal)
corner(modal, 8)
outline(modal)
local modalTitle = label(modal, {
	Position = UDim2.fromOffset(18, 14),
	Size = UDim2.new(1, -36, 0, 32),
	Text = "OPÇÕES",
	Font = Enum.Font.GothamBold,
	TextSize = 19,
	ZIndex = 22,
})
local closeButton = button(modal, {
	Name = "Close",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.new(1, -36, 0, 44),
	Text = "VOLTAR AO JOGO",
	Modal = true, -- Roblox unlocks first-person cursor while a visible modal button exists.
	ZIndex = 22,
})
local settingsContent = make("ScrollingFrame", {
	Name = "Accessibility",
	Position = UDim2.fromOffset(18, 54),
	Size = UDim2.new(1, -36, 1, -125),
	CanvasSize = UDim2.fromOffset(0, 230),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = colors.muted,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ZIndex = 22,
}, modal)
local motionButton = button(settingsContent, {
	Name = "ReducedMotion",
	Size = UDim2.new(1, -8, 0, 46),
	Text = "MOVIMENTO REDUZIDO: OFF",
	TextSize = 12,
	ZIndex = 23,
})
local blurButton = button(settingsContent, {
	Name = "CameraBlur",
	Position = UDim2.fromOffset(0, 56),
	Size = UDim2.new(1, -8, 0, 46),
	Text = "DESFOQUE: ON",
	TextSize = 12,
	ZIndex = 23,
})
label(settingsContent, {
	Position = UDim2.fromOffset(0, 116),
	Size = UDim2.new(1, -12, 0, 110),
	Text = "Movimento reduzido desliga o balanço, a inclinação, a mudança de campo de visão e o desfoque.\n\nPC: Shift correr · F lanterna · E interagir\nControle: L3 correr · Y lanterna · X interagir\nM abre/fecha opções; Esc fecha a leitura.",
	TextSize = 12,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = colors.muted,
	ZIndex = 23,
})
local readingContent = make("ScrollingFrame", {
	Name = "Document",
	Position = UDim2.fromOffset(18, 56),
	Size = UDim2.new(1, -36, 1, -126),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = colors.muted,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	Visible = false,
	ZIndex = 22,
}, modal)
local readingText = label(readingContent, {
	Size = UDim2.new(1, -12, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Text = "",
	TextWrapped = true,
	TextSize = 15,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 23,
})

local oldBlur = Lighting:FindFirstChild("Sector7MotionBlur")
if oldBlur then
	oldBlur:Destroy()
end
local blur = make("BlurEffect", { Name = "Sector7MotionBlur", Size = 0 }, Lighting)

local function reducedMotion()
	return player:GetAttribute("ReducedMotion") == true
end

local function syncOptions()
	motionButton.Text = "MOVIMENTO REDUZIDO: " .. (reducedMotion() and "ON" or "OFF")
	blurButton.Text = "DESFOQUE: " .. (player:GetAttribute("CameraBlurEnabled") == true and "ON" or "OFF")
	motionButton.TextColor3 = reducedMotion() and colors.green or colors.ink
	if reducedMotion() or player:GetAttribute("CameraBlurEnabled") ~= true then
		blur.Size = 0
	end
end

local function updateSprint()
	local requested = alive and not modalKind and not coreMenuOpen
		and player:GetAttribute("Escaped") ~= true
		and (keyboardSprint or gamepadSprint or touchSprint)
	requested = requested == true
	if requested ~= lastSprintRequest then
		lastSprintRequest = requested
		sprintRemote:FireServer(requested)
	end
	sprintButton.BackgroundColor3 = touchSprint and colors.line or colors.panel
	sprintButton.Text = touchSprint and "CORRER\nON" or "CORRER"
end

local function clearSprint()
	keyboardSprint = false
	gamepadSprint = false
	touchSprint = false
	updateSprint()
end

local function syncPointer()
	local unlocked = modalKind ~= nil or coreMenuOpen or not alive
	UserInputService.MouseIconEnabled = unlocked
	UserInputService.MouseBehavior = unlocked and Enum.MouseBehavior.Default or Enum.MouseBehavior.LockCenter
end

local function closeModal()
	modalKind = nil
	modalOverlay.Visible = false
	GuiService.SelectedObject = nil
	syncPointer()
	updateSprint()
end

local function openModal(kind, title, text)
	clearSprint()
	modalKind = kind
	modalTitle.Text = title
	settingsContent.Visible = kind == "settings"
	readingContent.Visible = kind ~= "settings"
	readingText.Text = text or ""
	readingContent.CanvasPosition = Vector2.zero
	closeButton.Text = kind == "escape" and "CONTINUAR" or (kind == "note" and "FECHAR DOCUMENTO" or "VOLTAR AO JOGO")
	modalOverlay.Visible = true
	syncPointer()
	local inputType = UserInputService:GetLastInputType()
	if string.find(inputType.Name, "Gamepad") then
		GuiService.SelectedObject = kind == "settings" and motionButton or closeButton
	end
end

local function toggleSettings()
	if modalKind then
		closeModal()
	else
		openModal("settings", "CONFORTO E CONTROLES")
	end
end

local function showToast(title, text, isScare)
	toastVersion += 1
	local version = toastVersion
	toastTitle.Text = title
	toastTitle.TextColor3 = isScare and colors.amber or colors.green
	toastText.Text = text
	toast.Visible = true
	task.delay(isScare and 5 or 7, function()
		if not destroyed and toastVersion == version then
			toast.Visible = false
		end
	end)
end

local function updateMission()
	local fuses = math.clamp(tonumber(Workspace:GetAttribute("S7Fuses")) or 0, 0, 3)
	local power = Workspace:GetAttribute("S7Power") == true
	local keycard = Workspace:GetAttribute("S7Keycard") == true
	if player:GetAttribute("Escaped") == true then
		objectiveText.Text = "Você saiu do Setor 7."
	elseif fuses < 3 then
		objectiveText.Text = "Localize os três fusíveis."
	elseif not power then
		objectiveText.Text = "Religue o gerador na sala de máquinas."
	elseif not keycard then
		objectiveText.Text = "Encontre o cartão no arquivo."
	else
		objectiveText.Text = "Alcance a porta de evacuação."
	end
	progressText.Text = string.format("FUSÍVEIS %d/3  •  %s", fuses, power and "ENERGIA ON" or "ENERGIA OFF")
end

local function syncFlashlight()
	local enabled = player:GetAttribute("FlashlightOn") == true
	flashlightButton.Text = enabled and "LUZ\nON" or "LUZ\nOFF"
	flashlightButton.TextColor3 = enabled and colors.green or colors.ink
end

local function toggleFlashlight()
	if alive and not modalKind and not coreMenuOpen and player:GetAttribute("Escaped") ~= true then
		flashlightRemote:FireServer(player:GetAttribute("FlashlightOn") ~= true)
	end
end

local function updateInputHint()
	local inputName = UserInputService:GetLastInputType().Name
	local touch = UserInputService.TouchEnabled
	flashlightButton.Visible = touch
	sprintButton.Visible = touch
	if touch then
		controlHint.Text = "Toque para interagir  ·  CORRER liga/desliga"
	elseif string.find(inputName, "Gamepad") then
		controlHint.Text = "L3 correr  ·  Y lanterna  ·  X interagir  ·  VIEW opções"
	else
		controlHint.Text = "SHIFT correr  ·  F lanterna  ·  E interagir  ·  M opções"
	end
end

connect(settingsButton.Activated, toggleSettings)
connect(closeButton.Activated, closeModal)
connect(motionButton.Activated, function()
	player:SetAttribute("ReducedMotion", not reducedMotion())
end)
connect(blurButton.Activated, function()
	player:SetAttribute("CameraBlurEnabled", player:GetAttribute("CameraBlurEnabled") ~= true)
end)
connect(sprintButton.Activated, function()
	if alive and not modalKind and not coreMenuOpen then
		touchSprint = not touchSprint
		updateSprint()
	end
end)
connect(flashlightButton.Activated, toggleFlashlight)
connect(UserInputService.LastInputTypeChanged, updateInputHint)
connect(UserInputService.WindowFocusReleased, clearSprint)
connect(UserInputService.TextBoxFocused, clearSprint)
connect(GuiService.MenuOpened, function()
	coreMenuOpen = true
	if modalKind then
		closeModal()
	end
	clearSprint()
	syncPointer()
end)
connect(GuiService.MenuClosed, function()
	coreMenuOpen = false
	syncPointer()
end)
connect(player:GetAttributeChangedSignal("ReducedMotion"), syncOptions)
connect(player:GetAttributeChangedSignal("CameraBlurEnabled"), syncOptions)
connect(player:GetAttributeChangedSignal("FlashlightOn"), syncFlashlight)
connect(player:GetAttributeChangedSignal("Escaped"), function()
	clearSprint()
	updateMission()
end)
connect(player:GetAttributeChangedSignal("Exhausted"), function()
	if player:GetAttribute("Exhausted") == true then
		-- Toggle devices require a new deliberate press after exhaustion.
		touchSprint = false
		gamepadSprint = false
		updateSprint()
	end
end)
for _, attribute in ipairs({ "S7Fuses", "S7Power", "S7Keycard", "S7Escaped" }) do
	connect(Workspace:GetAttributeChangedSignal(attribute), updateMission)
end

ContextActionService:BindAction("S7Sprint", function(_, state, input)
	if input.KeyCode == Enum.KeyCode.LeftShift and state == Enum.UserInputState.End then
		keyboardSprint = false
		updateSprint()
		return Enum.ContextActionResult.Sink
	end
	if UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Cancel then
		clearSprint()
	elseif state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() and not modalKind and not coreMenuOpen then
		if input.KeyCode == Enum.KeyCode.ButtonL3 then
			gamepadSprint = not gamepadSprint
		else
			keyboardSprint = true
		end
		updateSprint()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:BindAction("S7Flashlight", function(_, state)
	if UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		toggleFlashlight()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
ContextActionService:BindAction("S7Options", function(_, state)
	if UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		toggleSettings()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)
ContextActionService:BindActionAtPriority("S7CloseReading", function(_, state)
	if modalKind and state == Enum.UserInputState.Begin then
		closeModal()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)

connect(feedbackRemote.OnClientEvent, function(payload)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" then
		return
	end
	local title = type(payload.title) == "string" and string.sub(payload.title, 1, 120) or "SETOR 7"
	local text = type(payload.text) == "string" and string.sub(payload.text, 1, 6000) or ""
	if payload.kind == "note" or payload.kind == "escape" then
		openModal(payload.kind, title, text)
	elseif payload.kind == "notice" or payload.kind == "scare" then
		local isScare = payload.kind == "scare"
		if isScare and not reducedMotion() then
			scarePulse = 0.13
		end
		showToast(title, text, isScare)
	end
end)

local function clearRunTrack()
	if runTrack then
		runTrack:Stop(0)
		runTrack:Destroy()
		runTrack = nil
	end
end

-- Preflight without playing. A failed/private asset never replaces a default slot.
local function validatedTrack(animator, id, version)
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		animation:Destroy()
		return nil
	end
	local deadline = os.clock() + 3
	while track.Length <= 0 and os.clock() < deadline and not destroyed and version == characterVersion do
		task.wait(0.1)
	end
	animation:Destroy()
	if track.Length <= 0 or destroyed or version ~= characterVersion then
		track:Destroy()
		return nil
	end
	return track
end

-- Keep Roblox Animate for walk/idle/jump/climb. R6 Animate does not select its run
-- entry, so one validated Movement-priority track handles sprinting separately.
local function applyOptionalAnimations(character, version)
	local animate = character:WaitForChild("Animate", 8)
	if not animate or destroyed or version ~= characterVersion then
		return
	end
	local characterHumanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = characterHumanoid and characterHumanoid:FindFirstChildOfClass("Animator")
	if not animator or characterHumanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return
	end
	for configName, animateName in pairs({ Walk = "walk", Run = "run", Idle = "idle" }) do
		local value = (Config.Animations or {})[configName]
		local id = type(value) == "string" and string.match(value, "^rbxassetid://(%d+)$") or nil
		id = id or (type(value) == "string" and string.match(value, "^(%d+)$"))
		local group = animate:FindFirstChild(animateName)
		if id then
			local track = validatedTrack(animator, id, version)
			if track then
				if configName == "Run" then
					clearRunTrack()
					track.Priority = Enum.AnimationPriority.Movement
					track.Looped = true
					runTrack = track
				else
					track:Destroy()
					if not group then
						-- Source-only R6 Animate has no child slots; adding a configured
						-- group triggers its normal ChildAdded configuration path.
						group = Instance.new("Folder")
						group.Name = animateName
						local animation = Instance.new("Animation")
						animation.Name = configName .. "Anim"
						animation.AnimationId = "rbxassetid://" .. id
						animation.Parent = group
						group.Parent = animate
					else
						for _, animation in ipairs(group:GetDescendants()) do
							if animation:IsA("Animation") then
								animation.AnimationId = "rbxassetid://" .. id
							end
						end
					end
				end
			end
		end
	end
end

local lastOffset = CFrame.identity
local offsetCamera = nil
local lastApplied = nil
local previousBase = nil
local phase = 0
local motionAmount = 0

local function removeCameraOffset()
	if offsetCamera and lastApplied then
		-- Do not overwrite a cutscene or another camera owner that moved the camera.
		if offsetCamera.CFrame:FuzzyEq(lastApplied, 0.0001) then
			offsetCamera.CFrame = offsetCamera.CFrame * lastOffset:Inverse()
		end
	end
	lastOffset = CFrame.identity
	offsetCamera = nil
	lastApplied = nil
end

local function bindCharacter(character)
	characterVersion += 1
	local version = characterVersion
	for _, connection in ipairs(characterConnections) do
		connection:Disconnect()
	end
	table.clear(characterConnections)
	alive = false
	humanoid = nil
	rootPart = nil
	clearRunTrack()
	clearSprint()
	closeModal()
	removeCameraOffset()
	previousBase = nil
	phase = 0
	motionAmount = 0
	blur.Size = 0
	task.spawn(function()
		local nextHumanoid = character:WaitForChild("Humanoid", 10)
		local nextRoot = character:WaitForChild("HumanoidRootPart", 10)
		if destroyed or version ~= characterVersion or not nextHumanoid or not nextRoot then
			return
		end
		humanoid = nextHumanoid
		rootPart = nextRoot
		alive = humanoid.Health > 0
		displayedStamina = tonumber(player:GetAttribute("Stamina")) or maxStamina
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		syncPointer()
		table.insert(characterConnections, humanoid.Died:Connect(function()
			alive = false
			clearSprint()
			closeModal()
			removeCameraOffset()
			blur.Size = 0
			previousBase = nil
			showToast("SINAL INTERROMPIDO", "Aguardando retorno ao abrigo…", false)
		end))
		applyOptionalAnimations(character, version)
	end)
end

connect(player.CharacterAdded, bindCharacter)
connect(player.CharacterRemoving, function()
	characterVersion += 1
	alive = false
	humanoid = nil
	rootPart = nil
	clearRunTrack()
	clearSprint()
	closeModal()
	removeCameraOffset()
	blur.Size = 0
end)

-- Unwind our last transform BEFORE Roblox's camera reads CFrame, then add a new
-- one AFTER it updates. No effect is fed back into the camera's next base pose.
RunService:BindToRenderStep("S7CameraUnwind", Enum.RenderPriority.Camera.Value - 1, removeCameraOffset)
RunService:BindToRenderStep("S7CameraPresentation", Enum.RenderPriority.Camera.Value + 1, function(rawDt)
	local dt = math.clamp(rawDt, 1 / 240, 1 / 15)
	local targetStamina = math.clamp(tonumber(player:GetAttribute("Stamina")) or maxStamina, 0, maxStamina)
	-- Interpolate replicated authority; this never changes stamina or WalkSpeed.
	displayedStamina += (targetStamina - displayedStamina) * (1 - math.exp(-dt * 15))
	local fraction = math.clamp(displayedStamina / maxStamina, 0, 1)
	local exhausted = player:GetAttribute("Exhausted") == true
	staminaFill.Size = UDim2.fromScale(fraction, 1)
	staminaFill.BackgroundColor3 = exhausted and colors.red or (fraction < 0.3 and colors.amber or colors.green)
	staminaNumber.Text = string.format("%d%%", math.floor(fraction * 100 + 0.5))
	staminaText.Text = not alive and "SEM SINAL" or (exhausted and "RECUPERANDO FÔLEGO" or "FÔLEGO")
	staminaText.TextColor3 = exhausted and colors.amber or colors.muted
	if runTrack then
		local state = humanoid and humanoid:GetState()
		local running = alive and humanoid and rootPart and player:GetAttribute("Sprinting") == true
			and humanoid.MoveDirection.Magnitude > 0.05
			and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics)
			and humanoid.FloorMaterial ~= Enum.Material.Air
		if running then
			if not runTrack.IsPlaying then
				runTrack:Play(0.15)
			end
			local velocity = rootPart.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			runTrack:AdjustSpeed(math.clamp(speed / math.max(1, Config.SprintSpeed or 18), 0.5, 1.4))
		elseif runTrack.IsPlaying then
			runTrack:Stop(0.15)
		end
	end
	scarePulse = math.max(0, scarePulse - dt * 0.09)
	scareShade.BackgroundTransparency = 1 - (reducedMotion() and 0 or scarePulse)

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if not cameraFovs[camera] then
		cameraFovs[camera] = camera.FieldOfView
	end
	local validCamera = camera.CameraType == Enum.CameraType.Custom and humanoid and camera.CameraSubject == humanoid
	if not validCamera then
		previousBase = nil
		blur.Size = 0
		return
	end
	local canMove = alive and not modalKind and not coreMenuOpen and not reducedMotion()
	local sprinting = player:GetAttribute("Sprinting") == true
	local targetFov = canMove and sprinting and sprintFov or baseFov
	camera.FieldOfView += (targetFov - camera.FieldOfView) * (1 - math.exp(-dt * 7))
	local base = camera.CFrame
	local angularSpeed = 0
	local yawVelocity = 0
	if previousBase and canMove then
		local _, yaw = previousBase:ToObjectSpace(base):ToOrientation()
		yawVelocity = yaw / math.max(rawDt, 1 / 240)
		angularSpeed = math.acos(math.clamp(previousBase.LookVector:Dot(base.LookVector), -1, 1)) / math.max(rawDt, 1 / 240)
	end
	previousBase = base
	local walking = false
	local speed = 0
	if canMove and humanoid and rootPart then
		local velocity = rootPart.AssemblyLinearVelocity
		speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		walking = humanoid.MoveDirection.Magnitude > 0.05 and speed > 0.7 and humanoid.FloorMaterial ~= Enum.Material.Air
	end
	local targetMotion = walking and 1 or 0
	motionAmount += (targetMotion - motionAmount) * (1 - math.exp(-dt * 12))
	if not canMove then
		motionAmount = 0
	end
	if walking then
		phase += dt * (sprinting and 11.5 or 8.0) * math.clamp(speed / (Config.WalkSpeed or 10), 0.5, 1.35)
	end
	local strength = bobStrength * motionAmount
	local x = math.sin(phase) * strength * 0.42
	local y = math.cos(phase * 2) * strength * 0.65
	local roll = canMove and math.clamp(-yawVelocity * 0.0025, -0.009, 0.009) or 0
	local offset = CFrame.new(x, y, 0) * CFrame.Angles(0, 0, roll)
	lastOffset = offset
	offsetCamera = camera
	lastApplied = base * offset
	camera.CFrame = lastApplied
	local targetBlur = canMove and player:GetAttribute("CameraBlurEnabled") == true
		and math.clamp((angularSpeed - 0.45) * 0.65, 0, maxBlur) or 0
	blur.Size = math.clamp(blur.Size + (targetBlur - blur.Size) * (1 - math.exp(-dt * 10)), 0, maxBlur)
end)

local function updateLayout()
	local size = safeRoot.AbsoluteSize
	local compact = size.Y < 440
	local top = compact and 42 or 54
	objective.Position = UDim2.fromOffset(16, top)
	settingsButton.Position = UDim2.new(1, -16, 0, top)
	controlHint.Visible = size.X >= 480 and not compact
	modal.Position = UDim2.fromScale(0.5, compact and 0.55 or 0.52)
	modal.Size = UDim2.fromScale(0.86, compact and 0.82 or 0.78)
	-- Touch actions stay above the default jump button and away from the thumbstick.
	flashlightButton.Position = UDim2.new(1, -18, compact and 0.40 or 0.43, 0)
	sprintButton.Position = UDim2.new(1, -18, compact and 0.63 or 0.62, 0)
end
connect(safeRoot:GetPropertyChangedSignal("AbsoluteSize"), updateLayout)

connect(script.Destroying, function()
	destroyed = true
	characterVersion += 1
	clearSprint()
	clearRunTrack()
	removeCameraOffset()
	RunService:UnbindFromRenderStep("S7CameraUnwind")
	RunService:UnbindFromRenderStep("S7CameraPresentation")
	for _, action in ipairs({ "S7Sprint", "S7Flashlight", "S7Options", "S7CloseReading" }) do
		ContextActionService:UnbindAction(action)
	end
	for _, connection in ipairs(characterConnections) do
		connection:Disconnect()
	end
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	for camera, fov in pairs(cameraFovs) do
		if camera.Parent then
			camera.FieldOfView = fov
		end
	end
	player.CameraMode = originalCameraMode
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = originalMouseIcon
	GuiService.SelectedObject = nil
	blur:Destroy()
	hud:Destroy()
	effectsGui:Destroy()
end)

syncOptions()
syncFlashlight()
updateMission()
updateInputHint()
updateLayout()
if player.Character then
	bindCharacter(player.Character)
end
