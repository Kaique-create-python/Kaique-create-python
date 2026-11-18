local H=require('./harness');local R=require('@lune/roblox')
local Rules=H.modulo('ReplicatedStorage/BB/Regras')
local node=H.arvore.ServerScriptService.BB_Servidor.LaboratorioServidor17
assert(node,'training service missing')
local T=H.require(node);local clock=10;local created=0;local removed=0;local target
local world=R.Instance.new('Folder');local calls={};local messages={}
local function actor(x)
 local m=R.Instance.new('Model');m.Parent=world
 local root=R.Instance.new('Part');root.Name='HumanoidRootPart';root.CFrame=R.CFrame.new(x,4,0);root.Position=R.Vector3.new(x,4,0);root.Parent=m
 local h=R.Instance.new('Humanoid');h.Health=100;h.Parent=m
 return{modelo=m,raiz=root,hum=h,estado=Rules.novoEstado()}
end
local player={UserId=5,Parent=true,mode='treino',GetAttribute=function(self,k)return self.mode end}
local owner=actor(0);owner.jogador=player;owner.estado.cds.skill=44
local C={bloquear=function(b,v)table.insert(calls,{'block',v,b})end,evasiva=function(b)table.insert(calls,{'evade',b})end,m1=function(b)table.insert(calls,{'m1',b})end,cancelar=function()end}
local service=T.novo({agora=function()return clock end,Lutadores={doJogador=function(who)return who==player and owner end,remover=function()removed+=1 end},Combate=C,Mapa={treino=function()return{spawn=R.CFrame.new(0,4,0),bonecos={R.CFrame.new(0,4,-12)}}end},Bots={criarLaboratorio17=function(who)created+=1;target=actor(-10);target.laboratorioDono17=who;return target end}}, {FireClient=function(_,who,data)table.insert(messages,{who=who,data=data})end})
service:receber(player,{tipo='configurar',modo='script'});assert(created==0)
clock+=.4;service:receber(player,{tipo='configurar',modo='bloquear'});assert(created==1)
local first=target;target.estado.stunAte=11
service:contato({},target,{dano=99});assert(messages[#messages].data.hits==0,'another attacker changed report')
service:contato(owner,target,{dano=5});assert(messages[#messages].data.dano==5)
service:passo();assert(#calls==0,'blocked during stun')
clock=11.1;service:passo();assert(calls[1][1]=='block' and calls[1][2]==true)
clock=11.5;service:receber(player,{tipo='configurar',modo='contra'});assert(created==1 and target==first,'mode switch reset target/cooldown')
clock=12.6;service:receber(player,{tipo='reiniciar'});assert(created==2 and removed==1)
assert(owner.estado.cds.skill==44 and owner.hum.Health==100,'reset changed live player combat state')
clock=13;service:receber(player,{tipo='reiniciar'});assert(created==2,'reset was not rate limited')
player.mode='luta';clock=13.5;service:passo();assert(removed==2 and target.modelo.Parent==nil,'left training with active target')
service:receber(player,{tipo='configurar',modo='parado'});assert(created==2,'non-training request spawned target')
print('AJ17 real training service: ownership, state gates, recovery, reset isolation/rate, cleanup PASS')
-- CreateHumanoidModelFromDescription yields; a Stand swap keeps the fighter table.
player.mode='treino';clock=50;owner.geracao14=1
local pendingTarget
local slow=T.novo({agora=function()return clock end,Lutadores={doJogador=function()return owner end,remover=function()end},Combate=C,Mapa={treino=function()return{spawn=R.CFrame.new(0,4,0),bonecos={R.CFrame.new(0,4,-12)}}end},Bots={criarLaboratorio17=function(who)
 coroutine.yield('loading');pendingTarget=actor(-10);pendingTarget.laboratorioDono17=who;return pendingTarget
end}}, {FireClient=function()end})
local co=coroutine.create(function()slow:receber(player,{tipo='configurar',modo='parado'})end)
assert(coroutine.resume(co))
slow:limpar(player);owner.geracao14+=1
assert(coroutine.resume(co))
assert(pendingTarget.modelo.Parent==nil,'stale async dummy survived cleanup/Stand swap')
print('AJ17 asynchronous training generation cleanup PASS')
