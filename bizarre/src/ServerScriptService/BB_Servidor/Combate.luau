-- BIZARRE BATTLEGROUNDS :: o combate no servidor (quem manda de verdade)
-- Recebe os pedidos dos celulares (M1, golpe, bloqueio, dash...), confere as regras,
-- aplica dano/empurrão/ragdoll e avisa todo mundo para desenhar os efeitos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BB = ReplicatedStorage:WaitForChild("BB")
local Config = require(BB:WaitForChild("Config"))
local Regras = require(BB:WaitForChild("Regras"))
local Golpes = require(BB:WaitForChild("Golpes"))
local Stands = require(BB:WaitForChild("Stands"))

local Lutadores = require(script.Parent.Lutadores)
local Hitbox = require(script.Parent.Hitbox)
local Fisica = require(script.Parent.Fisica)
local Mapa = require(script.Parent.Mapa)

local Combate = {}

local efeito: RemoteEvent? = nil
local privado: RemoteEvent? = nil
local Executores: any = nil
local aoAbate: ((vitima: any, assassino: any?) -> ())? = nil
local ultimoPedido: { [Player]: { [string]: number } } = {}

function Combate.agora(): number
	return workspace:GetServerTimeNow()
end
local agora = Combate.agora

function Combate.efeito(tipo: string, dados: any)
	if efeito then
		efeito:FireAllClients(tipo, dados)
	end
end

function Combate.privado(lut: any, tipo: string, dados: any)
	if privado and lut and lut.jogador then
		privado:FireClient(lut.jogador, tipo, dados)
	end
end

-- avisa todo mundo menos o próprio jogador (ele já animou na hora, sem esperar a internet)
function Combate.efeitoOutros(lut: any, tipo: string, dados: any)
	if not efeito then
		return
	end
	if lut.jogador then
		for _, p in Players:GetPlayers() do
			if p ~= lut.jogador then
				efeito:FireClient(p, tipo, dados)
			end
		end
	else
		efeito:FireAllClients(tipo, dados)
	end
end

------------------------------------------------------------------------------- velocidade e atributos
function Combate.atualizarMovimento(lut: any)
	local e = lut.estado
	local t = agora()
	local hum: Humanoid = lut.hum
	if hum.Health <= 0 then
		return
	end
	local base = if lut.correndo then Config.CORRER else Config.ANDAR
	local passiva = lut.stand.passiva
	if passiva and passiva.multVelocidade then
		base *= passiva.multVelocidade
	end
	local vel = base
	local pulo = Config.PULO
	if t < e.congeladoAte or t < e.ragdollAte then
		vel, pulo = 0, 0
	elseif t < e.stunAte then
		vel, pulo = 3, 0
	elseif e.bloqueando then
		vel, pulo = Config.BLOQUEIO.andar, 0
	elseif t < e.acaoAte then
		vel = base * (lut.andarAcao or 1)
		pulo = if (lut.andarAcao or 1) >= 0.6 then pulo else 0
	end
	if math.abs(hum.WalkSpeed - vel) > 0.05 then
		hum.WalkSpeed = vel
	end
	hum.UseJumpPower = false
	if math.abs(hum.JumpHeight - pulo) > 0.05 then
		hum.JumpHeight = pulo
	end
end

function Combate.sincronizar(lut: any)
	local e = lut.estado
	local m = lut.modelo
	m:SetAttribute("BB_Stun", e.stunAte)
	m:SetAttribute("BB_Bloqueando", e.bloqueando)
	m:SetAttribute("BB_Guarda", math.floor(e.guarda))
	m:SetAttribute("BB_Despertar", math.floor(e.despertar))
	m:SetAttribute("BB_Desperto", e.despertoAte)
	m:SetAttribute("BB_Evasiva", e.evasivaPronta)
	m:SetAttribute("BB_Iframes", math.max(e.iframesAte, e.protecaoAte))
	m:SetAttribute("BB_StandFora", e.standFora)
