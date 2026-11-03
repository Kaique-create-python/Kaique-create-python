-- OI3 :: painel de ADM (AJUSTE-10) — para testar o jogo sem passar fase por fase
-- Só aparece para quem é ADM (o servidor marca o jogador com o atributo OI3_Admin e confere TODO pedido).
-- Botão "ADM" no canto de cima → painel com:
--  * IR PARA: tarde, jantar, ritual, qualquer missão e qualquer passo, final, menu (modo teste: não salva)
--  * MISSÃO ATUAL: pular passo, reiniciar passo, próxima/anterior, chamar a sombra, pular cutscene
--  * EU: imortal, correr rápido, voar atravessando paredes, ir até o objetivo, voltar ao início da sala
--  * MONSTRO: ver o monstro na sua frente (poses), espiar você, susto, medo, TROCAR o modelo do monstro
--  * SONS E TELA: testar os sons gravados, dia/noite, dar ADM para alguém
-- Também dá para digitar no chat: /adm, /ir tarde, /missao 3 2, /passo, /proxima, /imortal, /voar ...

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local OI3 = script.Parent.Parent
local MissoesDados = require(OI3.Missoes)
local Interface = require(script.Parent.Interface)
local Som = require(script.Parent.Som)
local Medo = require(script.Parent.Medo)
local Cutscene = require(script.Parent.Cutscene)
local Iluminacao = require(script.Parent.Iluminacao)
local PrimeiraPessoa = require(script.Parent.PrimeiraPessoa)
local MC = require(script.Parent.MissoesCliente)
local Capitulo1 = require(script.Parent.Capitulo1)

local AdminCliente = {}

local COR = Interface.COR
local FONTE = Interface.FONTE
local RGB = Color3.fromRGB
local V3 = Vector3.new
local lp = Players.LocalPlayer

local estado = {
	ctx = nil :: any,
	tela = nil :: ScreenGui?,
	botaoAdm = nil :: TextButton?,
	painel = nil :: Frame?,
	status = nil :: TextLabel?,
	crianca = "KE",
	missaoSel = 1,
	listaPassos = nil :: Frame?,
	listaMonstros = nil :: Frame?,
	imortal = false,
	rapido = false,
	voando = false,
	voo = {} :: any,
	visor = {} :: any,
	botoes = {} :: { [string]: TextButton },
	relatorio = nil :: TextLabel?,
}

-- função pura (testável): lê um comando digitado no chat → (comando, argumentos)
function AdminCliente.lerComando(texto: string): (string?, { string })
	local partes = {}
	for p in string.gmatch(texto, "%S+") do
		table.insert(partes, p)
	end
	if #partes == 0 or string.sub(partes[1], 1, 1) ~= "/" then
		return nil, {}
	end
	local cmd = string.lower(string.sub(partes[1], 2))
	table.remove(partes, 1)
	return cmd, partes
end

local function ehAdmin(): boolean
	return lp:GetAttribute("OI3_Admin") == true
end

local function mensagem(texto: string, ok: boolean?)
	if estado.status then
		estado.status.Text = texto
		estado.status.TextColor3 = if ok == false then COR.destaqueClaro else COR.texto
	end
	print("[OI3 ADM] " .. texto)
end

local function servidor(cmd: string, args: any?)
	local r = estado.ctx and estado.ctx.remoto
	if r then
		r:FireServer(cmd, args or {})
	end
end

---------------------------------------------------------------------------
-- PULOS (o servidor muda a fase; o aparelho só se arruma antes)
---------------------------------------------------------------------------
local function prepararPulo(destino: string)
	local ctx = estado.ctx
	if ctx.estado() == "menu" then
		ctx.sairDoMenu()
	end
	if Cutscene.ativa() then
		Cutscene.pular()
		task.wait(0.6)
	end
	if not (MC.ativo() and (destino == "missao" or destino == "final")) then
		Capitulo1.parar()
	end
end

function AdminCliente.irPara(destino: string, n: number?, i: number?)
	if destino == "menu" then
		if estado.ctx.estado() ~= "menu" then
			mensagem("Voltando ao menu...")
			task.spawn(estado.ctx.voltarAoMenu)
		end
		return
	end
	task.spawn(function()
		mensagem("Indo para " .. destino .. (if n then " " .. n .. (if i then " passo " .. i else "") else "") .. "...")
		prepararPulo(destino)
		servidor("ir", { destino = destino, n = n, i = i, crianca = estado.crianca })
	end)
