-- AJUSTE-19: HUD novo (skills design-critique, roblox-ui-layout, roblox-gui, roblox-ui-typography,
-- roblox-ui-genre-scifi). Módulos reais (HUD, Controles, Interface, Layout17) com serviços controlados.
local R = require("@lune/roblox")
local H = require("./harness")

local function sinal()
	return { Connect = function() return { Disconnect = function() end } end }
end
local capt = { RenderStepped = {}, Heartbeat = {} }
local function captura(l)
	return { Connect = function(_, fn) table.insert(l, fn); return { Disconnect = function() end } end }
end
for _, ev in { "InputBegan", "InputEnded", "InputChanged", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "MouseEnter", "MouseLeave", "Activated" } do
	R.implementProperty("GuiObject", ev, sinal)
end
R.implementMethod("Instance", "GetPropertyChangedSignal", sinal)
-- AbsoluteSize não existe fora do motor: as leituras passam por __tam (área segura W x Hh)
local W, Hh = 705, 280
local function tam(obj: any): any
	if obj:IsA("ScreenGui") then return R.Vector2.new(W, Hh) end
	local pai = obj.Parent
	local pp = if pai and (pai:IsA("GuiObject") or pai:IsA("ScreenGui")) then tam(pai) else R.Vector2.new(W, Hh)
	return R.Vector2.new(pp.X * obj.Size.X.Scale + obj.Size.X.Offset, pp.Y * obj.Size.Y.Scale + obj.Size.Y.Offset)
end
H.extras.__tam = tam
for _, nome in { "HUD", "Controles", "Interface", "EditorToques17" } do
	local no = H.arvore.ReplicatedStorage.BB.Cliente[nome]
	rawset(no, "fonte", (string.gsub(rawget(no, "fonte"), "([%w_]+)%.AbsoluteSize", "__tam(%1)")))
end

------------------------------------------------------------------ 1) layout padrão dos botões de toque
local L = H.modulo("ReplicatedStorage/BB/Layout17")
local function cobreCentro(boxes, w, h)
	local cx0, cy0, cx1, cy1 = w / 4, h / 4, 3 * w / 4, 3 * h / 4
	local area = 0
	for _, a in boxes do
		local x0, y0 = math.max(cx0, a.x - a.w / 2), math.max(cy0, a.y - a.h / 2)
		local x1, y1 = math.min(cx1, a.x + a.w / 2), math.min(cy1, a.y + a.h / 2)
		if x1 > x0 and y1 > y0 then area += (x1 - x0) * (y1 - y0) end
	end
	return area / ((cx1 - cx0) * (cy1 - cy0))
end
local tamanhos = { { 568, 260 }, { 568, 320 }, { 667, 375 }, { 705, 280 }, { 750, 323 }, { 800, 360 }, { 844, 390 }, { 874, 402 }, { 1024, 700 }, { 1280, 720 }, { 1366, 1024 }, { 390, 844 } }
for _, v in tamanhos do
	local w, h = v[1], v[2]
	local boxes = L.resolver(w, h, {})
	for name, a in boxes do
		assert(a.x - a.w / 2 >= 4 and a.x + a.w / 2 <= w - 4 and a.y - a.h / 2 >= 4 and a.y + a.h / 2 <= h - 4, name .. " fora da área segura em " .. w .. "x" .. h)
		assert(math.min(a.w, a.h) >= 40, name .. " menor que 40 px (dedo) em " .. w .. "x" .. h)
	end
	assert(L.valido(boxes, w, h), "botões se sobrepõem ou cobrem joystick/pulo em " .. w .. "x" .. h)
	if w >= 600 then
		-- golpes na faixa de baixo; DESPERTAR e pouco usados na faixa de cima; meio da luta livre
		for i = 1, 4 do
			assert(boxes["g" .. i].y > h * 0.72, "golpe " .. i .. " saiu da faixa de baixo em " .. w .. "x" .. h)
		end
		for _, n in { "ult", "stand", "mira", "shift", "pose" } do
			assert(boxes[n].y < h * 0.22, n .. " saiu da faixa de cima em " .. w .. "x" .. h)
		end
		local c = cobreCentro(boxes, w, h)
		assert(c <= 0.03, string.format("botões cobrem %.1f%% do centro em %dx%d", c * 100, w, h))
	end
