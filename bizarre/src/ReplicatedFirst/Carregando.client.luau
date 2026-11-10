-- BIZARRE BATTLEGROUNDS :: tela de carregamento (aparece na hora; some só quando o menu está pronto)
-- AJUSTE7: mostra as etapas DE VERDADE (jogo baixado, servidor ligado, Stands, menu). Se uma etapa
-- não terminar, avisa qual foi e oferece TENTAR DE NOVO. Nunca diz "pronto" sem estar pronto.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local plr = Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local gui = Instance.new("ScreenGui")
gui.Name = "BB_Carregando"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.Parent = playerGui

local fundo = Instance.new("Frame")
fundo.Size = UDim2.fromScale(1, 1)
fundo.BackgroundColor3 = Color3.fromRGB(12, 8, 20)
fundo.BorderSizePixel = 0
fundo.Parent = gui
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(58, 30, 110), Color3.fromRGB(10, 6, 18))
grad.Rotation = 120
grad.Parent = fundo

local function texto(t: string, tam: UDim2, pos: UDim2, cor: Color3, rot: number?, fonte: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = tam
	l.Position = pos
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.BackgroundTransparency = 1
	l.Text = t
	l.Font = fonte or Enum.Font.Bangers
	l.TextScaled = true
	l.TextColor3 = cor
	l.Rotation = rot or 0
	l.Parent = fundo
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = Color3.fromRGB(10, 4, 20)
	s.Parent = l
	return l
end

local titulo = texto("BIZARRE", UDim2.fromScale(0.6, 0.2), UDim2.fromScale(0.5, 0.33), Color3.fromRGB(255, 206, 64), -4)
texto("BATTLEGROUNDS", UDim2.fromScale(0.5, 0.1), UDim2.fromScale(0.5, 0.47), Color3.fromRGB(255, 255, 255), -2)
local status = texto("", UDim2.fromScale(0.7, 0.055), UDim2.fromScale(0.5, 0.7), Color3.fromRGB(230, 220, 255), 0, Enum.Font.GothamBold)
local dicas = {
	"Dica: aperte BLOQ bem na hora do golpe para dar PARRY.",
	"Dica: atordoado? DASH faz a EVASIVA e você escapa do combo.",
	"Dica: o 4º soco arremessa o inimigo e quebra paredes.",
	"Dica: a barra de DESPERTAR enche batendo e apanhando.",
	"Dica: MIRA trava no inimigo; o DASH de lado gira em volta dele.",
	"Dica: duas rajadas de frente se anulam: ORA x MUDA!",
	"Dica: Star Platinum e The World despertos PARAM O TEMPO.",
	"Dica: o Crazy Diamond conserta o mapa... em cima dos inimigos.",
	"Dica: a Killer Queen transforma em bomba o que ela tocar.",
}
local dica = texto(dicas[math.random(1, #dicas)], UDim2.fromScale(0.86, 0.045), UDim2.fromScale(0.5, 0.9), Color3.fromRGB(255, 255, 255), 0, Enum.Font.GothamMedium)

-- barra de etapas
local barra = Instance.new("Frame")
barra.AnchorPoint = Vector2.new(0.5, 0.5)
barra.Position = UDim2.fromScale(0.5, 0.78)
barra.Size = UDim2.fromScale(0.5, 0.018)
barra.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
barra.BorderSizePixel = 0
barra.Parent = fundo
local cantoB = Instance.new("UICorner")
cantoB.CornerRadius = UDim.new(0.5, 0)
cantoB.Parent = barra
local cheia = Instance.new("Frame")
cheia.Size = UDim2.fromScale(0, 1)
cheia.BackgroundColor3 = Color3.fromRGB(255, 206, 64)
cheia.BorderSizePixel = 0
cheia.Parent = barra
local cantoC = Instance.new("UICorner")
cantoC.CornerRadius = UDim.new(0.5, 0)
cantoC.Parent = cheia

-- botão de tentar de novo (só aparece quando uma etapa falha)
local botao = Instance.new("TextButton")
botao.AnchorPoint = Vector2.new(0.5, 0.5)
botao.Position = UDim2.fromScale(0.5, 0.6)
botao.Size = UDim2.fromScale(0.3, 0.09)
botao.BackgroundColor3 = Color3.fromRGB(255, 206, 64)
botao.Text = "TENTAR DE NOVO"
botao.Font = Enum.Font.Bangers
botao.TextScaled = true
botao.TextColor3 = Color3.fromRGB(40, 20, 10)
botao.Visible = false
botao.Parent = fundo
local cantoBotao = Instance.new("UICorner")
cantoBotao.CornerRadius = UDim.new(0, 12)
cantoBotao.Parent = botao

-- letras "ゴ" girando em volta do título
local letras = {}
for i = 1, 6 do
	local l = texto("ゴ", UDim2.fromScale(0.06, 0.1), UDim2.fromScale(0.5, 0.36), Color3.fromRGB(190, 110, 255))
	l.Font = Enum.Font.GothamBlack
	letras[i] = l
end

local vivo = true
task.spawn(function()
	local t = 0
	while vivo do
		t += 1 / 30
		for i, l in letras do
			local a = t * 0.8 + i * (math.pi * 2 / #letras)
			l.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.36, 0.4 + math.sin(a) * 0.24)
			l.Rotation = math.sin(t * 3 + i) * 15
			l.TextTransparency = 0.2 + math.sin(t * 2 + i) * 0.2
		end
		titulo.Rotation = -4 + math.sin(t * 2) * 1.5
		if math.floor(t * 30) % 150 == 0 then
			dica.Text = dicas[math.random(1, #dicas)]
		end
		task.wait(1 / 30)
	end
end)

-- etapas: { texto, pronto?(), limite em segundos, obrigatória }
local function standsProntos(): boolean
	local pasta = ReplicatedStorage:FindFirstChild("BB_Stands")
	return workspace:GetAttribute("BB_StandsProntos") == true or (pasta ~= nil and #pasta:GetChildren() >= 6)
end
local ETAPAS = {
	{ "Baixando o jogo", function()
		return game:IsLoaded()
	end, 60, true },
	{ "Ligando o servidor e abrindo Morioh", function()
		return workspace:GetAttribute("BB_Pronto") == true
	end, 40, true },
	{ "Chamando os Stands", standsProntos, 15, false }, -- se demorar, eles aparecem depois no menu
	{ "Abrindo o menu", function()
		return plr:GetAttribute("BB_MenuPronto") == true
	end, 30, true },
}

local tentar = false
botao.Activated:Connect(function()
	tentar = true
end)

local i = 1
while i <= #ETAPAS do
	local etapa = ETAPAS[i]
	status.Text = string.format("%s...  (%d de %d)", etapa[1], i, #ETAPAS)
	TweenService:Create(cheia, TweenInfo.new(0.3), { Size = UDim2.fromScale((i - 1) / #ETAPAS, 1) }):Play()
	local inicio = os.clock()
	local ok = etapa[2]()
	while not ok and os.clock() - inicio < etapa[3] do
		task.wait(0.2)
		ok = etapa[2]()
	end
	if ok or not etapa[4] then
		i += 1
	else
		-- falhou de verdade: diz qual etapa e espera o jogador pedir para tentar de novo
		status.Text = "Não carregou: " .. etapa[1] .. ". Confira a internet."
		status.TextColor3 = Color3.fromRGB(255, 150, 150)
		tentar = false
		botao.Visible = true
		while not tentar and not etapa[2]() do
			task.wait(0.2)
		end
		botao.Visible = false
		status.TextColor3 = Color3.fromRGB(230, 220, 255)
	end
end

TweenService:Create(cheia, TweenInfo.new(0.2), { Size = UDim2.fromScale(1, 1) }):Play()
status.Text = "PRONTO!"
task.wait(0.3)
vivo = false
for _, d in fundo:GetDescendants() do
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		TweenService:Create(d, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	elseif d:IsA("Frame") then
		TweenService:Create(d, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end
end
TweenService:Create(fundo, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
task.wait(0.7)
gui:Destroy()
