-- CyberOutlaw · vida em Maré Baixa no cliente (LocalScript em StarterPlayerScripts).
-- Carteira em €$ e estrelas de procurado na barra de cima, linha de objetivo com distância e prazo, marcador
-- no mundo, holochamada dos fixers na visão (sem celular: a chamada aparece no canto, com o rosto do fixer
-- em holograma e legendas), painel da Casa (loja de móveis, meus móveis, reforma), posicionamento de móveis
-- no apartamento e o painel do Agente (contatos, trabalho atual, não perturbe). Conversa com life.server.luau.

local MEDIA = __CYBEROUTLAW_MEDIA__
local SOUNDS = if type(MEDIA) == "table" and type(MEDIA.sons) == "table" then MEDIA.sons else {}

local M = {}

-- Sons da biblioteca licenciada do Roblox (equipe de som do Roblox e ProSoundEffects), públicos para
-- qualquer jogo: o toque, o atender e o desligar são os mesmos das chamadas do app do Roblox. vol iguala o
-- volume percebido (medido em tools/library_sounds.py). Sem carregar, cai no som próprio da mesma chave.
local LIBRARY = {
	-- proprio: o som feito no ElevenLabs (enviado pelo midia) ganha da biblioteca quando já existe; o número é o volume.
	chamada = { id = 17208308857, vol = 0.45, proprio = 0.55, loop = true }, -- Roblox GUI - Ringtone (toca até atender)
	chamada_atender = { id = 17208209318, vol = 0.5 }, -- Roblox GUI - Call Accept
	chamada_recusar = { id = 17208214688, vol = 0.5 }, -- Roblox GUI - Call Decline
	chamada_fim = { id = 17208220181, vol = 0.45 }, -- Roblox GUI - Call Hang Up
	notificacao = { id = 17208361335, vol = 0.3 }, -- Roblox GUI - Notification High
	clique = { id = 15675059323, vol = 0.45 }, -- Roblox_UI_Bright_Click
	aba = { id = 17208408337, vol = 0.7 }, -- Roblox GUI - Tab
	ui_abrir = { id = 17208405682, vol = 0.9 }, -- Roblox GUI - Swipe
	ui_fechar = { id = 17208186900, vol = 0.8, proprio = 0.7 }, -- Roblox GUI - Back
	ui_negado = { id = 17208353912, vol = 0.5 }, -- Roblox GUI - Negative
	compra = { id = 17208380755, vol = 0.6 }, -- Roblox GUI - Purchase
	dinheiro = { id = 127645268874265, vol = 0.5 }, -- CoinTransfer_01 (Roblox)
	assalto = { id = 9113728049, vol = 0.7 }, -- PSE Cash Register, Drawer
	alarme = { id = 9119164823, vol = 1.6 }, -- PSE Siren Variety, Short Bursts
	radio_policia = { id = 9116219037, vol = 1.8 }, -- PSE LAPD Radio Beep, Dispatcher Chatter
}
M.LIBRARY = LIBRARY

-- Pura: confere se um móvel cabe na unidade (mesma regra do servidor, para o fantasma ficar vermelho).
local function footprint(size: Vector3, rot: number): (number, number)
	if rot % 2 == 1 then
		return size.Z / 2, size.X / 2
	end
	return size.X / 2, size.Z / 2
end
-- Devolve também o motivo, com as mesmas frases do servidor (aparecem embaixo do móvel no modo construção).
local function fits(unit, sizes, floors, placed, id: string, x: number, z: number, rot: number, ignore: number?): (boolean, string?)
	local size = sizes[id]
	if not size then
		return false, "Móvel desconhecido."
	end
	local hx, hz = footprint(size, rot)
	if math.abs(x) + hx > unit.meia[1] + 0.01 or math.abs(z) + hz > unit.meia[2] + 0.01 then
		return false, "Fora do apartamento."
	end
	local k = unit.livre
	if x + hx > k[1] and x - hx < k[2] and z + hz > k[3] and z - hz < k[4] then
		return false, "Deixe livre a saída do elevador."
	end
	local count = 0
	for _, item in placed do
		if item.u ~= ignore then
			count += 1
			if not floors[id] and not floors[item.id] and sizes[item.id] then
				local ox, oz = footprint(sizes[item.id], item.r)
				if math.abs(item.x - x) < hx + ox - 0.1 and math.abs(item.z - z) < hz + oz - 0.1 then
					return false, "Encostado em outro móvel."
				end
			end
		end
	end
	if unit.maximo and count >= unit.maximo then
		return false, string.format("Apartamento cheio (máximo de %d móveis).", unit.maximo)
	end
	return true, nil
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
-- Sistema de design do Agente (o implante que é o "celular" de Maré Baixa), seguindo as skills de interface:
-- vidro azul-abissal, coral para molduras e ações, ciano maré para o que está ao vivo (chamada, sinal),
-- âmbar para dinheiro e trabalho. Rajdhani nos títulos e botões, TitilliumWeb no texto e números de
-- largura fixa nos relógios. Painéis chanfrados com borda em Path2D. Frases normais (nada de CAIXA ALTA
-- nem "A · B · C"), e o único destaque forte é a holochamada.
local ABYSS = Color3.fromRGB(10, 20, 28)
local WELL = Color3.fromRGB(6, 12, 18)
local CORAL = Color3.fromRGB(255, 92, 84)
local TIDE = Color3.fromRGB(94, 246, 255)
local AMBER = Color3.fromRGB(255, 196, 64)
local PAPER = Color3.fromRGB(234, 240, 244)
local FOG = Color3.fromRGB(138, 158, 170)
local GOOD = Color3.fromRGB(98, 232, 148)
local DANGER = Color3.fromRGB(255, 70, 84)
local GLASS = 0.16
local RAJDHANI = "rbxassetid://12187375422"
local TITILLIUM = "rbxasset://fonts/families/TitilliumWeb.json"
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"

