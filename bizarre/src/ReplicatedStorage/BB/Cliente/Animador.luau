-- BIZARRE BATTLEGROUNDS :: animações feitas por código (Motor6D.Transform)
-- Roda depois das animações do Roblox (PreSimulation): por cima do andar/correr normal do
-- avatar entra o golpe, mesclado. Bots e Stands não têm animação do Roblox: aqui também
-- fazemos o andar, o pulo e a respiração deles.
-- As poses são escritas para R15; no R6 (o jogo todo agora é R6) o cotovelo entra no ombro,
-- o joelho entra no quadril e a cintura entra na raiz. Caído (ragdoll de verdade) não mexe em nada.

local RunService = game:GetService("RunService")

local BB = script.Parent.Parent
local Poses = require(BB:WaitForChild("Poses"))

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
	STAR_PLATINUM = { -- Jotaro: mãos no bolso, passo firme, cabeça um pouco baixa
		bE = { -10, 0, -2 }, bD = { -10, 0, 2 }, balanco = 0.12, inclina = -2, cabeca = -6, passo = 34, gingado = 6,
		parado = { Root = { 0, 14, 0 }, Neck = { -8, -14, 0 }, LH = { 5, 0, -7 }, RH = { -6, 0, 5 } },
	},
	THE_WORLD = { -- DIO: peito estufado, braços abertos, queixo para cima
		bE = { 0, 0, -14 }, bD = { 0, 0, 14 }, balanco = 1.1, inclina = -9, cabeca = 10, passo = 30, gingado = 10,
		parado = { Root = { -6, 24, 0 }, Neck = { 12, -10, 0 }, LS = { 74, 0, 36 }, RS = { 68, 0, -36 }, LH = { 2, 0, -10 }, RH = { -2, 0, 10 } },
	},
	MAGICIANS_RED = { -- Avdol: mãos para trás, passo calmo
		bE = { -24, 0, -4 }, bD = { -24, 0, 4 }, balanco = 0.1, inclina = -3, cabeca = 2, passo = 26, gingado = 3,
		parado = { Neck = { 4, 0, 0 }, LH = { 0, 0, -6 }, RH = { 0, 0, 6 } },
	},
	SILVER_CHARIOT = { -- Polnareff: animado, braços balançando alto
		bE = { 0, 0, -6 }, bD = { 0, 0, 6 }, balanco = 1.4, inclina = 2, cabeca = 4, passo = 40, gingado = 8,
		parado = { Root = { 0, -12, 0 }, RS = { 40, 0, 10 }, LS = { 0, 0, -24 }, LH = { 8, 0, -4 }, RH = { -8, 0, 8 } },
	},
	CRAZY_DIAMOND = { -- Josuke: uma mão no bolso, gingado de malandro
		bE = { -10, 0, -2 }, bD = { 0, 0, 8 }, balanco = 0.9, inclina = -5, cabeca = 4, passo = 34, gingado = 12, soDireito = true,
		parado = { Root = { 0, -16, 4 }, Neck = { 2, 12, -6 }, RS = { 12, 0, 18 }, LH = { 4, 0, -8 }, RH = { -4, 0, 4 } },
	},
	KILLER_QUEEN = { -- Kira: executivo, postura reta, balanço curto
		bE = { 0, 0, -3 }, bD = { 0, 0, 3 }, balanco = 0.5, inclina = 0, cabeca = 0, passo = 28, gingado = 2,
		parado = { Neck = { -2, 6, 0 }, RS = { 20, 0, -22 } },
	},
}
local ESTILO_PADRAO = { bE = { 0, 0, -6 }, bD = { 0, 0, 6 }, balanco = 1, inclina = -3, cabeca = 2, passo = 34, gingado = 6, parado = {} }
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
	a.fase += dt * (3.2 + vs * 0.42)
	local s = math.sin(a.fase)
	local sb = math.sin(a.fase - 0.35) -- os braços vêm um pouco atrasados (balanço solto)
	local passoAgora = math.floor(a.fase / math.pi)
	if passoAgora ~= a.ultimoPasso then
		a.ultimoPasso = passoAgora
		if k > 1.05 and Animador.aoPasso then
			Animador.aoPasso(a.modelo, k)
		end
	end
	local resp = math.sin(tt * 1.8) * 2
	local parado = math.clamp(1 - k * 1.6, 0, 1)
	local correndo = math.clamp((k - 1.05) / 0.4, 0, 1)
	local balanco = (40 * est.balanco * (1 - correndo) + 64 * correndo) * k * math.max(0.35, math.abs(fr))
	local giro = math.clamp(-(giroY or 0) * 2.6, -11, 11) * math.min(k, 1)
	local inclinaAcel = math.clamp(-acel * 0.22, -9, 4)
	local quique = -math.abs(math.sin(a.fase)) * (0.16 + 0.12 * correndo) * math.min(k, 1.3)
	local pouso = if a.pousoAte and tt < a.pousoAte then -0.38 * ((a.pousoAte - tt) / 0.22) else 0
	local gingado = s * est.gingado * k * (1 - correndo * 0.6)
	local p: { [string]: { number } } = {
		Root = { est.inclina * (1 - correndo) - 14 * correndo + inclinaAcel + resp * 0.3 * parado, gingado, giro },
		RootPos = { 0, quique + pouso + resp * 0.012 * parado, 0 },
		-- a cabeça compensa o gingado (o olhar fica firme)
		Neck = { est.cabeca + 8 * correndo + resp * 0.5 * parado, -gingado * 0.8, -giro * 0.5 },
		LS = { est.bE[1] - sb * balanco, est.bE[2], est.bE[3] - math.abs(sb) * 4 * k },
		RS = { est.bD[1] + sb * balanco * (if est.soDireito then 1.3 else 1), est.bD[2], est.bD[3] + math.abs(sb) * 4 * k },
		LH = { s * est.passo * k * fr, 0, -s * est.passo * 0.45 * k * la },
		RH = { -s * est.passo * k * fr, 0, s * est.passo * 0.45 * k * la },
	}
	if est.soDireito then
		p.LS = { est.bE[1] - sb * balanco * 0.15, est.bE[2], est.bE[3] }
	end
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
		end
	end
end

function Animador.passo(dt: number)
	for modelo, a in anims do
		if not modelo.Parent then
			continue
		end
		local ok, err = pcall(aplicar, a, dt)
		if not ok then
			warn("[BB] animação:", err)
			anims[modelo] = nil
		end
	end
end

function Animador.iniciar()
	RunService.PreSimulation:Connect(function(dt)
		Animador.passo(dt)
	end)
end

return Animador
