-- Real Jogador; native attribute/death signals are the only simulated boundary.
local H=require('./harness')
local rb=require('@lune/roblox')
local function signal()
 local s={fns={}}
 function s:Connect(f)table.insert(self.fns,f)return{Disconnect=function()end}end
 function s:Fire(...)for _,f in self.fns do f(...)end end
 return s
end
local attrSignals,deathSignals={},{}
local function attr(model,name)
 attrSignals[model]=attrSignals[model] or {}
 attrSignals[model][name]=attrSignals[model][name] or signal()
 return attrSignals[model][name]
end
rb.implementMethod('Instance','GetAttributeChangedSignal',attr)
rb.implementProperty('Humanoid','Died',function(h)
 deathSignals[h]=deathSignals[h] or signal();return deathSignals[h]
end)
local function fixture()
 local now=10
 local c=rb.Instance.new('Model');c:SetAttribute('BB_Stand','STAR_PLATINUM');c:SetAttribute('BB_StandFora',true);c:SetAttribute('BB_Geracao14',1)
 local hum=rb.Instance.new('Humanoid');hum.Health=100;hum.FloorMaterial=rb.Enum.Material.Ground;hum.Parent=c
 local root=rb.Instance.new('Part');root.Name='HumanoidRootPart';root.CFrame=rb.CFrame.new(0,3,0);root.Position=rb.Vector3.new(0,3,0);root.AssemblyLinearVelocity=rb.Vector3.zero;root.Parent=c
 local plr={Character=c,CharacterAdded=signal(),GetAttribute=function()return nil end}
 H.servicos.Players={LocalPlayer=plr};H.servicos.RunService.Heartbeat=signal();H.servicos.Debris={AddItem=function()end}
 local actions,stops,confirmations={},{},{}
 local deps={Acoes={tocar=function(_,d)table.insert(actions,d)end,interromper=function(...)table.insert(stops,{...})end,confirmar=function(_,d)table.insert(confirmations,d)end},Animador={tocar=function()end,parar=function()table.insert(stops,{})end},Camera={travado=function()return nil end,correndo=function()end,travar=function()end},Efeitos={_modelosLutadores=function()return {}end},StandVisual={prever=function()end}}
 H.extras.require=function(m)return deps[m.Name] or H.require(m)end
 H.extras.os={clock=function()return now end}
 H.extras.workspace={GetServerTimeNow=function()return now end,CurrentCamera={CFrame=rb.CFrame.new()}}
 local J=H.moduloNovo('ReplicatedStorage/BB/Cliente/Jogador')
 local sent={};local rem={Acao={FireServer=function(_,typ,d)table.insert(sent,{typ=typ,d=d})end},Privado={OnClientEvent=signal()}}
 J.iniciar(rem,{})
 J.golpe(2);J.m1();now=10.2;J.golpe(2)
 local old=sent[#sent].d.seq;assert(#actions==1 and old>actions[1].seq)
 return {j=J,c=c,hum=hum,sent=sent,actions=actions,stops=stops,now=function(t)now=t end,
 ack=function()rem.Privado.OnClientEvent:Fire('confirmado',{seq=old,id='STAR_PLATINUM_2',standId='STAR_PLATINUM',lifeId=1,t=10.3,actionId='in-flight-old',acaoAte=11})end,
 ackNoSeq=function()rem.Privado.OnClientEvent:Fire('confirmado',{id='STAR_PLATINUM_2',standId='STAR_PLATINUM',t=10.3})end,
 air=function()rem.Privado.OnClientEvent:Fire('airlink',{seq=old,standId='STAR_PLATINUM',abre=20,fecha=20.65,actionId='old-uppercut'})end}
end
local fails=0
local function test(name,fn)
 local ok,err=pcall(fn);print((if ok then 'PASS ' else 'FAIL ')..name..(if ok then '' else ': '..tostring(err)))
 if not ok then fails+=1 end
end
test('focus/menu release fences in-flight buffered ACK and allows fresh requests',function()
 local f=fixture();f.j.soltarEntradas();local count=#f.actions;f.ack();assert(#f.actions==count,'old ACK animated after release')
 f.now(20);f.j.golpe(4);assert(#f.actions==count+1,'fence blocked fresh input')
end)
test('Stand round trip fences ACK without relying on matching Stand ID',function()
 local f=fixture();f.c:SetAttribute('BB_Stand','THE_WORLD');attr(f.c,'BB_Stand'):Fire();f.c:SetAttribute('BB_Stand','STAR_PLATINUM');attr(f.c,'BB_Stand'):Fire()
 local count=#f.actions;f.ack();assert(#f.actions==count,'old same-Stand ACK animated after round trip')
end)
test('coalesced Stand replication still fences by monotonic generation attribute',function()
 local f=fixture();f.c:SetAttribute('BB_Geracao14',3);attr(f.c,'BB_Geracao14'):Fire();local count=#f.actions;f.ack();assert(#f.actions==count,'generation change did not fence')
end)
test('death and same-frame Health recovery cannot revive pending ACK',function()
 local f=fixture();f.hum.Health=0;f.hum.Died:Fire();f.hum.Health=100;local count=#f.actions;f.ack();assert(#f.actions==count,'death fence did not stop ACK')
end)
test('released old airlink notification cannot grant a later predicted followup',function()
 local f=fixture();f.j.soltarEntradas();f.air();f.now(20);f.j.m1();assert(f.actions[#f.actions].id=='m1','old airlink survived release fence')
end)
test('unsequenced old legacy ACK cannot clear a fresh pilot prediction',function()
 local f=fixture();f.j.soltarEntradas();f.now(20);f.j.golpe(4)
 local pending=f.j.pendente;assert(pending)
 f.ackNoSeq();assert(f.j.pendente==pending,'legacy ACK cleared fresh prediction')
end)
assert(fails==0,tostring(fails)..' client fence regressions failed')
print('COMBATE14 client fences GREEN')