end

---------------------------------------------------------------------------
-- FERRAMENTAS LOCAIS (só no seu aparelho)
---------------------------------------------------------------------------
local function personagem(): (Model?, Humanoid?, BasePart?)
	local char = lp.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return char, hum, if r and r:IsA("BasePart") then r else nil
end

-- voar atravessando paredes (para onde a câmera olha)
function AdminCliente.voar(sim: boolean)
	local v = estado.voo
	if v.conexao then
		v.conexao:Disconnect()
		v.conexao = nil
	end
	for _, x in { v.lv, v.av, v.att } do
		if x then
			x:Destroy()
		end
	end
	v.lv, v.av, v.att = nil, nil, nil
	local char, hum, r = personagem()
	estado.voando = sim and r ~= nil
	if not (char and hum and r) then
		return
	end
	if not sim then
		hum.PlatformStand = false
		for _, nome in { "HumanoidRootPart", "Torso", "Head", "UpperTorso", "LowerTorso" } do
			local p = char:FindFirstChild(nome)
			if p and p:IsA("BasePart") then
				p.CanCollide = true
			end
		end
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "OI3_AdmVoo"
	att.Parent = r
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = Vector3.zero
	lv.Parent = r
	local av = Instance.new("AngularVelocity")
	av.Attachment0 = att
	av.MaxTorque = math.huge
	av.AngularVelocity = Vector3.zero
	av.Parent = r
	v.att, v.lv, v.av = att, lv, av
	hum.PlatformStand = true
	v.conexao = RunService.Stepped:Connect(function()
		if not char.Parent then
			return
		end
		for _, p in char:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
			end
		end
		local cam = workspace.CurrentCamera
		local md = hum.MoveDirection
		local vel = Vector3.zero
		if md.Magnitude > 0.05 then
			local look = cam.CFrame.LookVector
			local right = cam.CFrame.RightVector
			local frente = V3(look.X, 0, look.Z)
			local direita = V3(right.X, 0, right.Z)
			frente = if frente.Magnitude > 0.01 then frente.Unit else V3(0, 0, -1)
			direita = if direita.Magnitude > 0.01 then direita.Unit else V3(1, 0, 0)
			vel = (look * md:Dot(frente) + right * md:Dot(direita)) * 30
		end
		lv.VectorVelocity = vel
	end)
end

function AdminCliente.irObjetivo()
	local p = MC.pontoObjetivo()
	if p then
		MC.levarPerto(p)
		mensagem("Você foi levado até o objetivo.")
	else
		mensagem("Não achei o objetivo agora (talvez seja uma cena).", false)
	end
end

-- VER O MONSTRO na sua frente e trocar as poses
local POSES_VISOR = { "parado", "andando", "contorcendo", "espiando você", "investida (susto)" }

local function pararVisor()
	local v = estado.visor
	if v.conexao then
		v.conexao:Disconnect()
	end
	if v.monstro then
		pcall(function()
			v.monstro:destruir()
		end)
	end
	if v.pasta then
		v.pasta:Destroy()
	end
	estado.visor = {}
end

function AdminCliente.verMonstro(variante: string?)
	pararVisor()
	local cam = workspace.CurrentCamera
	local look = cam.CFrame.LookVector
	local frente = V3(look.X, 0, look.Z)
	frente = if frente.Magnitude > 0.01 then frente.Unit else V3(0, 0, -1)
	local base = cam.CFrame.Position + frente * 9
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { lp.Character :: any }
	local hit = workspace:Raycast(base + V3(0, 4, 0), V3(0, -60, 0), params)
	local pes = if hit then hit.Position else base - V3(0, 4.5, 0)
	local pasta = Instance.new("Folder")
	pasta.Name = "OI3_AdmMonstro"
	pasta.Parent = workspace
	local Monstro = require(script.Parent.Monstro)
	local ok, a = pcall(Monstro.novo, pasta, pes, cam.CFrame.Position, variante)
	if not ok or not a then
		pasta:Destroy()
		mensagem("O monstro não apareceu: " .. tostring(a), false)
		return
	end
	a:semMedo()
	local v = estado.visor
	v.monstro, v.pasta, v.pose, v.pes = a, pasta, 1, pes
	v.conexao = RunService.RenderStepped:Connect(function()
		if a.raiz.Parent then
			a:passo()
		end
	end)
	local pastaAtores = ReplicatedStorage:FindFirstChild("OI3_Atores")
	local ativo = variante or (pastaAtores and pastaAtores:GetAttribute("MonstroAtivo")) or "?"
	local nome = a.modelo:GetAttribute("NomeMonstro") or ativo
	mensagem("Monstro: " .. tostring(nome) .. " · pose: parado (toque PRÓXIMA POSE)")
