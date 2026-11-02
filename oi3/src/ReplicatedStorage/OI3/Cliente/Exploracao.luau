-- OI3 :: modo exploração (depois da abertura), em primeira pessoa.
-- HUD limpa: barra de estamina embaixo, ponto no centro, vinheta, botões LUZ/CORRER no celular.

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Interface = require(script.Parent.Interface)
local Som = require(script.Parent.Som)
local PrimeiraPessoa = require(script.Parent.PrimeiraPessoa)
local Ambiente = require(script.Parent.Ambiente)

local Exploracao = {}

local COR = Interface.COR
local RGB = Color3.fromRGB

local estado = {
	tela = nil :: ScreenGui?,
	telaCheia = nil :: ScreenGui?,
	botaoLuz = nil :: TextButton?,
	botaoCorrer = nil :: TextButton?,
	aviso = nil :: Frame?,
	barra = nil :: CanvasGroup?,
	preenchido = nil :: Frame?,
	vinheta = {} :: { Frame },
	ativo = false,
	luz = false,
	remotos = nil :: any,
	aoMenu = nil :: (() -> ())?,
	tokenClima = 0,
	barraVisivel = false,
	ultimoCheio = 0,
	conexaoPersonagem = nil :: RBXScriptConnection?,
}

local function pintarBotao(b: TextButton?, ligado: boolean)
	if not b then
		return
	end
	b.BackgroundColor3 = if ligado then RGB(196, 150, 70) else RGB(26, 24, 29)
	for _, f in b:GetDescendants() do
		if f:IsA("Frame") and f.Name == "Traco" then
			f.BackgroundColor3 = if ligado then RGB(30, 22, 12) else COR.texto
		elseif f:IsA("TextLabel") then
			f.TextColor3 = if ligado then RGB(30, 22, 12) else COR.texto
		end
	end
end

local function definirLuz(ligar: boolean)
	estado.luz = ligar
	if estado.remotos then
		estado.remotos.Lanterna:FireServer(ligar) -- os outros jogadores veem a luz pela cabeça
	end
	PrimeiraPessoa.definirLuz(ligar)
	local nome = if ligar then "lanterna_liga" else "lanterna_desliga"
	if Som.disponivel(nome) then
		Som.tocar(nome, { volume = 0.85 })
	else
		Som.tocar("clique", { volume = 0.7 })
	end
	pintarBotao(estado.botaoLuz, ligar)
end

-- botão redondinho de canto 4 px com ícone desenhado
local function botaoAcao(tela: Instance, nome: string, rotulo: string, posicao: UDim2): (TextButton, Frame)
	local b = Instance.new("TextButton")
	b.Name = nome
	b.Text = ""
	b.AutoButtonColor = false
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = posicao
	b.Size = UDim2.fromOffset(62, 62)
	b.BackgroundColor3 = RGB(26, 24, 29)
	b.BackgroundTransparency = 0.12
	Interface.canto(b, 4)
	Interface.borda(b, COR.borda, 1, 0.3)
	b.Parent = tela
	local icone = Instance.new("Frame")
	icone.Name = "Icone"
	icone.BackgroundTransparency = 1
	icone.Size = UDim2.new(1, 0, 1, -14)
	icone.Parent = b
	Interface.texto(b, {
		Text = rotulo,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, 0, 0, 13),
		TextSize = 11,
		FontFace = Interface.FONTE.textoNegrito,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	return b, icone
end

local function traco(pai: Instance, pos: UDim2, tam: UDim2, rot: number)
	local f = Instance.new("Frame")
	f.Name = "Traco"
	f.BackgroundColor3 = COR.texto
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = pos
	f.Size = tam
	f.Rotation = rot
	Interface.canto(f, 3)
	f.Parent = pai
	return f
end

local function criarVinheta(tela: ScreenGui)
	local lados = {
		{ "Cima", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.28), 90 },
		{ "Baixo", UDim2.fromScale(0, 0.72), UDim2.fromScale(1, 0.28), -90 },
		{ "Esq", UDim2.fromScale(0, 0), UDim2.fromScale(0.24, 1), 0 },
		{ "Dir", UDim2.fromScale(0.76, 0), UDim2.fromScale(0.24, 1), 180 },
	}
	for _, l in lados do
		local f = Instance.new("Frame")
		f.Name = "Vinheta" .. l[1]
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Position = l[2]
		f.Size = l[3]
		local g = Instance.new("UIGradient")
		g.Rotation = l[4]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.55, 0.85), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		f.Parent = tela
		table.insert(estado.vinheta, f)
	end
end

