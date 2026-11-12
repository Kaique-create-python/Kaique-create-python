local H=require('./harness')
local fs=require('@lune/fs')
local rb=require('@lune/roblox')
local P=H.modulo('ReplicatedStorage/BB/PerfilCombate14')
assert(P.suporta('SILVER_CHARIOT') and P.suporta('MAGICIANS_RED'),'SC/MR must use authoritative pilot profile')
assert(not P.suporta('CRAZY_DIAMOND') and not P.suporta('KILLER_QUEEN'))
local R=H.modulo('ReplicatedStorage/BB/VFXReceitas')
for _,id in {'SILVER_CHARIOT','MAGICIANS_RED'}do
 assert(R.suporta(id))
 for _,move in {'invocar','m1','m1_aereo','dash','bloqueio','parry','quebra_guarda',id..'_1',id..'_2',id..'_3',id..'_4',id..'_ULT'}do
  assert(#assert(R.resolve(id,move,'inicio',{variant='antecipacao',n=1}))>0,move)
 end
end
local catalog=rb.deserializeModel(fs.readFile('bizarre/assets/vfx15/catalogo.rbxm'))[1]
assert(catalog.Name=='BB_VFXCatalogo15')
local meshes=0
for _,n in catalog:GetDescendants()do
 assert(not n:IsA('LuaSourceContainer') and not n:IsA('Sound') and not n:IsA('Humanoid'))
 if n:IsA('BasePart')then
  assert(n.Anchored and not n.CanCollide and not n.CanTouch and not n.CanQuery)
  if n:GetAttribute('BB_VisibleMesh')then assert(n.Transparency<1);meshes+=1 end
 end
end
assert(meshes>=2,'authored mesh slash must remain visible')
print('AJ15 recipes/catalog/profile PASS; visible meshes '..meshes)
