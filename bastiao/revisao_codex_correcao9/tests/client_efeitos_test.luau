-- Legendas que se quebram (Interface) e efeitos do cliente (Efeitos) no harness, sem motor.
local Harness = require("./client_harness")
local roblox = require("@lune/roblox")
local h = Harness.new()
-- o que o harness básico não tem e estes módulos usam
h.services.RunService.RenderStepped = h:signal()
local esperas = 0
local aoEsperar: (() -> ())? = nil
h.heartbeat.Wait = function()
	esperas += 1
	if aoEsperar then aoEsperar() end
	return 0
end
local passosRender = {}
h.services.RunService.BindToRenderStep = function(_, nome, _, fn) passosRender[nome] = fn end
h.services.RunService.UnbindFromRenderStep = function(_, nome) passosRender[nome] = nil end
local function renderizar() for _, fn in table.clone(passosRender) do fn(1 / 60) end end
h.services.ReplicatedStorage = h:new("ReplicatedStorage", "ReplicatedStorage")
h.services.GuiService.ReducedMotionEnabled = false -- o harness vem com movimento reduzido; aqui testa o giro 3D de verdade
h.environment.CFrame = roblox.CFrame
h.workspace.CurrentCamera = { CFrame = roblox.CFrame.new(), FieldOfView = 70, CameraType = roblox.Enum.CameraType.Custom }
h.services.Lighting = h:new("Lighting", "Lighting")
h.environment.ColorSequence = roblox.ColorSequence
h.environment.ColorSequenceKeypoint = roblox.ColorSequenceKeypoint
h.environment.NumberSequence = roblox.NumberSequence
h.environment.NumberSequenceKeypoint = roblox.NumberSequenceKeypoint

local texts = h:load("tests/_textos_base.luau")
local lang = "pt"
local Interface = h:load("src/client/Interface.luau")
local ui = Interface.criar(h.playerGui, texts, function() return lang end)
local quebras = 0
ui.definirSom(function(chave) if chave == "legenda_quebra" then quebras += 1 end end)
local caixa = h.playerGui:FindFirstChild("Fala", true)
local glifos = caixa:FindFirstChild("Glifos")
local caption = caixa:FindFirstChild("Texto")
local function letras()
	local n = 0
	for _, c in glifos:GetChildren() do if c.Name == "Letra" then n += 1 end end
	return n
end
for _, locale in { "pt", "en", "ru" } do
	lang = locale
	ui.fala("pavel_cafe", 2)
	h:tick(0.05)
	local frase = texts.de(locale).falas.pavel_cafe
	local semEspaco = utf8.len((string.gsub(frase, "%s", ""))) or 0
	assert(letras() == semEspaco, locale .. ": letras " .. letras() .. " ~= " .. semEspaco)
	assert(string.gsub(caption.Text, "\n", " ") == frase, "texto guardado diferente")
	assert(caption.TextTransparency == 1, "texto inteiro não pode aparecer por cima das letras")
	for _ = 1, 40 do h:tick(0.1) end -- passa a duração e a quebra
	assert(letras() == 0, locale .. ": letras não foram embora depois da quebra (" .. letras() .. ")")
end
assert(quebras == 3, "estalo da legenda tocou " .. quebras .. " vezes")
-- fala nova por cima de uma em andamento: a velha quebra rápido, a nova entra inteira
ui.fala("pavel_cafe", 3); h:tick(0.05)
ui.fala("pavel_canal", 3); h:tick(0.05)
for _ = 1, 6 do h:tick(0.1) end
for _ = 1, 6 do h:tick(0.1) end
assert(letras() == utf8.len((string.gsub(texts.de("ru").falas.pavel_canal, "%s", ""))), "troca de fala deixou letras velhas")

-- efeitos: menu, lanterna e perseguição
local menu = h:new("ScreenGui", "S7BodycamMenu", h.playerGui)
menu.Enabled = false
local canvas = h:new("Frame", "Canvas", menu)
local overlay = h:new("Frame", "MenuOverlay", canvas)
local painel = h:new("Frame", "CameraMenu", overlay)
painel.Visible = true
painel.AbsolutePosition = roblox.Vector2.new(370, 180)
painel.AbsoluteSize = roblox.Vector2.new(540, 360)
local tocados, uis = {}, {}
local Efeitos = h:load("src/client/Efeitos.luau")
local fx = Efeitos.iniciar({ jogador = h.player, playerGui = h.playerGui,
	efeito = function(k) table.insert(tocados, k); return nil end,
	ui = function(k) table.insert(uis, k) end })
