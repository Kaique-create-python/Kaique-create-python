-- BIZARRE BATTLEGROUNDS :: regras do combate (funções puras, iguais no servidor e no cliente)
-- O servidor é quem manda; o cliente usa as mesmas regras só para "adivinhar" e não ter atraso.

local Config = require(script.Parent.Config)

local Regras = {}

export type Estado = {
	stunAte: number,
	ragdollAte: number,
	acaoAte: number,
	iframesAte: number,
	armaduraAte: number,
	congeladoAte: number,
	protecaoAte: number,
	bloqueando: boolean,
	bloqueioInicio: number,
	guarda: number,
	guardaUsoT: number,
	combo: number,
	comboT: number,
	m1ProntoEm: number,
	cds: { [string]: number },
	despertar: number,
	despertoAte: number,
	ultUsado: boolean,
	evasivaPronta: number,
	ultimoDanoT: number,
	standFora: boolean,
	token: number,
	acertosSeguidos: number,
	acertosT: number,
	contra: any,
	multDanoRecebido: number,
	semRecarga: boolean,
	buffAte: number,
	buffDano: number,
	imuneRagdollAte: number,
}

function Regras.novoEstado(): Estado
	return {
		stunAte = 0,
		ragdollAte = 0,
		acaoAte = 0,
		iframesAte = 0,
		armaduraAte = 0,
		congeladoAte = 0,
		protecaoAte = 0,
		bloqueando = false,
		bloqueioInicio = -100,
		guarda = Config.BLOQUEIO.guardaMax,
		guardaUsoT = -100,
		combo = 0,
		comboT = -100,
		m1ProntoEm = 0,
		cds = {},
		despertar = 0,
		despertoAte = 0,
		ultUsado = false,
		evasivaPronta = 0,
		ultimoDanoT = -1e9,
		standFora = false,
		token = 0,
		acertosSeguidos = 0,
		acertosT = -100,
		contra = nil,
		multDanoRecebido = 1,
		semRecarga = false,
		buffAte = 0,
		buffDano = 1,
		imuneRagdollAte = 0,
	}
end

function Regras.atordoado(e: Estado, t: number): boolean
	return t < e.stunAte or t < e.ragdollAte or t < e.congeladoAte
end

function Regras.ocupado(e: Estado, t: number): boolean
	return t < e.acaoAte
end

-- pode começar uma ação nova agora?
function Regras.podeAgir(e: Estado, t: number): (boolean, string?)
	if t < e.congeladoAte then
		return false, "congelado"
	end
	if t < e.ragdollAte then
		return false, "no chão"
	end
	if t < e.stunAte then
		return false, "atordoado"
	end
	if t < e.acaoAte then
		return false, "ocupado"
	end
	return true, nil
end

function Regras.invencivel(e: Estado, t: number): boolean
	return t < e.iframesAte or t < e.protecaoAte
end

function Regras.desperto(e: Estado, t: number): boolean
	return t < e.despertoAte
end

-- M1: devolve o número do golpe (1 a 4) ou nil se ainda não pode
function Regras.m1(e: Estado, t: number): number?
	if t < e.m1ProntoEm then
		return nil
	end
	local n = e.combo + 1
	if t - e.comboT > Config.M1.reset or n > 4 then
		n = 1
	end
	e.combo = n
	e.comboT = t
	e.m1ProntoEm = t + (if n == 4 then Config.M1.recargaFinal else Config.M1.intervalo)
	e.acaoAte = math.max(e.acaoAte, t + 0.2)
	return n
end

function Regras.danoM1(n: number, standFora: boolean): number
	local tabela = if standFora then Config.M1.danoStand else Config.M1.dano
	return tabela[math.clamp(n, 1, 4)]
end

-- recargas (chave = id do golpe, "dash_frente", "evasiva"...)
function Regras.cdPronto(e: Estado, chave: string, t: number): boolean
	if e.semRecarga then
		return true
	end
	return (e.cds[chave] or 0) <= t
end

function Regras.cdRestante(e: Estado, chave: string, t: number): number
	return math.max(0, (e.cds[chave] or 0) - t)
end

function Regras.usarCd(e: Estado, chave: string, dur: number, t: number): number
	local mult = if Regras.desperto(e, t) then Config.DESPERTAR.multRecarga else 1
	local fim = t + dur * mult
	if e.semRecarga then
		fim = t + math.min(dur * mult, 0.35)
	end
	e.cds[chave] = fim
	return fim
end

-- direção (achatada) que o golpe vem: de onde está o atacante em relação à vítima
local function achatar(v: Vector3): Vector3
	local p = Vector3.new(v.X, 0, v.Z)
	if p.Magnitude < 1e-4 then
		return Vector3.new(0, 0, -1)
	end
	return p.Unit
end
Regras.achatar = achatar

-- resultado do bloqueio: "nada" (pega cheio), "bloqueado", "parry" ou "quebra"
function Regras.resolverBloqueio(alvo: Estado, t: number, paraAtacante: Vector3, olharAlvo: Vector3, golpe: any): string
	if not alvo.bloqueando then
		return "nada"
	end
	if golpe.inbloqueavel then
		return "nada"
	end
	local frente = achatar(olharAlvo):Dot(achatar(paraAtacante)) >= Config.BLOQUEIO.angulo
	if not frente then
		return "nada"
	end
	if (golpe.tipo or "melee") == "melee" and t - alvo.bloqueioInicio <= Config.BLOQUEIO.parryJanela then
		return "parry"
	end
	if golpe.quebraGuarda then
		alvo.guarda = 0
		alvo.guardaUsoT = t
		return "quebra"
	end
	local custo = (golpe.dano or 0) * Config.BLOQUEIO.gastoPorDano
	alvo.guarda -= custo
	alvo.guardaUsoT = t
	if alvo.guarda <= 0 then
		alvo.guarda = 0
		return "quebra"
	end
	return "bloqueado"
