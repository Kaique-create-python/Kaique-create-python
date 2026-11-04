-- BIZARRE BATTLEGROUNDS :: menu (escolher o Stand, lutar, treinar, controles e ajustes)
-- A câmera passeia pela cidade atrás do menu. Cada Stand aparece girando numa janelinha 3D.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local BB = script.Parent.Parent
local Stands = require(BB:WaitForChild("Stands"))
local Golpes = require(BB:WaitForChild("Golpes"))
local Config = require(BB:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("Interface"))
local Som = require(script.Parent:WaitForChild("Som"))
local Efeitos = require(script.Parent:WaitForChild("Efeitos"))
local Camera = require(script.Parent:WaitForChild("Camera"))

local Menu = {}

local plr = Players.LocalPlayer
local gui: ScreenGui
local remotos: any
local aberto = false
local selecionado = Stands.ORDEM[1]
local cartoes: { [string]: any } = {}
local detalhe: any = {}
local conexaoCamera: RBXScriptConnection? = nil
local aoFechar: ((entrou: boolean) -> ())? = nil
local botaoLutar: TextButton
local botaoVoltar: TextButton
local painelControles: Frame
local painelAjustes: Frame
local ajustes = { musica = Config.VOLUME_MUSICA, efeitosAltos = true, tremor = true }

local function estrelas(n: number): string
	return string.rep("★", n) .. string.rep("☆", 3 - n)
end

local function moldeStand(id: string): Model?
	local pasta = ReplicatedStorage:FindFirstChild("BB_Stands")
	local m = pasta and pasta:FindFirstChild(id)
	return m :: Model?
end

-- janelinha 3D com o Stand girando
local function viewport(pai: Instance, id: string, tam: UDim2, pos: UDim2): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Size = tam
	vp.Position = pos
	vp.BackgroundTransparency = 1
	vp.LightColor = Color3.fromRGB(255, 240, 220)
	vp.Ambient = Color3.fromRGB(140, 130, 170)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vp.Parent = pai
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	cam.Parent = vp
	vp.CurrentCamera = cam
	local function montar()
		local molde = moldeStand(id)
		if not molde then
			return false
		end
		local m = molde:Clone()
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		m:PivotTo(CFrame.new(0, 0, 0))
		m.Parent = vp
		local _, tamanho = m:GetBoundingBox()
		local altura = tamanho.Y
		cam.CFrame = CFrame.lookAt(Vector3.new(0, altura * 0.08, -altura * 2.05), Vector3.new(0, altura * 0.05, 0))
		vp:SetAttribute("Pronto", true)
		task.spawn(function()
			local ang = math.random() * 6
			while vp.Parent do
				ang += 0.02
				if vp.Visible and aberto then
					m:PivotTo(CFrame.Angles(0, ang, 0))
				end
				task.wait(1 / 30)
			end
		end)
		return true
	end
	task.spawn(function()
		while vp.Parent and not montar() do
			task.wait(0.5)
		end
	end)
	return vp
end

local function selecionar(id: string)
	selecionado = id
	local s = Stands.get(id)
	for outro, c in cartoes do
		c.borda.Color = if outro == id then s.aura else Color3.fromRGB(60, 40, 90)
		c.borda.Thickness = if outro == id then 4 else 2
	end
	detalhe.nome.Text = "『" .. s.nome .. "』"
	detalhe.nome.TextColor3 = s.aura
	detalhe.titulo.Text = s.titulo
	detalhe.tipo.Text = s.tipo .. "   ·   dificuldade " .. estrelas(s.dificuldade)
	detalhe.desc.Text = s.desc
	detalhe.passiva.Text = "PASSIVA — " .. s.passiva.nome .. ": " .. s.passiva.desc
	for i, linha in detalhe.golpes do
		local g = if i <= 4 then Golpes.get(s.golpes[i]) else Golpes.get(s.ult)
		local tecla = if i <= 4 then tostring(i) else "ULT"
		linha.Text = string.format('<font color="#FFCE40">%s</font>  <b>%s</b> — %s', tecla, g.nome, g.desc)
	end
	Som.tocar("ui_selecao", nil)
end

