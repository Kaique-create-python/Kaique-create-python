--!strict
-- Executor de veículos. Física "arcade" estável:
--   terrestres/aquáticos: LinearVelocity no plano XZ + AlignOrientation (sempre em pé)
--   aéreos: LinearVelocity 3D (compensa a gravidade) + AlignOrientation
-- Quando um JOGADOR senta, o cliente dele assume a física e dirige localmente
-- (resposta imediata); o servidor só limita a velocidade máxima.
-- Sem jogador: estaciona; com NPC (vínculo "ride"): piloto automático.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Builders = require(script.Parent.Parent.Builders)
local Fx = require(script.Parent.Parent.Core.Fx)
local Actors = require(script.Parent.Parent.Core.Actors)
local PropActions = require(script.Parent.Parent.Core.PropActions)

local H = { name = "vehicle" }

local active: { any } = {}
local loopStarted = false

function H.estimate(spec: any): { [string]: number }
	return { events = 1, dynamic = 4 * spec.count, parts = 70 * spec.count, effects = 1 }
end

local function setupPhysics(v: any)
	local chassis: BasePart = v.chassis
	local att = Instance.new("Attachment")
	att.Name = "Motor"
	att.Parent = chassis
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Tracao"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	if v.drive == "air" or v.drive == "rocket" then
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.VectorVelocity = Vector3.zero
		lv.MaxForce = 5e5
	else
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.xAxis
		lv.SecondaryTangentAxis = Vector3.zAxis
		lv.PlaneVelocity = Vector2.zero
		lv.MaxForce = 2e5
	end
	lv.Parent = chassis
	local ao = Instance.new("AlignOrientation")
	ao.Name = "Estabilizador"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 5e6
	ao.Responsiveness = 18
	ao.CFrame = chassis.CFrame.Rotation
	ao.Parent = chassis
	v.lv = lv
	v.ao = ao
	v.yaw = math.atan2(-chassis.CFrame.LookVector.X, -chassis.CFrame.LookVector.Z)
end

local function driverPlayer(seat: VehicleSeat): Player?
	local h = seat.Occupant
	return h and Players:GetPlayerFromCharacter(h.Parent)
end

local function autopilot(v: any, dt: number)
	local chassis: BasePart = v.chassis
	local seat: VehicleSeat = v.seat
	local npcDriver = seat.Occupant ~= nil and driverPlayer(seat) == nil
	local speed = 0
	if npcDriver or v.autopilot then
		-- persegue o jogador mais próximo se o piloto for hostil; senão passeia
		local rider = seat.Occupant and Actors.ofHumanoid(seat.Occupant)
		local goal: Vector3? = nil
		if rider and rider.faction == "hostile" then
			local best, bd = nil, 200
			for _, a in Actors.players() do
				local d = (a.root.Position - chassis.Position).Magnitude
				if d < bd then
					best, bd = a, d
				end
			end
			goal = best and best.root.Position
		end
		if not goal then
			v.wanderT = (v.wanderT or 0) - dt
			if v.wanderT <= 0 or not v.wanderGoal then
				v.wanderT = 6
				local ang = math.random() * math.pi * 2
				v.wanderGoal = v.home + Vector3.new(math.cos(ang) * 70, 0, math.sin(ang) * 70)
			end
			goal = v.wanderGoal
		end
		local to = (goal :: Vector3) - chassis.Position
		local desired = math.atan2(-to.X, -to.Z)
		local diff = (desired - v.yaw + math.pi) % (2 * math.pi) - math.pi
		v.yaw += math.clamp(diff, -1.6 * dt, 1.6 * dt)
		speed = if to.Magnitude > 12 then v.maxSpeed * 0.55 else 0
	end
	local look = Vector3.new(-math.sin(v.yaw), 0, -math.cos(v.yaw))
	v.ao.CFrame = CFrame.Angles(0, v.yaw, 0)
	if v.drive == "air" then
		local alt = v.home.Y + (if npcDriver or v.autopilot then 40 else 0)
		local vy = math.clamp((alt - chassis.Position.Y) * 0.8, -20, 20)
		v.lv.VectorVelocity = look * speed + Vector3.new(0, if v.parked then -6 else vy, 0)
	elseif v.drive ~= "rocket" then
		v.lv.PlaneVelocity = Vector2.new(look.X * speed, look.Z * speed)
	end
