-- CyberOutlaw · garante avatares R6 no servidor.
-- O Place grava R6 nas configurações de avatar, mas o universo pode continuar
-- em MorphToR15. Este script refaz em R6 qualquer personagem que nasça em R15
-- e registra o resultado no atributo CyberOutlawRig do jogador.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local ATTRIBUTE = "CyberOutlawRig"
local busy: { [Player]: boolean } = {}

local function call(object: any, names: { string }, ...: any): (boolean, any)
	for _, name in names do
		local ok, method = pcall(function()
			return object[name]
		end)
		if ok and typeof(method) == "function" then
			return pcall(method, object, ...)
		end
	end
	return false, "método ausente"
end

local function description(player: Player, humanoid: Humanoid): HumanoidDescription?
	local ok, result = call(humanoid, { "GetAppliedDescription" })
	if ok and typeof(result) == "Instance" and result:IsA("HumanoidDescription") then
		return result
	end
	ok, result = call(Players, { "GetHumanoidDescriptionFromUserIdAsync", "GetHumanoidDescriptionFromUserId" }, math.max(player.UserId, 1))
	if ok and typeof(result) == "Instance" and result:IsA("HumanoidDescription") then
		return result
	end
	return nil
end

local function rebuild(player: Player, character: Model, humanoid: Humanoid)
	local desc = description(player, humanoid)
	if not desc then
		warn("[CyberOutlaw] Sem descrição de avatar para refazer em R6:", player.Name)
		return
	end
	local ok, model = call(Players, { "CreateHumanoidModelFromDescriptionAsync", "CreateHumanoidModelFromDescription" }, desc, Enum.HumanoidRigType.R6)
	if not ok or typeof(model) ~= "Instance" or not model:IsA("Model") then
		warn("[CyberOutlaw] Falha ao montar o avatar R6:", model)
		return
	end
	if player.Parent ~= Players or player.Character ~= character then
		model:Destroy()
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local pivot = if root and root:IsA("BasePart") then root.CFrame else character:GetPivot()
	model.Name = player.Name
	local starterScripts = StarterPlayer:FindFirstChildOfClass("StarterCharacterScripts")
	if starterScripts then
		for _, child in starterScripts:GetChildren() do
			local existing = model:FindFirstChild(child.Name)
			if existing then
				existing:Destroy()
			end
			child:Clone().Parent = model
		end
	end
	if not model:FindFirstChild("Animate") then
		warn("[CyberOutlaw] O avatar R6 veio sem o script Animate:", player.Name)
	end
	model:PivotTo(pivot)
	player.Character = model
	model.Parent = workspace
	character:Destroy()
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 15)
	if not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= character then
		return
	end
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		player:SetAttribute(ATTRIBUTE, "R6")
		return
	end
	if busy[player] then
		return
	end
	busy[player] = true
	player:SetAttribute(ATTRIBUTE, "R15→R6")
	local ok, err = pcall(rebuild, player, character, humanoid)
	busy[player] = nil
	if not ok then
		warn("[CyberOutlaw] Erro ao converter para R6:", err)
	end
	local current = player.Character
	local currentHumanoid = current and current:FindFirstChildOfClass("Humanoid")
	if currentHumanoid and currentHumanoid.RigType == Enum.HumanoidRigType.R6 then
		player:SetAttribute(ATTRIBUTE, "R6 (convertido)")
		print("[CyberOutlaw] Avatar convertido para R6:", player.Name)
	else
		player:SetAttribute(ATTRIBUTE, "R15 (falhou)")
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end

