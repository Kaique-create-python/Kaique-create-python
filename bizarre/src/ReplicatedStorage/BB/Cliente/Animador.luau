-- BIZARRE BATTLEGROUNDS :: animações feitas por código (Motor6D.Transform)
-- Roda depois das animações do Roblox (PreSimulation): por cima do andar/correr normal do
-- avatar entra o golpe, mesclado. Bots e Stands não têm animação do Roblox: aqui também
-- fazemos o andar, o pulo e a respiração deles.
-- As poses são escritas para R15; no R6 (o jogo todo agora é R6) o cotovelo entra no ombro,
-- o joelho entra no quadril e a cintura entra na raiz. Caído (ragdoll de verdade) não mexe em nada.

local RunService = game:GetService("RunService")

local BB = script.Parent.Parent
local Poses = require(BB:WaitForChild("Poses"))
local Config = require(BB:WaitForChild("Config"))
local AnimacoesDono = require(BB:WaitForChild("AnimacoesDono"))

local Animador = {}

local anims: { [Model]: any } = {}
local rad = math.rad
local pausaGlobal = 0

-- nomes das juntas do R6 -> nomes do R15 usados nas poses
local R6 = {
	RootJoint = "Root",
	Neck = "Neck",
	["Left Shoulder"] = "LeftShoulder",
	["Right Shoulder"] = "RightShoulder",
	["Left Hip"] = "LeftHip",
	["Right Hip"] = "RightHip",
}

local CURTO: { [string]: string } = {}
for curto, longo in Poses.JUNTAS do
	CURTO[longo] = curto
end

local function lerJuntas(modelo: Model)
	local j = {}
	for _, d in modelo:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 and d:IsDescendantOf(modelo) then
			local nome = R6[d.Name] or d.Name
			local curto = CURTO[nome]
			if curto and not j[curto] then
				local c0 = d.C0
				local rot0 = c0 - c0.Position
				j[curto] = { motor = d, rot0 = rot0, inv = rot0:Inverse(), r6 = R6[d.Name] ~= nil }
			end
		end
	end
	return j
end

-- R6: dobra o cotovelo no ombro, o joelho no quadril e a cintura na raiz
local DOBRA_COTOVELO = 0.55
local DOBRA_JOELHO = 0.35
local DOBRA_CINTURA = 0.6
local function somar(p: { [string]: { number } }, destino: string, v: { number }?, fator: number, soX: boolean?)
	if not v then
		return
	end
	local d = p[destino]
	local x, y, z = v[1] * fator, if soX then 0 else v[2] * fator, if soX then 0 else v[3] * fator
	if d then
		p[destino] = { d[1] + x, d[2] + y, d[3] + z }
	else
		p[destino] = { x, y, z }
	end
end

local function paraR6(pose: { [string]: { number } }?): { [string]: { number } }?
	if not pose then
		return nil
	end
	local p = {}
	for k, v in pose do
		if k == "LS" or k == "RS" or k == "LH" or k == "RH" or k == "Neck" or k == "Root" or k == "RootPos" then
			p[k] = v
		end
	end
	somar(p, "LS", pose.LE, DOBRA_COTOVELO, true)
	somar(p, "RS", pose.RE, DOBRA_COTOVELO, true)
	somar(p, "LH", pose.LK, DOBRA_JOELHO, true)
	somar(p, "RH", pose.RK, DOBRA_JOELHO, true)
	somar(p, "Root", pose.Waist, DOBRA_CINTURA, false)
	return p
end
Animador.paraR6 = paraR6

local function angulos(v: { number }?): CFrame
	if not v then
		return CFrame.identity
	end
	return CFrame.Angles(rad(v[1]), rad(v[2]), rad(v[3]))
end

