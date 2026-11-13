-- AJ14 visual renderer. Clones only vetted store templates; never generates effect geometry.
local Receitas = require(script.Parent.Parent.VFXReceitas)
local RS = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local P = {}
local scopes = {}
local sessions = {}
local seen = setmetatable({}, {__mode='k'})
local anonymous = {}
local folder
local connection
local function now() return workspace:GetServerTimeNow() end
local function finite(value, fallback)
 if type(value)=='number' and value==value and math.abs(value)<math.huge then return value end
 return fallback
end
local function descendants(root)
 local list=root:GetDescendants();table.insert(list,1,root);return list
end
local function rootOf(owner)
 if not owner or not owner.Parent then return nil end
 return owner:FindFirstChild('HumanoidRootPart') or owner:FindFirstChild('Torso')
end
local function frameOf(ctx)
 local root=rootOf(ctx.owner)
 local pos=ctx.pos or (root and root.CFrame.Position) or Vector3.zero
 local dir=ctx.dir or (root and root.CFrame.LookVector) or Vector3.new(0,0,-1)
 if dir.Magnitude<.001 then dir=Vector3.new(0,0,-1) end
 dir=dir.Unit
 local up=math.abs(dir.Y)>.98 and Vector3.new(1,0,0) or Vector3.yAxis
 return CFrame.lookAt(pos,pos+dir,up)
end
local function tintSequence(seq, color, name)
 local core=string.find(string.lower(name),'core') or string.lower(name)=='light'
 local mixed=false
 for _,key in seq.Keypoints do
  local c=key.Value
  if math.max(c.R,c.G,c.B)-math.min(c.R,c.G,c.B)>.12 then mixed=true end
 end
 local result={}
 for _,key in seq.Keypoints do
  local c=key.Value
  local high=math.max(c.R,c.G,c.B);local low=math.min(c.R,c.G,c.B)
  local white=high>.86 and high-low<.1
  local value
  if low<.12 and high<.18 then value=c
  elseif white and (core or mixed) then value=Color3.new(1,1,1)
  else
   local luminance=math.max(.28,c.R*.2126+c.G*.7152+c.B*.0722)
   value=Color3.new(color.R*luminance,color.G*luminance,color.B*luminance)
  end
  table.insert(result,ColorSequenceKeypoint.new(key.Time,value))
 end
 return ColorSequence.new(result)
end
local function numberScale(seq, scale)
 local result={}
 for _,key in seq.Keypoints do table.insert(result,NumberSequenceKeypoint.new(key.Time,key.Value*scale,key.Envelope*scale)) end
 return NumberSequence.new(result)
end
local function actorOf(ctx,moveId,phase)
 local actor=ctx.owner
 local victimEffect=phase=='contato' or phase=='final' or moveId=='parry' or moveId=='quebra_guarda' or moveId=='agarrao' or moveId=='marca' or moveId=='pedra16'
 if victimEffect and typeof(ctx.target)=='Instance' and ctx.target:IsA('Model') then actor=ctx.target end
 if typeof(actor)=='Instance' and actor:IsA('Model') then return actor end
 return nil
end
local function frozen(scope)
 if scope.ctx.projectile then return now()<(scope.projectileAte or 0) end
 if scope.kind=='tempo' then return false end
 local actor=scope.actor
 if not actor or not actor.Parent then return false end
 -- The server owns spatial membership. A running session alone cannot freeze out-of-radius FX.
 local clock=now()
 if finite(actor:GetAttribute('BB_Congelado'),0)<=clock then return false end
 local session=sessions[actor:GetAttribute('BB_SessaoTempo')]
 return session~=nil and session.owner~=actor and session.fim>clock
end
local function stop(scope)
 if scope.cancelled then return end
 scope.cancelled=true;scope.active=false
 for _,item in scope.items do
  for _,pe in item.particles do pe.node.Enabled=false end
  for _,b in item.beams do b.node.Enabled=false end
  for _,t in item.trails do t.Enabled=false end
  item.stoppedAt=scope.elapsed;item.stoppedClock=now()
 end