end

function AdminCliente.proximaPose()
	local v = estado.visor
	local a = v.monstro
	if not a then
		AdminCliente.verMonstro()
		return
	end
	v.pose = (v.pose % #POSES_VISOR) + 1
	local nome = POSES_VISOR[v.pose]
	local cam = workspace.CurrentCamera
	if a.espiada then
		a:pararEspiar()
	end
	if nome == "parado" then
		a.poseAnterior, a.poseNome, a.misturaPose = a.poseNome, "dino", 0
		a.olharCabeca = nil
	elseif nome == "andando" then
		local pes = v.pes :: Vector3
		task.spawn(function()
			local lado = cam.CFrame.RightVector
			for _ = 1, 2 do
				if not a.raiz.Parent then
					return
				end
				task.wait(a:andar(pes + V3(lado.X, 0, lado.Z) * 7, 4.5))
				task.wait(a:andar(pes - V3(lado.X, 0, lado.Z) * 7, 4.5))
			end
			if a.raiz.Parent then
				a:andar(pes, 4.5)
			end
		end)
	elseif nome == "contorcendo" then
		a:contorcer(4)
	elseif nome == "espiando você" then
		-- chega perto e encosta o rosto na sua frente (como na fresta do armário)
		local olho = cam.CFrame.Position
		local look = cam.CFrame.LookVector
		local frente = V3(look.X, 0, look.Z)
		frente = if frente.Magnitude > 0.01 then frente.Unit else V3(0, 0, -1)
		local pes = v.pes :: Vector3
		task.spawn(function()
			task.wait(a:andar(V3(olho.X, pes.Y, olho.Z) + frente * 3.6, 5))
			if a.raiz.Parent then
				a:espiar(olho + frente * 2.2, olho, "fresta", 6)
			end
		end)
	else
		a:investida()
	end
	mensagem("Pose: " .. nome)
end

-- AJUSTE-11: confere as vozes: quais falas tocam, quais ainda não foram gravadas, quais arquivos não
-- carregam (em análise no Roblox ou bloqueados) e quais estão usando a voz antiga de reserva
local NOMES_VOZ = { vozes1 = "vozes 1", vozes2 = "vozes 2", vozes3 = "vozes 3 (menino novo)", historia = "história" }

function AdminCliente.relatorioVozes(): string
	local Dialogos = require(OI3.Dialogos)
	local AudioMapa = require(OI3.AudioMapa)
	local total, tocam = 0, 0
	local semGravacao, parados, reserva = {}, {}, {}
	for id in Dialogos.FALAS do
		if id ~= "CONTA_3_RADIO" then
			total += 1
			local it = AudioMapa.itens[id]
			if Som.temGravacao(id) then
				tocam += 1
			elseif not it and not AudioMapa.itens[id .. "_v1"] then
				table.insert(semGravacao, id)
			else
				local usado = Som.itemTocavel(id)
				if usado then
					tocam += 1
					if usado ~= it then
						table.insert(reserva, id)
					end
				else
					table.insert(parados, id)
				end
			end
		end
	end
	table.sort(semGravacao)
	table.sort(parados)
	table.sort(reserva)
	local arquivos = {}
	for arq, nome in NOMES_VOZ do
		table.insert(arquivos, nome .. ": " .. Som.estadoDoArquivo(arq))
	end
	table.sort(arquivos)
	local l = { string.format("Falas com voz tocando: %d de %d.", tocam, total) }
	if #semGravacao > 0 then
		table.insert(l, "Ainda SEM gravação (só legenda): " .. table.concat(semGravacao, ", "))
	end
	if #parados > 0 then
		table.insert(l, "Gravadas mas o arquivo NÃO carregou (em análise no Roblox ou bloqueado): " .. table.concat(parados, ", "))
	end
	if #reserva > 0 then
		table.insert(l, "Tocando a voz ANTIGA no lugar da nova: " .. table.concat(reserva, ", "))
	end
	table.insert(l, "Arquivos: " .. table.concat(arquivos, " · "))
	return table.concat(l, "\n")
end

function AdminCliente.testarSons()
	local p, f, t = Som.estadoBiblioteca()
	mensagem(string.format("Sons gravados: %d de %d carregados (%d falharam)", p, t, f))
	task.spawn(function()
		for _, nome in { "coracao_batida", "ofegar", "passo_monstro", "osso", "gemido", "farejar", "rangido", "tres_batidas" } do
			Som.tocar(nome, { volume = 1 })
			task.wait(1.4)
		end
		Som.tocar("caixinha", { volume = 0.8 })
	end)
end

---------------------------------------------------------------------------
-- COMANDOS (painel e chat usam os mesmos)
---------------------------------------------------------------------------
local ACOES: { [string]: (...any) -> () } = {}
ACOES.ir = function(destino, n, i)
	AdminCliente.irPara(destino, tonumber(n), tonumber(i))
end
ACOES.missao = function(n, i)
	AdminCliente.irPara("missao", tonumber(n) or 1, tonumber(i) or 1)
end
ACOES.passo = function()
	servidor("passo")
end
ACOES.proxima = function()
	servidor("proxima")
end
ACOES.anterior = function()
	servidor("anterior")
end
ACOES.reiniciar = function()
	servidor("reiniciar")
end
ACOES.sombra = function()
	servidor("sombra")
end
ACOES.info = function()
	servidor("info")
end
ACOES.imortal = function()
	estado.imortal = not estado.imortal
	servidor("imortal", { ligar = estado.imortal })
end
ACOES.rapido = function()
	estado.rapido = not estado.rapido
	PrimeiraPessoa.velocidadeAdm(if estado.rapido then 2.5 else 1)
	mensagem(if estado.rapido then "Correndo rápido (x2,5)." else "Velocidade normal.")
end
ACOES.voar = function()
	AdminCliente.voar(not estado.voando)
	mensagem(if estado.voando then "Voando: ande para onde a câmera olha (atravessa paredes)." else "Voo desligado.")
end
ACOES.objetivo = function()
	AdminCliente.irObjetivo()
end
ACOES.inicio = function()
	if not MC.voltarInicio() then
		mensagem("Fora das missões não há início de sala.", false)
	end
end
ACOES.monstro = function()
	AdminCliente.verMonstro()
end
ACOES.sombra_esconde = function()
	AdminCliente.verMonstro(require(OI3.Config).MONSTRO_ESCONDE)
end
ACOES.pose = function()
	AdminCliente.proximaPose()
end
ACOES.sumir = function()
	pararVisor()
	mensagem("Monstro de teste sumiu.")
end
ACOES.susto = function()
	MC.susto()
end
ACOES.medo = function()
	Medo.forcar(1, 6)
	mensagem("Medo no máximo por 6 s (câmera embaça, coração e respiração).")
end
ACOES.sons = function()
	AdminCliente.testarSons()
end
ACOES.vozes = function()
	local txt = AdminCliente.relatorioVozes()
	if estado.relatorio then
		estado.relatorio.Text = txt
	end
	mensagem("Vozes conferidas (veja embaixo de CONFERIR VOZES).")
	print(txt)
end
ACOES.dia = function()
	Iluminacao.tarde(0.5)
end
ACOES.noite = function()
	Iluminacao.noite(0.5)
end
ACOES.cutscene = function()
	if Cutscene.ativa() then
		Cutscene.pular()
		mensagem("Cutscene pulada.")
	else
		mensagem("Nenhuma cutscene tocando.", false)
	end
end
ACOES.daradm = function(nome)
	if nome and nome ~= "" then
		servidor("daradm", { nome = nome })
	end
end
ACOES.trocarmonstro = function(chave)
	if chave then
		servidor("monstro", { chave = chave })
	end
end

function AdminCliente.executar(cmd: string, args: { string }?)
	local fn = ACOES[cmd]
	if not fn then
		mensagem("Comando desconhecido: /" .. cmd, false)
		return
	end
	fn(table.unpack(args or {}))
end

---------------------------------------------------------------------------
-- PAINEL
---------------------------------------------------------------------------
local function secao(pai: Instance, titulo: string, ordem: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Secao_" .. titulo
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, -8, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = ordem
	f.Parent = pai
	local lista = Instance.new("UIListLayout")
	lista.Padding = UDim.new(0, 4)
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Parent = f
	Interface.texto(f, {
		Text = titulo,
		FontFace = FONTE.textoNegrito,
		TextSize = 14,
		TextColor3 = COR.ouro,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 0,
	})
	local grade = Instance.new("Frame")
	grade.Name = "Grade"
	grade.BackgroundTransparency = 1
	grade.Size = UDim2.new(1, 0, 0, 0)
	grade.AutomaticSize = Enum.AutomaticSize.Y
	grade.LayoutOrder = 1
	grade.Parent = f
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(122, 36)
	g.CellPadding = UDim2.fromOffset(5, 5)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = grade
	return grade
end

local function botao(pai: Instance, texto: string, ordem: number, fn: () -> (), cor: Color3?): TextButton
	local b = Interface.botao(pai, texto, {
		TextSize = 13,
		LayoutOrder = ordem,
		BackgroundColor3 = cor or RGB(34, 31, 36),
		TextWrapped = true,
	}, fn)
	return b
end

-- liga/desliga um botão (texto com ✔ e cor; a cor de fundo o botão já usa no toque)
local function pintar(b: TextButton?, ligado: boolean)
	if b then
		local base = b:GetAttribute("Base")
		if base == nil then
			base = b.Text
			b:SetAttribute("Base", base)
		end
		b.Text = (if ligado then "✔ " else "") .. tostring(base)
		b.TextColor3 = if ligado then COR.destaqueClaro else COR.texto
	end
end

local function preencherPassos()
	local grade = estado.listaPassos
	if not grade then
		return
	end
	for _, x in grade:GetChildren() do
		if x:IsA("GuiButton") then
			x:Destroy()
		end
	end
	local n = estado.missaoSel
	local m = MissoesDados.missao(n)
	if not m then
		return
	end
	for i, p in m.passos do
		local nome = if p.tipo == "evento" then "cena" else (p.objetivo or p.tipo)
		botao(grade, string.format("%d · %s", i, string.sub(nome, 1, 22)), i, function()
			AdminCliente.irPara("missao", n, i)
		end)
	end
end

local function preencherMonstros()
	local grade = estado.listaMonstros
	if not grade then
		return
	end
	for _, x in grade:GetChildren() do
		if x:IsA("GuiButton") then
			x:Destroy()
		end
	end
	local pasta = ReplicatedStorage:FindFirstChild("OI3_Atores")
	local variantes = pasta and pasta:FindFirstChild("Monstros")
	local ativo = pasta and pasta:GetAttribute("MonstroAtivo")
	local ordem = 0
	for _, v in (variantes and variantes:GetChildren()) or {} do
		ordem += 1
		local nome = v:GetAttribute("NomeMonstro") or v.Name
		local b = botao(grade, string.sub(tostring(nome), 1, 26), ordem, function()
			ACOES.trocarmonstro(v.Name)
			task.delay(0.6, preencherMonstros)
		end)
		pintar(b, v.Name == ativo)
	end
	if ordem <= 1 then
		Interface.texto(grade, {
			Text = "Só o monstro do catálogo carregou (veja no instalador como liberar os da internet).",
			TextSize = 12,
			TextColor3 = COR.textoFraco,
			LayoutOrder = 99,
		})
	end
end

local function criarPainel()
	local tela = Interface.tela("OI3_Adm", 60, true)
	estado.tela = tela
	local b = Interface.botao(tela, "ADM", {
		Name = "BotaoADM",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 54),
		Size = UDim2.fromOffset(58, 30),
		TextSize = 15,
		BackgroundColor3 = RGB(110, 28, 28),
		Visible = ehAdmin(),
	}, function()
		if estado.painel then
			estado.painel.Visible = not estado.painel.Visible
			if estado.painel.Visible then
				preencherMonstros()
				servidor("info")
			end
		end
	end)
	estado.botaoAdm = b

	local painel = Instance.new("Frame")
	painel.Name = "Painel"
	painel.AnchorPoint = Vector2.new(1, 0)
	painel.Position = UDim2.new(1, -8, 0, 92)
	painel.Size = UDim2.new(0, 540, 1, -104)
	painel.BackgroundColor3 = COR.painel
	painel.BackgroundTransparency = 0.06
	painel.Visible = false
	Interface.canto(painel, 6)
	Interface.borda(painel, COR.borda, 1, 0.2)
	painel.Parent = tela
	local limite = Instance.new("UISizeConstraint")
	limite.MaxSize = Vector2.new(540, 2000)
	limite.Parent = painel
	estado.painel = painel
	-- celular estreito: o painel ocupa quase a largura toda
	local function ajustar()
		local cam = workspace.CurrentCamera
		local w = cam and cam.ViewportSize.X or 800
		painel.Size = UDim2.new(0, math.min(540, w - 24), 1, -104)
	end
	ajustar()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustar)
	end

	local status = Interface.texto(painel, {
		Name = "Status",
		Text = "Painel de ADM — modo teste: os pulos NÃO salvam progresso.",
		TextSize = 13,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -60, 0, 34),
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	estado.status = status
	Interface.botao(painel, "X", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(36, 30),
		TextSize = 15,
	}, function()
		painel.Visible = false
	end)

	local rolar = Instance.new("ScrollingFrame")
	rolar.Name = "Rolar"
	rolar.Position = UDim2.fromOffset(8, 44)
	rolar.Size = UDim2.new(1, -16, 1, -52)
	rolar.BackgroundTransparency = 1
	rolar.BorderSizePixel = 0
	rolar.ScrollBarThickness = 6
	rolar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rolar.CanvasSize = UDim2.new()
	rolar.Parent = painel
	local lista = Instance.new("UIListLayout")
	lista.Padding = UDim.new(0, 10)
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Parent = rolar

	-- criança para os pulos
	local gC = secao(rolar, "CRIANÇA (para os pulos)", 1)
	local botoesC = {}
	for i, cod in { "KE", "NI", "ME" } do
		local nome = if cod == "KE" then "Keko" elseif cod == "NI" then "Nina" else "Menino"
		botoesC[cod] = botao(gC, nome, i, function()
			estado.crianca = cod
			for c, bb in botoesC do
				pintar(bb, c == cod)
			end
		end)
	end
	pintar(botoesC.KE, true)

	-- ir para
	local gI = secao(rolar, "IR PARA (modo teste: não salva)", 2)
	for i, d in { { "TARDE", "tarde" }, { "JANTAR", "jantar" }, { "RITUAL", "ritual" }, { "FINAL", "final" }, { "MENU", "menu" } } do
		botao(gI, d[1], i, function()
			AdminCliente.irPara(d[2])
		end)
	end

	-- missões e passos
	local gM = secao(rolar, "MISSÕES (toque para ver os passos)", 3)
	for n = 1, MissoesDados.TOTAL do
		local m = MissoesDados.missao(n)
		botao(gM, string.format("M%d %s", n, string.sub(m.nome, 1, 14)), n, function()
			estado.missaoSel = n
			preencherPassos()
			mensagem(string.format("Missão %d: toque num passo para ir direto.", n))
		end)
	end
	estado.listaPassos = secao(rolar, "PASSOS DA MISSÃO ESCOLHIDA", 4)
	preencherPassos()

	-- missão atual
	local gA = secao(rolar, "MISSÃO ATUAL", 5)
	for i, d in {
		{ "PULAR PASSO", "passo" },
		{ "REINICIAR PASSO", "reiniciar" },
		{ "PRÓXIMA MISSÃO", "proxima" },
		{ "MISSÃO ANTERIOR", "anterior" },
		{ "CHAMAR A SOMBRA", "sombra" },
		{ "PULAR CUTSCENE", "cutscene" },
		{ "ONDE ESTOU?", "info" },
	} do
		botao(gA, d[1], i, function()
			ACOES[d[2]]()
		end)
	end

	-- eu
	local gE = secao(rolar, "EU", 6)
	estado.botoes.imortal = botao(gE, "IMORTAL", 1, function()
		ACOES.imortal()
		pintar(estado.botoes.imortal, estado.imortal)
	end)
	estado.botoes.rapido = botao(gE, "CORRER RÁPIDO", 2, function()
		ACOES.rapido()
		pintar(estado.botoes.rapido, estado.rapido)
	end)
	estado.botoes.voar = botao(gE, "VOAR (atravessa)", 3, function()
		ACOES.voar()
		pintar(estado.botoes.voar, estado.voando)
	end)
	botao(gE, "IR AO OBJETIVO", 4, ACOES.objetivo)
	botao(gE, "INÍCIO DA SALA", 5, ACOES.inicio)

	-- monstro
	local gMo = secao(rolar, "MONSTRO", 7)
	for i, d in {
		{ "VER O MONSTRO", "monstro" },
		{ "VER A SOMBRA (esconde)", "sombra_esconde" },
		{ "PRÓXIMA POSE", "pose" },
		{ "SUMIR MONSTRO", "sumir" },
		{ "SUSTO (jumpscare)", "susto" },
		{ "MEDO 6s", "medo" },
	} do
		botao(gMo, d[1], i, function()
			ACOES[d[2]]()
		end)
	end
	estado.listaMonstros = secao(rolar, "MONSTRO PRINCIPAL (fica salvo; o esconde-esconde usa sempre a sombra)", 8)
	preencherMonstros()

	-- sons e tela
	local gS = secao(rolar, "SONS, VOZES E TELA", 9)
	botao(gS, "CONFERIR VOZES", 1, ACOES.vozes)
	botao(gS, "TESTAR SONS", 2, ACOES.sons)
	botao(gS, "DIA", 3, ACOES.dia)
	botao(gS, "NOITE", 4, ACOES.noite)
	estado.relatorio = Interface.texto(rolar, {
		Name = "RelatorioVozes",
		Text = "",
		TextSize = 13,
		TextColor3 = COR.texto,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 10,
	})

	-- dar ADM
	local gD = secao(rolar, "DAR ADM PARA ALGUÉM (só o dono)", 11)
	local caixa = Instance.new("TextBox")
	caixa.PlaceholderText = "nome do jogador"
	caixa.Text = ""
	caixa.ClearTextOnFocus = false
	caixa.TextSize = 13
	caixa.FontFace = FONTE.texto
	caixa.TextColor3 = COR.texto
	caixa.BackgroundColor3 = RGB(24, 22, 26)
	caixa.LayoutOrder = 1
	Interface.canto(caixa, 4)
	caixa.Parent = gD
	botao(gD, "DAR ADM", 2, function()
		ACOES.daradm(caixa.Text)
	end)
