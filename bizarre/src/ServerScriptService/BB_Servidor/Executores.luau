-- BIZARRE BATTLEGROUNDS :: quem executa cada tipo de golpe no servidor
-- (golpe, barragem, projetil, area, investida, agarrar, contra, teleporte, cura, buff e os especiais:
-- tempo parado + rolo compressor, bomba e Bites the Dust da Killer Queen, sol, carnaval, reconstruir...)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BB = ReplicatedStorage:WaitForChild("BB")
local Regras = require(BB:WaitForChild("Regras"))
local Golpes = require(BB:WaitForChild("Golpes"))

local Lutadores = require(script.Parent.Lutadores)
local Hitbox = require(script.Parent.Hitbox)
local Fisica = require(script.Parent.Fisica)
local Mapa = require(script.Parent.Mapa)
local Projeteis = require(script.Parent.Projeteis)
local Combate = require(script.Parent.Combate)

local Executores = {}
local EXEC: { [string]: (ctx: any) -> () } = {}
local ESPECIAL: { [string]: (ctx: any) -> () } = {}

local agora = Combate.agora

------------------------------------------------------------------------------- ajudantes
local function vivo(ctx: any): boolean
	local lut = ctx.lut
	if lut.hum.Health <= 0 or not lut.modelo.Parent then
		return false
	end
	return ctx.livre or lut.estado.token == ctx.token
end

local function esperar(ctx: any, tRel: number): boolean
	local falta = ctx.t0 + tRel - agora()
	if falta > 0 then
		task.wait(falta)
	end
	return vivo(ctx)
end

local function copiar(h: any, extra: any?): any
	local r = {}
	for k, v in h do
		r[k] = v
	end
	if extra then
		for k, v in extra do
			r[k] = v
		end
	end
	return r
end

-- bate numa caixa na frente (h.caixa/h.frente); devolve quem acertou de verdade
local function bater(ctx: any, h: any, ignorar: { [any]: boolean }?): { any }
	local lut = ctx.lut
	local cf = Hitbox.cfFrente(lut.raiz, ctx.dir, h.frente or 4, h.cima, h.lado)
	local tam = h.caixa or Vector3.new(5, 5, 6)
	local acertados = {}
	for _, alvo in Hitbox.caixa(cf, tam, lut) do
		if ignorar and ignorar[alvo] then
			continue
		end
		local hh = if h.tipo then h else copiar(h, { tipo = "melee" })
		local r = Combate.acertar(lut, alvo, hh, { dir = ctx.dir })
		if r == "acertou" then
			table.insert(acertados, alvo)
		end
	end
	if (h.quebra or 0) > 0 then
		Mapa.quebrarCaixa(cf, tam, h.quebra, ctx.dir)
	end
	return acertados
end
Executores.bater = bater

local function paramsCenario(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = Mapa.filtro()
	pcall(function()
		params.RespectCanCollide = true
	end)
	return params
end
Executores.paramsCenario = paramsCenario

local function ondeOChao(pos: Vector3): Vector3
	-- de 6 studs acima (não pega o telhado de cima de quem está dentro de casa)
	local r = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), paramsCenario())
	if r then
		return r.Position
	end
	return Vector3.new(pos.X, 0.6, pos.Z)
end
Executores.ondeOChao = ondeOChao

-- explosão num ponto (bomba, moeda, tanquinho, Bites the Dust...)
local function explosaoEm(lut: any, pos: Vector3, ex: any, dir: Vector3?, principal: any?)
	for _, l in Hitbox.esfera(pos, ex.raio, lut) do
		Combate.acertar(lut, l, {
			dano = ex.dano,
			empurrar = ex.empurrar,
			ragdoll = ex.ragdoll,
			quebra = ex.quebra,
			queima = ex.queima,
			tipo = "area",
			inbloqueavel = ex.inbloqueavel or l == principal,
			vfx = ex.vfx,
			som = nil,
			tremor = ex.tremor,
		}, { origem = pos, dir = dir })
	end
	Mapa.quebrarArea(pos, ex.raio * 0.75, ex.quebra or 1)
	Combate.efeito("explosao", { pos = pos, raio = ex.raio, tipo = ex.vfx, som = ex.som, tremor = ex.tremor })
end
Executores.explosaoEm = explosaoEm

-- cura aos poucos (Soco do Vampiro, Restauração...)
local function curarAosPoucos(lut: any, total: number, dur: number)
	if total <= 0 then
		return
	end
	Combate.efeito("cura", { quem = lut.modelo, dur = dur, stand = lut.standId })
	local passos = math.max(1, math.floor(dur / 0.1))
	for _ = 1, passos do
		task.wait(0.1)
		if lut.hum.Health <= 0 then
			return
		end
		lut.hum.Health = math.min(lut.hum.MaxHealth, lut.hum.Health + total / passos)
	end
end

------------------------------------------------------------------------------- executar
function Executores.executar(lut: any, g: any, id: string, t0: number, dados: any?)
	local e = lut.estado
	local ctx = {
		lut = lut,
		g = g,
		id = id,
		t0 = t0,
		token = e.token,
		dir = Lutadores.olhar(lut, t0),
		dados = dados or {},
	}
	-- golpes de perto grudam no inimigo que está quase na frente
	if (g.alcance or 0) > 0 and g.alcance <= 40 then
		ctx.dir = Hitbox.grudar(lut, ctx.dir, g.alcance + 4, 0.6)
	end
	if g.armadura then
		e.armaduraAte = math.max(e.armaduraAte, t0 + g.armadura[2])
	end
	if g.iframes then
		e.iframesAte = math.max(e.iframesAte, t0 + g.iframes[2])
		Combate.sincronizar(lut)
	end
	-- bots se movem sozinhos (jogadores fazem o impulso no próprio celular)
	if not lut.jogador and g.impulsos then
		for _, i in g.impulsos do
			task.delay(i.t, function()
				if vivo(ctx) then
					Fisica.impulsoProprio(lut, ctx.dir, i.frente or 0, i.cima or 0, i.dur or 0.15)
				end
			end)
		end
	end
	local fn = if g.tipo == "especial" then ESPECIAL[g.especial] else EXEC[g.tipo]
	if not fn then
		warn("[BB] golpe sem executor:", id, g.tipo, g.especial)
		return
	end
	task.spawn(function()
		local ok, err = pcall(fn, ctx)
		if not ok then
			warn("[BB] erro no golpe " .. id .. ": " .. tostring(err))
		end
	end)
