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

Camera.forcaTremor = 1 -- ajuste do jogador (0 = desligado ... 1,4 = forte)
function Camera.tremer(forca: number, dur: number)
	if not tremorLigado or Camera.forcaTremor <= 0 then
		return
	end
	intensidade = math.min(1.4, math.max(intensidade, forca * Camera.forcaTremor))
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

-- mira travada: um losango vermelho girando em cima do alvo
local marca: BillboardGui? = nil
local function mostrarMarca(alvo: Model?)
	if marca then
		marca:Destroy()
		marca = nil
	end
	local r = alvo and alvo:FindFirstChild("HumanoidRootPart")
	if not r then
		return
	end
	local b = Instance.new("BillboardGui")
	b.Name = "BB_Mira"
	b.Size = UDim2.fromOffset(46, 46)
	b.StudsOffsetWorldSpace = Vector3.new(0, 4.4, 0)
	b.AlwaysOnTop = true
	b.LightInfluence = 0
	b.Adornee = r
	local q = Instance.new("Frame")
	q.Name = "Losango"
	q.AnchorPoint = Vector2.new(0.5, 0.5)
	q.Position = UDim2.fromScale(0.5, 0.5)
	q.Size = UDim2.fromScale(0.62, 0.62)
	q.Rotation = 45
	q.BackgroundTransparency = 1
	q.Parent = b
	local borda = Instance.new("UIStroke")
	borda.Color = Color3.fromRGB(255, 60, 70)
	borda.Thickness = 3
	borda.Parent = q
	local ponto = Instance.new("Frame")
	ponto.AnchorPoint = Vector2.new(0.5, 0.5)
	ponto.Position = UDim2.fromScale(0.5, 0.5)
	ponto.Size = UDim2.fromScale(0.22, 0.22)
	ponto.BackgroundColor3 = Color3.fromRGB(255, 60, 70)
	ponto.BorderSizePixel = 0
	ponto.Parent = q
	b.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	marca = b
end

-- AJUSTE7: com a mira travada a câmera começa a 11 studs e o zoom fica entre 7,5 e 18
local DIST_TRAVA, ZOOM_MIN, ZOOM_MAX = 11, 7.5, 18
Camera.preferida = nil :: number? -- distância escolhida nos AJUSTES (nil = padrão)
local DIST_LIVRE_MIN, DIST_LIVRE_MAX = 4, 32
local atrasParede = 0
local function zoomPara(min: number, max: number)
	local plr = Players.LocalPlayer
	plr.CameraMinZoomDistance = min
	plr.CameraMaxZoomDistance = max
end

function Camera.travar(alvo: Model?)
	local antes = alvoTrava
	alvoTrava = alvo
	atrasParede = 0
	mostrarMarca(alvo)
	if alvo and alvo ~= antes then
		local d = math.clamp(Camera.preferida or DIST_TRAVA, ZOOM_MIN, ZOOM_MAX)
		zoomPara(d, d)
		task.delay(0.12, function()
			if alvoTrava == alvo then
				zoomPara(ZOOM_MIN, ZOOM_MAX)
			end
		end)
	elseif not alvo and antes then
		zoomPara(DIST_LIVRE_MIN, DIST_LIVRE_MAX)
	end
end

-- ajuste "distância da câmera" (fora da trava): põe o zoom nesse valor e libera de novo
function Camera.distancia(valor: number)
	Camera.preferida = valor
	if alvoTrava then
		return
	end
	zoomPara(valor, valor)
	task.delay(0.12, function()
		if not alvoTrava then
			zoomPara(DIST_LIVRE_MIN, DIST_LIVRE_MAX)
		end
	end)
end

-- AJUSTE7: um dono só para a câmera. "jogo" = câmera normal; "menu" e "cinema" pegam emprestado
-- e devolvem. Se alguém esquecer de devolver (morreu no meio da cena), a câmera se recupera.
local dono = "jogo"
function Camera.dono(): string
	return dono
end
function Camera.assumir(quem: string)
	dono = quem
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
end
function Camera.recuperar()
	if dono ~= "jogo" then
		return
	end
	local cam = workspace.CurrentCamera
	if cam.CameraType ~= Enum.CameraType.Custom then
		cam.CameraType = Enum.CameraType.Custom
	end
	local c = Players.LocalPlayer.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum and cam.CameraSubject ~= hum then
		cam.CameraSubject = hum
	end
end
function Camera.devolver(quem: string)
	if dono ~= quem then
		return
	end
	dono = "jogo"
	Camera.recuperar()
