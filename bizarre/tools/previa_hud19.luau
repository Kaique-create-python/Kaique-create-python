-- AJUSTE-19 :: prévia do HUD de verdade, sem Roblox Studio.
-- Roda os módulos reais (Cliente/HUD, Cliente/Controles, Interface, Layout17...) no Lune com
-- serviços controlados, deixa a tela num estado de luta e grava a árvore de GUI montada em JSON.
-- tools/previa_hud19.py desenha esse JSON (Chromium) por cima de um cenário, no tamanho do celular.
-- Não é o renderizador do Roblox: serve para ver layout, cores, tamanhos e o que se sobrepõe.
--
-- uso: lune run bizarre/tools/previa_hud19.luau <largura> <altura> <saida.json> [STAND] [cena]
--   largura/altura = área segura do celular (ex.: 705 280 = Galaxy A06; 750 323 = iPhone 17 Pro)
--   cena: luta (padrão) | pronto (despertar cheio) | desperto (ULT pronta) | vazio (sem recargas)
--         | medir (luta sem combo/abates, que somem sozinhos: para medir quanto da tela fica coberto)
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local R = require("@lune/roblox")
local H = require("./harness")

local W = tonumber(process.args[1]) or 705
local Hh = tonumber(process.args[2]) or 280
local SAIDA = process.args[3] or "hud.json"
local STAND = process.args[4] or "STAR_PLATINUM"
local CENA = process.args[5] or "luta"
local PC = process.args[6] == "pc" -- teclado e mouse: sem botões de toque, barra de golpes embaixo
local T = 1000 -- relógio do servidor fixo: as recargas ficam iguais em toda prévia

-------------------------------------------------------------------------- sinais e tamanhos
local function sinal()
	return { Connect = function() return { Disconnect = function() end, Connected = true } end, Once = function() return { Disconnect = function() end } end, Wait = function() end }
end
local capturados = { RenderStepped = {}, Heartbeat = {} }
local function sinalCaptura(lista)
	return { Connect = function(_, fn) table.insert(lista, fn); return { Disconnect = function() end } end }
end
for _, ev in { "InputBegan", "InputEnded", "InputChanged", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "MouseEnter", "MouseLeave", "Activated", "TouchTap" } do
	R.implementProperty("GuiObject", ev, sinal)
end
R.implementMethod("Instance", "GetPropertyChangedSignal", sinal)
R.implementMethod("Path2D", "SetControlPoints", function(self, pontos)
	local lista = {}
	for _, p in pontos do
		local u = p.Position
		table.insert(lista, { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset })
	end
	self:SetAttribute("BB_Pontos", serde.encode("json", lista))
end)

-- AbsoluteSize não existe fora do motor: calcula pela árvore (o UIScale da tela já está "dentro")
local function tam(obj: any): any
	if obj:IsA("ScreenGui") then
		return R.Vector2.new(W, Hh)
	end
	local pai = obj.Parent
	local p = if pai and (pai:IsA("GuiObject") or pai:IsA("ScreenGui")) then tam(pai) else R.Vector2.new(W, Hh)
	local s = obj.Size
	return R.Vector2.new(p.X * s.X.Scale + s.X.Offset, p.Y * s.Y.Scale + s.Y.Offset)
end
for _, nome in { "HUD", "Controles", "Interface", "EditorToques17" } do
	local no = H.arvore.ReplicatedStorage.BB.Cliente[nome]
	if no then
		rawset(no, "fonte", (string.gsub(rawget(no, "fonte"), "([%w_]+)%.AbsoluteSize", "__tam(%1)")))
	end
end

-------------------------------------------------------------------------- serviços controlados
local playerGui = R.Instance.new("Folder")
playerGui.Name = "PlayerGui"
local personagem = R.Instance.new("Model")
personagem.Name = "Kaique"
local hum = R.Instance.new("Humanoid")
hum.Parent = personagem
local plr = {
	Name = "Kaique", DisplayName = "Kaique", UserId = 1, Character = personagem,
	WaitForChild = function(_, n) return if n == "PlayerGui" then playerGui else nil end,
	FindFirstChild = function(_, n) return if n == "PlayerGui" then playerGui else nil end,
	GetAttribute = function() return nil end,
}
H.servicos.Players = { LocalPlayer = plr, GetPlayers = function() return { plr } end }
H.servicos.UserInputService.WindowFocusReleased = sinal()
if PC then
	H.servicos.UserInputService.TouchEnabled = false
	H.servicos.UserInputService.KeyboardEnabled = true
	H.servicos.UserInputService.MouseEnabled = true
