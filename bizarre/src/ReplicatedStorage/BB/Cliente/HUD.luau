-- BIZARRE BATTLEGROUNDS :: HUD (vida, despertar, evasiva, golpes, combo, abates, avisos e barras em cima de cada um)

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

local plr = Players.LocalPlayer
local gui: ScreenGui
local painel: Frame
local nomeTxt: TextLabel
local standTxt: TextLabel
local vidaFill: Frame
local vidaRastro: Frame
local vidaNum: TextLabel
local guardaFill: Frame
local guardaFundo: Frame
local despFill: Frame
local despTxt: TextLabel
local evaTxt: TextLabel
local evaIcone: Frame
local barraGolpes: Frame
local slots: { [any]: any } = {}
local botoesMoveis: { [any]: any } = {}
local comboTxt: TextLabel
local comboSub: TextLabel
local comboAte = 0
local feed: Frame
local anuncioTxt: TextLabel
local avisoTxt: TextLabel
local vinheta: Frame
local Jogador: any = nil
local standVisto = ""
local cabecas: { [Model]: BillboardGui } = {}
local pastaCabecas: Folder

local function tServ()
	return workspace:GetServerTimeNow()
end

function HUD.contato(d)
 local data=Contato17:resolver(d,plr and plr.Character or Players.LocalPlayer.Character,tServ and tServ()or workspace:GetServerTimeNow())
 if not data or not gui then return end
 local now=os.clock()
 if now<contatoAte17 and data.nivel<contatoNivel17 then return end
 contatoNivel17=data.nivel;contatoAte17=now+.45
 if not contatoTxt17 then
  contatoTxt17=UI.texto(gui,"",UDim2.fromOffset(260,28),UDim2.new(.5,-130,.43,0),{limite=19,z=12})
 end
 contatoTxt17.Text=data.texto;contatoTxt17.TextColor3=data.cor;contatoTxt17.Visible=true
 local current=contatoAte17
 task.delay(.55,function()if contatoAte17==current and contatoTxt17 then contatoTxt17.Visible=false end end)
end

local function rotuloTecla(slot: any): string
	if slot == "ult" then
		return "G"
	end
	return tostring(slot)
end

local function criarPainel()
	painel = UI.frame(gui, UDim2.fromOffset(330, 96), UDim2.fromOffset(14, 10), UI.CORES.fundo, 0.25)
	UI.canto(painel, 12)
	UI.borda(painel, UI.CORES.roxo, 2, 0.3)
	local faixa = UI.frame(painel, UDim2.new(0, 6, 1, -12), UDim2.fromOffset(6, 6), UI.CORES.dourado)
	faixa.Name = "Faixa"
	UI.canto(faixa, 3)
	nomeTxt = UI.texto(painel, plr.DisplayName, UDim2.fromOffset(170, 22), UDim2.fromOffset(18, 4), { alinhar = Enum.TextXAlignment.Left })
	standTxt = UI.texto(painel, "", UDim2.fromOffset(140, 20), UDim2.fromOffset(182, 6), { alinhar = Enum.TextXAlignment.Right, cor = UI.CORES.dourado })
	-- vida
	local fundoVida = UI.frame(painel, UDim2.fromOffset(268, 18), UDim2.fromOffset(18, 30), Color3.fromRGB(40, 20, 30))
	UI.canto(fundoVida, 5)
	vidaRastro = UI.frame(fundoVida, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(255, 240, 240))
	UI.canto(vidaRastro, 5)
	vidaFill = UI.frame(fundoVida, UDim2.fromScale(1, 1), UDim2.new(), UI.CORES.vermelho)
	UI.canto(vidaFill, 5)
	UI.gradiente(vidaFill, Color3.fromRGB(255, 110, 110), Color3.fromRGB(200, 30, 50), 90)
	vidaNum = UI.texto(fundoVida, "100", UDim2.fromScale(1, 1), UDim2.new(), { z = 3 })
	-- guarda (só aparece bloqueando)
	guardaFundo = UI.frame(painel, UDim2.fromOffset(268, 5), UDim2.fromOffset(18, 50), Color3.fromRGB(20, 30, 50))
	guardaFill = UI.frame(guardaFundo, UDim2.fromScale(1, 1), UDim2.new(), UI.CORES.azul)
	guardaFundo.Visible = false
	-- evasiva
	evaIcone = UI.frame(painel, UDim2.fromOffset(34, 34), UDim2.fromOffset(290, 28), UI.CORES.azul)
	UI.circulo(evaIcone)
	UI.borda(evaIcone, Color3.fromRGB(10, 6, 20), 2)
	evaTxt = UI.texto(evaIcone, "EV", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1))
	-- despertar
	local fundoDesp = UI.frame(painel, UDim2.fromOffset(268, 12), UDim2.fromOffset(18, 58), Color3.fromRGB(30, 20, 50))
	UI.canto(fundoDesp, 4)
	despFill = UI.frame(fundoDesp, UDim2.fromScale(0, 1), UDim2.new(), UI.CORES.roxo)
	UI.canto(despFill, 4)
	UI.gradiente(despFill, UI.CORES.dourado, UI.CORES.roxo, 0)
	despTxt = UI.texto(painel, "DESPERTAR", UDim2.fromOffset(268, 18), UDim2.fromOffset(18, 72), { cor = Color3.fromRGB(200, 180, 255), alinhar = Enum.TextXAlignment.Left })
