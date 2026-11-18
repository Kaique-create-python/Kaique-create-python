--!strict
-- PROJETO BASTIÃO :: Cenario (Etapa 1)
-- Cria em workspace.BastiaoHistoria tudo o que a abertura precisa e registra cada objeto
-- como entidade do Mundo (um estado por vez, idempotente). O mapa Sector7World e o HUD não
-- são tocados: nenhuma peça existente é movida, apagada ou recolorida. As posições foram
-- medidas no place enviado (paredes, batentes, abóbadas e móveis) e são conferidas por um
-- teste que monta este cenário dentro do place real e procura colisões com o mapa.
-- Sem efeitos desenhados: luz, neon, material e o vapor padrão do próprio Roblox.

local Cenario = {}

local V = Vector3.new
local M = Enum.Material

-- mesma paleta do MilitaryProps do mapa, para as peças novas parecerem da mesma base
local C = {
	steel = Color3.fromRGB(55, 63, 58),
	steelLight = Color3.fromRGB(78, 88, 82),
	dark = Color3.fromRGB(29, 35, 33),
	black = Color3.fromRGB(19, 24, 23),
	green = Color3.fromRGB(67, 78, 52),
	khaki = Color3.fromRGB(104, 105, 73),
	aluminum = Color3.fromRGB(121, 131, 128),
	wood = Color3.fromRGB(96, 79, 53),
	woodDark = Color3.fromRGB(70, 56, 37),
	paper = Color3.fromRGB(164, 158, 130),
	white = Color3.fromRGB(166, 174, 157),
	red = Color3.fromRGB(115, 49, 36),
	hazard = Color3.fromRGB(168, 134, 40),
	copper = Color3.fromRGB(150, 98, 60),
	screen = Color3.fromRGB(9, 13, 11),
	ledOff = Color3.fromRGB(46, 34, 30),
}
local LUZ = {
	vermelha = Color3.fromRGB(255, 52, 36),
	ambar = Color3.fromRGB(255, 166, 54),
	verde = Color3.fromRGB(96, 255, 128),
}
local TXT = {
	ambar = Color3.fromRGB(244, 186, 88),
	verde = Color3.fromRGB(150, 236, 160),
	vermelho = Color3.fromRGB(255, 96, 76),
	tinta = Color3.fromRGB(28, 30, 32),
	apagado = Color3.fromRGB(70, 74, 66),
}
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

-- ===== posições medidas no place (chão em y = 0) =====
Cenario.POS = {
	pavelTunel = V(3.4, 0, 2.2),
	caixa = CFrame.new(6.0, 0, 1.6), -- encostada na parede leste do túnel (face x = 7.0)
	relogio = CFrame.lookAt(V(-7.0, 0, 1.5), V(-6.0, 0, 1.5)), -- parede oeste do túnel
	painelEntrada = CFrame.lookAt(V(2.6, 0, 23.98), V(2.6, 0, 22.98)), -- na antepara, entre os reforços
	carregador = CFrame.lookAt(V(-88, 0, -198.15), V(-88, 0, -199.15)), -- parede norte do arsenal
	terminalEnfermaria = CFrame.lookAt(V(-65.0, 0, -306), V(-64.0, 0, -306)), -- corredor oeste
	portaContencaoX = -65.36, -- plano do vão da enfermaria (batentes em z -313.75 e -326.25)
	placaContencao = CFrame.lookAt(V(-65.0, 0, -329.2), V(-64.0, 0, -329.2)),
	portaOficinaX = 65.36, -- plano do vão da oficina
	travaOficina = CFrame.lookAt(V(65.8, 0, -305.0), V(66.8, 0, -305.0)), -- lado de dentro, ao norte da folha recolhida
	caixaTravaExterna = CFrame.lookAt(V(65.0, 0, -311.2), V(64.0, 0, -311.2)), -- lado do corredor
	terminalOficina = CFrame.lookAt(V(88, 0, -298.15), V(88, 0, -299.15)), -- parede norte da oficina
	-- giroflex na rota da isolação (face interna das paredes, entre as juntas que se repetem a cada 22 studs)
	giroflex = {
		CFrame.lookAt(V(-7.0, 0, -5), V(-6.0, 0, -5)),
		CFrame.lookAt(V(7.0, 0, -70), V(6.0, 0, -70)),
		CFrame.lookAt(V(-51.0, 0, -290), V(-52.0, 0, -290)),
		CFrame.lookAt(V(-22, 0, -253.0), V(-22, 0, -254.0)),
		CFrame.lookAt(V(30, 0, -253.0), V(30, 0, -254.0)),
		CFrame.lookAt(V(51.0, 0, -290), V(52.0, 0, -290)),
		CFrame.lookAt(V(51.0, 0, -334), V(52.0, 0, -334)),
	},
}

-- caixas usadas por zonas e regras
Cenario.OFICINA_DENTRO = { min = V(65.9, -4, -342), max = V(112, 16, -298) }
Cenario.SPAWN_OFICINA = CFrame.lookAt(V(76, 3.2, -318), V(88, 3.2, -300))

export type Servicos = {
	tween: (inst: Instance, tempo: number, alvo: { [string]: any }) -> (),
	atrasar: (segundos: number, fn: () -> ()) -> (),
	marcar: (inst: Instance, tag: string) -> (),
	agora: () -> number,
	ruido: ((chave: string, pos: Vector3?) -> ())?, -- som mecânico sem legenda (porta, alavanca, bipe)
}

-- definidos no começo de Cenario.construir (as peças usam ao serem montadas)
local TEXTO_MUNDO: any = {}
local SV: any = nil

-- ===== construção =====
local function bloco(pai: Instance, nome: string, tamanho: Vector3, cf: CFrame, cor: Color3, material: Enum.Material?, solida: boolean?): Part
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.Size = tamanho
	p.CFrame = cf
	p.Color = cor
	p.Material = material or M.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = solida == true
	p.CanQuery = solida == true
	p.CanTouch = false
	p.CastShadow = solida == true
	p.Parent = pai
	return p
end

