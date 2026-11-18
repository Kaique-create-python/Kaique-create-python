--!strict
-- PROJETO BASTIÃO :: interface da história (cliente)
-- Mesmo visual da bodycam que já existe (RobotoMono, branco com borda escura queimada na
-- imagem, sem painéis), na mesma tela de desenho 1280x720 e com a mesma escala.
--   topo, ao centro: objetivo, alerta de isolamento e avisos curtos;
--   embaixo, ao centro: legendas de fala e de som (largura limitada para não cobrir os
--   botões de toque da bodycam nem o pulo);
--   tela cheia: corte preto (troca de lugar) e cartão de fim da etapa.
-- Não mexe no HUD existente: é outro ScreenGui, só com rótulos (nada aqui recebe toque).

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Interface = {}

local WHITE = Color3.fromRGB(238, 238, 232)
local DIM = Color3.fromRGB(166, 168, 160)
local AMBER = Color3.fromRGB(244, 186, 88)
local RED = Color3.fromRGB(232, 54, 42)
local BLACK = Color3.new(0, 0, 0)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local MONO_MEDIUM = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)

local DESIGN_W, DESIGN_H = 1280, 720
local MARGIN_Y = 16
local AVANCO = 0.6 -- largura de cada caractere da RobotoMono (em "em")

