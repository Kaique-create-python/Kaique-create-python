--!strict
-- Onde cada acontecimento aparece: à frente do jogador, em uma região
-- escolhida ("no vulcão"), no céu, ou perto do centro quando não há dono.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapLayout = require(ReplicatedStorage.IdeiasShared.MapLayout)
local Rng = require(ReplicatedStorage.IdeiasShared.Util.Rng)

local Placement = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = false

local function refreshFilter()
	local ignore = {}
	local ev = Workspace:FindFirstChild("IdeiasEventos")
	if ev then
		table.insert(ignore, ev)
	end
	for _, p in game:GetService("Players"):GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
end

-- ponto no chão abaixo (ou acima) de pos
function Placement.ground(pos: Vector3, fromHeight: number?): Vector3
	refreshFilter()
	local up = fromHeight or 140
	local result = Workspace:Raycast(pos + Vector3.new(0, up, 0), Vector3.new(0, -up - 400, 0), params)
	if result then
		return result.Position
	end
	return Vector3.new(pos.X, 0, pos.Z)
end

local function facing(at: Vector3, lookTo: Vector3): CFrame
	local flat = Vector3.new(lookTo.X, at.Y, lookTo.Z)
	if (flat - at).Magnitude < 0.1 then
		return CFrame.new(at)
	end
	return CFrame.lookAt(at, flat)
end

-- à frente do jogador; index/total espalham várias ideias lado a lado
function Placement.forPlayer(player: Player?, distance: number, index: number?, total: number?): CFrame
	local char = player and player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local i, n = index or 1, total or 1
	if not root then
		local base = Vector3.new((i - (n + 1) / 2) * 24, 0, -30)
		return facing(Placement.ground(base), Vector3.new(0, 0, 30))
	end
	local look = root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	local right = look:Cross(Vector3.yAxis)
	local lateral = (i - (n + 1) / 2) * (distance * 0.9)
	local target = root.Position + look * distance + right * lateral
	local g = Placement.ground(target, 60)
	return facing(g, root.Position)
end

function Placement.region(regionId: string, rng: Rng.Rng): CFrame
	local r = MapLayout.ById[regionId] or MapLayout.ById.hub
	local ang = rng:range(0, math.pi * 2)
	local dist = rng:range(0, r.radius * 0.5)
	local pos = r.center + Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
	if regionId == "sky" then
		return CFrame.new(Placement.ground(pos + Vector3.new(0, 60, 0), 20))
	elseif regionId == "arena" then
		return CFrame.new(Placement.ground(r.center + Vector3.new(rng:range(-30, 30), 10, rng:range(-30, 30)), 15))
	end
	return facing(Placement.ground(pos), r.center)
end

function Placement.sky(base: CFrame, height: number): CFrame
	return base + Vector3.new(0, height, 0)
end

return Placement
