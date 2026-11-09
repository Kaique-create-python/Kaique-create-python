--!strict
-- Veículos procedurais. Todos têm um "Chassi" invisível (parte principal),
-- um VehicleSeat e peças soldadas. Rodas e hélices recebem juntas "wheel"/"spin"
-- que o cliente anima localmente.

local Kit = require(script.Parent.Kit)

local Vehicles = {}

local rgb = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local PAINT = { rgb(220, 40, 45), rgb(40, 110, 230), rgb(250, 200, 40), rgb(40, 170, 90), rgb(240, 240, 245), rgb(30, 30, 35), rgb(255, 120, 30), rgb(150, 70, 200) }

export type VehicleResult = {
	model: Model,
	chassis: BasePart,
	seat: VehicleSeat,
	length: number,
	height: number,
	drive: string,
}

local function spinJoint(part: BasePart, chassis: BasePart, kind: string, axis: string, speed: number)
	local m = Instance.new("Motor6D")
	m.Part0 = chassis
	m.Part1 = part
	m.C0 = chassis.CFrame:Inverse() * part.CFrame
	m.C1 = CFrame.identity
	m:SetAttribute("Anim", kind)
	m:SetAttribute("AnimAxis", axis)
	m:SetAttribute("AnimAmp", 1)
	m:SetAttribute("AnimPhase", 0)
	m:SetAttribute("AnimSpeed", speed)
	m.Parent = chassis
end

