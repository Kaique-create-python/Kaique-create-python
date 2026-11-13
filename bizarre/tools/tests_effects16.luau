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

a:SetAttribute('BB_Stand','KILLER_QUEEN');b:SetAttribute('BB_Geracao14',1)
E.marca({quem=a,v=b,stand='KILLER_QUEEN',actionId='bomb-old',moveId='KILLER_QUEEN_1',ate=clock+1.2,t=clock,bomba=true})
local folder=world:FindFirstChild('BB_VFXPiloto14');assert(folder and #folder:GetChildren()>0,'mark was not routed to incorporated VFX')
local count=#folder:GetChildren();E.marca({quem=a,v=b,stand='KILLER_QUEEN',actionId='bomb-old',moveId='KILLER_QUEEN_1',ate=clock+1.2,t=clock,bomba=true})
assert(#folder:GetChildren()==count,'duplicate mark created another scope')
A.tocar(a,{id='m1',seq=1});step(.31)
local present=false;for _,node in folder:GetChildren()do if node:GetAttribute('BB_ActionId'):find('marca:')then present=true end end
assert(present,'next action cleared established mark')
b:SetAttribute('BB_Geracao14',2);step(.01)
for _,node in folder:GetChildren()do if node:GetAttribute('BB_ActionId'):find('marca:')then for _,n in node:GetDescendants()do if n:IsA('ParticleEmitter')then assert(not n.Enabled,'target generation kept emitting')end end end end
P.cancelar(nil);step(20)
E.proj({id=992,dono=a,stand='KILLER_QUEEN',moveId='KILLER_QUEEN_2',visual='tanque',origem=R.Vector3.zero,dir=R.Vector3.new(0,0,-1),t=clock,vel=38,alcance=150,raio=2})
count=#folder:GetChildren();assert(count>0)
E.projVirar({id=992,pos=R.Vector3.new(0,0,-3.8),dir=R.Vector3.new(1,0,0),t=clock,resta=146.2})
assert(#folder:GetChildren()==count,'homing direction restarted muzzle/particles')
step(.1)
local first=folder:GetChildren()[1];local position=first:IsA('BasePart')and first or first:FindFirstChildWhichIsA('BasePart',true)
assert(position,'guided projectile VFX missing')
E.projFim({id=992,pos=R.Vector3.zero,explodiu=false});P.cancelar(nil);step(20)
a:SetAttribute('BB_Stand','CRAZY_DIAMOND')
local brick=R.Instance.new('Part');brick.CFrame=R.CFrame.new(5,0,0);brick.Parent=world
E.reconstruir({quem=a,stand='CRAZY_DIAMOND',actionId='restore',moveId='CRAZY_DIAMOND_3',pos=R.Vector3.zero,n=1,partes={brick},t=clock})
assert(world:FindFirstChild('BB_Residuos16'),'restoration copies missing')
assert(brick.CFrame==R.CFrame.new(5,0,0),'client changed real collision part')
print('AJ16 Efeitos integration: established mark dedupe/generation, guided projectile stable scope, real restoration PASS')
