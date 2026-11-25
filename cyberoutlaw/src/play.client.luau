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

-- Biblioteca licenciada do Roblox: sons profissionais (equipe de som do Roblox e ProSoundEffects) que o
-- Roblox deixa públicos para qualquer jogo, sem envio e sem chave. Medidos com tools/library_sounds.py:
-- vol iguala o volume percebido (pelo RMS dos 50 ms mais altos), region corta a cauda longa das gravações
-- de tiro (um disparo por gravação, com eco de área aberta) e speed ajusta o tom. Se um ID não carregar,
-- o jogo toca o som próprio enviado pelo midia (mesma chave).
local LIBRARY = {
	ui_tick = { id = 17208339919, vol = 1 }, -- Roblox GUI - Hover 01
	ui_abrir = { id = 17208405682, vol = 0.9 }, -- Roblox GUI - Swipe
	ui_fechar = { id = 17208186900, vol = 0.8 }, -- Roblox GUI - Back
	ui_confirmar = { id = 17208396156, vol = 0.6 }, -- Roblox GUI - Select
	ui_negado = { id = 17208353912, vol = 0.5 }, -- Roblox GUI - Negative
	acerto = { id = 9113520887, vol = 1.1, jitter = 0.05 }, -- PSE Body Hit, Chin Hit, With Rubber Glove
	acerto_cabeca = { id = 9119072899, vol = 1 }, -- PSE Shield Impacts, Punches
	tempo_estrondo = { id = 9125484367, vol = 0.9 }, -- PSE Deep Hit, Big Reverberant Boom
	tempo_pulso = { id = 9119855716, vol = 0.55 }, -- PSE Synth Whomp, Boomy, Pulsing
	tempo_volta = { id = 9125626856, vol = 0.55, region = { 0, 2.25 } }, -- PSE Light Cone Suck, Reverse Cymbal Build
	surto_estatica = { id = 9125998684, vol = 0.9 }, -- PSE Static, Burst of Interference
	kiroshi_scan = { id = 9120985237, vol = 1.2 }, -- PSE Zap, Glassy Reversed Whoosh
	implante_encaixe = { id = 9118363081, vol = 1.1 }, -- PSE Robot Servo, Short Gritty Bursts
	arma_glock = { id = 9114708294, vol = 0.8, region = { 0, 0.9 }, jitter = 0.03 }, -- PSE 9mm Beretta
	arma_deagle = { id = 9119297472, vol = 0.9, region = { 0, 1.5 }, jitter = 0.02 }, -- PSE S&W .357 Magnum
	arma_uzi = { id = 9114714603, vol = 0.7, region = { 0, 0.38 }, speed = 1.12, jitter = 0.04 }, -- PSE 9mm Beretta
	arma_ak47 = { id = 9116343569, vol = 0.75, region = { 0, 0.75 }, jitter = 0.03 }, -- PSE AK-47 single shots
	arma_m4 = { id = 9116343569, vol = 0.7, region = { 0, 0.65 }, speed = 1.08, jitter = 0.03 },
	arma_escopeta = { id = 9112909615, vol = 1, region = { 0, 1.1 } }, -- PSE Mossberg 12 gauge
	arma_sniper = { id = 9118173988, vol = 0.95, region = { 0, 2.4 } }, -- PSE Barrett M82 .50
}
M.LIBRARY = LIBRARY

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
		-- Corre ~13 s seguidos: a caminhada segue o ciclo original (mais lento), então a corrida leva pela cidade.
		state.value = math.max(0, state.value - 0.075 * dt)
		state.rest = 0
		if state.value <= 0 then
			state.exhausted = true
		end
	else
		state.rest += dt
		if state.rest > 0.6 then
			state.value = math.min(1, state.value + 0.25 * dt)
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
	if kind == "louva" then
		local a = Vector3.new(0.95 * side, 0.85, -0.2)
		local b = Vector3.new(-0.75 * side, -0.55, -0.7)
		return a:Lerp(b, math.clamp(t * 1.3, 0, 1)).Unit
	elseif kind == "gorila" then
		local rest = Vector3.new(0.25 * side, -0.4, 0.75)
		local hit = Vector3.new(-0.1 * side, 0.05, -1)
		return rest:Lerp(hit, math.clamp((t - 0.25) / 0.45, 0, 1)).Unit
	end
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

-- Camada de ação por cima das animações: com arma na mão (ou golpeando), o tronco e as pernas saem do idle
-- agachado e ficam numa postura de tiro, como uma animação de mira de prioridade Action faria.
local STANCE_LEGS = { [5] = Vector3.new(0.08, -1, 0.04), [6] = Vector3.new(-0.08, -1, -0.05) }
local function aimStance(index: number, c0: CFrame, c1: CFrame): CFrame
	if index == 1 then
		return rootTransform(c0, CFrame.Angles(math.rad(-4), 0, 0))
	elseif index == 5 or index == 6 then
		return jointTransform(c0, c1, armRotation(STANCE_LEGS[index].Unit, Vector3.new(0, 1, 0)))
	end
	return CFrame.identity
end
M.aimStance = aimStance

-- Inclinação do tronco em relação ao HumanoidRootPart (só a rotação), pela Transform atual do RootJoint.
local function torsoTilt(rootC0: CFrame, rootTransformNow: CFrame, rootC1: CFrame): CFrame
	local tilt = rootC0 * rootTransformNow * rootC1:Inverse()
	return tilt - tilt.Position
end
M.torsoTilt = torsoTilt

-- Braços da arma: a mira vem no espaço do personagem e é levada para o espaço do tronco, então a arma
-- aponta para onde a câmera mira mesmo com o tronco inclinado pela animação (corrida, caminhada).
local function gunArms(tilt: CFrame, rightC0: CFrame, rightC1: CFrame, leftC0: CFrame, leftC1: CFrame, direction: Vector3, reach: number): (CFrame, CFrame)
	local up = tilt:VectorToObjectSpace(Vector3.new(0, 1, 0))
	local d = tilt:VectorToObjectSpace(direction.Unit)
	local rightT = jointTransform(rightC0, rightC1, armRotation(d, up))
	local hand = rightC0.Position + Vector3.new(0.5, 0, 0) + d * reach
	local support = hand + tilt:VectorToObjectSpace(Vector3.new(-0.35, -0.12, 0))
	local leftT = jointTransform(leftC0, leftC1, armRotation((support - leftC0.Position).Unit, up))
	return rightT, leftT
end
M.gunArms = gunArms

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