end

-- volta suave para a câmera do jogo depois de uma cena de cinema
local retorno: any = nil
function Camera.suavizarRetorno(de: CFrame, dur: number)
	retorno = { de = de, t0 = os.clock(), dur = dur }
end

-- raios só contra o cenário (a câmera não entra na parede)
local paramsParede: RaycastParams? = nil
local paramsParedeT = 0
local function paramsCenario(): RaycastParams
	if not paramsParede or os.clock() - paramsParedeT > 5 then
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Include
		local lista = {}
		for _, nome in { "Morioh", "BB_Mapa", "BB_Temporarias" } do
			local m = workspace:FindFirstChild(nome)
			if m then
				table.insert(lista, m)
			end
		end
		p.FilterDescendantsInstances = lista
		pcall(function()
			p.RespectCanCollide = true
		end)
		paramsParede = p
		paramsParedeT = os.clock()
	end
	return paramsParede :: RaycastParams
end

-- solta sozinho: alvo morreu, sumiu, ficou longe demais ou o dono caiu no ragdoll
local DISTANCIA_MAXIMA = 130
function Camera.travado(): Model?
	if alvoTrava and (not alvoTrava.Parent or not alvoTrava:FindFirstChild("HumanoidRootPart")) then
		Camera.travar(nil)
	end
	if alvoTrava then
		local hum = alvoTrava:FindFirstChildOfClass("Humanoid")
		local eu = Players.LocalPlayer.Character
		local raiz = eu and eu:FindFirstChild("HumanoidRootPart") :: BasePart?
		local r = alvoTrava:FindFirstChild("HumanoidRootPart") :: BasePart?
		if (hum and hum.Health <= 0) or (raiz and r and (r.Position - raiz.Position).Magnitude > DISTANCIA_MAXIMA) then
			Camera.travar(nil)
		end
	end
	if marca and marca.Parent then
		local q = marca:FindFirstChild("Losango") :: Frame?
		if q then
			q.Rotation = 45 + math.sin(os.clock() * 5) * 12
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
		-- ninguém pediu a câmera e ela ficou presa (cena interrompida, renasceu): recupera
		if dono == "jogo" and cam.CameraType == Enum.CameraType.Scriptable then
			Camera.recuperar()
		end
		-- travar no inimigo: gira a câmera para olhar o alvo
		local alvo = Camera.travado()
		local eu = Players.LocalPlayer.Character
		local raiz = eu and eu:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- alvo atrás de parede por 1,5 s: solta a trava
		if alvo and raiz then
			local r0 = alvo:FindFirstChild("HumanoidRootPart") :: BasePart
			local v = r0.Position - raiz.Position
			local hit = workspace:Raycast(raiz.Position + Vector3.new(0, 1.5, 0), v, paramsCenario())
			if hit and (hit.Position - raiz.Position).Magnitude < v.Magnitude - 2 then
				atrasParede += dt
				if atrasParede > 1.5 then
					Camera.travar(nil)
					alvo = nil
				end
			else
				atrasParede = 0
			end
		end
		if alvo and raiz and cam.CameraType == Enum.CameraType.Custom then
			local r = alvo:FindFirstChild("HumanoidRootPart") :: BasePart
			local foco = cam.Focus.Position
			local dist = (cam.CFrame.Position - foco).Magnitude
			local dir = (r.Position - foco)
			if dir.Magnitude > 2 then
				-- câmera atrás do ombro olhando o alvo (como no Jujutsu Shenanigans)
				local olhar = CFrame.lookAt(foco, r.Position + Vector3.new(0, -2, 0))
				local desejado = olhar * CFrame.new(1.4, 0, dist)
				desejado = desejado + Vector3.new(0, 2.5, 0)
				-- proteção contra parede: a câmera para antes do que estiver entre ela e o jogador
				local volta = desejado.Position - foco
				local bate = workspace:Raycast(foco, volta, paramsCenario())
				local posCam = desejado.Position
				if bate then
					posCam = bate.Position - volta.Unit * 0.6
				end
				cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(posCam, r.Position + Vector3.new(0, 0.5, 0)), math.min(1, dt * 12))
			end
		end
		-- volta suave depois da cena de cinema
		if retorno and cam.CameraType == Enum.CameraType.Custom then
			local k = (os.clock() - retorno.t0) / retorno.dur
			if k >= 1 then
				retorno = nil
			else
				local e = k * k * (3 - 2 * k)
				cam.CFrame = retorno.de:Lerp(cam.CFrame, e)
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
