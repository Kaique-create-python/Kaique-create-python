-- BIZARRE BATTLEGROUNDS :: peças de interface reaproveitadas (botões, cantos, textos com contorno)

local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local UI = {}

UI.FONTE = Enum.Font.Bangers
UI.FONTE_TEXTO = Enum.Font.GothamBold
UI.CORES = {
	fundo = Color3.fromRGB(16, 12, 28),
	fundo2 = Color3.fromRGB(34, 24, 58),
	roxo = Color3.fromRGB(150, 70, 230),
	dourado = Color3.fromRGB(255, 206, 64),
	rosa = Color3.fromRGB(255, 90, 170),
	branco = Color3.fromRGB(255, 255, 255),
	vermelho = Color3.fromRGB(230, 50, 60),
	verde = Color3.fromRGB(70, 220, 120),
	azul = Color3.fromRGB(90, 170, 255),
}

function UI.canto(pai: Instance, raio: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, raio or 10)
	c.Parent = pai
	return c
end

function UI.circulo(pai: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = pai
	return c
end

function UI.borda(pai: Instance, cor: Color3?, espessura: number?, transp: number?)
	local s = Instance.new("UIStroke")
	s.Color = cor or Color3.fromRGB(0, 0, 0)
	s.Thickness = espessura or 2
	s.Transparency = transp or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = pai
	return s
end

function UI.gradiente(pai: Instance, a: Color3, b: Color3, rot: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rot or 90
	g.Parent = pai
	return g
end

function UI.frame(pai: Instance, tam: UDim2, pos: UDim2, cor: Color3?, transp: number?): Frame
	local f = Instance.new("Frame")
	f.Size = tam
	f.Position = pos
	f.BackgroundColor3 = cor or UI.CORES.fundo
	f.BackgroundTransparency = transp or 0
	f.BorderSizePixel = 0
	f.Parent = pai
	return f
end

function UI.texto(pai: Instance, texto: string, tam: UDim2, pos: UDim2, opcoes: any?): TextLabel
	local o = opcoes or {}
	local t = Instance.new("TextLabel")
	t.Size = tam
	t.Position = pos
	t.BackgroundTransparency = 1
	t.Text = texto
	t.Font = o.fonte or UI.FONTE
	t.TextColor3 = o.cor or UI.CORES.branco
	t.TextScaled = o.escalado ~= false
	t.TextSize = o.tamanho or 18
	t.TextXAlignment = o.alinhar or Enum.TextXAlignment.Center
	t.TextYAlignment = o.alinharY or Enum.TextYAlignment.Center
	t.TextWrapped = o.quebrar == true
	t.RichText = o.rico == true
	t.ZIndex = o.z or 1
	if o.face then
		t.FontFace = o.face
	end
	if o.contorno ~= false then
		local s = Instance.new("UIStroke")
		s.Thickness = o.contornoEsp or 1.6
		s.Color = o.contornoCor or Color3.fromRGB(10, 6, 20)
		s.Parent = t
	end
	if o.limite then
		local lim = Instance.new("UITextSizeConstraint")
		lim.MaxTextSize = o.limite
		lim.Parent = t
	end
	t.Parent = pai
	return t
end

-- botão com pulinho ao tocar
function UI.botao(pai: Instance, texto: string, tam: UDim2, pos: UDim2, cor: Color3?, opcoes: any?): TextButton
	local o = opcoes or {}
	local b = Instance.new("TextButton")
	b.Size = tam
	b.Position = pos
	b.AnchorPoint = o.ancora or Vector2.new(0, 0)
	b.BackgroundColor3 = cor or UI.CORES.roxo
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Text = ""
	b.ZIndex = o.z or 2
	b.Parent = pai
	if o.redondo then
		UI.circulo(b)
	else
		UI.canto(b, o.raio or 12)
	end
	UI.borda(b, o.borda or Color3.fromRGB(10, 6, 20), o.bordaEsp or 2.5)
	UI.gradiente(b, Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190), 90)
	local t = UI.texto(b, texto, UDim2.fromScale(0.86, 0.7), UDim2.fromScale(0.07, 0.15), { cor = o.corTexto, z = (o.z or 2) + 1, limite = o.limite or 34 })
	t.Name = "Rotulo"
	local escala = Instance.new("UIScale")
	escala.Parent = b
	b.MouseButton1Down:Connect(function()
		TweenService:Create(escala, TweenInfo.new(0.06), { Scale = 0.9 }):Play()
	end)
	local function soltar()
		TweenService:Create(escala, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	b.MouseButton1Up:Connect(soltar)
	b.MouseLeave:Connect(soltar)
	return b
end

function UI.escalaTela(gui: ScreenGui, larguraBase: number, alturaBase: number, minimo: number?, maximo: number?): UIScale
	local esc = Instance.new("UIScale")
	esc.Parent = gui
	local function atualizar()
		local tam = gui.AbsoluteSize
		if tam.X < 10 then
			return
		end
		esc.Scale = math.clamp(math.min(tam.X / larguraBase, tam.Y / alturaBase), minimo or 0.55, maximo or 1.3)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(atualizar)
	atualizar()
	return esc
end

-- AJUSTE-8: artes do Canva (logo, fundo do menu e tela de carregamento). O instalador envia as
-- imagens e grava os números em ReplicatedStorage.BB_Imagens ("logo fundo carregando"; 0 = sem).
-- Enquanto o Roblox não liberar (moderação) a imagem não aparece e a interface de texto fica.
UI.IMAGENS = { logo = 1, fundo = 2, carregando = 3 }

function UI.imagem(nome: string): string?
	local v = game:GetService("ReplicatedStorage"):FindFirstChild("BB_Imagens")
	local n = UI.IMAGENS[nome]
	if not v or not v:IsA("StringValue") or not n then
		return nil
	end
	local i = 0
	for id in string.gmatch(v.Value, "%d+") do
		i += 1
		if i == n then
			return if id ~= "0" then "rbxassetid://" .. id else nil
		end
	end
	return nil
end

-- imagem que só aparece quando carregou de verdade (se falhar, some sem deixar buraco)
function UI.imagemOpcional(pai: Instance, nome: string, props: { [string]: any }, aoCarregar: any?): ImageLabel?
	local id = UI.imagem(nome)
	if not id then
		return nil
	end
	local img = Instance.new("ImageLabel")
	img.Name = "Arte_" .. nome
	img.BackgroundTransparency = 1
	local alvo: any = img
	local transpFinal = 0
	for k, v in props do
		if k == "ImageTransparency" then
			transpFinal = v
		else
			alvo[k] = v
		end
	end
	img.Image = id
	img.ImageTransparency = 1
	img.Parent = pai
	task.spawn(function()
		local ok = false
		pcall(function()
			ContentProvider:PreloadAsync({ img }, function(_, status)
				ok = status == Enum.AssetFetchStatus.Success
			end)
		end)
		if not img.Parent then
			return
		end
		if ok or img.IsLoaded then
			TweenService:Create(img, TweenInfo.new(0.6), { ImageTransparency = transpFinal }):Play()
			if aoCarregar then
				aoCarregar(img)
			end
		else
			img:Destroy()
		end
	end)
	return img
end

------------------------------------------------------------------------------ AJUSTE-19: HUD
-- Um estilo só no HUD (gênero battlegrounds, identidade própria): vidro escuro, bordas inclinadas,
-- texto branco condensado e a cor da aura do Stand como único destaque. Duas fontes no jogo:
-- Bangers (momentos grandes: Stand, combo, avisos de luta) e Roboto Condensed (rótulos e números).
-- Tudo com peças nativas (sem imagem para enviar nem esperar moderação).
UI.FACE = {
	-- família tirada do próprio Enum (mesmo arquivo que o Roblox usa), peso Bold nos rótulos
	rotulo = Font.new(Font.fromEnum(Enum.Font.RobotoCondensed).Family, Enum.FontWeight.Bold),
	destaque = Font.fromEnum(Enum.Font.Bangers),
}
UI.HUD = {
	vidro = Color3.fromRGB(12, 10, 20),
	vidroT = 0.3,
	escuro = Color3.fromRGB(6, 5, 10),
	texto = Color3.fromRGB(246, 244, 250),
	apagado = Color3.fromRGB(178, 172, 194),
	contorno = Color3.fromRGB(8, 6, 14),
	vida = Color3.fromRGB(236, 52, 82),
	vidaClara = Color3.fromRGB(255, 122, 132),
	rastro = Color3.fromRGB(255, 196, 186),
	despertar = Color3.fromRGB(255, 206, 64),
	esquiva = Color3.fromRGB(92, 214, 255),
	guarda = Color3.fromRGB(116, 174, 255),
	inclinacao = 0.27, -- deslocamento horizontal / altura das bordas inclinadas (~15 graus)
}

-- Paralelogramo que ocupa o pai inteiro: um Frame que recorta (ClipsDescendants) e, dentro, um
-- retângulo girado cujas bordas laterais ficam inclinadas. Mesma técnica testada no Studio para
-- cantos cortados (recorte de filhos girados é padrão desde 2026-09). ajustar(w, h) refaz para o
-- tamanho atual do pai em px de design (o UIScale da tela vale por igual).
function UI.paralelo(pai: Instance, cor: Color3, transp: number?, inclinacao: number?, z: number?)
	local k = inclinacao or UI.HUD.inclinacao
	local ang = math.atan(k)
	local clip = Instance.new("Frame")
	clip.Name = "Paralelo"
	clip.Size = UDim2.fromScale(1, 1)
	clip.BackgroundTransparency = 1
	clip.BorderSizePixel = 0
	clip.ClipsDescendants = true
	clip.ZIndex = z or 1
	local corpo = Instance.new("Frame")
	corpo.Name = "Corpo"
	corpo.AnchorPoint = Vector2.new(0.5, 0.5)
	corpo.BackgroundColor3 = cor
	corpo.BackgroundTransparency = transp or 0
	corpo.BorderSizePixel = 0
	corpo.Rotation = math.deg(ang)
	corpo.ZIndex = z or 1
	corpo.Parent = clip
	clip.Parent = pai
	local obj = { quadro = clip, corpo = corpo, angulo = math.deg(ang), k = k }
	-- em Scale do recorte: Offset no Roblox é inteiro e cortaria meio pixel das bordas
	function obj.ajustar(w: number, h: number)
		if w <= 0 or h <= 0 then
			corpo.Visible = false
			return
		end
		local s = h * k
		local a = math.max(0, (w / 2 - s / 2) * math.cos(ang))
		corpo.Size = UDim2.fromScale(2 * a / w, 2 * (w + h) / h)
		corpo.Position = UDim2.fromScale(0.5, 0.5)
		corpo.Visible = w > s + 0.5
	end
	-- degradê que continua na vertical da tela mesmo com o corpo girado
	function obj.degrade(topo: Color3, base: Color3, transpTopo: number?, transpBase: number?)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(topo, base)
		g.Transparency = NumberSequence.new(transpTopo or 0, transpBase or 0)
		g.Rotation = 90 - obj.angulo
		g.Parent = corpo
		return g
	end
	return obj
end

-- Barra inclinada com tamanho fixo (fundo + preenchimento que muda de largura pela fração).
function UI.barraInclinada(pai: Instance, tam: Vector2, pos: UDim2, cor: Color3?, fundo: Color3?, fundoT: number?, z: number?)
	local raiz = UI.frame(pai, UDim2.fromOffset(tam.X, tam.Y), pos, Color3.new(), 1)
	raiz.ZIndex = z or 1
	local trilho = UI.paralelo(raiz, fundo or UI.HUD.escuro, fundoT or 0.45, nil, z)
	trilho.ajustar(tam.X, tam.Y)
	local camadas = {}
	local obj = { raiz = raiz, trilho = trilho, camadas = camadas }
	-- cada camada (rastro, preenchimento) é um quadro alinhado à esquerda com o próprio paralelogramo
	function obj.camada(nome: string, c: Color3, transp: number?)
		local q = UI.frame(raiz, UDim2.fromOffset(tam.X, tam.Y), UDim2.new(), Color3.new(), 1)
		q.Name = nome
		q.ZIndex = (z or 1) + #camadas + 1
		local p = UI.paralelo(q, c, transp, nil, q.ZIndex)
		p.ajustar(tam.X, tam.Y)
		local camada = { quadro = q, forma = p, frac = 1 }
		function camada.fracao(f: number)
			f = math.clamp(f, 0, 1)
			if math.abs(f - camada.frac) < 1e-4 then
				return
			end
			camada.frac = f
			-- a borda direita inclinada acompanha a fração; abaixo do mínimo some
			local s = tam.Y * p.k
			local w = math.floor(s + (tam.X - s) * f + 0.5)
			q.Size = UDim2.fromOffset(w, tam.Y)
			p.ajustar(w, tam.Y)
			q.Visible = f > 0.002
		end
		table.insert(camadas, camada)
		return camada
	end
	if cor then
		obj.preenche = obj.camada("Preenche", cor, 0)
	end
	return obj
end

-- Escala do HUD: 1 no celular (px de celular já são do tamanho certo), cresce até 1,35 em telas altas.
function UI.escalaHUD(gui: ScreenGui): UIScale
	local esc = Instance.new("UIScale")
	esc.Parent = gui
	local function atualizar()
		local tam = gui.AbsoluteSize
		if tam.Y < 10 then
			return
		end
		esc.Scale = math.clamp(tam.Y / 300, 1, 1.35)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(atualizar)
	atualizar()
	return esc
end

-- Rótulo do HUD: Roboto Condensed, branco, contorno fino escuro (lê em cima do mundo claro ou escuro).
function UI.rotulo(pai: Instance, texto: string, tam: UDim2, pos: UDim2, opcoes: any?): TextLabel
	local o = opcoes or {}
	o.face = o.face or UI.FACE.rotulo
	o.cor = o.cor or UI.HUD.texto
	o.contornoEsp = o.contornoEsp or 1
	o.contornoCor = o.contornoCor or UI.HUD.contorno
	return UI.texto(pai, texto, tam, pos, o)
end

-- Botão redondo de vidro (celular): aro claro fino, rótulo condensado, afunda ao tocar.
function UI.botaoRedondo(pai: Instance, texto: string, opcoes: any?): TextButton
	local o = opcoes or {}
	local b = Instance.new("TextButton")
	b.Name = o.nome or texto
	b.Size = UDim2.fromOffset(60, 60)
	b.BackgroundColor3 = o.cor or UI.HUD.vidro
	b.BackgroundTransparency = o.transp or UI.HUD.vidroT
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Text = ""
	b.ZIndex = o.z or 2
	if o.quadrado then
		UI.canto(b, o.raio or 10)
	else
		UI.circulo(b)
	end
	local aro = UI.borda(b, o.aro or Color3.fromRGB(255, 255, 255), o.aroEsp or 1.5, o.aroT or 0.55)
	aro.Name = "Aro"
	local g = Instance.new("UIGradient")
	g.Name = "Brilho"
	g.Rotation = 90
	g.Transparency = NumberSequence.new(0, 0.25)
	g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 186, 200))
	g.Parent = b
	local t = if o.quebrar
		then UI.rotulo(b, texto, UDim2.fromScale(0.9, 0.7), UDim2.fromScale(0.05, 0.15), { z = (o.z or 2) + 2, limite = o.limite or 14, quebrar = true })
		else UI.rotulo(b, texto, UDim2.fromScale(0.86, 0.5), UDim2.fromScale(0.07, 0.25), { z = (o.z or 2) + 2, limite = o.limite or 14 })
	t.Name = "Rotulo"
	local escala = Instance.new("UIScale")
	escala.Parent = b
	b.MouseButton1Down:Connect(function()
		TweenService:Create(escala, TweenInfo.new(0.05), { Scale = 0.9 }):Play()
	end)
	local function soltar()
		TweenService:Create(escala, TweenInfo.new(0.14, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	b.MouseButton1Up:Connect(soltar)
	b.MouseLeave:Connect(soltar)
	b.Parent = pai
	return b
end

-- Cartão de golpe (barra de golpes do PC e botões 1-4 do celular): paralelogramo de vidro, número
-- na cor do Stand, nome em até 2 linhas, recarga com número grande e faixa de progresso embaixo.
function UI.cartaoGolpe(pai: Instance, numero: string, opcoes: any?)
	local o = opcoes or {}
	local raiz: GuiObject
	if o.botao then
		local b = Instance.new("TextButton")
		b.Text = ""
		b.AutoButtonColor = false
		raiz = b
	else
		raiz = Instance.new("Frame")
	end
	raiz.Name = o.nome or ("Golpe" .. numero)
	raiz.BackgroundTransparency = 1
	raiz.BorderSizePixel = 0
	raiz.Size = o.tam or UDim2.fromOffset(76, 46)
	raiz.ZIndex = 2
	raiz.Parent = pai
	local fundo = UI.paralelo(raiz, UI.HUD.vidro, 0, nil, 2)
	local brilho = fundo.degrade(Color3.fromRGB(70, 66, 92), Color3.fromRGB(18, 16, 28), 0.18, 0.32)
	local faixaQ = UI.frame(raiz, UDim2.fromOffset(10, 3), UDim2.new(0, 0, 1, -3), Color3.new(), 1)
	faixaQ.Name = "Faixa"
	faixaQ.ZIndex = 4
	local faixa = UI.paralelo(faixaQ, o.cor or UI.HUD.despertar, 0, nil, 4)
	-- número numa aba que sai pela borda de cima (não briga com o nome do golpe)
	local selo = UI.frame(raiz, UDim2.fromOffset(18, 14), UDim2.fromOffset(0, -7), Color3.new(), 1)
	selo.Name = "Selo"
	selo.ZIndex = 5
	local seloFundo = UI.paralelo(selo, o.cor or UI.HUD.despertar, 0, nil, 5)
	seloFundo.ajustar(18, 14)
	local num = UI.rotulo(selo, numero, UDim2.fromScale(0.8, 1), UDim2.fromScale(0.12, 0), { z = 6, cor = UI.HUD.contorno, contorno = false, limite = 12 })
	num.Name = "Numero"
	local nome = UI.rotulo(raiz, "", UDim2.new(1, -20, 1, -14), UDim2.fromOffset(12, 7), { z = 6, quebrar = true, limite = 13 })
	nome.Name = "Nome"
	local tempo = UI.rotulo(raiz, "", UDim2.new(1, -16, 1, -10), UDim2.fromOffset(8, 4), { z = 7, limite = 24, contornoEsp = 1.6 })
	tempo.Name = "Tempo"
	tempo.Visible = false
	local obj = { raiz = raiz, fundo = fundo, brilho = brilho, faixa = faixa, faixaQ = faixaQ, selo = selo, seloFundo = seloFundo, numero = num, nome = nome, tempo = tempo, frac = 1 }
	function obj.ajustar()
		local w, h = raiz.Size.X.Offset, raiz.Size.Y.Offset
		if w < 4 or h < 4 then
			return
		end
		fundo.ajustar(w, h)
		local s = h * fundo.k
		selo.Position = UDim2.fromOffset(s - 2, -7)
		nome.Size = UDim2.fromOffset(w - s - 10, h - 14)
		nome.Position = UDim2.fromOffset(s / 2 + 5, 7)
		local util = (w - s) * obj.frac + 3 * fundo.k
		faixaQ.Size = UDim2.fromOffset(math.max(0, util), 3)
		faixa.ajustar(math.max(0, util), 3)
		faixaQ.Visible = obj.frac > 0.01
	end
	-- estado: pronto (frac 1) / recarga (frac < 1 e número grande) / bloqueado (apagado, sem número)
	function obj.estado(frac: number, textoTempo: string?, bloqueado: boolean?)
		obj.frac = math.clamp(frac, 0, 1)
		local recarga = textoTempo ~= nil and textoTempo ~= ""
		tempo.Text = textoTempo or ""
		tempo.Visible = recarga
		local apagado = recarga or bloqueado == true
		-- na recarga só o número (o selo já diz qual golpe é); bloqueado fica apagado
		nome.Visible = not recarga
		nome.TextTransparency = if apagado then 0.5 else 0
		local s = nome:FindFirstChildOfClass("UIStroke")
		if s then
			s.Transparency = if apagado then 0.75 else 0
		end
		brilho.Transparency = if apagado then NumberSequence.new(0.06, 0.12) else NumberSequence.new(0.18, 0.32)
		obj.ajustar()
	end
	function obj.cor(c: Color3)
		faixa.corpo.BackgroundColor3 = c
		seloFundo.corpo.BackgroundColor3 = c
	end
	obj.ajustar()
	return obj
end

-- zoom lento sem parar (a arte parece viva)
function UI.zoomLento(obj: GuiObject, quanto: number?, dur: number?)
	local esc = Instance.new("UIScale")
	esc.Parent = obj
	TweenService:Create(esc, TweenInfo.new(dur or 16, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1 + (quanto or 0.06) }):Play()
	return esc
end

return UI