end

local function rocketLaunch(v: any)
	if v.launched then
		return
	end
	v.launched = true
	local chassis: BasePart = v.chassis
	local player = driverPlayer(v.seat)
	if player then
		Fx.to(player, "toast", { t = "3... 2... 1... DECOLAR! 🚀", c = Color3.fromRGB(255, 200, 80) })
	end
	task.wait(3)
	if not chassis.Parent then
		return
	end
	pcall(function()
		chassis:SetNetworkOwner(nil)
	end)
	local fire = Instance.new("Fire")
	fire.Size = 10
	fire.Heat = 25
	fire.Parent = chassis
	local t0 = os.clock()
	while chassis.Parent and os.clock() - t0 < 5 do
		v.lv.VectorVelocity = Vector3.new(0, 30 + (os.clock() - t0) * 40, 0)
		task.wait(0.1)
	end
	if chassis.Parent then
		local pos = chassis.Position
		local occupant = v.seat.Occupant
		if occupant then
			occupant.Sit = false
			local p = Players:GetPlayerFromCharacter(occupant.Parent)
			if p then
				Fx.to(p, "slowfall", { d = 12 })
			end
		end
		Fx.near(pos, 1000, "fireworks", { p = pos, n = 12 })
		PropActions.explode(pos, 0.6, nil)
		v.model:Destroy()
	end
end

local function step(dt: number)
	for i = #active, 1, -1 do
		local v = active[i]
		if not v.model.Parent then
			table.remove(active, i)
		else
			local player = driverPlayer(v.seat)
			if player then
				-- jogador dirige no próprio cliente; servidor só limita abusos
				local vel = v.chassis.AssemblyLinearVelocity
				if vel.Magnitude > v.maxSpeed * 1.6 then
					v.chassis.AssemblyLinearVelocity = vel.Unit * v.maxSpeed
				end
				v.parked = false
				if v.drive == "rocket" then
					task.spawn(rocketLaunch, v)
				end
			else
				if v.wasDriven then
					pcall(function()
						v.chassis:SetNetworkOwner(nil)
					end)
				end
				v.parked = v.seat.Occupant == nil and not v.autopilot
				autopilot(v, dt)
			end
			v.wasDriven = player ~= nil
		end
	end
end

function H.spawn(ctx: any): any
	if not loopStarted then
		loopStarted = true
		RunService.Heartbeat:Connect(step)
	end
	local params = table.clone(ctx.params)
	params.rng = ctx.rng
	local first: any = nil
	for i = 1, ctx.count do
		local origin = ctx.origin * CFrame.new((i - 1) * 14, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
		if params.drive == "air" then
			origin += Vector3.new(0, 3, 0)
		end
		local v = Builders.vehicle(origin + Vector3.new(0, 1, 0), params)
		v.model.Name = ctx.def.label
		v.model.Parent = ctx.folder
		pcall(function()
			v.chassis:SetNetworkOwner(nil)
		end)
		local rec = {
			model = v.model,
			chassis = v.chassis,
			seat = v.seat,
			drive = v.drive,
			maxSpeed = (params.speed or 60) * (params.speedMul or 1),
			home = v.chassis.Position,
			autopilot = false,
		}
		setupPhysics(rec)
		v.model:SetAttribute("VelMax", rec.maxSpeed)
		table.insert(active, rec)
		PropActions.elementize(v.chassis, params)
		first = first or rec
	end
	Fx.near(ctx.origin.Position, 300, "spawn", { p = ctx.origin.Position, s = 1.5, c = Color3.fromRGB(150, 220, 255) })
	local handle: any = {
		model = first.model,
		seat = first.seat,
		anchor = first.chassis,
		position = first.home,
		radius = 8,
		elements = { params.element },
	}
	-- o vínculo "ride" liga o piloto automático por aqui
	task.spawn(function()
		while first.model.Parent do
			if handle.autopilot then
				first.autopilot = true
			end
			task.wait(0.5)
		end
	end)
	return handle
end

return H
