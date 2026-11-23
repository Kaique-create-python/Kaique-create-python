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