function Vehicles.build(origin: CFrame, params: { [string]: any }, variant: string): VehicleResult
	local p = table.clone(params)
	p.anchored = false
	p.collide = false
	local b = Kit.new(variant, origin, p)
	local rng = params.rng
	local paint = if rng then rng:pick(PAINT) else PAINT[1]
	local glass = rgb(150, 210, 240)
	local dark = rgb(30, 30, 35)
	local spinners: { { any } } = {}
	local drive = params.drive or "ground"

	local L, W, H = 9, 5, 2 -- dimensões do chassi (frente = -Z)
	local seatPos = V(0, 2.2, 0.5)
	local function wheel(x: number, z: number, d: number)
		local w = b:part("cyl", V(0.9, d, d), CF(x, d / 2, z), dark, { role = "fixed", collide = false, name = "Roda" })
		b:part("cyl", V(0.95, d * 0.45, d * 0.45), CF(x, d / 2, z), rgb(200, 200, 210), { role = "fixed", material = Enum.Material.Metal, collide = false })
		table.insert(spinners, { w, "wheel", "X", 6 })
	end
	local function lights(z: number, y: number, x: number)
		for _, side in { -1, 1 } do
			b:box(V(0.6, 0.35, 0.1), CF(side * x, y, z), rgb(255, 250, 210), { role = "fixed", material = Enum.Material.Neon })
			b:box(V(0.6, 0.35, 0.1), CF(side * x, y, -z), rgb(230, 30, 30), { role = "fixed", material = Enum.Material.Neon })
		end
	end

	if variant == "car" or variant == "sportscar" or variant == "police_car" then
		local low = variant == "sportscar"
		local col = if variant == "police_car" then rgb(245, 245, 248) else paint
		L, W = if low then 10 else 9, 5
		local bodyY = if low then 1.5 else 1.8
		b:box(V(W, 1.4, L), CF(0, bodyY, 0), col, { role = "primary" })
		b:part("wedge", V(W, 0.8, 2.2), CF(0, bodyY + 1.1, -1.8) * ANG(0, rad(180), 0), glass, { role = "fixed", material = Enum.Material.Glass, transparency = 0.3 })
		b:box(V(W - 0.2, if low then 0.9 else 1.2, 3.4), CF(0, bodyY + (if low then 1.1 else 1.3), 0.6), if low then col else glass, { role = if low then "primary" else "fixed", material = if low then Enum.Material.SmoothPlastic else Enum.Material.Glass, transparency = if low then 0 else 0.3 })
		b:box(V(W - 0.1, 0.25, 3.5), CF(0, bodyY + (if low then 1.6 else 1.95), 0.6), col, { role = "primary" })
		b:box(V(W + 0.1, 0.4, 0.4), CF(0, bodyY - 0.4, -L / 2), rgb(60, 60, 65), { role = "fixed" })
		b:box(V(W + 0.1, 0.4, 0.4), CF(0, bodyY - 0.4, L / 2), rgb(60, 60, 65), { role = "fixed" })
		lights(-L / 2 - 0.02, bodyY + 0.2, W / 2 - 0.7)
		if low then
			b:box(V(W, 0.15, 1.2), CF(0, bodyY + 1.4, L / 2 - 0.4), dark, { role = "fixed" })
			for _, side in { -1, 1 } do
				b:box(V(0.2, 0.7, 0.3), CF(side * 1.8, bodyY + 1.0, L / 2 - 0.4), dark, { role = "fixed" })
			end
			b:box(V(W * 0.3, 0.1, L * 0.8), CF(0, bodyY + 0.72, -0.2), rgb(250, 250, 250), { role = "accent" })
		end
		if variant == "police_car" then
			b:box(V(W - 0.1, 0.9, L * 0.55), CF(0, bodyY, 0), dark, { role = "fixed" })
			b:box(V(0.9, 0.35, 0.5), CF(-0.6, bodyY + 2.25, 0.6), rgb(255, 40, 40), { role = "fixed", material = Enum.Material.Neon })
			b:box(V(0.9, 0.35, 0.5), CF(0.6, bodyY + 2.25, 0.6), rgb(40, 80, 255), { role = "fixed", material = Enum.Material.Neon })
		end
		for _, z in { -L / 2 + 1.6, L / 2 - 1.6 } do
			for _, side in { -1, 1 } do
				wheel(side * (W / 2), z, 2)
			end
		end
		seatPos = V(-0.9, bodyY + 0.8, 0.4)
		H = bodyY + 2
	elseif variant == "truck" or variant == "firetruck" or variant == "bus" then
		local col = if variant == "firetruck" then rgb(210, 30, 30) elseif variant == "bus" then rgb(250, 200, 30) else paint
		L, W = if variant == "bus" then 18 else 14, 6
		if variant == "bus" then
			b:box(V(W, 5, L), CF(0, 3.5, 0), col, { role = "primary" })
			for k = 0, 5 do
				for _, side in { -1, 1 } do
					b:box(V(0.1, 1.6, 2.0), CF(side * W / 2, 4.3, -L / 2 + 2 + k * 2.6), glass, { role = "fixed", material = Enum.Material.Glass, transparency = 0.25 })
				end
			end
			b:box(V(W - 0.4, 2.2, 0.1), CF(0, 4.2, -L / 2), glass, { role = "fixed", material = Enum.Material.Glass, transparency = 0.25 })
			b:box(V(W + 0.05, 0.4, L + 0.05), CF(0, 2.0, 0), dark, { role = "fixed" })
			seatPos = V(-1.6, 2.6, -L / 2 + 2.2)
		else
			b:box(V(W, 4, 4), CF(0, 3, -L / 2 + 2), col, { role = "primary" })
			b:box(V(W - 0.4, 1.6, 0.1), CF(0, 3.8, -L / 2), glass, { role = "fixed", material = Enum.Material.Glass, transparency = 0.25 })
			b:box(V(W - 0.4, 0.6, L - 4.5), CF(0, 1.5, 2.2), rgb(70, 70, 75), { role = "fixed" })
			if variant == "firetruck" then
				b:box(V(W, 2.4, L - 4.6), CF(0, 2.9, 2.2), col, { role = "primary" })
				b:box(V(W + 0.05, 0.4, L - 4.5), CF(0, 2.3, 2.2), rgb(250, 250, 250), { role = "fixed" })
				for _, side in { -1, 1 } do
					b:box(V(0.25, 0.25, L - 5), CF(side * 0.9, 4.5, 2.2), rgb(200, 200, 210), { role = "fixed", material = Enum.Material.Metal })
				end
				for k = 0, 7 do
					b:box(V(1.9, 0.18, 0.18), CF(0, 4.5, -0.2 + k * 1.1), rgb(200, 200, 210), { role = "fixed", material = Enum.Material.Metal })
				end
				b:box(V(1.6, 0.4, 0.5), CF(0, 5.1, -L / 2 + 2), rgb(40, 80, 255), { role = "fixed", material = Enum.Material.Neon })
			else
				b:box(V(W, 3.6, L - 4.6), CF(0, 3.5, 2.2), Kit.lighter(col, 0.3), { role = "secondary" })
			end
			seatPos = V(-1.5, 2.6, -L / 2 + 2)
		end
		lights(-L / 2 - 0.02, 2.2, W / 2 - 0.8)
		for _, z in { -L / 2 + 2, L / 2 - 2.5 } do
			for _, side in { -1, 1 } do
				wheel(side * (W / 2), z, 2.6)
			end
		end
		H = 6
	elseif variant == "tractor" then
		L, W = 8, 5
		local col = rgb(60, 160, 60)
		b:box(V(3, 2.4, 5), CF(0, 2.6, -0.5), col, { role = "primary" })
		b:box(V(3.4, 3, 2.6), CF(0, 4.3, 1.6), glass, { role = "fixed", material = Enum.Material.Glass, transparency = 0.35 })
		b:box(V(3.5, 0.3, 2.8), CF(0, 5.9, 1.6), col, { role = "primary" })
		b:cylY(2, 0.4, CF(0.8, 4.4, -2.2), dark, { role = "fixed" })
		for _, side in { -1, 1 } do
			wheel(side * 2.4, 2.2, 4.2)
			wheel(side * 1.9, -2.6, 2.2)
		end
		seatPos = V(0, 3.4, 1.6)
		H = 6
	elseif variant == "tank" then
		L, W = 11, 7
		local col = rgb(90, 105, 70)
		b:box(V(W - 2, 2, L), CF(0, 2.2, 0), col, { role = "primary" })
		for _, side in { -1, 1 } do
			b:box(V(1.4, 2, L + 0.6), CF(side * (W / 2 - 0.7), 1.1, 0), dark, { role = "fixed" })
			for k = -2, 2 do
				b:part("cyl", V(1.45, 1.4, 1.4), CF(side * (W / 2 - 0.7), 1.0, k * 2), rgb(70, 70, 70), { role = "fixed" })
			end
		end
		b:part("cyl", V(1.6, 4.6, 4.6), CF(0, 4, 0.5) * ANG(0, 0, rad(90)), col, { role = "primary" })
		b:part("cyl", V(6, 0.7, 0.7), CF(0, 4.1, -3.5) * ANG(0, rad(90), 0), Kit.darker(col, 0.2), { role = "secondary" })
		seatPos = V(0, 3.4, 1.8)
		H = 5
	elseif variant == "motorcycle" then
		L, W = 6, 1.6
		b:box(V(0.8, 1.2, 3.4), CF(0, 2.0, 0), paint, { role = "primary" })
		b:part("wedge", V(0.9, 0.9, 1.2), CF(0, 2.6, -1.8) * ANG(0, rad(180), 0), paint, { role = "primary" })
		b:box(V(2.2, 0.15, 0.15), CF(0, 3.1, -1.9), dark, { role = "fixed" })
		b:box(V(0.6, 0.3, 0.1), CF(0, 2.5, -2.45), rgb(255, 250, 200), { role = "fixed", material = Enum.Material.Neon })
		wheel(0, -2.1, 2.2)
		wheel(0, 2.1, 2.2)
		seatPos = V(0, 2.5, 0.6)
		H = 3
		W = 2.4
	elseif variant == "skateboard" then
		L, W = 4, 1.4
		b:box(V(1.4, 0.2, 4), CF(0, 0.7, 0), paint, { role = "primary" })
		b:box(V(1.2, 0.05, 3.6), CF(0, 0.82, 0), rgb(80, 255, 220), { role = "accent", material = Enum.Material.Neon })
		for _, z in { -1.4, 1.4 } do
			for _, side in { -1, 1 } do
				wheel(side * 0.5, z, 0.5)
			end
		end
		seatPos = V(0, 1.2, 0)
		H = 1
	elseif variant == "boat" or variant == "ship" then
		local big = variant == "ship"
		L, W = if big then 26 else 12, if big then 9 else 5
		local hull = if big then rgb(110, 70, 40) else rgb(245, 245, 250)
		b:box(V(W, 2.2, L - 3), CF(0, 1.6, 1), hull, { role = "primary", material = if big then Enum.Material.WoodPlanks else Enum.Material.SmoothPlastic })
		b:part("wedge", V(W, 2.2, 4), CF(0, 1.6, -L / 2 + 1.5) * ANG(0, rad(180), 0), hull, { role = "primary", material = if big then Enum.Material.WoodPlanks else Enum.Material.SmoothPlastic })
		b:box(V(W - 0.6, 0.3, L - 2.5), CF(0, 2.75, 0.8), rgb(180, 140, 90), { role = "fixed", material = Enum.Material.WoodPlanks })
		if big then
			for _, z in { -4, 4 } do
				b:cylY(14, 0.7, CF(0, 9.8, z), rgb(90, 60, 35), { role = "fixed" })
				b:box(V(8, 6, 0.2), CF(0, 11, z - 0.3), rgb(240, 235, 220), { role = "fixed", material = Enum.Material.Fabric })
			end
			b:box(V(2.5, 1.6, 0.1), CF(0, 17.4, -4), rgb(20, 20, 20), { role = "fixed" })
			b:box(V(W, 3, 4), CF(0, 4.2, L / 2 - 2.5), hull, { role = "primary", material = Enum.Material.WoodPlanks })
			for k = -2, 2 do
				b:part("cyl", V(2, 0.6, 0.6), CF(W / 2 + 0.6, 2.3, k * 3) * ANG(0, 0, 0), dark, { role = "fixed" })
			end
			seatPos = V(0, 3.4, L / 2 - 5)
		else
			b:part("wedge", V(W - 1, 1.2, 1.4), CF(0, 3.5, -1.5) * ANG(0, rad(180), 0), glass, { role = "fixed", material = Enum.Material.Glass, transparency = 0.3 })
			b:box(V(1.4, 1.6, 1.2), CF(0, 2.4, L / 2), dark, { role = "fixed" })
			seatPos = V(0, 3.2, 1)
		end
		H = if big then 18 else 4
	elseif variant == "plane" or variant == "spaceship" then
		local space = variant == "spaceship"
		L, W = 14, 16
		local col = if space then rgb(220, 225, 235) else paint
		b:part("cyl", V(L, 2.6, 2.6), CF(0, 3, 0) * ANG(0, rad(90), 0), col, { role = "primary" })
		b:part("ball", V(2.6, 2.6, 3), CF(0, 3, -L / 2), col, { role = "primary" })
		b:part("ball", V(1.8, 1.4, 3.2), CF(0, 4.1, -L / 2 + 2.5), glass, { role = "fixed", material = Enum.Material.Glass, transparency = 0.2 })
		if space then
			b:part("wedge", V(W, 0.5, 6), CF(0, 2.6, 1.5), col, { role = "primary" })
			for _, side in { -1, 1 } do
				b:part("cyl", V(3, 1.2, 1.2), CF(side * 2.4, 2.8, L / 2 - 0.5) * ANG(0, rad(90), 0), rgb(60, 60, 70), { role = "fixed" })
				b:part("cyl", V(0.3, 1.0, 1.0), CF(side * 2.4, 2.8, L / 2 + 1.05) * ANG(0, rad(90), 0), rgb(90, 200, 255), { role = "accent", material = Enum.Material.Neon })
			end
		else
			b:box(V(W, 0.4, 3), CF(0, 2.6, -0.5), col, { role = "primary" })
			b:box(V(5, 0.3, 1.6), CF(0, 3.2, L / 2 - 1), col, { role = "primary" })
			b:part("wedge", V(0.3, 2.4, 2.2), CF(0, 4.6, L / 2 - 1), col, { role = "primary" })
			local prop = b:box(V(4.4, 0.4, 0.15), CF(0, 3, -L / 2 - 1.5), dark, { role = "fixed", name = "Helice" })
			table.insert(spinners, { prop, "spin", "Z", 10 })
			for _, side in { -1, 1 } do
				wheel(side * 1.5, -1, 1.2)
			end
		end
		seatPos = V(0, 3.4, -L / 2 + 2.5)
		H = 5
	elseif variant == "helicopter" then
		L, W = 12, 4
		local col = paint
		b:part("ball", V(4, 3.6, 5.4), CF(0, 3.4, -1), col, { role = "primary" })
		b:part("ball", V(3.4, 2.6, 2.6), CF(0, 3.6, -3.1), glass, { role = "fixed", material = Enum.Material.Glass, transparency = 0.25 })
		b:part("cyl", V(6.5, 0.8, 0.8), CF(0, 3.8, 4) * ANG(0, rad(90), 0), col, { role = "primary" })
		b:part("wedge", V(0.3, 2, 1.6), CF(0, 4.9, 7), col, { role = "primary" })
		for _, side in { -1, 1 } do
			b:box(V(0.3, 0.3, 6), CF(side * 1.6, 0.6, -0.8), dark, { role = "fixed" })
			b:box(V(0.2, 1.4, 0.2), CF(side * 1.4, 1.2, -0.8), dark, { role = "fixed" })
		end
		b:cylY(0.8, 0.5, CF(0, 5.5, -1), dark, { role = "fixed" })
		local rotor = b:box(V(13, 0.2, 0.7), CF(0, 6, -1), dark, { role = "fixed", name = "Rotor" })
		table.insert(spinners, { rotor, "spin", "Y", 12 })
		local tail = b:box(V(0.15, 2.4, 0.4), CF(0.5, 4.9, 7.2), dark, { role = "fixed", name = "RotorCauda" })
		table.insert(spinners, { tail, "spin", "X", 14 })
		seatPos = V(0, 2.6, -2.2)
		H = 6
	elseif variant == "rocket" then
		L, W = 4, 4
		b:cylY(12, 3.2, CF(0, 7, 0), rgb(245, 245, 250), { role = "primary" })
		b:cone(4, 3.2, CF(0, 13, 0), rgb(220, 40, 40), 4, { role = "secondary" })
		b:part("cyl", V(0.2, 1.4, 1.4), CF(0, 10, -1.6) * ANG(0, rad(90), 0), glass, { role = "fixed", material = Enum.Material.Glass })
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2
			b:part("wedge", V(0.3, 3, 2), CF(math.cos(a) * 1.9, 2.4, math.sin(a) * 1.9) * ANG(0, -a + math.pi / 2, 0), rgb(220, 40, 40), { role = "secondary" })
		end
		b:cylY(1, 2.2, CF(0, 0.6, 0), dark, { role = "fixed" })
		seatPos = V(0, 9, 0)
		H = 17
	elseif variant == "hot_air_balloon" then
		L, W = 6, 6
		local cols = { rgb(230, 50, 50), rgb(255, 210, 50), rgb(60, 140, 240) }
		b:ball(16, CF(0, 20, 0), cols[1], { role = "primary" })
		for k = 1, 3 do
			b:part("cyl", V(1.6, 16.2 - k * 2.5, 16.2 - k * 2.5), CF(0, 20 + (k - 2) * 4.2, 0) * ANG(0, 0, rad(90)), cols[(k % 3) + 1], { role = "secondary" })
		end
		b:box(V(5, 3, 5), CF(0, 1.8, 0), rgb(150, 100, 55), { role = "fixed", material = Enum.Material.WoodPlanks })
		for _, x in { -2.2, 2.2 } do
			for _, z in { -2.2, 2.2 } do
				b:beam(V(x, 3.3, z), V(x * 1.6, 13, z * 1.6), 0.12, rgb(80, 60, 40), { role = "fixed" })
			end
		end
		local fire = b:ball(1.2, CF(0, 5, 0), rgb(255, 160, 40), { role = "fixed", material = Enum.Material.Neon })
		local f = Instance.new("Fire")
		f.Size = 4
		f.Parent = fire
		seatPos = V(0, 2, 0)
		H = 28
	elseif variant == "train" then
		L, W = 20, 6
		local col = rgb(40, 50, 60)
		b:part("cyl", V(9, 4, 4), CF(0, 4, -4.5) * ANG(0, rad(90), 0), col, { role = "primary" })
		b:box(V(W, 5, 4), CF(0, 4.6, 1.6), rgb(170, 30, 30), { role = "secondary" })
		b:cylY(2.6, 1.3, CF(0, 7.2, -7.3), dark, { role = "fixed" })
		b:part("wedge", V(W, 2, 2), CF(0, 1.5, -9.6) * ANG(0, rad(180), 0), rgb(200, 30, 30), { role = "secondary" })
		b:box(V(W, 4, 7), CF(0, 4, 7.5), rgb(120, 80, 45), { role = "fixed", material = Enum.Material.WoodPlanks })
		for _, z in { -7, -3, 1, 6, 9 } do
			for _, side in { -1, 1 } do
				wheel(side * (W / 2), z, 2.4)
			end
		end
		local smoke = Instance.new("Smoke")
		smoke.Color = rgb(220, 220, 220)
		smoke.Opacity = 0.3
		smoke.RiseVelocity = 6
		smoke.Parent = b.parts[#b.parts]
		seatPos = V(0, 3.2, 1.6)
		H = 8
	end

	-- chassi físico e assento
	local chassisY = if drive == "air" then H * 0.4 else 1.5
	local chassis = b:box(V(W, 1, L), CF(0, chassisY, 0), rgb(0, 0, 0), { role = "fixed", transparency = 1, collide = true, name = "Chassi" })
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.25, 0.1, 1, 1)
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Assento"
	seat.Size = V(2, 0.4, 2) * b.s
	seat.CFrame = b:at(CF(seatPos))
	seat.Transparency = 0.5
	seat.Color = rgb(40, 40, 45)
	seat.Anchored = false
	seat.CanCollide = false
	seat.MaxSpeed = params.speed or 60
	seat.Torque = 1e5
	seat.TurnSpeed = 2
	seat.Parent = b.model
	table.insert(b.parts, seat)
	b.roles[seat] = "fixed"

	local model = b:finish(chassis)
	for _, part in b.parts do
		if part ~= chassis then
			part.Massless = true
		end
	end
	for _, s in spinners do
		spinJoint(s[1], chassis, s[2], s[3], s[4])
	end
	-- soldas rígidas para tudo que não gira
	local spinning = {}
	for _, s in spinners do
		spinning[s[1]] = true
	end
	for _, part in b.parts do
		if part ~= chassis and not spinning[part] then
			local w = Instance.new("WeldConstraint")
			w.Part0 = chassis
			w.Part1 = part
			w.Parent = part
		end
	end
	model:SetAttribute("Veiculo", variant)
	model:SetAttribute("Conducao", drive)
	model:AddTag("IdeiasVeiculo")
	return {
		model = model,
		chassis = chassis,
		seat = seat,
		length = L * b.s,
		height = H * b.s,
		drive = drive,
	}
end

return Vehicles
