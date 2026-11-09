--!strict
-- Inteligência dos NPCs. Um único laço no Heartbeat agenda todos os NPCs,
-- cada um "pensa" a cada ~0,3 s (escalonado), o que mantém o custo baixo
-- mesmo com dezenas de criaturas.
-- Terrestres: Humanoid:MoveTo + detecção de travamento + Pathfinding sob demanda.
-- Voadores: AlignPosition/AlignOrientation (física suave replicada pelo servidor).

local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.IdeiasShared.Config)
local Actors = require(script.Parent.Parent.Core.Actors)
local Factions = require(script.Parent.Parent.Core.Factions)
local Abilities = require(script.Parent.Abilities)

local Brain = {}

local list: { any } = {}
local started = false
Brain.freezeUntil = 0 -- "parar o tempo"
Brain.slowUntil = 0 -- "câmera lenta"
local pathBudget = 0 -- cálculos de caminho permitidos neste segundo

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundBelow(pos: Vector3, ignore: { Instance }): number?
	rayParams.FilterDescendantsInstances = ignore
	local r = Workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -300, 0), rayParams)
	return r and r.Position.Y
end

function Brain.add(npc: any)
	npc.nextThink = os.clock() + math.random() * Config.Combat.NpcThinkInterval
	npc.home = npc.home or npc.root.Position
	npc.lastPos = npc.root.Position
	npc.stuck = 0
	npc.wanderAt = 0
	npc.cd = npc.cd or {}
	table.insert(list, npc)
	if npc.flying then
		Brain.setupFlight(npc)
	end
end

function Brain.remove(npc: any)
	local i = table.find(list, npc)
	if i then
		table.remove(list, i)
	end
end

function Brain.count(): number
	return #list
end

function Brain.setupFlight(npc: any)
	local root: BasePart = npc.root
	local att = root:FindFirstChild("VooAtt") :: Attachment?
	if not att then
		att = Instance.new("Attachment")
		att.Name = "VooAtt"
		att.Parent = root
	end
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 1e7
	ap.MaxVelocity = npc.speed
	ap.Responsiveness = 18
	ap.Position = root.Position
	ap.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e7
	ao.Responsiveness = 12
	ao.CFrame = root.CFrame
	ao.Parent = root
	npc.align = ap
	npc.alignOri = ao
	npc.humanoid.PlatformStand = true
	npc.hover = npc.hover or (10 + 6 * npc.scale)
end

local function speedOf(npc: any, now: number): number
	local s = npc.speed
	if npc.chargeUntil and now < npc.chargeUntil then
		s *= 2.4
	end
	if now < Brain.slowUntil and npc.faction ~= "pet" then
		s *= 0.3
	end
	return s
end

local function flyTo(npc: any, target: Vector3, look: Vector3?, now: number)
	local g = groundBelow(target, { npc.model, Workspace:FindFirstChild("IdeiasEventos") :: Instance })
	local y = math.max(target.Y, (g or target.Y) + npc.hover)
	local goal = Vector3.new(target.X, y, target.Z)
	npc.align.Position = goal
	npc.align.MaxVelocity = speedOf(npc, now)
	local pos = npc.root.Position
	local dir = (look or goal) - pos
	dir = Vector3.new(dir.X, dir.Y * 0.3, dir.Z)
	if dir.Magnitude > 1 then
		npc.alignOri.CFrame = CFrame.lookAt(pos, pos + dir.Unit)
	end
end

local function computePath(npc: any, goal: Vector3)
	if pathBudget <= 0 or npc.computing then
		return
	end
	pathBudget -= 1
	npc.computing = true
	task.spawn(function()
		local path = npc.path
		if not path then
			path = PathfindingService:CreatePath({
				AgentRadius = math.clamp(2 * npc.scale, 2, 10),
				AgentHeight = math.clamp(5 * npc.scale, 4, 30),
				AgentCanJump = true,
				WaypointSpacing = 6,
			})
			npc.path = path
		end
		local ok = pcall(function()
			path:ComputeAsync(npc.root.Position, goal)
		end)
		npc.computing = false
		if ok and path.Status == Enum.PathStatus.Success then
			npc.waypoints = path:GetWaypoints()
			npc.wpIndex = 2
			npc.pathUntil = os.clock() + 4
		end
	end)
end

local function walkTo(npc: any, goal: Vector3, now: number)
	local h: Humanoid = npc.humanoid
	h.WalkSpeed = speedOf(npc, now)
	-- seguindo um caminho calculado?
	if npc.waypoints and npc.pathUntil and now < npc.pathUntil then
		local wp = npc.waypoints[npc.wpIndex]
		if wp then
			if (wp.Position - npc.root.Position).Magnitude < 4 then
				npc.wpIndex += 1
				wp = npc.waypoints[npc.wpIndex]
			end
			if wp then
				if wp.Action == Enum.PathWaypointAction.Jump then
					h.Jump = true
				end
				h:MoveTo(wp.Position)
				return
			end
		end
		npc.waypoints = nil
	end
	h:MoveTo(goal)
	-- travado? pula, desvia e pede um caminho
	local moved = (npc.root.Position - npc.lastPos).Magnitude
	npc.lastPos = npc.root.Position
	if moved < 0.6 and (goal - npc.root.Position).Magnitude > 6 then
		npc.stuck += 1
		if npc.stuck == 2 then
			h.Jump = true
		elseif npc.stuck >= 4 then
			npc.stuck = 0
			computePath(npc, goal)
		end
	else
		npc.stuck = 0
	end
end

local function moveTo(npc: any, goal: Vector3, now: number, look: Vector3?)
	if npc.flying then
		flyTo(npc, goal, look, now)
	else
		walkTo(npc, goal, now)
	end
