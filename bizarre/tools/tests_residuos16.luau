local H=require('./harness');local R=require('@lune/roblox')
local world=R.Instance.new('Workspace');local now=100;local step
R.implementMethod('Workspace','GetServerTimeNow',function()return now end)
H.extras.workspace=world;H.servicos.RunService.Heartbeat={Connect=function(_,f)step=f;return{Disconnect=function()end}end}
local function actor(id,x)
 local m=R.Instance.new('Model');m.Parent=world;m:SetAttribute('BB_Stand',id);m:SetAttribute('BB_Geracao14',1)
 local r=R.Instance.new('Part');r.Name='HumanoidRootPart';r.CFrame=R.CFrame.new(x,3,0);r.Parent=m
 local h=R.Instance.new('Humanoid');h.Health=100;h.Parent=m
 local arm=R.Instance.new('Part');arm.Name='Right Arm';arm.CFrame=r.CFrame;arm.Parent=m
 return m,r
end
local a,root=actor('CRAZY_DIAMOND',0);local b,br=actor('THE_WORLD',10)
local fx=H.modulo('ReplicatedStorage/BB/Cliente/Residuos16')
local part=R.Instance.new('Part');part.Material=R.Enum.Material.Brick;part.CFrame=R.CFrame.new(5,0,0);part.Parent=world
local script=R.Instance.new('Script');script.Parent=part
local mesh=R.Instance.new('SpecialMesh');mesh.Parent=part
local clone=fx.copiar(part);assert(clone.Anchored and not clone.CanCollide and not clone.CanQuery and #clone:GetChildren()==1)
clone:Destroy()
local restored=fx.restaurar(a,{part});assert(restored and #restored:GetChildren()==1)
local node=restored:GetChildren()[1];local start=node.CFrame;now+=.2;step(.2)
assert(node.CFrame~=start and part.CFrame==R.CFrame.new(5,0,0),'restoration moved original or failed to animate')
now+=1;step(1);assert(not restored.Parent,'restore residue leaked')
local prison=fx.pedra(a,b,2,part);assert(prison and #prison:GetChildren()>1)
br.CFrame=R.CFrame.new(14,3,0);now+=.1;step(.1);local center=prison:GetChildren()[1].CFrame.Position
assert(math.abs(center.X-14)<4,'stone shell detached from actual victim')
b:SetAttribute('BB_Geracao14',2);now+=.01;step(.01);assert(not prison.Parent,'old-generation prison remained')
local rewind=fx.rebobinar(a,{R.Vector3.new(0,3,0),R.Vector3.new(-8,3,0),R.Vector3.new(-10,3,0)})
assert(rewind and #rewind:GetChildren()>1)
a:SetAttribute('BB_Stand','KILLER_QUEEN');now+=.01;step(.01);assert(not rewind.Parent,'swap retained ghost')
print('AJ16 residues real: sanitize/material, original map unchanged, return motion, prison target/gen, rewind cleanup PASS')
