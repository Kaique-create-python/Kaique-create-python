-- Original R6 choreography. Existing locomotion remains owned by AnimacoesDono.
local A={P={},C={}}
local P,C=A.P,A.C
P.cd_ready16={Waist={-5,8,0},Neck={0,-6,0},RS={52,-10,18},LS={58,12,-18},LH={12,0,-3},RH={-10,0,3}}
P.cd_left16={Waist={-12,-24,-3},Neck={0,15,0},RS={42,-12,18},LS={94,5,-4},LH={17,0,-3},RH={-14,0,3}}
P.cd_right16={Waist={-12,24,3},Neck={0,-15,0},RS={96,-5,4},LS={42,12,-18},LH={18,0,-3},RH={-15,0,3}}
P.cd_shards16={Waist={-8,0,0},Neck={-5,0,0},RS={102,-25,12},LS={104,25,-12},LH={10,0,-3},RH={-8,0,3}}
P.cd_repair16={Waist={-4,0,0},Neck={-12,0,0},RS={140,-12,30},LS={140,12,-30},LH={6,0,-4},RH={-5,0,4}}
P.cd_grab16={Waist={-13,8,0},Neck={3,-5,0},RS={90,-18,12},LS={90,18,-12},LH={18,0,-4},RH={-14,0,4}}
P.kq_ready16={Waist={-2,-12,0},Neck={-2,10,0},RS={43,-12,18},LS={20,18,-12},LH={7,0,-3},RH={-6,0,3}}
P.kq_touch16={Waist={-7,22,0},Neck={0,-14,0},RS={91,-8,-3},LS={28,15,-18},LH={12,0,-3},RH={-8,0,3}}
P.kq_left16={Waist={-7,-20,0},Neck={0,14,0},RS={36,-12,18},LS={92,8,3},LH={12,0,-3},RH={-8,0,3}}
P.kq_detonate16={Waist={-3,-12,0},Neck={8,14,0},RS={114,-24,-21},LS={22,12,-10},LH={5,0,-3},RH={-4,0,3}}
P.kq_release16={Waist={-8,24,0},Neck={0,-14,0},RS={102,-10,2},LS={28,15,-17},LH={14,0,-3},RH={-10,0,3}}
P.cd_owner16={Waist={-3,8,0},Neck={-3,-8,0},RS={72,-6,8},LS={8,4,-4}}
P.kq_owner16={Waist={0,-10,0},Neck={10,12,0},RS={108,-22,-15},LS={9,4,-4}}
P.ora_ready16={Waist={-13,0,0},Neck={7,0,0},RS={48,-12,18},LS={48,12,-18},LH={20,0,-5},RH={-15,0,5}}
P.ora_left16={Waist={-18,-18,-3},Neck={8,10,0},RS={45,-15,20},LS={104,5,-5},LH={22,0,-5},RH={-16,0,5}}
P.ora_right16={Waist={-18,18,3},Neck={8,-10,0},RS={104,-5,5},LS={45,15,-20},LH={22,0,-5},RH={-16,0,5}}
P.muda_ready16={Waist={-9,0,0},Neck={4,0,0},RS={59,-16,25},LS={59,16,-25},LH={16,0,-6},RH={-12,0,6}}
P.muda_left16={Waist={-14,-23,-2},Neck={5,13,0},RS={52,-18,24},LS={110,8,-4},LH={18,0,-6},RH={-14,0,6}}
P.muda_right16={Waist={-14,23,2},Neck={5,-13,0},RS={110,-8,4},LS={52,18,-24},LH={18,0,-6},RH={-14,0,6}}
P.ora_load16={Waist={2,-29,0},Neck={0,15,0},RS={20,-12,34},LS={65,15,-22},LH={22,0,-5},RH={-15,0,5}}
P.muda_load16={Waist={0,-34,0},Neck={-4,18,0},RS={25,-18,30},LS={68,18,-24},LH={18,0,-6},RH={-14,0,6}}
local function clipe(name,ready,hit,dur,impact)
 C[name]={dur=dur,impacto=impact,keys={{0,ready},{impact*.55,ready,"suave"},{impact,hit,"estalo"},{impact+.06,hit},{dur,ready,"suave"}}}