-- cilindro com o eixo no X local do cf
local function cilindro(pai: Instance, nome: string, comprimento: number, diametro: number, cf: CFrame, cor: Color3, material: Enum.Material?): Part
	local p = bloco(pai, nome, V(comprimento, diametro, diametro), cf, cor, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function modelo(pai: Instance, nome: string): Model
	local m = Instance.new("Model")
	m.Name = nome
	m.Parent = pai
	return m
end

local function luzPontual(pai: BasePart, cor: Color3, alcance: number, brilho: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = cor
	l.Range = alcance
	l.Brightness = brilho
	l.Shadows = false
	l.Parent = pai
	return l
end

local function lampada(pai: Instance, nome: string, tamanho: Vector3, cf: CFrame, alcance: number): (Part, PointLight)
	local p = bloco(pai, nome, tamanho, cf, C.ledOff, M.SmoothPlastic)
	local l = luzPontual(p, LUZ.vermelha, alcance, 0)
	l.Enabled = false
	return p, l
end

local function acender(p: BasePart, l: PointLight?, cor: Color3?, brilho: number?)
	if cor then
		p.Color = cor
		p.Material = M.Neon
	else
		p.Color = C.ledOff
		p.Material = M.SmoothPlastic
	end
	if l then
		l.Enabled = cor ~= nil
		if cor then
			l.Color = cor
			l.Brightness = brilho or 1.2
		end
	end
end

-- texto numa face: telas e visores brilham sozinhos; papel e pintura recebem a luz do lugar
local function tela(parte: BasePart, face: Enum.NormalId, pps: number, tamanhoTexto: number, corFundo: Color3?, impresso: boolean?): TextLabel
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Tela"
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = pps
	sg.LightInfluence = if impresso then 1 else 0
	sg.ClipsDescendants = true
	if not impresso then
		pcall(function()
			(sg :: any).Brightness = 1.6
		end)
	end
	sg.Parent = parte
	local fundo = Instance.new("Frame")
	fundo.Name = "Fundo"
	fundo.Size = UDim2.fromScale(1, 1)
	fundo.BorderSizePixel = 0
	fundo.BackgroundColor3 = corFundo or C.screen
	fundo.BackgroundTransparency = if corFundo then 0 else 0.02
	fundo.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, math.floor(tamanhoTexto * 0.8))
	pad.PaddingRight = UDim.new(0, math.floor(tamanhoTexto * 0.6))
	pad.PaddingTop = UDim.new(0, math.floor(tamanhoTexto * 0.7))
	pad.Parent = fundo
	local t = Instance.new("TextLabel")
	t.Name = "Texto"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = MONO
	t.TextSize = tamanhoTexto
	t.TextColor3 = TXT.ambar
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.TextWrapped = true
	t.LineHeight = 1.05
	t.Text = ""
	t.Parent = fundo
	return t
end

-- tela de terminal: o servidor só diz qual tela e qual estado; cada cliente desenha na própria
-- língua (SurfaceGui local com Adornee nesta peça). Nada de texto fixo no servidor.
local function telaLocalizada(parte: BasePart, id: string, pps: number, tamanhoTexto: number): any
	parte:SetAttribute("BastiaoTela", id)
	parte:SetAttribute("BastiaoTelaPPS", pps)
	parte:SetAttribute("BastiaoTelaTamanho", tamanhoTexto)
	parte:SetAttribute("BastiaoTelaEstado", "")
	parte:SetAttribute("BastiaoTelaNomes", "")
	SV.marcar(parte, "BastiaoTela")
	return {
		parte = parte,
		mostrar = function(estado: string, nomes: { string }?)
			parte:SetAttribute("BastiaoTelaNomes", if nomes then table.concat(nomes, "\n") else "")
			parte:SetAttribute("BastiaoTelaEstado", estado)
		end,
	}
end

local function prompt(pai: BasePart, nome: string, texto: string, segurar: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = nome
	p.ActionText = texto
	p.ObjectText = ""
	p.Style = Enum.ProximityPromptStyle.Custom
	p.MaxActivationDistance = 7
	p.HoldDuration = segurar
	p.RequiresLineOfSight = false
	p.Enabled = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p:SetAttribute("Bastiao", true)
	p.Parent = pai
	return p
end

-- guarda a posição de cada peça relativa a uma peça base para mover o conjunto inteiro
local function offsets(base: BasePart, m: Instance): { [BasePart]: CFrame }
	local r = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			r[d] = base.CFrame:ToObjectSpace(d.CFrame)
		end
	end
	return r
end

local function moverConjunto(ofs: { [BasePart]: CFrame }, cf: CFrame)
	for p, o in ofs do
		p.CFrame = cf * o
	end
end

-- ===== peças =====

-- caixa de madeira com cantoneiras (canto do Pavel)
local function construirCaixa(pasta: Instance, textos: any): (Model, Part)
	local pose = Cenario.POS.caixa
	local m = modelo(pasta, "CantoPavel")
	local L, A, P = 1.7, 1.8, 2.6 -- x, y, z
	local corpo = bloco(m, "Caixa", V(L - 0.08, A - 0.06, P - 0.08), pose * CFrame.new(0, (A - 0.06) / 2, 0), C.wood, M.WoodPlanks, true)
	-- tampa e cantoneiras escuras
	bloco(m, "Tampa", V(L, 0.08, P), pose * CFrame.new(0, A - 0.04, 0), C.woodDark, M.Wood, true)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			bloco(m, "Cantoneira", V(0.1, A - 0.1, 0.1), pose * CFrame.new(sx * (L / 2 - 0.03), A / 2 - 0.04, sz * (P / 2 - 0.03)), C.woodDark, M.Wood)
		end
	end
	for _, y in { 0.28, A - 0.34 } do
		bloco(m, "Cinta", V(L + 0.02, 0.12, 0.04), pose * CFrame.new(0, y, -P / 2 - 0.01), C.woodDark, M.Wood)
		bloco(m, "Cinta", V(L + 0.02, 0.12, 0.04), pose * CFrame.new(0, y, P / 2 + 0.01), C.woodDark, M.Wood)
		bloco(m, "Cinta", V(0.04, 0.12, P + 0.02), pose * CFrame.new(-L / 2 - 0.01, y, 0), C.woodDark, M.Wood)
	end
	local topo = A
	-- caixa de ferramentas fechada (lado sul do tampo)
	local ferr = pose * CFrame.new(-0.1, topo + 0.28, -0.6)
	bloco(m, "CaixaFerramentas", V(0.7, 0.5, 1.3), ferr, C.red, M.Metal, true)
	bloco(m, "TampaFerramentas", V(0.72, 0.06, 1.32), ferr * CFrame.new(0, 0.28, 0), Color3.fromRGB(96, 40, 30), M.Metal)
	bloco(m, "AlcaFerramentas", V(0.06, 0.06, 0.7), ferr * CFrame.new(0, 0.42, 0), C.aluminum, M.Metal)
	for _, s in { -1, 1 } do
		bloco(m, "PeAlca", V(0.06, 0.14, 0.06), ferr * CFrame.new(0, 0.36, s * 0.32), C.aluminum, M.Metal)
		bloco(m, "Fecho", V(0.04, 0.1, 0.12), ferr * CFrame.new(-0.37, 0.2, s * 0.4), C.aluminum, M.Metal)
	end
	-- caneca esmaltada
	local caneca = pose * CFrame.new(0.55, topo + 0.2, 0.75)
	cilindro(m, "Caneca", 0.38, 0.32, caneca * CFrame.Angles(0, 0, math.pi / 2), C.white, M.SmoothPlastic)
	cilindro(m, "BordaCaneca", 0.03, 0.33, caneca * CFrame.new(0, 0.18, 0) * CFrame.Angles(0, 0, math.pi / 2), C.dark, M.SmoothPlastic)
	bloco(m, "AsaCaneca", V(0.06, 0.2, 0.05), caneca * CFrame.new(0.2, 0, 0), C.white, M.SmoothPlastic)
	-- prancheta com a lista de turno, apoiada na caixa de ferramentas e virada para quem
	-- chega pelo túnel (+z): a pista aparece antes da explicação
	local prancheta = pose * CFrame.new(-0.1, topo + 0.47, 0.24) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(20), 0, 0)
	bloco(m, "Prancheta", V(0.86, 1.08, 0.04), prancheta, Color3.fromRGB(84, 62, 40), M.Wood)
	local folha = bloco(m, "ListaTurno", V(0.74, 0.92, 0.012), prancheta * CFrame.new(0, -0.04, -0.026), C.paper, M.SmoothPlastic)
	bloco(m, "Presilha", V(0.42, 0.1, 0.05), prancheta * CFrame.new(0, 0.5, -0.045), C.aluminum, M.Metal)
	local lista = tela(folha, Enum.NormalId.Front, 260, 15, C.paper, true)
	lista.TextColor3 = TXT.tinta
	lista.Text = TEXTO_MUNDO.lista_turno
	return m, corpo
end

-- rádio portátil em pé sobre a caixa
local function construirRadio(pasta: Instance): (Model, Part, Part, PointLight)
	local pose = Cenario.POS.caixa * CFrame.new(0.55, 1.8, -0.3)
	local m = modelo(pasta, "Radio")
	local corpo = bloco(m, "Radio", V(0.42, 0.95, 0.3), pose * CFrame.new(0, 0.475, 0), C.dark, M.Plastic, true)
	bloco(m, "Grade", V(0.32, 0.36, 0.02), pose * CFrame.new(0, 0.62, -0.16), C.black, M.DiamondPlate)
	bloco(m, "Botao", V(0.08, 0.08, 0.06), pose * CFrame.new(0.12, 0.25, -0.17), C.aluminum, M.Metal)
	cilindro(m, "Antena", 0.55, 0.06, pose * CFrame.new(-0.12, 1.22, 0) * CFrame.Angles(0, 0, math.pi / 2), C.black, M.Plastic)
	cilindro(m, "Seletor", 0.1, 0.12, pose * CFrame.new(0.1, 1.0, 0) * CFrame.Angles(0, 0, math.pi / 2), C.aluminum, M.Metal)
	local led, luzLed = lampada(m, "LedRadio", V(0.06, 0.06, 0.04), pose * CFrame.new(-0.1, 0.84, -0.16), 4)
	return m, corpo, led, luzLed
end

-- relógio digital da base (marca 02:49 e anda devagar: relógio de apresentação)
local function construirRelogio(pasta: Instance): TextLabel
	local pose = Cenario.POS.relogio
	local m = modelo(pasta, "RelogioBase")
	local caixa = bloco(m, "Relogio", V(2.2, 0.9, 0.36), pose * CFrame.new(0, 4.0, -0.18), C.dark, M.Metal, true)
	local visor = bloco(m, "Visor", V(1.9, 0.62, 0.04), pose * CFrame.new(0, 4.0, -0.38), C.black, M.Glass)
	bloco(m, "Suporte", V(0.5, 0.1, 0.3), pose * CFrame.new(0, 3.5, -0.15), C.steel, M.Metal)
	local t = tela(visor, Enum.NormalId.Front, 120, 58, C.black)
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.TextColor3 = Color3.fromRGB(255, 84, 52)
	t.Text = "02:49"
	luzPontual(visor, Color3.fromRGB(255, 70, 40), 5, 0.6)
	local _ = caixa
	return t
end

-- painel "ACESSO EXTERNO" diante dos reforços da antepara de entrada
local function construirPainelEntrada(pasta: Instance): (Part, PointLight, TextLabel)
	local pose = Cenario.POS.painelEntrada
	local m = modelo(pasta, "PainelAcessoExterno")
	bloco(m, "Painel", V(1.5, 1.1, 0.16), pose * CFrame.new(0, 6.0, -0.08), C.steel, M.Metal, true)
	local placa = bloco(m, "Placa", V(1.3, 0.5, 0.02), pose * CFrame.new(0, 6.18, -0.17), C.black, M.SmoothPlastic)
	local lamp, luz = lampada(m, "Lampada", V(0.3, 0.3, 0.1), pose * CFrame.new(0, 5.72, -0.2), 8)
	local t = tela(placa, Enum.NormalId.Front, 200, 24, C.black)
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.Text = TEXTO_MUNDO.acesso_aberto
	return lamp, luz, t
end

-- módulo de bateria lacrado (mesma forma no carregador, na mão e no terminal)
local function construirModulo(pai: Instance, nome: string, cf: CFrame): (Model, Part)
	local m = modelo(pai, nome)
	local corpo = bloco(m, "Corpo", V(0.9, 1.0, 0.6), cf, C.green, M.Metal, true)
	bloco(m, "Tampa", V(0.94, 0.12, 0.64), cf * CFrame.new(0, 0.56, 0), C.dark, M.Metal)
	bloco(m, "Faixa", V(0.92, 0.2, 0.62), cf * CFrame.new(0, -0.2, 0), C.hazard, M.SmoothPlastic)
	cilindro(m, "PoloPositivo", 0.12, 0.12, cf * CFrame.new(0.24, 0.68, 0) * CFrame.Angles(0, 0, math.pi / 2), C.copper, M.Metal)
	cilindro(m, "PoloNegativo", 0.12, 0.12, cf * CFrame.new(-0.24, 0.68, 0) * CFrame.Angles(0, 0, math.pi / 2), C.dark, M.Metal)
	bloco(m, "Alca", V(0.5, 0.06, 0.08), cf * CFrame.new(0, 0.86, 0), C.aluminum, M.Metal)
	bloco(m, "PeAlca", V(0.06, 0.24, 0.08), cf * CFrame.new(0.22, 0.74, 0), C.aluminum, M.Metal)
	bloco(m, "PeAlca", V(0.06, 0.24, 0.08), cf * CFrame.new(-0.22, 0.74, 0), C.aluminum, M.Metal)
	local etiqueta = bloco(m, "Etiqueta", V(0.6, 0.3, 0.02), cf * CFrame.new(0, 0.18, -0.31), C.paper, M.SmoothPlastic)
	local t = tela(etiqueta, Enum.NormalId.Front, 200, 15, C.paper, true)
	t.TextColor3 = TXT.tinta
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.Text = TEXTO_MUNDO.modulo
	m.PrimaryPart = corpo
	return m, corpo
end

-- carregador de módulos no arsenal
local function construirCarregador(pasta: Instance): (Model, CFrame, Part, PointLight)
	local pose = Cenario.POS.carregador
	local m = modelo(pasta, "CarregadorModulos")
	local L, A, P = 3.6, 3.0, 1.6
	bloco(m, "Gabinete", V(L, A, P), pose * CFrame.new(0, A / 2, -P / 2), C.steel, M.Metal, true)
	bloco(m, "Rodape", V(L + 0.1, 0.18, P + 0.1), pose * CFrame.new(0, 0.09, -P / 2), C.dark, M.Metal, true)
	bloco(m, "Porta", V(L - 0.4, A - 0.8, 0.04), pose * CFrame.new(0, A / 2 - 0.2, -P - 0.02), C.steelLight, M.Metal)
	bloco(m, "Puxador", V(0.06, 0.6, 0.06), pose * CFrame.new(1.25, A / 2 - 0.2, -P - 0.07), C.aluminum, M.Metal)
	bloco(m, "Berco", V(1.3, 0.14, 0.9), pose * CFrame.new(0, A + 0.07, -P / 2), C.dark, M.Metal, true)
	bloco(m, "Trilho", V(0.08, 0.3, 0.9), pose * CFrame.new(-0.55, A + 0.29, -P / 2), C.aluminum, M.Metal)
	bloco(m, "Trilho", V(0.08, 0.3, 0.9), pose * CFrame.new(0.55, A + 0.29, -P / 2), C.aluminum, M.Metal)
	-- cabo do gabinete até a parede
	bloco(m, "Cabo", V(0.12, 0.12, 0.6), pose * CFrame.new(-1.5, A - 0.4, -0.3), C.black, M.Plastic)
	local placa = bloco(m, "Placa", V(1.6, 0.36, 0.02), pose * CFrame.new(-0.6, A - 0.3, -P - 0.03), C.black, M.SmoothPlastic)
	local t = tela(placa, Enum.NormalId.Front, 200, 17, C.black, true)
	t.TextColor3 = TXT.ambar
	t.Text = TEXTO_MUNDO.carregador
	local lamp, luz = lampada(m, "Status", V(0.22, 0.22, 0.06), pose * CFrame.new(0.95, A - 0.3, -P - 0.04), 6)
	local berco = pose * CFrame.new(0, A + 0.14 + 0.5, -P / 2)
	return m, berco, lamp, luz
end

-- terminal externo da enfermaria, com encaixe para o módulo
local function construirTerminalEnfermaria(pasta: Instance): (any, Part, CFrame, Part, PointLight)
	local pose = Cenario.POS.terminalEnfermaria
	local m = modelo(pasta, "TerminalEnfermaria")
	local L, A, P = 2.4, 2.7, 0.6
	local cy = 2.15 + A / 2
	bloco(m, "Gabinete", V(L, A, P), pose * CFrame.new(0, cy, -P / 2), C.steel, M.Metal, true)
	bloco(m, "Moldura", V(2.0, 1.4, 0.08), pose * CFrame.new(0, cy + 0.5, -P - 0.04), C.black, M.Metal)
	local visor = bloco(m, "Visor", V(1.8, 1.2, 0.02), pose * CFrame.new(0, cy + 0.5, -P - 0.09), C.screen, M.Glass)
	local encaixe = bloco(m, "Encaixe", V(1.1, 0.8, 0.1), pose * CFrame.new(0, cy - 0.75, -P - 0.05), C.black, M.Metal, true)
	bloco(m, "BordaEncaixe", V(1.24, 0.08, 0.14), pose * CFrame.new(0, cy - 0.31, -P - 0.06), C.hazard, M.SmoothPlastic)
	bloco(m, "BordaEncaixe", V(1.24, 0.08, 0.14), pose * CFrame.new(0, cy - 1.19, -P - 0.06), C.hazard, M.SmoothPlastic)
	bloco(m, "Conduite", V(0.16, 0.5, 0.16), pose * CFrame.new(0.9, 2.15 + A + 0.12, -0.2), C.steelLight, M.Metal)
	local lamp, luz = lampada(m, "Status", V(0.18, 0.18, 0.06), pose * CFrame.new(0.95, cy - 0.75, -P - 0.03), 5)
	local t = telaLocalizada(visor, "enfermaria", 170, 16)
	-- o módulo encaixado fica metade para fora da face do gabinete
	local cfModulo = pose * CFrame.new(0, cy - 0.75, -P - 0.25) * CFrame.Angles(0, 0, 0)
	return t, encaixe, cfModulo, lamp, luz
end

-- uma folha de porta deslizante no plano do vão (o vão mede 12.0 entre as paredes; some dentro da parede quando abre)
local function folha(pai: Instance, nome: string, x: number, zCentro: number, espessura: number, cor: Color3): Part
	return bloco(pai, nome, V(espessura, 8.0, 6.0), CFrame.new(x, 4.0, zCentro), cor, M.Metal, true)
end

-- porta de contenção da enfermaria (fica fechada nesta etapa)
local function construirPortaContencao(pasta: Instance): (Part, PointLight, ParticleEmitter)
	local m = modelo(pasta, "PortaContencao")
	local x = Cenario.POS.portaContencaoX
	local a = folha(m, "FolhaNorte", x, -317.0, 0.5, C.steel)
	local b = folha(m, "FolhaSul", x, -323.0, 0.5, C.steel)
	-- reforços rentes do lado do corredor (+x)
	for _, f in { a, b } do
		local z = f.CFrame.Position.Z
		for _, y in { 1.6, 4.0, 6.4 } do
			bloco(m, "Reforco", V(0.08, 0.3, 5.7), CFrame.new(x + 0.29, y, z), C.steelLight, M.Metal)
		end
		bloco(m, "FaixaRisco", V(0.06, 0.5, 5.9), CFrame.new(x + 0.28, 0.45, z), C.hazard, M.SmoothPlastic)
	end
	bloco(m, "Vedacao", V(0.1, 8.0, 0.14), CFrame.new(x + 0.3, 4.0, -320), C.black, M.Rubber)
	-- lâmpada de estado acima do vão (face da parede sobre o vão em x = -65.0)
	bloco(m, "CaixaLampada", V(0.3, 0.5, 0.7), CFrame.new(-64.85, 8.9, -320), C.dark, M.Metal)
	local lamp, luz = lampada(m, "Lampada", V(0.08, 0.32, 0.5), CFrame.new(-64.66, 8.9, -320), 12)
	-- vapor pela fresta da vedação (textura de fumaça padrão do Roblox)
	local bico = bloco(m, "Fresta", V(0.1, 0.1, 0.1), CFrame.new(x + 0.36, 0.5, -320), C.black, M.Metal)
	bico.Transparency = 1
	local emissor = Instance.new("ParticleEmitter")
	emissor.Name = "Vapor"
	emissor.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emissor.Enabled = false
	emissor.Rate = 38
	emissor.Lifetime = NumberRange.new(1.4, 2.4)
	emissor.Speed = NumberRange.new(3, 6)
	emissor.SpreadAngle = Vector2.new(18, 18)
	emissor.EmissionDirection = Enum.NormalId.Right
	emissor.Acceleration = V(0, 1.2, 0)
	emissor.Drag = 1.5
	emissor.LightEmission = 0.05
	emissor.LightInfluence = 0.9
	emissor.Color = ColorSequence.new(Color3.fromRGB(196, 204, 200))
	emissor.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 3.6) })
	emissor.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.4, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	emissor.Parent = bico
	return lamp, luz, emissor