end

------------------------------------------------------------------------------- dano e efeitos
local function aplicarDano(alvo: any, dano: number, atk: any?)
	local hum: Humanoid = alvo.hum
	if dano <= 0 then
		return
	end
	local t = agora()
	alvo.estado.ultimoDanoT = t
	if atk and atk ~= alvo then
		alvo.ultimoAtacante = atk
		alvo.ultimoAtacanteT = t
		atk.estado.ultimoDanoT = t -- quem bate também está "em combate"
	end
	if alvo.imortal then
		hum.Health = math.max(1, hum.Health - dano)
		return
	end
	hum.Health = math.max(0, hum.Health - dano)
end
Combate.aplicarDano = aplicarDano

local function queimar(alvo: any, segundos: number, atk: any?)
	local fim = agora() + segundos
	alvo.queimaAte = math.max(alvo.queimaAte or 0, fim)
	alvo.modelo:SetAttribute("BB_Queima", alvo.queimaAte)
	if alvo.queimando then
		return
	end
	alvo.queimando = true
	task.spawn(function()
		while agora() < (alvo.queimaAte or 0) and alvo.hum.Health > 0 do
			task.wait(0.5)
			aplicarDano(alvo, 0.6, atk)
		end
		alvo.queimando = false
	end)
end
Combate.queimar = queimar

-- vetor de empurrão de um golpe
local function vetor(h: any, dir: Vector3, origem: Vector3?, alvo: any): Vector3
	local emp = h.empurrar
	if not emp then
		return Vector3.zero
	end
	local d = dir
	if emp.radial and origem then
		local v = alvo.raiz.Position - origem
		d = Vector3.new(v.X, 0, v.Z)
		if d.Magnitude < 0.5 then
			d = dir
		end
	end
	return Regras.vetorEmpurrao(d, emp.frente or 0, emp.cima or 0)
end

