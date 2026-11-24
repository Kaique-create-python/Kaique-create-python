-- CyberOutlaw · gameplay (LocalScript in StarterPlayerScripts).
-- Shoulder camera with spring and collision, movement with sprint and stamina, smooth
-- turning and lean, weapons with a 3D wheel, crosshair only when aiming, and the
-- city's visual effects. Turns on after Jogar (attribute CyberOutlawMenuStarted).

local MEDIA = __CYBEROUTLAW_MEDIA__
local SOUNDS = if type(MEDIA) == "table" and type(MEDIA.sons) == "table" then MEDIA.sons else {}
-- 2D icon atlas (design/icones.py, drawn in Figma). Without approval, the 3D models are used.
local ATLAS = if type(MEDIA) == "table" and type(MEDIA.icones) == "number" and MEDIA.icones > 0
	then string.format("rbxassetid://%.0f", MEDIA.icones) else nil

local M = {}

-- Pure math (tested in tests/play_test.luau) ------------------------------------------------------
-- Critically damped spring, stable for any dt (implicit Euler).
local function spring(x, v, target, frequency: number, dt: number)
	local omega = frequency * 2 * math.pi
	local f = 1 + 2 * dt * omega
	local oo = omega * omega
	local hoo = dt * oo
	local hhoo = dt * hoo
	local inverse = 1 / (f + hhoo)
	return (f * x + dt * v + hhoo * target) * inverse, (v + hoo * (target - x)) * inverse
end
M.spring = spring

local function angleDelta(from: number, to: number): number
	return (to - from + math.pi) % (2 * math.pi) - math.pi
end
M.angleDelta = angleDelta

-- Wheel slot pointed to by a screen vector (y down). Slot 1 at the top, clockwise.
local function slotFromVector(x: number, y: number, count: number): number?
	if x * x + y * y < 1e-6 then
		return nil
	end
	local angle = math.deg(math.atan2(y, x)) + 90 -- 0 = top
	local step = 360 / count
	return math.floor(((angle + step / 2) % 360) / step) + 1
end
M.slotFromVector = slotFromVector

-- Screen position of the slot center (angle in degrees, 0 = right, slot 1 at the top).
local function slotAngle(index: number, count: number): number
	return -90 + (index - 1) * 360 / count
end
M.slotAngle = slotAngle

-- Stamina: drains while sprinting, refills after a short pause.
local function staminaStep(state, sprinting: boolean, dt: number)
	if sprinting then
		state.value = math.max(0, state.value - 0.13 * dt)
		state.rest = 0
		if state.value <= 0 then
			state.exhausted = true
		end
	else
		state.rest += dt
		if state.rest > 0.8 then
			state.value = math.min(1, state.value + 0.2 * dt)
		end
		if state.exhausted and state.value >= 0.3 then
			state.exhausted = false
		end
	end
	return state
end
M.staminaStep = staminaStep

-- Random direction inside a cone around `look` (radius in radians).
local function coneDirection(look: Vector3, radius: number, rng): Vector3
	if radius <= 0 then
		return look.Unit
	end
	local up = if math.abs(look.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local right = look:Cross(up).Unit
	local trueUp = right:Cross(look).Unit
	local angle = rng:NextNumber(0, 2 * math.pi)
	local spread = math.sqrt(rng:NextNumber()) * math.tan(radius)
	return (look.Unit + (right * math.cos(angle) + trueUp * math.sin(angle)) * spread).Unit
end
M.coneDirection = coneDirection

-- Joint Transform that puts Part1 at `rotation` (rotation only, in Part0 space).
local function jointTransform(c0: CFrame, c1: CFrame, rotation: CFrame): CFrame
	local r0 = c0 - c0.Position
	local r1 = c1 - c1.Position
	return r0:Inverse() * rotation * r1
end
M.jointTransform = jointTransform

-- Arm rotation in torso space: the arm (-Y) points to `direction`, the palm (-Z) toward `up`.
local function armRotation(direction: Vector3, up: Vector3): CFrame
	local y = -direction.Unit
	local z = -up
	z = (z - y * z:Dot(y))
	if z.Magnitude < 1e-3 then
		z = Vector3.zAxis - y * Vector3.zAxis:Dot(y)
	end
	z = z.Unit
	local x = y:Cross(z)
	return CFrame.fromMatrix(Vector3.zero, x, y, z)
end
M.armRotation = armRotation

-- Melee swing direction (torso space) at progress t in [0, 1].
local function swingDirection(kind: string, side: number, t: number): Vector3
	local strike = math.sin(math.min(t, 1) * math.pi)
	if kind == "faca" then
		local a = Vector3.new(0.75 * side, 0.75, -0.35)
		local b = Vector3.new(-0.55 * side, -0.45, -0.75)
		return a:Lerp(b, math.clamp(t * 1.2, 0, 1)).Unit
	end
	local rest = Vector3.new(0.1 * side, -1, -0.15)
	local hit = Vector3.new(-0.12 * side, 0.08, -1)
	return rest:Lerp(hit, strike).Unit
end
M.swingDirection = swingDirection

-- Locomoção procedural do R6 (sem joelhos): o peso vem do tronco. Ele balança a cada passo, inclina ao
-- acelerar e nas curvas, gira um pouco com os braços e assenta na aterrissagem. Parado, respira e troca o
-- peso de perna. Pura: recebe o estado e a velocidade e devolve as direções dos membros (no espaço do
-- tronco), o deslocamento do tronco (no espaço do HumanoidRootPart) e o peso da pose.
local function newGait()
	return {
		phase = 0, speed = 0, speedVel = 0, accel = 0, lastForward = 0, lean = 0, leanVel = 0, bank = 0, bankVel = 0,
		land = 0, landVel = 0, air = 0, airFall = 0, time = 0, weight = 0, turnPhase = 0, turnAmount = 0,
	}
end
M.newGait = newGait

local function gaitStep(g, input, dt: number)
	dt = math.clamp(dt, 0, 0.1)
	g.time += dt
	local state = input.state or "run"
	local busy = state == "climb" or state == "swim" or state == "seated" or state == "dead"
	g.weight += ((if busy then 0 else 1) - g.weight) * math.min(1, dt * 8)
	-- Velocidade no espaço do personagem: frente = -Z, direita = +X.
	local local3 = input.velocity
	local planar = Vector3.new(local3.X, 0, local3.Z)
	local raw = planar.Magnitude
	g.speed, g.speedVel = spring(g.speed, g.speedVel, raw, 6, dt)
	local s = math.max(0, g.speed)
	local forward = -local3.Z
	g.accel += (((forward - g.lastForward) / math.max(dt, 1e-3)) - g.accel) * math.min(1, dt * 6)
	g.lastForward = forward
	local move = if raw > 0.5 then planar / raw else Vector3.new(0, 0, -1)
	local grounded = state == "run" or state == "idle"
	-- Cadência: a passada cresce com a velocidade (corrida a 17 studs/s, sprint a 27).
	local stride = 2.5 + 0.48 * s
	local walking = grounded and s > 0.6
	if walking then
		g.phase = (g.phase + (s / stride) * dt * math.pi * 2) % (math.pi * 2)
	end
	-- Girar no lugar: passinhos curtos acompanham a virada.
	local yawRate = input.yawRate or 0
	local turning = grounded and s < 1.5 and math.abs(yawRate) > 1.2
	g.turnAmount += ((if turning then 1 else 0) - g.turnAmount) * math.min(1, dt * 6)
	if turning then
		g.turnPhase = (g.turnPhase + math.abs(yawRate) * dt * 1.6) % (math.pi * 2)
	end
	local runBlend = math.clamp((s - 0.6) / 3, 0, 1)
	local legAmp = math.clamp(0.25 + 0.028 * s, 0, 1) * runBlend
	local armAmp = math.clamp(0.15 + 0.03 * s, 0, 1.05) * runBlend
	local phase = g.phase
	local stepped = 0
	if walking then
		local before = phase - (s / stride) * dt * math.pi * 2
		for index, mark in { math.pi / 2, math.pi * 1.5 } do
			local a, b = before, phase
			if a < 0 then
				a += math.pi * 2
				b += math.pi * 2
			end
			if (a < mark and b >= mark) or (a < mark + math.pi * 2 and b >= mark + math.pi * 2) then
				stepped = index
			end
		end
	end
	-- Pernas: balanço oposto, com um pouco mais de avanço na fase do ar.
	local swing = math.sin(phase)
	local lift = math.max(0, math.cos(phase))
	local rightLeg = legAmp * (swing + 0.18 * lift)
	local leftLeg = legAmp * (-swing + 0.18 * math.max(0, -math.cos(phase)))
	if g.turnAmount > 0.01 then
		local t = math.sin(g.turnPhase) * 0.22 * g.turnAmount
		rightLeg += t
		leftLeg -= t
	end
	local function legDirection(angle: number, side: number): Vector3
		local d = move * math.sin(angle) + Vector3.new(0, -math.cos(angle), 0)
		return (d + Vector3.new(side * 0.04, 0, 0)).Unit
	end
	-- Braços: contrabalançam as pernas; no sprint, bombeiam mais à frente.
	local pump = math.clamp((s - 17) / 10, 0, 1)
	local function armDirection(angle: number, side: number): Vector3
		local forwardBias = 0.08 + 0.18 * pump
		local d = Vector3.new(0, 0, -1) * math.sin(angle + forwardBias) + Vector3.new(0, -math.cos(angle + forwardBias), 0)
		return (d + Vector3.new(side * (0.09 + 0.05 * runBlend), 0, 0)).Unit
	end
	local pose = {
		weight = g.weight, step = stepped,
		rightLeg = legDirection(rightLeg, 1), leftLeg = legDirection(leftLeg, -1),
		rightArm = armDirection(-armAmp * swing, 1), leftArm = armDirection(armAmp * swing, -1),
	}
	-- Tronco: sobe e desce duas vezes por ciclo, balança para o lado de apoio e gira com os ombros.
	local bobAmp = (0.06 + 0.012 * s) * runBlend
	local bob = bobAmp * (0.5 - math.abs(swing))
	local sway = (0.04 + 0.004 * s) * runBlend * swing
	local twist = (0.05 + 0.003 * s) * runBlend * swing
	-- Inclinação à frente com a velocidade e com a aceleração (para trás ao frear).
	local targetLean = (0.03 + 0.006 * s) * runBlend + math.clamp(g.accel * 0.012, -0.2, 0.2)
	g.lean, g.leanVel = spring(g.lean, g.leanVel, targetLean, 4, dt)
	local targetBank = math.clamp(-yawRate * 0.045 * (s / 17), -0.22, 0.22)
	g.bank, g.bankVel = spring(g.bank, g.bankVel, targetBank, 3, dt)
	-- Parado: respiração e troca de peso lenta.
	local idle = 1 - runBlend
	local breath = math.sin(g.time * 1.9)
	local shift = math.sin(g.time * 0.35)
	local y = bob + idle * 0.03 * breath
	local x = sway + idle * 0.08 * shift
	local pitch = -g.lean - idle * 0.015 * breath
	local roll = g.bank + idle * 0.025 * shift
	if idle > 0.01 then
		pose.rightArm = pose.rightArm:Lerp(Vector3.new(0.07, -1, -0.02 - 0.015 * breath).Unit, idle).Unit
		pose.leftArm = pose.leftArm:Lerp(Vector3.new(-0.07, -1, -0.02 - 0.015 * breath).Unit, idle).Unit
	end
	-- No ar: uma perna à frente, braços abertos; queda longa levanta os braços.
	if state == "jump" or state == "fall" then
		g.air += dt
		local falling = math.clamp(-(input.verticalSpeed or 0) / 60, 0, 1)
		g.airFall = math.max(g.airFall, -(input.verticalSpeed or 0))
		local airBlend = math.clamp(g.air / 0.12, 0, 1)
		pose.rightLeg = pose.rightLeg:Lerp(Vector3.new(0.04, -1, -0.55).Unit, airBlend).Unit
		pose.leftLeg = pose.leftLeg:Lerp(Vector3.new(-0.04, -1, 0.25).Unit, airBlend).Unit
		pose.rightArm = pose.rightArm:Lerp(Vector3.new(0.6, -0.45 + 0.7 * falling, -0.2).Unit, airBlend).Unit
		pose.leftArm = pose.leftArm:Lerp(Vector3.new(-0.6, -0.45 + 0.7 * falling, -0.2).Unit, airBlend).Unit
	else
		if g.air > 0.25 then
			-- Aterrissagem: o corpo assenta e volta com mola, mais forte quanto maior a queda.
			g.landVel -= math.clamp(g.airFall / 80, 0.15, 0.6) * 32
		end
		g.air = 0
		g.airFall = 0
	end
	g.land, g.landVel = spring(g.land, g.landVel, 0, 3.5, dt)
	y += g.land * 0.7
	pitch += g.land * 0.15
	pose.root = CFrame.new(x, y, 0) * CFrame.Angles(pitch, twist, roll)
	-- A cabeça compensa o tronco para o olhar ficar estável.
	pose.headCompensation = CFrame.Angles(-pitch * 0.8, -twist * 0.9, -roll * 0.8)
	return pose
end
M.gaitStep = gaitStep

-- Transform do RootJoint que leva o tronco ao deslocamento pedido no espaço do HumanoidRootPart.
local function rootTransform(c0: CFrame, offset: CFrame): CFrame
	return c0:Inverse() * offset * c0
end
M.rootTransform = rootTransform

-- Animações do catálogo no R6 ---------------------------------------------------------------------
-- Os pacotes do catálogo só tocam em R15. Cada personagem ganha um esqueleto R15 invisível (só no
-- cliente) que toca o pacote; a cada quadro a pose dele vira a pose do R6: o tronco segue a média dos
-- dois troncos do R15, cada braço e perna aponta do ombro (quadril) até a mão (pé) e gira junto com o
-- segmento de cima, e a cabeça copia o pescoço. Tudo relativo à pose de descanso, então o R6 parado
-- fica reto mesmo com os braços do R15 levemente abertos.
-- Juntas do R15 padrão (blocos): nome, peça 0, peça 1, posição do C0 e do C1 (sem rotação).
local R15_JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso", Vector3.new(0, -1, 0), Vector3.new(0, -0.2, 0) },
	{ "Waist", "LowerTorso", "UpperTorso", Vector3.new(0, 0.2, 0), Vector3.new(0, -0.8, 0) },
	{ "Neck", "UpperTorso", "Head", Vector3.new(0, 0.8, 0), Vector3.new(0, -0.5, 0) },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", Vector3.new(1, 0.563, 0), Vector3.new(-0.5, 0.394, 0) },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", Vector3.new(0, -0.334, 0), Vector3.new(0, 0.262, 0) },
	{ "RightWrist", "RightLowerArm", "RightHand", Vector3.new(0, -0.501, 0), Vector3.new(0, 0.125, 0) },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", Vector3.new(-1, 0.563, 0), Vector3.new(0.5, 0.394, 0) },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", Vector3.new(0, -0.334, 0), Vector3.new(0, 0.262, 0) },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", Vector3.new(0, -0.501, 0), Vector3.new(0, 0.125, 0) },
	{ "RightHip", "LowerTorso", "RightUpperLeg", Vector3.new(0.5, -0.2, 0), Vector3.new(0, 0.42, 0) },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", Vector3.new(0, -0.42, 0), Vector3.new(0, 0.413, 0) },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", Vector3.new(0, -0.547, 0), Vector3.new(0, 0.101, 0) },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", Vector3.new(-0.5, -0.2, 0), Vector3.new(0, 0.42, 0) },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", Vector3.new(0, -0.42, 0), Vector3.new(0, 0.413, 0) },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", Vector3.new(0, -0.547, 0), Vector3.new(0, 0.101, 0) },
}
M.R15_JOINTS = R15_JOINTS
local R15_SIZES = {
	HumanoidRootPart = Vector3.new(2, 2, 1), LowerTorso = Vector3.new(2, 0.4, 1), UpperTorso = Vector3.new(2, 1.6, 1),
	Head = Vector3.new(1.2, 1.2, 1.2), RightUpperArm = Vector3.new(1, 1.169, 1), RightLowerArm = Vector3.new(1, 1.052, 1),
	RightHand = Vector3.new(1, 0.3, 1), LeftUpperArm = Vector3.new(1, 1.169, 1), LeftLowerArm = Vector3.new(1, 1.052, 1),
	LeftHand = Vector3.new(1, 0.3, 1), RightUpperLeg = Vector3.new(1, 1.217, 1), RightLowerLeg = Vector3.new(1, 1.193, 1),
	RightFoot = Vector3.new(1, 0.3, 1), LeftUpperLeg = Vector3.new(1, 1.217, 1), LeftLowerLeg = Vector3.new(1, 1.193, 1),
	LeftFoot = Vector3.new(1, 0.3, 1),
}
M.R15_SIZES = R15_SIZES

-- Cinemática direta do R15 no espaço do HumanoidRootPart: CFrame de cada peça e posição de cada junta.
local function r15Frames(transforms)
	local frames = { HumanoidRootPart = CFrame.identity }
	local pivots = {}
	for _, joint in R15_JOINTS do
		local base = frames[joint[2]] * CFrame.new(joint[4])
		pivots[joint[1]] = base.Position
		frames[joint[3]] = base * (transforms[joint[1]] or CFrame.identity) * CFrame.new(-joint[5])
	end
	return frames, pivots
end
M.r15Frames = r15Frames
local REST_FRAMES, REST_PIVOTS = r15Frames({})
local TORSO_MIX = 0.65
local REST_TORSO = REST_FRAMES.LowerTorso.Rotation:Lerp(REST_FRAMES.UpperTorso.Rotation, TORSO_MIX)

-- Gira `base` pela menor rotação que leva `from` até `to`.
local function swing(from: Vector3, to: Vector3, base: Vector3): Vector3
	local a, b = from.Unit, to.Unit
	local axis = a:Cross(b)
	local s, c = axis.Magnitude, a:Dot(b)
	if s < 1e-6 then
		return if c > 0 then base else -base
	end
	return CFrame.fromAxisAngle(axis / s, math.atan2(s, c)) * base
end
M.swing = swing

local LIMBS = {
	{ "rightArm", "RightShoulder", "RightHand", "RightUpperArm" },
	{ "leftArm", "LeftShoulder", "LeftHand", "LeftUpperArm" },
	{ "rightLeg", "RightHip", "RightFoot", "RightUpperLeg" },
	{ "leftLeg", "LeftHip", "LeftFoot", "LeftUpperLeg" },
}
local DOWN, FRONT = Vector3.new(0, -1, 0), Vector3.new(0, 0, -1)
-- transforms: Transform de cada junta do R15 (Motor6D ou AnimationConstraint). Devolve a pose do R6 no
-- mesmo formato da locomoção procedural (direções no espaço do tronco) mais o giro de cada membro.
local function retargetPose(transforms, strafe: number?)
	local f, p = r15Frames(transforms)
	local rotation = f.LowerTorso.Rotation:Lerp(f.UpperTorso.Rotation, TORSO_MIX) * REST_TORSO:Inverse()
	local bob = f.LowerTorso.Position - REST_FRAMES.LowerTorso.Position
	local torso = CFrame.new(bob) * rotation
	local turn = CFrame.Angles(0, strafe or 0, 0)
	local pose = { root = torso, weight = 1, step = 0 }
	for _, limb in LIMBS do
		local key, pivot, tip, upper = limb[1], limb[2], limb[3], limb[4]
		local direction = swing(REST_FRAMES[tip].Position - REST_PIVOTS[pivot], f[tip].Position - p[pivot], DOWN)
		local front = (f[upper].Rotation * REST_FRAMES[upper].Rotation:Inverse()) * FRONT
		if key == "rightLeg" or key == "leftLeg" then
			-- Andando de lado ou de costas (mirando), o passo segue a direção do movimento. Só a direção gira: girar
			-- também a "frente" torceria a perna em volta do pivô do quadril do R6 (que fica na borda da perna) e
			-- as pernas abririam para os lados. De lado o passo fica mais curto, para uma perna não cruzar a outra.
			local side = math.abs(math.sin(strafe or 0))
			if side > 0.01 then
				direction = DOWN:Lerp(direction, 1 - 0.45 * side).Unit
			end
			direction = turn * direction
		end
		pose[key] = torso:VectorToObjectSpace(direction)
		pose[key .. "Up"] = torso:VectorToObjectSpace(front)
	end
	local head = f.UpperTorso.Rotation:Inverse() * f.Head.Rotation
	local headRest = REST_FRAMES.UpperTorso.Rotation:Inverse() * REST_FRAMES.Head.Rotation
	pose.headCompensation = head * headRest:Inverse()
	pose.feet = { f.RightFoot.Position.Y, f.LeftFoot.Position.Y }
	return pose
