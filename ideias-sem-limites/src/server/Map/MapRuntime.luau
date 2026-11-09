--!strict
-- Comportamentos do mapa em tempo de jogo (separados da geração para que
-- a geração rode também nos testes offline):
--   * plataformas de teleporte (ProximityPrompt)
--   * zonas de perigo (lava) checadas por raycast barato a cada 0,5 s
--   * acontecimentos ambientais ocasionais por região

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.IdeiasShared.Config)
local Status = require(script.Parent.Parent.Core.Status)
local Fx = require(script.Parent.Parent.Core.Fx)

local MapRuntime = {}

local function hookTeleport(part: Instance)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		local target = part:GetAttribute("Destino")
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if typeof(target) == "CFrame" and root then
			Fx.near(root.Position, 200, "poof", { p = root.Position, s = 1 })
			root.CFrame = target :: CFrame
			Fx.to(player, "toast", { t = "✈️ " .. tostring(part:GetAttribute("Rotulo")), c = Color3.fromRGB(150, 220, 255) })
		end
	end)
end

local function hazards()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	while true do
		task.wait(0.5)
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				params.FilterDescendantsInstances = { char :: Instance }
				local hit = Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), params)
				local part = hit and hit.Instance
				if part and part:HasTag("Perigo") then
					local dps = (part:GetAttribute("Dano") :: number?) or 8
					hum:TakeDamage(dps * 0.5)
					Status.apply(hum, "burn", 2)
				elseif hit and hit.Material == Enum.Material.CrackedLava then
					hum:TakeDamage(3)
					Status.apply(hum, "burn", 1.5)
				end
			end
		end
	end
end

function MapRuntime.start()
	for _, part in CollectionService:GetTagged("IdeiasTeleporte") do
		hookTeleport(part)
	end
	CollectionService:GetInstanceAddedSignal("IdeiasTeleporte"):Connect(hookTeleport)
	task.spawn(hazards)
	-- eventos ambientais leves (sem custo de orçamento): meteoritos decorativos
	-- no céu à noite, gêiser de vapor no vulcão
	task.spawn(function()
		while true do
			task.wait(Config.World.AmbientEventInterval)
			local clock = game:GetService("Lighting").ClockTime
			if clock > 19 or clock < 5 then
				Fx.near(nil, nil, "shootingstar", {})
			end
		end
	end)
end

return MapRuntime
