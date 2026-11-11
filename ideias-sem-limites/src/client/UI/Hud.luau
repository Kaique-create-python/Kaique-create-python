--!strict
-- HUD principal: barra de ideias no topo (não cobre analógico nem botão de
-- pulo), prévia ao vivo da interpretação, botão CRIAR com recarga,
-- indicador de capacidade do mundo, notificações e destaques.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("IdeiasShared")
local Config = require(Shared.Config)
local Planner = require(Shared.Planner)
local Theme = require(script.Parent.Theme)
local Settings = require(script.Parent.Parent.Settings)

local Hud = {}

local player = Players.LocalPlayer
local C = Theme.Colors
local new = Theme.new

Hud.onSubmit = nil :: ((string) -> ())?
Hud.history = {} :: { string }

local gui: ScreenGui
local bar: Frame
local box: TextBox
local createBtn: TextButton
local cooldownFill: Frame
local previewLabel: TextLabel
local feedback: TextLabel
local capLabel: TextLabel
local capFill: Frame
local toastList: Frame
local banner: Frame
local cooldownUntil = 0
local sounds: { [string]: Sound } = {}

local Effects: any = nil
local function sound(name: string)
	if not Settings.values.sounds then
		return
	end
	-- criar/erro usam os sons do ElevenLabs quando o sprite está no jogo
	if Config.SoundSprite and Config.SoundSprite.Id ~= 0 then
		if not Effects then
			local ok, mod = pcall(require, script.Parent.Parent.FX.Effects)
			Effects = if ok then mod else false
		end
		if Effects and Effects.cue then
			Effects.cue(if name == "Error" then "error" elseif name == "Click" then "click" elseif name == "Achievement" then "achievement" else "create", nil, 1)
			return
		end
	end
	local s = sounds[name]
	if s then
		s:Play()
	end
end
Hud.sound = sound

local function makeSounds()
	for name, id in Config.Sounds do
		local s = Instance.new("Sound")
		s.Name = "Ideias_" .. name
		s.SoundId = id
		s.Volume = 0.5
		s.Parent = SoundService
		sounds[name] = s
	end
end

