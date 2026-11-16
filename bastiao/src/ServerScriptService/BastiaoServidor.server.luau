-- PROJETO BASTIÃO :: servidor (Etapa 1: abertura, cenas 1, 3, 4, 5, 7 e 8; Etapa 2: vozes, sons e 3 línguas)
-- Só acrescenta: cria remotos e a pasta workspace.BastiaoHistoria. Não altera o mapa
-- Sector7World, o HUD da bodycam nem os scripts Sector7, e não usa DataStore.
-- Ordem: remotos -> espera o mapa -> cenário -> valida o capítulo -> missão.
-- Se o capítulo não passar na validação, a história não começa (o jogo base segue igual).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local moduloCompartilhado = ReplicatedStorage:WaitForChild("BastiaoCompartilhado")
local Compartilhado = require(moduloCompartilhado)
local Textos = require(moduloCompartilhado:WaitForChild("Textos"))
local Audio = require(moduloCompartilhado:WaitForChild("Audio"))
local StoryRunner = require(script:WaitForChild("StoryRunner"))
local StoryValidator = require(script:WaitForChild("StoryValidator"))
local Capitulo01 = require(script:WaitForChild("Capitulo01"))
local Mundo = require(script:WaitForChild("Mundo"))
local Missao = require(script:WaitForChild("Missao"))
local Sequencias = require(script:WaitForChild("Sequencias"))
local Interacoes = require(script:WaitForChild("Interacoes"))
local Zonas = require(script:WaitForChild("Zonas"))
local Checkpoint = require(script:WaitForChild("Checkpoint"))
local Cenario = require(script:WaitForChild("Cenario"))
local Pavel = require(script:WaitForChild("Pavel"))
local Preferencias = require(script:WaitForChild("Preferencias"))

local SPAWN_TUNEL = Vector3.new(0, 4, 12) -- onde o Sector7 coloca cada personagem

-- 1) remotos primeiro: o cliente nunca fica esperando algo que não existe
local remotos = ReplicatedStorage:FindFirstChild(Compartilhado.PASTA_REMOTOS)
if not remotos then
	remotos = Instance.new("Folder")
	remotos.Name = Compartilhado.PASTA_REMOTOS
	remotos.Parent = ReplicatedStorage
end
local apresentacao = remotos:FindFirstChild(Compartilhado.REMOTO_APRESENTACAO)
if not apresentacao then
	apresentacao = Instance.new("RemoteEvent")
	apresentacao.Name = Compartilhado.REMOTO_APRESENTACAO
	apresentacao.Parent = remotos
end
local remotoIdioma = remotos:FindFirstChild(Compartilhado.REMOTO_IDIOMA)
if not remotoIdioma then
	remotoIdioma = Instance.new("RemoteEvent")
	remotoIdioma.Name = Compartilhado.REMOTO_IDIOMA
	remotoIdioma.Parent = remotos
end
moduloCompartilhado:SetAttribute(Compartilhado.ATR_OBJETIVO, "")
moduloCompartilhado:SetAttribute(Compartilhado.ATR_ACESSO, "aberto")
moduloCompartilhado:SetAttribute(Compartilhado.ATR_ALARME, false)
moduloCompartilhado:SetAttribute(Compartilhado.ATR_FIM, 0)
moduloCompartilhado:SetAttribute("BastiaoEtapa", Compartilhado.ETAPA)

-- 2) o mapa já existe no place; se não existir, a história não começa (nunca é recriado)
local mapa = workspace:FindFirstChild("Sector7World") or workspace:WaitForChild("Sector7World", 30)
if not mapa then
	warn("[Bastiao] Sector7World não encontrado: a história não iniciou e o mapa não foi alterado")
	moduloCompartilhado:SetAttribute("BastiaoErro", "sem_mapa")
	return
end

-- 3) grupos de colisão: o Pavel não empurra nem é empurrado por jogadores
for _, nome in { Pavel.GRUPO, "BastiaoJogador" } do
	pcall(function()
		workspace:RegisterCollisionGroup(nome)
	end)
end
pcall(function()
	workspace:CollisionGroupSetCollidable(Pavel.GRUPO, "BastiaoJogador", false)
end)

-- 4) pasta própria da história (substitui só uma pasta criada por este mesmo script)
local antiga = workspace:FindFirstChild(Compartilhado.PASTA_MUNDO)
if antiga then
	if antiga:GetAttribute("BastiaoDono") == true then
		antiga:Destroy()
	else
		warn("[Bastiao] já existe um " .. Compartilhado.PASTA_MUNDO .. " que não é desta etapa; nada foi mexido")
		moduloCompartilhado:SetAttribute("BastiaoErro", "pasta_ocupada")
		return
	end
