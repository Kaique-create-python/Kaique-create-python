-- BIZARRE BATTLEGROUNDS :: câmera (tremor nos golpes, zoom rápido e TRAVAR no inimigo)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Registro = require(script.Parent:WaitForChild("Registro"))

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
-- AJUSTE-8: câmera que GRUDA. A trava pode vir do botão MIRA ou sozinha (quando você bate ou
-- apanha). A automática solta depois de uns segundos sem luta; a do botão só no botão.
local travaAuto = false
local ultimoCombate = 0
-- AJUSTE-12: câmera da trava própria (Scriptable): não briga com o dedo, enquadra você e o alvo
local modoTrava = false
local camPos: Vector3? = nil
local camOlhar: Vector3? = nil
local frenteTrava: Vector3 = Vector3.new(0, 0, -1)
local FORCA_TRAVA = 20 -- quanto a câmera puxa para o alvo por segundo (era 12)
local SEGUNDOS_PAREDE = 3 -- alvo escondido atrás de parede por mais que isso: solta
local SEGUNDOS_SEM_LUTA = 7 -- trava automática sem golpes e longe: solta
Camera.miraAuto = true
local function zoomPara(min: number, max: number)
	local plr = Players.LocalPlayer
	plr.CameraMinZoomDistance = min
	plr.CameraMaxZoomDistance = max
end

function Camera.travar(alvo: Model?, automatica: boolean?)
	local antes = alvoTrava
	alvoTrava = alvo
	atrasParede = 0
	travaAuto = alvo ~= nil and automatica == true
	ultimoCombate = os.clock()
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
function Camera.modoTrava(): boolean
	return modoTrava
end

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

-- o inimigo vivo mais perto (para a trava passar de um para o outro numa luta em grupo)
local function inimigoMaisPerto(limite: number, menos: Model?): Model?
	local eu = Players.LocalPlayer.Character
	local raiz = eu and eu:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return nil
	end
	local melhor, menor = nil, limite
	for m in Registro.lutadores() do
		if m ~= eu and m ~= menos then
			local r = m:FindFirstChild("HumanoidRootPart") :: BasePart?
			local h = m:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 then
				local d = (r.Position - raiz.Position).Magnitude
				if d < menor then
					melhor, menor = m, d
				end
			end
		end
	end
	return melhor
end

-- AJUSTE-8: bateu em alguém ou apanhou sem estar travado: a câmera gruda nele sozinha
function Camera.aoAcerto(d: any)
	local eu = Players.LocalPlayer.Character
	if not eu or type(d) ~= "table" then
		return
	end
	local outro = if d.a == eu then d.v elseif d.v == eu then d.a else nil
	if typeof(outro) ~= "Instance" or not outro:IsA("Model") or outro == eu then
		return
	end
	if alvoTrava == outro then
		ultimoCombate = os.clock()
		return
	end
	-- AJUSTE-12: só trava sozinha em quem EU acertei (apanhar de alguém por trás não gira a câmera)
	if d.a ~= eu or alvoTrava or not Camera.miraAuto or dono ~= "jogo" then
		return
	end
	local h = outro:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 and outro:GetAttribute("BB_Lutador") and outro:FindFirstChild("HumanoidRootPart") then
		Camera.travar(outro, true)
	end
end

