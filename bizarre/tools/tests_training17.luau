local H=require('./harness')
local node=H.arvore.ReplicatedStorage.BB.Laboratorio17
assert(node,'AJ17 training policy absent')
local T=H.require(node);local R=H.modulo('ReplicatedStorage/BB/Regras')
local a,b={},{}
assert(T.permite({jogador=a},{laboratorioDono17=a}))
assert(not T.permite({jogador=b},{laboratorioDono17=a}))
assert(not T.permite({laboratorioDono17=a},{jogador=b}))
assert(T.modo('bloquear') and not T.modo('script') and not T.modo({}))
local s=T.novo('bloquear');local e=R.novoEstado()
e.stunAte=10.5
T.contato(s,10,5,e)
assert(not T.reacao(s,e,10.2),'dummy blocked while stunned')
assert(T.reacao(s,e,10.6)=='bloquear','dummy did not defend after first hit recovery')
T.contato(s,10.7,7,e)
assert(s.hits==2 and s.dano==12 and s.janela,'escapable gap reported as a guaranteed combo')
local s2=T.novo('evasiva');e.stunAte=20.5;e.evasivaPronta=30
T.contato(s2,20,5,e);assert(not T.reacao(s2,e,20.1),'dummy ignored evasion cooldown')
e.evasivaPronta=0
assert(T.reacao(s2,e,20.2)=='evasiva','available evasion not used')
local s3=T.novo('contra');e.stunAte=40.5;e.ragdollAte=41
T.contato(s3,40,3,e);assert(not T.reacao(s3,e,40.6),'counter executed during ragdoll')
assert(T.reacao(s3,e,41.1)=='contra')
print('AJ17 training policy: mode whitelist, recovery, evasion cooldown, real escape windows PASS')

local cooldown=T.novo('bloquear');local state=R.novoEstado()
state.stunAte=51;state.evasivaPronta=50.15
T.contato(cooldown,50,3,state)
T.contato(cooldown,50.3,3,state)
assert(cooldown.janela,'evasion becoming ready during stun was reported as no opening')
local Time=H.modulo('ServerScriptService/BB_Servidor/TempoSessao')
local owner,other={},{}
local private={laboratorioDono17=owner}
local session=Time.nova({jogador=other},60)
assert(#Time.congelar(session,{private})==0 and private.sessaoTempo==nil,'another player froze private target')
print('AJ17 training regressions: cooldown opening and private time-stop PASS')