end

local function construirPlacaContencao(pasta: Instance)
	local pose = Cenario.POS.placaContencao
	local m = modelo(pasta, "PlacaContencao")
	local placa = bloco(m, "Placa", V(2.0, 1.1, 0.06), pose * CFrame.new(0, 3.9, -0.03), C.hazard, M.SmoothPlastic, true)
	local t = tela(placa, Enum.NormalId.Front, 150, 20, C.hazard, true)
	t.TextColor3 = TXT.tinta
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.Text = TEXTO_MUNDO.contencao
end

-- giroflex: base na parede, cúpula vermelha e rotor com o facho (o cliente gira o rotor)
local VERMELHO_APAGADO = Color3.fromRGB(120, 26, 20)
local function construirGiroflex(pai: Instance, i: number, pose: CFrame, servicos: Servicos): { lentes: { Part }, luzes: { Light } }
	local m = modelo(pai, "Giroflex" .. i)
	local vertical = CFrame.Angles(0, 0, math.pi / 2) -- cilindro do Roblox tem o eixo em X
	bloco(m, "Base", V(0.7, 0.7, 0.14), pose * CFrame.new(0, 4.3, -0.07), C.dark, M.Metal, true)
	bloco(m, "Braco", V(0.24, 0.24, 0.3), pose * CFrame.new(0, 4.3, -0.29), C.steel, M.Metal)
	cilindro(m, "Pe", 0.12, 0.58, pose * CFrame.new(0, 4.17, -0.62) * vertical, C.black, M.Metal)
	local lente = cilindro(m, "Lente", 0.4, 0.5, pose * CFrame.new(0, 4.43, -0.62) * vertical, VERMELHO_APAGADO, M.Glass)
	lente.Transparency = 0.25
	local cupula = bloco(m, "Cupula", V(0.5, 0.5, 0.5), pose * CFrame.new(0, 4.63, -0.62), VERMELHO_APAGADO, M.Glass)
	cupula.Shape = Enum.PartType.Ball
	cupula.Transparency = 0.25
	local rotor = bloco(m, "Rotor", V(0.16, 0.2, 0.16), pose * CFrame.new(0, 4.43, -0.62), C.black, M.Metal)
	rotor.Transparency = 1
	local facho = Instance.new("SpotLight")
	facho.Name = "Facho"
	facho.Face = Enum.NormalId.Front
	facho.Angle = 50
	facho.Range = 26
	facho.Brightness = 4
	facho.Color = LUZ.vermelha
	facho.Shadows = false
	facho.Enabled = false
	facho.Parent = rotor
	local brilho = luzPontual(lente, LUZ.vermelha, 9, 1.4)
	brilho.Enabled = false
	servicos.marcar(rotor, "BastiaoGiroflex")
	return { lentes = { lente, cupula }, luzes = { facho, brilho } }