end
local function positionItem(scope,item)
 local spec=item.spec
 local cf=item.base
 if spec.mode=='follow' or spec.mode=='beam' or spec.mode=='mesh' then
  local root=rootOf(scope.ctx.owner)
  if root then
   -- Follow live R6 orientation while retaining an explicit impact/world position for bursts.
   local dir=item.directionLocal and root.CFrame:VectorToWorldSpace(item.directionLocal) or root.CFrame.LookVector
   local pos=item.anchorLocal and root.CFrame:PointToWorldSpace(item.anchorLocal) or root.CFrame.Position
   cf=frameOf({pos=pos,dir=dir})
  end
 end
 if spec.mode=='target' then
  local target=rootOf(scope.ctx.target)
  if target then cf=frameOf({pos=target.CFrame.Position,dir=scope.ctx.dir}) end
 elseif spec.mode=='sol' and scope.ctx.above and scope.ctx.destination then
  local t=math.clamp((item.age-(scope.ctx.formar or 1.1))/math.max(.01,scope.ctx.cair or .5),0,1)
  cf=CFrame.new(scope.ctx.above:Lerp(scope.ctx.destination,t*t))
 end
 cf=cf*CFrame.Angles(0,math.rad((spec.yaw or 0)+(spec.spin or 0)*item.age),0)
 cf=cf*CFrame.new(spec.offset or Vector3.zero)
 if spec.mode=='projectile' then
  cf=cf*CFrame.new(0,0,-(spec.speed or 125)*math.min(item.age,spec.duration,item.stoppedAt and math.max(0,item.stoppedAt-spec.at) or math.huge))
 end
 if spec.axis=='front' then cf=cf*CFrame.Angles(-math.pi/2,0,0)
 elseif spec.axis=='beam' then cf=cf*CFrame.Angles(math.pi/2,0,0) end
 for _,part in item.parts do part.node.CFrame=cf*part.relative end
