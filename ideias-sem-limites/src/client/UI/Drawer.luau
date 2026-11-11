--!strict
-- Painel lateral recolhível: um "dock" de botões redondos à esquerda (acima do
-- analógico) abre abas com sugestões por categoria, histórico, favoritos,
-- progresso, loja de cosméticos e ajustes. Fechado por padrão: a tela fica limpa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("IdeiasShared")
local Catalog = require(Shared.Catalog)
local Progression = require(Shared.Catalog.Progression)
local Planner = require(Shared.Planner)
local Theme = require(script.Parent.Theme)
local Hud = require(script.Parent.Hud)
local Settings = require(script.Parent.Parent.Settings)

local Drawer = {}

local C = Theme.Colors
local new = Theme.new

Drawer.sendAction = nil :: ((string, any) -> ())?
Drawer.profile = nil :: any

local panel: Frame
local content: ScrollingFrame
local title: TextLabel
local current: string? = nil
local selectedCategory = "creature"
local dockLabels: { [string]: TextLabel } = {}

-- nome do azulejo da aba aberta fica dourado
local function markDock()
	for id, lbl in dockLabels do
		lbl.TextColor3 = if id == current then Theme.Colors.gold else Theme.Colors.text
	end
end

local COMBOS = {
	"dragão de gelo gigante",
	"herói contra demônio",
	"chuva de pizzas",
	"dragão protegendo castelo",
	"robô dinossauro",
	"tornado de tubarões",
	"100 zumbis",
	"cavaleiro montando dragão",
	"tornado elétrico gigante",
	"meteoro congelante",
	"casa de ouro",
	"capivara de estimação",
	"zumbi no carro",
	"fogo e gelo",
}

local function clear()
	for _, ch in content:GetChildren() do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
			ch:Destroy()
		end
	end
end

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function section(text: string)
	Theme.label({ Text = text, TextSize = 14, TextColor3 = C.muted, FontFace = Theme.FontBold, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = nextOrder(), Parent = content })
end

local function chipGrid(items: { { text: string, fill: string, color: Color3? } })
	local grid = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
		Parent = content,
	}, {
		new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 34), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, it in items do
		local b = Theme.button({ Text = it.text, TextSize = 14, TextWrapped = true, BackgroundColor3 = it.color or C.bg2, LayoutOrder = i, Parent = grid })
		b.Activated:Connect(function()
			Hud.setText(it.fill)
			Hud.sound("Click")
			Theme.pop(b)
		end)
	end
end

local function row(text: string, actions: { { label: string, fn: () -> () } }, onTap: (() -> ())?)
	local r = new("Frame", {
		BackgroundColor3 = C.bg2,
		Size = UDim2.new(1, 0, 0, 38),
		LayoutOrder = nextOrder(),
		Parent = content,
	}, { Theme.corner(10) })
	local tap = new("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.new(1, -40 * #actions, 1, 0),
		Parent = r,
	})
	Theme.label({ Text = text, TextSize = 15, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -10, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = tap })
	if onTap then
		tap.Activated:Connect(onTap)
	end
	for i, a in actions do
		local b = Theme.button({ Text = a.label, TextSize = 16, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4 - (i - 1) * 40, 0.5, 0), Size = UDim2.fromOffset(34, 30), BackgroundColor3 = C.panel, Parent = r })
		b.Activated:Connect(a.fn)
	end
end