end

local function hold(npc: any, now: number)
	if npc.flying then
		flyTo(npc, npc.root.Position, nil, now)
	else
		npc.humanoid:MoveTo(npc.root.Position)
	end
end

local function pickTarget(npc: any): (any?, number)
	local pos = npc.root.Position
	local range = Config.Combat.TargetRange
	if npc.faction == "neutral" then
		range = 45
	end
	local center = pos
	if npc.guard then
		center = npc.guard.position
		range = npc.guard.radius * 2
	end
	-- mantém o alvo atual se ainda é válido (evita trocar a cada instante)
	local cur = npc.target
	if cur and Actors.alive(cur) and Factions.hostileTo(npc, cur) then
		local d = (cur.root.Position - pos).Magnitude
		if d < range * 1.3 then
			return cur, d
		end
	end
	local best, bestD = nil, math.huge
	for _, a in Actors.near(center, range) do
		if a ~= npc and Factions.hostileTo(npc, a) then
			local d = (a.root.Position - pos).Magnitude
			if d < bestD then
				best, bestD = a, d
			end
		end
	end
	return best, bestD
end

local function threatNear(npc: any): any?
	local pos = npc.root.Position
	for _, a in Actors.near(pos, 34) do
		if a.kind == "npc" and a ~= npc then
			local hunts = a.prey and a.prey[npc.eventId]
			local scary = npc.def and npc.def.tagSet and npc.def.tagSet.prey and a.faction == "hostile"
			if hunts or scary or (npc.fleeFrom and npc.fleeFrom[a.eventId]) then
				return a
			end
		end
	end
	return nil
end

local function think(npc: any, now: number)
	local h: Humanoid = npc.humanoid
	if npc.riding then
		return
	end
	if now < Brain.freezeUntil and npc.faction ~= "pet" then
		hold(npc, now)
		return
	end
	if npc.busyUntil and now < npc.busyUntil then
		return
	end
	if npc.behavior == "dance" then
		npc.model:SetAttribute("Dancando", true)
		hold(npc, now)
		return
	end

	Abilities.support(npc, now)

	local target, dist = pickTarget(npc)
	npc.target = target
	if target then
		local stop = Abilities.tryUse(npc, target, dist, now)
		if stop then
			hold(npc, now)
			return
		end
		local tpos = target.root.Position
		local pref = Abilities.preferredRange(npc)
		if pref > 0 and dist < pref * 0.7 then
			-- atirador: recua mantendo distância
			local away = (npc.root.Position - tpos)
			away = Vector3.new(away.X, 0, away.Z)
			if away.Magnitude > 0.1 then
				moveTo(npc, npc.root.Position + away.Unit * 12, now, tpos)
			end
		elseif pref > 0 and dist < pref then
			hold(npc, now)
			if npc.flying then
				flyTo(npc, npc.root.Position, tpos, now)
			end
		else
			local goal = if npc.flying then tpos + Vector3.new(0, 4 + 2 * npc.scale, 0) else tpos
			moveTo(npc, goal, now, tpos)
		end
		return
	end

	-- presas fogem de predadores
	local threat = threatNear(npc)
	if threat then
		local away = npc.root.Position - threat.root.Position
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude > 0.1 then
			h.WalkSpeed = npc.speed * 1.3
			moveTo(npc, npc.root.Position + away.Unit * 25, now)
			return
		end
	end

	-- seguir o dono (mascotes e aliados)
	local owner: Player? = npc.owner
	if owner and (npc.faction == "pet" or npc.faction == "ally") then
		local oa = Actors.playerActor(owner)
		if Actors.alive(oa) then
			local d = (oa.root.Position - npc.root.Position).Magnitude
			local near = if npc.faction == "pet" then 10 else 22
			if d > near then
				if d > 160 then
					-- ficou muito para trás: teleporta perto do dono
					npc.root.CFrame = oa.root.CFrame * CFrame.new(math.random(-6, 6), 4 + npc.hover * (if npc.flying then 1 else 0), 8)
				else
					moveTo(npc, oa.root.Position, now)
				end
			else
				hold(npc, now)
			end
			return
		end
	end

	-- guarda: patrulha em volta do ponto protegido
	if npc.guard then
		local g = npc.guard
		local ang = now * 0.4 + npc.id
		local r = g.radius * 0.8
		moveTo(npc, g.position + Vector3.new(math.cos(ang) * r, if npc.flying then 12 else 0, math.sin(ang) * r), now)
		return
	end

	-- vagar perto de casa
	if now >= npc.wanderAt then
		npc.wanderAt = now + 3 + math.random() * 4
		local radius = if npc.faction == "hostile" then 30 else 22
		local ang = math.random() * math.pi * 2
		npc.wanderGoal = npc.home + Vector3.new(math.cos(ang) * radius, 0, math.sin(ang) * radius)
	end
	if npc.wanderGoal then
		moveTo(npc, npc.wanderGoal, now)
	end
end

local function step(_dt: number)
	local now = os.clock()
	local interval = Config.Combat.NpcThinkInterval
	for i = #list, 1, -1 do
		local npc = list[i]
		if npc and now >= npc.nextThink then
			npc.nextThink = now + interval * (0.85 + math.random() * 0.3)
			if not Actors.alive(npc) or npc.dead then
				table.remove(list, i)
			else
				local ok, err = pcall(think, npc, now)
				if not ok then
					warn("[Ideias] NPC " .. tostring(npc.def and npc.def.id) .. ": " .. tostring(err))
					npc.nextThink = now + 2
				end
			end
		end
	end
end

function Brain.start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(step)
	task.spawn(function()
		while true do
			pathBudget = 4
			task.wait(1)
		end
	end)
end

Brain._think = think

return Brain