local function criarCartao(pai: Instance, id: string, pos: UDim2)
	local s = Stands.get(id)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(168, 196)
	b.Position = pos
	b.BackgroundColor3 = UI.CORES.fundo
	b.BackgroundTransparency = 0.15
	b.Text = ""
	b.AutoButtonColor = false
	b.Parent = pai
	UI.canto(b, 14)
	local borda = UI.borda(b, Color3.fromRGB(60, 40, 90), 2)
	UI.gradiente(b, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 170), 90)
	local brilho = UI.frame(b, UDim2.new(1, -12, 0, 120), UDim2.fromOffset(6, 6), s.aura, 0.82)
	UI.canto(brilho, 10)
	viewport(b, id, UDim2.new(1, -12, 0, 126), UDim2.fromOffset(6, 4))
	UI.texto(b, s.nome, UDim2.new(1, -10, 0, 30), UDim2.fromOffset(5, 128), { cor = s.aura, contornoEsp = 2 })
	UI.texto(b, s.tipo .. "  " .. estrelas(s.dificuldade), UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 160), { cor = UI.CORES.branco, limite = 18 })
	b.MouseButton1Click:Connect(function()
		selecionar(id)
	end)
	cartoes[id] = { botao = b, borda = borda }
end

local function camadaPainel(titulo: string): Frame
	local f = UI.frame(gui, UDim2.fromOffset(620, 420), UDim2.new(0.5, -310, 0.5, -210), UI.CORES.fundo, 0.05)
	UI.canto(f, 16)
	UI.borda(f, UI.CORES.dourado, 3)
	f.ZIndex = 20
	f.Visible = false
	UI.texto(f, titulo, UDim2.new(1, -20, 0, 44), UDim2.fromOffset(10, 8), { cor = UI.CORES.dourado, z = 21 })
	local fechar = UI.botao(f, "FECHAR", UDim2.fromOffset(140, 44), UDim2.new(0.5, -70, 1, -56), UI.CORES.vermelho, { z = 22 })
	fechar.MouseButton1Click:Connect(function()
		f.Visible = false
		Som.tocar("ui_clique", nil)
	end)
	return f
end

local function criarControles()
	painelControles = camadaPainel("CONTROLES")
	local texto = table.concat({
		"<b>CELULAR</b>: ATACAR (segure para o combo) · BLOQ (segure; aperte na hora do golpe = <font color='#8CDCFF'>PARRY</font>)",
		"DASH (para o lado que estiver andando) · DASH atordoado = <font color='#FFCE40'>EVASIVA</font> (sai do combo)",
		"1 a 4 = golpes do Stand · DESPERTAR quando a barra encher (depois vira ULT) · STAND = chama/guarda o Stand",
		"TRAVAR = a câmera segue o inimigo mais perto · POSE = pose bizarra",
		"",
		"<b>PC</b>: clique = M1 · F = bloquear · Q = dash/evasiva · 1-4 = golpes · G = despertar/ULT",
		"E = Stand · T = travar · B = pose · Shift = travar a câmera do Roblox",
		"",
		"<b>DICAS</b>: o 4º soco arremessa e QUEBRA PAREDES. Pulando no 4º = para cima; no ar = crava no chão.",
		"O mapa se reconstrói sozinho. Quanto mais você bate e apanha, mais a barra de DESPERTAR enche.",
	}, "\n")
	local t = UI.texto(painelControles, texto, UDim2.new(1, -40, 1, -130), UDim2.fromOffset(20, 60), { rico = true, quebrar = true, alinhar = Enum.TextXAlignment.Left, alinharY = Enum.TextYAlignment.Top, fonte = UI.FONTE_TEXTO, limite = 17, z = 21 })
	local _ = t
end