end
local pasta = Instance.new("Folder")
pasta.Name = Compartilhado.PASTA_MUNDO
pasta:SetAttribute("BastiaoDono", true)
pasta.Parent = workspace

local servicos = {
	tween = function(inst: Instance, tempo: number, alvo: { [string]: any })
		TweenService:Create(inst, TweenInfo.new(tempo, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), alvo):Play()
	end,
	atrasar = function(segundos: number, fn: () -> ())
		task.delay(segundos, fn)
	end,
	marcar = function(inst: Instance, tag: string)
		CollectionService:AddTag(inst, tag)
	end,
	agora = os.clock,
	-- som mecânico sem legenda (porta, alavanca, módulo, bipe), tocado em 3D por cada cliente
	ruido = function(chave: string, pos: Vector3?)
		apresentacao:FireAllClients({ tipo = "ruido", chave = chave, pos = pos })
	end,
}

local mundo = Mundo.novo(warn)
local cena = Cenario.construir({
	pasta = pasta,
	textos = Textos,
	mundo = mundo,
	servicos = servicos,
	jogadores = function()
		return Players:GetPlayers()
	end,
	criarPavel = function(p: Instance)
		return Pavel.criar(p, warn)
	end,
	log = print,
})

-- 5) o capítulo precisa bater com as entidades que o cenário registrou
local relatorio = StoryValidator.Validate(Capitulo01, mundo:registro())
if not relatorio.ok then
	for _, e in relatorio.erros do
		warn("[Bastiao] capítulo inválido: " .. e)
	end
	moduloCompartilhado:SetAttribute("BastiaoErro", "capitulo_invalido")
	return
end

-- 6) serviços da história
-- avisos vão como chave (+ argumentos): cada cliente mostra na própria língua
local function avisarTodos(chave: string, args: { any }?)
	apresentacao:FireAllClients({ tipo = "aviso", chave = chave, args = args })
end

local checkpoint = Checkpoint.novo(cena.spawns)
local interacoes: any = nil
local missao = Missao.novo({
	def = Capitulo01,
	runner = StoryRunner,
	mundo = mundo,
	objetivo = function(chave: string?)
		moduloCompartilhado:SetAttribute(Compartilhado.ATR_OBJETIVO, chave or "")
	end,
	checkpoint = function(id: string, estado: any, retrato: { [string]: string })
		checkpoint:salvar(id, estado, retrato)
	end,
	aoAvancar = function()
		if interacoes then
			interacoes:atualizar()
		end
	end,
	aoFinal = function()
		moduloCompartilhado:SetAttribute(Compartilhado.ATR_FIM, workspace:GetServerTimeNow())
		print("[Bastiao] Etapa 1 concluída neste servidor")
	end,
	log = print,
})
local sequencias = Sequencias.novo({
	def = Capitulo01,
	textos = Textos,
	mundo = mundo,
	apresentar = function(msg)
		apresentacao:FireAllClients(msg)
	end,
	aoTerminar = function(id: string, execucao: number)
		missao:reportar({ id = "seq:" .. id .. ":" .. execucao, kind = "sequencia", name = id .. "_fim" })
	end,
	agendar = function(segundos: number, fn: () -> ())
		return task.delay(segundos, fn)
	end,
	cancelar = function(h: any)
		task.cancel(h)
	end,
	duracaoLeitura = Compartilhado.duracaoLeitura,
	duracoes = Audio.duracoes,
	log = warn,
})
missao:ligarSequencias(sequencias)

local function localizar(j: Player): (Vector3?, boolean)
	local c = j.Character
	local raiz = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not raiz or not hum then
		return nil, false
	end
	return raiz.Position, hum.Health > 0
end

interacoes = Interacoes.novo({
	missao = missao,
	mundo = mundo,
	localizar = localizar,
	agora = os.clock,
	aviso = function(j: Player, chave: string, args: { any }?)
		apresentacao:FireClient(j, { tipo = "aviso", chave = chave, args = args })
	end,
	log = warn,
})
local ligados = {}
for _, def in cena.interacoes do
	interacoes:registrar(def.nome, def)
	if def.prompt and not ligados[def.prompt] then
		ligados[def.prompt] = true
		local p = def.prompt
		p.Triggered:Connect(function(j: Player)
			local ok, motivo = interacoes:acionar(j, p)
			if not ok and motivo ~= "repetido" then
				print("[Bastiao] interação recusada: " .. p.Name .. " / " .. tostring(motivo))
			end
		end)
	end
end

mundo:aoMudar(function(id: string, estado: string)
	if id == "alarme" then
		moduloCompartilhado:SetAttribute(Compartilhado.ATR_ALARME, estado == "ligado")
	elseif id == "acesso_externo" then
		moduloCompartilhado:SetAttribute(Compartilhado.ATR_ACESSO, estado)
	end
	interacoes:atualizar()
end)

