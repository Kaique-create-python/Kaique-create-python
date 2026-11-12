-- AJ14: compositions exclusively from the owner's approved Creator Store packages.
-- Pure data/policy: no services, no generated geometry, no automatic FPS reduction.
local Extra = require(script.Parent.VFXReceitas15)
local R = {}
local E = 'E_Anime_'
local S = 'S_vfxpack_'
local names = {
 E..'Punch_01', E..'Punch_02', E..'Punch_03', E..'Stars_01', E..'Shiny_01',
 E..'Wind_01', E..'Wind_02', E..'Charge_01', E..'ForceField_Break_01', E..'Crack_01',
 E..'Shoot_01', E..'Portal_01', E..'Portal_Enter_01', 'E_Beams_Wind_01', 'E_Big_Explosion_01',
 S..'premade_direction_one', S..'premade_direction_all', S..'premade_speedlines',
 S..'separated_impacts', S..'separated_stars', S..'separated_ring', S..'separated_lines', S..'separated_smoke',
}
R.CORES = {
 STAR_PLATINUM = {Color3.fromRGB(155,92,255),Color3.fromRGB(100,175,255)},
 THE_WORLD = {Color3.fromRGB(255,202,63),Color3.fromRGB(219,115,20)},
}
function R.suporta(id)
 return id=='STAR_PLATINUM' or id=='THE_WORLD' or Extra.suporta(id)
end
function R.templates()
 local result={}; for _,name in names do result[name]=true end; return result
end
for id,palette in Extra.CORES do R.CORES[id]=palette end
function R.catalogos(id)
 local out={BB_VFXCatalogo14=R.templates()}
 if id==nil or Extra.suporta(id)then out.BB_VFXCatalogo15=Extra.templates()end
 return out
end
local function layer(template, mode, scale, duration, extra)
 local result={template=template,mode=mode or 'burst',scale=scale or 1,duration=duration or .12,at=0,axis='front'}
 if extra then for k,v in extra do result[k]=v end end
 return result
end
local function hit(n, strong)
 return {
  layer(E..'Punch_0'..tostring(((n or 1)-1)%3+1),'burst',strong and 1.65 or .85),
  layer(S..'premade_direction_all','burst',strong and .9 or .5),
  layer(E..'Stars_01','burst',strong and 1.2 or .65),
  layer(E..'Wind_01','burst',strong and 1.2 or .55),
 }