-- tipo: "jogador" (tem animação do Roblox por baixo), "npc" (bot/boneco) ou "stand"
function Animador.registrar(modelo: Model, tipo: string?): any
	local a = anims[modelo]
	if a then
		return a
	end
	a = {
		modelo = modelo,
		tipo = tipo or "jogador",
		juntas = lerJuntas(modelo),
		clipe = nil,
		nome = nil,
		t = 0,
		vel = 1,
		peso = 0,
		pesoAlvo = 0,
		ate = nil,
		semente = math.random() * 100,
		ragdoll = 0,
		congelado = false,
		hitstop = 0,
		fase = 0,
		ultimo = {},
		r6 = modelo:FindFirstChild("Torso") ~= nil and modelo:FindFirstChild("UpperTorso") == nil,
		boneco = modelo:GetAttribute("BB_Boneco") == true,
		temTrilhas = true,
		conferido = 0,
	}
	anims[modelo] = a
	modelo.Destroying:Connect(function()
		anims[modelo] = nil
	end)
	return a
end

function Animador.de(modelo: Model?): any
	if not modelo then
		return nil
	end
	return anims[modelo]
end

function Animador.atualizarJuntas(modelo: Model)
	local a = anims[modelo]
	if a then
		a.juntas = lerJuntas(modelo)
		a.r6 = modelo:FindFirstChild("Torso") ~= nil and modelo:FindFirstChild("UpperTorso") == nil
	end
end

-- toca um clipe. opcoes = { impacto (s): o golpe de verdade acontece nesse tempo, ate (os.clock), vel }
function Animador.tocar(modelo: Model?, nome: string?, opcoes: any?)
	if not modelo or not nome then
		return
	end
	local a = anims[modelo] or Animador.registrar(modelo)
	local clipe = Poses.clipe(nome)
	if not clipe then
		return
	end
	local o = opcoes or {}
	a.clipe = clipe
	a.nome = nome
	a.t = o.inicio or 0
	a.vel = o.vel or 1
	if o.impacto and clipe.impacto and o.impacto > 0.01 then
		a.vel = math.clamp(clipe.impacto / o.impacto, 0.35, 3)
	end
	a.ate = o.ate
	a.pesoAlvo = 1
	a.semente = math.random() * 100
end

function Animador.parar(modelo: Model?)
	local a = modelo and anims[modelo]
	if a then
		a.pesoAlvo = 0
		a.ate = nil
	end
end

-- AJUSTE7: atordoado/congelado corta a ação NA HORA (sem esperar o peso cair)
function Animador.cortar(modelo: Model?)
	local a = modelo and anims[modelo]
	if a then
		a.pesoAlvo = 0
		a.peso = 0
		a.clipe = nil
		a.nome = nil
		a.ate = nil
	end
end

function Animador.tocando(modelo: Model?): string?
	local a = modelo and anims[modelo]
	if a and a.pesoAlvo > 0 then
		return a.nome
	end
	return nil
end

function Animador.hitstop(modelo: Model?, dur: number)
	local a = modelo and anims[modelo]
	if a then
		a.hitstop = math.max(a.hitstop, os.clock() + dur)
	end
end

function Animador.pausarTudo(dur: number)
	pausaGlobal = math.max(pausaGlobal, os.clock() + dur)
end

