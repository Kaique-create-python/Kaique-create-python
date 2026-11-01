-- OI3 :: tela de carregamento (substitui a padrão do Roblox)

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local sg = Instance.new("ScreenGui")
sg.Name = "OI3_Carregando"
sg.IgnoreGuiInset = true
sg.DisplayOrder = 100
sg.ResetOnSpawn = false
pcall(function()
	sg.ScreenInsets = Enum.ScreenInsets.None
end)

local fundo = Instance.new("Frame")
fundo.BackgroundColor3 = Color3.fromRGB(6, 6, 8)
fundo.BorderSizePixel = 0
fundo.Size = UDim2.fromScale(1, 1)
fundo.Parent = sg

local titulo = Instance.new("TextLabel")
titulo.BackgroundTransparency = 1
titulo.AnchorPoint = Vector2.new(0.5, 0.5)
titulo.Position = UDim2.fromScale(0.5, 0.45)
titulo.Size = UDim2.fromScale(0.6, 0.26)
titulo.TextScaled = true
titulo.Text = "OI3"
titulo.FontFace = Font.new("rbxasset://fonts/families/Creepster.json")
titulo.TextColor3 = Color3.fromRGB(220, 214, 204)
titulo.Parent = fundo

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.AnchorPoint = Vector2.new(0.5, 0)
sub.Position = UDim2.fromScale(0.5, 0.62)
sub.Size = UDim2.fromScale(0.5, 0.05)
sub.TextScaled = true
sub.Text = "carregando"
sub.FontFace = Font.new("rbxasset://fonts/families/SpecialElite.json")
sub.TextColor3 = Color3.fromRGB(150, 142, 132)
sub.Parent = fundo

sg.Parent = pg

local t0 = os.clock()
local pontos = 0
while not lp:GetAttribute("OI3_Pronto") and os.clock() - t0 < 40 do
	pontos = (pontos + 1) % 4
	sub.Text = "carregando" .. string.rep(".", pontos)
	titulo.TextTransparency = 0.1 + math.abs(math.sin(os.clock() * 1.6)) * 0.25
	task.wait(0.35)
end

local info = TweenInfo.new(0.9, Enum.EasingStyle.Sine)
TweenService:Create(fundo, info, { BackgroundTransparency = 1 }):Play()
TweenService:Create(titulo, info, { TextTransparency = 1 }):Play()
TweenService:Create(sub, info, { TextTransparency = 1 }):Play()
task.wait(1)
sg:Destroy()