-- Animações R6 originais do usuário (10 ciclos) ---------------------------------------------------------
-- __R6_ANIMACOES_INICIO__ (gerado por tools/convert_r6_animations.py; não editar à mão)
-- Fonte: animacoes_r6/*.rbxmx (pacote do usuário, 10 ciclos R6). Juntas por keyframe: tronco, cabeça,
-- braço direito, braço esquerdo, perna direita, perna esquerda; quatérnio x, y, z, w (/32767) e
-- posição (/8192) em int16. passos: fase (0 a 1) em que cada pé pisa à frente, medida no rig R6.
local R6_CLIPS = {
	{ key = "idle", sequence = "Okarun_Exhausted_Idle_R6_V3", offset = 0, count = 151, duration = 5.0000, reference = nil, priority = "Idle", steps = nil },
	{ key = "frente", sequence = "Relaxed_Human_Walk_R6", offset = 12684, count = 73, duration = 1.2000, reference = 3.5, priority = "Movement", steps = { 0.9722, 0.4722 } },
	{ key = "frente_direita", sequence = "ForwardRight_Walk_R6", offset = 18816, count = 73, duration = 1.2000, reference = 2.7, priority = "Movement", steps = { 0.9722, 0.4722 } },
	{ key = "direita", sequence = "Right_Walk_R6", offset = 24948, count = 73, duration = 1.2000, reference = 1.5, priority = "Movement", steps = { 0.9722, 0.4722 } },
	{ key = "tras_direita", sequence = "BackwardRight_Walk_R6", offset = 31080, count = 73, duration = 1.2000, reference = 2.0, priority = "Movement", steps = { 0.9722, 0.4722 } },
	{ key = "tras", sequence = "Backward_Walk_R6", offset = 37212, count = 73, duration = 1.2000, reference = 2.5, priority = "Movement", steps = { 0.9722, 0.4722 } },
	{ key = "tras_esquerda", sequence = "BackwardLeft_Walk_R6", offset = 43344, count = 73, duration = 1.2000, reference = 2.0, priority = "Movement", steps = { 0.9722, 0.4722 } },
	{ key = "esquerda", sequence = "Left_Walk_R6", offset = 49476, count = 73, duration = 1.2000, reference = 1.5, priority = "Movement", steps = { 0.9722, 0.4722 } },
	{ key = "frente_esquerda", sequence = "ForwardLeft_Walk_R6", offset = 55608, count = 73, duration = 1.2000, reference = 2.7, priority = "Movement", steps = { 0.9722, 0.4722 } },
	{ key = "corrida", sequence = "Okarun_Fluid_Reference_R6_V5", offset = 61740, count = 31, duration = 0.5000, reference = 13.2, priority = "Movement", steps = { 0.8000, 0.2667 } },
}
local R6_DATA = "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"
-- __R6_ANIMACOES_FIM__

-- Toca as poses originais nos Motor6D do R6, como o Animator faria (easing Linear, peso 1, todas as juntas
-- em cada keyframe): a pose de cada junta é a interpolação linear entre os dois keyframes vizinhos. Os dados
-- vêm compactados em base64 e são abertos uma vez só.
local B64_INDEX = {}
do
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for index = 1, #alphabet do
		B64_INDEX[string.byte(alphabet, index)] = index - 1
	end
end
local function decodeBase64(text: string): buffer
	local length = #text
	local padding = (if string.sub(text, -1) == "=" then 1 else 0) + (if string.sub(text, -2, -2) == "=" then 1 else 0)
	local out = buffer.create(length // 4 * 3 - padding)
	local size = buffer.len(out)
	local at = 0
	for index = 1, length, 4 do
		local a, b, c, d = string.byte(text, index, index + 3)
		local n = B64_INDEX[a] * 262144 + B64_INDEX[b] * 4096 + (B64_INDEX[c] or 0) * 64 + (B64_INDEX[d] or 0)
		if at < size then
			buffer.writeu8(out, at, n // 65536)
		end
		if at + 1 < size then
			buffer.writeu8(out, at + 1, (n // 256) % 256)
		end
		if at + 2 < size then
			buffer.writeu8(out, at + 2, n % 256)
		end
		at += 3
	end
	return out
end
M.decodeBase64 = decodeBase64

-- Juntas na ordem dos dados: pose da KeyframeSequence -> Motor6D do R6 (e a peça pai dele).
local R6_JOINTS = {
	{ pose = "Torso", motor = "RootJoint", parent = "HumanoidRootPart" },
	{ pose = "Head", motor = "Neck", parent = "Torso" },
	{ pose = "Right Arm", motor = "Right Shoulder", parent = "Torso" },
	{ pose = "Left Arm", motor = "Left Shoulder", parent = "Torso" },
	{ pose = "Right Leg", motor = "Right Hip", parent = "Torso" },
	{ pose = "Left Leg", motor = "Left Hip", parent = "Torso" },
}
M.R6_JOINTS = R6_JOINTS
local r6Library
-- Abre os 10 ciclos (uma vez): por animação, a lista de keyframes, cada um com os 6 CFrames.
local function r6Clips()
	if r6Library then
		return r6Library
	end
	local data = decodeBase64(R6_DATA)
	local library = {}
	for _, info in R6_CLIPS do
		local frames = table.create(info.count)
		local at = info.offset
		for frame = 1, info.count do
			local pose = table.create(6)
			for joint = 1, 6 do
				local qx, qy, qz, qw = buffer.readi16(data, at) / 32767, buffer.readi16(data, at + 2) / 32767,
					buffer.readi16(data, at + 4) / 32767, buffer.readi16(data, at + 6) / 32767
				local px, py, pz = buffer.readi16(data, at + 8) / 8192, buffer.readi16(data, at + 10) / 8192, buffer.readi16(data, at + 12) / 8192
				pose[joint] = CFrame.new(px, py, pz, qx, qy, qz, qw)
				at += 14
			end
			frames[frame] = pose
		end
		library[info.key] = {
			key = info.key, frames = frames, count = info.count, duration = info.duration, reference = info.reference,
			steps = info.steps, priority = info.priority,
		}
	end
	r6Library = library
	return library
end
M.r6Clips = r6Clips

-- Pose de uma animação na fase (0 a 1) do ciclo, escrita em out (6 CFrames).
local function clipPose(clip, phase: number, out)
	local x = (phase % 1) * (clip.count - 1)
	local index = math.floor(x)
	local alpha = x - index
	local a, b = clip.frames[index + 1], clip.frames[math.min(index + 2, clip.count)]
	for joint = 1, 6 do
		out[joint] = if alpha < 1e-6 then a[joint] else a[joint]:Lerp(b[joint], alpha)
	end
	return out
end
M.clipPose = clipPose

-- Direções em setores de 45 graus a partir do vetor no espaço do personagem (X+ direita, Z- frente),
-- com histerese: só troca de setor depois de passar 10 graus da borda.
local R6_SECTORS = { "frente", "frente_direita", "direita", "tras_direita", "tras", "tras_esquerda", "esquerda", "frente_esquerda" }
M.R6_SECTORS = R6_SECTORS
local SECTOR_HYSTERESIS = math.rad(10)
local function moveSector(x: number, z: number, current: number?): number
	local angle = math.atan2(x, -z)
	local index = math.floor(angle / (math.pi / 4) + 0.5) % 8 + 1
	if current then
		local center = (current - 1) * math.pi / 4
		local delta = math.abs((angle - center + math.pi) % (2 * math.pi) - math.pi)
		if delta < math.pi / 8 + SECTOR_HYSTERESIS then
			return current
		end
	end
	return index
end
M.moveSector = moveSector

-- Velocidades do jogo com as animações novas: andar e correr ficam perto das referências do pacote
-- (passo sincronizado, sem forçar a reprodução). Mirando, cada direção tem o seu limite.
local MOTION = {
	walk = 9.5, sprint = 26, sprintAt = 14, minRate = 0.4, maxWalkRate = 3, maxSprintRate = 2.1,
	strafe = { 8, 7, 4.5, 5.5, 6.5, 5.5, 4.5, 7 },
}
M.MOTION = MOTION
local REF_STRIKE = 0.972 -- fase em que o pé direito pisa nas caminhadas (medida no rig)
local function newMotion()
	local weights = { idle = 1, corrida = 0 }
	for _, key in R6_SECTORS do
		weights[key] = 0
	end
	return { phase = 0, idleTime = 0, sector = 1, moving = false, speed = 0, weights = weights, pose = table.create(6),
		scratch = table.create(6), sprinting = false }
end
M.newMotion = newMotion

-- Um passo da locomoção: input.move (direção no espaço do personagem, X+ direita, Z- frente, pode ser zero),
-- input.speed (velocidade real no plano, studs/s) e input.sprint (pedido de corrida). Devolve a pose (6 CFrames)
-- e o pé que pisou neste quadro (1 direito, 2 esquerdo, 0 nenhum).
local function motionStep(m, input, dt: number)
	local clips = r6Clips()
	dt = math.clamp(dt, 0, 0.1)
	m.speed += (input.speed - m.speed) * math.min(1, dt * 10)
	local move = input.move
	local planar = Vector3.new(move.X, 0, move.Z)
	-- Começa a andar acima de 0,8 studs/s e para abaixo de 0,4 (sem piscar entre parado e andando).
	if m.moving then
		m.moving = m.speed > 0.4 or planar.Magnitude > 0.5
	else
		m.moving = m.speed > 0.8
	end
	if m.moving and planar.Magnitude > 0.05 then
		m.sector = moveSector(planar.X, planar.Z, m.sector)
	end
	m.sprinting = m.moving and m.sector == 1 and m.speed > MOTION.sprintAt and input.sprint ~= false
	-- Pesos: parado, oito direções e corrida, cada um indo para o alvo aos poucos (crossfade).
	local w = m.weights
	local function approach(key: string, goal: number, rate: number)
		w[key] += (goal - w[key]) * math.min(1, dt * rate)
		if w[key] < 1e-3 then
			w[key] = 0
		end
	end
	approach("idle", if m.moving then 0 else 1, 7)
	approach("corrida", if m.sprinting then 1 else 0, 6)
	for index, key in R6_SECTORS do
		approach(key, if m.moving and not m.sprinting and index == m.sector then 1 else 0, 9)
	end
	-- Fase comum: todas as caminhadas pisam juntas; a corrida é deslocada para o pé bater no mesmo ponto.
	local walkWeight, walkRate = 0, 0
	for _, key in R6_SECTORS do
		if w[key] > 0 then
			local clip = clips[key]
			local rate = math.clamp(m.speed / clip.reference, MOTION.minRate, MOTION.maxWalkRate)
			walkWeight += w[key]
			walkRate += w[key] * rate / clip.duration
		end
	end
	local sprintClip = clips.corrida
	local sprintRate = math.clamp(m.speed / sprintClip.reference, MOTION.minRate, MOTION.maxSprintRate) / sprintClip.duration
	local moveWeight = walkWeight + w.corrida
	local stepped = 0
	if moveWeight > 0.01 then
		local cycles = (walkRate + w.corrida * sprintRate) / moveWeight
		local before = m.phase
		m.phase = (m.phase + cycles * dt) % 1
		-- Passos: o pé direito pisa na fase 0 (REF_STRIKE) e o esquerdo meia volta depois.
		local leftAt = if w.corrida > walkWeight
			then (sprintClip.steps[2] - sprintClip.steps[1]) % 1
			else (clips.frente.steps[2] - clips.frente.steps[1]) % 1
		local function crossed(mark: number): boolean
			local a, b = before, m.phase
			if b < a then
				return mark > a or mark <= b
			end
			return mark > a and mark <= b
		end
		if crossed(0) then
			stepped = 1
		elseif crossed(leftAt) then
			stepped = 2
		end
	end
	m.idleTime = (m.idleTime + dt / clips.idle.duration) % 1
	-- Mistura: média ponderada das poses (sequência de lerps normalizados).
	local pose, scratch = m.pose, m.scratch
	local total = 0
	local function add(clip, phase: number, weight: number)
		if weight <= 0 then
			return
		end
		if total == 0 then
			clipPose(clip, phase, pose)
		else
			clipPose(clip, phase, scratch)
			local alpha = weight / (total + weight)
			for joint = 1, 6 do
				pose[joint] = pose[joint]:Lerp(scratch[joint], alpha)
			end
		end
		total += weight
	end
	add(clips.idle, m.idleTime, w.idle)
	for _, key in R6_SECTORS do
		local clip = clips[key]
		add(clip, m.phase + clip.steps[1] - REF_STRIKE, w[key])
	end
	add(sprintClip, m.phase + sprintClip.steps[1] - REF_STRIKE, w.corrida)
	if total == 0 then
		clipPose(clips.idle, m.idleTime, pose)
	end
	return pose, stepped
end
M.motionStep = motionStep

-- Limite de velocidade mirando (corpo virado para a câmera): cada direção anda no ritmo do seu ciclo.
local function strafeSpeed(x: number, z: number): number
	if x * x + z * z < 1e-4 then
		return MOTION.strafe[1]
	end
	return MOTION.strafe[moveSector(x, z, nil)]
end
M.strafeSpeed = strafeSpeed

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
local PACK_ORDER = { "r6", "realista", "estiloso", "esportivo", "aura", "classico", "gta6", "ninja", "heroi", "padrao" }
-- "r6": as 10 animações R6 originais do usuário (tocadas direto nos Motor6D, sem esqueleto R15).
ANIMATION_PACKS.r6 = { nome = "Okarun R6 (original)", r6 = true }
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
local HEALTH = Color3.fromRGB(94, 246, 255) -- vida em ciano, como em Night City
local HURT = Color3.fromRGB(236, 72, 84)
local BREATH = Color3.fromRGB(255, 208, 102)
local ACCENT = Color3.fromRGB(255, 206, 114)
-- Paleta "pôr do sol de Maré Baixa": rosa quente, laranja e dourado sobre vidro azul-escuro (como o
-- clima de Vice City), usada só nos destaques: o resto do HUD continua discreto.
local PINK = Color3.fromRGB(255, 72, 140)
local ORANGE = Color3.fromRGB(255, 146, 72)
local GOLD = Color3.fromRGB(255, 208, 102)
local TEAL = Color3.fromRGB(72, 226, 210)
-- Estilo Cyberpunk 2077: molduras e ícones vermelho-coral, destaques em ciano, objetivos em amarelo.
local NEON_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 104, 92)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 72, 84)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 132, 96)),
})
local SUNSET = ColorSequence.new({
	ColorSequenceKeypoint.new(0, PINK), ColorSequenceKeypoint.new(0.55, ORANGE), ColorSequenceKeypoint.new(1, GOLD),
})
-- Neon do HUD 3D (como o do Chrome Clash): ciano, e rosa para dano e ciberpsicose.
local NEON = Color3.fromRGB(255, 92, 84)
local NEON_HURT = Color3.fromRGB(196, 96, 255) -- ciberpsicose em violeta (o vermelho já é das molduras)
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

-- Cantos retos (Night City); só os botões redondos de toque continuam círculos.
local function round(parent, radius: UDim)
	local shape = if radius.Scale >= 0.5 then radius else UDim.new(0, math.min(radius.Offset, 2))
	new("UICorner", parent, { CornerRadius = shape })
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

	-- Selo da zona segura no estilo do resto: placa escura, traço ciano à esquerda e texto ciano.
	local safe = label(gui, "ZonaSegura", "ZONA SEGURA · ARMAS TRAVADAS", f.heavy, if touch then 9 else 11, HEALTH, 12, {
		Size = UDim2.fromOffset(if touch then 168 else 220, if touch then 18 else 22), TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = PANEL, BackgroundTransparency = 0.25, Visible = false,
	})
	round(safe, UDim.new(0, 2))
	stroke(safe, HEALTH, 0.55, 1)
	frame(safe, "Traco", 13, { Size = UDim2.new(0, 3, 1, 0), BackgroundTransparency = 0, BackgroundColor3 = HEALTH })

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
	-- Mesma paleta do HUD neon: degradê ciano (no lugar do pôr do sol) e textos escuros no cartão aceso.
	local sunset = function(parent: Instance, rotation: number?): UIGradient
		return new("UIGradient", parent, { Color = NEON_SEQUENCE, Rotation = rotation or 0 })
	end
	local PINK = NEON
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
			-- Selecionado: cartão aceso em degradê neon, ícone e textos escuros (contraste no ciano claro).
			entry.glow.Enabled = on
			entry.card.BackgroundColor3 = if on then LINE else PANEL
			entry.card.BackgroundTransparency = if on then 0.04 else 0.26
			entry.edge.Color = NEON
			entry.edge.Transparency = if on then 0.05 else 0.7
			entry.edge.Thickness = if on then 2 else 1
			if entry.image:IsA("ImageLabel") then
				entry.image.ImageColor3 = if on then PANEL else NEON
			end
			entry.ammo.Text = ammoText(entry.def.id, ammoTable)
			entry.ammo.TextColor3 = if on then PANEL else SUB
			if entry.key then
				entry.key.TextColor3 = if on then PANEL else SUB
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
		label(button, "Tecla", keyHint, Font.new("rbxassetid://12187375422", Enum.FontWeight.Bold), 10, NEON, 22, {
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
	local mono = Font.new("rbxassetid://12187375422", Enum.FontWeight.Bold)
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
		local box, line, glow = neonBox(gui, if side == "left" then "SetaEsquerda" else "SetaDireita", hit[1], hit[2], 2, 2)
		text(box, "Simbolo", if side == "left" then "<" else ">", 0.42, 5, { TextXAlignment = Enum.TextXAlignment.Center })
		arrows[side] = { box = box, line = line, glow = glow }
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
			entry[1].TextSize = math.max(18, math.floor(canvas.Y * entry[2] + 0.5)) -- 9 px de tela, no mínimo
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
		-- O halo é outro Frame: some junto com a seta (antes sobrava uma "cápsula" vazia na última página).
		arrows.left.box.Visible = bar.page > 1
		arrows.right.box.Visible = bar.page < bar.pages
		arrows.left.glow.Visible = arrows.left.box.Visible
		arrows.right.glow.Visible = arrows.right.box.Visible
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

-- Implantes -------------------------------------------------------------------------------------------------
-- Lugares no corpo R6, no espaço do Torso (frente em -Z, costas em +Z), com a direção para onde a marca
-- olha: o terminal desenha a marca sobre o boneco e a apaga quando o lugar fica de costas para a câmera.
local IMPLANT_SPOTS = {
	coluna = { label = "COLUNA", point = Vector3.new(0, 0.35, 0.64), normal = Vector3.new(0, 0, 1) },
	olhos = { label = "OLHOS", point = Vector3.new(0.26, 1.62, -0.6), normal = Vector3.new(0, 0, -1) },
	bracos = { label = "BRAÇOS", point = Vector3.new(1.68, -0.55, -0.52), normal = Vector3.new(0.25, 0, -1) },
	pernas = { label = "PERNAS", point = Vector3.new(-0.5, -2.1, -0.52), normal = Vector3.new(0, 0, -1) },
	pele = { label = "PELE", point = Vector3.new(-0.5, 0.3, -0.54), normal = Vector3.new(0, 0, -1) },
}
M.IMPLANT_SPOTS = IMPLANT_SPOTS
-- Cores dos rastros do Sandevistan, como no anime (verde, ciano, azul, violeta, rosa, amarelo); no surto, vermelhos.
local GHOST_COLORS = {
	Color3.fromRGB(70, 255, 140), Color3.fromRGB(50, 235, 255), Color3.fromRGB(80, 130, 255),
	Color3.fromRGB(170, 90, 255), Color3.fromRGB(255, 80, 200), Color3.fromRGB(255, 226, 80),
}
local FRENZY_COLORS = { Color3.fromRGB(255, 40, 70), Color3.fromRGB(255, 110, 60), Color3.fromRGB(200, 20, 60) }
M.GHOST_COLORS = GHOST_COLORS

-- Projeta um ponto 3D na imagem de uma câmera (a do boneco no ViewportFrame): x e y de 0 a 1 (do canto de cima
-- à esquerda) e a profundidade (zero ou menos: atrás da câmera). fov é o vertical, em graus; aspect = largura/altura.
local function projectPoint(cameraCFrame: CFrame, fov: number, aspect: number, point: Vector3): (number, number, number)
	local p = cameraCFrame:PointToObjectSpace(point)
	local depth = -p.Z
	if depth <= 1e-3 then
		return 0.5, 0.5, depth
	end
	local t = math.tan(math.rad(fov) / 2)
	return 0.5 + (p.X / depth) / (t * aspect) / 2, 0.5 - (p.Y / depth) / t / 2, depth
end
M.projectPoint = projectPoint

-- Velocidade do próprio corpo: o Sandevistan acelera, perto de quem ativou fica lento e no surto cambaleia.
local function abilitySpeed(active: boolean, slowed: boolean, frenzy: boolean, stats): number
	if frenzy then
		return 1.6 -- surto: o corpo corre sozinho atrás de alguém
	elseif active then
		return (stats and stats.velocidade) or 2.2
	elseif slowed then
		return (stats and stats.lento) or 0.3
	end
	return 1
end
M.abilitySpeed = abilitySpeed

-- Boneco R6 do terminal, em pose A (braços um pouco abertos para mostrar os implantes dos braços), em cor de
-- holograma. Devolve o modelo e o Torso (o centro do giro).
local HOLO_BODY = Color3.fromRGB(70, 214, 220)
local function buildMannequin(): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Boneco"
	local function limb(name: string, size: Vector3, pose: CFrame)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = pose
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = HOLO_BODY
		p.Transparency = 0.42
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local torso = limb("Torso", Vector3.new(2, 2, 1), CFrame.new())
	local head = limb("Head", Vector3.new(2, 1, 1), CFrame.new(0, 1.5, 0))
	new("SpecialMesh", head, { MeshType = Enum.MeshType.Head, Scale = Vector3.new(1.25, 1.25, 1.25) })
	-- Visor na frente da cabeça: mostra para onde o boneco olha enquanto gira.
	limb("Visor", Vector3.new(0.9, 0.16, 0.06), CFrame.new(0, 1.55, -0.62)).Transparency = 0.1
	for _, side in { 1, -1 } do
		local shoulder = CFrame.new(side * 1.5, 1, 0) * CFrame.Angles(0, 0, math.rad(side * 10))
		limb(if side == 1 then "Right Arm" else "Left Arm", Vector3.new(1, 2, 1), shoulder * CFrame.new(side * 0.08, -1, 0))
		limb(if side == 1 then "Right Leg" else "Left Leg", Vector3.new(1, 2, 1), CFrame.new(side * 0.5, -2, 0))
	end
	model.PrimaryPart = torso
	return model, torso
end
M.buildMannequin = buildMannequin

-- Terminal de implantes: uma placa translúcida na frente da câmera, como a tela de um ripperdoc. Lista dos
-- implantes à esquerda, boneco 3D que gira no meio (marcas onde cada implante encaixa) e, à direita, os
-- detalhes com o botão ENCAIXAR. As áreas de toque saem em panel.hits (escala da placa) para a camada 2D.
local TERMINAL = {
	rows = { x = 0.03, y = 0.17, w = 0.325, h = 0.118, gap = 0.012 },
	doll = { x = 0.37, y = 0.16, w = 0.27, h = 0.72 },
	details = { x = 0.655, y = 0.16, w = 0.315, h = 0.64 },
	action = { x = 0.655, y = 0.83, w = 0.315, h = 0.12 },
	close = { x = 0.925, y = 0.03, w = 0.05, h = 0.09 },
}
M.TERMINAL = TERMINAL
-- Ficha do implante no terminal: até três linhas (rótulo, valor) com os números que o servidor publica.
local function decimal(value: number): string
	return (string.gsub(string.format("%.1f", value), "%.0$", ""):gsub("%.", ","))
end
local function implantFacts(def)
	local s = def.stats or {}
	if def.id == "sandevistan" then
		return {
			{ "DURAÇÃO", string.format("%s s", decimal(s.duracao or 4)) },
			{ "CUSTO POR USO", string.format("%d%% ESTABILIDADE", s.custo or 25) },
			{ "CIBERPSICOSE", string.format("%d s SEM CONTROLE", s.surto or 30) },
		}
	elseif def.id == "kiroshi" then
		return { { "ALCANCE", string.format("%d studs", s.alcance or 120) }, { "MARCAÇÃO", "ATRAVÉS DE PAREDES" }, { "MIRA", "ZOOM FORTE" } }
	elseif def.id == "louva" then
		return { { "DANO DO CORTE", tostring(s.dano or 40) }, { "ALCANCE", string.format("%d studs", s.alcance or 9) }, { "CORRENDO", "SALTO DE ATAQUE" } }
	elseif def.id == "gorila" then
		return { { "DANO DO SOCO", tostring(s.dano or 36) }, { "EMPURRÃO", "ARREMESSA O ALVO" }, { "ESPAÇO", "BRAÇOS" } }
	elseif def.id == "tendoes" then
		return { { "PULO", string.format("+%d%%", math.floor(((s.pulo or 1.4) - 1) * 100 + 0.5)) }, { "NO AR", "SEGUNDO PULO" }, { "ESPAÇO", "PERNAS" } }
	elseif def.id == "subdermal" then
		return { { "DANO RECEBIDO", string.format("-%d%%", math.floor((s.reducao or 0.3) * 100 + 0.5)) }, { "PROTEGE DE", "BALAS E GOLPES" }, { "ESPAÇO", "PELE" } }
	end
	return {}
end
M.implantFacts = implantFacts

local function buildImplantPanel(implants, atlas: string?, models: Instance?)
	local f = fonts()
	local mono = Font.new("rbxassetid://12187375422", Enum.FontWeight.Bold)
	local part, gui = holoSurface("CyberOutlawTerminal", Vector2.new(1100, 560))
	gui.Brightness = 1.7
	-- Textos: { rótulo, fração da altura da placa, mínimo em px de tela, limite (texto que encolhe para caber) }.
	local texts = {}
	local function text(parent, name, value, share, minimum, color, z, props, font, scaled)
		local item = label(parent, name, value, font or mono, 18, color or NEON, z, props)
		local limit
		if scaled then
			item.TextScaled, item.TextWrapped = true, true
			limit = new("UITextSizeConstraint", item, { MaxTextSize = 18, MinTextSize = 9 })
		end
		table.insert(texts, { item, share, minimum, limit })
		return item
	end
	local function at(r)
		return UDim2.fromScale(r.x, r.y), UDim2.fromScale(r.w, r.h)
	end
	local root = frame(gui, "Terminal", 1, { Size = FULL, BackgroundColor3 = Color3.fromRGB(4, 12, 18), BackgroundTransparency = 0.18 })
	round(root, UDim.new(0.02, 0))
	stroke(root, NEON, 0.15, 3)
	new("UIGradient", root, {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.3) }),
	})
	-- Grade de fundo e cantoneiras: a cara de tela de computador.
	for index = 1, 23 do
		frame(root, "Grade", 1, { Position = UDim2.fromScale(index / 24, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = NEON, BackgroundTransparency = 0.94 })
	end
	for index = 1, 11 do
		frame(root, "Grade", 1, { Position = UDim2.fromScale(0, index / 12), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = NEON, BackgroundTransparency = 0.94 })
	end
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local position = UDim2.new(corner.X, if corner.X == 0 then 5 else -5, corner.Y, if corner.Y == 0 then 5 else -5)
		frame(root, "Canto", 6, { AnchorPoint = corner, Position = position, Size = UDim2.new(0.06, 0, 0, 5), BackgroundColor3 = NEON, BackgroundTransparency = 0 })
		frame(root, "Canto", 6, { AnchorPoint = corner, Position = position, Size = UDim2.new(0, 5, 0.1, 0), BackgroundColor3 = NEON, BackgroundTransparency = 0 })
	end
	local scan = frame(root, "Varredura", 2, { Size = UDim2.fromScale(1, 0.14), BackgroundColor3 = NEON, BackgroundTransparency = 0 })
	new("UIGradient", scan, {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.85, 0.9), NumberSequenceKeypoint.new(1, 1) }),
	})
	-- Cabeçalho.
	text(root, "Titulo", "TERMINAL DE IMPLANTES", 0.05, 12, NEON, 4, { Position = UDim2.fromScale(0.03, 0.025), Size = UDim2.fromScale(0.75, 0.07) })
	text(root, "Subtitulo", "RIPPERDOC · MARÉ BAIXA · CONEXÃO NEURAL ESTÁVEL", 0.024, 8, SUB, 4, {
		Position = UDim2.fromScale(0.03, 0.095), Size = UDim2.fromScale(0.75, 0.04),
	}, f.bold)
	local rule = frame(root, "Linha", 3, { Position = UDim2.fromScale(0.03, 0.145), Size = UDim2.new(0.94, 0, 0, 2), BackgroundColor3 = NEON, BackgroundTransparency = 0 })
	new("UIGradient", rule, { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) }) })
	local closePosition, closeSize = at(TERMINAL.close)
	local close = frame(root, "Fechar", 4, { Position = closePosition, Size = closeSize, BackgroundColor3 = NEON, BackgroundTransparency = 0.85 })
	round(close, UDim.new(0.2, 0))
	stroke(close, NEON, 0, 2)
	text(close, "X", "X", 0.045, 11, NEON, 5, { TextXAlignment = Enum.TextXAlignment.Center })

	local panel = { part = part, gui = gui, root = root, rows = {}, markers = {}, hits = {}, selected = nil, yaw = math.rad(200),
		aspect = 0.8, equipped = {}, psy = 100, busy = false, spin = 0, scanAt = 0 }
	table.insert(panel.hits, { key = "fechar", position = closePosition, size = closeSize })

	-- Lista dos implantes.
	local byId = {}
	for index, def in implants do
		byId[def.id] = def
		local r = TERMINAL.rows
		local position = UDim2.fromScale(r.x, r.y + (index - 1) * (r.h + r.gap))
		local size = UDim2.fromScale(r.w, r.h)
		local row = frame(root, "Linha_" .. def.id, 3, { Position = position, Size = size, BackgroundColor3 = NEON, BackgroundTransparency = 0.94 })
		round(row, UDim.new(0.14, 0))
		local line = stroke(row, NEON, 0.55, 2)
		local iconBox = frame(row, "Icone", 4, {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.025, 0.5), Size = UDim2.fromScale(0.78, 0.78),
			SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundColor3 = PANEL, BackgroundTransparency = 0.3,
		})
		round(iconBox, UDim.new(0.2, 0))
		stroke(iconBox, NEON, 0.35, 1.5)
		if atlas and iconRect(def.id) then
			atlasImage(iconBox, "Simbolo", atlas, def.id, 5, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), ImageColor3 = NEON })
		else
			frameGlyph(iconBox, def.id, 5, NEON)
		end
		local name = text(row, "Nome", upper(def.name), 0.03, 9, TEXT, 5, {
			Position = UDim2.fromScale(0.27, 0.08), Size = UDim2.fromScale(0.71, 0.48), TextTruncate = Enum.TextTruncate.AtEnd,
		}, f.heavy)
		local status = text(row, "Estado", "", 0.022, 8, NEON, 5, { Position = UDim2.fromScale(0.27, 0.55), Size = UDim2.fromScale(0.71, 0.36) })
		panel.rows[def.id] = { row = row, line = line, name = name, status = status }
		table.insert(panel.hits, { key = "linha:" .. def.id, position = position, size = size })
	end

	-- Boneco 3D que gira, com plataforma e as marcas dos lugares.
	local dollPosition, dollSize = at(TERMINAL.doll)
	local dollFrame = frame(root, "Boneco", 3, { Position = dollPosition, Size = dollSize })
	local floor = frame(dollFrame, "Plataforma", 3, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.93), Size = UDim2.fromScale(0.8, 0.09),
		BackgroundColor3 = NEON, BackgroundTransparency = 0.82,
	})
	round(floor, UDim.new(1, 0))
	stroke(floor, NEON, 0.2, 2)
	local viewport = new("ViewportFrame", dollFrame, {
		Name = "Vista", Size = FULL, BackgroundTransparency = 1, ZIndex = 4, Ambient = Color3.fromRGB(110, 190, 200),
		LightColor = Color3.fromRGB(190, 255, 250), LightDirection = Vector3.new(-0.5, -1, 0.6),
	})
	local dollCamera = new("Camera", viewport, { Name = "Camera", FieldOfView = 30 })
	viewport.CurrentCamera = dollCamera
	dollCamera.CFrame = CFrame.lookAt(Vector3.new(0, -0.35, -13.5), Vector3.new(0, -0.35, 0))
	local doll = buildMannequin()
	doll.Parent = viewport
	panel.doll, panel.camera, panel.viewport = doll, dollCamera, viewport
	-- Cada peça guarda a pose em relação ao Torso; girar é recolocar todas (sem depender de PivotTo).
	local dollParts = {}
	local dollRest = {}
	for _, item in doll:GetChildren() do
		if item:IsA("BasePart") then
			table.insert(dollParts, { item, item.CFrame })
			dollRest[item.Name] = item.CFrame
		end
	end
	panel.dollParts = dollParts
	text(root, "Girar", "<  ARRASTE PARA GIRAR  >", 0.022, 8, SUB, 4, {
		Position = UDim2.fromScale(TERMINAL.doll.x, TERMINAL.doll.y + TERMINAL.doll.h + 0.015), Size = UDim2.fromScale(TERMINAL.doll.w, 0.05),
		TextXAlignment = Enum.TextXAlignment.Center,
	}, f.bold)
	table.insert(panel.hits, { key = "boneco", position = dollPosition, size = dollSize })
	for slot, spot in IMPLANT_SPOTS do
		local mark = frame(dollFrame, "Marca_" .. slot, 7, {
			AnchorPoint = CENTER, Size = UDim2.fromScale(0.07, 0.07), SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundColor3 = PANEL, BackgroundTransparency = 0.4,
		})
		round(mark, UDim.new(1, 0))
		local ring = stroke(mark, NEON, 0, 2.5)
		local dot = frame(mark, "Ponto", 8, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.42, 0.42), BackgroundColor3 = NEON, BackgroundTransparency = 0 })
		round(dot, UDim.new(1, 0))
		local tag = text(mark, "Rotulo", spot.label, 0.02, 7, NEON, 8, {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(1.25, 0.5), Size = UDim2.fromScale(3.4, 0.9),
		}, f.heavy)
		tag.TextStrokeTransparency, tag.TextStrokeColor3 = 0.3, PANEL
		panel.markers[slot] = { mark = mark, ring = ring, dot = dot, tag = tag, spot = spot }
	end

	-- Detalhes do implante escolhido.
	local detailsPosition, detailsSize = at(TERMINAL.details)
	local details = frame(root, "Detalhes", 3, { Position = detailsPosition, Size = detailsSize })
	local system = text(details, "Sistema", "", 0.024, 8, NEON, 4, { Size = UDim2.fromScale(1, 0.08) })
	local title = text(details, "Nome", "", 0.05, 11, TEXT, 4, { Position = UDim2.fromScale(0, 0.08), Size = UDim2.fromScale(1, 0.13) }, mono, true)
	local chip = text(details, "Situacao", "", 0.022, 8, PANEL, 5, {
		Position = UDim2.fromScale(0, 0.23), Size = UDim2.fromScale(0.5, 0.075), TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0, BackgroundColor3 = NEON,
	}, f.heavy)
	round(chip, UDim.new(0.3, 0))
	local desc = text(details, "Descricao", "", 0.026, 9, TEXT, 4, {
		Position = UDim2.fromScale(0, 0.33), Size = UDim2.fromScale(1, 0.34), TextYAlignment = Enum.TextYAlignment.Top,
	}, f.medium, true)
	local stats = {}
	-- Três linhas de ficha (rótulo e valor) que mudam com o implante escolhido.
	for index = 1, 3 do
		local y = 0.68 + (index - 1) * 0.075
		stats[index] = {
			label = text(details, "Rotulo_" .. index, "", 0.022, 8, SUB, 4, { Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(0.55, 0.07) }, f.bold),
			value = text(details, "Valor_" .. index, "—", 0.022, 8, NEON, 4, {
				Position = UDim2.fromScale(0.55, y), Size = UDim2.fromScale(0.45, 0.07), TextXAlignment = Enum.TextXAlignment.Right,
			}, f.heavy),
		}
	end
	local psyLabel = text(details, "Estabilidade", "ESTABILIDADE 100%", 0.022, 8, NEON_HURT, 4, {
		Position = UDim2.fromScale(0, 0.915), Size = UDim2.fromScale(1, 0.06),
	}, f.heavy)
	local psyTrack = frame(details, "EstabilidadeBarra", 4, {
		Position = UDim2.fromScale(0, 0.975), Size = UDim2.fromScale(1, 0.025), BackgroundColor3 = PANEL, BackgroundTransparency = 0.2,
	})
	stroke(psyTrack, NEON_HURT, 0.5, 1)
	local psyFill = frame(psyTrack, "Valor", 5, { Size = FULL, BackgroundColor3 = NEON_HURT, BackgroundTransparency = 0 })
	local actionPosition, actionSize = at(TERMINAL.action)
	local actionBox = frame(root, "Acao", 4, { Position = actionPosition, Size = actionSize, BackgroundColor3 = NEON, BackgroundTransparency = 0.8 })
	round(actionBox, UDim.new(0.18, 0))
	local actionLine = stroke(actionBox, NEON, 0, 3)
	local actionText = text(actionBox, "Texto", "", 0.04, 11, NEON, 5, { TextXAlignment = Enum.TextXAlignment.Center })
	table.insert(panel.hits, { key = "acao", position = actionPosition, size = actionSize })
	panel.title, panel.desc, panel.action, panel.actionText, panel.chip = title, desc, actionBox, actionText, chip

	-- O que o botão de ação faz agora com o implante escolhido: "encaixar", "tirar", nil (em breve ou em uso).
	function panel.actionFor(id: string?): string?
		local def = id and byId[id]
		if not def or panel.busy then
			return nil
		end
		if panel.equipped[id] then
			return "tirar"
		end
		return if def.pronto then "encaixar" else nil
	end
	local function refresh()
		for id, entry in panel.rows do
			local def = byId[id]
			local on = panel.equipped[id] == true
			local chosen = panel.selected == id
			entry.row.BackgroundTransparency = if chosen then 0.8 else 0.94
			entry.line.Thickness = if chosen then 3 else 2
			entry.line.Transparency = if chosen then 0 else 0.55
			entry.line.Color = if on then NEON_HURT else NEON
			entry.status.Text = if on then "ENCAIXADO" elseif def.pronto then "DISPONÍVEL" else "EM BREVE"
			entry.status.TextColor3 = if on then NEON_HURT elseif def.pronto then NEON else SUB
			entry.name.TextTransparency = if def.pronto or on then 0 else 0.35
		end
		local def = panel.selected and byId[panel.selected]
		if def then
			system.Text = def.sistema or ""
			title.Text = upper(def.name)
			desc.Text = def.desc or ""
			local on = panel.equipped[def.id] == true
			chip.Text = if on then "ENCAIXADO" elseif def.pronto then "DISPONÍVEL" else "EM BREVE"
			chip.BackgroundColor3 = if on then NEON_HURT elseif def.pronto then NEON else SUB
			local s = def.stats
			for index, row in stats do
				local fact = implantFacts(def)[index]
				row.label.Text = if fact then fact[1] else ""
				row.value.Text = if fact then fact[2] else ""
			end
		end
		local verb = panel.actionFor(panel.selected)
		actionText.Text = if verb == "encaixar" then "ENCAIXAR" elseif verb == "tirar" then "DESENCAIXAR"
			elseif panel.busy and def and panel.equipped[def.id] then "EM USO" else "EM BREVE"
		local tone = if verb == "tirar" then NEON_HURT elseif verb then NEON else SUB
		actionText.TextColor3, actionLine.Color, actionBox.BackgroundColor3 = tone, tone, tone
		actionBox.BackgroundTransparency = if verb then 0.78 else 0.94
		actionLine.Transparency = if verb then 0 else 0.6
		for slot, marker in panel.markers do
			local filled = false
			for id in panel.equipped do
				if byId[id] and byId[id].slot == slot then
					filled = true
				end
			end
			local tone2 = if filled then NEON_HURT else NEON
			marker.ring.Color, marker.dot.BackgroundColor3, marker.tag.TextColor3 = tone2, tone2, tone2
			marker.dot.Visible = filled or (def ~= nil and def.slot == slot)
		end
		local value = math.clamp(panel.psy / 100, 0, 1)
		psyLabel.Text = string.format("ESTABILIDADE %d%%", math.floor(panel.psy + 0.5))
		psyFill.Size = UDim2.fromScale(value, 1)
	end
	function panel.select(id: string)
		if byId[id] then
			panel.selected = id
			refresh()
		end
	end
	-- equipped: conjunto de ids encaixados; psy: estabilidade de 0 a 100; busy: Sandevistan ou surto em curso.
	function panel.setState(equipped, psy: number, busy: boolean)
		panel.equipped = equipped or {}
		panel.psy = psy or 100
		panel.busy = busy == true
		-- A coluna do Sandevistan aparece nas costas do boneco quando encaixada.
		local changed = false
		for id in byId do
			local existing = doll:FindFirstChild("Implante_" .. id)
			if panel.equipped[id] and not existing and models then
				local template = models:FindFirstChild(id)
				if template and template:IsA("Model") then
					local copy = template:Clone()
					copy.Name = "Implante_" .. id
					-- Cada peça vai na parte do boneco com o mesmo nome (tronco, cabeça, braços, pernas).
					for _, piece in copy:GetChildren() do
						local rest = dollRest[piece.Name]
						for _, item in piece:GetDescendants() do
							if item:IsA("BasePart") then
								item.Anchored = true
								table.insert(dollParts, { item, (rest or CFrame.identity) * item.CFrame })
							end
						end
					end
					copy.Parent = doll
					changed = true
				end
			elseif not panel.equipped[id] and existing then
				for index = #dollParts, 1, -1 do
					if dollParts[index][1]:IsDescendantOf(existing) then
						table.remove(dollParts, index)
					end
				end
				existing:Destroy()
				changed = true
			end
		end
		if changed then
			panel.rotate(panel.yaw)
		end
		refresh()
	end
	function panel.resize(canvas: Vector2)
		gui.CanvasSize = canvas
		for _, entry in texts do
			local size = math.max(2 * entry[3], math.floor(canvas.Y * entry[2] + 0.5))
			if entry[4] then
				entry[4].MaxTextSize = size
				entry[4].MinTextSize = math.min(size, 2 * 7)
			else
				entry[1].TextSize = size
			end
		end
		panel.aspect = (TERMINAL.doll.w * canvas.X) / math.max(1, TERMINAL.doll.h * canvas.Y)
	end
	-- Gira o boneco e põe cada marca sobre o lugar dela (apagada quando o lugar fica de costas).
	function panel.rotate(yaw: number)
		panel.yaw = yaw
		local pose = CFrame.Angles(0, yaw, 0)
		for _, entry in dollParts do
			entry[1].CFrame = pose * entry[2]
		end
		local eye = dollCamera.CFrame.Position
		for _, marker in panel.markers do
			local point = pose * marker.spot.point
			local x, y, depth = projectPoint(dollCamera.CFrame, dollCamera.FieldOfView, panel.aspect, point)
			local facing = pose:VectorToWorldSpace(marker.spot.normal.Unit):Dot((eye - point).Unit)
			marker.mark.Position = UDim2.fromScale(x, y)
			marker.mark.Visible = depth > 0
			local back = facing < -0.05
			marker.mark.BackgroundTransparency = if back then 0.85 else 0.4
			marker.ring.Transparency = if back then 0.7 else 0
			marker.tag.Visible = not back
		end
	end
	-- Animação: varredura descendo, giro lento quando ninguém arrasta e marca escolhida pulsando.
	function panel.step(dt: number, dragging: boolean)
		panel.scanAt = (panel.scanAt + dt / 3.2) % 1
		scan.Position = UDim2.fromScale(0, panel.scanAt * 1.14 - 0.14)
		if not dragging then
			panel.rotate(panel.yaw + dt * 0.45)
		end
		local def = panel.selected and byId[panel.selected]
		local pulse = 1 + 0.18 * math.sin(os.clock() * 6)
		for slot, marker in panel.markers do
			local size = if def and def.slot == slot then 0.07 * pulse else 0.06
			marker.mark.Size = UDim2.fromScale(size, size)
		end
	end
	panel.resize(gui.CanvasSize)
	panel.select(implants[1] and implants[1].id or "")
	panel.setState({}, 100, false)
	panel.rotate(panel.yaw)
	return panel
end
M.buildImplantPanel = buildImplantPanel

-- Monotrilho Linha Anel ---------------------------------------------------------------------------------------
-- O trem anda no viaduto em volta da cidade e é igual em todos os clientes: a posição sai da hora do servidor
-- (GetServerTimeNow), sem rede. Para na Estação Prisma com as portas abertas, acelera, corre, freia e volta à
-- estação depois de uma volta; quem estiver dentro é levado junto (cada cliente move o próprio corpo).
local TRAIN = { speed = 45, accel = 5, dwell = 14, cars = 3, length = 34, pitch = 36, floor = 1.5, bogie = 13 }
M.TRAIN = TRAIN

-- Caminho fechado a partir dos pontos (x, z) do viaduto, na altura do trilho (deck).
local function trainTrack(points, deck: number)
	local track = { segments = {}, total = 0, deck = deck }
	for index, point in points do
		local nextPoint = points[index % #points + 1]
		local a = Vector3.new(point[1], deck, point[2])
		local b = Vector3.new(nextPoint[1], deck, nextPoint[2])
		local length = (b - a).Magnitude
		if length > 1e-3 then
			table.insert(track.segments, { a = a, dir = (b - a).Unit, start = track.total, length = length })
			track.total += length
		end
	end
	return track
end
M.trainTrack = trainTrack

-- Ponto e direção a s studs do começo do caminho (dá a volta nos dois sentidos).
local function trackPoint(track, s: number): (Vector3, Vector3)
	s %= track.total
	for _, segment in track.segments do
		if s <= segment.start + segment.length then
			return segment.a + segment.dir * (s - segment.start), segment.dir
		end
	end
	local last = track.segments[#track.segments]
	return last.a + last.dir * last.length, last.dir
end
M.trackPoint = trackPoint

-- Quantos studs do começo do caminho fica o ponto do trilho mais perto de (x, z).
local function trackDistance(track, x: number, z: number): number
	local best, bestS = math.huge, 0
	local p = Vector3.new(x, track.deck, z)
	for _, segment in track.segments do
		local t = math.clamp((p - segment.a):Dot(segment.dir), 0, segment.length)
		local d = (segment.a + segment.dir * t - p).Magnitude
		if d < best then
			best, bestS = d, segment.start + t
		end
	end
	return bestS
end
M.trackDistance = trackDistance

-- Horário: parado (dwell s), acelera, corre, freia e chega de novo depois de uma volta (total studs).
-- Devolve quanto já andou desde a estação, a velocidade e quanto as portas estão abertas (0 a 1).
local function trainSchedule(t: number, total: number): (number, number, number)
	local v, a, dwell = TRAIN.speed, TRAIN.accel, TRAIN.dwell
	local ramp = v / a
	local rampDistance = v * v / (2 * a)
	local cruise = math.max(0, (total - 2 * rampDistance) / v)
	local u = t % (dwell + 2 * ramp + cruise)
	if u < dwell then
		return 0, 0, math.clamp(math.min(u - 0.6, dwell - 2 - u), 0, 1)
	end
	u -= dwell
	if u < ramp then
		return 0.5 * a * u * u, a * u, 0
	end
	u -= ramp
	if u < cruise then
		return rampDistance + v * u, v, 0
	end
	local left = math.max(0, ramp - (u - cruise))
	return total - 0.5 * a * left * left, a * left, 0
end
M.trainSchedule = trainSchedule

-- Pose de um carro cujo centro está a s studs: apoiado em dois truques (frente e trás) no trilho, então
-- faz a curva aos poucos. A origem é o chão do carro; a frente é -Z.
local function carCFrame(track, s: number): CFrame
	local front = trackPoint(track, s + TRAIN.bogie)
	local back = trackPoint(track, s - TRAIN.bogie)
	local lift = Vector3.new(0, TRAIN.floor, 0)
	return CFrame.lookAt((front + back) / 2 + lift, front + lift)
end
M.carCFrame = carCFrame

-- Um carro: casca de metal com janelas de vidro, duas portas de correr por lado, bancos, barras, faixa de
-- luz no teto e neon rosa por fora. Devolve o modelo e as peças com a pose no espaço do carro (e, nas portas,
-- para onde correm ao abrir). head/tail: faróis na frente do primeiro carro e lanternas atrás do último.
local TRAIN_BODY, TRAIN_DARK = Color3.fromRGB(58, 64, 80), Color3.fromRGB(26, 28, 36)
local function buildTrainCar(index: number, head: boolean, tail: boolean)
	local model = Instance.new("Model")
	model.Name = "Carro " .. index
	local parts = {}
	local L = TRAIN.length
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, solid: boolean, slide: Vector3?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = solid, solid, false, solid
		p.Color = color
		p.Material = material
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CFrame = offset
		p.Parent = model
		table.insert(parts, { part = p, offset = offset, slide = slide })
		return p
	end
	local glass = Color3.fromRGB(120, 170, 200)
	piece("Piso", Vector3.new(7.6, 0.5, L + 1.6), CFrame.new(0, 0.25, 0), Color3.fromRGB(44, 46, 54), Enum.Material.DiamondPlate, true)
	piece("Teto", Vector3.new(8, 0.6, L), CFrame.new(0, 8.3, 0), TRAIN_BODY, Enum.Material.Metal, true)
	local strip = piece("Luz do teto", Vector3.new(1.2, 0.1, L - 4), CFrame.new(0, 7.95, 0), Color3.fromRGB(220, 240, 255), Enum.Material.Neon, false)
	new("SurfaceLight", strip, { Face = Enum.NormalId.Bottom, Range = 12, Brightness = 1.6, Angle = 120, Color = Color3.fromRGB(210, 235, 255) })
	piece("Saia", Vector3.new(7, 1.5, L - 4), CFrame.new(0, -0.75, 0), TRAIN_DARK, Enum.Material.Metal, false)
	-- Paredes: painel de baixo, vidro e painel de cima, com dois vãos de porta (z = -8 e 8) de cada lado.
	local DOOR, DOOR_W = 8, 4.2
	local spans = { { -L / 2, -DOOR - DOOR_W / 2 }, { -DOOR + DOOR_W / 2, DOOR - DOOR_W / 2 }, { DOOR + DOOR_W / 2, L / 2 } }
	for _, side in { -1, 1 } do
		local x = side * 3.85
		for _, span in spans do
			local length, middle = span[2] - span[1], (span[1] + span[2]) / 2
			piece("Parede", Vector3.new(0.3, 3.1, length), CFrame.new(x, 2.05, middle), TRAIN_BODY, Enum.Material.Metal, true)
			piece("Janela", Vector3.new(0.2, 3, length - 0.6), CFrame.new(x, 5.1, middle), glass, Enum.Material.Glass, true).Transparency = 0.45
			piece("Coluna", Vector3.new(0.32, 3, 0.3), CFrame.new(x, 5.1, span[1] + 0.15), TRAIN_BODY, Enum.Material.Metal, true)
			piece("Coluna", Vector3.new(0.32, 3, 0.3), CFrame.new(x, 5.1, span[2] - 0.15), TRAIN_BODY, Enum.Material.Metal, true)
		end
		piece("Parede de cima", Vector3.new(0.3, 1.4, L), CFrame.new(x, 7.3, 0), TRAIN_BODY, Enum.Material.Metal, true)
		piece("Faixa", Vector3.new(0.12, 0.35, L - 1), CFrame.new(side * 4.06, 2.3, 0), Color3.fromRGB(255, 72, 140), Enum.Material.Neon, false)
		for _, center in { -DOOR, DOOR } do
			for _, half in { -1, 1 } do
				-- Folha da porta por fora da parede: abre correndo por cima dela.
				local offset = CFrame.new(side * 4.05, 3.55, center + half * DOOR_W / 4)
				local leaf = piece("Porta", Vector3.new(0.16, 6.1, DOOR_W / 2), offset, Color3.fromRGB(70, 76, 92), Enum.Material.Metal, true,
					Vector3.new(0, 0, half * (DOOR_W / 2 + 0.1)))
				leaf.CastShadow = false
				piece("Vidro da porta", Vector3.new(0.18, 2.6, DOOR_W / 2 - 0.6), offset * CFrame.new(0, 1.2, 0), glass, Enum.Material.Glass, false,
					Vector3.new(0, 0, half * (DOOR_W / 2 + 0.1))).Transparency = 0.4
			end
		end
	end
	-- Pontas: passagem para o próximo carro; na frente do primeiro e atrás do último, parede inteira.
	for _, endSide in { -1, 1 } do
		local z = endSide * (L / 2 - 0.15)
		local closed = (endSide == -1 and head) or (endSide == 1 and tail)
		if closed then
			piece("Frente", Vector3.new(7.7, 3.1, 0.3), CFrame.new(0, 2.05, z), TRAIN_BODY, Enum.Material.Metal, true)
			piece("Para-brisa", Vector3.new(7.3, 3, 0.2), CFrame.new(0, 5.1, z), glass, Enum.Material.Glass, true).Transparency = 0.35
			piece("Testa", Vector3.new(7.7, 1.4, 0.3), CFrame.new(0, 7.3, z), TRAIN_BODY, Enum.Material.Metal, true)
			for _, x in { -2.6, 2.6 } do
				local lamp = piece(if head and endSide == -1 then "Farol" else "Lanterna", Vector3.new(1.1, 0.5, 0.15),
					CFrame.new(x, 1.6, z + endSide * 0.2), if head and endSide == -1 then Color3.fromRGB(255, 250, 230) else Color3.fromRGB(255, 40, 60),
					Enum.Material.Neon, false)
				if head and endSide == -1 then
					new("SpotLight", lamp, { Face = Enum.NormalId.Front, Range = 40, Brightness = 2.2, Angle = 50, Color = Color3.fromRGB(255, 246, 225) })
				end
			end
			if head and endSide == -1 then
				local sign = piece("Letreiro", Vector3.new(4.6, 0.7, 0.12), CFrame.new(0, 7.3, z - 0.22), Color3.fromRGB(255, 72, 140), Enum.Material.Neon, false)
				sign.Transparency = 0.1
			end
		else
			for _, x in { -2.6, 2.6 } do
				piece("Ponta", Vector3.new(2.5, 7.5, 0.3), CFrame.new(x, 4.25, z), TRAIN_BODY, Enum.Material.Metal, true)
			end
			piece("Sanfona", Vector3.new(3, 7, 1.4), CFrame.new(0, 4, endSide * (L / 2 + 0.7)), TRAIN_DARK, Enum.Material.Fabric, false)
		end
	end
	-- Bancos encostados nas paredes e barras para segurar.
	for _, side in { -1, 1 } do
		for _, span in { { -16, -10.6 }, { -5.6, 5.6 }, { 10.6, 16 } } do
			local length = span[2] - span[1]
			piece("Banco", Vector3.new(1.4, 1.1, length), CFrame.new(side * 3, 1.05, (span[1] + span[2]) / 2), Color3.fromRGB(96, 40, 120), Enum.Material.Fabric, true)
			piece("Encosto", Vector3.new(0.3, 1.6, length), CFrame.new(side * 3.55, 2.4, (span[1] + span[2]) / 2), Color3.fromRGB(96, 40, 120), Enum.Material.Fabric, false)
		end
	end
	for _, z in { -DOOR, DOOR } do
		piece("Barra", Vector3.new(0.22, 7.5, 0.22), CFrame.new(0, 4.25, z), Color3.fromRGB(200, 204, 212), Enum.Material.Metal, true)
	end
	return model, parts
end
M.buildTrainCar = buildTrainCar

-- Dia e noite ---------------------------------------------------------------------------------------------------
-- Um dia de jogo dura 24 minutos (1 minuto por hora), igual para todos pela hora do servidor. Cada hora-chave
-- tem a luz da cidade; entre elas a luz mistura aos poucos. A noite é a de antes (clara, com neon forte).
local DAY_MINUTES = 24
local function dayClock(t: number): number
	return (t / (DAY_MINUTES * 60) * 24 + 20.5) % 24
end
M.dayClock = dayClock
local function c3(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local DAY_KEYS = {
	{ hour = 0, brightness = 2.3, ambient = c3(70, 66, 96), outdoor = c3(112, 108, 148), exposure = 0.4, density = 0.27,
		haze = c3(140, 128, 178), decay = c3(160, 104, 132), glare = 0.15, hazeAmount = 1.3, bloom = 0.5, threshold = 1.2,
		tint = c3(240, 236, 255), rays = 0, clouds = c3(52, 48, 74), cover = 0.32, lamps = 1 },
	{ hour = 5, brightness = 2.2, ambient = c3(66, 68, 100), outdoor = c3(104, 112, 156), exposure = 0.38, density = 0.28,
		haze = c3(120, 132, 190), decay = c3(140, 110, 160), glare = 0.1, hazeAmount = 1.4, bloom = 0.5, threshold = 1.2,
		tint = c3(236, 238, 255), rays = 0, clouds = c3(60, 60, 90), cover = 0.34, lamps = 1 },
	{ hour = 6.4, brightness = 2.6, ambient = c3(112, 92, 108), outdoor = c3(176, 132, 140), exposure = 0.25, density = 0.33,
		haze = c3(255, 172, 150), decay = c3(255, 120, 112), glare = 0.6, hazeAmount = 2.2, bloom = 0.45, threshold = 1.35,
		tint = c3(255, 236, 226), rays = 0.14, clouds = c3(255, 186, 166), cover = 0.5, lamps = 0.6 },
	{ hour = 8.5, brightness = 3, ambient = c3(120, 120, 130), outdoor = c3(150, 152, 166), exposure = 0.1, density = 0.3,
		haze = c3(199, 215, 235), decay = c3(120, 140, 180), glare = 0.3, hazeAmount = 1.2, bloom = 0.35, threshold = 1.6,
		tint = c3(250, 250, 255), rays = 0.06, clouds = c3(255, 255, 255), cover = 0.55, lamps = 0.3 },
	{ hour = 12.5, brightness = 3.2, ambient = c3(126, 126, 136), outdoor = c3(156, 158, 172), exposure = 0, density = 0.28,
		haze = c3(199, 215, 235), decay = c3(106, 128, 170), glare = 0.2, hazeAmount = 1, bloom = 0.32, threshold = 1.7,
		tint = c3(255, 255, 255), rays = 0.05, clouds = c3(255, 255, 255), cover = 0.5, lamps = 0.3 },
	{ hour = 16.5, brightness = 3, ambient = c3(130, 118, 118), outdoor = c3(166, 150, 146), exposure = 0.08, density = 0.3,
		haze = c3(232, 202, 182), decay = c3(180, 122, 112), glare = 0.35, hazeAmount = 1.4, bloom = 0.36, threshold = 1.55,
		tint = c3(255, 246, 236), rays = 0.08, clouds = c3(255, 236, 220), cover = 0.55, lamps = 0.35 },
	{ hour = 18.3, brightness = 2.5, ambient = c3(120, 90, 110), outdoor = c3(190, 120, 132), exposure = 0.25, density = 0.35,
		haze = c3(255, 140, 120), decay = c3(255, 90, 120), glare = 0.8, hazeAmount = 2.5, bloom = 0.45, threshold = 1.3,
		tint = c3(255, 232, 226), rays = 0.16, clouds = c3(255, 150, 140), cover = 0.5, lamps = 0.75 },
	{ hour = 19.6, brightness = 2.3, ambient = c3(80, 70, 110), outdoor = c3(120, 100, 160), exposure = 0.35, density = 0.3,
		haze = c3(150, 120, 190), decay = c3(190, 100, 150), glare = 0.3, hazeAmount = 1.6, bloom = 0.5, threshold = 1.2,
		tint = c3(244, 236, 255), rays = 0, clouds = c3(90, 70, 120), cover = 0.4, lamps = 1 },
}
M.DAY_KEYS = DAY_KEYS
-- Luz da cidade numa hora qualquer: mistura as duas horas-chave em volta (dá a volta da meia-noite).
local function dayLight(hour: number)
	hour %= 24
	local count = #DAY_KEYS
	local a, b = DAY_KEYS[count], DAY_KEYS[1]
	for index = 1, count do
		local key = DAY_KEYS[index]
		if key.hour <= hour then
			a, b = key, DAY_KEYS[index % count + 1]
		end
	end
	local span = (b.hour - a.hour) % 24
	local t = if span > 0 then ((hour - a.hour) % 24) / span else 0
	t = t * t * (3 - 2 * t)
	local out = {}
	for key, value in a do
		local other = b[key]
		if typeof(value) == "Color3" then
			out[key] = value:Lerp(other, t)
		elseif type(value) == "number" then
			out[key] = value + (other - value) * t
		end
	end
	out.hour = hour
	return out
end
M.dayLight = dayLight
-- O céu de dia é o padrão do Roblox; o céu desenhado de Maré Baixa só aparece à noite.
local function nightSky(hour: number): boolean
	hour %= 24
	return hour >= 19 or hour < 5.6
end
M.nightSky = nightSky

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
			if type(SOUNDS[key]) == "number" or LIBRARY[key] then
				return key
			end
		end
		return (...)
	end
	-- IDs da biblioteca que não carregaram (o jogo cai para o som próprio da mesma chave).
	local libraryFailed: { [number]: boolean } = {}
	task.spawn(function()
		local probes, seen = {}, {}
		for _, entry in LIBRARY do
			if not seen[entry.id] then
				seen[entry.id] = true
				local probe = Instance.new("Sound")
				probe.SoundId = string.format("rbxassetid://%.0f", entry.id)
				table.insert(probes, probe)
			end
		end
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(probes, function(content, status)
				if status == Enum.AssetFetchStatus.Failure then
					local id = tonumber(string.match(tostring(content), "%d+"))
					if id then
						libraryFailed[id] = true
					end
				end
			end)
		end)
		for _, probe in probes do
			probe:Destroy()
		end
	end)
	local function sound(key: string, parent: Instance?, volume: number?): Sound?
		local entry = LIBRARY[key]
		local useLibrary = entry ~= nil and not libraryFailed[entry.id]
		local id = if useLibrary then entry.id else SOUNDS[key]
		if type(id) ~= "number" or id <= 0 then
			return nil
		end
		local item = Instance.new("Sound")
		item.SoundId = string.format("rbxassetid://%.0f", id)
		item.Volume = (volume or 0.6) * (if useLibrary then entry.vol else 1)
		item.RollOffMaxDistance = if string.sub(key, 1, 5) == "arma_" then 520 else 260
		item.RollOffMinDistance = if string.sub(key, 1, 5) == "arma_" then 18 else 10
		local life = 4
		if useLibrary then
			local jitter = entry.jitter or 0
			item.PlaybackSpeed = (entry.speed or 1) * (1 + (rng:NextNumber() * 2 - 1) * jitter)
			if entry.region then
				item.PlaybackRegionsEnabled = true
				item.PlaybackRegion = NumberRange.new(entry.region[1], entry.region[2])
				life = (entry.region[2] - entry.region[1]) / item.PlaybackSpeed + 0.3
			end
		end
		-- Sem pai: toca em 2D (no SoundService), e não pelo PlayLocalSound, que ignora o trecho cortado.
		item.Parent = parent or SoundService
		item:Play()
		item.Ended:Once(function()
			item:Destroy()
		end)
		task.delay(math.max(life, 6), function()
			if item.Parent then
				item:Destroy()
			end
		end)
		return item
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
		lastInput = 0, trauma = 0, kick = 0, kickYaw = 0, side = 1, deathSpin = 0, punch = 0,
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
	-- Sandevistan e surto: o servidor marca o personagem com a hora (GetServerTimeNow) em que cada um acaba.
	local function serverNow(): number
		return Workspace:GetServerTimeNow()
	end
	local function timeAttr(model: Instance?, name: string): number
		local value = model and model:GetAttribute(name)
		return if type(value) == "number" then value else 0
	end
	local function boosted(model: Instance?): boolean
		return timeAttr(model, "CyberOutlawSandevistanAte") > serverNow()
	end
	local function raving(model: Instance?): boolean
		return timeAttr(model, "CyberOutlawSurtoAte") > serverNow()
	end
	local function slowedDown(model: Instance?): boolean
		return timeAttr(model, "CyberOutlawLentoAte") > serverNow()
	end
	local sandevistanStats = { duracao = 4, recarga = 1.5, custo = 25, surto = 2, lento = 0.3, cadencia = 2, velocidade = 2.2 }
	local abilityFov = 0
	local abilityFx = { flashAt = -10, rageAt = -10 }

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
	local terminalLayout: ((Vector2, any) -> ())? -- idem: tamanho do terminal quando a tela muda
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
		if terminalLayout then
			terminalLayout(size, l)
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

	-- Impacto: som carnudo, tranco na câmera, zoom curto, sangue/faíscas, o alvo pisca e dá um solavanco.
	local hitFlash = Instance.new("Highlight")
	hitFlash.Name = "CyberOutlawAcerto"
	hitFlash.FillColor = Color3.new(1, 1, 1)
	hitFlash.OutlineColor = Color3.fromRGB(255, 60, 80)
	hitFlash.FillTransparency = 1
	hitFlash.OutlineTransparency = 1
	hitFlash.DepthMode = Enum.HighlightDepthMode.Occluded
	hitFlash.Parent = camera
	local flashAt = -10
	local function targetNear(position: Vector3): Model?
		local best, bestDistance = nil, 5
		local function test(model: Instance?)
			local rootPart = model and model:FindFirstChild("HumanoidRootPart")
			if model and model ~= character and rootPart and rootPart:IsA("BasePart") then
				local distance = (rootPart.Position - position).Magnitude
				if distance < bestDistance then
					best, bestDistance = model :: Model, distance
				end
			end
		end
		for _, other in Players:GetPlayers() do
			test(other.Character)
		end
		local npcs = Workspace:FindFirstChild("CyberOutlawNPCs")
		for _, model in if npcs then npcs:GetChildren() else {} do
			test(model)
		end
		return best
	end
	local function impact(position: Vector3, normal: Vector3?, heavy: boolean?)
		local target = targetNear(position)
		local headHit = false
		if target then
			local targetHead = target:FindFirstChild("Head")
			headHit = targetHead ~= nil and targetHead:IsA("BasePart") and (targetHead.Position - position).Magnitude < 1.1
			hitFlash.Adornee = target
			flashAt = os.clock()
			local state = poses[target] or {}
			poses[target] = state
			local rootPart = target:FindFirstChild("HumanoidRootPart")
			local push = if rootPart and rootPart:IsA("BasePart") and root then rootPart.CFrame:VectorToObjectSpace((rootPart.Position - root.Position).Unit) else Vector3.zAxis
			state.hurtAt = os.clock()
			state.hurtPitch = math.clamp(push.Z, -1, 1) * (if heavy then 0.55 else 0.32)
			state.hurtRoll = math.clamp(-push.X, -1, 1) * (if heavy then 0.45 else 0.26)
		end
		sound("acerto", nil, if heavy then 1 else 0.85)
		if headHit then
			sound("acerto_cabeca", nil, 0.9)
		end
		cam.trauma = math.min(1, cam.trauma + (if heavy then 0.32 else 0.16))
		cam.punch = math.min(1.6, (cam.punch or 0) + (if heavy then 1 else 0.55))
		spark(position, Color3.fromRGB(190, 10, 30), if heavy then 14 else 9, normal)
		spark(position, Color3.fromRGB(255, 220, 160), 4, normal)
		combat.hit(headHit)
	end
	RunService.RenderStepped:Connect(function()
		local age = os.clock() - flashAt
		local alpha = math.clamp(age / 0.18, 0, 1)
		hitFlash.FillTransparency = 0.35 + 0.65 * alpha
		hitFlash.OutlineTransparency = alpha
		if alpha >= 1 then
			hitFlash.Adornee = nil
		end
	end)

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
		local boost = if boosted(character) then sandevistanStats.cadencia else 1
		nextMelee = now + 1 / (weapon.rate * boost)
		meleeSide = -meleeSide
		-- Implantes de braço trocam o soco (o servidor confere e aplica o dano).
		local arms = abilityFx.implants
		local kind = weapon.id
		if weapon.id == "punhos" and arms then
			kind = if arms.louva then "louva" elseif arms.gorila then "gorila" else kind
		end
		poses[character] = poses[character] or {}
		poses[character].swingStart = now
		poses[character].swingKind = kind
		poses[character].swingSide = meleeSide
		if kind == "louva" then
			sound(pick("arma_lamina", "arma_soco"), nil, 0.6)
			-- Correndo, as lâminas dão um salto de ataque para a frente.
			if root and root.AssemblyLinearVelocity.Magnitude > 12 then
				root.AssemblyLinearVelocity += root.CFrame.LookVector * 42 + Vector3.new(0, 14, 0)
			end
		elseif kind == "gorila" then
			sound(pick("soco_gorila", "arma_soco"), nil, 0.7)
			cam.trauma = math.min(1, cam.trauma + 0.12)
		else
			sound(weapon.som or "arma_soco", nil, 0.55)
		end
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
		if not character or not head or dead or raving(character) then
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
		nextShot = now + 1 / (weapon.rate * (if boosted(character) then sandevistanStats.cadencia else 1))
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
		-- Tiro próprio: a versão pesada (grave reforçado) bem alta, e um segundo baque grave por baixo.
		local shotKey = weapon.som or ("arma_" .. weapon.id)
		-- Disparo gravado da biblioteca e, por baixo, o reforço grave (a versão "pesada" enviada pelo midia).
		sound(shotKey, nil, 1)
		if type(SOUNDS[shotKey .. "_pesada"]) == "number" then
			sound(shotKey .. "_pesada", nil, 0.45)
		end
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
			-- Tiros dos NPCs armados chegam com o modelo do NPC no lugar do jogador.
			local npcModel = typeof(who) == "Instance" and who:IsA("Model") and kind == "tiro"
			if not npcModel and (typeof(who) ~= "Instance" or not who:IsA("Player")) then
				return
			end
			local model = if npcModel then who else who.Character
			local weapon = byId[id]
			if kind == "sandevistan" then
				-- Ativou: som com cauda longa no corpo de quem ativou; na própria tela, clarão e o surto se vier.
				local rootPart = model and model:FindFirstChild("HumanoidRootPart")
				if who == player then
					abilityFx.flashAt = os.clock()
					-- O mundo para: estrondo subgrave gravado (o pulso e a volta ficam no sandiStep).
					sound("tempo_estrondo", nil, 1)
					if b == true then
						abilityFx.rageAt = os.clock()
						task.delay(0.15, sound, "surto_estatica", nil, 1)
					end
				elseif rootPart then
					sound("tempo_estrondo", rootPart, 0.9)
				end
				return
			end
			if kind == "surto" then
				kind = "tiro"
				if who == player and type(b) == "table" then
					-- Os tiros do surto não saíram deste cliente: desenha como os de outro jogador.
					who = nil :: any
				end
			end
			if kind == "tiro" and type(b) == "table" then
				if who == player then
					for _, hit in b do
						if hit[3] and typeof(hit[1]) == "Vector3" then
							impact(hit[1], if typeof(hit[2]) == "Vector3" then hit[2] else nil, weapon ~= nil and (weapon.damage or 0) >= 40)
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
					local shotKey = if weapon and weapon.som then weapon.som else "arma_" .. tostring(id)
					sound(shotKey, emitter, 1)
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
				impact(b + Vector3.new(0, 0.5, 0), nil, id == "gorila" or id == "louva" or id == "faca")
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
		sound("ui_abrir", nil, 0.35)
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
			sound("ui_fechar", nil, 0.3)
		end
	end

	if wheel then
		for index, entry in wheel.cards do
			entry.card.MouseEnter:Connect(function()
				if wheelOpen and wheelSelection ~= index then
					wheelSelection = index
					wheel.select(index, ammoTable)
					sound("ui_tick", nil, 0.3)
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
				sound("ui_tick", nil, 0.3)
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
			if not processed and not wheelOpen and not implantsOpen and input.Position.X > camera.ViewportSize.X * 0.35 then
				touchCamera[input] = input.Position
			end
			return
		end
		if processed or typing() then
			return
		end
		local key = input.KeyCode
		if raving(character) then
			return -- ciberpsicose: o implante assumiu o controle
		end
		-- Implantes (I) e habilidade (X); com o terminal aberto, o resto do jogo espera.
		if key == Enum.KeyCode.I or key == Enum.KeyCode.DPadDown then
			if toggleImplants then
				toggleImplants()
			end
			return
		elseif implantsOpen then
			if key == Enum.KeyCode.ButtonB then
				if toggleImplants then
					toggleImplants(false)
				end
			end
			return
		elseif key == Enum.KeyCode.X or key == Enum.KeyCode.DPadUp then
			if useAbility then
				useAbility()
			end
			return
		end
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
						sound("ui_tick", nil, 0.3)
					end
				end
			elseif not processed and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter and not raving(character) then
				local factor = 0.0042 * sensitivity * (if aiming then 0.62 else 1)
				cam.yaw -= input.Delta.X * factor
				cam.pitch -= input.Delta.Y * factor
				cam.lastInput = os.clock()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed and not wheelOpen then
			cycle(if input.Position.Z > 0 then -1 else 1)
		elseif input.UserInputType == Enum.UserInputType.Touch and touchCamera[input] and not raving(character) then
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
		if raving(character) then
			cam.yaw += angleDelta(cam.yaw, facingYaw) * math.min(1, dt * 2.5)
			cam.pitch += (math.rad(-12) - cam.pitch) * math.min(1, dt * 2)
		end
		cam.pitch = math.clamp(cam.pitch, math.rad(-72), math.rad(62))

		local scoped = aimingNow and weapon.luneta == true
		local targetDistance = if not alive then 16
			elseif scoped then 0.5
			elseif aimingNow then (if weapon.tipo == "fuzil" then 4.6 else 5.6)
			elseif sprinting then 13
			elseif gun then 9 -- com arma na mão a câmera chega mais perto: dá para ver a arma
			else 11.5
		local targetShoulder = (if aimingNow or raised then 2.1 else 1.35) * cam.side
		local targetFov = (if aimingNow then (weapon.fov or 54) elseif sprinting then 77 else 70) + abilityFov
		if aimingNow and not (weapon.luneta == true) and abilityFx.implants and abilityFx.implants.kiroshi then
			targetFov -= 14 -- Ópticos Kiroshi: zoom forte na mira
		end
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
		cam.punch = (cam.punch or 0) * math.exp(-dt * 12)
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
		camera.FieldOfView = cam.fov - (cam.punch or 0) * 3
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
		local active, frenzy = boosted(character), raving(character)
		local factor = abilitySpeed(active, slowedDown(character), frenzy, sandevistanStats)
		-- Andar e correr no ritmo das animações originais; mirando (corpo virado para a câmera) cada direção tem
		-- o seu limite, para a passada de lado não escorregar.
		local localMove = root.CFrame:VectorToObjectSpace(moveDirection)
		local base = if raised then strafeSpeed(localMove.X, localMove.Z) elseif sprinting then MOTION.sprint else MOTION.walk
		local target = base * factor
		speed += (target - speed) * math.min(1, dt * (if active then 12 else 6))
		humanoid.WalkSpeed = speed
		-- Facing: when aiming, the body follows the camera; otherwise it turns smoothly toward the movement.
		if raised then
			facingYaw = cam.yaw
			align.Responsiveness = 45
		elseif moving then
			facingYaw = math.atan2(-moveDirection.X, -moveDirection.Z)
			align.Responsiveness = if sprinting then 11 else 16
		end
		-- Surto (30 s): o implante assume. O corpo corre atrás do alvo que o servidor escolheu (jogador ou NPC)
		-- ou vaga procurando alguém; o controle e a câmera não respondem (o servidor atira sozinho).
		if frenzy then
			local name = character:GetAttribute("CyberOutlawSurtoAlvo")
			local targetRoot
			if type(name) == "string" and name ~= "" then
				local owner = Players:FindFirstChild(name)
				local model = if owner and owner:IsA("Player") then owner.Character else nil
				if not model then
					local npcs = Workspace:FindFirstChild("CyberOutlawNPCs")
					model = npcs and npcs:FindFirstChild(name)
				end
				local part = model and model:FindFirstChild("HumanoidRootPart")
				targetRoot = if part and part:IsA("BasePart") then part else nil
			end
			local heading = Vector3.zero
			if targetRoot then
				local offset = targetRoot.Position - root.Position
				facingYaw = math.atan2(-offset.X, -offset.Z)
				if offset.Magnitude > 10 then
					heading = Vector3.new(offset.X, 0, offset.Z).Unit
				end
			else
				local clock = os.clock()
				if not abilityFx.wanderAt or clock > abilityFx.wanderAt then
					abilityFx.wanderAt = clock + rng:NextNumber(0.8, 1.8)
					abilityFx.wanderYaw = facingYaw + rng:NextNumber(-2.2, 2.2)
				end
				facingYaw += angleDelta(facingYaw, abilityFx.wanderYaw) * math.min(1, dt * 4)
				heading = Vector3.new(-math.sin(facingYaw), 0, -math.cos(facingYaw))
			end
			humanoid:Move(heading, false)
			align.Responsiveness = 60
		end
		align.CFrame = CFrame.Angles(0, facingYaw, 0)
	end

	-- Arm and head pose (PreSimulation: after the animation, before the physics).
	local SWING = { punhos = 0.26, faca = 0.38, louva = 0.34, gorila = 0.4 }
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
		if model:GetAttribute("CyberOutlawMaosAlto") == true then
			-- Camelô rendido: mãos para cima.
			right.Transform = jointTransform(right.C0, right.C1, armRotation(Vector3.new(0.15, 1, -0.1).Unit, Vector3.new(0, 0, 1)))
			left.Transform = jointTransform(left.C0, left.C1, armRotation(Vector3.new(-0.15, 1, -0.1).Unit, Vector3.new(0, 0, 1)))
			return
		end
		local id = model:GetAttribute("CyberOutlawArma")
		local weapon = byId[id]
		local state = poses[model]
		if state and state.hurtAt then
			-- Solavanco de quem levou o tiro: o tronco tomba para trás e volta.
			local k = 1 - (now - state.hurtAt) / 0.3
			local joint = model:FindFirstChild("HumanoidRootPart") and model.HumanoidRootPart:FindFirstChild("RootJoint")
			if k <= 0 then
				state.hurtAt = nil
			elseif joint and joint:IsA("Motor6D") then
				joint.Transform = joint.Transform * CFrame.Angles(state.hurtPitch * k * k, 0, state.hurtRoll * k * k)
			end
		end
		local isLocal = model == character
		local pitch = if isLocal then cam.pitch else math.rad(model:GetAttribute("CyberOutlawPitch") or 0)
		local aimed = if isLocal then (aiming or aimToggle or raving(model)) else model:GetAttribute("CyberOutlawMirando") == true
		local firedRecently = state and state.firedAt and now - state.firedAt < 0.7
		-- Direções no espaço do personagem, levadas para o tronco (a animação pode inclinar o tronco).
		local rootPartNow = model:FindFirstChild("HumanoidRootPart")
		local rootJoint = rootPartNow and rootPartNow:FindFirstChild("RootJoint")
		local tilt = if rootJoint and rootJoint:IsA("Motor6D") then torsoTilt(rootJoint.C0, rootJoint.Transform, rootJoint.C1) else CFrame.identity
		local up = tilt:VectorToObjectSpace(Vector3.new(0, 1, 0))
		if state and state.swingStart then
			local duration = SWING[state.swingKind] or 0.3
			local t = (now - state.swingStart) / duration
			if t < 1 then
				local arm = if state.swingSide == -1 and state.swingKind == "punhos" then left else right
				local side = if arm == left then -1 else 1
				local direction = tilt:VectorToObjectSpace(swingDirection(state.swingKind, side, t))
				arm.Transform = jointTransform(arm.C0, arm.C1, armRotation(direction, up))
				return
			end
			state.swingStart = nil
		end
		if not weapon or weapon.kind ~= "gun" then
			if weapon and weapon.id == "faca" then
				right.Transform = jointTransform(right.C0, right.C1, armRotation(tilt:VectorToObjectSpace(Vector3.new(0.12, -0.72, -0.68).Unit), up))
			end
			return
		end
		local direction
		if aimed or firedRecently then
			direction = Vector3.new(0, math.sin(pitch), -math.cos(pitch))
		else
			direction = Vector3.new(0.05, -0.55, -0.83).Unit
		end
		right.Transform, left.Transform = gunArms(tilt, right.C0, right.C1, left.C0, left.C1, direction, weapon.alcance or 2.45)
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
		if gait and gait.neckPose then
			-- Animação original no pescoço (respiração do idle, balanço da caminhada) e o olhar por cima dela.
			joints.neck.Transform = jointTransform(joints.neck.C0, joints.neck.C1, rotation) * gait.neckPose
			return
		end
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
		return "r6"
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

	-- Pacote "r6" (padrão): as 10 animações originais. No chão, parado/8 direções/corrida frontal com as poses
	-- dos arquivos; no ar (pulo e queda) a pose procedural de antes, misturada aos poucos; sentado, nadando,
	-- escalando ou morto, nada é escrito (fica o que o Roblox já faz). Braços com arma e golpes vêm depois
	-- (poseCharacter, a camada de ação), e a cabeça olha para a câmera por cima da pose do pescoço.
	local function r6Character(model: Model, g, rootPart: BasePart, body: BasePart, state: string, velocity: Vector3, distance: number, dt: number)
		dropProxy(model)
		local m = g.motion
		if not m then
			m = newMotion()
			g.motion = m
			g.ground = 1
		end
		local grounded = state == "run" or state == "idle"
		local planar = Vector3.new(velocity.X, 0, velocity.Z)
		-- Direção: o próprio jogador usa a intenção do controle (MoveDirection, inclui o analógico do celular);
		-- os outros, a velocidade que chega pela rede. Sempre no espaço do HumanoidRootPart.
		local moveWorld = if model == character and humanoid and humanoid.MoveDirection.Magnitude > 0.05 then humanoid.MoveDirection else planar
		local moveLocal = rootPart.CFrame:VectorToObjectSpace(moveWorld)
		local pose, step = motionStep(m, { move = moveLocal, speed = if grounded then planar.Magnitude else 0 }, dt)
		-- Postura de ação: arma de fogo ou faca na mão, mirando ou golpeando tira o corpo do idle agachado.
		local held = byId[model:GetAttribute("CyberOutlawArma")]
		local swing = poses[model]
		local acting = (held ~= nil and held.id ~= "punhos")
			or (swing ~= nil and swing.swingStart ~= nil and os.clock() - swing.swingStart < 0.8)
			or (model == character and (aiming or aimToggle))
			or model:GetAttribute("CyberOutlawMirando") == true
		g.stance = (g.stance or 0) + ((if acting then 1 else 0) - (g.stance or 0)) * math.min(1, dt * 9)
		local stance = g.stance * m.weights.idle
		-- A pose procedural cuida do ar e do pouso; também guarda o peso de "ocupado" (sentado, morto...).
		local procedural = gaitStep(g, {
			velocity = rootPart.CFrame:VectorToObjectSpace(velocity), state = state,
			yawRate = rootPart.AssemblyAngularVelocity.Y, verticalSpeed = velocity.Y,
		}, dt)
		g.pose = procedural
		g.ground += ((if grounded then 1 else 0) - g.ground) * math.min(1, dt * 10)
		local w = procedural.weight
		g.neckPose = nil
		if w < 0.01 then
			return
		end
		for index, info in R6_JOINTS do
			local motor = if index == 1 then rootPart:FindFirstChild(info.motor) else body:FindFirstChild(info.motor)
			if motor and motor:IsA("Motor6D") then
				local target = pose[index]
				if stance > 0.01 and index ~= 3 and index ~= 4 then
					target = target:Lerp(aimStance(index, motor.C0, motor.C1), stance)
				end
				if g.ground < 0.999 then
					local air
					if index == 1 then
						air = rootTransform(motor.C0, procedural.root)
					elseif index == 2 then
						air = jointTransform(motor.C0, motor.C1, procedural.headCompensation)
					else
						local direction = ({ nil, nil, procedural.rightArm, procedural.leftArm, procedural.rightLeg, procedural.leftLeg })[index]
						air = jointTransform(motor.C0, motor.C1, armRotation(direction, UP))
					end
					target = air:Lerp(target, g.ground)
				end
				if index == 2 then
					g.neckPose = target
					if model ~= character then
						-- Outros jogadores: olham para onde miram, por cima do pescoço da animação.
						local pitch = if model:GetAttribute("CyberOutlawMirando") then math.rad(model:GetAttribute("CyberOutlawPitch") or 0) else 0
						local look = CFrame.lookAt(Vector3.zero, Vector3.new(0, math.sin(pitch), -math.cos(pitch)))
						blend(motor, jointTransform(motor.C0, motor.C1, look) * target, w)
					end
				else
					blend(motor, target, w)
				end
			end
		end
		if step ~= 0 and distance < 70 then
			footstep(model, step)
		end
	end

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
		if currentPack() == "r6" and body:IsA("BasePart") then
			r6Character(model, g, rootPart, body, state, velocity, distance, dt)
			return
		end
		g.neckPose = nil
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

	-- Monotrilho: os carros andam no mesmo horário em todos os clientes; quem está em pé num carro vai junto.
	-- (Numa função à parte: o start() já está no limite de variáveis locais do Luau.)
	local trainStep = (function()
		local folder = Instance.new("Folder")
		folder.Name = "CyberOutlawTrem"
		folder.Parent = Workspace
		local rideParams = RaycastParams.new()
		rideParams.FilterType = Enum.RaycastFilterType.Include
		rideParams.FilterDescendantsInstances = { folder }
		local cars, track, station
		local partList, frameList = {}, {}
		local function ensure(): boolean
			if cars then
				return true
			end
			local layout = cityLayout
			if type(layout) ~= "table" or type(layout.monorail) ~= "table" or #layout.monorail < 3 then
				return false
			end
			track = trainTrack(layout.monorail, tonumber(layout.deck) or 66)
			local spot = layout.station
			station = if type(spot) == "table" then trackDistance(track, spot[1], spot[2]) else 0
			cars = {}
			for index = 1, TRAIN.cars do
				local model, parts = buildTrainCar(index, index == 1, index == TRAIN.cars)
				model.Parent = folder
				cars[index] = { model = model, parts = parts }
			end
			return true
		end
		return function(_dt: number)
			if not ensure() then
				return
			end
			local traveled, _, open = trainSchedule(serverNow(), track.total)
			table.clear(partList)
			table.clear(frameList)
			local middle = math.ceil(TRAIN.cars / 2)
			for index, car in cars do
				-- O carro do meio para no centro da plataforma; o primeiro vai na frente.
				local pose = carCFrame(track, station + traveled + (middle - index) * TRAIN.pitch)
				car.previous, car.pose = car.pose, pose
				for _, entry in car.parts do
					table.insert(partList, entry.part)
					table.insert(frameList, if entry.slide then pose * CFrame.new(entry.slide * open) * entry.offset else pose * entry.offset)
				end
			end
			Workspace:BulkMoveTo(partList, frameList, Enum.BulkMoveMode.FireCFrameChanged)
			-- Carona: em pé num carro, o corpo, o rumo e a câmera andam e viram junto com ele.
			if not root or not humanoid or humanoid.Health <= 0 then
				return
			end
			local hit = Workspace:Raycast(root.Position, Vector3.new(0, -4.6, 0), rideParams)
			if not hit then
				return
			end
			for _, car in cars do
				if car.previous and hit.Instance:IsDescendantOf(car.model) then
					local delta = car.pose * car.previous:Inverse()
					local before = root.Position
					root.CFrame = delta * root.CFrame
					local _, turn = delta:ToEulerAnglesYXZ()
					facingYaw += turn
					cam.yaw += turn
					local moved = root.Position - before
					if cam.focus then
						cam.focus += Vector3.new(moved.X, 0, moved.Z)
						cam.height += moved.Y
					end
					break
				end
			end
		end
	end)()

	-- Dia e noite: 24 minutos por dia, a mesma hora para todos. Luz, névoa, nuvens, raios de sol e o brilho
	-- dos postes mudam aos poucos; o céu desenhado de Maré Baixa fica para a noite e o de dia é o do Roblox.
	local dayStep = (function()
		local Lighting = game:GetService("Lighting")
		local sky = Lighting:FindFirstChildOfClass("Sky")
		local FACES = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }
		local DAY_FACES = {
			SkyboxBk = "rbxassetid://6444884337", SkyboxDn = "rbxassetid://6444884785", SkyboxFt = "rbxassetid://6444884337",
			SkyboxLf = "rbxassetid://6444884337", SkyboxRt = "rbxassetid://6444884337", SkyboxUp = "rbxassetid://6412503613",
		}
		local nightFaces = {}
		local nightBodies, nightStars = true, 400
		local custom = false
		if sky then
			for _, key in FACES do
				nightFaces[key] = (sky :: any)[key]
			end
			nightBodies, nightStars = sky.CelestialBodiesShown, sky.StarCount
			custom = nightFaces.SkyboxUp ~= DAY_FACES.SkyboxUp and string.find(tostring(nightFaces.SkyboxUp), "rbxassetid") ~= nil
		end
		local dayFaces = DAY_FACES
		if custom then
			-- Se o céu padrão não carregar, usa o céu clássico que vem dentro do Roblox.
			task.spawn(function()
				local probe = Instance.new("Sky")
				for key, value in DAY_FACES do
					(probe :: any)[key] = value
				end
				local failed = false
				pcall(function()
					game:GetService("ContentProvider"):PreloadAsync({ probe }, function(_, status)
						if status == Enum.AssetFetchStatus.Failure then
							failed = true
						end
					end)
				end)
				probe:Destroy()
				if failed then
					local classic = {}
					for key in DAY_FACES do
						classic[key] = "rbxasset://textures/sky/sky512_" .. string.lower(string.sub(key, 7)) .. ".tex"
					end
					dayFaces = classic
				end
			end)
		end
		local haze = Lighting:FindFirstChildOfClass("Atmosphere")
		local bloom = Lighting:FindFirstChild("CyberOutlawCityBloom")
		local grade = Lighting:FindFirstChild("CyberOutlawCityGrade")
		local rays = Instance.new("SunRaysEffect")
		rays.Name = "CyberOutlawSol"
		rays.Intensity = 0
		rays.Spread = 0.55
		rays.Parent = Lighting
		local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
		if not clouds then
			local made = Instance.new("Clouds")
			made.Name = "CyberOutlawNuvens"
			made.Density = 0.55
			made.Parent = Workspace.Terrain
			clouds = made
		end
		-- Postes, letreiros e janelas acesas: de dia ficam mais fracos (as do trem e dos efeitos não mudam).
		local lamps = {}
		local level = 1
		local function track(item: Instance)
			if item:IsA("Light") and not item:IsDescendantOf(camera) and not item:IsDescendantOf(Workspace:FindFirstChild("CyberOutlawTrem") or camera) then
				table.insert(lamps, { item, item.Brightness })
				item.Brightness *= level
			end
		end
		task.defer(function()
			for _, item in Workspace:GetDescendants() do
				track(item)
			end
			Workspace.DescendantAdded:Connect(track)
		end)
		local nightNow
		local wait = 0
		return function(dt: number)
			wait -= dt
			if wait > 0 then
				return
			end
			wait = 0.1
			local hour = dayClock(serverNow())
			local light = dayLight(hour)
			Lighting.ClockTime = hour
			Lighting.Brightness = light.brightness
			Lighting.Ambient = light.ambient
			Lighting.OutdoorAmbient = light.outdoor
			Lighting.ExposureCompensation = light.exposure
			if haze then
				haze.Density, haze.Color, haze.Decay = light.density, light.haze, light.decay
				haze.Glare, haze.Haze = light.glare, light.hazeAmount
			end
			if bloom and bloom:IsA("BloomEffect") then
				bloom.Intensity, bloom.Threshold = light.bloom, light.threshold
			end
			if grade and grade:IsA("ColorCorrectionEffect") then
				grade.TintColor = light.tint
			end
			rays.Intensity = light.rays
			clouds.Color, clouds.Cover = light.clouds, light.cover
			if sky and custom then
				local night = nightSky(hour)
				if night ~= nightNow then
					nightNow = night
					for key, value in (if night then nightFaces else dayFaces) do
						(sky :: any)[key] = value
					end
					sky.CelestialBodiesShown = if night then nightBodies else true
					sky.StarCount = if night then nightStars else 0
				end
			end
			if math.abs(light.lamps - level) > 0.02 then
				level = light.lamps
				for index = #lamps, 1, -1 do
					local entry = lamps[index]
					if entry[1].Parent then
						entry[1].Brightness = entry[2] * level
					else
						lamps[index] = lamps[#lamps]
						lamps[#lamps] = nil
					end
				end
			end
		end
	end)()

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
		-- NPCs da cidade (pedestres, gangues, polícia): mesma animação R6 dos jogadores.
		local npcs = Workspace:FindFirstChild("CyberOutlawNPCs")
		if npcs then
			for _, model in npcs:GetChildren() do
				if model:IsA("Model") then
					pcall(gaitCharacter, model, dt)
					pcall(poseCharacter, model, now)
				end
			end
		end
		pcall(headStep, dt)
		pcall(trainStep, dt)
	end
	local preSimulation = if (RunService :: any).PreSimulation then (RunService :: any).PreSimulation else RunService.Stepped
	preSimulation:Connect(function(a, b)
		onPreSimulation(if type(b) == "number" then b else a)
	end)

	-- Sons do corpo: os sons padrão do Roblox (pulo, queda, corrida...) ficam mudos; no lugar, pulo e
	-- aterrissagem gravados de verdade (passos em pedra, CC0), e os passos do próprio jogo.
	do
		local MUTE = { Jumping = true, Landing = true, FreeFalling = true, Running = true, GettingUp = true, Climbing = true, Splash = true, Swimming = true }
		local function body(model: Model)
			local rootPart = model:WaitForChild("HumanoidRootPart", 10)
			local hum = model:WaitForChild("Humanoid", 10)
			if not rootPart or not hum or not rootPart:IsA("BasePart") or not hum:IsA("Humanoid") then
				return
			end
			local function mute(item: Instance)
				if item:IsA("Sound") and MUTE[item.Name] then
					item.Volume = 0
				end
			end
			for _, item in rootPart:GetChildren() do
				mute(item)
			end
			rootPart.ChildAdded:Connect(mute)
			local falling = 0
			hum.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Jumping then
					sound("pulo", rootPart, if model == character then 0.55 else 0.4)
				elseif new == Enum.HumanoidStateType.Freefall then
					falling = 0
				elseif new == Enum.HumanoidStateType.Landed then
					local speed = math.max(falling, -rootPart.AssemblyLinearVelocity.Y)
					if speed > 18 then
						sound("aterrissar", rootPart, math.clamp(speed / 70, 0.35, 0.9))
					end
				end
			end)
			local watcher
			watcher = RunService.Heartbeat:Connect(function()
				if not model.Parent then
					watcher:Disconnect()
					return
				end
				if hum.Parent and hum:GetState() == Enum.HumanoidStateType.Freefall then
					falling = math.max(falling, -rootPart.AssemblyLinearVelocity.Y)
				end
			end)
		end
		local function watchPlayer(other: Player)
			other.CharacterAdded:Connect(function(model)
				task.spawn(body, model)
			end)
			if other.Character then
				task.spawn(body, other.Character)
			end
		end
		Players.PlayerAdded:Connect(watchPlayer)
		for _, other in Players:GetPlayers() do
			watchPlayer(other)
		end
	end

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
			psychosis = if abilityFx.sandevistan then (abilityFx.stability or 100) / 100 else nil,
			safe = (position ~= nil and inSafeZone(position) and weapon.kind == "gun") or os.clock() < safeBlockedUntil,
		}, dt)
		hud.gui.Enabled = not dead and not implantsOpen
		-- Avisa o life.client.luau (casa, agente, objetivo) para sair da frente do terminal e da roleta.
		local covered = dead or implantsOpen or wheelOpen
		if player:GetAttribute("CyberOutlawHudOculto") ~= covered then
			player:SetAttribute("CyberOutlawHudOculto", covered)
		end
		-- Mira: só com arma de fogo, ao mirar ou logo depois de um tiro; no celular, sempre que armado.
		local showCross = not dead and not wheelOpen and not implantsOpen and weapon.kind == "gun" and (aimingNow or raised or touch)
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
	local function holoPlace(part: BasePart, anchor: GuiObject, depth: number, opts: any?)
		local size, at = anchor.AbsoluteSize, anchor.AbsolutePosition
		local view = camera.ViewportSize
		local cx, cy = at.X + size.X / 2, at.Y + size.Y / 2
		local nx = math.clamp((cx - view.X / 2) / math.max(1, view.X / 2), -1, 1)
		local ny = math.clamp((cy - view.Y / 2) / math.max(1, view.Y / 2), -1, 1)
		local fx, fy, pitch, yaw = holoTilt(nx, ny)
		local still = opts ~= nil and opts.still == true
		pitch += (opts and opts.pitch) or 0
		size *= (opts and opts.scale) or 1
		local ray = camera:ScreenPointToRay(cx + fx * size.X / 2, cy + fy * size.Y / 2, 1)
		local along = math.max(0.2, ray.Direction:Dot(camera.CFrame.LookVector))
		local pivot = camera.CFrame.Position + ray.Direction * (depth / along)
		local perPixel = 2 * depth * math.tan(math.rad(camera.FieldOfView) / 2) / math.max(1, view.Y)
		local w, h = math.max(0.05, size.X * perPixel), math.max(0.05, size.Y * perPixel)
		part.Size = Vector3.new(w, h, 0.02)
		-- Na placa, x cresce para a direita e y para cima (na tela, y cresce para baixo).
		local sway = if still then 0 else holo.sway
		local roll = if still then 0 else math.rad(1.2) * math.sin(os.clock() * 0.8 + nx)
		part.CFrame = CFrame.new(pivot) * camera.CFrame.Rotation * CFrame.Angles(pitch, yaw + sway, roll)
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

	-- Implantes: terminal holográfico, botão da habilidade e efeitos do Sandevistan ------------------------
	-- (Numa função à parte: o start() já está no limite de 200 variáveis locais do Luau.)
	local implantSteps = (function()
		local implantDefs = {}
		pcall(function()
			local decoded = HttpService:JSONDecode(arsenal:GetAttribute("Implantes"))
			if type(decoded) == "table" then
				implantDefs = decoded
			end
		end)
		for _, entry in implantDefs do
			if type(entry) == "table" and entry.id == "sandevistan" and type(entry.stats) == "table" then
				for key, value in entry.stats do
					sandevistanStats[key] = value
				end
			end
		end
		local implantModels = arsenal and arsenal:FindFirstChild("Implantes")
		local equippedImplants: { [string]: boolean } = {}
		local stability = 100
		local terminal = if #implantDefs > 0 then buildImplantPanel(implantDefs, ATLAS, implantModels) else nil
		local terminalGui = new("ScreenGui", playerGui, {
			Name = "CyberOutlawTerminalToque", ResetOnSpawn = false, DisplayOrder = 45, Enabled = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		})
		local terminalAnchor = frame(terminalGui, "Ancora", 1, { AnchorPoint = CENTER, Position = UDim2.fromScale(0.5, 0.5) })
		local terminalBlur = Instance.new("BlurEffect")
		terminalBlur.Name = "CyberOutlawTerminalFoco"
		terminalBlur.Size = 0
		terminalBlur.Parent = camera
		local terminalOpen = 0
		local dragInput: InputObject?, dragLast: Vector3?, dragAt = nil, nil, -10
		local terminalHits: { [string]: TextButton } = {}
		if terminal then
			terminal.gui.Parent = playerGui
		end

		local function busyNow(): boolean
			return character ~= nil and (boosted(character) or raving(character))
		end
		local function readMind()
			local list = {}
			local raw = player:GetAttribute("CyberOutlawImplantes")
			if type(raw) == "string" then
				local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
				if ok and type(decoded) == "table" then
					list = decoded
				end
			end
			table.clear(equippedImplants)
			for _, id in list do
				if type(id) == "string" then
					equippedImplants[id] = true
				end
			end
			local value = player:GetAttribute("CyberOutlawPsicose")
			stability = if type(value) == "number" then value else 100
			abilityFx.stability = stability
			abilityFx.sandevistan = equippedImplants.sandevistan == true
			abilityFx.implants = equippedImplants
			if terminal then
				terminal.setState(equippedImplants, stability, busyNow())
			end
		end
		player:GetAttributeChangedSignal("CyberOutlawImplantes"):Connect(readMind)
		player:GetAttributeChangedSignal("CyberOutlawPsicose"):Connect(readMind)
		readMind()

		toggleImplants = function(force: boolean?)
			if not terminal then
				return
			end
			local open = if force == nil then not implantsOpen else force
			if open and (dead or wheelOpen) then
				return
			end
			if open == implantsOpen then
				return
			end
			implantsOpen = open
			terminalGui.Enabled = open
			dragInput = nil
			pcall(function()
				GuiService.TouchControlsEnabled = not open
			end)
			if open then
				triggerHeld, aiming, aimToggle = false, false, false
				readMind()
			end
			implantsButton.light(open)
		end

		useAbility = function()
			if dead or not character or equippedImplants.sandevistan ~= true or not action then
				return
			end
			local t = serverNow()
			if boosted(character) or raving(character) or timeAttr(character, "CyberOutlawHabilidadePronta") > t then
				return
			end
			action:FireServer("habilidade")
		end

		-- Camada de toque do terminal: as mesmas áreas da placa 3D (panel.hits), por cima dela.
		if terminal then
			for _, hit in terminal.hits do
				local button = new("TextButton", terminalAnchor, {
					Name = hit.key, Text = "", BackgroundTransparency = 1, Position = hit.position, Size = hit.size, ZIndex = 2,
					Selectable = false, AutoButtonColor = false,
				})
				terminalHits[hit.key] = button
				local key = hit.key
				if key == "boneco" then
					button.InputBegan:Connect(function(input)
						local kind = input.UserInputType
						if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
							dragInput, dragLast, dragAt = input, input.Position, os.clock()
						end
					end)
				else
					button.Activated:Connect(function()
						if key == "fechar" then
							toggleImplants(false)
						elseif key == "acao" then
							local id = terminal.selected
							local verb = terminal.actionFor(id)
							if verb and id and action then
								action:FireServer("implante", id, verb == "encaixar")
								sound("implante_encaixe", nil, 0.55)
							end
						elseif string.sub(key, 1, 6) == "linha:" then
							terminal.select(string.sub(key, 7))
						end
					end)
				end
			end
			UserInputService.InputChanged:Connect(function(input)
				if not implantsOpen or not dragInput or not dragLast then
					return
				end
				local mouse = dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement
				if input == dragInput or mouse then
					local delta = input.Position.X - dragLast.X
					dragLast = input.Position
					dragAt = os.clock()
					terminal.rotate(terminal.yaw + delta * 0.013)
				end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if dragInput and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
					dragInput = nil
				end
			end)
		end
		-- Tamanho do terminal: quase a tela toda no celular; no PC, até 1180 px de largura.
		terminalLayout = function(size: Vector2, l)
			if not terminal then
				return
			end
			local w = math.min(size.X * 0.96, if touch then math.huge else 1180 * l.scale)
			local h = math.min(size.Y * 0.94, w / 1.85)
			w = math.min(w, h * 2.15)
			w, h = math.floor(w), math.floor(h)
			terminalAnchor.Size = UDim2.fromOffset(w, h)
			terminal.resize(Vector2.new(w, h) * 2)
			local close = terminalHits.fechar
			if close then
				-- O X da placa é pequeno; o toque dele cresce até 44 px.
				local gx, gy = math.max(0, 44 - TERMINAL.close.w * w), math.max(0, 44 - TERMINAL.close.h * h)
				close.Position = UDim2.new(TERMINAL.close.x, -gx / 2, TERMINAL.close.y, -gy / 2)
				close.Size = UDim2.new(TERMINAL.close.w, gx, TERMINAL.close.h, gy)
			end
		end
		relayout()

		local function terminalStep(dt: number)
			if not terminal then
				return
			end
			if implantsOpen and dead then
				toggleImplants(false)
			end
			terminalOpen = math.clamp(terminalOpen + (if implantsOpen then dt * 5 else -dt * 7), 0, 1)
			local eased = 1 - (1 - terminalOpen) ^ 3
			terminalBlur.Size = 16 * eased
			local visible = terminalOpen > 0.01 and terminalAnchor.AbsoluteSize.X > 2
			terminal.part.Parent = if visible then camera else nil
			if visible then
				-- Abre como um holograma ligando: vem deitado e menor e se endireita.
				holoPlace(terminal.part, terminalAnchor, 3.2, { still = true, pitch = (1 - eased) * 0.55, scale = 0.86 + 0.14 * eased })
				terminal.step(dt, dragInput ~= nil or os.clock() - dragAt < 1.6)
				local busy = busyNow()
				if busy ~= terminal.busy then
					terminal.setState(equippedImplants, stability, busy)
				end
			end
		end

		-- Botão da habilidade: aceso nas cores dos rastros enquanto ativo, rosa no surto e a recarga descendo.
		local cooldownMask = frame(abilityButton.button, "Recarga", 23, {
			Size = FULL, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, Visible = false,
		})
		round(cooldownMask, if touch then UDim.new(1, 0) else UDim.new(0, 9))
		local cooldownGradient = new("UIGradient", cooldownMask, { Rotation = 90 })

		-- Tela: o Sandevistan deixa o mundo verde-pálido e mais largo; quem está lento vê azulado; o surto é
		-- vermelho, treme e mostra CIBERPSICOSE.
		local slowGrade = Instance.new("ColorCorrectionEffect")
		slowGrade.Name = "CyberOutlawSandevistan"
		slowGrade.Enabled = false
		slowGrade.Parent = camera
		local rageGrade = Instance.new("ColorCorrectionEffect")
		rageGrade.Name = "CyberOutlawSurto"
		rageGrade.Enabled = false
		rageGrade.Parent = camera
		local rageGui = new("ScreenGui", playerGui, {
			Name = "CyberOutlawSurto", ResetOnSpawn = false, DisplayOrder = 35, Enabled = false,
			ScreenInsets = Enum.ScreenInsets.None, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
		for _, side in { { 0, 0, 1, 0.22, 90 }, { 0, 0.78, 1, 0.22, -90 }, { 0, 0, 0.18, 1, 0 }, { 0.82, 0, 0.18, 1, 180 } } do
			local edge = frame(rageGui, "Borda", 1, {
				Position = UDim2.fromScale(side[1], side[2]), Size = UDim2.fromScale(side[3], side[4]),
				BackgroundColor3 = Color3.fromRGB(255, 20, 60), BackgroundTransparency = 0,
			})
			new("UIGradient", edge, { Rotation = side[5], Transparency = NumberSequence.new(0.25, 1) })
		end
		local rageTitle = label(rageGui, "Titulo", "CIBERPSICOSE", Font.new("rbxassetid://12187375422", Enum.FontWeight.Bold), if touch then 26 else 44, Color3.fromRGB(255, 70, 100), 3, {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.16), Size = UDim2.fromOffset(600, 60),
			TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, TextStrokeColor3 = Color3.fromRGB(40, 0, 10),
		})
		local rageSub = label(rageGui, "Sub", "O IMPLANTE ASSUMIU O CONTROLE", Font.new(BUILDER, Enum.FontWeight.Heavy), if touch then 12 else 16, TEXT, 3, {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.16, if touch then 58 else 82), Size = UDim2.fromOffset(600, 24),
			TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3,
		})
		-- Rastros por cima do mundo em preto e branco: o filtro de cor pega tudo o que está no mundo, então os
		-- rastros de quem ativou vão para uma ViewportFrame que cobre a tela com a mesma câmera e ficam coloridos.
		local trailGui = new("ScreenGui", playerGui, {
			Name = "CyberOutlawRastros", ResetOnSpawn = false, DisplayOrder = 1, Enabled = false,
			ScreenInsets = Enum.ScreenInsets.None, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
		local trailView = new("ViewportFrame", trailGui, {
			Name = "Rastros", Size = FULL, BackgroundTransparency = 1, Ambient = Color3.fromRGB(235, 235, 235),
			LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.3, -1, -0.4),
		})
		local trailCamera = new("Camera", trailView, { Name = "Camera" })
		trailView.CurrentCamera = trailCamera
		local fx = { slow = 0, slowed = 0, rage = 0, wasFrenzy = false }
		local frozen: { [ParticleEmitter]: number }?
		local emitters: { ParticleEmitter }?
		-- Partículas (fumaça, faíscas, vapor) quase param junto com o tempo.
		local function freezeParticles(on: boolean)
			if on and not frozen then
				if not emitters then
					local list = {}
					for _, item in Workspace:GetDescendants() do
						if item:IsA("ParticleEmitter") then
							table.insert(list, item)
						end
					end
					emitters = list
				end
				local saved = {}
				for _, emitter in emitters :: { ParticleEmitter } do
					if emitter.Parent then
						saved[emitter] = emitter.TimeScale
						emitter.TimeScale = 0.12
					end
				end
				frozen = saved
			elseif not on and frozen then
				for emitter, scale in frozen do
					emitter.TimeScale = scale
				end
				frozen = nil
			end
		end
		-- Detalhes do Sandevistan (tudo colorido por cima do mundo cinza, na ViewportFrame dos rastros):
		-- onda de choque ao ligar (bolha e anel no chão), poeira suspensa no ar quase parada, cantos e leitura
		-- "TEMPO ×0,08" com o tempo restante, bordas com aberração cromática, linhas de varredura, batida no
		-- canto da tela e o "estalo" de volta quando desliga.
		local sandiStep = (function()
			local overlay = new("ScreenGui", playerGui, {
				Name = "CyberOutlawSandevistanHUD", ResetOnSpawn = false, DisplayOrder = 3, Enabled = false, IgnoreGuiInset = true,
				ScreenInsets = Enum.ScreenInsets.None, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			})
			local edges = {}
			for index, spec in { { 0, 0.16, 0, Color3.fromRGB(40, 255, 150) }, { 0.84, 0.16, 180, Color3.fromRGB(255, 40, 210) } } do
				local edge = frame(overlay, "Aberracao", 1, {
					Position = UDim2.fromScale(spec[1], 0), Size = UDim2.fromScale(spec[2], 1), BackgroundTransparency = 0, BackgroundColor3 = spec[4],
				})
				new("UIGradient", edge, { Rotation = spec[3], Transparency = NumberSequence.new(0.55, 1) })
				edges[index] = edge
			end
			local lines = frame(overlay, "Varredura", 2, { Size = FULL })
			for index = 0, 89 do
				frame(lines, "Linha", 2, {
					Position = UDim2.fromScale(0, index / 90), Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.9, BackgroundColor3 = Color3.new(0, 0, 0),
				})
			end
			local brackets = {}
			for _, spec in { { 0, 0, 1, 1 }, { 1, 0, -1, 1 }, { 0, 1, 1, -1 }, { 1, 1, -1, -1 } } do
				local holder = frame(overlay, "Canto", 4, {
					AnchorPoint = Vector2.new(spec[1], spec[2]), Position = UDim2.new(spec[1], -spec[3] * 26, spec[2], -spec[4] * 26), Size = UDim2.fromOffset(46, 46),
				})
				local across = frame(holder, "H", 4, {
					AnchorPoint = Vector2.new(spec[1], spec[2]), Position = UDim2.fromScale(spec[1], spec[2]), Size = UDim2.fromOffset(46, 3), BackgroundTransparency = 0,
				})
				local down = frame(holder, "V", 4, {
					AnchorPoint = Vector2.new(spec[1], spec[2]), Position = UDim2.fromScale(spec[1], spec[2]), Size = UDim2.fromOffset(3, 46), BackgroundTransparency = 0,
				})
				table.insert(brackets, across)
				table.insert(brackets, down)
			end
			local tech = Font.new("rbxassetid://12187375422", Enum.FontWeight.Bold)
			local brand = label(overlay, "Marca", "SANDEVISTAN · ATIVO", tech, if touch then 11 else 14, Color3.fromRGB(70, 255, 140), 5, {
				Position = UDim2.new(0, 34, 0, if touch then 70 else 40), Size = UDim2.fromOffset(320, 18), TextStrokeTransparency = 0.5,
			})
			local readout = label(overlay, "Tempo", "TEMPO ×0,08", tech, if touch then 18 else 26, Color3.new(1, 1, 1), 5, {
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if touch then -86 else -150), Size = UDim2.fromOffset(420, 30),
				TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.35,
			})
			local clockText = label(overlay, "Relogio", "", Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold), if touch then 12 else 15,
				Color3.fromRGB(50, 235, 255), 5, {
					AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if touch then -70 else -128), Size = UDim2.fromOffset(420, 18),
					TextXAlignment = Enum.TextXAlignment.Center,
				})
			local track = frame(overlay, "Restante", 5, {
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, if touch then -64 else -120), Size = UDim2.fromOffset(if touch then 220 else 320, 3),
				BackgroundTransparency = 0.7, BackgroundColor3 = Color3.new(1, 1, 1),
			})
			local fill = frame(track, "Valor", 6, { Size = FULL, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(70, 255, 140) })
			local gradient = new("UIGradient", fill, { Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, GHOST_COLORS[1]), ColorSequenceKeypoint.new(0.5, GHOST_COLORS[3]), ColorSequenceKeypoint.new(1, GHOST_COLORS[5]),
			}) })
			-- Poeira e faíscas suspensas: pedacinhos de luz quase parados em volta da câmera.
			local motes = {}
			for index = 1, 70 do
				local mote = Instance.new("Part")
				mote.Name = "Poeira"
				mote.Anchored, mote.CanCollide, mote.CanQuery, mote.CanTouch, mote.CastShadow = true, false, false, false, false
				mote.Material = Enum.Material.Neon
				mote.Shape = Enum.PartType.Ball
				local size = rng:NextNumber(0.05, 0.16)
				mote.Size = Vector3.new(size, size, size)
				mote.Color = if index % 5 == 0 then GHOST_COLORS[index % #GHOST_COLORS + 1] else Color3.fromRGB(220, 240, 255)
				motes[index] = { part = mote, drift = Vector3.new(rng:NextNumber(-0.15, 0.15), rng:NextNumber(-0.08, 0.12), rng:NextNumber(-0.15, 0.15)) }
			end
			-- Onda de choque: bolha que cresce e anel no chão (e o contrário quando o tempo volta).
			local bubble = Instance.new("Part")
			bubble.Name = "Bolha"
			bubble.Anchored, bubble.CanCollide, bubble.CanQuery, bubble.CanTouch, bubble.CastShadow = true, false, false, false, false
			bubble.Material = Enum.Material.Neon
			bubble.Shape = Enum.PartType.Ball
			local ring = bubble:Clone()
			ring.Name = "Anel"
			ring.Shape = Enum.PartType.Cylinder
			local inner = ring:Clone()
			inner.Name = "AnelMiolo"
			inner.Color = Color3.new(0, 0, 0)
			local wave = { at = -10, center = Vector3.zero, reverse = false }
			local was = false
			local pulse: Sound? = nil
			local beat = 0
			return function(dt: number, active: boolean)
				local now = os.clock()
				local root0 = character and character:FindFirstChild("HumanoidRootPart")
				if active ~= was then
					was = active
					wave.at, wave.reverse = now, not active
					-- Som: pulso grave em loop enquanto dura, e o prato ao contrário chegando no topo quando o tempo volta.
					if active then
						pulse = sound("tempo_pulso", nil, 1)
						if pulse then
							pulse.Looped = true
						end
						local left = if character then timeAttr(character, "CyberOutlawSandevistanAte") - serverNow() else 0
						task.delay(math.max(0, left - 2.1), function()
							if was then
								sound("tempo_volta", nil, 1)
							end
						end)
					elseif pulse then
						pulse:Destroy()
						pulse = nil
					end
					wave.center = if root0 and root0:IsA("BasePart") then root0.Position - Vector3.new(0, 2.9, 0) else camera.Focus.Position
					if active then
						-- A poeira aparece espalhada em volta de onde a câmera está agora.
						for _, mote in motes do
							mote.part.Position = camera.CFrame.Position + Vector3.new(rng:NextNumber(-28, 28), rng:NextNumber(-6, 14), rng:NextNumber(-28, 28))
						end
					end
				end
				local age = now - wave.at
				local span = if wave.reverse then 0.35 else 0.7
				local k = math.clamp(age / span, 0, 1)
				if k < 1 then
					local grow = if wave.reverse then 1 - k else 1 - (1 - k) ^ 3
					local radius = 4 + 76 * grow
					local tone = GHOST_COLORS[math.floor(now * 12) % #GHOST_COLORS + 1]
					bubble.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
					bubble.CFrame = CFrame.new(wave.center + Vector3.new(0, 3, 0))
					bubble.Color = tone
					bubble.Transparency = 0.78 + 0.22 * k
					ring.Size = Vector3.new(0.12, radius * 2.2, radius * 2.2)
					ring.CFrame = CFrame.new(wave.center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
					ring.Color = tone
					ring.Transparency = 0.2 + 0.8 * k
					inner.Size = Vector3.new(0.14, radius * 2.2 - 1.6, radius * 2.2 - 1.6)
					inner.CFrame = ring.CFrame
					inner.Transparency = 1
					bubble.Parent, ring.Parent = trailView, trailView
				else
					bubble.Parent, ring.Parent = nil, nil
				end
				overlay.Enabled = fx.slow > 0.02
				if not overlay.Enabled then
					for _, mote in motes do
						mote.part.Parent = nil
					end
					return
				end
				local alpha = fx.slow
				beat += dt
				local pulse = 0.5 + 0.5 * math.sin(beat * 7.5)
				for index, edge in edges do
					edge.BackgroundTransparency = 1 - alpha * (0.55 + 0.25 * pulse)
					edge.Position = UDim2.fromScale(if index == 1 then 0 else 0.84, 0) + UDim2.fromOffset((if index == 1 then -1 else 1) * 4 * pulse, 0)
				end
				lines.Position = UDim2.fromOffset(0, (beat * 30) % 6)
				for _, child in lines:GetChildren() do
					if child:IsA("Frame") then
						child.BackgroundTransparency = 1 - 0.12 * alpha
					end
				end
				local tone = GHOST_COLORS[math.floor(now * 8) % #GHOST_COLORS + 1]
				for _, piece in brackets do
					piece.BackgroundColor3 = tone
					piece.BackgroundTransparency = 1 - alpha
				end
				brand.TextColor3 = tone
				brand.TextTransparency = 1 - alpha
				local left = if character then math.max(0, timeAttr(character, "CyberOutlawSandevistanAte") - serverNow()) else 0
				local total = math.max(0.5, sandevistanStats.duracao or 4)
				readout.Text = string.format("TEMPO ×%s", string.gsub(string.format("%.2f", sandevistanStats.lento or 0.08), "%.", ","))
				readout.TextTransparency = 1 - alpha * (if rng:NextNumber() < 0.05 then 0.4 else 1)
				readout.Position = UDim2.new(0.5, if rng:NextNumber() < 0.06 then rng:NextInteger(-4, 4) else 0, 1, if touch then -86 else -150)
				clockText.Text = string.format("00:%05.2f  ·  ESTABILIDADE %d%%", left, math.floor(abilityFx.stability or 100))
				clockText.TextTransparency = 1 - alpha
				fill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
				gradient.Offset = Vector2.new((now * 0.6) % 1 - 0.5, 0)
				track.BackgroundTransparency = 1 - 0.3 * alpha
				fill.BackgroundTransparency = 1 - alpha
				local eye = camera.CFrame.Position
				for _, mote in motes do
					local part0 = mote.part
					local position = part0.Position + mote.drift * dt
					-- Fica sempre perto da câmera: quem sai do cubo volta do outro lado.
					local offset = position - eye
					if math.abs(offset.X) > 30 then
						position -= Vector3.new(math.sign(offset.X) * 60, 0, 0)
					end
					if math.abs(offset.Z) > 30 then
						position -= Vector3.new(0, 0, math.sign(offset.Z) * 60)
					end
					if offset.Y > 16 or offset.Y < -8 then
						position = Vector3.new(position.X, eye.Y + rng:NextNumber(-6, 14), position.Z)
					end
					part0.Position = position
					part0.Transparency = 1 - alpha * 0.85
					part0.Parent = trailView
				end
			end
		end)()
		local function approach(value: number, goal: number, rate: number): number
			return value + (goal - value) * math.min(1, rate)
		end
		local function abilityStep(dt: number)
			local active = character ~= nil and boosted(character)
			local frenzy = character ~= nil and raving(character)
			local slowed = character ~= nil and slowedDown(character) and not active
			fx.slow = approach(fx.slow, if active then 1 else 0, dt * (if active then 9 else 3))
			fx.slowed = approach(fx.slowed, if slowed then 1 else 0, dt * 5)
			fx.rage = approach(fx.rage, if frenzy then 1 else 0, dt * (if frenzy then 12 else 3))
			local flash = math.clamp(1 - (os.clock() - abilityFx.flashAt) / 0.4, 0, 1)
			-- Sandevistan: o mundo fica em preto e branco (só os rastros, por cima, têm cor); quem está lento vê azulado.
			slowGrade.Enabled = fx.slow > 0.01 or fx.slowed > 0.01 or flash > 0
			slowGrade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(186, 212, 255), fx.slowed * 0.8)
			slowGrade.Saturation = -1 * fx.slow - 0.25 * fx.slowed
			slowGrade.Contrast = 0.3 * fx.slow
			slowGrade.Brightness = 0.35 * flash - 0.04 * fx.slow
			-- Zoom: fecha um instante (o "soco" do tempo parando) e depois abre mais largo que o normal.
			local snap = math.clamp(1 - (os.clock() - abilityFx.flashAt) / 0.16, 0, 1)
			abilityFov = 12 * fx.slow + 8 * flash - 16 * snap
			pcall(sandiStep, dt, active)
			trailGui.Enabled = fx.slow > 0.01
			if trailGui.Enabled then
				trailCamera.CFrame = camera.CFrame
				trailCamera.FieldOfView = camera.FieldOfView
			end
			-- Começo e fim do surto: o controle sai da mão do jogador e volta no fim.
			if frenzy ~= fx.wasFrenzy then
				fx.wasFrenzy = frenzy
				if controls then
					pcall(function()
						if frenzy then
							controls:Disable()
						else
							controls:Enable()
						end
					end)
				end
				if frenzy then
					if toggleImplants then
						toggleImplants(false)
					end
					closeWheel(false)
					triggerHeld, aiming, aimToggle = false, false, false
				end
			end
			freezeParticles(active)
			rageGrade.Enabled = fx.rage > 0.01
			rageGrade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 120, 132), fx.rage)
			rageGrade.Saturation = 0.5 * fx.rage
			rageGrade.Contrast = 0.35 * fx.rage
			rageGui.Enabled = fx.rage > 0.02
			if rageGui.Enabled then
				-- Letreiro com falha: treme e pisca como sinal ruim.
				local jitter = if frenzy then Vector2.new(rng:NextNumber(-6, 6), rng:NextNumber(-3, 3)) else Vector2.zero
				rageTitle.Position = UDim2.new(0.5, jitter.X, 0.16, jitter.Y)
				rageTitle.TextTransparency = 1 - fx.rage * (if rng:NextNumber() < 0.12 then 0.4 else 1)
				rageSub.TextTransparency = 1 - fx.rage
				local left = math.max(0, math.ceil(timeAttr(character, "CyberOutlawSurtoAte") - serverNow()))
				rageSub.Text = if frenzy then string.format("O IMPLANTE ASSUMIU O CONTROLE · %d s", left) else "CONTROLE DE VOLTA"
				for _, child in rageGui:GetChildren() do
					if child.Name == "Borda" and child:IsA("Frame") then
						child.BackgroundTransparency = 1 - fx.rage * (0.75 + 0.25 * math.sin(os.clock() * 14))
					end
				end
			end
			if frenzy then
				cam.trauma = math.max(cam.trauma, 0.55)
			end
			-- Botão.
			local equipped = equippedImplants.sandevistan == true
			abilityButton.button.Visible = equipped and not dead and not implantsOpen
			if abilityButton.button.Visible then
				if frenzy then
					abilityButton.light(true, NEON_HURT)
				elseif active then
					abilityButton.light(true, GHOST_COLORS[math.floor(os.clock() * 8) % #GHOST_COLORS + 1])
				else
					abilityButton.light(false)
				end
				local ready = timeAttr(character, "CyberOutlawHabilidadePronta")
				local t = serverNow()
				local remaining = if not active and not frenzy and ready > t then math.clamp((ready - t) / math.max(0.1, sandevistanStats.recarga), 0, 1) else 0
				cooldownMask.Visible = remaining > 0.002
				if cooldownMask.Visible then
					local cut = math.clamp(remaining, 0.003, 0.997)
					cooldownGradient.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(cut - 0.002, 0),
						NumberSequenceKeypoint.new(cut, 1), NumberSequenceKeypoint.new(1, 1),
					})
				end
			end
		end

		-- Rastros: enquanto o Sandevistan de alguém roda, o corpo dele deixa cópias de neon translúcidas que somem
		-- em meio segundo, cada uma numa cor do ciclo; no surto, vermelhas. As peças são reaproveitadas.
		local ghosts = {}
		local ghostPool: { Part } = {}
		local ghostClock = setmetatable({}, { __mode = "k" }) :: any
		local highlights = setmetatable({}, { __mode = "k" }) :: any
		local rageTags = setmetatable({}, { __mode = "k" }) :: any
		local GHOST_LIFE = 0.8
		local function ghostPart(): Part
			local item = table.remove(ghostPool)
			if not item then
				item = Instance.new("Part")
				item.Name = "Rastro"
				item.Anchored = true
				item.CanCollide, item.CanQuery, item.CanTouch, item.CastShadow = false, false, false, false
				item.Material = Enum.Material.Neon
				item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			end
			return item :: Part
		end
		local function spawnGhost(model: Model, color: Color3)
			local entry = { parts = {}, born = os.clock() }
			local function copy(source: BasePart, ball: boolean)
				local item = ghostPart()
				item.Shape = if ball then Enum.PartType.Ball else Enum.PartType.Block
				item.Size = if ball then Vector3.new(1.2, 1.2, 1.2) else source.Size
				item.CFrame = source.CFrame
				item.Color = color
				item.Transparency = 0.3
				item.Parent = if fx.slow > 0.05 then trailView else effects
				table.insert(entry.parts, item)
			end
			for _, child in model:GetChildren() do
				if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.Transparency < 0.9 then
					copy(child, child.Name == "Head")
				end
			end
			local weapon = model:FindFirstChild("CyberOutlawArma")
			if weapon then
				local count = 0
				for _, item in weapon:GetDescendants() do
					if item:IsA("BasePart") and count < 8 then
						count += 1
						copy(item, false)
					end
				end
			end
			table.insert(ghosts, entry)
		end
		local function ghostStep(_dt: number)
			local clock = os.clock()
			local t = serverNow()
			for _, other in Players:GetPlayers() do
				local model = other.Character
				local rootPart = model and model:FindFirstChild("HumanoidRootPart")
				if model and rootPart and rootPart:IsA("BasePart") then
					local active = timeAttr(model, "CyberOutlawSandevistanAte") > t
					local frenzy = timeAttr(model, "CyberOutlawSurtoAte") > t
					if active or frenzy then
						local state = ghostClock[model]
						if not state then
							state = { last = 0, index = 0, position = nil }
							ghostClock[model] = state
						end
						local moved = if state.position then (rootPart.Position - state.position).Magnitude else 99
						if clock - state.last > 0.05 and (moved > 0.25 or clock - state.last > 0.2) then
							state.last, state.position = clock, rootPart.Position
							state.index += 1
							local palette = if frenzy then FRENZY_COLORS else GHOST_COLORS
							spawnGhost(model, palette[(state.index - 1) % #palette + 1])
						end
					end
					-- Luzes da coluna: ciclo de cores ativo, vermelho piscando no surto, ciano fraco parado.
					for _, child in model:GetChildren() do
						if child.Name == "CyberOutlawImplante" and child:GetAttribute("Id") == "sandevistan" then
							for _, item in child:GetDescendants() do
								if item:IsA("BasePart") and item.Name == "Luz" then
									if frenzy then
										item.Color = if math.floor(clock * 12) % 2 == 0 then Color3.fromRGB(255, 30, 60) else Color3.fromRGB(120, 0, 20)
										item.Transparency = 0
									elseif active then
										item.Color = GHOST_COLORS[math.floor(clock * 10 + item.Position.Y * 3) % #GHOST_COLORS + 1]
										item.Transparency = 0
									else
										item.Color = Color3.fromRGB(90, 255, 220)
										item.Transparency = 0.35
									end
								end
							end
						end
					end
					-- Letreiro sobre quem está em surto (para os outros saberem correr).
					local tag = rageTags[model]
					if frenzy and model ~= character and not tag then
						local head = model:FindFirstChild("Head")
						if head then
							tag = new("BillboardGui", effects, {
								Name = "CyberOutlawSurto", Adornee = head, Size = UDim2.fromOffset(180, 34), StudsOffset = Vector3.new(0, 2.6, 0),
								AlwaysOnTop = true, MaxDistance = 220, LightInfluence = 0,
							})
							label(tag, "Texto", "CIBERPSICOSE", Font.new("rbxassetid://12187375422", Enum.FontWeight.Bold), 18, Color3.fromRGB(255, 70, 100), 2, {
								TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, TextStrokeColor3 = Color3.fromRGB(40, 0, 10),
							})
							rageTags[model] = tag
						end
					elseif not frenzy and tag then
						tag:Destroy()
						rageTags[model] = nil
					end
					-- Contorno vermelho em quem está em surto: aviso para todo mundo correr.
					local glow = highlights[model]
					if frenzy and not glow then
						glow = Instance.new("Highlight")
						glow.Name = "CyberOutlawSurto"
						glow.FillColor = Color3.fromRGB(255, 30, 60)
						glow.OutlineColor = Color3.fromRGB(255, 80, 110)
						glow.FillTransparency = 0.75
						glow.Adornee = model
						glow.Parent = effects
						highlights[model] = glow
					elseif not frenzy and glow then
						glow:Destroy()
						highlights[model] = nil
					end
				end
			end
			for index = #ghosts, 1, -1 do
				local entry = ghosts[index]
				local age = (clock - entry.born) / GHOST_LIFE
				if age >= 1 then
					for _, item in entry.parts do
						item.Parent = nil
						table.insert(ghostPool, item)
					end
					ghosts[index] = ghosts[#ghosts]
					ghosts[#ghosts] = nil
				else
					local fade = 0.3 + 0.7 * age
					for _, item in entry.parts do
						item.Transparency = fade
					end
				end
			end
		end
		-- Ópticos Kiroshi: os 8 alvos mais perto (até o alcance) ganham contorno visível através das paredes.
		local scans = {}
		local scanWait = 0
		local kiroshiRange = 120
		for _, entry in implantDefs do
			if type(entry) == "table" and entry.id == "kiroshi" and type(entry.stats) == "table" then
				kiroshiRange = entry.stats.alcance or kiroshiRange
			end
		end
		local function scanStep(dt: number)
			scanWait -= dt
			if scanWait > 0 then
				return
			end
			scanWait = 0.25
			local wanted = {}
			if equippedImplants.kiroshi and root and not dead then
				local found = {}
				local function consider(model: Instance?)
					local part = model and model:FindFirstChild("HumanoidRootPart")
					local hum = model and model:FindFirstChildOfClass("Humanoid")
					if model and model ~= character and part and part:IsA("BasePart") and hum and hum.Health > 0 then
						local distance = (part.Position - root.Position).Magnitude
						if distance <= kiroshiRange then
							table.insert(found, { model, distance })
						end
					end
				end
				for _, other in Players:GetPlayers() do
					consider(other.Character)
				end
				local npcs = Workspace:FindFirstChild("CyberOutlawNPCs")
				if npcs then
					for _, model in npcs:GetChildren() do
						consider(model)
					end
				end
				table.sort(found, function(a, b)
					return a[2] < b[2]
				end)
				for index = 1, math.min(8, #found) do
					wanted[found[index][1]] = true
				end
			end
			for model, mark in scans do
				if not wanted[model] or not model.Parent then
					mark:Destroy()
					scans[model] = nil
				end
			end
			for model in wanted do
				if not scans[model] then
					local armed = model:GetAttribute("CyberOutlawArmado") == true or model:FindFirstChild("CyberOutlawArma") ~= nil
					local tone = if armed then Color3.fromRGB(255, 64, 96) else Color3.fromRGB(86, 255, 222)
					scans[model] = new("Highlight", effects, {
						Name = "CyberOutlawKiroshi", Adornee = model, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
						FillTransparency = 0.88, OutlineTransparency = 0.1, FillColor = tone, OutlineColor = tone,
					})
				end
			end
		end
		-- Tendões Reforçados: pulo mais alto e um segundo pulo no ar.
		local doubleUsed = false
		UserInputService.JumpRequest:Connect(function()
			if not equippedImplants.tendoes or not humanoid or not root or dead or raving(character) then
				return
			end
			local state = humanoid:GetState()
			if (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping) and not doubleUsed then
				doubleUsed = true
				local v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(v.X, 58, v.Z)
				sound("pulo_duplo", nil, 0.6)
				spark(root.Position - Vector3.new(0, 3, 0), Color3.fromRGB(86, 220, 255), 6, Vector3.yAxis)
			end
		end)
		local function legsStep(_dt: number)
			if not humanoid then
				return
			end
			local state = humanoid:GetState()
			if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
				doubleUsed = false
			end
			local boost = if equippedImplants.tendoes then 1.4 else 1
			local power, height = 50 * boost, 7.2 * boost
			if math.abs(humanoid.JumpPower - power) > 0.01 then
				humanoid.JumpPower = power
			end
			if math.abs(humanoid.JumpHeight - height) > 0.01 then
				humanoid.JumpHeight = height
			end
		end
		return { ability = abilityStep, ghost = ghostStep, terminal = terminalStep, scan = scanStep, legs = legsStep }
	end)()

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
		pcall(implantSteps.ability, dt)
		pcall(implantSteps.ghost, dt)
		pcall(implantSteps.terminal, dt)
		pcall(implantSteps.scan, dt)
		pcall(implantSteps.legs, dt)
		pcall(dayStep, dt)
		pcall(reflectionStep, dt)
		pcall(reflectCharacters)
		pcall(pitchStep)
		-- Automatic fire while the trigger is held.
		if triggerHeld and def().auto and not wheelOpen and not implantsOpen and player:GetAttribute("CyberOutlawPainel") ~= true then
			shoot()
		end
		-- Mouse locked while playing (like third-person shooters), free in the wheel and menus.
		if not touch then
			local free = wheelOpen or implantsOpen or GuiService.MenuIsOpen or UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
				or player:GetAttribute("CyberOutlawPainel") == true -- painéis da casa e do agente (life.client.luau)
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