end
H.servicos.UserInputService.InputEnded = sinal()
H.servicos.UserInputService.LastInputTypeChanged = sinal()
H.servicos.UserInputService.PreferredInput = R.Enum.PreferredInput.Touch
H.servicos.ContextActionService = { BindAction = function() end, BindActionAtPriority = function() end, UnbindAction = function() end }
H.servicos.GuiService = { MenuOpened = sinal(), MenuClosed = sinal(), TopbarInset = R.Rect.new(0, 0, 0, 0), ReducedMotionEnabled = false, PreferredTransparency = 1 }
H.servicos.RunService.RenderStepped = sinalCaptura(capturados.RenderStepped)
H.servicos.RunService.Heartbeat = sinalCaptura(capturados.Heartbeat)
local camera = { ViewportSize = R.Vector2.new(W, Hh), CFrame = R.CFrame.new(), GetPropertyChangedSignal = function() return sinal() end }
H.extras.workspace = setmetatable({ CurrentCamera = camera, GetServerTimeNow = function() return T end }, { __index = H.workspace })
H.extras.__tam = tam

-- dependências pesadas (câmera, efeitos, som) não desenham nada no HUD: ficam de fora
local deps = {
	Som = { tocar = function() end },
	Camera = { travado = function() return false end, travar = function() end, shiftLock = function() return false end },
	Efeitos = { _modelosLutadores = function() return function() return nil end end },
	Registro = { lutadores = function() return function() return nil end end },
}
H.extras.require = function(n)
	return deps[rawget(n, "Name")] or H.require(n)
end

-------------------------------------------------------------------------- estado da luta
local Stands = H.modulo("ReplicatedStorage/BB/Stands")
local Config = H.modulo("ReplicatedStorage/BB/Config")
local Golpes = H.modulo("ReplicatedStorage/BB/Golpes")
local stand = assert(Stands.get(STAND), "Stand desconhecido: " .. STAND)
local cds = {} -- id do golpe -> segundos que faltam
for slot, resta in { [2] = 4.2, [3] = 9 } do
	local g, id = Golpes.doSlot(stand, slot)
	if g and id and (CENA == "luta" or CENA == "medir") then
		cds[id] = resta
	end
end
local despertar = if CENA == "pronto" then Config.DESPERTAR.max else 64
hum.MaxHealth = 100
hum.Health = if CENA == "vazio" then 100 else 68
personagem:SetAttribute("BB_Stand", STAND)
personagem:SetAttribute("BB_Despertar", despertar)
personagem:SetAttribute("BB_Guarda", 70)
personagem:SetAttribute("BB_Bloqueando", false)
personagem:SetAttribute("BB_Evasiva", if CENA == "luta" or CENA == "medir" then T + 2.4 else 0)
personagem:SetAttribute("BB_Desperto", if CENA == "desperto" then T + 14 else 0)

local Jogador = {
	standAtual = function() return stand end,
	desperto = function() return CENA == "desperto" end,
	ultUsada = function() return false end,
	cdRestante = function(id) return cds[id] or 0 end,
	bloqueando = function() return false end,
	soltarEntradas = function() end,
}
for _, f in { "m1", "bloquear", "dash", "golpe", "despertar", "alternarStand", "pose" } do
	Jogador[f] = function() end
end

local HUD = H.modulo("ReplicatedStorage/BB/Cliente/HUD")
local Controles = H.modulo("ReplicatedStorage/BB/Cliente/Controles")
HUD.iniciar(Jogador)
Controles.iniciar(Jogador, HUD)
Controles.ativar(true)
HUD.mostrar(true)
-- 12 quadros: o rastro do dano ainda aparece um pouco (como logo depois de apanhar)
for _ = 1, 12 do
	for _, fn in capturados.RenderStepped do fn(0.25) end
	for _, fn in capturados.Heartbeat do fn(0.25) end
end
if CENA == "luta" then
	HUD.combo(7)
	HUD.morte({ assassino = "Kaique", vitima = "Dio_Brando", standA = STAND, standV = "THE_WORLD" })
end