end
function R.resolve(stand,move,phase,ctx)
 if Extra.suporta(stand) then return Extra.resolve(stand,move,phase,ctx) end
 if not R.suporta(stand) then return nil end
 if phase~='inicio' and phase~='contato' and phase~='final' and phase~='fim' then return nil end
 ctx=ctx or {}
 local slot=string.match(move or '', '^'..stand..'_(.+)$')
 local known={invocar=true,m1=true,m1_aereo=true,dash=true,bloqueio=true,parry=true,quebra_guarda=true,tempo=true,tempoVolta=true,rolo=true}
 if not known[move] and slot~='1' and slot~='2' and slot~='3' and slot~='4' and slot~='ULT' then return nil end
 if phase=='fim' then return {} end
 local contact=phase=='contato' or phase=='final'
 local strong=phase=='final' or ctx.n==4
 if move=='invocar' then
  if contact then return {} end
  return {layer(E..'Portal_Enter_01','burst',1.2,.3,{axis='ground'}),layer(E..'Charge_01','follow',1,.55,{continuous=true}),layer(E..'Stars_01','burst',.9),layer(E..'Wind_02','follow',.9,.55,{continuous=true})}
 elseif move=='m1' or move=='m1_aereo' then
  if contact then return hit(ctx.n,strong) end
  return {layer(E..'Wind_01','follow',.55,.19,{offset=Vector3.new(.9,.4,-2.4)}),layer(S..'separated_lines','follow',.35,.16,{offset=Vector3.new(.9,.4,-2.4)})}
 elseif move=='dash' then
  if contact then return {} end
  return {layer(S..'premade_speedlines','follow',.95,ctx.dur or .23),layer(S..'separated_smoke','burst',.8,.15,{axis='ground',offset=Vector3.new(0,-2.7,0)})}
 elseif move=='bloqueio' then
  if contact then return {layer(S..'separated_ring','burst',.5),layer(S..'separated_impacts','burst',.4)} end
  return {layer(E..'Shiny_01','follow',.5,ctx.dur or 120,{continuous=true,offset=Vector3.new(0,.3,-2)})}
 elseif move=='parry' then
  return {layer(E..'Stars_01','burst',1.1),layer(E..'Shiny_01','burst',.9),layer(S..'separated_stars','burst',.85)}
 elseif move=='quebra_guarda' then
  return {layer(E..'ForceField_Break_01','burst',1.2),layer(S..'separated_ring','burst',.9),layer(E..'Crack_01','burst',.65,.12,{axis='ground'})}
 elseif move=='tempoVolta' then
  return {layer(E..'Portal_Enter_01','burst',2.2,.25,{axis='ground'}),layer(S..'separated_ring','burst',2.6,.2,{axis='ground'})}
 elseif move=='tempo' or slot=='ULT' then
  if contact then return {layer(E..'Portal_01','burst',2.5,.55,{axis='ground'}),layer(E..'Portal_Enter_01','burst',1.8,.4),layer(S..'separated_ring','burst',3,.2,{axis='ground'})} end
  return {layer(E..'Charge_01','follow',1.4,1.7,{continuous=true,kind='tempo'}),layer(E..'Shiny_01','follow',1.1,1.7,{continuous=true,kind='tempo'})}
 elseif move=='rolo' then
  if not contact then return {layer(E..'Wind_02','follow',2.4,ctx.dur or .8,{continuous=true,axis='ground'})} end
  return {layer('E_Big_Explosion_01','burst',2),layer(E..'Crack_01','burst',2.6,.2,{axis='ground'}),layer(S..'premade_direction_all','burst',2.5),layer(S..'separated_smoke','burst',2.5,.3,{axis='ground'})}
 elseif slot=='1' then
  if contact then return hit(ctx.n,phase=='final') end
  local result={layer(E..'Wind_02','follow',1,4.6,{continuous=true})}
  local start=stand=='STAR_PLATINUM' and .25 or .20
  local index=0
  for t = start,3.7,.12 do
   index+=1
   table.insert(result,layer(E..'Punch_0'..tostring((index-1)%3+1),'follow',.7,.12,{at=t,offset=Vector3.new(index%2==0 and -.85 or .85,.3,-3.1)}))
   table.insert(result,layer(S..'separated_lines','follow',.45,.12,{at=t,offset=Vector3.new(index%2==0 and -.85 or .85,.3,-3.1)}))
  end
  table.insert(result,layer(E..'Charge_01','follow',1.2,.65,{at=3.7,continuous=true,offset=Vector3.new(0,.5,-2.7)}))
  return result
 elseif stand=='STAR_PLATINUM' and slot=='2' then
  if contact then return hit(2,false) end
  return {layer('E_Beams_Wind_01','beam',.65,.32,{at=.28,length=16,axis='beam',continuous=true,offset=Vector3.new(.9,.6,-2.5)})}
 elseif (stand=='STAR_PLATINUM' and slot=='4') or (stand=='THE_WORLD' and slot=='2') then
  if contact then return hit(1,false) end
  if ctx.variant=='antecipacao' then
   return {layer(E..'Charge_01','follow',.45,.22,{continuous=true,offset=Vector3.new(.8,.4,-1.8)})}
  end
  local result={layer(E..'Shoot_01','burst',.85)}
  -- Efeitos.proj sends one confirmed event per actual projectile, already aimed by the server.
  local single=ctx.variant=='projetil'
  local count=single and 1 or (stand=='THE_WORLD' and 5 or 1)
  local duration=single and (ctx.dur or .36) or .36
  for i = 1,count do
   table.insert(result,layer(S..'separated_lines','projectile',.35,duration,{continuous=true,speed=ctx.speed or (stand=='THE_WORLD' and 125 or 165),yaw=count==1 and 0 or (i-3)*4.5,offset=single and Vector3.zero or Vector3.new(0,.3,-2)}))
  end
  return result
 elseif stand=='THE_WORLD' and slot=='3' then
  if contact then return hit(2,false) end
  return {layer(E..'Portal_Enter_01','follow',1.15,.18),layer(S..'premade_speedlines','follow',.8,.28)}
 else -- confirmed heavy / uppercut variants use the same authored layered family
  if contact then
   local result=hit(3,true)
   table.insert(result,layer(E..'ForceField_Break_01','burst',1.1))
   table.insert(result,layer(E..'Crack_01','burst',1,.1,{axis='ground',offset=Vector3.new(0,-2.7,0)}))
   return result
  end
  return {layer(E..'Charge_01','follow',1.1,ctx.dur or .46,{continuous=true,offset=Vector3.new(1,.4,-2)}),layer(S..'premade_direction_one','follow',.65,.25,{offset=Vector3.new(1,.4,-2)})}
 end
end
return R
