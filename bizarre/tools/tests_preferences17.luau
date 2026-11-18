local H=require('./harness')
local node=H.arvore.ServerScriptService.BB_Servidor.PreferenciasServidor17
assert(node,'AJ17 persistent preferences service absent')
local P=H.require(node)
local saved={u_5={camera=20,efeitos=.4,external='keep'}}
local failRead=false;local failWrite=false;local writes=0
local store={GetAsync=function(_,k) if failRead then error('network')end return saved[k]end,UpdateAsync=function(_,k,fn)if failWrite then error('network')end writes+=1;saved[k]=fn(saved[k]);return saved[k]end}
local messages={};local remote={FireClient=function(_,who,data)table.insert(messages,{who=who,data=data})end}
local player={UserId=5,Parent=true}
local service=P.novo(store,remote)
assert(not service:alterar(player,{camera=9}),'unloaded preferences must never overwrite saved data')
service:carregar(player)
assert(messages[#messages].data.valores.camera==20,'saved camera not restored')
assert(service:alterar(player,{camera=16,damage=999}))
assert(service:alterar(player,{mira=true}))
service:salvar(player)
assert(saved.u_5.camera==16 and saved.u_5.mira==true and saved.u_5.external=='keep' and saved.u_5.damage==nil,'whitelist patch clobbered unrelated data')
failWrite=true;service:alterar(player,{camera=9});service:salvar(player);assert(saved.u_5.camera==16)
failWrite=false;service:salvar(player);assert(saved.u_5.camera==9,'failed write lost pending preference')
local other={UserId=7,Parent=true};failRead=true;service:carregar(other)
assert(not service:alterar(other,{camera=9}),'load failure allowed blind overwrite')
failRead=false;service:carregar(other);assert(service:alterar(other,{camera=16}));service:salvar(other)
assert(saved.u_7.camera==16 and saved.u_5.camera==9,'players share preferences')
print('AJ17 persistent preferences: load gate, whitelist, batching, retries, isolation PASS')
