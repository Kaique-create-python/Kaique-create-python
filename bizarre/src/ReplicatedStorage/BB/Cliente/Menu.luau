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
local Entrada = require(BB:WaitForChild("Entrada"))
local UI = require(script.Parent:WaitForChild("Interface"))
local Som = require(script.Parent:WaitForChild("Som"))
local Efeitos = require(script.Parent:WaitForChild("Efeitos"))
local Camera = require(script.Parent:WaitForChild("Camera"))

local Menu = {}

local plr = Players.LocalPlayer
local gui: ScreenGui
local remotos: any
local conteudo: Frame
local statusTxt: TextLabel
local pedido = Entrada.novoCliente()
local previas: { any } = {}
local conexaoPrevias: RBXScriptConnection? = nil
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
local ajustes: { [string]: any } = { musica = 1, efeitos = 1, qualidade = "auto", tremor = 1, camera = 12.5, mira = true }

local function estrelas(n: number): string
	return string.rep("★", n) .. string.rep("☆", 3 - n)
end

-- AJUSTE7: todas as prévias giram numa atualização só, e ela para quando o menu está fechado
local function animarPrevias(ligar: boolean)
	if conexaoPrevias then
		conexaoPrevias:Disconnect()
		conexaoPrevias = nil
	end
	if not ligar then
		return
	end
	local acum = 0
	conexaoPrevias = RunService.Heartbeat:Connect(function(dt)
		acum += dt
		if acum < 1 / 30 then
			return
		end
		for _, p in previas do
			if p.vp.Parent and p.vp.Visible then
				p.ang += acum * 0.6
				p.modelo:PivotTo(CFrame.Angles(0, p.ang, 0))
			end
		end
		acum = 0
	end)
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
		table.insert(previas, { vp = vp, modelo = m, ang = math.random() * 6 })
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
	detalhe.titulo.Text = string.format("%s · %s (%s)", tostring(s.usuario), tostring(s.parte), s.titulo)
	-- AJUSTE-4: os status oficiais de Stand da JoJo (letras de A a E)
	local CORES_LETRA = { A = "#FFCE40", B = "#5BE08A", C = "#5AAAFF", D = "#B0A8C0", E = "#FF5A64" }
	local CURTO = { "PODER", "VELOC.", "ALCANCE", "RESIST.", "PRECISÃO", "POTENC." }
	local partes = {}
	for i, letra in s.stats or {} do
		table.insert(partes, string.format('%s <font color="%s"><b>%s</b></font>', CURTO[i] or "?", CORES_LETRA[letra] or "#FFFFFF", letra))
	end
	detalhe.tipo.Text = table.concat(partes, "   ")
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
	local f = UI.frame(conteudo, UDim2.fromOffset(620, 420), UDim2.new(0.5, -310, 0.5, -210), UI.CORES.fundo, 0.05)
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

-- AJUSTE7: ajustes completos (cada toque troca para a próxima opção)
local OPCOES = {
	musica = { { "100%", 1 }, { "50%", 0.5 }, { "DESLIGADA", 0 }, { "160%", 1.6 } },
	efeitos = { { "100%", 1 }, { "70%", 0.7 }, { "40%", 0.4 }, { "SEM SOM", 0 } },
	qualidade = { { "AUTOMÁTICA", "auto" }, { "BAIXA (celular fraco)", "baixa" }, { "ALTA", "alta" } },
	tremor = { { "NORMAL", 1 }, { "FORTE", 1.4 }, { "LEVE", 0.5 }, { "DESLIGADO", 0 } },
	camera = { { "NORMAL", 12.5 }, { "LONGE", 16 }, { "MUITO LONGE", 20 }, { "PERTO", 9 } },
	mira = { { "GRUDA SOZINHA", true }, { "SÓ NO BOTÃO MIRA", false } },
}
local LINHAS = { { "musica", "MÚSICA" }, { "efeitos", "VOLUME DOS EFEITOS" }, { "qualidade", "QUALIDADE" }, { "tremor", "TREMOR DA CÂMERA" }, { "camera", "DISTÂNCIA DA CÂMERA" }, { "mira", "MIRA NA LUTA" } }

