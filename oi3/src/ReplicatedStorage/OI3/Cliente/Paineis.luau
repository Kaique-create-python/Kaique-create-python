-- OI3 :: painéis 2D do menu (Créditos, Configurações, Multiplayer)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local OI3 = script.Parent.Parent
local Config = require(OI3.Config)
local Interface = require(script.Parent.Interface)

local Paineis = {}

local COR = Interface.COR
local FONTE = Interface.FONTE

local estado = {
	tela = nil :: ScreenGui?,
	fundo = nil :: TextButton?,
	cartoes = {} :: { [string]: CanvasGroup },
	aberto = nil :: string?,
	ctx = nil :: any,
	aoFechar = nil :: ((string) -> ())?,
	multi = nil :: any,
	aviso = nil :: any,
	resumo = nil :: any,
	noMenu = false,
}

local function cartao(nome: string, titulo: string, largura: number, altura: number): (CanvasGroup, ScrollingFrame)
	local tela = estado.tela :: ScreenGui
	local c = Instance.new("CanvasGroup")
	c.Name = "Cartao_" .. nome
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Position = UDim2.fromScale(0.5, 0.5)
	c.Size = UDim2.fromOffset(largura, altura)
	c.BackgroundColor3 = COR.painel
	c.BackgroundTransparency = 0.04
	c.BorderSizePixel = 0
	c.GroupTransparency = 1
	c.Visible = false
	c.ZIndex = 5
	Interface.canto(c, 4)
	Interface.borda(c, COR.borda, 1, 0.2)
	local lim = Instance.new("UISizeConstraint")
	lim.MaxSize = Vector2.new(largura, altura)
	lim.Parent = c
	c.Parent = tela

	Interface.texto(c, {
		Name = "Titulo",
		Text = titulo,
		FontFace = FONTE.titulo,
		TextSize = 22,
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -80, 0, 34),
		TextColor3 = COR.texto,
	})
	local fechar = Interface.botao(c, "×", {
		Name = "Fechar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 9),
		Size = UDim2.fromOffset(38, 36),
		TextSize = 26,
	}, function()
		Paineis.fechar()
	end)
	fechar.ZIndex = 6
	local linha = Instance.new("Frame")
	linha.Name = "Divisor"
	linha.BackgroundColor3 = COR.borda
	linha.BackgroundTransparency = 0.5
	linha.BorderSizePixel = 0
	linha.Position = UDim2.fromOffset(16, 52)
	linha.Size = UDim2.new(1, -32, 0, 1)
	linha.Parent = c

	local conteudo = Instance.new("ScrollingFrame")
	conteudo.Name = "Conteudo"
	conteudo.BackgroundTransparency = 1
	conteudo.BorderSizePixel = 0
	conteudo.Position = UDim2.fromOffset(18, 60)
	conteudo.Size = UDim2.new(1, -30, 1, -70)
	conteudo.ScrollBarThickness = 4
	conteudo.ScrollBarImageColor3 = COR.borda
	conteudo.CanvasSize = UDim2.new()
	conteudo.AutomaticCanvasSize = Enum.AutomaticSize.Y
	conteudo.ScrollingDirection = Enum.ScrollingDirection.Y
	conteudo.Parent = c
	local lista = Instance.new("UIListLayout")
	lista.Padding = UDim.new(0, 6)
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Parent = conteudo
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = conteudo
	estado.cartoes[nome] = c
	return c, conteudo
end

local function ordem(obj: GuiObject, n: number)
	obj.LayoutOrder = n
	return obj
end

---------------------------------------------------------------------------
-- Créditos
---------------------------------------------------------------------------
local function montarCreditos()
	local _, conteudo = cartao("creditos", "CRÉDITOS", 470, 330)
	local cred = Config.CREDITOS
	ordem(Interface.texto(conteudo, {
		Text = cred.titulo,
		FontFace = FONTE.textoNegrito,
		TextSize = 15,
		TextColor3 = COR.textoFraco,
		Size = UDim2.new(1, 0, 0, 22),
	}), 1)
	local n = 2
	for _, pessoa in cred.pessoas do
		ordem(Interface.texto(conteudo, {
			Text = pessoa.nome,
			FontFace = FONTE.titulo,
			TextSize = 22,
			TextColor3 = COR.ouro,
			Size = UDim2.new(1, 0, 0, 28),
		}), n)
		ordem(Interface.texto(conteudo, {
			Text = pessoa.funcao,
			FontFace = FONTE.texto,
			TextSize = 17,
			TextColor3 = COR.texto,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}), n + 1)
		local esp = Instance.new("Frame")
		esp.BackgroundTransparency = 1
		esp.Size = UDim2.new(1, 0, 0, 6)
		ordem(esp, n + 2)
		esp.Parent = conteudo
		n += 3
	end
	ordem(Interface.texto(conteudo, {
		Text = cred.nota,
		FontFace = FONTE.texto,
		TextSize = 14,
		TextColor3 = COR.textoFraco,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}), n)
	ordem(Interface.texto(conteudo, {
		Text = Config.JOGO .. " · " .. Config.REVISAO,
		FontFace = FONTE.texto,
		TextSize = 13,
		TextColor3 = COR.textoFraco,
		TextTransparency = 0.3,
		Size = UDim2.new(1, 0, 0, 20),
	}), n + 1)