end
M.retargetPose = retargetPose
local REST_FEET = REST_FRAMES.RightFoot.Position.Y
M.REST_FEET = REST_FEET

-- Pesos das trilhas de locomoção como no Animate do R15: caminhada até 8 studs/s, mistura até 16 e
-- corrida acima disso (a cadência acompanha a velocidade até um limite, para o pé não patinar demais).
local function locomotionWeights(state: string, speed: number, vertical: number)
	local weights = { idle = 0, walk = 0, run = 0, fall = 0, climb = 0, swim = 0, swimidle = 0 }
	local rates = { idle = 1, walk = 1, run = 1, fall = 1, climb = 1, swim = 1, swimidle = 1 }
	if state == "fall" or state == "jump" then
		weights.fall = 1
	elseif state == "climb" then
		weights.climb = 1
		rates.climb = math.clamp(vertical / 6, -1.6, 1.6)
	elseif state == "swim" then
		if speed > 1 then
			weights.swim = 1
			rates.swim = math.clamp(speed / 10, 0.6, 1.6)
		else
			weights.swimidle = 1
		end
	elseif state == "seated" or state == "dead" then
		return weights, rates
	else
		local normalized = speed / 16
		if speed < 0.6 then
			weights.idle = 1
		elseif normalized <= 0.5 then
			weights.walk = 1
			rates.walk = math.max(normalized / 0.5, 0.35)
		elseif normalized < 1 then
			local t = (normalized - 0.5) / 0.5
			weights.walk, weights.run = 1 - t, t
		else
			weights.run = 1
			rates.run = math.min(normalized, 1.35)
		end
	end
	return weights, rates
end
M.locomotionWeights = locomotionWeights

-- Pacotes: IDs de animação da documentação oficial do Roblox (create.roblox.com, "Catalog animations").
-- Os pacotes "do catálogo" (adidas, Oldschool e o pack UGC GTA 6) são resolvidos pelo servidor e chegam
-- como atributos de ReplicatedStorage.CyberOutlawAnimacoes.
local ANIMATION_PACKS = {
	realista = { nome = "Realista (Rthro)", idle = { 2510197257, 2510196951 }, walk = 2510202577, run = 2510198475,
		jump = 2510197830, fall = 2510195892, climb = 2510192778, swim = 2510199791, swimidle = 2510201162 },
	estiloso = { nome = "Estiloso (Stylish)", idle = { 616136790, 616138447 }, walk = 616146177, run = 616140816,
		jump = 616139451, fall = 616134815, climb = 616133594, swim = 616143378, swimidle = 616144772 },
	ninja = { nome = "Ninja", idle = { 656117400, 656118341 }, walk = 656121766, run = 656118852,
		jump = 656117878, fall = 656115606, climb = 656114359, swim = 656119721, swimidle = 656121397 },
	heroi = { nome = "Super-herói", idle = { 616111295, 616113536 }, walk = 616122287, run = 616117076,
		jump = 616115533, fall = 616108001, climb = 616104706, swim = 616119360, swimidle = 616120861 },
	padrao = { nome = "Padrão do Roblox", idle = { 507766388, 507766666 }, walk = 913402848, run = 913376220,
		jump = 507765000, fall = 507767968, climb = 507765644, swim = 507784897, swimidle = 507785072 },
}
local PACK_ORDER = { "realista", "estiloso", "esportivo", "aura", "classico", "gta6", "ninja", "heroi", "padrao" }
M.ANIMATION_PACKS = ANIMATION_PACKS
M.PACK_ORDER = PACK_ORDER

-- Reflexo planar: posição e rotação de uma peça espelhada no plano y = plane. Blocos, cilindros e esferas
-- são simétricos em Y (rotação M R M); cunhas só em X, então ganham meia volta em Z.
local function mirrorCFrame(cf: CFrame, plane: number, wedge: boolean?): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local mirrored = CFrame.new(x, 2 * plane - y, z, r00, -r01, r02, -r10, r11, -r12, r20, -r21, r22)
	if wedge then
		mirrored *= CFrame.Angles(0, 0, math.pi)
	end
	return mirrored
end
M.mirrorCFrame = mirrorCFrame

-- Atlas cell: weapons at 384 x 192 in two columns (left 768 px), glyphs at 128 x 128 in the right strip.
-- Same layout as design/icones.py (weapon silhouettes projected from the 3D models).
local ICON_ORDER = { "punhos", "faca", "glock", "deagle", "uzi", "ak47", "m4", "escopeta", "sniper" }
local GLYPHS = { "tiro", "mira", "recarga", "arsenal", "correr", "golpe", "teleporte", "fechar",
	"implantes", "sandevistan", "psicose", "kiroshi", "louva", "gorila", "tendoes", "subdermal" }
