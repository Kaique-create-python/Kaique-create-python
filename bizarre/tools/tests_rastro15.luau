local H=require('./harness');local R=require('@lune/roblox')
local step;local now=100
local world=R.Instance.new('Workspace')
R.implementMethod('Workspace','GetServerTimeNow',function()return now end)
H.extras.workspace=world;H.servicos.RunService.Heartbeat={Connect=function(_,f)step=f;return{Disconnect=function()end}end}
local owner=R.Instance.new('Model');owner.Parent=world;owner:SetAttribute('BB_Stand','SILVER_CHARIOT')
local h=R.Instance.new('Humanoid');h.Health=100;h.Parent=owner
local root=R.Instance.new('Part');root.Name='HumanoidRootPart';root.Parent=owner;root.CFrame=R.CFrame.new(10,3,0)
local stand=R.Instance.new('Model');stand.Parent=world
local arm=R.Instance.new('Part');arm.Name='Right Arm';arm.CFrame=R.CFrame.new(9,4,0);arm.Parent=stand
local unsafe=R.Instance.new('Script');unsafe.Parent=arm
local Trail=H.modulo('ReplicatedStorage/BB/Cliente/RastroStand15')
local ghost=Trail.tocar(owner,stand,R.Vector3.new(0,3,0),.25)
assert(ghost and #ghost:GetChildren()==1)
local clone=ghost:GetChildren()[1]
assert(clone.CFrame.Position==R.Vector3.new(-1,4,0))
for _,n in ghost:GetDescendants()do assert(not n:IsA('LuaSourceContainer') and not n:IsA('Humanoid'))end
assert(clone.Anchored and not clone.CanCollide and not clone.CanTouch and not clone.CanQuery)
now+=.1;step();assert(clone.Transparency>.55)
now+=.2;step();assert(not ghost.Parent)
local second=Trail.tocar(owner,stand,nil,.25);owner:SetAttribute('BB_Stand','MAGICIANS_RED');step();assert(not second.Parent)
print('AJ15 afterimage actual Stand clone: sanitize/offset/fade/TTL/stand swap PASS')