end

-- porta deslizante da oficina (folhas entram na parede) + caixa da trava externa
local function construirPortaOficina(pasta: Instance): ({ { parte: Part, fechada: CFrame, aberta: CFrame } }, Part, PointLight)
	local m = modelo(pasta, "PortaOficina")
	local x = Cenario.POS.portaOficinaX
	local folhas = {}
	for _, d in { { "FolhaNorte", -317.0, 6.3 }, { "FolhaSul", -323.0, -6.3 } } do
		local f = folha(m, d[1], x, d[2], 0.36, C.steelLight)
		local fechada = f.CFrame
		local aberta = fechada * CFrame.new(0, 0, d[3])
		table.insert(folhas, { parte = f, fechada = fechada, aberta = aberta })
	end
	-- letreiro no lado do corredor (-x): fica rente e entra na parede com a folha
	local letreiro = folhas[1].parte
	local t = tela(letreiro, Enum.NormalId.Left, 40, 46, C.steelLight, true)
	t.TextColor3 = Color3.fromRGB(214, 206, 170)
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.Text = TEXTO_MUNDO.oficina
	-- lâmpada de estado sobre o vão, lado do corredor
	bloco(m, "CaixaLampada", V(0.3, 0.5, 0.7), CFrame.new(64.85, 8.9, -320), C.dark, M.Metal)
	local lamp, luz = lampada(m, "Lampada", V(0.08, 0.32, 0.5), CFrame.new(64.66, 8.9, -320), 12)
	-- caixa da trava mecânica externa (o Pavel abre por aqui)
	local pose = Cenario.POS.caixaTravaExterna
	bloco(m, "CaixaTravaExterna", V(0.8, 1.0, 0.3), pose * CFrame.new(0, 4.0, -0.15), C.steel, M.Metal, true)
	bloco(m, "AlavancaExterna", V(0.12, 0.6, 0.12), pose * CFrame.new(0.2, 4.1, -0.36), C.red, M.Metal)
	return folhas, lamp, luz