-- O acerto. Devolve "acertou", "bloqueado", "parry", "contra", "invencivel", "fila" ou "nada".
-- h = { dano, atordoar, empurrar = {frente, cima, dur, radial}, ragdoll, quebra, tipo ("melee"/"projetil"/"area"),
--       inbloqueavel, quebraGuarda, queima, som, vfx, tremor, impactFrame, m1 }
function Combate.acertar(atk: any, alvo: any, h: any, info: any?): string
	local t = agora()
	local e = alvo.estado
	if alvo == atk or alvo.hum.Health <= 0 or not alvo.modelo.Parent then
		return "nada"
	end
	local inf = info or {}
	local dir = inf.dir or Regras.achatar(alvo.raiz.Position - atk.raiz.Position)
	if Regras.invencivel(e, t) then
		Combate.efeito("esquiva", { v = alvo.modelo })
		return "invencivel"
	end
	if h.m1 and t < e.ragdollAte then
		return "nada"
	end
	-- tempo parado: o golpe fica guardado e chega junto quando o tempo voltar
	if t < e.congeladoAte and alvo.congeladoPor == atk then
		alvo.filaTempo = alvo.filaTempo or {}
		table.insert(alvo.filaTempo, { atk = atk, h = h, dir = dir })
		Combate.efeito("acerto", { a = atk.modelo, v = alvo.modelo, pos = alvo.raiz.Position, tipo = h.vfx or "impacto", dano = 0, som = h.som, congelado = true, stand = atk.standId })
		return "fila"
	end
	-- contra-ataque armado
	local c = e.contra
	if c and t < c.ate and t >= c.de then
		local tipo = h.tipo or "melee"
		local frente = Regras.achatar(alvo.raiz.CFrame.LookVector):Dot(Regras.achatar(atk.raiz.Position - alvo.raiz.Position)) > 0
		if c.tipos[tipo] and (frente or not c.frenteApenas) then
			if Executores then
				Executores.contraAtivado(alvo, atk, h)
			end
			return "contra"
		end
	end
	local tipoGolpe = h.tipo or "melee"
	local res = Regras.resolverBloqueio(e, t, atk.raiz.Position - alvo.raiz.Position, alvo.raiz.CFrame.LookVector, {
		tipo = tipoGolpe,
		dano = h.dano or 0,
		inbloqueavel = h.inbloqueavel,
		quebraGuarda = h.quebraGuarda,
	})
	local pos = alvo.raiz.Position + Vector3.new(0, 0.6, 0) - dir * 0.8
	if res == "parry" then
		Regras.atordoar(atk.estado, t, Config.BLOQUEIO.parryAtordoa, true)
		Combate.atualizarMovimento(atk)
		Combate.sincronizar(atk)
		Combate.efeito("acerto", { a = atk.modelo, v = alvo.modelo, pos = pos, tipo = "parry", dano = 0, som = "parry", tremor = 0.4 })
		Regras.ganharDespertar(alvo.estado, 6, t)
		return "parry"
	end
	local dano = Regras.danoFinal(h.dano or 0, atk.estado, e, t)
	if res == "bloqueado" then
		local chip = math.floor(dano * (1 - Config.BLOQUEIO.reducao) * 10 + 0.5) / 10
		aplicarDano(alvo, chip, atk)
		Fisica.empurrar(alvo, dir * 10, 0.08)
		Combate.efeito("acerto", { a = atk.modelo, v = alvo.modelo, pos = pos, tipo = "bloqueio", dano = chip, som = "bloqueio", tremor = 0.1 })
		Combate.sincronizar(alvo)
		Regras.ganharDespertar(alvo.estado, chip * Config.DESPERTAR.porDanoRecebido + 1, t)
		return "bloqueado"
	end
	if res == "quebra" then
		Regras.atordoar(e, t, Config.BLOQUEIO.quebraAtordoa, true)
		Combate.efeito("acerto", { a = atk.modelo, v = alvo.modelo, pos = pos, tipo = "quebra_guarda", dano = 0, som = "quebra_guarda", tremor = 0.5 })
	end
	-- dano cheio
	aplicarDano(alvo, dano, atk)
	if h.atordoar and h.atordoar > 0 then
		Regras.atordoar(e, t, h.atordoar)
	end
	local vel = vetor(h, dir, inf.origem, alvo)
	if h.ragdoll and h.ragdoll > 0 then
		Regras.derrubar(e, t, h.ragdoll)
		Fisica.derrubar(alvo, e.ragdollAte)
		alvo.forcaVoo = h.quebra or 1
	end
	if vel.Magnitude > 0.1 then
		local emp = h.empurrar or {}
		Fisica.empurrar(alvo, vel, emp.dur or 0.12)
	end
	if h.queima or (atk.stand.passiva and atk.stand.passiva.queima and tipoGolpe ~= "melee") then
		queimar(alvo, h.queima or 3, atk)
	end
	-- barras
	Regras.ganharDespertar(atk.estado, dano * Config.DESPERTAR.porDanoCausado, t)
	Regras.ganharDespertar(e, dano * Config.DESPERTAR.porDanoRecebido, t)
	local n = Regras.contarAcerto(atk.estado, t)
	Combate.privado(atk, "combo", { n = n })
	-- golpe fortíssimo abre um buraco na hora
	if (h.quebra or 0) >= 3 then
		Mapa.quebrarArea(alvo.raiz.Position, 5, h.quebra, dir)
	end
	Combate.atualizarMovimento(alvo)
	Combate.sincronizar(alvo)
	Combate.sincronizar(atk)
	Combate.efeito("acerto", {
		a = atk.modelo,
		v = alvo.modelo,
		pos = pos,
		dir = dir,
		tipo = h.vfx or "impacto",
		dano = dano,
		som = h.som or "soco",
		tremor = h.tremor,
		impactFrame = h.impactFrame,
		ragdoll = h.ragdoll,
		stand = atk.standId,
		combo = n,
	})
	-- interrompe o que a vítima estava fazendo (se não tinha super armadura)
	return "acertou"
