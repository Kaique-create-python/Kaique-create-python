-- OI3 :: o resto do Capítulo 1 no CLIENTE (AJUSTE-8)
-- Monta o cenário de cada missão no aparelho, leva o personagem até lá, mostra o objetivo e os botões
-- de interação, e faz os sustos/lembranças. Quem decide os passos é o servidor (OI3_Servidor/Missoes).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local OI3 = script.Parent.Parent
local M = require(OI3.Missoes)
local MM = require(OI3.MissoesMapa)
local Personagens = require(OI3.Personagens)
local Interface = require(script.Parent.Interface)
local Cinema = require(script.Parent.Cinema)
local Som = require(script.Parent.Som)
local Ator = require(script.Parent.Ator)
local PrimeiraPessoa = require(script.Parent.PrimeiraPessoa)
local Iluminacao = require(script.Parent.Iluminacao)
local Final = require(script.Parent.Final)
local Medo = require(script.Parent.Medo)
local Dialogos = require(OI3.Dialogos)

local MC = {}

local COR = Interface.COR
local FONTE = Interface.FONTE
local RGB = Color3.fromRGB
local V3 = Vector3.new
local lp = Players.LocalPlayer

local estado = {
	ctx = nil :: any,
	token = 0,
	cenario = nil :: Model?,
	nomeCenario = nil :: string?,
	layout = nil :: any,
	n = 0,
	i = 0,
	feitos = {} :: { [string]: boolean },
	prompts = {} :: { Instance },
	coisas = {} :: { Instance },
	conexoes = {} :: { RBXScriptConnection },
	atores = {} :: { any },
	tela = nil :: ScreenGui?,
	titulo = nil :: TextLabel?,
	objetivo = nil :: TextLabel?,
	extra = nil :: TextLabel?,
	aviso = nil :: TextLabel?,
	botoes = nil :: Frame?,
	tokenAviso = 0,
	escondido = nil :: string?,
	sombra = nil :: any,
	sombraDistraida = false,
	sentado = false,
	contando = false,
	ultimoOlhar = 0,
	npcs = {} :: { [string]: any },
	presenca = nil :: any,
	presencaX = 0,
	maquinas = {} :: { [number]: boolean },
	digitos = {} :: { [string]: string },
	pecas = 0,
	numeros = "",
	fugindo = false,
	ativo = false,
}

---------------------------------------------------------------------------
-- utilidades
---------------------------------------------------------------------------
local function remoto(): RemoteEvent
	return estado.ctx.remoto
end

local function acharNoCenario(nome: string): Instance?
	return estado.cenario and estado.cenario:FindFirstChild(nome, true)
end

local function todosNoCenario(nome: string): { BasePart }
	local lista = {}
	if estado.cenario then
		for _, d in estado.cenario:GetDescendants() do
			if d.Name == nome and d:IsA("BasePart") then
				table.insert(lista, d)
			end
		end
	end
	return lista
end