end
-- tablet: reservas do Roblox grandes (pulo 120 px a 50/90 da borda)
local rg = L.reservas(1024, 700)
assert(rg[2].w >= 170 and rg[2].h >= 210 and rg[1].w >= 215, "reserva grande do pulo/joystick ausente no tablet")
local rp = L.reservas(705, 280)
assert(rp[2].w == 124 and rp[1].w == 162, "reserva de celular mudou")

------------------------------------------------------------------ 2) forma inclinada (geometria)
local UI = H.modulo("ReplicatedStorage/BB/Cliente/Interface")
local raiz = R.Instance.new("Frame")
raiz.Size = R.UDim2.fromOffset(120, 20)
local p = UI.paralelo(raiz, R.Color3.new(1, 0, 0), 0)
p.ajustar(120, 20)
local k = UI.HUD.inclinacao
local ang = math.atan(k)
local s = 20 * k
local a = p.corpo.Size.X.Scale * 120 / 2
assert(math.abs(p.corpo.Rotation - math.deg(ang)) < 1e-6, "ângulo do paralelogramo")
assert(p.corpo.Position.X.Scale == 0.5 and p.corpo.Position.Y.Scale == 0.5, "retângulo girado fora do centro")
local function u(px, py) return (px - 60) * math.cos(ang) + (py - 10) * math.sin(ang) end
assert(math.abs(u(s, 0) + a) < 1e-4 and math.abs(u(0, 20) + a) < 1e-4, "borda esquerda inclinada fora dos cantos")
assert(math.abs(u(120, 0) - a) < 1e-4 and math.abs(u(120 - s, 20) - a) < 1e-4, "borda direita inclinada fora dos cantos")
assert(p.corpo.Size.Y.Scale * 20 >= 2 * 140 and p.quadro.ClipsDescendants, "o recorte não segura o retângulo girado")
local barra = UI.barraInclinada(raiz, R.Vector2.new(200, 16), R.UDim2.new(), R.Color3.new(1, 0, 0))
barra.preenche.fracao(0.5)
assert(math.abs(barra.preenche.quadro.Size.X.Offset - (16 * k + (200 - 16 * k) * 0.5)) <= 0.5, "fração da barra")
barra.preenche.fracao(0)
assert(not barra.preenche.quadro.Visible, "barra vazia ainda aparece")
assert(UI.FACE.rotulo.Weight == R.Enum.FontWeight.Bold and string.find(UI.FACE.rotulo.Family, "RobotoCondensed", 1, true), "fonte dos rótulos")
assert(string.find(UI.FACE.destaque.Family, "Bangers", 1, true), "fonte de destaque")