end

------------------------------------------------------------------------------- tipos
EXEC.golpe = function(ctx)
	local g = ctx.g
	local acertouAlguem = false
	for _, h in g.hits do
		if not esperar(ctx, h.t) then
			return
		end
		local acertados = bater(ctx, h)
		if #acertados > 0 then
			acertouAlguem = true
		end
		if g.eco and h.marcar and #acertados > 0 then
			local eco = g.eco
			for _, alvo in acertados do
				Combate.efeito("marca", { v = alvo.modelo, ate = agora() + eco.atraso, stand = ctx.lut.standId })
				task.delay(eco.atraso, function()
					if alvo.hum.Health > 0 and ctx.lut.modelo.Parent then
						Combate.acertar(ctx.lut, alvo, copiar(eco, { tipo = "area", inbloqueavel = true }), { dir = Regras.achatar(alvo.raiz.Position - ctx.lut.raiz.Position) })
					end
				end)
			end
		end
	end
	-- DIO: o soco do vampiro suga vida de quem apanhou
	if g.cura and acertouAlguem then
		if esperar(ctx, g.cura.depois or 0) or ctx.lut.hum.Health > 0 then
			curarAosPoucos(ctx.lut, g.cura.total, g.cura.dur or 0.5)
		end
	end
end

EXEC.barragem = function(ctx)
	local g = ctx.g
	local t = g.inicio
	while t <= g.fim do
		if not esperar(ctx, t) then
			return
		end
		bater(ctx, g.hit)
		t += g.intervalo
	end
	if g.final then
		if not esperar(ctx, g.final.t) then
			return
		end
		bater(ctx, g.final)
	end
end

EXEC.projetil = function(ctx)
	local p = ctx.g.proj
	if not esperar(ctx, p.t) then
		return
	end
	local lut = ctx.lut
	local n = p.n or 1
	if p.nComDestrocos and Mapa.quebradasPerto(lut.raiz.Position, p.raioDestrocos or 30) > 0 then
		n = p.nComDestrocos
	end
	local origem = lut.raiz.Position + ctx.dir * 2.5 + Vector3.new(0, 1.2, 0)
	if p.guiado then
		-- o tanquinho anda no chão
		origem = ondeOChao(lut.raiz.Position + ctx.dir * 3) + Vector3.new(0, p.raio or 1, 0)
	end
	for i = 1, n do
		local off = if n > 1 then (i - (n + 1) / 2) * (p.espalhar or 8) else 0
		local d = CFrame.Angles(0, math.rad(off), 0):VectorToWorldSpace(ctx.dir)
		Projeteis.lancar(lut, p, origem, d, ctx.id)
	end
end

EXEC.area = function(ctx)
	local g = ctx.g
	local lut = ctx.lut
	for _, a in g.areas do
		local rep = a.repetir or 1
		for k = 0, rep - 1 do
			if not esperar(ctx, a.t + k * (a.intervalo or 0)) then
				return
			end
			local raiz = lut.raiz
			local centro = if a.centro == "frente" then raiz.Position + ctx.dir * (a.dist or 6) else raiz.Position
			local alvos
			if a.cone then
				alvos = Hitbox.cone(centro, ctx.dir, a.cone.angulo, a.cone.alcance, lut)
			else
				alvos = Hitbox.esfera(centro, a.raio, lut)
			end
			local h = copiar(a, { tipo = "area" })
			for _, alvo in alvos do
				Combate.acertar(lut, alvo, h, { dir = ctx.dir, origem = centro })
			end
			if (a.quebra or 0) > 0 then
				if a.cone then
					local cf = Hitbox.cfFrente(raiz, ctx.dir, a.cone.alcance / 2)
					Mapa.quebrarCaixa(cf, Vector3.new(a.cone.alcance * 0.8, 8, a.cone.alcance), a.quebra, ctx.dir)
				else
					Mapa.quebrarArea(centro, a.raioQuebra or a.raio, a.quebra)
				end
			end
			if a.quebraVidroRaio then
				Mapa.quebrarVidros(centro, a.quebraVidroRaio)
			end
			if a.vfx and not a.repetir then
				Combate.efeito("area", { quem = lut.modelo, vfx = a.vfx, pos = centro, raio = a.raio or (a.cone and a.cone.alcance) or 10, dir = ctx.dir, som = a.som, tremor = a.tremor, stand = lut.standId })
			end
		end
	end
end

