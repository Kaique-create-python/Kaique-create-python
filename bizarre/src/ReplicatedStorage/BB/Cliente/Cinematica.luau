-- BIZARRE BATTLEGROUNDS :: cenas de anime nas ULTs e no DESPERTAR (só no celular)
-- Quem usa a ULT ganha ~1,2 s de câmera de cinema: close no rosto, giro mostrando o Stand atrás,
-- barras pretas de cinema, o nome do golpe gigante (『ZA WARUDO』), ゴゴゴ na tela e linhas de
-- velocidade de mangá. Quem está perto vê o nome do golpe e o ゴゴゴ (sem perder a câmera).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Cinematica = {}

local RGB = Color3.fromRGB
local rng = Random.new()
local tela: Frame? = nil
local barraCima: Frame? = nil
local barraBaixo: Frame? = nil
local cor: ColorCorrectionEffect? = nil
local tocandoAte = 0

local function tween(obj: Instance, dur: number, props: any, estilo: Enum.EasingStyle?, direcao: Enum.EasingDirection?)
	local t = TweenService:Create(obj, TweenInfo.new(dur, estilo or Enum.EasingStyle.Quad, direcao or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

function Cinematica.iniciar(gui: ScreenGui)
	local f = Instance.new("Frame")
	f.Name = "BB_Cinema"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.ZIndex = 40
	f.Parent = gui
	tela = f
	for i, nome in { "BarraCima", "BarraBaixo" } do
		local b = Instance.new("Frame")
		b.Name = nome
		b.BackgroundColor3 = RGB(0, 0, 0)
		b.BorderSizePixel = 0
		b.ZIndex = 41
		b.AnchorPoint = Vector2.new(0, if i == 1 then 0 else 1)
		b.Position = UDim2.fromScale(0, if i == 1 then 0 else 1)
		b.Size = UDim2.fromScale(1, 0)
		b.Parent = f
		if i == 1 then
			barraCima = b
		else
			barraBaixo = b
		end
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "BB_Cinema"
	cc.Parent = Lighting
	cor = cc
end

function Cinematica.tocando(): boolean
	return os.clock() < tocandoAte
end

-- barras pretas de cinema
local function barras(dur: number)
	for _, b in { barraCima, barraBaixo } do
		if b then
			tween(b, 0.16, { Size = UDim2.fromScale(1, 0.12) })
			task.delay(dur, function()
				tween(b, 0.25, { Size = UDim2.fromScale(1, 0) })
			end)
		end
	end
end

-- nome do golpe gigante entre 『 』, entrando de lado com tremidinha
local function titulo(texto: string, subtitulo: string?, corAura: Color3, dur: number)
	if not tela then
		return
	end
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(1.3, 0.72)
	t.Size = UDim2.fromScale(0.9, 0.16)
	t.Font = Enum.Font.Bangers
	t.Text = "『" .. texto .. "』"
	t.TextScaled = true
	t.TextColor3 = RGB(255, 255, 255)
	t.Rotation = -4
	t.ZIndex = 45
	t.Parent = tela
	local borda = Instance.new("UIStroke")
	borda.Color = corAura
	borda.Thickness = 4
	borda.Parent = t
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(RGB(255, 255, 255), corAura:Lerp(RGB(255, 255, 255), 0.35))
	grad.Rotation = 90
	grad.Parent = t
	tween(t, 0.18, { Position = UDim2.fromScale(0.5, 0.72) }, Enum.EasingStyle.Back)
	if subtitulo then
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromScale(-0.3, 0.83)
		s.Size = UDim2.fromScale(0.6, 0.06)
		s.Font = Enum.Font.GothamBlack
		s.Text = subtitulo
		s.TextScaled = true
		s.TextColor3 = corAura:Lerp(RGB(255, 255, 255), 0.5)
		s.ZIndex = 45
		s.Parent = tela
		local b2 = Instance.new("UIStroke")
		b2.Thickness = 2
		b2.Parent = s
		tween(s, 0.22, { Position = UDim2.fromScale(0.5, 0.83) }, Enum.EasingStyle.Back)
		task.delay(dur, function()
			tween(s, 0.25, { TextTransparency = 1, Position = UDim2.fromScale(1.3, 0.83) })
			tween(b2, 0.25, { Transparency = 1 })
			task.delay(0.3, function()
				s:Destroy()
			end)
		end)
	end
	task.spawn(function()
		local fim = os.clock() + dur
		while os.clock() < fim and t.Parent do
			t.Rotation = -4 + rng:NextNumber(-0.8, 0.8)
			task.wait(0.03)
		end
		tween(t, 0.25, { TextTransparency = 1, Position = UDim2.fromScale(-0.3, 0.72) })
		tween(borda, 0.25, { Transparency = 1 })
		task.delay(0.3, function()
			t:Destroy()
		end)
	end)
end

-- ゴゴゴゴ (a "ameaça" da JoJo) espalhado pela beira da tela
local function ameaca(corAura: Color3, dur: number, quantos: number)
	if not tela then
		return
	end
	for i = 1, quantos do
		task.delay(i * 0.05, function()
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			local lado = rng:NextInteger(1, 4)
			local x = if lado == 1 then rng:NextNumber(0.04, 0.2) elseif lado == 2 then rng:NextNumber(0.8, 0.96) else rng:NextNumber(0.1, 0.9)
			local y = if lado == 3 then rng:NextNumber(0.16, 0.3) elseif lado == 4 then rng:NextNumber(0.45, 0.6) else rng:NextNumber(0.2, 0.62)
			l.Position = UDim2.fromScale(x, y)
			l.Size = UDim2.fromScale(0.09, 0.14)
			l.Font = Enum.Font.GothamBlack
			l.Text = "ゴ"
			l.TextScaled = true
			l.TextColor3 = corAura:Lerp(RGB(170, 90, 230), 0.5)
			l.TextTransparency = 1
			l.Rotation = rng:NextNumber(-18, 18)
			l.ZIndex = 42
			l.Parent = tela
			local b = Instance.new("UIStroke")
			b.Color = RGB(30, 0, 40)
			b.Thickness = 3
			b.Transparency = 1
			b.Parent = l
			tween(l, 0.12, { TextTransparency = 0, Size = UDim2.fromScale(0.11, 0.17) })
			tween(b, 0.12, { Transparency = 0 })
			task.spawn(function()
				local fim = os.clock() + dur
				local base = l.Position
				while os.clock() < fim and l.Parent do
					l.Position = base + UDim2.fromScale(rng:NextNumber(-0.004, 0.004), rng:NextNumber(-0.004, 0.004))
					task.wait(0.04)
				end
				tween(l, 0.2, { TextTransparency = 1 })
				tween(b, 0.2, { Transparency = 1 })
				task.delay(0.25, function()
					l:Destroy()
				end)
			end)
		end)
	end
end

-- linhas de velocidade de mangá (集中線) saindo do meio da tela
local function linhas(dur: number, corLinha: Color3?)
	if not tela then
		return
	end
	local grupo = Instance.new("Frame")
	grupo.Size = UDim2.fromScale(1, 1)
	grupo.BackgroundTransparency = 1
	grupo.ZIndex = 41
	grupo.Parent = tela
	local lista = {}
	for i = 1, 30 do
		local l = Instance.new("Frame")
		l.AnchorPoint = Vector2.new(0, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.Size = UDim2.new(0.75, 0, 0, rng:NextInteger(2, 5))
		l.BackgroundColor3 = corLinha or RGB(255, 255, 255)
		l.BorderSizePixel = 0
		l.Rotation = (i / 30) * 360 + rng:NextNumber(-5, 5)
		l.ZIndex = 41
		l.Parent = grupo
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(0.8, 0.45),
			NumberSequenceKeypoint.new(1, 0.15),
		})
		g.Parent = l
		table.insert(lista, l)
	end
	task.spawn(function()
		local fim = os.clock() + dur
		while os.clock() < fim and grupo.Parent do
			for _, l in lista do
				l.Rotation += rng:NextNumber(-3, 3)
				l.Size = UDim2.new(rng:NextNumber(0.6, 0.85), 0, 0, l.Size.Y.Offset)
			end
			task.wait(0.04)
		end
		grupo:Destroy()
	end)
end

-- cor dramática (contraste alto) durante a cena
local function corDramatica(dur: number, tinta: Color3)
	local cc = cor
	if not cc then
		return
	end
	tween(cc, 0.12, { Contrast = 0.35, Saturation = 0.25, TintColor = Color3.new(1, 1, 1):Lerp(tinta, 0.18) })
	task.delay(dur, function()
		tween(cc, 0.35, { Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) })
	end)
