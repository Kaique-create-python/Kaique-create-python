-- Production projectile + hitbox + actor registry; engine overlap/raycast are controlled geometry boundaries.
local H=require('./harness');local R=require('@lune/roblox')
local arena=R.Instance.new('Folder');local now=100;local blocked=false;local candidate
local wall=R.Instance.new('Part');wall.CanCollide=true
H.extras.workspace=setmetatable({GetServerTimeNow=function()return now end,
 GetPartBoundsInRadius=function(_,pos,radius)
  return candidate and(candidate.CFrame.Position-pos).Magnitude<=radius and{candidate}or{}
 end,
 Raycast=function(_,pos,delta)
  if blocked and math.abs(delta.X)>.1 then return{Instance=wall,Position=pos+delta*.3}end
  return nil
 end},{__index=H.workspace})
local physics={};H.extras.require=function(node)
 if node.Name=='Mapa'then return{pasta={},filtro=function()return{}end}end
 return H.require(node)
end
local L=H.modulo('ServerScriptService/BB_Servidor/Lutadores')
local function actor(id,pos)
 local model=R.Instance.new('Model');model.Parent=arena
 for _,name in {'HumanoidRootPart','Torso'}do local p=R.Instance.new('Part');p.Name=name;p.CFrame=R.CFrame.new(pos);p.Position=pos;p.Parent=model end
 local h=R.Instance.new('Humanoid');h.Health=100;h.Parent=model
 return L.criar(model,nil,id)
end
local owner=actor('CRAZY_DIAMOND',R.Vector3.new(0,3,0));local victim=actor('SILVER_CHARIOT',R.Vector3.new(1.5,3,-1))
local accessory=R.Instance.new('Accessory');accessory.Parent=victim.modelo
local handle=R.Instance.new('Part');handle.Name='Handle';handle.CFrame=R.CFrame.new(0,3,-1);handle.Parent=accessory
local hits=0
local function probe(id,kind)
 owner.standId=id;blocked=kind=='wall';candidate=kind=='accessory'and handle or victim.raiz
 local P=H.moduloNovo('ServerScriptService/BB_Servidor/Projeteis')
 P.iniciar({FireAllClients=function()end},function()hits+=1 end,function()hits+=1 end,nil)
 local before=hits
 P.lancar(owner,{vel=10,raio=1,alcance=20,context14={stand=id}},R.Vector3.new(0,3,0),R.Vector3.new(0,0,-1),id..'_2')
 P.passo(.1)
 assert(hits-before==(kind=='body'and 1 or 0),id..' accepted '..kind)
end
for _,id in {'CRAZY_DIAMOND','KILLER_QUEEN','SILVER_CHARIOT','MAGICIANS_RED','STAR_PLATINUM','THE_WORLD'}do
 for _,kind in {'body','wall','accessory'}do probe(id,kind)end
end
-- Reflection transfers one projectile's owner generation, not the shared launch definition.
blocked=false;candidate=victim.raiz;owner.standId='CRAZY_DIAMOND'
local V=H.modulo('ServerScriptService/BB_Servidor/Vinculos16')
local P=H.moduloNovo('ServerScriptService/BB_Servidor/Projeteis')
local first
P.iniciar({FireAllClients=function()end},function()end,function()end,function(_,p)return p.id==first and p.dono==owner end)
local def={vel=10,raio=1,alcance=100,context14={stand='CRAZY_DIAMOND',actionId='launch',moveId='CRAZY_DIAMOND_2'},vinculo16=V.capturar(owner)}
first=P.lancar(owner,def,R.Vector3.new(0,3,0),R.Vector3.new(0,0,-1),'CRAZY_DIAMOND_2')
P.lancar(owner,def,R.Vector3.new(0,3,20),R.Vector3.new(0,0,-1),'CRAZY_DIAMOND_2')
P.passo(.1);P.passo(.01);assert(P.quantos()==2,'reflection modified another projectile launch definition')
owner.hum.Health=0;P.passo(.01);assert(P.quantos()==1,'reflection failed to transfer owner lifetime')
print('AJ16 projectile actual: six body filters, accessory-only miss, side-wall LOS, independent reflected owner lifetime PASS')