------------------------------------------------------------------ 3) HUD real montado no celular
local T = 1000
local playerGui = R.Instance.new("Folder")
local corpo = R.Instance.new("Model")
local hum = R.Instance.new("Humanoid")
hum.Parent = corpo
local plr = { Name = "Kaique", DisplayName = "Kaique", UserId = 1, Character = corpo, WaitForChild = function() return playerGui end }
H.servicos.Players = { LocalPlayer = plr }
H.servicos.UserInputService.WindowFocusReleased = sinal()
H.servicos.UserInputService.LastInputTypeChanged = sinal()
H.servicos.ContextActionService = { BindAction = function() end }
H.servicos.GuiService = { MenuOpened = sinal() }
H.servicos.RunService.RenderStepped = captura(capt.RenderStepped)
H.servicos.RunService.Heartbeat = captura(capt.Heartbeat)
H.extras.workspace = setmetatable({ CurrentCamera = { ViewportSize = R.Vector2.new(W, Hh), GetPropertyChangedSignal = sinal }, GetServerTimeNow = function() return T end }, { __index = H.workspace })
local shift = false
local deps = {
	Som = { tocar = function() end },
	Camera = { travado = function() return false end, travar = function() end, shiftLock = function(v) if v ~= nil then shift = v end return shift end },
	Efeitos = { _modelosLutadores = function() return function() end end },
	Registro = { lutadores = function() return function() end end },
}
H.extras.require = function(n) return deps[rawget(n, "Name")] or H.require(n) end
-- recarrega Interface com a mesma fonte já trocada (cache novo para os módulos do cliente)
local Stands = H.modulo("ReplicatedStorage/BB/Stands")
local Golpes = H.modulo("ReplicatedStorage/BB/Golpes")
local Config = H.modulo("ReplicatedStorage/BB/Config")
local stand = Stands.get("STAR_PLATINUM")
local _, id2 = Golpes.doSlot(stand, 2)
local cds = { [id2] = 4.2 }
hum.MaxHealth = 100
hum.Health = 25
corpo:SetAttribute("BB_Stand", "STAR_PLATINUM")
corpo:SetAttribute("BB_Despertar", 64)
corpo:SetAttribute("BB_Evasiva", T + 2)
local Jogador = {
	standAtual = function() return stand end, desperto = function() return false end, ultUsada = function() return false end,
	cdRestante = function(id) return cds[id] or 0 end, bloqueando = function() return false end, soltarEntradas = function() end,
}
for _, f in { "m1", "bloquear", "dash", "golpe", "despertar", "alternarStand", "pose" } do Jogador[f] = function() end end
local HUD = H.moduloNovo("ReplicatedStorage/BB/Cliente/HUD")
local Controles = H.moduloNovo("ReplicatedStorage/BB/Cliente/Controles")
HUD.iniciar(Jogador)
Controles.iniciar(Jogador, HUD)
Controles.ativar(true)
shift = true
for _ = 1, 2 do
	for _, fn in capt.RenderStepped do fn(0.25) end
	for _, fn in capt.Heartbeat do fn(0.25) end
end
local hudGui = playerGui:FindFirstChild("BB_HUD")
local botGui = playerGui:FindFirstChild("BB_Botoes")
assert(hudGui and botGui, "telas do HUD/botões não foram criadas")
assert(hudGui:FindFirstChildOfClass("UIScale").Scale == 1, "no celular o HUD fica em escala 1 (px de celular)")
assert(botGui.ZIndexBehavior == R.Enum.ZIndexBehavior.Sibling, "botões precisam de ZIndex por irmão")
local vitais = hudGui:FindFirstChild("Vitais")
for _, n in { "AbaStand", "Nome", "Vida", "VidaNum", "Despertar", "Esquiva", "Gomo1", "Gomo10" } do
	assert(vitais:FindFirstChild(n), "falta " .. n .. " no bloco de vida")
end
assert(not hudGui:FindFirstChild("BarraGolpes").Visible, "barra de golpes do PC aparecendo no celular")
assert(vitais.AbaStand.Stand.Text == "STAR PLATINUM", "nome do Stand na aba")
assert(vitais.VidaNum.Text == "25" and vitais.VidaNum.TextColor3 == UI.HUD.vidaClara and hudGui.Vinheta.Visible, "vida baixa: número claro e vinheta vermelha")
assert(vitais.Despertar.Text == "DESPERTAR 64%", "texto do despertar: " .. vitais.Despertar.Text)
assert(vitais.Esquiva.Texto.Text == "ESQUIVA 2", "esquiva em recarga: " .. vitais.Esquiva.Texto.Text)
-- gomos: 6 cheios, o 7º pela metade, o resto vazio
local function transp(i) return vitais["Gomo" .. i].Paralelo.Corpo.BackgroundTransparency end
assert(transp(6) == 0 and transp(7) > 0 and transp(7) < 0.55 and transp(8) >= 0.75, "gomos do despertar")
-- cartões de golpe (toque): 2 em recarga mostra só o número; 1 pronto mostra o nome
local canvas = botGui:FindFirstChildOfClass("Frame")
local g1, g2 = canvas:FindFirstChild("g1"), canvas:FindFirstChild("g2")
assert(g1.Nome.Visible and g1.Nome.Text == "ORA RUSH" and not g1.Tempo.Visible, "golpe pronto")
assert(g2.Tempo.Visible and g2.Tempo.Text == "5" and not g2.Nome.Visible, "golpe em recarga")
assert(g2.Faixa.Size.X.Offset < g1.Faixa.Size.X.Offset, "faixa de recarga não diminuiu")
assert(g1.Selo.Paralelo.Corpo.BackgroundColor3 == stand.aura, "selo do golpe sem a cor do Stand")
-- DESPERTAR: tanque com 64% de líquido e aro calmo (ainda não cheio)
local ult = canvas:FindFirstChild("ult")
assert(math.abs(ult.Tanque.Liquido.Size.Y.Scale - 0.64) < 1e-6 and ult.Pct.Text == "64%", "tanque do despertar")
assert(canvas:FindFirstChild("m1").Aro.Color == stand.aura, "aro do ATACAR na cor do Stand")
assert(canvas:FindFirstChild("shift").BackgroundColor3 == UI.HUD.despertar, "SHIFT LOCK ligado não aparece")
-- despertar cheio: pisca e diz PRONTO; texto do HUD avisa
corpo:SetAttribute("BB_Despertar", Config.DESPERTAR.max)
for _, fn in capt.RenderStepped do fn(0.25) end
for _, fn in capt.Heartbeat do fn(0.25) end
assert(ult.Pct.Text == "PRONTO" and ult.Aro.Thickness > 2, "despertar cheio não chama atenção")
assert(string.find(vitais.Despertar.Text, "DESPERTAR!", 1, true), "texto de despertar pronto")

