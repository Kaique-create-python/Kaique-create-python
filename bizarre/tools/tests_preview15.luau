-- Real preview + renderer + catalog. Only clock, Roblox events and Emit are boundaries.
local H=require('./harness');local R=require('@lune/roblox');local fs=require('@lune/fs')
assert(fs.isFile('bizarre/src/ReplicatedStorage/BB/Cliente/PreviaVFX14.luau'),'preview module missing')
local clock=100;local jobs={};local beats={};local emitted=0;local remoteCalls=0
R.implementMethod('ParticleEmitter','Emit',function(_,n)emitted+=n end)
R.implementMethod('RemoteEvent','FireServer',function()remoteCalls+=1;error('preview remote forbidden')end)
local world=R.Instance.new('Workspace');local rs=R.Instance.new('Folder')
local camera=R.Instance.new('Camera');camera.CFrame=R.CFrame.new(3,5,7);world.CurrentCamera=camera;local originalCamera=camera.CFrame
R.implementMethod('Workspace','GetServerTimeNow',function()return clock end)
local catalog=R.deserializeModel(fs.readFile('bizarre/assets/vfx14/catalogo.rbxm'))[1];catalog.Parent=rs
H.extras.workspace=world;H.servicos.ReplicatedStorage=rs
H.servicos.RunService.Heartbeat={Connect=function(_,fn)
 local entry={fn=fn,active=true};table.insert(beats,entry);return {Disconnect=function()entry.active=false end}
end}
H.extras.task={delay=function(dt,fn)table.insert(jobs,{t=clock+dt,fn=fn})end}
local function step(dt)
 local goal=clock+dt
 while true do
  table.sort(jobs,function(a,b)return a.t<b.t end)
  if not jobs[1] or jobs[1].t>goal then break end
  local nextJob=table.remove(jobs,1);local span=nextJob.t-clock;clock=nextJob.t
  for _,beat in beats do if beat.active then beat.fn(span)end end;nextJob.fn()
 end
 local span=goal-clock;clock=goal;for _,beat in beats do if beat.active then beat.fn(span)end end
end
local function actor(x)
 local m=R.Instance.new('Model');m.Parent=world
 local root=R.Instance.new('Part');root.Name='HumanoidRootPart';root.CFrame=R.CFrame.new(x,3,0);root.Position=R.Vector3.new(x,3,0);root.Parent=m
 local h=R.Instance.new('Humanoid');h.Health=100;h.WalkSpeed=16;h.Parent=m;return m,h
end
local a,hum=actor(0);local plr={Character=a};H.servicos.Players={LocalPlayer=plr}
local P=H.modulo('ReplicatedStorage/BB/Cliente/VFXPiloto')
local freezeCalls=0;P.congelar=function()freezeCalls+=1;error('preview global freeze forbidden')end
H.extras.require=function(node)
 if node.Name=='Som' or node.Name=='Camera' or node.Name=='Animador' then error('preview must not use combat audiovisual modules')end
 return H.require(node)
end
local contexts={};local originalPlay=P.tocar
P.tocar=function(stand,move,phase,ctx)
 if ctx and ctx.actionId and ctx.actionId:match('^preview14:')then table.insert(contexts,{stand=stand,move=move,phase=phase,ctx=ctx})end
 local h=originalPlay(stand,move,phase,ctx)
 if h and ctx and ctx.actionId and ctx.actionId:match('^preview15:')then table.insert(contexts,{stand=stand,move=move,phase=phase,ctx=ctx,handle=h})end
 return h
end
local Preview=H.modulo('ReplicatedStorage/BB/Cliente/PreviaVFX14')
local fighter=actor(60)
local combat=P.tocar('STAR_PLATINUM','bloqueio','inicio',{owner=fighter,actionId='combat:real',t=clock})
local ownCombat=P.tocar('STAR_PLATINUM','bloqueio','inicio',{owner=a,actionId='combat:own',t=clock})
local cancellations={};local originalCancel=P.cancelar
P.cancelar=function(owner,id)table.insert(cancellations,{owner,id});originalCancel(owner,id)end
local handle=Preview.tocar(a);assert(handle and handle.scopes[1]:match('^preview14:%d+:SP$') and handle.scopes[2]:match(':TW$'))
assert(combat.active and ownCombat.active,'preview interrupted combat scope')
assert(contexts[1].ctx.pos==R.Vector3.new(-6,3,-12) and contexts[2].ctx.pos==R.Vector3.new(6,3,-12),'SP/TW do not occupy two local positions in front')
local initial=emitted;step(3.5);assert(emitted>initial,'preview sequence did not emit approved assets')
local folder=world:FindFirstChild('BB_VFXPiloto14');assert(folder and #folder:GetChildren()>0)
local beam=false;for _,node in folder:GetDescendants()do if node:IsA('Beam')then beam=true end end
assert(beam,'preview StarFinger does not use real Beam')
assert(hum.Health==100 and hum.WalkSpeed==16 and a:GetAttribute('BB_Congelado')==nil)
step(3);assert(not handle.active and combat.active and ownCombat.active,'natural preview end affected combat')
local old=Preview.tocar(a);step(.7);local fresh=Preview.tocar(a)
assert(not old.active and fresh.active and combat.active);old.cancelar();assert(fresh.active,'old handle cancelled new preview');Preview.cancelar();Preview.cancelar();assert(not fresh.active and combat.active)
local dead=Preview.tocar(a);hum.Health=0;step(.01);assert(not dead.active and combat.active,'death cleanup affected combat')
local before=emitted;step(7);assert(emitted==before,'dead preview callback emitted')
hum.Health=100
local respawn=Preview.tocar(a);local b=actor(30);plr.Character=b;step(.01);assert(not respawn.active)
plr.Character=a;local removed=Preview.tocar(a);a.Parent=nil;step(.01);assert(not removed.active);a.Parent=world
assert(Preview.tocar(nil)==false,'nil owner must return false');catalog.Parent=nil;local missing=Preview.tocar(a);assert(missing==false,'missing catalog must return false');catalog.Parent=rs
assert(remoteCalls==0 and freezeCalls==0 and combat.active and camera.CFrame==originalCamera)
local knife=false
for _,call in contexts do
 assert(call.ctx.owner==a and call.ctx.actionId:match('^preview14:%d+:[ST][PW]$'))
 if call.move=='THE_WORLD_2' then assert(call.ctx.variant=='projetil' and call.ctx.n==1);knife=true end
end
assert(knife,'no unit knife preview')
for _,call in cancellations do assert(call[1]==a and call[2] and call[2]:match('^preview14:'),'preview cancellation escaped its scopes')end
R.deserializeModel(fs.readFile('bizarre/assets/vfx15/catalogo.rbxm'))[1].Parent=rs
for _,stand in {'MAGICIANS_RED','SILVER_CHARIOT','STAR_PLATINUM','THE_WORLD'}do
 local selected=assert(Preview.tocar(a,stand));step(1.6)
 Preview.cancelar();assert(not selected.active)
 for _,event in contexts do if event.handle and event.ctx.actionId:match('^preview15:')then assert(event.handle.cancelled or (not event.handle.active and #event.handle.items==0),'selected preview projectile escaped stop')end end
 step(20)
end
assert(camera.CFrame==originalCamera and remoteCalls==0 and freezeCalls==0,'selected preview changed gameplay')
P.cancelar=originalCancel;P.cancelar(nil);step(30);assert(#folder:GetChildren()==0,'preview clones leaked')
print('AJ14 preview REAL: sequence/Beam/scopes/cancel twice/death/respawn/removal/catalog absent/no damage OK')
