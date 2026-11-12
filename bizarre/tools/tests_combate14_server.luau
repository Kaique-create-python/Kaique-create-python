-- Módulos de produção reais. Só relógio/sinais/agenda/física física ausente no Lune são fronteiras.
local H=require('./harness')
local rb=require('@lune/roblox')
local V=rb.Vector3.new
local now=100
local queue={}
local function schedule(delay,fn)
	table.insert(queue,{t=now+delay,co=coroutine.create(fn)})
end
local function advance(t)
	while true do
		table.sort(queue,function(a,b) return a.t<b.t end)
		if not queue[1] or queue[1].t>t+1e-8 then break end
		local item=table.remove(queue,1)
		now=item.t
		local ok,wait=coroutine.resume(item.co)
		assert(ok,wait)
		if coroutine.status(item.co)~='dead' then table.insert(queue,{t=now+math.max(wait or 0,0.0001),co=item.co}) end
	end
	now=t
end
local function signal()
	local s={fns={}}
	function s:Connect(f) table.insert(self.fns,f) return {Disconnect=function()end} end
	function s:Fire(...) for _,f in self.fns do f(...) end end
	return s
end
local heart=signal()
H.servicos.RunService.Heartbeat=heart
H.servicos.Players={PlayerRemoving=signal(),GetPlayers=function() return {} end}
local events,acks,forces={},{},{}
local ws=setmetatable({GetServerTimeNow=function()return now end},{__index=H.workspace})
H.extras.workspace=ws
H.extras.task={delay=function(d,f) schedule(d,f)end,spawn=function(f)schedule(0,f)end,wait=function(d)return coroutine.yield(d or 0.01)end}
local fakePhysics=setmetatable({empurrar=function(l,v,d)table.insert(forces,{l=l,v=v,d=d})end},{__index=function()return function()end end})
local fakeMap=setmetatable({spawns=function()return{}end},{__index=function()return function()end end})
H.extras.require=function(m)
	if m.Name=='Fisica' then return fakePhysics elseif m.Name=='Mapa' then return fakeMap end
	return H.require(m)
end
local R=H.modulo('ReplicatedStorage/BB/Regras')
local L=H.modulo('ServerScriptService/BB_Servidor/Lutadores')
local B=H.modulo('ServerScriptService/BB_Servidor/Combate')
local HB=H.modulo('ServerScriptService/BB_Servidor/Hitbox')
local rem={Efeito={FireAllClients=function(_,typ,d)table.insert(events,{typ=typ,d=d})end},Privado={FireClient=function(_,p,typ,d)table.insert(acks,{p=p,typ=typ,d=d})end},Acao={OnServerEvent=signal()}}
local parede=false
B.iniciar(rem,{paredeEntre=function()return parede end,executar=function()end},nil)
local arena=rb.Instance.new("Folder")
local function actor(name,pos,stand)
	local m=rb.Instance.new('Model');m.Name=name;m.Parent=arena
	local hum=rb.Instance.new('Humanoid');hum.Parent=m;hum.Health=100;hum.FloorMaterial=rb.Enum.Material.Air
	local root=rb.Instance.new('Part');root.Name='HumanoidRootPart';root.CFrame=rb.CFrame.new(pos);root.Position=pos;root.AssemblyLinearVelocity=V(0,8,0);root.Size=V(2,2,1);root.Parent=m
	local torso=rb.Instance.new('Part');torso.Name='Torso';torso.CFrame=root.CFrame;torso.Position=pos;torso.Size=V(2,2,1);torso.Parent=m
	local l=L.criar(m,nil,stand or 'STAR_PLATINUM');l.estado.standFora=true
	return l
end
local a=actor('A',V(0,3,0))
local b=actor('B',V(0,3,-5),'THE_WORLD')
local function move(l,pos)
 l.raiz.Position=pos; l.raiz.CFrame=rb.CFrame.new(pos); l.modelo.Torso.Position=pos; l.modelo.Torso.CFrame=rb.CFrame.new(pos)
