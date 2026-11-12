-- Política autoritativa pura do piloto; nenhum campo recebido do cliente concede permissões.
local P = { bufferTTL = 0.12, janela = 0.08, cancelApos = 0.06 }
local contador = 0
function P.suporta(id) return id == 'STAR_PLATINUM' or id == 'THE_WORLD' or id == 'SILVER_CHARIOT' or id == 'MAGICIANS_RED' or id == 'CRAZY_DIAMOND' or id == 'KILLER_QUEEN' end
function P.novo() return { ultimaSeq = 0 } end
function P.sequencia(s, seq)
	if seq == nil then return true end -- bots internos; a entrada de Player exige seq no servidor
	if type(seq) ~= 'number' or seq ~= seq or seq % 1 ~= 0 or seq < 1 or seq > 9007199254740991 or seq <= s.ultimaSeq then return false end
	s.ultimaSeq = seq
	return true
end
function P.impedido(e,t) return t < e.stunAte or t < e.ragdollAte or t < e.congeladoAte end
function P.iniciar(s,e,id,n,t,stand,seq)
	contador += 1
	e.token += 1
	local a = { actionId = 'a14:'..contador, id=id, moveId=id, n=n, t=t, stand=stand, seq=seq, token=e.token, hits=0 }
	s.acao=a
	s.link=nil
	s.buffer=nil
	return a
end
function P.vigente(s,e,a) return a and s.acao == a and a.token == e.token end
function P.acerto(s,a,t)
	if s.acao == a and not a.hitTime then a.hitTime=t end
end
function P.cancelavel(s,e,t)
	local a=s.acao
	return P.vigente(s,e,a) and a.id=='m1' and a.n<4 and a.hitTime ~= nil and t+1e-8>=a.hitTime+P.cancelApos and not P.impedido(e,t)
end
function P.normal(s,e,t)
	local a=s.acao
	return t>=e.acaoAte or (P.vigente(s,e,a) and (a.id=='m1' or a.id=='m1_aereo' or a.normal==true))
end
function P.enfileirar(s,e,cmd,t,pronto)
	if P.impedido(e,t) or not P.normal(s,e,t) or pronto<t or pronto-t>P.bufferTTL+1e-8 then return false end
	s.buffer={ cmd=cmd, ate=t+P.bufferTTL, pronto=pronto, token=e.token }
	return true
end
function P.retirar(s,e,t)
	local b=s.buffer
	if not b then return nil end
	if P.impedido(e,t) or b.token~=e.token or t>b.ate+1e-8 then s.buffer=nil return nil end
	if t+1e-8<b.pronto then return nil end
	s.buffer=nil
	return b.cmd
end
function P.vincular(s,a,alvo,t)
	if s.acao==a and not s.link then s.link={ action=a, alvo=alvo, alvoGeracao=alvo.geracao14, alvoModelo=alvo.modelo, alvoEstado=alvo.estado, alvoStand=alvo.standId, abre=t+0.18, fecha=t+0.65, stand=a.stand } end
end
function P.alvoVigente(l)
	local alvo=l and l.alvo
	return alvo and alvo.geracao14==l.alvoGeracao and alvo.modelo==l.alvoModelo and alvo.estado==l.alvoEstado and alvo.standId==l.alvoStand
end
function P.reservar(s,e,t,stand)
	local l=s.link
	if not l or l.usado or not P.alvoVigente(l) or not P.vigente(s,e,l.action) or l.stand~=stand or P.impedido(e,t) or t+1e-8<l.abre or t>l.fecha+1e-8 then return nil end
	l.usado=true -- tentativa consumida inclusive se não houver contato
	return l
end
function P.seguimento(e,t)
	e.m1ProntoEm=math.max(e.m1ProntoEm,t+0.45)
	e.acaoAte=t+0.30
end
function P.tempos(n) return if n==4 then 0.16 else 0.10, if n==4 then 0.45 else 0.30 end
return P
