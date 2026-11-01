-- OI3 :: modo exploração (depois da abertura): HUD limpa, lanterna e clima

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Interface = require(script.Parent.Interface)
local Som = require(script.Parent.Som)

local Exploracao = {}

local COR = Interface.COR

local estado = {
	tela = nil :: ScreenGui?,
	botaoLuz = nil :: TextButton?,
	aviso = nil :: Frame?,
	ativo = false,
	luz = false,
	remotos = nil :: any,
	aoMenu = nil :: (() -> ())?,
	tokenClima = 0,
}

local function definirLuz(ligar: boolean)
	estado.luz = ligar
	if estado.remotos then
		estado.remotos.Lanterna:FireServer(ligar)
	end
	Som.tocar("clique", { volume = 0.6 })
	local b = estado.botaoLuz
	if b then
		b.BackgroundColor3 = if ligar then Color3.fromRGB(196, 150, 70) else Color3.fromRGB(26, 24, 29)
		local icone = b:FindFirstChild("Icone")
		if icone then
			for _, f in icone:GetChildren() do
				if f:IsA("Frame") then
					f.BackgroundColor3 = if ligar then Color3.fromRGB(30, 22, 12) else COR.texto
				end
			end
		end
	end
end

function Exploracao.iniciar(remotos: any, aoMenu: () -> ())
	estado.remotos = remotos
	estado.aoMenu = aoMenu
	local tela = Interface.tela("OI3_HUD", 10, true)
	tela.Enabled = false
	estado.tela = tela
	Interface.escalaAuto(tela)

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

	-- botão da lanterna (acima do botão de pulo no celular)
	local luz = Instance.new("TextButton")
	luz.Name = "Lanterna"
	luz.Text = ""
	luz.AutoButtonColor = false
	luz.AnchorPoint = Vector2.new(1, 1)
	luz.Position = if UserInputService.TouchEnabled then UDim2.new(1, -26, 1, -168) else UDim2.new(1, -16, 1, -16)
	luz.Size = UDim2.fromOffset(60, 60)
	luz.BackgroundColor3 = Color3.fromRGB(26, 24, 29)
	luz.BackgroundTransparency = 0.1
	Interface.canto(luz, 4)
	Interface.borda(luz, COR.borda, 1, 0.3)
	luz.Parent = tela
	local icone = Instance.new("Frame")
	icone.Name = "Icone"
	icone.BackgroundTransparency = 1
	icone.Size = UDim2.fromScale(1, 1)
	icone.Parent = luz
	local corpo = Instance.new("Frame")
	corpo.BackgroundColor3 = COR.texto
	corpo.BorderSizePixel = 0
	corpo.AnchorPoint = Vector2.new(0.5, 0.5)
	corpo.Position = UDim2.fromScale(0.42, 0.56)
	corpo.Size = UDim2.fromScale(0.42, 0.16)
	corpo.Rotation = -35
	Interface.canto(corpo, 3)
	corpo.Parent = icone
	local cabeca = Instance.new("Frame")
	cabeca.BackgroundColor3 = COR.texto
	cabeca.BorderSizePixel = 0
	cabeca.AnchorPoint = Vector2.new(0.5, 0.5)
	cabeca.Position = UDim2.fromScale(0.64, 0.4)
	cabeca.Size = UDim2.fromScale(0.24, 0.24)
	cabeca.Rotation = -35
	Interface.canto(cabeca, 3)
	cabeca.Parent = icone
	Interface.texto(luz, {
		Text = "LUZ",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = 11,
		FontFace = Interface.FONTE.textoNegrito,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	luz.Activated:Connect(function()
		definirLuz(not estado.luz)
	end)
	estado.botaoLuz = luz

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
	Interface.texto(aviso, { Name = "L1", Text = "Explore o orfanato.", FontFace = Interface.FONTE.titulo, TextSize = 18, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), TextXAlignment = Enum.TextXAlignment.Center })
	Interface.texto(aviso, { Name = "L2", Text = "Capítulo 1 em breve · Lanterna: botão LUZ ou tecla F", TextSize = 14, TextColor3 = COR.textoFraco, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), TextXAlignment = Enum.TextXAlignment.Center })
	aviso.Parent = tela
	estado.aviso = aviso

	ContextActionService:BindAction("OI3_Lanterna", function(_, st)
		if st == Enum.UserInputState.Begin and estado.ativo then
			definirLuz(not estado.luz)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F)
end

function Exploracao.entrar()
	estado.ativo = true
	local tela = estado.tela :: ScreenGui
	tela.Enabled = true
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
	end)
	Som.ambiente("interior", 0.7, 2)
	Som.ambiente("vento", 0.3, 2)
	local aviso = estado.aviso :: Frame
	aviso.Visible = true
	task.delay(7, function()
		aviso.Visible = false
	end)
	-- rangidos e sussurros raros
	estado.tokenClima += 1
	local token = estado.tokenClima
	task.spawn(function()
		while estado.ativo and token == estado.tokenClima do
			task.wait(10 + math.random() * 14)
			if not estado.ativo or token ~= estado.tokenClima then
				break
			end
			if math.random() < 0.75 then
				Som.tocar("rangido", { volume = 0.18 + math.random() * 0.15 })
			else
				Som.tocar("sussurro", { volume = 0.22 })
			end
		end
	end)
end

function Exploracao.sair()
	if estado.luz then
		definirLuz(false)
	end
	estado.ativo = false
	estado.tokenClima += 1
	if estado.tela then
		estado.tela.Enabled = false
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
end

function Exploracao.ativo(): boolean
	return estado.ativo
end

return Exploracao