local function rotuloDe(chave: string): string
	for _, o in OPCOES[chave] do
		if o[2] == ajustes[chave] then
			return o[1]
		end
	end
	return "?"
end

local function proximaOpcao(chave: string)
	local lista = OPCOES[chave]
	local i = 1
	for k, o in lista do
		if o[2] == ajustes[chave] then
			i = k
		end
	end
	ajustes[chave] = lista[i % #lista + 1][2]
end

local function criarAjustes(aoMudar: (any, string?) -> ())
	painelAjustes = camadaPainel("AJUSTES")
	local y = 62
	for _, def in LINHAS do
		local chave = def[1]
		UI.texto(painelAjustes, def[2], UDim2.fromOffset(290, 36), UDim2.fromOffset(30, y), { alinhar = Enum.TextXAlignment.Left, z = 21, limite = 24 })
		local b = UI.botao(painelAjustes, rotuloDe(chave), UDim2.fromOffset(250, 42), UDim2.fromOffset(340, y - 3), UI.CORES.roxo, { z = 22, limite = 22 })
		b.MouseButton1Click:Connect(function()
			proximaOpcao(chave)
			local rot = b:FindFirstChild("Rotulo") :: TextLabel
			rot.Text = rotuloDe(chave)
			Som.tocar("ui_clique", nil)
			aoMudar(ajustes, chave)
		end)
		y += 56
	end
end

local function aplicarAjustes(a: any, chave: string?)
	Som.volumeMusica(Config.VOLUME_MUSICA * a.musica)
	Som.volumeEfeitos(Config.VOLUME_EFEITOS * a.efeitos)
	Efeitos.modoQualidade(a.qualidade)
	Camera.ligarTremor(a.tremor > 0)
	Camera.forcaTremor = a.tremor
	Camera.miraAuto = a.mira ~= false
	if chave == "camera" then
		Camera.distancia(a.camera)
	end
end

-- AJUSTE-8: tela de abertura (só na primeira vez): arte do Canva, logo grande, raios de mangá,
-- ゴゴゴ e "TOQUE PARA LUTAR". Sem as imagens (moderação), fica o logo de texto por cima de Morioh.
local function criarAbertura()
	local a = Instance.new("TextButton")
	a.Name = "Abertura"
	a.Size = UDim2.fromScale(1, 1)
	a.BackgroundColor3 = Color3.fromRGB(14, 8, 26)
	a.BackgroundTransparency = 0.3
	a.BorderSizePixel = 0
	a.AutoButtonColor = false
	a.Text = ""
	a.ZIndex = 50
	a.Parent = gui
	UI.gradiente(a, Color3.fromRGB(120, 60, 200), Color3.fromRGB(20, 10, 34), 70)
	local arte = UI.imagemOpcional(a, "fundo", { Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, ZIndex = 1 }, function()
		a.BackgroundTransparency = 0
	end)
	if arte then
		UI.zoomLento(arte, 0.08, 14)
	end
	-- escurece embaixo e nas bordas (o texto sempre aparece bem)
	local sombra = UI.frame(a, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(6, 2, 12), 0)
	sombra.ZIndex = 2
	local gs = Instance.new("UIGradient")
	gs.Rotation = 90
	gs.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.45, 0.85), NumberSequenceKeypoint.new(0.75, 0.55), NumberSequenceKeypoint.new(1, 0.1) })
	gs.Parent = sombra
	-- raios de mangá girando atrás do logo
	local raios = {}
	for i = 1, 16 do
		local r = UI.frame(a, UDim2.new(1.7, 0, 0, if i % 2 == 0 then 10 else 4), UDim2.fromScale(0.5, 0.4), if i % 3 == 0 then UI.CORES.dourado else Color3.fromRGB(190, 110, 255), 0.35)
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.ZIndex = 3
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.53, 1), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = r
		table.insert(raios, r)
	end
	-- logo: imagem do Canva; até ela carregar, o logo de texto
	local t1 = UI.texto(a, "BIZARRE", UDim2.fromScale(0.62, 0.2), UDim2.fromScale(0.19, 0.2), { cor = UI.CORES.dourado, contornoEsp = 5, z = 6 })
	t1.Rotation = -5
	UI.gradiente(t1, Color3.fromRGB(255, 246, 190), Color3.fromRGB(255, 160, 20), 90)
	local t2 = UI.texto(a, "BATTLEGROUNDS", UDim2.fromScale(0.5, 0.1), UDim2.fromScale(0.26, 0.41), { contornoEsp = 4, z = 6 })
	t2.Rotation = -4
	local logo = UI.imagemOpcional(a, "logo", { Size = UDim2.fromScale(0.72, 0.62), Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 7 }, function()
		t1.Visible = false
		t2.Visible = false
	end)
	if logo then
		local prop = Instance.new("UIAspectRatioConstraint")
		prop.AspectRatio = 2
		prop.Parent = logo
		UI.zoomLento(logo, 0.035, 1.6)
	end
	-- ゴゴゴ nas bordas
	local gogo = {}
	for i = 1, 8 do
		local esq = i <= 4
		local l = UI.texto(a, "ゴ", UDim2.fromScale(0.07, 0.11), UDim2.fromScale(if esq then 0.03 + (i % 2) * 0.05 else 0.86 + (i % 2) * 0.05, 0.12 + ((i - 1) % 4) * 0.18), { cor = Color3.fromRGB(200, 120, 255), contornoEsp = 3, z = 8, fonte = Enum.Font.GothamBlack })
		table.insert(gogo, l)
	end
	local toque = UI.texto(a, "TOQUE PARA LUTAR", UDim2.fromScale(0.5, 0.075), UDim2.fromScale(0.25, 0.76), { contornoEsp = 3, contornoCor = Color3.fromRGB(60, 20, 90), z = 9 })
	UI.texto(a, "versão " .. tostring(Config.REVISAO), UDim2.fromScale(0.2, 0.035), UDim2.fromScale(0.78, 0.94), { cor = Color3.fromRGB(200, 190, 230), z = 9, fonte = UI.FONTE_TEXTO, alinhar = Enum.TextXAlignment.Right })
	local t0 = os.clock()
	local con = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		for i, r in raios do
			r.Rotation = (i / #raios) * 360 + t * 6
		end
		for i, l in gogo do
			l.Rotation = math.sin(t * 2.4 + i) * 12
			l.TextTransparency = 0.15 + (math.sin(t * 3 + i * 1.7) * 0.5 + 0.5) * 0.5
		end
		toque.TextTransparency = 0.1 + (math.sin(t * 4) * 0.5 + 0.5) * 0.55
	end)
	local saindo = false
	a.Activated:Connect(function()
		if saindo then
			return
		end
		saindo = true
		Som.tocar("gongo", nil)
		local brilho = UI.frame(a, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(255, 255, 255), 0.1)
		brilho.ZIndex = 20
		local info = TweenInfo.new(0.45)
		for _, d in a:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, info, { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			elseif d:IsA("ImageLabel") then
				TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
			elseif d:IsA("Frame") then
				TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
			end
		end
		TweenService:Create(a, info, { BackgroundTransparency = 1 }):Play()
		task.delay(0.5, function()
			con:Disconnect()
			a:Destroy()
		end)
	end)
end

local function criar()
	gui = Instance.new("ScreenGui")
	gui.Name = "BB_Menu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = plr:WaitForChild("PlayerGui")
	local fundo = UI.frame(gui, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(8, 6, 14), 0.2)
	-- AJUSTE7: o menu fica num quadro de 1100x600 no MEIO da tela, que cresce ou encolhe junto
	-- (celular, PC e TV com a mesma proporção; nada colado no canto)
	conteudo = Instance.new("Frame")
	conteudo.Name = "Conteudo"
	conteudo.Size = UDim2.fromOffset(1100, 600)
	conteudo.AnchorPoint = Vector2.new(0.5, 0.5)
	conteudo.Position = UDim2.fromScale(0.5, 0.5)
	conteudo.BackgroundTransparency = 1
	conteudo.Parent = gui
	local escala = Instance.new("UIScale")
	escala.Parent = conteudo
	local function ajustarEscala()
		local tam = gui.AbsoluteSize
		if tam.X >= 10 then
			escala.Scale = math.clamp(math.min(tam.X / 1100, tam.Y / 600), 0.4, 1.8)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ajustarEscala)
	ajustarEscala()
	local g = Instance.new("UIGradient")
	g.Rotation = 0
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.55, 0.35), NumberSequenceKeypoint.new(1, 0.15) })
	g.Parent = fundo
	-- AJUSTE-8: arte do Canva atrás do menu (sem ela, o voo por Morioh continua aparecendo)
	local arte = UI.imagemOpcional(gui, "fundo", { Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, ZIndex = 0 }, function()
		fundo.BackgroundTransparency = 0.3
	end)
	if arte then
		UI.zoomLento(arte, 0.06, 18)
	end
	-- título
	local titulo = UI.texto(conteudo, "BIZARRE", UDim2.fromOffset(330, 70), UDim2.fromOffset(24, 8), { cor = UI.CORES.dourado, contornoEsp = 4, alinhar = Enum.TextXAlignment.Left })
	titulo.Rotation = -3
	local subtitulo = UI.texto(conteudo, "BATTLEGROUNDS", UDim2.fromOffset(330, 40), UDim2.fromOffset(30, 66), { cor = UI.CORES.branco, contornoEsp = 3, alinhar = Enum.TextXAlignment.Left })
	-- AJUSTE-8: logo do jogo (recortado da imagem 1024x512) no lugar do texto, quando carregar
	UI.imagemOpcional(conteudo, "logo", { Size = UDim2.fromOffset(272, 128), Position = UDim2.fromOffset(16, -12), ImageRectOffset = Vector2.new(40, 26), ImageRectSize = Vector2.new(980, 460), ZIndex = 6 }, function()
		titulo.Visible = false
		subtitulo.Visible = false
	end)
	UI.texto(conteudo, "escolha o seu Stand", UDim2.fromOffset(250, 24), UDim2.fromOffset(372, 82), { cor = Color3.fromRGB(210, 190, 255), alinhar = Enum.TextXAlignment.Left })
	-- cartões
	for i, id in Stands.ORDEM do
		local col = (i - 1) % 3
		local lin = math.floor((i - 1) / 3)
		criarCartao(conteudo, id, UDim2.fromOffset(24 + col * 180, 116 + lin * 206))
	end
	-- detalhes
	local p = UI.frame(conteudo, UDim2.fromOffset(500, 470), UDim2.fromOffset(580, 18), UI.CORES.fundo, 0.12)
	UI.canto(p, 16)
	UI.borda(p, UI.CORES.roxo, 2, 0.2)
	detalhe.nome = UI.texto(p, "", UDim2.new(1, -24, 0, 56), UDim2.fromOffset(12, 8), { contornoEsp = 3, alinhar = Enum.TextXAlignment.Left })
	detalhe.titulo = UI.texto(p, "", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(14, 62), { cor = UI.CORES.branco, alinhar = Enum.TextXAlignment.Left })
	detalhe.tipo = UI.texto(p, "", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(14, 90), { cor = UI.CORES.branco, alinhar = Enum.TextXAlignment.Left, limite = 18 })
	detalhe.tipo.RichText = true
	detalhe.desc = UI.texto(p, "", UDim2.new(1, -28, 0, 56), UDim2.fromOffset(14, 116), { fonte = UI.FONTE_TEXTO, quebrar = true, alinhar = Enum.TextXAlignment.Left, alinharY = Enum.TextYAlignment.Top, limite = 16 })
	detalhe.passiva = UI.texto(p, "", UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 176), { fonte = UI.FONTE_TEXTO, cor = Color3.fromRGB(150, 230, 190), alinhar = Enum.TextXAlignment.Left, limite = 15 })
	detalhe.golpes = {}
	for i = 1, 5 do
		local t = UI.texto(p, "", UDim2.new(1, -28, 0, 46), UDim2.fromOffset(14, 202 + (i - 1) * 48), { fonte = UI.FONTE_TEXTO, rico = true, quebrar = true, alinhar = Enum.TextXAlignment.Left, alinharY = Enum.TextYAlignment.Top, limite = 15 })
		detalhe.golpes[i] = t
	end
	-- botões
	botaoLutar = UI.botao(conteudo, "LUTAR!", UDim2.fromOffset(240, 70), UDim2.fromOffset(580, 500), UI.CORES.dourado, { corTexto = Color3.fromRGB(40, 20, 10), limite = 44 })
	local treinar = UI.botao(conteudo, "TREINAR", UDim2.fromOffset(150, 56), UDim2.fromOffset(830, 507), UI.CORES.roxo, { limite = 30 })
	local controles = UI.botao(conteudo, "CONTROLES", UDim2.fromOffset(120, 40), UDim2.fromOffset(24, 540), Color3.fromRGB(60, 50, 90), { limite = 22 })
	local ajustesB = UI.botao(conteudo, "AJUSTES", UDim2.fromOffset(110, 40), UDim2.fromOffset(152, 540), Color3.fromRGB(60, 50, 90), { limite = 22 })
	botaoVoltar = UI.botao(conteudo, "VOLTAR", UDim2.fromOffset(100, 56), UDim2.fromOffset(988, 507), UI.CORES.vermelho, { limite = 26 })
	botaoVoltar.Visible = false
	criarControles()
	criarAjustes(aplicarAjustes)
	statusTxt = UI.texto(conteudo, "", UDim2.fromOffset(500, 24), UDim2.fromOffset(580, 574), { cor = UI.CORES.dourado, limite = 20 })
	criarAbertura()
	-- AJUSTE7: o menu só fecha quando o servidor responde "ok" para ESTE pedido
	local function entrar(modo: string)
		local id = pedido.pedir(os.clock())
		if not id then
			return -- já tem um pedido indo (toque repetido não cria outra entrada)
		end
		Som.tocar("gongo", nil)
		statusTxt.Text = "Entrando..."
		remotos.Entrar:FireServer({ id = id, stand = selecionado, modo = modo, bot = modo == "treino" })
		task.delay(Entrada.ESPERA_MAXIMA + 0.3, function()
			if pedido.expirou(os.clock()) then
				statusTxt.Text = "O servidor não respondeu. Toque de novo."
			end
		end)
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
	Camera.assumir("menu")
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
	statusTxt.Text = ""
	animarPrevias(true)
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
	Camera.devolver("menu")
	animarPrevias(false)
	if aoFechar then
		aoFechar(entrou)
	end
end

-- resposta do servidor ao pedido de entrada ("entrada": id, ok, motivo)
function Menu.respostaEntrada(msg: any)
	local r = pedido.resposta(msg)
	if r == "ok" then
		statusTxt.Text = ""
		if aberto then
			Menu.fechar(true)
		end
	elseif r == "recusado" then
		statusTxt.Text = tostring(msg.motivo or "Não deu para entrar agora.")
		Som.tocar("ui_clique", nil)
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
