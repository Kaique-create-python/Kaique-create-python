-- BIZARRE BATTLEGROUNDS :: servidor (liga tudo)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BB = ReplicatedStorage:WaitForChild("BB")
local Config = require(BB:WaitForChild("Config"))
local Stands = require(BB:WaitForChild("Stands"))
local Regras = require(BB:WaitForChild("Regras"))

local pasta = script.Parent
local Fisica = require(pasta.Fisica)
local Mapa = require(pasta.Mapa)
local Lutadores = require(pasta.Lutadores)
local Combate = require(pasta.Combate)
local Executores = require(pasta.Executores)
local StandModelos = require(pasta.StandModelos)
local Bots = require(pasta.Bots)
local Dados = require(pasta.Dados)
local Admin = require(pasta.Admin)

-- remotos
local pastaRemotos = Instance.new("Folder")
pastaRemotos.Name = "BB_Remotos"
local remotos = {}
for _, nome in { "Acao", "Efeito", "Privado", "Entrar", "Admin" } do
	local r = Instance.new("RemoteEvent")
	r.Name = nome
	r.Parent = pastaRemotos
	remotos[nome] = r
end
pastaRemotos.Parent = ReplicatedStorage

Fisica.iniciar(remotos.Privado)
Mapa.construir(workspace)
Mapa.iniciar(remotos.Efeito)
task.spawn(function()
	StandModelos.preparar()
	workspace:SetAttribute("BB_StandsProntos", true)
end)

local function agora()
	return workspace:GetServerTimeNow()
end

-- quando alguém cai
local function aoAbate(vitima: any, assassino: any?)
	local dados = {
		vitima = vitima.nome,
		standV = vitima.standId,
		assassino = if assassino then assassino.nome else nil,
		standA = if assassino then assassino.standId else nil,
	}
	remotos.Efeito:FireAllClients("morte", dados)
	if vitima.jogador then
		Dados.morte(vitima.jogador)
	end
	if assassino then
		Regras.ganharDespertar(assassino.estado, 25, agora())
		if assassino.jogador then
			local seq = Dados.abate(assassino.jogador)
			local nome = Regras.nomeSequencia(seq)
			if nome then
				remotos.Efeito:FireAllClients("anuncio", { texto = assassino.nome .. ": " .. nome, cor = assassino.stand.aura })
			end
		end
	end
end

Executores.iniciar(remotos)
Combate.iniciar(remotos, Executores, aoAbate)
Bots.iniciar()
Bots.criarBonecos()
Dados.iniciar()
Admin.iniciar(remotos.Admin)

-------------------------------------------------------------------------------- personagens
local escolha: { [Player]: any } = {}

local function melhorSpawn(modo: string?): CFrame
	local treino = Mapa.treino()
	if modo == "treino" and treino then
		return treino.spawn * CFrame.new(math.random(-8, 8), 0, math.random(-4, 4))
	end
	local spawns = Mapa.spawns()
	local melhor, melhorD = spawns[1] or CFrame.new(0, 6, 0), -1
	for _, cf in spawns do
		local menor = math.huge
		for _, l in Lutadores.vivos() do
			menor = math.min(menor, (l.raiz.Position - cf.Position).Magnitude)
		end
		menor += math.random() * 25
		if menor > melhorD then
			melhor, melhorD = cf, menor
		end
	end
	return melhor
end

local function prepararPersonagem(jogador: Player, personagem: Model)
	local hum = personagem:WaitForChild("Humanoid", 10) :: Humanoid?
	local raiz = personagem:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not hum or not raiz then
		return
	end
	local e = escolha[jogador] or {}
	local standId = if Stands.valido(e.stand) then e.stand else Stands.padrao()
	hum.MaxHealth = Config.VIDA
	hum.Health = Config.VIDA
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.UseJumpPower = false
	hum.JumpHeight = Config.PULO
	hum.WalkSpeed = Config.ANDAR
	task.wait()
	personagem:PivotTo(melhorSpawn(e.modo) + Vector3.new(0, 1, 0))
	Fisica.grupo(personagem, Fisica.GRUPOS.lutador)
	personagem.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = if (personagem:GetAttribute("BB_Ragdoll") or 0) > agora() then Fisica.GRUPOS.voando else Fisica.GRUPOS.lutador
		end
	end)
	local lut = Lutadores.criar(personagem, jogador, standId)
	lut.estado.protecaoAte = agora() + Config.PROTECAO_SPAWN
	Combate.sincronizar(lut)
	hum.Died:Connect(function()
		Combate.abate(lut)
		task.delay(Config.RESPAWN, function()
			Lutadores.remover(personagem)
			if jogador.Parent and escolha[jogador] then
				jogador:LoadCharacter()
			end
		end)
	end)
end

Players.PlayerAdded:Connect(function(jogador)
	jogador.CharacterAdded:Connect(function(personagem)
		prepararPersonagem(jogador, personagem)
	end)
	jogador.CharacterRemoving:Connect(function(personagem)
		Lutadores.remover(personagem)
	end)
end)

Players.PlayerRemoving:Connect(function(jogador)
	escolha[jogador] = nil
	Bots.limpar(jogador)
end)

-- o menu do celular pede para entrar (ou trocar de Stand)
remotos.Entrar.OnServerEvent:Connect(function(jogador: Player, dados: any)
	if type(dados) ~= "table" or not Stands.valido(dados.stand) then
		return
	end
	local modo = if dados.modo == "treino" then "treino" else "luta"
	escolha[jogador] = { stand = dados.stand, modo = modo }
	jogador:SetAttribute("BB_Stand", dados.stand)
	local lut = Lutadores.doJogador(jogador)
	if lut and lut.hum.Health > 0 then
		local t = agora()
		if t - lut.estado.ultimoDanoT < Config.FORA_DE_COMBATE and not Admin.eh(jogador) then
			remotos.Privado:FireClient(jogador, "aviso", { texto = "Saia do combate por alguns segundos para trocar de Stand." })
			return
		end
		Lutadores.trocarStand(lut, dados.stand)
		Combate.sincronizar(lut)
		remotos.Privado:FireClient(jogador, "aviso", { texto = "Stand: " .. Stands.get(dados.stand).nome })
		if modo == "treino" then
			local treino = Mapa.treino()
			if treino then
				jogador.Character:PivotTo(treino.spawn)
			end
		end
		return
	end
	if not jogador.Character then
		jogador:LoadCharacter()
	end
	if dados.bot == true and modo == "treino" then
		task.delay(2, function()
			local l = Lutadores.doJogador(jogador)
			if l then
				Bots.criar(l.raiz.Position + l.raiz.CFrame.LookVector * 22, nil, "facil", jogador)
			end
		end)
	end
end)

workspace:SetAttribute("BB_Pronto", true)
workspace:SetAttribute("BB_Revisao", Config.REVISAO)
print("[BB] servidor pronto", Config.REVISAO)