end

-- câmera de cinema: close no rosto -> giro mostrando o Stand -> volta para trás do ombro
local function cameraCinema(dono: Model, dur: number, estilo: string?)
	local raiz = dono:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cabeca = dono:FindFirstChild("Head") :: BasePart?
	if not raiz or not cabeca then
		return
	end
	local cam = workspace.CurrentCamera
	local antes = cam.CameraType
	cam.CameraType = Enum.CameraType.Scriptable
	local inicio = cam.CFrame
	local t0 = os.clock()
	local lado = if rng:NextNumber() < 0.5 then -1 else 1
	local con
	con = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - t0) / dur, 0, 1)
		if not raiz.Parent then
			t = 1
		end
		local base = raiz.CFrame
		local rosto = cabeca.Position
		local p1 = (base * CFrame.new(0.9 * lado, 0.9, -5.2)).Position -- close de baixo, na frente
		local p2 = (base * CFrame.new(6.5 * lado, 2.2, -1.5)).Position -- de lado, mostrando o Stand atrás
		local p3 = (base * CFrame.new(1.6 * lado, 2.6, 9.5)).Position -- atrás do ombro (volta ao jogo)
		if estilo == "baixo" then
			p1 = (base * CFrame.new(0.4 * lado, -1.6, -6)).Position -- de baixo para cima (imponente)
		end
		local pos, olhar
		if t < 0.42 then
			local k = t / 0.42
			local e = 1 - (1 - k) ^ 3
			pos = p1:Lerp(p2, e * 0.25)
			olhar = rosto
		elseif t < 0.8 then
			local k = (t - 0.42) / 0.38
			local e = k * k * (3 - 2 * k)
			pos = p1:Lerp(p2, 0.25 + e * 0.75)
			olhar = rosto:Lerp((base * CFrame.new(0, 1.5, 2.5)).Position, e)
		else
			local k = (t - 0.8) / 0.2
			local e = k * k * (3 - 2 * k)
			pos = p2:Lerp(p3, e)
			olhar = ((base * CFrame.new(0, 1.5, 2.5)).Position):Lerp((base * CFrame.new(0, 1.5, -20)).Position, e)
		end
		cam.CFrame = CFrame.lookAt(pos, olhar)
		if t >= 1 then
			con:Disconnect()
			cam.CameraType = if antes == Enum.CameraType.Scriptable then Enum.CameraType.Custom else antes
			local _ = inicio
		end
	end)
