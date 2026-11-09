--!strict
-- Registro de "atores": jogadores e NPCs criados pelos acontecimentos.
-- Permite consultas baratas por proximidade sem varrer o Workspace.

local Players = game:GetService("Players")

local Actors = {}

export type Npc = {
	kind: "npc",
	id: number,
	eventId: number,
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	faction: string,
	owner: Player?,
	params: { [string]: any },
	def: any,
	[string]: any,
}

local npcs: { [Model]: Npc } = {}
local byHumanoid: { [Humanoid]: Npc } = {}
local playerActors: { [Player]: any } = {}
local count = 0
local nextId = 0

function Actors.register(npc: Npc): Npc
	nextId += 1
	npc.id = nextId
	npcs[npc.model] = npc
	byHumanoid[npc.humanoid] = npc
	count += 1
	return npc
end

function Actors.unregister(npc: Npc)
	if npcs[npc.model] then
		npcs[npc.model] = nil
		byHumanoid[npc.humanoid] = nil
		count -= 1
	end
end

function Actors.count(): number
	return count
end

function Actors.npcs(): { [Model]: Npc }
	return npcs
end

function Actors.playerActor(player: Player): any
	local a = playerActors[player]
	if not a then
		a = { kind = "player", faction = "player", owner = player, player = player }
		playerActors[player] = a
	end
	local char = player.Character
	a.model = char
	a.humanoid = char and char:FindFirstChildOfClass("Humanoid")
	a.root = char and char:FindFirstChild("HumanoidRootPart")
	return a
end

Players.PlayerRemoving:Connect(function(p)
	playerActors[p] = nil
end)

function Actors.ofHumanoid(h: Humanoid): any
	local npc = byHumanoid[h]
	if npc then
		return npc
	end
	local model = h.Parent
	local player = model and Players:GetPlayerFromCharacter(model)
	if player then
		return Actors.playerActor(player)
	end
	return nil
end

function Actors.ofModel(m: Instance): any
	local npc = npcs[m :: Model]
	if npc then
		return npc
	end
	local player = Players:GetPlayerFromCharacter(m)
	if player then
		return Actors.playerActor(player)
	end
	return nil
end

local function alive(a: any): boolean
	return a.humanoid ~= nil and a.humanoid.Health > 0 and a.root ~= nil and a.root.Parent ~= nil
end
Actors.alive = alive

-- todos os atores vivos dentro do raio (jogadores + NPCs)
function Actors.near(pos: Vector3, radius: number): { any }
	local out = {}
	local r2 = radius * radius
	for _, player in Players:GetPlayers() do
		local a = Actors.playerActor(player)
		if alive(a) then
			local d = a.root.Position - pos
			if d:Dot(d) <= r2 then
				table.insert(out, a)
			end
		end
	end
	for _, npc in npcs do
		if alive(npc) then
			local d = npc.root.Position - pos
			if d:Dot(d) <= r2 then
				table.insert(out, npc)
			end
		end
	end
	return out
end

function Actors.players(): { any }
	local out = {}
	for _, player in Players:GetPlayers() do
		local a = Actors.playerActor(player)
		if alive(a) then
			table.insert(out, a)
		end
	end
	return out
end

return Actors
