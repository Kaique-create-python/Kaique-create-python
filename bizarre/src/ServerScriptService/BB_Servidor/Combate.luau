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
local Perfil = require(BB:WaitForChild("PerfilCombate14"))
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
local hitContador14=0
local protocolos14 = {}
local jogadoresRemovidos14 = setmetatable({}, {__mode="k"})
local ultimoPedido: { [Player]: { [string]: number } } = {}

local function piloto(lut) return Perfil.suporta(lut.standId) end
local function politica(lut)
	if not lut.combate14 then lut.combate14 = Perfil.novo() end
	return lut.combate14
end
local function transporte(lut)
	if not lut.jogador then return politica(lut) end
	local p=protocolos14[lut.jogador]
	if not p then p=Perfil.novo(); protocolos14[lut.jogador]=p end
	return p
end
local function alvoLinkVivo(link)
	local alvo=link and link.alvo
	return Perfil.alvoVigente(link) and alvo.hum.Health>0 and alvo.modelo.Parent~=nil and Lutadores.de(alvo.modelo)==alvo
end
local function fimAcao(lut,a,reason)
	if not a or a.encerrada then return end
	a.encerrada=true
	Combate.efeito("acaoFim",{quem=lut.modelo,id=a.id,moveId=a.id,actionId=a.actionId,seq=a.seq,t=workspace:GetServerTimeNow(),phase="fim",reason=reason})
end
local function iniciarAcao(lut,id,n,t,dados)
	if not piloto(lut) then return nil end
	fimAcao(lut,politica(lut).acao,"substituida")
	local a=Perfil.iniciar(politica(lut),lut.estado,id,n,t,lut.standId,dados and dados.seq)
	lut.acao14=a
	return a
end
function Combate.cancelar(lut)
	Lutadores.invalidarGeracao(lut)
	lut.filaTempo=nil
	local p=lut.combate14
	if p then
		fimAcao(lut,p.acao,"interrompida")
		p.buffer=nil; p.link=nil; p.acao=nil; lut.acao14=nil
	end
	Regras.interromper(lut.estado,workspace:GetServerTimeNow())
	lut.defesaSegurada14=false
	for _,outro in Lutadores.todos() do
		local q=outro.combate14
		if q and q.link and q.link.alvo==lut then q.link=nil end
	end
end
function Combate.contexto(lut)
	local a=lut.acao14
	return a and { actionId=a.actionId, moveId=a.id, t=a.t, n=a.n, variant=a.variant, token=a.token, stand=a.stand } or {}
end
local function registrarAck(lut,tipo,d)
	d.generation=lut.geracao14
	if piloto(lut) and d.seq then
		local p=transporte(lut)
		p.acks=p.acks or {}; p.ackOrdem=p.ackOrdem or {}
		if not p.acks[d.seq] then table.insert(p.ackOrdem,d.seq) end
		p.acks[d.seq]={tipo=tipo,dados=d,lut=lut,geracao=lut.geracao14}
		if #p.ackOrdem>32 then p.acks[table.remove(p.ackOrdem,1)]=nil end
	end
	Combate.privado(lut,tipo,d)
end
local function confirmar(lut,a,extra)
	if not a then return end
	local d={ seq=a.seq, actionId=a.actionId, id=a.id, t=a.t, n=a.n, variant=a.variant, variante=a.variant, stand=lut.estado.standFora, standId=lut.standId, lifeId=lut.vida14, dir=lut.dir, acaoAte=lut.estado.acaoAte }
	for k,v in extra or {} do d[k]=v end
	registrarAck(lut,"confirmado",d)
end
local function fila(lut,tipo,dados,pronto)
	if not piloto(lut) or lut.hum.Health<=0 or not lut.modelo.Parent or lut.agarradoPor or lut.raiz.Anchored or lut.modelo:GetAttribute("BB_Menu") then return false end
	local cmd={tipo=tipo,dados=table.clone(dados or {}),slot=dados and dados.slot}
	return Perfil.enfileirar(politica(lut),lut.estado,cmd,workspace:GetServerTimeNow(),pronto)