function Hud.build(parent: Instance): ScreenGui
	makeSounds()
	Theme.onClick = function()
		sound("Click")
	end
	gui = new("ScreenGui", {
		Name = "IdeiasHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})
	local uiScale = new("UIScale", { Parent = gui })
	local function rescale()
		local cam = workspace.CurrentCamera
		local vp = if cam then cam.ViewportSize else Vector2.new(1000, 600)
		local s = math.clamp(math.min(vp.X / 960, vp.Y / 520), 0.72, 1.25)
		uiScale.Scale = s * (Settings.values.uiScale or 1)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	Settings.onChanged(function(key)
		if key == "uiScale" then
			rescale()
		end
	end)

	-- barra de ideias -----------------------------------------------------------
	bar = new("Frame", {
		Name = "Barra",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0.58, 0, 0, 52),
		BackgroundColor3 = Color3.fromRGB(30, 30, 38),
		BackgroundTransparency = 0.06,
		Parent = gui,
	}, {
		Theme.corner(26),
		Theme.stroke(Theme.Ink, 3, 0),
		new("UISizeConstraint", { MinSize = Vector2.new(300, 52), MaxSize = Vector2.new(620, 52) }),
	})
	local icon = Theme.label({
		Text = "💡",
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(44, 52),
		Parent = bar,
	})
	Theme.icon("ideias", 40, icon, function(loaded)
		icon.TextTransparency = if loaded then 1 else 0
	end)
	box = new("TextBox", {
		Name = "Texto",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -170, 1, 0),
		Text = "",
		PlaceholderText = "Digite qualquer ideia... (ex.: dragão de gelo)",
		PlaceholderColor3 = C.muted,
		TextColor3 = C.text,
		FontFace = Theme.Font,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = bar,
	})
	createBtn = Theme.button({
		Name = "Criar",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(116, 40),
		Text = "CRIAR",
		TextSize = 21,
		FontFace = Theme.FontHeavy,
		BackgroundColor3 = Theme.TileColors.ideias,
		TextColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Parent = bar,
	})
	createBtn.Parent = bar
	new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = createBtn })
	-- botão estilo azulejo: contorno escuro grosso e texto branco com borda preta
	local border = createBtn:FindFirstChildOfClass("UIStroke")
	if border then
		border.Color = Theme.Ink
		border.Thickness = 3
		border.Transparency = 0
	end
	Theme.outlined(createBtn, 2.2)
	cooldownFill = new("Frame", {
		Name = "Recarga",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 2,
		Parent = createBtn,
	}, { Theme.corner(20) })

	-- botão CRIAR pulsando quando pronto
	do
		task.spawn(function()
			while createBtn.Parent do
				local ready = os.clock() >= cooldownUntil
				local k = 1 + (if ready then math.sin(os.clock() * 4) * 0.035 else 0)
				local sc = createBtn:FindFirstChild("Pulso") :: UIScale?
				if sc then
					sc.Scale = k
				end
				task.wait(1 / 30)
			end
		end)
	end
	new("UIScale", { Name = "Pulso", Parent = createBtn })

	-- sugestões rápidas: toque para usar
	local IDEAS = {
		"dragão de fogo gigante", "arma que atira cachorro", "goku contra freeza", "buraco negro", "tung tung tung sahur",
		"chuva de pizza", "meteoro", "terremoto", "bomba nuclear", "gato tubarão", "jesus", "titã colossal",
		"tralalero tralala", "circo", "vingadores", "naruto", "dinossauro robô", "vaca que vira dragão",
	}
	local chips = new("Frame", {
		Name = "Sugestoes",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.new(0.62, 0, 0, 30),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }),
		new("UISizeConstraint", { MaxSize = Vector2.new(640, 30) }),
	})
	local function fillChips()
		for _, c in chips:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		local used = {}
		for _ = 1, 3 do
			local idea
			repeat
				idea = IDEAS[math.random(1, #IDEAS)]
			until not used[idea]
			used[idea] = true
			local b = Theme.button({ Text = "✨ " .. idea, TextSize = 13, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), BackgroundColor3 = C.bg, BackgroundTransparency = 0.25, Parent = chips })
			new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = b })
			b.Activated:Connect(function()
				box.Text = idea
				Hud.updatePreview()
				sound("Click")
			end)
		end
	end
	fillChips()
	task.spawn(function()
		while chips.Parent do
			task.wait(9)
			chips.Visible = box.Text == ""
			if chips.Visible then
				fillChips()
			end
		end
	end)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		chips.Visible = box.Text == ""
	end)

	-- abertura: logo animado ao entrar no jogo (imagem do Canva se enviada)
	task.spawn(function()
		local splash = new("Frame", { Name = "Abertura", BackgroundColor3 = Color3.fromRGB(8, 10, 24), BackgroundTransparency = 0.15, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = gui })
		local logoId = Config.UiImages and Config.UiImages.Logo or 0
		local logo = Theme.label({ Text = "IDEIAS SEM LIMITES", TextScaled = true, FontFace = Theme.FontHeavy, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.8, 0.16), ZIndex = 21, Parent = splash })
		Theme.gradient(Color3.fromRGB(110, 230, 255), Color3.fromRGB(255, 120, 200), 0).Parent = logo
		Theme.stroke(Color3.new(0, 0, 0), 3, 0).Parent = logo
		local logoImage: ImageLabel? = nil
		if logoId ~= 0 then
			logoImage = new("ImageLabel", { BackgroundTransparency = 1, Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.5, 0.5), Image = "rbxthumb://type=Asset&id=" .. tostring(logoId) .. "&w=420&h=420", ScaleType = Enum.ScaleType.Fit, ZIndex = 21, Parent = splash })
			Theme.imageFallback(logoImage, function(loaded)
				logo.Visible = not loaded
			end)
			local imageScale = new("UIScale", { Scale = 0.6, Parent = logoImage })
			Theme.tween(imageScale, 0.8, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		local sub = Theme.label({ Text = "Escreva qualquer coisa. Ela vira realidade.", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(0.8, 0.06), ZIndex = 21, Parent = splash })
		local sc = new("UIScale", { Scale = 0.6, Parent = logo })
		Theme.tween(sc, 0.8, { Scale = 1 }, Enum.EasingStyle.Back)
		task.wait(2.6)
		Theme.tween(splash, 0.6, { BackgroundTransparency = 1 })
		Theme.tween(sub, 0.6, { TextTransparency = 1 })
		Theme.tween(logo, 0.6, { TextTransparency = 1 })
		if logoImage then
			Theme.tween(logoImage, 0.6, { ImageTransparency = 1 })
		end
		task.wait(0.7)
		splash:Destroy()
	end)

	-- prévia + retorno logo abaixo da barra
	previewLabel = Theme.label({
		Name = "Previa",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.new(0.9, 0, 0, 22),
		Text = "",
		TextSize = 15,
		TextColor3 = C.accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.6,
		FontFace = Theme.FontBold,
		Parent = gui,
	})
	feedback = Theme.label({
		Name = "Retorno",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 86),
		Size = UDim2.new(0.9, 0, 0, 24),
		Text = "",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		FontFace = Theme.FontBold,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		Parent = gui,
	})

	-- capacidade do mundo (canto superior direito da barra)
	local cap = new("Frame", {
		Name = "Capacidade",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(96, 40),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.2,
		Parent = gui,
	}, { Theme.corner(12), Theme.stroke(nil, 1, 0.6) })
	capLabel = Theme.label({
		Text = "🌍 0/12",
		TextSize = 15,
		FontFace = Theme.FontBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = cap,
	})
	local capBack = new("Frame", {
		BackgroundColor3 = C.bg2,
		Position = UDim2.new(0, 10, 1, -11),
		Size = UDim2.new(1, -20, 0, 5),
		Parent = cap,
	}, { Theme.corner(3) })
	capFill = new("Frame", { BackgroundColor3 = C.good, Size = UDim2.fromScale(0, 1), Parent = capBack }, { Theme.corner(3) })

	-- notificações (lado direito, abaixo do topo)
	toastList = new("Frame", {
		Name = "Avisos",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 120),
		Size = UDim2.fromOffset(300, 300),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})

	-- destaque (conquistas, segredos)
	banner = new("Frame", {
		Name = "Destaque",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -140),
		Size = UDim2.fromOffset(420, 86),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.05,
		Parent = gui,
	}, { Theme.corner(18), Theme.stroke(C.gold, 2.5, 0.1), Theme.gradient(Color3.fromRGB(40, 32, 70), Color3.fromRGB(20, 22, 36), 90) })
	Theme.label({ Name = "Titulo", Text = "", TextSize = 22, FontFace = Theme.FontHeavy, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 30), Parent = banner })
	Theme.label({ Name = "Texto", Text = "", TextSize = 16, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 40), Size = UDim2.new(1, -20, 0, 40), Parent = banner })

	-- eventos ---------------------------------------------------------------------
	local lastTyped = 0
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > Config.Request.MaxTextLength then
			box.Text = string.sub(box.Text, 1, Config.Request.MaxTextLength)
		end
		lastTyped = os.clock()
		local stamp = lastTyped
		task.delay(0.18, function()
			if stamp == lastTyped then
				Hud.updatePreview()
			end
		end)
	end)
	box.FocusLost:Connect(function(enter)
		if enter then
			Hud.submit()
		end
	end)
	createBtn.Activated:Connect(function()
		Hud.submit()
	end)
	RunService.RenderStepped:Connect(function()
		local left = cooldownUntil - os.clock()
		if left > 0 then
			cooldownFill.Size = UDim2.fromScale(left / Config.Request.Cooldown, 1)
			createBtn.Text = string.format("%.1fs", left)
		elseif createBtn.Text ~= "CRIAR" then
			cooldownFill.Size = UDim2.fromScale(0, 1)
			createBtn.Text = "CRIAR"
		end
	end)
	return gui
