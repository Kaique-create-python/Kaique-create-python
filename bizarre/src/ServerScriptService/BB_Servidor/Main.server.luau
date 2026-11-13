-- BIZARRE BATTLEGROUNDS :: servidor (liga tudo)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BB = ReplicatedStorage:WaitForChild("BB")
local Config = require(BB:WaitForChild("Config"))
local Entrada = require(BB:WaitForChild("Entrada"))
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
local VFXLoja = require(pasta.VFXLoja)
local Admin = require(pasta.Admin)

-- remotos
local pastaRemotos = Instance.new("Folder")
pastaRemotos.Name = "BB_Remotos"
local remotos = {}
for _, nome in { "Acao", "Efeito", "Privado", "Entrar", "Admin", "Preferencias", "Treino" } do
	local r = Instance.new("RemoteEvent")
	r.Name = nome
	r.Parent = pastaRemotos
	remotos[nome] = r
end
pastaRemotos.Parent = ReplicatedStorage

Fisica.iniciar(remotos.Privado)
Mapa.construir(workspace)
Mapa.iniciar(remotos.Efeito)

-- Morioh é grande e chega aos pouquinhos no celular (StreamingEnabled). No menu o celular
-- recebe a região do centro (onde a câmera voa); antes de nascer, recebe a região do spawn.
local focoMenu = Instance.new("Part")
focoMenu.Name = "BB_FocoMenu"
focoMenu.Anchored = true
focoMenu.CanCollide = false
focoMenu.CanQuery = false
focoMenu.CanTouch = false
focoMenu.Transparency = 1
focoMenu.Size = Vector3.new(1, 1, 1)
focoMenu.Position = Mapa.CENTRO_MENU
focoMenu.Parent = workspace

local function carregarRegiao(jogador: Player, pos: Vector3)
	if not workspace.StreamingEnabled then
		return
	end
	pcall(function()
		jogador:RequestStreamAroundAsync(pos, 6)
	end)
end
Fisica.carregarRegiao = carregarRegiao
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
		quem = vitima.modelo,
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
require(pasta.PreferenciasServidor17).iniciar(remotos.Preferencias)
local laboratorio17=require(pasta.LaboratorioServidor17).iniciar(remotos.Treino,{Bots=Bots,Lutadores=Lutadores,Combate=Combate,Mapa=Mapa})
Combate.aoContato17=function(atk,alvo,data)
 local ok,err=pcall(function()laboratorio17:contato(atk,alvo,data)end)
 if not ok then warn("[BB] relatório de treino: "..tostring(err))end
end

-------------------------------------------------------------------------------- personagens
local escolha: { [Player]: any } = {}
local pedidos: { [Player]: any } = {} -- pedido de entrada em andamento (AJUSTE7)

-- responde UMA vez o pedido de entrada pelo remoto privado
local function responderEntrada(jogador: Player, id: string?, ok: boolean, motivo: string?)
	if id then
		remotos.Privado:FireClient(jogador, "entrada", { id = id, ok = ok, motivo = motivo })
	end
end

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

-- AJUSTE-11: "Animate" que não é o nosso (padrão do Roblox) sai do personagem
local function tirarAnimacaoRoblox(personagem: Model)
	for _, d in personagem:GetChildren() do
		if d.Name == "Animate" and d:IsA("BaseScript") and not d:GetAttribute("BB_Nosso") then
			d:Destroy()
		end
	end
end

local function prepararPersonagem(jogador: Player, personagem: Model)
	local hum = personagem:WaitForChild("Humanoid", 10) :: Humanoid?
	local raiz = personagem:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	tirarAnimacaoRoblox(personagem)
	personagem.ChildAdded:Connect(function(d)
		if d.Name == "Animate" then
			task.defer(tirarAnimacaoRoblox, personagem)
		end
	end)
	if not hum or not raiz then
		local p = pedidos[jogador]
		pedidos[jogador] = nil
		responderEntrada(jogador, p and p.id, false, "O personagem não carregou. Tente de novo.")
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
	local destino = melhorSpawn(e.modo) + Vector3.new(0, 1, 0)
	carregarRegiao(jogador, destino.Position)
	personagem:PivotTo(destino)
	jogador.ReplicationFocus = nil
	Fisica.grupo(personagem, Fisica.GRUPOS.lutador)
	personagem.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = if (personagem:GetAttribute("BB_Ragdoll") or 0) > agora() then Fisica.GRUPOS.voando else Fisica.GRUPOS.lutador
		end
	end)
	local lut = Lutadores.criar(personagem, jogador, standId)
	lut.estado.protecaoAte = agora() + Config.PROTECAO_SPAWN
	Combate.sincronizar(lut)
	-- personagem e região prontos: confirma o pedido de entrada (o menu fecha só agora)
	local p = pedidos[jogador]
	if p then
		pedidos[jogador] = nil
		responderEntrada(jogador, p.id, true)
		if p.bot and Bots.doDono(jogador) < 1 then
			task.delay(1.5, function()
				local l = Lutadores.doJogador(jogador)
				if l and Bots.doDono(jogador) < 1 then
					Bots.criar(l.raiz.Position + l.raiz.CFrame.LookVector * 22, nil, "facil", jogador)
				end
			end)
		end
	end
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

