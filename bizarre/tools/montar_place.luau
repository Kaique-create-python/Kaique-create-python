-- BIZARRE BATTLEGROUNDS :: monta o arquivo do place (.rbxlx) a partir de bizarre/src
-- uso (na raiz do repositório): lune run bizarre/tools/montar_place.luau

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Color3 = roblox.Color3
local Enum = roblox.Enum

local RAIZ = "bizarre/src"
local SAIDA = "bizarre/dist/BB_place.rbxlx"

local game = Instance.new("DataModel")

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function carregar(caminho: string, pai)
	for _, nome in fs.readDir(caminho) do
		local completo = caminho .. "/" .. nome
		if fs.isDir(completo) then
			local pasta = Instance.new("Folder")
			pasta.Name = nome
			carregar(completo, pasta)
			pasta.Parent = pai
		elseif string.sub(nome, -5) == ".luau" then
			local base = string.gsub(nome, "%.luau$", "")
			local classe = "ModuleScript"
			if string.find(base, "%.server$") then
				classe = "Script"
				base = string.gsub(base, "%.server$", "")
			elseif string.find(base, "%.client$") then
				classe = "LocalScript"
				base = string.gsub(base, "%.client$", "")
			end
			local s = Instance.new(classe)
			s.Name = base
			s.Source = fs.readFile(completo)
			s.Parent = pai
		end
	end
end

-- Workspace: a cidade é montada pelo servidor quando ele liga
local ws = game:GetService("Workspace")
ws.StreamingEnabled = false
ws.FallenPartsDestroyHeight = -250
ws.Gravity = 196.2
local terreno = Instance.new("Terrain")
terreno.Parent = ws

-- luz de fim de tarde, cores vivas (clima "bizarro")
local luz = game:GetService("Lighting")
luz.Technology = Enum.Technology.Future
pcall(function()
	luz.LightingStyle = Enum.LightingStyle.Realistic
	luz.PrioritizeLightingQuality = false
end)
luz.ClockTime = 15.8
luz.GeographicLatitude = 22
luz.Brightness = 2.4
luz.Ambient = rgb(70, 60, 90)
luz.OutdoorAmbient = rgb(140, 128, 160)
luz.ColorShift_Top = rgb(255, 214, 170)
luz.ColorShift_Bottom = rgb(60, 40, 90)
luz.EnvironmentDiffuseScale = 0.6
luz.EnvironmentSpecularScale = 0.8
luz.GlobalShadows = true
luz.ShadowSoftness = 0.3
luz.ExposureCompensation = 0.1

local atm = Instance.new("Atmosphere")
atm.Density = 0.3
atm.Offset = 0.18
atm.Color = rgb(230, 190, 210)
atm.Decay = rgb(140, 100, 170)
atm.Glare = 0.35
atm.Haze = 1.4
atm.Parent = luz

local ceu = Instance.new("Sky")
ceu.SunAngularSize = 14
ceu.MoonAngularSize = 9
ceu.StarCount = 1500
ceu.Parent = luz

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.5
bloom.Size = 26
bloom.Threshold = 1.6
bloom.Parent = luz

local raios = Instance.new("SunRaysEffect")
raios.Intensity = 0.06
raios.Spread = 0.7
raios.Parent = luz

local cor = Instance.new("ColorCorrectionEffect")
cor.Name = "Vivo"
cor.Saturation = 0.18
cor.Contrast = 0.1
cor.TintColor = rgb(255, 248, 245)
cor.Parent = luz

local servicoMateriais = game:GetService("MaterialService")
pcall(function()
	servicoMateriais.Use2022Materials = true
end)

-- jogadores: entram pelo menu (o personagem só nasce quando aperta LUTAR)
local jogadores = game:GetService("Players")
jogadores.CharacterAutoLoads = false
jogadores.RespawnTime = 4
pcall(function()
	jogadores.MaxPlayers = 20
end)

local sp = game:GetService("StarterPlayer")
sp.CameraMaxZoomDistance = 32
sp.CameraMinZoomDistance = 4
sp.CharacterWalkSpeed = 18
sp.CharacterUseJumpPower = false
sp.CharacterJumpHeight = 7.6
sp.AutoJumpEnabled = false
sp.EnableMouseLockOption = true
sp.LoadCharacterAppearance = true
pcall(function()
	sp.GameSettingsAvatar = Enum.GameAvatarType.R15
end)
local sps = Instance.new("StarterPlayerScripts")
sps.Parent = sp
local scs = Instance.new("StarterCharacterScripts")
scs.Parent = sp
carregar(RAIZ .. "/StarterPlayerScripts", sps)
carregar(RAIZ .. "/StarterCharacterScripts", scs)

local sg = game:GetService("StarterGui")
sg.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
sg.ResetPlayerGuiOnSpawn = false

local som = game:GetService("SoundService")
som.RespectFilteringEnabled = true

carregar(RAIZ .. "/ReplicatedFirst", game:GetService("ReplicatedFirst"))
carregar(RAIZ .. "/ReplicatedStorage", game:GetService("ReplicatedStorage"))
carregar(RAIZ .. "/ServerScriptService", game:GetService("ServerScriptService"))

for _, nome in { "ServerStorage", "Teams", "Chat", "TextChatService", "LocalizationService", "TestService" } do
	pcall(function()
		game:GetService(nome)
	end)
end

local xml = roblox.serializePlace(game, true)
fs.writeDir("bizarre/dist")
fs.writeFile(SAIDA, xml)
local n = 0
for _, d in game:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		n += 1
	end
end
print(string.format("place gerado: %s (%d scripts, %d bytes)", SAIDA, n, #xml))