-- AJUSTE-4: jeito de andar e de ficar parado de cada usuário de Stand (pose de JoJo)
-- bE/bD = braços parados (ombro), balanco = quanto os braços balançam, inclina = tronco para trás,
-- cabeca = queixo para cima, passo = tamanho do passo, gingado = o quadril/tronco girando
local ESTILOS = {
	-- R6 não tem cotovelo nem joelho: o estilo aparece no tronco (torção, inclinação, rolar do
	-- quadril), no tamanho do passo e no arco dos braços. Nada de braço parado colado no corpo.
	STAR_PLATINUM = { -- Jotaro: pesado e confiante, peito aberto, passo firme
		bE = { 0, 0, -7 }, bD = { 0, 0, 7 }, balanco = 0.8, abre = 7, inclina = -8, cabeca = -3, passo = 42, gingado = 13, quadril = 5,
		parado = { Root = { -3, 22, 0 }, Neck = { -6, -20, 0 }, LS = { 4, 0, -12 }, RS = { -6, 0, 10 }, LH = { 7, 0, -9 }, RH = { -8, 0, 6 } },
	},
	THE_WORLD = { -- DIO: arrogante, peito estufado, braços abertos, queixo para cima
		bE = { 0, 0, -14 }, bD = { 0, 0, 14 }, balanco = 1.15, abre = 12, inclina = -12, cabeca = 10, passo = 44, gingado = 17, quadril = 6,
		parado = { Root = { -6, 26, 0 }, Neck = { 12, -14, 0 }, LS = { 74, 0, 36 }, RS = { 68, 0, -36 }, LH = { 3, 0, -11 }, RH = { -3, 0, 10 } },
	},
	MAGICIANS_RED = { -- Avdol: calmo e sério, passo regular
		bE = { -4, 0, -6 }, bD = { -4, 0, 6 }, balanco = 0.65, abre = 5, inclina = -4, cabeca = 2, passo = 36, gingado = 7, quadril = 3,
		parado = { Root = { 0, 10, 0 }, Neck = { 4, -6, 0 }, LS = { -14, 0, -8 }, RS = { -14, 0, 8 }, LH = { 0, 0, -7 }, RH = { 0, 0, 7 } },
	},
	SILVER_CHARIOT = { -- Polnareff: animado, braços balançando alto
		bE = { 0, 0, -8 }, bD = { 0, 0, 8 }, balanco = 1.4, abre = 9, inclina = 0, cabeca = 5, passo = 46, gingado = 11, quadril = 5,
		parado = { Root = { 0, -14, 0 }, RS = { 40, 0, 12 }, LS = { 0, 0, -26 }, LH = { 9, 0, -5 }, RH = { -8, 0, 8 } },
	},
	CRAZY_DIAMOND = { -- Josuke: gingado de malandro, ombros rolando
		bE = { 0, 0, -9 }, bD = { 0, 0, 10 }, balanco = 1.0, abre = 10, inclina = -6, cabeca = 4, passo = 42, gingado = 19, quadril = 7,
		parado = { Root = { 0, -18, 5 }, Neck = { 2, 14, -7 }, RS = { 12, 0, 20 }, LS = { -4, 0, -10 }, LH = { 5, 0, -9 }, RH = { -5, 0, 5 } },
	},
	KILLER_QUEEN = { -- Kira: executivo, postura reta, passo elegante
		bE = { 0, 0, -4 }, bD = { 0, 0, 4 }, balanco = 0.6, abre = 4, inclina = -2, cabeca = 0, passo = 36, gingado = 5, quadril = 3,
		parado = { Neck = { -2, 8, 0 }, RS = { 22, 0, -24 }, LS = { 0, 0, -6 }, LH = { 0, 0, -5 }, RH = { 0, 0, 5 } },
	},
}
local ESTILO_PADRAO = { bE = { 0, 0, -8 }, bD = { 0, 0, 8 }, balanco = 1, abre = 8, inclina = -5, cabeca = 2, passo = 40, gingado = 10, quadril = 5, parado = {} }
Animador.ESTILOS = ESTILOS
Animador.aoPasso = nil :: ((Model, number) -> ())? -- poeira nos pés quando corre (Main liga)

local function suavizar(a: any, p: { [string]: { number } }, dt: number): { [string]: { number } }
	-- AJUSTE-5: cada junta segue o alvo com um amortecedor (nada de pose "pulando" de um quadro
	-- para o outro: o andar fica mole e natural em vez de duro)
	local s = a.suave
	if not s then
		s = {}
		a.suave = s
	end
	local k = 1 - math.exp(-dt * 14)
	local r = {}
	for junta, v in p do
		local atual = s[junta]
		if not atual then
			atual = { v[1], v[2], v[3] }
			s[junta] = atual
		else
			atual[1] += (v[1] - atual[1]) * k
			atual[2] += (v[2] - atual[2]) * k
			atual[3] += (v[3] - atual[3]) * k
		end
		r[junta] = { atual[1], atual[2], atual[3] }
	end
	-- junta que saiu da pose volta para o neutro devagar
	for junta, atual in s do
		if not p[junta] then
			atual[1] -= atual[1] * k
			atual[2] -= atual[2] * k
			atual[3] -= atual[3] * k
			r[junta] = { atual[1], atual[2], atual[3] }
		end
	end
	return r
end