end
local function spawnItem(scope,spec,index)
 local catalog=RS:FindFirstChild(string.sub(spec.template,1,2)=='N_' and 'BB_VFXCatalogo15' or 'BB_VFXCatalogo14')
 local template=catalog and catalog:FindFirstChild(spec.template)
 if spec.mode=='target' and not rootOf(scope.ctx.target) then return nil end
 if not template then return nil end -- missing optional assets never block gameplay
 local clone=template:Clone()
 local scale=math.clamp(finite(spec.scale,1),.01,30)
 local all=descendants(clone)
 local pivot=clone:IsA('BasePart') and clone or clone:FindFirstChildWhichIsA('BasePart',true)
 if not pivot then clone:Destroy();return nil end
 local origin=pivot.CFrame
 if spec.fit then
  local extent=.001
  for _,part in all do if part:IsA('BasePart')then extent=math.max(extent,(origin:PointToObjectSpace(part.CFrame.Position)).Magnitude*2+part.Size.Magnitude)end end
  scale=spec.fit/extent
 end
 local item={node=clone,spec=spec,base=frameOf(scope.ctx),parts={},particles={},beams={},trails={},meshes={},lights={},age=0,tail=spec.duration,stoppedAt=nil}
 local ownerRoot=rootOf(scope.ctx.owner)
 if ownerRoot then
  if scope.ctx.pos then item.anchorLocal=ownerRoot.CFrame:PointToObjectSpace(scope.ctx.pos) end
  if scope.ctx.dir and scope.ctx.dir.Magnitude>.001 then item.directionLocal=ownerRoot.CFrame:VectorToObjectSpace(scope.ctx.dir.Unit) end
 end
 local palette=Receitas.CORES[scope.stand]
 local color=palette[(index-1)%#palette+1]
 -- The response has its own identity, independent of the attacker's Stand hue.
 if scope.cue=='bloqueio'then color=Color3.fromRGB(116,185,255)
 elseif scope.cue=='parry'then color=Color3.fromRGB(255,210,91)
 elseif scope.cue=='quebra_guarda'then color=Color3.fromRGB(255,113,73)end
 for _,n in all do
  if n:IsA('BasePart') then
   local relative=origin:ToObjectSpace(n.CFrame)
   relative=CFrame.new(relative.Position*scale)*relative.Rotation
   n.Size=n.Size*scale;n.Anchored=true;n.CanCollide=false;n.CanTouch=false;n.CanQuery=false
   table.insert(item.parts,{node=n,relative=relative})
   if n:GetAttribute('BB_VisibleMesh') then
    n.Color=n.Color:Lerp(color,.4)
    table.insert(item.meshes,{node=n,alpha=n.Transparency,size=n.Size})
   end
  elseif n:IsA('SpecialMesh') then
   n.Scale=n.Scale*scale
  elseif n:IsA('Attachment') then
   n.CFrame=CFrame.new(n.CFrame.Position*scale)*n.CFrame.Rotation
  elseif n:IsA('Light') then
   n.Brightness=math.min(n.Brightness,2.5);n.Range=math.min(n.Range,18)
   table.insert(item.lights,{node=n,enabled=n.Enabled});n.Enabled=false
  elseif n:IsA('ParticleEmitter') then
   n.Enabled=false
   n.Size=numberScale(n.Size,scale)
   n.Speed=NumberRange.new(n.Speed.Min*scale,n.Speed.Max*scale)
   n.Acceleration=n.Acceleration*scale;n.ZOffset*=scale
   n.Color=tintSequence(n.Color,color,n.Name)
   local layerName=string.lower(n.Name)
   if spec.continuous and (string.find(layerName,'core')or string.find(layerName,'light')or string.find(layerName,'flash'))then
    local keys={}
    for _,key in n.Transparency.Keypoints do table.insert(keys,NumberSequenceKeypoint.new(key.Time,.26+.74*key.Value,.74*key.Envelope))end
    n.Transparency=NumberSequence.new(keys)
   end
   local delay=math.max(0,finite(n:GetAttribute('EmitDelay'),0))
   local duration=math.max(0,finite(n:GetAttribute('EmitDuration'),0))
   -- Continuous recipe duration is an absolute end, not an extra span after EmitDelay.
   if spec.continuous then duration=math.max(0,spec.duration-delay) elseif string.sub(spec.template,1,2)=='N_' then duration=math.min(duration,math.max(0,spec.duration-delay))end
   local count=n:GetAttribute('EmitCount')
   if type(count)~='number' then count=math.max(1,math.ceil(n.Rate*.2)) end
   count=math.max(0,math.floor(finite(count,0)))
   local timeScale=n.TimeScale
   local life=n.Lifetime.Max/math.max(timeScale,.01)
   table.insert(item.particles,{node=n,delay=delay,duration=duration,count=count,emitted=false,timeScale=timeScale,life=life,size=n.Size})
   item.tail=math.max(item.tail,delay+duration+life)
  elseif n:IsA('Beam') then
   n.Enabled=false;n.Color=tintSequence(n.Color,color,n.Name)
   n.Width0*=scale;n.Width1*=scale;n.CurveSize0*=scale;n.CurveSize1*=scale
   table.insert(item.beams,{node=n,width0=n.Width0,width1=n.Width1,textureSpeed=n.TextureSpeed})
  elseif n:IsA('Trail') then
   n.Enabled=false;n.Color=tintSequence(n.Color,color,n.Name)
   item.tail=math.max(item.tail,spec.duration+n.Lifetime)
   table.insert(item.trails,n)
  end
 end
 if spec.length then
  for _,b in item.beams do
   local start=b.node.Attachment0;local finish=b.node.Attachment1
   if start and finish then
    -- Authored Wind-01 travels along local -Y, with the original Attachment rotations intact.
    finish.CFrame=CFrame.new(start.CFrame.Position+Vector3.new(0,-spec.length,0))*finish.CFrame.Rotation
   end
  end
 end
 item.age=math.max(0,scope.elapsed-spec.at)
 positionItem(scope,item)
 clone:SetAttribute('BB_VFX14',true)
 clone:SetAttribute('BB_ActionId',scope.ctx.actionId or '')
 clone:SetAttribute('BB_Template',spec.template)
 clone.Parent=folder
 table.insert(scope.items,item)
 return item
end
local function updateItem(scope,item,isFrozen)
 local age=scope.elapsed-item.spec.at
 item.age=age
 local stopped=scope.cancelled or age>=item.spec.duration
 for _,mesh in item.meshes do
  local fade=math.min(item.rebased and 1 or math.clamp(age/.035,0,1),math.clamp((item.spec.duration-age)/.09,0,1))
  if scope.cancelled then fade=math.min(fade,math.clamp(1-(now()-item.stoppedClock)/.09,0,1)) end
  mesh.node.Transparency=1-(1-mesh.alpha)*fade
  mesh.node.Size=mesh.size*(1+((item.spec.expand or 1)-1)*math.clamp(age/item.spec.duration,0,1))
 end
 if not isFrozen then positionItem(scope,item) end
 for _,light in item.lights do light.node.Enabled=light.enabled and not stopped end
 for _,pe in item.particles do
  pe.node.TimeScale=isFrozen and 0 or pe.timeScale
  if item.spec.mode=='sol' then pe.node.Size=numberScale(pe.size,.15+.85*math.clamp(age/(scope.ctx.formar or 1.1),0,1))end
  if not scope.cancelled and age>=pe.delay then
   if not pe.emitted then
    pe.emitted=true
    local withinWindow=not item.spec.continuous or age<item.spec.duration
    if withinWindow and pe.count>0 and age<pe.delay+pe.duration+pe.life then pe.node:Emit(pe.count) end
   end
   pe.node.Enabled=pe.duration>0 and age<pe.delay+pe.duration
  else pe.node.Enabled=false end
 end
 local fade=math.min(math.clamp(age/.055,0,1),math.clamp((item.spec.duration-age)/.09,0,1))
 for _,b in item.beams do
  b.node.Enabled=not stopped
  b.node.TextureSpeed=isFrozen and 0 or b.textureSpeed
  b.node.Width0=b.width0*fade;b.node.Width1=b.width1*fade
 end
 for _,trail in item.trails do trail.Enabled=not stopped and not isFrozen end
 local tail=item.tail
 if item.stoppedAt then
  if #item.meshes>0 and #item.particles==0 and #item.trails==0 then
   if now()-item.stoppedClock>=.09 then item.node:Destroy();return false end
   return true
  end
  tail=0
  for _,pe in item.particles do tail=math.max(tail,item.stoppedAt-item.spec.at+pe.life) end
  for _,trail in item.trails do tail=math.max(tail,item.stoppedAt-item.spec.at+trail.Lifetime) end
 end
 if age>=tail then item.node:Destroy();return false end
 return true
end
local function advance(scope,dt)
 local paused=frozen(scope)
 if not paused then scope.elapsed+=dt end
 local root=rootOf(scope.ctx.owner)
 local actualStand=scope.ctx.owner and scope.ctx.owner:GetAttribute('BB_Stand')
 if scope.ctx.owner and scope.ownerGeneration~=scope.ctx.owner:GetAttribute('BB_Geracao14')then stop(scope)end
 if scope.actor and scope.actorGeneration~=scope.actor:GetAttribute('BB_Geracao14')then stop(scope)end
 if not scope.ctx.preview and not scope.ctx.projectile and actualStand and actualStand~=scope.stand then stop(scope)end
 if scope.ctx.owner and not root then stop(scope) end
 if scope.actor and scope.actor~=scope.ctx.owner then
  local h=scope.actor:FindFirstChildOfClass('Humanoid');if not scope.actor.Parent or h and h.Health<=0 then stop(scope)end
 end
 if scope.ctx.owner then
  local humanoid=scope.ctx.owner:FindFirstChildOfClass('Humanoid')
  if humanoid and humanoid.Health<=0 then stop(scope) end
 end
 if not scope.cancelled then
  for index,spec in scope.recipe do
   if not scope.started[index] and scope.elapsed>=spec.at then
    scope.started[index]=true
    if scope.elapsed<spec.at+spec.duration+10 then spawnItem(scope,spec,index) end
   end
  end
 end
 for i = #scope.items,1,-1 do
  if not updateItem(scope,scope.items[i],paused) then table.remove(scope.items,i) end
 end
 if scope.elapsed>=scope.duration then scope.active=false end
 return scope.active or #scope.items>0
end
function P.suporta(standId) return Receitas.suporta(standId) end
function P.iniciar()
 if connection then return end
 folder=workspace:FindFirstChild('BB_VFXPiloto14')
 if not folder then folder=Instance.new('Folder');folder.Name='BB_VFXPiloto14';folder.Parent=workspace end
 connection=RunService.Heartbeat:Connect(function(dt)
  local clock=now()
  for id,session in sessions do if clock>=session.fim then sessions[id]=nil end end
  for owner,keys in seen do
   for key,expiry in keys do if expiry<=clock then keys[key]=nil end end
   if next(keys)==nil then seen[owner]=nil end
  end
  for i = #scopes,1,-1 do if not advance(scopes[i],dt) then table.remove(scopes,i) end end
 end)
end
function P.tocar(standId,moveId,phase,ctx)
 if not P.suporta(standId) then return nil end
 ctx=ctx or {}
 if phase=='fim' then P.cancelar(ctx.owner,ctx.actionId);return nil end
 local recipe=Receitas.resolve(standId,moveId,phase,ctx)
 if not recipe then return nil end
 P.iniciar()
 local key
 if ctx.hitId then key='hit:'..tostring(ctx.hitId)..':'..phase
 elseif ctx.actionId then key='action:'..tostring(ctx.actionId)..':'..moveId..':'..phase end
 if key then
  local owner=ctx.owner or anonymous
  seen[owner]=seen[owner] or {}
  if seen[owner][key] then return nil end
  seen[owner][key]=now()+150
 end
 local copy={};for k,v in ctx do copy[k]=v end
 if copy.variant=="projetil" then copy.projectile=true end
 if not copy.pos and (phase=='contato' or phase=='final') then
  local targetRoot=rootOf(copy.target)
  if targetRoot then copy.pos=targetRoot.CFrame.Position end
 end
 local scope={ctx=copy,actor=actorOf(copy,moveId,phase),stand=standId,cue=moveId,recipe=recipe,started={},items={},elapsed=math.max(0,now()-finite(ctx.t,now())),active=true,cancelled=false,duration=0,kind=moveId=='tempo' and 'tempo' or nil}
 scope.ownerGeneration=copy.owner and copy.owner:GetAttribute('BB_Geracao14')
 scope.actorGeneration=scope.actor and scope.actor:GetAttribute('BB_Geracao14')
 for _,spec in recipe do
  spec.duration=math.clamp(finite(spec.duration,.12),.01,120)
  scope.duration=math.max(scope.duration,spec.at+spec.duration)
  if spec.kind=='tempo' then scope.kind='tempo' end
 end
 table.insert(scopes,scope)
 advance(scope,0)
 return scope
end
-- Authoritative projectile anchors; unlike actor effects these follow server pause state.
function P.estadoProjetil(owner,actionId,d)
 for _,scope in scopes do
  if scope.ctx.owner==owner and scope.ctx.actionId==actionId and not scope.cancelled then
   scope.projectileAte=d.ate or 0
   scope.ctx.pos=d.pos;scope.ctx.dir=d.dir
   local previous=scope.elapsed
   scope.active=true;scope.elapsed=0;scope.duration=math.max(.01,(d.resta or 1)/math.max(1,d.vel or 125))
   for _,spec in scope.recipe do if spec.mode=="projectile"then spec.duration=scope.duration else spec.at-=previous end end
   for _,item in scope.items do
    if item.spec.mode=="projectile"then
    item.age=0;item.base=frameOf(scope.ctx);item.rebased=true;item.tail=scope.duration
    for _,pe in item.particles do
     if item.spec.continuous then pe.duration=math.max(0,scope.duration-pe.delay)end
     item.tail=math.max(item.tail,pe.duration+pe.delay+pe.life)
    end
    positionItem(scope,item);updateItem(scope,item,frozen(scope))
    end
   end
  end
 end
end
function P.cancelar(owner,actionId)
 for _,scope in scopes do
  if (not owner or scope.ctx.owner==owner) and (not actionId or scope.ctx.actionId==actionId) then stop(scope) end
 end
end
function P.congelar(sessionId,owner,fim)
 if sessionId==nil then return end
 P.iniciar()
 sessions[sessionId]={owner=owner,fim=finite(fim,now())}
 for _,scope in scopes do for _,item in scope.items do updateItem(scope,item,frozen(scope)) end end
end
function P.descongelar(sessionId)
 sessions[sessionId]=nil
 for _,scope in scopes do for _,item in scope.items do updateItem(scope,item,frozen(scope)) end end
end
return P
