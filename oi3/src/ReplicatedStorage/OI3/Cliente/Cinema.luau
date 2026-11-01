-- OI3 :: camada de cinema: faixas pretas, legendas, escurecer, títulos e botão "Pular"

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local OI3 = script.Parent.Parent
local Dialogos = require(OI3.Dialogos)
local Interface = require(script.Parent.Interface)

local Cinema = {}

local estado = {
	tela = nil :: ScreenGui?,
	telaSegura = nil :: ScreenGui?,
	cima = nil :: Frame?,
	baixo = nil :: Frame?,
	preto = nil :: Frame?,
	legenda = nil :: TextLabel?,
	caixaLegenda = nil :: Frame?,
	titulo = nil :: TextLabel?,
	flash = nil :: TextLabel?,
	pular = nil :: TextButton?,
	barraPular = nil :: Frame?,
	legendasLigadas = true,
	tokenLegenda = 0,
	aoPular = nil :: (() -> ())?,
}

function Cinema.iniciar()
	local tela = Interface.tela("OI3_Cinema", 40, false)
	estado.tela = tela
	local function faixa(nome: string, cima: boolean): Frame
		local f = Instance.new("Frame")
		f.Name = nome
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.AnchorPoint = if cima then Vector2.new(0, 0) else Vector2.new(0, 1)
		f.Position = if cima then UDim2.fromScale(0, 0) else UDim2.fromScale(0, 1)
		f.Size = UDim2.fromScale(1, 0)
		f.ZIndex = 2
		f.Parent = tela
		return f
	end
	estado.cima = faixa("FaixaCima", true)
	estado.baixo = faixa("FaixaBaixo", false)
	local preto = Instance.new("Frame")
	preto.Name = "Preto"
	preto.BackgroundColor3 = Color3.new(0, 0, 0)
	preto.BorderSizePixel = 0
	preto.Size = UDim2.fromScale(1, 1)
	preto.BackgroundTransparency = 1
	preto.ZIndex = 10
	preto.Parent = tela
	estado.preto = preto

	local titulo = Instance.new("TextLabel")
	titulo.Name = "Titulo"
	titulo.BackgroundTransparency = 1
	titulo.AnchorPoint = Vector2.new(0.5, 0.5)
	titulo.Position = UDim2.fromScale(0.5, 0.47)
	titulo.Size = UDim2.fromScale(0.7, 0.34)
	titulo.TextScaled = true
	titulo.Text = ""
	titulo.FontFace = Interface.FONTE.logo
	titulo.TextColor3 = Color3.fromRGB(226, 220, 212)
	titulo.TextTransparency = 1
	titulo.ZIndex = 12
	titulo.Parent = tela
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(120, 14, 14)
	st.Thickness = 2
	st.Transparency = 1
	st.Parent = titulo
	estado.titulo = titulo

	local flash = titulo:Clone()
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(0.5, 0.28)
	flash.ZIndex = 11
	flash.Parent = tela
	estado.flash = flash

	-- legendas (tela segura: evita entalhe/barra do Roblox)
	local telaS = Interface.tela("OI3_Legendas", 41, true)
	estado.telaSegura = telaS
	Interface.escalaAuto(telaS)
	local caixa = Instance.new("Frame")
	caixa.Name = "CaixaLegenda"
	caixa.AnchorPoint = Vector2.new(0.5, 1)
	caixa.Position = UDim2.new(0.5, 0, 1, -64)
	caixa.Size = UDim2.fromOffset(0, 0)
	caixa.AutomaticSize = Enum.AutomaticSize.XY
	caixa.BackgroundColor3 = Color3.new(0, 0, 0)
	caixa.BackgroundTransparency = 1
	caixa.BorderSizePixel = 0
	Interface.canto(caixa, 4)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = caixa
	caixa.Parent = telaS
	local leg = Instance.new("TextLabel")
	leg.Name = "Texto"
	leg.BackgroundTransparency = 1
	leg.RichText = true
	leg.Text = ""
	leg.TextWrapped = true
	leg.AutomaticSize = Enum.AutomaticSize.XY
	leg.Size = UDim2.fromOffset(0, 0)
	leg.FontFace = Interface.FONTE.textoForte
	leg.TextSize = 21
	leg.TextColor3 = Color3.fromRGB(240, 236, 228)
	leg.TextTransparency = 1
	local limite = Instance.new("UISizeConstraint")
	limite.MaxSize = Vector2.new(560, 200)
	limite.Parent = leg
	leg.Parent = caixa
	estado.legenda = leg
	estado.caixaLegenda = caixa

	-- botão Pular (segurar)
	local pular = Instance.new("TextButton")
	pular.Name = "Pular"
	pular.AutoButtonColor = false
	pular.AnchorPoint = Vector2.new(1, 1)
	pular.Position = UDim2.new(1, -14, 1, -12)
	pular.Size = UDim2.fromOffset(108, 38)
	pular.BackgroundColor3 = Color3.fromRGB(18, 16, 20)
	pular.BackgroundTransparency = 0.25
	pular.Text = "PULAR  ›"
	pular.FontFace = Interface.FONTE.textoNegrito
	pular.TextSize = 16
	pular.TextColor3 = Color3.fromRGB(230, 224, 214)
	pular.Visible = false
	Interface.canto(pular, 4)
	Interface.borda(pular, Color3.fromRGB(92, 78, 62), 1, 0.4)
	local barra = Instance.new("Frame")
	barra.Name = "Barra"
	barra.BackgroundColor3 = Color3.fromRGB(176, 38, 38)
	barra.BorderSizePixel = 0
	barra.AnchorPoint = Vector2.new(0, 1)
	barra.Position = UDim2.fromScale(0, 1)
	barra.Size = UDim2.new(0, 0, 0, 3)
	barra.Parent = pular
	pular.Parent = telaS
	estado.pular = pular
	estado.barraPular = barra

	local segurando = false
	local inicio = 0
	pular.MouseButton1Down:Connect(function()
		segurando = true
		inicio = os.clock()
		task.spawn(function()
			while segurando and pular.Visible do
				local k = math.clamp((os.clock() - inicio) / 0.7, 0, 1)
				barra.Size = UDim2.new(k, 0, 0, 3)
				if k >= 1 then
					segurando = false
					pular.Visible = false
					if estado.aoPular then
						estado.aoPular()
					end
					break
				end
				task.wait()
			end
			barra.Size = UDim2.new(0, 0, 0, 3)
		end)
	end)
	local function soltar()
		segurando = false
	end
	pular.MouseButton1Up:Connect(soltar)
	pular.MouseLeave:Connect(soltar)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			soltar()
		end
	end)