-- vLocal = velocidade no espaço do corpo (frente = -Z), giroY = rotação (rad/s), velY = subida/queda
local function andarJoJo(a: any, dt: number, plano: number, noAr: boolean, vLocal: Vector3?, giroY: number?, velY: number?): { [string]: { number } }
	local est = ESTILOS[a.modelo:GetAttribute("BB_Stand") or ""] or ESTILO_PADRAO
	local tt = os.clock()
	-- velocidade suavizada (começar e parar de andar sem tranco)
	local antes = a.velSuave or plano
	a.velSuave = antes + (plano - antes) * math.min(1, dt * 7)
	local vs = a.velSuave
	local acel = (vs - antes) / math.max(dt, 1e-3)
	-- pouso: afunda um pouquinho ao tocar o chão
	if a.noArAntes and not noAr then
		a.pousoAte = tt + 0.22
	end
	a.noArAntes = noAr
	if noAr then
		local p = {}
		for j, v in Poses.P.no_ar do
			p[j] = { v[1], v[2], v[3] }
		end
		if (velY or 0) < -8 then
			-- caindo: braços abrem e sobem
			p.LS = { 30, 0, -40 }
			p.RS = { 30, 0, 40 }
		end
		return suavizar(a, p, dt)
	end
	local k = math.clamp(vs / 16, 0, 1.6)
	local fr, la = 1, 0 -- quanto do passo é para frente e quanto é de lado
	if vLocal and vLocal.Magnitude > 1 then
		local plan = Vector3.new(vLocal.X, 0, vLocal.Z)
		if plan.Magnitude > 0.5 then
			fr = -plan.Z / plan.Magnitude -- negativo = andando de costas (mira travada)
			la = plan.X / plan.Magnitude
		end
	end
	a.fase += dt * (3.4 + vs * 0.4)
	local s = math.sin(a.fase)
	local c = math.cos(a.fase)
	local sb = math.sin(a.fase - 0.45) -- braços atrasados em relação às pernas (balanço solto)
	local passoAgora = math.floor(a.fase / math.pi)
	if passoAgora ~= a.ultimoPasso then
		a.ultimoPasso = passoAgora
		if k > 1.05 and Animador.aoPasso then
			Animador.aoPasso(a.modelo, k)
		end
	end
	local resp = math.sin(tt * 1.8)
	local andando = math.clamp(k * 1.6, 0, 1) -- 0 parado ... 1 andando
	local parado = 1 - andando
	local correndo = math.clamp((k - 1.05) / 0.4, 0, 1)
	local kk = math.min(k, 1.25)
	-- braços: arco grande, abrindo para fora no meio do balanço (gingado, não "boneco de pau")
	local amp = (46 * est.balanco * (1 - correndo) + 72 * correndo) * kk * math.max(0.35, math.abs(fr))
	local abre = (est.abre or 8) * kk
	local giro = math.clamp(-(giroY or 0) * 2.6, -11, 11) * math.min(k, 1)
	local inclinaAcel = math.clamp(-acel * 0.22, -9, 4)
	local quique = -math.abs(c) * (0.22 + 0.14 * correndo) * kk
	local pouso = if a.pousoAte and tt < a.pousoAte then -0.38 * ((a.pousoAte - tt) / 0.22) else 0
	local torcao = s * est.gingado * kk * (1 - correndo * 0.5) -- ombros vão para frente com o braço
	local rolar = -c * (est.quadril or 5) * kk -- quadril desce do lado da perna que pisa
	local passo = (est.passo * (1 - correndo) + 56 * correndo) * kk
	local p: { [string]: { number } } = {
		Root = {
			(est.inclina * (1 - correndo) - 16 * correndo) * andando + inclinaAcel + resp * 1.2 * parado,
			torcao,
			rolar + giro,
		},
		RootPos = { 0, quique + pouso + resp * 0.03 * parado, 0 },
		-- a cabeça compensa o tronco (o olhar fica firme) e acompanha o passo
		Neck = { (est.cabeca + 10 * correndo) * andando - math.abs(c) * 3 * kk + resp * 1.5 * parado, -torcao * 0.75, -rolar * 0.6 },
		LS = { est.bE[1] - sb * amp, est.bE[2], est.bE[3] - abre * (0.6 + 0.4 * math.abs(sb)) },
		RS = { est.bD[1] + sb * amp, est.bD[2], est.bD[3] + abre * (0.6 + 0.4 * math.abs(sb)) },
		LH = { s * passo * fr, 0, -s * passo * 0.45 * la - 2 * kk },
		RH = { -s * passo * fr, 0, s * passo * 0.45 * la + 2 * kk },
	}
	-- parado: a pose de JoJo de cada um (mistura suave com o andar)
	if parado > 0.01 then
		for junta, v in est.parado do
			local atual = p[junta] or { 0, 0, 0 }
			p[junta] = {
				atual[1] + (v[1] - atual[1]) * parado,
				atual[2] + (v[2] - atual[2]) * parado,
				atual[3] + (v[3] - atual[3]) * parado,
			}
		end
	end
	return suavizar(a, p, dt)