end

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
	-- ARMOR OFF e outros buffs de velocidade
	if lut.buffVel and t < (lut.buffAte or 0) then
		base *= lut.buffVel
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
		-- quem me bateu e quando (Bites the Dust explode essa gente)
		alvo.atacadoPor = alvo.atacadoPor or {}
		alvo.atacadoPor[atk] = t
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
	if inf.airlink and not alvoLinkVivo(inf.airlink) then return "nada" end
	if piloto(atk) and (not Hitbox.corpo(alvo.raiz,alvo) or alvo.hum.Parent ~= alvo.modelo) then return "nada" end
	local ctx=inf.context or Combate.contexto(atk)
	if piloto(atk) and ctx.token and ctx.token ~= atk.estado.token and not inf.resolved and not inf.projetil then return "nada" end
	local hitId=inf.hitId
	if piloto(atk) and not hitId and ctx.actionId then
		hitContador14+=1
		hitId=ctx.actionId..":h"..hitContador14
	end
	local dir = inf.dir or Regras.achatar(alvo.raiz.Position - atk.raiz.Position)
	local function acertoFX(d)
		d.actionId=ctx.actionId; d.hitId=hitId; d.moveId=ctx.moveId; d.phase=if d.congelado then "queued" else "resolved"
		d.queuedHitIds=inf.queuedHitIds; d.t=t; d.dir=d.dir or dir; d.stand=ctx.stand or atk.standId; d.n=ctx.n; d.variant=ctx.variant
		Combate.efeito("acerto",d)
	end
	if Regras.invencivel(e, t) then
		Combate.efeito("esquiva", { v = alvo.modelo })
		return "invencivel"
	end
	if h.m1 and t < e.ragdollAte and not (inf.airlink and inf.airlink.alvo == alvo and inf.airlink.usado and ctx.moveId == "m1_aereo") then
		return "nada"
	end
	-- acabou de levantar: um instante sem cair de novo (não fica preso no chão apanhando)
	local podeCair = t >= (e.imuneRagdollAte or 0)
	-- tempo parado: o golpe fica guardado e chega junto quando o tempo voltar
	if t < e.congeladoAte and alvo.congeladoPor == atk then
		alvo.filaTempo = alvo.filaTempo or {}
		table.insert(alvo.filaTempo, { atk = atk, h = h, dir = dir, context=ctx, hitId=hitId })
		acertoFX({ a = atk.modelo, v = alvo.modelo, pos = alvo.raiz.Position, tipo = h.vfx or "impacto", dano = 0, som = h.som, congelado = true, stand = atk.standId })
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
		acertoFX({ a = atk.modelo, v = alvo.modelo, pos = pos, tipo = "parry", dano = 0, som = "parry", tremor = 0.4 })
		Regras.ganharDespertar(alvo.estado, 6, t)
		return "parry"
	end
	local dano = Regras.danoFinal(h.dano or 0, atk.estado, e, t)
	if res == "bloqueado" then
		local chip = math.floor(dano * (1 - Config.BLOQUEIO.reducao) * 10 + 0.5) / 10
		aplicarDano(alvo, chip, atk)
		Fisica.empurrar(alvo, dir * 10, 0.08)
		acertoFX({ a = atk.modelo, v = alvo.modelo, pos = pos, tipo = "bloqueio", dano = chip, som = "bloqueio", tremor = 0.1 })
		Combate.sincronizar(alvo)
		Regras.ganharDespertar(alvo.estado, chip * Config.DESPERTAR.porDanoRecebido + 1, t)
		return "bloqueado"
	end
	if res == "quebra" then
		Regras.atordoar(e, t, Config.BLOQUEIO.quebraAtordoa, true)
		acertoFX({ a = atk.modelo, v = alvo.modelo, pos = pos, tipo = "quebra_guarda", dano = 0, som = "quebra_guarda", tremor = 0.5 })
	end
	-- dano cheio
	if piloto(atk) and ctx.actionId == (atk.acao14 and atk.acao14.actionId) then Perfil.acerto(politica(atk),atk.acao14,t) end
	aplicarDano(alvo, dano, atk)
	if h.atordoar and h.atordoar > 0 then
		Regras.atordoar(e, t, h.atordoar)
	end
	local vel = vetor(h, dir, inf.origem, alvo)
	local emp = h.empurrar or {}
	local durEmp = emp.dur or 0.12
	if h.ragdoll and h.ragdoll > 0 and podeCair then
		Regras.derrubar(e, t, h.ragdoll)
		Fisica.derrubar(alvo, e.ragdollAte)
		alvo.forcaVoo = h.quebra or 1
		-- AJUSTE-2: quem cai não sai voando longe demais
		vel *= Config.EMPURRAO.multRagdoll
		durEmp = math.min(durEmp, Config.EMPURRAO.durMax)
	end
	if vel.Magnitude > 0.1 then
		Fisica.empurrar(alvo, vel, durEmp)
	end
	-- DIO suga vida
	local roubo = atk.stand.passiva and atk.stand.passiva.rouboVida
	if roubo and atk ~= alvo and atk.hum.Health > 0 then
		atk.hum.Health = math.min(atk.hum.MaxHealth, atk.hum.Health + dano * roubo)
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
	acertoFX({
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
	registrarAck(lut, "negado", { acao = acao, motivo = motivo, seq = lut.pedidoSeq14 })
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
	local p=piloto(lut) and politica(lut)
	if p and p.link then
		local alvo=p.link.alvo
		if not alvoLinkVivo(p.link) then p.link=nil end
	end
	if p and (lut.hum.Health<=0 or not lut.modelo.Parent or lut.agarradoPor or lut.raiz.Anchored or lut.modelo:GetAttribute("BB_Menu")) then return negar(lut,"m1","preso") end
	local link=p and Perfil.reservar(p,e,t,lut.standId)
	if e.bloqueando then
		Regras.pararBloqueio(e)
	end
	local pode, motivo = Regras.podeAgir(e, t)
	if not pode and not link then
		local pronto=math.max(e.acaoAte,e.m1ProntoEm)
		if p and p.link and not p.link.usado then pronto=math.min(pronto,p.link.abre) end
		if fila(lut,"m1",dados,pronto) then return end
		return negar(lut, "m1", motivo)
	end
	local n = if link then 1 else Regras.m1(e, t)
	if not n then
		if fila(lut,"m1",dados,e.m1ProntoEm) then return end
		return negar(lut, "m1", "recarga")
	end
	local dir = lerDir(lut, dados)
	local variante = nil
	if n == 4 and type(dados) == "table" then
		if dados.variante == "cima" or dados.variante == "baixo" then
			if not p or (lut.hum.FloorMaterial==Enum.Material.Air and ((dados.variante=="cima" and lut.raiz.AssemblyLinearVelocity.Y>4) or (dados.variante=="baixo" and lut.raiz.AssemblyLinearVelocity.Y<=4))) then
				variante = dados.variante
			end
		end
	end
	local stand = e.standFora
	lut.andarAcao = 0.55
	local a=iniciarAcao(lut,if link then "m1_aereo" else "m1",n,t,dados)
	if a then
		a.variant=variante
		local _,rec=Perfil.tempos(n)
		e.acaoAte=t+rec
		if link then Perfil.seguimento(e,t) end
		confirmar(lut,a,{m1ProntoEm=e.m1ProntoEm,acaoAte=e.acaoAte,combo=e.combo})
	end
	local token = e.token
	Combate.efeitoOutros(lut, "acao", { quem = lut.modelo, id = if link then "m1_aereo" else "m1", seq=dados and dados.seq, actionId=a and a.actionId, variant=variante, n = n, variante = variante, t = t, dir = dir, stand = stand })
	Combate.atualizarMovimento(lut)
	local vistos={}
	local candidatos={}
	local alvoMira=type(dados)=="table" and Lutadores.de(dados.alvo) or nil
	local contato=if a then (if link then 0.10 else Perfil.tempos(n)) else 0.10
	local function contatoM1()
		if link and not alvoLinkVivo(link) then return end
		if a and agora()>t+contato+Perfil.janela+1e-6 then return end
		if e.token ~= token or lut.hum.Health <= 0 or not lut.modelo.Parent or (a and (lut.standId~=a.stand or Perfil.impedido(e,agora()))) then
			return
		end
		local hb = if stand then Config.M1.hitboxStand else Config.M1.hitbox
		local d = if link then dir else Hitbox.grudar(lut, Lutadores.olhar(lut, agora()), hb.frente + hb.tam.Z * 0.5 + 2.5, 0.5)
		local folga = if stand and lut.stand.passiva and lut.stand.passiva.alcanceExtra then lut.stand.passiva.alcanceExtra else 0
		if lut.jogador then
			folga += math.clamp(lut.raiz.AssemblyLinearVelocity:Dot(d) * 0.06, 0, 1.5)
		end
		local cf = Hitbox.cfFrente(lut.raiz, d, hb.frente + folga)
		local alvos = {}
		for _, alvo in Hitbox.caixa(cf, hb.tam, lut) do
			-- soco não atravessa parede
			if not (Executores and Executores.paredeEntre(lut.raiz.Position, alvo.raiz.Position)) then
				table.insert(alvos, alvo)
			end
		end
		local estilo = lut.stand.m1
		local vfx = if estilo == "fogo" then "impacto_fogo" elseif estilo == "rapieira" then "corte_prata" else "impacto"
		for _, alvo in alvos do
			if vistos[alvo] or (link and alvo~=link.alvo) then continue end
			vistos[alvo]=true
			local h: any = {
				m1 = true,
				dano = Regras.danoM1(n, stand),
				atordoar = Config.M1.atordoar,
				tipo = "melee",
				som = if n == 4 then "soco_forte" elseif estilo == "rapieira" then "estocada" else "soco",
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
				if lut.stand.passiva and lut.stand.passiva.m1Explode then
					h.dano += 2
					h.vfx = "explosao_fogo"
					h.som = "explosao"
				end
			end
			if link then h.empurrar={frente=8,cima=-24,dur=0.12}; h.atordoar=0; h.ragdoll=nil end
			local res=Combate.acertar(lut, alvo, h, { dir = d, context=a and Combate.contexto(lut), airlink=link })
			if a and n==4 and variante=="cima" and res=="acertou" then
				candidatos[alvo]=agora()
				local escolhido=if candidatos[alvoMira] then alvoMira else nil
				local dist=math.huge
				if not escolhido then for candidato in candidatos do
					local dd=(candidato.raiz.Position-lut.raiz.Position).Magnitude
					if dd<dist then escolhido=candidato; dist=dd end
				end end
				p.link=nil; Perfil.vincular(p,a,escolhido,candidatos[escolhido])
				Combate.privado(lut,"airlink",{seq=a.seq,generation=lut.geracao14,standId=a.stand,actionId=a.actionId,abre=p.link.abre,fecha=p.link.fecha,alvo=escolhido.modelo})
			end
		end
		-- o 4º golpe também quebra o que estiver na frente
		if n == 4 and not vistos.mapa then
			vistos.mapa=true
			Mapa.quebrarCaixa(cf, hb.tam, 2, d)
		end
	end
	task.delay(contato, function()
		contatoM1()
		if a then
			local fim=t+contato+Perfil.janela
			while agora()<fim do
				task.wait(math.min(0.02,fim-agora()))
				if e.token~=token then break end
				contatoM1()
			end
		end
	end)
end

function Combate.golpe(lut: any, slot: any, dados: any)
	local e = lut.estado
	local t = agora()
	if e.bloqueando then
		Regras.pararBloqueio(e)
	end
	local g, id = Golpes.doSlot(lut.stand, slot)
	if not g or not id then return negar(lut,"golpe","golpe inválido") end
	local p=piloto(lut) and politica(lut)
	if p and (lut.hum.Health<=0 or not lut.modelo.Parent or lut.agarradoPor or lut.raiz.Anchored or lut.modelo:GetAttribute("BB_Menu")) then return negar(lut,"golpe","preso") end
	if g.ult then
		if not Regras.desperto(e, t) then
			return negar(lut, "golpe", "precisa DESPERTAR")
		end
		if e.ultUsado and not e.semRecarga then
			return negar(lut, "golpe", "ULT já usada")
		end
	end
	local cancela=p and not g.ult and type(slot)=="number" and slot>=1 and slot<=4 and Perfil.cancelavel(p,e,t)
	local pode,motivo=Regras.podeAgir(e,t)
	if not pode and not cancela then
		if fila(lut,"golpe",dados,math.max(e.acaoAte,e.cds[id] or 0)) then return end
		return negar(lut,"golpe",motivo)
	end
	if not Regras.cdPronto(e, id, t) then
		if fila(lut,"golpe",dados,e.cds[id]) then return end
		return negar(lut, "golpe", "recarga")
	end
	local a=iniciarAcao(lut,id,nil,t,dados)
	if a then a.normal=not g.ult and g.tipo~="barragem" and g.tipo~="agarrar" end
	local dir = lerDir(lut, dados)
	local mult = (lut.stand.passiva and lut.stand.passiva.multRecarga) or 1
	local fim = Regras.usarCd(e, id, (g.cd or 10) * mult, t)
	if g.ult then
		e.ultUsado = true
	end
	e.acaoAte = t + (g.trava or 0.5)
	lut.andarAcao = g.andar or 0.3
	Combate.privado(lut, "cd", { chave = id, fim = fim })
	Combate.efeitoOutros(lut, "acao", { quem = lut.modelo, id = id, seq=dados and dados.seq, actionId=a and a.actionId, t = t, dir = dir, stand = lut.standId })
	if lut.jogador then
		-- o próprio jogador já animou; só confirma o tempo do servidor
		if a then confirmar(lut,a,{stand=lut.standId}) else registrarAck(lut, "confirmado", { id = id, t = t, standId = lut.standId }) end
	end
	Combate.atualizarMovimento(lut)
	if Executores then
		Executores.executar(lut, g, id, t, dados)
	end
end

function Combate.bloquear(lut: any, ligar: boolean)
	local e = lut.estado
	local t = agora()
	if piloto(lut) then
		if ligar and not lut.defesaSegurada14 then lut.defesaInicio14=t end
		lut.defesaSegurada14=ligar
	end
	if ligar then
		if not Regras.podeAgir(e, t) then
			if piloto(lut) then return end
			return negar(lut, "bloqueio", "ocupado")
		end
		if not Regras.comecarBloqueio(e, t) then
			return negar(lut, "bloqueio", "guarda quebrada")
		end
		if piloto(lut) then e.bloqueioInicio=lut.defesaInicio14 end
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
		if fila(lut,"dash",dados,e.acaoAte) then return end
		return negar(lut, "dash", motivo)
	end
	local tipo = if type(dados) == "table" and (dados.tipo == "frente" or dados.tipo == "lado" or dados.tipo == "tras") then dados.tipo else "frente"
	local chave = "dash_" .. tipo
	if not Regras.cdPronto(e, chave, t) then
		if fila(lut,"dash",dados,e.cds[chave]) then return end
		return negar(lut, "dash", "recarga")
	end
	local def = Config.DASH[tipo]
	local a=iniciarAcao(lut,"dash",nil,t,dados)
	if a then a.normal=true end
	local fim = Regras.usarCd(e, chave, def.recarga, t)
	if e.bloqueando then
		Regras.pararBloqueio(e)
	end
	e.acaoAte = t + def.dur
	lut.andarAcao = 1
	Combate.privado(lut, "cd", { chave = chave, fim = fim })
	local dir = if type(dados) == "table" and typeof(dados.mov) == "Vector3" then dados.mov else lut.raiz.CFrame.LookVector
	Combate.efeitoOutros(lut, "acao", { quem = lut.modelo, id = "dash", seq=a and a.seq, actionId=a and a.actionId, tipo = tipo, lado = if type(dados) == "table" then dados.lado else nil, t = t, dir = dir })
	if a then confirmar(lut,a,{tipo=tipo,dir=dir,lado=type(dados)=="table" and dados.lado,stand=lut.standId}) end
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

function Combate.despertar(lut: any, dados: any?)
	local e = lut.estado
	local t = agora()
	if Regras.desperto(e, t) then
		-- já desperto: G = ULT
		return Combate.golpe(lut, "ult", dados or {})
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
local LIMITES = { soltar=0, m1 = 0.08, golpe = 0.15, bloqueio = 0.03, dash = 0.12, evasiva = 0.2, despertar = 0.3, stand = 0.3, pose = 0.5, correr = 0.05 }
function Combate.pedido(jogador: Player, tipo: any, dados: any)
	if jogadoresRemovidos14[jogador] then return end
	if type(tipo) ~= "string" or not LIMITES[tipo] then
		return
	end
	local lut = Lutadores.doJogador(jogador)
	if not lut or lut.hum.Health <= 0 then
		return
	end
	if type(dados) ~= "table" then dados={} end
	if piloto(lut) or (protocolos14[jogador] and dados.seq~=nil) then
		if dados.seq==nil then return end
		local p=transporte(lut)
		if not Perfil.sequencia(p,dados.seq) then
			local ack=type(dados.seq)=="number" and dados.seq==dados.seq and p.acks and p.acks[dados.seq]
			if ack and ack.lut==lut and ack.geracao==lut.geracao14 then Combate.privado(lut,ack.tipo,ack.dados) end
			return
		end
		lut.pedidoSeq14=dados.seq
	end
	local release=tipo=="soltar" or (tipo=="bloqueio" and dados.ligar~=true)
	local t = os.clock()
	local reg = ultimoPedido[jogador]
	if not reg then
		reg = {}
		ultimoPedido[jogador] = reg
	end
	if not release and reg[tipo] and t - reg[tipo] < (if piloto(lut) then 0.015 else LIMITES[tipo]) then
		return
	end
	reg[tipo] = t
	if type(dados) ~= "table" then
		dados = {}
	end
	if tipo=="soltar" then
		politica(lut).buffer=nil
		Combate.bloquear(lut,false)
	elseif tipo == "m1" then
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
		Combate.despertar(lut,dados)
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
			if lut.combate14 then lut.combate14.buffer=nil; lut.combate14.link=nil; fimAcao(lut,lut.combate14.acao,"interrompida") end
			continue
		end
		if piloto(lut) then
			local p=politica(lut)
			local a=p.acao
			if a and (a.token~=e.token or a.stand~=lut.standId) then
				p.buffer=nil; p.link=nil; fimAcao(lut,a,"interrompida")
			elseif a and t>=e.acaoAte then fimAcao(lut,a,"concluida") end
			local cmd=Perfil.retirar(p,e,t)
			if cmd then
				lut.pedidoSeq14=cmd.dados.seq
				if cmd.tipo=="m1" then Combate.m1(lut,cmd.dados) elseif cmd.tipo=="golpe" then Combate.golpe(lut,cmd.dados.slot,cmd.dados) elseif cmd.tipo=="dash" then Combate.dash(lut,cmd.dados) end
			end
			if lut.defesaSegurada14 and not e.bloqueando and Regras.podeAgir(e,t) and not lut.agarradoPor then
				if Regras.comecarBloqueio(e,t) then e.bloqueioInicio=lut.defesaInicio14; Combate.sincronizar(lut) end
			end
		end
		-- quem está voando quebra as paredes no caminho
		if t < e.ragdollAte then
			Mapa.atravessar(lut, lut.forcaVoo or 2)
			Fisica.manterRagdoll(lut)
		elseif lut.modelo:GetAttribute("BB_Ragdoll") and (lut.modelo:GetAttribute("BB_Ragdoll") :: number) > 0 then
			-- acabou o ragdoll: quebra o que ficou "dentro" e levanta
			Mapa.quebrarCaixa(lut.raiz.CFrame + Vector3.new(0, 1.6, 0), Vector3.new(4, 4, 4), 3, Vector3.new(0, 1, 0), true)
			Fisica.levantar(lut)
			e.imuneRagdollAte = t + Config.EMPURRAO.imuneDepois
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
	Lutadores.antesTrocarStand=function(lut,novoId)
		if piloto(lut) or Perfil.suporta(novoId) then Combate.cancelar(lut) end
	end
	Lutadores.antesRemover=Combate.cancelar
	remotos.Acao.OnServerEvent:Connect(Combate.pedido)
	Players.PlayerRemoving:Connect(function(p)
		ultimoPedido[p] = nil
		protocolos14[p]=nil
		jogadoresRemovidos14[p]=true
	end)
	RunService.Heartbeat:Connect(passo)
end

function Combate.abate(vitima: any)
	Combate.cancelar(vitima)
	vitima.vida14=vitima.geracao14
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
