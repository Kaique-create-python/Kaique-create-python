-- BIZARRE BATTLEGROUNDS :: monta o arquivo do place a partir de bizarre/src
-- Base: o mapa Morioh V2 (bizarre/assets/morioh.rbxl, feito no ChatGPT e convertido para binário).
-- Saída: bizarre/dist/BB_place.rbxl (binário, ~2,5 MB). Sem o mapa, sai uma cidade gerada.
-- uso (na raiz do repositório): lune run bizarre/tools/montar_place.luau

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Color3 = roblox.Color3
local Enum = roblox.Enum

local RAIZ = "bizarre/src"
local SAIDA = "bizarre/dist/BB_place.rbxl"
local MAPA = "bizarre/assets/morioh.rbxl"
-- o instalador troca este texto pelo número do áudio das vozes (mesmo tamanho: 64 letras)
local MARCADOR_VOZES = "BBVOZ" .. string.rep("_", 59)
-- AJUSTE-8: o áudio dos sons do anime (separado) e as imagens do Canva ("logo fundo carregando")
local MARCADOR_ANIME = "BBVZA" .. string.rep("_", 59)
local MARCADOR_IMAGENS = "BBIMG" .. string.rep("_", 59)

local game
local comMapa = fs.isFile(MAPA)
if comMapa then
	game = roblox.deserializePlace(fs.readFile(MAPA))
else
	game = Instance.new("DataModel")
end

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

-- Workspace: com o Morioh, o mapa já vem pronto (StreamingEnabled ligado, raio 128/512)
local ws = game:GetService("Workspace")
if comMapa then
	ws.StreamingEnabled = true
	pcall(function()
		ws.StreamingMinRadius = 128
		ws.StreamingTargetRadius = 512
	end)
else
	ws.StreamingEnabled = false -- a cidade gerada é montada pelo servidor quando ele liga
end
ws.FallenPartsDestroyHeight = -250
ws.Gravity = 196.2
if not ws:FindFirstChildOfClass("Terrain") then
	local terreno = Instance.new("Terrain")
	terreno.Parent = ws
end

-- luz: a paleta e a atmosfera de Morioh (do mapa) + iluminação Future, céu, brilho e raios de sol
local luz = game:GetService("Lighting")
luz.Technology = Enum.Technology.Future
pcall(function()
	luz.LightingStyle = Enum.LightingStyle.Realistic
	luz.PrioritizeLightingQuality = false
end)
luz.GlobalShadows = true
luz.ShadowSoftness = 0.25
luz.EnvironmentDiffuseScale = 0.5
luz.EnvironmentSpecularScale = 0.6
if not comMapa then
	luz.ClockTime = 15.8
	luz.GeographicLatitude = 22
	luz.Brightness = 2.4
	luz.Ambient = rgb(70, 60, 90)
	luz.OutdoorAmbient = rgb(140, 128, 160)
	luz.ExposureCompensation = 0.1
end
luz.ColorShift_Top = rgb(255, 222, 190)
luz.ColorShift_Bottom = rgb(70, 50, 90)

if not luz:FindFirstChildOfClass("Atmosphere") then
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.18
	atm.Color = rgb(230, 190, 210)
	atm.Decay = rgb(140, 100, 170)
	atm.Glare = 0.35
	atm.Haze = 1.4
	atm.Parent = luz
end

if not luz:FindFirstChildOfClass("Sky") then
	local ceu = Instance.new("Sky")
	ceu.SunAngularSize = 14
	ceu.MoonAngularSize = 9
	ceu.StarCount = 1500
	ceu.Parent = luz
end

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.4
bloom.Size = 24
bloom.Threshold = 1.8
bloom.Parent = luz

local raios = Instance.new("SunRaysEffect")
raios.Intensity = 0.05
raios.Spread = 0.6
raios.Parent = luz

if not luz:FindFirstChildOfClass("ColorCorrectionEffect") then
	local cor = Instance.new("ColorCorrectionEffect")
	cor.Name = "Vivo"
	cor.Saturation = 0.18
	cor.Contrast = 0.1
	cor.TintColor = rgb(255, 248, 245)
	cor.Parent = luz
end

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
	sp.GameSettingsAvatar = Enum.GameAvatarType.R6
end)
local sps = Instance.new("StarterPlayerScripts")
sps.Parent = sp
local scs = Instance.new("StarterCharacterScripts")
scs.Parent = sp
carregar(RAIZ .. "/StarterPlayerScripts", sps)
carregar(RAIZ .. "/StarterCharacterScripts", scs)
-- AJUSTE-11: marca os scripts do personagem como "nossos": qualquer outro "Animate" (o padrão do
-- Roblox) é tirado pelo servidor e pelo celular, e o andar fica sendo o do jogo
for _, sc in scs:GetChildren() do
	sc:SetAttribute("BB_Nosso", true)
end

local sg = game:GetService("StarterGui")
sg.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
sg.ResetPlayerGuiOnSpawn = false

local som = game:GetService("SoundService")
som.RespectFilteringEnabled = true

carregar(RAIZ .. "/ReplicatedFirst", game:GetService("ReplicatedFirst"))
carregar(RAIZ .. "/ReplicatedStorage", game:GetService("ReplicatedStorage"))
carregar(RAIZ .. "/ServerScriptService", game:GetService("ServerScriptService"))

local vozes = Instance.new("StringValue")
vozes.Name = "BB_Vozes"
vozes.Value = MARCADOR_VOZES
vozes.Parent = game:GetService("ReplicatedStorage")
for nome, marcador in { BB_VozesAnime = MARCADOR_ANIME, BB_Imagens = MARCADOR_IMAGENS } do
	local v = Instance.new("StringValue")
	v.Name = nome
	v.Value = marcador
	v.Parent = game:GetService("ReplicatedStorage")
end

for _, nome in { "ServerStorage", "Teams", "Chat", "TextChatService", "LocalizationService", "TestService" } do
	pcall(function()
		game:GetService(nome)
	end)
end

local dados = roblox.serializePlace(game, false)
fs.writeDir("bizarre/dist")
fs.writeFile(SAIDA, dados)
local n = 0
for _, d in game:GetChildren() do
	if d.Name ~= "Workspace" then
		for _, x in d:GetDescendants() do
			if x:IsA("LuaSourceContainer") then
				n += 1
			end
		end
	end
end
print(string.format("place gerado: %s (%d scripts, %d bytes, mapa Morioh: %s)", SAIDA, n, #dados, tostring(comMapa)))