end

-- alavanca da trava no lado de dentro
local function construirTrava(pasta: Instance): (Part, CFrame, CFrame, CFrame, Part, PointLight)
	local pose = Cenario.POS.travaOficina
	local m = modelo(pasta, "TravaOficina")
	bloco(m, "Caixa", V(1.1, 1.6, 0.36), pose * CFrame.new(0, 3.8, -0.18), C.steel, M.Metal, true)
	local placa = bloco(m, "Placa", V(0.9, 0.3, 0.02), pose * CFrame.new(0, 4.75, -0.37), C.hazard, M.SmoothPlastic)
	local rotuloTrava = tela(placa, Enum.NormalId.Front, 120, 24, C.hazard, true)
	rotuloTrava.TextColor3 = TXT.tinta
	rotuloTrava.TextXAlignment = Enum.TextXAlignment.Center
	rotuloTrava.TextYAlignment = Enum.TextYAlignment.Center
	rotuloTrava.Text = TEXTO_MUNDO.trava
	bloco(m, "Eixo", V(0.24, 0.24, 0.2), pose * CFrame.new(0, 3.7, -0.46), C.dark, M.Metal)
	-- cabo da alavanca gira em torno do eixo: para cima = aberta, para baixo = travada
	local pivo = pose * CFrame.new(0, 3.7, -0.5)
	local cima = pivo * CFrame.new(0, 0.42, 0)
	local meio = pivo * CFrame.Angles(0, 0, math.pi / 2) * CFrame.new(0, 0.42, 0)
	local baixo = pivo * CFrame.Angles(0, 0, math.pi) * CFrame.new(0, 0.42, 0)
	local cabo = bloco(m, "Alavanca", V(0.14, 0.84, 0.14), cima, C.red, M.Metal, true)
	bloco(m, "Batente", V(0.5, 0.08, 0.1), pose * CFrame.new(0, 2.95, -0.4), C.dark, M.Metal)
	local lamp, luz = lampada(m, "Status", V(0.18, 0.18, 0.06), pose * CFrame.new(0.38, 4.35, -0.38), 5)
	return cabo, cima, meio, baixo, lamp, luz
