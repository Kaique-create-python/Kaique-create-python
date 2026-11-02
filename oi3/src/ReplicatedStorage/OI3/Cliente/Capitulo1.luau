-- OI3 :: Capítulo 1 no cliente (AJUSTE-6)
-- Escolha da criança -> tarde (explorar, conversar, 5 coisas estranhas) -> o Vô chama para o jantar
-- -> cena do jantar -> "mais tarde, naquela noite..." -> o ritual (cutscene) -> a noite.
-- O servidor (Historia) decide os momentos para o grupo inteiro ficar junto.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local OI3 = script.Parent.Parent
local Mapa = require(OI3.Mapa)
local Animacoes = require(OI3.Animacoes)
local Dialogos = require(OI3.Dialogos)
local Personagens = require(OI3.Personagens)
local Capitulo1Mapa = require(OI3.Capitulo1Mapa)
local Interface = require(script.Parent.Interface)
local Cinema = require(script.Parent.Cinema)
local Som = require(script.Parent.Som)
local Iluminacao = require(script.Parent.Iluminacao)
local Cutscene = require(script.Parent.Cutscene)

local Capitulo1 = {}

local COR = Interface.COR
local FONTE = Interface.FONTE
local RGB = Color3.fromRGB
local V3 = Vector3.new

Capitulo1.NOMES = { KE = "Keko", NI = "Nina", ME = "O menino" }
Capitulo1.SOBRE = {
	KE = "Curioso e brincalhão. Sempre o primeiro a explorar.",
	NI = "Observadora e esperta. Repara no que ninguém vê.",
	ME = "Quieto. Não lembra direito do próprio passado.",
}
-- o que aparece ao interagir com cada coisa estranha (curto: nada explica o mistério)
Capitulo1.DETALHES = {
	foto = { objeto = "Foto antiga", acao = "Olhar", texto = "Uma foto antiga de uma família. Alguém rabiscou o rosto do menino." },
	trancado = { objeto = "Porta", acao = "Abrir", texto = "Trancada. Essa porta nunca abre." },
	tv = { objeto = "TV velha", acao = "Olhar", texto = "O fio da TV está fora da tomada." },
	brinquedos = { objeto = "Caixa de brinquedos", acao = "Olhar", texto = "Três ursinhos iguais, guardados juntos." },
	porao = { objeto = "Porta do porão", acao = "Abrir", texto = "Corrente e cadeado." },
}
local ANCORAS = { foto = "OI3_Foto", trancado = "OI3_PortaTrancada", tv = "OI3_TV", brinquedos = "OI3_CaixaBrinquedos", porao = "OI3_PortaPorao" }

local estado = {
	ctx = nil :: any,
	fase = "nada",
	tela = nil :: ScreenGui?,
	objetivo = nil :: TextLabel?,
	contador = nil :: TextLabel?,
	aviso = nil :: TextLabel?,
	total = 5,
	achados = {} :: { [string]: boolean },
	coisas = {} :: { Instance },
	conexoes = {} :: { RBXScriptConnection },
	vo = nil :: Model?,
	escolha = nil :: ScreenGui?,
	cartoes = {} :: { [string]: any },
	grupo = 1,
	escolhas = {} :: { [string]: string },
	quem = {} :: { [string]: string },
	token = 0,
}

local function orfanato(): Instance?
	return workspace:FindFirstChild("Orfanato")
end

local function acharNoMapa(nome: string): BasePart?
	local o = orfanato()
	local p = o and o:FindFirstChild(nome, true)
	return if p and p:IsA("BasePart") then p else nil
end

