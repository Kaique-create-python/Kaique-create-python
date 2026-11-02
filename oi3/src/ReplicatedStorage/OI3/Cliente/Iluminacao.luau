-- OI3 :: luz do dia (AJUSTE-6): a história começa à TARDE e o ritual é à NOITE.
-- A noite é o que vem no place; a tarde é aplicada aqui no aparelho e desfeita depois.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Iluminacao = {}

local noite: { [string]: any }? = nil
local atual = "noite"

local CAMPOS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ExposureCompensation", "EnvironmentDiffuseScale" }

local function guardarNoite()
	if noite then
		return
	end
	local n: { [string]: any } = {}
	for _, c in CAMPOS do
		n[c] = (Lighting :: any)[c]
	end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		n.atm = { atm.Density, atm.Color, atm.Decay, atm.Haze, atm.Glare }
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		n.cc = { cc.TintColor, cc.Saturation, cc.Contrast }
	end
	local raios = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if raios then
		n.raios = raios.Intensity
	end
	noite = n
end

-- valores da tarde (função pura: dá para testar)
function Iluminacao.valoresTarde(): { [string]: any }
	return {
		ClockTime = 16.7,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(78, 68, 60),
		OutdoorAmbient = Color3.fromRGB(134, 120, 106),
		ColorShift_Top = Color3.fromRGB(255, 212, 164),
		ExposureCompensation = 0.05,
		EnvironmentDiffuseScale = 0.8,
		atm = { 0.3, Color3.fromRGB(206, 178, 146), Color3.fromRGB(132, 104, 84), 1.4, 0.3 },
		cc = { Color3.fromRGB(255, 240, 222), -0.04, 0.08 },
		raios = 0.12,
	}
end

local function aplicar(v: { [string]: any }, tempo: number)
	local info = TweenInfo.new(tempo, Enum.EasingStyle.Sine)
	local alvo = {}
	for _, c in CAMPOS do
		if v[c] ~= nil then
			alvo[c] = v[c]
		end
	end
	if tempo > 0 then
		TweenService:Create(Lighting, info, alvo):Play()
	else
		for c, x in alvo do
			(Lighting :: any)[c] = x
		end
	end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm and v.atm then
		local a = { Density = v.atm[1], Color = v.atm[2], Decay = v.atm[3], Haze = v.atm[4], Glare = v.atm[5] }
		if tempo > 0 then
			TweenService:Create(atm, info, a):Play()
		else
			for k, x in a do
				(atm :: any)[k] = x
			end
		end
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc and v.cc then
		cc.TintColor, cc.Saturation, cc.Contrast = v.cc[1], v.cc[2], v.cc[3]
	end
	local raios = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if raios and v.raios then
		raios.Intensity = v.raios
	end
end

function Iluminacao.tarde(tempo: number?)
	guardarNoite()
	atual = "tarde"
	aplicar(Iluminacao.valoresTarde(), tempo or 0)
end

function Iluminacao.noite(tempo: number?)
	if not noite then
		return
	end
	atual = "noite"
	aplicar(noite, tempo or 0)
end

function Iluminacao.atual(): string
	return atual
end

return Iluminacao
