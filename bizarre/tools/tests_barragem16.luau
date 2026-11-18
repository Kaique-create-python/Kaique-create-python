local H=require('./harness');local R=require('@lune/roblox')
local world=R.Instance.new('Workspace');local now=100;local step
R.implementMethod('Workspace','GetServerTimeNow',function()return now end)
H.extras.workspace=world;H.servicos.RunService.Heartbeat={Connect=function(_,fn)step=fn;return{Disconnect=function()end}end}
local owner=R.Instance.new('Model');owner.Parent=world;owner:SetAttribute('BB_Stand','STAR_PLATINUM');owner:SetAttribute('BB_Geracao14',1)
local hum=R.Instance.new('Humanoid');hum.Health=100;hum.Parent=owner
local root=R.Instance.new('Part');root.Name='HumanoidRootPart';root.Parent=owner;root.CFrame=R.CFrame.new(0,3,0)
local stand=R.Instance.new('Model');stand.Parent=world
local sr=R.Instance.new('Part');sr.Name='HumanoidRootPart';sr.CFrame=R.CFrame.new(0,3,-3);sr.Parent=stand
for i,name in {'Left Arm','Right Arm'}do
 local arm=R.Instance.new('Part');arm.Name=name;arm.Color=R.Color3.fromRGB(139,84,205);arm.Size=R.Vector3.new(1,2,1);arm.CFrame=sr.CFrame*R.CFrame.new(i==1 and-1.5 or 1.5,0,0);arm.Parent=stand
 local mesh=R.Instance.new('SpecialMesh');mesh.Parent=arm
 local unsafe=R.Instance.new('Script');unsafe.Parent=arm
end
local B=H.modulo('ReplicatedStorage/BB/Cliente/Barragem16')
local function tick(dt)now+=dt;step(dt)end
local h=B.tocar(owner,stand,1,function()return true end)
assert(h and h.node);tick(.045)
local parts={}
for _,part in h.node:GetDescendants()do
 assert(not part:IsA('LuaSourceContainer')and not part:IsA('Humanoid'))
 if part:IsA('BasePart')then table.insert(parts,part);assert(part.Anchored and not part.CanCollide and not part.CanQuery);assert(part:FindFirstChildOfClass('SpecialMesh'),'real arm visual missing')end
end
assert(#parts>=2,'missing real residual arms')
local arm=parts[1];local from=arm.CFrame.Position;tick(.04)
assert((arm.CFrame.Position-from):Dot(sr.CFrame.LookVector)>0,'punch travelled backward')
owner:SetAttribute('BB_Congelado',now+2);local held=arm.CFrame;tick(.2);assert(arm.CFrame==held,'time stop moved residual arms')
owner:SetAttribute('BB_Congelado',nil);tick(.02);assert(arm.CFrame~=held,'residual failed to resume')
local newer=B.tocar(owner,stand,1,function()return true end);B.cancelar(owner,h);tick(.045)
assert(newer.active,'old cancellation killed newer barrage')
local preview=B.tocar(owner,stand,1,nil,{preview=true,base=R.CFrame.new(0,3,-12)})
assert(newer.active,'preview cancelled live combat barrage')
B.cancelar(owner,preview);assert(newer.active,'stopping preview cancelled live barrage')
owner:SetAttribute('BB_Geracao14',2);tick(.15);assert(not newer.node.Parent,'generation change retained arm copies')
local P=H.modulo('ReplicatedStorage/BB/Poses')
for _,id in {'STAR_PLATINUM','THE_WORLD'}do
 local name=P.clipe15(id,'barragem');assert(name~='barragem' and P.C[name],'video choreography missing '..id)
 local left=P.aj16Proc(P.C[name].proc,.27);local right=P.aj16Proc(P.C[name].proc,.35)
 assert(left and right and left.RS[1]~=right.RS[1]and left.LS[1]~=right.LS[1],'arms do not alternate')
 for _,pose in {left,right}do for _,v in pose do for _,n in v do assert(n==n and math.abs(n)<1000)end end end
end
print('AJ16 barrage real: own R6 arms/mesh, forward trajectory, freeze/resume, generation/stale cancel, alternating poses PASS')