h:flush()
painel.AbsoluteSize = roblox.Vector2.new(540, 0) -- o Sector7 só calcula a altura depois de ligar a tela
esperas = 0
aoEsperar = function() if esperas >= 3 then painel.AbsoluteSize = roblox.Vector2.new(540, 360) end end
menu.Enabled = true; menu:GetPropertyChangedSignal("Enabled"):Fire()
h:tick(0.01)
local cartao = h.playerGui:FindFirstChild("BastiaoMenuFX"):FindFirstChild("Cartao")
assert(cartao and cartao.Size.Y.Offset == 360, "cartão 3D usou o tamanho errado do painel: " .. tostring(cartao and cartao.Size))
aoEsperar = nil
h:tick(0.1)
assert(table.find(tocados, "menu_abre") and table.find(uis, "ui_confirm"), "menu não tocou o som de abrir (nem a reserva)")
local fxGui = h.playerGui:FindFirstChild("BastiaoMenuFX")
assert(fxGui and fxGui.Enabled, "tela de efeitos do menu não ligou")
assert(#fxGui:GetChildren() >= 4, "cantos/cartão do menu não apareceram")
h.services.RunService.RenderStepped:Fire(1 / 60)
h:tick(0.5)
assert(painel.Visible == true, "painel do menu ficou escondido depois da abertura")
menu.Enabled = false; menu:GetPropertyChangedSignal("Enabled"):Fire()
assert(table.find(uis, "ui_click"), "menu não tocou o som de fechar")
h:tick(0.6)
assert(fxGui.Enabled == false, "tela de efeitos ficou ligada depois de fechar")
-- abrir e fechar rápido não pode deixar o painel escondido
menu.Enabled = true; menu:GetPropertyChangedSignal("Enabled"):Fire(); h:tick(0.01)
menu.Enabled = false; menu:GetPropertyChangedSignal("Enabled"):Fire(); h:tick(0.6)
assert(painel.Visible == true, "fechar no meio do giro deixou o painel escondido")
-- lanterna
h.player:SetAttribute("FlashlightOn", true)
h.player:SetAttribute("FlashlightOn", false)
assert(table.find(tocados, "lanterna_liga") and table.find(tocados, "lanterna_desliga"), "clique da lanterna não tocou")
-- perseguição perto: tela pesa; longe: volta ao normal
local ana = h:character("Ana")
h.player.Character = ana
ana:FindFirstChild("HumanoidRootPart").Position = roblox.Vector3.new(0, 3, -260)
local historia = h.workspace:FindFirstChild("BastiaoHistoria") or h:new("Folder", "BastiaoHistoria", h.workspace)
local pasta = h:new("Folder", "Criatura", historia)
local monstro = h:new("Model", "Bastiao731A", pasta)
local corpo = h:new("Part", "HumanoidRootPart", monstro)
corpo.Position = roblox.Vector3.new(0, 4.7, -275)
monstro:SetAttribute("BastiaoState", "chase")
for _ = 1, 30 do h.services.RunService.RenderStepped:Fire(0.1) end
local cor = h.services.Lighting:FindFirstChild("BastiaoTensao")
assert(cor and cor.Enabled == true and cor.Saturation < -0.2, "perseguição perto não pesou a tela")
corpo.Position = roblox.Vector3.new(0, 4.7, -440)
monstro:SetAttribute("BastiaoState", "roam")
for _ = 1, 60 do h.services.RunService.RenderStepped:Fire(0.1) end
assert(cor.Enabled == false, "tela não voltou ao normal com o monstro longe")
-- pancada na porta da oficina perto: a câmera treme
local camera = h.workspace.CurrentCamera
corpo.Position = roblox.Vector3.new(60.5, 4.7, -319)
ana:FindFirstChild("HumanoidRootPart").Position = roblox.Vector3.new(75, 3, -319)
monstro:SetAttribute("BastiaoState", "search")
monstro:SetAttribute("BastiaoMarkerName", "DoorHit")
monstro:SetAttribute("BastiaoMarkerSerial", 1)
h.services.RunService.RenderStepped:Fire(0.1)
camera.CFrame = roblox.CFrame.new()
renderizar()
assert(camera.CFrame ~= roblox.CFrame.new(), "pancada na porta não tremeu a câmera")
-- jumpscare: o servidor marca este jogador como capturado
monstro:SetAttribute("BastiaoHeightStuds", 9.1)
monstro:SetAttribute("BastiaoState", "capture")
h:new("Part", "Head", ana).Position = roblox.Vector3.new(75, 4.5, -319)
h.player:SetAttribute("BastiaoCapturaAnimacao", "31_JUMPSCARE_FROM_BEHIND")
h.player:SetAttribute("BastiaoCapturado", 1)
h:flush()
local susto = h.playerGui:FindFirstChild("BastiaoJumpscare")
assert(susto and susto.Enabled, "jumpscare não abriu a tela")
assert(camera.CameraType == roblox.Enum.CameraType.Scriptable, "jumpscare não prendeu a câmera")
assert(table.find(tocados, "jumpscare"), "jumpscare não pediu o som")
for _ = 1, 40 do h.now += 0.1; renderizar() end
assert(susto:FindFirstChild("Preto").BackgroundTransparency == 0, "golpe do jumpscare não cortou para o preto")
assert(camera.FieldOfView < 60, "jumpscare não deu zoom no rosto")
-- renasce: câmera volta ao normal e a tela some
local novo = h:character("Ana2")
h.player.Character = novo
h.player.CharacterAdded:Fire(novo)
h:tick(1.2)
assert(camera.CameraType == roblox.Enum.CameraType.Custom and camera.FieldOfView == 70, "câmera não voltou depois do jumpscare")
assert(susto.Enabled == false, "tela do jumpscare ficou ligada")
assert(passosRender.BastiaoJumpscare == nil, "passo de câmera do jumpscare ficou preso")
fx.destroy()
assert(h.playerGui:FindFirstChild("BastiaoMenuFX") == nil, "destroy não limpou a tela de efeitos")
assert(passosRender.BastiaoTremor == nil, "destroy não soltou o tremor")
print("PASS legendas em 3 línguas que quebram, menu 3D (espera o painel; abrir/fechar/rápido), lanterna, perseguição, pancada na porta e jumpscare")