-- agarrão: segura a vítima na frente, bate e arremessa
local function agarrar(ctx: any, alvo: any)
	local lut = ctx.lut
	local ag = ctx.g.agarrao
	local t0 = agora()
	local r = Combate.acertar(lut, alvo, { dano = 0.5, atordoar = ag.duracao + 0.4, inbloqueavel = true, tipo = "melee", som = "soco", vfx = "impacto" }, { dir = ctx.dir })
	if r ~= "acertou" then
		return
	end
	lut.estado.acaoAte = math.max(lut.estado.acaoAte, t0 + ag.duracao + 0.1)
	lut.andarAcao = 0
	Combate.atualizarMovimento(lut)
	alvo.agarradoPor = lut
	Fisica.prender(alvo)
	if ag.pedra then
		alvo.modelo:SetAttribute("BB_Pedra", t0 + ag.duracao)
	end
	Combate.efeito("agarrao", { quem = lut.modelo, alvo = alvo.modelo, t = t0, dur = ag.duracao, id = ctx.id })
	local conexao = RunService.Heartbeat:Connect(function()
		if alvo.agarradoPor ~= lut or not alvo.raiz.Parent or not lut.raiz.Parent then
			return
		end
		alvo.raiz.CFrame = lut.raiz.CFrame * CFrame.new(0, 0, -ag.distancia) * CFrame.Angles(0, math.pi, 0)
	end)
	local function soltar()
		conexao:Disconnect()
		if alvo.agarradoPor == lut then
			alvo.agarradoPor = nil
		end
		if agora() >= alvo.estado.congeladoAte then
			Fisica.soltar(alvo)
		end
		alvo.modelo:SetAttribute("BB_Pedra", nil)
	end
	for _, s in ag.sequencia do
		local falta = t0 + s.t - agora()
		if falta > 0 then
			task.wait(falta)
		end
		if lut.hum.Health <= 0 or lut.estado.token ~= ctx.token or alvo.agarradoPor ~= lut then
			soltar()
			return
		end
		Combate.acertar(lut, alvo, { dano = s.dano, atordoar = ag.duracao - s.t + 0.4, inbloqueavel = true, tipo = "melee", som = s.som, vfx = s.vfx }, { dir = lut.raiz.CFrame.LookVector })
	end
	local falta = t0 + ag.final.t - agora()
	if falta > 0 then
		task.wait(falta)
	end
	local ainda = alvo.agarradoPor == lut and lut.hum.Health > 0
	soltar()
	if ainda then
		Combate.acertar(lut, alvo, copiar(ag.final, { inbloqueavel = true, tipo = "melee" }), { dir = Regras.achatar(lut.raiz.CFrame.LookVector) })
	end
end
Executores.agarrar = agarrar

EXEC.investida = function(ctx)
	local g = ctx.g
	local lut = ctx.lut
	local inv = g.investida
	if not esperar(ctx, inv.t) then
		return
	end
	if not lut.jogador then
		Fisica.impulsoProprio(lut, ctx.dir, inv.vel, 0, inv.dur)
	end
	local fim = ctx.t0 + inv.t + inv.dur + 0.06
	local ultimo: { [any]: number } = {}
	while agora() < fim do
		if not vivo(ctx) then
			return
		end
		local cf = Hitbox.cfFrente(lut.raiz, ctx.dir, inv.frente or 3)
		local tam = inv.caixa or Vector3.new(6, 6, 6)
		Mapa.quebrarCaixa(cf, tam, 1, ctx.dir)
		local alvos = Hitbox.caixa(cf, tam, lut)
		if #alvos > 0 then
			if g.agarrao then
				Fisica.pararMovimento(lut)
				agarrar(ctx, alvos[1])
				return
			elseif inv.multi then
				for _, alvo in alvos do
					if not ultimo[alvo] or agora() - ultimo[alvo] >= (inv.intervalo or 0.12) then
						ultimo[alvo] = agora()
						Combate.acertar(lut, alvo, copiar(g.hit, { tipo = "melee" }), { dir = ctx.dir })
					end
				end
			else
				Fisica.pararMovimento(lut)
				for _, alvo in alvos do
					Combate.acertar(lut, alvo, copiar(g.hit, { tipo = "melee" }), { dir = ctx.dir })
				end
				Combate.efeito("area", { quem = lut.modelo, vfx = g.hit.vfx or "impacto_forte", pos = alvos[1].raiz.Position, raio = 6, dir = ctx.dir, som = nil })
				return
			end
		end
		task.wait(0.03)
	end
	if g.final then
		if not esperar(ctx, g.final.t) then
			return
		end
		bater(ctx, g.final)
	end
end

EXEC.agarrar = function(ctx)
	local g = ctx.g
	if g.investida then
		return EXEC.investida(ctx)
	end
	local ga = g.golpeAgarra
	if not esperar(ctx, ga.t) then
		return
	end
	local lut = ctx.lut
	local cf = Hitbox.cfFrente(lut.raiz, ctx.dir, ga.frente or 4)
	local alvos = Hitbox.caixa(cf, ga.caixa or Vector3.new(6, 6, 7), lut)
	if #alvos == 0 then
		return
	end
	table.sort(alvos, function(a, b)
		return (a.raiz.Position - lut.raiz.Position).Magnitude < (b.raiz.Position - lut.raiz.Position).Magnitude
	end)
	agarrar(ctx, alvos[1])
end

EXEC.contra = function(ctx)
	local c = ctx.g.contra
	local e = ctx.lut.estado
	local estado = {
		de = ctx.t0 + c.inicio,
		ate = ctx.t0 + c.inicio + c.janela,
		tipos = c.tipos,
		frenteApenas = c.frenteApenas,
		reflete = c.reflete,
		continua = c.continua,
		ctx = ctx,
		respondeu = false,
	}
	e.contra = estado
	task.delay(c.inicio + c.janela + 0.05, function()
		if e.contra == estado then
			e.contra = nil
		end
	end)
end

