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
 return {j=J,c=c,hum=hum,sent=sent,actions=actions,stops=stops,now=function(t)now=t end,receive=function(typ,d)rem.Privado.OnClientEvent:Fire(typ,d)end,
 confirm=function(seq,stand,generation)rem.Privado.OnClientEvent:Fire('confirmado',{seq=seq,id=stand..'_4',standId=stand,generation=generation,t=20,actionId='fresh',acaoAte=21})end,
 ack=function()rem.Privado.OnClientEvent:Fire('confirmado',{seq=old,id='STAR_PLATINUM_2',standId='STAR_PLATINUM',lifeId=1,generation=1,t=10.3,actionId='in-flight-old',acaoAte=11})end,
 ackNoSeq=function()rem.Privado.OnClientEvent:Fire('confirmado',{id='STAR_PLATINUM_2',standId='STAR_PLATINUM',t=10.3})end,
 air=function()rem.Privado.OnClientEvent:Fire('airlink',{seq=old,standId='STAR_PLATINUM',abre=20,fecha=20.65,actionId='old-uppercut'})end}
end
local function change(f,name,value)f.c:SetAttribute(name,value);attr(f.c,name):Fire()end
local fails=0
local function test(name,fn)local ok,err=pcall(fn);print((if ok then 'PASS ' else 'FAIL ')..name..(if ok then '' else ': '..tostring(err)));if not ok then fails+=1 end end
local function fresh(f,stand)
 f.now(20);f.j.golpe(4);local seq=f.sent[#f.sent].d.seq;assert(f.j.pendente)
 return seq,#f.stops
end
test('Stand then fresh action then late generation preserves action and ACK',function()
 local f=fixture();change(f,'BB_Stand','THE_WORLD');local seq,stops=fresh(f)
 change(f,'BB_Geracao14',3);assert(#f.stops==stops and f.j.pendente,'late generation cancelled fresh action')
 f.confirm(seq,'THE_WORLD',3);assert(not f.j.pendente,'fresh ACK was fenced')
end)
test('generation then Stand then fresh action preserves ACK',function()
 local f=fixture();change(f,'BB_Geracao14',3);change(f,'BB_Stand','THE_WORLD');local seq=fresh(f)
 f.confirm(seq,'THE_WORLD',3);assert(not f.j.pendente)
end)
test('new request between generation and Stand replication is not cancelled',function()
 local f=fixture();change(f,'BB_Geracao14',3);local seq,stops=fresh(f)
 change(f,'BB_Stand','THE_WORLD');assert(f.j.pendente and #f.stops==stops,'late Stand cancelled generation-current input')
 f.confirm(seq,'THE_WORLD',3);assert(not f.j.pendente)
end)
test('initial generation arrival preserves pending action',function()
 local f=fixture();change(f,'BB_Geracao14',nil);local seq,stops=fresh(f)
 change(f,'BB_Geracao14',3);assert(f.j.pendente and #f.stops==stops)
 f.confirm(seq,'STAR_PLATINUM',3);assert(not f.j.pendente)
end)
test('coalesced same-Stand generation rejects stale ACK but accepts fresh generation',function()
 local f=fixture();change(f,'BB_Geracao14',3);local n=#f.actions;f.ack();assert(#f.actions==n)
 local seq=fresh(f);f.confirm(seq,'STAR_PLATINUM',3);assert(not f.j.pendente)
end)
-- Missing generation on a real legacy server ACK must leave this test red.
-- Reuse the client fixture above and the server test's service/physics boundary.
local server,L
for _,stand in {'CRAZY_DIAMOND','MAGICIANS_RED','SILVER_CHARIOT','KILLER_QUEEN'} do
 test('real legacy server ACK clears current pending action: '..stand,function()
  local f=fixture()
  if not server then
   H.servicos.Players.PlayerRemoving=signal()
   H.servicos.Players.GetPlayers=function()return {}end
   local clientRequire=H.extras.require
   H.extras.require=function(m)
    if m.Name=='Fisica' or m.Name=='Mapa' then return {} end
    return H.require(m)
   end
   L=H.modulo('ServerScriptService/BB_Servidor/Lutadores')
   server=H.modulo('ServerScriptService/BB_Servidor/Combate')
   H.extras.require=clientRequire
  end
  local player={DisplayName=stand}
  local lut=L.criar(f.c,player,'STAR_PLATINUM')
  assert(L.trocarStand(lut,stand))
  change(f,'BB_Geracao14',lut.geracao14);change(f,'BB_Stand',stand)
  lut.estado.standFora=true;f.c:SetAttribute('BB_StandFora',true)
  local seq=fresh(f)
  local ack
  server.iniciar({Efeito={FireAllClients=function()end},Acao={OnServerEvent=signal()},Privado={FireClient=function(_,p,typ,d)
   assert(p==player)
   if typ=='confirmado' then ack=d end
   f.receive(typ,d)
  end}},nil,nil)
  server.pedido(player,'golpe',{slot=4,seq=seq})
  assert(ack and ack.id==stand..'_4','server did not confirm legacy skill')
  assert(not f.j.pendente,'real legacy ACK was fenced; pending remains')
  assert(ack.generation==lut.geracao14 and ack.standId==stand,'missing authoritative legacy ACK metadata')
 end)
end
assert(fails==0,tostring(fails)..' generation tests failed');print('FINAL14 generation GREEN')