end

local function criarSlots()
	barraGolpes = UI.frame(gui, UDim2.fromOffset(5 * 128, 64), UDim2.new(0.5, -320, 1, -78), UI.CORES.fundo, 1)
	for i, slot in { 1, 2, 3, 4, "ult" } do
		local f = UI.frame(barraGolpes, UDim2.fromOffset(120, 58), UDim2.fromOffset((i - 1) * 128, 0), UI.CORES.fundo, 0.2)
		UI.canto(f, 10)
		local borda = UI.borda(f, if slot == "ult" then UI.CORES.dourado else UI.CORES.roxo, 2, 0.2)
		local tecla = UI.texto(f, rotuloTecla(slot), UDim2.fromOffset(22, 22), UDim2.fromOffset(4, 2), { cor = UI.CORES.dourado })
		local nome = UI.texto(f, "", UDim2.new(1, -10, 0, 30), UDim2.fromOffset(5, 22), { quebrar = true, limite = 18 })
		local capa = UI.frame(f, UDim2.fromScale(1, 0), UDim2.fromScale(0, 1), Color3.fromRGB(0, 0, 0), 0.35)
		capa.AnchorPoint = Vector2.new(0, 1)
		UI.canto(capa, 10)
		local tempo = UI.texto(f, "", UDim2.fromScale(1, 0.6), UDim2.fromScale(0, 0.2), { z = 4, cor = UI.CORES.branco })
		local _ = tecla
		slots[slot] = { frame = f, nome = nome, capa = capa, tempo = tempo, borda = borda }
	end
	barraGolpes.Visible = not UserInputService.TouchEnabled or UserInputService.KeyboardEnabled
end

local function criarCentro()
	comboTxt = UI.texto(gui, "", UDim2.fromOffset(220, 70), UDim2.new(1, -250, 0.42, 0), { cor = UI.CORES.dourado, contornoEsp = 3 })
	comboTxt.Rotation = -6
	comboSub = UI.texto(gui, "", UDim2.fromOffset(160, 26), UDim2.new(1, -220, 0.42, 66), { cor = UI.CORES.branco })
	comboSub.Rotation = -6
	feed = UI.frame(gui, UDim2.fromOffset(360, 160), UDim2.new(1, -372, 0, 54), UI.CORES.fundo, 1)
	local lista = Instance.new("UIListLayout")
	lista.HorizontalAlignment = Enum.HorizontalAlignment.Right
	lista.Padding = UDim.new(0, 4)
	lista.Parent = feed
	anuncioTxt = UI.texto(gui, "", UDim2.fromOffset(700, 54), UDim2.new(0.5, -350, 0, 70), { cor = UI.CORES.dourado, contornoEsp = 3 })
	anuncioTxt.TextTransparency = 1
	avisoTxt = UI.texto(gui, "", UDim2.fromOffset(560, 30), UDim2.new(0.5, -280, 1, -118), { cor = UI.CORES.branco })
	avisoTxt.TextTransparency = 1
	-- vinheta vermelha (vida baixa): quatro bordas com degradê
	vinheta = UI.frame(gui, UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(0, 0, 0), 1)
	vinheta.ZIndex = 0
	for i, def in { { UDim2.new(1, 0, 0.18, 0), UDim2.new(), 90 }, { UDim2.new(1, 0, 0.18, 0), UDim2.fromScale(0, 0.82), 270 }, { UDim2.new(0.12, 0, 1, 0), UDim2.new(), 0 }, { UDim2.new(0.12, 0, 1, 0), UDim2.fromScale(0.88, 0), 180 } } do
		local f = UI.frame(vinheta, def[1], def[2], Color3.fromRGB(200, 0, 20), 0.2)
		local g = Instance.new("UIGradient")
		g.Rotation = def[3]
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = f
		f.Name = "Borda" .. i
	end
	vinheta.Visible = false
end

