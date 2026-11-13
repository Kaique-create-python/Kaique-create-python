-- Verificações estruturais do pacote no motor; não carrega nem executa código dos modelos.
local V = {}
local ALLOWED = {
	Folder=true,Model=true,Part=true,MeshPart=true,Attachment=true,SpecialMesh=true,
	ParticleEmitter=true,Beam=true,Trail=true,Decal=true,Texture=true,
	PointLight=true,SpotLight=true,SurfaceLight=true,
}

function V.djb(source: string): string
	local value = 5381
	for i=1,#source do value=(value*33+string.byte(source,i))%4294967296 end
	return string.format("%08x",value)
end

local function locate(root: Instance, path: {string}): Instance?
	local at = root
	for _,name in path do
		local found = nil
		for _,child in at:GetChildren() do
			if child.Name == name then
				if found then return nil end
				found = child
			end
		end
		if not found then return nil end
		at = found
	end
	return at
end

function V.executar(root: Instance,cfg: any,config: any,receitas: any,perfil: any): any
	local out = {package=cfg.package,passed=true,erros={},avisos={},info={templates=0,emissores=0,beams=0,fonts=0}}
	local function fail(msg: string) out.passed=false; table.insert(out.erros,msg) end
	if (cfg.stage~=14 and cfg.stage~=15 and cfg.stage~=16 and cfg.stage~=17) or cfg.package~="BIZARRE-AJUSTE-"..tostring(cfg.stage) or cfg.universe~=10774214555 or cfg.place~=108061345551908 then fail("Destino/pacote incorreto.") end
	if config.REVISAO~="AJUSTE-"..tostring(cfg.stage) or config.UNIVERSE_ID~=10774214555 or config.PLACE_ID~=108061345551908 then fail("Revisao/destino do jogo nao corresponde ao teste.") end
	if type(cfg.hashes)~="table" or #cfg.hashes==0 then fail("Manifesto de fontes ausente.") end
	for _,row in cfg.hashes or {} do
		local label = table.concat(row.path,"/")
		local obj = locate(root,row.path)
		if not obj or obj.ClassName~=row.class then
			fail("Fonte ausente, ambigua ou de outra classe: "..label)
		else
			local ok, source = pcall(function() return (obj :: any).Source end)
			if not ok or type(source)~="string" then
				fail("O teste nao conseguiu ler Source: "..label)
			elseif #source~=row.bytes or V.djb(source)~=row.hash then
				fail("Fonte divergiu do pacote: "..label)
			else out.info.fonts+=1 end
		end
	end
 local catalogs=if cfg.stage>=15 then receitas.catalogos()else {BB_VFXCatalogo14=receitas.templates()}
 for catalogName,expectedTemplates in catalogs do
	local catalog = locate(root,{"ReplicatedStorage",catalogName})
	if not catalog or not catalog:IsA("Folder") then
		fail("Catalogo visual incorporado ausente ou ambiguo.")
	else
		local expected = expectedTemplates
		for name in expected do
			local template = locate(catalog,{name})
			if not template then
				fail("Template ausente/ambiguo: "..name)
			else
				out.info.templates+=1
				local items=template:GetDescendants();table.insert(items,template)
				for _,item in items do
					if not ALLOWED[item.ClassName] then fail("Componente proibido no catalogo: "..item.ClassName) end
					if item:IsA("ParticleEmitter") then out.info.emissores+=1 end
					if item:IsA("Beam") or item:IsA("Trail") then
						if item:IsA("Beam") then out.info.beams+=1 end
						local a0,a1 = item.Attachment0,item.Attachment1
						if not a0 or not a1 or not a0:IsDescendantOf(template) or not a1:IsDescendantOf(template) then fail("Feixe/rastro com referencia externa: "..name) end
					end
					if item:IsA("BasePart") and (item.CanCollide or item.CanTouch or item.CanQuery) then fail("Visual participa de colisoes/raycast: "..name) end
				end
			end
		end
		for _,template in catalog:GetChildren() do
			if not expected[template.Name] then fail("Template fora do manifesto: "..template.Name) end
		end
	end
 end
	if not perfil.suporta("STAR_PLATINUM") or not perfil.suporta("THE_WORLD") then fail("Piloto de combate ausente.") end
 if cfg.stage>=15 and (not perfil.suporta("MAGICIANS_RED")or not perfil.suporta("SILVER_CHARIOT"))then fail("Novos Stands ausentes.")end
 for _,id in {"CRAZY_DIAMOND","KILLER_QUEEN"} do
		if cfg.stage>=16 then
   if not perfil.suporta(id)or not receitas.suporta(id)then fail("Perfil/receitas ausentes: "..id)end
  elseif perfil.suporta(id)or receitas.suporta(id)then fail("Piloto habilitado em Stand legado: "..id)end
	end
	local contact,recovery = perfil.tempos(4)
	if contact~=0.16 or recovery~=0.45 or perfil.bufferTTL~=0.12 or perfil.janela~=0.08 then fail("Tempos do piloto divergiram.") end
	return out
end

return V
