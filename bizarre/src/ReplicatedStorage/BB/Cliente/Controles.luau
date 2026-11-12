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

local Controles = {}

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
	local t = Toques.novo(aoApertar, aoSoltar)
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			t.comecar(input, false)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			t.comecar(input, true)
		end
	end)
end

local criarBotoesMoveis: () -> ()
function criarBotoesMoveis()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BB_Botoes"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.Enabled = ativo
	gui.Parent = plr:WaitForChild("PlayerGui")
	guiMovel = gui
	-- o botão de pulo do Roblox: pequeno (tela até 500 de altura) ou grande
	local inicio = os.clock()
	while workspace.CurrentCamera.ViewportSize.Y < 100 and os.clock() - inicio < 5 do
		task.wait(0.1)
	end
	local tela = workspace.CurrentCamera.ViewportSize
	local pequeno = math.min(tela.X, tela.Y) <= 500
	local pulo = if pequeno then 70 else 120
	local u = math.clamp(pulo, 64, 86)
	local puloCentro = if pequeno then Vector2.new(-95 + 35, -90 + 35) else Vector2.new(-170 + 60, -210 + 60)
	-- M1 grande à esquerda do pulo
	local m1c = puloCentro + Vector2.new(-u * 1.45, u * 0.05)
	local m1 = botaoRedondo(gui, "ATACAR", u * 1.3, m1c, Color3.fromRGB(230, 60, 70), 26)
	segurar(m1, function()
		segurandoM1 = true
		Jogador.m1()
	end, function()
		segurandoM1 = false
	end)
	-- bloquear em cima do M1, dash em cima do pulo
	local bloq = botaoRedondo(gui, "BLOQ", u * 0.88, m1c + Vector2.new(-u * 0.1, -u * 1.32), Color3.fromRGB(70, 140, 230))
	segurar(bloq, function()
		Jogador.bloquear(true)
	end, function()
		Jogador.bloquear(false)
	end)
	local dash = botaoRedondo(gui, "DASH", u * 0.88, puloCentro + Vector2.new(u * 0.05, -u * 1.2), Color3.fromRGB(240, 170, 40))
	segurar(dash, function()
		Jogador.dash()
	end)
	-- golpes 1-4 (2x2) acima
	local larg, alt = u * 1.3, u * 0.62
	local baseY = puloCentro.Y - u * 2.25
	local colunas = { puloCentro.X - u * 1.55, puloCentro.X - u * 0.15 }
	for i = 1, 4 do
		local col = colunas[(i - 1) % 2 + 1]
		local lin = if i <= 2 then baseY - alt - 8 else baseY
		local b = UI.botao(gui, "", UDim2.fromOffset(larg, alt), UDim2.new(1, col - larg / 2, 1, lin - alt / 2), Color3.fromRGB(110, 60, 200), { limite = 18, raio = 12 })
		b.BackgroundTransparency = 0.1
		local rot = b:FindFirstChild("Rotulo") :: TextLabel
		rot.Size = UDim2.fromScale(0.78, 0.8)
		rot.Position = UDim2.fromScale(0.2, 0.1)
		rot.TextWrapped = true
		local num = UI.texto(b, tostring(i), UDim2.fromScale(0.2, 0.6), UDim2.fromScale(0.02, 0.2), { cor = UI.CORES.dourado, z = 4 })
		local _ = num
		segurar(b, function()
			Jogador.golpe(i)
		end)
		HUD.registrarBotao(i, b, rot)
	end
	-- despertar / ULT
	local desp = botaoRedondo(gui, "DESPERTAR", u * 0.92, m1c + Vector2.new(-u * 1.25, -u * 1.15), Color3.fromRGB(150, 70, 230), 16)
	segurar(desp, function()
		Jogador.despertar()
	end)
	botaoDespertar = desp
	-- Stand, travar e pose (menores)
	local stand = botaoRedondo(gui, "STAND", u * 0.72, m1c + Vector2.new(-u * 1.35, u * 0.1), Color3.fromRGB(255, 120, 190), 16)
	segurar(stand, function()
		Jogador.alternarStand()
	end)
	local trava = botaoRedondo(gui, "MIRA", u * 0.7, m1c + Vector2.new(-u * 2.4, u * 0.15), Color3.fromRGB(190, 40, 55), 16)
	segurar(trava, function()
		travarProximo()
	end)
	-- AJUSTE-13: SHIFT LOCK (liga/desliga): câmera reta por cima do ombro, o personagem olha para onde
	-- a câmera olha. Dourado = ligado.
	local corShift = Color3.fromRGB(60, 60, 80)
	local shift = botaoRedondo(gui, "SHIFT LOCK", u * 0.66, m1c + Vector2.new(-u * 3.3, u * 0.15), corShift, 12)
	local function pintarShift()
		shift.BackgroundColor3 = if Camera.shiftLock() then UI.CORES.dourado else corShift
	end
	pintarShift()
	segurar(shift, function()
		Camera.shiftLock(not Camera.shiftLock())
		pintarShift()
		if HUD then
			HUD.aviso(if Camera.shiftLock() then "Shift Lock LIGADO" else "Shift Lock desligado")
		end
	end)
	local pose = botaoRedondo(gui, "POSE", u * 0.58, m1c + Vector2.new(-u * 2.3, -u * 0.95), Color3.fromRGB(60, 60, 80), 14)
	segurar(pose, function()
		Jogador.pose()
	end)
end

local function atualizarBotaoDespertar()
	local b = botaoDespertar
	if not b then
		return
	end
	local c = plr.Character
	local rot = b:FindFirstChild("Rotulo") :: TextLabel?
	if not c or not rot then
		return
	end
	local t = workspace:GetServerTimeNow()
	local desperto = (c:GetAttribute("BB_Desperto") or 0) > t
	local cheio = (c:GetAttribute("BB_Despertar") or 0) >= Config.DESPERTAR.max
	if desperto then
		rot.Text = if Jogador.ultUsada() then "DESPERTO" else "ULT!"
		b.BackgroundColor3 = if Jogador.ultUsada() then Color3.fromRGB(90, 70, 120) else UI.CORES.dourado
	elseif cheio then
		rot.Text = "DESPERTAR!"
		b.BackgroundColor3 = if math.floor(os.clock() * 4) % 2 == 0 then UI.CORES.dourado else Color3.fromRGB(150, 70, 230)
	else
		rot.Text = string.format("%d%%", math.floor(c:GetAttribute("BB_Despertar") or 0))
		b.BackgroundColor3 = Color3.fromRGB(70, 50, 100)
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
	end)
	local _ = GuiService
end

return Controles