end

---------------------------------------------------------------------------
-- Configurações
---------------------------------------------------------------------------
local function montarConfig()
	local _, conteudo = cartao("config", "CONFIGURAÇÕES", 480, 340)
	local aj = estado.ctx.ajustes
	local v = aj.valores
	local L = Config.LIMITES
	ordem(Interface.deslizante(conteudo, "Música e clima", v.musica, 0, 1, function(x)
		aj.definir("musica", x)
	end), 1)
	ordem(Interface.deslizante(conteudo, "Efeitos sonoros", v.efeitos, 0, 1, function(x)
		aj.definir("efeitos", x)
	end), 2)
	ordem(Interface.deslizante(conteudo, "Vozes", v.vozes, 0, 1, function(x)
		aj.definir("vozes", x)
	end), 3)
	ordem(Interface.deslizante(conteudo, "Brilho da tela", v.brilho, L.brilhoMin, L.brilhoMax, function(x)
		aj.definir("brilho", x)
	end), 4)
	ordem(Interface.chave(conteudo, "Legendas", v.legendas, function(b)
		aj.definir("legendas", b)
	end), 5)
	ordem(Interface.chave(conteudo, "Efeitos leves (celular fraco)", v.efeitosLeves, function(b)
		aj.definir("efeitosLeves", b)
	end), 6)
	ordem(Interface.chave(conteudo, "Tremor de câmera", v.tremor, function(b)
		aj.definir("tremor", b)
	end), 7)
	ordem(Interface.texto(conteudo, {
		Text = "Suas escolhas ficam salvas.",
		TextSize = 14,
		TextColor3 = COR.textoFraco,
		Size = UDim2.new(1, 0, 0, 22),
	}), 8)
	-- situação dos sons (ajuda a saber se o Roblox já liberou os áudios)
	local statusSom = ordem(Interface.texto(conteudo, {
		Name = "StatusSom",
		Text = "Sons: carregando...",
		TextSize = 14,
		TextColor3 = COR.textoFraco,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}), 9)
	local som = estado.ctx.som
	if som then
		local function atualizar()
			local texto, tudoBem = som.textoEstado()
			statusSom.Text = texto
			statusSom.TextColor3 = if tudoBem then COR.ok else COR.textoFraco
		end
		atualizar()
		som.aoMudarEstado(atualizar)
		-- botão para ouvir na hora se o som está saindo
		ordem(Interface.botao(conteudo, "TESTAR SOM", { Size = UDim2.new(1, 0, 0, 44), TextSize = 17 }, function()
			som.testar()
		end), 10)
	end
end

