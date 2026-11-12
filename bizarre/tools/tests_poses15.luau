local H=require('./harness')
local P=H.modulo('ReplicatedStorage/BB/Poses')
assert(type(P.clipe15)=='function','new stand pose routing absent')
for _,pair in {{'SILVER_CHARIOT','estocada'},{'SILVER_CHARIOT','estocadas'},{'SILVER_CHARIOT','gira_sombrinha'},{'SILVER_CHARIOT','conjurar'},{'MAGICIANS_RED','sopro'},{'MAGICIANS_RED','conjurar'}}do
 local name=P.clipe15(pair[1],pair[2]);assert(name~=pair[2] and P.C[name])
 local clip=P.C[name]
 for _,t in {0,.05,.15,.3,.8}do
  local pose=clip.proc and P.aj15Proc(clip.proc,t)or P.amostrar(clip,t)
  assert(pose and pose.RS and pose.Waist)
  for _,angles in pose do for _,n in angles do assert(n==n and math.abs(n)<1000)end end
 end
end
assert(P.clipe15('STAR_PLATINUM','sopro')=='sopro')
assert(P.clipe15('KILLER_QUEEN','conjurar')=='conjurar')
print('AJ15 stand clips: finite/sampled, scoped, no locomotion changes PASS')
