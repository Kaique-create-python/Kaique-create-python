local fs=require('@lune/fs')
local rb=require('@lune/roblox')
local serde=require('@lune/serde')
local process=require('@lune/process')
local C=require('./curar_vfx14')
local dir,out=process.args[1],process.args[2]
local plan=serde.decode('json',fs.readFile(dir..'/plan.json'))
local catalog=rb.Instance.new('Folder');catalog.Name='BB_VFXCatalogo15'
local loaded={}
local manifest={}
for _,spec in plan do
 if not loaded[spec.asset]then loaded[spec.asset]=rb.deserializeModel(fs.readFile(dir..'/'..spec.asset..'.rbxm'))end
 local source=C.selecionar(loaded[spec.asset],spec.path,spec.ordinals)
 local clone=C.sanitizar(source,spec.mesh);clone.Name=spec.name
 clone:SetAttribute('BB_AssetOriginal',spec.asset)
 clone:SetAttribute('BB_CaminhoOriginal',table.concat(spec.path,'/'))
 clone.Parent=catalog
 local particles,meshes,uris=0,0,{}
 for _,n in clone:GetDescendants()do
  if n:IsA('ParticleEmitter')then particles+=1 end
  if n:IsA('BasePart')and n:GetAttribute('BB_VisibleMesh')then meshes+=1 end
 end
 table.insert(manifest,{name=spec.name,asset=spec.asset,path=spec.path,particles=particles,visibleMeshes=meshes})
end
fs.writeFile(out..'/catalogo.rbxm',rb.serializeModel({catalog}))
fs.writeFile(out..'/catalogo.rbxmx',rb.serializeModel({catalog},true))
fs.writeFile(out..'/manifesto.json',serde.encode('json',manifest,true))
print('AJ15 curated '..#catalog:GetChildren()..' templates; no third-party code executed')
