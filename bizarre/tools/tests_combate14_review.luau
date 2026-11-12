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
	local hum=rb.Instance.new('Humanoid');hum.Parent=m;hum.Health=100
	local root=rb.Instance.new('Part');root.Name='HumanoidRootPart';root.CFrame=rb.CFrame.new(pos);root.Position=pos;root.AssemblyLinearVelocity=V(0,0,0);root.Size=V(2,2,1);root.Parent=m
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
	now=t;table.clear(queue);table.clear(events);table.clear(acks);table.clear(forces)
	a.estado=R.novoEstado();a.estado.standFora=true;a.combate14=nil;a.acao14=nil;a.defesaSegurada14=false
	b.estado=R.novoEstado();b.hum.Health=100;move(b,V(0,3,-5))
	parede=false
end

local failures=0
local function test(name,fn)
 local ok,err=pcall(fn)
 print((if ok then 'PASS ' else 'FAIL ')..name..(if ok then '' else ': '..tostring(err)))
 if not ok then failures+=1 end
end
local function airborne()
 a.hum.FloorMaterial=rb.Enum.Material.Air;a.raiz.AssemblyLinearVelocity=V(0,8,0)
end
local function upper(t)
 reset(t);airborne();a.estado.combo=3;a.estado.comboT=now;B.m1(a,{variante='cima',dir=V(0,0,-1)})
 advance(t+.34);assert(a.combate14.link)
