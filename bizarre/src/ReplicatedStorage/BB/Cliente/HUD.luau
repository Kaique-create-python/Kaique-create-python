-- BIZARRE BATTLEGROUNDS :: HUD (vida, despertar, esquiva, golpes, combo, abates, avisos e barras em cima de cada um)
-- AJUSTE-19: visual novo estilo battlegrounds (identidade própria): vidro escuro, bordas inclinadas,
-- texto branco condensado e a cor da aura do Stand como destaque. A lógica (recargas, despertar,
-- guarda, esquiva, vinheta, feed, contatos) é a mesma da AJ17/18.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local BB = script.Parent.Parent
local Config = require(BB:WaitForChild("Config"))
local Golpes = require(BB:WaitForChild("Golpes"))
local Stands = require(BB:WaitForChild("Stands"))
local UI = require(script.Parent:WaitForChild("Interface"))
local Som = require(script.Parent:WaitForChild("Som"))
local Registro = require(script.Parent:WaitForChild("Registro"))
local Lighting = game:GetService("Lighting")

local Contato17 = require(BB.Contato17).novo()
local HUD = {}
local contatoTxt17 = nil
local contatoAte17 = 0
local contatoNivel17 = -1

local E = UI.HUD
local SEGMENTOS = 10
local plr = Players.LocalPlayer
local gui: ScreenGui
local painel: Frame
local abaStand: any
local abaQuadro: Frame
local standTxt: TextLabel
local nomeTxt: TextLabel
local barraVida: any
local vidaRastro: any
local vidaNum: TextLabel
local barraGuarda: any
local gomos: { any } = {}
local despTxt: TextLabel
local evaQuadro: Frame
local evaForma: any
local evaTxt: TextLabel
local barraGolpes: Frame
local slots: { [any]: any } = {}
local botoesMoveis: { [any]: any } = {}
local comboQuadro: Frame
local comboNum: TextLabel
local comboTxt: TextLabel
local comboAte = 0
local feed: Frame
local anuncioTxt: TextLabel
local avisoQuadro: Frame
local avisoTxt: TextLabel
local vinheta: Frame
local Jogador: any = nil
local standVisto = ""
local corStand = E.despertar
local cabecas: { [Model]: BillboardGui } = {}
local barrasCabeca: { [BillboardGui]: any } = {}
local pastaCabecas: Folder

local function tServ()
	return workspace:GetServerTimeNow()
end