end

function Cinema.legendas(ligadas: boolean)
	estado.legendasLigadas = ligadas
	if not ligadas then
		Cinema.limparLegenda()
	end
end

function Cinema.faixas(mostrar: boolean, tempo: number?)
	local alvo = if mostrar then UDim2.fromScale(1, 0.1) else UDim2.fromScale(1, 0)
	local t = tempo or 0.8
	TweenService:Create(estado.cima :: Frame, TweenInfo.new(t, Enum.EasingStyle.Quad), { Size = alvo }):Play()
	TweenService:Create(estado.baixo :: Frame, TweenInfo.new(t, Enum.EasingStyle.Quad), { Size = alvo }):Play()
end

-- escurecer: 1 = tela preta, 0 = imagem
function Cinema.escurecer(alvo: number, tempo: number?)
	local preto = estado.preto :: Frame
	local t = tempo or 0.6
	if t <= 0 then
		preto.BackgroundTransparency = 1 - alvo
		return
	end
	TweenService:Create(preto, TweenInfo.new(t, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 - alvo }):Play()
end

function Cinema.legenda(codigoFala: string, duracao: number)
	if not estado.legendasLigadas then
		return
	end
	local fala = Dialogos.FALAS[codigoFala]
	if not fala then
		return
	end
	local quem = Dialogos.FALANTES[fala.quem]
	local texto = if fala.censura then Dialogos.CENSURA else fala.texto
	local cor = quem and quem.cor or Color3.new(1, 1, 1)
	local hex = string.format("#%02X%02X%02X", math.floor(cor.R * 255), math.floor(cor.G * 255), math.floor(cor.B * 255))
	local leg = estado.legenda :: TextLabel
	local caixa = estado.caixaLegenda :: Frame
	leg.Text = string.format('<font color="%s"><b>%s:</b></font> %s', hex, quem and quem.nome or "", texto)
	estado.tokenLegenda += 1
	local token = estado.tokenLegenda
	TweenService:Create(leg, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
	TweenService:Create(caixa, TweenInfo.new(0.15), { BackgroundTransparency = 0.45 }):Play()
	task.delay(duracao, function()
		if estado.tokenLegenda == token then
			Cinema.limparLegenda()
		end
	end)
end

function Cinema.limparLegenda()
	estado.tokenLegenda += 1
	local leg = estado.legenda
	local caixa = estado.caixaLegenda
	if leg and caixa then
		TweenService:Create(leg, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
		TweenService:Create(caixa, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	end
end

function Cinema.titulo(texto: string, mostrar: boolean, tempo: number?)
	local t = estado.titulo :: TextLabel
	t.Text = texto
	local tt = tempo or 1.2
	local st = t:FindFirstChildOfClass("UIStroke")
	TweenService:Create(t, TweenInfo.new(tt, Enum.EasingStyle.Sine), { TextTransparency = if mostrar then 0.05 else 1 }):Play()
	if st then
		TweenService:Create(st, TweenInfo.new(tt), { Transparency = if mostrar then 0.3 else 1 }):Play()
	end
end

-- Texto que pisca rapidamente (ex.: o nome do jogo quando o Keko fala)
function Cinema.piscarTexto(texto: string)
	local f = estado.flash :: TextLabel
	f.Text = texto
	task.spawn(function()
		for _, tr in { 0.2, 1, 0.35, 1, 0.1 } do
			f.TextTransparency = tr
			task.wait(0.06)
		end
		task.wait(0.45)
		TweenService:Create(f, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	end)
end

-- Texto pequeno abaixo do título (ex.: "fim da introdução")
function Cinema.rodape(texto: string, mostrar: boolean)
	local tela = estado.tela :: ScreenGui
	local r = tela:FindFirstChild("Rodape") :: TextLabel?
	if not r then
		local novo = Instance.new("TextLabel")
		novo.Name = "Rodape"
		novo.BackgroundTransparency = 1
		novo.AnchorPoint = Vector2.new(0.5, 0)
		novo.Position = UDim2.fromScale(0.5, 0.66)
		novo.Size = UDim2.fromScale(0.6, 0.06)
		novo.TextScaled = true
		novo.FontFace = Interface.FONTE.maquina
		novo.TextColor3 = Color3.fromRGB(190, 182, 170)
		novo.TextTransparency = 1
		novo.ZIndex = 12
		novo.Parent = tela
		r = novo
	end
	local rr = r :: TextLabel
	rr.Text = texto
	TweenService:Create(rr, TweenInfo.new(1), { TextTransparency = if mostrar then 0.15 else 1 }):Play()
end

function Cinema.botaoPular(mostrar: boolean, aoPular: (() -> ())?)
	local p = estado.pular :: TextButton
	p.Visible = mostrar
	estado.aoPular = aoPular
end

function Cinema.limparTudo()
	Cinema.limparLegenda()
	Cinema.titulo("", false, 0.3)
	Cinema.botaoPular(false, nil)
	Cinema.faixas(false, 0.5)
end

return Cinema
