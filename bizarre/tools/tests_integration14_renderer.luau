-- Full Acoes -> Apresentacao14 -> VFXPiloto -> approved RBXM integration.
local H=require('./harness');local R=require('@lune/roblox');local fs=require('@lune/fs')
local clock=100;local pending={};local beats={};local emitted=0
R.implementProperty('BasePart','Position',function(self)return self.CFrame.Position end,function(self,v)self.CFrame=R.CFrame.new(v)*self.CFrame.Rotation end)
R.implementProperty('Attachment','Position',function(self)return self.CFrame.Position end,function(self,v)self.CFrame=R.CFrame.new(v)*self.CFrame.Rotation end)
R.implementMethod('ParticleEmitter','Emit',function(_,n)emitted+=n end)
local world=R.Instance.new('Workspace');local rs=R.Instance.new('Folder')
R.implementMethod('Workspace','GetServerTimeNow',function()return clock end)
local catalog=R.deserializeModel(fs.readFile('bizarre/assets/vfx14/catalogo.rbxm'))[1];catalog.Parent=rs
H.extras.workspace=world;H.servicos.ReplicatedStorage=rs
H.extras.os={clock=function()return clock end}
H.servicos.Debris={AddItem=function()end}
H.servicos.RunService.Heartbeat={Connect=function(_,fn)table.insert(beats,fn);return {Disconnect=function()end}end}
H.extras.task={delay=function(dt,fn)table.insert(pending,{t=clock+dt,fn=fn})end,spawn=function()end,wait=function()error('unused async loop')end}
local function step(dt)
 clock+=dt
 for i=#pending,1,-1 do if pending[i].t<=clock then local f=table.remove(pending,i);f.fn() end end
 for _,fn in beats do fn(dt)end
end
local function actor(id,x)
 local m=R.Instance.new('Model');m.Parent=world;m:SetAttribute('BB_Stand',id)
 local root=R.Instance.new('Part');root.Name='HumanoidRootPart';root.CFrame=R.CFrame.new(x,3,0);root.Position=R.Vector3.new(x,3,0);root.Parent=m
 local h=R.Instance.new('Humanoid');h.Health=100;h.Parent=m;return m
end
local a=actor('STAR_PLATINUM',0);local b=actor('THE_WORLD',10);local c=actor('THE_WORLD',20)
H.servicos.Players={LocalPlayer={Character=a}}
local animCount=0
local deps={
 Animador={tocar=function()animCount+=1 end,tocando=function()return nil end,cortar=function()end,hitstop=function()end},
 StandVisual={modelo=function()return nil end,acao=function()end,cancelar=function()end,investida=function()end},
 Som={voz=function()return nil end,duracaoVoz=function()return 0 end,tocar=function()end,golpe=function()end,vozPronta=function()return true end,abafar=function()end},
 Camera={tremer=function()end,fov=function()end},Cinematica={ult=function()end,cancelar=function()end},Registro={iniciar=function()end,todosModelos=function()return {}end},
 VFX=setmetatable({},{__index=function(_,key)return function()error('unexpected AJ13 '..key)end end}),
}
H.extras.require=function(node)return deps[node.Name] or H.require(node)end
local E=H.modulo('ReplicatedStorage/BB/Cliente/Efeitos');deps.Efeitos=E
local A=H.modulo('ReplicatedStorage/BB/Cliente/Acoes');deps.Acoes=A
local P=H.modulo('ReplicatedStorage/BB/Cliente/VFXPiloto')
A.tocar(a,{id='STAR_PLATINUM_1',seq=1});step(.26)
local folder=world:FindFirstChild('BB_VFXPiloto14');assert(folder and #folder:GetChildren()>0 and emitted>0)
local count=animCount;assert(A.confirmar(a,{seq=1,actionId='confirmed1'}));assert(animCount==count)
assert(A.interromper(a,'confirmed1',1));assert(#folder:GetChildren()>0,'cancel destroyed live authored particles')
for _,node in folder:GetDescendants()do if node:IsA('ParticleEmitter')then assert(not node.Enabled,'prediction scope not remapped to ACK actionId')end end
local d={a=a,v=b,pos=R.Vector3.new(10,4,0),dir=R.Vector3.new(0,0,-1),stand='STAR_PLATINUM',moveId='m1',hitId='realhit',phase='queued',congelado=true,t=clock}
E.acerto(d);local after=emitted;E.acerto(d);assert(after==emitted,'duplicate contact emitted')
d.phase='resolved';d.congelado=false;E.acerto(d);assert(emitted>after,'resolved phase hidden by queued phase')
local guard=P.tocar('THE_WORLD','bloqueio','inicio',{owner=b,actionId='guard',t=clock})
local pe=guard.items[1].particles[1].node
local firstVictim=actor('THE_WORLD',30)
local outside=actor('STAR_PLATINUM',250)
local firstGuard=P.tocar('THE_WORLD','bloqueio','inicio',{owner=firstVictim,actionId='firstGuard',t=clock})
local outsideGuard=P.tocar('STAR_PLATINUM','bloqueio','inicio',{owner=outside,actionId='outsideGuard',t=clock})
local firstPE=firstGuard.items[1].particles[1].node
local outsidePE=outsideGuard.items[1].particles[1].node
-- Fixture simulates server-owned spatial membership; production only reads these attributes.
firstVictim:SetAttribute('BB_SessaoTempo','s1');firstVictim:SetAttribute('BB_Congelado',clock+3)
b:SetAttribute('BB_SessaoTempo','s2');b:SetAttribute('BB_Congelado',clock+5)
E.tempo({sessao='s1',dono=a,stand='STAR_PLATINUM',inicio=clock,fim=clock+3,centro=R.Vector3.zero,raio=150})
assert(firstPE.TimeScale==0 and pe.TimeScale>0,'session association not respected before second session')
E.tempo({sessao='s2',dono=c,stand='THE_WORLD',inicio=clock,fim=clock+5,centro=R.Vector3.zero,raio=150})
assert(pe.TimeScale==0 and firstPE.TimeScale==0 and outsidePE.TimeScale>0,'unmarked outside actor was frozen')
E.tempoVolta({sessao='s1',dono=a})
assert(firstPE.TimeScale>0 and pe.TimeScale==0,'first session disturbed independent second session')
assert(firstVictim:GetAttribute('BB_SessaoTempo')=='s1','client modified server membership')
firstVictim:SetAttribute('BB_SessaoTempo',nil);firstVictim:SetAttribute('BB_Congelado',nil)
E.tempoVolta({sessao='s2',dono=c});assert(pe.TimeScale>0)
assert(b:GetAttribute('BB_SessaoTempo')=='s2' and b:GetAttribute('BB_Congelado')==clock+5,'client cleared server attributes')
b:SetAttribute('BB_SessaoTempo',nil);b:SetAttribute('BB_Congelado',nil)
assert(outside:GetAttribute('BB_Congelado')==nil and outsidePE.TimeScale>0,'client invented out-of-radius freeze tag')
P.cancelar(nil);step(30);assert(#folder:GetChildren()==0,'renderer integration leaked clones')
print('AJ14 full real renderer integration: ACK/cancel, phase dedupe, two freezes, cleanup OK')