-- fala do Vô: com voz quando o áudio existe; legenda sempre (mesmo com legendas desligadas, se não há voz)
local function falar(id: string): number
	local fala = Dialogos.FALAS[id]
	local dur = Som.duracao(id) or (fala and math.clamp(#fala.texto / 14, 2, 6)) or 3
	if Som.disponivel(id) then
		Som.tocar(id, { grupo = "Vozes" })
		Cinema.legenda(id, dur + 0.4)
	else
		Cinema.legenda(id, dur + 0.6, true)
	end
	return dur
end

---------------------------------------------------------------------------
-- HUD da história: objetivo + contador + aviso curto embaixo
---------------------------------------------------------------------------
local function criarTela()
	if estado.tela then
		return
	end
	local tela = Interface.tela("OI3_Historia", 6, true)
	local caixa = Instance.new("Frame")
	caixa.Name = "Objetivo"
	caixa.Position = UDim2.new(0, 14, 0, 12)
	caixa.Size = UDim2.fromOffset(300, 54)
	caixa.BackgroundColor3 = RGB(16, 14, 18)
	caixa.BackgroundTransparency = 0.35
	caixa.Parent = tela
	Interface.canto(caixa, 4)
	estado.objetivo = Interface.texto(caixa, {
		Text = "",
		FontFace = FONTE.textoForte,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 24),
	})
	estado.contador = Interface.texto(caixa, {
		Text = "",
		TextSize = 14,
		TextColor3 = COR.textoFraco,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 0, 20),
	})
	local aviso = Interface.texto(tela, {
		Name = "Aviso",
		Text = "",
		FontFace = FONTE.maquina,
		TextSize = 20,
		TextWrapped = true,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -70),
		Size = UDim2.new(0.7, 0, 0, 60),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	estado.aviso = aviso
	estado.tela = tela
end

local function objetivo(texto: string)
	criarTela()
	if estado.objetivo then
		estado.objetivo.Text = texto
	end
end

local function atualizarContador()
	if estado.contador then
		local n = 0
		for _ in estado.achados do
			n += 1
		end
		estado.contador.Text = if estado.fase == "tarde" then string.format("Coisas estranhas: %d/%d", n, estado.total) else ""
	end
end

local tokenAviso = 0
local function aviso(texto: string, tempo: number?)
	criarTela()
	local a = estado.aviso :: TextLabel
	tokenAviso += 1
	local t = tokenAviso
	a.Text = texto
	TweenService:Create(a, TweenInfo.new(0.25), { TextTransparency = 0, TextStrokeTransparency = 0.4 }):Play()
	task.delay(tempo or 4, function()
		if t == tokenAviso then
			TweenService:Create(a, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

---------------------------------------------------------------------------
-- Escolha da criança (avatares de verdade, do catálogo)
---------------------------------------------------------------------------
local function fecharEscolha()
	if estado.escolha then
		estado.escolha:Destroy()
		estado.escolha = nil
	end
	estado.cartoes = {}
end

local function atualizarCartoes(livres: { string }, quem: { [string]: string }?)
	estado.livres = livres
	if quem then
		estado.quem = quem
	end
	local nomes = estado.quem or {}
	for cod, cartao in estado.cartoes do
		local minha = estado.minha == cod
		local livre = table.find(livres, cod) ~= nil
		local pode = livre and not estado.minha
		cartao.botao.Active = pode
		cartao.botao.AutoButtonColor = pode
		local dono = nomes[cod]
		cartao.botao.Text = if minha
			then "VOCÊ"
			elseif pode then "ESCOLHER"
			elseif livre then "LIVRE"
			elseif dono then "COM " .. string.upper(string.sub(dono, 1, 14))
			else "OCUPADO"
		cartao.botao.BackgroundColor3 = if minha then RGB(150, 112, 52) elseif pode then RGB(120, 28, 28) else RGB(44, 40, 46)
		cartao.frame.BackgroundTransparency = if minha or livre then 0.15 else 0.55
	end
end

function Capitulo1.mostrarEscolha(info: any)
	fecharEscolha()
	estado.minha = nil
	estado.quem = {}
	estado.grupo = (info and info.grupo) or 1
	local tela = Interface.tela("OI3_Escolha", 20, false)
	estado.escolha = tela
	local fundo = Instance.new("Frame")
	fundo.Size = UDim2.fromScale(1, 1)
	fundo.BackgroundColor3 = RGB(8, 7, 10)
	fundo.BackgroundTransparency = 0.08
	fundo.Parent = tela
	Interface.texto(fundo, {
		Text = "COM QUEM VOCÊ VAI BRINCAR?",
		FontFace = FONTE.titulo,
		TextSize = 26,
		TextColor3 = COR.ouro,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.new(0.9, 0, 0, 34),
	})
	local tempo = Interface.texto(fundo, {
		Text = "",
		TextSize = 14,
		TextColor3 = COR.textoFraco,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.new(0.9, 0, 0, 20),
	})
	local linha = Instance.new("Frame")
	linha.BackgroundTransparency = 1
	linha.AnchorPoint = Vector2.new(0.5, 0.5)
	linha.Position = UDim2.fromScale(0.5, 0.56)
	linha.Size = UDim2.new(0.94, 0, 0.74, 0)
	linha.Parent = fundo
	local lista = Instance.new("UIListLayout")
	lista.FillDirection = Enum.FillDirection.Horizontal
	lista.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lista.VerticalAlignment = Enum.VerticalAlignment.Center
	lista.Padding = UDim.new(0.02, 0)
	lista.Parent = linha
	for _, cod in { "KE", "NI", "ME" } do
		local f = Instance.new("Frame")
		f.Size = UDim2.new(0.3, 0, 1, 0)
		f.BackgroundColor3 = RGB(28, 25, 31)
		f.BackgroundTransparency = 0.15
		f.Parent = linha
		Interface.canto(f, 4)
		Interface.borda(f, COR.borda, 1, 0.4)
		local vp = Instance.new("ViewportFrame")
		vp.BackgroundTransparency = 1
		vp.Size = UDim2.new(1, 0, 0.6, 0)
		vp.Ambient = RGB(170, 160, 150)
		vp.LightColor = RGB(255, 240, 220)
		vp.LightDirection = V3(-0.6, -0.7, -1)
		vp.Parent = f
		task.spawn(function()
			local ok, m = pcall(Personagens.criar, cod)
			if not ok or not m or not vp.Parent then
				return
			end
			local s = m:GetAttribute("Escala") or 1
			m:PivotTo(CFrame.new(0, 3 * s, 0) * CFrame.Angles(0, math.rad(180), 0))
			m.Parent = vp
			local cam = Instance.new("Camera")
			cam.FieldOfView = 34
			cam.CFrame = CFrame.lookAt(V3(0.4, 3.9 * s, -9.5 * s), V3(0, 3.2 * s, 0))
			cam.Parent = vp
			vp.CurrentCamera = cam
		end)
		Interface.texto(f, {
			Text = Capitulo1.NOMES[cod],
			FontFace = FONTE.titulo,
			TextSize = 22,
			Position = UDim2.new(0, 8, 0.6, 2),
			Size = UDim2.new(1, -16, 0, 28),
		})
		Interface.texto(f, {
			Text = Capitulo1.SOBRE[cod],
			TextSize = 14,
			TextWrapped = true,
			TextColor3 = COR.textoFraco,
			Position = UDim2.new(0, 8, 0.6, 30),
			Size = UDim2.new(1, -16, 0.4, -84),
		})
		local b = Interface.botao(f, "ESCOLHER", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 44),
			BackgroundColor3 = RGB(120, 28, 28),
		}, function()
			if estado.minha or (estado.livres and not table.find(estado.livres, cod)) then
				return
			end
			estado.minha = cod
			atualizarCartoes(estado.livres or {})
			estado.ctx.remoto:FireServer("escolher", cod)
		end)
		estado.cartoes[cod] = { frame = f, botao = b }
	end
	atualizarCartoes((info and info.livres) or { "KE", "NI", "ME" })
	local fim = os.clock() + ((info and info.tempo) or 25)
	task.spawn(function()
		while estado.escolha == tela do
			local resta = math.max(0, math.ceil(fim - os.clock()))
			tempo.Text = if estado.grupo > 1 then string.format("Cada um escolhe uma criança. Começa em %d s.", resta) else string.format("Começa em %d s.", resta)
			task.wait(0.25)
		end
	end)
end

---------------------------------------------------------------------------
-- A tarde
---------------------------------------------------------------------------
local function limparCoisas()
	for _, c in estado.conexoes do
		c:Disconnect()
	end
	estado.conexoes = {}
	for _, x in estado.coisas do
		x:Destroy()
	end
	estado.coisas = {}
	if estado.vo then
		estado.vo:Destroy()
		estado.vo = nil
	end
end

local function prompt(parte: BasePart, acao: string, objeto: string, aoUsar: () -> ())
	local p = Instance.new("ProximityPrompt")
	p.Name = "OI3_Interagir"
	p.ActionText = acao
	p.ObjectText = objeto
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.HoldDuration = 0
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = parte
	table.insert(estado.coisas, p)
	table.insert(estado.conexoes, p.Triggered:Connect(aoUsar))
	return p
end

local function mostrarFoto()
	criarTela()
	local tela = estado.tela :: ScreenGui
	local velho = tela:FindFirstChild("FotoGrande")
	if velho then
		velho:Destroy()
	end
	-- escurece o fundo e a foto "chega" girando de leve, como se fosse pega na mão
	local f = Instance.new("TextButton")
	f.Name = "FotoGrande"
	f.Text = ""
	f.AutoButtonColor = false
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = RGB(0, 0, 0)
	f.BackgroundTransparency = 1
	f.ZIndex = 20
	f.Parent = tela
	local foto = Instance.new("Frame")
	foto.AnchorPoint = Vector2.new(0.5, 0.5)
	foto.Position = UDim2.fromScale(0.5, 0.56)
	foto.Size = UDim2.fromScale(0.62, 0.66)
	foto.BackgroundTransparency = 1
	foto.Rotation = -7
	foto.ZIndex = 21
	foto.Parent = f
	local proporcao = Instance.new("UIAspectRatioConstraint")
	proporcao.AspectRatio = Capitulo1Mapa.PROPORCAO_FOTO
	proporcao.Parent = foto
	local sombra = Instance.new("Frame")
	sombra.AnchorPoint = Vector2.new(0.5, 0.5)
	sombra.Position = UDim2.new(0.5, 8, 0.5, 10)
	sombra.Size = UDim2.fromScale(1, 1)
	sombra.BackgroundColor3 = RGB(0, 0, 0)
	sombra.BackgroundTransparency = 0.55
	sombra.BorderSizePixel = 0
	sombra.ZIndex = 21
	sombra.Parent = foto
	local quadro = Capitulo1Mapa.desenharFoto(foto)
	for _, d in quadro:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += 22
		end
	end
	quadro.ZIndex = 22
	local dica = Instance.new("TextLabel")
	dica.BackgroundTransparency = 1
	dica.AnchorPoint = Vector2.new(0.5, 0)
	dica.Position = UDim2.fromScale(0.5, 0.92)
	dica.Size = UDim2.fromScale(0.6, 0.04)
	dica.TextScaled = true
	dica.FontFace = FONTE.texto
	dica.TextColor3 = COR.textoFraco
	dica.Text = "toque para fechar"
	dica.TextTransparency = 1
	dica.ZIndex = 23
	dica.Parent = f
	local entra = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(f, entra, { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(foto, entra, { Position = UDim2.fromScale(0.5, 0.46), Rotation = -2 }):Play()
	TweenService:Create(dica, TweenInfo.new(0.6), { TextTransparency = 0.2 }):Play()
	local fechado = false
	local function fechar()
		if fechado or not f.Parent then
			return
		end
		fechado = true
		local sai = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(f, sai, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(foto, sai, { Position = UDim2.fromScale(0.5, 1.4), Rotation = 8 }):Play()
		TweenService:Create(dica, sai, { TextTransparency = 1 }):Play()
		task.delay(0.32, function()
			f:Destroy()
		end)
	end
	f.Activated:Connect(fechar)
	task.delay(9, fechar)
end

local function achar(nome: string)
	local d = Capitulo1.DETALHES[nome]
	if nome == "foto" then
		mostrarFoto()
	elseif nome == "trancado" then
		Som.tocar("clique", { volume = 1, velocidade = 0.7 })
		task.delay(0.12, function()
			Som.tocar("clique", { volume = 0.9, velocidade = 0.62 })
		end)
	elseif nome == "porao" then
		task.delay(0.6, function()
			falar("VO_5")
		end)
	end
	aviso(d.texto, 4.5)
	if not estado.achados[nome] then
		estado.ctx.remoto:FireServer("detalhe", nome)
	end
end

-- a TV liga sozinha uns segundos quando alguém chega perto (só uma vez)
local function vigiarTV()
	local tela = acharNoMapa("OI3_TVTela")
	if not tela then
		return
	end
	local ligou = false
	local acumulado = 0
	table.insert(estado.conexoes, RunService.Heartbeat:Connect(function(dt)
		acumulado += dt
		if ligou or acumulado < 0.3 then
			return
		end
		acumulado = 0
		local char = Players.LocalPlayer.Character
		local raiz = char and char:FindFirstChild("HumanoidRootPart")
		if not raiz or (raiz.Position - tela.Position).Magnitude > 13 then
			return
		end
		ligou = true
		local corAntes, matAntes = tela.Color, tela.Material
		tela.Material = Enum.Material.Neon
		local luz = Instance.new("SurfaceLight")
		luz.Face = Enum.NormalId.Front
		luz.Range = 14
		luz.Brightness = 1.2
		luz.Color = RGB(190, 210, 230)
		luz.Parent = tela
		local ponto = Instance.new("Attachment")
		ponto.Parent = tela
		Som.tocar("estatica", { pai = tela, volume = 0.8, alcance = 40, minimo = 6 })
		local fim = os.clock() + 3.6
		task.spawn(function()
			while os.clock() < fim and tela.Parent do
				local v = 150 + math.random(0, 90)
				tela.Color = RGB(v, v, v + 10)
				luz.Brightness = 0.6 + math.random() * 1.2
				task.wait(0.05)
			end
			tela.Color, tela.Material = corAntes, matAntes
			luz:Destroy()
			ponto:Destroy()
		end)
	end))
end

local function criarVo()
	local ok, m = pcall(Personagens.criar, "VO")
	if not ok or not m then
		return
	end
	local F = Mapa.L.F
	local s = m:GetAttribute("Escala") or 1
	m:PivotTo(CFrame.lookAt(V3(0, F + 3 * s, -2.9), V3(0, F + 3 * s, 3)))
	m.Parent = workspace
	estado.vo = m
	local hum = m:FindFirstChildOfClass("Humanoid")
	local animador = hum and hum:FindFirstChildOfClass("Animator")
	if animador then
		local a = Instance.new("Animation")
		a.AnimationId = Animacoes.parado
		pcall(function()
			local tr = animador:LoadAnimation(a)
			tr.Looped = true
			tr:Play()
		end)
	end
	local torso = m:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		torso.CanQuery = true
		prompt(torso, "Conversar", "Vô", function()
			if estado.fase == "jantar" then
				falar("VO_4")
			else
				falar("VO_3")
			end
		end)
	end
end

function Capitulo1.tarde(info: any)
	fecharEscolha()
	estado.token += 1
	estado.fase = "tarde"
	estado.achados = {}
	estado.total = (info and info.total) or 5
	estado.escolhas = (info and info.escolhas) or {}
	Iluminacao.tarde(0)
	estado.ctx.entrarExploracao()
	criarTela()
	objetivo("Explore o orfanato.")
	atualizarContador()
	Cinema.titulo("CAPÍTULO 1", true, 1.2)
	Cinema.rodape("A brincadeira nunca terminou", true)
	task.delay(3.6, function()
		Cinema.titulo("CAPÍTULO 1", false, 1)
		Cinema.rodape("A brincadeira nunca terminou", false)
	end)
	for nome, ancora in ANCORAS do
		local p = acharNoMapa(ancora)
		if p then
			local d = Capitulo1.DETALHES[nome]
			prompt(p, d.acao, d.objeto, function()
				achar(nome)
			end)
		end
	end
	vigiarTV()
	criarVo()
end

function Capitulo1.achado(info: any)
	if type(info) ~= "table" or type(info.nome) ~= "string" then
		return
	end
	estado.achados[info.nome] = true
	atualizarContador()
	if info.de ~= Players.LocalPlayer.UserId then
		aviso("Alguém achou uma coisa estranha.", 3)
	end
end

---------------------------------------------------------------------------
-- O jantar
---------------------------------------------------------------------------
function Capitulo1.jantar()
	estado.fase = "jantar"
	atualizarContador()
	falar("VO_4")
	objetivo("Vá jantar no hall.")
	local mesa = acharNoMapa("OI3_MesaJantar")
	if not mesa then
		estado.ctx.remoto:FireServer("naMesa")
		return
	end
	local marca = Instance.new("BillboardGui")
	marca.Name = "OI3_MarcaJantar"
	marca.AlwaysOnTop = true
	marca.Size = UDim2.fromOffset(120, 34)
	marca.StudsOffset = V3(0, 3.2, 0)
	marca.Adornee = mesa
	marca.Parent = mesa
	table.insert(estado.coisas, marca)
	Interface.texto(marca, {
		Text = "JANTAR",
		FontFace = FONTE.textoNegrito,
		TextSize = 18,
		TextColor3 = COR.ouro,
		TextStrokeTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
	})
	local enviado = false
	local acumulado = 0
	table.insert(estado.conexoes, RunService.Heartbeat:Connect(function(dt)
		acumulado += dt
		if enviado or acumulado < 0.3 then
			return
		end
		acumulado = 0
		local char = Players.LocalPlayer.Character
		local raiz = char and char:FindFirstChild("HumanoidRootPart")
		if raiz and (raiz.Position - mesa.Position).Magnitude < 7.5 then
			enviado = true
			marca.Enabled = false
			estado.ctx.remoto:FireServer("naMesa")
			if estado.grupo > 1 then
				objetivo("Esperando os outros na mesa...")
			end
		end
	end))
end

-- cena curta do jantar e depois a noite do ritual
function Capitulo1.ritual(info: any)
	if estado.fase == "ritual" then
		return
	end
	estado.fase = "ritual"
	local token = estado.token
	Cinema.limparLegenda()
	Cinema.escurecer(1, 0.6)
	task.wait(0.65)
	estado.ctx.sairExploracao()
	if estado.tela then
		estado.tela.Enabled = false
	end
	local F = Mapa.L.F
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	-- as crianças em volta da mesa (avatares do catálogo)
	local atores = {}
	for i, cod in { "KE", "NI", "ME" } do
		local ok, m = pcall(Personagens.criar, cod)
		if ok and m then
			local s = m:GetAttribute("Escala") or 1
			local lado = if i == 2 then 1 else -1
			local z = ({ 0.4, 2, 3.6 })[i]
			m:PivotTo(CFrame.lookAt(V3(lado * 3.4, F + 3 * s, z), V3(0, F + 3 * s, z)))
			m.Parent = workspace
			table.insert(atores, m)
		end
	end
	local olho1 = CFrame.lookAt(V3(5.2, F + 6.2, 8.6), V3(0, F + 3.4, 1.4))
	local olho2 = CFrame.lookAt(V3(3.6, F + 5.6, 6.2), V3(0, F + 3.6, -1.6))
	cam.CFrame = olho1
	cam.FieldOfView = 55
	Cinema.faixas(true, 0.5)
	Cinema.escurecer(0, 1)
	TweenService:Create(cam, TweenInfo.new(8, Enum.EasingStyle.Sine), { CFrame = olho2, FieldOfView = 48 }):Play()
	task.wait(1.2)
	falar("VO_6")
	task.wait(5.4)
	Cinema.escurecer(1, 1.2)
	task.wait(1.3)
	Cinema.rodape("Mais tarde, naquela noite...", true)
	task.wait(2.4)
	Cinema.rodape("Mais tarde, naquela noite...", false)
	for _, m in atores do
		m:Destroy()
	end
	limparCoisas()
	Iluminacao.noite(0)
	if estado.tela then
		estado.tela:Destroy()
		estado.tela = nil
	end
	if token ~= estado.token then
		return
	end
	-- o próprio personagem fica parado e escondido durante a cutscene
	local char = Players.LocalPlayer.Character
	local raiz = char and char:FindFirstChild("HumanoidRootPart")
	if raiz and raiz:IsA("BasePart") then
		raiz.Anchored = true
	end
	Cutscene.tocar({
		inicio = info and info.inicio,
		aoTerminar = function()
			estado.fase = "noite"
			if raiz and raiz.Parent then
				raiz.Anchored = false
			end
			estado.ctx.fimRitual()
		end,
	})
end

---------------------------------------------------------------------------
function Capitulo1.parar()
	estado.token += 1
	estado.fase = "nada"
	fecharEscolha()
	limparCoisas()
	if estado.tela then
		estado.tela:Destroy()
		estado.tela = nil
	end
	Iluminacao.noite(0)
end

function Capitulo1.iniciar(ctx: any)
	estado.ctx = ctx
	ctx.remoto.OnClientEvent:Connect(function(tipo: string, info: any)
		if tipo == "escolher" then
			task.spawn(function()
				ctx.sairDoMenu()
				Capitulo1.mostrarEscolha(info)
			end)
		elseif tipo == "escolhas" or tipo == "ocupado" then
			if tipo == "ocupado" then
				estado.minha = nil
			end
			atualizarCartoes((info and info.livres) or {}, info and info.quem)
		elseif tipo == "tarde" then
			task.spawn(Capitulo1.tarde, info)
		elseif tipo == "achado" then
			Capitulo1.achado(info)
		elseif tipo == "jantar" then
			Capitulo1.jantar()
		elseif tipo == "ritual" then
			task.spawn(Capitulo1.ritual, info)
		end
	end)
end

return Capitulo1
