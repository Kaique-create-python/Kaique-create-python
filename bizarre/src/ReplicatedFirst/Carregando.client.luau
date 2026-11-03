-- BIZARRE BATTLEGROUNDS :: tela de carregamento (aparece na hora; some só quando o menu está pronto)
-- Assim nunca fica aquela tela preta no começo.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
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
fundo.BackgroundColor3 = Color3.fromRGB(14, 6, 30)
fundo.BorderSizePixel = 0
fundo.Parent = gui
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(70, 30, 140), Color3.fromRGB(12, 4, 26))
grad.Rotation = 120
grad.Parent = fundo

local function texto(t: string, tam: UDim2, pos: UDim2, cor: Color3, rot: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = tam
	l.Position = pos
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.BackgroundTransparency = 1
	l.Text = t
	l.Font = Enum.Font.Bangers
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

local titulo = texto("BIZARRE", UDim2.fromScale(0.6, 0.2), UDim2.fromScale(0.5, 0.36), Color3.fromRGB(255, 206, 64), -4)
texto("BATTLEGROUNDS", UDim2.fromScale(0.5, 0.1), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(255, 255, 255), -2)
local status = texto("carregando a cidade...", UDim2.fromScale(0.6, 0.06), UDim2.fromScale(0.5, 0.82), Color3.fromRGB(210, 190, 255))
local dicas = {
	"Dica: aperte BLOQ bem na hora do golpe para dar PARRY.",
	"Dica: atordoado? DASH faz a EVASIVA e você escapa do combo.",
	"Dica: o 4º soco arremessa o inimigo através das paredes!",
	"Dica: a barra de DESPERTAR enche batendo e apanhando.",
	"Dica: CHORINHO conserta o mapa... em cima dos inimigos.",
	"Dica: BOSSA NOVA desperto pode PARAR O TEMPO.",
}
local dica = texto(dicas[math.random(1, #dicas)], UDim2.fromScale(0.8, 0.05), UDim2.fromScale(0.5, 0.9), Color3.fromRGB(255, 255, 255))

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
			l.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.36, 0.42 + math.sin(a) * 0.26)
			l.Rotation = math.sin(t * 3 + i) * 15
			l.TextTransparency = 0.2 + math.sin(t * 2 + i) * 0.2
		end
		titulo.Rotation = -4 + math.sin(t * 2) * 1.5
		task.wait(1 / 30)
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
status.Text = "acordando os Stands..."
local inicio = os.clock()
-- espera o menu avisar que está pronto (no máximo 40 s)
while not plr:GetAttribute("BB_MenuPronto") and os.clock() - inicio < 40 do
	task.wait(0.2)
	if os.clock() - inicio > 6 then
		dica.Text = dicas[(math.floor(os.clock() / 4) % #dicas) + 1]
	end
end
status.Text = "PRONTO!"
task.wait(0.3)
vivo = false
for _, d in fundo:GetDescendants() do
	if d:IsA("TextLabel") then
		TweenService:Create(d, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end
end
TweenService:Create(fundo, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
task.wait(0.7)
gui:Destroy()
