local H=require('./harness')
local now=0;local jobs={};local sent={};local callback
local function schedule(dt,fn) table.insert(jobs,{t=now+dt,fn=fn})end
local function tick(dt)
 local goal=now+dt
 while true do table.sort(jobs,function(a,b)return a.t<b.t end);if not jobs[1]or jobs[1].t>goal then break end
 local j=table.remove(jobs,1);now=j.t;j.fn()end
 now=goal
end
H.extras.task={spawn=function(fn) schedule(0,fn)end,delay=schedule,wait=function()end}
local P=H.modulo('ReplicatedStorage/BB/Cliente/PreferenciasCliente17')
local last
P.observar(function(v)last=v end)
P.iniciar({OnClientEvent={Connect=function(_,fn)callback=fn end},FireServer=function(_,d)table.insert(sent,d)end})
P.definir({efeitos=.4})
assert(last.efeitos==.4)
callback({tipo='estado',pronto=true,valores={camera=20,efeitos=1,mira=true}})
assert(last.camera==20 and last.efeitos==.4 and last.mira==true,'late load overwrote local edit or lost saved settings')
tick(1.1)
assert(sent[#sent].tipo=='salvar' and sent[#sent].valores.efeitos==.4,'pre-load edit was not saved after ready')
P.definir({camera=16});P.definir({camera=9});tick(1.1)
assert(sent[#sent].valores.camera==9,'debounce lost latest camera choice')
callback({tipo='salvo',pronto=true,valores={camera=20,efeitos=1}})
assert(P.valores().camera==9,'stale save acknowledgement reset newer preference')
print('AJ17 real preferences client: late load merge, debounce, ACK freshness PASS')