end

------------------------------------------------------------------------------- pedidos dos jogadores
local function negar(lut: any, acao: string, motivo: string?)
	Combate.privado(lut, "negado", { acao = acao, motivo = motivo })
end

local function lerDir(lut: any, dados: any)
	if type(dados) == "table" and typeof(dados.dir) == "Vector3" then
		local d = dados.dir
		if d.Magnitude > 0.1 and d.Magnitude < 10 then
			lut.dir = Regras.achatar(d)
			lut.dirT = agora()
		end
	end
	return Lutadores.olhar(lut, agora())
end

function Combate.m1(lut: any, dados: any)
	local e = lut.estado
	local t = agora()
	if e.bloqueando then
		Regras.pararBloqueio(e)
	end
	local pode, motivo = Regras.podeAgir(e, t)
	if not pode then
		return negar(lut, "m1", motivo)
	end
	local n = Regras.m1(e, t)
	if not n then
		return negar(lut, "m1", "recarga")
	end
	local dir = lerDir(lut, dados)
	local variante = nil
	if n == 4 and type(dados) == "table" then
		if dados.variante == "cima" or dados.variante == "baixo" then
			variante = dados.variante
		end
	end
	local stand = e.standFora
	lut.andarAcao = 0.55
	local token = e.token
	Combate.efeitoOutros(lut, "acao", { quem = lut.modelo, id = "m1", n = n, variante = variante, t = t, dir = dir, stand = stand })
	Combate.atualizarMovimento(lut)
	task.delay(0.1, function()
		if e.token ~= token or lut.hum.Health <= 0 then
			return
		end
		local hb = if stand then Config.M1.hitboxStand else Config.M1.hitbox
		local d = Lutadores.olhar(lut, agora())
		local folga = 0
		if lut.jogador then
			folga = math.clamp(lut.raiz.AssemblyLinearVelocity:Dot(d) * 0.06, 0, 1.5)
		end
		local cf = Hitbox.cfFrente(lut.raiz, d, hb.frente + folga)
		local alvos = Hitbox.caixa(cf, hb.tam, lut)
		local estilo = lut.stand.m1
		local vfx = if estilo == "fogo" then "impacto_fogo" elseif estilo == "grave" then "impacto_som" elseif estilo == "cristal" then "impacto_rosa" elseif estilo == "sombrinha" then "corte_colorido" elseif estilo == "chutes" then "impacto_dourado" else "impacto"
		for _, alvo in alvos do
			local h: any = {
				m1 = true,
				dano = Regras.danoM1(n, stand),
				atordoar = Config.M1.atordoar,
				tipo = "melee",
				som = if n == 4 then "soco_forte" elseif estilo == "chutes" then "chute" else "soco",
				vfx = if n == 4 then "impacto_forte" else vfx,
				tremor = if n == 4 then 0.45 else 0.12,
			}
			if n < 4 then
				h.empurrar = { frente = Config.M1.empurraoLeve, cima = 0, dur = 0.08 }
			else
				local f = if variante == "cima" then Config.M1.finalCima elseif variante == "baixo" then Config.M1.finalBaixo else Config.M1.final
				local mult = (lut.stand.passiva and lut.stand.passiva.empurraoFinal) or 1
				h.empurrar = { frente = f.frente * mult, cima = f.cima * (if f.cima > 0 then mult else 1), dur = f.dur }
				h.ragdoll = f.ragdoll
				h.quebra = f.quebra
				h.atordoar = 0
				if variante == "baixo" then
					h.vfx = "cratera"
				end
			end
			Combate.acertar(lut, alvo, h, { dir = d })
		end
		-- o 4º golpe também quebra o que estiver na frente
		if n == 4 then
			Mapa.quebrarCaixa(cf, hb.tam, 2, d)
		end
	end)
