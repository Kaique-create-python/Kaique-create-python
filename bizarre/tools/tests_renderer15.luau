local H=require('./harness')
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local rb=require('@lune/roblox')
local R=H.modulo('ReplicatedStorage/BB/VFXReceitas')
local rs=rb.Instance.new('Folder')
for _,v in {14,15}do rb.deserializeModel(fs.readFile('bizarre/assets/vfx'..v..'/catalogo.rbxm'))[1].Parent=rs end
local world=rb.Instance.new('Workspace');local clock=100;local step
rb.implementMethod('ParticleEmitter','Emit',function()end)
rb.implementMethod('Workspace','GetServerTimeNow',function()return clock end)
local env={game={GetService=function(_,n)if n=='ReplicatedStorage'then return rs elseif n=='RunService'then return {Heartbeat={Connect=function(_,f)step=f;return{Disconnect=function()end}end}}end end},workspace=world,script={Parent={Parent={VFXReceitas={}}}},require=function()return R end}
for _,n in {'Instance','Vector3','CFrame','Color3','ColorSequence','ColorSequenceKeypoint','NumberSequence','NumberSequenceKeypoint','NumberRange','Enum'}do env[n]=rb[n]end
local P=luau.load(fs.readFile('bizarre/src/ReplicatedStorage/BB/Cliente/VFXPiloto.luau'),{environment=env})()
local function actor(x)
 local m=rb.Instance.new('Model');m.Parent=world;local h=rb.Instance.new('Humanoid');h.Health=100;h.Parent=m
 local r=rb.Instance.new('Part');r.Name='HumanoidRootPart';r.CFrame=rb.CFrame.new(x,3,0);r.Parent=m;return m,r
end
local a,ar=actor(0);local b,br=actor(15)
local function tick(t)clock+=t;step(t)end
local h=P.tocar('SILVER_CHARIOT','m1','inicio',{owner=a,actionId='mesh',n=1,t=clock})
assert(#h.items>0,'new catalog was not rendered')
tick(.02)
local mesh=h.items[1].node
assert(mesh:GetAttribute('BB_VisibleMesh') and mesh.Transparency<1)
local old=mesh.Transparency;tick(.1);assert(mesh.Transparency~=old,'mesh fade did not advance')
a:SetAttribute('BB_SessaoTempo','s1');a:SetAttribute('BB_Congelado',clock+5)
P.congelar('s1',b,clock+5);local cf=mesh.CFrame;local alpha=mesh.Transparency;tick(1)
assert(mesh.CFrame==cf and mesh.Transparency==alpha,'mesh did not freeze with actor')
P.descongelar('s1');tick(.2);assert(not mesh.Parent,'mesh survived timeline')
a:SetAttribute('BB_Congelado',nil);a:SetAttribute('BB_SessaoTempo',nil)
local grab=P.tocar('MAGICIANS_RED','agarrao','inicio',{owner=a,target=b,actionId='grab',dur=1.6,t=clock})
br.CFrame=rb.CFrame.new(18,3,0);tick(.1)
assert((grab.items[1].node.CFrame.Position-br.CFrame.Position).Magnitude<.01,'capture flame must follow actual victim')
local sol=P.tocar('MAGICIANS_RED','sol','inicio',{owner=a,actionId='sol',above=rb.Vector3.new(0,24,0),destination=rb.Vector3.new(0,0,-28),formar=1.1,cair=.5,t=clock})
tick(1.35)
local pos=sol.items[1].parts[1].node.CFrame.Position
assert(pos.Y<24 and pos.Y>0 and pos.Z<0,'solar effect did not follow formation/fall')
local fade=P.tocar('SILVER_CHARIOT','m1','inicio',{owner=a,actionId='fade',n=1,t=clock})
tick(.06);local node=fade.items[1].node
P.cancelar(a,'fade');tick(.02);assert(node.Parent and node.Transparency<1,'cancel skipped mesh fade')
tick(.1);assert(not node.Parent,'mesh cancellation did not expire')
local fm=P.tocar('SILVER_CHARIOT','m1','inicio',{owner=a,actionId='frozen-cancel',t=clock})
tick(.05);local fn=fm.items[1].node
a:SetAttribute('BB_SessaoTempo','cancel-session');a:SetAttribute('BB_Congelado',clock+5)
P.congelar('cancel-session',b,clock+5);P.cancelar(a,'frozen-cancel');tick(.11)
assert(not fn.Parent,'cancelled frozen mesh was retained until unfreeze')
P.descongelar('cancel-session');a:SetAttribute('BB_SessaoTempo',nil);a:SetAttribute('BB_Congelado',nil)
local shot=P.tocar('SILVER_CHARIOT','SILVER_CHARIOT_2','inicio',{owner=a,actionId='shot',variant='projetil',t=clock,dir=rb.Vector3.new(0,0,-1),pos=rb.Vector3.zero,dur=1,speed=150})
tick(.1)
P.estadoProjetil(a,'shot',{pos=rb.Vector3.new(0,0,-15),dir=rb.Vector3.new(0,0,-1),ate=clock+5,resta=85,vel=150})
local stopped=shot.items[1].parts[1].node.CFrame;tick(1);assert(shot.items[1].parts[1].node.CFrame==stopped,'projectile moved while server paused')
P.estadoProjetil(a,'shot',{pos=rb.Vector3.new(0,0,-15),dir=rb.Vector3.new(0,0,-1),ate=0,resta=85,vel=150})
tick(.1);assert((shot.items[1].parts[1].node.CFrame.Position-rb.Vector3.new(0,0,-30)).Magnitude<.1,'resume jumped instead of rebasing')
a:SetAttribute('BB_Stand','SILVER_CHARIOT')
local buff=P.tocar('SILVER_CHARIOT','buff','inicio',{owner=a,actionId='buff-swap',dur=8,t=clock})
a:SetAttribute('BB_Stand','MAGICIANS_RED');tick(.02);assert(buff.cancelled,'stand swap kept old buff visual active')
local preview=P.tocar('SILVER_CHARIOT','m1','inicio',{owner=a,actionId='preview-switch',preview=true,t=clock})
tick(.02);assert(not preview.cancelled,'preview must not require selected stand to be equipped')
P.cancelar(a);tick(10)
assert(#world.BB_VFXPiloto14:GetChildren()==0,'cancelled residue did not clean')
print('AJ15 renderer real: mesh/fade/freeze/TTL/target/solar timeline PASS')