-- tipografia: só 2 fontes e nada abaixo do piso de leitura no celular
local function familia(o)
	local ok, f = pcall(function() return o.FontFace end)
	if ok and f and not string.find(f.Family, "LegacyArial", 1, true) then return f.Family end
	return R.Font.fromEnum(o.Font).Family
end
local textos = 0
for _, g in { hudGui, botGui } do
	for _, d in g:GetDescendants() do
		if d:IsA("TextLabel") then
			textos += 1
			local fam = familia(d)
			assert(string.find(fam, "Bangers", 1, true) or string.find(fam, "RobotoCondensed", 1, true), "fonte fora do par do HUD: " .. fam .. " em " .. d:GetFullName())
			local lim = d:FindFirstChildOfClass("UITextSizeConstraint")
			assert(not lim or lim.MaxTextSize >= 11, "texto pequeno demais: " .. d:GetFullName())
		end
	end
end
assert(textos >= 30, "poucos textos no HUD montado: " .. textos)

-- sobreposição: blocos fixos do HUD não ficam embaixo de nenhum botão (celulares comuns)
local function absoluto(o: any)
	local x, y = 0, 0
	local n = o
	local sz = tam(o)
	while n and n:IsA("GuiObject") do
		local pai = n.Parent
		local ps = if pai:IsA("GuiObject") then tam(pai) else R.Vector2.new(W, Hh)
		local nsz = tam(n)
		x += ps.X * n.Position.X.Scale + n.Position.X.Offset - n.AnchorPoint.X * nsz.X
		y += ps.Y * n.Position.Y.Scale + n.Position.Y.Offset - n.AnchorPoint.Y * nsz.Y
		n = pai
	end
	return x, y, sz.X, sz.Y
end
for _, v in { { 705, 280 }, { 750, 323 }, { 667, 375 }, { 844, 390 } } do
	W, Hh = v[1], v[2]
	local boxes = L.resolver(W, Hh, {})
	for _, nome in { "Vitais", "Abates", "Combo" } do
		local x, y, w, h = absoluto(hudGui:FindFirstChild(nome))
		for b, a in boxes do
			local sep = x + w <= a.x - a.w / 2 or a.x + a.w / 2 <= x or y + h <= a.y - a.h / 2 or a.y + a.h / 2 <= y
			assert(sep, string.format("%s encosta no botão %s em %dx%d", nome, b, W, Hh))
		end
	end
end

-- compatibilidade: registrarBotao (AJ17) continua funcionando
local velho = R.Instance.new("TextButton")
HUD.registrarBotao(9, velho, nil)
assert(velho:FindFirstChildOfClass("Frame") and velho:FindFirstChildOfClass("TextLabel"), "registrarBotao antigo quebrou")

print("HUD19 OK — layout em " .. #tamanhos .. " telas sem tapar o centro, barras inclinadas, recarga, despertar, 2 fontes, " .. textos .. " textos e nada embaixo dos botões")
