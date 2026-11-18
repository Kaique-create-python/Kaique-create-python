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
local fakePhysics=setmetatable({prender=function(l)l.raiz.Anchored=true end,soltar=function(l)l.raiz.Anchored=false end,empurrar=function(l,v,d)if l.raiz.Anchored then return end;table.insert(forces,{l=l,v=v,d=d})end},{__index=function()return function()end end})
local restored={};local fakeMap=setmetatable({restaurarPerto=function()return restored end,quebradasPerto=function()return 0 end,spawns=function()return{}end},{__index=function()return function()end end})
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

local Profile=H.modulo('ReplicatedStorage/BB/PerfilCombate14')
for _,id in {'CRAZY_DIAMOND','KILLER_QUEEN'}do assert(Profile.suporta(id),'Perfil responsivo ausente: '..id)end
local Links=H.modulo('ServerScriptService/BB_Servidor/Vinculos16')
local E=H.modulo('ServerScriptService/BB_Servidor/Executores')
B.iniciar(rem,E,nil);E.iniciar(rem)
local function tick(t)advance(t);Links.passo()end
local function fresh(t,id)
 reset(t);a.hum.Health=100;a.raiz.Anchored=false;b.raiz.Anchored=false;restored={}
 a.agarradoPor=nil;b.agarradoPor=nil
 L.trocarStand(a,id);a.estado.standFora=true
end
local function find(kind,move)
 for _,v in events do if v.typ==kind and (not move or v.d.moveId==move)then return v.d end end