end
Animador.andarJoJo = andarJoJo

-- AJUSTE-10: ANDAR e CORRER do dono (feitos no Studio, vindos do Drive). Os quadros vão direto nas
-- juntas do R6 (Motor6D.Transform), como o Animator do Roblox faria. Parado continua a pose JoJo.
local POSE_MOTOR = {
	Torso = "RootJoint",
	Head = "Neck",
	["Left Arm"] = "Left Shoulder",
	["Right Arm"] = "Right Shoulder",
	["Left Leg"] = "Left Hip",
	["Right Leg"] = "Right Hip",
}
local CLIPES_DONO: { [string]: any } = {}
for nome, c in AnimacoesDono do
	local tempos, cfs = {}, {}
	for i, q in c.quadros do
		tempos[i] = q[1]
		local porMotor = {}
		for pose, v in q[2] do
			local motor = POSE_MOTOR[pose]
			if motor then
				porMotor[motor] = CFrame.new(v[1], v[2], v[3]) * CFrame.fromEulerAnglesXYZ(v[4], v[5], v[6])
			end
		end
		cfs[i] = porMotor
	end
	CLIPES_DONO[nome] = { dur = c.dur, tempos = tempos, cfs = cfs }
end

-- pose do clipe do dono no tempo t (interpola entre dois quadros; volta ao começo no fim)
local function amostrarDono(nome: string, t: number): { [string]: CFrame }?
	local c = CLIPES_DONO[nome]
	if not c or #c.tempos == 0 then
		return nil
	end
	local n = #c.tempos
	if c.dur > 0 then
		t = t % c.dur
	end
	local i = 1
	while i < n and c.tempos[i + 1] <= t do
		i += 1
	end
	local a, b = c.cfs[i], c.cfs[math.min(n, i + 1)]
	local t0, t1 = c.tempos[i], c.tempos[math.min(n, i + 1)]
	local k = if t1 > t0 then math.clamp((t - t0) / (t1 - t0), 0, 1) else 0
	local r = {}
	for motor, cfa in a do
		local cfb = b[motor]
		r[motor] = if cfb then cfa:Lerp(cfb, k) else cfa
	end
	return r
end
Animador.amostrarDono = amostrarDono
Animador.CLIPES_DONO = CLIPES_DONO