local function toque(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- texto que aparece um instante com um pulinho (UIScale; nunca tween de TextSize)
local function pulo(obj: GuiObject, de: number, dur: number?)
	local esc = obj:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	esc.Parent = obj
	esc.Scale = de
	TweenService:Create(esc, TweenInfo.new(dur or 0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function HUD.contato(d)
 local data=Contato17:resolver(d,plr and plr.Character or Players.LocalPlayer.Character,tServ and tServ()or workspace:GetServerTimeNow())
 if not data or not gui then return end
 local now=os.clock()
 if now<contatoAte17 and data.nivel<contatoNivel17 then return end
 contatoNivel17=data.nivel;contatoAte17=now+.45
 if not contatoTxt17 then
  contatoTxt17=UI.texto(gui,"",UDim2.fromOffset(280,36),UDim2.new(.5,-140,.40,0),{face=UI.FACE.destaque,limite=30,z=12,contornoEsp=2.2,contornoCor=E.contorno})
  contatoTxt17.Name="Contato"
 end
 contatoTxt17.Text=data.texto;contatoTxt17.TextColor3=data.cor;contatoTxt17.Visible=true
 pulo(contatoTxt17,1.3,.14)
 local current=contatoAte17
 task.delay(.55,function()if contatoAte17==current and contatoTxt17 then contatoTxt17.Visible=false end end)
end

local function rotuloTecla(slot: any): string
	if slot == "ult" then
		return "G"
	end
	return tostring(slot)
end

------------------------------------------------------------------------------ vida (canto de cima)
local function criarPainel()
	painel = UI.frame(gui, UDim2.fromOffset(320, 66), UDim2.fromOffset(10, 6), E.vidro, 1)
	painel.Name = "Vitais"
	-- aba do Stand: paralelogramo na cor da aura, nome em Bangers
	abaQuadro = UI.frame(painel, UDim2.fromOffset(150, 21), UDim2.fromOffset(0, 0), E.vidro, 1)
	abaQuadro.Name = "AbaStand"
	abaStand = UI.paralelo(abaQuadro, corStand, 0, nil, 2)
	abaStand.ajustar(150, 21)
	abaStand.degrade(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 200, 215))
	standTxt = UI.texto(abaQuadro, "", UDim2.new(1, -16, 1, -2), UDim2.fromOffset(9, 1), { face = UI.FACE.destaque, cor = E.contorno, contorno = false, limite = 19, z = 3 })
	standTxt.Name = "Stand"
	nomeTxt = UI.rotulo(painel, plr.DisplayName, UDim2.fromOffset(150, 16), UDim2.fromOffset(158, 3), { alinhar = Enum.TextXAlignment.Left, cor = E.apagado, limite = 14 })
	nomeTxt.Name = "Nome"
	-- vida: trilho escuro, rastro claro do dano e preenchimento vermelho com brilho em cima
	barraVida = UI.barraInclinada(painel, Vector2.new(236, 17), UDim2.fromOffset(0, 26), nil, E.escuro, 0.38, 2)
	barraVida.raiz.Name = "Vida"
	vidaRastro = barraVida.camada("Rastro", E.rastro, 0.2)
	barraVida.preenche = barraVida.camada("Cor", E.vida, 0)
	barraVida.preenche.forma.degrade(E.vidaClara, Color3.fromRGB(196, 22, 58))
	vidaNum = UI.rotulo(painel, "100", UDim2.fromOffset(52, 22), UDim2.fromOffset(240, 23), { alinhar = Enum.TextXAlignment.Left, limite = 21, contornoEsp = 1.4, z = 4 })
	vidaNum.Name = "VidaNum"
	-- guarda (só aparece bloqueando), fina logo abaixo da vida
	barraGuarda = UI.barraInclinada(painel, Vector2.new(228, 4), UDim2.fromOffset(0, 45), E.guarda, E.escuro, 0.4, 3)
	barraGuarda.raiz.Name = "Guarda"
	barraGuarda.raiz.Visible = false
	-- despertar: 10 gomos dourados
	local larg, alt, vao = 160, 7, 3
	local w = (larg - vao * (SEGMENTOS - 1)) / SEGMENTOS
	for i = 1, SEGMENTOS do
		local q = UI.frame(painel, UDim2.fromOffset(w, alt), UDim2.fromOffset((i - 1) * (w + vao), 52), E.vidro, 1)
		q.Name = "Gomo" .. i
		local p = UI.paralelo(q, E.despertar, 0, nil, 3)
		p.ajustar(w, alt)
		gomos[i] = p
	end
	despTxt = UI.rotulo(painel, "DESPERTAR", UDim2.fromOffset(110, 15), UDim2.fromOffset(larg + 8, 48), { alinhar = Enum.TextXAlignment.Left, cor = E.despertar, limite = 13 })
	despTxt.Name = "Despertar"
	-- esquiva: chip inclinado ciano (cinza com número enquanto recarrega)
	evaQuadro = UI.frame(painel, UDim2.fromOffset(62, 16), UDim2.fromOffset(250, 47), E.vidro, 1)
	evaQuadro.Name = "Esquiva"
	evaForma = UI.paralelo(evaQuadro, E.esquiva, 0.05, nil, 3)
	evaForma.ajustar(62, 16)
	evaTxt = UI.rotulo(evaQuadro, "ESQUIVA", UDim2.new(1, -10, 1, -2), UDim2.fromOffset(5, 1), { cor = E.contorno, contorno = false, limite = 12, z = 4 })
	evaTxt.Name = "Texto"
end

------------------------------------------------------------------------------ golpes (PC: barra embaixo)
local function criarSlots()
	local larg, alt, vao = 96, 50, 12
	local n = 5
	barraGolpes = UI.frame(gui, UDim2.fromOffset(n * larg + (n - 1) * vao, alt + 10), UDim2.new(0.5, -(n * larg + (n - 1) * vao) / 2, 1, -(alt + 18)), E.vidro, 1)
	barraGolpes.Name = "BarraGolpes"
	for i, slot in { 1, 2, 3, 4, "ult" } do
		local c = UI.cartaoGolpe(barraGolpes, rotuloTecla(slot), { tam = UDim2.fromOffset(larg, alt), cor = if slot == "ult" then E.despertar else corStand })
		c.raiz.Position = UDim2.fromOffset((i - 1) * (larg + vao), 8)
		slots[slot] = c
	end
	barraGolpes.Visible = not toque()
end

------------------------------------------------------------------------------ meio da tela e avisos
local function criarCentro()
	-- combo: número grande + HITS, inclinado, logo à direita do meio (some em 1,6 s)
	comboQuadro = UI.frame(gui, UDim2.fromOffset(130, 74), UDim2.new(0.5, 40, 0.27, 0), E.vidro, 1)
	comboQuadro.Name = "Combo"
	comboQuadro.Rotation = -7
	comboNum = UI.texto(comboQuadro, "", UDim2.fromOffset(80, 62), UDim2.fromOffset(0, 0), { face = UI.FACE.destaque, cor = E.despertar, contornoEsp = 2.6, contornoCor = E.contorno, alinhar = Enum.TextXAlignment.Right, limite = 60, z = 6 })
	comboNum.Name = "Numero"
	comboTxt = UI.texto(comboQuadro, "", UDim2.fromOffset(66, 28), UDim2.fromOffset(84, 26), { face = UI.FACE.destaque, cor = E.texto, contornoEsp = 2, contornoCor = E.contorno, alinhar = Enum.TextXAlignment.Left, limite = 26, z = 6 })
	comboTxt.Name = "Hits"
	-- abates: fitas logo abaixo da vida, à esquerda (somem sozinhas)
	feed = UI.frame(gui, UDim2.fromOffset(260, 70), UDim2.fromOffset(10, 76), E.vidro, 1)
	feed.Name = "Abates"
	local lista = Instance.new("UIListLayout")
	lista.HorizontalAlignment = Enum.HorizontalAlignment.Left
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Padding = UDim.new(0, 3)
	lista.Parent = feed
	anuncioTxt = UI.texto(gui, "", UDim2.fromOffset(640, 52), UDim2.new(0.5, -320, 0.2, 0), { face = UI.FACE.destaque, cor = E.despertar, contornoEsp = 3, contornoCor = E.contorno, limite = 46, z = 10 })
	anuncioTxt.Name = "Anuncio"
	anuncioTxt.TextTransparency = 1
	-- aviso curto: fita que some nas pontas, logo acima dos golpes
	avisoQuadro = UI.frame(gui, UDim2.fromOffset(400, 26), UDim2.new(0.5, -200, 1, -100), E.escuro, 0.25)
	avisoQuadro.Name = "Aviso"
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.15), NumberSequenceKeypoint.new(0.8, 0.15), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = avisoQuadro
	avisoTxt = UI.rotulo(avisoQuadro, "", UDim2.new(1, -40, 1, -4), UDim2.fromOffset(20, 2), { limite = 16, z = 6 })
	avisoQuadro.Visible = false
	-- vinheta vermelha (vida baixa): quatro bordas com degradê
	vinheta = UI.frame(gui, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(0, 0, 0), 1)
	vinheta.Name = "Vinheta"
	vinheta.ZIndex = 0
	for i, def in { { UDim2.new(1, 0, 0.18, 0), UDim2.new(), 90 }, { UDim2.new(1, 0, 0.18, 0), UDim2.fromScale(0, 0.82), 270 }, { UDim2.new(0.12, 0, 1, 0), UDim2.new(), 0 }, { UDim2.new(0.12, 0, 1, 0), UDim2.fromScale(0.88, 0), 180 } } do
		local f = UI.frame(vinheta, def[1], def[2], Color3.fromRGB(200, 0, 20), 0.2)
		local gr = Instance.new("UIGradient")
		gr.Rotation = def[3]
		gr.Transparency = NumberSequence.new(0, 1)
		gr.Parent = f
		f.Name = "Borda" .. i
	end
	vinheta.Visible = false
end

------------------------------------------------------------------------------------- público
function HUD.aviso(texto: string)
	avisoTxt.Text = texto
	avisoTxt.TextTransparency = 0
	avisoQuadro.Visible = true
	avisoQuadro.BackgroundTransparency = 0.25
	local s = avisoTxt:FindFirstChildOfClass("UIStroke")
	if s then
		s.Transparency = 0
	end
	pulo(avisoQuadro, 1.08, 0.12)
	task.delay(2, function()
		if avisoTxt.Text == texto then
			TweenService:Create(avisoTxt, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(avisoQuadro, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			if s then
				TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
	end)
end

function HUD.combo(n: number)
	if n < 2 then
		return
	end
	comboNum.Text = tostring(n)
	comboTxt.Text = "HITS"
	comboAte = os.clock() + 1.6
	comboNum.TextTransparency = 0
	comboTxt.TextTransparency = 0
	for _, t in { comboNum, comboTxt } do
		local s = t:FindFirstChildOfClass("UIStroke")
		if s then
			s.Transparency = 0
		end
	end
	-- a cada 5 acertos o número esquenta (dourado -> laranja -> vermelho)
	comboNum.TextColor3 = if n >= 15 then Color3.fromRGB(255, 70, 70) elseif n >= 10 then Color3.fromRGB(255, 140, 50) else E.despertar
	pulo(comboQuadro, 1.35, 0.15)
end

function HUD.anuncio(texto: string, cor: Color3?)
	anuncioTxt.Text = texto
	anuncioTxt.TextColor3 = cor or E.despertar
	anuncioTxt.TextTransparency = 0
	local s = anuncioTxt:FindFirstChildOfClass("UIStroke")
	if s then
		s.Transparency = 0
	end
	pulo(anuncioTxt, 1.6, 0.25)
	Som.tocar("notificacao", nil)
	task.delay(3, function()
		if anuncioTxt.Text == texto then
			TweenService:Create(anuncioTxt, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			if s then
				TweenService:Create(s, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end
	end)
end

function HUD.morte(d: any)
	local linha = UI.frame(feed, UDim2.fromOffset(260, 20), UDim2.new(), E.escuro, 0.2)
	linha.Name = "Abate"
	linha.LayoutOrder = math.floor(os.clock() * 100)
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.25), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = linha
	local a = d.assassino
	local corA = if d.standA and Stands.get(d.standA) then Stands.get(d.standA).aura else E.texto
	local corV = if d.standV and Stands.get(d.standV) then Stands.get(d.standV).aura else E.texto
	local texto
	if a then
		texto = string.format('<font color="#%s">%s</font>  ×  <font color="#%s">%s</font>', corA:ToHex(), a, corV:ToHex(), d.vitima)
	else
		texto = string.format('<font color="#%s">%s</font> caiu', corV:ToHex(), d.vitima)
	end
	UI.rotulo(linha, texto, UDim2.new(1, -30, 1, -4), UDim2.fromOffset(8, 2), { rico = true, limite = 14, alinhar = Enum.TextXAlignment.Left })
	if a == plr.DisplayName then
		Som.tocar("abate", nil)
	end
	task.delay(6, function()
		linha:Destroy()
	end)
	local filhos = {}
	for _, f in feed:GetChildren() do
		if f:IsA("Frame") then
			table.insert(filhos, f)
		end
	end
	table.sort(filhos, function(x, y)
		return x.LayoutOrder < y.LayoutOrder
	end)
	while #filhos > 3 do
		table.remove(filhos, 1):Destroy()
	end
end

-- botões do celular (Controles registra para o HUD mostrar as recargas)
-- AJUSTE-19: os golpes do celular são cartões (UI.cartaoGolpe); registrarBotao fica por compatibilidade
function HUD.registrarCartao(slot: any, cartao: any)
	botoesMoveis[slot] = { cartao = cartao }
	cartao.cor(corStand)
end

function HUD.registrarBotao(slot: any, botao: GuiObject, rotulo: TextLabel?)
	local capa = UI.frame(botao, UDim2.fromScale(1, 0), UDim2.fromScale(0, 1), Color3.fromRGB(0, 0, 0), 0.4)
	capa.AnchorPoint = Vector2.new(0, 1)
	capa.ZIndex = 8
	local tempo = UI.rotulo(botao, "", UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0.25), { z = 9 })
	botoesMoveis[slot] = { capa = capa, tempo = tempo, rotulo = rotulo, botao = botao }
end

local function atualizarNomes()
	local s = Jogador.standAtual()
	if not s then
		return
	end
	corStand = s.aura
	standTxt.Text = s.nome
	abaStand.corpo.BackgroundColor3 = s.aura
	-- a aba cresce com o nome (Bangers ~9,4 px por letra no tamanho 19)
	local larg = math.clamp(28 + #s.nome * 9.4, 110, 190)
	abaQuadro.Size = UDim2.fromOffset(larg, 21)
	abaStand.ajustar(larg, 21)
	nomeTxt.Position = UDim2.fromOffset(larg + 8, 3)
	for slot, c in slots do
		local g = Golpes.doSlot(s, slot)
		c.nome.Text = if g then string.upper(g.nome) else "-"
		c.cor(if slot == "ult" then E.despertar else s.aura)
	end
	for slot, b in botoesMoveis do
		local g = Golpes.doSlot(s, slot)
		if b.cartao then
			b.cartao.nome.Text = if g then string.upper(g.nome) else "-"
			b.cartao.cor(s.aura)
		elseif b.rotulo and g and slot ~= "ult" then
			b.rotulo.Text = g.nome
		end
	end
end

local function atualizarCds()
	local s = Jogador.standAtual()
	if not s then
		return
	end
	local desperto = Jogador.desperto()
	-- devolve fração pronta (1 = pronto) e o texto do tempo ("" = pronto)
	local function estado(slot): (number?, string?, boolean?)
		local g, id = Golpes.doSlot(s, slot)
		if not g or not id then
			return nil, nil
		end
		local resta = Jogador.cdRestante(id)
		if slot == "ult" then
			if not desperto then
				return 0, "", true
			elseif Jogador.ultUsada() then
				return 0, "USADA", true
			end
			return 1, ""
		end
		if resta > 0 then
			return 1 - math.clamp(resta / math.max(1, g.cd), 0, 1), string.format("%.0f", math.ceil(resta))
		end
		return 1, ""
	end
	for slot, c in slots do
		local frac, txt, bloq = estado(slot)
		if frac then
			c.estado(frac, txt, bloq)
		end
	end
	for slot, b in botoesMoveis do
		if slot == "ult" then
			continue
		end
		local frac, txt = estado(slot)
		if not frac then
			continue
		end
		if b.cartao then
			b.cartao.estado(frac, txt)
		else
			b.capa.Size = UDim2.fromScale(1, 1 - frac)
			b.tempo.Text = txt or ""
		end
	end
end
HUD.atualizarCds = atualizarCds

local function pintarGomos(frac: number, cor: Color3)
	local cheio = frac * SEGMENTOS
	for i, p in gomos do
		local resto = math.clamp(cheio - (i - 1), 0, 1)
		p.corpo.BackgroundColor3 = if resto > 0 then cor else Color3.fromRGB(255, 255, 255)
		p.corpo.BackgroundTransparency = if resto >= 1 then 0 elseif resto > 0 then 0.55 - resto * 0.35 else 0.78
	end
end

local function atualizarPainel()
	local c = plr.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not c or not hum then
		return
	end
	local frac = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
	barraVida.preenche.fracao(frac)
	local rastro = vidaRastro.frac
	vidaRastro.fracao(if rastro > frac then math.max(frac, rastro - 0.01) else frac)
	vidaNum.Text = tostring(math.ceil(hum.Health))
	vidaNum.TextColor3 = if frac < 0.3 then E.vidaClara else E.texto
	vinheta.Visible = frac < 0.3 and hum.Health > 0
	if vinheta.Visible then
		local pulso = 0.35 + math.sin(os.clock() * 5) * 0.15
		for _, f in vinheta:GetChildren() do
			if f:IsA("Frame") then
				f.BackgroundTransparency = pulso
			end
		end
	end
	local t = tServ()
	local guarda = c:GetAttribute("BB_Guarda") or 100
	barraGuarda.raiz.Visible = c:GetAttribute("BB_Bloqueando") == true
	barraGuarda.preenche.fracao(math.clamp(guarda / Config.BLOQUEIO.guardaMax, 0, 1))
	local desp = c:GetAttribute("BB_Despertar") or 0
	local desperto = (c:GetAttribute("BB_Desperto") or 0) > t
	local tecla = if toque() then "" else " [G]"
	if desperto then
		local resta = (c:GetAttribute("BB_Desperto") :: number) - t
		pintarGomos(math.clamp(resta / Config.DESPERTAR.duracao, 0, 1), Color3.fromRGB(255, 240, 160))
		despTxt.Text = if Jogador.ultUsada() then string.format("DESPERTO %ds", math.ceil(resta)) else string.format("ULT PRONTA%s · %ds", tecla, math.ceil(resta))
		despTxt.TextColor3 = E.despertar
	else
		pintarGomos(math.clamp(desp / Config.DESPERTAR.max, 0, 1), E.despertar)
		if desp >= Config.DESPERTAR.max then
			despTxt.Text = "DESPERTAR!" .. tecla
			despTxt.TextColor3 = if math.floor(os.clock() * 3) % 2 == 0 then E.despertar else E.texto
		else
			despTxt.Text = string.format("DESPERTAR %d%%", math.floor(desp))
			despTxt.TextColor3 = E.despertar
		end
	end
	local eva = c:GetAttribute("BB_Evasiva") or 0
	if eva > t then
		evaTxt.Text = string.format("ESQUIVA %d", math.ceil(eva - t))
		evaTxt.TextColor3 = E.texto
		evaForma.corpo.BackgroundColor3 = Color3.fromRGB(70, 74, 92)
	else
		evaTxt.Text = "ESQUIVA"
		evaTxt.TextColor3 = E.contorno
		evaForma.corpo.BackgroundColor3 = E.esquiva
	end
	local id = c:GetAttribute("BB_Stand")
	if id ~= standVisto then
		standVisto = id
		atualizarNomes()
	end
	if os.clock() > comboAte and comboNum.TextTransparency < 1 then
		local tr = math.min(1, comboNum.TextTransparency + 0.08)
		comboNum.TextTransparency = tr
		comboTxt.TextTransparency = tr
		for _, lbl in { comboNum, comboTxt } do
			local s = lbl:FindFirstChildOfClass("UIStroke")
			if s then
				s.Transparency = tr
			end
		end
	end
end

-- barrinha de vida em cima de cada lutador (mesmo estilo: nome, Stand na cor da aura, barra inclinada)
local function cabeca(modelo: Model)
	if cabecas[modelo] then
		return
	end
	local raiz = modelo:FindFirstChild("Head") or modelo:FindFirstChild("HumanoidRootPart")
	if not raiz then
		return
	end
	local b = Instance.new("BillboardGui")
	b.Name = "BB_Cabeca"
	b.Size = UDim2.fromOffset(150, 46)
	b.StudsOffset = Vector3.new(0, 2.6, 0)
	b.MaxDistance = 110
	b.AlwaysOnTop = false
	b.LightInfluence = 0
	b.Adornee = raiz :: BasePart
	b.Parent = pastaCabecas
	local nome = UI.rotulo(b, "", UDim2.new(1, 0, 0, 16), UDim2.new(), { limite = 15, contornoEsp = 1.3 })
	nome.Name = "Nome"
	local stand = UI.texto(b, "", UDim2.new(1, 0, 0, 14), UDim2.fromOffset(0, 16), { face = UI.FACE.destaque, limite = 14, contornoEsp = 1.2, contornoCor = E.contorno })
	stand.Name = "Stand"
	local barra = UI.barraInclinada(b, Vector2.new(120, 8), UDim2.fromOffset(15, 33), E.vida, E.escuro, 0.3)
	barra.raiz.Name = "Barra"
	barra.preenche.forma.degrade(E.vidaClara, Color3.fromRGB(196, 22, 58))
	cabecas[modelo] = b
	barrasCabeca[b] = barra
end

local function atualizarCabecas()
	local vistos = {}
	-- AJUSTE7: lista pronta do registro (sem varrer o workspace)
	for m in Registro.lutadores() do
		if m ~= plr.Character then
			vistos[m] = true
			cabeca(m)
			local b = cabecas[m]
			if b then
				local hum = m:FindFirstChildOfClass("Humanoid")
				local s = Stands.get(m:GetAttribute("BB_Stand"))
				local nome = b:FindFirstChild("Nome") :: TextLabel
				local st = b:FindFirstChild("Stand") :: TextLabel
				nome.Text = tostring(m:GetAttribute("BB_Nome") or m.Name)
				st.Text = if s and not m:GetAttribute("BB_Boneco") then s.nome else ""
				st.TextColor3 = if s then s.aura else E.texto
				local barra = barrasCabeca[b]
				if hum and barra then
					barra.preenche.fracao(math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1))
				end
				b.Enabled = hum ~= nil and hum.Health > 0
			end
		end
	end
	for m, b in cabecas do
		if not vistos[m] then
			barrasCabeca[b] = nil
			b:Destroy()
			cabecas[m] = nil
		end
	end
end

-- AJUSTE7: caiu? A seta "TO BE CONTINUED" entra de lado e a tela fica sépia até você voltar
local setaContinua: Frame? = nil
local corContinua: ColorCorrectionEffect? = nil
function HUD.continua(sim: boolean)
	if not setaContinua then
		local ouro = Color3.fromRGB(236, 192, 62)
		local marrom = Color3.fromRGB(58, 30, 10)
		local f = UI.frame(gui, UDim2.fromOffset(430, 62), UDim2.new(0, -480, 1, -150), ouro, 0)
		f.ZIndex = 30
		UI.borda(f, marrom, 3)
		local ponta = UI.frame(f, UDim2.fromOffset(44, 44), UDim2.fromOffset(-22, 9), ouro, 0)
		ponta.Rotation = 45
		ponta.ZIndex = 30
		UI.texto(f, "TO BE CONTINUED", UDim2.new(1, -44, 1, -14), UDim2.fromOffset(30, 7), { cor = marrom, contorno = false, z = 31 })
		setaContinua = f
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "BB_Continua"
		cc.Parent = Lighting
		corContinua = cc
	end
	local f = setaContinua :: Frame
	local cc = corContinua :: ColorCorrectionEffect
	if sim then
		f.Position = UDim2.new(0, -480, 1, -150)
		f.Visible = true
		TweenService:Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0, 44, 1, -150) }):Play()
		TweenService:Create(cc, TweenInfo.new(0.3), { Saturation = -0.75, Contrast = 0.18, TintColor = Color3.fromRGB(255, 226, 184) }):Play()
	else
		f.Visible = false
		TweenService:Create(cc, TweenInfo.new(0.4), { Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }):Play()
	end
end

function HUD.mostrar(sim: boolean)
	gui.Enabled = sim
end

function HUD.gui(): ScreenGui
	return gui
end

function HUD.iniciar(jogador: any)
	Jogador = jogador
	gui = Instance.new("ScreenGui")
	gui.Name = "BB_HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	-- respeita o recorte/câmera frontal do celular (nada fica escondido atrás do "notch")
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end)
	gui.Parent = plr:WaitForChild("PlayerGui")
	pastaCabecas = Instance.new("Folder")
	pastaCabecas.Name = "BB_Cabecas"
	pastaCabecas.Parent = plr:WaitForChild("PlayerGui")
	UI.escalaHUD(gui)
	criarPainel()
	criarSlots()
	criarCentro()
	UserInputService.LastInputTypeChanged:Connect(function()
		barraGolpes.Visible = not toque()
	end)
	local acum = 0
	RunService.RenderStepped:Connect(function(dt)
		atualizarPainel()
		acum += dt
		if acum >= 0.2 then
			acum = 0
			atualizarCds()
			atualizarCabecas()
		end
	end)
end

return HUD