local function iconRect(key: string): (Vector2?, Vector2?)
	local weapon = table.find(ICON_ORDER, key)
	if weapon then
		return Vector2.new(((weapon - 1) % 2) * 384, ((weapon - 1) // 2) * 192), Vector2.new(384, 192)
	end
	local glyph = table.find(GLYPHS, key)
	if glyph then
		return Vector2.new(768 + ((glyph - 1) % 2) * 128, ((glyph - 1) // 2) * 128), Vector2.new(128, 128)
	end
	return nil, nil
end
M.iconRect = iconRect

-- Interface v3: limpa, no estilo dos jogos de mundo aberto (também montada nos testes com Instances reais) -----
-- Um só destaque de cor, tipografia Builder Sans, painéis escuros translúcidos e nada de molduras chanfradas.
local TEXT = Color3.fromRGB(242, 243, 246)
local SUB = Color3.fromRGB(164, 170, 184)
local PANEL = Color3.fromRGB(12, 11, 26)
local LINE = Color3.fromRGB(255, 255, 255)
local HEALTH = Color3.fromRGB(98, 212, 148)
local HURT = Color3.fromRGB(236, 72, 84)
local BREATH = Color3.fromRGB(158, 210, 255)
local ACCENT = Color3.fromRGB(255, 206, 114)
-- Paleta "pôr do sol de Maré Baixa": rosa quente, laranja e dourado sobre vidro azul-escuro (como o
-- clima de Vice City), usada só nos destaques: o resto do HUD continua discreto.
local PINK = Color3.fromRGB(255, 72, 140)
local ORANGE = Color3.fromRGB(255, 146, 72)
local GOLD = Color3.fromRGB(255, 208, 102)
local TEAL = Color3.fromRGB(72, 226, 210)
local SUNSET = ColorSequence.new({
	ColorSequenceKeypoint.new(0, PINK), ColorSequenceKeypoint.new(0.55, ORANGE), ColorSequenceKeypoint.new(1, GOLD),
})
-- Neon do HUD 3D (como o do Chrome Clash): ciano, e rosa para dano e ciberpsicose.
local NEON = Color3.fromRGB(86, 255, 222)
local NEON_HURT = Color3.fromRGB(255, 72, 140)
local CENTER = Vector2.new(0.5, 0.5)
local FULL = UDim2.fromScale(1, 1)
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
local function fonts()
	return {
		regular = Font.new(BUILDER, Enum.FontWeight.Regular),
		medium = Font.new(BUILDER, Enum.FontWeight.Medium),
		bold = Font.new(BUILDER, Enum.FontWeight.Bold),
		heavy = Font.new(BUILDER, Enum.FontWeight.ExtraBold),
		mono = Font.fromEnum(Enum.Font.RobotoMono),
	}
end

-- string.upper não converte letras acentuadas; o HUD mostra "DOCAS DA MARÉ", não "DOCAS DA MARé".
local ACCENTS = {
	["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["é"] = "É", ["ê"] = "Ê", ["í"] = "Í",
	["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ", ["ú"] = "Ú", ["ü"] = "Ü", ["ç"] = "Ç",
}
local function upper(text: string): string
	return (string.gsub(string.upper(text), "\195[\160-\191]", function(char)
		return ACCENTS[char] or char
	end))
end
M.upper = upper

local function new(class: string, parent: Instance?, props)
	local item = Instance.new(class)
	for key, value in props or {} do
		(item :: any)[key] = value
	end
	item.Parent = parent
	return item
end

local function frame(parent, name, z, props)
	local base = { Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z }
	for key, value in props or {} do
		base[key] = value
	end
	return new("Frame", parent, base)
end

local function label(parent, name, text, font, size, color, z, props)
	local base = {
		Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z, Text = text, FontFace = font,
		TextSize = size, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, Size = FULL,
	}
	for key, value in props or {} do
		base[key] = value
	end
	return new("TextLabel", parent, base)
end

local function round(parent, radius: UDim)
	new("UICorner", parent, { CornerRadius = radius })
end

local function stroke(parent, color: Color3, transparency: number, thickness: number?)
	return new("UIStroke", parent, {
		Color = color, Transparency = transparency, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function sunset(parent: Instance, rotation: number?): UIGradient
	return new("UIGradient", parent, { Color = SUNSET, Rotation = rotation or 0 })
end

local function atlasImage(parent, name: string, atlas: string, key: string, z: number, props)
	local offset, size = iconRect(key)
	local base = {
		Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z, Image = atlas,
		ImageRectOffset = offset or Vector2.zero, ImageRectSize = size or Vector2.zero, ScaleType = Enum.ScaleType.Fit,
	}
	for key2, value in props or {} do
		base[key2] = value
	end
	return new("ImageLabel", parent, base)
end

local function rgb(list)
	return Color3.fromRGB(list[1], list[2], list[3])
end

-- Model inside a ViewportFrame, framed by its bounding box (fallback while the 2D icons await approval).
local function viewportModel(viewport: ViewportFrame, template: Model?)
	if not template then
		return nil
	end
	local model = template:Clone()
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
		end
	end
	local world = new("WorldModel", viewport, { Name = "Mundo" })
	model.Parent = world
	local box, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local offset = pivot:ToObjectSpace(box)
	local radius = math.max(size.X, size.Y, size.Z) * 0.5
	local camera = new("Camera", viewport, { Name = "Camera", FieldOfView = 30 })
	viewport.CurrentCamera = camera
	local distance = radius / math.tan(math.rad(15)) * 1.05
	camera.CFrame = CFrame.lookAt(Vector3.new(distance * 0.82, distance * 0.36, distance * 0.42), Vector3.zero)
	return { model = model, offset = offset }
end

local function poseViewport(entry, yaw: number)
	if entry then
		entry.model:PivotTo(CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(-6)) * entry.offset:Inverse())
	end
end

-- Layout ---------------------------------------------------------------------------------------------------
-- Posições em pixels da área segura (abaixo da barra do Roblox e fora dos entalhes). Pura: os testes conferem
-- que nada se sobrepõe em celulares, tablets e PCs. No toque: mapa no alto à esquerda, arsenal e implantes no
-- alto à direita, barra de armas embaixo no centro e botões em arco em volta do pulo do Roblox. No PC: mapa
-- embaixo à esquerda, barra no centro, implantes e habilidade embaixo à direita.
local MAP_BLOCK = {
	touch = { width = 136, map = 88, gap = 4, caption = 14, bar = 5, breath = 3, psy = 4 },
	desktop = { width = 272, map = 184, gap = 6, caption = 16, bar = 7, breath = 4, psy = 5 },
}
local function blockHeight(b): number
	return b.map + b.gap + b.caption + b.gap + b.bar + 3 + b.breath + 3 + b.psy
end

local function hudLayout(screen: Vector2, touch: boolean, jump)
	local W, H = screen.X, screen.Y
	local l = { touch = touch, screen = screen }
	if touch then
		local large = math.min(W, H) > 500
		local s = if large then 1.25 else 1
		local b = MAP_BLOCK.touch
		local m = math.floor(12 * s)
		l.scale = s
		l.minimap = { anchor = Vector2.new(0, 0), position = Vector2.new(m, math.floor(10 * s)), size = Vector2.new(b.width, blockHeight(b)) }
		-- Canto de cima à direita: roleta de armas e implantes (o cartão de arma antigo saiu: a barra neon mostra tudo).
		l.arsenal = { anchor = Vector2.new(1, 0), position = Vector2.new(W - m, math.floor(10 * s)), size = Vector2.new(44, 44) }
		l.implants = { anchor = Vector2.new(1, 0), position = Vector2.new(W - m - math.floor(52 * s), math.floor(10 * s)), size = Vector2.new(44, 44) }
		-- Barra neon das armas, embaixo no centro (entre o analógico e os botões de ação).
		l.neon = { anchor = Vector2.new(0.5, 1), position = Vector2.new(math.floor(W / 2), H - math.floor(4 * s)), size = Vector2.new(280, 46) }
		l.toast = { anchor = Vector2.new(0.5, 0), position = Vector2.new(math.floor(W / 2), math.floor(8 * s)), size = Vector2.new(260, 50) }
		local center, radius
		if jump then
			center, radius = jump.center, jump.size / 2
		else
			-- Medidas do pulo padrão do Roblox: 70 px (telas pequenas) ou 120 px (grandes).
			radius = if large then 60 else 35
			center = if large then Vector2.new(W - 50 - 60, H - 90 - 60) else Vector2.new(W - 25 - 35, H - 20 - 35)
		end
		local k = radius / 35
		l.jump = { center = center, radius = radius }
		l.buttons = {
			fire = { center = center + Vector2.new(-76, -6) * k, radius = 32 * k },
			aim = { center = center + Vector2.new(-46, -74) * k, radius = 26 * k },
			reload = { center = center + Vector2.new(10, -78) * k, radius = 21 * k },
			ability = { center = center + Vector2.new(-112, -78) * k, radius = 24 * k },
		}
		l.wheel = { scale = math.clamp(H / 340, 0.78, 1.4) }
	else
		local s = math.clamp(H / 1000, 0.85, 1.35)
		local b = MAP_BLOCK.desktop
		local m = math.floor(24 * s)
		l.scale = s
		l.minimap = { anchor = Vector2.new(0, 1), position = Vector2.new(m, H - m), size = Vector2.new(b.width, blockHeight(b)) }
		l.neon = { anchor = Vector2.new(0.5, 1), position = Vector2.new(math.floor(W / 2), H - m), size = Vector2.new(420, 76) }
		l.implants = { anchor = Vector2.new(1, 1), position = Vector2.new(W - m, H - m), size = Vector2.new(56, 56) }
		l.ability = { anchor = Vector2.new(1, 1), position = Vector2.new(W - m - math.floor(64 * s), H - m), size = Vector2.new(56, 56) }
		l.toast = { anchor = Vector2.new(0.5, 0), position = Vector2.new(math.floor(W / 2), math.floor(22 * s)), size = Vector2.new(420, 70) }
		l.buttons = {}
		l.wheel = { scale = math.clamp(H / 860, 0.8, 1.4) }
	end
	return l
end
M.hudLayout = hudLayout

-- Retângulo ocupado na tela (x0, y0, x1, y1) por um item do layout.
local function layoutRect(item, scale: number)
	local size = item.size * scale
	local origin = item.position - Vector2.new(item.anchor.X * size.X, item.anchor.Y * size.Y)
	return origin.X, origin.Y, origin.X + size.X, origin.Y + size.Y
end
M.layoutRect = layoutRect

local function place(gui: GuiObject, item, scale: number, uiScale: UIScale?)
	gui.AnchorPoint = item.anchor
	gui.Position = UDim2.fromOffset(item.position.X, item.position.Y)
	gui.Size = UDim2.fromOffset(item.size.X, item.size.Y)
	if uiScale then
		uiScale.Scale = scale
	end
end

-- HUD: bloco do mapa (minimapa, distrito, hora, vida e fôlego), aviso de distrito e selo de zona segura -------
local function buildHud(parent: Instance, touch: boolean)
	local f = fonts()
	local b = if touch then MAP_BLOCK.touch else MAP_BLOCK.desktop
	local gui = new("ScreenGui", parent, {
		Name = "CyberOutlawHUD", ResetOnSpawn = false, DisplayOrder = 30, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	})
	local hud = { gui = gui, canvas = Vector2.new(b.width, blockHeight(b)) }
	-- A âncora é o que o layout posiciona; o bloco fica dentro dela (2D) ou vai para a placa neon 3D (no jogo).
	local anchor = frame(gui, "MinimapAncora", 1, { Size = UDim2.fromOffset(b.width, blockHeight(b)) })
	local anchorScale = new("UIScale", anchor, { Name = "Escala" })
	local block = frame(anchor, "Minimap", 1, { Size = UDim2.fromOffset(b.width, blockHeight(b)) })
	local blockScale = new("UIScale", block, { Name = "Escala3D", Scale = 1 })
	-- Neon no mesmo estilo da barra de armas: traço ciano forte e um halo largo por trás.
	local halo = frame(block, "Halo", 1, { Size = UDim2.fromOffset(b.width, b.map) })
	round(halo, UDim.new(0, 8))
	stroke(halo, NEON, 0.82, 7)
	local plate = frame(block, "Plate", 1, { Size = UDim2.fromOffset(b.width, b.map), BackgroundColor3 = PANEL, BackgroundTransparency = 0.3 })
	round(plate, UDim.new(0, 6))
	stroke(plate, NEON, 0.05, 1.5)
	-- Frame com ClipsDescendants (CanvasGroup não recorta numa ScreenGui Global).
	local view = frame(plate, "Viewport", 2, { Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2), ClipsDescendants = true })
	local pivot = frame(view, "Pivot", 2, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(0, 0) })
	local map = frame(pivot, "Map", 2, {})
	local arrow = label(view, "PlayerArrow", "▲", f.heavy, if touch then 13 else 17, NEON, 8, {
		AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(18, 18),
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.35, TextStrokeColor3 = PANEL,
	})
	local northRadius = if touch then 46 else 92
	local north = label(pivot, "Norte", "N", f.heavy, if touch then 9 else 11, TEXT, 9, {
		AnchorPoint = CENTER, Position = UDim2.fromOffset(0, -northRadius), Size = UDim2.fromOffset(14, 14),
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, TextStrokeColor3 = PANEL,
	})
	local noSignal = label(view, "NoSignal", "SEM SINAL DA CIDADE", f.bold, if touch then 9 else 11, SUB, 9, {
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local captionY = b.map + b.gap
	-- Fundo discreto atrás da legenda e das barras, para ler sobre letreiros claros.
	local backing = frame(block, "Legenda", 1, {
		Position = UDim2.fromOffset(-4, b.map + 2), Size = UDim2.new(1, 8, 0, blockHeight(b) - b.map + 2),
		BackgroundColor3 = PANEL, BackgroundTransparency = 0.45,
	})
	round(backing, UDim.new(0, 4))
	local districtLabel = label(block, "DistrictName", "MARÉ BAIXA", f.heavy, if touch then 10 else 13, TEXT, 3, {
		Position = UDim2.fromOffset(1, captionY), Size = UDim2.fromOffset(b.width * 0.76, b.caption),
		TextStrokeTransparency = 0.55, TextStrokeColor3 = PANEL, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local clock = label(block, "Clock", "--:--", f.bold, if touch then 10 else 13, SUB, 3, {
		Position = UDim2.fromOffset(b.width * 0.76, captionY), Size = UDim2.fromOffset(b.width * 0.24 - 1, b.caption),
		TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.55, TextStrokeColor3 = PANEL,
	})
	local barY = captionY + b.caption + b.gap
	local track = frame(block, "HealthTrack", 3, {
		Position = UDim2.fromOffset(0, barY), Size = UDim2.fromOffset(b.width, b.bar), BackgroundColor3 = PANEL, BackgroundTransparency = 0.3,
	})
	round(track, UDim.new(0, 2))
	local trail = frame(track, "HealthTrail", 4, { Size = FULL, BackgroundColor3 = TEXT, BackgroundTransparency = 0.1 })
	round(trail, UDim.new(0, 2))
	local fill = frame(track, "HealthFill", 5, { Size = FULL, BackgroundColor3 = LINE, BackgroundTransparency = 0 })
	round(fill, UDim.new(0, 2))
	new("UIGradient", fill, { Color = ColorSequence.new(HEALTH, TEAL) })
	local breathTrack = frame(block, "StaminaTrack", 3, {
		Position = UDim2.fromOffset(0, barY + b.bar + 3), Size = UDim2.fromOffset(b.width, b.breath),
		BackgroundColor3 = PANEL, BackgroundTransparency = 0.4, Visible = false,
	})
	round(breathTrack, UDim.new(0, 2))
	local breath = frame(breathTrack, "StaminaFill", 4, { Size = FULL, BackgroundColor3 = BREATH, BackgroundTransparency = 0 })
	round(breath, UDim.new(0, 2))
	-- Ciberpsicose (só com o Sandevistan encaixado): cada uso esvazia a barra; a zero, surto.
	local psyTrack = frame(block, "PsicoseTrack", 3, {
		Position = UDim2.fromOffset(0, barY + b.bar + 3 + b.breath + 3), Size = UDim2.fromOffset(b.width, b.psy),
		BackgroundColor3 = PANEL, BackgroundTransparency = 0.3, Visible = false,
	})
	round(psyTrack, UDim.new(0, 2))
	stroke(psyTrack, NEON_HURT, 0.5, 1)
	local psy = frame(psyTrack, "PsicoseFill", 4, { Size = FULL, BackgroundColor3 = NEON_HURT, BackgroundTransparency = 0 })
	round(psy, UDim.new(0, 2))

	local toast = frame(gui, "DistrictToast", 10, { Visible = false })
	local toastScale = new("UIScale", toast, { Name = "Escala" })
	local toastCity = label(toast, "DistrictCity", "MARÉ BAIXA", f.bold, if touch then 10 else 12, SUB, 11, {
		Size = UDim2.fromScale(1, 0.3), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6, TextStrokeColor3 = PANEL,
	})
	local toastTitle = label(toast, "DistrictTitle", "", f.heavy, if touch then 22 else 32, TEXT, 11, {
		Position = UDim2.fromScale(0, 0.26), Size = UDim2.fromScale(1, 0.56), TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5, TextStrokeColor3 = PANEL,
	})
	local toastRule = frame(toast, "Linha", 11, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.9), Size = UDim2.new(0.3, 0, 0, 2),
		BackgroundColor3 = ACCENT, BackgroundTransparency = 0,
	})

	local safe = label(gui, "ZonaSegura", "ZONA SEGURA · ARMAS TRAVADAS", f.heavy, if touch then 9 else 11, TEXT, 12, {
		Size = UDim2.fromOffset(if touch then 168 else 220, if touch then 18 else 22), TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = Color3.fromRGB(26, 110, 88), BackgroundTransparency = 0.12, Visible = false,
	})
	round(safe, UDim.new(1, 0))

	local mapScale = if touch then 0.16 else 0.22 -- pixels por stud
	local extent = 0
	function hud.setMap(data)
		for _, child in map:GetChildren() do
			child:Destroy()
		end
		extent = 0
		noSignal.Visible = true
		if type(data) ~= "table" or type(data.lines) ~= "table" then
			return
		end
		local half = data.half or 1000
		local quay = data.quay or half
		extent = half + 400
		local size = extent * 2 * mapScale
		map.Size = UDim2.fromOffset(size, size)
		local function rect(name, x0, z0, x1, z1, color, transparency, z)
			return frame(map, name, z, {
				Position = UDim2.fromOffset((x0 + extent) * mapScale, (z0 + extent) * mapScale),
				Size = UDim2.fromOffset(math.max(1, (x1 - x0) * mapScale), math.max(1, (z1 - z0) * mapScale)),
				BackgroundColor3 = color, BackgroundTransparency = transparency,
			})
		end
		rect("Terra", -extent, -extent, extent, quay, Color3.fromRGB(24, 26, 34), 0, 2)
		rect("Agua", -extent, quay, extent, extent, Color3.fromRGB(14, 32, 48), 0, 2)
		for _, line in data.lines do
			local p, width = line[1], line[2]
			local tone = if width > 60 then Color3.fromRGB(104, 108, 122) else Color3.fromRGB(70, 74, 88)
			rect("Rua", -half - 40, p - width / 2, half + 40, p + width / 2, tone, 0, 3)
			rect("Rua", p - width / 2, -half - 40, p + width / 2, math.min(half + 40, quay), tone, 0, 3)
		end
		if type(data.plaza) == "table" then
			rect("Praca", data.plaza[1] - 30, data.plaza[2] - 30, data.plaza[1] + 30, data.plaza[2] + 30, ACCENT, 0.5, 4)
		end
		noSignal.Visible = false
	end

	function hud.layout(l)
		place(anchor, l.minimap, l.scale, anchorScale)
		hud.scale = l.scale
		place(toast, l.toast, l.scale, toastScale)
		local x0, _, x1, y1 = layoutRect(l.minimap, l.scale)
		if touch then
			safe.AnchorPoint = Vector2.new(0, 0)
			safe.Position = UDim2.fromOffset(x0, y1 + 6)
		else
			safe.AnchorPoint = Vector2.new(0.5, 0)
			safe.Position = UDim2.fromOffset(l.screen.X / 2, l.toast.position.Y + (l.toast.size.Y + 8) * l.scale)
		end
		local _ = x1
	end

	local state = { trail = 1, hold = 0, district = nil, toastAt = -100, idle = 0, fade = 0, time = 0, damage = 0 }
	local TOAST = 3.6
	-- update: health, maxHealth, stamina, exhausted, position (Vector3), cameraYaw, facingYaw, district {name, key},
	-- clock ("HH:MM"), safe, sprinting.
	function hud.update(input, dt: number)
		state.time += dt
		local health = math.clamp((input.health or 0) / math.max(1, input.maxHealth or 100), 0, 1)
		fill.Visible = health > 0
		fill.Size = UDim2.fromScale(health, 1)
		-- Rastro de dano: espera um instante e então desce até a vida atual.
		if health < state.trail - 0.001 then
			state.hold += dt
			if state.hold > 0.6 then
				state.trail = math.max(health, state.trail - dt * 0.9)
			end
			state.damage = state.time
		else
			state.trail = health
			state.hold = 0
		end
		trail.Size = UDim2.fromScale(state.trail, 1)
		trail.Visible = state.trail > health + 0.001
		local low = health > 0 and health < 0.3
		fill.BackgroundColor3 = if low then HURT:Lerp(TEXT, 0.2 + 0.2 * math.sin(state.time * 6)) else HEALTH
		local stamina = math.clamp(input.stamina or 1, 0, 1)
		breathTrack.Visible = stamina < 0.999 or input.exhausted == true
		breath.Size = UDim2.fromScale(stamina, 1)
		breath.BackgroundColor3 = if input.exhausted then HURT else BREATH
		psyTrack.Visible = type(input.psychosis) == "number"
		if psyTrack.Visible then
			local value = math.clamp(input.psychosis, 0, 1)
			psy.Size = UDim2.fromScale(value, 1)
			psy.BackgroundColor3 = if value < 0.25 then HURT:Lerp(NEON_HURT, 0.5 + 0.5 * math.sin(state.time * 9)) else NEON_HURT
		end
		-- HUD que descansa: com vida cheia e sem correr, as barras ficam discretas (como no GTA 6).
		local busy = health < 0.999 or breathTrack.Visible or state.time - state.damage < 4
		state.idle = if busy then 0 else state.idle + dt
		local goal = if state.idle > 6 then 0.6 else 0
		state.fade += (goal - state.fade) * math.min(1, dt * 3)
		track.BackgroundTransparency = 0.3 + state.fade * 0.6
		fill.BackgroundTransparency = state.fade
		-- Minimapa: o mapa gira com a câmera; a seta mostra para onde o personagem olha.
		if extent > 0 and input.position then
			local position = input.position
			map.Position = UDim2.fromOffset(-(position.X + extent) * mapScale, -(position.Z + extent) * mapScale)
			pivot.Rotation = math.deg(input.cameraYaw or 0)
			north.Rotation = -pivot.Rotation
			arrow.Rotation = math.deg((input.cameraYaw or 0) - (input.facingYaw or 0))
		end
		if input.clock then
			clock.Text = input.clock
		end
		local district = input.district
		if district and district.name ~= state.district then
			state.district = district.name
			local name = upper(district.name)
			districtLabel.Text = name
			toastTitle.Text = name
			state.toastAt = state.time
		end
		local age = state.time - state.toastAt
		toast.Visible = age < TOAST
		if toast.Visible then
			local alpha = math.clamp(math.min(age / 0.35, (TOAST - age) / 0.6), 0, 1)
			toastTitle.TextTransparency = 1 - alpha
			toastCity.TextTransparency = 1 - alpha
			toastTitle.TextStrokeTransparency = 1 - alpha * 0.5
			toastRule.BackgroundTransparency = 1 - alpha
		end
		safe.Visible = input.safe == true
	end
	hud.parts = { block = block, toast = toast, safe = safe, fill = fill, trail = trail, map = map, pivot = pivot, arrow = arrow, track = track,
		anchor = anchor, blockScale = blockScale, psy = psy, psyTrack = psyTrack }
	return hud
end
M.buildHud = buildHud

-- Camada de combate: mira, marcador de acerto, bordas da mira, dano e tela de morte ---------------------------
local function buildCombat(parent: Instance, touch: boolean)
	local f = fonts()
	local gui = new("ScreenGui", parent, {
		Name = "CyberOutlawCombate", ResetOnSpawn = false, DisplayOrder = 32, IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local combat = { gui = gui }
	-- As bordas ficam numa camada abaixo do HUD, para não escurecer o mapa nem a munição.
	local edgeGui = new("ScreenGui", parent, {
		Name = "CyberOutlawBordas", ResetOnSpawn = false, DisplayOrder = 4, IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	combat.edges = edgeGui
	local function edges(name, color)
		local list = {}
		for _, side in { { 0, 0, 1, 0.22, 90 }, { 0, 0.78, 1, 0.22, -90 }, { 0, 0, 0.18, 1, 0 }, { 0.82, 0, 0.18, 1, 180 } } do
			local piece = frame(edgeGui, name, 1, {
				Position = UDim2.fromScale(side[1], side[2]), Size = UDim2.fromScale(side[3], side[4]),
				BackgroundTransparency = 0, BackgroundColor3 = color, Visible = false,
			})
			local gradient = new("UIGradient", piece, {
				Rotation = side[5], Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			})
			table.insert(list, { piece = piece, gradient = gradient })
		end
		return list
	end
	-- Ao mirar, as bordas escurecem (e a câmera desfoca o que está perto) para o olho ir ao centro.
	local aimEdges = edges("VinhetaMira", Color3.fromRGB(3, 4, 9))
	local hurtEdges = edges("VinhetaDano", Color3.fromRGB(170, 0, 30))
	local cross = frame(gui, "Mira", 5, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40), Visible = false })
	local dot = frame(cross, "Dot", 6, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 3), BackgroundTransparency = 0, BackgroundColor3 = TEXT })
	round(dot, UDim.new(1, 0))
	stroke(dot, PANEL, 0.4, 1)
	local ticks = {}
	for _, dir in { Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) } do
		local tick = frame(cross, "Traço", 6, {
			AnchorPoint = CENTER, Size = if dir.X == 0 then UDim2.fromOffset(2, 7) else UDim2.fromOffset(7, 2),
			BackgroundTransparency = 0.05, BackgroundColor3 = TEXT,
		})
		stroke(tick, PANEL, 0.55, 1)
		table.insert(ticks, { item = tick, dir = dir })
	end
	local hit = frame(gui, "Acerto", 7, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), Visible = false })
	local hitLines = {}
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		table.insert(hitLines, frame(hit, "Traço", 7, {
			AnchorPoint = CENTER, Position = UDim2.new(0.5, corner[1] * 9, 0.5, corner[2] * 9), Size = UDim2.fromOffset(10, 2),
			Rotation = if corner[1] * corner[2] > 0 then 45 else -45, BackgroundTransparency = 0, BackgroundColor3 = TEXT,
		}))
	end
	local death = frame(gui, "SinalPerdido", 20, { Size = FULL, BackgroundColor3 = Color3.fromRGB(6, 2, 4), BackgroundTransparency = 0.45, Visible = false })
	local deathTitle = label(death, "Titulo", "SINAL PERDIDO", f.heavy, if touch then 30 else 48, TEXT, 21, {
		AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(720, 60), TextXAlignment = Enum.TextXAlignment.Center,
	})
	frame(death, "Linha", 21, {
		AnchorPoint = CENTER, Position = UDim2.new(0.5, 0, 0.46, if touch then 26 else 38), Size = UDim2.fromOffset(if touch then 120 else 180, 2),
		BackgroundTransparency = 0, BackgroundColor3 = HURT,
	})
	local deathHint = label(death, "Dica", "RECONECTANDO AO CORPO…", f.bold, if touch then 11 else 13, SUB, 21, {
		AnchorPoint = CENTER, Position = UDim2.new(0.5, 0, 0.46, if touch then 44 else 62), Size = UDim2.fromOffset(420, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	-- Luneta da sniper: um círculo recortado por um contorno preto grosso, retículo fino com postes
	-- grossos nas pontas e uma leve vinheta. Sem imagens, para funcionar antes da mídia ser aprovada.
	local scope = frame(gui, "Luneta", 3, { Size = FULL, Visible = false })
	local lens = frame(scope, "Lente", 3, {
		AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.94),
	})
	new("UIAspectRatioConstraint", lens, { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height })
	round(lens, UDim.new(0.5, 0))
	local ring = new("UIStroke", lens, {
		Color = Color3.new(0, 0, 0), Thickness = 2400, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	local inner = frame(lens, "Vinheta", 3, { Size = FULL, BackgroundTransparency = 0, BackgroundColor3 = Color3.new(0, 0, 0) })
	round(inner, UDim.new(0.5, 0))
	new("UIGradient", inner, {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.72, 1), NumberSequenceKeypoint.new(1, 0.35),
		}),
	})
	local RETICLE = Color3.fromRGB(8, 8, 10)
	frame(lens, "Horizontal", 4, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 1),
		BackgroundTransparency = 0, BackgroundColor3 = RETICLE })
	frame(lens, "Vertical", 4, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 1, 1, 0),
		BackgroundTransparency = 0, BackgroundColor3 = RETICLE })
	for _, post in { { 0, 0.5, 0.34, 0, 0, 5 }, { 1, 0.5, 0.34, 0, 0, 5 }, { 0.5, 1, 0, 0.34, 5, 0 } } do
		frame(lens, "Poste", 4, {
			AnchorPoint = Vector2.new(post[1], post[2]), Position = UDim2.fromScale(post[1], post[2]),
			Size = UDim2.new(post[3], post[5], post[4], post[6]), BackgroundTransparency = 0, BackgroundColor3 = RETICLE,
		})
	end
	for k = -3, 3 do
		if k ~= 0 then
			frame(lens, "Marca", 4, { AnchorPoint = CENTER, Position = UDim2.new(0.5 + k * 0.035, 0, 0.5, 0),
				Size = UDim2.fromOffset(1, 7), BackgroundTransparency = 0, BackgroundColor3 = RETICLE })
		end
	end
	local scoped = false
	function combat.scope(visible: boolean)
		if visible == scoped then
			return
		end
		scoped = visible
		scope.Visible = visible
		if visible then
			ring.Thickness = math.max(gui.AbsoluteSize.X, gui.AbsoluteSize.Y)
			cross.Visible = false
		end
	end

	local hitUntil, hitKill = 0, false
	local now = 0
	function combat.crosshair(visible: boolean, spread: number)
		cross.Visible = visible and not scoped
		local gap = 5 + spread * 9
		for _, t in ticks do
			t.item.Position = UDim2.new(0.5, t.dir.X * (gap + 3.5), 0.5, t.dir.Y * (gap + 3.5))
		end
	end
	function combat.hit(kill: boolean?)
		hitUntil = now + (if kill then 0.35 else 0.16)
		hitKill = kill == true
	end
	function combat.death(visible: boolean, title: string?, hint: string?)
		death.Visible = visible
		if title then
			deathTitle.Text = title
		end
		if hint then
			deathHint.Text = hint
		end
	end
	local aimAlpha, hurtAlpha = 0, 0
	function combat.step(dt: number, aimGoal: number, hurtGoal: number)
		now += dt
		hit.Visible = now < hitUntil
		for _, line in hitLines do
			line.BackgroundColor3 = if hitKill then HURT else TEXT
		end
		aimAlpha += (aimGoal - aimAlpha) * math.min(1, dt * 8)
		hurtAlpha += (hurtGoal - hurtAlpha) * math.min(1, dt * 10)
		for _, e in aimEdges do
			e.piece.Visible = aimAlpha > 0.02
			e.gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - 0.75 * aimAlpha), NumberSequenceKeypoint.new(1, 1) })
		end
		for _, e in hurtEdges do
			e.piece.Visible = hurtAlpha > 0.02
			e.gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - 0.8 * hurtAlpha), NumberSequenceKeypoint.new(1, 1) })
		end
	end
	combat.parts = { cross = cross, dot = dot, hit = hit, death = death, aimEdges = aimEdges, hurtEdges = hurtEdges, scope = scope }
	return combat
end
M.buildCombat = buildCombat