-- quanto do andar/correr do dono entra agora (0 parado ou no ar) e a pose já misturada
local function locomocaoDono(a: any, dt: number): ({ [string]: CFrame }?, number)
	local andar, correr = CLIPES_DONO.andar, CLIPES_DONO.correr
	local raiz = a.modelo:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = a.modelo:FindFirstChildOfClass("Humanoid")
	if not andar or not raiz or not hum then
		return nil, 0
	end
	local estado = hum:GetState()
	local noAr = estado == Enum.HumanoidStateType.Freefall or estado == Enum.HumanoidStateType.Jumping
	local v = raiz.AssemblyLinearVelocity
	local plano = Vector3.new(v.X, 0, v.Z).Magnitude
	local alvo = if noAr then 0 else math.clamp((plano - 1.5) / 5, 0, 1)
	a.pesoDono = (a.pesoDono or 0) + (alvo - (a.pesoDono or 0)) * math.min(1, dt * 10)
	-- AJUSTE-12: o maior valor dos últimos 5 s (o DIAG mostra mesmo se você parou para olhar)
	if a.pesoDono >= (a.picoDono or 0) or os.clock() - (a.picoT or 0) > 5 then
		a.picoDono = a.pesoDono
		a.picoT = os.clock()
	end
	if a.pesoDono < 0.01 then
		a.faseDono = 0
		return nil, 0
	end
	-- andar -> correr conforme a velocidade (ANDAR 18, CORRER 27)
	local alvoCorrida = if correr then math.clamp((plano - (Config.ANDAR + 1.5)) / math.max(1, Config.CORRER - Config.ANDAR - 3), 0, 1) else 0
	a.corridaDono = (a.corridaDono or 0) + (alvoCorrida - (a.corridaDono or 0)) * math.min(1, dt * 8)
	local k = a.corridaDono
	-- velocidade do clipe acompanha os pés (como o Animate do Roblox faz)
	local vAndar = (math.max(plano, 6) / 16) / andar.dur
	local vCorrer = if correr then (math.max(plano, 6) / 26) / correr.dur else vAndar
	a.faseDono = ((a.faseDono or 0) + dt * (vAndar + (vCorrer - vAndar) * k)) % 1
	local pose = amostrarDono("andar", a.faseDono * andar.dur)
	if pose and correr and k > 0.01 then
		local pc = amostrarDono("correr", a.faseDono * correr.dur)
		if pc then
			for m, cf in pose do
				local cfc = pc[m]
				if cfc then
					pose[m] = cf:Lerp(cfc, k)
				end
			end
		end
	end
	return pose, a.pesoDono
end

-- camada de baixo dos bots e Stands: parado, andando, correndo, no ar
local function locomocao(a: any, dt: number): { [string]: { number } }
	local m = a.modelo
	if a.tipo == "stand" then
		local tt = os.clock()
		local base = Poses.P.cruzado_flutua
		local p = {}
		for k, v in base do
			p[k] = { v[1], v[2], v[3] }
		end
		p.Neck = { -6 + math.sin(tt * 1.3) * 3, math.sin(tt * 0.7) * 6, 0 }
		p.Waist = { 4 + math.sin(tt * 2) * 2, 0, 0 }
		return p
	end
	local raiz = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not raiz or not hum then
		return {}
	end
	local v = raiz.AssemblyLinearVelocity
	local plano = Vector3.new(v.X, 0, v.Z).Magnitude
	if a.boneco then
		return { Waist = { math.sin(os.clock() * 1.5) * 1, 0, 0 } }
	end
	local estado = hum:GetState()
	local noAr = estado == Enum.HumanoidStateType.Freefall or estado == Enum.HumanoidStateType.Jumping
	-- jogadores e bots com Stand andam no estilo JoJo
	if a.tipo == "jogador" or m:GetAttribute("BB_Stand") then
		local vLocal = raiz.CFrame:VectorToObjectSpace(v)
		return andarJoJo(a, dt, plano, noAr, vLocal, raiz.AssemblyAngularVelocity.Y, v.Y)
	end
	if noAr then
		return Poses.P.no_ar
	end
	local k = math.clamp(plano / 16, 0, 1.4)
	a.fase += dt * (4 + plano * 0.42)
	local s = math.sin(a.fase)
	local c = math.cos(a.fase)
	local resp = math.sin(os.clock() * 2) * 2 * (1 - math.min(k, 1))
	return {
		Waist = { -6 * k + resp, s * 6 * k, 0 },
		Neck = { 3 * k, -s * 4 * k, 0 },
		LS = { -s * 40 * k, 0, -6 }, LE = { 20 + 30 * k, 0, 0 },
		RS = { s * 40 * k, 0, 6 }, RE = { 20 + 30 * k, 0, 0 },
		LH = { s * 38 * k, 0, 0 }, LK = { -math.max(0, c) * 50 * k - 4, 0, 0 },
		RH = { -s * 38 * k, 0, 0 }, RK = { -math.max(0, -c) * 50 * k - 4, 0, 0 },
		Root = { -8 * math.min(k, 1), 0, 0 },
	}
end

-- caído de verdade (juntas soltas pelo servidor): a física manda, a animação não mexe
local function caido(a: any): boolean
	local ate = a.modelo:GetAttribute("BB_Ragdoll")
	return type(ate) == "number" and ate > workspace:GetServerTimeNow()
