-- Cosmetic copies of real map/avatar parts. Originals and physics are never edited.
local RunService=game:GetService("RunService")
local R={}
local active={}
local connection=nil
local folder=nil
local allowed={SpecialMesh=true,Decal=true,Texture=true,SurfaceAppearance=true}
function R.copiar(part)
 if not part or not part:IsA("BasePart")then return nil end
 local clone=part:Clone();if not clone then return nil end
 for _,child in clone:GetDescendants()do if not allowed[child.ClassName]then child:Destroy()end end
 clone.Anchored=true;clone.CanCollide=false;clone.CanTouch=false;clone.CanQuery=false;clone.CastShadow=false
 clone.LocalTransparencyModifier=0
 return clone
end
local function snapshot(owner)
 return owner and{model=owner,stand=owner:GetAttribute("BB_Stand"),generation=owner:GetAttribute("BB_Geracao14")}
end
local function alive(ref)
 if not ref then return true end
 local h=ref.model:FindFirstChildOfClass("Humanoid")
 return ref.model.Parent~=nil and h~=nil and h.Health>0 and ref.model:GetAttribute("BB_Stand")==ref.stand and ref.model:GetAttribute("BB_Geracao14")==ref.generation
end
local function root(model)return model and model:FindFirstChild("HumanoidRootPart")end
local function erase(i)active[i].node:Destroy();table.remove(active,i)end
function R.cancelar(owner)
 for i=#active,1,-1 do if not owner or active[i].owner and active[i].owner.model==owner then erase(i)end end
end
local function group(owner,target,dur,kind)
 if not root(owner)then return nil end
 if not folder or not folder.Parent then folder=Instance.new("Folder");folder.Name="BB_Residuos16";folder.Parent=workspace end
 local node=Instance.new("Folder");node.Name=kind;node.Parent=folder
 local entry={node=node,owner=snapshot(owner),target=snapshot(target),duration=dur,t=workspace:GetServerTimeNow(),kind=kind,items={}}
 table.insert(active,entry)
 if not connection then connection=RunService.Heartbeat:Connect(function()
  local now=workspace:GetServerTimeNow()
  for i=#active,1,-1 do
   local g=active[i];local k=(now-g.t)/g.duration
   local ended=g.held and g.target and math.max(g.target.model:GetAttribute("BB_Pedra")or 0,g.target.model:GetAttribute("BB_Preso")or 0)<=now
   if k>=1 or not alive(g.owner)or not alive(g.target)or ended then erase(i)
   else
    for _,item in g.items do
     if g.kind=="stone"then
      local r=root(g.target.model);if r then item.node.CFrame=r.CFrame*item.offset end
      item.node.Transparency=item.alpha+(1-item.alpha)*math.clamp((k-.8)/.2,0,1)
     elseif g.kind=="restore"then
      local f=1-(1-k)^3;item.node.CFrame=item.from:Lerp(item.to,f);item.node.Transparency=.35+.65*k
     else item.node.Transparency=item.alpha+(1-item.alpha)*k end
    end
   end
  end
 end)end
 return entry
end
function R.restaurar(owner,parts)
 local g=group(owner,nil,.48,"restore");if not g then return nil end
 for i,part in parts or{}do
  if i>24 then break end
  local clone=R.copiar(part)
  if clone then
   local goal=part.CFrame
   local from=goal*CFrame.new(math.sin(i*2.4)*2,2.5+math.cos(i)*.5,math.cos(i*2.4)*2)*CFrame.Angles(.6,.9,.3)
   clone.CFrame=from;clone.Transparency=.35;clone.Parent=g.node
   table.insert(g.items,{node=clone,from=from,to=goal})
  end
 end
 return g.node
end
function R.pedra(owner,target,dur,source)
 if not source or not source:IsA("BasePart")or not root(target)then return nil end
 local g=group(owner,target,dur,"stone");if not g then return nil end
 g.held=math.max(target:GetAttribute("BB_Pedra")or 0,target:GetAttribute("BB_Preso")or 0)>workspace:GetServerTimeNow()
 for i=1,5 do
  local clone=R.copiar(source)
  if clone then
   local angle=(i-1)*math.pi*2/5;local offset=CFrame.Angles(0,angle,0)*CFrame.new(0,-.6,-1.65)
   clone.Size=Vector3.new(2.2,4.4,.85);clone.CFrame=root(target).CFrame*offset;clone.Transparency=.16;clone.Parent=g.node
   table.insert(g.items,{node=clone,offset=offset,alpha=.16})
  end
 end
 return g.node
end
function R.rebobinar(owner,path)
 local r=root(owner);if not r then return nil end
 local g=group(owner,nil,.5,"rewind");if not g then return nil end
 local count=math.min(#path,6)
 for i=1,count do
  local index=math.max(1,math.floor(1+(#path-1)*(i-1)/math.max(1,count-1)))
  local offset=path[index]-r.CFrame.Position
  for _,part in owner:GetDescendants()do
   if part:IsA("BasePart")and part~=r and part.Transparency<1 then
    local clone=R.copiar(part)
    if clone then
     clone.CFrame=part.CFrame+offset;clone.Transparency=.62;clone.Color=clone.Color:Lerp(Color3.fromRGB(228,144,219),.2);clone.Parent=g.node
     table.insert(g.items,{node=clone,alpha=.62})
    end
   end
  end
 end
 return g.node
end
return R
