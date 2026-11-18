-- AJUSTE-18: acerto legível (skill roblox-vfx): camadas em degraus, sem bola de brilho atrasada,
-- soco do pacote realçado, luz do impacto que apaga, pico segurado junto com a pausa dos corpos e
-- soco de FOV. Catálogo real (assets/vfx14) e renderer real; serviços e relógio controlados.
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local r=require('@lune/roblox')
r.implementProperty('BasePart','Position',function(self)return self.CFrame.Position end,function(self,v)self.CFrame=r.CFrame.new(v)*self.CFrame.Rotation end)
r.implementProperty('Attachment','Position',function(self)return self.CFrame.Position end,function(self,v)self.CFrame=r.CFrame.new(v)*self.CFrame.Rotation end)
local prefix=if fs.isDir('bizarre/src') then 'bizarre/' else ''
local base=prefix..'src/ReplicatedStorage/BB/'
local extra=luau.load(fs.readFile(base..'VFXReceitas15.luau'),{environment={Color3=r.Color3,Vector3=r.Vector3}})()
local newer=luau.load(fs.readFile(base..'VFXReceitas16.luau'),{environment={Color3=r.Color3,Vector3=r.Vector3}})()
local R=luau.load(fs.readFile(base..'VFXReceitas.luau'),{environment={Color3=r.Color3,Vector3=r.Vector3,script={Parent={VFXReceitas15={Name="VFXReceitas15"},VFXReceitas16={Name="VFXReceitas16"}}},require=function(n)return n.Name=="VFXReceitas15"and extra or newer end}})()

-- 1) receitas: em todo acerto dos seis kits a 1ª camada sai no contato e as outras em degraus
local kits={'STAR_PLATINUM','THE_WORLD','SILVER_CHARIOT','MAGICIANS_RED','CRAZY_DIAMOND','KILLER_QUEEN'}
for _,stand in kits do
 for _,ctx in {{n=1},{n=4}} do
  local recipe=R.resolve(stand,'m1','contato',ctx)
  assert(recipe and #recipe>=2,'acerto sem camadas: '..stand)
  assert(recipe[1].at==0,'a 1ª camada do acerto tem que sair no contato: '..stand)
  local depois=0
  for i=2,#recipe do
   assert(recipe[i].at>0 and recipe[i].at<=.06,'camada '..i..' fora do degrau 0-0,06 s: '..stand)
   depois+=1
  end
  assert(depois>=1,'nenhum degrau: '..stand)
 end
end
local sp=R.resolve('STAR_PLATINUM','m1','contato',{n=1})
assert(sp[1].template=='S_vfxpack_premade_direction_all','SP/TW: o impacto (clarão + fundo escuro) vem primeiro')
local punch=nil
for _,layer in sp do if string.find(layer.template,'Punch_0',1,true) then punch=layer end end
assert(punch and punch.brilho and punch.brilho>=2,'soco do pacote sem realce de brilho')

-- 2) renderer real com o catálogo real
local cat=r.deserializeModel(fs.readFile(prefix..'assets/vfx14/catalogo.rbxm'))[1]
local time=100
local callbacks={}
local emitted={}
r.implementMethod('ParticleEmitter','Emit',function(self,n) table.insert(emitted,{emitter=self,count=n,t=time}) end)
local rs=r.Instance.new('Folder');cat.Parent=rs
local world=r.Instance.new('Workspace')
r.implementMethod('Workspace','GetServerTimeNow',function()return time end)
local env={game={GetService=function(_,n)
 if n=='ReplicatedStorage' then return rs end
 if n=='RunService' then return {Heartbeat={Connect=function(_,fn)table.insert(callbacks,fn);return {Disconnect=function()end}end}} end
 error(n)
end},workspace=world,script={Parent={Parent={VFXReceitas={}}}},require=function()return R end}
for _,n in {'Instance','Vector3','CFrame','Color3','ColorSequence','ColorSequenceKeypoint','NumberSequence','NumberSequenceKeypoint','NumberRange','Enum'} do env[n]=r[n] end
local P=luau.load(fs.readFile(base..'Cliente/VFXPiloto.luau'),{environment=env})()
local function tick(dt)time+=dt;for _,fn in callbacks do fn(dt) end end
local function actor(name,x)
 local m=r.Instance.new('Model');m.Name=name;m.Parent=world
 local root=r.Instance.new('Part');root.Name='HumanoidRootPart';root.CFrame=r.CFrame.new(x,4,0);root.Parent=m
 return m
end
local a=actor('A',0)
local function context(owner,action,hit)return {owner=owner,pos=r.Vector3.new(0,4,0),dir=r.Vector3.new(0,0,-1),actionId=action,hitId=hit,t=time} end

-- política pura
local pular,vMin,vMax=P._politicaContato('Light',1,1)
assert(pular,'brilho Light de 1 s ficou no acerto')
pular=P._politicaContato('Core1',2.5,2.5)
assert(pular,'brilho Core de 2,5 s ficou no acerto')
pular,vMin,vMax=P._politicaContato('Stars',1,1)
assert(not pular and math.abs(vMax-.45)<1e-6 and math.abs(vMin-.45)<1e-6,'estrelas não encurtaram para 0,45 s')
pular,vMin,vMax=P._politicaContato('Hit1',.5,.5)
assert(not pular and vMax==.5,'camada curta foi mexida')