-------------------------------------------------------------------------- árvore -> JSON
local function cor(c) return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) } end
local function udim2(u) return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset } end
-- no Lune, Font e FontFace não se atualizam um ao outro (no Roblox sim): vale o que o código mudou
local function fonte(o)
	local ok, f = pcall(function() return o.FontFace end)
	if ok and f and not string.find(f.Family, "LegacyArial", 1, true) then
		return { f.Family, f.Weight.Name, f.Style.Name }
	end
	local okE, e = pcall(function() return R.Font.fromEnum(o.Font) end)
	if okE and e then return { e.Family, e.Weight.Name, e.Style.Name } end
	return { "rbxasset://fonts/families/LegacyArial.json", "Regular", "Normal" }
end
local function pegar(o, k) local ok, v = pcall(function() return o[k] end); return if ok then v else nil end

local function no(o)
	local d: any = { classe = o.ClassName, nome = o.Name, filhos = {} }
	if o:IsA("GuiObject") then
		d.tam = udim2(o.Size); d.pos = udim2(o.Position)
		d.ancora = { o.AnchorPoint.X, o.AnchorPoint.Y }
		d.rot = o.Rotation; d.z = o.ZIndex; d.ordem = o.LayoutOrder
		d.visivel = o.Visible; d.clip = o.ClipsDescendants
		d.fundo = cor(o.BackgroundColor3); d.fundoT = o.BackgroundTransparency
		if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
			d.texto = o.Text; d.textoCor = cor(o.TextColor3); d.textoT = o.TextTransparency
			d.fonte = fonte(o); d.escalado = o.TextScaled; d.textoTam = o.TextSize
			d.alinX = o.TextXAlignment.Name; d.alinY = o.TextYAlignment.Name
			d.quebra = o.TextWrapped; d.rico = o.RichText
		end
		if o:IsA("ImageLabel") or o:IsA("ImageButton") then
			d.imagem = o.Image; d.imagemT = o.ImageTransparency; d.imagemCor = cor(o.ImageColor3)
		end
		if o:IsA("CanvasGroup") then d.grupoT = o.GroupTransparency end
	elseif o:IsA("ScreenGui") then
		d.ativo = o.Enabled; d.ordemTela = o.DisplayOrder
	elseif o:IsA("UICorner") then
		d.raio = { o.CornerRadius.Scale, o.CornerRadius.Offset }
	elseif o:IsA("UIStroke") then
		d.cor = cor(o.Color); d.esp = o.Thickness; d.t = o.Transparency; d.modo = o.ApplyStrokeMode.Name
		d.posicao = (pegar(o, "BorderStrokePosition") or { Name = "Outer" }).Name
	elseif o:IsA("UIGradient") then
		local cs = {}
		for _, k in o.Color.Keypoints do table.insert(cs, { k.Time, cor(k.Value) }) end
		local ts = {}
		for _, k in o.Transparency.Keypoints do table.insert(ts, { k.Time, k.Value }) end
		d.cores = cs; d.transp = ts; d.rot = o.Rotation; d.offset = { o.Offset.X, o.Offset.Y }
		d.escala = pegar(o, "Scale") or 1; d.modo = (pegar(o, "TileMode") or { Name = "Clamp" }).Name
	elseif o:IsA("UIScale") then
		d.escala = o.Scale
	elseif o:IsA("UITextSizeConstraint") then
		d.max = o.MaxTextSize; d.min = o.MinTextSize
	elseif o:IsA("UIListLayout") then
		d.dir = o.FillDirection.Name; d.alinH = o.HorizontalAlignment.Name; d.alinV = o.VerticalAlignment.Name
		d.espaco = { o.Padding.Scale, o.Padding.Offset }; d.ordenar = o.SortOrder.Name
	elseif o:IsA("UIPadding") then
		d.pad = { o.PaddingLeft.Offset, o.PaddingRight.Offset, o.PaddingTop.Offset, o.PaddingBottom.Offset }
	elseif o:IsA("UIAspectRatioConstraint") then
		d.razao = o.AspectRatio
	elseif o:IsA("Path2D") then
		d.cor = cor(o.Color3); d.esp = o.Thickness; d.pontos = o:GetAttribute("BB_Pontos"); d.fechado = o.Closed
	end
	for _, f in o:GetChildren() do
		table.insert(d.filhos, no(f))
	end
	return d
end

local telas = {}
for _, g in playerGui:GetChildren() do
	if g:IsA("ScreenGui") then table.insert(telas, no(g)) end
end
fs.writeFile(SAIDA, serde.encode("json", { largura = W, altura = Hh, stand = STAND, cena = CENA .. (if PC then " (PC)" else ""), pc = PC, telas = telas }))
print(string.format("prévia HUD: %d telas, %s %dx%d -> %s", #telas, STAND, W, Hh, SAIDA))