end

---------------------------------------------------------------------------
-- CHAT: /adm, /ir tarde, /missao 3 2, /passo ...
---------------------------------------------------------------------------
local ALIASES = {
	adm = "/adm", ir = "/ir", missao = "/missao", passo = "/passo", proxima = "/proxima", anterior = "/anterior",
	reiniciar = "/reiniciar", sombra = "/sombra", imortal = "/imortal", rapido = "/rapido", voar = "/voar",
	objetivo = "/objetivo", inicio = "/inicio", monstro = "/monstro", pose = "/pose", sumir = "/sumir",
	susto = "/susto", medo = "/medo", sons = "/sons", dia = "/dia", noite = "/noite", cutscene = "/cutscene",
	info = "/info", daradm = "/daradm", vozes = "/vozes",
}

local function criarComandosChat()
	pcall(function()
		local pasta = TextChatService:FindFirstChild("OI3_ComandosADM") or Instance.new("Folder")
		pasta.Name = "OI3_ComandosADM"
		pasta.Parent = TextChatService
		for nome, alias in ALIASES do
			local c = Instance.new("TextChatCommand")
			c.Name = "OI3_" .. nome
			c.PrimaryAlias = alias
			c.Parent = pasta
			c.Triggered:Connect(function(origem: TextSource, texto: string)
				if origem.UserId ~= lp.UserId or not ehAdmin() then
					return
				end
				local cmd, args = AdminCliente.lerComando(texto)
				if cmd == "adm" then
					if estado.painel then
						estado.painel.Visible = true
						preencherMonstros()
					end
				elseif cmd then
					AdminCliente.executar(cmd, args)
				end
			end)
		end
	end)
end

function AdminCliente.iniciar(ctx: any)
	estado.ctx = ctx
	criarPainel()
	local function atualizar()
		if estado.botaoAdm then
			estado.botaoAdm.Visible = ehAdmin()
		end
		if not ehAdmin() and estado.painel then
			estado.painel.Visible = false
		end
	end
	lp:GetAttributeChangedSignal("OI3_Admin"):Connect(atualizar)
	atualizar()
	criarComandosChat()
	ctx.remoto.OnClientEvent:Connect(function(tipo: string, info: any)
		if tipo == "msg" and type(info) == "table" then
			mensagem(tostring(info.texto), info.ok)
		end
	end)
	-- personagem novo: o voo/velocidade não ficam pela metade
	lp.CharacterAdded:Connect(function()
		if estado.voando then
			estado.voando = false
			pintar(estado.botoes.voar, false)
		end
	end)
end

return AdminCliente