---------------------------------------------------------------------------
-- Multiplayer
---------------------------------------------------------------------------
local function montarMulti()
	-- AJUSTE-7: sala com uma VAGA por criança (até 3), foto de cada um, quem está pronto e a contagem
	local maximo = Config.SALA.maximoJogadores
	local c, conteudo = cartao("multi", "MULTIPLAYER", 560, 400)
	local sala = estado.ctx.sala
	local lp = Players.LocalPlayer
	local contador = Interface.texto(c, {
		Name = "Contador",
		Text = "SALA 0/" .. maximo,
		FontFace = FONTE.textoNegrito,
		TextSize = 14,
		TextColor3 = COR.textoFraco,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -56, 0, 18),
		Size = UDim2.fromOffset(110, 20),
	})
	ordem(Interface.texto(conteudo, {
		Text = "Entrem na sala, apertem ESTOU PRONTO e a história começa para o grupo. Cada um vai ser uma criança diferente.",
		TextSize = 15,
		TextColor3 = COR.textoFraco,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}), 1)

	local vagas = Instance.new("Frame")
	vagas.Name = "Vagas"
	vagas.BackgroundTransparency = 1
	vagas.Size = UDim2.new(1, 0, 0, 150)
	ordem(vagas, 2)
	vagas.Parent = conteudo
	local lv = Instance.new("UIListLayout")
	lv.FillDirection = Enum.FillDirection.Horizontal
	lv.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lv.Padding = UDim.new(0, 8)
	lv.SortOrder = Enum.SortOrder.LayoutOrder
	lv.Parent = vagas
	local slots = {}
	for i = 1, maximo do
		local v = Instance.new("Frame")
		v.Name = "Vaga" .. i
		v.LayoutOrder = i
		v.BackgroundColor3 = Color3.fromRGB(22, 20, 25)
		v.BorderSizePixel = 0
		v.Size = UDim2.new(1 / maximo, -math.ceil(8 * (maximo - 1) / maximo), 1, 0)
		Interface.canto(v, 4)
		local bordaVaga = Interface.borda(v, COR.borda, 1, 0.5)
		v.Parent = vagas
		local foto = Instance.new("ImageLabel")
		foto.Name = "Foto"
		foto.AnchorPoint = Vector2.new(0.5, 0)
		foto.Position = UDim2.new(0.5, 0, 0, 12)
		foto.Size = UDim2.fromOffset(66, 66)
		foto.BackgroundColor3 = Color3.fromRGB(38, 34, 40)
		foto.BorderSizePixel = 0
		foto.Image = ""
		Interface.canto(foto, 4)
		local aro = Interface.borda(foto, COR.textoFraco, 2, 0.2)
		foto.Parent = v
		local nome = Interface.texto(v, {
			Name = "Nome",
			Text = "",
			FontFace = FONTE.textoForte,
			TextSize = 16,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 6, 0, 84),
			Size = UDim2.new(1, -12, 0, 22),
		})
		local chip = Interface.texto(v, {
			Name = "Chip",
			Text = "",
			FontFace = FONTE.textoNegrito,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.fromOffset(104, 22),
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(46, 42, 48),
		})
		Interface.canto(chip, 4)
		-- vaga livre: o cartão inteiro vira um botão de convidar
		local livre = Instance.new("TextButton")
		livre.Name = "Livre"
		livre.BackgroundTransparency = 1
		livre.Size = UDim2.fromScale(1, 1)
		livre.Text = ""
		livre.ZIndex = 3
		livre.Parent = v
		local mais = Interface.texto(livre, {
			Text = "+",
			FontFace = FONTE.titulo,
			TextSize = 40,
			TextColor3 = COR.borda,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 0, 0, 18),
			Size = UDim2.new(1, 0, 0, 56),
			ZIndex = 3,
		})
		local convidar = Interface.texto(livre, {
			Text = "VAGA LIVRE\ntoque para convidar",
			FontFace = FONTE.textoForte,
			TextSize = 13,
			TextColor3 = COR.textoFraco,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 6, 0, 82),
			Size = UDim2.new(1, -12, 0, 40),
			ZIndex = 3,
		})
		livre.Activated:Connect(function()
			if livre.Visible then
				sala.convidar()
			end
		end)
		slots[i] = { quadro = v, borda = bordaVaga, foto = foto, aro = aro, nome = nome, chip = chip, livre = livre, mais = mais, convidar = convidar }
	end

	local status = ordem(Interface.texto(conteudo, {
		Name = "Status",
		Text = "Entrando na sala...",
		FontFace = FONTE.textoForte,
		TextSize = 17,
		TextColor3 = COR.texto,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
	}), 3)
	local pulso = Instance.new("UIScale")
	pulso.Parent = status
	local botoes = Instance.new("Frame")
	botoes.Name = "Botoes"
	botoes.BackgroundTransparency = 1
	botoes.Size = UDim2.new(1, 0, 0, 48)
	ordem(botoes, 4)
	botoes.Parent = conteudo
	local lb = Instance.new("UIListLayout")
	lb.FillDirection = Enum.FillDirection.Horizontal
	lb.Padding = UDim.new(0, 10)
	lb.Parent = botoes
	local pronto = false
	local naSala = false
	local bPronto: TextButton
	local VERMELHO, CINZA = Color3.fromRGB(128, 28, 28), Color3.fromRGB(52, 48, 56)
	local function pintarPronto()
		bPronto.Text = if pronto then "CANCELAR" else "ESTOU PRONTO"
		bPronto.BackgroundColor3 = if pronto then CINZA else VERMELHO
		bPronto.TextTransparency = if naSala then 0 else 0.5
	end
	bPronto = Interface.botao(botoes, "ESTOU PRONTO", { Size = UDim2.new(0.5, -5, 1, 0), BackgroundColor3 = VERMELHO }, function()
		if not naSala then
			sala.entrar()
			return
		end
		pronto = not pronto
		pintarPronto()
		sala.pronto(pronto)
	end)
	Interface.botao(botoes, "CONVIDAR AMIGOS", { Size = UDim2.new(0.5, -5, 1, 0) }, function()
		sala.convidar()
	end)
	ordem(Interface.texto(conteudo, {
		Text = "Até " .. maximo .. " pessoas por grupo. Quem não estiver na sala continua no menu.",
		TextSize = 13,
		TextColor3 = COR.textoFraco,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}), 5)

	local function pintarVaga(sl, info: { userId: number, nome: string, pronto: boolean }?)
		sl.livre.Visible = info == nil
		sl.foto.Visible = info ~= nil
		sl.nome.Visible = info ~= nil
		sl.chip.Visible = info ~= nil
		if not info then
			sl.quadro.BackgroundTransparency = 0.45
			sl.borda.Color = COR.borda
			sl.borda.Transparency = 0.6
			return
		end
		local eu = info.userId == lp.UserId
		sl.quadro.BackgroundTransparency = 0
		sl.foto.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", info.userId)
		sl.nome.Text = if eu then info.nome .. " (você)" else info.nome
		sl.nome.TextColor3 = if eu then COR.ouro else COR.texto
		sl.chip.Text = if info.pronto then "PRONTO" else "ESPERANDO"
		sl.chip.BackgroundColor3 = if info.pronto then Color3.fromRGB(38, 74, 46) else Color3.fromRGB(46, 42, 48)
		sl.chip.TextColor3 = if info.pronto then COR.ok else COR.textoFraco
		sl.aro.Color = if info.pronto then COR.ok else COR.textoFraco
		sl.borda.Color = if eu then COR.ouro else COR.borda
		sl.borda.Transparency = if eu then 0.25 else 0.5
	end

	estado.multi = {
		atualizar = function(dados: any)
			local membros = dados.membros or {}
			naSala = false
			for _, info in membros do
				if info.userId == lp.UserId then
					naSala = true
					pronto = info.pronto == true
				end
			end
			for i, sl in slots do
				pintarVaga(sl, membros[i])
			end
			contador.Text = string.format("SALA %d/%d", #membros, maximo)
			pintarPronto()
			local minimo = Config.SALA.minimoJogadores
			pulso.Scale = 1
			if dados.contagem then
				status.Text = "A história começa em " .. tostring(dados.contagem) .. "..."
				status.TextColor3 = COR.destaqueClaro
				pulso.Scale = 1.18
				TweenService:Create(pulso, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			elseif not naSala and #membros >= maximo then
				status.Text = "Sala cheia. Espere uma vaga."
				status.TextColor3 = COR.textoFraco
			elseif #membros < minimo then
				status.Text = "Esperando mais alguém entrar (mínimo " .. minimo .. ")."
				status.TextColor3 = COR.texto
			else
				local faltam = 0
				for _, info in membros do
					if not info.pronto then
						faltam += 1
					end
				end
				status.Text = if faltam == 1 then "Falta 1 pessoa apertar ESTOU PRONTO." else "Faltam " .. faltam .. " pessoas apertarem ESTOU PRONTO."
				status.TextColor3 = COR.texto
			end
			if dados.mensagem then
				status.Text = dados.mensagem
				status.TextColor3 = COR.textoFraco
			end
		end,
		mensagem = function(texto: string)
			status.Text = texto
			status.TextColor3 = COR.textoFraco
		end,
		reiniciar = function()
			pronto = false
			naSala = false
			for _, sl in slots do
				pintarVaga(sl, nil)
			end
			status.Text = "Entrando na sala..."
			pintarPronto()
		end,
	}
	estado.multi.reiniciar()
end

-- AJUSTE-7: aviso discreto no menu quando já tem gente na sala (toque para entrar)
local function montarAvisoSala()
	local tela = estado.tela :: ScreenGui
	local b = Instance.new("TextButton")
	b.Name = "AvisoSala"
	b.AutoButtonColor = false
	b.AnchorPoint = Vector2.new(0, 0)
	b.Position = UDim2.fromOffset(14, 12)
	b.Size = UDim2.fromOffset(210, 40)
	b.BackgroundColor3 = COR.painel
	b.BackgroundTransparency = 0.1
	b.BorderSizePixel = 0
	b.Text = ""
	b.Visible = false
	b.ZIndex = 2
	Interface.canto(b, 4)
	Interface.borda(b, COR.destaque, 1, 0.2)
	b.Parent = tela
	local ponto = Instance.new("Frame")
	ponto.AnchorPoint = Vector2.new(0, 0.5)
	ponto.Position = UDim2.new(0, 12, 0.5, 0)
	ponto.Size = UDim2.fromOffset(10, 10)
	ponto.BackgroundColor3 = COR.destaqueClaro
	ponto.BorderSizePixel = 0
	ponto.ZIndex = 2
	Interface.canto(ponto, 4)
	ponto.Parent = b
	TweenService:Create(ponto, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.7 }):Play()
	local t = Interface.texto(b, {
		Text = "",
		FontFace = FONTE.textoNegrito,
		TextSize = 15,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -36, 1, 0),
		ZIndex = 2,
	})
	b.Activated:Connect(function()
		if estado.ctx and estado.ctx.abrirMulti then
			estado.ctx.abrirMulti()
		end
	end)
	estado.aviso = { botao = b, texto = t }