end
local function reset(t)
	now=t;a.hum.FloorMaterial=rb.Enum.Material.Air;a.raiz.AssemblyLinearVelocity=V(0,8,0);table.clear(queue);table.clear(events);table.clear(acks);table.clear(forces)
	a.estado=R.novoEstado();a.estado.standFora=true;a.combate14=nil;a.acao14=nil;a.defesaSegurada14=false
	b.estado=R.novoEstado();b.hum.Health=100;move(b,V(0,3,-5))
	parede=false
end
-- active window and dedupe
B.m1(a,{seq=1,dir=V(0,0,-1)})
assert(a.estado.acaoAte==100.30)
advance(100.099);assert(b.hum.Health==100)
advance(100.101);assert(b.hum.Health<100)
local hp=b.hum.Health
advance(100.19);assert(b.hum.Health==hp,'dedupe sweep')
assert(events[#events].d.hitId and events[#events].d.actionId and events[#events].d.moveId=='m1')
-- late entrant is detected within 80 ms
reset(101);move(b,V(40,3,-5))
B.m1(a,{dir=V(0,0,-1)});advance(101.11);assert(b.hum.Health==100)
move(b,V(0,3,-5))
advance(101.17);assert(b.hum.Health<100,'late entrant missed')
-- wall, accessory-only broadphase, parry/block/whiff never authorize cancel
reset(102);parede=true;B.m1(a,{dir=V(0,0,-1)});advance(102.18)
assert(b.hum.Health==100 and not a.acao14.hitTime)
reset(103);move(b,V(40,3,-5))
local accessory=rb.Instance.new('Accessory');accessory.Parent=b.modelo
local handle=rb.Instance.new('Part');handle.Name='Handle';handle.Position=V(0,3,-5);handle.CFrame=rb.CFrame.new(handle.Position);handle.Size=V(2,2,2);handle.Parent=accessory
assert(not HB.corpo(handle,b))
B.m1(a,{dir=V(0,0,-1)});advance(103.18);assert(b.hum.Health==100)
accessory:Destroy()
reset(104);b.estado.bloqueando=true;b.estado.bloqueioInicio=103;b.raiz.CFrame=rb.CFrame.lookAt(b.raiz.Position,a.raiz.Position)
B.m1(a,{dir=V(0,0,-1)});advance(104.18);assert(not a.acao14.hitTime)
reset(105);b.estado.bloqueando=true;b.estado.bloqueioInicio=105.09;b.raiz.CFrame=rb.CFrame.lookAt(b.raiz.Position,a.raiz.Position)
B.m1(a,{dir=V(0,0,-1)});advance(105.18);assert(not a.acao14.hitTime and a.estado.stunAte>105.18)
-- n4 uppercut -> one linked followup; exact times / original combo and cooldown survive
reset(106);a.estado.combo=3;a.estado.comboT=106
B.m1(a,{seq=2,variante='cima',dir=V(0,0,-1)})
advance(106.159);assert(b.hum.Health==100)
advance(106.161);assert(b.hum.Health<100 and a.combate14.link)
local originalCD=a.estado.m1ProntoEm
local originalFall=b.estado.ragdollAte
advance(106.34);B.m1(a,{seq=3,dir=V(0,0,-1)})
assert(a.acao14.id=='m1_aereo' and a.estado.combo==4 and a.estado.m1ProntoEm==originalCD)
local before=b.hum.Health
advance(106.45);assert(b.hum.Health<before and b.estado.ragdollAte==originalFall)
assert(forces[#forces].v.Y==-24 and forces[#forces].d==0.12)
B.m1(a,{seq=4});assert(a.acao14.id=='m1_aereo','second followup started')
-- wrong target cannot receive reserved exception; miss consumes attempt
reset(108);a.estado.combo=3;a.estado.comboT=108;B.m1(a,{variante='cima'});advance(108.34)
move(b,V(40,3,-5))
B.m1(a,{});local air=a.acao14;advance(108.55);assert(air.id=='m1_aereo')
B.m1(a,{});assert(a.acao14==air)
-- held defense original press does not grant fresh parry after stun and releases immediately
reset(110);a.estado.stunAte=110.5
B.bloquear(a,true);assert(a.defesaSegurada14 and not a.estado.bloqueando)
advance(110.5);heart:Fire(0.01)
assert(a.estado.bloqueando and a.estado.bloqueioInicio==110)
a.estado.stunAte=112;B.bloquear(a,false)
assert(not a.defesaSegurada14 and not a.estado.bloqueando)
-- real hit cancel is available at +60 ms, never earlier; M1 cooldown/combo preserved
reset(114);B.m1(a,{seq=10});advance(114.159)
B.golpe(a,2,{slot=2,seq=11});assert(a.acao14.id=='m1')
advance(114.16);local cd=a.estado.m1ProntoEm
B.golpe(a,2,{slot=2,seq=12});assert(a.acao14.id=='STAR_PLATINUM_2' and a.estado.combo==1 and a.estado.m1ProntoEm==cd)
-- total buffer one, .12 boundary and replacement across move kinds
reset(116);move(b,V(40,3,-5));B.m1(a,{seq=20});advance(116.19)
B.m1(a,{seq=21});assert(a.combate14.buffer)
B.golpe(a,2,{slot=2,seq=22});assert(a.combate14.buffer.cmd.tipo=='golpe')
advance(116.30);heart:Fire(.01);assert(a.acao14.id=='STAR_PLATINUM_2' and a.acao14.seq==22 and not a.combate14.buffer)
-- cannot queue during barrage/ULT or stun; release clears pending command immediately
reset(118);B.golpe(a,1,{slot=1,seq=30});advance(122.51)
B.m1(a,{seq=31});assert(not a.combate14.buffer)
reset(124);B.m1(a,{seq=32});advance(124.19);B.m1(a,{seq=33});assert(a.combate14.buffer)
local player={};a.jogador=player
B.pedido(player,'soltar',{seq=100});assert(not a.combate14.buffer)
a.jogador=nil
-- old/duplicate seq cannot release new guard or interrupt action
reset(126);a.jogador=player
B.pedido(player,'m1',{seq=101});local action=a.acao14
B.pedido(player,'bloqueio',{seq=100,ligar=false});local acksBefore=#acks;B.pedido(player,'m1',{seq=101})
assert(#acks==acksBefore+1 and acks[#acks].d.actionId==action.actionId,'duplicate must repeat same ack')
assert(a.acao14==action and a.estado.combo==1)
a.jogador=nil
-- link expires / stun invalidates / a different action cannot borrow its recovery bypass
reset(128);a.estado.combo=3;a.estado.comboT=128;B.m1(a,{variante='cima'});advance(128.82)
B.m1(a,{});assert(a.acao14.id=='m1')
reset(130);a.estado.combo=3;a.estado.comboT=130;B.m1(a,{variante='cima'});advance(130.34)
R.atordoar(a.estado,now,.2,true);B.m1(a,{});assert(a.acao14.id=='m1')
-- one reserved target only: a second body in range never receives followup
reset(132);a.estado.combo=3;a.estado.comboT=132;B.m1(a,{variante='cima'});advance(132.34)
local c=actor('C',V(0,3,-5),'THE_WORLD');local cHP=c.hum.Health
B.m1(a,{});advance(132.45);assert(c.hum.Health==cHP)
L.remover(c.modelo);c.modelo:Destroy()
-- switching twice between ticks never revives a link; rejected Stand IDs do nothing
reset(133);a.estado.combo=3;a.estado.comboT=133;B.m1(a,{variante='cima'});advance(133.34)
local token=a.estado.token
assert(not L.trocarStand(a,'INVALIDO') and a.estado.token==token)
assert(L.trocarStand(a,'THE_WORLD') and L.trocarStand(a,'STAR_PLATINUM'))
assert(not a.combate14.link and a.estado.token~=token)
-- Real executors and real time sessions keep action attribution while owner uses newer M1.
local E=H.modulo('ServerScriptService/BB_Servidor/Executores')
B.iniciar(rem,E,nil)
E.iniciar(rem)
-- A late cleanup from interrupted barrage cannot erase a newer barrage's clash record.
reset(136);B.golpe(a,1,{});advance(136.01);R.interromper(a.estado,now);a.estado.cds.STAR_PLATINUM_1=0
B.golpe(a,1,{});advance(136.02);local currentRush=a.rajada
advance(136.251);assert(a.rajada==currentRush,'old barrage cleanup erased newer barrage')
local function hitEvent(phase,move)
 for _,evt in events do if evt.typ=='acerto' and evt.d.phase==phase and (not move or evt.d.moveId==move) then return evt.d end end
end
reset(140);a.estado.despertoAte=1000;B.golpe(a,'ult',{})
local ultAction=a.acao14.actionId
advance(141.9);assert(b.estado.congeladoAte>now)
B.m1(a,{});local queuedAction=a.acao14.actionId
advance(142.1);local queued=hitEvent('queued','m1')
assert(queued and queued.actionId==queuedAction and b.hum.Health==100)
advance(144.8);local resolved=hitEvent('resolved','m1')
assert(resolved and resolved.actionId==queuedAction and resolved.hitId==queued.hitId and b.hum.Health<100)
local ended=false
for _,ev in events do if ev.typ=='tempoVolta' then assert(ev.d.actionId==ultAction and ev.d.moveId=='STAR_PLATINUM_ULT'); ended=true end end
assert(ended)
-- Launched projectile preserves its original context after another action starts.
reset(146);E.iniciar(rem);B.golpe(a,4,{})
local launch=a.acao14.actionId
advance(146.46);B.m1(a,{});local newer=a.acao14.actionId
H.modulo('ServerScriptService/BB_Servidor/Projeteis').passo(.01)
local projHit=hitEvent('resolved','STAR_PLATINUM_4')
assert(projHit and projHit.actionId==launch and projHit.actionId~=newer)
-- The World rolo keeps the original ULT ID and its own moveId through queued/resolved.
reset(150);L.trocarStand(a,'THE_WORLD');a.estado.despertoAte=1000
B.golpe(a,'ult',{});local twUlt=a.acao14.actionId
advance(151.9);B.m1(a,{})
advance(156.8)
local roloQueued=hitEvent('queued','rolo');local roloResolved=hitEvent('resolved','rolo')
assert(roloQueued and roloResolved and roloQueued.actionId==twUlt and roloResolved.actionId==twUlt and roloQueued.hitId==roloResolved.hitId)
local roloFinal=false
for _,evt in events do if evt.typ=='explosao' and evt.d.moveId=='rolo' then
 assert(evt.d.actionId==twUlt and evt.d.phase=='final' and evt.d.stand=='THE_WORLD' and evt.d.quem==a.modelo and evt.d.t)
 roloFinal=true
end end
assert(roloFinal,'missing rolo final metadata')
L.trocarStand(a,'STAR_PLATINUM')
-- ordinary AJ13 fighters retain their original one-query and .2 recovery
for n,id in {'CRAZY_DIAMOND','KILLER_QUEEN'} do
 reset(160+n);a.standId=id;a.stand=H.modulo('ReplicatedStorage/BB/Stands').get(id)
 local tok=a.estado.token;assert(L.trocarStand(a,id) and a.estado.token==tok)
 B.m1(a,{});assert(a.estado.acaoAte==160+n+.2 and not a.acao14)
 advance(160+n+.11);assert(b.hum.Health<100,id)
end
print('COMBATE14 servidor real: sweeps/corpo/parede/parry/airlink/buffer/cancel/seq/legado OK')
