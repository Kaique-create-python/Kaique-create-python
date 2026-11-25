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
		new("UICorner", item, { CornerRadius = UDim.new(0, radius) })
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
		corner(item, 8)
		outline(item, NEON, 0.35)
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
		Name = "Carteira", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(150, 32),
		BackgroundColor3 = PANEL, BackgroundTransparency = 0.2, BorderSizePixel = 0,
	})
	corner(chip, 16)
	outline(chip, GOLD, 0.3)
	local wallet = text(chip, "Valor", money(0), 16, GOLD, { TextXAlignment = Enum.TextXAlignment.Center })
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
		corner(item, 8)
		outline(item, NEON, 0.12)
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
	local objective = plate(gui, "Objetivo", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, if touch then 64 else 100), Size = UDim2.fromOffset(if touch then 330 else 440, 30),
		Visible = false,
	})
	local objectiveText = text(objective, "Texto", "", if touch then 13 else 15, TEXT, {
		Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
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
	-- Pesquisa (Cyberpunk 2077): o "celular" é o implante Agente; a chamada aparece no canto da visão com o rosto
	-- do contato em vídeo holográfico, nome e "chamada recebida"; atende com uma tecla e a conversa vira legenda.
	local holo = plate(gui, "Holochamada", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, if touch then 112 else 60), Size = UDim2.fromOffset(310, 112), Visible = false,
		BackgroundTransparency = 0.25,
	})
	local holoStroke = holo:FindFirstChildOfClass("UIStroke")
	local portrait = new("ViewportFrame", holo, {
		Name = "Rosto", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(96, 96), BackgroundColor3 = Color3.fromRGB(4, 20, 30),
		BackgroundTransparency = 0.2, Ambient = Color3.fromRGB(120, 255, 240), LightColor = Color3.fromRGB(90, 230, 255), ImageColor3 = Color3.fromRGB(150, 255, 240),
	})
	corner(portrait, 6)
	for line = 0, 23 do
		new("Frame", portrait, {
			Name = "Linha", Position = UDim2.fromOffset(0, line * 4), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 3,
		})
	end
	local portraitCamera = new("Camera", portrait, { FieldOfView = 26 })
	portrait.CurrentCamera = portraitCamera
	local callerName = text(holo, "Nome", "", 17, TEXT, { Position = UDim2.fromOffset(114, 8), Size = UDim2.new(1, -122, 0, 22) })
	local callerRole = text(holo, "Cargo", "", 12, SUB, { Position = UDim2.fromOffset(114, 28), Size = UDim2.new(1, -122, 0, 16), FontFace = font(Enum.FontWeight.Medium) })
	local callStatus = text(holo, "Status", "", 12, NEON, { Position = UDim2.fromOffset(114, 46), Size = UDim2.new(1, -122, 0, 16) })
	local actions = new("Frame", holo, { Name = "Botoes", Position = UDim2.fromOffset(114, 70), Size = UDim2.new(1, -122, 0, 34), BackgroundTransparency = 1 })
	new("UIListLayout", actions, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local subtitle = plate(gui, "Legenda", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if touch then -64 else -118), Size = UDim2.fromOffset(if touch then 380 else 560, 54),
		Visible = false, BackgroundTransparency = 0.35,
	})
	local subtitleText = text(subtitle, "Texto", "", if touch then 14 else 17, TEXT, {
		Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 1, -8), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = font(Enum.FontWeight.SemiBold),
	})
	local call = nil -- { offer, state = "tocando"|"conversa"|"oferta"|"recado", at }
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
			portraitCamera.CFrame = CFrame.lookAt(at + Vector3.new(0.6, -0.1, -4.8), at + Vector3.new(0, -0.35, 0))
		end
		local fixer = fixers[fixerId]
		local tone = if fixer then Color3.fromRGB(fixer.cor[1], fixer.cor[2], fixer.cor[3]) else NEON
		holoStroke.Color = tone
		callerName.TextColor3 = TEXT
		callStatus.TextColor3 = tone
	end
	local function hangUp()
		call = nil
		holo.Visible = false
		subtitle.Visible = false
		clearActions()
	end
	local function typeLines(lines, done)
		local token = {}
		call.token = token
		subtitle.Visible = true
		task.spawn(function()
			for _, line in lines do
				for count = 1, #line, 2 do
					if not call or call.token ~= token then
						return
					end
					subtitleText.Text = string.sub(line, 1, count)
					task.wait(0.03)
				end
				subtitleText.Text = line
				task.wait(math.clamp(#line * 0.035, 1.6, 3.2))
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
		callStatus.Text = string.format("%s · %s · %s", string.upper(offer.titulo), money(offer.valor), clock(offer.prazo))
		subtitleText.Text = offer.objetivo
		clearActions()
		button(actions, "Aceitar", if touch then "ACEITAR" else "ACEITAR (T)", GREEN, { Size = UDim2.fromOffset(88, 32), LayoutOrder = 1 }, function()
			answer()
		end)
		button(actions, "Recusar", if touch then "RECUSAR" else "RECUSAR (Y)", RED, { Size = UDim2.fromOffset(88, 32), LayoutOrder = 2 }, function()
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
		call = { offer = offer, state = "tocando" }
		holo.Visible = true
		showPortrait(offer.fixer)
		callerName.Text = offer.nome
		callerRole.Text = offer.cargo .. " · HOLOCHAMADA"
		clearActions()
		if outgoing then
			call.state = "tocando"
			answer()
			return
		end
		callStatus.Text = "CHAMADA RECEBIDA"
		button(actions, "Atender", if touch then "ATENDER" else "ATENDER (T)", GREEN, { Size = UDim2.fromOffset(88, 32), LayoutOrder = 1 }, answer)
		button(actions, "Recusar", if touch then "RECUSAR" else "RECUSAR (Y)", RED, { Size = UDim2.fromOffset(88, 32), LayoutOrder = 2 }, decline)
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
		call = { state = "recado" }
		holo.Visible = true
		showPortrait(fixerId)
		callerName.Text = if fixer then fixer.nome else "Fixer"
		callerRole.Text = (if fixer then fixer.titulo else "") .. " · MENSAGEM"
		callStatus.Text = if good then "TRABALHO CONCLUÍDO" else "TRABALHO PERDIDO"
		callStatus.TextColor3 = if good then GREEN else RED
		clearActions()
		typeLines({ message }, hangUp)
	end

	-- Painéis (Casa e Agente) -----------------------------------------------------------------------------
	local dim = new("Frame", gui, { Name = "Fundo", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false, ZIndex = 20 })
	local card = plate(gui, "Painel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(if touch then 0.78 else 0.56, if touch then 0.86 else 0.74),
		Visible = false, ZIndex = 21, BackgroundTransparency = 0.06,
	})
	new("UISizeConstraint", card, { MaxSize = Vector2.new(820, 620), MinSize = Vector2.new(320, 240) })
	local title = text(card, "Titulo", "", 20, NEON, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -60, 0, 28), ZIndex = 22, FontFace = font(Enum.FontWeight.ExtraBold) })
	local close
	local tabs = new("Frame", card, { Name = "Abas", Position = UDim2.fromOffset(12, 42), Size = UDim2.new(1, -24, 0, 32), BackgroundTransparency = 1, ZIndex = 22 })
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
	close = button(card, "Fechar", "✕", PINK, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(40, 32), ZIndex = 23 }, function()
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
			Name = "Linha", Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = Color3.fromRGB(22, 20, 44), BackgroundTransparency = 0.2,
			LayoutOrder = order, ZIndex = 23, BorderSizePixel = 0,
		})
		corner(item, 6)
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
		gui.Enabled, top.Enabled = started, started
		local level = player:GetAttribute("CyberOutlawProcurado") or 0
		stars.Visible = level > 0
		if level > 0 then
			local seen = player:GetAttribute("CyberOutlawVisto") == true
			stars.Text = string.rep("★", level) .. string.rep("☆", 5 - level)
			stars.TextTransparency = if seen and os.clock() % 0.5 < 0.25 then 0.6 else 0
		end
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if mission and rootPart and rootPart:IsA("BasePart") then
			local distance = if type(mission.alvo) == "table" then (Vector3.new(mission.alvo[1], mission.alvo[2], mission.alvo[3]) - rootPart.Position).Magnitude else 0
			local left = (mission.prazo or 0) - workspace:GetServerTimeNow()
			local extra = if mission.restantes then string.format(" · faltam %d", mission.restantes) else ""
			objectiveText.Text = string.format("◆ %s%s · %d m · %s", mission.objetivo or "", extra, math.floor(distance / 3.6), clock(left))
			objectiveText.TextColor3 = if left < 30 then RED else TEXT
			distanceText.Text = string.format("%d m", math.floor(distance / 3.6))
		end
		if holo.Visible then
			portrait.ImageTransparency = if math.random() < 0.04 then 0.5 else 0.08
			portrait.Position = UDim2.fromOffset(8 + (if math.random() < 0.03 then math.random(-2, 2) else 0), 8)
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
