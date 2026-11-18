--!strict
-- PROJETO BASTIÃO :: efeitos do cliente (Etapa 3)
--  * Abertura do menu da bodycam (S7BodycamMenu): quando ele abre, um cartão escuro vira de lado
--    para a frente (como uma placa em 3D girando), camadas de profundidade se juntam atrás dele,
--    cantos de mira chegam das bordas da tela, uma linha de varredura passa e o menu aparece com
--    um clarão. Ao fechar, ele apaga como uma TV antiga (linha que encolhe até um ponto).
--    Nada do menu é trocado: tudo é desenhado numa tela própria por cima; só o painel do menu
--    fica invisível durante os 0,35 s do giro e volta sozinho (inclusive se o menu fechar antes).
--  * Clique da lanterna: quando o atributo FlashlightOn do jogador muda (o Sector7 continua dono
--    da lanterna; aqui só se escuta a mudança).
--  * Perseguição: quando o 731-A persegue perto, a tela escurece nas bordas e pulsa, e a imagem
--    perde cor e treme de leve no brilho, como luz falhando.
--  * Jumpscare: quando o 731-A agarra ESTE jogador (atributo BastiaoCapturado do servidor), a câmera
--    prende no rosto dele, treme cada vez mais, dá zoom, a imagem enche de estática e corta para o
--    preto no golpe; volta ao normal quando o personagem renasce.
--  * Pancadas na porta da oficina: a câmera de quem está perto treme a cada soco.
-- Pode ser exigido no servidor (teste na nuvem): nada roda até Efeitos.iniciar.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Efeitos = {}

local BRANCO = Color3.fromRGB(238, 238, 232)
local AMBAR = Color3.fromRGB(244, 186, 88)
local VERMELHO = Color3.fromRGB(232, 54, 42)
local CIANO = Color3.fromRGB(110, 220, 235)
local PRETO = Color3.new(0, 0, 0)

local function finito(v: any): boolean
	return type(v) == "number" and v == v and math.abs(v) < math.huge
end

-- Envelope puro: ataque curto, golpe amortecido e recuperação sem pulsos de luz.
-- A intensidade anterior preserva o efeito quando outro golpe chega durante o ataque.
function Efeitos.amostraImpacto(forca: number, idade: number, anterior: number?): any
	if not finito(forca) or not finito(idade) or idade < 0 then
		return { intensidade = 0, pitch = 0, roll = 0, duracao = 0 }
	end
	local f = math.clamp(forca, 0, 1)
	local duracao = 2 + 3.5 * f
	local base = if finito(anterior) then math.clamp(anterior :: number, 0, f) else 0
	local intensidade = 0
	if idade < 0.045 then
		local a = idade / 0.045
		intensidade = base + (f - base) * a * a * (3 - 2 * a)
	elseif idade < duracao then
		local r = math.clamp((idade - 0.045) / (duracao - 0.045), 0, 1)
		intensidade = f * (1 - r * r * (3 - 2 * r))
	end
	local kick = if idade < 0.65 then math.sin(idade * 24) * math.exp(-idade * 9) * (1 - idade / 0.65) else 0
	return { intensidade = intensidade, pitch = math.rad(-2.8) * f * kick,
		roll = math.rad(1.8) * f * kick, duracao = duracao }
end

export type Opcoes = {
	jogador: Player,
	playerGui: Instance,
	efeito: ((chave: string) -> any)?, -- toca um efeito do Som (nil se o som ainda não existe)
	ui: ((chave: string) -> ())?, -- clique de interface do Foley (reserva)
}

local function tween(inst: Instance, tempo: number, alvo: { [string]: any }, estilo: Enum.EasingStyle?, direcao: Enum.EasingDirection?)
	local t = TweenService:Create(inst, TweenInfo.new(tempo, estilo or Enum.EasingStyle.Quad, direcao or Enum.EasingDirection.Out), alvo)
	t:Play()
	return t
end

local function quadro(pai: Instance, nome: string, cor: Color3, transparencia: number): Frame
	local f = Instance.new("Frame")
	f.Name = nome
	f.BackgroundColor3 = cor
	f.BackgroundTransparency = transparencia
	f.BorderSizePixel = 0
	f.Active = false
	f.Parent = pai
	return f
end

