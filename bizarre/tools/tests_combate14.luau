local H = require('./harness')
local P = H.modulo('ReplicatedStorage/BB/PerfilCombate14')
local R = H.modulo('ReplicatedStorage/BB/Regras')
assert(P.suporta('STAR_PLATINUM') and P.suporta('THE_WORLD'))
assert(P.suporta('CRAZY_DIAMOND') and P.suporta('KILLER_QUEEN'))
local s = P.novo()
assert(P.sequencia(s, 1))
assert(not P.sequencia(s, 1) and not P.sequencia(s, 0))
for _,invalid in {0,-1,1.1,math.huge,0/0,'2'} do assert(not P.sequencia(s,invalid)) end
assert(P.sequencia(s, nil))
local e = R.novoEstado()
local a = P.iniciar(s,e,'m1',1,10,'STAR_PLATINUM',1)
assert(a.actionId and a.seq==1 and a.token==e.token)
assert(not P.cancelavel(s,e,10.1))
P.acerto(s,a,10.1)
assert(not P.cancelavel(s,e,10.159) and P.cancelavel(s,e,10.16))
a.n=4
assert(not P.cancelavel(s,e,10.2))
assert(not P.enfileirar(s,e,{tipo='m1'},10,10.121))
assert(P.enfileirar(s,e,{tipo='m1',seq=2},10,10.12))
assert(P.enfileirar(s,e,{tipo='golpe',seq=3},10.01,10.12))
assert(P.retirar(s,e,10.12).seq==3 and not P.retirar(s,e,10.12))
e.stunAte=20
assert(not P.enfileirar(s,e,{},10,10.1))
e.stunAte=0
local victim={}
P.vincular(s,a,victim,10.2)
assert(not P.reservar(s,e,10.379,'STAR_PLATINUM'))
local link=P.reservar(s,e,10.38,'STAR_PLATINUM')
assert(link and link.alvo==victim)
assert(not P.reservar(s,e,10.4,'STAR_PLATINUM'))
e.combo=4
e.m1ProntoEm=12
P.seguimento(e,11)
assert(e.combo==4 and e.m1ProntoEm==12)
e.m1ProntoEm=0
P.seguimento(e,11)
assert(e.m1ProntoEm==11.45)
P.vincular(s,a,victim,11)
e.token+=1
assert(not P.reservar(s,e,11.2,'STAR_PLATINUM'))
local b=P.iniciar(s,e,'m1',1,12,'THE_WORLD')
P.vincular(s,b,victim,12)
assert(not P.reservar(s,e,12.2,'STAR_PLATINUM'))
local e2=R.novoEstado()
local s2=P.novo()
assert(P.enfileirar(s2,e2,{tipo='m1'},0,.12))
assert(not P.retirar(s2,e2,.121) and not s2.buffer)
e2.ragdollAte=10;assert(not P.enfileirar(s2,e2,{},0,.1))
e2.ragdollAte=0;e2.congeladoAte=10;assert(not P.enfileirar(s2,e2,{},0,.1))
e2.congeladoAte=0
local ult=P.iniciar(s2,e2,'STAR_PLATINUM_ULT',nil,1,'STAR_PLATINUM')
e2.acaoAte=1.1
assert(not P.enfileirar(s2,e2,{},1,1.1))
print('COMBATE14 política OK')