-- solta sozinho: alvo sumiu, ficou longe demais, ou (trava automática) a luta acabou.
-- Alvo caiu: passa para o inimigo mais perto, se tiver alguém lutando por perto.
local DISTANCIA_MAXIMA = 130
function Camera.travado(): Model?
	if alvoTrava and (not alvoTrava.Parent or not alvoTrava:FindFirstChild("HumanoidRootPart")) then
		Camera.travar(inimigoMaisPerto(40, alvoTrava), travaAuto)
	end
	if alvoTrava then
		local hum = alvoTrava:FindFirstChildOfClass("Humanoid")
		local eu = Players.LocalPlayer.Character
		local raiz = eu and eu:FindFirstChild("HumanoidRootPart") :: BasePart?
		local r = alvoTrava:FindFirstChild("HumanoidRootPart") :: BasePart?
		local dist = if raiz and r then (r.Position - raiz.Position).Magnitude else 0
		if hum and hum.Health <= 0 then
			Camera.travar(inimigoMaisPerto(40, alvoTrava), travaAuto)
		elseif dist > DISTANCIA_MAXIMA then
			Camera.travar(nil)
		elseif travaAuto then
			if dist < 24 then
				ultimoCombate = os.clock()
			elseif os.clock() - ultimoCombate > SEGUNDOS_SEM_LUTA then
				Camera.travar(nil)
			end
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
		if dono == "jogo" and cam.CameraType == Enum.CameraType.Scriptable and not modoTrava then
			Camera.recuperar()
		end
		-- travar no inimigo: gira a câmera para olhar o alvo
		local alvo = Camera.travado()
		local eu = Players.LocalPlayer.Character
		local raiz = eu and eu:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- alvo atrás de parede por 3 s: solta a trava
		if alvo and raiz then
			local r0 = alvo:FindFirstChild("HumanoidRootPart") :: BasePart
			local v = r0.Position - raiz.Position
			local hit = workspace:Raycast(raiz.Position + Vector3.new(0, 1.5, 0), v, paramsCenario())
			if hit and (hit.Position - raiz.Position).Magnitude < v.Magnitude - 2 then
				atrasParede += dt
				if atrasParede > SEGUNDOS_PAREDE then
					Camera.travar(nil)
					alvo = nil
				end
			else
				atrasParede = 0
			end
		end
		if alvo and raiz and dono == "jogo" then
			-- AJUSTE-12: câmera da trava (como nos battlegrounds): atrás do ombro direito, olhando um
			-- ponto entre você e o alvo (os dois na tela), suave e sem brigar com o dedo
			local r = alvo:FindFirstChild("HumanoidRootPart") :: BasePart
			if cam.CameraType ~= Enum.CameraType.Scriptable then
				cam.CameraType = Enum.CameraType.Scriptable
				camPos = cam.CFrame.Position
				camOlhar = cam.CFrame.Position + cam.CFrame.LookVector * 12
			end
			modoTrava = true
			local pivo = raiz.Position + Vector3.new(0, 1.7, 0)
			local para = r.Position - raiz.Position
			local plano = Vector3.new(para.X, 0, para.Z)
			if plano.Magnitude > 0.6 then
				frenteTrava = plano.Unit
			end
			local direita = frenteTrava:Cross(Vector3.yAxis)
			local distAlvo = plano.Magnitude
			local dist = math.clamp((Camera.preferida or DIST_TRAVA) + math.max(0, distAlvo - 12) * 0.3, ZOOM_MIN, ZOOM_MAX + 4)
			-- alvo no ar (uppercut) ou embaixo: a câmera sobe/desce um pouco, sem virar de ponta-cabeça
			local subida = math.clamp(r.Position.Y - raiz.Position.Y, -6, 18)
			local desejada = pivo - frenteTrava * dist + direita * 1.7 + Vector3.new(0, 2.3 + subida * 0.3, 0)
			-- parede: a câmera para antes dela
			local volta = desejada - pivo
			local bate = workspace:Raycast(pivo, volta, paramsCenario())
			if bate then
				desejada = bate.Position - volta.Unit * 0.6
			end
			local olharDesejado = pivo:Lerp(r.Position + Vector3.new(0, 0.6, 0), 0.62)
			local a1 = 1 - math.exp(-dt * FORCA_TRAVA * 0.6)
			local a2 = 1 - math.exp(-dt * FORCA_TRAVA * 0.85)
			camPos = (camPos or desejada):Lerp(desejada, a1)
			camOlhar = (camOlhar or olharDesejado):Lerp(olharDesejado, a2)
			if ((camOlhar :: Vector3) - (camPos :: Vector3)).Magnitude > 0.2 then
				cam.CFrame = CFrame.lookAt(camPos :: Vector3, camOlhar :: Vector3)
			end
		elseif modoTrava then
			-- saiu da trava: a câmera normal do Roblox continua de onde está (sem pulo)
			modoTrava = false
			camPos = nil
			camOlhar = nil
			if dono == "jogo" then
				cam.CameraType = Enum.CameraType.Custom
				Camera.recuperar()
				Camera.suavizarRetorno(cam.CFrame, 0.35)
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
			elseif modoTrava then
				-- na trava a câmera é refeita do zero a cada quadro: não precisa desfazer
				cam.CFrame = cam.CFrame * tremor
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