end

local function atualizarAviso()
	local av = estado.aviso
	if not av then
		return
	end
	local r = estado.resumo
	local lp = Players.LocalPlayer
	local souMembro = r and r.ids and table.find(r.ids, lp.UserId) ~= nil
	local mostrar = estado.noMenu and not estado.aberto and r ~= nil and (r.n or 0) > 0 and not souMembro
	av.botao.Visible = mostrar == true
	if mostrar then
		av.texto.Text = string.format("SALA %d/%d · ENTRAR", r.n, r.max or Config.SALA.maximoJogadores)
	end
end

function Paineis.resumoSala(info: any)
	if type(info) == "table" then
		estado.resumo = info
		atualizarAviso()
	end
end

function Paineis.noMenu(v: boolean)
	estado.noMenu = v
	atualizarAviso()
end

---------------------------------------------------------------------------

function Paineis.iniciar(ctx: any)
	estado.ctx = ctx
	local tela = Interface.tela("OI3_Paineis", 20, true)
	estado.tela = tela
	Interface.escalaAuto(tela)
	local fundo = Instance.new("TextButton")
	fundo.Name = "Fundo"
	fundo.Text = ""
	fundo.AutoButtonColor = false
	fundo.BackgroundColor3 = Color3.new(0, 0, 0)
	fundo.BackgroundTransparency = 1
	fundo.Size = UDim2.fromScale(1, 1)
	fundo.Visible = false
	fundo.ZIndex = 1
	fundo.Parent = tela
	fundo.Activated:Connect(function()
		Paineis.fechar()
	end)
	estado.fundo = fundo
	montarCreditos()
	montarConfig()
	montarMulti()
	montarAvisoSala()
