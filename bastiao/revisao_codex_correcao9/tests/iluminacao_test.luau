-- Exercita o LocalScript de produção com os mesmos nomes e valores do Sector7.
local Harness = require("./client_harness")
local roblox = require("@lune/roblox")
local h = Harness.new()
local rgb = roblox.Color3.fromRGB
local v = roblox.Vector3.new
local enum = roblox.Enum
local lighting = h:new("Lighting", "Lighting", h:new("DataModel"))
h.services.Lighting = lighting
lighting.Ambient = rgb(12, 14, 14)
lighting.ExposureCompensation = -0.1
lighting.EnvironmentSpecularScale = 0.35
lighting.ShadowSoftness = 0.12
local atmosphere = h:new("Atmosphere", "Atmosphere", lighting)
atmosphere.Density = 0.22
atmosphere.Color = rgb(30, 34, 33)
local grade = h:new("ColorCorrectionEffect", "S7BodycamGrade", lighting)
grade.Brightness = 0.01
grade.TintColor = rgb(231, 237, 235)
grade.Saturation = -0.3
grade.Contrast = 0.2
local bloom = h:new("BloomEffect", "S7BodycamBloom", lighting)
bloom.Intensity = 0.58
bloom.Size = 38
bloom.Threshold = 1.05
local lens = h:new("DepthOfFieldEffect", "S7BodycamLens", lighting)
lens.Enabled = true
lens.FarIntensity = 0.06
lens.NearIntensity = 0.45
local hit = h:new("BlurEffect", "S7BastiaoImpactoBlur", lighting)
hit.Size = 11
local world = h:new("Model", "Sector7World", h.workspace)
local lamp = h:new("PointLight", "LampadaOriginal", world)
lamp.Color = rgb(255, 244, 220)
local character, root, human = h:character("Soldado")
root.Position = v(-58, 4, -278)
h.player.Character = character
h.workspace.CurrentCamera.CameraType = enum.CameraType.Custom
h.workspace.CurrentCamera.CameraSubject = human
local config = { SavedQualityLevel = enum.SavedQualitySetting.Automatic }
h.environment.UserSettings = function()
	return { GetService = function(_, name)
		assert(name == "UserGameSettings")
		return config
	end }
end
h.environment.Instance.new = function() error("A iluminação usa apenas efeitos e luzes existentes") end
local scriptNode = h:new("LocalScript", "BastiaoIluminacao", h.player)
h.environment.script = scriptNode
function scriptNode.Destroying:Once(callback)
	local connection
	connection = self:Connect(function()
		connection:Disconnect()
		callback()
	end)
	return connection
end
h.services.UserInputService.TouchEnabled = true
h.services.UserInputService.MouseEnabled = false
h:load("src/client/BastiaoIluminacao.client.luau")
local function tick(steps)
	for _ = 1, steps do h:tick(0.125) end
end

tick(20)
assert(lighting.Ambient.B > lighting.Ambient.R and lighting.Ambient.R > 12 / 255, "corredor frio com preenchimento")
assert(atmosphere.Density > 0.22, "corredor recebe profundidade")
assert(not lens.Enabled and bloom.Size == 16, "automático no celular usa perfil leve")
assert(lighting.ExposureCompensation == -0.1 and grade.Saturation == -0.3 and grade.Contrast == 0.2)
assert(bloom.Intensity == 0.58 and hit.Size == 11 and lamp.Color == rgb(255, 244, 220), "efeitos antigos e mapa permanecem com seus donos")

-- A lanterna pode ficar disponível depois do personagem. O feixe acompanha o sistema anterior.
local vest = h:new("Attachment", "S7VestLight", h.workspace.Terrain)
local hotspot = h:new("SpotLight", "Hotspot", vest)
hotspot.Brightness, hotspot.Enabled, hotspot.Range, hotspot.Shadows = 6, false, 60, true
local spill = h:new("SpotLight", "Spill", vest)
spill.Brightness, spill.Enabled = 0.45, false
tick(16)
assert(hotspot.Brightness == 4.9 and not hotspot.Enabled and hotspot.Range == 60 and hotspot.Shadows)
assert(spill.Brightness == 0.7 and not spill.Enabled)

local corridorR = lighting.Ambient.R
root.Position = v(88, 4, -320)
tick(1)
assert(lighting.Ambient.R > corridorR and lighting.Ambient.R < 31 / 255, "a oficina entra por transição")
tick(18)
assert(lighting.Ambient.R > lighting.Ambient.B and atmosphere.Density < 0.20, "oficina mais quente e clara no ar")
root.Position = v(-88, 4, -320)
tick(18)
assert(grade.TintColor.G > grade.TintColor.R and lighting.Ambient.G > lighting.Ambient.R, "enfermaria fria")

config.SavedQualityLevel = enum.SavedQualitySetting.QualityLevel8
tick(18)
assert(lens.Enabled and lens.NearIntensity < 0.24 and bloom.Size == 25, "qualidade maior mantém lente mais nítida")
config.SavedQualityLevel = enum.SavedQualitySetting.QualityLevel1
tick(1)
assert(not lens.Enabled, "nível baixo entra no perfil leve")

-- Outro script assume uma propriedade. O passe deve ceder e respeitar a nova cor na saída.
local authoredTint = rgb(255, 220, 210)
grade.TintColor = authoredTint
tick(3)
assert(grade.TintColor == authoredTint)
h.player:SetAttribute("S7LensFilter", false)
tick(1)
assert(not lens.Enabled and lighting.Ambient ~= rgb(12, 14, 14), "Grão e vinheta têm o mesmo significado")
root.Position = v(0, 4, 65)
tick(1)
assert(lighting.Ambient == rgb(12, 14, 14) and atmosphere.Density == 0.22)
assert(grade.TintColor == authoredTint and grade.Brightness == 0.01 and lens.Enabled and bloom.Size == 38)
assert(hotspot.Brightness == 6 and spill.Brightness == 0.45)

root.Position = v(-88, 4, -320)
tick(18)
h.workspace.CurrentCamera.CameraType = enum.CameraType.Scriptable
tick(1)
assert(lighting.Ambient == rgb(12, 14, 14) and lens.Enabled, "devolve as propriedades durante o jumpscare")
h.workspace.CurrentCamera.CameraType = enum.CameraType.Custom
human.Health = 0
tick(1)
assert(lighting.Ambient == rgb(12, 14, 14), "não atua no personagem morto")
local novo, newRoot, newHuman = h:character("Respawn")
h.player.Character = novo
newRoot.Position = v(0, 4, 12)
h.workspace.CurrentCamera.CameraSubject = newHuman
tick(18)
assert(not lens.Enabled and lighting.Ambient ~= rgb(12, 14, 14), "retoma após respawn")
scriptNode:Destroy()
assert(lens.Enabled and lighting.Ambient == rgb(12, 14, 14), "limpeza restaura a luz e a lente")
for _, connection in h.connections do assert(not connection.Connected, "conexão ficou pendurada") end
print("PASS iluminação por setor, perfil leve, preservação e ciclo de vida")