local function contorno(pai: Instance, cor: Color3, transparencia: number, espessura: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = cor
	s.Transparency = transparencia
	s.Thickness = espessura
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = pai
	return s
end

-- canto em "L" (duas barras) usado como mira da bodycam
local function canto(pai: Instance, cor: Color3): Frame
	local c = Instance.new("Frame")
	c.Name = "Canto"
	c.BackgroundTransparency = 1
	c.Size = UDim2.fromOffset(22, 22)
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Parent = pai
	local h = quadro(c, "H", cor, 0)
	h.Size = UDim2.new(1, 0, 0, 2)
	local v = quadro(c, "V", cor, 0)
	v.Size = UDim2.new(0, 2, 1, 0)
	return c
end

function Efeitos.iniciar(op: Opcoes): { destroy: () -> (), impacto: (number, Vector3?) -> () }
	local conexoes: { RBXScriptConnection } = {}
	local vivo = true
	local function tocar(chave: string, reserva: string?)
		local ok, som = pcall(function()
			return if op.efeito then op.efeito(chave) else nil
		end)
		if (not ok or som == nil) and reserva and op.ui then
			pcall(op.ui, reserva)
		end
	end

	-- tela própria por cima do menu (o menu usa DisplayOrder 20)
	local fx = Instance.new("ScreenGui")
	fx.Name = "BastiaoMenuFX"
	fx.ResetOnSpawn = false
	fx.DisplayOrder = 21
	fx.IgnoreGuiInset = true
	fx.ScreenInsets = Enum.ScreenInsets.None
	fx.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	fx.Enabled = false
	fx.Parent = op.playerGui

	-- ===== menu =====
	local menuGui: ScreenGui? = nil
	local painel: GuiObject? = nil
	local geracao = 0
	local cantos: { Frame } = {}
	local seguindo: RBXScriptConnection? = nil
	local painelEscondido = false

	local function mostrarPainel()
		if painel and painelEscondido then
			painel.Visible = true
		end
		painelEscondido = false
	end

	local function limparCantos()
		if seguindo then
			seguindo:Disconnect()
			seguindo = nil
		end
		for _, c in cantos do
			c:Destroy()
		end
		table.clear(cantos)
	end

	local function retangulo(): (Vector2, Vector2)
		if painel and painel.AbsoluteSize.X > 40 and painel.AbsoluteSize.Y > 40 then
			return painel.AbsolutePosition, painel.AbsoluteSize
		end
		local tela = fx.AbsoluteSize
		return Vector2.new(tela.X * 0.5 - 270, tela.Y * 0.5 - 180), Vector2.new(540, 360)
	end

	local function abrir()
		geracao += 1
		local minha = geracao
		limparCantos()
		for _, filho in fx:GetChildren() do
			filho:Destroy()
		end
		fx.Enabled = true
		tocar("menu_abre", "ui_confirm")
		-- espera o menu terminar de montar: o painel tem altura automática e só ganha tamanho um
		-- ou dois quadros depois que o Sector7 liga a tela. Medir antes dava altura 0 e o cartão
		-- 3D saía invisível (só a piscada de TV do fechar aparecia).
		for _ = 1, 40 do
			RunService.Heartbeat:Wait()
			if minha ~= geracao or not vivo then
				return
			end
			if painel and painel.AbsoluteSize.X > 40 and painel.AbsoluteSize.Y > 40 then
				break
			end
		end
		local pos, tam = retangulo()
		local centro = pos + tam / 2
		local reduzido = GuiService.ReducedMotionEnabled
		local tela = fx.AbsoluteSize

		-- cantos de mira: chegam das bordas da tela e ficam presos nos cantos do menu
		local alvos = {
			Vector2.new(pos.X, pos.Y), Vector2.new(pos.X + tam.X, pos.Y),
			Vector2.new(pos.X, pos.Y + tam.Y), Vector2.new(pos.X + tam.X, pos.Y + tam.Y),
		}
		local origens = { Vector2.new(0, 0), Vector2.new(tela.X, 0), Vector2.new(0, tela.Y), Vector2.new(tela.X, tela.Y) }
		local giros = { 0, 90, 270, 180 }
		for i, alvo in alvos do
			local c = canto(fx, AMBAR)
			c.Rotation = giros[i]
			c.Position = UDim2.fromOffset(origens[i].X, origens[i].Y)
			tween(c, if reduzido then 0.01 else 0.42, { Position = UDim2.fromOffset(alvo.X, alvo.Y) }, Enum.EasingStyle.Quint)
			table.insert(cantos, c)
		end
		-- enquanto o menu estiver aberto, os cantos acompanham o painel (respiram de leve)
		seguindo = RunService.RenderStepped:Connect(function()
			if not painel or not painel.Parent then
				return
			end
			local p, t = painel.AbsolutePosition, painel.AbsoluteSize
			local folga = 6 + math.sin(os.clock() * 3) * 2
			local pontos = {
				Vector2.new(p.X - folga, p.Y - folga), Vector2.new(p.X + t.X + folga, p.Y - folga),
				Vector2.new(p.X - folga, p.Y + t.Y + folga), Vector2.new(p.X + t.X + folga, p.Y + t.Y + folga),
			}
			for i, c in cantos do
				if os.clock() - (c:GetAttribute("Desde") or 0) > 0.45 then
					c.Position = UDim2.fromOffset(pontos[i].X, pontos[i].Y)
				end
			end
		end)
		for _, c in cantos do
			c:SetAttribute("Desde", os.clock())
		end
		if reduzido or not painel then
			return
		end

		-- cartão que gira de lado para a frente (o painel real fica escondido nesse tempo)
		painel.Visible = false
		painelEscondido = true
		local cartao = quadro(fx, "Cartao", Color3.fromRGB(16, 18, 17), 0.05)
		cartao.AnchorPoint = Vector2.new(0.5, 0.5)
		cartao.Position = UDim2.fromOffset(centro.X, centro.Y)
		cartao.Size = UDim2.fromOffset(4, tam.Y)
		cartao.Rotation = -7
		cartao.ClipsDescendants = true
		contorno(cartao, BRANCO, 0.45, 1)
		local luz = Instance.new("UIGradient")
		luz.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 74, 70)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 156, 148)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 42, 40)),
		})
		luz.Offset = Vector2.new(-0.8, 0)
		luz.Parent = cartao
		-- linhas da tela da câmera
		for k = 1, 9 do
			local linha = quadro(cartao, "Linha", BRANCO, 0.9)
			linha.Size = UDim2.new(1, 0, 0, 1)
			linha.Position = UDim2.fromScale(0, k / 10)
		end
		-- camadas de profundidade: contornos atrás do cartão que se juntam nele (efeito extrudado)
		local camadas = {}
		for k = 1, 5 do
			local camada = quadro(fx, "Camada", PRETO, 1)
			camada.AnchorPoint = Vector2.new(0.5, 0.5)
			camada.Size = UDim2.fromOffset(tam.X, tam.Y)
			camada.Position = UDim2.fromOffset(centro.X + k * 9, centro.Y + k * 7)
			camada.Rotation = -7 + k
			camada.ZIndex = 0
			contorno(camada, if k % 2 == 0 then CIANO else AMBAR, 0.35 + k * 0.1, 1)
			table.insert(camadas, camada)
			tween(camada, 0.38 + k * 0.03, { Position = UDim2.fromOffset(centro.X, centro.Y), Rotation = 0 }, Enum.EasingStyle.Quint)
		end
		-- fantasmas vermelho/ciano (aberração da lente) piscando no giro
		local fantasmas = {}
		for k, cor in { VERMELHO, CIANO } do
			local f = quadro(fx, "Fantasma", cor, 1)
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Size = UDim2.fromOffset(tam.X, tam.Y)
			f.Position = UDim2.fromOffset(centro.X + (if k == 1 then -5 else 5), centro.Y)
			contorno(f, cor, 0.3, 2)
			table.insert(fantasmas, f)
		end
		tween(cartao, 0.34, { Size = UDim2.fromOffset(tam.X, tam.Y), Rotation = 0 }, Enum.EasingStyle.Back)
		tween(luz, 0.5, { Offset = Vector2.new(0.8, 0) })
		-- varredura: barra clara que desce pelo cartão
		local barra = quadro(cartao, "Varredura", BRANCO, 0.35)
		barra.Size = UDim2.new(1, 0, 0, 3)
		barra.Position = UDim2.fromScale(0, 0)
		tween(barra, 0.36, { Position = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)
		task.delay(0.12, function()
			for _, f in fantasmas do
				f.Position = UDim2.fromOffset(centro.X, centro.Y)
			end
		end)
		task.delay(0.36, function()
			if minha ~= geracao then
				return
			end
			mostrarPainel()
			-- clarão no lugar do menu e o cartão some
			local clarao = quadro(fx, "Clarao", BRANCO, 0.55)
			clarao.AnchorPoint = Vector2.new(0.5, 0.5)
			clarao.Position = UDim2.fromOffset(centro.X, centro.Y)
			clarao.Size = UDim2.fromOffset(tam.X, tam.Y)
			tween(clarao, 0.22, { BackgroundTransparency = 1 })
			tween(cartao, 0.18, { BackgroundTransparency = 1 })
			for _, d in cartao:GetDescendants() do
				if d:IsA("Frame") then
					tween(d, 0.18, { BackgroundTransparency = 1 })
				elseif d:IsA("UIStroke") then
					tween(d, 0.18, { Transparency = 1 })
				end
			end
			for _, c in camadas do
				c:Destroy()
			end
			for _, f in fantasmas do
				f:Destroy()
			end
			task.delay(0.3, function()
				cartao:Destroy()
				clarao:Destroy()
			end)
		end)
	end

	local function fechar()
		geracao += 1
		local minha = geracao
		mostrarPainel()
		local pos, tam = retangulo()
		limparCantos()
		for _, filho in fx:GetChildren() do
			filho:Destroy()
		end
		fx.Enabled = true
		tocar("ui_click", "ui_click")
		if GuiService.ReducedMotionEnabled then
			fx.Enabled = false
			return
		end
		-- desliga como TV antiga: vira uma linha e depois um ponto
		local centro = pos + tam / 2
		local tela = quadro(fx, "Desliga", BRANCO, 0.15)
		tela.AnchorPoint = Vector2.new(0.5, 0.5)
		tela.Position = UDim2.fromOffset(centro.X, centro.Y)
		tela.Size = UDim2.fromOffset(tam.X, tam.Y * 0.6)
		tween(tela, 0.12, { Size = UDim2.fromOffset(tam.X, 2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.12, function()
			tween(tela, 0.12, { Size = UDim2.fromOffset(3, 2), BackgroundTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
		task.delay(0.3, function()
			tween(tela, 0.15, { BackgroundTransparency = 1 })
		end)
		task.delay(0.5, function()
			if minha == geracao then
				for _, filho in fx:GetChildren() do
					filho:Destroy()
				end
				fx.Enabled = false
			end
		end)
	end

	local function ligarMenu(gui: Instance)
		if not gui:IsA("ScreenGui") or gui.Name ~= "S7BodycamMenu" then
			return
		end
		menuGui = gui
		local canvas = gui:WaitForChild("Canvas", 10)
		local overlay = canvas and canvas:WaitForChild("MenuOverlay", 10)
		local achado = overlay and overlay:WaitForChild("CameraMenu", 10)
		painel = if achado and achado:IsA("GuiObject") then achado else nil
		local estava = gui.Enabled
		table.insert(conexoes, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			if not vivo then
				return
			end
			if gui.Enabled and not estava then
				estava = true
				task.spawn(abrir)
			elseif not gui.Enabled and estava then
				estava = false
				fechar()
			end
		end))
	end
	local existente = op.playerGui:FindFirstChild("S7BodycamMenu")
	if existente then
		task.spawn(ligarMenu, existente)
	end
	table.insert(conexoes, op.playerGui.ChildAdded:Connect(function(filho)
		if filho.Name == "S7BodycamMenu" and filho ~= menuGui then
			task.spawn(ligarMenu, filho)
		end
	end))

	-- ===== lanterna =====
	local lanternaAntes = op.jogador:GetAttribute("FlashlightOn") == true
	table.insert(conexoes, op.jogador:GetAttributeChangedSignal("FlashlightOn"):Connect(function()
		local agora = op.jogador:GetAttribute("FlashlightOn") == true
		if agora ~= lanternaAntes then
			lanternaAntes = agora
			tocar(if agora then "lanterna_liga" else "lanterna_desliga", "ui_click")
		end
	end))

	-- ===== tremor de câmera (pancadas na porta, golpe do jumpscare) =====
	local tremorAte, tremorForca = 0, 0
	local function tremer(forca: number, duracao: number)
		local agora = os.clock()
		tremorForca = math.max(if agora < tremorAte then tremorForca else 0, forca)
		tremorAte = math.max(tremorAte, agora + duracao)
	end
	local NOME_TREMOR = "BastiaoTremor"
	local tremorCamera: Camera? = nil
	local tremorBase: CFrame? = nil
	local tremorFinal: CFrame? = nil
	local function desfazerTremor()
		local camera, base, final = tremorCamera, tremorBase, tremorFinal
		if camera and base and final and camera.CFrame:FuzzyEq(final, 1e-4) then
			camera.CFrame = base
		end
		tremorCamera, tremorBase, tremorFinal = nil, nil, nil
	end
	local function limparTremor()
		desfazerTremor()
		tremorAte, tremorForca = 0, 0
	end
	-- Apply order: Sector7 -> door shake -> injury. Unwind in reverse order.
	RunService:BindToRenderStep("BastiaoTremorUnwind", Enum.RenderPriority.Input.Value - 2, desfazerTremor)
	RunService:BindToRenderStep(NOME_TREMOR, Enum.RenderPriority.Last.Value, function()
		local agora = os.clock()
		if agora >= tremorAte then
			tremorForca = 0
			return
		end
		local camera = workspace.CurrentCamera
		local personagem = op.jogador.Character
		local h = personagem and personagem:FindFirstChildOfClass("Humanoid")
		if not camera or camera.CameraType ~= Enum.CameraType.Custom or not h or h.Health <= 0 then
			limparTremor()
			return
		end
		local movimento = op.jogador:GetAttribute("S7CameraMotion")
		local nivel = if finito(movimento) then math.clamp(movimento, 0, 1) else 1
		if GuiService.ReducedMotionEnabled or nivel <= 0 then return end
		local f = tremorForca * nivel * math.clamp((tremorAte - agora) / 0.2, 0, 1)
		tremorBase = camera.CFrame
		tremorFinal = camera.CFrame * CFrame.Angles((math.random() - 0.5) * 0.05 * f, (math.random() - 0.5) * 0.05 * f, (math.random() - 0.5) * 0.03 * f)
		tremorCamera = camera
		camera.CFrame = tremorFinal :: CFrame
	end)

	-- ===== jumpscare: quando o 731-A agarra ESTE jogador =====
	local susto = Instance.new("ScreenGui")
	susto.Name = "BastiaoJumpscare"
	susto.ResetOnSpawn = false
	susto.DisplayOrder = 40
	susto.IgnoreGuiInset = true
	susto.ScreenInsets = Enum.ScreenInsets.None
	susto.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	susto.Enabled = false
	susto.Parent = op.playerGui
	local clarao = quadro(susto, "Clarao", VERMELHO, 1)
	clarao.Size = UDim2.fromScale(1, 1)
	local escuro = quadro(susto, "Preto", PRETO, 1)
	escuro.Size = UDim2.fromScale(1, 1)
	escuro.ZIndex = 3
	local estatica: { Frame } = {}
	for _ = 1, 16 do
		local linha = quadro(susto, "Estatica", BRANCO, 1)
		linha.Size = UDim2.new(1, 0, 0, 3)
		linha.ZIndex = 4
		table.insert(estatica, linha)
	end
	local NOME_SUSTO = "BastiaoJumpscare"
	local emSusto = false

	-- ===== reação local a dano confirmado pelo Humanoid =====
	-- S7 prefix: BodycamLook pauses effects belonging to other camera owners.
	-- Separate instances preserve its existing grade, lens and motion blur.
	local impactoBlur = Instance.new("BlurEffect")
	impactoBlur.Name = "S7BastiaoImpactoBlur"
	impactoBlur.Size = 0
	impactoBlur.Enabled = false
	impactoBlur.Parent = Lighting
	local impactoCor = Instance.new("ColorCorrectionEffect")
	impactoCor.Name = "S7BastiaoImpactoCor"
	impactoCor.Enabled = false
	impactoCor.Parent = Lighting
	local inicioImpacto, forcaImpacto, baseImpacto = 0, 0, 0
	local ladoImpacto = 1
	local humanoideImpacto: Humanoid? = nil
	local saudeAntes = 0
	local conexoesPersonagem: { RBXScriptConnection } = {}
	local eqImpacto: EqualizerSoundEffect? = nil
	local zumbido: Sound? = nil
	local volumeZumbido = 0
	local camAplicada: Camera? = nil
	local baseCamera: CFrame? = nil
	local finalCamera: CFrame? = nil
	local function desfazerImpacto()
		local cam, base, final = camAplicada, baseCamera, finalCamera
		if cam and base and final and cam.CFrame:FuzzyEq(final, 1e-4) then
			cam.CFrame = base
		end
		camAplicada, baseCamera, finalCamera = nil, nil, nil
	end
	local function limparAudioImpacto()
		-- Only our EQ is removed; SoundGroup.Volume and other owners' effects are untouched.
		if eqImpacto then eqImpacto:Destroy(); eqImpacto = nil end
		if zumbido then
			if zumbido.Parent then zumbido:Stop(); zumbido:Destroy() end
			zumbido = nil
		end
	end
	local function limparImpacto()
		forcaImpacto, baseImpacto = 0, 0
		desfazerImpacto()
		impactoBlur.Size = 0
		impactoBlur.Enabled = false
		impactoCor.Enabled = false
		limparAudioImpacto()
	end
	local function podeImpacto(): boolean
		local cam = workspace.CurrentCamera
		local h = humanoideImpacto
		return vivo and not emSusto and h ~= nil and h.Health > 0 and h.Parent == op.jogador.Character
			and cam ~= nil and cam.CameraType == Enum.CameraType.Custom
	end
	local function impacto(forca: number, pos: Vector3?)
		if not finito(forca) or forca <= 0 or not podeImpacto() then return end
		local agora = os.clock()
		local atual = Efeitos.amostraImpacto(forcaImpacto, agora - inicioImpacto, baseImpacto).intensidade
		local nova = math.clamp(forca, 0, 1)
		-- A smaller rapid hit cannot reset a stronger recovery to a weaker peak.
		if nova <= atual or (agora - inicioImpacto < 0.045 and nova <= forcaImpacto) then return end
		inicioImpacto, forcaImpacto, baseImpacto = agora, nova, atual
		local cam = workspace.CurrentCamera
		if pos and typeof(pos) == "Vector3" and finito(pos.X) and finito(pos.Y) and finito(pos.Z) and cam then
			ladoImpacto = if cam.CFrame:PointToObjectSpace(pos).X < 0 then -1 else 1
		else ladoImpacto = -ladoImpacto end
		if not zumbido or not zumbido.Parent then
			local ok, s = pcall(function() return if op.efeito then op.efeito("impacto_zumbido") else nil end)
			if ok and typeof(s) == "Instance" and s:IsA("Sound") then
				zumbido = s
				volumeZumbido = s.Volume
			end
		end
	end
	local function desligarPersonagem()
		for _, c in conexoesPersonagem do c:Disconnect() end
		table.clear(conexoesPersonagem)
		humanoideImpacto = nil
		limparImpacto()
		limparTremor()
	end
	local function ligarPersonagem(personagem: Model)
		desligarPersonagem()
		local function ligarHumanoide(inst: Instance)
			if not vivo or personagem ~= op.jogador.Character or humanoideImpacto or not inst:IsA("Humanoid") then return end
			local h = inst :: Humanoid
			humanoideImpacto, saudeAntes = h, h.Health
			table.insert(conexoesPersonagem, h.HealthChanged:Connect(function(saude: number)
				if not finito(saude) then return end
				local perda = saudeAntes - saude
				saudeAntes = saude
				if saude <= 0 then limparImpacto(); limparTremor(); return end
				if perda > 0 and personagem == op.jogador.Character then
					local maxSaude = if finito(h.MaxHealth) then math.max(1, h.MaxHealth) else 100
					impacto(math.clamp(perda / maxSaude * 2.5, 0.1, 1), nil)
				end
			end))
		end
		table.insert(conexoesPersonagem, personagem.ChildAdded:Connect(ligarHumanoide))
		local h = personagem:FindFirstChildOfClass("Humanoid")
		if h then ligarHumanoide(h) end
	end
	if op.jogador.Character then ligarPersonagem(op.jogador.Character) end
	table.insert(conexoes, op.jogador.CharacterAdded:Connect(ligarPersonagem))
	table.insert(conexoes, op.jogador.CharacterRemoving:Connect(desligarPersonagem))
	-- Unwind injury first, door shake second, then Sector7's guarded Input-1 unwind.
	RunService:BindToRenderStep("BastiaoImpactoUnwind", Enum.RenderPriority.Input.Value - 3, desfazerImpacto)
	RunService:BindToRenderStep("BastiaoImpacto", Enum.RenderPriority.Last.Value + 2, function()
		if forcaImpacto <= 0 then return end
		if not podeImpacto() then limparImpacto(); return end
		local amostra = Efeitos.amostraImpacto(forcaImpacto, os.clock() - inicioImpacto, baseImpacto)
		local i = amostra.intensidade
		if os.clock() - inicioImpacto >= amostra.duracao then limparImpacto(); return end
		local reduzido = GuiService.ReducedMotionEnabled
		local movimento = op.jogador:GetAttribute("S7CameraMotion")
		local nivel = if finito(movimento) then math.clamp(movimento, 0, 1) else 1
		if reduzido then nivel = 0 end
		impactoBlur.Size = if not reduzido and op.jogador:GetAttribute("S7MotionBlur") ~= false then 18 * i else 0
		impactoBlur.Enabled = impactoBlur.Size > 0.01
		impactoCor.Enabled = i > 0.001
		impactoCor.Saturation = -0.3 * i
		impactoCor.Contrast = -0.08 * i
		impactoCor.Brightness = -0.035 * i
		local grupo = SoundService:FindFirstChild("BastiaoEfeitos")
		if eqImpacto and eqImpacto.Parent ~= grupo then eqImpacto:Destroy(); eqImpacto = nil end
		if not eqImpacto and grupo and grupo:IsA("SoundGroup") then
			eqImpacto = Instance.new("EqualizerSoundEffect")
			eqImpacto.Name = "S7BastiaoImpactoEQ"
			eqImpacto.Parent = grupo
		end
		if eqImpacto then
			eqImpacto.HighGain = -24 * i
			eqImpacto.MidGain = -9 * i
			eqImpacto.LowGain = -2 * i
		end
		if zumbido and zumbido.Parent then zumbido.Volume = volumeZumbido * i end
		if nivel > 0 and (amostra.pitch ~= 0 or amostra.roll ~= 0) then
			local cam = workspace.CurrentCamera :: Camera
			baseCamera = cam.CFrame
			finalCamera = cam.CFrame * CFrame.Angles(amostra.pitch * nivel, 0, amostra.roll * ladoImpacto * nivel)
			camAplicada = cam
			cam.CFrame = finalCamera :: CFrame
		end
	end)

	local function tempos(nome: string): { [string]: number }
		-- tempos do catálogo (Grip, Roar, Impact, CameraCut); reserva se não achar
		local t = { Grip = 1.0, Roar = 1.7, Impact = 2.0, CameraCut = 2.63, fim = 3.0 }
		local ok, catalogo = pcall(function()
			local pasta = ReplicatedStorage:FindFirstChild("BastiaoCompartilhado")
			local modulo = pasta and pasta:FindFirstChild("MonsterCatalog")
			return if modulo and modulo:IsA("ModuleScript") then require(modulo) :: any else nil
		end)
		local clip = if ok and type(catalogo) == "table" and type(catalogo.animations) == "table" then catalogo.animations[nome] else nil
		if type(clip) == "table" then
			t.fim = tonumber(clip.duration) or t.fim
			for _, m in clip.markers or {} do
				if type(m) == "table" and t[m.name] ~= nil and type(m.time) == "number" then
					t[m.name] = m.time
				end
			end
		end
		return t
	end
	local function jumpscare()
		if emSusto or not vivo then
			return
		end
		emSusto = true
		limparImpacto()
		limparTremor()
		local nome = op.jogador:GetAttribute("BastiaoCapturaAnimacao")
		local t = tempos(if type(nome) == "string" then nome else "30_JUMPSCARE_FRONTAL_GRAB")
		local camera = workspace.CurrentCamera
		local fovAntes = camera.FieldOfView
		local personagemAntes = op.jogador.Character
		camera.CameraType = Enum.CameraType.Scriptable
		susto.Enabled = true
		clarao.BackgroundColor3 = VERMELHO
		clarao.BackgroundTransparency = 0.3
		escuro.BackgroundTransparency = 1
		tween(clarao, 0.55, { BackgroundTransparency = 1 })
		tocar("jumpscare", nil) -- som do ElevenLabs quando existir; o MonstroSom já ruge na cabeça
		local inicio = os.clock()
		local golpeou = false
		local encerrado = false
		local function encerrar()
			if encerrado then
				return
			end
			encerrado = true
			RunService:UnbindFromRenderStep(NOME_SUSTO)
			local cam = workspace.CurrentCamera
			cam.CameraType = Enum.CameraType.Custom
			cam.FieldOfView = fovAntes
			local novo = op.jogador.Character
			local humanoide = novo and novo:FindFirstChildOfClass("Humanoid")
			if humanoide then
				cam.CameraSubject = humanoide
			end
			for _, linha in estatica do
				linha.BackgroundTransparency = 1
			end
			tween(escuro, 0.9, { BackgroundTransparency = 1 })
			task.delay(0.95, function()
				if encerrado and not emSusto then
					return
				end
				susto.Enabled = false
				emSusto = false
			end)
		end
		RunService:BindToRenderStep(NOME_SUSTO, Enum.RenderPriority.Last.Value + 1, function()
			local agora = os.clock() - inicio
			local historia = workspace:FindFirstChild("BastiaoHistoria")
			local pasta = historia and historia:FindFirstChild("Criatura")
			local monstro = pasta and pasta:FindFirstChild("Bastiao731A")
			local corpo = monstro and monstro:FindFirstChild("HumanoidRootPart")
			local personagem = op.jogador.Character
			local cabeca = personagem and (personagem:FindFirstChild("Head") or personagem:FindFirstChild("HumanoidRootPart"))
			local cam = workspace.CurrentCamera
			if corpo and corpo:IsA("BasePart") and cabeca and cabeca:IsA("BasePart") and not golpeou then
				local altura = tonumber(monstro:GetAttribute("BastiaoHeightStuds")) or corpo.Size.Y
				local rosto = corpo.Position + Vector3.new(0, altura * 0.3, 0)
				local olho = cabeca.Position + Vector3.new(0, 0.35, 0)
				local forca = if agora < t.Grip then 0.05 elseif agora < t.Impact then 0.14 + (agora - t.Grip) * 0.25 else 0.4
				local tremor = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * forca
				cam.CameraType = Enum.CameraType.Scriptable
				cam.CFrame = CFrame.lookAt(olho + tremor, rosto + tremor * 4)
				cam.FieldOfView = fovAntes + (42 - fovAntes) * math.clamp((agora - t.Grip * 0.4) / 1.1, 0, 1)
			end
			-- estática: aparece no rugido, toma a tela no golpe
			local chance = if agora < t.Roar then 0.05 elseif agora < t.Impact then 0.45 else 0.8
			for _, linha in estatica do
				linha.Position = UDim2.fromScale(0, math.random())
				linha.Size = UDim2.new(1, 0, 0, math.random(2, 7))
				linha.BackgroundTransparency = if math.random() < chance then 0.15 + math.random() * 0.6 else 1
			end
			if agora >= t.Roar and agora < t.Roar + 0.05 then
				clarao.BackgroundColor3 = VERMELHO
				clarao.BackgroundTransparency = 0.5
				tween(clarao, 0.3, { BackgroundTransparency = 1 })
			end
			if agora >= t.Impact and not golpeou then
				-- golpe: clarão branco e corte seco para o preto
				golpeou = true
				clarao.BackgroundColor3 = BRANCO
				clarao.BackgroundTransparency = 0
				tween(clarao, 0.18, { BackgroundTransparency = 1 })
				escuro.BackgroundTransparency = 0
			end
			if agora > t.fim + 6 then
				encerrar() -- reserva: se o renascer não chegar
			end
		end)
		-- volta quando o personagem renasce (ou se a captura for cancelada sem golpe)
		local conexao: RBXScriptConnection? = nil
		conexao = op.jogador.CharacterAdded:Connect(function(novo)
			if novo ~= personagemAntes then
				if conexao then
					conexao:Disconnect()
				end
				task.wait(0.2)
				encerrar()
			end
		end)
		table.insert(conexoes, conexao :: RBXScriptConnection)
	end
	local ultimoCapturado = op.jogador:GetAttribute("BastiaoCapturado")
	table.insert(conexoes, op.jogador:GetAttributeChangedSignal("BastiaoCapturado"):Connect(function()
		local valor = op.jogador:GetAttribute("BastiaoCapturado")
		if valor ~= ultimoCapturado and type(valor) == "number" then
			ultimoCapturado = valor
			task.spawn(jumpscare)
		end
	end))

	-- ===== perseguição: tela fecha nas bordas, perde cor e a luz falha =====
	local cor = Instance.new("ColorCorrectionEffect")
	cor.Name = "BastiaoTensao"
	cor.Enabled = false
	cor.Parent = Lighting
	local borda = Instance.new("ScreenGui")
	borda.Name = "BastiaoTensaoTela"
	borda.ResetOnSpawn = false
	borda.DisplayOrder = 9 -- abaixo do HUD da bodycam (10)
	borda.IgnoreGuiInset = true
	borda.ScreenInsets = Enum.ScreenInsets.None
	borda.Enabled = false
	borda.Parent = op.playerGui
	-- duas faixas escuras (laterais e cima/baixo) formam a borda que fecha
	local sombras = {}
	for _, giro in { 0, 90 } do
		local sombra = quadro(borda, "Sombra", PRETO, 1)
		sombra.Size = UDim2.fromScale(1, 1)
		local degrade = Instance.new("UIGradient")
		degrade.Rotation = giro
		degrade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.24, 1),
			NumberSequenceKeypoint.new(0.76, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
		degrade.Parent = sombra
		table.insert(sombras, sombra)
	end
	local intensidade = 0
	local acumulado = 0
	local ultimoMarcador: any = nil
	table.insert(conexoes, RunService.RenderStepped:Connect(function(dt)
		acumulado += dt
		if acumulado < 0.05 then
			return
		end
		local passo = acumulado
		acumulado = 0
		local alvo = 0
		local personagem = op.jogador.Character
		local raiz = personagem and personagem:FindFirstChild("HumanoidRootPart")
		local historia = workspace:FindFirstChild("BastiaoHistoria")
		local pasta = historia and historia:FindFirstChild("Criatura")
		local monstro = pasta and pasta:FindFirstChild("Bastiao731A")
		local corpo = monstro and monstro:FindFirstChild("HumanoidRootPart")
		if raiz and raiz:IsA("BasePart") and corpo and corpo:IsA("BasePart") then
			local estado = monstro:GetAttribute("BastiaoState")
			local d = (corpo.Position - raiz.Position).Magnitude
			local perto = math.clamp(1 - (d - 8) / 55, 0, 1)
			local marcador = monstro:GetAttribute("BastiaoMarkerSerial")
			if marcador ~= ultimoMarcador then
				ultimoMarcador = marcador
				local nomeMarcador = monstro:GetAttribute("BastiaoMarkerName")
				if (nomeMarcador == "DoorHit" or nomeMarcador == "Impact") and estado == "search" and d < 45 then
					tremer(1 - d / 60, 0.3)
				end
			end
			if estado == "chase" or estado == "attack" or estado == "alert" or estado == "capture" then
				alvo = perto
			elseif estado == "search" then
				alvo = perto * 0.45
			else
				alvo = perto * 0.25
			end
		end
		intensidade += (alvo - intensidade) * math.clamp(passo * 3, 0, 1)
		local ativo = intensidade > 0.02
		cor.Enabled = ativo
		borda.Enabled = ativo
		if ativo then
			local pulso = 0.5 + 0.5 * math.sin(os.clock() * (4 + intensidade * 5))
			local falha = if math.random() < intensidade * 0.12 then -0.18 * intensidade else 0
			cor.Saturation = -0.55 * intensidade
			cor.Contrast = 0.18 * intensidade
			cor.Brightness = -0.05 * intensidade + falha
			cor.TintColor = Color3.new(1, 1 - 0.12 * intensidade, 1 - 0.14 * intensidade)
			for _, sombra in sombras do
				sombra.BackgroundTransparency = math.clamp(1 - intensidade * (0.55 + 0.25 * pulso), 0, 1)
			end
		end
	end))

	local function destroy()
		if not vivo then
			return
		end
		vivo = false
		desligarPersonagem()
		RunService:UnbindFromRenderStep("BastiaoImpactoUnwind")
		RunService:UnbindFromRenderStep("BastiaoImpacto")
		RunService:UnbindFromRenderStep("BastiaoTremorUnwind")
		impactoBlur:Destroy()
		impactoCor:Destroy()
		for _, c in conexoes do
			c:Disconnect()
		end
		limparCantos()
		mostrarPainel()
		pcall(function()
			RunService:UnbindFromRenderStep(NOME_TREMOR)
		end)
		if emSusto then
			pcall(function()
				RunService:UnbindFromRenderStep(NOME_SUSTO)
				workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			end)
		end
		fx:Destroy()
		susto:Destroy()
		borda:Destroy()
		cor:Destroy()
	end
	return { destroy = destroy, impacto = impacto }
end

return Efeitos