end
clipe("cd_left16","cd_ready16","cd_left16",.3,.1)
clipe("cd_right16","cd_ready16","cd_right16",.3,.1)
clipe("cd_final16","cd_ready16","cd_right16",.45,.16)
clipe("cd_shards16","cd_ready16","cd_shards16",.6,.28)
clipe("cd_repair16","cd_ready16","cd_repair16",.9,.5)
clipe("cd_grab16","cd_ready16","cd_grab16",.5,.22)
clipe("kq_touch16","kq_ready16","kq_touch16",.3,.1)
clipe("kq_left16","kq_ready16","kq_left16",.3,.1)
clipe("kq_final16","kq_ready16","kq_touch16",.45,.16)
clipe("kq_release16","kq_ready16","kq_release16",.5,.25)
C.kq_detonate16={dur=.7,impacto=.25,keys={{0,"kq_ready16"},{.18,"kq_detonate16","saida"},{.25,"kq_detonate16"},{.38,"kq_ready16","estalo"},{.7,"kq_ready16","suave"}}}
C.cd_rush16={proc="cd_rush16",segurar=true,keys={{0,"cd_ready16"}}}
C.cd_owner16={segurar=true,keys={{0,"cd_owner16"}}}
C.kq_owner16={segurar=true,keys={{0,"kq_owner16"}}}
C.ora_loop16={proc="ora_loop16",segurar=true,keys={{0,"ora_ready16"}}}
C.muda_loop16={proc="muda_loop16",segurar=true,keys={{0,"muda_ready16"}}}
C.ora_final16={dur=.9,impacto=.65,keys={{0,"ora_ready16"},{.28,"ora_load16","saida"},{.57,"ora_load16"},{.65,"ora_right16","estalo"},{.73,"ora_right16"},{.9,"ora_ready16","suave"}}}
C.muda_final16={dur=.9,impacto=.65,keys={{0,"muda_ready16"},{.28,"muda_load16","saida"},{.57,"muda_load16"},{.65,"muda_right16","estalo"},{.73,"muda_right16"},{.9,"muda_ready16","suave"}}}
local routes={
 STAR_PLATINUM={barragem="ora_loop16"},THE_WORLD={barragem="muda_loop16"},
 CRAZY_DIAMOND={barragem="cd_rush16",soco_e="cd_left16",soco_d="cd_right16",soco_pesado="cd_final16",m1_4="cd_final16",leque="cd_shards16",conjurar="cd_repair16",agarrar="cd_grab16"},
 KILLER_QUEEN={soco_e="kq_left16",soco_d="kq_touch16",soco_pesado="kq_final16",m1_4="kq_final16",detonar="kq_detonate16",conjurar="kq_detonate16",lancar="kq_release16"},
}
function A.route(id,clip,owner)
 if owner then
  if id=="CRAZY_DIAMOND"and(clip=="pose_josuke"or clip=="conjurar")then return"cd_owner16"end
  if id=="KILLER_QUEEN"and clip=="detonar"then return"kq_owner16"end
  return nil
 end
 return routes[id]and routes[id][clip]or nil
end
function A.proc(name,t)
 if name=="ora_loop16"or name=="muda_loop16"then
  local ora=name=="ora_loop16";local prefix=ora and"ora"or"muda";local start=ora and .25 or .2
  local ready=P[prefix.."_ready16"]
  if t<start then return ready end
  local phase=((t-start)/.16)%1
  local to=P[prefix..(phase<.5 and"_left16"or"_right16")]
  local pulse=math.sin((phase%.5)*math.pi*2)
  local out={}
  for k,v in ready do local b=to[k]or v;out[k]={v[1]+(b[1]-v[1])*pulse,v[2]+(b[2]-v[2])*pulse,v[3]+(b[3]-v[3])*pulse}end
  return out
 end
 if name~="cd_rush16"then return nil end
 local phase=(t/.17)%1
 local from=phase<.5 and P.cd_left16 or P.cd_right16
 local to=phase<.5 and P.cd_right16 or P.cd_left16
 local f=(phase%.5)*2;f=f*f*(3-2*f)
 local out={}
 for k,v in from do local b=to[k]or v;out[k]={v[1]+(b[1]-v[1])*f,v[2]+(b[2]-v[2])*f,v[3]+(b[3]-v[3])*f}end
 return out
end
return A
