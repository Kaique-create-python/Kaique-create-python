--!strict
-- Configurações locais do jogador (gráficos, câmera, som, notificações).
-- Guardadas como atributos no Player: persistem durante a sessão.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local Settings = {}

local player = Players.LocalPlayer
local listeners: { (string, any) -> () } = {}

Settings.values = {
	quality = "medio", -- baixo | medio | alto
	camera = "normal", -- normal | primeira | cinematica
	shake = true,
	sounds = true,
	notifications = true,
	uiScale = 1,
	cutscenes = true, -- câmera cinematográfica quando algo grande aparece
	soundSource = "auto", -- auto (ElevenLabs quando aprovado) | roblox (sempre os embutidos)
}

local QUALITY = {
	baixo = { particles = 0.35, post = false, shadows = false, weather = 0.4 },
	medio = { particles = 0.7, post = true, shadows = true, weather = 0.7 },
	alto = { particles = 1, post = true, shadows = true, weather = 1 },
}

function Settings.quality(): { particles: number, post: boolean, shadows: boolean, weather: number }
	return QUALITY[Settings.values.quality] or QUALITY.medio
end

local function applyGraphics()
	local q = Settings.quality()
	-- mudanças em Lighting feitas no cliente valem só para este jogador
	for _, name in { "BrilhoIdeias", "RaiosIdeias", "CorIdeias" } do
		local e = Lighting:FindFirstChild(name)
		if e and e:IsA("PostEffect") then
			e.Enabled = q.post
		end
	end
	Lighting.GlobalShadows = q.shadows
end

local function applyCamera()
	if Settings.values.camera == "primeira" then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
	end
end

function Settings.set(key: string, value: any)
	(Settings.values :: any)[key] = value
	player:SetAttribute("Cfg_" .. key, value)
	if key == "quality" then
		applyGraphics()
	elseif key == "camera" then
		applyCamera()
	end
	for _, fn in listeners do
		task.spawn(fn, key, value)
	end
end

function Settings.onChanged(fn: (string, any) -> ())
	table.insert(listeners, fn)
end

function Settings.init()
	-- celulares começam no médio; telas grandes no alto
	local cam = workspace.CurrentCamera
	if cam and cam.ViewportSize.X > 1300 then
		Settings.values.quality = "alto"
	end
	for key, value in Settings.values do
		local saved = player:GetAttribute("Cfg_" .. key)
		if saved ~= nil then
			(Settings.values :: any)[key] = saved
		end
	end
	applyGraphics()
	applyCamera()
	-- efeitos de pós-processamento podem chegar depois do servidor criá-los
	Lighting.ChildAdded:Connect(function()
		task.defer(applyGraphics)
	end)
end

return Settings
