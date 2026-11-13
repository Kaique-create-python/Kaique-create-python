-- OI3 :: interface 2D (HUD limpa, cantos de 4 px, feita para celular primeiro)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local OI3 = script.Parent.Parent
local Config = require(OI3.Config)

local Interface = {}

local COR = Config.CORES
Interface.COR = COR

Interface.FONTE = {
	titulo = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold),
	tituloForte = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Heavy),
	texto = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular),
	textoForte = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold),
	textoNegrito = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
	logo = Font.new("rbxasset://fonts/families/Creepster.json", Enum.FontWeight.Regular),
	maquina = Font.new("rbxasset://fonts/families/SpecialElite.json", Enum.FontWeight.Regular),
}

local function playerGui(): Instance
	local lp = Players.LocalPlayer
	return lp:WaitForChild("PlayerGui")
end

function Interface.tela(nome: string, ordem: number, seguro: boolean?): ScreenGui
	local sg = Instance.new("ScreenGui")
	sg.Name = nome
	sg.ResetOnSpawn = false
	sg.DisplayOrder = ordem
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.IgnoreGuiInset = not seguro
	pcall(function()
		sg.ScreenInsets = if seguro then Enum.ScreenInsets.CoreUISafeInsets else Enum.ScreenInsets.None
	end)
	sg.Parent = playerGui()
	return sg
end

function Interface.canto(obj: Instance, px: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px or 4)
	c.Parent = obj
	return c
end

function Interface.borda(obj: Instance, cor: Color3?, espessura: number?, transparencia: number?)
	local s = Instance.new("UIStroke")
	s.Color = cor or COR.borda
	s.Thickness = espessura or 1
	s.Transparency = transparencia or 0.25
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

function Interface.texto(pai: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextColor3 = COR.texto
	t.FontFace = Interface.FONTE.texto
	t.TextSize = 18
	t.TextWrapped = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = pai
	return t
end

-- Escala da interface conforme a altura da tela (celular ~390px, PC 720-1080px)
function Interface.escalaAuto(sg: ScreenGui): UIScale
	local esc = Instance.new("UIScale")
	esc.Parent = sg
	local function atualizar()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local vh = cam.ViewportSize.Y
		esc.Scale = math.clamp(vh / 430, 0.82, 1.5)
	end
	atualizar()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(atualizar)
	end
	return esc
end

-- Botão 2D simples (4 px de canto, retorno visual ao tocar)
function Interface.botao(pai: Instance, texto: string, props: { [string]: any }?, aoClicar: (() -> ())?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.fromRGB(34, 31, 36)
	b.BorderSizePixel = 0
	b.Text = texto
	b.TextColor3 = COR.texto
	b.FontFace = Interface.FONTE.textoNegrito
	b.TextSize = 18
	b.Size = UDim2.fromOffset(150, 44)
	Interface.canto(b, 4)
	local borda = Interface.borda(b, COR.borda, 1, 0.35)
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	local corBase = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = corBase:Lerp(Color3.new(1, 1, 1), 0.08) }):Play()
		borda.Transparency = 0.05
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15), { BackgroundColor3 = corBase }):Play()
		borda.Transparency = 0.35
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.06), { BackgroundColor3 = corBase:Lerp(Color3.new(0, 0, 0), 0.25) }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15), { BackgroundColor3 = corBase }):Play()
	end)
	if aoClicar then
		b.Activated:Connect(aoClicar)
	end
	b.Parent = pai
	return b
end