local function progressBar(label: string, value: number, max: number, color: Color3)
	local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = nextOrder(), Parent = content })
	Theme.label({ Text = string.format("%s  %d/%d", label, value, max), TextSize = 14, Size = UDim2.new(1, 0, 0, 20), FontFace = Theme.FontBold, Parent = f })
	local back = new("Frame", { BackgroundColor3 = C.bg2, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 10), Parent = f }, { Theme.corner(5) })
	new("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(math.clamp(value / math.max(max, 1), 0, 1), 1), Parent = back }, { Theme.corner(5) })
end

local function choice(label: string, key: string, options: { { any } })
	section(label)
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = nextOrder(), Parent = content }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})
	for _, opt in options do
		local active = (Settings.values :: any)[key] == opt[2]
		local b = Theme.button({ Text = opt[1], TextSize = 14, Size = UDim2.new(1 / #options, -6, 1, 0), BackgroundColor3 = if active then C.accent2 else C.bg2, Parent = holder })
		b.Activated:Connect(function()
			Settings.set(key, opt[2])
			Drawer.show(current)
		end)
	end
end

-- abas -------------------------------------------------------------------------
local TABS = {}

TABS.ideias = function()
	section("Categorias")
	local cats = {}
	for id, info in Catalog.CategoryInfo do
		table.insert(cats, { id = id, info = info })
	end
	table.sort(cats, function(a, b)
		return a.info.order < b.info.order
	end)
	local strip = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 3,
		LayoutOrder = nextOrder(),
		Parent = content,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	for i, c in cats do
		local b = Theme.button({ Text = c.info.icon .. " " .. c.info.label, TextSize = 14, Size = UDim2.fromOffset(130, 34), LayoutOrder = i, BackgroundColor3 = if c.id == selectedCategory then C.accent2 else C.bg2, Parent = strip })
		local ic = Theme.icon(c.id, 26, b)
		if ic then
			ic.AnchorPoint = Vector2.new(0, 0.5)
			ic.Position = UDim2.new(0, 6, 0.5, 0)
			b.Text = "     " .. c.info.label
		end
		b.Activated:Connect(function()
			selectedCategory = c.id
			Drawer.show("ideias")
		end)
	end
	local items = {}
	for _, def in Catalog.Concepts do
		if def.category == selectedCategory then
			table.insert(items, { text = def.label, fill = def.label })
		end
	end
	table.sort(items, function(a, b)
		return a.text < b.text
	end)
	section(string.format("%d ideias • toque para escrever", #items))
	chipGrid(items)
	section("Combinações (experimente!)")
	local combos = {}
	for _, cmb in COMBOS do
		table.insert(combos, { text = cmb, fill = cmb, color = Color3.fromRGB(40, 36, 70) })
	end
	chipGrid(combos)
	section("Dica: qualquer palavra funciona — palavras desconhecidas viram surpresas 🎲")
end

TABS.historico = function()
	if #Hud.history == 0 then
		section("Suas ideias aparecem aqui.")
		return
	end
	for _, text in Hud.history do
		row(text, {
			{
				label = "⭐",
				fn = function()
					local ok, plan = pcall(Planner.plan, text)
					if ok and not plan.surprise and Drawer.sendAction then
						Drawer.sendAction("favoritar", plan.label)
						Hud.toast("⭐ Favorito: " .. plan.label, C.gold)
					else
						Hud.toast("Só ideias reconhecidas podem ser favoritas", C.warn)
					end
				end,
			},
		}, function()
			Hud.setText(text)
		end)
	end
end

TABS.favoritos = function()
	local favs = Drawer.profile and Drawer.profile.favorites or {}
	if #favs == 0 then
		section("Toque em ⭐ no histórico para guardar ideias aqui.")
		return
	end
	for _, label in favs do
		row(label, {
			{
				label = "✕",
				fn = function()
					if Drawer.sendAction then
						Drawer.sendAction("favoritar", label)
					end
				end,
			},
		}, function()
			Hud.setText(label)
		end)
	end
end

TABS.progresso = function()
	local p = Drawer.profile
	if not p then
		section("Carregando...")
		return
	end
	section(string.format("✨ Faíscas: %d   %s", p.sparks or 0, if p.saved then "" else "(progresso só nesta sessão)"))
	progressBar("📖 Descobertas", #(p.discovered or {}), p.totalConcepts or 1, C.accent)
	progressBar("🔮 Combinações secretas", #(p.secrets or {}), p.totalSecrets or 1, C.accent2)
	section("Missões da sessão")
	for _, q in p.quests or {} do
		local def = Progression.QuestById[q.id]
		if def then
			progressBar((if q.done then "✅ " else "🎯 ") .. def.title, math.min(q.progress, def.goal), def.goal, if q.done then C.good else C.warn)
		end
	end
	section("Conquistas")
	local got = {}
	for _, id in p.achievements or {} do
		got[id] = true
	end
	for _, a in Progression.Achievements do
		row((if got[a.id] then "🏆 " else "🔒 ") .. a.title .. " — " .. a.desc, {})
	end
end

TABS.loja = function()
	local p = Drawer.profile
	if not p then
		section("Carregando...")
		return
	end
	section(string.format("✨ Faíscas: %d  •  ganhe criando, descobrindo e cumprindo missões", p.sparks or 0))
	local owned = {}
	for _, id in p.owned or {} do
		owned[id] = true
	end
	for _, c in Progression.Cosmetics do
		local equipped = p.equipped and p.equipped[c.kind] == c.id
		local icon = if c.kind == "trail" then "🌈" elseif c.kind == "aura" then "✨" else "🏷️"
		local text = string.format("%s %s", icon, c.title)
		if owned[c.id] then
			row(text .. (if equipped then "  (usando)" else ""), {
				{
					label = if equipped then "✓" else "👕",
					fn = function()
						if Drawer.sendAction then
							Drawer.sendAction("equipar", c.id)
						end
					end,
				},
			})
		else
			row(text .. "  —  " .. c.price .. " ✨", {
				{
					label = "🛒",
					fn = function()
						if (p.sparks or 0) < c.price then
							Hud.toast("Faíscas insuficientes", C.warn)
						elseif Drawer.sendAction then
							Drawer.sendAction("comprar", c.id)
						end
					end,
				},
			})
		end
	end
end

TABS.ajustes = function()
	choice("Gráficos", "quality", { { "Baixo", "baixo" }, { "Médio", "medio" }, { "Alto", "alto" } })
	choice("Câmera", "camera", { { "Normal", "normal" }, { "1ª pessoa", "primeira" }, { "Cinemática", "cinematica" } })
	choice("Tremor de câmera", "shake", { { "Ligado", true }, { "Desligado", false } })
	choice("Sons", "sounds", { { "Ligados", true }, { "Desligados", false } })
	choice("Sons do jogo", "soundSource", { { "ElevenLabs", "auto" }, { "Roblox", "roblox" } })
	do
		local ok, Effects = pcall(require, script.Parent.Parent.FX.Effects)
		local st = if ok and Effects.soundStatus then Effects.soundStatus() else "?"
		local txt = if st == "ok" then "✅ Sons do ElevenLabs carregados" elseif st == "off" then "ℹ️ Sons do ElevenLabs ainda não enviados (use ideias.sh sons)" elseif st == "failed" then "⏳ Áudio aguardando aprovação do Roblox: usando sons do Roblox" else "⏳ Verificando sons..."
		Theme.label({ Text = txt, TextSize = 13, TextWrapped = true, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = nextOrder(), Parent = content })
		local b = Theme.button({ Text = "🔊 Testar som", TextSize = 15, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = nextOrder(), Parent = content })
		b.Activated:Connect(function()
			if ok and Effects.cue then
				Effects.cue("explosion", nil, 1)
				task.delay(0.8, function()
					Effects.cue("achievement", nil, 1)
				end)
			end
		end)
	end
	choice("Cenas de cinema (coisas grandes)", "cutscenes", { { "Ligadas", true }, { "Desligadas", false } })
	choice("Avisos", "notifications", { { "Ligados", true }, { "Desligados", false } })
	choice("Tamanho da interface", "uiScale", { { "Menor", 0.85 }, { "Normal", 1 }, { "Maior", 1.15 } })
	section("Ideias Sem Limites • V3")
end

local TITLES = {
	ideias = "💡 Ideias",
	historico = "🕘 Histórico",
	favoritos = "⭐ Favoritos",
	progresso = "🏆 Progresso",
	loja = "🛍️ Loja",
	ajustes = "⚙️ Ajustes",
}

function Drawer.show(tab: string?)
	if not tab then
		return
	end
	current = tab
	clear()
	order = 0
	title.Text = TITLES[tab] or tab
	markDock()
	local f = TABS[tab]
	if f then
		f()
	end
	if not panel.Visible then
		panel.Visible = true
		panel.Position = UDim2.new(0, -360, 0.5, 0)
		Theme.tween(panel, 0.28, { Position = UDim2.new(0, 178, 0.5, 0) }, Enum.EasingStyle.Quint)
	end
end

function Drawer.hide()
	current = nil
	markDock()
	local tw = Theme.tween(panel, 0.22, { Position = UDim2.new(0, -360, 0.5, 0) })
	tw.Completed:Once(function()
		if not current then
			panel.Visible = false
		end
	end)
end

local sparksLabel: TextLabel? = nil

function Drawer.refresh()
	if sparksLabel and Drawer.profile then
		local n = Drawer.profile.sparks or 0
		local txt = tostring(n):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
		sparksLabel.Text = "✨ " .. txt
		Theme.pop(sparksLabel)
	end
	if current and panel.Visible then
		Drawer.show(current)
	end
end

function Drawer.build(gui: ScreenGui)
	-- coluna de azulejos com o nome ao lado (estilo da referência)
	local dock = new("Frame", {
		Name = "Dock",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.45, 0),
		Size = UDim2.fromOffset(160, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local buttons = {
		{ "ideias", "💡", "Ideias" },
		{ "historico", "🕘", "Histórico" },
		{ "favoritos", "⭐", "Favoritos" },
		{ "progresso", "🏆", "Progresso" },
		{ "loja", "🛍️", "Loja" },
		{ "ajustes", "⚙️", "Ajustes" },
	}
	for i, bdef in buttons do
		local b = new("TextButton", {
			Name = bdef[1],
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(160, 50),
			LayoutOrder = i,
			Parent = dock,
		})
		local tile = Theme.tile(bdef[1], bdef[2], 50, b)
		local lbl = Theme.label({
			Name = "Nome",
			Text = bdef[3],
			TextSize = 19,
			FontFace = Theme.FontHeavy,
			TextWrapped = false,
			Position = UDim2.fromOffset(58, 0),
			Size = UDim2.new(1, -58, 1, 0),
			Parent = b,
		})
		Theme.outlined(lbl, 2.2)
		dockLabels[bdef[1]] = lbl
		Theme.pressable(b, tile)
		b.Activated:Connect(function()
			if current == bdef[1] then
				Drawer.hide()
			else
				Drawer.show(bdef[1])
			end
		end)
	end

	-- contador de faíscas dourado, embaixo da coluna (como as moedas da referência)
	sparksLabel = Theme.label({
		Name = "Faiscas",
		Text = "✨ 0",
		TextSize = 24,
		FontFace = Theme.FontHeavy,
		TextColor3 = Theme.Colors.gold,
		TextWrapped = false,
		Size = UDim2.fromOffset(160, 34),
		LayoutOrder = 99,
		Parent = dock,
	})
	Theme.outlined(sparksLabel :: TextLabel, 2.5)

	panel = new("Frame", {
		Name = "Painel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -360, 0.5, 0),
		Size = UDim2.new(0, 340, 0.72, 0),
		BackgroundColor3 = Color3.fromRGB(30, 30, 38),
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = gui,
	}, {
		Theme.corner(18),
		Theme.stroke(Theme.Ink, 3, 0),
		new("UISizeConstraint", { MaxSize = Vector2.new(360, 520), MinSize = Vector2.new(260, 220) }),
	})
	title = Theme.label({ Text = "", TextSize = 21, FontFace = Theme.FontHeavy, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -60, 0, 30), Parent = panel })
	Theme.outlined(title, 2)
	local close = Theme.button({ Text = "✕", TextSize = 18, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(32, 32), Parent = panel })
	close.Activated:Connect(Drawer.hide)
	content = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -50),
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.accent,
		Parent = panel,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }),
	})
end

return Drawer