------------------------------------------------------------------------------------- público
function HUD.aviso(texto: string)
	avisoTxt.Text = texto
	avisoTxt.TextTransparency = 0
	local s = avisoTxt:FindFirstChildOfClass("UIStroke")
	if s then
		s.Transparency = 0
	end
	task.delay(2, function()
		if avisoTxt.Text == texto then
			TweenService:Create(avisoTxt, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
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
	comboTxt.Text = n .. " HITS"
	comboSub.Text = ""
	comboAte = os.clock() + 1.6
	comboTxt.TextTransparency = 0
	comboSub.TextTransparency = 0
	local esc = comboTxt:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	esc.Parent = comboTxt
	esc.Scale = 1.35
	TweenService:Create(esc, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function HUD.anuncio(texto: string, cor: Color3?)
	anuncioTxt.Text = texto
	anuncioTxt.TextColor3 = cor or UI.CORES.dourado
	anuncioTxt.TextTransparency = 0
	local esc = anuncioTxt:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	esc.Parent = anuncioTxt
	esc.Scale = 1.6
	TweenService:Create(esc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Som.tocar("notificacao", nil)
	task.delay(3, function()
		if anuncioTxt.Text == texto then
			TweenService:Create(anuncioTxt, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
	end)
end

function HUD.morte(d: any)
	local linha = UI.frame(feed, UDim2.fromOffset(360, 26), UDim2.new(), UI.CORES.fundo, 0.3)
	UI.canto(linha, 8)
	local a = d.assassino
	local corA = if d.standA and Stands.get(d.standA) then Stands.get(d.standA).aura else UI.CORES.branco
	local corV = if d.standV and Stands.get(d.standV) then Stands.get(d.standV).aura else UI.CORES.branco
	local texto
	if a then
		texto = string.format('<font color="#%s">%s</font>  ✖  <font color="#%s">%s</font>', corA:ToHex(), a, corV:ToHex(), d.vitima)
	else
		texto = string.format('<font color="#%s">%s</font> caiu', corV:ToHex(), d.vitima)
	end
	UI.texto(linha, texto, UDim2.new(1, -10, 1, -4), UDim2.fromOffset(5, 2), { rico = true, alinhar = Enum.TextXAlignment.Right })
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
	if #filhos > 5 then
		filhos[1]:Destroy()
	end
end

-- botões do celular (Controles registra para o HUD mostrar as recargas)
function HUD.registrarBotao(slot: any, botao: GuiObject, rotulo: TextLabel?)
	local capa = UI.frame(botao, UDim2.fromScale(1, 0), UDim2.fromScale(0, 1), Color3.fromRGB(0, 0, 0), 0.4)
	capa.AnchorPoint = Vector2.new(0, 1)
	capa.ZIndex = 8
	UI.canto(capa, 12)
	local tempo = UI.texto(botao, "", UDim2.fromScale(1, 0.5), UDim2.fromScale(0, 0.25), { z = 9 })
	local estado=UI.texto(botao,"",UDim2.new(1,-8,.26,0),UDim2.new(0,4,.70,0),{z=10,limite=11,cor=UI.CORES.dourado})
 if rotulo then rotulo.Size=UDim2.new(1,-10,.62,0);rotulo.Position=UDim2.fromOffset(5,3)end
 botoesMoveis[slot] = { capa = capa, tempo = tempo, rotulo = rotulo, botao = botao, estado=estado }
end

local function atualizarNomes()
	local s = Jogador.standAtual()
	if not s then
		return
	end
	standTxt.Text = "『" .. s.nome .. "』"
	standTxt.TextColor3 = s.aura
	local faixa = painel:FindFirstChild("Faixa") :: Frame?
	if faixa then
		faixa.BackgroundColor3 = s.aura
	end
	for slot, sl in slots do
		local g = Golpes.doSlot(s, slot)
		sl.nome.Text = if g then g.nome else "-"
	end
	for slot, b in botoesMoveis do
		local g = Golpes.doSlot(s, slot)
		if b.rotulo and g and slot ~= "ult" then
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
	local function pintar(slot, capa, tempo, extra)
		local g, id = Golpes.doSlot(s, slot)
		if not g or not id then
			return
		end
		local resta = Jogador.cdRestante(id)
		local bloqueado = false
		if slot == "ult" then
			bloqueado = not desperto or Jogador.ultUsada()
			resta = 0
		end
		if bloqueado then
			capa.Size = UDim2.fromScale(1, 1)
			tempo.Text = if slot == "ult" and not desperto then "" else "USADA"
		elseif resta > 0 then
			capa.Size = UDim2.fromScale(1, math.clamp(resta / math.max(1, g.cd), 0, 1))
			tempo.Text = string.format("%.0f", math.ceil(resta))
		else
			capa.Size = UDim2.fromScale(1, 0)
			tempo.Text = ""
		end
		if extra then
			extra(bloqueado, resta)
		end
	end
	for slot, sl in slots do
		pintar(slot, sl.capa, sl.tempo)
	end
	for slot, b in botoesMoveis do
		if slot == "ult" then
			continue
		end
		pintar(slot, b.capa, b.tempo,function(bloqueado,resta)
   b.estado.Text=if bloqueado then "INDISPONÍVEL"elseif resta>0 then "RECARGA"else "PRONTO"
   b.estado.TextColor3=if resta>0 then Color3.fromRGB(202,190,218)else UI.CORES.dourado
  end)
	end
end
HUD.atualizarCds = atualizarCds

local function atualizarPainel()
	local c = plr.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not c or not hum then
		return
	end
	local frac = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
	vidaFill.Size = UDim2.fromScale(frac, 1)
	local rastro = vidaRastro.Size.X.Scale
	if rastro > frac then
		vidaRastro.Size = UDim2.fromScale(math.max(frac, rastro - 0.01), 1)
	else
		vidaRastro.Size = UDim2.fromScale(frac, 1)
	end
	vidaNum.Text = tostring(math.ceil(hum.Health))
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
	guardaFundo.Visible = c:GetAttribute("BB_Bloqueando") == true
	guardaFill.Size = UDim2.fromScale(math.clamp(guarda / Config.BLOQUEIO.guardaMax, 0, 1), 1)
	local desp = c:GetAttribute("BB_Despertar") or 0
	local desperto = (c:GetAttribute("BB_Desperto") or 0) > t
	if desperto then
		local resta = (c:GetAttribute("BB_Desperto") :: number) - t
		despFill.Size = UDim2.fromScale(math.clamp(resta / Config.DESPERTAR.duracao, 0, 1), 1)
		despTxt.Text = if Jogador.ultUsada() then string.format("DESPERTO  %ds", math.ceil(resta)) else string.format("DESPERTO  %ds  ·  ULT PRONTA [G]", math.ceil(resta))
		despTxt.TextColor3 = UI.CORES.dourado
	else
		despFill.Size = UDim2.fromScale(math.clamp(desp / Config.DESPERTAR.max, 0, 1), 1)
		if desp >= Config.DESPERTAR.max then
			despTxt.Text = "DESPERTAR PRONTO! [G]"
			despTxt.TextColor3 = if math.floor(os.clock() * 3) % 2 == 0 then UI.CORES.dourado else UI.CORES.branco
		else
			despTxt.Text = string.format("DESPERTAR  %d%%", math.floor(desp))
			despTxt.TextColor3 = Color3.fromRGB(200, 180, 255)
		end
	end
	local eva = c:GetAttribute("BB_Evasiva") or 0
	if eva > t then
		evaTxt.Text = tostring(math.ceil(eva - t))
		evaIcone.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
	else
		evaTxt.Text = "EV"
		evaIcone.BackgroundColor3 = UI.CORES.azul
	end
	local id = c:GetAttribute("BB_Stand")
	if id ~= standVisto then
		standVisto = id
		atualizarNomes()
	end
	if os.clock() > comboAte and comboTxt.TextTransparency < 1 then
		comboTxt.TextTransparency = math.min(1, comboTxt.TextTransparency + 0.08)
		comboSub.TextTransparency = comboTxt.TextTransparency
	end
end

-- barrinha de vida em cima de cada lutador
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
	local nome = UI.texto(b, "", UDim2.new(1, 0, 0, 18), UDim2.new(), {})
	nome.Name = "Nome"
	local stand = UI.texto(b, "", UDim2.new(1, 0, 0, 14), UDim2.fromOffset(0, 17), {})
	stand.Name = "Stand"
	local fundo = UI.frame(b, UDim2.new(1, -20, 0, 8), UDim2.fromOffset(10, 33), Color3.fromRGB(30, 10, 20))
	UI.canto(fundo, 4)
	local fill = UI.frame(fundo, UDim2.fromScale(1, 1), UDim2.new(), UI.CORES.vermelho)
	fill.Name = "Fill"
	UI.canto(fill, 4)
	cabecas[modelo] = b
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
				st.Text = if s and not m:GetAttribute("BB_Boneco") then "『" .. s.nome .. "』" else ""
				st.TextColor3 = if s then s.aura else UI.CORES.branco
				local fill = b:FindFirstChild("Fill", true) :: Frame
				if hum and fill then
					fill.Size = UDim2.fromScale(math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1), 1)
				end
				b.Enabled = hum ~= nil and hum.Health > 0
			end
		end
	end
	for m, b in cabecas do
		if not vistos[m] then
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
	UI.escalaTela(gui, 1100, 600, 0.55, 1.15)
	criarPainel()
	criarSlots()
 if UserInputService.TouchEnabled then barraGolpes.Visible=false end
	criarCentro()
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