P.iniciar()
local folder=world:FindFirstChild('BB_VFXPiloto14')
local h=P.tocar('STAR_PLATINUM','m1','contato',context(a,'m1','h1'))
tick(.06)
local luzes,starsNode,lightNode,hitNode=0,nil,nil,nil
for _,d in folder:GetDescendants() do
 if d:IsA('PointLight') and d.Parent and d.Parent.Name=='BB_LuzContato18' then luzes+=1 end
 if d:IsA('ParticleEmitter') then
  if d.Name=='Stars' and d.Parent and d.Parent.Parent and d.Parent.Parent:GetAttribute('BB_Template')=='E_Anime_Stars_01' then starsNode=d end
  if d.Name=='Light' then lightNode=d end
  if d.Name=='Hit1' then hitNode=d end
 end
end
assert(luzes==1,'acerto sem a luz do impacto (ou mais de uma): '..luzes)
assert(lightNode and hitNode,'camadas do acerto não apareceram')
local emitiuLight=0
for _,e in emitted do if e.emitter==lightNode then emitiuLight+=e.count end end
assert(emitiuLight==0 and not lightNode.Enabled,'bola de brilho atrasada ainda sai no acerto')
assert(hitNode.Brightness>=2,'soco do pacote não ganhou brilho: '..hitNode.Brightness)
assert(starsNode and starsNode.Lifetime.Max<=.46,'estrelas ainda duram 1 s (ou não apareceram)')
-- a luz apaga sozinha (e o alcance cresce enquanto apaga)
local luz=nil
for _,d in folder:GetDescendants() do if d:IsA('PointLight') then luz=d end end
local b0,r0=luz.Brightness,luz.Range
tick(.15)
assert(luz.Brightness<b0 and luz.Range>r0,'a luz não apagou abrindo o alcance')
tick(.5)
assert(luz.Parent==nil or not luz:IsDescendantOf(folder),'luz do impacto ficou acesa')
-- defesa não acende luz; outro dono no mesmo instante acende a dele, o mesmo dono só a cada 0,12 s
local antes=0
local function contarLuzes()local n=0;for _,d in folder:GetDescendants() do if d:IsA('PointLight') and d.Parent and d.Parent.Name=='BB_LuzContato18' then n+=1 end end;return n end
P.tocar('STAR_PLATINUM','bloqueio','contato',context(a,'bloq','b1'))
assert(contarLuzes()==antes,'bloqueio acendeu luz de acerto')
P.tocar('STAR_PLATINUM','m1','contato',context(a,'m1b','h2'))
P.tocar('STAR_PLATINUM','m1','contato',context(a,'m1c','h3'))
assert(contarLuzes()==1,'mesmo dono acendeu duas luzes no mesmo instante')
P.cancelar(nil);tick(30)
assert(#folder:GetChildren()==0,'limpeza deixou efeito ou luz')

-- 3) segura o pico: com segurar=0,08 o efeito anda 2 quadros e para junto com os corpos
local ctx=context(a,'hold','h9');ctx.segurar=.08
local held=P.tocar('STAR_PLATINUM','m1','contato',ctx)
tick(.02);local e1=held.elapsed
tick(.03);local e2=held.elapsed
tick(.03);local e3=held.elapsed
assert(e1>0 and math.abs(e2-e1)<1e-9 and math.abs(e3-e2)<1e-9,'o pico não ficou parado durante a pausa')
tick(.1);assert(held.elapsed>e3,'o efeito não voltou a andar depois da pausa')
-- rajada e efeitos sem pausa não seguram
local livre=P.tocar('STAR_PLATINUM','m1','contato',context(a,'livre','h10'))
local l0=livre.elapsed;tick(.05);assert(livre.elapsed>l0,'efeito sem pausa ficou parado')
P.cancelar(nil);tick(30)

-- 4) câmera: soco de FOV curto, com rebote leve, e nada quando o tremor está desligado
local camFonte=fs.readFile(base..'Cliente/Camera.luau')
local impulso=assert(string.match(camFonte,'(function Camera%.impulsoFov.-\nend)'),'impulsoFov ausente')
local C={}
luau.load('local Camera=...\n'..impulso,{environment={math=math}})(C)
local menor,maior=0,0
for i=0,40 do local v=C.impulsoFov(i*.01,1);menor=math.min(menor,v);maior=math.max(maior,v) end
assert(menor<=-5.5 and menor>=-7,'soco de FOV fora de 5-7 graus: '..menor)
assert(math.abs(C.impulsoFov(.05,1)+6)<.2,'pico do soco não está em 0,05 s')
assert(maior>0 and maior<1,'rebote do FOV ausente ou exagerado: '..maior)
assert(C.impulsoFov(.31,1)==0 and C.impulsoFov(-.01,1)==0 and C.impulsoFov(.05,0)==0,'FOV fora da janela')
assert(string.find(camFonte,'if not tremorLigado or Camera.forcaTremor <= 0 then',1,true),'soco de FOV ignora o tremor desligado')
local efe=fs.readFile(base..'Cliente/Efeitos.luau')
assert(string.find(efe,'if nivel >= 2 then Camera.socoFov(',1,true),'soco de FOV não está só nos golpes fortes')
assert(string.find(efe,'ctx.segurar=if forte then 0.08 else 0.04',1,true),'pausa do efeito diferente da pausa dos corpos')
assert(string.find(efe,'tipo~="barragem" and tipo~="bloqueio"',1,true),'rajada/defesa não podem segurar')
-- 5) juntas: aceita AnimationConstraint além de Motor6D
local anim=fs.readFile(base..'Cliente/Animador.luau')
assert(string.find(anim,'d:IsA("Motor6D") or d:IsA("AnimationConstraint")',1,true),'Animador só aceita Motor6D')
print('VFX18 OK — degraus nos 6 kits, sem bola atrasada, soco realçado, luz que apaga, pico segurado, soco de FOV e juntas novas')