-- Roleta de armas: fundo desfocado, seis espaços arredondados com ícones 2D e o centro com nome e atributos ---
local function buildWheel(parent: Instance, defs, templates, touch: boolean, atlas: string?)
	local f = fonts()
	local count = #defs
	-- Mais armas: anel maior e cartões menores, para nenhum cartão encostar no vizinho.
	local crowd = math.max(0, count - 6)
	local ring = if touch then 112 + crowd * 6 else 196 + crowd * 8
	local slotW, slotH = if touch then 92 - crowd * 5 else 148 - crowd * 6, if touch then 56 - crowd * 3 else 86 - crowd * 3
	local hubR = if touch then 58 else 96
	local gui = new("ScreenGui", parent, {
		Name = "CyberOutlawRoleta", ResetOnSpawn = false, DisplayOrder = 60, Enabled = false, IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local shade = new("TextButton", gui, {
		Name = "Fundo", Text = "", AutoButtonColor = false, Size = FULL, BackgroundColor3 = Color3.fromRGB(2, 3, 6),
		BackgroundTransparency = 0.5, ZIndex = 1, Selectable = false,
	})
	local root = frame(gui, "Roda", 2, {
		AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset((ring + slotW) * 2, (ring + slotH) * 2),
	})
	local scale = new("UIScale", root, { Name = "Escala" })
	-- Disco de vidro atrás dos cartões, com borda em degradê e um anel fino por dentro.
	local discRadius = ring + math.max(slotW, slotH) * 0.5 + (if touch then 8 else 16)
	local disc = frame(root, "Disco", 2, {
		AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(discRadius * 2, discRadius * 2),
		BackgroundColor3 = PANEL, BackgroundTransparency = 0.36,
	})
	round(disc, UDim.new(1, 0))
	sunset(stroke(disc, LINE, 0.2, if touch then 1.5 else 2), 45)
	local innerRadius = ring - slotH * 0.5 - (if touch then 6 else 10)
	local innerRing = frame(root, "Anel", 2, {
		AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(innerRadius * 2, innerRadius * 2),
	})
	round(innerRing, UDim.new(1, 0))
	stroke(innerRing, LINE, 0.86, 1)
	local hub = frame(root, "Centro", 3, {
		AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(hubR * 2, hubR * 2),
		BackgroundColor3 = PANEL, BackgroundTransparency = 0.18,
	})
	round(hub, UDim.new(1, 0))
	sunset(stroke(hub, LINE, 0.25, 1.5), 90)
	local hubClass = label(hub, "Classe", "", f.bold, if touch then 8 else 11, PINK, 4, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.17), Size = UDim2.new(0.8, 0, 0, if touch then 10 else 14),
		TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true,
	})
	new("UITextSizeConstraint", hubClass, { MaxTextSize = if touch then 8 else 11, MinTextSize = 5 })
	local hubName = label(hub, "Nome", "", f.heavy, if touch then 14 else 22, TEXT, 4, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.27), Size = UDim2.new(0.9, 0, 0, if touch then 17 else 26),
		TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true,
	})
	new("UITextSizeConstraint", hubName, { MaxTextSize = if touch then 14 else 22, MinTextSize = 8 })
	local hubAmmo = label(hub, "Municao", "", f.bold, if touch then 11 else 15, TEXT, 4, {
		Position = UDim2.fromScale(0, 0.45), Size = UDim2.new(1, 0, 0, if touch then 14 else 18), TextXAlignment = Enum.TextXAlignment.Center,
		RichText = true,
	})
	local statNames = { "DANO", "CADÊNCIA", "ALCANCE", "CONTROLE" }
	local statBars = {}
	for row = 1, 4 do
		local y = (if touch then 0.6 else 0.6) + (row - 1) * 0.08
		label(hub, "Atributo" .. row, statNames[row], f.bold, if touch then 6 else 9, SUB, 4, {
			Position = UDim2.fromScale(0.2, y), Size = UDim2.new(0.28, 0, 0, if touch then 7 else 10),
		})
		local barTrack = frame(hub, "Trilho" .. row, 4, {
			Position = UDim2.new(0.5, 0, y, if touch then 2 else 3), Size = UDim2.new(0.3, 0, 0, if touch then 3 else 4),
			BackgroundTransparency = 0.82, BackgroundColor3 = LINE,
		})
		round(barTrack, UDim.new(1, 0))
		local bar = frame(barTrack, "Valor", 5, { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, BackgroundColor3 = LINE })
		round(bar, UDim.new(1, 0))
		sunset(bar)
		statBars[row] = bar
	end
	local entries = {}
	for index, def in defs do
		local angle = math.rad(slotAngle(index, count))
		local card = new("TextButton", root, {
			Name = "Arma" .. index, Text = "", AutoButtonColor = false, AnchorPoint = CENTER,
			Position = UDim2.new(0.5, math.cos(angle) * ring, 0.5, math.sin(angle) * ring), Size = UDim2.fromOffset(slotW, slotH),
			BackgroundColor3 = PANEL, BackgroundTransparency = 0.26, ZIndex = 5, Selectable = true,
		})
		round(card, UDim.new(0, if touch then 8 else 12))
		local edge = stroke(card, LINE, 0.84, 1)
		local glow = sunset(card, 30)
		glow.Enabled = false
		local pop = new("UIScale", card, { Name = "Pop" })
		local image, viewport
		if atlas then
			image = atlasImage(card, "Icone", atlas, def.id, 6, {
				AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.78, 0.56), ImageColor3 = TEXT,
			})
		else
			image = new("ViewportFrame", card, {
				Name = "Modelo3D", AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.8, 0.62),
				BackgroundTransparency = 1, ZIndex = 6, Ambient = Color3.fromRGB(150, 150, 170), LightColor = Color3.fromRGB(255, 240, 230),
				LightDirection = Vector3.new(-1, -1.4, -0.6),
			})
			viewport = viewportModel(image, templates and templates[def.id])
		end
		local key = if touch then nil else label(card, "Tecla", tostring(index), f.bold, 10, SUB, 7, {
			Position = UDim2.fromOffset(8, 5), Size = UDim2.fromOffset(12, 12),
		})
		local ammo = label(card, "Municao", "", f.bold, if touch then 9 else 11, SUB, 7, {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if touch then -3 else -6), Size = UDim2.new(1, 0, 0, if touch then 11 else 14),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		entries[index] = {
			card = card, pop = pop, image = image, viewport = viewport, ammo = ammo, edge = edge, key = key, def = def, target = 1, glow = glow,
		}
	end
	local selected = 1
	local wheel = { gui = gui, cards = entries, scale = scale, shade = shade, root = root }
	local function ammoText(id, ammoTable)
		local a = ammoTable and ammoTable[id]
		if type(a) == "table" then
			return string.format("%d/%d", a[1] or 0, a[2] or 0)
		end
		return ""
	end
	function wheel.select(index: number, ammoTable)
		selected = index
		local def = defs[index]
		if not def then
			return
		end
		hubClass.Text = upper(def.class or (if def.kind == "gun" then "ARMA DE FOGO" else "CORPO A CORPO"))
		hubName.Text = upper(def.name or def.id)
		local a = ammoTable and ammoTable[def.id]
		hubAmmo.Text = if type(a) == "table" then string.format('%d <font color="#A4AAB8">/ %d</font>', a[1] or 0, a[2] or 0)
			else '<font color="#A4AAB8">SEM MUNIÇÃO</font>'
		for row = 1, 4 do
			local value = (def.stats or {})[row] or 0
			statBars[row].Size = UDim2.fromScale(math.clamp(if value > 1 then value / 10 else value, 0, 1), 1)
		end
		for i, entry in entries do
			local on = i == index
			entry.target = if on then 1.1 else 1
			-- Selecionado: cartão em degradê pôr do sol, ícone e textos brancos.
			entry.glow.Enabled = on
			entry.card.BackgroundColor3 = if on then LINE else PANEL
			entry.card.BackgroundTransparency = if on then 0.04 else 0.26
			entry.edge.Color = LINE
			entry.edge.Transparency = if on then 0.15 else 0.84
			entry.edge.Thickness = if on then 2 else 1
			if entry.image:IsA("ImageLabel") then
				entry.image.ImageColor3 = TEXT
			end
			entry.ammo.Text = ammoText(entry.def.id, ammoTable)
			entry.ammo.TextColor3 = if on then LINE else SUB
			if entry.key then
				entry.key.TextColor3 = if on then LINE else SUB
			end
		end
	end
	local spin = 0
	function wheel.animate(dt: number, eased: number)
		spin += dt * 0.6
		shade.BackgroundTransparency = 1 - 0.55 * eased
		for i, entry in entries do
			entry.pop.Scale += (entry.target - entry.pop.Scale) * math.min(1, dt * 14)
			if entry.viewport then
				poseViewport(entry.viewport, if i == selected then spin else 0.6)
			end
		end
	end
	wheel.select(1, {})
	return wheel
end
M.buildWheel = buildWheel

-- Botão de toque redondo, translúcido, com ícone 2D branco (ou o nome, enquanto os ícones aguardam aprovação).
-- Glifos feitos de Frames, para os botões terem símbolo mesmo antes do atlas ser aprovado.
local function frameGlyph(parent: Instance, key: string, z: number, color: Color3): Frame
	local old = parent:FindFirstChild("Glifo")
	if old then
		old:Destroy()
	end
	local box = frame(parent, "Glifo", z, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6) })
	box:SetAttribute("Chave", key)
	local function bar(x: number, y: number, w: number, h: number, rotation: number?, radius: number?)
		local item = frame(box, "Traço", z, {
			AnchorPoint = CENTER, Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), Rotation = rotation or 0,
			BackgroundTransparency = 0, BackgroundColor3 = color,
		})
		if radius then
			round(item, UDim.new(radius, 0))
		end
		return item
	end
	local function ring(x: number, y: number, size: number, thickness: number)
		local item = frame(box, "Anel", z, { AnchorPoint = CENTER, Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(size, size) })
		new("UIAspectRatioConstraint", item, { AspectRatio = 1 })
		round(item, UDim.new(1, 0))
		return item, stroke(item, color, 0, thickness)
	end
	if key == "tiro" then
		-- Pistola de lado, cano para a direita: ferrolho, armação, cabo inclinado e guarda-mato.
		bar(0.56, 0.33, 0.8, 0.2, 0, 0.12)
		bar(0.5, 0.47, 0.6, 0.1)
		bar(0.3, 0.68, 0.2, 0.44, 16, 0.18)
		local guard = frame(box, "Guarda", z, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromScale(0.17, 0.17) })
		round(guard, UDim.new(0.3, 0))
		stroke(guard, color, 0, 2)
		bar(0.2, 0.22, 0.06, 0.06)
		bar(0.92, 0.22, 0.04, 0.06)
	elseif key == "golpe" then
		bar(0.5, 0.58, 0.76, 0.44, 0, 0.28)
		for index = 0, 3 do
			bar(0.23 + index * 0.18, 0.32, 0.16, 0.26, 0, 0.45)
		end
		bar(0.38, 0.6, 0.42, 0.12, 0, 1).BackgroundColor3 = PANEL
		bar(0.5, 0.88, 0.56, 0.12, 0, 0.2)
	elseif key == "mira" then
		ring(0.5, 0.5, 0.46, 2)
		bar(0.5, 0.1, 0.07, 0.24, 0, 0.5)
		bar(0.5, 0.9, 0.07, 0.24, 0, 0.5)
		bar(0.1, 0.5, 0.24, 0.07, 0, 0.5)
		bar(0.9, 0.5, 0.24, 0.07, 0, 0.5)
		bar(0.5, 0.5, 0.09, 0.09, 0, 1)
	elseif key == "recarga" then
		local _, line = ring(0.5, 0.5, 0.82, 2.5)
		new("UIGradient", line, {
			Rotation = 35,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.42, 0), NumberSequenceKeypoint.new(0.5, 1),
				NumberSequenceKeypoint.new(0.58, 0), NumberSequenceKeypoint.new(1, 0),
			}),
		})
		bar(0.82, 0.24, 0.18, 0.18, 45, 0.1)
		bar(0.5, 0.52, 0.24, 0.44, 8, 0.25)
	elseif key == "implantes" then
		-- Chip: corpo quadrado vazado, núcleo e três pinos de cada lado.
		local body = frame(box, "Chip", z, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.56, 0.56) })
		round(body, UDim.new(0.14, 0))
		stroke(body, color, 0, 2)
		bar(0.5, 0.5, 0.2, 0.2, 0, 0.2)
		for index = 0, 2 do
			local t = 0.3 + index * 0.2
			bar(0.1, t, 0.16, 0.06)
			bar(0.9, t, 0.16, 0.06)
			bar(t, 0.1, 0.06, 0.16)
			bar(t, 0.9, 0.06, 0.16)
		end
	elseif key == "sandevistan" then
		-- Coluna: vértebras que estreitam para baixo, ligadas por um cabo.
		bar(0.5, 0.5, 0.06, 0.96, 0, 0.5)
		for index = 0, 4 do
			bar(0.5, 0.1 + index * 0.2, 0.74 - index * 0.1, 0.11, 0, 0.4)
		end
	elseif key == "psicose" then
		-- Olho rachado: anel, pupila e um raio cortando.
		ring(0.5, 0.5, 0.8, 2)
		bar(0.5, 0.5, 0.2, 0.2, 0, 1)
		bar(0.38, 0.3, 0.06, 0.4, -28, 0.5)
		bar(0.6, 0.68, 0.06, 0.4, -28, 0.5)
	else
		bar(0.5, 0.5, 0.5, 0.5, 45, 0.2)
	end
	return box
end
M.frameGlyph = frameGlyph

local function touchButton(parent, name: string, caption: string, icon: string, center: Vector2, radius: number, atlas: string?)
	local f = fonts()
	local button = new("TextButton", parent, {
		Name = name, Text = "", AutoButtonColor = false, AnchorPoint = CENTER, Position = UDim2.fromOffset(center.X, center.Y),
		Size = UDim2.fromOffset(radius * 2, radius * 2), BackgroundColor3 = PANEL, BackgroundTransparency = 0.4, ZIndex = 20,
	})
	round(button, UDim.new(1, 0))
	local ring = stroke(button, LINE, 0.68, 1.5)
	local image
	if atlas and iconRect(icon) then
		image = atlasImage(button, "Icone", atlas, icon, 21, {
			AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.58, 0.58), ImageColor3 = TEXT,
		})
	else
		frameGlyph(button, icon, 21, TEXT)
		button:SetAttribute("Legenda", caption)
	end
	local _ = f
	return button, ring, image
end
M.touchButton = touchButton