local function criarAjustes(aoMudar: (any) -> ())
	painelAjustes = camadaPainel("AJUSTES")
	local y = 70
	local function linha(rotulo: string, obter: () -> string, aoTocar: () -> ())
		UI.texto(painelAjustes, rotulo, UDim2.fromOffset(300, 40), UDim2.fromOffset(30, y), { alinhar = Enum.TextXAlignment.Left, z = 21 })
		local b = UI.botao(painelAjustes, obter(), UDim2.fromOffset(220, 46), UDim2.fromOffset(360, y - 3), UI.CORES.roxo, { z = 22 })
		b.MouseButton1Click:Connect(function()
			aoTocar()
			local rot = b:FindFirstChild("Rotulo") :: TextLabel
			rot.Text = obter()
			Som.tocar("ui_clique", nil)
			aoMudar(ajustes)
		end)
		y += 64
	end
	linha("MÚSICA", function()
		return if ajustes.musica <= 0 then "DESLIGADA" else string.format("%d%%", math.floor(ajustes.musica / Config.VOLUME_MUSICA * 100 + 0.5))
	end, function()
		local passos = { Config.VOLUME_MUSICA, Config.VOLUME_MUSICA * 0.5, 0, Config.VOLUME_MUSICA * 1.6 }
		local i = 1
		for k, v in passos do
			if math.abs(v - ajustes.musica) < 0.01 then
				i = k
			end
		end
		ajustes.musica = passos[i % #passos + 1]
	end)
	linha("EFEITOS", function()
		return if ajustes.efeitosAltos then "ALTOS" else "LEVES (celular fraco)"
	end, function()
		ajustes.efeitosAltos = not ajustes.efeitosAltos
	end)
	linha("TREMOR DA CÂMERA", function()
		return if ajustes.tremor then "LIGADO" else "DESLIGADO"
	end, function()
		ajustes.tremor = not ajustes.tremor
	end)
end

local function aplicarAjustes(a: any)
	Som.volumeMusica(a.musica)
	Efeitos.qualidade(a.efeitosAltos)
	Camera.ligarTremor(a.tremor)
end

local function criar()
	gui = Instance.new("ScreenGui")
	gui.Name = "BB_Menu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = plr:WaitForChild("PlayerGui")
	UI.escalaTela(gui, 1100, 600, 0.5, 1.2)
	local fundo = UI.frame(gui, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(10, 4, 24), 0.25)
	local g = Instance.new("UIGradient")
	g.Rotation = 0
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.55, 0.35), NumberSequenceKeypoint.new(1, 0.15) })
	g.Parent = fundo
	-- título
	local titulo = UI.texto(gui, "BIZARRE", UDim2.fromOffset(330, 70), UDim2.fromOffset(24, 8), { cor = UI.CORES.dourado, contornoEsp = 4, alinhar = Enum.TextXAlignment.Left })
	titulo.Rotation = -3
	UI.texto(gui, "BATTLEGROUNDS", UDim2.fromOffset(330, 40), UDim2.fromOffset(30, 66), { cor = UI.CORES.branco, contornoEsp = 3, alinhar = Enum.TextXAlignment.Left })
	UI.texto(gui, "escolha o seu Stand", UDim2.fromOffset(250, 24), UDim2.fromOffset(372, 82), { cor = Color3.fromRGB(210, 190, 255), alinhar = Enum.TextXAlignment.Left })
	-- cartões
	for i, id in Stands.ORDEM do
		local col = (i - 1) % 3
		local lin = math.floor((i - 1) / 3)
		criarCartao(gui, id, UDim2.fromOffset(24 + col * 180, 116 + lin * 206))
	end
	-- detalhes
	local p = UI.frame(gui, UDim2.fromOffset(500, 470), UDim2.fromOffset(580, 18), UI.CORES.fundo, 0.12)
	UI.canto(p, 16)
	UI.borda(p, UI.CORES.roxo, 2, 0.2)
	detalhe.nome = UI.texto(p, "", UDim2.new(1, -24, 0, 56), UDim2.fromOffset(12, 8), { contornoEsp = 3, alinhar = Enum.TextXAlignment.Left })
	detalhe.titulo = UI.texto(p, "", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(14, 62), { cor = UI.CORES.branco, alinhar = Enum.TextXAlignment.Left })
	detalhe.tipo = UI.texto(p, "", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(14, 90), { cor = UI.CORES.dourado, alinhar = Enum.TextXAlignment.Left, limite = 20 })
	detalhe.desc = UI.texto(p, "", UDim2.new(1, -28, 0, 56), UDim2.fromOffset(14, 116), { fonte = UI.FONTE_TEXTO, quebrar = true, alinhar = Enum.TextXAlignment.Left, alinharY = Enum.TextYAlignment.Top, limite = 16 })
	detalhe.passiva = UI.texto(p, "", UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 176), { fonte = UI.FONTE_TEXTO, cor = Color3.fromRGB(150, 230, 190), alinhar = Enum.TextXAlignment.Left, limite = 15 })
	detalhe.golpes = {}
	for i = 1, 5 do
		local t = UI.texto(p, "", UDim2.new(1, -28, 0, 46), UDim2.fromOffset(14, 202 + (i - 1) * 48), { fonte = UI.FONTE_TEXTO, rico = true, quebrar = true, alinhar = Enum.TextXAlignment.Left, alinharY = Enum.TextYAlignment.Top, limite = 15 })
		detalhe.golpes[i] = t
	end
	-- botões
	botaoLutar = UI.botao(gui, "LUTAR!", UDim2.fromOffset(240, 70), UDim2.fromOffset(580, 500), UI.CORES.dourado, { corTexto = Color3.fromRGB(40, 20, 10), limite = 44 })
	local treinar = UI.botao(gui, "TREINAR", UDim2.fromOffset(150, 56), UDim2.fromOffset(830, 507), UI.CORES.roxo, { limite = 30 })
	local controles = UI.botao(gui, "CONTROLES", UDim2.fromOffset(120, 40), UDim2.fromOffset(24, 540), Color3.fromRGB(60, 50, 90), { limite = 22 })
	local ajustesB = UI.botao(gui, "AJUSTES", UDim2.fromOffset(110, 40), UDim2.fromOffset(152, 540), Color3.fromRGB(60, 50, 90), { limite = 22 })
	botaoVoltar = UI.botao(gui, "VOLTAR", UDim2.fromOffset(100, 56), UDim2.fromOffset(988, 507), UI.CORES.vermelho, { limite = 26 })
	botaoVoltar.Visible = false
	criarControles()
	criarAjustes(aplicarAjustes)
	local function entrar(modo: string)
		Som.tocar("gongo", nil)
		remotos.Entrar:FireServer({ stand = selecionado, modo = modo, bot = modo == "treino" })
		Menu.fechar(true)
	end
	botaoLutar.MouseButton1Click:Connect(function()
		entrar("luta")
	end)
	treinar.MouseButton1Click:Connect(function()
		entrar("treino")
	end)
	controles.MouseButton1Click:Connect(function()
		painelControles.Visible = true
		painelAjustes.Visible = false
		Som.tocar("ui_clique", nil)
	end)
	ajustesB.MouseButton1Click:Connect(function()
		painelAjustes.Visible = true
		painelControles.Visible = false
		Som.tocar("ui_clique", nil)
	end)
	botaoVoltar.MouseButton1Click:Connect(function()
		Menu.fechar(false)
	end)
	selecionar(selecionado)