end

function Combate.golpe(lut: any, slot: any, dados: any)
	local e = lut.estado
	local t = agora()
	if e.bloqueando then
		Regras.pararBloqueio(e)
	end
	local pode, motivo = Regras.podeAgir(e, t)
	if not pode then
		return negar(lut, "golpe", motivo)
	end
	local g, id = Golpes.doSlot(lut.stand, slot)
	if not g or not id then
		return negar(lut, "golpe", "golpe inválido")
	end
	if g.ult then
		if not Regras.desperto(e, t) then
			return negar(lut, "golpe", "precisa DESPERTAR")
		end
		if e.ultUsado and not e.semRecarga then
			return negar(lut, "golpe", "ULT já usada")
		end
	end
	if not Regras.cdPronto(e, id, t) then
		return negar(lut, "golpe", "recarga")
	end
	local dir = lerDir(lut, dados)
	local mult = (lut.stand.passiva and lut.stand.passiva.multRecarga) or 1
	local fim = Regras.usarCd(e, id, (g.cd or 10) * mult, t)
	if g.ult then
		e.ultUsado = true
	end
	e.acaoAte = t + (g.trava or 0.5)
	lut.andarAcao = g.andar or 0.3
	Combate.privado(lut, "cd", { chave = id, fim = fim })
	Combate.efeitoOutros(lut, "acao", { quem = lut.modelo, id = id, t = t, dir = dir, stand = lut.standId })
	if lut.jogador then
		-- o próprio jogador já animou; só confirma o tempo do servidor
		Combate.privado(lut, "confirmado", { id = id, t = t })
	end
	Combate.atualizarMovimento(lut)
	if Executores then
		Executores.executar(lut, g, id, t, dados)
	end
end

function Combate.bloquear(lut: any, ligar: boolean)
	local e = lut.estado
	local t = agora()
	if ligar then
		if not Regras.podeAgir(e, t) then
			return negar(lut, "bloqueio", "ocupado")
		end
		if not Regras.comecarBloqueio(e, t) then
			return negar(lut, "bloqueio", "guarda quebrada")
		end
	else
		Regras.pararBloqueio(e)
	end
	Combate.atualizarMovimento(lut)
	Combate.sincronizar(lut)
end

function Combate.dash(lut: any, dados: any)
	local e = lut.estado
	local t = agora()
	-- Q atordoado = evasiva
	if Regras.atordoado(e, t) then
		return Combate.evasiva(lut)
	end
	local pode, motivo = Regras.podeAgir(e, t)
	if not pode then
		return negar(lut, "dash", motivo)
	end
	local tipo = if type(dados) == "table" and (dados.tipo == "frente" or dados.tipo == "lado" or dados.tipo == "tras") then dados.tipo else "frente"
	local chave = "dash_" .. tipo
	if not Regras.cdPronto(e, chave, t) then
		return negar(lut, "dash", "recarga")
	end
	local def = Config.DASH[tipo]
	local fim = Regras.usarCd(e, chave, def.recarga, t)
	if e.bloqueando then
		Regras.pararBloqueio(e)
	end
	e.acaoAte = t + def.dur
	lut.andarAcao = 1
	Combate.privado(lut, "cd", { chave = chave, fim = fim })
	local dir = if type(dados) == "table" and typeof(dados.mov) == "Vector3" then dados.mov else lut.raiz.CFrame.LookVector
	Combate.efeitoOutros(lut, "acao", { quem = lut.modelo, id = "dash", tipo = tipo, lado = if type(dados) == "table" then dados.lado else nil, t = t, dir = dir })
	if not lut.jogador then
		local d = Regras.achatar(dir)
		Fisica.empurrar(lut, d * def.vel, def.dur)
	end
end

