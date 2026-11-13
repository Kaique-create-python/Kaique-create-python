-- CD/KQ choreography reuses the owner's incorporated catalogs; no asset scripts.
local R={CORES={CRAZY_DIAMOND={Color3.fromRGB(255,143,207),Color3.fromRGB(137,224,255)},KILLER_QUEEN={Color3.fromRGB(228,144,219),Color3.fromRGB(255,223,158)}}}
local E="E_Anime_"
local S="S_vfxpack_"
local function L(name,mode,dur,scale,extra)
 local x={template=name,mode=mode or"burst",duration=dur or .2,scale=scale or 1,at=0,axis="front"}
 for k,v in extra or{}do x[k]=v end
 return x
end
function R.suporta(id)return id=="CRAZY_DIAMOND"or id=="KILLER_QUEEN"end
-- AJ18: impacto primeiro; o brilho do kit entra 0,04 s depois (camadas em degraus)
local function impacto(strong,diamond)
 return {L(S..(strong and"premade_direction_all"or"separated_impacts"),nil,.22,strong and 1.1 or .6),L(E..(diamond and"Stars_01"or"Shiny_01"),nil,.16,strong and 1.3 or .55,{at=.04})}
end
function R.resolve(id,move,phase,c)
 if not R.suporta(id)then return nil end
 c=c or{};if phase=="fim"then return{}end
 local diamond=id=="CRAZY_DIAMOND";local slot=(move or""):match("^"..id.."_(.+)$")
 local hit=phase=="contato"or phase=="final"
 if move=="marca"or move=="pedra16"or move=="agarrao"then
  local mode=c.pos and not c.target and"burst"or"target"
  return {L(E..(diamond and"Crack_01"or"Shiny_01"),mode,c.dur or 1.2,.55,{continuous=true}),L(S.."separated_lines",mode,c.dur or 1.2,.4,{continuous=true})}
 elseif move=="reconstruir"then
  return {L(E.."Charge_01",nil,.4,c.ult and 2 or .9),L(E.."Stars_01",nil,.35,c.ult and 1.5 or .7),L(S.."separated_smoke",nil,.35,.65,{axis="ground"})}
 elseif move=="rebobinar"then
  return {L(E.."Charge_01","follow",c.dur or .7,1.1,{continuous=true}),L(S.."separated_ring","follow",c.dur or .7,.8,{continuous=true})}
 elseif move=="rebobinarFim"then
  return {L(E.."Portal_Enter_01",nil,.35,1.3),L(S.."separated_lines",nil,.3,1.3)}
 elseif move=="explosao"then
  return {L("E_Big_Explosion_01",nil,.22,math.clamp((c.radius or 9)/12,.4,1.2)),L(S.."separated_smoke",nil,.3,.9),L(S.."separated_ring",nil,.15,1.1)}
 elseif move=="invocar"then
  return {L(E.."Portal_Enter_01",nil,.5,.9),L(E.."Shiny_01","follow",.6,.55,{continuous=true})}
 elseif move=="m1"or move=="m1_aereo"then
  if hit then return impacto(c.n==4,diamond)end
  return {L(E.."Wind_01","follow",.17,.55,{offset=Vector3.new(c.n and c.n%2==0 and -.7 or .7,.6,-2.5)}),L(S.."separated_lines","follow",.17,.35)}
 elseif move=="dash"then return {L(S.."premade_speedlines","follow",c.dur or .23,.9),L(S.."separated_smoke",nil,.17,.6,{axis="ground"})}
 elseif move=="bloqueio"then
  if hit then return impacto(false,diamond)end
  return {L(E.."Shiny_01","follow",c.dur or 120,.4,{continuous=true,offset=Vector3.new(0,.5,-2)})}
 elseif move=="parry"or move=="quebra_guarda"then return impacto(true,diamond)
 elseif not slot then return nil end
 if hit then return impacto(phase=="final"or slot=="ULT",diamond)end
 if diamond then
  if slot=="1"then
   local list={L(E.."Wind_02","follow",1.7,.85,{continuous=true})}
   for t=.18,1.45,.085 do table.insert(list,L(E.."Punch_01","follow",.085,.6,{at=t,offset=Vector3.new(math.floor(t/.085)%2==0 and -.8 or .8,.5,-3)}))end
   return list
  elseif slot=="2"then
   if c.variant=="projetil"then return {L(E.."Shoot_01","projectile",c.dur or .71,.45,{speed=c.speed or 112}),L(S.."separated_lines","projectile",c.dur or .71,.3,{speed=c.speed or 112,continuous=true})}end
   return {L(E.."Charge_01","follow",.28,.75,{continuous=true,offset=Vector3.new(0,.5,-2.7)})}
  elseif slot=="3"then return {L(E.."Charge_01","follow",.5,.8,{continuous=true}),L(E.."Stars_01","follow",.4,.5,{at=.1})}
  elseif slot=="4"then return {L(E.."Wind_01","follow",.22,.7,{offset=Vector3.new(.8,.5,-2.5)})}
  elseif slot=="ULT"then return {L(E.."Charge_01","follow",.9,1.4,{continuous=true}),L(E.."Stars_01","follow",.7,1)}end
 else
  if slot=="1"or slot=="4"then return {L(E.."Shiny_01","follow",.25,.5,{offset=Vector3.new(.8,.7,-2.7)}),L(S.."separated_lines","follow",.2,.5)}
  elseif slot=="2"or slot=="3"then
   if c.variant=="projetil"then return {L(S.."separated_smoke","projectile",c.dur or .8,slot=="2"and .4 or .2,{speed=c.speed or(slot=="2"and 38 or 72),continuous=true}),L(E.."Shiny_01","projectile",c.dur or .8,.25,{speed=c.speed or(slot=="2"and 38 or 72),continuous=true})}end
   return {L(E.."Shiny_01","follow",.25,.45,{offset=Vector3.new(.8,.5,-2)})}
  elseif slot=="ULT"then return R.resolve(id,"rebobinar",phase,{dur=.7})end
 end
 return nil
end
return R