end

-- mesa com o terminal da oficina (CRT), rádio de manutenção e papéis
local function construirTerminalOficina(pasta: Instance): (any, Part, Part, PointLight)
	local pose = Cenario.POS.terminalOficina
	local m = modelo(pasta, "TerminalOficina")
	local alt = 2.9
	bloco(m, "Tampo", V(4.2, 0.14, 2.4), pose * CFrame.new(0, alt - 0.07, -1.2), C.steel, M.Metal, true)
	for _, sx in { -1, 1 } do
		for _, sz in { 0.15, 2.25 } do
			bloco(m, "Pe", V(0.14, alt - 0.14, 0.14), pose * CFrame.new(sx * 1.95, (alt - 0.14) / 2, -sz), C.dark, M.Metal, true)
		end
	end
	bloco(m, "Gaveteiro", V(1.2, 1.9, 2.1), pose * CFrame.new(1.3, 0.95 + 0.4, -1.2), C.steelLight, M.Metal, true)
	-- monitor CRT
	local crt = pose * CFrame.new(-0.3, alt + 0.85, -1.05)
	local caixa = bloco(m, "Monitor", V(1.9, 1.6, 1.5), crt, Color3.fromRGB(150, 146, 128), M.SmoothPlastic, true)
	bloco(m, "TraseiraMonitor", V(1.4, 1.2, 0.5), crt * CFrame.new(0, -0.05, 0.95), Color3.fromRGB(132, 128, 112), M.SmoothPlastic)
	local visor = bloco(m, "Visor", V(1.6, 1.2, 0.02), crt * CFrame.new(0, 0.04, -0.76), C.screen, M.Glass)
	local t = telaLocalizada(visor, "oficina", 220, 13)
	luzPontual(visor, Color3.fromRGB(120, 230, 140), 7, 0.5)
	bloco(m, "Teclado", V(1.6, 0.08, 0.55), pose * CFrame.new(-0.3, alt + 0.04, -2.0) * CFrame.Angles(math.rad(-6), 0, 0), Color3.fromRGB(140, 136, 118), M.SmoothPlastic)
	-- rádio de manutenção independente (Elena chama por ele)
	local radio = pose * CFrame.new(1.55, alt + 0.3, -1.6)
	bloco(m, "RadioManutencao", V(0.9, 0.6, 0.45), radio, C.green, M.Metal, true)
	bloco(m, "GradeRadio", V(0.5, 0.36, 0.02), radio * CFrame.new(-0.12, 0, -0.235), C.black, M.DiamondPlate)
	local led, luzLed = lampada(m, "LedRadio", V(0.08, 0.08, 0.03), radio * CFrame.new(0.3, 0.15, -0.235), 4)
	cilindro(m, "AntenaRadio", 0.7, 0.05, radio * CFrame.new(0.3, 0.65, 0.1) * CFrame.Angles(0, 0, math.pi / 2), C.black, M.Plastic)
	-- papéis soltos
	bloco(m, "Papeis", V(0.8, 0.03, 1.0), pose * CFrame.new(-1.6, alt + 0.015, -1.4) * CFrame.Angles(0, math.rad(-12), 0), C.paper, M.SmoothPlastic)
	return t, caixa, led, luzLed
end

-- ===== montagem e entidades =====
export type Opcoes = {
	pasta: Instance,
	textos: any,
	mundo: any,
	servicos: Servicos,
	jogadores: () -> { any },
	criarPavel: (pasta: Instance) -> any,
	log: ((string) -> ())?,
}