end
-- Established bombs outlive the attack token, retaining the original action identity.
fresh(200,'KILLER_QUEEN');B.golpe(a,1,{});local bomb=a.acao14.actionId
tick(200.251);local hp=b.hum.Health;assert(hp<100,'bomb touch missed')
tick(200.56);B.m1(a,{});assert(a.acao14.actionId~=bomb)
tick(201.46);local ex=find('explosao','KILLER_QUEEN_1')
assert(ex and ex.actionId==bomb and ex.quem==a.modelo,'detonation lost original action')
assert(b.hum.Health<hp,'confirmed bomb lost damage after another action')
-- Echo is also established by a confirmed hit and must retain its own action.
fresh(204,'KILLER_QUEEN');B.golpe(a,4,{});local echo=a.acao14.actionId
tick(204.21);local before=b.hum.Health
tick(204.51);B.m1(a,{});tick(204.66)
local found=false;for _,v in events do if v.typ=='acerto'and v.d.moveId=='KILLER_QUEEN_4'and v.d.actionId==echo and v.d.t>204.6 then found=true end end
assert(found and b.hum.Health<before,'echo attribution/damage lost')
-- Actor identity, not an ordinary action token, owns established effects.
fresh(207,'CRAZY_DIAMOND');local binding=Links.capturar(a);a.estado.token+=1;assert(Links.vigente(binding,a))
L.trocarStand(a,'KILLER_QUEEN');assert(not Links.vigente(binding,a),'stand swap revived old binding')
-- A short lease cannot clear/release a longer prison; frozen release is deferred.
fresh(210,'CRAZY_DIAMOND');local one=Links.prender(a,b,.2,'BB_Preso');local two=Links.prender(a,b,1,'BB_Preso')
assert(b.raiz.Anchored);tick(210.25);assert(b.raiz.Anchored and b.modelo:GetAttribute('BB_Preso')==211)
b.estado.congeladoAte=212;tick(211.1);assert(b.raiz.Anchored and not b.modelo:GetAttribute('BB_Preso'))
b.estado.congeladoAte=0;tick(212.01);assert(not b.raiz.Anchored,'prison stayed anchored after time stop')
-- Owner death and victim generation replacement release only their own lease.
fresh(214,'CRAZY_DIAMOND');Links.prender(a,b,5,'BB_Pedra');a.hum.Health=0;tick(214.01)
assert(not b.raiz.Anchored and not b.modelo:GetAttribute('BB_Pedra'),'dead owner left prison')
fresh(216,'CRAZY_DIAMOND');Links.prender(a,b,5,'BB_Preso');L.trocarStand(b,'STAR_PLATINUM');tick(216.01)
assert(not b.raiz.Anchored,'victim generation kept old prison')
-- Restoration's no-debris damage is a real path; original values are used.
fresh(220,'CRAZY_DIAMOND');B.golpe(a,3,{});tick(220.51)
assert(b.hum.Health<100 and find('reconstruir','CRAZY_DIAMOND_3'),'empty restoration missing hit/event')
-- A dead owner cannot detonate a planted bomb later.
fresh(223,'KILLER_QUEEN');B.golpe(a,1,{});tick(223.26);local held=b.hum.Health;a.hum.Health=0
tick(225);assert(b.hum.Health==held and not b.modelo:GetAttribute('BB_Bomba'),'dead owner detonated/kept mark')
fresh(228,'CRAZY_DIAMOND');a.estado.despertoAte=1000;B.golpe(a,'ult',{});tick(228.31)
assert(b.raiz.Anchored,'diamond ULT did not capture');a.hum.Health=0;tick(228.32)
assert(not b.raiz.Anchored and not b.modelo:GetAttribute('BB_Pedra'),'diamond ULT left a dead-owner prison')
fresh(231,'KILLER_QUEEN');a.estado.despertoAte=1000
local back=rb.CFrame.new(-10,3,0);a.historico={{t=220,cf=back,hp=100},{t=230,cf=a.raiz.CFrame,hp=90}}
B.golpe(a,'ult',{});local rewind=a.acao14.actionId;tick(231.71)
local data=find('rebobinarFim','KILLER_QUEEN_ULT')
assert(data and data.actionId==rewind and data.para==back.Position and data.trajeto,'rewind lost authoritative result/path')
fresh(240,'CRAZY_DIAMOND');B.golpe(a,4,{});advance(240.23)
assert(b.agarradoPor==a)
L.trocarStand(a,'KILLER_QUEEN');L.trocarStand(a,'CRAZY_DIAMOND');a.estado.standFora=true
B.golpe(a,4,{});advance(240.46);Links.passo()
assert(b.agarradoPor==a,'old prison cleanup cleared newer grab from same actor')
tick(242.1);assert(not b.raiz.Anchored,'replacement grab failed to release')
fresh(245,'CRAZY_DIAMOND');a.estado.despertoAte=1000;B.golpe(a,'ult',{});tick(246.4)
local launched=false;for _,f in forces do if f.l==b and f.v.Y>0 then launched=true end end
assert(launched,'diamond ULT lost final launch while victim was anchored')
local Projectiles=H.modulo('ServerScriptService/BB_Servidor/Projeteis')
fresh(250,'KILLER_QUEEN');B.golpe(a,2,{});local tank=a.acao14.actionId;advance(250.56)
B.m1(a,{});Projectiles.passo(.01)
local boom=find('explosao','KILLER_QUEEN_2')
assert(boom and boom.actionId==tank,'tank explosion borrowed newer M1 context')
fresh(252,'MAGICIANS_RED');local fire=H.modulo('ReplicatedStorage/BB/Golpes').get('MAGICIANS_RED_1')
B.golpe(a,1,{});local fireAction=a.acao14.actionId;advance(252+fire.trava+.01);B.m1(a,{})
Projectiles.passo(.01);local fireBoom=find('explosao','MAGICIANS_RED_1')
assert(b.hum.Health<100 and fireBoom and fireBoom.actionId==fireAction,'existing Crossfire lost damage after a newer action')
for i,reason in {'death','swap','remove'}do
 fresh(253+i*2,'KILLER_QUEEN');B.golpe(a,3,{});advance(253+i*2+.27);local before=b.hum.Health
 if reason=='death'then a.hum.Health=0 elseif reason=='swap'then L.trocarStand(a,'STAR_PLATINUM')else L.remover(a.modelo)end
 Projectiles.passo(.01)
 assert(b.hum.Health==before and Projectiles.quantos()==0,'obsolete projectile survived '..reason)
end
print('AJ16 server: six profiles, bomb/echo attribution, leases, freeze, death/swap, restoration PASS')