end

function Paineis.aoFechar(fn: (string) -> ())
	estado.aoFechar = fn
end

function Paineis.aberto(): string?
	return estado.aberto
end

function Paineis.abrir(nome: string)
	if estado.aberto then
		Paineis.fechar(true)
	end
	local c = estado.cartoes[nome]
	if not c then
		return
	end
	estado.aberto = nome
	local fundo = estado.fundo :: TextButton
	fundo.Visible = true
	TweenService:Create(fundo, TweenInfo.new(0.2), { BackgroundTransparency = 0.5 }):Play()
	c.Visible = true
	c.Position = UDim2.new(0.5, 0, 0.5, 22)
	c.GroupTransparency = 1
	TweenService:Create(c, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5), GroupTransparency = 0 }):Play()
	if nome == "multi" then
		estado.multi.reiniciar()
		estado.ctx.sala.entrar()
	end
	atualizarAviso()
end

function Paineis.fechar(semAviso: boolean?)
	local nome = estado.aberto
	if not nome then
		return
	end
	estado.aberto = nil
	local c = estado.cartoes[nome]
	local fundo = estado.fundo :: TextButton
	TweenService:Create(fundo, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
	task.delay(0.19, function()
		if not estado.aberto then
			fundo.Visible = false
		end
	end)
	if c then
		local tw = TweenService:Create(c, TweenInfo.new(0.18), { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 16) })
		tw:Play()
		task.delay(0.19, function()
			if estado.aberto ~= nome then
				c.Visible = false
			end
		end)
	end
	if nome == "multi" then
		estado.ctx.sala.sair()
	end
	atualizarAviso()
	if not semAviso and estado.aoFechar then
		estado.aoFechar(nome)
	end
end

-- só um recado na linha de status (não mexe nas vagas)
function Paineis.recadoSala(texto: string)
	if estado.multi then
		estado.multi.mensagem(texto)
	end
end

function Paineis.atualizarSala(dados: any)
	if estado.multi then
		estado.multi.atualizar(dados)
	end
end

return Paineis
