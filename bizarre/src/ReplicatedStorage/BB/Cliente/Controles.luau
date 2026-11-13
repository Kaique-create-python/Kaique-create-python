-- BIZARRE BATTLEGROUNDS :: controles (PC, celular e controle)
-- PC: clique = M1 · F = bloquear · Q = dash/evasiva · 1-4 = golpes · G = despertar/ULT
--     E = Stand · B = pose · T = travar no inimigo
-- Celular: botões do lado direito em volta do botão de pulo do Roblox.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BB = script.Parent.Parent
local Config = require(BB:WaitForChild("Config"))
local UI = require(script.Parent:WaitForChild("Interface"))
local Toques = require(script.Parent:WaitForChild("Toques"))
local Camera = require(script.Parent:WaitForChild("Camera"))
local Efeitos = require(script.Parent:WaitForChild("Efeitos"))

local Layout17 = require(BB.Layout17)
local Preferencias17 = require(script.Parent.PreferenciasCliente17)
local Editor17 = require(script.Parent.EditorToques17)
local Controles = {}
local editor17 = nil
local botoes17 = {}
local canvas17 = nil
local antesEditor17 = false
local function aplicarLayout17()
 if not canvas17 or (editor17 and editor17.aberto) then return end
 local size=canvas17.AbsoluteSize
 if size.X<200 or size.Y<200 then return end
 for name,a in Layout17.resolver(size.X,size.Y,Preferencias17.valores().layout) do
  local b=botoes17[name]
  if b then b.Size=UDim2.fromOffset(a.w,a.h);b.Position=UDim2.fromOffset(a.x-a.w/2,a.y-a.h/2)end
  local c=cartoes17 and cartoes17[name];if c then c.ajustar()end
 end
end

local plr = Players.LocalPlayer
local Jogador: any = nil
local HUD: any = nil
local segurandoM1 = false
local ativo = false
local guiMovel: ScreenGui? = nil
local botaoDespertar: TextButton? = nil

local function travarProximo()
	if Camera.travado() then
		Camera.travar(nil)
		return
	end
	local c = plr.Character
	local raiz = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return
	end
	-- o melhor alvo: perto e no meio da tela (quem está atrás da câmera quase nunca é escolhido)
	local olharCam = workspace.CurrentCamera.CFrame.LookVector
	local melhor, nota = nil, math.huge
	for modelo in Efeitos._modelosLutadores() do
		if modelo ~= c and modelo:GetAttribute("BB_Lutador") then
			local r = modelo:FindFirstChild("HumanoidRootPart") :: BasePart?
			local h = modelo:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 then
				local v = r.Position - raiz.Position
				local dist = v.Magnitude
				if dist < 90 and dist > 0.1 then
					local frente = v.Unit:Dot(olharCam)
					local n = dist * (2.2 - frente)
					if n < nota then
						melhor, nota = modelo, n
					end
				end
			end
		end
	end
	Camera.travar(melhor)
	if melhor and HUD then
		HUD.aviso("Travado em " .. tostring(melhor:GetAttribute("BB_Nome") or melhor.Name))
	end
end
Controles.travarProximo = travarProximo

------------------------------------------------------------------------------------- teclado/controle
local function acao(nome: string, estado: Enum.UserInputState, _obj: InputObject)
	if not ativo then
		if nome=="BB_Bloq" and (estado==Enum.UserInputState.End or estado==Enum.UserInputState.Cancel) then Jogador.bloquear(false) end
		return Enum.ContextActionResult.Pass
	end
	local comecou = estado == Enum.UserInputState.Begin
	local terminou = estado == Enum.UserInputState.End or estado == Enum.UserInputState.Cancel
	if nome == "BB_M1" then
		if comecou then
			segurandoM1 = true
			Jogador.m1()
		elseif terminou then
			segurandoM1 = false
		end
		return Enum.ContextActionResult.Pass
	elseif nome == "BB_Bloq" then
		if comecou then
			Jogador.bloquear(true)
		elseif terminou then
			Jogador.bloquear(false)
		end
	elseif comecou then
		if nome == "BB_Dash" then
			Jogador.dash()
		elseif nome == "BB_G1" then
			Jogador.golpe(1)
		elseif nome == "BB_G2" then
			Jogador.golpe(2)
		elseif nome == "BB_G3" then
			Jogador.golpe(3)
		elseif nome == "BB_G4" then
			Jogador.golpe(4)
		elseif nome == "BB_Desp" then
			Jogador.despertar()
		elseif nome == "BB_Stand" then
			Jogador.alternarStand()
		elseif nome == "BB_Pose" then
			Jogador.pose()
		elseif nome == "BB_Trava" then
			travarProximo()
		end
	end
	return Enum.ContextActionResult.Sink
