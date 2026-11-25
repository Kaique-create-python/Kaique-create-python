-- CyberOutlaw · vida em Maré Baixa no cliente (LocalScript em StarterPlayerScripts).
-- Carteira em €$ e estrelas de procurado na barra de cima, linha de objetivo com distância e prazo, marcador
-- no mundo, holochamada dos fixers na visão (sem celular: a chamada aparece no canto, com o rosto do fixer
-- em holograma e legendas), painel da Casa (loja de móveis, meus móveis, reforma), posicionamento de móveis
-- no apartamento e o painel do Agente (contatos, trabalho atual, não perturbe). Conversa com life.server.luau.

local MEDIA = __CYBEROUTLAW_MEDIA__
local SOUNDS = if type(MEDIA) == "table" and type(MEDIA.sons) == "table" then MEDIA.sons else {}

local M = {}

-- Pura: confere se um móvel cabe na unidade (mesma regra do servidor, para o fantasma ficar vermelho).
local function footprint(size: Vector3, rot: number): (number, number)
	if rot % 2 == 1 then
		return size.Z / 2, size.X / 2
	end
	return size.X / 2, size.Z / 2
end
local function fits(unit, sizes, floors, placed, id: string, x: number, z: number, rot: number, ignore: number?): boolean
	local size = sizes[id]
	if not size then
		return false
	end
	local hx, hz = footprint(size, rot)
	if math.abs(x) + hx > unit.meia[1] + 0.01 or math.abs(z) + hz > unit.meia[2] + 0.01 then
		return false
	end
	local k = unit.livre
	if x + hx > k[1] and x - hx < k[2] and z + hz > k[3] and z - hz < k[4] then
		return false
	end
	for _, item in placed do
		if item.u ~= ignore and not floors[id] and not floors[item.id] and sizes[item.id] then
			local ox, oz = footprint(sizes[item.id], item.r)
			if math.abs(item.x - x) < hx + ox - 0.1 and math.abs(item.z - z) < hz + oz - 0.1 then
				return false
			end
		end
	end
	return true
end
M.fits = fits

local function money(value: number): string
	local text = tostring(math.floor(math.abs(value)))
	local out = text:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then
		out = out:sub(2)
	end
	return (if value < 0 then "-" else "") .. "€$ " .. out
end
M.money = money

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end
M.clock = clock

-- Cliente ------------------------------------------------------------------------------------------------
local TEXT = Color3.fromRGB(242, 243, 246)
local SUB = Color3.fromRGB(164, 170, 184)
local PANEL = Color3.fromRGB(12, 11, 26)
local NEON = Color3.fromRGB(86, 255, 222)
local PINK = Color3.fromRGB(255, 72, 140)
local GOLD = Color3.fromRGB(255, 208, 102)
local GREEN = Color3.fromRGB(98, 232, 148)
local RED = Color3.fromRGB(255, 70, 84)
local HOT = Color3.fromRGB(255, 84, 92) -- vermelho das molduras (Cyberpunk)
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"

