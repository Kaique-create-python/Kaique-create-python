-- Silhouettes cloned from the actual equipped Stand; no external model code.
local RunService=game:GetService('RunService')
local R={};local active={}
local connection = nil
local folder = nil
local visuals={SpecialMesh=true,Decal=true,Texture=true,SurfaceAppearance=true}
local function erase(i)local g=active[i];g.node:Destroy();table.remove(active,i)end
function R.limpar(owner)
 for i=#active,1,-1 do if not owner or active[i].owner==owner then erase(i)end end
end
function R.tocar(owner,stand,pos,dur)
 if not owner or not owner.Parent or not stand or not stand.Parent then return nil end
 local root=owner:FindFirstChild('HumanoidRootPart');local hum=owner:FindFirstChildOfClass('Humanoid')
 if not root or not hum or hum.Health<=0 then return nil end
 if not folder or not folder.Parent then folder=Instance.new('Folder');folder.Name='BB_Rastros15';folder.Parent=workspace end
 local group=Instance.new('Folder');group.Name='SilverAfterimage'
 local offset=pos and (pos-root.CFrame.Position)or Vector3.zero
 local items={}
 for _,part in stand:GetDescendants()do
  if part:IsA('BasePart')and part.Name~='HumanoidRootPart' and part.Transparency<1 then
   local clone=part:Clone()
   for _,n in clone:GetDescendants()do if not visuals[n.ClassName]then n:Destroy()end end
   clone.CFrame=clone.CFrame+offset;clone.Anchored=true;clone.CanCollide=false;clone.CanTouch=false;clone.CanQuery=false;clone.CastShadow=false
   clone.LocalTransparencyModifier=0;clone.Transparency=math.max(.55,clone.Transparency);clone.Color=clone.Color:Lerp(Color3.fromRGB(208,232,255),.45)
   table.insert(items,{node=clone,alpha=clone.Transparency});clone.Parent=group
  end
 end
 if #items==0 then group:Destroy();return nil end
 group.Parent=folder
 table.insert(active,{node=group,owner=owner,items=items,t=workspace:GetServerTimeNow(),duration=dur or .25})
 if not connection then connection=RunService.Heartbeat:Connect(function()
  local now=workspace:GetServerTimeNow()
  for i=#active,1,-1 do
   local g=active[i];local h=g.owner:FindFirstChildOfClass('Humanoid');local k=(now-g.t)/g.duration
   if k>=1 or not g.owner.Parent or not h or h.Health<=0 or g.owner:GetAttribute('BB_Stand')~='SILVER_CHARIOT'then erase(i)
   else for _,item in g.items do item.node.Transparency=item.alpha+(1-item.alpha)*k end end
  end
 end)end
 return group
end
return R