end

local function aplicar(a: any, dt: number)
	local agora = os.clock()
	if a.congelado then
		return -- tempo parado: fica exatamente como estava
	end
	if caido(a) then
		if not a.estavaCaido then
			a.estavaCaido = true
			for _, j in a.juntas do
				j.motor.Transform = CFrame.identity
			end
		end
		a.peso = 0
		a.pesoAlvo = 0
		a.clipe = nil
		a.nome = nil
		return
	end
	a.estavaCaido = false
	local passo = dt
	if agora < a.hitstop or agora < pausaGlobal then
		passo = 0
	end
	-- avança o clipe
	local clipe = a.clipe
	if clipe then
		a.t += passo * a.vel
		local acabou = false
		if a.ate and agora >= a.ate then
			acabou = true
		elseif not a.ate and not clipe.segurar and clipe.dur and a.t >= clipe.dur then
			acabou = true
		end
		if acabou then
			a.pesoAlvo = 0
		end
	end
	local velPeso = if a.pesoAlvo > a.peso then 18 else 7
	a.peso += (a.pesoAlvo - a.peso) * math.min(1, dt * velPeso)
	if a.pesoAlvo == 0 and a.peso < 0.02 then
		a.peso = 0
		a.clipe = nil
		a.nome = nil
	end
	local acao: { [string]: { number } }? = nil
	local giro = 0
	if clipe and a.peso > 0 then
		if clipe.proc == "barragem" then
			acao = Poses.barragem(a.t, a.semente)
		elseif clipe.proc == "estocadas" then
			acao = Poses.estocadas(a.t)
		else
			acao, giro = Poses.amostrar(clipe, a.t)
		end
	end
	-- jogador: o andar do Roblox foi trocado (StarterCharacterScripts/Animate); o andar é o nosso
	local base = if a.tipo ~= "jogador" or not a.temTrilhas then locomocao(a, dt) else nil
	if a.r6 then
		acao = paraR6(acao)
		base = paraR6(base)
	end
	local peso = a.peso
	-- AJUSTE-10: andar/correr do dono por cima (corpos R6 de jogadores e bots; golpe tem prioridade)
	local poseDono: { [string]: CFrame }? = nil
	local pesoDono = 0
	if a.r6 and a.tipo ~= "stand" and not a.boneco and not (a.tipo == "jogador" and a.temTrilhas) then
		poseDono, pesoDono = locomocaoDono(a, passo)
		pesoDono *= 1 - math.clamp(peso, 0, 1)
	end
	-- avatar sem nenhuma animação do Roblox tocando: nós cuidamos de todas as juntas
	if a.tipo == "jogador" and agora - a.conferido > 0.5 then
		a.conferido = agora
		local hum = a.modelo:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		local ok, trilhas = pcall(function()
			return if animator then #animator:GetPlayingAnimationTracks() else 0
		end)
		a.temTrilhas = ok and trilhas > 0
	end
	for curto, j in a.juntas do
		local m: Motor6D = j.motor
		local va = acao and acao[curto]
		local vb = base and base[curto]
		if a.tipo == "jogador" and a.temTrilhas then
			-- por cima da animação do Roblox: só mexe nas juntas que o golpe usa
			if va and peso > 0.001 then
				local alvo = angulos(va)
				if curto == "Root" and giro ~= 0 then
					alvo = alvo * CFrame.Angles(0, rad(giro), 0)
				end
				local cf = j.inv * alvo * j.rot0
				m.Transform = m.Transform:Lerp(cf, math.clamp(peso, 0, 1))
			elseif curto == "Root" and giro ~= 0 and peso > 0.001 then
				m.Transform = m.Transform * CFrame.Angles(0, rad(giro), 0)
			end
		else
			local alvo = angulos(vb)
			-- quique do corpo (o tronco sobe e desce a cada passo)
			if curto == "Root" and base and base.RootPos then
				local rp = base.RootPos
				alvo = CFrame.new(rp[1], rp[2], rp[3]) * alvo
			end
			if va and peso > 0.001 then
				alvo = alvo:Lerp(angulos(va), math.clamp(peso, 0, 1))
			end
			if curto == "Root" and giro ~= 0 then
				alvo = alvo * CFrame.Angles(0, rad(giro * peso), 0)
			end
			m.Transform = j.inv * alvo * j.rot0
			if poseDono and pesoDono > 0.001 then
				local cfd = poseDono[m.Name]
				if cfd then
					m.Transform = m.Transform:Lerp(cfd, pesoDono)
				end
			end
		end
	end
