-- BIZARRE BATTLEGROUNDS :: câmera (tremor nos golpes, zoom rápido e TRAVAR no inimigo)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Camera = {}

local intensidade = 0
local fimTremor = 0
local tremorLigado = true
local fovBase = 70
local fovExtra = 0
local alvoTrava: Model? = nil
local rng = Random.new()
local correndo = false
local tremorAplicado: CFrame? = nil

function Camera.ligarTremor(sim: boolean)
	tremorLigado = sim
end

function Camera.tremer(forca: number, dur: number)
	if not tremorLigado then
		return
	end
	intensidade = math.min(1.2, math.max(intensidade, forca))
	fimTremor = math.max(fimTremor, os.clock() + dur)
end

function Camera.fov(extra: number, dur: number)
	fovExtra = extra
	task.delay(dur, function()
		fovExtra = 0
	end)
end

function Camera.correndo(sim: boolean)
	correndo = sim
end

function Camera.travar(alvo: Model?)
	alvoTrava = alvo
end

function Camera.travado(): Model?
	if alvoTrava and (not alvoTrava.Parent or not alvoTrava:FindFirstChild("HumanoidRootPart")) then
		alvoTrava = nil
	end
	if alvoTrava then
		local hum = alvoTrava:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then
			alvoTrava = nil
		end
	end
	return alvoTrava
end

function Camera.iniciar()
	local cam = workspace.CurrentCamera
	fovBase = cam.FieldOfView
	-- desfaz o tremor do quadro anterior ANTES da câmera do Roblox calcular (senão ele acumula)
	RunService:BindToRenderStep("BB_CameraAntes", Enum.RenderPriority.Camera.Value - 1, function()
		if tremorAplicado then
			local c = workspace.CurrentCamera
			c.CFrame = c.CFrame * tremorAplicado:Inverse()
			tremorAplicado = nil
		end
	end)
	RunService:BindToRenderStep("BB_Camera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		cam = workspace.CurrentCamera
		-- travar no inimigo: gira a câmera para olhar o alvo
		local alvo = Camera.travado()
		local eu = Players.LocalPlayer.Character
		local raiz = eu and eu:FindFirstChild("HumanoidRootPart") :: BasePart?
		if alvo and raiz and cam.CameraType == Enum.CameraType.Custom then
			local r = alvo:FindFirstChild("HumanoidRootPart") :: BasePart
			local foco = cam.Focus.Position
			local dist = (cam.CFrame.Position - foco).Magnitude
			local dir = (r.Position - foco)
			if dir.Magnitude > 2 then
				local olhar = CFrame.lookAt(foco, r.Position + Vector3.new(0, -2, 0))
				local desejado = olhar * CFrame.new(0, 0, dist)
				desejado = desejado + Vector3.new(0, 2.5, 0)
				cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(desejado.Position, r.Position), math.min(1, dt * 10))
			end
		end
		-- tremor
		local agora = os.clock()
		if agora < fimTremor and intensidade > 0 then
			local k = intensidade * math.clamp((fimTremor - agora) / 0.25, 0, 1)
			local a = math.rad(k * 1.6)
			local tremor = CFrame.Angles(rng:NextNumber(-a, a), rng:NextNumber(-a, a), rng:NextNumber(-a, a) * 0.5)
				* CFrame.new(rng:NextNumber(-k, k) * 0.25, rng:NextNumber(-k, k) * 0.25, 0)
			if cam.CameraType == Enum.CameraType.Custom then
				cam.CFrame = cam.CFrame * tremor
				tremorAplicado = tremor
			end
		elseif agora >= fimTremor then
			intensidade = 0
		end
		-- FOV (corrida e golpes fortes)
		local alvoFov = fovBase + fovExtra + (if correndo then 6 else 0)
		cam.FieldOfView += (alvoFov - cam.FieldOfView) * math.min(1, dt * 8)
	end)
end

local _ = TweenService
return Camera