local function start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local SoundService = game:GetService("SoundService")
	local HttpService = game:GetService("HttpService")
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local folder = ReplicatedStorage:WaitForChild("CyberOutlawVida", 120)
	if not folder then
		return
	end
	local request = folder:WaitForChild("Pedido") :: RemoteEvent
	local notice = folder:WaitForChild("Aviso") :: RemoteEvent
	local function decode(name: string, fallback)
		local ok, value = pcall(HttpService.JSONDecode, HttpService, folder:GetAttribute(name) or "")
		return if ok and value then value else fallback
	end
	local catalog = decode("Catalogo", {})
	local renovations = decode("Reformas", {})
	local fixerList = decode("Fixers", {})
	local economy = decode("Economia", { faxina = 150, venda = 0.5 })
	local unitRule = decode("Unidade", { meia = { 26, 21 }, livre = { 12, 26, 8, 21 }, grade = 0.5 })
	local byId, sizes, floors = {}, {}, {}
	for _, def in catalog do
		byId[def.id] = def
		sizes[def.id] = Vector3.new(def.tam[1], def.tam[2], def.tam[3])
		floors[def.id] = def.chao
	end
	table.sort(catalog, function(a, b)
		return a.ordem < b.ordem
	end)
	local fixers = {}
	for _, fixer in fixerList do
		fixers[fixer.id] = fixer
	end
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local house = { unidade = 0, moveis = {}, guardados = {}, sujeira = {} }

	local function sound(key: string, volume: number?)
		local id = SOUNDS[key]
		if type(id) ~= "number" or id <= 0 then
			return
		end
		local item = Instance.new("Sound")
		item.SoundId = string.format("rbxassetid://%.0f", id)
		item.Volume = volume or 0.6
		SoundService:PlayLocalSound(item)
		item:Destroy()
	end

	-- Kit de interface -----------------------------------------------------------------------------------
	local function new(class: string, parent: Instance?, props)
		local item = Instance.new(class)
		for key, value in props or {} do
			(item :: any)[key] = value
		end
		item.Parent = parent
		return item
	end
	local function font(weight)
		return Font.new(BUILDER, weight or Enum.FontWeight.Bold)
	end
	local function corner(item, radius: number)
		-- Estilo Cyberpunk: cantos quase retos.
		new("UICorner", item, { CornerRadius = UDim.new(0, math.min(radius, 2)) })
	end
	local function outline(item, color: Color3, transparency: number, thickness: number?)
		return new("UIStroke", item, { Color = color, Transparency = transparency, Thickness = thickness or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	end
	local function text(parent, name, value, size, color, props)
		local base = {
			Name = name, Text = value, FontFace = font(), TextSize = size, TextColor3 = color, BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromScale(1, 1),
		}
		for key, value2 in props or {} do
			base[key] = value2
		end
		return new("TextLabel", parent, base)
	end
	local function plate(parent, name, props)
		local base = { Name = name, BackgroundColor3 = PANEL, BackgroundTransparency = 0.18, BorderSizePixel = 0 }
		for key, value in props or {} do
			base[key] = value
		end
		local item = new("Frame", parent, base)
		corner(item, 2)
		outline(item, HOT, 0.3)
		-- Aba vermelha no canto de cima (assinatura dos painéis de Night City).
		new("Frame", item, { Name = "Aba", Position = UDim2.fromOffset(-1, -3), Size = UDim2.fromOffset(26, 3), BackgroundColor3 = HOT, BorderSizePixel = 0, ZIndex = 30 })
		return item
	end
	local function button(parent, name, caption, color: Color3, props, onClick)
		local base = {
			Name = name, Text = caption, FontFace = font(Enum.FontWeight.ExtraBold), TextSize = 14, TextColor3 = color,
			BackgroundColor3 = PANEL, BackgroundTransparency = 0.1, AutoButtonColor = true, BorderSizePixel = 0,
		}
		for key, value in props or {} do
			base[key] = value
		end
		local item = new("TextButton", parent, base)
		corner(item, 6)
		outline(item, color, 0.2)
		item.Activated:Connect(onClick)
		return item
	end

	local gui = new("ScreenGui", player:WaitForChild("PlayerGui"), {
		Name = "CyberOutlawVida", ResetOnSpawn = false, DisplayOrder = 36, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, Enabled = false,
	})
	local top = new("ScreenGui", player.PlayerGui, {
		Name = "CyberOutlawVidaTopo", ResetOnSpawn = false, DisplayOrder = 36, ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets, Enabled = false,
	})

	-- Carteira e estrelas, à direita da barra do Roblox.
	local chip = new("Frame", top, {
		Name = "Carteira", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(140, 30),
		BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
	})
	new("UIGradient", chip, { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.45), NumberSequenceKeypoint.new(1, 0.35) }) })
	new("Frame", chip, { Name = "Traco", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.new(0.8, 0, 0, 2), BackgroundColor3 = GOLD, BorderSizePixel = 0 })
	local wallet = text(chip, "Valor", money(0), 17, GOLD, {
		TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -8, 1, 0), FontFace = font(Enum.FontWeight.ExtraBold),
		TextStrokeTransparency = 0.7, TextStrokeColor3 = GOLD,
	})
	local stars = text(top, "Estrelas", "", 18, RED, {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -166, 0.5, 0), Size = UDim2.fromOffset(110, 30),
		TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.4, Visible = false,
	})
	local function refreshWallet()
		wallet.Text = money(player:GetAttribute("CyberOutlawEddies") or 0)
	end
	player:GetAttributeChangedSignal("CyberOutlawEddies"):Connect(refreshWallet)
	refreshWallet()

	-- Avisos rápidos (dinheiro, mensagens) embaixo da carteira.
	local toasts = new("Frame", gui, {
		Name = "Avisos", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, if touch then 118 else 12), Size = UDim2.fromOffset(300, 200),
		BackgroundTransparency = 1,
	})
	new("UIListLayout", toasts, { HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	local toastCount = 0
	local function toast(message: string, color: Color3?)
		toastCount += 1
		local item = plate(toasts, "Aviso", { Size = UDim2.fromOffset(300, 30), LayoutOrder = toastCount })
		item:FindFirstChildOfClass("UIStroke").Color = color or NEON
		text(item, "Texto", message, 14, color or TEXT, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -16, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
		task.delay(4.5, function()
			item:Destroy()
		end)
		local list = toasts:GetChildren()
		local frames = 0
		for _, child in list do
			if child:IsA("Frame") then
				frames += 1
			end
		end
		if frames > 5 then
			for _, child in list do
				if child:IsA("Frame") then
					child:Destroy()
					break
				end
			end
		end
	end

	-- Botões Casa (H) e Agente (J): no toque, embaixo dos botões de cima; no PC, acima dos implantes.
	local function hudButton(name: string, caption: string, key: string?)
		local item = new("TextButton", gui, {
			Name = name, Text = caption .. (if key and not touch then "  " .. key else ""), FontFace = font(Enum.FontWeight.ExtraBold), TextSize = 12,
			TextColor3 = NEON, BackgroundColor3 = PANEL, BackgroundTransparency = 0.3, AutoButtonColor = true, BorderSizePixel = 0,
			Size = UDim2.fromOffset(if touch then 58 else 84, if touch then 40 else 34), AnchorPoint = Vector2.new(1, 0),
		})
		corner(item, 2)
		outline(item, HOT, 0.12)
		item.TextColor3 = HOT
		return item
	end
	local homeButton = hudButton("Casa", "CASA", "H")
	local agentButton = hudButton("Agente", "AGENTE", "J")
	local function layoutButtons()
		local size = gui.AbsoluteSize
		if touch then
			homeButton.Position = UDim2.fromOffset(size.X - 12, 62)
			agentButton.Position = UDim2.fromOffset(size.X - 76, 62)
		else
			homeButton.AnchorPoint, agentButton.AnchorPoint = Vector2.new(1, 1), Vector2.new(1, 1)
			homeButton.Position = UDim2.fromOffset(size.X - 24, size.Y - 96)
			agentButton.Position = UDim2.fromOffset(size.X - 116, size.Y - 96)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutButtons)
	task.defer(layoutButtons)

	-- Objetivo da missão: linha no alto e um losango no mundo.
	-- Como no Cyberpunk: o trabalho fica num canto, em duas linhas (quem pagou e o prazo; o que fazer e a distância).
	local objective = new("Frame", gui, {
		Name = "Objetivo", AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(1, 0), Position = if touch then UDim2.fromOffset(12, 172) else UDim2.new(1, -24, 0, 16),
		Size = UDim2.fromOffset(if touch then 220 else 330, if touch then 38 else 46), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Visible = false,
	})
	new("UIGradient", objective, { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.95) }) })
	new("Frame", objective, { Name = "Traco", Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = GOLD, BorderSizePixel = 0 })
	local objectiveHead = text(objective, "Rotulo", "TRABALHO", if touch then 9 else 11, HOT, {
		Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -14, 0.42, 0), FontFace = Font.fromEnum(Enum.Font.Michroma), TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local objectiveText = text(objective, "Texto", "", if touch then 12 else 15, GOLD, {
		Position = UDim2.new(0, 10, 0.42, 0), Size = UDim2.new(1, -14, 0.58, -2), TextTruncate = Enum.TextTruncate.AtEnd, TextStrokeTransparency = 0.6,
	})
	local marker = new("Part", nil, {
		Name = "CyberOutlawObjetivo", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one,
	})
	local board = new("BillboardGui", marker, {
		Name = "Marcador", AlwaysOnTop = true, Size = UDim2.fromOffset(90, 54), LightInfluence = 0, MaxDistance = 100000,
	})
	local diamond = new("Frame", board, {
		Name = "Losango", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(18, 18), Rotation = 45,
		BackgroundColor3 = GOLD, BorderSizePixel = 0,
	})
	outline(diamond, PANEL, 0, 2)
	local distanceText = text(board, "Distancia", "", 13, GOLD, {
		Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3,
	})
	local mission = nil
	local function readMission()
		local raw = player:GetAttribute("CyberOutlawMissao")
		local ok, value = pcall(HttpService.JSONDecode, HttpService, raw or "")
		mission = if ok and type(value) == "table" then value else nil
		objective.Visible = mission ~= nil
		if mission and type(mission.alvo) == "table" then
			marker.Position = Vector3.new(mission.alvo[1], mission.alvo[2] + 7, mission.alvo[3])
			marker.Parent = workspace
		else
			marker.Parent = nil
		end
	end
	player:GetAttributeChangedSignal("CyberOutlawMissao"):Connect(readMission)
	readMission()

	-- Holochamada ------------------------------------------------------------------------------------------
	-- Como no Cyberpunk 2077 e em Edgerunners: não existe celular na mão. O implante Agente projeta a chamada na
	-- visão: retrato do contato num quadro vermelho com cortes de sinal, código da linha, o nome em ciano,
	-- "CHAMADA RECEBIDA" em vermelho e as teclas em caixinhas ([T] ATENDER · [Y] RECUSAR). A conversa vira
	-- legenda "Nome: fala" embaixo, e no fim aparece o contrato (valor e prazo) para aceitar ou recusar.
	local MONO = Font.fromEnum(Enum.Font.RobotoMono)
	local TECH = Font.fromEnum(Enum.Font.Michroma)
	local holo = new("Frame", gui, {
		Name = "Holochamada", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 28, 0.26, 0),
		Size = UDim2.fromOffset(340, 132), BackgroundTransparency = 1, Visible = false,
	})
	local holoScale = new("UIScale", holo, { Scale = 1 })
	local HOLO_AT = if touch then UDim2.new(0.5, -200, 0, 2) else UDim2.new(0, 28, 0.26, 0)
	if touch then
		holo.Size = UDim2.fromOffset(400, 80)
	end
	local holoGlow = new("Frame", holo, {
		Name = "Brilho", Position = UDim2.fromOffset(98, 4), Size = UDim2.new(1, -98, 1, -8), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
	})
	new("UIGradient", holoGlow, { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }) })
	-- Cortes de sinal à esquerda do retrato (os blocos vermelhos da referência).
	for index = 0, 7 do
		new("Frame", holo, {
			Name = "Sinal", Position = UDim2.fromOffset(0, 10 + index * 13), Size = UDim2.fromOffset(4 + (index * 7) % 9, 8), BackgroundColor3 = HOT,
			BackgroundTransparency = 0.25 + (index % 3) * 0.2, BorderSizePixel = 0,
		})
	end
	local portraitFrame = new("Frame", holo, {
		Name = "Quadro", Position = UDim2.fromOffset(16, 6), Size = if touch then UDim2.fromOffset(56, 68) else UDim2.fromOffset(78, 96),
		BackgroundColor3 = Color3.fromRGB(30, 8, 12), BorderSizePixel = 0,
	})
	outline(portraitFrame, HOT, 0, 2)
	local portrait = new("ViewportFrame", portraitFrame, {
		Name = "Rosto", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(150, 130, 140),
		LightColor = Color3.fromRGB(255, 225, 220), LightDirection = Vector3.new(-0.6, -0.5, 1), ImageColor3 = Color3.fromRGB(255, 225, 225),
	})
	for line = 0, 31 do
		new("Frame", portraitFrame, {
			Name = "Linha", Position = UDim2.fromOffset(0, line * 3), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = HOT,
			BackgroundTransparency = 0.86, BorderSizePixel = 0, ZIndex = 3,
		})
	end
	new("Frame", portraitFrame, { Name = "Canto", Position = UDim2.fromOffset(-3, -3), Size = UDim2.fromOffset(12, 4), BackgroundColor3 = HOT, BorderSizePixel = 0, ZIndex = 4 })
	new("Frame", portraitFrame, { Name = "Canto", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 3, 1, 3), Size = UDim2.fromOffset(12, 4), BackgroundColor3 = HOT, BorderSizePixel = 0, ZIndex = 4 })
	local portraitCamera = new("Camera", portrait, { FieldOfView = 24 })
	portrait.CurrentCamera = portraitCamera
	-- Colunas de texto: no PC embaixo uma da outra; no toque, texto no meio e os botões grandes à direita.
	local textX, textW = if touch then 80 else 104, if touch then -264 else -108
	local lineCode = text(holo, "Linha", "", if touch then 9 else 10, HOT, { Position = UDim2.fromOffset(textX, 4), Size = UDim2.new(1, textW, 0, 12), FontFace = MONO, TextTransparency = 0.2 })
	local callerName = text(holo, "Nome", "", 19, NEON, {
		Position = UDim2.fromOffset(textX, if touch then 15 else 18), Size = UDim2.new(1, textW, 0, if touch then 22 else 26), FontFace = TECH, TextScaled = true,
		TextStrokeTransparency = 0.6, TextStrokeColor3 = NEON,
	})
	new("UITextSizeConstraint", callerName, { MaxTextSize = if touch then 16 else 19 })
	local callStatus = text(holo, "Status", "", if touch then 11 else 13, HOT, {
		Position = UDim2.fromOffset(textX, if touch then 39 else 46), Size = UDim2.new(1, textW, 0, 16), FontFace = TECH, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local callerRole = text(holo, "Cargo", "", if touch then 10 else 11, SUB, {
		Position = UDim2.fromOffset(textX, if touch then 56 else 64), Size = UDim2.new(1, textW, 0, 14), FontFace = font(Enum.FontWeight.Medium),
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local actions = new("Frame", holo, {
		Name = "Botoes", AnchorPoint = if touch then Vector2.new(1, 0.5) else Vector2.zero,
		Position = if touch then UDim2.new(1, -4, 0.5, 0) else UDim2.fromOffset(104, 84), Size = if touch then UDim2.fromOffset(180, 46) else UDim2.new(1, -108, 0, 30),
		BackgroundTransparency = 1,
	})
	new("UIListLayout", actions, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, if touch then 6 else 14), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = if touch then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left })
	-- Tecla na caixinha + ação: no toque, a linha inteira é o botão.
	local function keyAction(caption: string, key: string, color: Color3, order: number, onClick)
		if touch then
			local big = new("TextButton", actions, {
				Name = caption, Text = caption, FontFace = TECH, TextSize = 11, TextColor3 = color, AutoButtonColor = true, BackgroundColor3 = Color3.fromRGB(16, 6, 12),
				BackgroundTransparency = 0.15, BorderSizePixel = 0, Size = UDim2.fromOffset(86, 44), LayoutOrder = order,
			})
			outline(big, color, 0, 1.5)
			big.Activated:Connect(onClick)
			return big
		end
		local item = new("TextButton", actions, {
			Name = caption, Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(104, 30), LayoutOrder = order,
		})
		local cap = new("Frame", item, { Name = "Tecla", Position = UDim2.fromOffset(0, 3), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = Color3.fromRGB(20, 6, 10),
			BackgroundTransparency = 0.2, BorderSizePixel = 0 })
		outline(cap, color, 0, 1.5)
		text(cap, "Letra", key, 13, color, { FontFace = TECH, TextXAlignment = Enum.TextXAlignment.Center })
		text(item, "Acao", caption, 14, color, { Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -30, 1, 0), FontFace = TECH })
		item.Activated:Connect(onClick)
		return item
	end
	local subtitle = new("Frame", gui, {
		Name = "Legenda", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if touch then -64 else -120), Size = UDim2.fromOffset(if touch then 400 else 640, if touch then 50 else 58),
		BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Visible = false,
	})
	new("UIGradient", subtitle, { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(0.8, 0.55), NumberSequenceKeypoint.new(1, 1) }) })
	local subtitleText = text(subtitle, "Texto", "", if touch then 14 else 17, TEXT, {
		Position = UDim2.fromOffset(16, 2), Size = UDim2.new(1, -32, 1, -4), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = font(Enum.FontWeight.SemiBold), RichText = true, TextStrokeTransparency = 0.5,
	})
	local call = nil -- { offer, state = "tocando"|"conversa"|"oferta"|"recado", token }
	local speaker, speakerColor = "", "#5EF6FF"
	local function clearActions()
		for _, child in actions:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end
	local function showPortrait(fixerId: string)
		for _, child in portrait:GetChildren() do
			if child:IsA("WorldModel") then
				child:Destroy()
			end
		end
		local fixer = fixers[fixerId]
		speaker = if fixer then fixer.nome else "Fixer"
		local tone = if fixer then Color3.fromRGB(fixer.cor[1], fixer.cor[2], fixer.cor[3]) else NEON
		speakerColor = string.format("#%02X%02X%02X", math.floor(tone.R * 255), math.floor(tone.G * 255), math.floor(tone.B * 255))
		lineCode.Text = string.format("TRN_%s_%06d  ||| SINAL", string.upper(string.sub(fixerId, 1, 4)), math.random(0, 999999))
		local source = folder:FindFirstChild("Fixers")
		local template = source and source:FindFirstChild(fixerId)
		if not template then
			return
		end
		local world = new("WorldModel", portrait, { Name = "Mundo" })
		local bust = template:Clone()
		bust.Parent = world
		local head = bust:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local at = head.Position
			portraitCamera.CFrame = CFrame.lookAt(at + Vector3.new(0.9, -0.2, -5.2), at + Vector3.new(0, -0.5, 0))
		end
	end
	local function hangUp()
		call = nil
		holo.Visible = false
		subtitle.Visible = false
		clearActions()
	end
	-- Digita a fala letra por letra (sem cortar acentos no meio).
	local function typeLines(lines, done)
		local token = {}
		call.token = token
		subtitle.Visible = true
		task.spawn(function()
			for _, line in lines do
				local count = utf8.len(line) or #line
				for index = 1, count, 2 do
					if not call or call.token ~= token then
						return
					end
					local cut = utf8.offset(line, index + 1) or (#line + 1)
					subtitleText.Text = string.format('<font color="%s">%s:</font> %s', speakerColor, speaker, string.sub(line, 1, cut - 1))
					task.wait(0.03)
				end
				subtitleText.Text = string.format('<font color="%s">%s:</font> %s', speakerColor, speaker, line)
				task.wait(math.clamp(count * 0.035, 1.6, 3.2))
			end
			if call and call.token == token then
				done()
			end
		end)
	end
	local answer, decline
	local function offerStep()
		if not call then
			return
		end
		call.state = "oferta"
		local offer = call.offer
		callStatus.Text = string.upper(offer.titulo)
		callStatus.TextColor3 = GOLD
		callerRole.Text = string.format("%s · PRAZO %s · %s", money(offer.valor), clock(offer.prazo), string.upper(offer.bairro or ""))
		callerRole.TextColor3 = GOLD
		subtitleText.Text = string.format('<font color="#FFD066">CONTRATO:</font> %s', offer.objetivo)
		clearActions()
		keyAction("ACEITAR", "T", GREEN, 1, function()
			answer()
		end)
		keyAction("RECUSAR", "Y", HOT, 2, function()
			decline()
		end)
	end
	answer = function()
		if not call then
			return
		end
		if call.state == "tocando" then
			call.state = "conversa"
			request:FireServer("atender", call.offer.id)
			callStatus.Text = "EM CHAMADA"
			callStatus.TextColor3 = NEON
			clearActions()
			typeLines(call.offer.falas, offerStep)
		elseif call.state == "oferta" then
			request:FireServer("aceitar", call.offer.id)
			local offer = call.offer
			call.state = "recado"
			clearActions()
			typeLines({ offer.tchau }, hangUp)
		end
	end
	decline = function()
		if not call then
			return
		end
		if call.offer then
			request:FireServer("recusar", call.offer.id)
		end
		hangUp()
	end
	local function incoming(offer, outgoing: boolean)
		call = { offer = offer, state = "tocando", at = os.clock() }
		holo.Visible = true
		showPortrait(offer.fixer)
		callerName.Text = string.upper(offer.nome)
		callerRole.Text = string.upper(offer.cargo)
		callerRole.TextColor3 = SUB
		clearActions()
		if outgoing then
			answer()
			return
		end
		callStatus.Text = "CHAMADA RECEBIDA"
		callStatus.TextColor3 = HOT
		keyAction("ATENDER", "T", NEON, 1, answer)
		keyAction("RECUSAR", "Y", HOT, 2, decline)
		task.spawn(function()
			local current = call
			for _ = 1, 8 do
				if call ~= current or call.state ~= "tocando" then
					return
				end
				sound("chamada", 0.7)
				task.wait(2.6)
			end
		end)
	end
	local function fixerMessage(fixerId: string, message: string, good: boolean)
		local fixer = fixers[fixerId]
		call = { state = "recado", at = os.clock() }
		holo.Visible = true
		showPortrait(fixerId)
		callerName.Text = string.upper(if fixer then fixer.nome else "Fixer")
		callerRole.Text = string.upper(if fixer then fixer.titulo else "")
		callerRole.TextColor3 = SUB
		callStatus.Text = if good then "TRABALHO CONCLUÍDO" else "TRABALHO PERDIDO"
		callStatus.TextColor3 = if good then GREEN else HOT
		clearActions()
		typeLines({ message }, hangUp)
	end
	local _ = holoScale

	-- Painéis (Casa e Agente) -----------------------------------------------------------------------------
	local dim = new("Frame", gui, { Name = "Fundo", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false, ZIndex = 20 })
	local card = plate(gui, "Painel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(if touch then 0.9 else 0.56, if touch then 0.97 else 0.74),
		Visible = false, ZIndex = 21, BackgroundTransparency = 0.06,
	})
	new("UISizeConstraint", card, { MaxSize = Vector2.new(820, 620), MinSize = Vector2.new(320, 240) })
	local title = text(card, "Titulo", "", if touch then 14 else 18, NEON, {
		Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -70, 0, 30), ZIndex = 22, FontFace = Font.fromEnum(Enum.Font.Michroma), TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local close
	local tabs = new("ScrollingFrame", card, {
		Name = "Abas", Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 36), BackgroundTransparency = 1, ZIndex = 22, BorderSizePixel = 0,
		ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
	})
	new("UIListLayout", tabs, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local body = new("ScrollingFrame", card, {
		Name = "Conteudo", Position = UDim2.fromOffset(12, 82), Size = UDim2.new(1, -24, 1, -92), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, ScrollBarImageColor3 = NEON, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 22,
		ElasticBehavior = Enum.ElasticBehavior.Never,
	})
	local panel = nil -- "casa" | "agente"
	local tab = "loja"
	local filter = "Todos"
	local render
	local function setOpen(which)
		panel = which
		local open = which ~= nil
		dim.Visible, card.Visible = open, open
		player:SetAttribute("CyberOutlawPainel", open)
		homeButton.BackgroundTransparency = if which == "casa" then 0 else 0.3
		agentButton.BackgroundTransparency = if which == "agente" then 0 else 0.3
		if open then
			render()
		end
	end
	close = button(card, "Fechar", "X", HOT, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 4), Size = UDim2.fromOffset(44, 34), ZIndex = 23, FontFace = Font.fromEnum(Enum.Font.Michroma), TextSize = 16,
	}, function()
		setOpen(nil)
	end)
	local function clearBody()
		for _, child in body:GetChildren() do
			child:Destroy()
		end
		for _, child in tabs:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end
	local function row(order: number, height: number)
		local item = new("Frame", body, {
			Name = "Linha", Size = UDim2.new(1, -8, 0, if touch then math.min(height, 50) else height), BackgroundColor3 = Color3.fromRGB(24, 14, 26),
			BackgroundTransparency = 0.15, LayoutOrder = order, ZIndex = 23, BorderSizePixel = 0,
		})
		new("Frame", item, { Name = "Traco", Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = HOT, BorderSizePixel = 0, ZIndex = 24 })
		return item
	end
	local function preview(parent, id: string, size: number)
		local view = new("ViewportFrame", parent, {
			Name = "Previa", Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.fromRGB(8, 8, 18), BackgroundTransparency = 0,
			Ambient = Color3.fromRGB(170, 170, 190), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1.4, -0.6), ZIndex = 24,
		})
		corner(view, 6)
		local source = folder:FindFirstChild("Moveis")
		local template = source and source:FindFirstChild(id)
		local tam = sizes[id]
		if template and tam then
			local world = new("WorldModel", view, {})
			template:Clone().Parent = world
			local radius = math.max(tam.X, tam.Y, tam.Z) * 0.62
			local cam = new("Camera", view, { FieldOfView = 34 })
			view.CurrentCamera = cam
			local target = Vector3.new(0, tam.Y / 2, 0)
			cam.CFrame = CFrame.lookAt(target + Vector3.new(radius * 1.3, radius * 1.0, -radius * 1.9), target)
		end
		return view
	end
	local function tabButton(key: string, caption: string, order: number)
		local selected = tab == key
		local item = button(tabs, "Aba", caption, if selected then GOLD else SUB, {
			Size = UDim2.fromOffset(if touch then 104 else 130, 30), LayoutOrder = order, ZIndex = 23, TextSize = 13,
			BackgroundTransparency = if selected then 0 else 0.4,
		}, function()
			tab = key
			render()
		end)
		return item
	end

	local startPlacing
	local function shop()
		local cats = { "Todos" }
		local seen = {}
		for _, def in catalog do
			if not seen[def.cat] then
				seen[def.cat] = true
				table.insert(cats, def.cat)
			end
		end
		local chips = new("Frame", body, { Name = "Filtros", Size = UDim2.new(1, -8, 0, 30), BackgroundTransparency = 1, LayoutOrder = 0, ZIndex = 23 })
		new("UIListLayout", chips, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
		for index, cat in cats do
			button(chips, "Filtro", cat, if filter == cat then NEON else SUB, {
				Size = UDim2.fromOffset(84, 26), LayoutOrder = index, ZIndex = 24, TextSize = 12, BackgroundTransparency = if filter == cat then 0 else 0.5,
			}, function()
				filter = cat
				render()
			end)
		end
		local grid = new("Frame", body, { Name = "Grade", Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 23 })
		new("UIGridLayout", grid, { CellSize = UDim2.fromOffset(if touch then 132 else 160, if touch then 186 else 212), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		local cash = player:GetAttribute("CyberOutlawEddies") or 0
		for _, def in catalog do
			if filter == "Todos" or def.cat == filter then
				local cell = new("Frame", grid, { Name = def.id, BackgroundColor3 = Color3.fromRGB(22, 20, 44), BackgroundTransparency = 0.15, LayoutOrder = def.ordem, ZIndex = 23 })
				corner(cell, 8)
				outline(cell, NEON, 0.7, 1)
				local view = preview(cell, def.id, if touch then 92 else 112)
				view.AnchorPoint = Vector2.new(0.5, 0)
				view.Position = UDim2.new(0.5, 0, 0, 6)
				local y = (if touch then 92 else 112) + 8
				text(cell, "Nome", def.nome, 13, TEXT, { Position = UDim2.fromOffset(8, y), Size = UDim2.new(1, -16, 0, 32), TextWrapped = true, ZIndex = 24,
					TextYAlignment = Enum.TextYAlignment.Top })
				local afford = cash >= def.preco
				button(cell, "Comprar", money(def.preco), if afford then GOLD else RED, {
					AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -16, 0, 30), ZIndex = 24, TextSize = 14,
				}, function()
					request:FireServer("comprar", def.id)
				end)
			end
		end
	end

	local function mine()
		local order = 0
		local function heading(caption: string)
			order += 1
			text(body, "Secao", caption, 14, NEON, { Size = UDim2.new(1, -8, 0, 24), LayoutOrder = order, ZIndex = 23 })
		end
		heading("GUARDADOS")
		local any = false
		for id, count in house.guardados do
			local def = byId[id]
			if def then
				any = true
				order += 1
				local line = row(order, 64)
				local view = preview(line, id, 56)
				view.Position = UDim2.fromOffset(4, 4)
				text(line, "Nome", string.format("%s  ×%d", def.nome, count), 14, TEXT, { Position = UDim2.fromOffset(68, 0), Size = UDim2.new(1, -260, 1, 0), ZIndex = 24 })
				button(line, "Colocar", "COLOCAR", GREEN, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0.5, 0), Size = UDim2.fromOffset(86, 30), ZIndex = 24, TextSize = 12 }, function()
					startPlacing(id, nil)
				end)
				button(line, "Vender", "VENDER " .. money(def.preco * economy.venda), RED, {
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(86, 30), ZIndex = 24, TextSize = 10,
				}, function()
					request:FireServer("venderGuardado", id)
				end)
			end
		end
		if not any then
			order += 1
			text(body, "Vazio", "Nada guardado. Compre móveis na LOJA.", 13, SUB, { Size = UDim2.new(1, -8, 0, 24), LayoutOrder = order, ZIndex = 23 })
		end
		heading("NO APARTAMENTO")
		for _, item in house.moveis do
			local def = byId[item.id]
			if def then
				order += 1
				local line = row(order, 64)
				local view = preview(line, item.id, 56)
				view.Position = UDim2.fromOffset(4, 4)
				text(line, "Nome", def.nome, 14, TEXT, { Position = UDim2.fromOffset(68, 0), Size = UDim2.new(1, -340, 1, 0), ZIndex = 24 })
				local uid = item.u
				button(line, "Mover", "MOVER", NEON, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -186, 0.5, 0), Size = UDim2.fromOffset(84, 30), ZIndex = 24, TextSize = 12 }, function()
					startPlacing(item.id, uid)
				end)
				button(line, "Guardar", "GUARDAR", GOLD, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0.5, 0), Size = UDim2.fromOffset(84, 30), ZIndex = 24, TextSize = 12 }, function()
					request:FireServer("guardar", uid)
				end)
				button(line, "Vender", "VENDER", RED, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(84, 30), ZIndex = 24, TextSize = 12 }, function()
					request:FireServer("vender", uid)
				end)
			end
		end
	end

	local function renovate()
		local order = 0
		for _, group in { { "piso", "PISO" }, { "luz", "LUZ DO TETO" }, { "vidro", "JANELAS" } } do
			order += 1
			text(body, "Secao", group[2], 14, NEON, { Size = UDim2.new(1, -8, 0, 24), LayoutOrder = order, ZIndex = 23 })
			order += 1
			local line = new("Frame", body, { Name = "Opcoes", Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 23 })
			new("UIGridLayout", line, { CellSize = UDim2.fromOffset(if touch then 150 else 170, 44), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder })
			for index, option in renovations[group[1]] or {} do
				local current = house[group[1]] == option.id
				local tone = Color3.fromRGB(option.cor[1], option.cor[2], option.cor[3])
				local item = button(line, option.id, string.format("%s\n%s", option.nome, if current then "EM USO" elseif option.preco == 0 then "GRÁTIS" else money(option.preco)),
					if current then GREEN else TEXT, { LayoutOrder = index, ZIndex = 24, TextSize = 12, TextWrapped = true }, function()
						if not current then
							request:FireServer("reforma", group[1], option.id)
						end
					end)
				local swatch = new("Frame", item, { Size = UDim2.new(0, 6, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = tone, BorderSizePixel = 0, ZIndex = 25 })
				corner(swatch, 3)
			end
		end
	end

	local function agentPanel()
		local order = 0
		local function heading(caption: string)
			order += 1
			text(body, "Secao", caption, 14, NEON, { Size = UDim2.new(1, -8, 0, 24), LayoutOrder = order, ZIndex = 23 })
		end
		heading("TRABALHO ATUAL")
		order += 1
		local current = row(order, 60)
		if mission then
			text(current, "Texto", string.format("%s · %s\n%s", mission.titulo, money(mission.valor or 0), mission.objetivo), 14, TEXT, {
				Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -130, 1, 0), TextWrapped = true, ZIndex = 24,
			})
			button(current, "Abandonar", "ABANDONAR", RED, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(110, 32), ZIndex = 24, TextSize = 12 }, function()
				request:FireServer("abandonar")
			end)
		else
			text(current, "Texto", "Nenhum. Ligue para um fixer ou espere uma holochamada.", 14, SUB, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), TextWrapped = true, ZIndex = 24 })
		end
		heading("CONTATOS")
		for _, fixer in fixerList do
			order += 1
			local line = row(order, 54)
			local tone = Color3.fromRGB(fixer.cor[1], fixer.cor[2], fixer.cor[3])
			local dot = new("Frame", line, { Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 10, 0.5, -5), BackgroundColor3 = tone, BorderSizePixel = 0, ZIndex = 24 })
			corner(dot, 5)
			text(line, "Nome", fixer.nome .. "\n" .. fixer.titulo, 14, TEXT, { Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -150, 1, 0), ZIndex = 24 })
			button(line, "Ligar", "LIGAR", GREEN, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(100, 32), ZIndex = 24, TextSize = 13 }, function()
				request:FireServer("ligar", fixer.id)
				setOpen(nil)
			end)
		end
		heading("AJUSTES")
		order += 1
		local quiet = player:GetAttribute("CyberOutlawNaoPerturbe") == true
		local line = row(order, 50)
		text(line, "Texto", string.format("Reputação de rua: %d", player:GetAttribute("CyberOutlawReputacao") or 0), 14, GOLD, {
			Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -200, 1, 0), ZIndex = 24,
		})
		button(line, "NaoPerturbe", if quiet then "NÃO PERTURBE: ON" else "NÃO PERTURBE: OFF", if quiet then PINK else SUB, {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(170, 32), ZIndex = 24, TextSize = 12,
		}, function()
			request:FireServer("naoPerturbe", not quiet)
			task.delay(0.3, render)
		end)
	end

	render = function()
		if not panel then
			return
		end
		clearBody()
		new("UIListLayout", body, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
		-- Só a Casa tem abas: no Agente a lista começa logo abaixo do título.
		tabs.Visible = panel == "casa"
		body.Position = UDim2.fromOffset(12, if panel == "casa" then 82 else 44)
		body.Size = UDim2.new(1, -24, 1, if panel == "casa" then -90 else -52)
		if panel == "casa" then
			title.Text = if (house.unidade or 0) > 0 then string.format("APARTAMENTO %02d · EDIFÍCIO COLMEIA", house.unidade) else "CASA · COLMEIA LOTADO"
			tabButton("loja", "LOJA", 1)
			tabButton("meus", "MEUS MÓVEIS", 2)
			tabButton("reforma", "REFORMA", 3)
			button(tabs, "IrCasa", "IR PARA CASA", NEON, { Size = UDim2.fromOffset(if touch then 112 else 130, 30), LayoutOrder = 4, ZIndex = 23, TextSize = 12 }, function()
				request:FireServer("irCasa")
				setOpen(nil)
			end)
			if #house.sujeira > 0 then
				button(tabs, "Faxina", "FAXINA " .. money(economy.faxina), GOLD, { Size = UDim2.fromOffset(if touch then 112 else 130, 30), LayoutOrder = 5, ZIndex = 23, TextSize = 12 }, function()
					request:FireServer("faxina")
				end)
			end
			if tab == "loja" then
				shop()
			elseif tab == "meus" then
				mine()
			else
				renovate()
			end
		else
			title.Text = "AGENTE · CONTATOS"
			agentPanel()
		end
	end
	homeButton.Activated:Connect(function()
		setOpen(if panel == "casa" then nil else "casa")
	end)
	agentButton.Activated:Connect(function()
		setOpen(if panel == "agente" then nil else "agente")
	end)

	-- Posicionamento: fantasma na frente do personagem, dentro do apartamento, preso na grade de 0,5.
	local placing = nil -- { id, uid, rot, ghost }
	local placeBar = new("Frame", gui, {
		Name = "Posicionar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if touch then -60 else -110), Size = UDim2.fromOffset(330, 44),
		BackgroundTransparency = 1, Visible = false,
	})
	new("UIListLayout", placeBar, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center })
	local placeHint = text(gui, "DicaPosicionar", "Ande até o lugar. Girar: Z · Colocar: F · Cancelar: C", 13, SUB, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if touch then -108 else -158), Size = UDim2.fromOffset(420, 20),
		TextXAlignment = Enum.TextXAlignment.Center, Visible = false, TextStrokeTransparency = 0.4,
	})
	local function unitMarker(): BasePart?
		local n = player:GetAttribute("CyberOutlawUnidade") or 0
		local city = workspace:FindFirstChild("CyberOutlawCity")
		local building = city and city:FindFirstChild("Edifício Colmeia", true)
		if not building or n <= 0 then
			return nil
		end
		for _, item in building:GetDescendants() do
			if item.Name == "Unidade" and item:GetAttribute("Unidade") == n and item:IsA("BasePart") then
				return item
			end
		end
		return nil
	end
	local function stopPlacing()
		if placing and placing.ghost then
			placing.ghost:Destroy()
		end
		placing = nil
		placeBar.Visible = false
		placeHint.Visible = false
	end
	local function confirmPlacing()
		if not placing or not placing.valid then
			sound("ui_negado", 0.3)
			return
		end
		if placing.uid then
			request:FireServer("mover", placing.uid, placing.x, placing.z, placing.rot)
		else
			request:FireServer("colocar", placing.id, placing.x, placing.z, placing.rot)
		end
		stopPlacing()
	end
	local function rotatePlacing()
		if placing then
			placing.rot = (placing.rot + 1) % 4
		end
	end
	button(placeBar, "Girar", "GIRAR", NEON, { Size = UDim2.fromOffset(100, 40) }, rotatePlacing)
	button(placeBar, "Colocar", "COLOCAR", GREEN, { Size = UDim2.fromOffset(110, 40) }, confirmPlacing)
	button(placeBar, "Cancelar", "CANCELAR", RED, { Size = UDim2.fromOffset(100, 40) }, stopPlacing)
	startPlacing = function(id: string, uid: number?)
		local markerPart = unitMarker()
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not markerPart or not rootPart then
			toast("Você não tem apartamento neste servidor.", RED)
			return
		end
		local here = markerPart.CFrame:PointToObjectSpace(rootPart.Position)
		if math.abs(here.X) > markerPart.Size.X / 2 + 1 or math.abs(here.Z) > markerPart.Size.Z / 2 + 1 or math.abs(here.Y) > markerPart.Size.Y then
			toast("Vá para o seu apartamento (botão IR PARA CASA) para arrumar os móveis.", GOLD)
			return
		end
		stopPlacing()
		local source = folder:FindFirstChild("Moveis")
		local template = source and source:FindFirstChild(id)
		if not template then
			return
		end
		local ghost = template:Clone()
		for _, item in ghost:GetDescendants() do
			if item:IsA("BasePart") then
				item.CanCollide, item.CanQuery, item.CanTouch, item.CastShadow = false, false, false, false
				item.Transparency = math.max(item.Transparency, 0.45)
			elseif item:IsA("Light") or item:IsA("ParticleEmitter") or item:IsA("SurfaceGui") then
				item:Destroy()
			end
		end
		local glow = new("Highlight", ghost, { FillColor = NEON, OutlineColor = NEON, FillTransparency = 0.7, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop })
		ghost.Parent = workspace
		local rot = 0
		if uid then
			for _, item in house.moveis do
				if item.u == uid then
					rot = item.r
				end
			end
		end
		placing = { id = id, uid = uid, rot = rot, ghost = ghost, glow = glow, marker = markerPart }
		setOpen(nil)
		placeBar.Visible = true
		placeHint.Visible = not touch
	end

	-- Interações (ProximityPrompt) no estilo da interface: [E] na caixinha vermelha, ação em ciano, objeto em
	-- cinza e a barra de segurar enchendo. No toque, a placa inteira é o botão (segura para assaltar, limpar...).
	local ProximityPromptService = game:GetService("ProximityPromptService")
	local promptGui = new("ScreenGui", player.PlayerGui, { Name = "CyberOutlawInteracoes", ResetOnSpawn = false, DisplayOrder = 34 })
	local shownPrompts = {}
	local function keyName(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
		if inputType == Enum.ProximityPromptInputType.Gamepad then
			return string.gsub(prompt.GamepadKeyCode.Name, "Button", "")
		end
		return prompt.KeyboardKeyCode.Name
	end
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom or shownPrompts[prompt] then
			return
		end
		local tapping = inputType == Enum.ProximityPromptInputType.Touch
		local board2 = new("BillboardGui", promptGui, {
			Name = "Interacao", Adornee = prompt.Parent, AlwaysOnTop = true, LightInfluence = 0, Size = UDim2.fromOffset(250, 58),
			StudsOffsetWorldSpace = Vector3.new(0, if prompt.Parent and prompt.Parent.Name == "HumanoidRootPart" then 3.2 else 1.6, 0), Active = tapping,
			ResetOnSpawn = false,
		})
		local face = new(if tapping then "TextButton" else "Frame", board2, {
			Name = "Placa", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.3, BorderSizePixel = 0,
		})
		if tapping then
			(face :: TextButton).Text = ""
			(face :: TextButton).AutoButtonColor = false
		end
		new("Frame", face, { Name = "Traco", Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = HOT, BorderSizePixel = 0 })
		local cap = new("Frame", face, { Name = "Tecla", Position = UDim2.fromOffset(10, 13), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Color3.fromRGB(26, 8, 12), BorderSizePixel = 0 })
		outline(cap, HOT, 0, 1.5)
		text(cap, "Letra", if tapping then "TOQUE" else keyName(prompt, inputType), if tapping then 8 else 15, HOT, {
			FontFace = Font.fromEnum(Enum.Font.Michroma), TextXAlignment = Enum.TextXAlignment.Center,
		})
		text(face, "Acao", string.upper(prompt.ActionText), 15, NEON, {
			Position = UDim2.fromOffset(52, 8), Size = UDim2.new(1, -58, 0, 22), FontFace = Font.fromEnum(Enum.Font.Michroma), TextTruncate = Enum.TextTruncate.AtEnd,
		})
		text(face, "Objeto", prompt.ObjectText, 12, SUB, { Position = UDim2.fromOffset(52, 30), Size = UDim2.new(1, -58, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
		local track = new("Frame", face, { Name = "Segurar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 3, 1, 0), Size = UDim2.new(1, -3, 0, 3),
			BackgroundColor3 = HOT, BackgroundTransparency = 0.75, BorderSizePixel = 0, Visible = prompt.HoldDuration > 0 })
		local fill = new("Frame", track, { Name = "Valor", Size = UDim2.fromScale(0, 1), BackgroundColor3 = HOT, BorderSizePixel = 0 })
		local entry = { board = board2, holdAt = nil, connections = {} }
		shownPrompts[prompt] = entry
		table.insert(entry.connections, prompt.PromptButtonHoldBegan:Connect(function()
			entry.holdAt = os.clock()
		end))
		table.insert(entry.connections, prompt.PromptButtonHoldEnded:Connect(function()
			entry.holdAt = nil
			fill.Size = UDim2.fromScale(0, 1)
		end))
		table.insert(entry.connections, prompt.Triggered:Connect(function()
			entry.holdAt = nil
			fill.Size = UDim2.fromScale(1, 1)
			face.BackgroundColor3 = Color3.fromRGB(60, 12, 18)
			task.delay(0.15, function()
				face.BackgroundColor3 = Color3.new(0, 0, 0)
				fill.Size = UDim2.fromScale(0, 1)
			end)
		end))
		table.insert(entry.connections, RunService.RenderStepped:Connect(function()
			if entry.holdAt and prompt.HoldDuration > 0 then
				fill.Size = UDim2.fromScale(math.clamp((os.clock() - entry.holdAt) / prompt.HoldDuration, 0, 1), 1)
			end
		end))
		if tapping then
			table.insert(entry.connections, face.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					prompt:InputHoldBegin()
				end
			end))
			table.insert(entry.connections, face.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					prompt:InputHoldEnd()
				end
			end))
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		local entry = shownPrompts[prompt]
		if entry then
			shownPrompts[prompt] = nil
			for _, connection in entry.connections do
				connection:Disconnect()
			end
			entry.board:Destroy()
		end
	end)

	-- Avisos do servidor -----------------------------------------------------------------------------------
	notice.OnClientEvent:Connect(function(kind, a, b, c)
		if kind == "dinheiro" and type(a) == "number" then
			if a > 0 then
				sound("dinheiro", 0.6)
			end
			toast(string.format("%s%s%s", if a > 0 then "+" else "", money(a), if type(b) == "string" then "  " .. b else ""), if a > 0 then GREEN else RED)
		elseif kind == "msg" and type(a) == "string" then
			toast(a, TEXT)
		elseif kind == "procurado" and type(a) == "number" then
			sound("alarme", 0.55)
			toast(string.format("PROCURADO: %s", string.rep("★", a)), RED)
		elseif kind == "chamada" and type(a) == "table" then
			incoming(a, b == true)
		elseif kind == "perdida" and type(a) == "string" then
			if call and call.state == "tocando" then
				hangUp()
			end
			local fixer = fixers[a]
			toast("Chamada perdida: " .. (if fixer then fixer.nome else "fixer") .. " (ligue pelo AGENTE)", GOLD)
		elseif kind == "fixer" and type(a) == "string" and type(b) == "string" then
			fixerMessage(a, b, c == true)
		elseif kind == "missao" and type(a) == "table" then
			toast("Trabalho aceito: " .. tostring(a.titulo), NEON)
		elseif kind == "comprado" and type(a) == "string" then
			local def = byId[a]
			if def then
				toast("Comprado: " .. def.nome .. " (está em MEUS MÓVEIS)", GOLD)
			end
		elseif kind == "casa" and type(a) == "table" then
			house = a
			house.moveis = house.moveis or {}
			house.guardados = house.guardados or {}
			house.sujeira = house.sujeira or {}
			if panel then
				render()
			end
		end
	end)
	player:GetAttributeChangedSignal("CyberOutlawEddies"):Connect(function()
		if panel == "casa" and tab == "loja" then
			render()
		end
	end)
	player:GetAttributeChangedSignal("CyberOutlawMissao"):Connect(function()
		if panel == "agente" then
			render()
		end
	end)
	request:FireServer("casa")

	-- Teclas: H casa, J agente, T atender/aceitar, Y recusar; no posicionamento Z gira, F coloca, C cancela.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not gui.Enabled then
			return
		end
		local key = input.KeyCode
		if placing then
			if key == Enum.KeyCode.Z then
				rotatePlacing()
			elseif key == Enum.KeyCode.F then
				confirmPlacing()
			elseif key == Enum.KeyCode.C then
				stopPlacing()
			end
			return
		end
		if key == Enum.KeyCode.H then
			setOpen(if panel == "casa" then nil else "casa")
		elseif key == Enum.KeyCode.J then
			setOpen(if panel == "agente" then nil else "agente")
		elseif key == Enum.KeyCode.T and call then
			answer()
		elseif key == Enum.KeyCode.Y and call then
			decline()
		end
	end)

	-- Por quadro: estrelas, objetivo, fantasma e o "chiado" do holograma.
	local started = player:GetAttribute("CyberOutlawMenuStarted") == true
	RunService.RenderStepped:Connect(function()
		if not started then
			started = player:GetAttribute("CyberOutlawMenuStarted") == true
		end
		local covered = player:GetAttribute("CyberOutlawHudOculto") == true
		gui.Enabled, top.Enabled = started and not covered, started
		board.Enabled = not covered
		if covered and panel then
			setOpen(nil)
		end
		local admin = player.PlayerGui:FindFirstChild("CyberOutlawAdminBotao")
		local shift = if admin and admin:IsA("ScreenGui") and admin.Enabled then 56 else 8
		chip.Position = UDim2.new(1, -shift, 0.5, 0)
		stars.Position = UDim2.new(1, -shift - 150, 0.5, 0)
		local level = player:GetAttribute("CyberOutlawProcurado") or 0
		stars.Visible = level > 0
		if level > 0 then
			local seen = player:GetAttribute("CyberOutlawVisto") == true
			stars.Text = string.rep("★", level) .. string.rep("☆", 5 - level)
			stars.TextTransparency = if seen and os.clock() % 0.5 < 0.25 then 0.6 else 0
		end
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if touch and objective.Visible then
			local hudGui = player.PlayerGui:FindFirstChild("CyberOutlawHUD")
			local anchor = hudGui and hudGui:FindFirstChild("MinimapAncora")
			if anchor and anchor:IsA("GuiObject") then
				local origin = gui.AbsolutePosition
				objective.Position = UDim2.fromOffset(anchor.AbsolutePosition.X - origin.X, anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y - origin.Y + 28)
			end
		end
		if mission and rootPart and rootPart:IsA("BasePart") then
			local distance = if type(mission.alvo) == "table" then (Vector3.new(mission.alvo[1], mission.alvo[2], mission.alvo[3]) - rootPart.Position).Magnitude else 0
			local left = (mission.prazo or 0) - workspace:GetServerTimeNow()
			local extra = if mission.restantes then string.format(" · faltam %d", mission.restantes) else ""
			objectiveHead.Text = string.format("TRABALHO · %s · %s", string.upper(mission.nomeFixer or ""), clock(left))
			objectiveHead.TextColor3 = if left < 30 then RED else HOT
			objectiveText.Text = string.format("◆ %s%s · %d m", mission.objetivo or "", extra, math.floor(distance / 3.6))
			objectiveText.TextColor3 = if left < 30 then RED else GOLD
			distanceText.Text = string.format("%d m", math.floor(distance / 3.6))
		end
		if holo.Visible then
			-- Chiado de sinal: o retrato some e treme por instantes; a chamada entra deslizando.
			portrait.ImageTransparency = if math.random() < 0.05 then 0.55 else 0.02
			portrait.Position = UDim2.fromOffset(if math.random() < 0.04 then math.random(-3, 3) else 0, 0)
			local age = os.clock() - ((call and call.at) or 0)
			local slide = 1 - math.clamp(age / 0.25, 0, 1)
			holo.Position = HOLO_AT + (if touch then UDim2.fromOffset(0, -40 * slide * slide) else UDim2.fromOffset(-60 * slide * slide, 0))
			holoGlow.BackgroundTransparency = slide
			if call and call.state == "tocando" then
				callStatus.TextTransparency = if os.clock() % 0.8 < 0.4 then 0 else 0.45
			else
				callStatus.TextTransparency = 0
			end
		end
		if placing and rootPart and rootPart:IsA("BasePart") then
			local markerPart = placing.marker
			local size = sizes[placing.id] or Vector3.one
			local reach = math.max(size.X, size.Z) / 2 + 2.5
			local front = rootPart.Position + rootPart.CFrame.LookVector * reach
			local here = markerPart.CFrame:PointToObjectSpace(front)
			local grid = unitRule.grade or 0.5
			local x = math.floor(here.X / grid + 0.5) * grid
			local z = math.floor(here.Z / grid + 0.5) * grid
			placing.x, placing.z = x, z
			placing.valid = fits(unitRule, sizes, floors, house.moveis, placing.id, x, z, placing.rot, placing.uid)
			placing.glow.FillColor = if placing.valid then NEON else RED
			placing.glow.OutlineColor = placing.glow.FillColor
			placing.ghost:PivotTo(markerPart.CFrame * CFrame.new(x, -markerPart.Size.Y / 2 + 0.1, z) * CFrame.Angles(0, placing.rot * math.pi / 2, 0))
		end
		local _ = camera
	end)
	player.CharacterRemoving:Connect(stopPlacing)
end

if typeof(game) == "Instance" and game:GetService("RunService"):IsClient() then
	task.spawn(start)
end

return M