-- Animações do catálogo para o R6 -----------------------------------------------------------------
-- Os pacotes do próprio Roblox (Rthro, Stylish, Ninja...) já vêm com os IDs no cliente. Os outros
-- (adidas, Oldschool e o pack UGC "GTA 6") são itens do catálogo: o servidor carrega cada item com
-- InsertService (ou aplica a descrição num esqueleto de teste) e publica os IDs de animação como
-- atributos de ReplicatedStorage.CyberOutlawAnimacoes. O atributo Pacote escolhe o pacote do jogo.
local function catalogAndAdmin()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local InsertService = game:GetService("InsertService")
	local HttpService = game:GetService("HttpService")

	local CATALOG_PACKS = {
		esportivo = { nome = "Esportivo (adidas Sports)", idle = 18538150608, walk = 18538146480, run = 18538133604,
			jump = 18538153691, fall = 18538164337, climb = 18538170170, swim = 18538158932 },
		aura = { nome = "Aura (adidas)", idle = 73137983344853, walk = 75183215343859, run = 123973978164540,
			jump = 129527230938281, fall = 99457463463495, climb = 140398319728398, swim = 119007025452432 },
		classico = { nome = "Clássico (Oldschool)", idle = 5319922112, walk = 5319909330, run = 5319900634,
			jump = 5319917561, fall = 5319914476, climb = 5319931619, swim = 5319927054 },
		gta6 = { nome = "GTA 6 de rua (UGC)", idle = 85896100133621, walk = 126013813901342, run = 116148092038774,
			jump = 100564303449299, fall = 106638217675920, climb = 101562770671987, swim = 94809183107962 },
	}
	local STATES = { "idle", "walk", "run", "jump", "fall", "climb", "swim" }
	local DESCRIPTION_FIELDS = {
		idle = "IdleAnimation", walk = "WalkAnimation", run = "RunAnimation", jump = "JumpAnimation",
		fall = "FallAnimation", climb = "ClimbAnimation", swim = "SwimAnimation",
	}
	local DEFAULT_PACK = "realista"
	local KNOWN_PACKS = { realista = true, estiloso = true, ninja = true, heroi = true, padrao = true }

	local animations = ReplicatedStorage:FindFirstChild("CyberOutlawAnimacoes") or Instance.new("Folder")
	animations.Name = "CyberOutlawAnimacoes"
	if animations:GetAttribute("Pacote") == nil then
		animations:SetAttribute("Pacote", DEFAULT_PACK)
	end
	animations.Parent = ReplicatedStorage

	-- Animation dentro de um item do catálogo: o StringValue pai diz o estado (walk, run, swimidle...).
	local function animationsIn(container: Instance)
		local found = {}
		for _, item in container:GetDescendants() do
			if item:IsA("Animation") and item.AnimationId ~= "" then
				local parent = item.Parent
				local state = if parent and parent:IsA("StringValue") then string.lower(parent.Name) else ""
				table.insert(found, { state = state, id = item.AnimationId })
			end
		end
		return found
	end

	local function fromInsert(pack)
		local result = {}
		for _, state in STATES do
			local ok, model = pcall(InsertService.LoadAsset, InsertService, pack[state])
			if ok and typeof(model) == "Instance" then
				for _, entry in animationsIn(model) do
					if entry.state == "swimidle" then
						result.swimidle = result.swimidle or entry.id
					elseif entry.state == state or entry.state == "" then
						result[state] = result[state] or entry.id
					end
				end
				model:Destroy()
			end
		end
		return result
	end

	-- Plano B: aplicar a descrição num esqueleto R15 com um Animate de mentira e ler os IDs que ele recebeu.
	local function fromDescription(pack)
		local desc = Instance.new("HumanoidDescription")
		for state, field in DESCRIPTION_FIELDS do
			pcall(function()
				(desc :: any)[field] = pack[state]
			end)
		end
		local ok, rig = call(Players, { "CreateHumanoidModelFromDescriptionAsync", "CreateHumanoidModelFromDescription" },
			Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
		if not ok or typeof(rig) ~= "Instance" then
			return {}
		end
		local animate = rig:FindFirstChild("Animate")
		if not animate then
			animate = Instance.new("LocalScript")
			animate.Name = "Animate"
			animate.Enabled = false
			for _, state in { "idle", "walk", "run", "jump", "fall", "climb", "swim", "swimidle" } do
				local value = Instance.new("StringValue")
				value.Name = state
				local animation = Instance.new("Animation")
				animation.Name = state
				animation.Parent = value
				value.Parent = animate
			end
			animate.Parent = rig
		end
		for _, part in rig:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.Transparency = 1
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
			end
		end
		rig:PivotTo(CFrame.new(0, 2000, 0))
		rig.Parent = workspace
		local humanoid = rig:FindFirstChildOfClass("Humanoid")
		if humanoid then
			call(humanoid, { "ApplyDescriptionAsync", "ApplyDescription" }, desc)
		end
		local result = {}
		for _, entry in animationsIn(animate) do
			if entry.state ~= "" and result[entry.state] == nil then
				result[entry.state] = entry.id
			end
		end
		rig:Destroy()
		return result
	end

	task.spawn(function()
		for name, pack in CATALOG_PACKS do
			local ids = fromInsert(pack)
			if not ids.walk or not ids.run then
				local other = fromDescription(pack)
				for state, id in other do
					ids[state] = ids[state] or id
				end
			end
			local count = 0
			for _ in ids do
				count += 1
			end
			if ids.walk and ids.run and ids.idle then
				ids.nome = pack.nome
				animations:SetAttribute(name, HttpService:JSONEncode(ids))
				KNOWN_PACKS[name] = true
			end
			animations:SetAttribute(name .. "_estado", if ids.walk and ids.run then string.format("ok (%d)", count) else "falhou")
		end
	end)

	-- Painel do dono: teleporte para os pontos da cidade e troca do pacote de animação ---------------------
	-- Só o dono do jogo (ou quem estiver no Studio) recebe o atributo CyberOutlawAdmin; o servidor confere
	-- de novo a cada pedido. Os pontos vêm de ReplicatedStorage.CyberOutlawPontos (publicados pela cidade).
	local RunService = game:GetService("RunService")
	local adminRemote = ReplicatedStorage:FindFirstChild("CyberOutlawAdmin") or Instance.new("RemoteEvent")
	adminRemote.Name = "CyberOutlawAdmin"
	adminRemote.Parent = ReplicatedStorage

	local function isAdmin(player: Player): boolean
		if RunService:IsStudio() then
			return true
		end
		if game.CreatorType == Enum.CreatorType.User then
			return player.UserId == game.CreatorId
		end
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		return ok and type(rank) == "number" and rank >= 254
	end

	local lastRequest: { [Player]: number } = {}
	adminRemote.OnServerEvent:Connect(function(player: Player, action, value)
		if not isAdmin(player) or type(action) ~= "string" then
			return
		end
		local now = os.clock()
		if now - (lastRequest[player] or 0) < 0.25 then
			return
		end
		lastRequest[player] = now
		if action == "tp" and type(value) == "string" then
			local points = ReplicatedStorage:FindFirstChild("CyberOutlawPontos")
			local target = points and points:GetAttribute(value)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if typeof(target) == "Vector3" and root then
				character:PivotTo(CFrame.new(target + Vector3.new(0, 3.5, 0)) * root.CFrame.Rotation)
				root.AssemblyLinearVelocity = Vector3.zero
			end
		elseif action == "pacote" and type(value) == "string" and KNOWN_PACKS[value] then
			animations:SetAttribute("Pacote", value)
		end
	end)

	local function markAdmin(player: Player)
		player:SetAttribute("CyberOutlawAdmin", isAdmin(player))
	end
	Players.PlayerAdded:Connect(markAdmin)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(markAdmin, player)
	end
end

-- Só no Roblox (o teste do R6 usa um game falso sem estes serviços).
if typeof(game) == "Instance" then
	catalogAndAdmin()
end
