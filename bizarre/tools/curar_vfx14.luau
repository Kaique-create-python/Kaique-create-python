-- Offline only. deserializeModel does not run any LuaSourceContainer.
local fs = require('@lune/fs')
local roblox = require('@lune/roblox')
local serde = require('@lune/serde')
local process = require('@lune/process')
local C = {}
local allowed = {Folder=true, Model=true, Part=true, MeshPart=true, SpecialMesh=true,
 Attachment=true, ParticleEmitter=true, Beam=true, Trail=true, Decal=true, Texture=true,
 PointLight=true, SpotLight=true, SurfaceLight=true}
function C.sanitizar(original)
 local clone = original:Clone()
 -- Remove untrusted code and nonvisual objects before assigning to any catalog/game parent.
 for _,n in clone:GetDescendants() do
  if not allowed[n.ClassName] then n:Destroy() end
 end
 assert(allowed[clone.ClassName], 'raiz visual inválida')
 local nodes = clone:GetDescendants(); table.insert(nodes,1,clone)
 for _,n in nodes do
  if n:IsA('BasePart') then
   n.Anchored=true; n.CanCollide=false; n.CanTouch=false; n.CanQuery=false
   n.Transparency=1; n.CastShadow=false
  elseif n:IsA('ParticleEmitter') or n:IsA('Beam') or n:IsA('Trail') then
   n.Enabled=false
  end
 end
 for _,n in nodes do
  if n:IsA('Beam') or n:IsA('Trail') then
   assert(n.Attachment0 and n.Attachment1, 'efeito sem Attachment0/1')
   assert(n.Attachment0:IsDescendantOf(clone) and n.Attachment1:IsDescendantOf(clone),'referência fora do template')
  end
 end
 return clone
end
function C.selecionar(roots, path, ordinals)
 local candidates=roots
 local node=nil
 for index,name in path do
  local occurrence=0
  node=nil
  for _,candidate in candidates do
   if candidate.Name==name then
    occurrence+=1
    if occurrence==(ordinals[index] or 1) then node=candidate; break end
   end
  end
  assert(node,'caminho não existe: '..table.concat(path,'/'))
  candidates=node:GetChildren()
 end
 return node
end
if process.args[1]=='build' then
 local dir=assert(process.args[2]); local out=assert(process.args[3])
 local plan=serde.decode('json',fs.readFile(dir..'/plan.json'))
 local loaded={}
 local catalog=roblox.Instance.new('Folder'); catalog.Name='BB_VFXCatalogo14'
 local originals=roblox.Instance.new('Folder'); originals.Name='FontesSelecionadas'
 for _,spec in plan do
  if not loaded[spec.asset] then loaded[spec.asset]=roblox.deserializeModel(fs.readFile(dir..'/'..spec.asset..'.rbxm')) end
  local source=C.selecionar(loaded[spec.asset],spec.path,spec.ordinals)
  local copy=source:Clone(); copy.Name=spec.name; copy.Parent=originals
  local template=C.sanitizar(source); template.Name=spec.name
  template:SetAttribute('BB_AssetOriginal',spec.asset)
  template:SetAttribute('BB_CaminhoOriginal',table.concat(spec.path,'/'))
  template:SetAttribute('BB_Ordinal',1)
  template.Parent=catalog
 end
 fs.writeFile(out..'/catalogo.rbxm',roblox.serializeModel({catalog}))
 fs.writeFile(dir..'/catalogo.xml',roblox.serializeModel({catalog},true))
 fs.writeFile(out..'/catalogo.rbxmx',roblox.serializeModel({catalog},true))
 fs.writeFile(dir..'/fontes.xml',roblox.serializeModel({originals},true))
 print('Catálogo visual: '..#catalog:GetChildren()..' templates; sem executar scripts dos modelos.')
end
return C