local function start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local SoundService = game:GetService("SoundService")
	local HttpService = game:GetService("HttpService")
	local TweenService = game:GetService("TweenService")
	local player = Players.LocalPlayer
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
	local lines = decode("FalasProntas", {})
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

	local failed: { [number]: boolean } = {}
	task.spawn(function()
		local probes = {}
		for _, entry in LIBRARY do
			local probe = Instance.new("Sound")
			probe.SoundId = string.format("rbxassetid://%.0f", entry.id)
			table.insert(probes, probe)
		end
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(probes, function(content, status)
				local id = tonumber(string.match(tostring(content), "%d+"))
				if status == Enum.AssetFetchStatus.Failure and id then
					failed[id] = true
				end
			end)
		end)
		for _, probe in probes do
			probe:Destroy()
		end
	end)
	-- Toca e devolve o Sound (o toque da chamada precisa parar quando atende).
	local function sound(key: string, volume: number?): Sound?
		local entry = LIBRARY[key]
		local own = SOUNDS[key]
		local preferOwn = entry ~= nil and entry.proprio ~= nil and type(own) == "number" and own > 0
		local useLibrary = entry ~= nil and not preferOwn and not failed[entry.id]
		local id = if useLibrary then entry.id else own
		if type(id) ~= "number" or id <= 0 then
			return nil
		end
		local item = Instance.new("Sound")
		item.SoundId = string.format("rbxassetid://%.0f", id)
		item.Volume = (volume or 1) * (if useLibrary then entry.vol elseif preferOwn then entry.proprio else 0.6)
		item.Looped = entry ~= nil and entry.loop == true
		item.Parent = SoundService
		item:Play()
		item.Ended:Once(function()
			item:Destroy()
		end)
		task.delay(30, function()
			if item.Parent then
				item:Destroy()
			end
		end)
		return item
	end

	-- Kit ------------------------------------------------------------------------------------------------
	local function new(class: string, parent: Instance?, props)
		local item = Instance.new(class)
		for key, value in props or {} do
			(item :: any)[key] = value
		end
		item.Parent = parent
		return item
	end
	local function display(weight: Enum.FontWeight?): Font
		return Font.new(RAJDHANI, weight or Enum.FontWeight.Bold)
	end
	local function body(weight: Enum.FontWeight?): Font
		return Font.new(TITILLIUM, weight or Enum.FontWeight.Regular)
	end
	local DIGITS = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
	local MONEY = Font.new(BUILDER, Enum.FontWeight.ExtraBold) -- tem o símbolo do euro; a Rajdhani pode não ter
	local function text(parent, name, value, size, color, props)
		local base = {
			Name = name, Text = value, FontFace = body(), TextSize = size, TextColor3 = color, BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromScale(1, 1),
		}
		for key, value2 in props or {} do
			base[key] = value2
		end
		return new("TextLabel", parent, base)
	end
	local function outline(item, color: Color3, transparency: number, thickness: number?)
		return new("UIStroke", item, { Color = color, Transparency = transparency, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	end
	local function uiScale(item: Instance): number
		local k, node = 1, item
		while node do
			local found = node:FindFirstChildOfClass("UIScale")
			if found then
				k *= found.Scale
			end
			node = node.Parent :: Instance
		end
		return k
	end
	-- Chanfro da skill roblox-ui-genre-scifi (hud_shapes.luau): um Frame girado 45° recortado por outro corta os
	-- cantos sem emenda, e um Path2D fechado desenha a borda fina pelos cortes. corners: "all", "tlbr" ou "trbl".
	local function chamfer(root: GuiObject, cut: number, corners: string, color: Color3, transparency: number, edgeColor: Color3?, edgeAlpha: number?)
		root.BackgroundTransparency = 1
		local clip = new("Frame", root, { Name = "Chanfro", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = root.ZIndex })
		local fill = new("Frame", clip, {
			Name = "Vidro", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = color,
			BackgroundTransparency = transparency, BorderSizePixel = 0, Rotation = if corners == "trbl" then -45 else 45, ZIndex = root.ZIndex,
		})
		-- Brilho do vidro: mais claro em cima (rotação compensa o giro de 45° do recheio).
		new("UIGradient", fill, { Rotation = 45, Transparency = NumberSequence.new(0.35, 0), Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 210, 220)) })
		local function layout()
			local w, h = root.AbsoluteSize.X, root.AbsoluteSize.Y
			if w < 1 or h < 1 then
				return
			end
			local c = cut * uiScale(root)
			local cutting = ((w + h) / 2 - c) / math.sqrt(2)
			local open = (w + h) / math.sqrt(2) + 2
			local ax = cutting
			local by = if corners == "all" then cutting else open
			fill.Size = UDim2.fromScale(2 * ax / w, 2 * by / h)
		end
		root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
		task.defer(layout)
		if edgeColor then
			local tl = corners == "all" or corners == "tlbr"
			local tr = corners == "all" or corners == "trbl"
			local points = {}
			local function p(sx, ox, sy, oy)
				table.insert(points, Path2DControlPoint.new(UDim2.new(sx, ox, sy, oy)))
			end
			if tl then
				p(0, 0, 0, cut)
				p(0, cut, 0, 0)
			else
				p(0, 0, 0, 0)
			end
			if tr then
				p(1, -cut, 0, 0)
				p(1, 0, 0, cut)
			else
				p(1, 0, 0, 0)
			end
			if tl then
				p(1, 0, 1, -cut)
				p(1, -cut, 1, 0)
			else
				p(1, 0, 1, 0)
			end
			if tr then
				p(0, cut, 1, 0)
				p(0, 0, 1, -cut)
			else
				p(0, 0, 1, 0)
			end
			pcall(function()
				local edge = Instance.new("Path2D")
				edge.Name = "Borda"
				edge.Closed = true
				edge.Color3 = edgeColor
				edge.Transparency = edgeAlpha or 0.35
				edge.Thickness = 1.5
				edge.ZIndex = root.ZIndex + 1
				edge:SetControlPoints(points)
				edge.Parent = root
			end)
		end
		return fill
	end
	-- Placa de vidro chanfrada (o recheio fica atrás do conteúdo pelo ZIndex).
	local function plate(parent, name: string, props, cut: number?, corners: string?, edge: Color3?)
		local base = { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0 }
		for key, value in props or {} do
			base[key] = value
		end
		local item = new("Frame", parent, base)
		chamfer(item, cut or 12, corners or "tlbr", ABYSS, GLASS, edge or CORAL, 0.45)
		return item
	end
	-- Botões: primário cheio (uma ação por tela), secundário com contorno, fantasma só texto.
	local function button(parent, name: string, caption: string, kind: string, color: Color3, props, onClick)
		local base = {
			Name = name, Text = caption, FontFace = display(), TextSize = 17, TextColor3 = if kind == "primario" then WELL else color,
			BackgroundColor3 = color, BackgroundTransparency = if kind == "primario" then 0 elseif kind == "secundario" then 0.88 else 1,
			AutoButtonColor = false, BorderSizePixel = 0,
		}
		for key, value in props or {} do
			base[key] = value
		end
		local item = new("TextButton", parent, base)
		new("UICorner", item, { CornerRadius = UDim.new(0, 2) })
		if kind == "secundario" then
			outline(item, color, 0.25, 1.5)
		end
		local scale = new("UIScale", item, {})
		local rest = item.BackgroundTransparency
		item.MouseEnter:Connect(function()
			item.BackgroundTransparency = math.max(0, rest - 0.12)
			sound("ui_tick", 0.6)
		end)
		item.MouseLeave:Connect(function()
			item.BackgroundTransparency = rest
			scale.Scale = 1
		end)
		item.MouseButton1Down:Connect(function()
			scale.Scale = 0.96
		end)
		item.MouseButton1Up:Connect(function()
			scale.Scale = 1
		end)
		item.Activated:Connect(function()
			sound("clique", 1)
			onClick()
		end)
		return item
	end
	local function tween(item: Instance, seconds: number, goal, style: Enum.EasingStyle?)
		local motion = TweenService:Create(item, TweenInfo.new(seconds, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal)
		motion:Play()
		return motion
	end
	-- Retrato oficial do avatar de um jogador (o mesmo do app do Roblox).
	local headshots: { [number]: string } = {}
	local function headshot(userId: number): string
		if headshots[userId] then
			return headshots[userId]
		end
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		headshots[userId] = if ok then image else ""
		return headshots[userId]
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local gui = new("ScreenGui", playerGui, {
		Name = "CyberOutlawVida", ResetOnSpawn = false, DisplayOrder = 36, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, Enabled = false,
	})
	local top = new("ScreenGui", playerGui, {
		Name = "CyberOutlawVidaTopo", ResetOnSpawn = false, DisplayOrder = 36, ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets, Enabled = false,
	})

	-- Carteira e estrelas, à direita da barra do Roblox --------------------------------------------------------
	local chip = new("Frame", top, {
		Name = "Carteira", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(132, 32),
	})
	chamfer(chip, 8, "tlbr", ABYSS, 0.25, AMBER, 0.5)
	local wallet = text(chip, "Valor", money(0), 17, AMBER, {
		TextXAlignment = Enum.TextXAlignment.Center, FontFace = MONEY, ZIndex = 3,
	})
	-- Sete estrelas: acesas em vermelho, piscando quando a polícia perdeu você de vista (está procurando); a
	-- estrela nova cresce e volta ao tamanho quando o nível sobe.
	local stars = new("Frame", top, {
		Name = "Estrelas", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -150, 0.5, 0), Size = UDim2.fromOffset(7 * 16 + 4, 30),
		BackgroundTransparency = 1, Visible = false,
	})
	new("UIListLayout", stars, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
	local starLabels = {}
	for index = 1, 7 do
		local label = text(stars, "Estrela", "★", 18, DANGER, {
			Size = UDim2.fromOffset(16, 26), LayoutOrder = index, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.35,
			FontFace = Font.new(BUILDER, Enum.FontWeight.Bold),
		})
		starLabels[index] = { label = label, scale = new("UIScale", label, {}) }
	end
	local shownLevel = 0
	local shownMoney = player:GetAttribute("CyberOutlawEddies") or 0
	local function refreshWallet()
		local goal = player:GetAttribute("CyberOutlawEddies") or 0
		-- Conta subindo ou descendo rápido (o número muda na frente do jogador).
		local from = shownMoney
		shownMoney = goal
		local started = os.clock()
		task.spawn(function()
			while os.clock() - started < 0.45 do
				local k = (os.clock() - started) / 0.45
				wallet.Text = money(from + (goal - from) * (1 - (1 - k) ^ 3))
				task.wait()
			end
			wallet.Text = money(goal)
		end)
	end
	player:GetAttributeChangedSignal("CyberOutlawEddies"):Connect(refreshWallet)
	wallet.Text = money(shownMoney)

	-- Avisos: cartões curtos que entram pela direita, com a barra da cor do assunto -----------------------------
	local toasts = new("Frame", gui, {
		Name = "Avisos", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, if touch then 112 else 74), Size = UDim2.fromOffset(300, 220),
		BackgroundTransparency = 1,
	})
	new("UIListLayout", toasts, { HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local toastCount = 0
	local function toast(message: string, color: Color3?)
		toastCount += 1
		local holder = new("Frame", toasts, { Name = "Aviso", Size = UDim2.fromOffset(290, 34), BackgroundTransparency = 1, LayoutOrder = toastCount, ClipsDescendants = true })
		local item = new("Frame", holder, { Name = "Cartao", Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(1, 0), BackgroundTransparency = 1 })
		chamfer(item, 8, "tlbr", ABYSS, 0.12, nil)
		new("Frame", item, { Name = "Barra", Size = UDim2.new(0, 3, 1, -10), Position = UDim2.fromOffset(6, 5), BackgroundColor3 = color or TIDE, BorderSizePixel = 0, ZIndex = 2 })
		text(item, "Texto", message, 15, PAPER, {
			Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -22, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2, FontFace = body(Enum.FontWeight.SemiBold),
		})
		tween(item, 0.25, { Position = UDim2.fromScale(0, 0) })
		task.delay(4.2, function()
			tween(item, 0.25, { Position = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Quad)
			task.delay(0.3, function()
				holder:Destroy()
			end)
		end)
		local frames = {}
		for _, child in toasts:GetChildren() do
			if child:IsA("Frame") then
				table.insert(frames, child)
			end
		end
		if #frames > 4 then
			table.sort(frames, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			frames[1]:Destroy()
		end
	end

	-- Botões Casa (H) e Agente (J) --------------------------------------------------------------------------------
	local function hudButton(name: string, caption: string, key: string?)
		local item = new("TextButton", gui, {
			Name = name, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Size = UDim2.fromOffset(if touch then 58 else 96, if touch then 40 else 36), AnchorPoint = Vector2.new(1, 0),
		})
		chamfer(item, 8, "tlbr", ABYSS, 0.2, CORAL, 0.2)
		text(item, "Nome", caption, if touch then 15 else 17, PAPER, { TextXAlignment = Enum.TextXAlignment.Center, FontFace = display(), ZIndex = 3,
			Size = UDim2.new(1, if key and not touch then -22 else 0, 1, 0) })
		if key and not touch then
			text(item, "Tecla", key, 12, CORAL, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(14, 14),
				TextXAlignment = Enum.TextXAlignment.Center, FontFace = DIGITS, ZIndex = 3 })
		end
		item.MouseEnter:Connect(function()
			sound("ui_tick", 0.6)
		end)
		return item
	end
	local homeButton = hudButton("Casa", "Casa", "H")
	local agentButton = hudButton("Agente", "Agente", "J")
	local function layoutButtons()
		local size = gui.AbsoluteSize
		if touch then
			homeButton.Position = UDim2.fromOffset(size.X - 12, 62)
			agentButton.Position = UDim2.fromOffset(size.X - 76, 62)
		else
			homeButton.AnchorPoint, agentButton.AnchorPoint = Vector2.new(1, 1), Vector2.new(1, 1)
			homeButton.Position = UDim2.fromOffset(size.X - 24, size.Y - 96)
			agentButton.Position = UDim2.fromOffset(size.X - 128, size.Y - 96)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutButtons)
	task.defer(layoutButtons)

	-- Trabalho atual: quem paga e o prazo em cima, o que fazer e a distância embaixo ------------------------------
	local objective = new("Frame", gui, {
		Name = "Objetivo", AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(1, 0), Position = if touch then UDim2.fromOffset(12, 172) else UDim2.new(1, -24, 0, 16),
		Size = UDim2.fromOffset(if touch then 232 else 340, if touch then 44 else 50), BackgroundTransparency = 1, Visible = false,
	})
	chamfer(objective, 10, "tlbr", ABYSS, 0.2, AMBER, 0.55)
	local objectiveHead = text(objective, "Quem", "", if touch then 13 else 15, FOG, {
		Position = UDim2.fromOffset(12, 3), Size = UDim2.new(1, -74, 0.45, 0), FontFace = body(Enum.FontWeight.SemiBold), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
	})
	local objectiveClock = text(objective, "Prazo", "", if touch then 13 else 15, AMBER, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 3), Size = UDim2.new(0, 60, 0.45, 0), TextXAlignment = Enum.TextXAlignment.Right,
		FontFace = DIGITS, ZIndex = 3,
	})
	local objectiveText = text(objective, "Texto", "", if touch then 15 else 18, AMBER, {
		Position = UDim2.new(0, 12, 0.42, 0), Size = UDim2.new(1, -20, 0.58, -3), TextTruncate = Enum.TextTruncate.AtEnd, FontFace = display(), ZIndex = 3,
	})
	local marker = new("Part", nil, {
		Name = "CyberOutlawObjetivo", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one,
	})
	local board = new("BillboardGui", marker, {
		Name = "Marcador", AlwaysOnTop = true, Size = UDim2.fromOffset(90, 54), LightInfluence = 0, MaxDistance = 100000,
	})
	local diamond = new("Frame", board, {
		Name = "Losango", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(16, 16), Rotation = 45,
		BackgroundColor3 = AMBER, BorderSizePixel = 0,
	})
	outline(diamond, WELL, 0, 2)
	local distanceText = text(board, "Distancia", "", 14, AMBER, {
		Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3,
		FontFace = display(),
	})
	-- Localização mandada por alguém na chamada: losango ciano por um minuto.
	local friendMarker = marker:Clone()
	friendMarker.Name = "CyberOutlawAmigo"
	local friendBoard = friendMarker:FindFirstChild("Marcador") :: BillboardGui
	friendBoard:FindFirstChild("Losango").BackgroundColor3 = TIDE
	local friendText = friendBoard:FindFirstChild("Distancia") :: TextLabel
	friendText.TextColor3 = TIDE
	local friendUntil = 0
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

	-- Holochamada (o destaque da interface) -----------------------------------------------------------------------
	-- Como em Cyberpunk 2077 e Edgerunners, não existe celular na mão: o Agente projeta a chamada na visão. O
	-- rosto entra num quadro chanfrado com varredura de holograma; quem fala tem as barras de voz mexendo; as
	-- falas viram legenda "Nome: fala" embaixo. Serve para os fixers (rosto 3D) e para outros jogadores (o
	-- retrato oficial do avatar), com o toque, o atender e o desligar das chamadas do próprio Roblox.
	local HOLO_AT = if touch then UDim2.new(0.5, -210, 0, 2) else UDim2.new(0, 28, 0.24, 0)
	local holo = new("Frame", gui, {
		Name = "Holochamada", Position = HOLO_AT, Size = if touch then UDim2.fromOffset(420, 84) else UDim2.fromOffset(392, 132),
		BackgroundTransparency = 1, Visible = false,
	})
	chamfer(holo, 16, "tlbr", ABYSS, 0.1, CORAL, 0.25)
	local frameSize = if touch then Vector2.new(58, 70) else Vector2.new(88, 108)
	local portraitFrame = new("Frame", holo, {
		Name = "Quadro", Position = UDim2.fromOffset(10, (if touch then 84 else 132) / 2 - frameSize.Y / 2), Size = UDim2.fromOffset(frameSize.X, frameSize.Y),
		BackgroundTransparency = 1, ZIndex = 3,
	})
	chamfer(portraitFrame, 10, "tlbr", WELL, 0, CORAL, 0)
	local portrait = new("ViewportFrame", portraitFrame, {
		Name = "Rosto", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(150, 140, 150),
		LightColor = Color3.fromRGB(255, 230, 225), LightDirection = Vector3.new(-0.6, -0.5, 1), ZIndex = 4,
	})
	local portraitCamera = new("Camera", portrait, { FieldOfView = 24 })
	portrait.CurrentCamera = portraitCamera
	local avatar = new("ImageLabel", portraitFrame, { Name = "Avatar", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4, Visible = false,
		ScaleType = Enum.ScaleType.Crop })
	-- Tom de holograma por cima e a linha de varredura que desce.
	local tint = new("Frame", portraitFrame, { Name = "Tom", Size = UDim2.fromScale(1, 1), BackgroundColor3 = TIDE, BackgroundTransparency = 0.9, BorderSizePixel = 0, ZIndex = 5 })
	local sweep = new("Frame", portraitFrame, { Name = "Varredura", Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = TIDE, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 6 })
	local textX = frameSize.X + 22
	local callerName = text(holo, "Nome", "", if touch then 21 else 26, PAPER, {
		Position = UDim2.fromOffset(textX, if touch then 8 else 14), Size = UDim2.new(1, -textX - (if touch then 190 else 14), 0, if touch then 24 else 30),
		FontFace = display(), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
	})
	local callStatus = text(holo, "Status", "", if touch then 14 else 16, CORAL, {
		Position = UDim2.fromOffset(textX, if touch then 32 else 46), Size = UDim2.new(1, -textX - (if touch then 190 else 14), 0, 18),
		FontFace = body(Enum.FontWeight.SemiBold), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
	})
	local callerRole = text(holo, "Cargo", "", if touch then 12 else 14, FOG, {
		Position = UDim2.fromOffset(textX, if touch then 52 else 66), Size = UDim2.new(1, -textX - (if touch then 190 else 14), 0, 16),
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3,
	})
	-- Barras de voz: mexem enquanto alguém fala na chamada.
	-- No celular as barras ficam na base do retrato (a faixa é estreita e o nome precisa de espaço).
	local wave = new("Frame", if touch then portraitFrame else holo, {
		Name = "Voz", AnchorPoint = if touch then Vector2.new(0.5, 1) else Vector2.new(1, 0),
		Position = if touch then UDim2.new(0.5, 0, 1, -3) else UDim2.new(1, -14, 0, 18),
		Size = if touch then UDim2.fromOffset(50, 14) else UDim2.fromOffset(54, 20), BackgroundTransparency = 1, ZIndex = 7,
	})
	local bars = {}
	for index = 1, 9 do
		bars[index] = new("Frame", wave, {
			Name = "Barra", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, (index - 1) * 6, 0.5, 0), Size = UDim2.new(0, 3, 0.15, 0),
			BackgroundColor3 = TIDE, BorderSizePixel = 0, ZIndex = 7,
		})
	end
	local actions = new("Frame", holo, {
		Name = "Acoes", AnchorPoint = if touch then Vector2.new(1, 0.5) else Vector2.zero,
		Position = if touch then UDim2.new(1, -10, 0.5, 0) else UDim2.fromOffset(textX, 88), Size = if touch then UDim2.fromOffset(180, 44) else UDim2.new(1, -textX - 12, 0, 34),
		BackgroundTransparency = 1, ZIndex = 3,
	})
	new("UIListLayout", actions, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = if touch then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left })
	-- Frases prontas da chamada entre jogadores: uma coluna que abre ao lado da chamada.
	local phrases = new("Frame", gui, {
		Name = "Frases", Size = UDim2.fromOffset(250, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false,
	})
	new("UIListLayout", phrases, { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	local subtitle = new("Frame", gui, {
		Name = "Legenda", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if touch then -64 else -126),
		Size = UDim2.fromOffset(if touch then 420 else 680, if touch then 50 else 60), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Visible = false,
	})
	new("UIGradient", subtitle, { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.18, 0.5),
		NumberSequenceKeypoint.new(0.82, 0.5), NumberSequenceKeypoint.new(1, 1) }) })
	local subtitleText = text(subtitle, "Texto", "", if touch then 16 else 19, PAPER, {
		Position = UDim2.fromOffset(18, 2), Size = UDim2.new(1, -36, 1, -4), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = body(Enum.FontWeight.SemiBold), RichText = true, TextStrokeTransparency = 0.55,
	})

	local call = nil -- { kind = "fixer"|"jogador", state, offer, id, outro, ring, token, at, speaking }
	local speakerColor = "#5EF6FF"
	local function stopRing()
		if call and call.ring then
			call.ring:Destroy()
			call.ring = nil
		end
	end
	local function clearActions()
		for _, child in actions:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		phrases.Visible = false
	end
	-- Ações da chamada: no PC a tecla aparece pequena dentro do botão.
	local function action(caption: string, kind: string, color: Color3, key: string?, order: number, onClick)
		local width = if touch then 86 else math.max(96, #caption * 9 + 34)
		local item = button(actions, caption, caption, kind, color, {
			Size = UDim2.fromOffset(width, if touch then 44 else 32), LayoutOrder = order, TextSize = if touch then 15 else 16, ZIndex = 4,
		}, onClick)
		if key and not touch then
			item.Text = caption .. "  " .. key
		end
		return item
	end
	local function showFace(fixerId: string?, userId: number?)
		for _, child in portrait:GetChildren() do
			if child:IsA("WorldModel") then
				child:Destroy()
			end
		end
		portrait.Visible, avatar.Visible = fixerId ~= nil, userId ~= nil
		if userId then
			avatar.Image = headshot(userId)
			speakerColor = "#5EF6FF"
			return
		end
		local fixer = fixers[fixerId or ""]
		local tone = if fixer then Color3.fromRGB(fixer.cor[1], fixer.cor[2], fixer.cor[3]) else TIDE
		speakerColor = string.format("#%02X%02X%02X", math.floor(tone.R * 255), math.floor(tone.G * 255), math.floor(tone.B * 255))
		local source = folder:FindFirstChild("Fixers")
		local template = source and source:FindFirstChild(fixerId or "")
		if template then
			local world = new("WorldModel", portrait, { Name = "Mundo" })
			local bust = template:Clone()
			bust.Parent = world
			local head = bust:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				local at = head.Position
				portraitCamera.CFrame = CFrame.lookAt(at + Vector3.new(0.9, -0.15, -5), at + Vector3.new(0, -0.45, 0))
			end
		end
	end
	local function openCard()
		holo.Visible = true
		holo.Position = HOLO_AT + (if touch then UDim2.fromOffset(0, -30) else UDim2.fromOffset(-50, 0))
		tween(holo, 0.28, { Position = HOLO_AT })
	end
	local function hangUp(soundKey: string?)
		stopRing()
		if soundKey then
			sound(soundKey, 1)
		end
		call = nil
		clearActions()
		tween(holo, 0.2, { Position = HOLO_AT + (if touch then UDim2.fromOffset(0, -30) else UDim2.fromOffset(-50, 0)) }, Enum.EasingStyle.Quad)
		task.delay(0.2, function()
			if not call then
				holo.Visible = false
			end
		end)
		subtitle.Visible = false
	end
	-- Fala letra por letra (MaxVisibleGraphemes, sem cortar acento) com as barras de voz mexendo.
	local function say(speaker: string, color: string, textLines, done)
		if not call then
			return
		end
		local token = {}
		call.token = token
		subtitle.Visible = true
		task.spawn(function()
			for _, line in textLines do
				subtitleText.Text = string.format('<font color="%s">%s:</font> %s', color, speaker, line)
				local total = utf8.len(subtitleText.ContentText) or #line
				local head = (utf8.len(speaker) or #speaker) + 2
				call.speaking = true
				for count = head, total, 2 do
					if not call or call.token ~= token then
						return
					end
					subtitleText.MaxVisibleGraphemes = count
					task.wait(0.028)
				end
				subtitleText.MaxVisibleGraphemes = -1
				if call then
					call.speaking = false
				end
				task.wait(math.clamp(total * 0.034, 1.5, 3.2))
			end
			if call and call.token == token and done then
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
		callStatus.Text = offer.titulo
		callStatus.TextColor3 = AMBER
		callerRole.Text = string.format("%s em %s, prazo de %s", money(offer.valor), offer.bairro or "Maré Baixa", clock(offer.prazo))
		callerRole.TextColor3 = AMBER
		subtitleText.MaxVisibleGraphemes = -1
		subtitleText.Text = string.format('<font color="#FFC440">Trabalho:</font> %s', offer.objetivo)
		clearActions()
		action("Aceitar", "primario", GOOD, "T", 1, function()
			answer()
		end)
		action("Recusar", "secundario", CORAL, "Y", 2, function()
			decline()
		end)
	end
	answer = function()
		if not call then
			return
		end
		if call.kind == "fixer" then
			if call.state == "tocando" then
				stopRing()
				sound("chamada_atender", 1)
				call.state = "conversa"
				call.at = os.clock()
				request:FireServer("atender", call.offer.id)
				callStatus.Text = "Em chamada"
				callStatus.TextColor3 = TIDE
				clearActions()
				say(call.offer.nome, speakerColor, call.offer.falas, offerStep)
			elseif call.state == "oferta" then
				request:FireServer("aceitar", call.offer.id)
				sound("notificacao", 1)
				call.state = "recado"
				clearActions()
				say(call.offer.nome, speakerColor, { call.offer.tchau }, function()
					hangUp("chamada_fim")
				end)
			end
		elseif call.kind == "jogador" and call.state == "tocando" then
			stopRing()
			request:FireServer("atenderJogador", call.id)
		end
	end
	decline = function()
		if not call then
			return
		end
		if call.kind == "fixer" then
			if call.offer then
				request:FireServer("recusar", call.offer.id)
			end
			hangUp("chamada_recusar")
		else
			request:FireServer(if call.state == "tocando" then "recusarJogador" else "desligar", call.id)
			hangUp("chamada_recusar")
		end
	end
	local function ring()
		local tone = sound("chamada", 1)
		if tone and call then
			call.ring = tone
		end
	end
	local function incoming(offer, outgoing: boolean)
		if call and call.kind == "jogador" then
			return -- quem está falando com outro jogador não recebe fixer por cima
		end
		stopRing()
		call = { kind = "fixer", offer = offer, state = "tocando", at = os.clock() }
		showFace(offer.fixer, nil)
		callerName.Text = offer.nome
		callerRole.Text = offer.cargo
		callerRole.TextColor3 = FOG
		clearActions()
		openCard()
		if outgoing then
			answer()
			return
		end
		callStatus.Text = "Chamada recebida"
		callStatus.TextColor3 = CORAL
		action("Atender", "primario", TIDE, "T", 1, answer)
		action("Recusar", "secundario", CORAL, "Y", 2, decline)
		ring()
	end
	local function fixerMessage(fixerId: string, message: string, good: boolean)
		if call and call.kind == "jogador" then
			toast(message, if good then GOOD else DANGER)
			return
		end
		local fixer = fixers[fixerId]
		stopRing()
		call = { kind = "fixer", state = "recado", at = os.clock() }
		showFace(fixerId, nil)
		callerName.Text = if fixer then fixer.nome else "Fixer"
		callerRole.Text = if fixer then fixer.titulo else ""
		callerRole.TextColor3 = FOG
		callStatus.Text = if good then "Trabalho concluído" else "Trabalho perdido"
		callStatus.TextColor3 = if good then GOOD else DANGER
		clearActions()
		openCard()
		sound("notificacao", 1)
		say(callerName.Text, speakerColor, { message }, function()
			hangUp("chamada_fim")
		end)
	end
	-- Chamadas entre jogadores.
	local function playerCard(data, state: string)
		stopRing()
		call = { kind = "jogador", id = data.id, outro = data.outro, state = state, at = os.clock() }
		showFace(nil, data.outro.userId)
		callerName.Text = data.outro.nome
		callerRole.Text = "Contato do Agente"
		callerRole.TextColor3 = FOG
		clearActions()
		openCard()
	end
	local function activeActions()
		clearActions()
		local order = 0
		local function add(caption, kind, color, onClick)
			order += 1
			action(caption, kind, color, nil, order, onClick)
		end
		add("Frases", "secundario", TIDE, function()
			phrases.Visible = not phrases.Visible
		end)
		if not touch then
			add("Localização", "secundario", TIDE, function()
				request:FireServer("compartilharLocal", call and call.id)
			end)
			add("Convidar", "secundario", AMBER, function()
				request:FireServer("convidarCasa", call and call.id)
			end)
		end
		add("Desligar", "primario", CORAL, function()
			decline()
		end)
		-- No celular a localização e o convite vão no topo da lista de frases (a faixa é estreita).
		for _, child in phrases:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local function phraseButton(caption: string, color: Color3, index: number, onClick)
			button(phrases, "Frase", caption, "secundario", color, {
				Size = UDim2.new(1, 0, 0, if touch then 40 else 32), LayoutOrder = index, TextSize = if touch then 15 else 16,
				TextXAlignment = Enum.TextXAlignment.Left, FontFace = body(Enum.FontWeight.SemiBold),
			}, onClick)
		end
		if touch then
			phraseButton("Mandar minha localização", TIDE, 1, function()
				request:FireServer("compartilharLocal", call and call.id)
				phrases.Visible = false
			end)
			phraseButton("Convidar pro meu apartamento", AMBER, 2, function()
				request:FireServer("convidarCasa", call and call.id)
				phrases.Visible = false
			end)
		end
		for index, line in lines do
			phraseButton(line, PAPER, index + 2, function()
				request:FireServer("falaPronta", call and call.id, index)
				phrases.Visible = false
			end)
		end
		phrases.Position = if touch then UDim2.new(0.5, -125, 0, 92) else UDim2.new(0, 28, 0.24, 140)
	end

	-- Painéis da Casa e do Agente -------------------------------------------------------------------------------
	local dim = new("Frame", gui, { Name = "Fundo", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 20 })
	local card = new("Frame", gui, {
		Name = "Painel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(if touch then 0.9 else 0.58, if touch then 0.97 else 0.76),
		BackgroundTransparency = 1, Visible = false, ZIndex = 21,
	})
	new("UISizeConstraint", card, { MaxSize = Vector2.new(860, 640), MinSize = Vector2.new(320, 240) })
	local cardScale = new("UIScale", card, {})
	chamfer(card, 18, "tlbr", ABYSS, 0.04, CORAL, 0.3)
	local title = text(card, "Titulo", "", if touch then 20 else 26, PAPER, {
		Position = UDim2.fromOffset(18, 6), Size = UDim2.new(1, -150, 0, 30), ZIndex = 22, FontFace = display(), TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local subtitleLabel = text(card, "Subtitulo", "", 14, FOG, {
		Position = UDim2.fromOffset(18, 34), Size = UDim2.new(1, -150, 0, 16), ZIndex = 22, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local tabs = new("ScrollingFrame", card, {
		Name = "Abas", Position = UDim2.fromOffset(14, 56), Size = UDim2.new(1, -28, 0, 38), BackgroundTransparency = 1, ZIndex = 22, BorderSizePixel = 0,
		ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
	})
	new("UIListLayout", tabs, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center })
	local content = new("ScrollingFrame", card, {
		Name = "Conteudo", Position = UDim2.fromOffset(14, 100), Size = UDim2.new(1, -28, 1, -110), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = CORAL, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 22,
		ElasticBehavior = Enum.ElasticBehavior.Never,
	})
	local panel = nil -- "casa" | "agente"
	local tab = "loja"
	local filter = "Todos"
	local render
	local function setOpen(which)
		local was = panel
		panel = which
		local open = which ~= nil
		player:SetAttribute("CyberOutlawPainel", open)
		if open then
			dim.Visible, card.Visible = true, true
			if not was then
				sound("ui_abrir", 1)
				cardScale.Scale = 0.94
				tween(cardScale, 0.22, { Scale = 1 })
				tween(dim, 0.22, { BackgroundTransparency = 0.45 })
			end
			render()
		elseif was then
			sound("ui_fechar", 1)
			tween(cardScale, 0.16, { Scale = 0.96 }, Enum.EasingStyle.Quad)
			tween(dim, 0.16, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
			task.delay(0.16, function()
				if not panel then
					dim.Visible, card.Visible = false, false
				end
			end)
		end
	end
	button(card, "Fechar", "Fechar", "secundario", CORAL, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(if touch then 84 else 96, 34), ZIndex = 23,
	}, function()
		setOpen(nil)
	end)
	local function clearContent()
		for _, child in content:GetChildren() do
			child:Destroy()
		end
		for _, child in tabs:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	local function section(order: number, caption: string)
		text(content, "Secao", caption, 15, FOG, { Size = UDim2.new(1, -8, 0, 26), LayoutOrder = order, ZIndex = 23, FontFace = body(Enum.FontWeight.SemiBold) })
	end
	local function row(order: number, height: number, edge: Color3?)
		local item = new("Frame", content, { Name = "Linha", Size = UDim2.new(1, -8, 0, height), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 23 })
		chamfer(item, 8, "tlbr", Color3.fromRGB(16, 30, 40), 0.1, edge, if edge then 0.4 else nil)
		return item
	end
	local function preview(parent, id: string, size: number)
		local view = new("ViewportFrame", parent, {
			Name = "Previa", Size = UDim2.fromOffset(size, size), BackgroundColor3 = WELL, BackgroundTransparency = 0,
			Ambient = Color3.fromRGB(170, 170, 190), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1.4, -0.6), ZIndex = 24,
		})
		new("UICorner", view, { CornerRadius = UDim.new(0, 2) })
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
		button(tabs, "Aba", caption, if selected then "primario" else "fantasma", if selected then CORAL else PAPER, {
			Size = UDim2.fromOffset(if touch then 112 else 132, 32), LayoutOrder = order, ZIndex = 23, TextSize = 17,
		}, function()
			if tab ~= key then
				sound("aba", 1)
				tab = key
				render()
			end
		end)
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
		local chips = new("ScrollingFrame", content, {
			Name = "Filtros", Size = UDim2.new(1, -8, 0, 34), BackgroundTransparency = 1, LayoutOrder = 0, ZIndex = 23, BorderSizePixel = 0,
			ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
		})
		new("UIListLayout", chips, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
		for index, cat in cats do
			local active = filter == cat
			button(chips, "Filtro", cat, if active then "secundario" else "fantasma", if active then TIDE else FOG, {
				Size = UDim2.fromOffset(#cat * 9 + 30, 30), LayoutOrder = index, ZIndex = 24, TextSize = 16,
			}, function()
				filter = cat
				render()
			end)
		end
		local grid = new("Frame", content, { Name = "Grade", Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 23 })
		new("UIGridLayout", grid, { CellSize = UDim2.fromOffset(if touch then 140 else 172, if touch then 206 else 238), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder })
		local cash = player:GetAttribute("CyberOutlawEddies") or 0
		for _, def in catalog do
			if filter == "Todos" or def.cat == filter then
				local cell = new("Frame", grid, { Name = def.id, BackgroundTransparency = 1, LayoutOrder = def.ordem, ZIndex = 23 })
				chamfer(cell, 10, "tlbr", Color3.fromRGB(16, 30, 40), 0.05, nil)
				local size = if touch then 104 else 128
				local view = preview(cell, def.id, size)
				view.AnchorPoint = Vector2.new(0.5, 0)
				view.Position = UDim2.new(0.5, 0, 0, 8)
				text(cell, "Nome", def.nome, 16, PAPER, { Position = UDim2.fromOffset(10, size + 12), Size = UDim2.new(1, -20, 0, 36), TextWrapped = true, ZIndex = 24,
					TextYAlignment = Enum.TextYAlignment.Top, FontFace = display() })
				local afford = cash >= def.preco
				local buy = button(cell, "Comprar", money(def.preco), if afford then "primario" else "secundario", if afford then AMBER else FOG, {
					AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 32), ZIndex = 24, FontFace = MONEY, TextSize = 16,
				}, function()
					if not afford then
						sound("ui_negado", 1)
						toast("Faltam " .. money(def.preco - cash) .. " para " .. def.nome .. ".", DANGER)
						return
					end
					request:FireServer("comprar", def.id)
				end)
				local _ = buy
			end
		end
	end

	local function mine()
		local order = 0
		order += 1
		section(order, "Guardados")
		local any = false
		for id, count in house.guardados do
			local def = byId[id]
			if def then
				any = true
				order += 1
				local line = row(order, 66)
				preview(line, id, 54).Position = UDim2.fromOffset(8, 6)
				text(line, "Nome", if count > 1 then string.format("%s (%d)", def.nome, count) else def.nome, 17, PAPER, {
					Position = UDim2.fromOffset(72, 0), Size = UDim2.new(1, -300, 1, 0), ZIndex = 24, FontFace = display(), TextTruncate = Enum.TextTruncate.AtEnd })
				button(line, "Colocar", "Colocar", "primario", TIDE, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -112, 0.5, 0), Size = UDim2.fromOffset(96, 34), ZIndex = 24 }, function()
					startPlacing(id, nil)
				end)
				button(line, "Vender", "Vender " .. money(def.preco * economy.venda), "secundario", CORAL, {
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(98, 34), ZIndex = 24, TextSize = 13, FontFace = MONEY,
				}, function()
					request:FireServer("venderGuardado", id)
				end)
			end
		end
		if not any then
			order += 1
			text(content, "Vazio", "Nada guardado. Os móveis comprados na loja aparecem aqui.", 15, FOG, { Size = UDim2.new(1, -8, 0, 26), LayoutOrder = order, ZIndex = 23 })
		end
		order += 1
		section(order, "No apartamento")
		for _, item in house.moveis do
			local def = byId[item.id]
			if def then
				order += 1
				local line = row(order, 66)
				preview(line, item.id, 54).Position = UDim2.fromOffset(8, 6)
				text(line, "Nome", def.nome, 17, PAPER, { Position = UDim2.fromOffset(72, 0), Size = UDim2.new(1, -390, 1, 0), ZIndex = 24, FontFace = display(),
					TextTruncate = Enum.TextTruncate.AtEnd })
				local uid = item.u
				button(line, "Mover", "Mover", "secundario", TIDE, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -212, 0.5, 0), Size = UDim2.fromOffset(96, 34), ZIndex = 24 }, function()
					startPlacing(item.id, uid)
				end)
				button(line, "Guardar", "Guardar", "secundario", AMBER, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -110, 0.5, 0), Size = UDim2.fromOffset(96, 34), ZIndex = 24 }, function()
					request:FireServer("guardar", uid)
				end)
				button(line, "Vender", "Vender", "secundario", CORAL, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(96, 34), ZIndex = 24 }, function()
					request:FireServer("vender", uid)
				end)
			end
		end
	end

	local function renovate()
		local order = 0
		for _, group in { { "piso", "Piso" }, { "luz", "Luz do teto" }, { "vidro", "Janelas" } } do
			order += 1
			section(order, group[2])
			order += 1
			local line = new("Frame", content, { Name = "Opcoes", Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 23 })
			new("UIGridLayout", line, { CellSize = UDim2.fromOffset(if touch then 156 else 178, 52), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder })
			for index, option in renovations[group[1]] or {} do
				local current = house[group[1]] == option.id
				local tile = new("TextButton", line, { Name = option.id, Text = "", AutoButtonColor = false, BackgroundTransparency = 1, LayoutOrder = index, ZIndex = 24 })
				chamfer(tile, 8, "tlbr", Color3.fromRGB(16, 30, 40), 0.05, if current then GOOD else nil, 0.2)
				new("Frame", tile, { Name = "Cor", Size = UDim2.new(0, 8, 1, -12), Position = UDim2.fromOffset(8, 6),
					BackgroundColor3 = Color3.fromRGB(option.cor[1], option.cor[2], option.cor[3]), BorderSizePixel = 0, ZIndex = 25 })
				text(tile, "Nome", option.nome, 15, PAPER, { Position = UDim2.fromOffset(24, 4), Size = UDim2.new(1, -30, 0, 22), ZIndex = 25, FontFace = display(),
					TextTruncate = Enum.TextTruncate.AtEnd })
				text(tile, "Preco", if current then "Em uso" elseif option.preco == 0 then "Grátis" else money(option.preco), 14, if current then GOOD else AMBER, {
					Position = UDim2.fromOffset(24, 26), Size = UDim2.new(1, -30, 0, 20), ZIndex = 25, FontFace = if current then body(Enum.FontWeight.SemiBold) else MONEY })
				tile.Activated:Connect(function()
					if not current then
						sound("clique", 1)
						request:FireServer("reforma", group[1], option.id)
					end
				end)
			end
		end
	end

	-- Agente: o app de contatos do implante (fixers e as pessoas deste servidor).
	local function bust(parent, fixerId: string, size: number)
		local view = new("ViewportFrame", parent, { Name = "Rosto", Size = UDim2.fromOffset(size, size), BackgroundColor3 = WELL, ZIndex = 24,
			Ambient = Color3.fromRGB(150, 140, 150), LightColor = Color3.fromRGB(255, 230, 225), LightDirection = Vector3.new(-0.6, -0.5, 1) })
		local source = folder:FindFirstChild("Fixers")
		local template = source and source:FindFirstChild(fixerId)
		if template then
			local world = new("WorldModel", view, {})
			local copy = template:Clone()
			copy.Parent = world
			local head = copy:FindFirstChild("Head")
			local cam = new("Camera", view, { FieldOfView = 24 })
			view.CurrentCamera = cam
			if head and head:IsA("BasePart") then
				cam.CFrame = CFrame.lookAt(head.Position + Vector3.new(0.8, -0.1, -4.4), head.Position + Vector3.new(0, -0.3, 0))
			end
		end
		return view
	end
	local function agentPanel()
		local order = 0
		if mission then
			order += 1
			section(order, "Trabalho atual")
			order += 1
			local current = row(order, 70, AMBER)
			text(current, "Titulo", mission.titulo or "", 18, AMBER, { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -150, 0, 24), ZIndex = 24, FontFace = display() })
			text(current, "Texto", string.format("%s, pago por %s", mission.objetivo or "", mission.nomeFixer or "um fixer"), 14, PAPER, {
				Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -150, 0, 30), ZIndex = 24, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
			button(current, "Abandonar", "Abandonar", "secundario", CORAL, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(116, 34), ZIndex = 24 }, function()
				request:FireServer("abandonar")
			end)
		end
		order += 1
		section(order, "Fixers")
		for _, fixer in fixerList do
			order += 1
			local line = row(order, 64)
			bust(line, fixer.id, 50).Position = UDim2.fromOffset(8, 7)
			text(line, "Nome", fixer.nome, 18, PAPER, { Position = UDim2.fromOffset(70, 8), Size = UDim2.new(1, -190, 0, 24), ZIndex = 24, FontFace = display() })
			text(line, "Cargo", fixer.titulo, 14, FOG, { Position = UDim2.fromOffset(70, 32), Size = UDim2.new(1, -190, 0, 20), ZIndex = 24 })
			button(line, "Ligar", "Ligar", "primario", TIDE, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(100, 36), ZIndex = 24 }, function()
				request:FireServer("ligar", fixer.id)
				setOpen(nil)
			end)
		end
		order += 1
		section(order, "Pessoas neste servidor")
		local anyone = false
		for _, other in Players:GetPlayers() do
			if other ~= player then
				anyone = true
				order += 1
				local line = row(order, 64)
				local face = new("ImageLabel", line, { Name = "Rosto", Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(50, 50), BackgroundColor3 = WELL, ZIndex = 24,
					Image = "", ScaleType = Enum.ScaleType.Crop })
				task.spawn(function()
					face.Image = headshot(other.UserId)
				end)
				text(line, "Nome", other.DisplayName, 18, PAPER, { Position = UDim2.fromOffset(70, 8), Size = UDim2.new(1, -190, 0, 24), ZIndex = 24, FontFace = display(),
					TextTruncate = Enum.TextTruncate.AtEnd })
				local busy = other:GetAttribute("CyberOutlawNaoPerturbe") == true
				text(line, "Usuario", if busy then "Não perturbe" else "@" .. other.Name, 14, if busy then CORAL else FOG, {
					Position = UDim2.fromOffset(70, 32), Size = UDim2.new(1, -190, 0, 20), ZIndex = 24, TextTruncate = Enum.TextTruncate.AtEnd })
				button(line, "Ligar", "Ligar", if busy then "secundario" else "primario", if busy then FOG else TIDE, {
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(100, 36), ZIndex = 24 }, function()
					request:FireServer("ligarJogador", other.UserId)
					setOpen(nil)
				end)
			end
		end
		if not anyone then
			order += 1
			text(content, "Vazio", "Ninguém mais no servidor agora. Quando alguém entrar, aparece aqui.", 15, FOG, { Size = UDim2.new(1, -8, 0, 26), LayoutOrder = order, ZIndex = 23 })
		end
		order += 1
		local quiet = player:GetAttribute("CyberOutlawNaoPerturbe") == true
		local footer = row(order, 54)
		text(footer, "Reputacao", string.format("Reputação de rua: %d", player:GetAttribute("CyberOutlawReputacao") or 0), 16, AMBER, {
			Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -220, 1, 0), ZIndex = 24, FontFace = display() })
		button(footer, "NaoPerturbe", if quiet then "Não perturbe: ligado" else "Não perturbe: desligado", "secundario", if quiet then CORAL else FOG, {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(196, 34), ZIndex = 24, TextSize = 15 }, function()
			request:FireServer("naoPerturbe", not quiet)
			task.delay(0.3, render)
		end)
		if SOUNDS.musica_calma or SOUNDS.musica_tensa then
			order += 1
			local musicOn = player:GetAttribute("CyberOutlawMusica") ~= false
			local musicRow = row(order, 54)
			text(musicRow, "Trilha", "Trilha da cidade", 16, PAPER, { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -220, 1, 0), ZIndex = 24, FontFace = display() })
			button(musicRow, "Musica", if musicOn then "Música: ligada" else "Música: desligada", "secundario", if musicOn then TIDE else FOG, {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(196, 34), ZIndex = 24, TextSize = 15 }, function()
				player:SetAttribute("CyberOutlawMusica", not musicOn)
				task.defer(render)
			end)
		end
	end

	render = function()
		if not panel then
			return
		end
		clearContent()
		new("UIListLayout", content, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		tabs.Visible = panel == "casa"
		content.Position = UDim2.fromOffset(14, if panel == "casa" then 100 else 60)
		content.Size = UDim2.new(1, -28, 1, if panel == "casa" then -110 else -70)
		if panel == "casa" then
			title.Text = if (house.unidade or 0) > 0 then string.format("Apartamento %02d", house.unidade) else "Colmeia lotado"
			subtitleLabel.Text = if (house.unidade or 0) > 0 then "Edifício Colmeia, Maré Baixa" else "Sem apartamento livre neste servidor"
			tabButton("loja", "Loja", 1)
			tabButton("meus", "Meus móveis", 2)
			tabButton("reforma", "Reforma", 3)
			button(tabs, "IrCasa", "Ir para casa", "secundario", TIDE, { Size = UDim2.fromOffset(if touch then 120 else 136, 32), LayoutOrder = 4, ZIndex = 23 }, function()
				request:FireServer("irCasa")
				setOpen(nil)
			end)
			if #house.sujeira > 0 then
				button(tabs, "Faxina", "Faxina " .. money(economy.faxina), "secundario", AMBER, { Size = UDim2.fromOffset(if touch then 128 else 146, 32), LayoutOrder = 5,
					ZIndex = 23, FontFace = MONEY, TextSize = 14 }, function()
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
			title.Text = "Agente"
			subtitleLabel.Text = "Contatos, trabalhos e chamadas"
			agentPanel()
		end
	end
	homeButton.Activated:Connect(function()
		setOpen(if panel == "casa" then nil else "casa")
	end)
	agentButton.Activated:Connect(function()
		setOpen(if panel == "agente" then nil else "agente")
	end)
	Players.PlayerAdded:Connect(function()
		if panel == "agente" then
			render()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if panel == "agente" then
			task.defer(render)
		end
	end)

	-- Posicionamento: fantasma na frente do personagem, dentro do apartamento, preso na grade de 0,5 --------------
	local placing = nil -- { id, uid, rot, ghost, glow, marker, x, z, valid }
	local placeBar = new("Frame", gui, {
		Name = "Posicionar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if touch then -60 else -110), Size = UDim2.fromOffset(340, 44),
		BackgroundTransparency = 1, Visible = false,
	})
	new("UIListLayout", placeBar, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center })
	local placeHint = text(gui, "DicaPosicionar", "Ande até o lugar. Z gira, F coloca, C cancela.", 15, PAPER, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if touch then -108 else -160), Size = UDim2.fromOffset(440, 22),
		TextXAlignment = Enum.TextXAlignment.Center, Visible = false, TextStrokeTransparency = 0.4, FontFace = body(Enum.FontWeight.SemiBold),
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
			sound("ui_negado", 1)
			return
		end
		if placing.uid then
			request:FireServer("mover", placing.uid, placing.x, placing.z, placing.rot)
		else
			request:FireServer("colocar", placing.id, placing.x, placing.z, placing.rot)
		end
		sound("compra", 0.6)
		stopPlacing()
	end
	local function rotatePlacing()
		if placing then
			placing.rot = (placing.rot + 1) % 4
			sound("ui_tick", 1)
		end
	end
	button(placeBar, "Girar", "Girar", "secundario", TIDE, { Size = UDim2.fromOffset(100, 42) }, rotatePlacing)
	button(placeBar, "Colocar", "Colocar", "primario", GOOD, { Size = UDim2.fromOffset(116, 42) }, confirmPlacing)
	button(placeBar, "Cancelar", "Cancelar", "secundario", CORAL, { Size = UDim2.fromOffset(104, 42) }, stopPlacing)
	startPlacing = function(id: string, uid: number?)
		local markerPart = unitMarker()
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not markerPart or not rootPart then
			toast("Você não tem apartamento neste servidor.", DANGER)
			return
		end
		local here = markerPart.CFrame:PointToObjectSpace(rootPart.Position)
		if math.abs(here.X) > markerPart.Size.X / 2 + 1 or math.abs(here.Z) > markerPart.Size.Z / 2 + 1 or math.abs(here.Y) > markerPart.Size.Y then
			toast("Vá para o seu apartamento (Ir para casa) para arrumar os móveis.", AMBER)
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
		local glowing = new("Highlight", ghost, { FillColor = TIDE, OutlineColor = TIDE, FillTransparency = 0.7, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop })
		ghost.Parent = workspace
		local rot = 0
		if uid then
			for _, item in house.moveis do
				if item.u == uid then
					rot = item.r
				end
			end
		end
		placing = { id = id, uid = uid, rot = rot, ghost = ghost, glow = glowing, marker = markerPart }
		setOpen(nil)
		placeBar.Visible = true
		placeHint.Visible = not touch
	end

	-- Interações (ProximityPrompt) no mesmo estilo: tecla na caixinha, ação, objeto e a barra de segurar ------------
	local ProximityPromptService = game:GetService("ProximityPromptService")
	local promptGui = new("ScreenGui", playerGui, { Name = "CyberOutlawInteracoes", ResetOnSpawn = false, DisplayOrder = 34 })
	local shownPrompts = {}
	local function keyName(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
		if inputType == Enum.ProximityPromptInputType.Gamepad then
			return (string.gsub(prompt.GamepadKeyCode.Name, "Button", ""))
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
		local face = new(if tapping then "TextButton" else "Frame", board2, { Name = "Placa", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
		if tapping then
			(face :: TextButton).Text = ""
			(face :: TextButton).AutoButtonColor = false
		end
		chamfer(face, 10, "tlbr", ABYSS, 0.12, CORAL, 0.35)
		local cap = new("Frame", face, { Name = "Tecla", Position = UDim2.fromOffset(10, 12), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, ZIndex = 2 })
		chamfer(cap, 6, "tlbr", WELL, 0, CORAL, 0)
		text(cap, "Letra", if tapping then "Toque" else keyName(prompt, inputType), if tapping then 11 else 18, CORAL, {
			FontFace = display(), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3,
		})
		text(face, "Acao", prompt.ActionText, 19, PAPER, {
			Position = UDim2.fromOffset(54, 6), Size = UDim2.new(1, -60, 0, 24), FontFace = display(), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2,
		})
		text(face, "Objeto", prompt.ObjectText, 14, FOG, { Position = UDim2.fromOffset(54, 30), Size = UDim2.new(1, -60, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2 })
		local track = new("Frame", face, { Name = "Segurar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -4), Size = UDim2.new(1, -20, 0, 3),
			BackgroundColor3 = CORAL, BackgroundTransparency = 0.75, BorderSizePixel = 0, Visible = prompt.HoldDuration > 0, ZIndex = 2 })
		local fill = new("Frame", track, { Name = "Valor", Size = UDim2.fromScale(0, 1), BackgroundColor3 = CORAL, BorderSizePixel = 0, ZIndex = 3 })
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
			sound("ui_confirmar", 0.8)
			task.delay(0.15, function()
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

	-- Avisos do servidor --------------------------------------------------------------------------------------------
	local LOOT = { ["Caixa eletrônico hackeado"] = true, ["Assalto ao camelô"] = true, ["Máquina arrombada"] = true, ["Carteira batida"] = true }
	notice.OnClientEvent:Connect(function(kind, a, b, c)
		if kind == "dinheiro" and type(a) == "number" then
			if a > 0 then
				sound(if LOOT[b] then "assalto" else "dinheiro", 1)
			end
			toast(string.format("%s%s%s", if a > 0 then "+" else "", money(a), if type(b) == "string" then "  " .. b else ""), if a > 0 then GOOD else DANGER)
		elseif kind == "msg" and type(a) == "string" then
			toast(a, TIDE)
		elseif kind == "procurado" and type(a) == "number" then
			sound("alarme", 1)
			task.delay(0.7, sound, "radio_policia", 1)
			toast(string.format("Procurado: %s", string.rep("★", a)), DANGER)
		elseif kind == "policia" and type(a) == "string" then
			local arriving = { helicoptero = "Helicóptero da PMMB no ar.", swat = "AV da PMMB trazendo a SWAT.", tanque = "Tanque! Saia do círculo vermelho." }
			local names = { helicoptero = "Helicóptero", av = "AV", tanque = "Tanque" }
			if a == "abatido" then
				toast(string.format("%s da PMMB abatido.", names[b] or "Viatura"), AMBER)
			elseif arriving[a] then
				sound("radio_policia", 1)
				toast(arriving[a], DANGER)
			end
		elseif kind == "chamada" and type(a) == "table" then
			incoming(a, b == true)
		elseif kind == "perdida" and type(a) == "string" then
			if call and call.kind == "fixer" and call.state == "tocando" then
				hangUp(nil)
			end
			local fixer = fixers[a]
			toast("Chamada perdida de " .. (if fixer then fixer.nome else "um fixer") .. ". Ligue pelo Agente.", AMBER)
		elseif kind == "fixer" and type(a) == "string" and type(b) == "string" then
			fixerMessage(a, b, c == true)
		elseif kind == "missao" and type(a) == "table" then
			toast("Trabalho aceito: " .. tostring(a.titulo), AMBER)
		elseif kind == "comprado" and type(a) == "string" then
			local def = byId[a]
			if def then
				sound("compra", 1)
				toast(def.nome .. " comprado. Está em Meus móveis.", AMBER)
			end
		elseif kind == "casa" and type(a) == "table" then
			house = a
			house.moveis = house.moveis or {}
			house.guardados = house.guardados or {}
			house.sujeira = house.sujeira or {}
			if panel then
				render()
			end
		elseif kind == "chamadaJogador" and type(a) == "table" then
			playerCard(a, "tocando")
			callStatus.Text = "Chamada recebida"
			callStatus.TextColor3 = CORAL
			action("Atender", "primario", TIDE, "T", 1, answer)
			action("Recusar", "secundario", CORAL, "Y", 2, decline)
			ring()
		elseif kind == "chamandoJogador" and type(a) == "table" then
			playerCard(a, "chamando")
			callStatus.Text = "Chamando…"
			callStatus.TextColor3 = TIDE
			action("Cancelar", "secundario", CORAL, "Y", 1, decline)
		elseif kind == "chamadaAtiva" and type(a) == "table" then
			if not call or call.id ~= a.id then
				playerCard(a, "ativa")
			end
			stopRing()
			sound("chamada_atender", 1)
			call.state = "ativa"
			call.at = os.clock()
			callStatus.TextColor3 = TIDE
			activeActions()
		elseif kind == "chamadaFala" and type(a) == "table" and call and call.id == a.id then
			say(if a.minha then "Você" else a.de, if a.minha then "#FFC440" else "#5EF6FF", { a.texto }, nil)
		elseif kind == "chamadaLocal" and type(a) == "table" and typeof(a.pos) == "Vector3" then
			friendMarker.Position = a.pos + Vector3.new(0, 7, 0)
			friendMarker.Parent = workspace
			friendUntil = os.clock() + 60
			sound("notificacao", 1)
			toast(a.de .. " mandou a localização (marcador ciano).", TIDE)
		elseif kind == "chamadaConvite" and type(a) == "table" and call and call.id == a.id then
			sound("notificacao", 1)
			toast(a.de .. " te convidou para o apartamento " .. string.format("%02d", a.unidade or 0) .. ".", AMBER)
			action("Visitar", "primario", AMBER, nil, 0, function()
				request:FireServer("visitar", call and call.id)
			end)
		elseif kind == "chamadaFim" and type(a) == "table" then
			if call and call.kind == "jogador" and call.id == a.id then
				hangUp("chamada_fim")
				if type(a.motivo) == "string" then
					toast(a.motivo, FOG)
				end
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

	-- Teclas: H casa, J agente, T atender ou aceitar, Y recusar ou desligar; no posicionamento Z gira, F coloca, C cancela.
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

	-- Viaturas da PMMB, só neste cliente: rotores girando, giroflex alternando, jatos tremendo, holofote do
	-- helicóptero no procurado, torre do tanque seguindo a mira, laser e círculo vermelho antes do canhão (dá
	-- tempo de sair), e a barra de blindagem de quem está levando tiro.
	do
		local localFolder = new("Folder", workspace, { Name = "CyberOutlawViaturasLocal" })
		local tracked = {}
		local sight = RaycastParams.new()
		sight.FilterType = Enum.RaycastFilterType.Exclude
		local LAMP = Color3.fromRGB(255, 244, 214)
		local function marker(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): BasePart
			return new("Part", localFolder, {
				Name = name, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Size = size, Color = color,
				Material = Enum.Material.Neon, Transparency = 1, Shape = shape or Enum.PartType.Block,
			})
		end
		local function prepare(model: Model)
			local entry = { kind = model:GetAttribute("CyberOutlawViatura"), motors = {}, sirens = {}, jets = {}, parts = {} }
			for _, item in model:GetDescendants() do
				if item:IsA("Motor6D") and item.Name == "Giro" then
					table.insert(entry.motors, { motor = item, group = item:GetAttribute("Grupo"), angle = 0 })
				elseif item:IsA("BasePart") and item:GetAttribute("Giroflex") then
					table.insert(entry.sirens, { part = item, side = item:GetAttribute("Giroflex"), light = item:FindFirstChildWhichIsA("Light") })
				elseif item:IsA("BasePart") and item:GetAttribute("Jato") then
					table.insert(entry.jets, item)
				end
			end
			if entry.kind == "helicoptero" then
				entry.lamp = model:FindFirstChild("Holofote")
				entry.source = marker("Holofote", Vector3.new(0.4, 0.4, 0.4), LAMP)
				entry.spot = marker("Fim do feixe", Vector3.new(0.4, 0.4, 0.4), LAMP)
				entry.light = new("SpotLight", entry.source, { Face = Enum.NormalId.Front, Angle = 22, Range = 130, Brightness = 7, Color = LAMP, Shadows = true })
				entry.shaft = new("Beam", entry.source, {
					Attachment0 = new("Attachment", entry.source, {}), Attachment1 = new("Attachment", entry.spot, {}), Color = ColorSequence.new(LAMP),
					Width0 = 1.2, Width1 = 15, FaceCamera = true, LightEmission = 1, LightInfluence = 0, Segments = 1,
					Transparency = NumberSequence.new(0.8, 0.93),
				})
				table.insert(entry.parts, entry.source)
				table.insert(entry.parts, entry.spot)
			elseif entry.kind == "tanque" then
				local gun = model:FindFirstChild("CyberOutlawArma")
				local muzzle = gun and gun:IsA("Model") and gun.PrimaryPart and gun.PrimaryPart:FindFirstChild("Cano")
				if muzzle and muzzle:IsA("Attachment") then
					entry.dot = marker("Mira do canhão", Vector3.new(0.5, 0.5, 0.5), DANGER, Enum.PartType.Ball)
					entry.ring = marker("Área do tiro", Vector3.new(0.16, 30, 30), DANGER, Enum.PartType.Cylinder)
					entry.laser = new("Beam", entry.dot, {
						Attachment0 = muzzle, Attachment1 = new("Attachment", entry.dot, {}), Color = ColorSequence.new(DANGER), Width0 = 0.18, Width1 = 0.18,
						FaceCamera = true, LightEmission = 1, LightInfluence = 0, Segments = 1, Enabled = false,
					})
					table.insert(entry.parts, entry.dot)
					table.insert(entry.parts, entry.ring)
				end
			end
			entry.humanoid = model:FindFirstChildOfClass("Humanoid")
			entry.board = new("BillboardGui", localFolder, {
				Name = "Blindagem", Adornee = model.PrimaryPart, Size = UDim2.fromOffset(110, 8), AlwaysOnTop = true, Enabled = false, MaxDistance = 240,
				StudsOffsetWorldSpace = Vector3.new(0, if entry.kind == "tanque" then 7.5 else 6.5, 0),
			})
			local back = new("Frame", entry.board, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WELL, BackgroundTransparency = 0.15, BorderSizePixel = 0 })
			entry.fill = new("Frame", back, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = DANGER, BorderSizePixel = 0 })
			tracked[model] = entry
		end
		RunService.RenderStepped:Connect(function(dt)
			local police = workspace:FindFirstChild("CyberOutlawPolicia")
			if police then
				for _, model in police:GetChildren() do
					if model:IsA("Model") and not tracked[model] and model.PrimaryPart then
						prepare(model)
					end
				end
			end
			local now, serverNow = os.clock(), workspace:GetServerTimeNow()
			local phase = math.floor(now * 5) % 2 + 1
			for model, entry in tracked do
				if model.Parent == nil then
					for _, item in entry.parts do
						item:Destroy()
					end
					entry.board:Destroy()
					tracked[model] = nil
					continue
				end
				local dead = model:GetAttribute("Destruido") == true
				for _, joint in entry.motors do
					if joint.group == "torre" then
						local goal = model:GetAttribute("MiraYaw") or 0
						local delta = (goal - joint.angle + math.pi) % (2 * math.pi) - math.pi
						joint.angle += math.clamp(delta, -dt * 1.8, dt * 1.8)
					else
						joint.angle += dt * (if joint.group == "cauda" then 46 else 30) * (if dead then 0.2 else 1)
					end
					joint.motor.Transform = CFrame.Angles(0, joint.angle, 0)
				end
				for _, siren in entry.sirens do
					local on = not dead and siren.side == phase
					siren.part.Transparency = if on then 0 else 0.78
					if siren.light then
						siren.light.Enabled = on
					end
				end
				for _, jet in entry.jets do
					jet.Transparency = if dead then 1 else 0.05 + 0.35 * math.abs(math.noise(now * 7, jet.Position.X * 0.1))
				end
				if entry.lamp and entry.source then
					local target = Players:GetPlayerByUserId(model:GetAttribute("Alvo") or 0)
					local character = target and target.Character
					local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
					local from = entry.lamp.Position
					local on = not dead and targetRoot ~= nil and targetRoot:IsA("BasePart") and (targetRoot.Position - from).Magnitude < 320
					if on and targetRoot and targetRoot:IsA("BasePart") then
						-- Balança um pouco, como quem segura o holofote lá de cima.
						local sway = Vector3.new(math.noise(now * 0.5, 1.3) * 5, 0, math.noise(now * 0.5, 7.7) * 5)
						local aim = targetRoot.Position - Vector3.new(0, 2.6, 0) + sway
						sight.FilterDescendantsInstances = { police :: Instance, localFolder }
						local hit = workspace:Raycast(from, (aim - from).Unit * 420, sight)
						local finish = if hit then hit.Position else aim
						entry.source.CFrame = CFrame.lookAt(from, finish)
						entry.spot.Position = finish
					end
					entry.shaft.Enabled = on
					entry.light.Enabled = on
				end
				if entry.laser then
					local charge = model:GetAttribute("CargaAte") or 0
					local point = model:GetAttribute("MiraPonto")
					local active = not dead and charge > serverNow and typeof(point) == "Vector3"
					entry.laser.Enabled = active
					if active and typeof(point) == "Vector3" then
						if entry.charge ~= charge then
							entry.charge = charge
							sight.FilterDescendantsInstances = { police :: Instance, localFolder }
							local ground = workspace:Raycast(point + Vector3.new(0, 3, 0), Vector3.new(0, -30, 0), sight)
							entry.ground = if ground then ground.Position else point
						end
						local left = math.clamp((charge - serverNow) / 1.6, 0, 1)
						entry.dot.Position = point
						entry.dot.Transparency = 0.1
						entry.ring.CFrame = CFrame.new(entry.ground + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
						entry.ring.Transparency = 0.5 + 0.35 * (0.5 + 0.5 * math.sin(now * (10 + (1 - left) * 30)))
						entry.laser.Width0 = 0.14 + (1 - left) * 0.3
						entry.laser.Width1 = entry.laser.Width0
					else
						entry.dot.Transparency = 1
						entry.ring.Transparency = 1
					end
				end
				local humanoid = entry.humanoid
				if humanoid and humanoid.MaxHealth > 0 then
					local fraction = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
					entry.board.Enabled = not dead and fraction < 0.999
					entry.fill.Size = UDim2.fromScale(fraction, 1)
				end
			end
		end)
	end

	-- Trilha da cidade: Under the Steel Canopy baixinho quando está tudo de boa; Tiro Rápido quando tem estrela,
	-- tiroteio por perto ou alguém te machucando. Troca com fade, só volta para a calma depois de 15 s de paz,
	-- abaixa nas holochamadas e, no Sandevistan, fica lenta e abafada. As duas chegam pelo comando midia; o botão
	-- "Música" no painel do Agente desliga.
	do
		local function track(name: string, id): Sound?
			if type(id) ~= "number" or id <= 0 then
				return nil
			end
			return new("Sound", SoundService, { Name = name, SoundId = string.format("rbxassetid://%.0f", id), Looped = true, Volume = 0 })
		end
		local tracks = { calma = track("MusicaCalma", SOUNDS.musica_calma), tensa = track("MusicaTensa", SOUNDS.musica_tensa) }
		if tracks.calma or tracks.tensa then
			local group = new("SoundGroup", SoundService, { Name = "CyberOutlawMusica", Volume = 1 })
			local eq = new("EqualizerSoundEffect", group, { HighGain = 0, MidGain = 0, LowGain = 0 })
			local LEVEL = { calma = 0.3, tensa = 0.5 }
			local started, pausedAt = {}, {}
			for _, item in tracks do
				item.SoundGroup = group
			end
			local mood, calmSince, lastHurt, lastHealth = "calma", 0, -100, nil :: number?
			local function bind(character: Model)
				local humanoid = character:WaitForChild("Humanoid", 10)
				if humanoid and humanoid:IsA("Humanoid") then
					lastHealth = humanoid.Health
					humanoid.HealthChanged:Connect(function(health)
						if lastHealth and health < lastHealth - 0.5 then
							lastHurt = os.clock()
						end
						lastHealth = health
					end)
				end
			end
			player.CharacterAdded:Connect(bind)
			if player.Character then
				task.spawn(bind, player.Character)
			end
			local function danger(now: number): boolean
				if (player:GetAttribute("CyberOutlawProcurado") or 0) > 0 or now - lastHurt < 12 then
					return true
				end
				local character = player.Character
				local shot = character and character:GetAttribute("CyberOutlawUltimoTiro")
				if type(shot) == "number" and workspace:GetServerTimeNow() - shot < 10 then
					return true
				end
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				local npcs = workspace:FindFirstChild("CyberOutlawNPCs")
				if rootPart and rootPart:IsA("BasePart") and npcs then
					for _, model in npcs:GetChildren() do
						if model:GetAttribute("CyberOutlawMirando") == true then
							local other = model:FindFirstChild("HumanoidRootPart")
							if other and other:IsA("BasePart") and (other.Position - rootPart.Position).Magnitude < 90 then
								return true
							end
						end
					end
				end
				return false
			end
			local checkAt = 0
			RunService.Heartbeat:Connect(function(dt)
				if player:GetAttribute("CyberOutlawMenuStarted") ~= true then
					return
				end
				local now = os.clock()
				if now >= checkAt then
					checkAt = now + 0.5
					if danger(now) then
						calmSince = now
						if mood ~= "tensa" and tracks.tensa then
							mood = "tensa"
							if now - (pausedAt.tensa or now) > 30 then
								tracks.tensa.TimePosition = 0
							end
						end
					elseif mood == "tensa" and now - calmSince > 15 then
						mood = "calma"
					end
				end
				local on = player:GetAttribute("CyberOutlawMusica") ~= false
				local duck = if call ~= nil then 0.35 else 1
				local character = player.Character
				local slowed = character ~= nil and (character:GetAttribute("CyberOutlawSandevistanAte") or 0) > workspace:GetServerTimeNow()
				local blend = math.min(1, dt * 3)
				for name, item in tracks do
					local goal = if on and name == mood then LEVEL[name] * duck else 0
					local step = dt * (if goal > item.Volume then 0.22 else 0.32)
					item.Volume = if goal > item.Volume then math.min(goal, item.Volume + step) else math.max(goal, item.Volume - step)
					if item.Volume > 0.001 and not item.IsPlaying then
						if started[name] then
							item:Resume()
						else
							started[name] = true
							item:Play()
						end
					elseif item.Volume <= 0.001 and item.IsPlaying then
						item:Pause()
						pausedAt[name] = now
					end
					item.PlaybackSpeed += ((if slowed then 0.8 else 1) - item.PlaybackSpeed) * blend
				end
				eq.HighGain += ((if slowed then -24 else 0) - eq.HighGain) * blend
				eq.MidGain += ((if slowed then -8 else 0) - eq.MidGain) * blend
			end)
		end
	end

	-- Por quadro: estrelas, objetivo, marcadores, fantasma, varredura do retrato e barras de voz.
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
		local admin = playerGui:FindFirstChild("CyberOutlawAdminBotao")
		local shift = if admin and admin:IsA("ScreenGui") and admin.Enabled then 56 else 8
		chip.Position = UDim2.new(1, -shift, 0.5, 0)
		stars.Position = UDim2.new(1, -shift - 140, 0.5, 0)
		local level = math.clamp(player:GetAttribute("CyberOutlawProcurado") or 0, 0, #starLabels)
		stars.Visible = level > 0
		if level > shownLevel then
			for index = shownLevel + 1, level do
				starLabels[index].scale.Scale = 1.9
				tween(starLabels[index].scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
		shownLevel = level
		if level > 0 then
			local searching = player:GetAttribute("CyberOutlawVisto") ~= true and os.clock() % 0.7 < 0.35
			for index, entry in starLabels do
				local lit = index <= level
				entry.label.TextColor3 = if not lit then FOG elseif searching then PAPER else DANGER
				entry.label.TextTransparency = if lit then 0 else 0.62
			end
		end
		if touch and objective.Visible then
			local hudGui = playerGui:FindFirstChild("CyberOutlawHUD")
			local anchor = hudGui and hudGui:FindFirstChild("MinimapAncora")
			if anchor and anchor:IsA("GuiObject") then
				local origin = gui.AbsolutePosition
				objective.Position = UDim2.fromOffset(anchor.AbsolutePosition.X - origin.X, anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y - origin.Y + 28)
			end
		end
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if mission and rootPart and rootPart:IsA("BasePart") then
			local distance = if type(mission.alvo) == "table" then (Vector3.new(mission.alvo[1], mission.alvo[2], mission.alvo[3]) - rootPart.Position).Magnitude else 0
			local left = (mission.prazo or 0) - workspace:GetServerTimeNow()
			local extra = if mission.restantes then string.format(", faltam %d", mission.restantes) else ""
			objectiveHead.Text = "Trabalho de " .. (mission.nomeFixer or "um fixer")
			objectiveClock.Text = clock(left)
			objectiveClock.TextColor3 = if left < 30 then DANGER else AMBER
			objectiveText.Text = string.format("%s%s (%d m)", mission.objetivo or "", extra, math.floor(distance / 3.6))
			distanceText.Text = string.format("%d m", math.floor(distance / 3.6))
		end
		if friendMarker.Parent then
			if os.clock() > friendUntil then
				friendMarker.Parent = nil
			elseif rootPart and rootPart:IsA("BasePart") then
				friendText.Text = string.format("%d m", math.floor((friendMarker.Position - rootPart.Position).Magnitude / 3.6))
			end
		end
		if holo.Visible then
			local now = os.clock()
			sweep.Position = UDim2.fromScale(0, (now * 0.6) % 1)
			tint.BackgroundTransparency = if math.random() < 0.04 then 0.75 else 0.9
			local talking = call ~= nil and call.speaking == true
			for index, bar in bars do
				local goal = if talking then 0.25 + 0.75 * math.abs(math.noise(now * 9, index * 0.37)) * 1.6 else 0.15
				bar.Size = UDim2.new(0, 3, math.clamp(goal, 0.12, 1), 0)
			end
			if call and call.kind == "jogador" and call.state == "ativa" then
				callStatus.Text = "Em chamada  " .. clock(now - (call.at or now))
			elseif call and call.kind == "fixer" and (call.state == "conversa" or call.state == "recado") and call.at then
				callerRole.TextColor3 = FOG
			end
			if call and call.state == "tocando" then
				callStatus.TextTransparency = if now % 0.9 < 0.45 then 0 else 0.4
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
			placing.glow.FillColor = if placing.valid then TIDE else DANGER
			placing.glow.OutlineColor = placing.glow.FillColor
			placing.ghost:PivotTo(markerPart.CFrame * CFrame.new(x, -markerPart.Size.Y / 2 + 0.1, z) * CFrame.Angles(0, placing.rot * math.pi / 2, 0))
		end
	end)
	player.CharacterRemoving:Connect(stopPlacing)
end

if typeof(game) == "Instance" and game:GetService("RunService"):IsClient() then
	task.spawn(start)
end

return M
