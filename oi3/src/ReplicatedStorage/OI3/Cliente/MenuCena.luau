-- OI3 :: cenário 3D do menu (quarto do espelho, à luz de velas). Existe só no cliente.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local OI3 = script.Parent.Parent
local Construtor = require(OI3.Construtor)
local Moveis = require(OI3.Moveis)

local MenuCena = {}

local V3 = Vector3.new
local CF = CFrame.new
local RGB = Color3.fromRGB
local M = Enum.Material
local COR = Moveis.COR

MenuCena.ORIGEM = V3(0, 420, 1400)
local O = MenuCena.ORIGEM

-- Monta as peças do cenário (função pura: dá para testar fora do Roblox)
function MenuCena.construirCenario(pasta: Instance)
	local c = Construtor.novo(pasta)
	local refs = {}
	local papel = RGB(44, 56, 54)
	local function P(x: number, y: number, z: number): Vector3
		return O + V3(x, y, z)
	end
	-- caixa do quarto
	c:entre(P(-16, -1, -13), P(16, 0, 13), COR.piso, M.WoodPlanks)
	c:entre(P(-16, 14, -13), P(16, 15, 13), COR.teto, M.Wood)
	c:entre(P(-16, 0, -13), P(16, 14, -12), papel, M.Fabric) -- fundo
	c:entre(P(-16, 0, 12), P(16, 14, 13), papel, M.Fabric) -- atrás da câmera
	-- parede esquerda com janela
	local abJ = { { centro = 11, largura = 4.2, base = 3.5, topo = 11.5 } }
	c:parede(P(-15.5, 0, -12), P(-15.5, 0, 12), O.Y, 14, 1, papel, M.Fabric, abJ)
	c:parede(P(15.5, 0, -12), P(15.5, 0, 12), O.Y, 14, 1, papel, M.Fabric, nil)
	-- lambri e frisos
	for _, s in { { P(-15, 0, -11.9), P(15, 0, -11.9) }, { P(-14.9, 0, -12), P(-14.9, 0, 12) }, { P(14.9, 0, 12), P(14.9, 0, -12) } } do
		c:parede(s[1], s[2], O.Y, 3.4, 0.2, COR.lambri, M.WoodPlanks, nil)
	end
	c:entre(P(-15, 3.4, -11.95), P(15, 3.65, -11.6), COR.madeiraEscura, M.Wood)
	c:entre(P(-15, 0, -11.95), P(15, 0.5, -11.6), COR.madeiraEscura, M.Wood)
	-- janela (luar)
	Moveis.janela(c, P(-15.5, 7.5, -1), V3(0, 0, 1), V3(-1, 0, 0), 4.2, 8, { cortinasTecido = true })
	local lua = c:entre(P(-22, 2, -6), P(-21.5, 14, 4), RGB(90, 110, 150), M.Neon, { Transparency = 0.55, Name = "CeuLua" })
	local fonteLua = c:caixa(P(-19, 11, 2), V3(0.4, 0.4, 0.4), RGB(0, 0, 0), M.SmoothPlastic, { Transparency = 1, Name = "FonteLua" })
	fonteLua.CFrame = CFrame.lookAt(P(-19, 11, 2), P(-6, 0, -3))
	c:luz(fonteLua, "SpotLight", { Brightness = 2.4, Range = 30, Angle = 38, Color = RGB(140, 160, 220), Face = Enum.NormalId.Front, Shadows = true })
	refs.lua = lua
	-- espelho grande no fundo
	local centroEsp = P(3, 7.6, -11.4)
	refs.vidro = Moveis.espelho(c, centroEsp, V3(0, 0, 1), 5.4, 8.2, "VidroMenu")
	refs.vidro.Reflectance = 0.12
	-- mesinha (aparador) com velas
	local topo = Moveis.comoda(c, P(3, 0, -10.6), V3(0, 0, 1), 6.6)
	refs.vela = Moveis.vela(c, topo + V3(-0.4, 0, 0.1), { altura = 0.9, luz = true, alcance = 18, brilho = 1.0, sombras = true })
	Moveis.vela(c, topo + V3(-1.6, 0, 0.2), { altura = 0.55, luz = false })
	Moveis.vela(c, topo + V3(2.1, 0, 0), { altura = 0.4, luz = true, alcance = 10, brilho = 0.45 })
	-- quadros
	Moveis.quadro(c, P(-6.5, 7.5, -11.55), V3(0, 0, 1), 3.2, 4.2, RGB(56, 50, 44))
	Moveis.quadro(c, P(11.5, 8, -11.55), V3(0, 0, 1), 2.4, 3, RGB(44, 52, 58))
	-- tapete, cadeirinha e ursinho
	c:cilindro(CF(P(2, 0.04, -2)) * CFrame.Angles(0, 0, math.pi / 2), 0.08, 12, RGB(72, 34, 38), M.Fabric)
	c:cilindro(CF(P(2, 0.06, -2)) * CFrame.Angles(0, 0, math.pi / 2), 0.08, 10, RGB(96, 50, 46), M.Fabric)
	Moveis.cadeira(c, P(10.5, 0, -6), V3(-0.7, 0, 0.7).Unit)
	Moveis.ursinho(c, P(10.5, 1.8, -6.1), V3(-0.7, 0, 0.7).Unit)
	-- AJUSTE-3: mais detalhes no quarto do menu
	Moveis.luar(c, P(-15.2, 9.5, -1), P(-7.5, 0, 0.5), false)
	Moveis.estante(c, P(14.45, 0, -8.6), V3(-1, 0, 0), 4.2, 8.5, 21)
	Moveis.boneca(c, P(0.4, 3.48, -10.6), V3(0.15, 0, 1).Unit)
	Moveis.blocos(c, P(7.2, 0, -0.8), 9)
	Moveis.teia(c, P(-15.4, 13.95, -11.9), V3(1, 0, 0), V3(0, 0, 1), 2.4)
	Moveis.teia(c, P(14.4, 13.95, -11.9), V3(-1, 0, 0), V3(0, 0, 1), 2.0)
	for _, x in { -9, -3, 3, 9 } do
		c:entre(P(x - 0.4, 13.25, -12), P(x + 0.4, 14, 12), COR.madeiraEscura, M.Wood)
	end
	Moveis.desenho(c, P(-10.5, 6.2, -11.55), V3(0, 0, 1), 1)
	Moveis.vela(c, P(-1.8, 0, -8.5), { altura = 0.55, luz = true, alcance = 9, brilho = 0.4 })
	Moveis.vela(c, P(-1.2, 0, -8.9), { altura = 0.35 })

	-- luz-chave dos botões (presa à câmera depois)
	local chave = c:caixa(P(0, 7, 8), V3(0.3, 0.3, 0.3), RGB(0, 0, 0), M.SmoothPlastic, { Transparency = 1, Name = "LuzBotoes" })
	refs.luzBotoesLuz = c:luz(chave, "SpotLight", { Brightness = 1.6, Range = 16, Angle = 70, Color = RGB(255, 214, 170), Face = Enum.NormalId.Front, Shadows = false })
	refs.luzBotoes = chave
	-- poeira no ar
	local volume = c:caixa(P(1, 6, -3), V3(26, 10, 16), RGB(0, 0, 0), M.SmoothPlastic, { Transparency = 1, Name = "Poeira", colisao = false, CanQuery = false })
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Poeira"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 14
	pe.Lifetime = NumberRange.new(6, 10)
	pe.Speed = NumberRange.new(0.05, 0.25)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.07)
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) })
	pe.LightEmission = 0.4
	pe.LightInfluence = 0.6
	pe.Color = ColorSequence.new(RGB(255, 236, 210))
	pe.Acceleration = V3(0, -0.01, 0)
	pe.Parent = volume
	refs.poeira = pe

	-- título "OI3" escrito no vidro do espelho
	local sg = Instance.new("SurfaceGui")
	sg.Name = "TituloEspelho"
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 0.15
	sg.Brightness = 1.6
	sg.Parent = refs.vidro
	local titulo = Instance.new("TextLabel")
	titulo.Name = "Titulo"
	titulo.BackgroundTransparency = 1
	titulo.AnchorPoint = Vector2.new(0.5, 0.5)
	titulo.Position = UDim2.fromScale(0.5, 0.42)
	titulo.Size = UDim2.fromScale(0.95, 0.42)
	titulo.Text = "OI3"
	titulo.TextScaled = true
	titulo.FontFace = Font.new("rbxasset://fonts/families/Creepster.json")
	titulo.TextColor3 = RGB(226, 220, 212)
	titulo.TextTransparency = 0.12
	titulo.Parent = sg
	local contorno = Instance.new("UIStroke")
	contorno.Color = RGB(120, 16, 16)
	contorno.Thickness = 2
	contorno.Transparency = 0.35
	contorno.Parent = titulo
	refs.titulo = titulo
	-- vulto que aparece de vez em quando no espelho (só uma sombra)
	local vulto = Instance.new("Frame")
	vulto.Name = "Vulto"
	vulto.BackgroundTransparency = 1
	vulto.AnchorPoint = Vector2.new(0.5, 1)
	vulto.Position = UDim2.fromScale(0.7, 1.02)
	vulto.Size = UDim2.fromScale(0.34, 0.78)
	vulto.Visible = false
	vulto.Parent = sg
	local cabeca = Instance.new("Frame")
	cabeca.BackgroundColor3 = RGB(0, 0, 0)
	cabeca.BackgroundTransparency = 0.35
	cabeca.BorderSizePixel = 0
	cabeca.AnchorPoint = Vector2.new(0.5, 0)
	cabeca.Position = UDim2.fromScale(0.5, 0)
	cabeca.Size = UDim2.fromScale(0.42, 0.17)
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = cabeca
	cabeca.Parent = vulto
	local corpo = Instance.new("Frame")
	corpo.BackgroundColor3 = RGB(0, 0, 0)
	corpo.BackgroundTransparency = 0.35
	corpo.BorderSizePixel = 0
	corpo.AnchorPoint = Vector2.new(0.5, 0)
	corpo.Position = UDim2.fromScale(0.5, 0.15)
	corpo.Size = UDim2.fromScale(0.85, 0.9)
	local cc2 = Instance.new("UICorner")
	cc2.CornerRadius = UDim.new(0.35, 0)
	cc2.Parent = corpo
	corpo.Parent = vulto
	refs.vulto = vulto
	refs.contagem = c.contagem
	Moveis.aplicarVariantes(pasta) -- AJUSTE-5: texturas realistas no quarto do menu
	return refs