local zonas = Zonas.novo({
	missao = missao,
	jogadores = function()
		local r = {}
		for _, j in Players:GetPlayers() do
			local pos, vivo = localizar(j)
			table.insert(r, { jogador = j, pos = pos, vivo = vivo })
		end
		return r
	end,
})
for nome, forma in cena.zonas do
	zonas:registrar(nome, forma)
end

-- 7) jogadores: grupo de colisão, módulo que cai de quem sai/morre e renascer no ponto seguro
local function soltarModulo(j: Player, motivo: string)
	if cena.bateria.soltar(j, motivo) then
		avisarTodos("modulo_voltou")
		interacoes:atualizar()
	end
end

local function levarParaDentro(j: Player, alvo: CFrame, comCorte: boolean)
	local c = j.Character
	if not c or not c.Parent then
		return
	end
	if comCorte then
		apresentacao:FireClient(j, { tipo = "corte" })
		task.wait(0.35)
	end
	pcall(function()
		j:RequestStreamAroundAsync(alvo.Position, 5)
	end)
	if c.Parent then
		c:PivotTo(alvo * CFrame.new(math.random(-30, 30) / 10, 0, math.random(-20, 20) / 10))
	end
end

-- o Sector7 coloca todo personagem no túnel depois de pedir streaming; durante alguns
-- segundos, quem aparecer no túnel depois do ponto seguro vai para dentro da oficina
local function renascerNoPonto(j: Player, c: Model)
	local raiz = c:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not raiz then
		return
	end
	local fim = os.clock() + 10
	local primeiro = true
	while os.clock() < fim and c.Parent do
		local spawn = checkpoint:spawn()
		if not spawn then
			return
		end
		if (raiz.Position - SPAWN_TUNEL).Magnitude < 10 then
			levarParaDentro(j, spawn, primeiro)
			primeiro = false
		end
		task.wait(0.15)
	end
end

local function prepararPersonagem(j: Player, c: Model)
	local function marcar(d: Instance)
		if d:IsA("BasePart") then
			d.CollisionGroup = "BastiaoJogador"
		end
	end
	for _, d in c:GetDescendants() do
		marcar(d)
	end
	c.DescendantAdded:Connect(marcar)
	local hum = c:WaitForChild("Humanoid", 10) :: Humanoid?
	if hum then
		hum.Died:Connect(function()
			soltarModulo(j, "morte")
		end)
	end
	if checkpoint:spawn() then
		task.spawn(renascerNoPonto, j, c)
	end
end

-- língua de cada jogador: da conta Roblox ou da escolha salva; troca pelo menu da bodycam
local preferencias = Preferencias.novo({ textos = Textos, atributo = Compartilhado.ATR_IDIOMA, log = warn })
remotoIdioma.OnServerEvent:Connect(function(j: Player, idioma: any)
	preferencias:trocar(j, idioma)
end)

local function jogadorEntrou(j: Player)
	preferencias:carregar(j)
	j.CharacterAdded:Connect(function(c)
		prepararPersonagem(j, c)
	end)
	j.CharacterRemoving:Connect(function()
		soltarModulo(j, "personagem removido")
	end)
	if j.Character then
		task.spawn(prepararPersonagem, j, j.Character)
	end
end
Players.PlayerAdded:Connect(jogadorEntrou)
for _, j in Players:GetPlayers() do
	jogadorEntrou(j)
end
Players.PlayerRemoving:Connect(function(j: Player)
	preferencias:saiu(j)
	soltarModulo(j, "saiu")
	interacoes:esquecer(j)
end)

-- trava fechada: quem ficou do lado de fora entra junto (ninguém fica preso fora da oficina)
checkpoint:aoSalvar(function(p)
	if p.id ~= "oficina_segura" or not p.spawn then
		return
	end
	for _, j in Players:GetPlayers() do
		if not cena.dentroOficina(j) then
			task.spawn(levarParaDentro, j, p.spawn, true)
		end
	end
end)

-- 8) começa: entrada do primeiro nó sem animação, depois as zonas 4 vezes por segundo
missao:iniciar()
interacoes:atualizar()
local acumulado = 0
RunService.Heartbeat:Connect(function(dt: number)
	acumulado += dt
	if acumulado < 0.25 then
		return
	end
	acumulado = 0
	local ok, err = pcall(zonas.verificar, zonas)
	if not ok then
		warn("[Bastiao] zonas: " .. tostring(err))
	end
end)

print(string.format("[Bastiao] %s pronta: %d interações, capítulo %s v%d", Compartilhado.ETAPA, #cena.interacoes, Capitulo01.id, Capitulo01.version))
