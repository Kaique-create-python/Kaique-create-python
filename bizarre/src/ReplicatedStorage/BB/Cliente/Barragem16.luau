-- Residual fists copied from the equipped Stand. This module has no combat/audio/camera API.
local RunService=game:GetService("RunService")
local Copies=require(script.Parent.Residuos16)
local B={}
local groups={}
local current=setmetatable({}, {__mode="k"})
local connection=nil
local folder=nil
local function root(model)return model and model:FindFirstChild("HumanoidRootPart")end
local function finish(g)
 g.active=false
 if current[g.owner]==g then current[g.owner]=nil end
end
function B.cancelar(owner,expected)
 if expected then if expected.owner==owner then finish(expected)end;return end
 local g=current[owner]
 if g then finish(g)end
end
local function sources(stand,arm)
 local list={{part=arm,relative=CFrame.identity}}
 for _,node in stand:GetDescendants()do
  if node:IsA("Weld")and(node.Part1==arm or node.Part0==arm)then
   local part=node.Part0==arm and node.Part1 or node.Part0
   if part and part:IsA("BasePart")and part~=arm and part.Name=="Handle"then
    table.insert(list,{part=part,relative=arm.CFrame:ToObjectSpace(part.CFrame)})
   end
  end
 end
 return list
end
local function emit(g)
 local sr=root(g.stand);if not sr then return end
 local base=g.base or sr.CFrame
 for side=1,2 do
  local arm=g.stand:FindFirstChild(side==1 and"Left Arm"or"Right Arm")
  if arm and arm:IsA("BasePart")then
   g.count+=1
   local x=(side==1 and-.8 or .8)+math.sin(g.count*2.4)*.35
   local y=.3+math.cos(g.count*1.7)*.65
   local pos=base:PointToWorldSpace(Vector3.new(x,y,-4.5))
   local goal=CFrame.lookAt(pos,pos+base.LookVector)*CFrame.Angles(math.pi/2,0,0)
   local pieces={}
   for _,source in sources(g.stand,arm)do
    local copy=Copies.copiar(source.part)
    if copy then
     copy.CFrame=base*sr.CFrame:ToObjectSpace(source.part.CFrame);copy.Transparency=math.max(.32,copy.Transparency)
     copy.Color=copy.Color:Lerp(Color3.new(1,1,1),.12);copy.Parent=g.node
     table.insert(pieces,{node=copy,relative=source.relative,alpha=copy.Transparency})
    end
   end
   table.insert(g.ghosts,{pieces=pieces,from=base*sr.CFrame:ToObjectSpace(arm.CFrame),to=goal,age=0})
  end
 end
end
local function step(dt)
 local now=workspace:GetServerTimeNow()
 for i=#groups,1,-1 do
  local g=groups[i];local h=g.owner:FindFirstChildOfClass("Humanoid")
  local invalid=not g.owner.Parent or not g.stand.Parent or not h or h.Health<=0
   or g.owner:GetAttribute("BB_Geracao14")~=g.generation
   or(not g.preview and g.owner:GetAttribute("BB_Stand")~=g.id)
  if invalid then
   finish(g);g.node:Destroy();table.remove(groups,i)
  else
   if g.ativo and not g.ativo()then finish(g)end
   local paused=not g.preview and(g.owner:GetAttribute("BB_Congelado")or 0)>now
   local span=math.max(0,now-g.last);g.last=now
   local delta=paused and g.active and 0 or span
   g.elapsed+=delta
   if g.elapsed>=g.duration then finish(g)end
   for j=#g.ghosts,1,-1 do
    local ghost=g.ghosts[j];ghost.age+=delta
    local k=math.clamp(ghost.age/.14,0,1)
    if k>=1 then
     for _,item in ghost.pieces do item.node:Destroy()end
     table.remove(g.ghosts,j)
    else
     local cf=ghost.from:Lerp(ghost.to,1-(1-k)^2)
     for _,item in ghost.pieces do item.node.CFrame=cf*item.relative;item.node.Transparency=item.alpha+(1-item.alpha)*k end
    end
   end
   if g.active and not paused then
    g.accumulator+=delta
    local n=math.min(2,math.floor(g.accumulator/.0416667))
    if n>0 then g.accumulator%=.0416667;for _=1,n do emit(g)end end
   end
   if not g.active and #g.ghosts==0 then g.node:Destroy();table.remove(groups,i)end
  end
 end
end
function B.tocar(owner,stand,dur,ativo,options)
 if not root(owner)or not root(stand)or not owner.Parent or not stand.Parent then return nil end
 if not(options and options.preview)then B.cancelar(owner)end
 if not folder or not folder.Parent then folder=Instance.new("Folder");folder.Name="BB_Barragens16";folder.Parent=workspace end
 local node=Instance.new("Folder");node.Name="ResidualArms";node.Parent=folder
 local g={owner=owner,stand=stand,node=node,duration=dur,ativo=ativo,preview=options and options.preview,base=options and options.base,id=owner:GetAttribute("BB_Stand"),generation=owner:GetAttribute("BB_Geracao14"),elapsed=0,last=workspace:GetServerTimeNow(),accumulator=0,count=0,ghosts={},active=true}
 if not g.preview then current[owner]=g end;table.insert(groups,g)
 if not connection then connection=RunService.Heartbeat:Connect(step)end
 return g
end
return B