-- AJUSTE-9: o jogo é TODO em R6 (as animações mexem nas juntas do R6). Se a experiência estiver
-- configurada como R15 (Creator Dashboard > Avatar), o servidor troca o corpo por um R6 com a
-- mesma roupa do jogador. Assim as animações funcionam qualquer que seja a configuração.
local function corpoR6(jogador: Player, personagem: Model): Model?
	local hum = personagem:FindFirstChildOfClass("Humanoid")
	if not hum or hum.RigType == Enum.HumanoidRigType.R6 then
		return nil
	end
	local ok, novo = pcall(function()
		local desc = hum:GetAppliedDescription()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	end)
	if not ok or not novo then
		ok, novo = pcall(function()
			return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
		end)
	end
	if not ok or not novo then
		warn("[BB] não consegui trocar o corpo para R6: " .. tostring(novo))
		return nil
	end
	novo.Name = jogador.Name
	-- AJUSTE-11: o corpo feito pelo Roblox vem com o "Animate" padrão (andar do Roblox por cima do
	-- nosso). Tira tudo que tiver o mesmo nome dos nossos scripts e coloca os nossos.
	local inicial = game:GetService("StarterPlayer").StarterCharacterScripts
	for _, d in novo:GetChildren() do
		if (d:IsA("BaseScript") or d:IsA("ModuleScript")) and inicial:FindFirstChild(d.Name) then
			d:Destroy()
		end
	end
	for _, sc in inicial:GetChildren() do
		sc:Clone().Parent = novo
	end
	local cf = personagem:GetPivot()
	novo:PivotTo(cf)
	return novo
end

Players.PlayerAdded:Connect(function(jogador)
	jogador.ReplicationFocus = focoMenu
	jogador.CharacterAdded:Connect(function(personagem)
		personagem:WaitForChild("Humanoid", 10)
		local r6 = corpoR6(jogador, personagem)
		if r6 then
			-- o CharacterAdded roda de novo com o corpo R6
			jogador.Character = r6
			r6.Parent = workspace
			personagem:Destroy()
			return
		end
		prepararPersonagem(jogador, personagem)
	end)
	jogador.CharacterRemoving:Connect(function(personagem)
		laboratorio17:limpar(jogador)
  Lutadores.remover(personagem)
	end)
end)

Players.PlayerRemoving:Connect(function(jogador)
	escolha[jogador] = nil
	pedidos[jogador] = nil
	Bots.limpar(jogador)
end)

-- o menu do celular pede para entrar (ou trocar de Stand). AJUSTE7: cada pedido tem número e
-- recebe UMA resposta ("entrada": id, ok, motivo); a troca de Stand é validada antes de mudar
-- a escolha; pedido repetido durante o carregamento não cria entrada nem bot duplicado.
remotos.Entrar.OnServerEvent:Connect(function(jogador: Player, dados: any)
	local t = agora()
	local lut = Lutadores.doJogador(jogador)
	local vivo = lut ~= nil and lut.hum.Health > 0
	local estado = {
		pendente = pedidos[jogador],
		vivo = vivo,
		emCombate = vivo and (t - lut.estado.ultimoDanoT < Config.FORA_DE_COMBATE),
		adm = Admin.eh(jogador),
	}
	-- o tempo do pedido pendente é contado no relógio do servidor
	if estado.pendente then
		estado.pendente = { id = estado.pendente.id, t = estado.pendente.t }
	end
	local ok, motivo, id = Entrada.validar(estado, dados, os.clock(), Stands.valido)
	if not ok then
		if motivo ~= "duplicado" then
			responderEntrada(jogador, id, false, motivo)
		end
		return
	end
	local modo = if dados.modo == "treino" then "treino" else "luta"
	escolha[jogador] = { stand = dados.stand, modo = modo }
	jogador:SetAttribute("BB_Stand", dados.stand)
 jogador:SetAttribute("BB_Modo",modo)
 laboratorio17:limpar(jogador)
	if vivo and lut then
		-- já está lutando: só troca o Stand (e vai para o treino se pediu)
		Lutadores.trocarStand(lut, dados.stand)
		Combate.sincronizar(lut)
		if modo == "treino" then
			local treino = Mapa.treino()
			if treino then
				carregarRegiao(jogador, treino.spawn.Position)
				Fisica.moverPara(lut, treino.spawn)
			end
		end
		remotos.Privado:FireClient(jogador, "aviso", { texto = "Stand: " .. Stands.get(dados.stand).nome })
		responderEntrada(jogador, id, true)
		return
	end
	pedidos[jogador] = { id = id, t = os.clock(), bot = dados.bot == true and modo == "treino" }
	if not jogador.Character or not jogador.Character.Parent then
		jogador:LoadCharacter()
	else
		-- personagem morto esperando renascer: o renascimento confirma o pedido
		local hum = jogador.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health > 0 then
			jogador:LoadCharacter()
		end
	end
end)

-- AJUSTE-11: VFX da loja (pacotes que o dono pegou), carregados sem rodar nenhum script deles
task.spawn(VFXLoja.iniciar)

workspace:SetAttribute("BB_Pronto", true)
workspace:SetAttribute("BB_Revisao", Config.REVISAO)
print("[BB] servidor pronto", Config.REVISAO)