end

function Hud.updatePreview()
	local text = box.Text
	if #string.gsub(text, "%s", "") == 0 then
		previewLabel.Text = ""
		return
	end
	local ok, plan = pcall(Planner.plan, text)
	if ok then
		previewLabel.Text = (if plan.surprise then "🎲 " else "→ ") .. plan.label
		previewLabel.TextColor3 = if plan.surprise then C.warn else C.accent
	else
		previewLabel.Text = ""
	end
end

function Hud.setText(text: string)
	box.Text = text
	Hud.updatePreview()
end

function Hud.focus()
	box:CaptureFocus()
end

function Hud.submit()
	local text = box.Text
	if #string.gsub(text, "%s", "") == 0 then
		Theme.shake(bar)
		Hud.feedback("Digite uma ideia primeiro 💡", C.warn)
		return
	end
	if os.clock() < cooldownUntil then
		Theme.shake(createBtn)
		sound("Error")
		return
	end
	cooldownUntil = os.clock() + Config.Request.Cooldown
	Theme.pop(createBtn)
	sound("Click")
	-- histórico local (texto do próprio jogador, mostrado só para ele)
	local i = table.find(Hud.history, text)
	if i then
		table.remove(Hud.history, i)
	end
	table.insert(Hud.history, 1, text)
	while #Hud.history > Config.Data.MaxHistory do
		table.remove(Hud.history)
	end
	if Hud.onSubmit then
		Hud.onSubmit(text)
	end