function Combate.evasiva(lut: any)
	local e = lut.estado
	local t = agora()
	if not Regras.podeEvasiva(e, t) then
		return negar(lut, "evasiva", if Regras.evasivaDisponivel(e, t) then "não precisa" else "recarga")
	end
	-- se estava preso num agarrão, solta
	if lut.raiz.Anchored and t >= e.congeladoAte then
		Fisica.soltar(lut)
	end
	if lut.agarradoPor then
		lut.agarradoPor = nil
	end
	Regras.usarEvasiva(e, t)
	Fisica.levantar(lut)
	Fisica.limparEmpurroes(lut.raiz)
	-- empurra quem estava em cima
	for _, l in Hitbox.esfera(lut.raiz.Position, Config.EVASIVA.raioEmpurrao, lut) do
		local v = Regras.achatar(l.raiz.Position - lut.raiz.Position)
		Fisica.empurrar(l, v * Config.EVASIVA.empurrao + Vector3.new(0, 12, 0), 0.14)
		Regras.atordoar(l.estado, t, 0.35)
		Combate.atualizarMovimento(l)
	end
	Combate.privado(lut, "cd", { chave = "evasiva", fim = e.evasivaPronta })
	Combate.efeito("acao", { quem = lut.modelo, id = "evasiva", t = t })
	Combate.atualizarMovimento(lut)
	Combate.sincronizar(lut)
end

function Combate.despertar(lut: any)
	local e = lut.estado
	local t = agora()
	if Regras.desperto(e, t) then
		-- já desperto: G = ULT
		return Combate.golpe(lut, "ult", {})
	end
	if not Regras.podeDespertar(e, t) then
		return negar(lut, "despertar", "barra não está cheia")
	end
	if Regras.atordoado(e, t) then
		return negar(lut, "despertar", "atordoado")
	end
	Regras.despertar(e, t)
	e.acaoAte = t + 1.3
	lut.andarAcao = 0
	e.standFora = true
	Combate.efeito("despertar", { quem = lut.modelo, stand = lut.standId, t = t, ate = e.despertoAte })
	Combate.efeito("anuncio", { texto = string.upper(lut.nome) .. " DESPERTOU 『" .. lut.stand.nome .. "』!", cor = lut.stand.aura })
	Combate.atualizarMovimento(lut)
	Combate.sincronizar(lut)
end

function Combate.alternarStand(lut: any)
	local e = lut.estado
	e.standFora = not e.standFora
	Combate.sincronizar(lut)
	Combate.efeitoOutros(lut, "acao", { quem = lut.modelo, id = "stand", fora = e.standFora, t = agora() })
end

function Combate.pose(lut: any, dados: any)
	local t = agora()
	if not Regras.podeAgir(lut.estado, t) then
		return
	end
	local n = if type(dados) == "table" and type(dados.n) == "number" then math.clamp(math.floor(dados.n), 1, 3) else 1
	Combate.efeitoOutros(lut, "acao", { quem = lut.modelo, id = "pose", n = n, t = t })
end

function Combate.correr(lut: any, ligar: boolean)
	lut.correndo = ligar == true
	Combate.atualizarMovimento(lut)
end