end

local ultimoErro = ""
function Animador.passo(dt: number)
	for modelo, a in anims do
		if not modelo.Parent then
			continue
		end
		local ok, err = pcall(aplicar, a, dt)
		if not ok then
			ultimoErro = tostring(err)
			warn("[BB] animação:", err)
			anims[modelo] = nil
		end
	end
end

-- AJUSTE-11: o MEU personagem só anda com a animação do jogo (a do dono). Se aparecer o "Animate"
-- padrão do Roblox (corpo refeito em R6, pacote de animação do avatar...), ele é tirado e qualquer
-- trilha de animação do Roblox para na hora (o jogo não usa trilhas: tudo é feito nas juntas).
Animador.tirados = 0
Animador.paradas = 0
-- tira um "Animate" que não é o nosso (devolve true se tirou)
function Animador.tirarAnimateRoblox(d: Instance): boolean
	if d.Name == "Animate" and d:IsA("BaseScript") and not d:GetAttribute("BB_Nosso") then
		pcall(function()
			local s: any = d
			s.Enabled = false
		end)
		pcall(function()
			d:Destroy()
		end)
		Animador.tirados += 1
		return true
	end
	return false
end

function Animador.assumirPersonagem(c: Model)
	for _, d in c:GetChildren() do
		Animador.tirarAnimateRoblox(d)
	end
	c.ChildAdded:Connect(Animador.tirarAnimateRoblox)
	task.spawn(function()
		local hum = c:WaitForChild("Humanoid", 15)
		local animator = hum and hum:WaitForChild("Animator", 15)
		if not animator then
			return
		end
		local function parar(t: any)
			pcall(function()
				t:Stop(0)
			end)
			Animador.paradas += 1
		end
		for _, t in (animator :: any):GetPlayingAnimationTracks() do
			parar(t)
		end
		(animator :: any).AnimationPlayed:Connect(parar)
	end)
end

-- AJUSTE-11: o que está acontecendo com a animação deste personagem (botão DIAG do ADM)
function Animador.diagnostico(modelo: Model?): string
	if not modelo then
		return "sem personagem"
	end
	local a = anims[modelo]
	if not a then
		return "personagem ainda não entrou na animação do jogo" .. (if ultimoErro ~= "" then " · ERRO: " .. ultimoErro else "")
	end
	local nJ = 0
	for _ in a.juntas do
		nJ += 1
	end
	local hum = modelo:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local trilhas = 0
	pcall(function()
		trilhas = if animator then #animator:GetPlayingAnimationTracks() else 0
	end)
	local animates = {}
	for _, d in modelo:GetChildren() do
		if d.Name == "Animate" then
			table.insert(animates, if d:GetAttribute("BB_Nosso") then "nosso" else "DO ROBLOX")
		end
	end
	return string.format(
		"corpo %s · juntas %d · trilhas do Roblox tocando %d · Animate: %s · andar do dono agora %d%%, maior nos últimos 5 s %d%% (clipes %s) · tirados %d, trilhas paradas %d%s",
		if a.r6 then "R6" else "R15 (não é R6!)",
		nJ,
		trilhas,
		if #animates > 0 then table.concat(animates, ", ") else "nenhum",
		math.floor((a.pesoDono or 0) * 100),
		math.floor((a.picoDono or 0) * 100),
		if CLIPES_DONO.andar and CLIPES_DONO.correr then "ok" else "FALTANDO",
		Animador.tirados,
		Animador.paradas,
		if ultimoErro ~= "" then " · ERRO: " .. ultimoErro else ""
	)
end

function Animador.iniciar()
	RunService.PreSimulation:Connect(function(dt)
		Animador.passo(dt)
	end)
end

return Animador