end

-- CFrame da câmera do menu conforme o formato da tela
function MenuCena.cameraBase(vw: number, vh: number): (CFrame, number)
	local aspecto = vw / math.max(vh, 1)
	if aspecto >= 1.15 then
		-- paisagem: espelho à direita, botões à esquerda
		local deslocX = math.clamp((aspecto - 1.6) * 1.4, -0.8, 1.2)
		return CFrame.lookAt(O + V3(-2.4 - deslocX, 6.3, 10.2), O + V3(-1.4 - deslocX, 6.2, -12)), 52
	end
	-- retrato: espelho em cima, botões embaixo
	return CFrame.lookAt(O + V3(3, 6.2, 10.4), O + V3(3, 2.4, -12)), 72
end

---------------------------------------------------------------------------
-- Execução (cliente)
---------------------------------------------------------------------------

local estado = {
	pasta = nil :: Folder?,
	refs = nil :: any,
	conexao = nil :: RBXScriptConnection?,
	grupo = nil :: any,
	inicio = 0,
	cfAtual = nil :: CFrame?,
	ativo = false,
	transicao = nil :: { de: CFrame, para: CFrame, t0: number, dur: number }?,
	proximoVulto = 0,
}

function MenuCena.construir(): any
	if estado.pasta then
		return estado.refs
	end
	local pasta = Instance.new("Folder")
	pasta.Name = "OI3_Menu"
	estado.refs = MenuCena.construirCenario(pasta)
	pasta.Parent = workspace
	estado.pasta = pasta
	return estado.refs