end

function Hud.result(res: any)
	if type(res) ~= "table" then
		Hud.feedback("Sem resposta do servidor", C.bad)
		return
	end
	if res.ok then
		box.Text = ""
		previewLabel.Text = ""
		sound("Create")
		local msg = (res.icon or "✨") .. " " .. tostring(res.label)
		if res.notes and #res.notes > 0 then
			msg ..= "  •  " .. tostring(res.notes[1])
		end
		Hud.feedback(msg, if res.surprise then C.warn else C.good)
		for _, d in res.discovered or {} do
			Hud.toast("📖 Nova descoberta: " .. d, C.accent)
		end
		if res.cooldown then
			cooldownUntil = os.clock() + res.cooldown
		end
	else
		sound("Error")
		Theme.shake(bar)
		Hud.feedback("⚠️ " .. tostring(res.message or "Não foi possível criar"), C.bad)
		if res.wait and res.wait > 0 then
			cooldownUntil = os.clock() + res.wait
		elseif res.reason ~= "cooldown" then
			cooldownUntil = 0
		end
	end
end

local feedbackStamp = 0
function Hud.feedback(text: string, color: Color3)
	feedbackStamp += 1
	local stamp = feedbackStamp
	feedback.Text = text
	feedback.TextColor3 = color
	feedback.TextTransparency = 0
	feedback.TextStrokeTransparency = 0.4
	task.delay(3.2, function()
		if stamp == feedbackStamp then
			Theme.tween(feedback, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

local toastOrder = 0
function Hud.toast(text: string, color: Color3?)
	if not Settings.values.notifications then
		return
	end
	toastOrder += 1
	local item = new("Frame", {
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromOffset(290, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = toastOrder,
		Parent = toastList,
	}, {
		Theme.corner(10),
		Theme.padding(8),
		new("UIStroke", { Color = color or C.accent, Thickness = 1.5, Transparency = 0.3 }),
	})
	Theme.label({ Text = text, TextSize = 15, TextColor3 = color or C.text, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, FontFace = Theme.FontBold, Parent = item })
	-- no máximo 4 avisos visíveis
	local items = {}
	for _, ch in toastList:GetChildren() do
		if ch:IsA("Frame") then
			table.insert(items, ch)
		end
	end
	table.sort(items, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #items > 4 do
		items[1]:Destroy()
		table.remove(items, 1)
	end
	task.delay(4.5, function()
		if item.Parent then
			Theme.tween(item, 0.4, { BackgroundTransparency = 1 })
			for _, d in item:GetDescendants() do
				if d:IsA("TextLabel") then
					Theme.tween(d, 0.4, { TextTransparency = 1 })
				elseif d:IsA("UIStroke") then
					Theme.tween(d, 0.4, { Transparency = 1 })
				end
			end
			task.wait(0.45)
			item:Destroy()
		end
	end)
end

function Hud.banner(title: string, text: string)
	sound("Create")
	local t = banner:FindFirstChild("Titulo") :: TextLabel
	local d = banner:FindFirstChild("Texto") :: TextLabel
	t.Text = title
	d.Text = text
	Theme.tween(banner, 0.45, { Position = UDim2.new(0.5, 0, 0, 104) }, Enum.EasingStyle.Back)
	task.delay(3.6, function()
		Theme.tween(banner, 0.4, { Position = UDim2.new(0.5, 0, 0, -140) })
	end)
end

function Hud.capacity(cap: any)
	if type(cap) ~= "table" then
		return
	end
	capLabel.Text = string.format("🌍 %d/%d", cap.events or 0, cap.maxEvents or 12)
	local load = math.clamp(cap.load or 0, 0, 1)
	Theme.tween(capFill, 0.3, { Size = UDim2.fromScale(load, 1) })
	capFill.BackgroundColor3 = if load > 0.85 then C.bad elseif load > 0.6 then C.warn else C.good
end

Hud._gui = function()
	return gui
end
Hud._guiService = GuiService
Hud._player = player

return Hud
