-- OI3 :: monta o arquivo do place (.rbxlx) a partir de oi3/src
-- uso: lune run oi3/tools/montar_place.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Color3 = roblox.Color3
local Enum = roblox.Enum

local RAIZ = "oi3/src"
local SAIDA = "oi3/dist/OI3_place.rbxlx"

local game = Instance.new("DataModel")

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- carrega uma pasta de código para dentro de uma instância
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

-- Workspace (o mapa é montado pelo servidor ao iniciar)
local ws = game:GetService("Workspace")
ws.StreamingEnabled = false
local terreno = Instance.new("Terrain")
terreno.Parent = ws

-- Iluminação noturna (Future)
local luz = game:GetService("Lighting")
luz.Technology = Enum.Technology.Future
luz.ClockTime = 22.3
luz.GeographicLatitude = 30
luz.Brightness = 1.6
luz.Ambient = rgb(22, 24, 32)
luz.OutdoorAmbient = rgb(48, 52, 70)
luz.ColorShift_Top = rgb(110, 124, 170)
luz.ColorShift_Bottom = rgb(0, 0, 0)
luz.EnvironmentDiffuseScale = 0.5
luz.EnvironmentSpecularScale = 1
luz.GlobalShadows = true
luz.ShadowSoftness = 0.25
luz.ExposureCompensation = 0.25

local atm = Instance.new("Atmosphere")
atm.Density = 0.38
atm.Offset = 0.24
atm.Color = rgb(98, 110, 134)
atm.Decay = rgb(40, 46, 64)
atm.Glare = 0.12
atm.Haze = 2.2
atm.Parent = luz

local ceu = Instance.new("Sky")
ceu.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
ceu.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
ceu.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
ceu.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
ceu.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
ceu.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
ceu.StarCount = 5000
ceu.MoonAngularSize = 15
ceu.CelestialBodiesShown = true
ceu.Parent = luz

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.65
bloom.Size = 30
bloom.Threshold = 1.25
bloom.Parent = luz

local cor = Instance.new("ColorCorrectionEffect")
cor.Saturation = -0.18
cor.Contrast = 0.14
cor.TintColor = rgb(222, 230, 255)
cor.Parent = luz

-- profundidade de campo leve e raios da lua (o modo "efeitos leves" desliga)
local dof = Instance.new("DepthOfFieldEffect")
dof.FarIntensity = 0.16
dof.FocusDistance = 28
dof.InFocusRadius = 34
dof.NearIntensity = 0
dof.Parent = luz
local raios = Instance.new("SunRaysEffect")
raios.Intensity = 0.04
raios.Spread = 0.55
raios.Parent = luz

-- materiais novos do Roblox (madeira, tijolo e pedra bem mais bonitos)
pcall(function()
	game:GetService("MaterialService").Use2022Materials = true
end)

-- Jogadores: o personagem só aparece depois do menu/abertura
local jogadores = game:GetService("Players")
jogadores.CharacterAutoLoads = false

local sp = game:GetService("StarterPlayer")
sp.CameraMaxZoomDistance = 14
sp.CameraMinZoomDistance = 0.5
sp.CharacterWalkSpeed = 12
sp.CharacterUseJumpPower = false
sp.CharacterJumpHeight = 4.5
sp.AutoJumpEnabled = false
local sps = Instance.new("StarterPlayerScripts")
sps.Parent = sp
local scs = Instance.new("StarterCharacterScripts")
scs.Parent = sp
carregar(RAIZ .. "/StarterPlayerScripts", sps)

local sg = game:GetService("StarterGui")
sg.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
sg.ResetPlayerGuiOnSpawn = false

local som = game:GetService("SoundService")
som.RespectFilteringEnabled = true

-- Código
carregar(RAIZ .. "/ReplicatedFirst", game:GetService("ReplicatedFirst"))
carregar(RAIZ .. "/ReplicatedStorage", game:GetService("ReplicatedStorage"))
carregar(RAIZ .. "/ServerScriptService", game:GetService("ServerScriptService"))

-- serviços padrão que o Roblox espera existir
for _, nome in { "ServerStorage", "Teams", "Chat", "TextChatService", "LocalizationService", "TestService" } do
	pcall(function()
		game:GetService(nome)
	end)
end

local xml = roblox.serializePlace(game, true)
fs.writeDir("oi3/dist")
fs.writeFile(SAIDA, xml)
local n = 0
for _, d in game:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		n += 1
	end
end
print(string.format("place gerado: %s (%d scripts, %d bytes)", SAIDA, n, #xml))