-- Painel do dono (só aparece para quem o servidor marcou com CyberOutlawAdmin): teleporte para os
-- pontos novos da cidade e troca do pacote de animação. O botão "TP" fica na faixa do topo, à direita.
local function buildAdminPanel(parent: Instance, touch: boolean, points, packs, onPick)
	local f = fonts()
	-- Nos testes (Lune) as Instances não têm eventos; no Roblox a conexão sempre existe.
	local function onActivated(button: Instance, callback: () -> ())
		pcall(function()
			(button :: any).Activated:Connect(callback)
		end)
	end
	local top = new("ScreenGui", parent, {
		Name = "CyberOutlawAdminBotao", ResetOnSpawn = false, DisplayOrder = 40, ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local open = new("TextButton", top, {
		Name = "AbrirPainel", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(44, 36), BackgroundColor3 = PANEL, BackgroundTransparency = 0.25,
	})
	round(open, UDim.new(1, 0))
	sunset(stroke(open, LINE, 0.15, 1.5), 45)
	label(open, "Texto", "TP", f.heavy, 14, TEXT, 2, { TextXAlignment = Enum.TextXAlignment.Center })
	local gui = new("ScreenGui", parent, {
		Name = "CyberOutlawAdmin", ResetOnSpawn = false, DisplayOrder = 70, Enabled = false, IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local shade = new("TextButton", gui, {
		Name = "Fundo", Text = "", AutoButtonColor = false, Size = FULL, BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45, ZIndex = 1,
	})
	local card = frame(gui, "Painel", 2, {
		AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(if touch then 0.62 else 0.42, 0.8),
		BackgroundColor3 = PANEL, BackgroundTransparency = 0.08,
	})
	new("UISizeConstraint", card, { MaxSize = Vector2.new(560, 640), MinSize = Vector2.new(260, 220) })
	round(card, UDim.new(0, 12))
	sunset(stroke(card, LINE, 0.1, 2), 35)
	label(card, "Titulo", "PAINEL DO DONO", f.heavy, if touch then 14 else 18, TEXT, 3, {
		Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -70, 0, 24),
	})
	local close = new("TextButton", card, {
		Name = "Fechar", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4),
		Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, ZIndex = 4,
	})
	frameGlyph(close, "fechar", 4, TEXT)
	local list = new("ScrollingFrame", card, {
		Name = "Lista", Position = UDim2.fromOffset(12, 50), Size = UDim2.new(1, -24, 1, -60), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never, ZIndex = 3,
	})
	new("UIListLayout", list, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	local order = 0
	local buttons = {}
	local function section(text: string)
		order += 1
		label(list, "Secao", text, f.bold, if touch then 10 else 12, PINK, 3, { Size = UDim2.new(1, 0, 0, 18), LayoutOrder = order })
	end
	local function item(kind: string, key: string, text: string)
		order += 1
		local button = new("TextButton", list, {
			Name = kind .. "_" .. key, Text = "", AutoButtonColor = true, Size = UDim2.new(1, -6, 0, if touch then 36 else 40),
			BackgroundColor3 = Color3.fromRGB(28, 26, 48), BackgroundTransparency = 0.1, LayoutOrder = order, ZIndex = 3,
		})
		round(button, UDim.new(0, 8))
		local edge = stroke(button, LINE, 0.85, 1)
		label(button, "Texto", text, f.bold, if touch then 12 else 14, TEXT, 4, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0) })
		onActivated(button, function()
			onPick(kind, key)
		end)
		buttons[kind .. "_" .. key] = { button = button, edge = edge }
		return button
	end
	section("TELEPORTE")
	for _, point in points do
		item("tp", point.k, point.n)
	end
	section("ANIMAÇÃO DO PERSONAGEM (CATÁLOGO)")
	for _, pack in packs do
		item("pacote", pack.k, pack.n)
	end
	local panel = { gui = gui, button = open, top = top, card = card, list = list, buttons = buttons }
	function panel.toggle(show: boolean?)
		gui.Enabled = if show == nil then not gui.Enabled else show
	end
	function panel.mark(kind: string, key: string)
		for name, entry in buttons do
			if string.sub(name, 1, #kind + 1) == kind .. "_" then
				local on = name == kind .. "_" .. key
				entry.edge.Color = if on then GOLD else LINE
				entry.edge.Transparency = if on then 0.1 else 0.85
				entry.edge.Thickness = if on then 2 else 1
			end
		end
	end
	onActivated(open, function()
		panel.toggle()
	end)
	onActivated(close, function()
		panel.toggle(false)
	end)
	onActivated(shade, function()
		panel.toggle(false)
	end)
	return panel
end
M.buildAdminPanel = buildAdminPanel

-- Botão do HUD no estilo neon: vidro escuro, traço ciano e halo largo, símbolo do atlas (ou de Frames) e a
-- tecla no canto no PC. Fica 2D porque recebe toque; o visual combina com as placas 3D.
local function neonButton(parent: Instance, name: string, glyph: string, atlas: string?, keyHint: string?, circle: boolean?)
	local corner = if circle then UDim.new(1, 0) else UDim.new(0, 9)
	local button = new("TextButton", parent, {
		Name = name, Text = "", AutoButtonColor = false, BackgroundColor3 = PANEL, BackgroundTransparency = 0.32, ZIndex = 20,
		AnchorPoint = CENTER, Size = UDim2.fromOffset(44, 44), Selectable = false,
	})
	round(button, corner)
	local scale = new("UIScale", button, { Name = "Escala" })
	local glow = frame(button, "Halo", 19, { Size = FULL })
	round(glow, corner)
	local halo = stroke(glow, NEON, 0.78, 6)
	local line = stroke(button, NEON, 0.12, 1.5)
	local image
	if atlas and iconRect(glyph) then
		image = atlasImage(button, "Icone", atlas, glyph, 21, {
			AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), ImageColor3 = NEON,
		})
	else
		frameGlyph(button, glyph, 21, NEON)
	end
	if keyHint then
		label(button, "Tecla", keyHint, Font.fromEnum(Enum.Font.Michroma), 10, NEON, 22, {
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -2), Size = UDim2.fromOffset(16, 12),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
	local entry = { button = button, line = line, halo = halo, image = image, scale = scale }
	-- Aceso (habilidade ativa ou painel aberto) ou apagado; color troca o neon (rosa no surto).
	function entry.light(on: boolean, color: Color3?)
		local tone = color or NEON
		line.Color, halo.Color = tone, tone
		line.Thickness = if on then 2.5 else 1.5
		halo.Transparency = if on then 0.45 else 0.78
		button.BackgroundTransparency = if on then 0.12 else 0.32
		if image then
			image.ImageColor3 = tone
		end
	end
	return entry
end
M.neonButton = neonButton

-- Barra neon das armas em 3D: uma placa na frente da câmera, inclinada e com balanço, com quatro armas por
-- página (setas < > mostram as outras), a tecla de cada uma e a munição. O brilho acima de 1 acende com o bloom.
-- As posições ficam em escala para a camada 2D de toque usar as mesmas áreas (BAR_HITS).
local BAR_PER_PAGE = 4
local BAR_SLOT_X, BAR_SLOT_W, BAR_SLOT_PITCH = 0.073, 0.145, 0.155
local BAR_HITS = {
	left = { UDim2.fromScale(0, 0.08), UDim2.fromScale(0.065, 0.84) },
	right = { UDim2.fromScale(0.691, 0.08), UDim2.fromScale(0.065, 0.84) },
}
for index = 1, BAR_PER_PAGE do
	BAR_HITS[index] = { UDim2.fromScale(BAR_SLOT_X + (index - 1) * BAR_SLOT_PITCH, 0.08), UDim2.fromScale(BAR_SLOT_W, 0.84) }
end
M.BAR_HITS = BAR_HITS
M.BAR_PER_PAGE = BAR_PER_PAGE
local SHORT_NAMES = { punhos = "SOCO", faca = "FACA", glock = "G17", deagle = ".50", uzi = "UZI", ak47 = "AK",
	m4 = "M4", escopeta = "12", sniper = ".308" }
local function neonBox(parent: Instance, name: string, position: UDim2, size: UDim2, z: number, thick: number?)
	local glow = frame(parent, name .. "Halo", z, { Position = position, Size = size })
	round(glow, UDim.new(0, 8))
	local halo = stroke(glow, NEON, 0.8, 9)
	local box = frame(parent, name, z + 1, { Position = position, Size = size })
	round(box, UDim.new(0, 6))
	local line = stroke(box, NEON, 0, thick or 3)
	return box, line, glow, halo
end
local function holoSurface(name: string, canvas: Vector2): (Part, SurfaceGui)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Transparency = 1
	part.Size = Vector3.new(3, 1.2, 0.02)
	local gui = new("SurfaceGui", nil, {
		Name = name, Face = Enum.NormalId.Back, Adornee = part, AlwaysOnTop = true, LightInfluence = 0,
		Brightness = 2.2, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = canvas,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ResetOnSpawn = false, ClipsDescendants = false,
	})
	return part, gui
end
M.holoSurface = holoSurface
-- Inclinação da placa pela posição na tela (nx, ny de -1 a 1 a partir do centro): devolve o pivô (borda de
-- fora: -1, 0 ou 1 em x e y) e os ângulos (pitch, yaw) em radianos, como um painel curvo de cabine.
local function holoTilt(nx: number, ny: number): (number, number, number, number)
	local fx = if math.abs(nx) > 0.35 then (if nx < 0 then -1 else 1) else 0
	local fy = if math.abs(ny) > 0.35 then (if ny < 0 then -1 else 1) else 0
	return fx, fy, -ny * 0.24, -nx * 0.28
end
M.holoTilt = holoTilt
local function buildWeaponBar(defs, atlas: string?)
	local mono = Font.fromEnum(Enum.Font.Michroma)
	-- Números estreitos (Roboto Mono em negrito) para "30/150" caber ao lado das setas.
	local digits = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
	local part, gui = holoSurface("CyberOutlawBarraNeon", Vector2.new(560, 92))
	local texts = {} -- { label, fração da altura da tela }
	local function text(parent, name, value, share, z, props, font)
		local item = label(parent, name, value, font or mono, 18, NEON, z, props)
		table.insert(texts, { item, share })
		return item
	end
	local slots = {}
	for index = 1, BAR_PER_PAGE do
		local hit = BAR_HITS[index]
		local box, line, glow = neonBox(gui, "Slot" .. index, hit[1], hit[2], 2)
		local key = text(box, "Tecla", "", 0.2, 5, {
			Position = UDim2.fromScale(0.07, 0.03), Size = UDim2.fromScale(0.4, 0.3), TextXAlignment = Enum.TextXAlignment.Left,
		})
		local icon
		if atlas then
			icon = new("ImageLabel", box, {
				Name = "Icone", BackgroundTransparency = 1, Image = atlas, ImageColor3 = NEON, ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromScale(0.9, 0.62), ZIndex = 5,
			})
		end
		local short = text(box, "Sigla", "", 0.28, 5, {
			AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromScale(0.96, 0.5),
			TextXAlignment = Enum.TextXAlignment.Center, Visible = atlas == nil,
		})
		slots[index] = { box = box, line = line, glow = glow, key = key, icon = icon, short = short, id = nil }
	end
	local arrows = {}
	for _, side in { "left", "right" } do
		local hit = BAR_HITS[side]
		local box, line = neonBox(gui, if side == "left" then "SetaEsquerda" else "SetaDireita", hit[1], hit[2], 2, 2)
		text(box, "Simbolo", if side == "left" then "<" else ">", 0.42, 5, { TextXAlignment = Enum.TextXAlignment.Center })
		arrows[side] = { box = box, line = line }
	end
	-- Munição: pente grande, reserva menor, nome da arma e a recarga embaixo.
	local mag = text(gui, "Pente", "", 0.46, 4, {
		Position = UDim2.fromScale(0.772, 0.04), Size = UDim2.fromScale(0.108, 0.52), TextXAlignment = Enum.TextXAlignment.Right,
	}, digits)
	local reserve = text(gui, "Reserva", "", 0.24, 4, {
		Position = UDim2.fromScale(0.884, 0.2), Size = UDim2.fromScale(0.114, 0.3), TextXAlignment = Enum.TextXAlignment.Left,
	}, digits)
	local nameLabel = text(gui, "Nome", "", 0.2, 4, {
		Position = UDim2.fromScale(0.77, 0.58), Size = UDim2.fromScale(0.225, 0.22), TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local reloadTrack = frame(gui, "Recarga", 4, {
		Position = UDim2.fromScale(0.775, 0.86), Size = UDim2.fromScale(0.215, 0.05), BackgroundTransparency = 0.7, BackgroundColor3 = NEON,
		Visible = false,
	})
	local reloadFill = frame(reloadTrack, "Valor", 5, { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, BackgroundColor3 = NEON })
	local bar = { part = part, gui = gui, slots = slots, arrows = arrows, page = 1, mag = mag, reserve = reserve, name = nameLabel,
		reload = reloadTrack }
	bar.pages = math.max(1, math.ceil(#defs / BAR_PER_PAGE))
	-- A tela da placa acompanha o retângulo do layout (2 px de tela por px do layout, sem esticar).
	function bar.resize(canvas: Vector2)
		gui.CanvasSize = canvas
		for _, entry in texts do
			entry[1].TextSize = math.max(9, math.floor(canvas.Y * entry[2] + 0.5))
		end
	end
	function bar.setPage(page: number)
		bar.page = math.clamp(page, 1, bar.pages)
		for index, slot in slots do
			local d = defs[(bar.page - 1) * BAR_PER_PAGE + index]
			slot.id = d and d.id
			slot.box.Visible = d ~= nil
			slot.glow.Visible = false
			if d then
				slot.key.Text = tostring(d.order or index)
				slot.short.Text = SHORT_NAMES[d.id] or upper(d.id)
				if slot.icon then
					local offset, size = iconRect(d.id)
					slot.icon.ImageRectOffset, slot.icon.ImageRectSize = offset or Vector2.zero, size or Vector2.zero
				end
			end
		end
		arrows.left.box.Visible = bar.page > 1
		arrows.right.box.Visible = bar.page < bar.pages
	end
	function bar.pageOf(id: string): number
		for index, d in defs do
			if d.id == id then
				return (index - 1) // BAR_PER_PAGE + 1
			end
		end
		return bar.page
	end
	-- weapon: a definição da arma atual; ammo: { pente, reserva } ou nil; progress: recarga de 0 a 1 ou nil.
	function bar.set(weapon, ammo, progress: number?)
		local current = weapon and weapon.id
		for _, slot in slots do
			local on = slot.id ~= nil and slot.id == current
			slot.box.BackgroundTransparency = if on then 0.74 else 1
			slot.box.BackgroundColor3 = NEON
			slot.line.Thickness = if on then 4 else 2.5
			slot.line.Transparency = if on then 0 else 0.35
			slot.glow.Visible = on
		end
		if type(ammo) == "table" then
			mag.Text = tostring(ammo[1] or 0)
			reserve.Text = "/" .. tostring(ammo[2] or 0)
			local low = (ammo[1] or 0) <= math.max(1, math.floor(((weapon and weapon.mag) or 10) * 0.25))
			mag.TextColor3 = if low then NEON_HURT else NEON
		else
			mag.Text = "∞"
			reserve.Text = ""
			mag.TextColor3 = NEON
		end
		nameLabel.Text = upper((weapon and (weapon.name or weapon.id)) or "")
		reloadTrack.Visible = progress ~= nil
		if progress then
			reloadFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
		end
	end
	bar.resize(gui.CanvasSize)
	bar.setPage(1)
	bar.set(defs[1], nil, nil)
	return bar
end
M.buildWeaponBar = buildWeaponBar

-- Runtime --------------------------------------------------------------------------------------
local function start()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GuiService = game:GetService("GuiService")
	local HttpService = game:GetService("HttpService")
	local SoundService = game:GetService("SoundService")
	local StarterGui = game:GetService("StarterGui")
	local Workspace = game:GetService("Workspace")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local quality = 10
	pcall(function()
		local saved = UserSettings():GetService("UserGameSettings").SavedQualityLevel
		quality = if saved == Enum.SavedQualitySetting.Automatic then 7 else saved.Value
	end)

	if not player:GetAttribute("CyberOutlawMenuStarted") then
		player:GetAttributeChangedSignal("CyberOutlawMenuStarted"):Wait()
	end
	local arsenal = ReplicatedStorage:WaitForChild("CyberOutlawArsenal", 30)
	local defs, byId, templates = {}, {}, {}
	local action, effectEvent, aimEvent
	local safeZone
	if arsenal then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(arsenal:GetAttribute("Armas"))
		end)
		if ok and type(decoded) == "table" then
			defs = decoded
			table.sort(defs, function(a, b)
				return a.order < b.order
			end)
		end
		for _, def in defs do
			byId[def.id] = def
		end
		local models = arsenal:WaitForChild("Modelos", 10)
		for _, def in defs do
			templates[def.id] = models and models:FindFirstChild(def.id)
		end
		action = arsenal:WaitForChild("Acao", 10)
		effectEvent = arsenal:WaitForChild("Efeito", 10)
		aimEvent = arsenal:WaitForChild("Mira", 10)
		pcall(function()
			safeZone = HttpService:JSONDecode(arsenal:GetAttribute("ZonaSegura"))
		end)
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	local camera = Workspace.CurrentCamera
	local effects = Instance.new("Folder")
	effects.Name = "CyberOutlawEfeitos"
	effects.Parent = camera
	local rng = Random.new()

	-- Primeiro som aprovado da lista (os novos têm o antigo como reserva).
	local function pick(...: string): string
		for _, key in { ... } do
			if type(SOUNDS[key]) == "number" then
				return key
			end
		end
		return (...)
	end
	local function sound(key: string, parent: Instance?, volume: number?)
		local id = SOUNDS[key]
		if type(id) ~= "number" or id <= 0 then
			return
		end
		local item = Instance.new("Sound")
		item.SoundId = string.format("rbxassetid://%.0f", id)
		item.Volume = volume or 0.6
		item.RollOffMaxDistance = 260
		if parent then
			item.Parent = parent
			item:Play()
			item.Ended:Once(function()
				item:Destroy()
			end)
			task.delay(4, function()
				if item.Parent then
					item:Destroy()
				end
			end)
		else
			SoundService:PlayLocalSound(item)
			item:Destroy()
		end
	end

	-- Character state ---------------------------------------------------------------------------
	local character, humanoid, root, torso, head
	local align, alignAttachment
	local joints = {}
	local facingYaw = 0
	local controls
	pcall(function()
		local module = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10))
		controls = module:GetControls()
	end)

	local function bindCharacter(model: Model)
		character = model
		humanoid = model:WaitForChild("Humanoid", 10)
		root = model:WaitForChild("HumanoidRootPart", 10)
		torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
		head = model:FindFirstChild("Head")
		table.clear(joints)
		if root then
			joints.root = root:FindFirstChild("RootJoint")
			joints.rootC0 = joints.root and joints.root.C0
			facingYaw = math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z)
			alignAttachment = Instance.new("Attachment")
			alignAttachment.Name = "CyberOutlawFacing"
			alignAttachment.Parent = root
			align = Instance.new("AlignOrientation")
			align.Name = "CyberOutlawFacing"
			align.Mode = Enum.OrientationAlignmentMode.OneAttachment
			align.Attachment0 = alignAttachment
			align.MaxTorque = 1e7
			align.MaxAngularVelocity = 30
			align.Responsiveness = 16
			align.RigidityEnabled = false
			align.CFrame = CFrame.Angles(0, facingYaw, 0)
			align.Parent = root
		end
		if torso then
			joints.neck = torso:FindFirstChild("Neck")
		end
		if humanoid then
			humanoid.AutoRotate = false
		end
	end

	-- Camera --------------------------------------------------------------------------------------
	local cam = {
		yaw = 0, pitch = math.rad(-10), focus = nil, focusVel = Vector3.zero, height = 0, heightVel = 0,
		distance = 11.5, distanceVel = 0, shoulder = 1.35, shoulderVel = 0, fov = 70, fovVel = 0,
		lastInput = 0, trauma = 0, kick = 0, kickYaw = 0, side = 1, deathSpin = 0,
	}
	local touchCamera: { [InputObject]: Vector3 } = {}
	local stick = Vector2.zero
	local sensitivity = 1
	pcall(function()
		sensitivity = UserSettings():GetService("UserGameSettings").MouseSensitivity
	end)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	local filterAt = 0
	local function refreshFilter()
		local list = { effects }
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(list, other.Character)
			end
		end
		rayParams.FilterDescendantsInstances = list
	end

	-- Movement and combat state ----------------------------------------------------------------------
	local stamina = { value = 1, rest = 0, exhausted = false }
	local sprintHeld, sprintToggle, sprinting = false, false, false
	local pushTime = 0
	local speed = 16
	local current = "punhos"
	local aiming, aimToggle = false, false
	local triggerHeld = false
	local nextShot, nextMelee = 0, 0
	local hipFireUntil = 0
	local bloom = 0
	local meleeSide = 1
	local wheelOpen = false
	local wheelOpenAmount = 0
	local wheelSelection = 1
	local ammoTable = {}
	local lastPitchSent, pitchSentAt = 999, 0
	local poses = {} -- [character] = { swingStart, swingKind, swingSide, firedAt }
	local gaits = setmetatable({}, { __mode = "k" }) -- [character] = estado da locomoção procedural
	local dead = false

	local function def(): any
		return byId[current] or byId.punhos or { id = "punhos", kind = "melee", name = "Punhos", accent = { 255, 166, 94 }, rate = 2.6 }
	end

	local function readAmmo()
		local raw = player:GetAttribute("CyberOutlawMunicao")
		if type(raw) == "string" then
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(raw)
			end)
			if ok and type(decoded) == "table" then
				ammoTable = decoded
			end
		end
	end
	player:GetAttributeChangedSignal("CyberOutlawMunicao"):Connect(readAmmo)
	readAmmo()

	local function inSafeZone(position: Vector3): boolean
		if type(safeZone) ~= "table" then
			return false
		end
		local dx, dz = position.X - safeZone[1], position.Z - safeZone[2]
		return dx * dx + dz * dz < safeZone[3] * safeZone[3]
	end

	-- Interface ----------------------------------------------------------------------------------
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	local hud = buildHud(playerGui, touch)
	local combat = buildCombat(playerGui, touch)
	-- Painel do dono: só monta quando o servidor confirma CyberOutlawAdmin; o servidor confere de novo.
	local adminPanel
	local function mountAdmin()
		if adminPanel or player:GetAttribute("CyberOutlawAdmin") ~= true then
			return
		end
		local remote = ReplicatedStorage:WaitForChild("CyberOutlawAdmin", 10)
		local pointsFolder = ReplicatedStorage:WaitForChild("CyberOutlawPontos", 20)
		if not remote or adminPanel then
			return
		end
		local points = {}
		local raw = pointsFolder and pointsFolder:GetAttribute("Lista")
		if type(raw) == "string" then
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
			if ok and type(decoded) == "table" then
				points = decoded
			end
		end
		local animations = ReplicatedStorage:FindFirstChild("CyberOutlawAnimacoes")
		local packs = {}
		for _, key in PACK_ORDER do
			local builtIn = ANIMATION_PACKS[key]
			local extra = animations and animations:GetAttribute(key)
			local name = if builtIn then builtIn.nome else nil
			if not name and type(extra) == "string" then
				local ok, decoded = pcall(HttpService.JSONDecode, HttpService, extra)
				name = if ok and type(decoded) == "table" then decoded.nome else nil
			end
			if name then
				table.insert(packs, { k = key, n = name })
			end
		end
		adminPanel = buildAdminPanel(playerGui, touch, points, packs, function(kind, key)
			remote:FireServer(kind, key)
			if kind == "tp" then
				adminPanel.toggle(false)
			else
				adminPanel.mark("pacote", key)
			end
		end)
		local current = animations and animations:GetAttribute("Pacote")
		if type(current) == "string" then
			adminPanel.mark("pacote", current)
		end
	end
	player:GetAttributeChangedSignal("CyberOutlawAdmin"):Connect(function()
		task.spawn(mountAdmin)
	end)
	task.spawn(mountAdmin)
	local wheel = if #defs > 0 then buildWheel(playerGui, defs, templates, touch, ATLAS) else nil
	-- Barra neon das armas (placa 3D) e a âncora 2D que marca o lugar dela e recebe o toque nas mesmas áreas.
	local bar = if #defs > 0 then buildWeaponBar(defs, ATLAS) else nil
	local barAnchor = frame(hud.gui, "BarraNeonAncora", 1, { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(280, 46) })
	local barAnchorScale = new("UIScale", barAnchor, { Name = "Escala" })
	local barTaps = {}
	if bar then
		bar.gui.Parent = playerGui
		for key, hit in BAR_HITS do
			-- Toque um pouco maior que a caixa: as caixas encostam umas nas outras e as setas crescem para fora.
			local x, w = hit[1].X.Scale - 0.005, BAR_SLOT_PITCH
			if key == "left" then
				x, w = -0.05, 0.118
			elseif key == "right" then
				x, w = 0.688, 0.118
			end
			barTaps[key] = new("TextButton", barAnchor, {
				Name = "Toque" .. tostring(key), Text = "", BackgroundTransparency = 1, Position = UDim2.fromScale(x, 0),
				Size = UDim2.fromScale(w, 1), ZIndex = 2, Selectable = false,
			})
		end
	end
	-- Botões neon: arsenal (no toque; no PC é Q), implantes (I) e a habilidade do implante encaixado (X).
	local arsenalButton = if touch and wheel then neonButton(hud.gui, "Arsenal", "arsenal", ATLAS, nil, false) else nil
	local implantsButton = neonButton(hud.gui, "Implantes", "implantes", ATLAS, if touch then nil else "I", false)
	local abilityButton = neonButton(hud.gui, "Habilidade", "sandevistan", ATLAS, if touch then nil else "X", touch)
	abilityButton.button.Visible = false
	local implantsOpen = false
	local toggleImplants: ((boolean?) -> ())?, useAbility: (() -> ())? -- definidas na seção dos implantes
	local blur = Instance.new("BlurEffect")
	blur.Name = "CyberOutlawRoletaBlur"
	blur.Size = 0
	blur.Parent = camera
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "CyberOutlawRoletaCor"
	grade.Parent = camera
	local depth = Instance.new("DepthOfFieldEffect")
	depth.Name = "CyberOutlawMiraFoco"
	depth.Enabled = false
	depth.FarIntensity = 0.28
	depth.NearIntensity = 0
	depth.InFocusRadius = 40
	depth.Parent = camera
	local deathGrade = Instance.new("ColorCorrectionEffect")
	deathGrade.Name = "CyberOutlawSinalPerdido"
	deathGrade.Enabled = false
	deathGrade.Saturation = -0.85
	deathGrade.TintColor = Color3.fromRGB(255, 200, 210)
	deathGrade.Parent = camera
	local damageFlash = 0
	local barShows
	local safeBlockedUntil = 0
	local aimBlur = 0

	local fireButton, aimButton, reloadButton, aimRing, fireRing, fireIcon
	local fireShows
	if touch then
		fireButton, fireRing, fireIcon = touchButton(hud.gui, "Atirar", "ATIRAR", "tiro", Vector2.zero, 32, ATLAS)
		-- O botão principal ganha a borda pôr do sol; os outros ficam brancos e discretos.
		fireRing.Transparency, fireRing.Thickness = 0.1, 2
		sunset(fireRing, 45)
		aimButton, aimRing = touchButton(hud.gui, "Mirar", "MIRAR", "mira", Vector2.zero, 26, ATLAS)
		reloadButton = touchButton(hud.gui, "Recarregar", "RECARGA", "recarga", Vector2.zero, 21, ATLAS)
	end

	-- Layout: recalculado quando a tela muda e quando os controles de toque do Roblox aparecem.
	local function jumpButton()
		local touchGui = playerGui:FindFirstChild("TouchGui")
		local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
		if jump and jump:IsA("GuiObject") and jump.Visible and jump.AbsoluteSize.X > 10 then
			return { center = jump.AbsolutePosition + jump.AbsoluteSize / 2 - hud.gui.AbsolutePosition, size = jump.AbsoluteSize.X }
		end
		return nil
	end
	local function relayout()
		local size = hud.gui.AbsoluteSize
		if size.X < 10 or size.Y < 10 then
			return
		end
		local l = hudLayout(size, touch, if touch then jumpButton() else nil)
		hud.layout(l)
		place(barAnchor, l.neon, l.scale, barAnchorScale)
		if bar then
			bar.resize(l.neon.size * 2)
		end
		if arsenalButton then
			place(arsenalButton.button, l.arsenal, l.scale, arsenalButton.scale)
		end
		place(implantsButton.button, l.implants, l.scale, implantsButton.scale)
		if touch then
			local spec = l.buttons.ability
			abilityButton.button.AnchorPoint = CENTER
			abilityButton.button.Position = UDim2.fromOffset(spec.center.X, spec.center.Y)
			abilityButton.button.Size = UDim2.fromOffset(spec.radius * 2, spec.radius * 2)
			abilityButton.scale.Scale = 1
		else
			place(abilityButton.button, l.ability, l.scale, abilityButton.scale)
		end
		if wheel then
			wheel.scale.Scale = l.wheel.scale
		end
		if touch and fireButton then
			for button, key in { [fireButton] = "fire", [aimButton] = "aim", [reloadButton] = "reload" } do
				local spec = l.buttons[key]
				button.Position = UDim2.fromOffset(spec.center.X, spec.center.Y)
				button.Size = UDim2.fromOffset(spec.radius * 2, spec.radius * 2)
			end
		end
	end
	hud.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	relayout()
	task.spawn(function()
		for _ = 1, 12 do
			task.wait(1)
			relayout()
		end
	end)

	-- Mapa publicado pelo servidor da cidade.
	local cityLayout
	task.spawn(function()
		local board = ReplicatedStorage:WaitForChild("CyberOutlawCityInfo", 60)
		if not board then
			return
		end
		local function read()
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(board:GetAttribute("Layout"))
			end)
			if ok and type(decoded) == "table" then
				cityLayout = decoded
				hud.setMap(decoded)
			end
		end
		board:GetAttributeChangedSignal("Layout"):Connect(read)
		read()
	end)
	-- Reflexos das poças -----------------------------------------------------------------------------
	-- Por baixo de cada poça há um buraco no asfalto. O cliente monta ali uma cópia espelhada dos prédios,
	-- néons, letreiros e personagens próximos, que aparece através da água. Não precisa de RTX e funciona
	-- em qualquer aparelho; só as poças perto da câmera ficam ativas.
	local mirror = Instance.new("Folder")
	mirror.Name = "CyberOutlawReflexos"
	mirror.Parent = camera
	local MIRROR_SKIP = {
		["Asfalto molhado"] = true, ["Poça"] = true, ["Calçada"] = true, ["Meio-fio"] = true, ["Pintura"] = true,
		["Faixa de pedestres"] = true, ["Muro invisível"] = true, ["Canteiro central"] = true, ["Bueiro"] = true,
	}
	local CELL = 64
	local grid, puddleList = {}, {}
	local function cellOf(x: number, z: number): string
		return math.floor(x / CELL) .. "," .. math.floor(z / CELL)
	end
	local function indexPart(item: Instance)
		if item:IsA("BasePart") then
			if item.Name == "Poça" and item:GetAttribute("CyberOutlawPlano") then
				table.insert(puddleList, item)
			elseif not MIRROR_SKIP[item.Name] then
				local key = cellOf(item.Position.X, item.Position.Z)
				local list = grid[key]
				if not list then
					list = {}
					grid[key] = list
				end
				table.insert(list, item)
			end
		end
	end
	task.spawn(function()
		local city = Workspace:WaitForChild("CyberOutlawCity", 120)
		if not city then
			return
		end
		city.DescendantAdded:Connect(indexPart)
		for index, item in city:GetDescendants() do
			indexPart(item)
			if index % 1500 == 0 then
				task.wait()
			end
		end
	end)
	local copies = {} -- [peça original] = { copy, users }
	local zones = {} -- [poça] = { plane, parts = {original...} }
	local queue = {}
	local mirrorCount = 0
	local MIRROR_LIMIT = if quality <= 4 then 160 else 320
	local function worthReflecting(part: BasePart, plane: number): boolean
		if part.Transparency >= 0.98 or not part.Parent then
			return false
		end
		local cf, size = part.CFrame, part.Size
		local _, _, _, _, _, _, r10, r11, r12 = cf:GetComponents()
		local extent = math.abs(r10) * size.X / 2 + math.abs(r11) * size.Y / 2 + math.abs(r12) * size.Z / 2
		if cf.Position.Y - extent < plane + 0.05 then
			return false -- o que encosta no chão não aparece no reflexo
		end
		return math.max(size.X, size.Y, size.Z) >= 2 or part.Material == Enum.Material.Neon or part:FindFirstChildOfClass("SurfaceGui") ~= nil
	end
	local function makeCopy(part: BasePart, plane: number)
		local ok, copy = pcall(function()
			return part:Clone()
		end)
		if not ok or not copy then
			return nil
		end
		for _, child in copy:GetDescendants() do
			if child:IsA("Light") or child:IsA("ParticleEmitter") or child:IsA("Fire") or child:IsA("Sound") or child:IsA("BaseScript") then
				child:Destroy()
			end
		end
		copy.Anchored, copy.CanCollide, copy.CanQuery, copy.CanTouch, copy.CastShadow = true, false, false, false, false
		local wedge = part:IsA("WedgePart") or (part:IsA("Part") and part.Shape == Enum.PartType.Wedge)
		copy.CFrame = mirrorCFrame(part.CFrame, plane, wedge)
		-- No reflexo, letreiros e janelas ficam de cabeça para baixo.
		for _, gui in copy:GetChildren() do
			if gui:IsA("SurfaceGui") and gui.Face ~= Enum.NormalId.Top and gui.Face ~= Enum.NormalId.Bottom then
				local turn = Instance.new("Frame")
				turn.Name = "Reflexo"
				turn.BackgroundTransparency = 1
				turn.Size = UDim2.fromScale(1, 1)
				turn.Rotation = 180
				for _, item in gui:GetChildren() do
					item.Parent = turn
				end
				turn.Parent = gui
			end
		end
		copy.Parent = mirror
		return copy
	end
	local function release(part: BasePart)
		local entry = copies[part]
		if entry then
			entry.users -= 1
			if entry.users <= 0 then
				if entry.copy then
					entry.copy:Destroy()
					mirrorCount -= 1
				end
				copies[part] = nil
			end
		end
	end
	local function activate(puddle: BasePart)
		local plane = puddle:GetAttribute("CyberOutlawPlano") or puddle.Position.Y
		local center = puddle.Position
		local found = {}
		local reach = 2
		local cx, cz = math.floor(center.X / CELL), math.floor(center.Z / CELL)
		for dx = -reach, reach do
			for dz = -reach, reach do
				for _, part in grid[(cx + dx) .. "," .. (cz + dz)] or {} do
					if worthReflecting(part, plane) then
						table.insert(found, part)
					end
				end
			end
		end
		-- Primeiro o que brilha e o que está perto; o resto entra se sobrar orçamento.
		table.sort(found, function(a, b)
			local ga = if a.Material == Enum.Material.Neon or a:FindFirstChildOfClass("SurfaceGui") then 0 else 1
			local gb = if b.Material == Enum.Material.Neon or b:FindFirstChildOfClass("SurfaceGui") then 0 else 1
			if ga ~= gb then
				return ga < gb
			end
			return (a.Position - center).Magnitude < (b.Position - center).Magnitude
		end)
		local zone = { plane = plane, parts = {} }
		for _, part in found do
			local entry = copies[part]
			if entry then
				entry.users += 1
			else
				copies[part] = { users = 1, plane = plane }
				table.insert(queue, part)
			end
			table.insert(zone.parts, part)
		end
		zones[puddle] = zone
	end
	local function deactivate(puddle: BasePart)
		local zone = zones[puddle]
		if zone then
			for _, part in zone.parts do
				release(part)
			end
			zones[puddle] = nil
		end
	end
	local zoneClock = 0
	local function reflectionStep(dt: number)
		zoneClock -= dt
		if zoneClock <= 0 then
			zoneClock = 0.5
			local eye = camera.CFrame.Position
			local wanted = {}
			local near = {}
			for _, puddle in puddleList do
				if puddle.Parent then
					local distance = (puddle.Position - eye).Magnitude
					if distance < 130 then
						table.insert(near, { puddle, distance })
					end
				end
			end
			table.sort(near, function(a, b)
				return a[2] < b[2]
			end)
			for index = 1, math.min(3, #near) do
				wanted[near[index][1]] = true
			end
			for puddle in zones do
				if not wanted[puddle] then
					deactivate(puddle)
				end
			end
			for puddle in wanted do
				if not zones[puddle] then
					activate(puddle)
				end
			end
		end
		-- Cria as cópias aos poucos, para não travar o quadro.
		local budget = 30
		while budget > 0 and #queue > 0 do
			local part = table.remove(queue, 1)
			local entry = copies[part]
			if entry and not entry.copy and mirrorCount < MIRROR_LIMIT then
				entry.copy = makeCopy(part, entry.plane)
				if entry.copy then
					mirrorCount += 1
				end
			end
			budget -= 1
		end
	end
	-- Personagens refletidos: uma cópia por jogador perto de uma poça ativa, movida a cada quadro.
	local mirrorBodies = {}
	local function reflectCharacters()
		local plane, centers = nil, {}
		for puddle, zone in zones do
			plane = zone.plane
			table.insert(centers, puddle.Position)
		end
		local alive = {}
		if plane then
			for _, other in Players:GetPlayers() do
				local model = other.Character
				local rootPart = model and model:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local close = false
					for _, c in centers do
						if (rootPart.Position - c).Magnitude < 70 then
							close = true
							break
						end
					end
					if close then
						alive[model] = true
						local body = mirrorBodies[model]
						if not body then
							local archivable = model.Archivable
							model.Archivable = true
							local ok, clone = pcall(function()
								return model:Clone()
							end)
							model.Archivable = archivable
							if ok and clone then
								-- Clone mantém a ordem da hierarquia: o i-ésimo descendente da cópia corresponde ao do original.
								local links, parts, frames = {}, {}, {}
								local originals, cloned = model:GetDescendants(), clone:GetDescendants()
								for index, item in cloned do
									if item:IsA("BasePart") then
										item.Anchored, item.CanCollide, item.CanQuery, item.CanTouch, item.CastShadow = true, false, false, false, false
										local source = originals[index]
										if source and source.ClassName == item.ClassName and source.Name == item.Name and source.Name ~= "HumanoidRootPart" then
											table.insert(links, { source, item })
											table.insert(parts, item)
										else
											item.Transparency = 1
										end
									end
								end
								for _, item in cloned do
									if item:IsA("BaseScript") or item:IsA("Sound") or item:IsA("Light") or item:IsA("ParticleEmitter") then
										item:Destroy()
									end
								end
								local clonedHumanoid = clone:FindFirstChildOfClass("Humanoid")
								if clonedHumanoid then
									clonedHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
									clonedHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
									pcall(function()
										clonedHumanoid.EvaluateStateMachine = false
									end)
								end
								clone.Name = "Reflexo de " .. model.Name
								clone.Parent = mirror
								body = { clone = clone, links = links, parts = parts, frames = frames }
								mirrorBodies[model] = body
							end
						end
						if body then
							for index, link in body.links do
								body.frames[index] = mirrorCFrame(link[1].CFrame, plane)
							end
							Workspace:BulkMoveTo(body.parts, body.frames, Enum.BulkMoveMode.FireCFrameChanged)
						end
					end
				end
			end
		end
		for model, body in mirrorBodies do
			if not alive[model] then
				body.clone:Destroy()
				mirrorBodies[model] = nil
			end
		end
	end

	local function districtOf(position: Vector3)
		if type(cityLayout) ~= "table" or type(cityLayout.districts) ~= "table" then
			return nil
		end
		for _, d in cityLayout.districts do
			local r = d.rect
			if position.X >= r[1] and position.X <= r[3] and position.Z >= r[2] and position.Z <= r[4] then
				return d
			end
		end
		return nil
	end

	-- Local effects ----------------------------------------------------------------------------------
	local function fadePart(part: BasePart, life: number, grow: Vector3?)
		local start = os.clock()
		local base = part.Transparency
		local size = part.Size
		local connection
		connection = RunService.Heartbeat:Connect(function()
			local t = (os.clock() - start) / life
			if t >= 1 or not part.Parent then
				connection:Disconnect()
				part:Destroy()
				return
			end
			part.Transparency = base + (1 - base) * t
			if grow then
				part.Size = size + grow * t
			end
		end)
	end

	local function spark(position: Vector3, color: Color3, count: number, normal: Vector3?)
		for _ = 1, count do
			local shard = Instance.new("Part")
			shard.Anchored = true
			shard.CanCollide = false
			shard.CanQuery = false
			shard.CanTouch = false
			shard.CastShadow = false
			shard.Material = Enum.Material.Neon
			shard.Color = color
			shard.Size = Vector3.new(0.08, 0.08, rng:NextNumber(0.2, 0.45))
			local direction = ((normal or Vector3.yAxis) + Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.3, 0.9), rng:NextNumber(-0.8, 0.8))).Unit
			shard.CFrame = CFrame.lookAt(position, position + direction)
			shard.Parent = effects
			local velocity = direction * rng:NextNumber(14, 26)
			local born = os.clock()
			local connection
			connection = RunService.Heartbeat:Connect(function(dt)
				local age = os.clock() - born
				if age > 0.28 or not shard.Parent then
					connection:Disconnect()
					shard:Destroy()
					return
				end
				velocity += Vector3.new(0, -60 * dt, 0)
				local p = shard.Position + velocity * dt
				shard.CFrame = CFrame.lookAt(p, p + velocity)
				shard.Transparency = age / 0.28
			end)
		end
		local flash = Instance.new("Part")
		flash.Anchored = true
		flash.CanCollide = false
		flash.CanQuery = false
		flash.CanTouch = false
		flash.Transparency = 1
		flash.Size = Vector3.new(0.2, 0.2, 0.2)
		flash.CFrame = CFrame.new(position)
		flash.Parent = effects
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 2.4
		light.Range = 10
		light.Shadows = false
		light.Parent = flash
		task.delay(0.07, function()
			flash:Destroy()
		end)
	end

	local function tracer(from: Vector3, to: Vector3, color: Color3)
		local length = (to - from).Magnitude
		if length < 0.5 then
			return
		end
		local beam = Instance.new("Part")
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Material = Enum.Material.Neon
		beam.Color = color:Lerp(Color3.new(1, 1, 1), 0.55)
		beam.Transparency = 0.25
		beam.Size = Vector3.new(0.07, 0.07, length)
		beam.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to)
		beam.Parent = effects
		fadePart(beam, 0.09)
	end

	local function muzzleOf(model: Model?): Vector3?
		local weapon = model and model:FindFirstChild("CyberOutlawArma")
		local attachment = weapon and weapon.PrimaryPart and weapon.PrimaryPart:FindFirstChild("Cano")
		return if attachment then attachment.WorldPosition else nil
	end

	local function muzzleFlash(position: Vector3, color: Color3, look: Vector3)
		for _, angle in { 0, 90 } do
			local blade = Instance.new("Part")
			blade.Anchored = true
			blade.CanCollide = false
			blade.CanQuery = false
			blade.CanTouch = false
			blade.CastShadow = false
			blade.Material = Enum.Material.Neon
			blade.Color = Color3.fromRGB(255, 226, 170):Lerp(color, 0.3)
			blade.Size = Vector3.new(0.08, 0.5, 0.9)
			blade.CFrame = CFrame.lookAt(position + look * 0.4, position + look) * CFrame.Angles(0, 0, math.rad(angle + rng:NextNumber(-20, 20)))
			blade.Parent = effects
			fadePart(blade, 0.05, Vector3.new(0, 0.3, 0.4))
		end
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.new(position)
		holder.Parent = effects
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Brightness = 3
		light.Range = 16
		light.Shadows = false
		light.Parent = holder
		task.delay(0.05, function()
			holder:Destroy()
		end)
	end

	local function showHit()
		combat.hit(false)
	end

	-- Weapons ------------------------------------------------------------------------------------
	local function equip(id: string)
		if not byId[id] or (dead) then
			return
		end
		if id ~= current then
			current = id
			sound("arma_troca")
			if action then
				action:FireServer("equipar", id)
			end
		end
		if byId[id].kind ~= "gun" then
			aimToggle = false
		end
	end

	local function cycle(step: number)
		local index = (byId[current] and byId[current].order) or 1
		local nextIndex = (index - 1 + step) % #defs + 1
		equip(defs[nextIndex].id)
	end

	local function reload()
		local weapon = def()
		local pair = ammoTable[weapon.id]
		if weapon.kind == "gun" and pair and pair[1] < weapon.mag and pair[2] > 0 and action then
			action:FireServer("recarregar")
			sound(pick(weapon.recarga or "arma_recarga", "arma_recarga"), nil, 0.55)
		end
	end

	local function melee()
		local weapon = def()
		local now = os.clock()
		if now < nextMelee or not character then
			return
		end
		nextMelee = now + 1 / weapon.rate
		meleeSide = -meleeSide
		poses[character] = poses[character] or {}
		poses[character].swingStart = now
		poses[character].swingKind = weapon.id
		poses[character].swingSide = meleeSide
		sound(weapon.som or "arma_soco", nil, 0.55)
		cam.trauma = math.min(1, cam.trauma + 0.08)
		if action then
			action:FireServer("golpe", meleeSide)
		end
	end

	local function shoot()
		local weapon = def()
		if weapon.kind ~= "gun" then
			melee()
			return
		end
		if not character or not head or dead then
			return
		end
		local now = os.clock()
		if now < nextShot then
			return
		end
		if root and inSafeZone(root.Position) then
			safeBlockedUntil = now + 2
			return
		end
		local pair = ammoTable[weapon.id]
		local reloadAt = player:GetAttribute("CyberOutlawRecargaAte")
		if type(reloadAt) == "number" and reloadAt > Workspace:GetServerTimeNow() then
			return
		end
		if not pair or pair[1] <= 0 then
			nextShot = now + 0.25
			sound("arma_vazia", nil, 0.5)
			reload()
			return
		end
		nextShot = now + 1 / weapon.rate
		hipFireUntil = now + 0.7
		local view = camera.CFrame
		local look = view.LookVector
		local skip = math.max(0, (head.Position - view.Position):Dot(look) - 1)
		local origin = view.Position + look * skip
		local moving = humanoid and humanoid.MoveDirection.Magnitude > 0.1
		local spread = weapon.spread * (if aiming then 1 else 1.8) * (if moving then 1.25 else 1) + bloom
		local directions = {}
		for index = 1, weapon.pellets or 1 do
			directions[index] = coneDirection(look, math.rad(spread), rng)
		end
		refreshFilter()
		local from = muzzleOf(character) or head.Position
		local accent = rgb(weapon.accent)
		for _, direction in directions do
			local result = Workspace:Raycast(origin, direction * weapon.range, rayParams)
			local point = if result then result.Position else origin + direction * weapon.range
			tracer(from, point, accent)
			if result then
				spark(point, Color3.fromRGB(255, 210, 150), 4, result.Normal)
			end
		end
		muzzleFlash(from, accent, look)
		sound(weapon.som or ("arma_" .. weapon.id), nil, 0.7)
		if weapon.acao then
			-- Bomba da escopeta e ferrolho da sniper logo depois do disparo.
			task.delay(0.34, sound, weapon.acao, nil, 0.5)
		end
		pair[1] -= 1
		-- Recoil: part of the kick stays (the climb), part returns on its own.
		local kick = math.rad(weapon.recoil or 1)
		cam.pitch += kick * 0.3
		cam.kick += kick * 0.7
		cam.kickYaw += kick * rng:NextNumber(-0.35, 0.35)
		cam.trauma = math.min(1, cam.trauma + 0.04 * (weapon.recoil or 1))
		bloom = math.min(weapon.spread * 3, bloom + weapon.recoil * 0.35)
		poses[character] = poses[character] or {}
		poses[character].firedAt = now
		if action then
			action:FireServer("atirar", origin, directions)
		end
	end

	if effectEvent then
		effectEvent.OnClientEvent:Connect(function(kind, who, id, a, b)
			if typeof(who) ~= "Instance" or not who:IsA("Player") then
				return
			end
			local model = who.Character
			local weapon = byId[id]
			if kind == "tiro" and type(b) == "table" then
				if who == player then
					for _, hit in b do
						if hit[3] then
							showHit()
							sound(pick("ui_tick", "click"), nil, 0.45)
							break
						end
					end
					return
				end
				if model then
					poses[model] = poses[model] or {}
					poses[model].firedAt = os.clock()
				end
				local from = muzzleOf(model) or a
				local accent = if weapon then rgb(weapon.accent) else TEXT
				if typeof(from) == "Vector3" then
					for _, hit in b do
						if typeof(hit[1]) == "Vector3" then
							tracer(from, hit[1], accent)
							spark(hit[1], if hit[3] then Color3.fromRGB(255, 60, 80) else Color3.fromRGB(255, 210, 150), 3, hit[2])
						end
					end
					local look = if b[1] and typeof(b[1][1]) == "Vector3" then (b[1][1] - from).Unit else Vector3.zAxis
					muzzleFlash(from, accent, look)
					local weaponModel = model and model:FindFirstChild("CyberOutlawArma")
					local emitter = weaponModel and weaponModel.PrimaryPart
					sound(if weapon and weapon.som then weapon.som else "arma_" .. tostring(id), emitter, 0.8)
					if weapon and weapon.acao and emitter then
						task.delay(0.34, sound, weapon.acao, emitter, 0.55)
					end
				end
			elseif kind == "golpe" and model and who ~= player then
				poses[model] = poses[model] or {}
				poses[model].swingStart = os.clock()
				poses[model].swingKind = id
				poses[model].swingSide = if a == -1 then -1 else 1
				if typeof(b) == "Vector3" then
					spark(b, Color3.fromRGB(255, 120, 90), 5)
				end
			elseif kind == "golpe" and who == player and typeof(b) == "Vector3" then
				showHit()
				spark(b, Color3.fromRGB(255, 120, 90), 6)
			elseif kind == "troca" and who == player and type(id) == "string" then
				current = id
			end
		end)
	end

	-- Wheel ----------------------------------------------------------------------------------------
	local function openWheel()
		if not wheel or wheelOpen or dead then
			return
		end
		wheelOpen = true
		wheel.gui.Enabled = true
		wheelSelection = (byId[current] and byId[current].order) or 1
		wheel.select(wheelSelection, ammoTable)
		sound(pick("ui_abrir", "glitch"), nil, 0.35)
	end

	local function closeWheel(equipSelected: boolean)
		if not wheelOpen then
			return
		end
		wheelOpen = false
		if equipSelected and defs[wheelSelection] then
			equip(defs[wheelSelection].id)
			sound(pick("ui_confirmar", "confirm"), nil, 0.4)
		else
			sound(pick("ui_fechar", "glitch"), nil, 0.3)
		end
	end

	if wheel then
		for index, entry in wheel.cards do
			entry.card.MouseEnter:Connect(function()
				if wheelOpen and wheelSelection ~= index then
					wheelSelection = index
					wheel.select(index, ammoTable)
					sound(pick("ui_tick", "click"), nil, 0.3)
				end
			end)
			entry.card.Activated:Connect(function()
				wheelSelection = index
				wheel.select(index, ammoTable)
				closeWheel(true)
			end)
		end
		wheel.shade.Activated:Connect(function()
			closeWheel(false)
		end)
	end
	if arsenalButton then
		arsenalButton.button.Activated:Connect(function()
			if wheelOpen then
				closeWheel(false)
			else
				openWheel()
			end
		end)
	end
	-- Barra: as setas trocam a página; uma caixa equipa a arma dela.
	for key, tap in barTaps do
		tap.Activated:Connect(function()
			if not bar then
				return
			end
			if key == "left" or key == "right" then
				bar.setPage(bar.page + (if key == "left" then -1 else 1))
				sound(pick("ui_tick", "click"), nil, 0.3)
			else
				local slot = bar.slots[key]
				if slot and slot.id and slot.box.Visible then
					equip(slot.id)
				end
			end
		end)
	end
	implantsButton.button.Activated:Connect(function()
		if toggleImplants then
			toggleImplants()
		end
	end)
	abilityButton.button.Activated:Connect(function()
		if useAbility then
			useAbility()
		end
	end)

	-- Input ----------------------------------------------------------------------------------------
	local function typing()
		return UserInputService:GetFocusedTextBox() ~= nil
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			if not processed and not wheelOpen and input.Position.X > camera.ViewportSize.X * 0.35 then
				touchCamera[input] = input.Position
			end
			return
		end
		if processed or typing() then
			return
		end
		local key = input.KeyCode
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if not wheelOpen then
				triggerHeld = true
				shoot()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			aiming = def().kind == "gun"
		elseif key == Enum.KeyCode.LeftShift then
			sprintHeld = true
		elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.ButtonL1 then
			openWheel()
		elseif key == Enum.KeyCode.R or key == Enum.KeyCode.ButtonX then
			reload()
		elseif key == Enum.KeyCode.G or key == Enum.KeyCode.ButtonY then
			equip("punhos")
		elseif key == Enum.KeyCode.V then
			cam.side = -cam.side
		elseif key == Enum.KeyCode.ButtonR2 then
			triggerHeld = true
			shoot()
		elseif key == Enum.KeyCode.ButtonL2 then
			aiming = def().kind == "gun"
		elseif key == Enum.KeyCode.ButtonL3 then
			sprintToggle = not sprintToggle
		elseif key == Enum.KeyCode.DPadRight then
			cycle(1)
		elseif key == Enum.KeyCode.DPadLeft then
			cycle(-1)
		else
			local numbers = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
				Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }
			local index = table.find(numbers, key)
			if index and defs[index] then
				equip(defs[index].id)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchCamera[input] = nil
			return
		end
		local key = input.KeyCode
		if input.UserInputType == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.ButtonR2 then
			triggerHeld = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 or key == Enum.KeyCode.ButtonL2 then
			aiming = false
		elseif key == Enum.KeyCode.LeftShift then
			sprintHeld = false
		elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.ButtonL1 then
			closeWheel(true)
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if wheelOpen and wheel then
				local mouse = UserInputService:GetMouseLocation()
				local size = camera.ViewportSize
				local offset = mouse - size / 2
				if offset.Magnitude > 40 then
					local index = slotFromVector(offset.X, offset.Y, #defs)
					if index and index ~= wheelSelection then
						wheelSelection = index
						wheel.select(index, ammoTable)
						sound(pick("ui_tick", "click"), nil, 0.3)
					end
				end
			elseif not processed and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
				local factor = 0.0042 * sensitivity * (if aiming then 0.62 else 1)
				cam.yaw -= input.Delta.X * factor
				cam.pitch -= input.Delta.Y * factor
				cam.lastInput = os.clock()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed and not wheelOpen then
			cycle(if input.Position.Z > 0 then -1 else 1)
		elseif input.UserInputType == Enum.UserInputType.Touch and touchCamera[input] then
			local previous = touchCamera[input]
			local delta = input.Position - previous
			touchCamera[input] = input.Position
			local factor = 0.0065 * (if aiming then 0.6 else 1)
			cam.yaw -= delta.X * factor
			cam.pitch -= delta.Y * factor
			cam.lastInput = os.clock()
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stick = Vector2.new(input.Position.X, input.Position.Y)
			if wheelOpen and stick.Magnitude > 0.5 then
				local index = slotFromVector(stick.X, -stick.Y, #defs)
				if index and index ~= wheelSelection then
					wheelSelection = index
					wheel.select(index, ammoTable)
				end
			end
		end
	end)
	if touch and fireButton then
		fireButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				triggerHeld = true
				shoot()
			end
		end)
		fireButton.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				triggerHeld = false
			end
		end)
		aimButton.Activated:Connect(function()
			aimToggle = not aimToggle and def().kind == "gun"
		end)
		reloadButton.Activated:Connect(reload)
	end

	-- Frame loop ---------------------------------------------------------------------------------
	local playTime = 0
	local function cameraStep(dt: number)
		if not character or not root or not root.Parent then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		local weapon = def()
		local alive = humanoid and humanoid.Health > 0
		local gun = weapon.kind == "gun"
		local aimingNow = alive and gun and (aiming or aimToggle)
		local raised = alive and gun and (aimingNow or os.clock() < hipFireUntil)
		local moving = humanoid and humanoid.MoveDirection.Magnitude > 0.1

		-- Gamepad: right stick turns the camera.
		if stick.Magnitude > 0.15 and not wheelOpen then
			local curve = stick * stick.Magnitude
			local rate = if aimingNow then 1.4 else 2.7
			cam.yaw -= curve.X * rate * dt
			cam.pitch += curve.Y * rate * 0.75 * dt
			cam.lastInput = os.clock()
		end
		-- Automatic follow: with no camera input, the camera slowly returns behind the character.
		if alive and not aimingNow and moving and os.clock() - cam.lastInput > 1.6 then
			local look = root.CFrame.LookVector
			local target = math.atan2(-look.X, -look.Z)
			local pull = math.clamp(root.AssemblyLinearVelocity.Magnitude / 26, 0, 1) * 1.1 * dt
			cam.yaw += angleDelta(cam.yaw, target) * pull
			cam.pitch += (math.rad(-10) - cam.pitch) * pull * 0.6
		end
		if not alive then
			cam.deathSpin += dt * 0.22
			cam.yaw += dt * 0.22
			cam.pitch += (math.rad(-28) - cam.pitch) * math.min(1, dt * 2)
		end
		cam.pitch = math.clamp(cam.pitch, math.rad(-72), math.rad(62))

		local scoped = aimingNow and weapon.luneta == true
		local targetDistance = if not alive then 16
			elseif scoped then 0.5
			elseif aimingNow then (if weapon.tipo == "fuzil" then 4.6 else 5.6)
			elseif sprinting then 13
			else 11.5
		local targetShoulder = (if aimingNow or raised then 2.1 else 1.35) * cam.side
		local targetFov = if aimingNow then (weapon.fov or 54) elseif sprinting then 77 else 70
		if wheelOpen then
			targetFov -= 6
		end
		cam.shoulder, cam.shoulderVel = spring(cam.shoulder, cam.shoulderVel, targetShoulder, 3.2, dt)
		cam.fov, cam.fovVel = spring(cam.fov, cam.fovVel, targetFov, 2.6, dt)

		-- Focus with lag: horizontal faster than vertical (jumps and stairs don't jerk).
		local anchor = root.Position + Vector3.new(0, 1.6, 0)
		if not cam.focus then
			cam.focus = Vector3.new(anchor.X, 0, anchor.Z)
			cam.height = anchor.Y
		end
		local flat = Vector3.new(anchor.X, 0, anchor.Z)
		cam.focus, cam.focusVel = spring(cam.focus, cam.focusVel, flat, if aimingNow then 9 else 6, dt)
		cam.height, cam.heightVel = spring(cam.height, cam.heightVel, anchor.Y, 3.4, dt)
		if (cam.focus - flat).Magnitude > 30 then
			cam.focus, cam.focusVel = flat, Vector3.zero
		end
		local focus = Vector3.new(cam.focus.X, cam.height, cam.focus.Z)

		-- Recoil that returns, plus shake with intensity (trauma).
		cam.kick *= math.exp(-dt * 9)
		cam.kickYaw *= math.exp(-dt * 9)
		cam.trauma = math.max(0, cam.trauma - dt * 1.6)
		bloom = math.max(0, bloom - dt * 3)
		playTime += dt
		local shake = cam.trauma * cam.trauma
		local shakePitch = shake * math.rad(2.2) * math.noise(playTime * 22, 0.3)
		local shakeYaw = shake * math.rad(2.2) * math.noise(playTime * 22, 7.1)
		local bob = if sprinting and moving then math.sin(playTime * 11) * 0.06 else 0

		local rotation = CFrame.Angles(0, cam.yaw + cam.kickYaw + shakeYaw, 0) * CFrame.Angles(cam.pitch + cam.kick + shakePitch, 0, 0)
		refreshFilter()
		local sideOffset = rotation.RightVector * cam.shoulder + Vector3.new(0, 0.55 + bob, 0)
		local pivot = focus + sideOffset
		local sideHit = Workspace:Spherecast(focus, 0.4, sideOffset, rayParams)
		if sideHit then
			pivot = focus + sideOffset.Unit * math.max(0, sideHit.Distance - 0.1)
		end
		local back = -rotation.LookVector * targetDistance
		local hit = Workspace:Spherecast(pivot, 0.45, back, rayParams)
		local allowed = if hit then math.max(1.1, hit.Distance - 0.12) else targetDistance
		if allowed < cam.distance then
			cam.distance, cam.distanceVel = allowed, 0
		else
			cam.distance, cam.distanceVel = spring(cam.distance, cam.distanceVel, allowed, 2.2, dt)
		end
		camera.FieldOfView = cam.fov
		camera.CFrame = CFrame.new(pivot - rotation.LookVector * cam.distance) * rotation
		camera.Focus = CFrame.new(focus)

		-- Body almost transparent when the camera gets inside it (and hidden behind the scope).
		local fade = if scoped and cam.distance < 1.2 then 1 elseif cam.distance < 2.2 then 0.7 else 0
		combat.scope(scoped and cam.distance < 1.6)
		for _, item in character:GetDescendants() do
			if item:IsA("BasePart") or item:IsA("Decal") then
				item.LocalTransparencyModifier = fade
			end
		end

		-- Ao mirar, a câmera foca no alvo: o ombro e o que está perto nas laterais ficam desfocados.
		aimBlur += ((if aimingNow then 1 else 0) - aimBlur) * math.min(1, dt * 9)
		depth.Enabled = aimBlur > 0.02 and quality >= 3
		if depth.Enabled then
			local result = Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 400, rayParams)
			local focus = if result then result.Distance else 200
			depth.FocusDistance = focus
			depth.InFocusRadius = math.clamp(focus * 0.35, 8, 60)
			depth.NearIntensity = 0.75 * aimBlur
			depth.FarIntensity = 0.2 * aimBlur
		end
		return aimingNow, raised
	end

	local function movementStep(dt: number, aimingNow: boolean, raised: boolean)
		if not humanoid or not root or not align then
			return
		end
		local alive = humanoid.Health > 0
		local seated = humanoid.SeatPart ~= nil
		align.Enabled = alive and not seated
		humanoid.AutoRotate = seated
		local moveDirection = humanoid.MoveDirection
		local moving = moveDirection.Magnitude > 0.1
		-- Mobile: stick pushed all the way for a moment = sprint.
		local analog = 0
		if controls then
			local ok, vector = pcall(function()
				return controls:GetMoveVector()
			end)
			if ok and typeof(vector) == "Vector3" then
				analog = vector.Magnitude
			end
		end
		if touch and analog > 0.92 then
			pushTime += dt
		else
			pushTime = 0
		end
		if not moving then
			sprintToggle = false
		end
		local wants = sprintHeld or sprintToggle or pushTime > 0.3
		sprinting = alive and moving and wants and not stamina.exhausted and not raised
		staminaStep(stamina, sprinting, dt)
		player:SetAttribute("CyberOutlawFolego", stamina.value)
		player:SetAttribute("CyberOutlawExausto", stamina.exhausted)
		local target = if raised then 11 elseif sprinting then 27 else 17
		speed += (target - speed) * math.min(1, dt * 6)
		humanoid.WalkSpeed = speed
		-- Facing: when aiming, the body follows the camera; otherwise it turns smoothly toward the movement.
		if raised then
			facingYaw = cam.yaw
			align.Responsiveness = 45
		elseif moving then
			facingYaw = math.atan2(-moveDirection.X, -moveDirection.Z)
			align.Responsiveness = if sprinting then 11 else 16
		end
		align.CFrame = CFrame.Angles(0, facingYaw, 0)
	end

	-- Arm and head pose (PreSimulation: after the animation, before the physics).
	local SWING = { punhos = 0.26, faca = 0.38 }
	local function poseCharacter(model: Model, now: number)
		local body = model:FindFirstChild("Torso")
		if not body then
			return
		end
		local right = body:FindFirstChild("Right Shoulder")
		local left = body:FindFirstChild("Left Shoulder")
		if not right or not left then
			return
		end
		local id = model:GetAttribute("CyberOutlawArma")
		local weapon = byId[id]
		local state = poses[model]
		local isLocal = model == character
		local pitch = if isLocal then cam.pitch else math.rad(model:GetAttribute("CyberOutlawPitch") or 0)
		local aimed = if isLocal then (aiming or aimToggle) else model:GetAttribute("CyberOutlawMirando") == true
		local firedRecently = state and state.firedAt and now - state.firedAt < 0.7
		if state and state.swingStart then
			local duration = SWING[state.swingKind] or 0.3
			local t = (now - state.swingStart) / duration
			if t < 1 then
				local arm = if state.swingSide == -1 and state.swingKind == "punhos" then left else right
				local side = if arm == left then -1 else 1
				local direction = swingDirection(state.swingKind, side, t)
				arm.Transform = jointTransform(arm.C0, arm.C1, armRotation(direction, Vector3.new(0, 1, 0)))
				return
			end
			state.swingStart = nil
		end
		if not weapon or weapon.kind ~= "gun" then
			if weapon and weapon.id == "faca" then
				right.Transform = jointTransform(right.C0, right.C1, armRotation(Vector3.new(0.12, -0.72, -0.68), Vector3.new(0, 1, 0)))
			end
			return
		end
		local up = Vector3.new(0, 1, 0)
		local direction
		if aimed or firedRecently then
			direction = Vector3.new(0, math.sin(pitch), -math.cos(pitch))
		else
			direction = Vector3.new(0.05, -0.55, -0.83).Unit
		end
		right.Transform = jointTransform(right.C0, right.C1, armRotation(direction, up))
		if weapon.kind == "gun" then
			local shoulderRight = right.C0.Position
			local shoulderLeft = left.C0.Position
			local reach = weapon.alcance or 2.45
			local hand = shoulderRight + Vector3.new(0.5, 0, 0) + direction * reach
			local support = hand + Vector3.new(-0.35, -0.12, 0)
			left.Transform = jointTransform(left.C0, left.C1, armRotation((support - shoulderLeft).Unit, up))
		end
	end

	local function headStep(dt: number)
		if not joints.neck or not torso or not humanoid or humanoid.Health <= 0 then
			return
		end
		local look = torso.CFrame:VectorToObjectSpace(camera.CFrame.LookVector)
		local yaw = math.clamp(math.atan2(-look.X, -look.Z), math.rad(-65), math.rad(65))
		local pitch = math.clamp(math.asin(math.clamp(look.Y, -1, 1)), math.rad(-35), math.rad(35))
		local direction = Vector3.new(-math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
		local rotation = CFrame.lookAt(Vector3.zero, direction)
		local gait = character and gaits[character]
		local compensation = if gait and gait.pose then gait.pose.headCompensation else CFrame.identity
		joints.neck.Transform = jointTransform(joints.neck.C0, joints.neck.C1, compensation * rotation)
		local _ = dt
	end

	local STATES = {
		[Enum.HumanoidStateType.Freefall] = "fall", [Enum.HumanoidStateType.Jumping] = "jump",
		[Enum.HumanoidStateType.Climbing] = "climb", [Enum.HumanoidStateType.Swimming] = "swim",
		[Enum.HumanoidStateType.Seated] = "seated", [Enum.HumanoidStateType.Dead] = "dead",
		[Enum.HumanoidStateType.Physics] = "seated", [Enum.HumanoidStateType.PlatformStanding] = "seated",
	}
	local UP = Vector3.new(0, 1, 0)
	local function blend(joint: Motor6D?, target: CFrame, weight: number)
		if joint then
			joint.Transform = if weight >= 0.999 then target else joint.Transform:Lerp(target, weight)
		end
	end
	-- Passos: som no pé que tocou o chão (os sons de passo chegam com a mídia aprovada).
	local stepSounds = {}
	for k = 1, 4 do
		if type(SOUNDS["passo_" .. k]) == "number" then
			table.insert(stepSounds, "passo_" .. k)
		end
	end
	local function footstep(model: Model, foot: number)
		if #stepSounds == 0 then
			return
		end
		local leg = model:FindFirstChild(if foot == 1 then "Right Leg" else "Left Leg")
		if leg and leg:IsA("BasePart") then
			sound(stepSounds[rng:NextInteger(1, #stepSounds)], leg, if model == character then 0.32 else 0.22)
		end
	end
	-- Esqueletos R15 invisíveis (só neste cliente) tocando o pacote do catálogo. Um por personagem perto
	-- da câmera; o resto usa a locomoção procedural. Se o pacote não carregar, volta para a procedural.
	local proxyFolder = Instance.new("Folder")
	proxyFolder.Name = "CyberOutlawEsqueletos"
	proxyFolder.Parent = camera
	local proxies: { [Model]: any } = {}
	local PROXY_RANGE = 120
	local function animationFolder()
		return ReplicatedStorage:FindFirstChild("CyberOutlawAnimacoes")
	end
	local function packIds(name: string)
		local builtIn = ANIMATION_PACKS[name]
		if builtIn then
			return builtIn
		end
		local folder = animationFolder()
		local raw = folder and folder:GetAttribute(name)
		if type(raw) == "string" then
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
			if ok and type(decoded) == "table" and decoded.walk and decoded.run then
				return decoded
			end
		end
		return nil
	end
	local function currentPack(): string
		local folder = animationFolder()
		local name = folder and folder:GetAttribute("Pacote")
		if type(name) == "string" and packIds(name) then
			return name
		end
		return "realista"
	end
	local function buildProxy()
		local model = Instance.new("Model")
		model.Name = "EsqueletoR15"
		local parts = {}
		for name, size in R15_SIZES do
			local part = Instance.new("Part")
			part.Name = name
			part.Size = size
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.CFrame = CFrame.new(0, -60, 0)
			part.Parent = model
			parts[name] = part
		end
		local joints = {}
		for _, joint in R15_JOINTS do
			local motor = Instance.new("Motor6D")
			motor.Name = joint[1]
			motor.Part0 = parts[joint[2]]
			motor.Part1 = parts[joint[3]]
			motor.C0 = CFrame.new(joint[4])
			motor.C1 = CFrame.new(joint[5])
			motor.Parent = parts[joint[3]]
			joints[joint[1]] = motor
		end
		model.PrimaryPart = parts.HumanoidRootPart
		local controller = Instance.new("AnimationController")
		controller.Parent = model
		local animator = Instance.new("Animator")
		animator.Parent = controller
		model.Parent = proxyFolder
		return {
			model = model, animator = animator, joints = joints, tracks = {}, pack = nil, born = os.clock(),
			lastState = "run", jumpAt = 0, strafe = 0, feetDown = { true, true }, alive = 0,
		}
	end
	local function loadTracks(proxy, name: string)
		for _, track in proxy.tracks do
			track:Stop(0)
			track:Destroy()
		end
		proxy.tracks = {}
		proxy.pack = name
		proxy.born = os.clock()
		proxy.alive = 0
		local ids = packIds(name)
		if not ids then
			return
		end
		local function load(key: string, id, looped: boolean)
			if type(id) == "table" then
				id = id[1]
			end
			if type(id) ~= "number" and type(id) ~= "string" then
				return
			end
			local animation = Instance.new("Animation")
			animation.AnimationId = if type(id) == "number" then string.format("rbxassetid://%.0f", id) else id
			local ok, track = pcall(proxy.animator.LoadAnimation, proxy.animator, animation)
			if ok and track then
				track.Looped = looped
				track.Priority = Enum.AnimationPriority.Core
				proxy.tracks[key] = track
				if looped then
					track:Play(0, 0.0001, 1)
				end
			end
		end
		load("idle", ids.idle, true)
		for _, key in { "walk", "run", "fall", "climb", "swim", "swimidle" } do
			load(key, ids[key], true)
		end
		load("jump", ids.jump, false)
	end
	local function dropProxy(model: Model)
		local proxy = proxies[model]
		if proxy then
			proxy.model:Destroy()
			proxies[model] = nil
		end
	end
	local IDENTITY = CFrame.identity
	-- Toca o pacote no esqueleto do personagem e devolve a pose convertida para o R6 (ou nil).
	local function catalogPose(model: Model, rootPart: BasePart, state: string, dt: number)
		local proxy = proxies[model]
		if proxy and proxy.failed then
			return nil
		end
		if not proxy then
			proxy = buildProxy()
			proxies[model] = proxy
		end
		local pack = currentPack()
		if proxy.pack ~= pack then
			loadTracks(proxy, pack)
		end
		local velocity = rootPart.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local speed = flat.Magnitude
		local jump = proxy.tracks.jump
		if state == "jump" and proxy.lastState ~= "jump" and jump then
			jump:Play(0.08, 1, 1)
			proxy.jumpAt = os.clock()
		end
		proxy.lastState = state
		local weights, rates = locomotionWeights(state, speed, velocity.Y)
		if jump and os.clock() - proxy.jumpAt < 0.32 then
			weights.fall = 0
		end
		for key, track in proxy.tracks do
			if key ~= "jump" then
				track:AdjustWeight(math.max(weights[key] or 0, 0.0001), 0.18)
				track:AdjustSpeed(rates[key] or 1)
			end
		end
		local transforms, moved = {}, false
		for name, motor in proxy.joints do
			local t = motor.Transform
			transforms[name] = t
			if not moved and (t.Position.Magnitude > 1e-4 or t.LookVector:Dot(IDENTITY.LookVector) < 0.9999
				or t.UpVector:Dot(IDENTITY.UpVector) < 0.9999) then
				moved = true
			end
		end
		if moved then
			proxy.alive = os.clock()
		elseif os.clock() - proxy.born > 6 and proxy.alive == 0 then
			-- O pacote não tocou (ID recusado ou sem permissão): usa a locomoção procedural.
			proxy.failed = true
			return nil
		end
		if not moved then
			return nil
		end
		-- Mirando e andando de lado ou de costas: o passo segue a direção do movimento.
		local target = 0
		if speed > 1.5 then
			local localVelocity = rootPart.CFrame:VectorToObjectSpace(flat)
			target = math.atan2(-localVelocity.X, -localVelocity.Z)
		end
		proxy.strafe += angleDelta(proxy.strafe, target) * math.min(1, dt * 10)
		local pose = retargetPose(transforms, proxy.strafe)
		if state == "seated" or state == "dead" then
			pose.weight = 0
		end
		-- Passos: o pé desce até o chão do esqueleto e volta a subir.
		pose.step = 0
		if speed > 2 and state == "run" then
			for index = 1, 2 do
				local height = pose.feet[index] - REST_FEET
				if not proxy.feetDown[index] and height < 0.1 then
					proxy.feetDown[index] = true
					pose.step = index
				elseif proxy.feetDown[index] and height > 0.28 then
					proxy.feetDown[index] = false
				end
			end
		end
		return pose
	end
	Players.PlayerRemoving:Connect(function(other)
		if other.Character then
			dropProxy(other.Character)
		end
	end)

	local function gaitCharacter(model: Model, dt: number)
		local body = model:FindFirstChild("Torso")
		local rootPart = model:FindFirstChild("HumanoidRootPart")
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not body or not rootPart or not hum then
			return
		end
		local distance = (rootPart.Position - camera.CFrame.Position).Magnitude
		if distance > 180 then
			dropProxy(model)
			return
		end
		local g = gaits[model]
		if not g then
			g = newGait()
			gaits[model] = g
		end
		local velocity = rootPart.AssemblyLinearVelocity
		local state = STATES[hum:GetState()] or (if hum.Health <= 0 then "dead" else "run")
		local pose
		if distance <= PROXY_RANGE then
			local ok, result = pcall(catalogPose, model, rootPart, state, dt)
			pose = if ok then result else nil
		else
			dropProxy(model)
		end
		if not pose then
			pose = gaitStep(g, {
				velocity = rootPart.CFrame:VectorToObjectSpace(velocity), state = state,
				yawRate = rootPart.AssemblyAngularVelocity.Y, verticalSpeed = velocity.Y,
			}, dt)
		end
		g.pose = pose
		local w = pose.weight
		if w < 0.01 then
			return
		end
		local rootJoint = rootPart:FindFirstChild("RootJoint")
		if rootJoint then
			blend(rootJoint, rootTransform(rootJoint.C0, pose.root), w)
		end
		local rightHip, leftHip = body:FindFirstChild("Right Hip"), body:FindFirstChild("Left Hip")
		local rightShoulder, leftShoulder = body:FindFirstChild("Right Shoulder"), body:FindFirstChild("Left Shoulder")
		if rightHip then
			blend(rightHip, jointTransform(rightHip.C0, rightHip.C1, armRotation(pose.rightLeg, pose.rightLegUp or UP)), w)
		end
		if leftHip then
			blend(leftHip, jointTransform(leftHip.C0, leftHip.C1, armRotation(pose.leftLeg, pose.leftLegUp or UP)), w)
		end
		if rightShoulder then
			blend(rightShoulder, jointTransform(rightShoulder.C0, rightShoulder.C1, armRotation(pose.rightArm, pose.rightArmUp or UP)), w)
		end
		if leftShoulder then
			blend(leftShoulder, jointTransform(leftShoulder.C0, leftShoulder.C1, armRotation(pose.leftArm, pose.leftArmUp or UP)), w)
		end
		if model ~= character then
			local neck = body:FindFirstChild("Neck")
			if neck then
				local pitch = if model:GetAttribute("CyberOutlawMirando") then math.rad(model:GetAttribute("CyberOutlawPitch") or 0) else 0
				local look = CFrame.lookAt(Vector3.zero, Vector3.new(0, math.sin(pitch), -math.cos(pitch)))
				blend(neck, jointTransform(neck.C0, neck.C1, pose.headCompensation * look), w)
			end
		end
		if pose.step ~= 0 and (rootPart.Position - camera.CFrame.Position).Magnitude < 70 then
			footstep(model, pose.step)
		end
	end

	local function onPreSimulation(dt: number)
		local now = os.clock()
		for _, other in Players:GetPlayers() do
			local model = other.Character
			if model then
				pcall(gaitCharacter, model, dt)
				local ok = pcall(poseCharacter, model, now)
				local _ = ok
			end
		end
		pcall(headStep, dt)
	end
	local preSimulation = if (RunService :: any).PreSimulation then (RunService :: any).PreSimulation else RunService.Stepped
	preSimulation:Connect(function(a, b)
		onPreSimulation(if type(b) == "number" then b else a)
	end)

	local function interfaceStep(dt: number, aimingNow: boolean, raised: boolean)
		local weapon = def()
		local reloadAt = player:GetAttribute("CyberOutlawRecargaAte")
		local reloading = type(reloadAt) == "number" and reloadAt > Workspace:GetServerTimeNow()
		if bar then
			local progress = nil
			if reloading then
				progress = 1 - (reloadAt - Workspace:GetServerTimeNow()) / (weapon.reload or 1)
			end
			-- A página segue a arma equipada (pela roleta, teclas ou barra); as setas só olham as outras.
			if barShows ~= weapon.id then
				barShows = weapon.id
				bar.setPage(bar.pageOf(weapon.id))
			end
			bar.set(weapon, ammoTable[weapon.id], progress)
		end
		-- HUD: vida, fôlego, minimapa, distrito e hora.
		local position = if root then root.Position else nil
		local clockTime = 0
		pcall(function()
			clockTime = game:GetService("Lighting").ClockTime
		end)
		local minutes = math.floor((clockTime % 24) * 60 + 0.5) % (24 * 60)
		hud.update({
			health = if humanoid then humanoid.Health else 0,
			maxHealth = if humanoid then humanoid.MaxHealth else 100,
			stamina = stamina.value,
			exhausted = stamina.exhausted,
			position = position,
			cameraYaw = cam.yaw,
			facingYaw = facingYaw,
			district = if position then districtOf(position) else nil,
			clock = string.format("%02d:%02d", minutes // 60, minutes % 60),
			safe = (position ~= nil and inSafeZone(position) and weapon.kind == "gun") or os.clock() < safeBlockedUntil,
		}, dt)
		hud.gui.Enabled = not dead
		-- Mira: só com arma de fogo, ao mirar ou logo depois de um tiro; no celular, sempre que armado.
		local showCross = not dead and not wheelOpen and weapon.kind == "gun" and (aimingNow or raised or touch)
		combat.crosshair(showCross, bloom + (if aimingNow then 0 else 0.6))
		if touch and fireButton then
			-- O botão de ação mostra a arma atual (punho, lâmina ou a arma de fogo).
			if fireShows ~= weapon.id then
				fireShows = weapon.id
				local offset, size = iconRect(weapon.id)
				if fireIcon and offset then
					fireIcon.ImageRectOffset, fireIcon.ImageRectSize = offset, size
				elseif not fireIcon then
					frameGlyph(fireButton, if weapon.kind == "gun" then "tiro" else "golpe", 21, TEXT)
				end
			end
			aimButton.Visible = weapon.kind == "gun"
			reloadButton.Visible = weapon.kind == "gun"
			aimRing.Color = if aimToggle then ACCENT else LINE
			aimRing.Transparency = if aimToggle then 0.1 else 0.68
		end
		-- Bordas: escurecem ao mirar; ficam vermelhas com dano e pulsam com pouca vida.
		local health = if humanoid then humanoid.Health / math.max(1, humanoid.MaxHealth) else 1
		damageFlash = math.max(0, damageFlash - dt * 1.8)
		local low = if health < 0.3 and health > 0 then 0.25 + 0.2 * math.sin(os.clock() * 5) else 0
		combat.step(dt, if aimingNow and weapon.kind == "gun" and not dead then 1 else 0, math.max(damageFlash, low))
		-- Roleta: abre com suavidade, desfoca e tira a cor do fundo.
		wheelOpenAmount = math.clamp(wheelOpenAmount + (if wheelOpen then dt * 7 else -dt * 9), 0, 1)
		if wheel then
			local eased = 1 - (1 - wheelOpenAmount) ^ 3
			wheel.gui.Enabled = wheelOpenAmount > 0.01
			if wheel.gui.Enabled then
				wheel.animate(dt, eased)
			end
			blur.Size = 18 * eased
			grade.Saturation = -0.35 * eased
			grade.Brightness = -0.05 * eased
		end
	end

	local function pitchStep()
		local weapon = def()
		local now = os.clock()
		if weapon.kind ~= "gun" or not aimEvent or now - pitchSentAt < 0.1 then
			return
		end
		local pitch = math.deg(cam.pitch)
		if math.abs(pitch - lastPitchSent) >= 2 then
			pitchSentAt = now
			lastPitchSent = pitch
			aimEvent:FireServer(pitch)
		end
	end

	-- Placas neon 3D: a barra de armas e o minimapa saem da tela 2D e flutuam na frente da câmera, no mesmo
	-- retângulo do layout (as âncoras 2D continuam marcando o lugar e recebem o toque).
	local mapPart, mapGui = holoSurface("CyberOutlawMapaNeon", hud.canvas)
	mapGui.Brightness = 1.5
	mapGui.Parent = playerGui
	hud.parts.block.Parent = mapGui
	hud.parts.block.Position = UDim2.fromOffset(0, 0)
	local holo = { sway = 0, swayVel = 0, yaw = nil }
	-- Coloca a placa onde a âncora está na tela, a "depth" studs à frente, virada para a câmera como um painel
	-- curvo de cabine (as dos lados giram para o centro) e com o balanço da mola. O giro é em volta da borda de
	-- fora (HOLO_PIVOT): ela fica parada na área segura e a borda de dentro recua, então a placa nunca cresce
	-- para fora do retângulo do layout.
	local function holoPlace(part: BasePart, anchor: GuiObject, depth: number)
		local size, at = anchor.AbsoluteSize, anchor.AbsolutePosition
		local view = camera.ViewportSize
		local cx, cy = at.X + size.X / 2, at.Y + size.Y / 2
		local nx = math.clamp((cx - view.X / 2) / math.max(1, view.X / 2), -1, 1)
		local ny = math.clamp((cy - view.Y / 2) / math.max(1, view.Y / 2), -1, 1)
		local fx, fy, pitch, yaw = holoTilt(nx, ny)
		local ray = camera:ScreenPointToRay(cx + fx * size.X / 2, cy + fy * size.Y / 2, 1)
		local along = math.max(0.2, ray.Direction:Dot(camera.CFrame.LookVector))
		local pivot = camera.CFrame.Position + ray.Direction * (depth / along)
		local perPixel = 2 * depth * math.tan(math.rad(camera.FieldOfView) / 2) / math.max(1, view.Y)
		local w, h = math.max(0.05, size.X * perPixel), math.max(0.05, size.Y * perPixel)
		part.Size = Vector3.new(w, h, 0.02)
		-- Na placa, x cresce para a direita e y para cima (na tela, y cresce para baixo).
		part.CFrame = CFrame.new(pivot) * camera.CFrame.Rotation
			* CFrame.Angles(pitch, yaw + holo.sway, math.rad(1.2) * math.sin(os.clock() * 0.8 + nx))
			* CFrame.new(-fx * w / 2, fy * h / 2, 0)
	end
	local function holoStep(dt: number)
		local hidden = dead or wheelOpen or implantsOpen or not hud.gui.Enabled
		local look = camera.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		local turn = if holo.yaw then angleDelta(holo.yaw, yaw) else 0
		holo.yaw = yaw
		holo.sway, holo.swayVel = spring(holo.sway, holo.swayVel, math.clamp(-turn / math.max(dt, 1e-3) * 0.02, -0.12, 0.12), 2.2, dt)
		local showMap = not hidden and hud.parts.anchor.AbsoluteSize.X > 2
		mapPart.Parent = if showMap then camera else nil
		if showMap then
			holoPlace(mapPart, hud.parts.anchor, 4)
		end
		local showBar = bar ~= nil and not hidden and barAnchor.AbsoluteSize.X > 2
		barAnchor.Visible = showBar
		if bar then
			bar.part.Parent = if showBar then camera else nil
			if showBar then
				holoPlace(bar.part, barAnchor, 4)
			end
		end
	end

	local lastAimSent = false
	RunService:BindToRenderStep("CyberOutlawCamera", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local ok, aimingNow, raised = pcall(cameraStep, dt)
		if not ok then
			warn("CyberOutlaw | Câmera: " .. tostring(aimingNow))
			aimingNow, raised = false, false
		end
		aimingNow, raised = aimingNow == true, raised == true
		if aimingNow ~= lastAimSent and action then
			lastAimSent = aimingNow
			action:FireServer("mirar", aimingNow)
		end
		local moved, problem = pcall(movementStep, dt, aimingNow, raised)
		if not moved then
			warn("CyberOutlaw | Movimento: " .. tostring(problem))
		end
		pcall(interfaceStep, dt, aimingNow, raised)
		pcall(holoStep, dt)
		pcall(reflectionStep, dt)
		pcall(reflectCharacters)
		pcall(pitchStep)
		-- Automatic fire while the trigger is held.
		if triggerHeld and def().auto and not wheelOpen then
			shoot()
		end
		-- Mouse locked while playing (like third-person shooters), free in the wheel and menus.
		if not touch then
			local free = wheelOpen or GuiService.MenuIsOpen or UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
			UserInputService.MouseBehavior = if free then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = free
		end
	end)

	local function onCharacter(model: Model)
		dead = false
		combat.death(false)
		deathGrade.Enabled = false
		current = "punhos"
		aiming, aimToggle, triggerHeld = false, false, false
		stamina.value, stamina.exhausted = 1, false
		cam.focus = nil
		cam.trauma = 0
		bindCharacter(model)
		if humanoid then
			local lastHealth = humanoid.Health
			humanoid.HealthChanged:Connect(function(health)
				if health < lastHealth - 0.5 then
					damageFlash = math.min(0.85, damageFlash + (lastHealth - health) / 40)
					cam.trauma = math.min(1, cam.trauma + 0.18)
				end
				lastHealth = health
			end)
			humanoid.StateChanged:Connect(function(_, state)
				if state == Enum.HumanoidStateType.Landed and root then
					local fall = math.abs(root.AssemblyLinearVelocity.Y)
					cam.trauma = math.min(1, cam.trauma + math.clamp((fall - 30) / 90, 0, 0.45))
				end
			end)
			humanoid.Died:Connect(function()
				dead = true
				wheelOpen = false
				combat.death(true, "SINAL PERDIDO", "RECONECTANDO AO CORPO…")
				deathGrade.Enabled = true
			end)
		end
		model:GetAttributeChangedSignal("CyberOutlawArma"):Connect(function()
			local id = model:GetAttribute("CyberOutlawArma")
			if type(id) == "string" and byId[id] then
				current = id
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
	local look = camera.CFrame.LookVector
	cam.yaw = math.atan2(-look.X, -look.Z)
end

if typeof(game) == "Instance" then
	task.spawn(start)
end

return M