end

-- ULT: dono = quem usou; g = o golpe; s = o Stand
function Cinematica.ult(dono: Model?, s: any, g: any)
	if not dono or not g then
		return
	end
	local eu = Players.LocalPlayer.Character
	local raiz = dono:FindFirstChild("HumanoidRootPart") :: BasePart?
	local meu = eu and eu:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return
	end
	local perto = meu and (meu.Position - raiz.Position).Magnitude < 140
	local corAura = if s and s.aura then s.aura else RGB(170, 90, 230)
	local nome = g.onomatopeia or g.nome or "ULT"
	if dono == eu then
		local dur = 1.15
		tocandoAte = os.clock() + dur
		barras(dur)
		cameraCinema(dono, dur, if s and (s.id == "THE_WORLD" or s.id == "KILLER_QUEEN") then "baixo" else nil)
		linhas(dur * 0.85, corAura:Lerp(RGB(255, 255, 255), 0.6))
		corDramatica(dur, corAura)
		titulo(string.upper(nome), if s then s.nome .. " · " .. tostring(s.usuario) else nil, corAura, dur)
		ameaca(corAura, dur + 0.4, 10)
	elseif perto then
		-- quem está perto: o nome do golpe e o ゴゴゴ (a câmera continua com o jogador)
		titulo(string.upper(nome), if s then s.nome else nil, corAura, 0.9)
		ameaca(corAura, 1.1, 5)
	end
end

-- DESPERTAR: cena curtinha com o nome do Stand
function Cinematica.despertar(dono: Model?, s: any)
	if not dono or not s then
		return
	end
	local eu = Players.LocalPlayer.Character
	local corAura = s.aura or RGB(170, 90, 230)
	if dono == eu then
		local dur = 1.0
		tocandoAte = os.clock() + dur
		barras(dur)
		cameraCinema(dono, dur, "baixo")
		linhas(dur * 0.8)
		corDramatica(dur, corAura)
		titulo(s.nome, tostring(s.usuario) .. " DESPERTOU!", corAura, dur)
		ameaca(corAura, dur + 0.5, 12)
	else
		local raiz = dono:FindFirstChild("HumanoidRootPart") :: BasePart?
		local meu = eu and eu:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz and meu and (meu.Position - raiz.Position).Magnitude < 120 then
			ameaca(corAura, 1.2, 6)
		end
	end
end

return Cinematica
