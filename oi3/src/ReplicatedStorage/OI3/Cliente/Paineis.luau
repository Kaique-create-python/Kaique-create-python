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
end

---------------------------------------------------------------------------
-- Multiplayer
---------------------------------------------------------------------------
local function montarMulti()
	local _, conteudo = cartao("multi", "MULTIPLAYER", 500, 350)
	local sala = estado.ctx.sala
	ordem(Interface.texto(conteudo, {
		Text = "Assistam à abertura juntos. Quando todos da sala estiverem prontos, a história começa para o grupo.",
		TextSize = 16,
		TextColor3 = COR.textoFraco,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}), 1)
	local lista = Instance.new("Frame")
	lista.Name = "Lista"
	lista.BackgroundTransparency = 1
	lista.Size = UDim2.new(1, 0, 0, 0)
	lista.AutomaticSize = Enum.AutomaticSize.Y
	ordem(lista, 2)
	lista.Parent = conteudo
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 4)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = lista
	local status = ordem(Interface.texto(conteudo, {
		Name = "Status",
		Text = "Entrando na sala...",
		FontFace = FONTE.textoForte,
		TextSize = 17,
		TextColor3 = COR.texto,
		Size = UDim2.new(1, 0, 0, 26),
	}), 3)
	local botoes = Instance.new("Frame")
	botoes.Name = "Botoes"
	botoes.BackgroundTransparency = 1
	botoes.Size = UDim2.new(1, 0, 0, 46)
	ordem(botoes, 4)
	botoes.Parent = conteudo
	local lb = Instance.new("UIListLayout")
	lb.FillDirection = Enum.FillDirection.Horizontal
	lb.Padding = UDim.new(0, 10)
	lb.Parent = botoes
	local pronto = false
	local bPronto: TextButton
	bPronto = Interface.botao(botoes, "ESTOU PRONTO", { Size = UDim2.new(0.5, -5, 1, 0), BackgroundColor3 = Color3.fromRGB(120, 28, 28) }, function()
		pronto = not pronto
		bPronto.Text = if pronto then "CANCELAR" else "ESTOU PRONTO"
		sala.pronto(pronto)
	end)
	Interface.botao(botoes, "CONVIDAR AMIGOS", { Size = UDim2.new(0.5, -5, 1, 0) }, function()
		sala.convidar()
	end)
	ordem(Interface.texto(conteudo, {
		Text = "Até " .. Config.SALA.maximoJogadores .. " pessoas por grupo. Quem não estiver na sala continua no menu.",
		TextSize = 13,
		TextColor3 = COR.textoFraco,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}), 5)

	local miniaturas: { [number]: string } = {}
	local function linhaJogador(info: { userId: number, nome: string, pronto: boolean }, i: number)
		local f = Instance.new("Frame")
		f.Name = "J" .. info.userId
		f.BackgroundColor3 = Color3.fromRGB(26, 24, 29)
		f.BorderSizePixel = 0
		f.Size = UDim2.new(1, 0, 0, 40)
		f.LayoutOrder = i
		Interface.canto(f, 4)
		local foto = Instance.new("ImageLabel")
		foto.BackgroundColor3 = Color3.fromRGB(40, 36, 42)
		foto.BorderSizePixel = 0
		foto.Position = UDim2.fromOffset(4, 4)
		foto.Size = UDim2.fromOffset(32, 32)
		foto.Image = miniaturas[info.userId] or ""
		Interface.canto(foto, 4)
		foto.Parent = f
		if not miniaturas[info.userId] then
			task.spawn(function()
				local ok, img = pcall(function()
					return Players:GetUserThumbnailAsync(info.userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				end)
				if ok and img then
					miniaturas[info.userId] = img
					if foto.Parent then
						foto.Image = img
					end
				end
			end)
		end
		Interface.texto(f, { Text = info.nome, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -150, 1, 0), TextSize = 17, FontFace = FONTE.textoForte })
		local tag = Interface.texto(f, {
			Text = if info.pronto then "PRONTO" else "ESPERANDO",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(100, 24),
			TextSize = 13,
			FontFace = FONTE.textoNegrito,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0,
			BackgroundColor3 = if info.pronto then Color3.fromRGB(38, 74, 46) else Color3.fromRGB(46, 42, 48),
			TextColor3 = if info.pronto then COR.ok else COR.textoFraco,
		})
		Interface.canto(tag, 4)
		f.Parent = lista
	end

	estado.multi = {
		atualizar = function(dados: any)
			for _, ch in lista:GetChildren() do
				if ch:IsA("Frame") then
					ch:Destroy()
				end
			end
			for i, info in dados.membros or {} do
				linhaJogador(info, i)
			end
			local minimo = Config.SALA.minimoJogadores
			if dados.contagem then
				status.Text = "Começando em " .. tostring(dados.contagem) .. "..."
				status.TextColor3 = COR.destaqueClaro
			elseif #(dados.membros or {}) < minimo then
				status.Text = "Esperando mais alguém entrar na sala (mínimo " .. minimo .. ")."
				status.TextColor3 = COR.texto
			else
				status.Text = "Todos precisam apertar ESTOU PRONTO."
				status.TextColor3 = COR.texto
			end
			if dados.mensagem then
				status.Text = dados.mensagem
			end
		end,
		reiniciar = function()
			pronto = false
			bPronto.Text = "ESTOU PRONTO"
		end,
	}
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
	if not semAviso and estado.aoFechar then
		estado.aoFechar(nome)
	end
end

function Paineis.atualizarSala(dados: any)
	if estado.multi then
		estado.multi.atualizar(dados)
	end
end

return Paineis