-- porta de entrada dos pedidos (tudo é conferido aqui; o celular só pede)
local LIMITES = { m1 = 0.08, golpe = 0.15, bloqueio = 0.03, dash = 0.12, evasiva = 0.2, despertar = 0.3, stand = 0.3, pose = 0.5, correr = 0.05 }
function Combate.pedido(jogador: Player, tipo: any, dados: any)
	if type(tipo) ~= "string" or not LIMITES[tipo] then
		return
	end
	local lut = Lutadores.doJogador(jogador)
	if not lut or lut.hum.Health <= 0 then
		return
	end
	local t = os.clock()
	local reg = ultimoPedido[jogador]
	if not reg then
		reg = {}
		ultimoPedido[jogador] = reg
	end
	if reg[tipo] and t - reg[tipo] < LIMITES[tipo] then
		return
	end
	reg[tipo] = t
	if type(dados) ~= "table" then
		dados = {}
	end
	if tipo == "m1" then
		Combate.m1(lut, dados)
	elseif tipo == "golpe" then
		Combate.golpe(lut, dados.slot, dados)
	elseif tipo == "bloqueio" then
		Combate.bloquear(lut, dados.ligar == true)
	elseif tipo == "dash" then
		Combate.dash(lut, dados)
	elseif tipo == "evasiva" then
		Combate.evasiva(lut)
	elseif tipo == "despertar" then
		Combate.despertar(lut)
	elseif tipo == "stand" then
		Combate.alternarStand(lut)
	elseif tipo == "pose" then
		Combate.pose(lut, dados)
	elseif tipo == "correr" then
		Combate.correr(lut, dados.ligar == true)
	end
end

------------------------------------------------------------------------------- laço do servidor
local acumulado = 0
local function passo(dt: number)
	local t = agora()
	acumulado += dt
	local lento = acumulado >= 0.25
	if lento then
		acumulado = 0
	end
	for _, lut in Lutadores.todos() do
		local e = lut.estado
		if lut.hum.Health <= 0 or not lut.modelo.Parent then
			continue
		end
		-- quem está voando quebra as paredes no caminho
		if t < e.ragdollAte then
			Mapa.atravessar(lut, lut.forcaVoo or 2)
		elseif lut.modelo:GetAttribute("BB_Ragdoll") and (lut.modelo:GetAttribute("BB_Ragdoll") :: number) > 0 then
			-- acabou o ragdoll: quebra o que ficou "dentro" e levanta
			Mapa.quebrarCaixa(lut.raiz.CFrame, Vector3.new(4, 6, 4), 3, Vector3.new(0, 1, 0))
			Fisica.levantar(lut)
			lut.forcaVoo = nil
		end
		Regras.recuperarGuarda(e, t, dt)
		if lento then
			Combate.atualizarMovimento(lut)
			-- cura fora de combate
			local atraso = Config.REGEN_ATRASO
			if lut.stand.passiva and lut.stand.passiva.regenRapida then
				atraso = 4
			end
			if t - e.ultimoDanoT > atraso and lut.hum.Health < lut.hum.MaxHealth then
				lut.hum.Health = math.min(lut.hum.MaxHealth, lut.hum.Health + Config.REGEN_POR_SEGUNDO * 0.25)
			end
			-- caiu do mapa
			if lut.raiz.Position.Y < Config.ALTURA_MINIMA then
				local spawns = Mapa.spawns()
				if #spawns > 0 then
					Fisica.moverPara(lut, spawns[math.random(1, #spawns)])
				end
			end
			-- despertar acabou
			if e.despertoAte > 0 and t >= e.despertoAte then
				e.despertoAte = 0
				e.ultUsado = false
			end
			Combate.sincronizar(lut)
		end
	end
end

function Combate.iniciar(remotos: any, executores: any, abate: any)
	efeito = remotos.Efeito
	privado = remotos.Privado
	Executores = executores
	aoAbate = abate
	remotos.Acao.OnServerEvent:Connect(Combate.pedido)
	Players.PlayerRemoving:Connect(function(p)
		ultimoPedido[p] = nil
	end)
	RunService.Heartbeat:Connect(passo)
end

function Combate.abate(vitima: any)
	local t = agora()
	local assassino = nil
	if vitima.ultimoAtacante and t - vitima.ultimoAtacanteT <= Config.CREDITO_ABATE and vitima.ultimoAtacante ~= vitima then
		assassino = vitima.ultimoAtacante
	end
	if aoAbate then
		aoAbate(vitima, assassino)
	end
	return assassino
end

-- para os testes e para o ADM
Combate.Stands = Stands
return Combate