end
test('R1 server rejects grounded forged uppercut',function()
 reset(200);a.hum.FloorMaterial=rb.Enum.Material.Ground;a.raiz.AssemblyLinearVelocity=V(0,0,0)
 a.estado.combo=3;a.estado.comboT=now;B.m1(a,{variante='cima',dir=V(0,0,-1)});advance(200.17)
 assert(a.acao14.variant~='cima' and not a.combate14.link)
end)
test('R2 reserved victim outside original direction must miss without rotation',function()
 upper(202);move(b,V(5,3,-5));local hp=b.hum.Health
 B.m1(a,{dir=V(0,0,-1)});advance(202.45)
 assert(b.hum.Health==hp,'aerial auto-aimed outside original box')
end)
test('R3 Player sequence floor survives replacement; no-seq player rejected; bot remains',function()
 reset(204);local player={};a.jogador=player
 B.pedido(player,'m1',{seq=400});assert(a.acao14)
 L.remover(a.modelo)
 local replacement=actor('Replacement',V(0,3,0));replacement.jogador=player
 B.pedido(player,'golpe',{seq=399,slot=2});assert(not replacement.acao14,'old seq399 accepted')
 B.pedido(player,'golpe',{slot=2});assert(not replacement.acao14,'missing player seq accepted')
 B.pedido(player,'golpe',{seq=401,slot=2});assert(replacement.acao14 and replacement.acao14.seq==401)
 H.servicos.Players.PlayerRemoving:Fire(player)
 local old=replacement.acao14
 B.pedido(player,'m1',{seq=1});assert(replacement.acao14==old,'removed player replay accepted')
 L.remover(replacement.modelo);replacement.modelo:Destroy();a.jogador=nil
 a=L.criar(a.modelo,nil,'STAR_PLATINUM');a.estado.standFora=true
 B.m1(a,{});assert(a.acao14,'bot without seq rejected')
end)
-- restore after failed R3 as well
if not L.de(a.modelo) then a=L.criar(a.modelo,nil,'STAR_PLATINUM');a.estado.standFora=true end
a.jogador=nil
test('R4 invalid ULT cannot replace valid buffer',function()
 reset(206);move(b,V(40,3,-5));B.m1(a,{});advance(206.19)
 B.golpe(a,2,{slot=2});assert(a.combate14.buffer.cmd.dados.slot==2)
 B.golpe(a,'ult',{slot='ult'});assert(a.combate14.buffer.cmd.dados.slot==2)
 advance(206.30);heart:Fire(.01);assert(a.acao14.id=='STAR_PLATINUM_2')
end)
test('natural uppercut completion retains link',function()
 upper(208);advance(208.50);heart:Fire(.01);assert(a.acao14.encerrada and a.combate14.link)
 B.m1(a,{});assert(a.acao14.id=='m1_aereo')
end)
test('R5 reserved victim double Stand swap invalidates hit',function()
 upper(210);B.m1(a,{dir=V(0,0,-1)});local hp=b.hum.Health
 L.trocarStand(b,'STAR_PLATINUM');L.trocarStand(b,'THE_WORLD');advance(210.45)
 assert(b.hum.Health==hp,'reserved aerial survived victim double swap')
end)
test('Died invalidates link even if health/model reused before callback',function()
 upper(212);B.m1(a,{dir=V(0,0,-1)});local hp=b.hum.Health
 b.hum.Health=0;B.abate(b);b.hum.Health=hp;advance(212.45)
 assert(b.hum.Health==hp,'old-life aerial dealt damage after death')
end)
test('Died attacker invalidates callbacks, queued damage and held input immediately',function()
 reset(214);B.m1(a,{});a.defesaSegurada14=true;a.filaTempo={{h={dano=9}}}
 local token=a.estado.token;a.hum.Health=0;B.abate(a)
 assert(a.estado.token~=token and not a.filaTempo and not a.defesaSegurada14 and not a.acao14)
 a.hum.Health=100;advance(214.18);assert(b.hum.Health==100,'dead action resumed')
end)
local E=H.modulo('ServerScriptService/BB_Servidor/Executores');B.iniciar(rem,E,nil);E.iniciar(rem)
test('R6 lateral wall blocks projectile volume victim while centerline is free',function()
 reset(216);move(b,V(3,3,-5));a.dir=V(0,0,-1);a.dirT=now
 local wall=rb.Instance.new('Part');wall.Size=V(.3,10,20);wall.Position=V(1.5,3,-5);wall.CanCollide=true;wall.Parent=arena
 local pathQueries=0
 ws.Raycast=function(_,origin,vector,_params)
  pathQueries+=1
  if math.abs(vector.X)<1e-8 then return nil end
  local fraction=(1.5-origin.X)/vector.X
  if fraction>=0 and fraction<=1 then return {Instance=wall,Position=origin+vector*fraction} end
  return nil
 end
 B.golpe(a,4,{dir=V(0,0,-1)});advance(216.23)
 local hp=b.hum.Health
 H.modulo('ServerScriptService/BB_Servidor/Projeteis').passo(.01)
 assert(pathQueries>0 and b.hum.Health==hp,'projectile overlap damaged body behind lateral wall')
 ws.Raycast=function()return nil end;wall:Destroy()
end)
test('R7 session cannot revive after owner death/recovery between polls',function()
 reset(220);a.estado.despertoAte=1000;B.golpe(a,'ult',{});advance(221.9)
 assert(b.estado.congeladoAte>now)
 a.hum.Health=0;B.abate(a);a.hum.Health=100;advance(222.1)
 assert(b.estado.congeladoAte==0 and not b.sessaoTempo,'dead session revived after Health recovered')
end)
test('R7 removed owner with model still parented cannot retain session',function()
 reset(224);a.estado.despertoAte=1000;B.golpe(a,'ult',{});advance(225.9)
 assert(b.estado.congeladoAte>now)
 L.remover(a.modelo);advance(226.1)
 assert(b.estado.congeladoAte==0 and not b.sessaoTempo,'unregistered owner still maintained time')
 a=L.criar(a.modelo,nil,'STAR_PLATINUM');a.estado.standFora=true
end)
test('legacy death/removal cancellation invalidates pending M1 without new pilot rules',function()
 for n,id in {'CRAZY_DIAMOND','MAGICIANS_RED','SILVER_CHARIOT','KILLER_QUEEN'} do
  reset(230+n);a.standId=id;a.stand=H.modulo('ReplicatedStorage/BB/Stands').get(id)
  B.m1(a,{});local token=a.estado.token
  a.hum.Health=0;B.abate(a);a.hum.Health=100
  assert(a.estado.token~=token,'legacy dead action token retained')
  advance(230+n+.18);assert(b.hum.Health==100,'legacy dead M1 revived')
  reset(230+n+.5);B.m1(a,{});token=a.estado.token;L.remover(a.modelo)
  assert(a.estado.token~=token,'legacy removed action token retained')
  advance(230+n+.68);assert(b.hum.Health==100,'legacy removed M1 resumed')
  a=L.criar(a.modelo,nil,id);a.estado.standFora=true
 end
end)
test('despertar race preserves Player seq when server already awakened',function()
 reset(238);a.standId='STAR_PLATINUM';a.stand=H.modulo('ReplicatedStorage/BB/Stands').get(a.standId)
 a.jogador={};a.estado.despertoAte=1000
 B.pedido(a.jogador,'despertar',{seq=1})
 assert(a.acao14 and a.acao14.id=='STAR_PLATINUM_ULT' and a.acao14.seq==1)
 assert(acks[#acks].d.seq==1,'ULT race lost seq')
 a.jogador=nil
end)
assert(failures==0,tostring(failures)..' combat review regressions failed')
print('COMBATE14 review regressions GREEN')