-- Controle deslizante (arrastar com o dedo ou mouse)
function Interface.deslizante(pai: Instance, rotulo: string, valor: number, minimo: number, maximo: number, aoMudar: (number) -> ()): Frame
	local linha = Instance.new("Frame")
	linha.Name = "Linha_" .. rotulo
	linha.BackgroundTransparency = 1
	linha.Size = UDim2.new(1, 0, 0, 46)
	linha.Parent = pai
	Interface.texto(linha, { Text = rotulo, Size = UDim2.new(0.42, 0, 1, 0), FontFace = Interface.FONTE.textoForte, TextSize = 18 })
	local trilho = Instance.new("TextButton")
	trilho.Name = "Trilho"
	trilho.Text = ""
	trilho.AutoButtonColor = false
	trilho.BackgroundColor3 = Color3.fromRGB(44, 40, 46)
	trilho.BorderSizePixel = 0
	trilho.AnchorPoint = Vector2.new(0, 0.5)
	trilho.Position = UDim2.new(0.44, 0, 0.5, 0)
	trilho.Size = UDim2.new(0.56, -8, 0, 10)
	Interface.canto(trilho, 4)
	trilho.Parent = linha
	local cheio = Instance.new("Frame")
	cheio.Name = "Cheio"
	cheio.BackgroundColor3 = COR.destaque
	cheio.BorderSizePixel = 0
	cheio.Size = UDim2.fromScale(0, 1)
	Interface.canto(cheio, 4)
	cheio.Parent = trilho
	local pino = Instance.new("Frame")
	pino.Name = "Pino"
	pino.AnchorPoint = Vector2.new(0.5, 0.5)
	pino.Size = UDim2.fromOffset(22, 22)
	pino.BackgroundColor3 = COR.texto
	pino.BorderSizePixel = 0
	Interface.canto(pino, 4)
	pino.Parent = trilho
	local function mostrar(v: number)
		local t = (v - minimo) / (maximo - minimo)
		cheio.Size = UDim2.fromScale(t, 1)
		pino.Position = UDim2.fromScale(t, 0.5)
	end
	mostrar(valor)
	local arrastando = false
	local function aplicar(xTela: number)
		local x0 = trilho.AbsolutePosition.X
		local w = math.max(trilho.AbsoluteSize.X, 1)
		local t = math.clamp((xTela - x0) / w, 0, 1)
		local v = minimo + (maximo - minimo) * t
		mostrar(v)
		aoMudar(v)
	end
	trilho.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			arrastando = true
			aplicar(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if arrastando and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			aplicar(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			arrastando = false
		end
	end)
	return linha
end

-- Chave liga/desliga
function Interface.chave(pai: Instance, rotulo: string, valor: boolean, aoMudar: (boolean) -> ()): Frame
	local linha = Instance.new("Frame")
	linha.Name = "Linha_" .. rotulo
	linha.BackgroundTransparency = 1
	linha.Size = UDim2.new(1, 0, 0, 46)
	linha.Parent = pai
	Interface.texto(linha, { Text = rotulo, Size = UDim2.new(1, -90, 1, 0), FontFace = Interface.FONTE.textoForte, TextSize = 18 })
	local botao = Instance.new("TextButton")
	botao.Name = "Chave"
	botao.Text = ""
	botao.AutoButtonColor = false
	botao.AnchorPoint = Vector2.new(1, 0.5)
	botao.Position = UDim2.new(1, -4, 0.5, 0)
	botao.Size = UDim2.fromOffset(64, 30)
	botao.BorderSizePixel = 0
	Interface.canto(botao, 4)
	botao.Parent = linha
	local bola = Instance.new("Frame")
	bola.Size = UDim2.fromOffset(24, 24)
	bola.AnchorPoint = Vector2.new(0, 0.5)
	bola.BorderSizePixel = 0
	bola.BackgroundColor3 = COR.texto
	Interface.canto(bola, 4)
	bola.Parent = botao
	local estado = valor
	local function mostrar(animar: boolean)
		local pos = if estado then UDim2.new(1, -27, 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
		local cor = if estado then COR.destaque else Color3.fromRGB(52, 48, 54)
		if animar then
			TweenService:Create(bola, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Position = pos }):Play()
			TweenService:Create(botao, TweenInfo.new(0.15), { BackgroundColor3 = cor }):Play()
		else
			bola.Position = pos
			botao.BackgroundColor3 = cor
		end
	end
	mostrar(false)
	botao.Activated:Connect(function()
		estado = not estado
		mostrar(true)
		aoMudar(estado)
	end)
	return linha
end

return Interface