local function tween(obj: Instance, t: number, props: { [string]: any }, estilo: Enum.EasingStyle?)
	local tw = TweenService:Create(obj, TweenInfo.new(t, estilo or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props)
	tw:Play()
	return tw
end

local function minhaCrianca(): string
	local c = estado.ctx and estado.ctx.minhaCrianca and estado.ctx.minhaCrianca()
	if c then
		return c
	end
	local char = lp.Character
	return (char and char:GetAttribute("Codigo")) or "KE"
end

local function falar(id: string): number
	local fala = Dialogos.FALAS[id]
	local dur = Som.duracao(id) or (fala and math.clamp(#fala.texto / 14, 2, 6)) or 3
	if Som.disponivel(id) then
		Som.tocar(id, { grupo = "Vozes" })
		Cinema.legenda(id, dur + 0.4)
	else
		Cinema.legenda(id, dur + 0.8, true)
	end
	return dur
end

local function somEm(nome: string, onde: Vector3?, opts: any?): Sound?
	local o = table.clone(opts or {})
	if onde then
		local ponto = Instance.new("Part")
		ponto.Anchored = true
		ponto.CanCollide = false
		ponto.CanQuery = false
		ponto.Transparency = 1
		ponto.Size = V3(0.2, 0.2, 0.2)
		ponto.Position = onde
		ponto.Parent = estado.cenario or workspace
		o.pai = ponto
		o.alcance = o.alcance or 70
		task.delay(20, function()
			if not (o.loop) then
				ponto:Destroy()
			end
		end)
		table.insert(estado.coisas, ponto)
	end
	return Som.tocar(nome, o)
end

local function raiz(): BasePart?
	local char = lp.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function levar(pos: Vector3, olhar: Vector3?)
	local char = lp.Character
	local r = raiz()
	if not (char and r) then
		return
	end
	local alvo = olhar or (pos + V3(0, 0, -1))
	PrimeiraPessoa.esquecerChao()
	char:PivotTo(CFrame.lookAt(pos + V3(0, 3, 0), V3(alvo.X, pos.Y + 3, alvo.Z)))
	r.AssemblyLinearVelocity = Vector3.zero
end

---------------------------------------------------------------------------
-- HUD da missão
---------------------------------------------------------------------------
local function criarTela()
	if estado.tela then
		return
	end
	local tela = Interface.tela("OI3_Missao", 7, true)
	estado.tela = tela
	local caixa = Instance.new("Frame")
	caixa.Name = "Painel"
	caixa.Position = UDim2.new(0, 14, 0, 12)
	caixa.Size = UDim2.fromOffset(330, 74)
	caixa.BackgroundColor3 = RGB(16, 14, 18)
	caixa.BackgroundTransparency = 0.3
	caixa.Parent = tela
	Interface.canto(caixa, 4)
	estado.titulo = Interface.texto(caixa, {
		Text = "",
		FontFace = FONTE.textoNegrito,
		TextSize = 12,
		TextColor3 = COR.ouro,
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 16),
	})
	estado.objetivo = Interface.texto(caixa, {
		Text = "",
		FontFace = FONTE.textoForte,
		TextSize = 16,
		TextWrapped = true,
		Position = UDim2.fromOffset(10, 20),
		Size = UDim2.new(1, -20, 0, 34),
	})
	estado.extra = Interface.texto(caixa, {
		Text = "",
		TextSize = 13,
		TextColor3 = COR.textoFraco,
		Position = UDim2.fromOffset(10, 54),
		Size = UDim2.new(1, -20, 0, 16),
	})
	estado.aviso = Interface.texto(tela, {
		Name = "Aviso",
		Text = "",
		FontFace = FONTE.textoForte,
		TextSize = 19,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -118),
		Size = UDim2.new(0.8, 0, 0, 52),
	})
	local botoes = Instance.new("Frame")
	botoes.Name = "Botoes"
	botoes.BackgroundTransparency = 1
	botoes.AnchorPoint = Vector2.new(0.5, 1)
	botoes.Position = UDim2.new(0.5, 0, 1, -56)
	botoes.Size = UDim2.fromOffset(420, 52)
	botoes.Parent = tela
	local lista = Instance.new("UIListLayout")
	lista.FillDirection = Enum.FillDirection.Horizontal
	lista.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lista.Padding = UDim.new(0, 10)
	lista.Parent = botoes
	estado.botoes = botoes
end

local function aviso(texto: string, tempo: number?)
	criarTela()
	local a = estado.aviso :: TextLabel
	estado.tokenAviso += 1
	local t = estado.tokenAviso
	a.Text = texto
	tween(a, 0.25, { TextTransparency = 0, TextStrokeTransparency = 0.4 })
	task.delay(tempo or 4, function()
		if t == estado.tokenAviso and a.Parent then
			tween(a, 0.6, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

local function botao(nome: string, texto: string, aoClicar: () -> (), cor: Color3?): TextButton
	criarTela()
	local velho = (estado.botoes :: Frame):FindFirstChild(nome)
	if velho then
		velho:Destroy()
	end
	local b = Interface.botao(estado.botoes :: Frame, texto, { Name = nome, Size = UDim2.fromOffset(150, 50), BackgroundColor3 = cor or RGB(120, 28, 28) }, aoClicar)
	return b
end

local function tirarBotao(nome: string)
	if estado.botoes then
		local b = estado.botoes:FindFirstChild(nome)
		if b then
			b:Destroy()
		end
	end
end

local function atualizarObjetivo(passo: any, extra: any?)
	criarTela()
	local missao = M.missao(estado.n)
	if missao then
		(estado.titulo :: TextLabel).Text = string.upper(missao.titulo .. " · " .. missao.nome)
	end
	if passo and passo.tipo ~= "evento" then
		(estado.objetivo :: TextLabel).Text = M.objetivo(passo, estado.feitos, extra)
	end
	local linhas = {}
	if next(estado.digitos) then
		table.insert(linhas, "Números nos balões: " .. (estado.digitos.bal_azul or "?") .. " " .. (estado.digitos.bal_vermelho or "?") .. " " .. (estado.digitos.bal_amarelo or "?"))
	end
	if estado.numeros ~= "" then
		table.insert(linhas, "Números da fita: " .. estado.numeros)
	end
	if estado.pecas > 0 then
		table.insert(linhas, string.format("Peças do mecanismo: %d/3", estado.pecas))
	end
	(estado.extra :: TextLabel).Text = table.concat(linhas, "   ")
end

---------------------------------------------------------------------------
-- telas: teclado, escolha de brinquedo, papel/foto, lembrança
---------------------------------------------------------------------------
local function modal(nome: string): (ScreenGui, Frame)
	local tela = Interface.tela(nome, 25, true)
	Interface.escalaAuto(tela)
	local fundo = Instance.new("TextButton")
	fundo.Text = ""
	fundo.AutoButtonColor = false
	fundo.Size = UDim2.fromScale(1, 1)
	fundo.BackgroundColor3 = RGB(0, 0, 0)
	fundo.BackgroundTransparency = 0.45
	fundo.Parent = tela
	local caixa = Instance.new("Frame")
	caixa.AnchorPoint = Vector2.new(0.5, 0.5)
	caixa.Position = UDim2.fromScale(0.5, 0.5)
	caixa.BackgroundColor3 = COR.painel
	caixa.BorderSizePixel = 0
	caixa.Active = true -- toque dentro da caixa não fecha a janela
	caixa.Parent = tela
	Interface.canto(caixa, 4)
	Interface.borda(caixa, COR.borda, 1, 0.2)
	fundo.Activated:Connect(function()
		tela:Destroy()
	end)
	table.insert(estado.coisas, tela)
	return tela, caixa
end

local function abrirTeclado(ponto: string)
	local tela, caixa = modal("OI3_Teclado")
	caixa.Size = UDim2.fromOffset(260, 330)
	local visor = Interface.texto(caixa, {
		Text = "_ _ _",
		FontFace = FONTE.maquina,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 44),
		BackgroundTransparency = 0,
		BackgroundColor3 = RGB(10, 12, 10),
		TextColor3 = RGB(140, 220, 150),
	})
	Interface.canto(visor, 4)
	local digitado = ""
	local function mostrar()
		visor.Text = if digitado == "" then "_ _ _" else digitado
	end
	local grade = Instance.new("Frame")
	grade.BackgroundTransparency = 1
	grade.Position = UDim2.fromOffset(10, 64)
	grade.Size = UDim2.new(1, -20, 1, -74)
	grade.Parent = caixa
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(1 / 3, -6, 0.25, -6)
	g.CellPadding = UDim2.fromOffset(6, 6)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = grade
	for k, t in { "1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "OK" } do
		local b = Interface.botao(grade, t, { LayoutOrder = k, TextSize = 22, BackgroundColor3 = if t == "OK" then RGB(120, 28, 28) else RGB(34, 31, 36) }, function()
			Som.tocar("clique", { volume = 0.7 })
			if t == "<" then
				digitado = string.sub(digitado, 1, -2)
			elseif t == "OK" then
				if digitado ~= "" then
					remoto():FireServer("m_codigo", { ponto = ponto, texto = digitado })
					tela:Destroy()
				end
				return
			elseif #digitado < 6 then
				digitado ..= t
			end
			mostrar()
		end)
		b.Size = UDim2.fromScale(1, 1)
	end
end

local BRINQUEDOS = { carrinho = "Carrinho", boneca = "Boneca", ursinho = "Ursinho" }

local function abrirEscolha(opcoes: { string }, aoEscolher: (string) -> ())
	local tela, caixa = modal("OI3_Escolha")
	caixa.Size = UDim2.fromOffset(380, 150)
	Interface.texto(caixa, {
		Text = "Qual brinquedo vai nessa cadeira?",
		FontFace = FONTE.textoForte,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 26),
	})
	local linha = Instance.new("Frame")
	linha.BackgroundTransparency = 1
	linha.Position = UDim2.fromOffset(10, 52)
	linha.Size = UDim2.new(1, -20, 0, 80)
	linha.Parent = caixa
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 8)
	l.Parent = linha
	for _, op in opcoes do
		Interface.botao(linha, BRINQUEDOS[op] or op, { Size = UDim2.new(1 / #opcoes, -6, 1, 0), TextSize = 18 }, function()
			tela:Destroy()
			aoEscolher(op)
		end)
	end
end

local function abrirPapel(cena: string?, texto: string?)
	local tela, caixa = modal("OI3_Papel")
	caixa.Size = UDim2.fromOffset(420, 300)
	caixa.BackgroundColor3 = RGB(226, 220, 200)
	if cena then
		local arte = Instance.new("Frame")
		arte.BackgroundTransparency = 1
		arte.Position = UDim2.fromOffset(14, 14)
		arte.Size = UDim2.new(1, -28, 1, -28)
		arte.ClipsDescendants = true
		arte.Parent = caixa
		MM.desenhar(arte, cena)
	end
	if texto then
		Interface.texto(caixa, {
			Text = texto,
			FontFace = FONTE.maquina,
			TextSize = 18,
			TextColor3 = RGB(40, 34, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(20, 18),
			Size = UDim2.new(1, -40, 1, -36),
		})
	end
	task.delay(9, function()
		if tela.Parent then
			tela:Destroy()
		end
	end)
end

-- "lembrança": uma cena antiga em sépia por alguns segundos (ViewportFrame)
local function lembranca(montar: (WorldModel, Camera) -> (), dur: number)
	local tela = Interface.tela("OI3_Lembranca", 30, false)
	table.insert(estado.coisas, tela)
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundColor3 = RGB(36, 28, 20)
	vp.Ambient = RGB(190, 160, 120)
	vp.LightColor = RGB(255, 220, 170)
	vp.LightDirection = V3(-0.4, -1, -0.6)
	vp.ImageColor3 = RGB(255, 222, 176)
	vp.ImageTransparency = 1
	vp.BackgroundTransparency = 1
	vp.Parent = tela
	local wm = Instance.new("WorldModel")
	wm.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 45
	cam.Parent = vp
	vp.CurrentCamera = cam
	local ok, err = pcall(montar, wm, cam)
	if not ok then
		warn("[OI3] lembrança:", err)
	end
	local vinheta = Instance.new("Frame")
	vinheta.Size = UDim2.fromScale(1, 1)
	vinheta.BackgroundColor3 = RGB(0, 0, 0)
	vinheta.BackgroundTransparency = 0.2
	vinheta.Parent = tela
	local gr = Instance.new("UIGradient")
	gr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0.2) })
	gr.Parent = vinheta
	tween(vp, 0.6, { ImageTransparency = 0, BackgroundTransparency = 0 })
	Som.tocar("whoosh", { volume = 0.5 })
	local t0 = os.clock()
	while os.clock() - t0 < dur and tela.Parent do
		vp.ImageTransparency = if math.random() < 0.08 then 0.25 else 0
		task.wait(0.08)
	end
	tween(vp, 0.6, { ImageTransparency = 1, BackgroundTransparency = 1 })
	task.wait(0.65)
	tela:Destroy()
end

local function cloneAtor(cod: string, pai: Instance, pos: Vector3, olhar: Vector3): Model?
	local ok, m = pcall(Personagens.criar, cod)
	if not ok or not m then
		return nil
	end
	m.Parent = pai
	local s = m:GetAttribute("Escala") or 1
	m:PivotTo(CFrame.lookAt(pos + V3(0, 3 * s, 0), V3(olhar.X, pos.Y + 3 * s, olhar.Z)))
	return m
end

-- AJUSTE-9: o susto agora é o MONSTRO se erguendo na sua cara: grito, ossos estalando, e a tela apaga
local function jumpscare()
	local cam = workspace.CurrentCamera
	local pasta = Instance.new("Folder")
	pasta.Name = "OI3_Susto"
	pasta.Parent = workspace
	local olho = cam.CFrame.Position
	local frente = V3(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	frente = if frente.Magnitude > 0.01 then frente.Unit else V3(0, 0, -1)
	local ok, a = pcall(Ator.novo, "CRIATURA", pasta, olho + frente * 3, olho)
	if ok and a then
		if a.semMedo then
			a:semMedo()
		end
		-- a cabeça dele fica na altura dos seus olhos
		local alto = a.alturaTotal or 7
		a:posicionar(olho + frente * 2.7 - V3(0, alto * 0.9, 0), olho)
		if a.investida then
			a:investida()
		end
		table.insert(estado.atores, a)
	end
	Som.tocar("susto", { volume = 1 })
	Som.tocar("grito_crianca", { volume = 0.9, velocidade = 1 + math.random() * 0.1 })
	Cinema.escurecer(0.3, 0.05)
	task.wait(0.95)
	Cinema.escurecer(1, 0.2)
	task.wait(0.45)
	if ok and a then
		local i = table.find(estado.atores, a)
		if i then
			table.remove(estado.atores, i)
		end
		a:destruir()
	end
	pasta:Destroy()
	Medo.forcar(0.75, 4) -- o coração continua disparado depois do susto
end

local function girarPorta(id: string)
	local folha = acharNoCenario("OI3_Porta_" .. id)
	if not (folha and folha:IsA("BasePart")) then
		return
	end
	local dob = folha:GetAttribute("Dobradica")
	if typeof(dob) ~= "Vector3" then
		return
	end
	local pecas = { folha }
	for _, d in todosNoCenario("OI3_PortaDet_" .. id) do
		table.insert(pecas, d)
	end
	local base = CFrame.new(dob)
	local rels = {}
	for _, p in pecas do
		rels[p] = base:ToObjectSpace(p.CFrame)
		p.CanCollide = false
	end
	somEm("rangido", dob, { volume = 0.8, velocidade = 0.9 })
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 1.4 do
			local k = (os.clock() - t0) / 1.4
			local a = math.rad(-82) * (k * k * (3 - 2 * k))
			for p, r in rels do
				p.CFrame = base * CFrame.Angles(0, a, 0) * r
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

---------------------------------------------------------------------------
-- cenário
---------------------------------------------------------------------------
local function pararAtores()
	for _, a in estado.atores do
		pcall(function()
			a:destruir()
		end)
	end
	estado.atores = {}
	estado.sombra = nil
	estado.presenca = nil
	estado.npcs = {}
end

local function limparPasso()
	for _, p in estado.prompts do
		p:Destroy()
	end
	estado.prompts = {}
	for nome in { JOGAR = true, SAIR = true, LEVANTAR = true, SENTAR = true } do
		tirarBotao(nome)
	end
end

local function limparCenario()
	limparPasso()
	pararAtores()
	for _, c in estado.conexoes do
		c:Disconnect()
	end
	estado.conexoes = {}
	for _, x in estado.coisas do
		pcall(function()
			x:Destroy()
		end)
	end
	estado.coisas = {}
	pcall(function()
		RunService:UnbindFromRenderStep("OI3_Tremor")
	end)
	Medo.limpar()
	if estado.cenario then
		estado.cenario:Destroy()
		estado.cenario = nil
	end
	estado.nomeCenario = nil
	estado.maquinas = {}
	estado.fugindo = false
end

-- esconde/arruma o que só aparece em certos momentos
local function prepararCenario(nome: string)
	local function sumir(n: string)
		for _, p in todosNoCenario(n) do
			p.LocalTransparencyModifier = 1
			p.CanCollide = false
			for _, sg in p:GetDescendants() do
				if sg:IsA("SurfaceGui") then
					sg.Enabled = false
				end
			end
		end
	end
	if nome == "quarto" then
		sumir("OI3_X_DesenhoCama")
	elseif nome == "festa" then
		sumir("OI3_X_Msg1")
		sumir("OI3_X_Msg2")
	elseif nome == "cadeiras" then
		sumir("OI3_X_QuartaCadeira")
	end
end

local function aparecer(n: string)
	for _, p in todosNoCenario(n) do
		p.LocalTransparencyModifier = 0
		for _, sg in p:GetDescendants() do
			if sg:IsA("SurfaceGui") then
				sg.Enabled = true
			end
		end
	end
end

local function montarCenario(nome: string)
	if estado.nomeCenario == nome and estado.cenario then
		return
	end
	limparCenario()
	local ok, modelo, l = pcall(MM.construir, nome, workspace)
	if not ok then
		warn("[OI3] cenário " .. nome .. ":", modelo)
		return
	end
	estado.cenario = modelo
	estado.layout = l
	estado.nomeCenario = nome
	prepararCenario(nome)
	-- AJUSTE-9: rede de segurança do cenário (caiu muito abaixo do chão? volta para o começo)
	table.insert(estado.conexoes, RunService.Heartbeat:Connect(function()
		local r = raiz()
		local l = estado.layout
		if r and l and l.spawn and not r.Anchored and r.Position.Y < l.spawn.Y - 40 then
			levar(l.spawn, l.olhar)
			aviso("Você caiu... voltou para o começo da sala.", 3)
		end
	end))
	-- atores andam a cada quadro
	table.insert(estado.conexoes, RunService.RenderStepped:Connect(function(dt)
		for _, a in estado.atores do
			if a.raiz and a.raiz.Parent then
				a:passo()
			end
		end
		-- máquinas da lavanderia tremendo
		for i, ligada in estado.maquinas do
			if ligada then
				local maq = acharNoCenario("OI3_X_Maquina" .. i)
				if maq and maq:IsA("BasePart") then
					local base = maq:GetAttribute("Base")
					if typeof(base) ~= "CFrame" then
						maq:SetAttribute("Base", maq.CFrame)
						base = maq.CFrame
					end
					maq.CFrame = (base :: CFrame) * CFrame.new((math.random() - 0.5) * 0.06, 0, (math.random() - 0.5) * 0.06)
				end
			end
		end
		-- a presença do porão desliza até onde o servidor mandou
		local p = estado.presenca
		if p and estado.layout then
			local O = estado.layout.origem
			local atual = p.pos.X - O.X
			local alvo = estado.presencaX
			local passo = math.clamp(alvo - atual, -22 * dt, 22 * dt)
			if math.abs(alvo - atual) > 0.05 then
				p.pos = V3(O.X + atual + passo, p.pos.Y, O.Z)
				p.yaw = if passo > 0 then -math.pi / 2 else math.pi / 2
				p:tocar("andar", 0.1, 1.6)
			else
				p:parar("andar", 0.2)
			end
		end
	end))
end

---------------------------------------------------------------------------
-- reações quando um ponto é feito (todo mundo do grupo vê)
---------------------------------------------------------------------------
local REACAO: { [string]: (string) -> () } = {}

local function balao(id: string)
	local b = acharNoCenario("OI3_X_Balao_" .. id)
	if b and b:IsA("BasePart") then
		tween(b, 2.5, { CFrame = b.CFrame + V3(0, 3.2, 0) })
	end
	estado.digitos[id] = M.DIGITOS_BALOES[id]
	somEm("whoosh", b and (b :: BasePart).Position, { volume = 0.35, velocidade = 1.4 })
end
REACAO.bal_azul = balao
REACAO.bal_vermelho = balao
REACAO.bal_amarelo = balao

REACAO.toca_discos = function()
	local disco = acharNoCenario("OI3_X_Disco")
	if disco and disco:IsA("BasePart") then
		local s = Som.tocar("caixinha", { pai = disco, loop = true, volume = 0.55, alcance = 50 })
		if s then
			table.insert(estado.coisas, s)
		end
		table.insert(estado.conexoes, RunService.RenderStepped:Connect(function(dt)
			if disco.Parent then
				disco.CFrame *= CFrame.Angles(dt * 3, 0, 0)
			end
		end))
	end
end

for i = 1, 4 do
	REACAO["prato" .. i] = function(id)
		local alvo = estado.layout.pontos[id]
		local prato = acharNoCenario("OI3_X_Prato" .. i)
		local copo = acharNoCenario("OI3_X_Copo" .. i)
		if prato and prato:IsA("BasePart") then
			tween(prato, 0.5, { CFrame = CFrame.new(V3(alvo.X, prato.Position.Y, alvo.Z)) * (prato.CFrame - prato.Position) })
		end
		if copo and copo:IsA("BasePart") then
			tween(copo, 0.5, { CFrame = CFrame.new(V3(alvo.X + 0.9, copo.Position.Y, alvo.Z)) * (copo.CFrame - copo.Position) })
		end
		Som.tocar("clique", { volume = 0.6 })
	end
end

for _, v in { "vela_a", "vela_b", "vela_c", "vela_d" } do
	REACAO[v] = function(id)
		for _, p in todosNoCenario("OI3_X_" .. id) do
			p.LocalTransparencyModifier = 1
		end
		Som.tocar("clique", { volume = 0.5 })
	end
end

local function acenderVela(id: string, ligar: boolean)
	local chama = acharNoCenario("OI3_X_Chama_" .. id)
	if chama and chama:IsA("BasePart") then
		chama.Transparency = if ligar then 0 else 1
		local luz = chama:FindFirstChildOfClass("PointLight")
		if luz then
			luz.Brightness = if ligar then 0.9 else 0
		end
	end
end
for _, v in { "bolo_vermelha", "bolo_azul", "bolo_amarela", "bolo_verde" } do
	REACAO[v] = function(id)
		acenderVela(id, true)
		Som.tocar("clique", { volume = 0.5, velocidade = 1.3 })
	end
end

local function girar(nome: string)
	local p = acharNoCenario(nome)
	if p and p:IsA("BasePart") then
		tween(p, 0.8, { CFrame = p.CFrame * CFrame.Angles(math.rad(170), 0, 0) })
	end
end

REACAO.registro = function()
	girar("OI3_X_Registro")
	somEm("rangido", estado.layout.pontos.registro, { volume = 0.6, velocidade = 1.5 })
end

for i = 1, 4 do
	REACAO["maquina" .. i] = function()
		estado.maquinas[i] = false
		local luz = acharNoCenario("OI3_X_LuzMaquina" .. i)
		if luz and luz:IsA("BasePart") then
			luz.Color = RGB(40, 20, 20)
			local l = luz:FindFirstChildOfClass("PointLight")
			if l then
				l.Enabled = false
			end
		end
		Som.tocar("clique", { volume = 0.8, velocidade = 0.8 })
	end
end

REACAO.valvula = function()
	-- espremer pelo espaço apertado (a câmera desce e passa por baixo)
	Cinema.escurecer(0.85, 0.3)
	Som.tocar("arrastar", { volume = 0.5, velocidade = 1.3 })
	task.delay(0.9, function()
		girar("OI3_X_Valvula")
		local agua = acharNoCenario("OI3_X_Agua")
		if agua and agua:IsA("BasePart") then
			tween(agua, 3, { Transparency = 1, CFrame = agua.CFrame - V3(0, 0.3, 0) })
		end
		for k in estado.maquinas do
			estado.maquinas[k] = false
		end
		Cinema.escurecer(0, 0.5)
	end)
end

REACAO.chave = function()
	local k = acharNoCenario("OI3_X_Chave")
	if k and k:IsA("BasePart") then
		k.LocalTransparencyModifier = 1
	end
	Som.tocar("clique", { volume = 0.8 })
end

REACAO.parede_certa = function()
	local p = acharNoCenario("OI3_X_Passagem")
	if p and p:IsA("BasePart") then
		p.CanCollide = false
		tween(p, 1.6, { CFrame = p.CFrame - V3(0, 8.2, 0) })
	end
	somEm("arrastar", estado.layout.pontos.parede_certa, { volume = 0.9, velocidade = 0.7 })
end

REACAO.parede_oca = function()
	somEm("batida_oca", estado.layout.pontos.parede_oca, { volume = 1 })
end

REACAO.armario = function()
	local a = acharNoCenario("OI3_X_Armario")
	if a and a:IsA("BasePart") then
		tween(a, 1.6, { CFrame = a.CFrame + V3(5, 0, 0) })
	end
	somEm("arrastar", estado.layout.pontos.armario, { volume = 1 })
end

REACAO.papel = function()
	local p = acharNoCenario("OI3_X_PapelSolto")
	if p and p:IsA("BasePart") then
		tween(p, 0.9, { CFrame = (p.CFrame - V3(0, 3, -0.6)) * CFrame.Angles(math.rad(70), 0, 0), Transparency = 1 })
	end
	Som.tocar("whoosh", { volume = 0.5, velocidade = 1.6 })
end

REACAO.mecanismo = function()
	local tampa = acharNoCenario("OI3_X_Tampa")
	if tampa and tampa:IsA("BasePart") then
		tampa.CanCollide = false
		tween(tampa, 1, { Transparency = 1 })
	end
	local porta = acharNoCenario("OI3_X_PortaC")
	if porta and porta:IsA("BasePart") then
		porta.CanCollide = false
		tween(porta, 2, { CFrame = porta.CFrame + V3(0, 7.4, 0) })
	end
	Som.tocar("clique", { volume = 1, velocidade = 0.7 })
	Som.tocar("rangido", { volume = 0.6 })
end

REACAO.passagem = function()
	-- entra rastejando no espacinho atrás da parede (AJUSTE-9: agachado; dá para passar andando agachado também)
	task.spawn(function()
		PrimeiraPessoa.agachar(true)
		Cinema.escurecer(1, 0.4)
		Som.tocar("arrastar", { volume = 0.5, velocidade = 1.4 })
		task.wait(0.6)
		local l = estado.layout
		levar(l.esconderijo + V3(0, 0, 2), l.desenhoMuda)
		Cinema.escurecer(0, 0.6)
		aviso("Você está agachado. Aperte AGACHAR (ou C) para levantar.", 4)
	end)
end

REACAO.gaveta = function()
	local g = acharNoCenario("OI3_X_Gaveta")
	if g and g:IsA("BasePart") then
		tween(g, 0.5, { CFrame = g.CFrame + V3(0, 0, 1.0) })
	end
	Som.tocar("arrastar", { volume = 0.4, velocidade = 1.8 })
	aviso("Uma lâmpada velha... ainda funciona.", 3)
end

for i = 1, 3 do
	REACAO["cabo" .. i] = function()
		local t = acharNoCenario("OI3_X_Tomada" .. i)
		if t and t:IsA("BasePart") then
			t.Material = Enum.Material.Neon
		end
		Som.tocar("clique", { volume = 0.8 })
	end
end

REACAO.chave_geral = function()
	Som.tocar("impacto", { volume = 0.35, velocidade = 1.6 })
	for _, b in todosNoCenario("OI3_Lampada") do
		local l = b:FindFirstChildOfClass("PointLight")
		if l then
			task.spawn(function()
				for _ = 1, 6 do
					l.Brightness = if math.random() < 0.5 then 0.1 else 0.7
					task.wait(0.08)
				end
				l.Brightness = 0.55
			end)
		end
	end
end

for _, f in { "fita1987", "fita1991", "fita1994" } do
	REACAO[f] = function(id)
		local p = acharNoCenario("OI3_X_" .. id)
		if p and p:IsA("BasePart") then
			p.LocalTransparencyModifier = 1
		end
		Som.tocar("clique", { volume = 0.6 })
	end
end

REACAO.lente = function()
	local luz = acharNoCenario("OI3_X_LuzProjetor")
	if luz and luz:IsA("BasePart") then
		luz.Transparency = 0.2
	end
	Som.tocar("clique", { volume = 0.6, velocidade = 0.6 })
end

local function poeBrinquedo(qual: string, onde: Vector3)
	if not estado.cenario then
		return
	end
	local mm = Instance.new("Model")
	mm.Name = "Brinquedo"
	mm.Parent = estado.cenario
	local Construtor = require(OI3.Construtor)
	local Moveis = require(OI3.Moveis)
	local c = Construtor.novo(mm)
	if qual == "ursinho" then
		Moveis.ursinho(c, onde, V3(0, 0, 1))
	elseif qual == "boneca" then
		Moveis.boneca(c, onde, V3(0, 0, 1))
	else
		c:caixa(onde + V3(0, 0.2, 0), V3(0.9, 0.3, 0.45), RGB(170, 30, 30), Enum.Material.SmoothPlastic)
		c:caixa(onde + V3(0, 0.42, 0), V3(0.45, 0.2, 0.4), RGB(170, 30, 30), Enum.Material.SmoothPlastic)
	end
end

local RESPOSTA_CADEIRA = { cadeira_ke = "carrinho", cadeira_ni = "boneca", cadeira_me = "ursinho" }
for id, qual in RESPOSTA_CADEIRA do
	REACAO[id] = function()
		local cod = string.sub(id, 9)
		local pos = estado.layout.cadeiras[cod]
		poeBrinquedo(qual, pos + V3(0, 1.7, 0))
		Som.tocar("clique", { volume = 0.7 })
	end
end

for _, id in { "peca_gaveta", "peca_caixa", "peca_quadro" } do
	REACAO[id] = function()
		estado.pecas += 1
		Som.tocar("clique", { volume = 0.9, velocidade = 0.8 })
		aviso(if estado.pecas < 3 then "Uma peça do mecanismo." else "Achamos as três peças!", 3)
	end
end

for _, id in { "simbolo_circulo", "simbolo_olho", "simbolo_espiral", "simbolo_tres" } do
	REACAO[id] = function()
		Som.tocar("clique", { volume = 0.8, velocidade = 1.1 })
	end
end

REACAO.documentos = function()
	abrirPapel(nil, "FICHA DE ENTRADA\n\nNome: KEKO\nNome: NINA\nNome: ________\n\n(o terceiro nome foi raspado do papel)")
	Som.tocar("whoosh", { volume = 0.3, velocidade = 1.8 })
end

REACAO.foto_apagada = function()
	abrirPapel("foto_apagada", nil)
	Som.tocar("coracao", { volume = 0.5 })
end

local LUGAR_BRINQUEDO = { lugar_carrinho = "carrinho", lugar_boneca = "boneca", lugar_ursinho = "ursinho" }
for id, qual in LUGAR_BRINQUEDO do
	REACAO[id] = function()
		poeBrinquedo(qual, estado.layout.pontos[id] - V3(0, 0.6, 0))
		Som.tocar("clique", { volume = 0.6 })
	end
end

local PORTAS = { porta_saida = "saida", porta_servico = "servico", porta_quarto = "quarto", escada = "escada" }
for id, porta in PORTAS do
	REACAO[id] = function()
		girarPorta(porta)
	end
end
REACAO.teclado_lavanderia = function()
	girarPorta("lavanderia")
end
REACAO.porta_porao = function()
	girarPorta("porao")
end

---------------------------------------------------------------------------
-- esconde-esconde (Missão 1)
---------------------------------------------------------------------------
local function esconderijo(id: string): any
	for _, e in (estado.layout and estado.layout.esconderijos) or {} do
		if e.id == id then
			return e
		end
	end
	return nil
end

local sairEsconderijo: (boolean?) -> ()

local function esconder(e: any)
	if estado.escondido then
		return
	end
	local char = lp.Character
	local r = raiz()
	if not (char and r) then
		return
	end
	estado.escondido = e.id
	remoto():FireServer("m_esconder", e.id)
	Medo.escondido(true)
	PrimeiraPessoa.desligar()
	r.Anchored = true
	char:PivotTo(CFrame.new(e.pos + V3(0, -8, 0))) -- some de vista (os outros não veem o corpo)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = e.cam
	cam.FieldOfView = 70
	botao("SAIR", "SAIR", function()
		sairEsconderijo(false)
	end, RGB(52, 48, 56))
	aviso(if e.tipo == "cama" then "Embaixo da cama. Não faça barulho..." elseif e.tipo == "armario" then "Dentro do armário. Dá para ver pelas frestas." else "Atrás do baú.", 3)
end

sairEsconderijo = function(silencioso: boolean?)
	if not estado.escondido then
		return
	end
	local e = esconderijo(estado.escondido)
	estado.escondido = nil
	Medo.escondido(false)
	remoto():FireServer("m_esconder", false)
	tirarBotao("SAIR")
	local char = lp.Character
	local r = raiz()
	if e and char and r then
		levar(e.checar, e.pos)
		r.Anchored = false
	end
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	if char then
		PrimeiraPessoa.ligar(char)
	end
	local _ = silencioso
end

local function prepararEsconde()
	for _, e in estado.layout.esconderijos do
		local parte = acharNoCenario("OI3_P_" .. e.id)
		if parte then
			local pr = Instance.new("ProximityPrompt")
			pr.ActionText = "Esconder"
			pr.ObjectText = if e.tipo == "cama" then "Embaixo da cama" elseif e.tipo == "armario" then "Armário" else "Baú"
			pr.MaxActivationDistance = 8
			pr.RequiresLineOfSight = false
			pr.HoldDuration = 0
			pr.KeyboardKeyCode = Enum.KeyCode.E
			pr.Parent = parte
			pr.Triggered:Connect(function()
				esconder(e)
			end)
			table.insert(estado.prompts, pr)
		end
	end
	local eu = minhaCrianca()
	if eu == "KE" then
		aviso("Keko: quando a sombra vier, aperte JOGAR para distraí-la com um brinquedo.", 6)
	elseif eu == "NI" then
		aviso("Nina: você ouve os passos da sombra antes de todo mundo.", 6)
	else
		aviso("Você consegue ver a sombra mesmo no escuro.", 6)
	end
end

local function pegarSombra(): any
	if estado.sombra then
		return estado.sombra
	end
	local pasta = estado.cenario
	if not pasta then
		return nil
	end
	local ok, a = pcall(Ator.novo, "CRIATURA", pasta, estado.layout.entrada, estado.layout.rota[2])
	if not ok or not a then
		warn("[OI3] o monstro não apareceu:", a)
		return nil
	end
	-- (as pisadas pesadas, a respiração e o medo já vêm com o monstro)
	if minhaCrianca() == "ME" then
		local h = Instance.new("Highlight")
		h.FillTransparency = 1
		h.OutlineColor = RGB(200, 40, 40)
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Parent = a.modelo
	end
	estado.sombra = a
	table.insert(estado.atores, a)
	return a
end

local function sombraSome()
	local a = estado.sombra
	if a then
		local i = table.find(estado.atores, a)
		if i then
			table.remove(estado.atores, i)
		end
		pcall(function()
			a:destruir()
		end)
		estado.sombra = nil
	end
end

-- AJUSTE-9: o monstro espia um esconderijo. Todo mundo vê; quem está DENTRO vê o rosto dele colado na
-- fresta (de lado no armário, de cabeça para baixo embaixo da cama), se contorcendo, farejando e gemendo.
local function tipoEspiada(e: any): string
	return if e.tipo == "cama" then "chao" elseif e.tipo == "bau" then "bau" else "fresta"
end

-- função pura (testável): onde a cabeça do monstro para (na frente da câmera de quem está escondido),
-- para onde ela olha e onde os pés dele ficam
function MC.pontoEspiada(e: any, meiaCabeca: number?): (Vector3, Vector3, Vector3)
	local cam: CFrame = e.cam
	local meia = meiaCabeca or 0.95
	-- o rosto fica logo DEPOIS da porta do armário (0,55 da câmera), da beirada da cama (~1) e colado
	-- na parede do baú (~3,1): de dentro dá para ver o rosto inteiro pela fresta
	local dist = if e.tipo == "cama" then 1.05 + meia elseif e.tipo == "bau" then 3.15 + meia * 0.3 else 0.62 + meia
	local alvo = cam.Position + cam.LookVector * dist
	if e.tipo == "cama" then
		-- de cabeça para baixo rente ao chão (mas sem afundar no assoalho)
		alvo = V3(alvo.X, math.max(cam.Position.Y + 0.3, e.pos.Y + meia + 0.08), alvo.Z)
	end
	local fora = V3(cam.LookVector.X, 0, cam.LookVector.Z)
	fora = if fora.Magnitude > 0.01 then fora.Unit else V3(0, 0, 1)
	local pes = V3(alvo.X, e.checar.Y, alvo.Z) + fora * (if e.tipo == "cama" then 2.4 else 1.7)
	return alvo, cam.Position, pes
end

local function espiarEsconderijo(a: any, e: any, dur: number, token: number)
	local cab = a.cabecaParte
	local alvo, olhar, pes = MC.pontoEspiada(e, if cab then math.max(cab.Size.X, cab.Size.Z) / 2 else nil)
	local d = a:andar(pes, 5)
	task.wait(d)
	if token ~= estado.token or not a.raiz.Parent then
		return
	end
	a:virar(V3(alvo.X, pes.Y, alvo.Z), 0.45)
	task.wait(0.45)
	if token ~= estado.token or not a.raiz.Parent then
		return
	end
	local comigo = estado.escondido == e.id
	if comigo then
		Medo.forcar(1, dur + 2.5)
		task.delay(dur * 0.35, function()
			if estado.escondido == e.id then
				Som.tocar("choramingo", { volume = 0.55, velocidade = 1.05 })
			end
		end)
	end
	if a.espiar then
		a:espiar(alvo, olhar, tipoEspiada(e), dur)
	end
	if e.tipo == "armario" then
		task.delay(0.9, function()
			somEm("raspar", alvo, { volume = 0.9, velocidade = 0.75, alcance = 40 })
		end)
	end
	task.wait(dur * 0.45)
	if token ~= estado.token or not a.raiz.Parent then
		return
	end
	if a.contorcer then
		a:contorcer(1.4) -- se contorce colado na fresta
	end
	task.wait(dur * 0.55)
	if token ~= estado.token or not a.raiz.Parent then
		return
	end
	if a.pararEspiar then
		a:pararEspiar()
	end
	task.wait(0.5)
end

local function rondaDaSombra(info: any, token: number)
	local l = estado.layout
	local a = pegarSombra()
	if not a then
		return
	end
	local function vivo(): boolean
		return token == estado.token and a.raiz.Parent ~= nil
	end
	-- entra devagar pela porta escura, para, fareja o ar e se contorce
	a:posicionar(l.rota[1], l.rota[2])
	local d = a:andar(l.rota[2], 4.2)
	task.wait(d)
	if not vivo() then
		return
	end
	if a.farejar then
		a:farejar()
		task.wait(0.8)
		a:contorcer(1.2)
		task.wait(1.3)
	end
	-- os lugares que ele vai conferir: os perigosos (usados na rodada anterior) e os seguros ocupados
	local alvos = {}
	local vistos = {}
	for _, lista in { info.checar or {}, info.espiar or {} } do
		for _, id in lista do
			local e = esconderijo(id)
			if e and not vistos[id] then
				vistos[id] = true
				table.insert(alvos, e)
			end
		end
	end
	table.sort(alvos, function(x, y)
		return x.pos.X < y.pos.X
	end)
	if #alvos == 0 then
		for k = 3, #l.rota - 2 do
			if not vivo() or estado.sombraDistraida then
				break
			end
			local dd = a:andar(l.rota[k], 5)
			task.wait(dd)
			if math.random() < 0.35 and a.farejar then
				a:farejar()
			end
		end
	else
		for i, e in alvos do
			if not vivo() or estado.sombraDistraida then
				break
			end
			local agora = workspace:GetServerTimeNow()
			local resta = (tonumber(info.avalia) or (agora + 10)) - agora
			local dur = math.clamp(resta / (#alvos - i + 1) - 2.4, 2.4, 5)
			espiarEsconderijo(a, e, dur, token)
		end
	end
	if estado.sombraDistraida and vivo() then
		-- o brinquedo do Keko: vai atrás do barulho, fareja, se contorce e desiste
		if a.pararEspiar then
			a:pararEspiar()
		end
		local dd = a:andar(l.barulho, 6)
		task.wait(dd + 0.2)
		a:virar(l.barulho + V3(0, 0, 3), 0.4)
		if a.farejar then
			a:farejar()
			task.wait(0.7)
			a:contorcer(1.0)
		end
		task.wait(2.2)
	end
	-- vai embora pela porta escura
	for _, k in { #l.rota - 1, #l.rota } do
		if not vivo() then
			return
		end
		local dd = a:andar(l.rota[k], 5.5)
		task.wait(dd)
	end
	sombraSome()
end

---------------------------------------------------------------------------
-- as três cadeiras (Missão 7)
---------------------------------------------------------------------------
local function levantar()
	if not estado.sentado then
		return
	end
	estado.sentado = false
	remoto():FireServer("m_sentar", false)
	tirarBotao("LEVANTAR")
	local char = lp.Character
	local r = raiz()
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Sit = false
	end
	if r then
		r.Anchored = false
		levar(r.Position - V3(0, 2.7, 0) + V3(0, 0, 2.5), estado.layout.olhar)
	end
end

local function sentar()
	local cod = string.lower(minhaCrianca())
	local pos = estado.layout.cadeiras[cod]
	local char = lp.Character
	local r = raiz()
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (pos and r and hum) then
		return
	end
	estado.sentado = true
	r.Anchored = true
	char:PivotTo(CFrame.lookAt(pos + V3(0, 2.7, 0), pos + V3(0, 2.7, -5)))
	hum.Sit = true
	remoto():FireServer("m_sentar", true)
	botao("LEVANTAR", "LEVANTAR", levantar, RGB(52, 48, 56))
	aviso("Fique sentado. Não olhe para trás.", 4)
end

local function prepararCadeiras()
	local cod = string.lower(minhaCrianca())
	local parte = acharNoCenario("OI3_P_cadeira_" .. cod)
	if parte then
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Sentar"
		pr.ObjectText = "Sua cadeira"
		pr.MaxActivationDistance = 8
		pr.RequiresLineOfSight = false
		pr.HoldDuration = 0
		pr.KeyboardKeyCode = Enum.KeyCode.E
		pr.Parent = parte
		pr.Triggered:Connect(sentar)
		table.insert(estado.prompts, pr)
	end
	-- quem olhar para a quarta cadeira faz a contagem recomeçar
	table.insert(estado.conexoes, RunService.RenderStepped:Connect(function()
		if not (estado.sentado and estado.contando) then
			return
		end
		local q = estado.layout.quarta + V3(0, 2, 0)
		local cam = workspace.CurrentCamera
		local dir = (q - cam.CFrame.Position)
		if dir.Magnitude < 30 and cam.CFrame.LookVector:Dot(dir.Unit) > 0.82 and os.clock() - estado.ultimoOlhar > 2.5 then
			estado.ultimoOlhar = os.clock()
			remoto():FireServer("m_olhou")
			Som.tocar("sussurro", { volume = 0.9 })
		end
	end))
end

local function colocarNpcs(mapa: { [string]: number })
	local eu = minhaCrianca()
	for _, cod in { "KE", "NI", "ME" } do
		local ocupado = mapa[cod] ~= nil or cod == eu
		local npc = estado.npcs[cod]
		if ocupado and npc then
			local i = table.find(estado.atores, npc)
			if i then
				table.remove(estado.atores, i)
			end
			npc:destruir()
			estado.npcs[cod] = nil
		elseif not ocupado and not npc and estado.cenario then
			local pos = estado.layout.cadeiras[string.lower(cod)]
			local ok, a = pcall(Ator.novo, cod, estado.cenario, pos + V3(0, -0.1, 0), pos + V3(0, 0, -5))
			if ok and a then
				a:tocar("sentar", 0)
				estado.npcs[cod] = a
				table.insert(estado.atores, a)
			end
		end
	end
end

---------------------------------------------------------------------------
-- eventos (sustos, lembranças, falas)
---------------------------------------------------------------------------
local EVENTOS: { [string]: (any, number) -> () } = {}

EVENTOS.m1_inicio = function()
	task.wait(1)
	local d = falar("KE_6")
	task.wait(d + 0.6)
	falar("NI_4")
end

EVENTOS.m1_desenhos = function(_, token)
	aparecer("OI3_X_DesenhoCama")
	local tela, caixa = modal("OI3_Desenhos")
	caixa.Size = UDim2.fromOffset(560, 270)
	caixa.BackgroundColor3 = RGB(200, 190, 170)
	for i, cena in { "embaixo_cama", "mao_porta" } do
		local f = Instance.new("Frame")
		f.BackgroundColor3 = RGB(230, 224, 206)
		f.Position = UDim2.new((i - 1) * 0.5, 10, 0, 10)
		f.Size = UDim2.new(0.5, -20, 1, -54)
		f.Rotation = if i == 1 then -2 else 3
		f.Parent = caixa
		MM.desenhar(f, cena)
	end
	Interface.texto(caixa, {
		Text = "Desenhos embaixo da cama. Um deles mostra uma mão de adulto segurando a porta.",
		TextSize = 15,
		TextColor3 = RGB(40, 34, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -20, 0, 34),
	})
	Som.tocar("coracao", { volume = 0.6 })
	task.wait(6)
	if tela.Parent then
		tela:Destroy()
	end
	if token == estado.token then
		falar("NI_5")
		girarPorta("saida")
	end
end

EVENTOS.m2_inicio = function()
	aparecer("OI3_X_Msg1")
	Som.tocar("caixinha", { volume = 0.5 })
	task.wait(2)
	aviso("A festa está preparada para QUATRO crianças...", 5)
end

EVENTOS.m2_esqueceram = function(_, token)
	-- a cadeira se arrasta sozinha, uma vela apaga e a parede responde
	local cadeira = todosNoCenario("OI3_X_Cadeira4")
	if #cadeira > 0 then
		somEm("arrastar", cadeira[1].Position, { volume = 1 })
		for _, p in cadeira do
			tween(p, 1.6, { CFrame = p.CFrame + V3(0, 0, 1.6) })
		end
	end
	task.wait(2.2)
	acenderVela("bolo_verde", false)
	Som.tocar("vela_apaga", { volume = 0.9 })
	task.wait(1.2)
	aparecer("OI3_X_Msg2")
	Som.tocar("impacto", { volume = 0.6 })
	task.wait(2.4)
	if token ~= estado.token then
		return
	end
	-- lembrança: uma festa antiga, as três crianças à mesa, uma delas chorando
	lembranca(function(wm, cam)
		local Construtor = require(OI3.Construtor)
		local c = Construtor.novo(wm)
		local base = V3(0, 0, 0)
		c:caixa(base + V3(0, 2.6, 0), V3(7, 0.3, 3.4), RGB(120, 90, 60), Enum.Material.Wood)
		c:caixa(base + V3(0, 2.8, 0), V3(1.6, 0.6, 1.6), RGB(232, 200, 196), Enum.Material.SmoothPlastic)
		c:caixa(base + V3(0, 6, -4), V3(14, 12, 0.4), RGB(86, 64, 70), Enum.Material.SmoothPlastic)
		for i, cod in { "KE", "NI", "ME" } do
			local m = cloneAtor(cod, wm, base + V3(-2.6 + (i - 1) * 2.6, 0, -2.2), base + V3(-2.6 + (i - 1) * 2.6, 0, 3))
			if m and cod == "ME" then
				Personagens.expressao(m, "chorando")
			end
		end
		cam.CFrame = CFrame.lookAt(base + V3(0, 5.2, 8.5), base + V3(0, 3.6, -1.5))
	end, 5.5)
end

EVENTOS.m3_inicio = function()
	for i = 1, 4 do
		estado.maquinas[i] = true
	end
	local s = somEm("maquina", estado.layout.pontos.maquina2, { loop = true, volume = 0.8, alcance = 60 })
	if s then
		table.insert(estado.coisas, s)
	end
	aviso("As máquinas estão ligadas... mas não tem energia.", 5)
end

EVENTOS.m3_voz = function()
	local maq = estado.layout.pontos.maquina2
	somEm("impacto", maq, { volume = 0.4, velocidade = 1.8 })
	task.wait(0.8)
	if Som.disponivel("CR_1") then
		somEm("CR_1", maq, { grupo = "Vozes", volume = 1.2, alcance = 40 })
		Cinema.legenda("CR_1", 3)
	else
		Cinema.legenda("CR_1", 3.4, true)
	end
	task.wait(3)
	aviso("A voz veio de dentro de uma máquina vazia.", 4)
end

EVENTOS.m4_inicio = function()
	local eu = minhaCrianca()
	aviso(if eu == "KE" then "Repare onde as coisas estão nos reflexos." elseif eu == "NI" then "Compare os reflexos: um deles está diferente." else "Fique na frente dos espelhos: eles mostram o que está escondido.", 7)
	-- o "duplo" que continua andando no reflexo do 2º espelho
	local l = estado.layout
	local x = l.espelhos[2]
	local O = l.origem
	local ok, a = pcall(Ator.novo, minhaCrianca(), estado.cenario, V3(O.X + x - 2.4, O.Y + 1, O.Z - 8), V3(O.X + x, O.Y + 1, O.Z))
	if ok and a then
		table.insert(estado.atores, a)
		task.spawn(function()
			local lado = 1
			while a.raiz and a.raiz.Parent do
				local d = a:andar(V3(O.X + x + 2.4 * lado, O.Y + 1, O.Z - 8), 1.6)
				task.wait(d + 0.6)
				lado = -lado
			end
		end)
	end
	-- o menino revela a passagem quando fica na frente do 4º espelho
	if eu == "ME" then
		local revela = acharNoCenario("OI3_X_Revela")
		table.insert(estado.conexoes, RunService.Heartbeat:Connect(function()
			local r = raiz()
			if r and revela and revela:IsA("BasePart") then
				local perto = math.abs(r.Position.X - (O.X + l.espelhos[4])) < 3.5
				revela.Transparency = if perto then 0.55 else 0.92
			end
		end))
	end
end

EVENTOS.m4_ultimo = function(_, token)
	local l = estado.layout
	local B = l.quartoB
	local criancas = {}
	for i, cod in { "KE", "NI", "ME" } do
		local ok, a = pcall(Ator.novo, cod, estado.cenario, V3(B.X - 2.4 + (i - 1) * 2.4, B.Y, B.Z + 10), V3(B.X, B.Y, B.Z))
		if ok and a then
			table.insert(estado.atores, a)
			table.insert(criancas, a)
			if cod == "ME" then
				-- o terceiro menino não tem rosto
				for _, x in a.modelo:GetChildren() do
					if x:GetAttribute("OI3_Rosto") or x:GetAttribute("OI3_Reacao") or x:IsA("Accessory") and x:FindFirstChild("Handle") and (x.Handle:FindFirstChild("FaceFrontAttachment") or x.Handle:FindFirstChild("FaceCenterAttachment")) then
						x:Destroy()
					end
				end
				local cab = a.modelo:FindFirstChild("Head")
				if cab then
					for _, d in cab:GetChildren() do
						if d:IsA("Decal") then
							d:Destroy()
						end
					end
				end
			end
		end
	end
	Som.tocar("coracao", { volume = 0.6 })
	task.wait(2.2)
	Som.tocar("sussurro", { volume = 1 })
	Cinema.legenda("ME_6", 3.6, true)
	task.wait(3.6)
	-- as luzes piscam e eles somem
	for _ = 1, 5 do
		Cinema.escurecer(0.9, 0.05)
		task.wait(0.09)
		Cinema.escurecer(0, 0.05)
		task.wait(0.12)
	end
	for _, a in criancas do
		a:visivel(false)
	end
	if token == estado.token then
		aviso("O reflexo dele não tinha rosto...", 3.5)
		girarPorta("quarto")
	end
end

EVENTOS.m5_inicio = function()
	for k = 1, 3 do
		local pts = estado.layout.pontos
		local alvo = ({ pts.bater1, pts.bater3, pts.parede_oca })[k]
		somEm("batida_oca", alvo, { volume = 0.9 })
		task.wait(1.6)
	end
	aviso("Batidas... de dentro das paredes.", 4)
end

EVENTOS.m5_desenho = function(_, token)
	local l = estado.layout
	local papel = acharNoCenario("OI3_X_DesenhoMuda")
	local arte = papel and papel:FindFirstChild("Arte")
	aviso("Um desenho do avô atrás das crianças...", 4)
	local mudou = false
	local longe = 0
	local t0 = os.clock()
	while token == estado.token and os.clock() - t0 < 12 do
		local cam = workspace.CurrentCamera
		local dir = (l.desenhoMuda - cam.CFrame.Position).Unit
		local olhando = cam.CFrame.LookVector:Dot(dir) > 0.75
		if not mudou then
			if not olhando and os.clock() - t0 > 3 then
				longe += 0.1
			else
				longe = 0
			end
			if longe > 1.2 or os.clock() - t0 > 9 then
				mudou = true
				if arte then
					MM.desenhar(arte, "vo_mao")
				end
			end
		elseif olhando then
			Som.tocar("susto", { volume = 0.35, velocidade = 1.3 })
			aviso("O desenho mudou. Agora o avô está segurando a mão de uma criança.", 5)
			break
		end
		task.wait(0.1)
	end
end

EVENTOS.m6_inicio = function()
	aviso("O escritório do avô. O projetor está quebrado e cheio de fitas antigas.", 5)
end

-- o filme do projetor (na tela da parede): três fitas e os números que piscam
EVENTOS.m6_filme = function(_, token)
	local tela = acharNoCenario("OI3_X_Tela")
	if not (tela and tela:IsA("BasePart")) then
		return
	end
	local projetor = somEm("projetor", estado.layout.pontos.lente, { loop = true, volume = 0.5 })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Left
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Brightness = 1.4
	sg.Parent = tela
	table.insert(estado.coisas, sg)
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundColor3 = RGB(30, 26, 20)
	vp.Ambient = RGB(170, 150, 120)
	vp.LightColor = RGB(255, 230, 190)
	vp.ImageColor3 = RGB(255, 226, 180)
	vp.Parent = sg
	local wm = Instance.new("WorldModel")
	wm.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam
	local legenda = Instance.new("TextLabel")
	legenda.BackgroundTransparency = 1
	legenda.Position = UDim2.fromScale(0.04, 0.04)
	legenda.Size = UDim2.fromScale(0.3, 0.12)
	legenda.TextScaled = true
	legenda.FontFace = FONTE.maquina
	legenda.TextColor3 = RGB(240, 230, 200)
	legenda.Parent = sg
	local numero = Instance.new("TextLabel")
	numero.BackgroundColor3 = RGB(0, 0, 0)
	numero.BackgroundTransparency = 1
	numero.TextTransparency = 1
	numero.Size = UDim2.fromScale(1, 1)
	numero.TextScaled = true
	numero.FontFace = FONTE.maquina
	numero.TextColor3 = RGB(255, 255, 255)
	numero.Parent = sg
	local Construtor = require(OI3.Construtor)
	local function limpar()
		for _, x in wm:GetChildren() do
			x:Destroy()
		end
	end
	local function piscar()
		vp.ImageTransparency = if math.random() < 0.1 then 0.3 else 0
	end
	local function esperar(seg: number)
		local t0 = os.clock()
		while os.clock() - t0 < seg and token == estado.token do
			piscar()
			task.wait(0.08)
		end
	end
	-- fita 1987: o avô recebendo crianças no orfanato
	legenda.Text = "1987"
	local c = Construtor.novo(wm)
	c:caixa(V3(0, 5, -3), V3(16, 10, 0.4), RGB(120, 100, 80), Enum.Material.SmoothPlastic)
	c:caixa(V3(-3, 4, -2.7), V3(4.4, 8, 0.2), RGB(40, 30, 24), Enum.Material.SmoothPlastic)
	cloneAtor("VO", wm, V3(-0.6, 0, -1.6), V3(-4, 0, 3))
	local kids = {}
	for i, cod in { "KE", "NI", "ME" } do
		local m = cloneAtor(cod, wm, V3(6 + i * 2, 0, 1), V3(-3, 0, -1))
		if m then
			table.insert(kids, m)
		end
	end
	cam.CFrame = CFrame.lookAt(V3(2, 5, 13), V3(0, 3.5, 0))
	local t0 = os.clock()
	while os.clock() - t0 < 7 and token == estado.token do
		local k = (os.clock() - t0) / 7
		for i, m in kids do
			local s = m:GetAttribute("Escala") or 1
			local x = 6 + i * 2 - k * 9.5
			m:PivotTo(CFrame.lookAt(V3(x, 3 * s, 1), V3(x - 3, 3 * s, -1)))
		end
		piscar()
		task.wait(1 / 12) -- filme antigo: poucos quadros
	end
	-- fita 1991: brinquedos guardados em caixas
	limpar()
	legenda.Text = "1991"
	c = Construtor.novo(wm)
	c:caixa(V3(0, 1, 0), V3(4, 2, 3), RGB(140, 110, 70), Enum.Material.Cardboard)
	local Moveis = require(OI3.Moveis)
	for k = 1, 3 do
		Moveis.ursinho(c, V3(-1.2 + (k - 1) * 1.2, 2.2, 0), V3(0, 0, 1))
	end
	cam.CFrame = CFrame.lookAt(V3(0, 6, 6), V3(0, 1.5, 0))
	esperar(6)
	-- fita 1994: o avô sozinho num cômodo escuro, símbolos estranhos e fotos de crianças
	limpar()
	legenda.Text = "1994"
	vp.Ambient = RGB(90, 70, 60)
	c = Construtor.novo(wm)
	c:caixa(V3(0, 5, -3), V3(16, 10, 0.4), RGB(40, 30, 28), Enum.Material.SmoothPlastic)
	for k = 0, 2 do
		local p = c:caixa(V3(-5 + k * 5, 6.5, -2.75), V3(2.6, 2.6, 0.05), RGB(80, 20, 20), Enum.Material.SmoothPlastic)
		local s2 = Instance.new("SurfaceGui")
		s2.Face = Enum.NormalId.Back
		s2.Parent = p
		MM.desenhar(s2, "simbolos")
	end
	for k = 0, 4 do
		c:caixa(V3(-5 + k * 2.4, 3.2, -2.75), V3(1, 1.3, 0.05), RGB(200, 190, 170), Enum.Material.SmoothPlastic)
	end
	cloneAtor("VO", wm, V3(0, 0, 0), V3(0, 0, 10))
	cam.CFrame = CFrame.lookAt(V3(0, 5, 11), V3(0, 4, 0))
	esperar(1.5)
	Cinema.legenda("VO_7", 4, true)
	esperar(4.2)
	-- os números que aparecem rapidinho
	for _, n in { "3", "1", "9", "4" } do
		numero.Text = n
		numero.BackgroundTransparency = 0
		numero.TextTransparency = 0
		Som.tocar("clique", { volume = 0.9, velocidade = 0.5 })
		task.wait(0.35)
		numero.BackgroundTransparency = 1
		numero.TextTransparency = 1
		esperar(0.9)
		estado.numeros ..= n
		atualizarObjetivo(nil)
	end
	esperar(1.5)
	if projetor then
		projetor:Destroy()
	end
	sg:Destroy()
	aviso("Números da fita: 3 1 9 4. Guarde isso.", 6)
end

EVENTOS.m7_inicio = function()
	aviso("As fotos na parede mostram de quem é cada brinquedo.", 6)
end

EVENTOS.m7_maos = function()
	aparecer("OI3_X_QuartaCadeira")
	local maos = acharNoCenario("OI3_X_Maos")
	if maos then
		local sg = maos:FindFirstChildOfClass("SurfaceGui")
		if sg then
			sg.Enabled = true
		end
	end
	Som.tocar("coracao", { volume = 0.7 })
	aviso("A quarta cadeira está vazia... mas tem marcas de mãos pequenas no assento.", 6)
	task.wait(3)
	for i = 1, 3 do
		local t = acharNoCenario("OI3_X_Trava" .. i)
		if t and t:IsA("BasePart") then
			tween(t, 0.6, { CFrame = t.CFrame - V3(0, 1.4, 0), Transparency = 1 })
		end
		Som.tocar("clique", { volume = 1, velocidade = 0.6 })
		task.wait(0.5)
	end
end

EVENTOS.m8_inicio = function()
	aviso("O porão. Três salas... e algo se mexendo no escuro.", 5)
end

EVENTOS.m8_gravacao = function()
	local s = somEm("radio", estado.layout.pontos.gravador, { loop = true, volume = 0.5 })
	task.wait(1.2)
	Cinema.legenda("VO_8", 5, true)
	task.wait(5.5)
	if s then
		s:Destroy()
	end
end

-- A DESCOBERTA: o espelho mostra as lembranças; os três aparecem pálidos e imóveis
EVENTOS.descoberta = function(_, token)
	local l = estado.layout
	local E = l.espelho
	local char = lp.Character
	local r = raiz()
	PrimeiraPessoa.desligar()
	if r then
		r.Anchored = true
	end
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 55
	cam.CFrame = CFrame.lookAt(E + V3(0, 0.6, 7.5), E + V3(0, -0.6, -4))
	Cinema.faixas(true, 0.6)
	local pasta = estado.cenario :: Model
	local fundo = V3(E.X, E.Y - 4.5, E.Z - 5) -- os pés no chão do "reflexo"
	local function ator(cod: string, pos: Vector3, olhar: Vector3)
		local ok, a = pcall(Ator.novo, cod, pasta, pos, olhar)
		if ok and a then
			table.insert(estado.atores, a)
			return a
		end
		return nil
	end
	-- 1) Keko vê o avô entrando no quarto
	Cinema.rodape("Keko lembra do avô entrando no quarto...", true)
	local vo = ator("VO", fundo + V3(5, 0, -2.5), fundo)
	if vo then
		vo:andar(fundo + V3(1, 0, -1), 1.6)
	end
	Som.tocar("rangido", { volume = 0.6 })
	task.wait(6.5)
	if vo then
		vo:destruir()
	end
	Cinema.rodape("", false)
	if token ~= estado.token then
		return
	end
	-- 2) Nina lembra de tentar fugir
	Cinema.rodape("Nina lembra de tentar fugir...", true)
	local ni = ator("NI", fundo + V3(-1, 0, 0), fundo + V3(-6, 0, -3))
	if ni then
		ni:andar(fundo + V3(-5, 0, -3), 9)
	end
	Som.tocar("respiracao", { volume = 0.9 })
	task.wait(5)
	if ni then
		ni:destruir()
	end
	Cinema.rodape("", false)
	-- 3) o menino vê o pai numa fotografia e lembra do próprio rosto
	Cinema.rodape("O menino vê o pai numa fotografia... e lembra do próprio rosto.", true)
	local me = ator("ME", fundo + V3(0, 0, 1), fundo + V3(0, 0, 10))
	if me then
		me:expressao("chorando")
	end
	task.wait(3)
	if me then
		me:expressao("neutro")
	end
	falar("ME_7")
	task.wait(5)
	if me then
		me:destruir()
	end
	Cinema.rodape("", false)
	-- 4) os três no espelho: pálidos, imóveis
	local tres = {}
	for i, cod in { "KE", "NI", "ME" } do
		local a = ator(cod, fundo + V3(-2.6 + (i - 1) * 2.6, 0, 2), fundo + V3(-2.6 + (i - 1) * 2.6, 0, 12))
		if a then
			Final.palido(a.modelo)
			table.insert(tres, a)
		end
	end
	Som.tocar("coracao", { volume = 0.9 })
	Cinema.rodape("Eles não estavam fugindo de um orfanato. Estavam presos às lembranças de onde morreram.", true)
	task.wait(8)
	Cinema.rodape("", false)
	for _ = 1, 4 do
		Cinema.escurecer(1, 0.05)
		task.wait(0.1)
		Cinema.escurecer(0, 0.05)
		task.wait(0.15)
	end
	for _, a in tres do
		a:destruir()
	end
	Cinema.faixas(false, 0.4)
	cam.CameraType = Enum.CameraType.Custom
	if r then
		r.Anchored = false
	end
	if char then
		PrimeiraPessoa.ligar(char)
	end
end

---------------------------------------------------------------------------
-- a fuga: o orfanato desmorona
---------------------------------------------------------------------------
local function comecarFuga()
	if estado.fugindo then
		return
	end
	estado.fugindo = true
	aviso("O ORFANATO ESTÁ DESMORONANDO! CORRAM ATÉ A SAÍDA!", 6)
	local s = Som.tocar("desmoronar", { loop = true, volume = 0.9 })
	if s then
		table.insert(estado.coisas, s)
	end
	for _, b in todosNoCenario("OI3_Lampada") do
		local luz = b:FindFirstChildOfClass("PointLight")
		if luz then
			task.spawn(function()
				for _ = 1, 10 do
					luz.Brightness = if math.random() < 0.5 then 0 else 0.6
					task.wait(0.1 + math.random() * 0.2)
				end
				luz.Brightness = 0
				b.Material = Enum.Material.SmoothPlastic
			end)
		end
	end
	local saida = acharNoCenario("OI3_X_LuzSaida")
	if saida and saida:IsA("BasePart") then
		saida.Transparency = 0.1
	end
	pcall(function()
		RunService:BindToRenderStep("OI3_Tremor", Enum.RenderPriority.Camera.Value + 5, function()
			local cam = workspace.CurrentCamera
			cam.CFrame *= CFrame.Angles((math.random() - 0.5) * 0.012, (math.random() - 0.5) * 0.012, 0)
		end)
	end)
	-- pedaços caindo perto de quem corre
	task.spawn(function()
		local token = estado.token
		while estado.fugindo and token == estado.token do
			local r = raiz()
			if r and estado.cenario then
				local p = Instance.new("Part")
				p.Size = V3(math.random() * 1.2 + 0.4, math.random() * 0.5 + 0.2, math.random() * 1.2 + 0.4)
				p.Color = RGB(70, 66, 60)
				p.Material = Enum.Material.Slate
				p.CanCollide = false
				p.CanQuery = false
				p.CFrame = CFrame.new(r.Position + V3((math.random() - 0.5) * 6, 7, (math.random() - 0.5) * 3 - 3))
				p.Parent = estado.cenario
				game:GetService("Debris"):AddItem(p, 2.5)
			end
			task.wait(0.45)
		end
	end)
end

---------------------------------------------------------------------------
-- passo atual
---------------------------------------------------------------------------
local function usarPonto(p: any, passo: any)
	if passo.tipo == "codigo" then
		abrirTeclado(p.id)
	elseif passo.escolher then
		abrirEscolha(passo.escolher, function(op)
			remoto():FireServer("m_acao", { ponto = p.id, valor = op })
		end)
	else
		remoto():FireServer("m_acao", { ponto = p.id })
	end
end

local function criarPrompt(p: any, passo: any)
	local parte = acharNoCenario("OI3_P_" .. p.id)
	if not parte then
		return
	end
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "Prompt_" .. p.id
	pr.ActionText = p.acao
	pr.ObjectText = p.objeto
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr.HoldDuration = 0
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.Parent = parte
	pr.Triggered:Connect(function()
		usarPonto(p, passo)
	end)
	table.insert(estado.prompts, pr)
end

local function aplicarPasso(info: any)
	estado.n = info.n or estado.n
	estado.i = info.i or estado.i
	estado.feitos = info.feitos or {}
	limparPasso()
	if estado.escondido then
		sairEsconderijo(true)
	end
	if estado.sentado then
		levantar()
	end
	estado.contando = false
	local passo = M.passo(estado.n, estado.i)
	atualizarObjetivo(passo, info.extra)
	if not passo or not estado.cenario then
		return
	end
	if passo.tipo == "achar" or passo.tipo == "ordem" then
		for _, p in passo.pontos do
			if not estado.feitos[p.id] then
				criarPrompt(p, passo)
			end
		end
		local modelo = passo.pontos[1]
		for _, id in passo.falsos or {} do
			criarPrompt({ id = id, acao = modelo.acao, objeto = modelo.objeto }, passo)
		end
	elseif passo.tipo == "codigo" then
		criarPrompt(passo.ponto, passo)
	elseif passo.tipo == "esconder" then
		prepararEsconde()
	elseif passo.tipo == "cadeiras" then
		prepararCadeiras()
	elseif passo.tipo == "fuga" then
		comecarFuga()
	end
end

local function entrarMissao(info: any)
	estado.token += 1
	local token = estado.token
	local missao = M.missao(info.n)
	if not missao then
		return
	end
	estado.ativo = true
	estado.n = info.n
	estado.i = 0
	-- quem continuou de um ponto salvo não viu o filme: os números da fita ficam anotados
	if info.n >= 7 and estado.numeros == "" then
		estado.numeros = M.CODIGO_PORAO
	end
	if info.n >= 3 then
		estado.digitos = {} -- a senha dos balões só servia para a lavanderia
	end
	if missao.cenario ~= estado.nomeCenario or not estado.cenario then
		Cinema.escurecer(1, 0.6)
		task.wait(0.65)
		if token ~= estado.token then
			return
		end
		montarCenario(missao.cenario)
	end
	Iluminacao.noite(0)
	-- espera o personagem existir (pode estar nascendo agora)
	local t0 = os.clock()
	while not raiz() and os.clock() - t0 < 12 do
		task.wait(0.1)
	end
	if estado.layout then
		levar(estado.layout.spawn, estado.layout.olhar)
	end
	criarTela()
	atualizarObjetivo(nil)
	local obj = estado.objetivo
	if obj then
		obj.Text = ""
	end
	Cinema.escurecer(0, 1.2)
	if not info.reentrada then
		Cinema.titulo(string.upper(missao.titulo), true, 0.8)
		Cinema.rodape(missao.nome, true)
		task.wait(2.8)
		Cinema.titulo(string.upper(missao.titulo), false, 0.8)
		Cinema.rodape(missao.nome, false)
	end
end

---------------------------------------------------------------------------
-- mensagens do servidor
---------------------------------------------------------------------------
local H: { [string]: (any) -> () } = {}

H.m_missao = function(info)
	task.spawn(entrarMissao, info)
end

H.m_passo = function(info)
	-- espera o cenário ficar pronto (a mensagem pode chegar junto com a troca de cenário)
	task.spawn(function()
		local missao = M.missao(info.n)
		local t0 = os.clock()
		while missao and estado.nomeCenario ~= missao.cenario and os.clock() - t0 < 8 do
			task.wait(0.1)
		end
		aplicarPasso(info)
	end)
end

H.m_feito = function(info)
	estado.feitos[info.ponto] = true
	for i = #estado.prompts, 1, -1 do
		local pr = estado.prompts[i]
		if pr.Name == "Prompt_" .. info.ponto then
			pr:Destroy()
			table.remove(estado.prompts, i)
		end
	end
	local r = REACAO[info.ponto]
	if r then
		task.spawn(r, info.ponto)
	else
		Som.tocar("clique", { volume = 0.6 })
	end
	if info.objetivo and estado.objetivo then
		estado.objetivo.Text = info.objetivo
	end
	atualizarObjetivo(M.passo(estado.n, estado.i))
	if info.por ~= lp.UserId then
		local p = Players:GetPlayerByUserId(info.por)
		if p then
			aviso(p.DisplayName .. " achou uma coisa.", 2.5)
		end
	end
end

H.m_errou = function(info)
	local passo = M.passo(estado.n, estado.i)
	if info.motivo == "codigo" then
		Som.tocar("estatica", { volume = 0.5 })
		aviso("Senha errada.", 3)
	elseif info.motivo == "dono" then
		Som.tocar("clique", { volume = 0.6, velocidade = 0.5 })
		aviso("Esse brinquedo não é do dono dessa cadeira. Olhe as fotos.", 4)
	else
		-- ordem errada: desfaz o que tinha sido feito
		estado.feitos = {}
		if passo then
			for _, p in passo.pontos do
				if string.sub(p.id, 1, 5) == "bolo_" then
					acenderVela(p.id, false)
				elseif string.sub(p.id, 1, 7) == "maquina" then
					local i = tonumber(string.sub(p.id, 8))
					if i then
						estado.maquinas[i] = true
						local luz = acharNoCenario("OI3_X_LuzMaquina" .. i)
						if luz and luz:IsA("BasePart") then
							luz.Color = RGB(220, 40, 30)
							local l = luz:FindFirstChildOfClass("PointLight")
							if l then
								l.Enabled = true
							end
						end
					end
				elseif string.sub(p.id, 1, 4) == "fita" then
					local f = acharNoCenario("OI3_X_" .. p.id)
					if f and f:IsA("BasePart") then
						f.LocalTransparencyModifier = 0
					end
				end
			end
		end
		Som.tocar(if estado.nomeCenario == "festa" then "vela_apaga" else "impacto", { volume = 0.5, velocidade = 1.4 })
		aviso(if estado.nomeCenario == "festa" then "As velas apagaram. Olhe os desenhos." elseif estado.nomeCenario == "lavanderia" then "As máquinas ligaram de novo! Leia o bilhete." else "Não é essa a ordem.", 4)
		aplicarPasso({ n = estado.n, i = estado.i, feitos = {} })
	end
end

H.m_falso = function(info)
	local pos = estado.layout and estado.layout.pontos[info.ponto]
	somEm("batida_macica", pos, { volume = 1 })
	aviso(if estado.nomeCenario == "espelhos" then "É só parede." else "Parece parede maciça.", 2.5)
end

H.m_evento = function(info)
	local f = EVENTOS[info.nome]
	if f then
		local token = estado.token
		task.spawn(function()
			local ok, err = pcall(f, info, token)
			if not ok then
				warn("[OI3] evento " .. tostring(info.nome) .. ":", err)
			end
		end)
	end
end

H.m_sombra_vem = function(info)
	local eu = minhaCrianca()
	local atraso = if eu == "NI" then 0 else 4
	local token = estado.token
	task.delay(atraso, function()
		aviso(if eu == "NI" then "Nina ouve passos vindo... ESCONDAM-SE!" else "Passos pesados no corredor! ESCONDA-SE!", 5)
		somEm("rangido", estado.layout and estado.layout.entrada, { volume = 0.9, velocidade = 0.6 })
	end)
	-- AJUSTE-9: passos de gigante vindo pelo corredor escuro (cada vez mais perto) e um gemido lá longe
	local entrada = estado.layout and estado.layout.entrada
	if entrada then
		local longe = entrada + V3(-14, 0, 0)
		for k = 1, 8 do
			task.delay(atraso + 1.6 + k * 1.25, function()
				if token == estado.token then
					local pos = longe:Lerp(entrada, k / 8)
					somEm("passo_monstro", pos, { volume = 0.35 + k * 0.1, velocidade = 0.85 + math.random() * 0.1, alcance = 120, minimo = 12 })
					Medo.pisada(pos, 0.5)
				end
			end)
		end
		task.delay(atraso + 6, function()
			if token == estado.token then
				somEm("gemido", longe, { volume = 0.9, velocidade = 0.8, alcance = 120, minimo = 12 })
			end
		end)
	end
	if eu == "KE" then
		botao("JOGAR", "JOGAR BRINQUEDO", function()
			remoto():FireServer("m_distrair")
			tirarBotao("JOGAR")
		end, RGB(150, 112, 52))
	end
end

H.m_sombra = function(info)
	estado.sombraDistraida = false
	local token = estado.token
	task.spawn(rondaDaSombra, info, token)
end

H.m_distraido = function(info)
	estado.sombraDistraida = true
	tirarBotao("JOGAR")
	if estado.layout then
		somEm("clique", estado.layout.barulho, { volume = 1, velocidade = 0.7 })
		task.delay(0.2, function()
			somEm("batida_macica", estado.layout.barulho, { volume = 0.8 })
		end)
	end
	local p = Players:GetPlayerByUserId(info.por)
	aviso((if p then p.DisplayName else "Keko") .. " jogou um brinquedo. A sombra foi atrás do barulho!", 4)
end

H.m_pego = function(info)
	local eu = table.find(info.ids or {}, lp.UserId) ~= nil
	if eu then
		task.spawn(function()
			jumpscare()
			if estado.escondido then
				sairEsconderijo(true)
			end
			if estado.layout then
				levar(estado.layout.spawn, estado.layout.olhar)
			end
			Cinema.escurecer(0, 0.8)
			aviso("A sombra te achou! Escondam-se de novo — e mudem de lugar.", 5)
		end)
	else
		aviso("A sombra achou alguém! Mais uma rodada...", 4)
	end
end

H.m_rodada = function(info)
	aviso(string.format("Ela não achou ninguém. (%d/%d) — os lugares usados agora são perigosos.", info.rodada, info.total), 5)
	atualizarObjetivo(M.passo(estado.n, estado.i), { rodada = info.rodada })
	tirarBotao("JOGAR")
end

H.m_fim_esconde = function()
	sombraSome()
	if estado.escondido then
		sairEsconderijo(true)
	end
	aviso("A sombra foi embora...", 3)
end

H.m_sentados = function(info)
	colocarNpcs(info.mapa or {})
end

H.m_conta = function(info)
	estado.contando = true
	if info.k == 1 then
		aparecer("OI3_X_QuartaCadeira")
	end
	local id = "CONTA_" .. tostring(info.k)
	if Som.disponivel(id) then
		Som.tocar(id, { grupo = "Vozes", volume = 1 })
	end
	Cinema.legenda(id, 1.5, true)
	if estado.objetivo then
		estado.objetivo.Text = string.format("Fiquem sentados... (%d/10) Não olhem para trás.", info.k)
	end
end

H.m_recomeca = function(info)
	Cinema.limparLegenda()
	Som.tocar("sussurro", { volume = 0.8 })
	aviso(if info.motivo == "olhou" then "Alguém olhou para a quarta cadeira... a contagem recomeçou." else "Todos precisam ficar sentados.", 4)
	if info.motivo == "levantou" then
		estado.contando = false
	end
end

H.m_presenca = function(info)
	if not estado.layout or estado.nomeCenario ~= "porao" then
		return
	end
	estado.presencaX = info.x
	if not estado.presenca and estado.cenario then
		local O = estado.layout.origem
		local ok, a = pcall(Ator.novo, "CRIATURA", estado.cenario, V3(O.X + info.x, O.Y + 1, O.Z), V3(O.X + info.x + 5, O.Y + 1, O.Z))
		if ok and a then
			if a.gritar then
				a:gritar()
			end
			estado.presenca = a
			table.insert(estado.atores, a)
		end
		Som.tocar("susto", { volume = 0.8 })
		aviso("CORRA! Alguma coisa está vindo pelo corredor!", 4)
	end
	if info.pulo and estado.presenca then
		local O = estado.layout.origem
		estado.presenca.pos = V3(O.X + info.x, estado.presenca.pos.Y, O.Z)
	end
end

H.m_presenca_fim = function()
	local a = estado.presenca
	if a then
		estado.presenca = nil
		local i = table.find(estado.atores, a)
		if i then
			table.remove(estado.atores, i)
		end
		a:destruir()
		aviso("Sumiu...", 2.5)
	end
end

H.m_pego_perseguicao = function(info)
	task.spawn(function()
		jumpscare()
		if typeof(info.volta) == "Vector3" then
			levar(info.volta, estado.layout and estado.layout.olhar)
		end
		Cinema.escurecer(0, 0.7)
		aviso("Ela te pegou... Corra mais rápido (segure CORRER).", 4)
	end)
end

H.m_fuga = function()
	comecarFuga()
end

H.m_final = function(info)
	task.spawn(function()
		estado.token += 1
		estado.fugindo = false
		limparCenario()
		if estado.tela then
			estado.tela.Enabled = false
		end
		local ctx = estado.ctx
		if ctx.antesDoFinal then
			ctx.antesDoFinal()
		end
		Final.tocar({
			inicio = info.inicio,
			aoTerminar = function()
				MC.parar()
				if ctx.voltarMenu then
					ctx.voltarMenu()
				end
			end,
		})
	end)
end

function MC.evento(tipo: string, info: any)
	local h = H[tipo]
	if h then
		h(if type(info) == "table" then info else {})
	end
end

function MC.ativo(): boolean
	return estado.ativo
end

function MC.parar()
	estado.token += 1
	estado.ativo = false
	if estado.escondido then
		sairEsconderijo(true)
	end
	estado.sentado = false
	limparCenario()
	if estado.tela then
		estado.tela:Destroy()
		estado.tela = nil
		estado.objetivo = nil
	end
	estado.digitos = {}
	estado.pecas = 0
	estado.numeros = ""
end

function MC.iniciar(ctx: any)
	estado.ctx = ctx
end

return MC