end

local function cameraMenu()
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local t0 = os.clock()
	if conexaoCamera then
		conexaoCamera:Disconnect()
	end
	conexaoCamera = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local a = t * 0.06
		-- voo por cima de Morioh (acima dos prédios de 4 a 6 andares)
		local raio = 165 + math.sin(t * 0.13) * 15
		local pos = Vector3.new(math.cos(a) * raio, 125 + math.sin(t * 0.2) * 8, math.sin(a) * raio)
		cam.CFrame = CFrame.lookAt(pos, Vector3.new(0, 10, 0))
	end)
end

function Menu.abrir(noJogo: boolean?)
	aberto = true
	gui.Enabled = true
	botaoVoltar.Visible = noJogo == true
	local rotulo = botaoLutar:FindFirstChild("Rotulo") :: TextLabel
	rotulo.Text = if noJogo then "TROCAR!" else "LUTAR!"
	if not noJogo then
		cameraMenu()
		Som.musica("menu")
	end
end

function Menu.fechar(entrou: boolean)
	aberto = false
	gui.Enabled = false
	painelControles.Visible = false
	painelAjustes.Visible = false
	if conexaoCamera then
		conexaoCamera:Disconnect()
		conexaoCamera = nil
	end
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	if aoFechar then
		aoFechar(entrou)
	end
end

function Menu.aberto(): boolean
	return aberto
end

function Menu.iniciar(rem: any, fechou: (entrou: boolean) -> ())
	remotos = rem
	aoFechar = fechou
	criar()
	aplicarAjustes(ajustes)
	gui.Enabled = false
	local _ = UserInputService
	local _ = TweenService
end

return Menu
