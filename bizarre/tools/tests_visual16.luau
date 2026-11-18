local H=require('./harness');local fs=require('@lune/fs');local rb=require('@lune/roblox')
local R=H.modulo('ReplicatedStorage/BB/VFXReceitas');local P=H.modulo('ReplicatedStorage/BB/Poses');local G=H.modulo('ReplicatedStorage/BB/Golpes')
local names={}
for _,v in {14,15}do for _,n in rb.deserializeModel(fs.readFile('bizarre/assets/vfx'..v..'/catalogo.rbxm'))[1]:GetChildren()do names[n.Name]=true end end
for _,id in {'CRAZY_DIAMOND','KILLER_QUEEN'}do
 assert(R.suporta(id),'visual profile missing '..id)
 for _,slot in {1,2,3,4,'ULT'}do
  local move=id..'_'..slot
  for _,phase in {'inicio','contato','final'}do
   local list=R.resolve(id,move,phase,{variant='projetil',dur=.8,speed=100})
   assert(list and #list>0,'missing recipe '..move..'/'..phase)
   for _,layer in list do assert(names[layer.template],'unavailable template '..tostring(layer.template));assert(layer.duration>0 and layer.at>=0)end
  end
 end
 for _,move in {'invocar','m1','dash','bloqueio','parry','quebra_guarda'}do assert(R.resolve(id,move,'inicio',{}),move)end
end
for _,case in {{'CRAZY_DIAMOND','barragem'},{'CRAZY_DIAMOND','leque'},{'CRAZY_DIAMOND','conjurar'},{'CRAZY_DIAMOND','agarrar'},{'KILLER_QUEEN','soco_d'},{'KILLER_QUEEN','conjurar'},{'KILLER_QUEEN','detonar'}}do
 local name=P.clipe15(case[1],case[2]);assert(name~=case[2] and P.C[name],'dedicated pose absent '..case[1]..'/'..case[2])
 for _,t in {0,.05,.2,.5,.9,1.5}do
  local c=P.C[name];local pose=c.proc and P.aj16Proc(c.proc,t)or P.amostrar(c,t)
  assert(pose and pose.RS and pose.LS,'missing arm pose')
  for _,angles in pose do for _,n in angles do assert(n==n and math.abs(n)<1000,'invalid pose angle')end end
 end
end
-- Established marks follow the confirmed victim and last beyond the casting animation.
for _,move in {'marca','pedra16'}do
 local list=R.resolve(move=='marca'and'KILLER_QUEEN'or'CRAZY_DIAMOND',move,'inicio',{dur=2})
 assert(list and list[1].mode=='target' and list[1].duration==2,'target lifecycle missing '..move)
end
assert(G.get('STAR_PLATINUM_1').trava==4.6 and G.get('THE_WORLD_1').final.t==4.35)
print('AJ16 recipes/poses: six profiles, every slot, authored assets, target timeline PASS')