-- alguém bateu em quem estava em postura de contra-ataque
function Executores.contraAtivado(defensor: any, atk: any, _h: any)
	local e = defensor.estado
	local c = e.contra
	if not c then
		return
	end
	local ctx = c.ctx
	local g = ctx.g
	local t = agora()
	Combate.efeito("contra", { quem = defensor.modelo, atk = atk.modelo, id = ctx.id })
	if not c.continua then
		e.contra = nil
	end
	if c.respondeu then
		return
	end
	c.respondeu = true
	Regras.atordoar(atk.estado, t, 0.7, true)
	Combate.atualizarMovimento(atk)
	local r = g.resposta
	if not r then
		return
	end
	task.spawn(function()
		local t0 = agora()
		e.acaoAte = math.max(e.acaoAte, t0 + 0.6)
		e.iframesAte = math.max(e.iframesAte, t0 + 0.4)
		if r.teleAtras then
			local atras = atk.raiz.CFrame * CFrame.new(0, 0, r.teleAtras)
			local cf = CFrame.lookAt(atras.Position, Vector3.new(atk.raiz.Position.X, atras.Position.Y, atk.raiz.Position.Z))
			Fisica.moverPara(defensor, cf)
			Combate.efeito("teleporte", { quem = defensor.modelo, para = cf.Position, stand = defensor.standId })
		end
		Combate.efeito("acao", { quem = defensor.modelo, id = ctx.id, resposta = true, t = t0, stand = defensor.standId })
		local ctx2 = { lut = defensor, g = g, id = ctx.id, t0 = t0, token = e.token, livre = true, dir = Regras.achatar(atk.raiz.Position - defensor.raiz.Position) }
		for _, h in r.hits do
			if not esperar(ctx2, h.t) then
				return
			end
			ctx2.dir = Regras.achatar(atk.raiz.Position - defensor.raiz.Position)
			Combate.acertar(defensor, atk, copiar(h, { tipo = "melee" }), { dir = ctx2.dir })
			Mapa.quebrarCaixa(Hitbox.cfFrente(defensor.raiz, ctx2.dir, 4), Vector3.new(6, 6, 7), h.quebra or 0, ctx2.dir)
		end
	end)
end

EXEC.teleporte = function(ctx)
	local g = ctx.g
	local lut = ctx.lut
	local tp = g.teleporte
	if not esperar(ctx, tp.t) then
		return
	end
	local alvo = Hitbox.maisPertoNaFrente(lut, ctx.dir, tp.alcance, tp.cone)
	local de = lut.raiz.Position
	local cf
	if alvo then
		local atras = alvo.raiz.CFrame * CFrame.new(0, 0, tp.atras or 3.5)
		local olhar = Vector3.new(alvo.raiz.Position.X, atras.Position.Y, alvo.raiz.Position.Z)
		cf = CFrame.lookAt(atras.Position, olhar)
		ctx.dir = Regras.achatar(olhar - atras.Position)
	else
		local p = de + ctx.dir * (tp.semAlvo or 14)
		-- não atravessa parede: para antes
		local hit = workspace:Raycast(de, p - de, paramsCenario())
		if hit then
			p = hit.Position - ctx.dir * 2
		end
		cf = CFrame.lookAt(p, p + ctx.dir)
	end
	Fisica.moverPara(lut, cf)
	Combate.efeito("teleporte", { quem = lut.modelo, de = de, para = cf.Position, stand = lut.standId })
	for _, h in g.hits or {} do
		if not esperar(ctx, h.t) then
			return
		end
		bater(ctx, h)
	end
end

EXEC.cura = function(ctx)
	local c = ctx.g.cura
	curarAosPoucos(ctx.lut, c.total, c.dur)
end

-- ARMOR OFF (Silver Chariot): mais rápido e mais forte por um tempo
EXEC.buff = function(ctx)
	local b = ctx.g.buff
	local lut = ctx.lut
	local e = lut.estado
	if not esperar(ctx, b.t or 0.2) then
		return
	end
	local t = agora()
	local ate = t + b.dur
	e.buffAte = ate
	e.buffDano = b.dano or 1
	lut.buffAte = ate
	lut.buffVel = b.velocidade or 1
	lut.modelo:SetAttribute("BB_Buff", ate)
	if b.standSemArmadura then
		lut.modelo:SetAttribute("BB_SemArmadura", ate)
	end
	Combate.efeito("buff", { quem = lut.modelo, ate = ate, stand = lut.standId, semArmadura = b.standSemArmadura })
	Combate.atualizarMovimento(lut)
	task.delay(b.dur + 0.05, function()
		if lut.modelo.Parent and (lut.buffAte or 0) <= agora() then
			lut.modelo:SetAttribute("BB_Buff", nil)
			lut.modelo:SetAttribute("BB_SemArmadura", nil)
			Combate.atualizarMovimento(lut)
		end
	end)
end

------------------------------------------------------------------------------- especiais
ESPECIAL.voo = function(ctx)
	EXEC.area(ctx)
end

