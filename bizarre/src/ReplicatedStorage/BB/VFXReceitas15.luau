-- Only authored assets from the owner's ZIP. Timing follows Golpes unchanged.
local R={CORES={SILVER_CHARIOT={Color3.fromRGB(222,239,255),Color3.fromRGB(142,177,212)},MAGICIANS_RED={Color3.fromRGB(255,108,27),Color3.fromRGB(255,207,92)}}}
local names={'Fire_01','Fire_02','Fire_03','Flamethrower_01','Fire_Slash_01','Slash_01','Slashes_01','Slash_Impact_01','Realistic_Explosion_01','Smoke_01','Fire_Aura_01','Mesh_Slash','Mesh_Wide','Mesh_Arc'}
function R.suporta(id)return id=='SILVER_CHARIOT' or id=='MAGICIANS_RED'end
function R.templates()local set={}for _,n in names do set['N_'..n]=true end return set end
local function L(name,mode,duration,extra)
 local x={template='N_'..name,mode=mode or 'burst',scale=1,duration=duration or .2,at=0,axis='front'}
 for k,v in extra or {}do x[k]=v end return x
end
local function slash(n,strong)
 return {L('Slash_Impact_01','burst',.18,{scale=strong and 1.1 or .6}),L('Mesh_Slash','mesh',.19,{fit=strong and 8 or 5,yaw=(n or 1)%2==0 and -20 or 20,axis='mesh',expand=1.15})}
end
local function flame(strong)
 return {L(strong and 'Realistic_Explosion_01' or 'Fire_03','burst',.22,{scale=strong and 1.4 or .65}),L('Smoke_01','burst',.3,{scale=strong and 1.1 or .45})}
end
function R.resolve(id,move,phase,c)
 if not R.suporta(id)then return nil end
 c=c or {};if phase=='fim'then return {}end
 local silver=id=='SILVER_CHARIOT'
 local slot=(move or ''):match('^'..id..'_(.+)$')
 local hit=phase=='contato' or phase=='final'
 if move=='invocar'then return {L(silver and 'Slashes_01' or 'Fire_Aura_01','follow',.5,{continuous=true,scale=.7})}
 elseif move=='m1'or move=='m1_aereo'then
  if hit then return silver and slash(c.n,c.n==4)or flame(c.n==4)end
  return {L(silver and 'Mesh_Wide' or 'Fire_Slash_01',silver and 'mesh' or 'follow',.18,{fit=5,axis=silver and 'mesh' or 'front',offset=Vector3.new(.9,.4,-2.6)})}
 elseif move=='dash'then return {L(silver and 'Slashes_01' or 'Fire_02','follow',c.dur or .23,{continuous=true,scale=.6})}
 elseif move=='bloqueio'then
  return hit and(silver and slash(1,false)or flame(false))or{L(silver and 'Slashes_01' or 'Fire_01','follow',c.dur or 120,{continuous=true,scale=.45,offset=Vector3.new(0,.6,-2)})}
 elseif move=='parry'or move=='quebra_guarda'then return silver and slash(2,true)or flame(true)
 elseif move=='buff'then return {L('Slashes_01','follow',math.min(c.dur or 8,8),{continuous=true,scale=.45})}
 elseif move=='contra'then return slash(1,true)
 elseif move=='agarrao'then return {L('Fire_01','target',c.dur or 1.6,{continuous=true,scale=.7})}
 elseif move=='sol'then
  if hit then return flame(true)end
  return {L('Fire_Aura_01','sol',1.6,{continuous=true,scale=2.5}),L('Smoke_01','sol',1.6,{continuous=true,scale=1.3})}
 elseif move=='teleporte'then return slash(2,false)
 elseif not slot then return nil end
 if hit then return silver and slash(c.n,phase=='final' or slot=='ULT')or flame(phase=='final' or slot=='ULT')end
 if silver then
  if slot=='1' then
   local out={L('Slashes_01','follow',1.25,{continuous=true,scale=.6})}
   for t=.15,.95,.08 do table.insert(out,L('Mesh_Slash','mesh',.13,{at=t,fit=6,axis='mesh',yaw=(math.floor(t/.08)%2==0)and -10 or 10,offset=Vector3.new(0,.5,-3)}))end
   table.insert(out,L('Mesh_Wide','mesh',.23,{at=1.02,fit=10,axis='mesh'}));return out
  elseif slot=='2'then
   if c.variant=='antecipacao'then return {L('Slash_01','follow',.22,{scale=.45})}end
   return {L('Mesh_Wide','projectile',c.dur or .66,{fit=3,axis='mesh',speed=c.speed or 150}),L('Slash_01','projectile',c.dur or .66,{scale=.45,speed=c.speed or 150})}
  elseif slot=='3'then return {L('Mesh_Arc','mesh',1.1,{fit=7,axis='mesh',spin=720}),L('Slashes_01','follow',1.1,{continuous=true,scale=.5})}
  elseif slot=='4'then return {L('Slashes_01','follow',.6,{continuous=true}),L('Mesh_Arc','mesh',.4,{fit=8,axis='mesh',expand=1.5})}
  elseif slot=='ULT'then return {L('Slashes_01','follow',2.6,{continuous=true,scale=1.2}),L('Mesh_Arc','mesh',.45,{fit=10,axis='mesh',spin=540})}end
 else
  if slot=='1'then
   if c.variant=='antecipacao'then return {L('Fire_02','follow',.3,{continuous=true,scale=.55,offset=Vector3.new(0,1,-2)})}end
   return {L('Fire_01','projectile',c.dur or 1.3,{continuous=true,speed=c.speed or 84}),L('Smoke_01','projectile',c.dur or 1.3,{continuous=true,scale=.6,speed=c.speed or 84})}
  elseif slot=='2'then return {L('Fire_Slash_01','follow',.35,{at=.18,continuous=true,scale=.9,offset=Vector3.new(0,.5,-6)})}
  elseif slot=='3'then return {L('Flamethrower_01','follow',1.15,{at=.15,continuous=true,scale=1.4,offset=Vector3.new(0,1,-2)})}
  elseif slot=='4'then return {L('Fire_01','burst',.3,{at=.2,scale=1.1,axis='ground',offset=Vector3.new(0,-2,-12)}),L('Realistic_Explosion_01','burst',.3,{at=.5,scale=1.2,axis='ground',offset=Vector3.new(0,-2,-12)})}
  elseif slot=='ULT'then return {L('Fire_02','follow',.9,{continuous=true,scale=.8})}end
 end
 return nil
end
return R
