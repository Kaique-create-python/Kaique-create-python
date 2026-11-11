--!strict
-- Céu, iluminação, clima e gravidade com "pilha" de alterações temporárias.
-- Cada acontecimento empurra uma alteração com prazo; ao terminar, o estado é
-- recalculado a partir do ciclo dia/noite base. Nada fica preso (ex.: gravidade
-- zero sempre volta ao normal, mesmo se dois pedidos se sobrepuserem).

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.IdeiasShared.Config)

local Ambience = {}

local BASE_GRAVITY = 196.2

type Override = { id: number, expires: number, props: { [string]: any }, priority: number }
local overrides: { Override } = {}
local nextId = 0
local cycleStart = os.clock()
local atmosphere: Atmosphere? = nil

local BASE = {
	Brightness = 2.8,
	Ambient = Color3.fromRGB(58, 58, 68),
	OutdoorAmbient = Color3.fromRGB(140, 138, 150),
	FogEnd = 100000,
	ExposureCompensation = 0,
	AtmosphereDensity = 0.24,
	AtmosphereColor = Color3.fromRGB(199, 220, 255),
	AtmosphereDecay = Color3.fromRGB(106, 120, 160),
	AtmosphereHaze = 1.2,
	Gravity = BASE_GRAVITY,
	Clima = "",
}

function Ambience.setup()
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		local a = Instance.new("Atmosphere")
		a.Density = BASE.AtmosphereDensity
		a.Offset = 0.15
		a.Color = BASE.AtmosphereColor
		a.Decay = BASE.AtmosphereDecay
		a.Glare = 0.4
		a.Haze = BASE.AtmosphereHaze
		a.Parent = Lighting
		atmosphere = a
	end
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.SunAngularSize = 14
		sky.MoonAngularSize = 9
		sky.StarCount = 3500
		sky.Parent = Lighting
	end
	if not Lighting:FindFirstChild("BrilhoIdeias") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "BrilhoIdeias"
		bloom.Intensity = 0.7
		bloom.Size = 26
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "CorIdeias"
		cc.Saturation = 0.2
		cc.Contrast = 0.1
		cc.TintColor = Color3.fromRGB(255, 251, 244)
		-- reflexos e luz ambiente mais bonitos (visual de desenho animado)
		Lighting.EnvironmentDiffuseScale = 1
		Lighting.EnvironmentSpecularScale = 1
		cc.Parent = Lighting
		local rays = Instance.new("SunRaysEffect")
		rays.Name = "RaiosIdeias"
		rays.Intensity = 0.05
		rays.Spread = 0.7
		rays.Parent = Lighting
	end
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		local c = Instance.new("Clouds")
		c.Cover = 0.55
		c.Density = 0.6
		c.Color = Color3.fromRGB(250, 252, 255)
		c.Parent = Workspace.Terrain
	end
end

local function baseClock(): number
	local dayLen = Config.World.DayLengthMinutes * 60
	local t = ((os.clock() - cycleStart) / dayLen) % 1
	-- dia mais longo que a noite: 06h -> 20h ocupa 70% do ciclo
	if t < 0.7 then
		return 6 + t / 0.7 * 14
	end
	return (20 + (t - 0.7) / 0.3 * 10) % 24
end

local function apply()
	local now = os.clock()
	for i = #overrides, 1, -1 do
		if now >= overrides[i].expires then
			table.remove(overrides, i)
		end
	end
	table.sort(overrides, function(a, b)
		return a.priority < b.priority
	end)
	local state = table.clone(BASE)
	state.ClockTime = baseClock()
	for _, o in overrides do
		for k, v in o.props do
			state[k] = v
		end
	end
	Lighting.ClockTime = state.ClockTime
	Lighting.Brightness = state.Brightness
	Lighting.Ambient = state.Ambient
	Lighting.OutdoorAmbient = state.OutdoorAmbient
	Lighting.FogEnd = state.FogEnd
	Lighting.ExposureCompensation = state.ExposureCompensation
	if atmosphere then
		atmosphere.Density = state.AtmosphereDensity
		atmosphere.Color = state.AtmosphereColor
		atmosphere.Decay = state.AtmosphereDecay
		atmosphere.Haze = state.AtmosphereHaze
	end
	if math.abs(Workspace.Gravity - state.Gravity) > 0.01 then
		Workspace.Gravity = state.Gravity
	end
	Workspace:SetAttribute("Clima", state.Clima)
end

-- empurra uma alteração temporária; retorna função que a remove antes do prazo
function Ambience.push(props: { [string]: any }, duration: number, priority: number?): () -> ()
	nextId += 1
	local o: Override = { id = nextId, expires = os.clock() + duration, props = props, priority = priority or 1 }
	table.insert(overrides, o)
	apply()
	return function()
		local i = table.find(overrides, o)
		if i then
			table.remove(overrides, i)
			apply()
		end
	end
end

function Ambience.clearAll()
	table.clear(overrides)
	apply()
end

function Ambience.clock(): number
	return Lighting.ClockTime
end

function Ambience.start()
	Ambience.setup()
	task.spawn(function()
		while true do
			apply()
			task.wait(1)
		end
	end)
end

Ambience.BaseGravity = BASE_GRAVITY
Ambience._tween = TweenService

return Ambience