end

function MenuCena.pasta(): Folder?
	return estado.pasta
end

function MenuCena.definirBotoes(grupo: any)
	estado.grupo = grupo
end

function MenuCena.modoLeve(sim: boolean)
	if estado.refs and estado.refs.poeira then
		estado.refs.poeira.Enabled = not sim
	end
end

function MenuCena.mostrar(aoVulto: (() -> ())?)
	if not estado.pasta then
		MenuCena.construir()
	end
	local pasta = estado.pasta :: Folder
	pasta.Parent = workspace
	estado.ativo = true
	estado.inicio = os.clock()
	estado.transicao = nil
	estado.proximoVulto = os.clock() + 18 + math.random() * 12
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	if estado.conexao then
		estado.conexao:Disconnect()
	end
	local ultimaTela = Vector2.new(0, 0)
	estado.conexao = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local vp = camera.ViewportSize
		if vp.X < 50 or vp.Y < 50 then
			return -- tela ainda não tem tamanho (primeiro quadro em alguns celulares)
		end
		local base, fov = MenuCena.cameraBase(vp.X, vp.Y)
		if vp ~= ultimaTela then
			ultimaTela = vp
			if estado.grupo then
				estado.grupo:recriar(vp.X, vp.Y, fov)
			end
		end
		local t = os.clock() - estado.inicio
		-- entrada: câmera se aproxima devagar
		local k = math.clamp(t / 3, 0, 1)
		local ease = 1 - (1 - k) ^ 3
		local recuo = CF(0, 0.6 * (1 - ease), 3.2 * (1 - ease))
		local balanco = CF(math.sin(t * 0.37) * 0.14, math.sin(t * 0.51) * 0.07, 0) * CFrame.Angles(math.sin(t * 0.29) * 0.006, math.sin(t * 0.23) * 0.008, 0)
		local cf = base * recuo * balanco
		local tr = estado.transicao
		if tr then
			local p = math.clamp((os.clock() - tr.t0) / tr.dur, 0, 1)
			local e = p * p * (3 - 2 * p)
			cf = tr.de:Lerp(tr.para, e)
		end
		camera.CFrame = cf
		camera.FieldOfView = fov
		if estado.grupo then
			estado.grupo:atualizar(base * recuo, t)
		end
		local refs = estado.refs
		if refs then
			-- luz dos botões acompanha a câmera
			if refs.luzBotoes then
				local paisagem = vp.X / math.max(vp.Y, 1) >= 1.15
				local alvo = base * (if paisagem then CF(-3.2, -0.4, -7) else CF(0, -1.8, -7))
				refs.luzBotoes.CFrame = CFrame.lookAt((base * CF(-1.2, 2.2, -1.5)).Position, alvo.Position)
			end
			-- título treme de leve
			if refs.titulo then
				local n = math.noise(t * 2.2, 3.3, 0.7)
				refs.titulo.TextTransparency = if n > 0.45 then 0.55 else 0.1 + n * 0.08
			end
			-- vulto raro no espelho
			if refs.vulto and os.clock() > estado.proximoVulto then
				estado.proximoVulto = os.clock() + 25 + math.random() * 20
				refs.vulto.Visible = true
				if aoVulto then
					aoVulto()
				end
				task.delay(0.22, function()
					refs.vulto.Visible = false
					task.wait(0.12)
					refs.vulto.Visible = true
					task.wait(0.08)
					refs.vulto.Visible = false
				end)
			end
		end
	end)
end

-- Câmera mergulha no espelho (antes da cutscene)
function MenuCena.mergulhar(dur: number)
	local cam = workspace.CurrentCamera
	local alvo = O + V3(3, 7.6, -11.2)
	local de = cam.CFrame
	local para = CFrame.lookAt(alvo + V3(0, 0, 1.2), alvo + V3(0, 0, -5))
	estado.transicao = { de = de, para = para, t0 = os.clock(), dur = dur }
end

function MenuCena.esconder()
	estado.ativo = false
	if estado.conexao then
		estado.conexao:Disconnect()
		estado.conexao = nil
	end
	if estado.pasta then
		estado.pasta.Parent = nil
	end
end

function MenuCena.refs()
	return estado.refs
end

return MenuCena
