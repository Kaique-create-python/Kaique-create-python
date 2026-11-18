--!strict
-- Ajuste local da luz do bunker. A exposição, os giroflexes e a lanterna
-- continuam ligados aos controladores existentes da bodycam e da história.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local settingsOk, settings = pcall(function()
	return UserSettings():GetService("UserGameSettings")
end)
local rgb = Color3.fromRGB
local UPDATE_INTERVAL = 0.125

-- Coordenadas e dimensões dos interiores medidos no Sector7World.
-- O peso só cresce depois que o jogador entra, para não tingir o corredor.
local CORREDOR = {
	ambient = rgb(19, 24, 29), tint = rgb(238, 246, 254), grade = 0.029,
	air = rgb(43, 52, 60), density = 0.252, specular = 0.42,
}
local ENFERMARIA = {
	ambient = rgb(19, 28, 28), tint = rgb(232, 251, 244), grade = 0.038,
	air = rgb(41, 54, 51), density = 0.181, specular = 0.38,
}
local OFICINA = {
	ambient = rgb(31, 25, 19), tint = rgb(253, 245, 227), grade = 0.04,
	air = rgb(55, 48, 39), density = 0.168, specular = 0.40,
}

local function interior(position: Vector3)
	local depth = math.min(24 - math.abs(math.abs(position.X) - 88), 22 - math.abs(position.Z + 320))
	local weight = math.clamp(depth / 9, 0, 1)
	return if position.X < 0 then ENFERMARIA else OFICINA, weight * weight * (3 - 2 * weight)
end

local function lerp(a: number, b: number, weight: number): number
	return a + (b - a) * weight
end

local function lightProfile(): boolean
	local quality = if settingsOk then settings.SavedQualityLevel.Value else 0
	if quality ~= 0 then return quality <= 4 end
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

type Override = { original: any, applied: any, active: boolean, stamp: number }
local overrides: { [Instance]: { [string]: Override } } = {}
local stamp = 0

-- As propriedades que outro controlador passar a escrever são liberadas.
-- Também guardamos os valores exatos lidos de volta do motor para restaurar
-- apenas os valores que esta camada aplicou.
local function adjust(object: Instance?, key: string, target: any, alpha: number)
	if not object then return end
	local item = object :: any
	local current = item[key]
	local props = overrides[object]
	if not props then
		props = {}
		overrides[object] = props
	end
	local saved = props[key]
	if not saved then
		saved = { original = current, applied = current, active = true, stamp = stamp }
		props[key] = saved
	end
	saved.stamp = stamp
	if current ~= saved.applied then saved.active = false end
	if not saved.active or current == target then return end

	local value = target
	if typeof(target) == "Color3" then
		local distance = math.max(math.abs(current.R - target.R), math.abs(current.G - target.G), math.abs(current.B - target.B))
		if distance > 0.001 then value = current:Lerp(target, alpha) end
	elseif type(target) == "number" and math.abs(current - target) > 0.001 then
		value = lerp(current, target, alpha)
	end
	if current ~= value then
		item[key] = value
		saved.applied = item[key]
	end
end

local function releaseUnused()
	for object, props in overrides do
		for key, saved in props do
			if saved.stamp ~= stamp or object.Parent == nil then
				local item = object :: any
				if object.Parent and saved.active and item[key] == saved.applied then item[key] = saved.original end
				props[key] = nil
			end
		end
		if next(props) == nil then overrides[object] = nil end
	end
end

local function named(parent: Instance?, name: string, class: string): Instance?
	local object = parent and parent:FindFirstChild(name)
	return if object and object:IsA(class) then object else nil
end

local function viewPosition(): Vector3?
	if not player then return nil end
	if not Workspace:FindFirstChild("Sector7World") then return nil end
	if player:GetAttribute("BastiaoCapturaAnimacao") then return nil end
	local camera = Workspace.CurrentCamera
	local character = player.Character
	if not camera or camera.CameraType ~= Enum.CameraType.Custom or not character then return nil end
	local human = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not human or human.Health <= 0 or camera.CameraSubject ~= human or not root or not root:IsA("BasePart") then return nil end
	local position = root.Position
	if math.abs(position.X) > 120 or position.Y < -3 or position.Y > 20 or position.Z < -566 or position.Z > 28 then
		return nil
	end
	return position
end

local function update(alpha: number)
	stamp += 1
	local position = viewPosition()
	if position then
		local zone, weight = interior(position)
		local light = lightProfile()
		adjust(Lighting, "Ambient", CORREDOR.ambient:Lerp(zone.ambient, weight), alpha)
		adjust(Lighting, "EnvironmentSpecularScale", lerp(CORREDOR.specular, zone.specular, weight), alpha)
		adjust(Lighting, "ShadowSoftness", 0.24, alpha)

		local air = Lighting:FindFirstChildOfClass("Atmosphere")
		adjust(air, "Density", lerp(CORREDOR.density, zone.density, weight), alpha)
		adjust(air, "Color", CORREDOR.air:Lerp(zone.air, weight), alpha)

		local grade = named(Lighting, "S7BodycamGrade", "ColorCorrectionEffect")
		adjust(grade, "Brightness", lerp(CORREDOR.grade, zone.grade, weight), alpha)
		adjust(grade, "TintColor", CORREDOR.tint:Lerp(zone.tint, weight), alpha)
		local bloom = named(Lighting, "S7BodycamBloom", "BloomEffect")
		adjust(bloom, "Size", if light then 16 else 25, 1)
		local lens = named(Lighting, "S7BodycamLens", "DepthOfFieldEffect")
		if light then
			adjust(lens, "Enabled", false, 1)
		else
			adjust(lens, "NearIntensity", 0.19, alpha)
			adjust(lens, "FarIntensity", 0.02, alpha)
		end

		local vest = named(Workspace.Terrain, "S7VestLight", "Attachment")
		adjust(named(vest, "Hotspot", "SpotLight"), "Brightness", 4.9, alpha)
		adjust(named(vest, "Spill", "SpotLight"), "Brightness", 0.7, alpha)
	end
	releaseUnused()
end

local elapsed = 0
local heartbeat = RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < UPDATE_INTERVAL then return end
	local alpha = 1 - math.exp(-math.min(elapsed, 0.25) * 5.5)
	elapsed = 0
	update(alpha)
end)
script.Destroying:Once(function()
	heartbeat:Disconnect()
	stamp += 1
	releaseUnused()
end)