local function atualizarEstamina(valor: number, correndo: boolean, cansado: boolean)
	local barra = estado.barra
	local fill = estado.preenchido
	if not (barra and fill) then
		return
	end
	fill.Size = UDim2.fromScale(math.clamp(valor, 0, 1), 1)
	fill.BackgroundColor3 = if cansado then RGB(196, 70, 60) elseif valor < 0.3 then RGB(214, 160, 92) else RGB(236, 230, 218)
	local agora = os.clock()
	local mostrar = correndo or valor < 0.995 or cansado
	if mostrar then
		estado.ultimoCheio = agora
	end
	local deveMostrar = mostrar or (agora - estado.ultimoCheio < 1.2)
	if deveMostrar ~= estado.barraVisivel then
		estado.barraVisivel = deveMostrar
		TweenService:Create(barra, TweenInfo.new(if deveMostrar then 0.2 else 0.6), { GroupTransparency = if deveMostrar then 0 else 1 }):Play()
	end
	-- vinheta aperta quando cansado
	local alvo = if cansado then 0.1 else 0
	for _, f in estado.vinheta do
		f.BackgroundTransparency = alvo
	end
end

function Exploracao.iniciar(remotos: any, aoMenu: () -> ())
	estado.remotos = remotos
	estado.aoMenu = aoMenu
	local tela = Interface.tela("OI3_HUD", 10, true)
	tela.Enabled = false
	estado.tela = tela
	Interface.escalaAuto(tela)
	local cheia = Interface.tela("OI3_HUD_Tela", 9, false)
	cheia.Enabled = false
	estado.telaCheia = cheia
	criarVinheta(cheia)

	-- ponto no centro (mira discreta)
	local ponto = Instance.new("Frame")
	ponto.Name = "Ponto"
	ponto.AnchorPoint = Vector2.new(0.5, 0.5)
	ponto.Position = UDim2.fromScale(0.5, 0.5)
	ponto.Size = UDim2.fromOffset(4, 4)
	ponto.BackgroundColor3 = RGB(240, 236, 228)
	ponto.BackgroundTransparency = 0.45
	ponto.BorderSizePixel = 0
	local cp = Instance.new("UICorner")
	cp.CornerRadius = UDim.new(1, 0)
	cp.Parent = ponto
	ponto.Parent = cheia

	-- botão MENU (canto superior direito)
	Interface.botao(tela, "MENU", {
		Name = "Menu",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(88, 36),
		TextSize = 16,
		BackgroundTransparency = 0.15,
	}, function()
		if estado.aoMenu then
			estado.aoMenu()
		end
	end)

	-- barra de estamina (bem fininha, embaixo no meio)
	local barra = Instance.new("CanvasGroup")
	barra.Name = "Estamina"
	barra.AnchorPoint = Vector2.new(0.5, 1)
	barra.Position = UDim2.new(0.5, 0, 1, -22)
	barra.Size = UDim2.fromOffset(230, 7)
	barra.BackgroundColor3 = RGB(14, 13, 16)
	barra.BackgroundTransparency = 0.35
	barra.GroupTransparency = 1
	barra.BorderSizePixel = 0
	Interface.canto(barra, 4)
	local stBarra = Instance.new("UIStroke")
	stBarra.Color = RGB(240, 232, 216)
	stBarra.Transparency = 0.82
	stBarra.Thickness = 1
	stBarra.Parent = barra
	local fill = Instance.new("Frame")
	fill.Name = "Cheio"
	fill.BackgroundColor3 = RGB(236, 230, 218)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	Interface.canto(fill, 4)
	local brilho = Instance.new("UIGradient")
	brilho.Color = ColorSequence.new(RGB(255, 255, 255), RGB(190, 182, 170))
	brilho.Rotation = 90
	brilho.Parent = fill
	fill.Parent = barra
	barra.Parent = tela
	estado.barra = barra
	estado.preenchido = fill
	PrimeiraPessoa.aoEstamina(atualizarEstamina)

	-- botões de ação no celular (acima do botão de pulo)
	if UserInputService.TouchEnabled then
		local cam = workspace.CurrentCamera
		local grande = cam and math.min(cam.ViewportSize.X, cam.ViewportSize.Y) > 520
		local y = if grande then -250 else -176
		local correr, iconeC = botaoAcao(tela, "Correr", "CORRER", UDim2.new(1, -24, 1, y))
		-- ícone: três setinhas (velocidade)
		for i = 0, 2 do
			traco(iconeC, UDim2.fromScale(0.3 + i * 0.2, 0.42), UDim2.fromScale(0.16, 0.08), 40)
			traco(iconeC, UDim2.fromScale(0.3 + i * 0.2, 0.58), UDim2.fromScale(0.16, 0.08), -40)
		end
		correr.MouseButton1Down:Connect(function()
			PrimeiraPessoa.correr(true)
			pintarBotao(correr, true)
		end)
		local function soltar()
			PrimeiraPessoa.correr(false)
			pintarBotao(correr, false)
		end
		correr.MouseButton1Up:Connect(soltar)
		correr.MouseLeave:Connect(soltar)
		estado.botaoCorrer = correr

		local luz, iconeL = botaoAcao(tela, "Lanterna", "LUZ", UDim2.new(1, -96, 1, y))
		traco(iconeL, UDim2.fromScale(0.42, 0.58), UDim2.fromScale(0.42, 0.16), -35)
		traco(iconeL, UDim2.fromScale(0.64, 0.4), UDim2.fromScale(0.24, 0.26), -35)
		luz.Activated:Connect(function()
			definirLuz(not estado.luz)
		end)
		estado.botaoLuz = luz
	end

	-- aviso no topo
	local aviso = Instance.new("Frame")
	aviso.Name = "Aviso"
	aviso.AnchorPoint = Vector2.new(0.5, 0)
	aviso.Position = UDim2.new(0.5, 0, 0, 12)
	aviso.Size = UDim2.fromOffset(0, 0)
	aviso.AutomaticSize = Enum.AutomaticSize.XY
	aviso.BackgroundColor3 = COR.painel
	aviso.BackgroundTransparency = 0.2
	aviso.Visible = false
	Interface.canto(aviso, 4)
	Interface.borda(aviso, COR.borda, 1, 0.4)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = aviso
	local lista = Instance.new("UIListLayout")
	lista.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lista.Parent = aviso
	local dica = if UserInputService.TouchEnabled then "Lanterna: LUZ · Correr: segure CORRER" else "Lanterna: F · Correr: segure Shift"
	Interface.texto(aviso, { Name = "L1", Text = "Explore o orfanato.", FontFace = Interface.FONTE.titulo, TextSize = 18, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), TextXAlignment = Enum.TextXAlignment.Center })
	Interface.texto(aviso, { Name = "L2", Text = "Capítulo 1 em breve · " .. dica, TextSize = 14, TextColor3 = COR.textoFraco, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), TextXAlignment = Enum.TextXAlignment.Center })
	aviso.Parent = tela
	estado.aviso = aviso

	-- teclado / controle
	ContextActionService:BindAction("OI3_Lanterna", function(_, st)
		if st == Enum.UserInputState.Begin and estado.ativo then
			definirLuz(not estado.luz)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("OI3_Correr", function(_, st)
		if estado.ativo then
			PrimeiraPessoa.correr(st == Enum.UserInputState.Begin or st == Enum.UserInputState.Change)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
end

function Exploracao.configurar(o: { tremor: boolean?, leve: boolean? })
	PrimeiraPessoa.configurar(o)
end

function Exploracao.entrar(char: Model?)
	estado.ativo = true
	local tela = estado.tela :: ScreenGui
	tela.Enabled = true
	if estado.telaCheia then
		estado.telaCheia.Enabled = true
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
	end)
	local lp = Players.LocalPlayer
	if char then
		PrimeiraPessoa.ligar(char)
		PrimeiraPessoa.definirLuz(estado.luz)
	end
	if estado.conexaoPersonagem then
		estado.conexaoPersonagem:Disconnect()
	end
	estado.conexaoPersonagem = lp.CharacterAdded:Connect(function(novo)
		if estado.ativo then
			task.wait(0.2)
			PrimeiraPessoa.ligar(novo)
			PrimeiraPessoa.definirLuz(estado.luz)
		end
	end)
	-- ambiente sonoro: vento e grilos lá fora, casa rangendo, lareira e relógio no hall
	Ambiente.iniciar()
	local aviso = estado.aviso :: Frame
	aviso.Visible = true
	task.delay(8, function()
		aviso.Visible = false
	end)
end

function Exploracao.sair()
	if estado.luz then
		definirLuz(false)
	end
	estado.ativo = false
	estado.tokenClima += 1
	Ambiente.parar(1.0)
	if estado.conexaoPersonagem then
		estado.conexaoPersonagem:Disconnect()
		estado.conexaoPersonagem = nil
	end
	PrimeiraPessoa.correr(false)
	PrimeiraPessoa.desligar()
	if estado.tela then
		estado.tela.Enabled = false
	end
	if estado.telaCheia then
		estado.telaCheia.Enabled = false
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
end

function Exploracao.ativo(): boolean
	return estado.ativo
end

return Exploracao
