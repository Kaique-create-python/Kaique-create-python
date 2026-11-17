--!strict
-- PROJETO BASTIÃO :: língua do jogador (cliente) e o seletor PT · EN · RU
-- A língua começa pela conta Roblox (o servidor confirma pela escolha salva). O seletor aparece
-- ao lado do painel do menu da bodycam (tecla M ou botão MENU no celular), no mesmo visual, sem
-- mexer no script do menu: só observa quando ele abre e fecha.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")

local Idioma = {}

local WHITE = Color3.fromRGB(238, 238, 232)
local DIM = Color3.fromRGB(166, 168, 160)
local BLACK = Color3.new(0, 0, 0)
local PANEL = Color3.fromRGB(8, 9, 9)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local DESIGN_W, DESIGN_H = 1280, 720
local MEIO_PAINEL = 270 -- metade da largura do painel do menu da bodycam (540)
local LARGURA = 196

export type Api = {
	atual: () -> string,
	aoMudar: (fn: (idioma: string) -> ()) -> (),
	escolher: (idioma: string) -> (),
}

function Idioma.iniciar(op: { textos: any, atributo: string, remoto: RemoteEvent?, playerGui: Instance }): Api
	local textos = op.textos
	local jogador = Players.LocalPlayer
	local ouvintes: { (string) -> () } = {}
	local okLocal, localidade = pcall(function()
		return LocalizationService.RobloxLocaleId
	end)
	local atual = textos.normalizar(jogador:GetAttribute(op.atributo) or textos.daLocalidade(if okLocal then localidade else ""))

	local api = {} :: any
	local function avisar()
		for _, fn in ouvintes do
			task.spawn(fn, atual)
		end
	end
	function api.atual(): string
		return atual
	end
	function api.aoMudar(fn: (string) -> ())
		table.insert(ouvintes, fn)
	end
	function api.escolher(idioma: string)
		idioma = textos.normalizar(idioma)
		if idioma == atual then
			return
		end
		atual = idioma -- troca na hora; o servidor confirma e salva
		avisar()
		if op.remoto then
			op.remoto:FireServer(idioma)
		end
	end
	jogador:GetAttributeChangedSignal(op.atributo):Connect(function()
		local novo = textos.normalizar(jogador:GetAttribute(op.atributo))
		if novo ~= atual then
			atual = novo
			avisar()
		end
	end)

	-- ===== seletor ao lado do menu da bodycam =====
	local gui = Instance.new("ScreenGui")
	gui.Name = "BastiaoIdioma"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 21 -- logo acima do menu da bodycam (20)
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = op.playerGui
	local seguro = Instance.new("Frame")
	seguro.Name = "SafeArea"
	seguro.BackgroundTransparency = 1
	seguro.Size = UDim2.fromScale(1, 1)
	seguro.Parent = gui
	local tela = Instance.new("Frame")
	tela.Name = "Canvas"
	tela.BackgroundTransparency = 1
	tela.Size = UDim2.fromScale(1, 1)
	tela.Parent = seguro
	local escala = Instance.new("UIScale")
	escala.Parent = tela

	local caixa = Instance.new("Frame")
	caixa.Name = "Seletor"
	caixa.AnchorPoint = Vector2.new(0, 0.5)
	caixa.Position = UDim2.new(0.5, MEIO_PAINEL + 12, 0.5, 0)
	caixa.Size = UDim2.fromOffset(LARGURA, 0)
	caixa.AutomaticSize = Enum.AutomaticSize.Y
	caixa.BackgroundColor3 = PANEL
	caixa.BackgroundTransparency = 0.1
	caixa.BorderSizePixel = 0
	caixa.Parent = tela
	local canto = Instance.new("UICorner")
	canto.CornerRadius = UDim.new(0, 2)
	canto.Parent = caixa
	local borda = Instance.new("UIStroke")
	borda.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	borda.Color = WHITE
	borda.Transparency = 0.55
	borda.Thickness = 1
	borda.Parent = caixa
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = caixa
	local lista = Instance.new("UIListLayout")
	lista.Padding = UDim.new(0, 6)
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Parent = caixa
	local titulo = Instance.new("TextLabel")
	titulo.Name = "Titulo"
	titulo.BackgroundTransparency = 1
	titulo.Size = UDim2.new(1, 0, 0, 16)
	titulo.FontFace = MONO
	titulo.TextSize = 11
	titulo.TextColor3 = DIM
	titulo.TextXAlignment = Enum.TextXAlignment.Left
	titulo.Text = textos.TITULO_MENU
	titulo.LayoutOrder = 0
	titulo.Parent = caixa

	local botoes: { [string]: TextButton } = {}
	local function pintar()
		for id, b in botoes do
			local escolhido = id == atual
			b.BackgroundColor3 = if escolhido then WHITE else BLACK
			b.BackgroundTransparency = if escolhido then 0.08 else 0.45
			b.TextColor3 = if escolhido then BLACK else WHITE
		end
	end
	for i, id in textos.IDIOMAS do
		local b = Instance.new("TextButton")
		b.Name = "Idioma_" .. id
		b.AutoButtonColor = false
		b.Size = UDim2.new(1, 0, 0, 40)
		b.FontFace = MONO
		b.TextSize = 15
		b.Text = textos.NOME_IDIOMA[id]
		b.BorderSizePixel = 0
		b.LayoutOrder = i
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 2)
		c.Parent = b
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Color = WHITE
		s.Transparency = 0.6
		s.Parent = b
		b.Activated:Connect(function()
			api.escolher(id)
		end)
		b.Parent = caixa
		botoes[id] = b
	end
	pintar()
	api.aoMudar(function()
		pintar()
	end)

	local function relayout()
		local s = seguro.AbsoluteSize
		if s.X < 2 or s.Y < 2 then
			return
		end
		local k = math.clamp(math.min(s.Y / DESIGN_H, s.X / DESIGN_W), 0.72, 1.7)
		escala.Scale = k
		tela.Size = UDim2.fromScale(1 / k, 1 / k)
		local larguraTela = s.X / k
		-- sem espaço à direita do painel (tela estreita): fica no canto inferior direito
		if larguraTela / 2 - MEIO_PAINEL - 12 < LARGURA then
			caixa.AnchorPoint = Vector2.new(1, 1)
			caixa.Position = UDim2.new(1, -8, 1, -8)
		else
			caixa.AnchorPoint = Vector2.new(0, 0.5)
			caixa.Position = UDim2.new(0.5, MEIO_PAINEL + 12, 0.5, 0)
		end
	end
	seguro:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	relayout()

	-- abre e fecha junto com o menu da bodycam (S7BodycamMenu), só observando
	local conexao: RBXScriptConnection? = nil
	local function ligarMenu(menu: Instance)
		if not menu:IsA("ScreenGui") then
			return
		end
		if conexao then
			conexao:Disconnect()
		end
		local function sync()
			gui.Enabled = (menu :: ScreenGui).Enabled
			if gui.Enabled then
				relayout()
				pintar()
			end
		end
		conexao = menu:GetPropertyChangedSignal("Enabled"):Connect(sync)
		sync()
	end
	local existente = op.playerGui:FindFirstChild("S7BodycamMenu")
	if existente then
		ligarMenu(existente)
	end
	op.playerGui.ChildAdded:Connect(function(filho)
		if filho.Name == "S7BodycamMenu" then
			ligarMenu(filho)
		end
	end)

	return api :: Api
end

return Idioma