function Cenario.construir(op: Opcoes): any
	local pasta, textos, mundo, sv = op.pasta, op.textos, op.mundo, op.servicos
	local log = op.log or function(_m: string) end
	TEXTO_MUNDO = textos.MUNDO
	SV = sv
	local function ruido(chave: string, pos: Vector3)
		if sv.ruido then
			sv.ruido(chave, pos)
		end
	end
	local cena = { interacoes = {}, zonas = {}, spawns = {}, pecas = {} }

	-- canto do Pavel, rádio e relógio
	construirCaixa(pasta, textos)
	local radioModelo, radioCorpo, radioLed, radioLuz = construirRadio(pasta)
	local relogioTexto = construirRelogio(pasta)
	local entradaLamp, entradaLuz, entradaTexto = construirPainelEntrada(pasta)
	local _, bercoCf, carregadorLamp, carregadorLuz = construirCarregador(pasta)
	local enfTexto, encaixe, cfEncaixado, enfLamp, enfLuz = construirTerminalEnfermaria(pasta)
	local contLamp, contLuz, vapor = construirPortaContencao(pasta)
	construirPlacaContencao(pasta)
	local folhas, ofLamp, ofLuz = construirPortaOficina(pasta)
	local cabo, caboCima, caboMeio, caboBaixo, travaLamp, travaLuz = construirTrava(pasta)
	local ofTexto, monitor, ofLed, ofLedLuz = construirTerminalOficina(pasta)
	local giros = Instance.new("Folder")
	giros.Name = "Giroflexes"
	giros.Parent = pasta
	local giroflexes = {}
	for i, pose in Cenario.POS.giroflex do
		table.insert(giroflexes, construirGiroflex(giros, i, pose, sv))
	end

	-- módulo de bateria (o do mundo fica sempre ancorado; na mão vai uma cópia soldada)
	local modulo, moduloCorpo = construirModulo(pasta, "ModuloBateria", bercoCf)
	local moduloOfs = offsets(moduloCorpo, modulo)
	local P = textos.L.pt.prompts
	local promptRadio = prompt(radioCorpo, "PegarRadio", P.PegarRadio, 0)
	local promptModulo = prompt(moduloCorpo, "PegarModulo", P.PegarModulo, 0.35)
	local promptEncaixe = prompt(encaixe, "EncaixarModulo", P.EncaixarModulo, 0.8)
	local promptTrava = prompt(cabo, "FecharTrava", P.FecharTrava, 0.6)
	promptTrava.RequiresLineOfSight = true -- a alavanca fica a 1 stud da parede do corredor
	local promptTerminal = prompt(monitor, "LerTerminal", P.LerTerminal, 0)

	local pavel = op.criarPavel(pasta)
	cena.pavel = pavel

	-- relógio de apresentação: começa em 02:49 e anda um minuto por minuto
	local minutos = 2 * 60 + 49
	local function tique()
		minutos += 1
		relogioTexto.Text = string.format("%02d:%02d", math.floor(minutos / 60) % 24, minutos % 60)
		sv.atrasar(60, tique)
	end
	sv.atrasar(60, tique)

	-- piscar enquanto um estado durar (o contador cancela piscas antigos)
	local function piscador(parte: Part, luz: PointLight, cor: Color3, periodo: number)
		local geracao = 0
		local function parar()
			geracao += 1
		end
		local function iniciar()
			geracao += 1
			local minha = geracao
			local aceso = false
			local function passo()
				if geracao ~= minha then
					return
				end
				aceso = not aceso
				acender(parte, luz, if aceso then cor else nil, 1.6)
				sv.atrasar(periodo, passo)
			end
			passo()
		end
		return iniciar, parar
	end

	-- ===== entidades =====
	local function E(id: string, estados: { string }, aplicar: (estado: string, instantaneo: boolean) -> (), pronto: (() -> boolean)?)
		local set = {}
		for _, e in estados do
			set[e] = true
		end
		mundo:registrar(id, { estados = set, aplicar = aplicar, pronto = pronto })
	end

	E("pavel", { "tunel", "arsenal", "enfermaria", "porta_oficina", "oficina" }, function(estado, instantaneo)
		pavel:ir(estado, instantaneo)
	end, function()
		return pavel:chegou()
	end)

	E("relogio", { "0249" }, function()
		minutos = 2 * 60 + 49
		relogioTexto.Text = "02:49"
	end)

	E("radio", { "guardado", "oferecido", "entregue" }, function(estado, instantaneo)
		radioModelo.Parent = if estado == "entregue" then nil else pasta
		acender(radioLed, radioLuz, if estado == "oferecido" then LUZ.verde else nil, 0.8)
		if estado == "oferecido" and not instantaneo then
			ruido("squelch", radioCorpo.CFrame.Position)
		end
	end)

	-- bateria: quem carrega é guardado aqui; se essa pessoa sai ou morre, o módulo volta ao carregador
	local bateria = { portador = nil :: any, copia = nil :: Model? }
	cena.bateria = bateria
	local function soltarCopia()
		if bateria.copia then
			bateria.copia:Destroy()
			bateria.copia = nil
		end
	end
	local function moduloNoCarregador()
		modulo.Parent = pasta
		moverConjunto(moduloOfs, bercoCf)
	end
	local function soldarNaMao(jogador: any): boolean
		local personagem = jogador and jogador.Character
		local braco = personagem and personagem:FindFirstChild("Right Arm")
		if not braco or not braco:IsA("BasePart") then
			return false
		end
		soltarCopia()
		local copia = modulo:Clone()
		copia.Name = "ModuloNaMao"
		for _, d in copia:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				d:Destroy()
			end
		end
		local corpo = copia:FindFirstChild("Corpo") :: BasePart
		local ofs = offsets(corpo, copia)
		moverConjunto(ofs, braco.CFrame * CFrame.new(0, -1.74, -0.05))
		for p in ofs do
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			if p ~= corpo then
				local w = Instance.new("WeldConstraint")
				w.Part0 = corpo
				w.Part1 = p
				w.Parent = corpo
			end
		end
		local solda = Instance.new("Weld")
		solda.Name = "MaoModulo"
		solda.Part0 = braco
		solda.Part1 = corpo
		solda.C0 = CFrame.new(0, -1.74, -0.05)
		solda.Parent = corpo
		copia.Parent = personagem
		bateria.copia = copia
		return true
	end

	function bateria.entregar(jogador: any)
		bateria.portador = jogador
		if mundo:estado("bateria") == "carregada" then
			-- pegou de volta do carregador (ação local, a história já estava em "carregada")
			if soldarNaMao(jogador) then
				modulo.Parent = nil
				ruido("modulo_pegar", bercoCf.Position)
			end
		end
	end

	function bateria.soltar(jogador: any, motivo: string?): boolean
		if bateria.portador ~= jogador or jogador == nil then
			return false
		end
		bateria.portador = nil
		soltarCopia()
		if mundo:estado("bateria") == "carregada" then
			moduloNoCarregador()
			acender(carregadorLamp, carregadorLuz, LUZ.verde, 1.2)
			log("[Bastiao] módulo voltou ao carregador (" .. tostring(motivo) .. ")")
		end
		return true
	end

	E("bateria", { "no_carregador", "disponivel", "carregada", "encaixada" }, function(estado, instantaneo)
		if estado == "no_carregador" then
			soltarCopia()
			moduloNoCarregador()
			acender(carregadorLamp, carregadorLuz, LUZ.ambar, 1.0)
		elseif estado == "disponivel" then
			soltarCopia()
			moduloNoCarregador()
			acender(carregadorLamp, carregadorLuz, LUZ.verde, 1.2)
		elseif estado == "carregada" then
			if bateria.portador and soldarNaMao(bateria.portador) then
				modulo.Parent = nil
				acender(carregadorLamp, carregadorLuz, nil)
				if not instantaneo then
					ruido("modulo_pegar", bercoCf.Position)
				end
			else
				bateria.portador = nil
				moduloNoCarregador()
				acender(carregadorLamp, carregadorLuz, LUZ.verde, 1.2)
			end
		elseif estado == "encaixada" then
			soltarCopia()
			bateria.portador = nil
			modulo.Parent = pasta
			moverConjunto(moduloOfs, cfEncaixado)
			acender(carregadorLamp, carregadorLuz, nil)
			if not instantaneo then
				ruido("modulo_encaixe", cfEncaixado.Position)
			end
		end
	end)

	E("terminal_enfermaria", { "sem_energia", "ligado", "autorizado" }, function(estado, instantaneo)
		enfTexto.mostrar(estado)
		if estado == "sem_energia" then
			acender(enfLamp, enfLuz, LUZ.vermelha, 0.6)
		elseif estado == "ligado" then
			acender(enfLamp, enfLuz, LUZ.verde, 0.8)
			if not instantaneo then
				ruido("terminal_liga", enfTexto.parte.CFrame.Position)
			end
		else
			acender(enfLamp, enfLuz, LUZ.ambar, 1.0)
			if not instantaneo then
				ruido("terminal_bip", enfTexto.parte.CFrame.Position)
			end
		end
	end)

	local piscaContencao, pararContencao = piscador(contLamp, contLuz, LUZ.ambar, 0.55)
	E("porta_contencao", { "trancada", "vazando", "destravada" }, function(estado)
		if estado == "trancada" then
			pararContencao()
			vapor.Enabled = false
			acender(contLamp, contLuz, LUZ.vermelha, 1.4)
		elseif estado == "vazando" then
			vapor.Enabled = true
			sv.atrasar(3.6, function()
				vapor.Enabled = false
			end)
		else
			vapor.Enabled = false
			piscaContencao()
		end
	end)

	E("alarme", { "desligado", "ligado" }, function(estado)
		local ligado = estado == "ligado"
		for _, g in giroflexes do
			for _, lente in g.lentes do
				lente.Material = if ligado then M.Neon else M.Glass
				lente.Color = if ligado then LUZ.vermelha else VERMELHO_APAGADO
			end
			for _, l in g.luzes do
				l.Enabled = ligado
			end
		end
	end)

	E("acesso_externo", { "aberto", "bloqueado" }, function(estado)
		if estado == "aberto" then
			acender(entradaLamp, entradaLuz, LUZ.verde, 1.0)
			entradaTexto.TextColor3 = TXT.verde
			entradaTexto.Text = TEXTO_MUNDO.acesso_aberto
		else
			acender(entradaLamp, entradaLuz, LUZ.vermelha, 1.6)
			entradaTexto.TextColor3 = TXT.vermelho
			entradaTexto.Text = TEXTO_MUNDO.acesso_bloqueado
		end
	end)

	-- a alavanca gira em arco: passa pelo meio (90°) em vez de cruzar o eixo em linha reta
	local function moverAlavanca(alvo: CFrame, instantaneo: boolean)
		if instantaneo or cabo.CFrame == alvo then
			cabo.CFrame = alvo
			return
		end
		ruido("alavanca", cabo.CFrame.Position)
		sv.tween(cabo, 0.2, { CFrame = caboMeio })
		sv.atrasar(0.2, function()
			sv.tween(cabo, 0.2, { CFrame = alvo })
		end)
	end
	local function moverFolhas(aberta: boolean, instantaneo: boolean)
		if not instantaneo then
			ruido("porta_desliza", Vector3.new(Cenario.POS.portaOficinaX, 4, -320))
		end
		for _, f in folhas do
			local alvo = if aberta then f.aberta else f.fechada
			if instantaneo then
				f.parte.CFrame = alvo
			else
				sv.tween(f.parte, 1.1, { CFrame = alvo })
			end
		end
	end
	E("porta_oficina", { "aberta", "trancada", "travada" }, function(estado, instantaneo)
		if estado == "aberta" then
			moverFolhas(true, instantaneo)
			acender(ofLamp, ofLuz, LUZ.verde, 1.2)
			moverAlavanca(caboCima, instantaneo)
			acender(travaLamp, travaLuz, LUZ.verde, 0.8)
		elseif estado == "trancada" then
			moverFolhas(false, instantaneo)
			acender(ofLamp, ofLuz, LUZ.vermelha, 1.4)
			cabo.CFrame = caboCima
			acender(travaLamp, travaLuz, LUZ.ambar, 0.8)
		else
			moverFolhas(false, instantaneo)
			acender(ofLamp, ofLuz, LUZ.vermelha, 1.4)
			moverAlavanca(caboBaixo, instantaneo)
			acender(travaLamp, travaLuz, LUZ.vermelha, 1.0)
		end
	end)

	-- nomes de quem está no servidor, na ordem de entrada (KEDR-1, KEDR-2...): o cliente monta a
	-- lista na língua de cada jogador
	local function nomesTurno(): { string }
		local lista = op.jogadores()
		table.sort(lista, function(a, b)
			return (a.UserId or 0) < (b.UserId or 0)
		end)
		local nomes = {}
		for i, j in lista do
			if i > 6 then
				break
			end
			local nome = string.upper(tostring(j.DisplayName or j.Name or "?"))
			if utf8.len(nome) and (utf8.len(nome) :: number) > 16 then
				nome = string.sub(nome, 1, (utf8.offset(nome, 16) :: number) - 1) .. "."
			end
			table.insert(nomes, nome)
		end
		return nomes
	end

	local piscaLed, pararLed = piscador(ofLed, ofLedLuz, LUZ.verde, 0.7)
	E("terminal_oficina", { "apagado", "aguardando", "lista" }, function(estado, instantaneo)
		if estado == "apagado" then
			pararLed()
			ofTexto.mostrar(estado)
		elseif estado == "aguardando" then
			piscaLed()
			ofTexto.mostrar(estado)
			if not instantaneo then
				ruido("terminal_bip", ofTexto.parte.CFrame.Position)
			end
		else
			pararLed()
			acender(ofLed, ofLedLuz, LUZ.verde, 0.6)
			ofTexto.mostrar(estado, nomesTurno())
			if not instantaneo then
				ruido("terminal_liga", ofTexto.parte.CFrame.Position)
			end
		end
	end)

	E("fim", { "oculto", "visivel" }, function(_estado)
		-- o cartão final é do cliente (atributo replicado); aqui não há peça
	end)

	-- ===== interações (o boot liga cada uma à Interacoes) =====
	local function pos(p: BasePart): () -> Vector3
		return function()
			return p.CFrame.Position
		end
	end
	local function dentroOficina(jogador: any): boolean
		local raiz = jogador and jogador.Character and jogador.Character:FindFirstChild("HumanoidRootPart")
		if not raiz then
			return false
		end
		local p = raiz.CFrame.Position
		local a, b = Cenario.OFICINA_DENTRO.min, Cenario.OFICINA_DENTRO.max
		return p.X >= a.X and p.X <= b.X and p.Z >= a.Z and p.Z <= b.Z
	end
	cena.dentroOficina = dentroOficina

	cena.interacoes = {
		{ nome = "pegar_radio", prompt = promptRadio, posicao = pos(radioCorpo), alcance = 10, evento = "pegar_radio", requer = { { "radio", "oferecido" } } },
		{
			nome = "pegar_bateria",
			prompt = promptModulo,
			posicao = pos(moduloCorpo),
			alcance = 10,
			evento = "pegar_bateria",
			requer = { { "bateria", "disponivel" } },
			aoAceitar = function(j)
				bateria.portador = j
			end,
		},
		{
			nome = "repegar_bateria",
			prompt = promptModulo,
			posicao = pos(moduloCorpo),
			alcance = 10,
			requer = { { "bateria", "carregada" } },
			disponivel = function()
				return bateria.portador == nil
			end,
			aoAceitar = function(j)
				bateria.entregar(j)
			end,
		},
		{
			nome = "encaixar_bateria",
			prompt = promptEncaixe,
			posicao = pos(encaixe),
			alcance = 10,
			evento = "encaixar_bateria",
			requer = { { "bateria", "carregada" } },
			validar = function(j)
				if bateria.portador == j then
					return true, nil
				end
				if bateria.portador == nil then
					return false, "modulo_no_carregador"
				end
				return false, "modulo_com", { string.upper(tostring(bateria.portador.DisplayName)) }
			end,
		},
		{
			nome = "fechar_trava",
			prompt = promptTrava,
			posicao = pos(cabo),
			alcance = 10,
			evento = "fechar_trava",
			requer = { { "porta_oficina", "aberta" } },
			validar = function(j)
				if not dentroOficina(j) then
					return false, "entre_oficina"
				end
				if not pavel:chegou() then
					return false, "espere_pavel"
				end
				return true, nil
			end,
		},
		{ nome = "ler_terminal", prompt = promptTerminal, posicao = pos(monitor), alcance = 10, evento = "ler_terminal", requer = { { "terminal_oficina", "aguardando" } } },
	}

	cena.zonas = {
		pavel_perto = { centro = Cenario.POS.pavelTunel + V(0, 3, 0), raio = 8.5 },
		chegou_oficina = {
			centro = V(59.5, 3, -318),
			raio = 7.5,
			condicao = function()
				return mundo:pronto("pavel")
			end,
		},
	}
	cena.spawns = { oficina_segura = Cenario.SPAWN_OFICINA, fim_etapa1 = Cenario.SPAWN_OFICINA }
	return cena
end

return Cenario