ESPECIAL.tempoParado = function(ctx)
	local lut = ctx.lut
	local tp = ctx.g.tempo
	if not esperar(ctx, tp.t) then
		return
	end
	local t = agora()
	local fim = t + tp.duracao
	local congelados = {}
	for _, l in Hitbox.esfera(lut.raiz.Position, tp.raio, lut) do
		l.estado.congeladoAte = fim
		l.congeladoPor = lut
		l.filaTempo = {}
		Regras.interromper(l.estado, t)
		Fisica.prender(l)
		l.modelo:SetAttribute("BB_Congelado", fim)
		Combate.atualizarMovimento(l)
		table.insert(congelados, l)
	end
	Projeteis.congelar(fim, lut)
	Combate.efeito("tempo", { dono = lut.modelo, inicio = t, fim = fim, centro = lut.raiz.Position, raio = tp.raio, stand = lut.standId })
	lut.estado.acaoAte = t + 0.15
	Combate.atualizarMovimento(lut)
	-- DIO: "ROAD ROLLER DA!" cai em cima do congelado mais perto, pouco antes do tempo voltar
	local rolo = tp.rolo
	if rolo then
		task.wait(math.max(0, tp.duracao - rolo.antes))
		local alvo, melhor = nil, rolo.raio
		for _, l in congelados do
			local d = (l.raiz.Position - lut.raiz.Position).Magnitude
			if l.hum.Health > 0 and d <= melhor then
				alvo, melhor = l, d
			end
		end
		if alvo and lut.hum.Health > 0 then
			Combate.efeito("rolo", { quem = lut.modelo, alvo = alvo.modelo, pos = alvo.raiz.Position, t = agora(), ate = fim, stand = lut.standId })
			task.wait(0.35)
			Combate.acertar(lut, alvo, { dano = rolo.dano, tipo = "area", inbloqueavel = true, empurrar = rolo.empurrar, ragdoll = rolo.ragdoll, quebra = 3, vfx = "explosao_fogo", som = "soco_forte" }, { origem = alvo.raiz.Position + Vector3.new(0, -1, 0) })
		end
		local falta = fim - agora()
		if falta > 0 then
			task.wait(falta)
		end
		if alvo then
			Mapa.quebrarArea(alvo.raiz.Position, 9, 3)
			Combate.efeito("explosao", { pos = alvo.raiz.Position, raio = 12, tipo = "explosao_fogo", som = "explosao_grande", tremor = 1.2, impactFrame = true })
		end
	else
		task.wait(tp.duracao)
	end
	Combate.efeito("tempoVolta", { dono = lut.modelo })
	for _, l in congelados do
		l.modelo:SetAttribute("BB_Congelado", nil)
		l.estado.congeladoAte = 0
		l.congeladoPor = nil
		if not l.agarradoPor then
			Fisica.soltar(l)
		end
		local fila = l.filaTempo
		l.filaTempo = nil
		Combate.atualizarMovimento(l)
		if fila and #fila > 0 and l.hum.Health > 0 then
			local total = 0
			local maior = nil
			for _, item in fila do
				total += item.h.dano or 0
				local f = if item.h.empurrar then (item.h.empurrar.frente or 0) else 0
				if not maior or f > ((maior.h.empurrar and maior.h.empurrar.frente) or 0) then
					maior = item
				end
			end
			local emp = if maior and maior.h.empurrar then copiar(maior.h.empurrar, { frente = math.max(50, maior.h.empurrar.frente or 0) * 1.2, cima = math.max(22, maior.h.empurrar.cima or 0) }) else { frente = 55, cima = 24, dur = 0.24 }
			Combate.acertar(lut, l, {
				dano = total,
				tipo = "melee",
				inbloqueavel = true,
				ragdoll = 1.6,
				empurrar = emp,
				vfx = "impacto_enorme",
				som = "soco_forte",
				tremor = 0.9,
				impactFrame = true,
				quebra = 2,
			}, { dir = if maior then maior.dir else nil })
		end
	end
end