-- quebra de linha determinística (fonte monoespaçada): nenhuma caixa cresce sozinha
function Interface.quebrar(texto: string, maxCaracteres: number): { string }
	local linhas = {}
	for paragrafo in string.gmatch(texto .. "\n", "(.-)\n") do
		local atual = ""
		for palavra in string.gmatch(paragrafo, "%S+") do
			local tentativa = if atual == "" then palavra else atual .. " " .. palavra
			if (utf8.len(tentativa) or #tentativa) <= maxCaracteres or atual == "" then
				atual = tentativa
			else
				table.insert(linhas, atual)
				atual = palavra
			end
		end
		table.insert(linhas, atual)
	end
	return linhas
end

-- toque de verdade (PreferredInput); notebook com tela de toque e mouse não conta
function Interface.usaToque(): boolean
	local ok, v = pcall(function()
		return UserInputService.PreferredInput
	end)
	if ok and v ~= nil then
		return v == Enum.PreferredInput.Touch
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function larguraTexto(texto: string, tamanho: number): number
	return math.ceil((utf8.len(texto) or #texto) * tamanho * AVANCO)
end

local function borda(pai: Instance)
	local s = Instance.new("UIStroke")
	s.Color = BLACK
	s.Thickness = 1
	s.Transparency = 0.3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = pai
end

local function rotulo(pai: Instance, nome: string, tamanho: number, fonte: Font, cor: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = nome
	t.BackgroundTransparency = 1
	t.BorderSizePixel = 0
	t.FontFace = fonte
	t.TextSize = tamanho
	t.TextColor3 = cor
	t.Text = ""
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.Active = false
	borda(t)
	t.Parent = pai
	return t
end

local function suave(inst: Instance, tempo: number, alvo: { [string]: any })
	local t = TweenService:Create(inst, TweenInfo.new(tempo, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), alvo)
	t:Play()
	return t
end

export type Api = {
	objetivo: (chave: string?) -> (),
	fala: (chave: string, duracao: number) -> (),
	som: (chave: string, duracao: number) -> (),
	aviso: (chave: string, args: { any }?) -> (),
	alarme: (ligado: boolean) -> (),
	corte: () -> (),
	fim: () -> (),
	idioma: () -> (), -- a língua mudou: redesenha o que está na tela
	definirSom: (fn: ((chave: string) -> ())?) -> (), -- toca o "estalo" quando a legenda quebra
}

-- cor do nome de quem fala (o rádio de cada um tem a sua)
local COR_FALANTE = {
	PAVEL = AMBER,
	PAVEL_RADIO = AMBER,
	ORLOV_RADIO = Color3.fromRGB(236, 128, 104),
	ELENA_RADIO = Color3.fromRGB(150, 212, 222),
	GRAVACAO = DIM,
	SISTEMA = WHITE,
}

function Interface.criar(playerGui: Instance, textos: any, idioma: (() -> string)?): Api
	local function L()
		return textos.de(if idioma then idioma() else textos.PADRAO)
	end
	for _, nome in { "BastiaoHUD", "BastiaoTela" } do
		local velho = playerGui:FindFirstChild(nome)
		if velho then
			velho:Destroy()
		end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "BastiaoHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11 -- acima do HUD da bodycam (10), abaixo do menu dela (20)
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local seguro = Instance.new("Frame")
	seguro.Name = "SafeArea"
	seguro.BackgroundTransparency = 1
	seguro.Size = UDim2.fromScale(1, 1)
	seguro.Parent = gui
	local tela = Instance.new("Frame")
	tela.Name = "Canvas"
	tela.BackgroundTransparency = 1
	tela.Size = UDim2.fromScale(1, 1)
	tela.Parent = seguro
	local escala = Instance.new("UIScale")
	escala.Parent = tela

	-- topo: objetivo, alerta, aviso
	local topo = Instance.new("Frame")
	topo.Name = "Topo"
	topo.BackgroundTransparency = 1
	topo.AnchorPoint = Vector2.new(0.5, 0)
	topo.Position = UDim2.new(0.5, 0, 0, MARGIN_Y)
	topo.Size = UDim2.fromOffset(560, 120)
	topo.Parent = tela
	local cabecalho = rotulo(topo, "ObjetivoTitulo", 12, MONO, DIM)
	cabecalho.Size = UDim2.new(1, 0, 0, 14)
	cabecalho.Text = L().ui.objetivo
	cabecalho.TextTransparency = 1
	local objetivoTexto = rotulo(topo, "Objetivo", 17, MONO, WHITE)
	objetivoTexto.Position = UDim2.fromOffset(0, 16)
	objetivoTexto.Size = UDim2.new(1, 0, 0, 22)
	objetivoTexto.TextWrapped = true
	local alerta = rotulo(topo, "Alerta", 14, MONO, RED)
	alerta.Position = UDim2.fromOffset(0, 44)
	alerta.Size = UDim2.new(1, 0, 0, 18)
	alerta.Text = L().ui.alerta
	alerta.Visible = false
	local avisoTexto = rotulo(topo, "Aviso", 14, MONO_MEDIUM, AMBER)
	avisoTexto.Position = UDim2.fromOffset(0, 68)
	avisoTexto.Size = UDim2.new(1, 0, 0, 40)
	avisoTexto.TextWrapped = true
	avisoTexto.TextTransparency = 1

	-- embaixo: som (legenda de áudio) e fala (caixa)
	local baixo = Instance.new("Frame")
	baixo.Name = "Legendas"
	baixo.BackgroundTransparency = 1
	baixo.AnchorPoint = Vector2.new(0.5, 1)
	baixo.Position = UDim2.new(0.5, 0, 1, -96)
	baixo.Size = UDim2.fromOffset(820, 160)
	baixo.Parent = tela
	local somTexto = rotulo(baixo, "Som", 15, MONO, DIM)
	somTexto.TextYAlignment = Enum.TextYAlignment.Bottom
	somTexto.TextTransparency = 1
	local caixa = Instance.new("Frame")
	caixa.Name = "Fala"
	caixa.AnchorPoint = Vector2.new(0.5, 1)
	caixa.BackgroundColor3 = BLACK
	caixa.BackgroundTransparency = 1
	caixa.BorderSizePixel = 0
	caixa.Parent = baixo
	local canto = Instance.new("UICorner")
	canto.CornerRadius = UDim.new(0, 3)
	canto.Parent = caixa
	local falante = rotulo(caixa, "Falante", 13, MONO, AMBER)
	falante.TextXAlignment = Enum.TextXAlignment.Left
	local falaTexto = rotulo(caixa, "Texto", 18, MONO_MEDIUM, WHITE)
	falaTexto.TextXAlignment = Enum.TextXAlignment.Left

	-- tela cheia: corte e cartão final (fora da área segura, por cima de tudo)
	local cheia = Instance.new("ScreenGui")
	cheia.Name = "BastiaoTela"
	cheia.ResetOnSpawn = false
	cheia.DisplayOrder = 30
	cheia.ScreenInsets = Enum.ScreenInsets.None
	cheia.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	cheia.Parent = playerGui
	local preto = Instance.new("Frame")
	preto.Name = "Corte"
	preto.BackgroundColor3 = BLACK
	preto.BackgroundTransparency = 1
	preto.BorderSizePixel = 0
	preto.Size = UDim2.fromScale(1, 1)
	preto.Active = false
	preto.Parent = cheia
	local cartao = Instance.new("Frame")
	cartao.Name = "Fim"
	cartao.BackgroundColor3 = BLACK
	cartao.BackgroundTransparency = 1
	cartao.BorderSizePixel = 0
	cartao.Size = UDim2.fromScale(1, 1)
	cartao.Visible = false
	cartao.Parent = cheia
	local cartaoEscala = Instance.new("UIScale")
	cartaoEscala.Parent = cartao
	local linhasFim = {}
	local chavesFim = { "titulo", "capitulo", "linha" }
	for i, d in { { L().fim.titulo, 34, MONO, WHITE }, { L().fim.capitulo, 18, MONO, AMBER }, { L().fim.linha, 13, MONO_MEDIUM, DIM } } do
		local t = rotulo(cartao, "Linha" .. i, d[2], d[3], d[4])
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.new(0.5, 0, 0.5, (i - 2) * 44)
		t.Size = UDim2.new(1, -40, 0, d[2] + 8)
		t.Text = d[1]
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.TextTransparency = 1
		table.insert(linhasFim, t)
	end

	-- escala igual à da bodycam; largura útil das legendas depende do toque
	local larguraTela, alturaTela = DESIGN_W, DESIGN_H
	local toque = false
	local function maxLegenda(): number
		if toque then
			return math.max(320, math.min(520, larguraTela - 300))
		end
		return math.max(360, math.min(820, larguraTela - 120))
	end
	local function relayout()
		local s = seguro.AbsoluteSize
		if s.X < 2 or s.Y < 2 then
			return
		end
		local k = math.clamp(math.min(s.Y / DESIGN_H, s.X / DESIGN_W), 0.72, 1.7)
		escala.Scale = k
		tela.Size = UDim2.fromScale(1 / k, 1 / k)
		larguraTela, alturaTela = s.X / k, s.Y / k
		topo.Size = UDim2.fromOffset(math.max(320, math.min(600, larguraTela - 480)), 120)
		objetivoTexto.TextSize = if larguraTela < 1100 then 15 else 17
		baixo.Size = UDim2.fromOffset(maxLegenda(), 200)
		local tela2 = cheia.AbsoluteSize
		cartaoEscala.Scale = math.clamp(math.min(tela2.Y / DESIGN_H, tela2.X / DESIGN_W), 0.72, 1.7)
	end
	local function atualizarEntrada()
		toque = Interface.usaToque()
		relayout()
	end
	seguro:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	pcall(function()
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(atualizarEntrada)
	end)
	atualizarEntrada()

	local api = {} :: any

	-- ===== objetivo: entra digitado, em âmbar por um instante, depois branco =====
	local geracaoObjetivo = 0
	local objetivoAtual: string? = nil
	function api.objetivo(chave: string?)
		geracaoObjetivo += 1
		local minha = geracaoObjetivo
		objetivoAtual = if chave and chave ~= "" then chave else nil
		local texto = if objetivoAtual then L().objetivos[objetivoAtual] else nil
		if not texto then
			suave(objetivoTexto, 0.3, { TextTransparency = 1 })
			suave(cabecalho, 0.3, { TextTransparency = 1 })
			return
		end
		local final = string.upper(texto)
		cabecalho.TextTransparency = 0
		objetivoTexto.TextTransparency = 0
		objetivoTexto.TextColor3 = AMBER
		local total = utf8.len(final) or #final
		local okR, valorR = pcall(function()
			return GuiService.ReducedMotionEnabled
		end)
		local reduzido = okR and valorR == true
		task.spawn(function()
			if reduzido then
				objetivoTexto.Text = final
			else
				for n = 1, total do
					if minha ~= geracaoObjetivo then
						return
					end
					local corte = utf8.offset(final, n + 1)
					objetivoTexto.Text = if corte then string.sub(final, 1, corte - 1) else final
					task.wait(0.018)
				end
			end
			task.wait(1.4)
			if minha == geracaoObjetivo then
				suave(objetivoTexto, 0.6, { TextColor3 = WHITE })
			end
		end)
	end

	-- ===== legendas (letra por letra em 3D; somem quebrando em pedaços) =====
	-- Cada letra chega sozinha, de perto da câmera (grande, girada) até o lugar dela, na ordem da
	-- leitura e na cor de quem fala; depois fica branca. Ao terminar, as letras se partem: caem
	-- girando, encolhem e soltam lascas. A fonte é monoespaçada, então cada letra tem lugar exato.
	local glifosPasta = Instance.new("Frame")
	glifosPasta.Name = "Glifos"
	glifosPasta.BackgroundTransparency = 1
	glifosPasta.BorderSizePixel = 0
	glifosPasta.Active = false
	glifosPasta.Parent = caixa
	local caixaEscala = Instance.new("UIScale")
	caixaEscala.Parent = caixa
	local tocarEfeito: ((string) -> ())? = nil
	local atuais: { any } = {}
	local geracaoFala = 0

	local function letras(texto: string): { string }
		local r = {}
		for _, c in utf8.codes(texto) do
			table.insert(r, utf8.char(c))
		end
		return r
	end

	local function quebrarGlifos(glifos: { any }, rapido: boolean)
		for i, g in glifos do
			local label = g.label
			if not label.Parent then
				continue
			end
			local atraso = if rapido then 0 else math.min(0.32, g.ordem * 0.006) + math.random() * 0.06
			local tempo = (if rapido then 0.26 else 0.55) + math.random() * 0.25
			task.delay(atraso, function()
				if not label.Parent then
					return
				end
				local base = label.Position
				local dx = (math.random() * 2 - 1) * 48
				local dy = 22 + math.random() * 74
				local info = TweenInfo.new(tempo, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				TweenService:Create(label, info, {
					Position = base + UDim2.fromOffset(dx, dy),
					Rotation = (math.random() * 2 - 1) * 210,
					TextTransparency = 1,
				}):Play()
				TweenService:Create(g.escala, info, { Scale = 0.2 + math.random() * 0.4 }):Play()
				TweenService:Create(g.contorno, info, { Transparency = 1 }):Play()
				if not rapido and i % 3 == 1 then
					for _ = 1, 2 do
						local lasca = Instance.new("Frame")
						lasca.Name = "Lasca"
						lasca.BorderSizePixel = 0
						lasca.Active = false
						lasca.BackgroundColor3 = label.TextColor3
						lasca.BackgroundTransparency = 0.05
						lasca.AnchorPoint = Vector2.new(0.5, 0.5)
						lasca.Size = UDim2.fromOffset(2 + math.random(0, 3), 2 + math.random(0, 4))
						lasca.Position = base
						lasca.Rotation = math.random(0, 90)
						lasca.Parent = glifosPasta
						TweenService:Create(lasca, TweenInfo.new(tempo + 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
							Position = base + UDim2.fromOffset(dx * 1.8 + (math.random() * 2 - 1) * 34, dy * 1.6),
							Rotation = lasca.Rotation + (math.random() * 2 - 1) * 400,
							BackgroundTransparency = 1,
						}):Play()
						task.delay(tempo + 0.35, function()
							lasca:Destroy()
						end)
					end
				end
				task.delay(tempo + 0.1, function()
					label:Destroy()
				end)
			end)
		end
	end

	function api.fala(chave: string, duracao: number)
		local quem = textos.FALANTE[chave]
		local frase = L().falas[chave]
		if not quem or not frase then
			return
		end
		geracaoFala += 1
		local minha = geracaoFala
		-- a fala anterior quebra rápido antes da nova chegar
		if #atuais > 0 then
			quebrarGlifos(atuais, true)
			atuais = {}
		end
		local nome = L().falantes[quem] or quem
		local destaque = COR_FALANTE[quem] or AMBER
		falante.TextColor3 = destaque
		local tamanho = falaTexto.TextSize
		local padX, padY = 14, 8
		local largura = maxLegenda()
		local maxCar = math.max(16, math.floor((largura - padX * 2) / (tamanho * AVANCO)))
		local linhas = Interface.quebrar(frase, maxCar)
		local maior = larguraTexto(nome, falante.TextSize)
		for _, l in linhas do
			maior = math.max(maior, larguraTexto(l, tamanho))
		end
		local alturaLinha = math.ceil(tamanho * 1.25)
		local w = maior + padX * 2
		local h = padY * 2 + 16 + #linhas * alturaLinha
		caixa.Size = UDim2.fromOffset(w, h)
		caixa.Position = UDim2.new(0.5, 0, 1, 0)
		falante.Position = UDim2.fromOffset(padX, padY)
		falante.Size = UDim2.fromOffset(w - padX * 2, 14)
		falante.Text = nome
		falaTexto.Position = UDim2.fromOffset(padX, padY + 16)
		falaTexto.Size = UDim2.fromOffset(w - padX * 2, #linhas * alturaLinha)
		falaTexto.LineHeight = 1.25
		falaTexto.Text = table.concat(linhas, "\n") -- texto inteiro guardado (leitores/testes); quem desenha são as letras
		falaTexto.TextTransparency = 1
		glifosPasta.Position = falaTexto.Position
		glifosPasta.Size = falaTexto.Size
		somTexto.Position = UDim2.new(0, 0, 1, -h - 26)
		somTexto.Size = UDim2.new(1, 0, 0, 20)
		-- a caixa chega inclinada e assenta (sensação de profundidade)
		caixa.Rotation = -2.5
		caixaEscala.Scale = 0.94
		caixa.BackgroundTransparency = 0.85
		suave(caixa, 0.32, { BackgroundTransparency = 0.42 })
		TweenService:Create(caixa, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
		TweenService:Create(caixaEscala, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		falante.TextTransparency = 0

		local cw = tamanho * AVANCO
		local glifos = {}
		local ordem = 0
		for li, linha in linhas do
			local coluna = 0
			for _, ch in letras(linha) do
				if ch ~= " " then
					ordem += 1
					local g = Instance.new("TextLabel")
					g.Name = "Letra"
					g.BackgroundTransparency = 1
					g.BorderSizePixel = 0
					g.Active = false
					g.FontFace = MONO_MEDIUM
					g.TextSize = tamanho
					g.TextColor3 = destaque
					g.Text = ch
					g.TextTransparency = 1
					g.TextXAlignment = Enum.TextXAlignment.Center
					g.TextYAlignment = Enum.TextYAlignment.Center
					g.AnchorPoint = Vector2.new(0.5, 0.5)
					g.Size = UDim2.fromOffset(math.ceil(cw) + 2, alturaLinha)
					local final = UDim2.fromOffset(coluna * cw + cw / 2, (li - 1) * alturaLinha + alturaLinha / 2)
					g.Position = final + UDim2.fromOffset((math.random() * 2 - 1) * 6, -12)
					g.Rotation = (math.random() * 2 - 1) * 42
					local contorno = Instance.new("UIStroke")
					contorno.Color = BLACK
					contorno.Thickness = 1
					contorno.Transparency = 0.3
					contorno.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
					contorno.Parent = g
					local escala = Instance.new("UIScale")
					escala.Scale = 2.4
					escala.Parent = g
					g.Parent = glifosPasta
					table.insert(glifos, { label = g, escala = escala, contorno = contorno, final = final, ordem = ordem })
				end
				coluna += 1
			end
		end
		atuais = glifos

		-- entrada: letra por letra; a fala inteira fica legível bem antes de acabar
		local total = #glifos
		local janela = math.clamp(math.min(duracao * 0.45, total / 34), 0.15, 3.5)
		local porQuadro = math.max(1, math.ceil(total / math.max(1, janela * 60)))
		task.spawn(function()
			for i, g in glifos do
				if minha ~= geracaoFala then
					return
				end
				local label = g.label
				if label.Parent then
					local chegada = TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
					TweenService:Create(label, chegada, { Position = g.final, Rotation = 0 }):Play()
					TweenService:Create(g.escala, chegada, { Scale = 1 }):Play()
					TweenService:Create(label, TweenInfo.new(0.12), { TextTransparency = 0 }):Play()
					TweenService:Create(label, TweenInfo.new(0.5), { TextColor3 = WHITE }):Play()
				end
				if i % porQuadro == 0 then
					task.wait()
				end
			end
		end)

		task.delay(duracao, function()
			if minha ~= geracaoFala then
				return
			end
			if tocarEfeito then
				pcall(tocarEfeito, "legenda_quebra")
			end
			quebrarGlifos(glifos, false)
			atuais = {}
			TweenService:Create(caixa, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Rotation = 1.5 }):Play()
			suave(caixa, 0.45, { BackgroundTransparency = 1 })
			suave(falante, 0.3, { TextTransparency = 1 })
		end)
	end

	function api.definirSom(fn: ((chave: string) -> ())?)
		tocarEfeito = fn
	end

	local geracaoSom = 0
	function api.som(chave: string, duracao: number)
		local s = L().sons[chave]
		if not s then
			return
		end
		geracaoSom += 1
		local minha = geracaoSom
		if caixa.BackgroundTransparency >= 0.99 then
			somTexto.Position = UDim2.new(0, 0, 1, -22)
			somTexto.Size = UDim2.new(1, 0, 0, 20)
		end
		somTexto.Text = s
		somTexto.TextTransparency = 0
		task.delay(duracao, function()
			if minha == geracaoSom then
				suave(somTexto, 0.4, { TextTransparency = 1 })
			end
		end)
	end

	local geracaoAviso = 0
	function api.aviso(chave: string, args: { any }?)
		local modelo = L().avisos[chave]
		if not modelo then
			return
		end
		local ok, texto = pcall(string.format, modelo, table.unpack(args or {}))
		geracaoAviso += 1
		local minha = geracaoAviso
		avisoTexto.Text = string.upper(if ok then texto else modelo)
		avisoTexto.TextTransparency = 0
		task.delay(3.2, function()
			if minha == geracaoAviso then
				suave(avisoTexto, 0.5, { TextTransparency = 1 })
			end
		end)
	end

	-- ===== alerta de isolamento (pisca como a gravação da câmera) =====
	local geracaoAlarme = 0
	function api.alarme(ligado: boolean)
		geracaoAlarme += 1
		local minha = geracaoAlarme
		alerta.Visible = ligado
		if not ligado then
			return
		end
		task.spawn(function()
			local aceso = true
			while minha == geracaoAlarme do
				alerta.TextTransparency = if aceso then 0 else 0.7
				aceso = not aceso
				task.wait(0.6)
			end
		end)
	end

	-- ===== corte preto (quem é levado para dentro da oficina) =====
	function api.corte()
		suave(preto, 0.3, { BackgroundTransparency = 0 })
		task.delay(0.95, function()
			suave(preto, 0.6, { BackgroundTransparency = 1 })
		end)
	end

	-- ===== cartão de fim da etapa =====
	local mostrouFim = false
	function api.fim()
		if mostrouFim then
			return
		end
		mostrouFim = true
		cartao.Visible = true
		suave(cartao, 1.2, { BackgroundTransparency = 0.18 })
		for i, t in linhasFim do
			task.delay(0.5 + i * 0.35, function()
				suave(t, 0.8, { TextTransparency = 0 })
			end)
		end
		task.delay(10, function()
			suave(cartao, 1.5, { BackgroundTransparency = 1 })
			for _, t in linhasFim do
				suave(t, 1.2, { TextTransparency = 1 })
			end
			task.delay(1.6, function()
				cartao.Visible = false
			end)
		end)
	end

	function api.idioma()
		cabecalho.Text = L().ui.objetivo
		alerta.Text = L().ui.alerta
		for i, t in linhasFim do
			t.Text = L().fim[chavesFim[i]]
		end
		if objetivoAtual then
			geracaoObjetivo += 1
			objetivoTexto.Text = string.upper(L().objetivos[objetivoAtual] or "")
			objetivoTexto.TextColor3 = WHITE
		end
	end

	return api :: Api
end

return Interface