end

local function ligarTeclas()
	ContextActionService:BindAction("BB_Bloq", acao, false, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
	ContextActionService:BindAction("BB_Dash", acao, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("BB_G1", acao, false, Enum.KeyCode.One, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("BB_G2", acao, false, Enum.KeyCode.Two, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("BB_G3", acao, false, Enum.KeyCode.Three, Enum.KeyCode.ButtonR1)
	ContextActionService:BindAction("BB_G4", acao, false, Enum.KeyCode.Four, Enum.KeyCode.ButtonL1)
	ContextActionService:BindAction("BB_Desp", acao, false, Enum.KeyCode.G, Enum.KeyCode.DPadUp)
	ContextActionService:BindAction("BB_Stand", acao, false, Enum.KeyCode.E, Enum.KeyCode.DPadLeft)
	ContextActionService:BindAction("BB_Pose", acao, false, Enum.KeyCode.B, Enum.KeyCode.DPadRight)
	ContextActionService:BindAction("BB_Trava", acao, false, Enum.KeyCode.T, Enum.KeyCode.ButtonR3)
	ContextActionService:BindAction("BB_M1", acao, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
end

------------------------------------------------------------------------------------- celular
local function botaoRedondo(pai: Instance, texto: string, tam: number, centro: Vector2, cor: Color3, limite: number?): TextButton
	local b = UI.botao(pai, texto, UDim2.fromOffset(tam, tam), UDim2.new(1, centro.X - tam / 2, 1, centro.Y - tam / 2), cor, { redondo = true, limite = limite or 22, bordaEsp = 2.5 })
	b.BackgroundTransparency = 0.12
	return b
end

-- AJUSTE7: o botão solta quando o dedo sai da tela em qualquer lugar (não só em cima dele),
-- quando o jogo perde o foco, quando o menu abre e quando a tela gira (ver Toques)
local function segurar(b: TextButton, aoApertar: () -> (), aoSoltar: (() -> ())?)
	local t = Toques.novo(function()if ativo and not(editor17 and editor17.aberto)then aoApertar()end end, aoSoltar)
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			t.comecar(input, false)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			t.comecar(input, true)
		end
	end)
end

local criarBotoesMoveis: () -> ()
local cartoes17 = {}
local tanqueDespertar: Frame? = nil
local pctDespertar: TextLabel? = nil
-- botão ligado (SHIFT LOCK ativo): fundo dourado e texto escuro
local function pintarLigado(b: GuiObject, ligado: boolean)
 local rot=b:FindFirstChild("Rotulo")::TextLabel?
 b.BackgroundColor3=if ligado then UI.HUD.despertar else UI.HUD.vidro
 b.BackgroundTransparency=if ligado then .05 else .42
 if rot then
  rot.TextColor3=if ligado then UI.HUD.contorno else UI.HUD.texto
  local st=rot:FindFirstChildOfClass("UIStroke");if st then st.Transparency=if ligado then 1 else 0 end
 end
end
-- DESPERTAR: um "tanque" redondo que enche de dourado (CanvasGroup recorta o líquido no círculo)
local function montarDespertar(b: TextButton)
 b.BackgroundTransparency=1
 local g=Instance.new("CanvasGroup");g.Name="Tanque";g.Size=UDim2.fromScale(1,1)
 g.BackgroundColor3=UI.HUD.vidro;g.BackgroundTransparency=UI.HUD.vidroT;g.BorderSizePixel=0;g.ZIndex=b.ZIndex
 UI.circulo(g);g.Parent=b
 local liq=UI.frame(g,UDim2.fromScale(1,0),UDim2.fromScale(0,1),UI.HUD.despertar,.12)
 liq.Name="Liquido";liq.AnchorPoint=Vector2.new(0,1);liq.ZIndex=b.ZIndex
 UI.gradiente(liq,Color3.fromRGB(255,240,170),Color3.fromRGB(232,150,28),90)
 local rot=b:FindFirstChild("Rotulo")::TextLabel?
 if rot then rot.Size=UDim2.fromScale(.84,.26);rot.Position=UDim2.fromScale(.08,.22)end
 pctDespertar=UI.rotulo(b,"",UDim2.fromScale(.7,.3),UDim2.fromScale(.15,.48),{z=b.ZIndex+3,limite=15})
 pctDespertar.Name="Pct"
 tanqueDespertar=liq
end
function criarBotoesMoveis()
 local gui=Instance.new("ScreenGui")
 gui.Name="BB_Botoes";gui.ResetOnSpawn=false;gui.DisplayOrder=6;gui.Enabled=ativo
 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling -- filhos sempre por cima do pai (cartões e tanque)
 pcall(function()gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets end)
 gui.Parent=plr:WaitForChild("PlayerGui");guiMovel=gui
 local canvas=UI.frame(gui,UDim2.fromScale(1,1),UDim2.new(),UI.CORES.fundo,1)
 canvas17=canvas;botoes17={};cartoes17={}
 local defs={
  {"m1","ATACAR",function()segurandoM1=true;Jogador.m1()end,function()segurandoM1=false end},
  {"bloq","DEFESA",function()Jogador.bloquear(true)end,function()Jogador.bloquear(false)end},
  {"dash","DASH",function()Jogador.dash()end},
  {"ult","DESPERTAR",function()Jogador.despertar()end},
  {"stand","STAND",function()Jogador.alternarStand()end},
  {"mira","MIRA",travarProximo},
  {"shift","SHIFT LOCK",function()Camera.shiftLock(not Camera.shiftLock())end},
  {"pose","POSE",function()Jogador.pose()end},
 }
 for i=1,4 do table.insert(defs,{"g"..i,tostring(i),function()Jogador.golpe(i)end})end
 -- AJUSTE-19: golpes = cartões inclinados; combate = círculos de vidro; pouco usados = quadradinhos
 local pequenos={stand=true,mira=true,shift=true,pose=true}
 for _,d in defs do
  local skill=string.match(d[1],"^g(%d)$")
  local b
  if skill then
   local cartao=UI.cartaoGolpe(canvas,skill,{botao=true,nome=d[1]})
   cartoes17[d[1]]=cartao;b=cartao.raiz
   b:GetPropertyChangedSignal("Size"):Connect(cartao.ajustar)
   HUD.registrarCartao(tonumber(skill),cartao)
  else
   b=UI.botaoRedondo(canvas,d[2],{nome=d[1],quadrado=pequenos[d[1]],raio=10,quebrar=d[1]=="shift",
    limite=if d[1]=="m1"then 17 elseif pequenos[d[1]]then 11 else 13,
    transp=if pequenos[d[1]]then .42 else nil,
    aroEsp=if d[1]=="m1"then 2.5 else 1.5,aroT=if d[1]=="m1"then .1 elseif pequenos[d[1]]then .72 else .55})
   if d[1]=="ult"then botaoDespertar=b;montarDespertar(b)end
  end
  b.Name=d[1];botoes17[d[1]]=b
  segurar(b,d[3],d[4])
 end
 aplicarLayout17()
 canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(aplicarLayout17)
 editor17=Editor17.novo(canvas,botoes17,function()
  antesEditor17=ativo;Controles.soltarTudo();ativo=false;HUD.mostrar(false)
 end,function()
  ativo=antesEditor17;HUD.mostrar(ativo);if guiMovel then guiMovel.Enabled=ativo end
  aplicarLayout17()
 end)
end

function Controles.editar()
 if editor17 and guiMovel then guiMovel.Enabled=true;editor17:abrir()end
end
function Controles.editando(): boolean return editor17~=nil and editor17.aberto end

local function atualizarBotaoDespertar()
	local b = botaoDespertar
	if not b then
		return
	end
	local c = plr.Character
	local rot = b:FindFirstChild("Rotulo") :: TextLabel?
	local aro = b:FindFirstChild("Aro") :: UIStroke?
	if not c or not rot then
		return
	end
	local t = workspace:GetServerTimeNow()
	local desperto = (c:GetAttribute("BB_Desperto") or 0) > t
	local valor = c:GetAttribute("BB_Despertar") or 0
	local cheio = valor >= Config.DESPERTAR.max
	local nivel, pct, piscar = 0, "", false
	if desperto then
		local resta = (c:GetAttribute("BB_Desperto") :: number) - t
		nivel = math.clamp(resta / Config.DESPERTAR.duracao, 0, 1)
		rot.Text = if Jogador.ultUsada() then "DESPERTO" else "ULT!"
		pct = string.format("%ds", math.ceil(resta))
		piscar = not Jogador.ultUsada()
	elseif cheio then
		nivel = 1
		rot.Text = "DESPERTAR"
		pct = "PRONTO"
		piscar = true
	else
		nivel = math.clamp(valor / Config.DESPERTAR.max, 0, 1)
		rot.Text = "DESPERTAR"
		pct = string.format("%d%%", math.floor(valor))
	end
	if tanqueDespertar then
		tanqueDespertar.Size = UDim2.fromScale(1, nivel)
	end
	if pctDespertar then
		pctDespertar.Text = pct
	end
	if aro then
		local brilho = piscar and math.floor(os.clock() * 4) % 2 == 0
		aro.Color = if piscar then (if brilho then UI.HUD.texto else UI.HUD.despertar) else Color3.fromRGB(255, 255, 255)
		aro.Thickness = if piscar then 2.5 else 1.5
		aro.Transparency = if piscar then 0 else 0.55
	end
end

local function soltarTudo()
	Toques.soltarTudo()
	segurandoM1 = false
	if Jogador then
		if Jogador.soltarEntradas then Jogador.soltarEntradas() elseif Jogador.bloqueando() then Jogador.bloquear(false) end
	end
end
Controles.soltarTudo = soltarTudo

function Controles.ativar(sim: boolean)
	ativo = sim
	if guiMovel then
		guiMovel.Enabled = sim
	end
	if not sim then
		soltarTudo()
	end
end

-- a tela mudou de tamanho (girou, janela dividida): refaz os botões no lugar certo
local function refazerBotoes()
	soltarTudo()
 if editor17 then editor17:destruir();editor17=nil end
	if guiMovel then
		guiMovel:Destroy()
		guiMovel = nil
	end
	Toques.esquecerTodos()
	criarBotoesMoveis()
end

function Controles.iniciar(jogador: any, hud: any)
	Jogador = jogador
	HUD = hud
	ligarTeclas()
 Preferencias17.observar(function()aplicarLayout17()end)
	if UserInputService.TouchEnabled then
		criarBotoesMoveis()
		local cam = workspace.CurrentCamera
		local ultimoTam = cam.ViewportSize
		local pedido = 0
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			pedido += 1
			local meu = pedido
			task.delay(0.4, function()
				local novo = workspace.CurrentCamera.ViewportSize
				if meu == pedido and (math.abs(novo.X - ultimoTam.X) > 8 or math.abs(novo.Y - ultimoTam.Y) > 8) then
					ultimoTam = novo
					refazerBotoes()
				end
			end)
		end)
	end
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			Toques.terminou(input, false)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			Toques.terminou(input, true)
		end
	end)
	UserInputService.WindowFocusReleased:Connect(soltarTudo)
	pcall(function()
		GuiService.MenuOpened:Connect(soltarTudo)
	end)
	-- segurar o ataque continua o combo
	local ultimo = 0
	RunService.Heartbeat:Connect(function()
		if ativo and segurandoM1 and os.clock() - ultimo > 0.1 then
			ultimo = os.clock()
			Jogador.m1()
		end
		atualizarBotaoDespertar()
  local shift=botoes17.shift
  if shift then pintarLigado(shift,Camera.shiftLock())end
  local m1=botoes17.m1;local st=Jogador and Jogador.standAtual and Jogador.standAtual()
  local aroM1=m1 and m1:FindFirstChild("Aro")::UIStroke?
  if aroM1 and st and st.aura then aroM1.Color=st.aura end
	end)
	local _ = GuiService
end

return Controles