end

function Regras.recuperarGuarda(e: Estado, t: number, dt: number)
	if e.bloqueando and e.guarda > 0 then
		-- segurando o bloqueio a guarda só volta devagar
		if t - e.guardaUsoT > Config.BLOQUEIO.recuperaAtraso then
			e.guarda = math.min(Config.BLOQUEIO.guardaMax, e.guarda + Config.BLOQUEIO.recuperaPorSegundo * 0.25 * dt)
		end
		return
	end
	if t - e.guardaUsoT > Config.BLOQUEIO.recuperaAtraso then
		e.guarda = math.min(Config.BLOQUEIO.guardaMax, e.guarda + Config.BLOQUEIO.recuperaPorSegundo * dt)
	end
end

function Regras.comecarBloqueio(e: Estado, t: number)
	if e.guarda <= 0 then
		return false
	end
	if not e.bloqueando then
		e.bloqueando = true
		e.bloqueioInicio = t
	end
	return true
end

function Regras.pararBloqueio(e: Estado)
	e.bloqueando = false
end

-- dano final: despertar do atacante e redução do alvo (passivas)
function Regras.danoFinal(base: number, atacante: Estado?, alvo: Estado, t: number): number
	local d = base
	if atacante and Regras.desperto(atacante, t) then
		d *= Config.DESPERTAR.multDano
	end
	if atacante and t < (atacante.buffAte or 0) then
		d *= atacante.buffDano or 1
	end
	d *= alvo.multDanoRecebido or 1
	return math.floor(d * 10 + 0.5) / 10
end

function Regras.atordoar(e: Estado, t: number, dur: number, ignorarArmadura: boolean?)
	if dur <= 0 then
		return
	end
	if t < e.armaduraAte and not ignorarArmadura then
		return -- super armadura: leva dano mas não para o golpe
	end
	e.stunAte = math.max(e.stunAte, t + math.min(dur, Config.ATORDOAR_MAX))
	Regras.interromper(e, t)
end

function Regras.derrubar(e: Estado, t: number, dur: number)
	if dur <= 0 then
		return
	end
	e.ragdollAte = math.max(e.ragdollAte, t + math.min(dur, Config.RAGDOLL_MAX))
	Regras.interromper(e, t)
end

-- interrompe o golpe que estava fazendo (o token muda e o golpe para de dar hits)
function Regras.interromper(e: Estado, t: number)
	e.token += 1
	e.acaoAte = math.min(e.acaoAte, t)
	e.bloqueando = false
	e.contra = nil
end

-- barra de despertar
function Regras.ganharDespertar(e: Estado, qtd: number, t: number)
	if Regras.desperto(e, t) then
		return
	end
	e.despertar = math.clamp(e.despertar + qtd, 0, Config.DESPERTAR.max)
end

function Regras.podeDespertar(e: Estado, t: number): boolean
	return e.despertar >= Config.DESPERTAR.max and not Regras.desperto(e, t)
end

function Regras.despertar(e: Estado, t: number)
	e.despertoAte = t + Config.DESPERTAR.duracao
	e.despertar = 0
	e.ultUsado = false
	e.iframesAte = math.max(e.iframesAte, t + Config.DESPERTAR.invencivelAoDespertar)
end

-- evasiva: sai do atordoamento/ragdoll
function Regras.evasivaDisponivel(e: Estado, t: number): boolean
	return t >= e.evasivaPronta
end

function Regras.podeEvasiva(e: Estado, t: number): boolean
	if t < e.congeladoAte then
		return false
	end
	return (t < e.stunAte or t < e.ragdollAte) and Regras.evasivaDisponivel(e, t)
end

function Regras.usarEvasiva(e: Estado, t: number)
	e.evasivaPronta = t + Config.EVASIVA.recarga
	e.stunAte = t
	e.ragdollAte = t
	e.iframesAte = math.max(e.iframesAte, t + Config.EVASIVA.invencivel)
	e.acaoAte = t
end

-- contador de acertos seguidos (combo do atacante)
function Regras.contarAcerto(e: Estado, t: number): number
	if t - e.acertosT > Config.COMBO_JANELA then
		e.acertosSeguidos = 0
	end
	e.acertosSeguidos += 1
	e.acertosT = t
	return e.acertosSeguidos
end

-- dash: de que lado foi pela direção do movimento (local: X = direita, Z = trás)
function Regras.tipoDash(local_: Vector3): string
	if local_.Magnitude < 0.2 then
		return "frente"
	end
	local u = local_.Unit
	if -u.Z >= 0.55 then
		return "frente"
	elseif u.Z >= 0.55 then
		return "tras"
	end
	return "lado"
end

-- nome da sequência de abates
function Regras.nomeSequencia(n: number): string?
	if n == 3 then
		return "TRIPLO!"
	elseif n == 5 then
		return "IMPARÁVEL!"
	elseif n == 7 then
		return "BIZARRO!!"
	elseif n == 10 then
		return "LENDÁRIO!!!"
	elseif n > 10 and n % 5 == 0 then
		return "DEUS DA BATALHA x" .. n
	end
	return nil
end

-- vetor de empurrão a partir de {frente, cima} e da direção do atacante
function Regras.vetorEmpurrao(dir: Vector3, frente: number, cima: number): Vector3
	local d = achatar(dir)
	return d * frente + Vector3.new(0, cima, 0)
end

return Regras