ESPECIAL.carnaval = function(ctx)
	local lut = ctx.lut
	local c = ctx.g.carnaval
	local candidatos = Hitbox.esfera(lut.raiz.Position, c.raio, lut)
	table.sort(candidatos, function(a, b)
		return (a.raiz.Position - lut.raiz.Position).Magnitude < (b.raiz.Position - lut.raiz.Position).Magnitude
	end)
	local alvos = {}
	for i = 1, math.min(#candidatos, c.maxAlvos) do
		table.insert(alvos, candidatos[i])
	end
	task.wait(0.15)
	if #alvos == 0 then
		for _, l in Hitbox.esfera(lut.raiz.Position, 12, lut) do
			Combate.acertar(lut, l, { dano = 8, empurrar = { radial = true, frente = 50, cima = 30, dur = 0.2 }, ragdoll = 1.2, tipo = "area", vfx = "impacto_prata", som = "corte" }, { origem = lut.raiz.Position })
		end
		Combate.efeito("area", { quem = lut.modelo, vfx = c.vfxFinal or "prata", pos = lut.raiz.Position, raio = 14, stand = lut.standId })
		return
	end
	local golpes = if #alvos == 1 then c.golpesPorAlvo + 2 else c.golpesPorAlvo
	for _, alvo in alvos do
		if lut.hum.Health <= 0 then
			return
		end
		if alvo.hum.Health <= 0 then
			continue
		end
		local ang = math.random() * math.pi * 2
		local pos = alvo.raiz.Position + Vector3.new(math.cos(ang) * 4, 0, math.sin(ang) * 4)
		local olhar = Vector3.new(alvo.raiz.Position.X, pos.Y, alvo.raiz.Position.Z)
		Fisica.moverPara(lut, CFrame.lookAt(pos, olhar))
		Combate.efeito("teleporte", { quem = lut.modelo, para = pos, stand = lut.standId })
		for _ = 1, golpes do
			task.wait(c.intervalo)
			Combate.acertar(lut, alvo, { dano = c.dano, atordoar = 1.4, inbloqueavel = true, tipo = "melee", som = "estocada", vfx = c.vfxCorte or "corte_prata", empurrar = { frente = 2, cima = 0, dur = 0.05 } }, { dir = Regras.achatar(alvo.raiz.Position - lut.raiz.Position) })
		end
	end
	task.wait(0.18)
	Combate.efeito("area", { quem = lut.modelo, vfx = c.vfxFinal or "prata", pos = lut.raiz.Position, raio = 16, som = "corte", tremor = 0.8, stand = lut.standId })
	for _, alvo in alvos do
		Combate.acertar(lut, alvo, copiar(c.final, { inbloqueavel = true, tipo = "area", vfx = "impacto_prata", som = "corte", empurrar = copiar(c.final.empurrar, { radial = true }), impactFrame = true }), { origem = lut.raiz.Position })
	end
end

ESPECIAL.onda = function(ctx)
	local lut = ctx.lut
	local o = ctx.g.onda
	if not esperar(ctx, o.t) then
		return
	end
	local dir = ctx.dir
	local chao = ondeOChao(lut.raiz.Position)
	local origem = Vector3.new(lut.raiz.Position.X, chao.Y, lut.raiz.Position.Z) + dir * 3
	local dur = o.alcance / o.vel
	local t1 = agora()
	Combate.efeito("onda", { quem = lut.modelo, origem = origem, dir = dir, vel = o.vel, dur = dur, largura = o.largura, altura = o.altura, visual = o.visual, t = t1, som = o.som })
	local pegos: { [any]: boolean } = {}
	while agora() - t1 < dur do
		local d = (agora() - t1) * o.vel
		local pos = origem + dir * d + Vector3.new(0, o.altura / 2, 0)
		local cf = CFrame.lookAt(pos, pos + dir)
		local tam = Vector3.new(o.largura, o.altura, 6)
		for _, alvo in Hitbox.caixa(cf, tam, lut) do
			if not pegos[alvo] then
				pegos[alvo] = true
				Combate.acertar(lut, alvo, { dano = o.dano, empurrar = o.empurrar, ragdoll = o.ragdoll, quebra = o.quebra, queima = o.queima, tipo = "area", vfx = "explosao_fogo", som = "fogo", tremor = 0.5 }, { dir = dir })
			end
		end
		Mapa.quebrarCaixa(cf, tam, o.quebra, dir)
		task.wait(0.05)
	end
end

ESPECIAL.sol = function(ctx)
	local lut = ctx.lut
	local s = ctx.g.sol
	local acima = lut.raiz.Position + Vector3.new(0, 24, 0)
	local alvoPos = ondeOChao(lut.raiz.Position + ctx.dir * s.dist)
	Combate.efeito("sol", { quem = lut.modelo, acima = acima, alvo = alvoPos, formar = s.formar, cair = s.cair, t = agora(), raio = s.raio, visual = s.visual })
	task.wait(s.formar + s.cair)
	for _, l in Hitbox.esfera(alvoPos, s.raio, lut) do
		local d = (l.raiz.Position - alvoPos).Magnitude
		local f = math.clamp(d / s.raio, 0, 1)
		local dano = s.danoCentro + (s.danoBorda - s.danoCentro) * f
		Combate.acertar(lut, l, { dano = dano, empurrar = s.empurrar, ragdoll = s.ragdoll, quebra = 3, queima = s.queima, tipo = "area", quebraGuarda = true, vfx = "explosao_fogo", som = nil, tremor = 1.2, impactFrame = true }, { origem = alvoPos, dir = ctx.dir })
	end
	Mapa.quebrarArea(alvoPos, s.raio * 0.85, s.quebra)
	Combate.efeito("explosao", { pos = alvoPos, raio = s.raio, tipo = "sol", som = "explosao_grande", tremor = 1.4, impactFrame = true })
end

local function prenderNaPedra(l: any, segundos: number, parte: BasePart?)
	Fisica.prender(l)
	l.modelo:SetAttribute("BB_Preso", agora() + segundos)
	task.delay(segundos, function()
		l.modelo:SetAttribute("BB_Preso", nil)
		if not l.agarradoPor and agora() >= l.estado.congeladoAte then
			Fisica.soltar(l)
		end
		-- sai quebrando a parede (não fica entalado)
		if parte and parte.Parent then
			Mapa.quebrar(parte, Vector3.new(0, 1, 0), 9)
		end
		if l.raiz.Parent then
			Mapa.quebrarCaixa(l.raiz.CFrame, Vector3.new(4, 6, 4), 9, Vector3.new(0, 1, 0))
		end
	end)
end

ESPECIAL.reconstruir = function(ctx)
	local lut = ctx.lut
	local r = ctx.g.reconstruir
	if not esperar(ctx, r.t) then
		return
	end
	local pos = lut.raiz.Position
	local voltaram = Mapa.restaurarPerto(pos, r.raio, true)
	Combate.efeito("reconstruir", { quem = lut.modelo, pos = pos, raio = r.raio, n = #voltaram })
	if #voltaram == 0 then
		local s = r.semNada
		for _, l in Hitbox.esfera(pos, s.raio, lut) do
			Combate.acertar(lut, l, { dano = s.dano, empurrar = s.empurrar, atordoar = 0.5, tipo = "area", vfx = "impacto_rosa", som = "cristal" }, { origem = pos })
		end
		Combate.efeito("area", { quem = lut.modelo, vfx = "onda_rosa", pos = pos, raio = s.raio })
		return
	end
	local afetados: { [any]: any } = {}
	for _, parte in voltaram do
		for _, l in Hitbox.caixa(parte.CFrame, parte.Size + Vector3.new(0.6, 0.6, 0.6), lut) do
			if not afetados[l] or afetados[l] == "perto" then
				afetados[l] = parte
			end
		end
		local tamMax = math.max(parte.Size.X, parte.Size.Y, parte.Size.Z)
		for _, l in Hitbox.esfera(parte.Position, r.raioPerto + tamMax / 2, lut) do
			if not afetados[l] then
				afetados[l] = "perto"
			end
		end
	end
	for l, tipo in afetados do
		if tipo ~= "perto" then
			local res = Combate.acertar(lut, l, { dano = r.danoPreso, atordoar = r.preso, inbloqueavel = true, tipo = "area", vfx = "estilhaco", som = "pedra", tremor = 0.5 }, { dir = ctx.dir })
			if res == "acertou" then
				prenderNaPedra(l, r.preso, tipo)
			end
		else
			Combate.acertar(lut, l, { dano = r.danoPerto, atordoar = 0.6, empurrar = { radial = true, frente = 24, cima = 10, dur = 0.12 }, tipo = "area", vfx = "impacto_rosa", som = "pedra" }, { origem = pos })
		end
	end
end

ESPECIAL.saudade = function(ctx)
	local lut = ctx.lut
	local s = ctx.g.saudade
	task.wait(0.3)
	local pos = lut.raiz.Position
	local voltaram = Mapa.restaurarPerto(pos, s.raioMapa, true)
	Combate.efeito("reconstruir", { quem = lut.modelo, pos = pos, raio = s.raioMapa, n = #voltaram, ult = true })
	lut.hum.Health = math.min(lut.hum.MaxHealth, lut.hum.Health + s.cura)
	Combate.efeito("cura", { quem = lut.modelo, dur = 1.2, stand = lut.standId })
	local presos = {}
	for _, l in Hitbox.esfera(pos, s.raio, lut) do
		local r = Combate.acertar(lut, l, { dano = 2, atordoar = s.preso + 1.2, inbloqueavel = true, tipo = "area", vfx = "estilhaco", som = "pedra" }, { origem = pos })
		if r == "acertou" then
			Fisica.prender(l)
			l.modelo:SetAttribute("BB_Pedra", agora() + s.preso + 0.8)
			table.insert(presos, l)
		end
	end
	task.wait(0.5)
	for _, l in presos do
		if l.hum.Health > 0 then
			Combate.efeito("acao", { quem = lut.modelo, id = "stand_visita", alvo = l.modelo, t = agora(), stand = lut.standId })
			for _ = 1, 3 do
				Combate.acertar(lut, l, { dano = s.dano / 3, atordoar = 1.5, inbloqueavel = true, tipo = "melee", vfx = "impacto_rosa", som = "soco_rapido" }, { dir = Regras.achatar(l.raiz.Position - pos) })
				task.wait(0.07)
			end
		end
	end
	task.wait(0.25)
	for _, l in presos do
		l.modelo:SetAttribute("BB_Pedra", nil)
		if not l.agarradoPor and agora() >= l.estado.congeladoAte then
			Fisica.soltar(l)
		end
		Combate.acertar(lut, l, { dano = s.final, empurrar = { radial = true, frente = 70, cima = 34, dur = 0.24 }, ragdoll = 1.6, quebra = 2, inbloqueavel = true, tipo = "area", vfx = "estilhaco", som = "pedra", tremor = 0.8, impactFrame = true }, { origem = pos })
	end
end

-- Killer Queen: "o que eu tocar vira bomba". Toca o inimigo (ou um objeto) e explode depois.
ESPECIAL.bomba = function(ctx)
	local b = ctx.g.bomba
	local lut = ctx.lut
	if not esperar(ctx, b.t) then
		return
	end
	local cf = Hitbox.cfFrente(lut.raiz, ctx.dir, b.frente or 4)
	local alvos = Hitbox.caixa(cf, b.caixa or Vector3.new(6, 6, 7), lut)
	table.sort(alvos, function(a, c)
		return (a.raiz.Position - lut.raiz.Position).Magnitude < (c.raiz.Position - lut.raiz.Position).Magnitude
	end)
	local alvo = alvos[1]
	if alvo then
		local r = Combate.acertar(lut, alvo, copiar(b.toque, { tipo = "melee", som = "soco", vfx = "impacto_rosa" }), { dir = ctx.dir })
		if r ~= "acertou" then
			return
		end
		local ate = agora() + b.atraso
		alvo.modelo:SetAttribute("BB_Bomba", ate)
		Combate.efeito("marca", { v = alvo.modelo, ate = ate, stand = lut.standId, bomba = true })
		task.wait(b.atraso)
		alvo.modelo:SetAttribute("BB_Bomba", nil)
		if alvo.hum.Health > 0 and alvo.modelo.Parent and lut.modelo.Parent then
			explosaoEm(lut, alvo.raiz.Position, b.explosao, ctx.dir, alvo)
		end
		return
	end
	-- errou o inimigo: a parede/objeto da frente vira bomba
	local parte = Mapa.maisPerto(cf, b.caixa or Vector3.new(6, 6, 7))
	if parte then
		local pos = parte.Position
		Combate.efeito("marca", { pos = pos, ate = agora() + b.atraso, stand = lut.standId, bomba = true })
		task.wait(b.atraso)
		if lut.modelo.Parent then
			explosaoEm(lut, pos, b.explosao, ctx.dir)
		end
	end
end

-- Killer Queen Bites the Dust: o tempo volta alguns segundos. Você volta para onde estava, com a
-- vida que tinha, a cidade em volta se conserta e quem te bateu nesse tempo explode.
ESPECIAL.rebobinar = function(ctx)
	local lut = ctx.lut
	local r = ctx.g.rebobinar
	local t0 = agora()
	Combate.efeito("rebobinar", { quem = lut.modelo, t = t0, dur = r.t, stand = lut.standId })
	if not esperar(ctx, r.t) then
		return
	end
	local t = agora()
	local alvoT = t - r.segundos
	local hist = lut.historico or {}
	local registro = nil
	for _, h in hist do
		if h.t <= alvoT then
			registro = h
		end
	end
	registro = registro or hist[1]
	local culpados = {}
	for atk, quando in lut.atacadoPor or {} do
		if quando >= alvoT and atk ~= lut and atk.hum and atk.hum.Health > 0 and atk.modelo.Parent then
			table.insert(culpados, atk)
		end
	end
	local de = lut.raiz.Position
	if registro then
		if registro.hp > lut.hum.Health then
			lut.hum.Health = math.min(lut.hum.MaxHealth, registro.hp)
		end
		if (registro.cf.Position - de).Magnitude > 2 then
			Fisica.moverPara(lut, registro.cf)
		end
	end
	local voltaram = Mapa.restaurarPerto(lut.raiz.Position, r.raio, true)
	Combate.efeito("rebobinarFim", { quem = lut.modelo, de = de, para = if registro then registro.cf.Position else de, n = #voltaram, stand = lut.standId })
	task.wait(0.25)
	local ex = { raio = 7, dano = r.dano, empurrar = r.empurrar, ragdoll = r.ragdoll, quebra = r.quebra, inbloqueavel = true, vfx = "explosao_fogo", som = "explosao_grande", tremor = 0.9 }
	if #culpados == 0 then
		-- ninguém te bateu: quem estiver perto leva uma explosão menor
		for _, l in Hitbox.esfera(lut.raiz.Position, 16, lut) do
			table.insert(culpados, l)
		end
		ex.dano = r.dano * 0.6
	end
	for _, atk in culpados do
		if atk.hum.Health > 0 and atk.modelo.Parent and (atk.raiz.Position - lut.raiz.Position).Magnitude <= r.raio * 2 then
			explosaoEm(lut, atk.raiz.Position, ex, Regras.achatar(atk.raiz.Position - lut.raiz.Position), atk)
		end
	end
end

ESPECIAL.paredao = function(ctx)
	local lut = ctx.lut
	local p = ctx.g.paredao
	if not esperar(ctx, p.t) then
		return
	end
	local dir = ctx.dir
	local chao = ondeOChao(lut.raiz.Position + dir * p.dist)
	local base = CFrame.lookAt(chao, chao + dir)
	local nx, ny = 3, 2
	local bw, bh = p.largura / nx, p.altura / ny
	for i = 1, nx do
		for j = 1, ny do
			local cf = base * CFrame.new((i - (nx + 1) / 2) * bw, (j - 0.5) * bh, 0)
			Mapa.temporaria({ n = "CaixaSom", s = Vector3.new(bw - 0.25, bh - 0.25, 3), cf = cf, c = Color3.fromRGB(26, 24, 32), m = "SmoothPlastic", f = "Block" }, p.duracao)
			Mapa.temporaria({ n = "ConeSom", s = Vector3.new(0.5, bh * 0.66, bh * 0.66), cf = cf * CFrame.new(0, 0, -1.6) * CFrame.Angles(0, math.rad(90), 0), c = Color3.fromRGB(70, 66, 84), m = "Metal", f = "Cylinder" }, p.duracao)
		end
	end
	Combate.efeito("paredao", { quem = lut.modelo, cf = base, largura = p.largura, altura = p.altura, duracao = p.duracao, stand = lut.standId })
	local fimT = agora() + p.duracao
	while agora() < fimT do
		task.wait(p.pulso)
		if not lut.modelo.Parent then
			return
		end
		local frenteCf = base * CFrame.new(0, p.altura / 2, -p.raioPulso / 2 - 1.6)
		for _, l in Hitbox.caixa(frenteCf, Vector3.new(p.largura + 4, p.altura + 4, p.raioPulso), lut) do
			Combate.acertar(lut, l, { dano = p.dano, empurrar = p.empurrar, atordoar = 0.3, tipo = "area", vfx = "impacto_som" }, { dir = dir })
		end
		Combate.efeito("pulso", { cf = base, largura = p.largura, altura = p.altura })
	end
end

ESPECIAL.baile = function(ctx)
	local lut = ctx.lut
	local b = ctx.g.baile
	if not esperar(ctx, b.inicio) then
		return
	end
	Combate.efeito("baile", { quem = lut.modelo, t = agora(), batidas = b.batidas, intervalo = b.intervalo, raio = b.raio })
	for _ = 1, b.batidas do
		local pos = lut.raiz.Position
		for _, l in Hitbox.esfera(pos, b.raio, lut) do
			Combate.acertar(lut, l, { dano = b.dano, empurrar = b.empurrarBatida, atordoar = 0.7, tipo = "area", vfx = "impacto_som" }, { origem = pos })
		end
		Mapa.quebrarVidros(pos, b.raio)
		task.wait(b.intervalo)
	end
	local pos = lut.raiz.Position
	for _, l in Hitbox.esfera(pos, b.raio, lut) do
		Combate.acertar(lut, l, copiar(b.final, { tipo = "area", vfx = "explosao_som", som = "grave", tremor = 1.2, impactFrame = true }), { origem = pos })
	end
	Mapa.quebrarArea(pos, b.raio * 0.7, b.final.quebra)
	Combate.efeito("explosao", { pos = pos, raio = b.raio, tipo = "som", som = "grave", tremor = 1.3, impactFrame = true })
end

------------------------------------------------------------------------------- projéteis
local function acertarProjetil(p: any, alvo: any, _pos: Vector3)
	local d = p.def
	Combate.acertar(p.dono, alvo, {
		dano = d.dano,
		atordoar = d.atordoar,
		empurrar = d.empurrar,
		ragdoll = d.ragdoll,
		quebra = d.quebra,
		tipo = "projetil",
		som = d.som,
		vfx = d.vfx,
	}, { dir = p.dir })
end

local function explodir(p: any, pos: Vector3)
	explosaoEm(p.dono, pos, p.def.explosao, p.dir)
end

local function contraProjetil(alvo: any, p: any): boolean
	local c = alvo.estado.contra
	local t = agora()
	if not c or t < c.de or t > c.ate or not c.tipos.projetil then
		return false
	end
	if c.frenteApenas and Regras.achatar(alvo.raiz.CFrame.LookVector):Dot(-p.dir) <= 0 then
		return false
	end
	if c.reflete then
		Combate.efeito("contra", { quem = alvo.modelo, reflexo = true })
		return true
	end
	return false
end

-- memória de onde cada lutador estava e com quanta vida (para o Bites the Dust)
local function guardarHistorico()
	local t = agora()
	for _, l in Lutadores.todos() do
		if l.hum.Health > 0 and l.raiz.Parent and l.stand and l.stand.ult and Executores.temRebobinar(l) then
			local h = l.historico or {}
			table.insert(h, { t = t, cf = l.raiz.CFrame, hp = l.hum.Health })
			while #h > 0 and t - h[1].t > 9 do
				table.remove(h, 1)
			end
			l.historico = h
		end
	end
end

function Executores.temRebobinar(l: any): boolean
	local ult = l.stand and l.stand.ult
	local g = ult and Golpes.get(ult)
	return g ~= nil and g.especial == "rebobinar"
end

function Executores.iniciar(remotos: any)
	Projeteis.iniciar(remotos.Efeito, acertarProjetil, explodir, contraProjetil)
	task.spawn(function()
		while true do
			task.wait(0.25)
			pcall(guardarHistorico)
		end
	end)
end

Executores.EXEC = EXEC
Executores.ESPECIAL = ESPECIAL
return Executores
