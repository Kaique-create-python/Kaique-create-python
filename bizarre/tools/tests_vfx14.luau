local fs=require('@lune/fs')
local luau=require('@lune/luau')
local r=require('@lune/roblox')
r.implementProperty('BasePart','Position',function(self)return self.CFrame.Position end,function(self,v)self.CFrame=r.CFrame.new(v)*self.CFrame.Rotation end)
r.implementProperty('Attachment','Position',function(self)return self.CFrame.Position end,function(self,v)self.CFrame=r.CFrame.new(v)*self.CFrame.Rotation end)
local prefix=if fs.isDir('bizarre/src') then 'bizarre/' else ''
local base=prefix..'src/ReplicatedStorage/BB/'
assert(fs.isFile(base..'VFXReceitas.luau'),'receitas piloto ausentes')
assert(fs.isFile(base..'Cliente/VFXPiloto.luau'),'renderizador piloto ausente')
local extra=luau.load(fs.readFile(base..'VFXReceitas15.luau'),{environment={Color3=r.Color3,Vector3=r.Vector3}})()
local newer=luau.load(fs.readFile(base..'VFXReceitas16.luau'),{environment={Color3=r.Color3,Vector3=r.Vector3}})()
local R=luau.load(fs.readFile(base..'VFXReceitas.luau'),{environment={Color3=r.Color3,Vector3=r.Vector3,script={Parent={VFXReceitas15={Name="VFXReceitas15"},VFXReceitas16={Name="VFXReceitas16"}}},require=function(n)return n.Name=="VFXReceitas15"and extra or newer end}})()
local cat=r.deserializeModel(fs.readFile(prefix..'assets/vfx14/catalogo.rbxm'))[1]
assert(R.suporta('STAR_PLATINUM') and R.suporta('THE_WORLD'))
for _,id in {'INVALIDO','OUTRO'} do
 assert(not R.suporta(id));assert(R.resolve(id,'m1','contato',{})==nil)
end
assert(R.resolve('STAR_PLATINUM','invocar','inicio',{}),'invocar/inicio sem receita piloto')
for _,case in {{'STAR_PLATINUM','STAR_PLATINUM_4'},{'THE_WORLD','THE_WORLD_2'}} do
 local anticipated=R.resolve(case[1],case[2],'inicio',{variant='antecipacao'})
 for _,layer in anticipated do assert(layer.mode~='projectile','antecipação gera projétil antes de confirmação') end
 local confirmed=R.resolve(case[1],case[2],'inicio',{variant='projetil',n=1,dur=1.2})
 local projectileCount=0
 for _,layer in confirmed do if layer.mode=='projectile' then projectileCount+=1;assert(layer.duration==1.2 and layer.continuous,'rastro não acompanha vida do projétil confirmado') end end
 assert(projectileCount==1,'um evento de projétil gerou leque inteiro')
end

for name in R.templates() do assert(cat:FindFirstChild(name),'template quebrado '..name) end
for _,stand in {'STAR_PLATINUM','THE_WORLD'} do
 for _,move in {'invocar','m1','m1_aereo','dash','bloqueio','parry','quebra_guarda','tempo','tempoVolta','rolo',stand..'_1',stand..'_2',stand..'_3',stand..'_4',stand..'_ULT'} do
  for _,phase in {'inicio','contato','final','fim'} do
   local recipe=R.resolve(stand,move,phase,{n=3})
   assert(recipe,'move sem rota '..move..'/'..phase)
   for _,layer in recipe do assert(cat:FindFirstChild(layer.template),layer.template) end
  end
 end
end
local time=100
local callbacks={}
local emitted={}
r.implementMethod('ParticleEmitter','Emit',function(self,n) table.insert(emitted,{emitter=self,count=n,t=time}) end)
local rs=r.Instance.new('Folder');cat.Parent=rs
local world=r.Instance.new('Workspace')
r.implementMethod('Workspace','GetServerTimeNow',function()return time end)
local ws=world
local env={game={GetService=function(_,n)
 if n=='ReplicatedStorage' then return rs end
 if n=='RunService' then return {Heartbeat={Connect=function(_,fn)table.insert(callbacks,fn);return {Disconnect=function()end}end}} end
 error(n)
end},workspace=ws,script={Parent={Parent={VFXReceitas={}}}},require=function()return R end}
for _,n in {'Instance','Vector3','CFrame','Color3','ColorSequence','ColorSequenceKeypoint','NumberSequence','NumberSequenceKeypoint','NumberRange','Enum'} do env[n]=r[n] end
local P=luau.load(fs.readFile(base..'Cliente/VFXPiloto.luau'),{environment=env})()
local function tick(dt)time+=dt;for _,fn in callbacks do fn(dt) end end
local function actor(name,x)
 local m=r.Instance.new('Model');m.Name=name; m.Parent=world
 local root=r.Instance.new('Part');root.Name='HumanoidRootPart';root.CFrame=r.CFrame.new(x,4,0);root.Parent=m
 return m
end
local a=actor('A',0); local b=actor('B',20); local c=actor('C',40); local d=actor('D',60)
local function mark(model,session,deadline)
 model:SetAttribute('BB_SessaoTempo',session);model:SetAttribute('BB_Congelado',deadline)
end
local function clearMark(model)
 model:SetAttribute('BB_SessaoTempo',nil);model:SetAttribute('BB_Congelado',nil)
end
P.iniciar();P.iniciar();assert(#callbacks==1,'iniciar não idempotente')
local function context(owner,action,hit)return {owner=owner,pos=r.Vector3.new(0,4,0),dir=r.Vector3.new(0,0,-1),actionId=action,hitId=hit,t=time} end
assert(P.tocar('INVALIDO','m1','contato',context(a,'legacy','h'))==nil)
local targetContext={owner=a,target=b,actionId='target',hitId='target',t=time}
local targetHit=P.tocar('STAR_PLATINUM','m1','contato',targetContext)
assert((targetHit.items[1].node.CFrame.Position-r.Vector3.new(20,4,0)).Magnitude<.01,'contato ignorou alvo quando pos não veio')
local h=P.tocar('STAR_PLATINUM','m1','contato',context(a,'m1','hit1'));assert(h)
local count=#emitted;assert(count>0,'contato não emite')
assert(P.tocar('STAR_PLATINUM','m1','contato',context(a,'m1','hit1'))==nil)
assert(#emitted==count,'hit repetido emite duas vezes')
assert(P.tocar('STAR_PLATINUM','m1','final',context(a,'m1','hit1')),'fase diferente deve aparecer')
assert(P.tocar('STAR_PLATINUM','m1','contato',context(b,'m1','hit1')),'donos distintos não colidem')
local long=P.tocar('STAR_PLATINUM','STAR_PLATINUM_1','inicio',context(a,'rush',nil));assert(long)
local rushWind=long.items[1]
local before=#emitted; tick(.25);assert(#emitted>before,'rajada não inicia no prazo')
tick(3.44);before=#emitted;tick(.02);assert(#emitted>before,'carga final ausente')
assert(long.active,'rajada termina antes de 4.6s')
tick(.88);assert(long.active);tick(.010001);assert(not long.active,'rajada não encerra em 4.6s')
for _,pe in rushWind.particles do assert(not pe.node.Enabled,'Wind_02 continua emitindo após 4.6s por somar EmitDelay à janela') end
-- Cancel old action cannot cancel new; cancellation disables emission but retains living particles.
local guard=P.tocar('THE_WORLD','bloqueio','inicio',context(a,'guard',nil));assert(guard)
P.cancelar(a,'old');assert(guard.active)
P.cancelar(a,'guard');assert(not guard.active)
local folder=world:FindFirstChild('BB_VFXPiloto14');assert(folder)
assert(#folder:GetChildren()>0,'cancelamento destruiu partículas já emitidas')
-- Server marks only in-radius victims; session existence must never freeze unrelated actors.
local outside=P.tocar('STAR_PLATINUM','bloqueio','inicio',context(c,'outsideRadius',nil))
local outsidePE=outside.items[1].particles[1].node
P.congelar('outsideSession',a,time+8)
local outsideElapsed=outside.elapsed;tick(.1)
assert(outside.elapsed>outsideElapsed and outsidePE.TimeScale>0,'sessão global congelou ator sem marca servidor fora do raio')
assert(c:GetAttribute('BB_SessaoTempo')==nil and c:GetAttribute('BB_Congelado')==nil,'cliente inventou marca servidor')
mark(c,'otherUnregisteredSession',time+8);tick(.1)
assert(outsidePE.TimeScale>0,'marca de outra sessão congelou ator na sessão errada')
mark(c,'outsideSession',time-.1);tick(.1)
assert(outsidePE.TimeScale>0,'marca expirada congelou ator já liberado fisicamente')
clearMark(c)
P.descongelar('outsideSession');P.cancelar(c,'outsideRadius')
local frozen=P.tocar('THE_WORLD','bloqueio','inicio',context(b,'freeze',nil));assert(frozen)
mark(b,'s2',time+8)
P.congelar('s1',a,time+8);P.congelar('s2',c,time+8);tick(.01)
local frozenPE
for _,n in folder:GetDescendants() do if n:IsA('ParticleEmitter') and n.TimeScale==0 then frozenPE=n;break end end
assert(frozenPE,'TimeScale real não pausou')
P.descongelar('s1');tick(.01);assert(frozenPE.TimeScale==0,'duas sessões desbloquearam cedo')
P.descongelar('s2');clearMark(b);tick(.01);assert(frozenPE.TimeScale>0,'TimeScale não restaurou')
local own=P.tocar('STAR_PLATINUM','bloqueio','inicio',context(a,'own',nil));assert(own)
P.congelar('ownTime',a,time+1);tick(.1);assert(own.elapsed>=.1,'dono do tempo foi pausado')
P.descongelar('ownTime')
local expiry=P.tocar('THE_WORLD','bloqueio','inicio',context(b,'expiry',nil))
local expiryPE=expiry.items[1].particles[1].node
mark(b,'lateExpiry',time+.30)
P.congelar('earlyExpiry',a,time+.15);P.congelar('lateExpiry',c,time+.30)
tick(.16);assert(expiryPE.TimeScale==0,'primeira expiração liberou overlay restante')
tick(.15);assert(expiryPE.TimeScale>0,'última sessão não expirou pelo relógio servidor')
P.cancelar(b,'expiry');clearMark(b)

-- Target-anchored contact/parry/guard break freeze on the actual victim, while DIO's charge stays free.
mark(b,'targetSession',time+8)
P.congelar('targetSession',a,time+8)
local contactContext=context(a,'dioContact','dioContactHit');contactContext.target=b
local victimContact=P.tocar('THE_WORLD','m1','contato',contactContext)
local parryContext=context(a,'victimParry',nil);parryContext.target=b
local victimParry=P.tocar('THE_WORLD','parry','inicio',parryContext)
local breakContext=context(a,'victimBreak',nil);breakContext.target=b
local victimBreak=P.tocar('THE_WORLD','quebra_guarda','inicio',breakContext)
local chargeContext=context(a,'dioCharge',nil);chargeContext.target=b
local dioCharge=P.tocar('THE_WORLD','THE_WORLD_4','inicio',chargeContext)
local projectileContext=context(a,'dioProjectile',nil);projectileContext.target=b;projectileContext.variant='projetil';projectileContext.n=1;projectileContext.dur=1.2
local dioProjectile=P.tocar('THE_WORLD','THE_WORLD_2','inicio',projectileContext)
local noActor=P.tocar('STAR_PLATINUM','m1','contato',{pos=r.Vector3.new(0,4,0),actionId='noActor',hitId='noActor',t=time})
local contactPE=victimContact.items[1].particles[1].node
local chargePE=dioCharge.items[1].particles[1].node
local contactElapsed=victimContact.elapsed;local chargeElapsed=dioCharge.elapsed
tick(.1)
assert(victimContact.elapsed==contactElapsed and contactPE.TimeScale==0,'fragmentos de vítima congelada seguiram dono DIO livre')
assert(victimParry.elapsed==0 and victimBreak.elapsed==0,'parry/quebra não usam vítima marcada')
assert(dioCharge.elapsed>chargeElapsed and chargePE.TimeScale>0,'alvo congelado pausou antecipação do dono livre')
assert(dioProjectile.elapsed>0 and dioProjectile.items[2].particles[1].node.TimeScale>0,'projétil herdou congelamento da vítima em vez do dono')
assert(noActor.elapsed>0,'efeito sem ator foi pausado por sessão global')
assert(b:GetAttribute('BB_SessaoTempo')=='targetSession' and b:GetAttribute('BB_Congelado')>time,'renderer mudou tags de autoridade servidor')
-- Already emitted contact fragments survive cancellation for five frozen seconds.
local residueHost=victimContact.items[1].node
P.cancelar(a,'dioContact');tick(5)
assert(residueHost.Parent==folder and victimContact.elapsed==contactElapsed,'resíduo cancelado expirou enquanto vítima estava congelada')
clearMark(b);tick(.01)
assert(contactPE.TimeScale>0,'remoção real da marca não liberou vítima enquanto sessão continua')
P.descongelar('targetSession')
-- Distinct actors under distinct sessions thaw independently even with another session still active.
mark(b,'actorOne',time+8);mark(c,'actorTwo',time+8)
P.congelar('actorOne',a,time+8);P.congelar('actorTwo',d,time+8)
local one=P.tocar('THE_WORLD','bloqueio','inicio',context(b,'actorOneVFX',nil))
local two=P.tocar('STAR_PLATINUM','bloqueio','inicio',context(c,'actorTwoVFX',nil))
local peOne=one.items[1].particles[1].node;local peTwo=two.items[1].particles[1].node
tick(.1);assert(peOne.TimeScale==0 and peTwo.TimeScale==0)
P.descongelar('actorOne');clearMark(b);tick(.01)
assert(peOne.TimeScale>0 and peTwo.TimeScale==0,'fim de sessão1 não liberou apenas seu ator')
P.descongelar('actorTwo');clearMark(c);tick(.01)
assert(peTwo.TimeScale>0)
P.cancelar(nil);tick(30)
assert(#folder:GetChildren()==0,'resíduos/ativos com congelamento escopado vazaram')
-- Native Beam links and motion follow current owner orientation, not source gallery coordinates.
local finger=P.tocar('STAR_PLATINUM','STAR_PLATINUM_2','inicio',context(a,'finger',nil));assert(finger)
assert(#finger.items==0,'Star Finger emite Beam imediatamente antes de .28s')
tick(.279);assert(#finger.items==0,'Star Finger antecipou Beam antes de .28s')
tick(.002);assert(#finger.items==1,'Star Finger não iniciou Beam em .28s')
local beam
for _,n in folder:GetDescendants() do if n:IsA('Beam') and n.Enabled then beam=n;break end end
assert(beam and beam.Attachment0 and beam.Attachment1,'Star Finger sem Beam real')
local p0=beam.Attachment0.Parent.CFrame:PointToWorldSpace(beam.Attachment0.CFrame.Position)
local p1=beam.Attachment1.Parent.CFrame:PointToWorldSpace(beam.Attachment1.CFrame.Position)
assert(math.abs((p1-p0).Magnitude-16)<.01,'Star Finger não mede 16 studs')
assert((p1-p0).Unit:Dot(r.Vector3.new(0,0,-1))>.99,'Star Finger aponta errado')
tick(.3201)
for _,pe in finger.items[1].particles do assert(not pe.node.Enabled,'partículas de Beam ultrapassaram fim absoluto .60 com EmitDelay') end
assert(not beam.Enabled,'Beam não desliga ao fim de sua sequência')
-- A fresh frozen impact must still be placed at the combat point, never at its gallery coordinates.
mark(b,'newFrozen',time+8)
P.congelar('newFrozen',a,time+8)
local newFrozen=P.tocar('THE_WORLD','m1','contato',context(b,'newFrozen','fresh'))
local frozenHost=newFrozen.items[1].node
assert((frozenHost.CFrame.Position-r.Vector3.new(0,4,0)).Magnitude<5,'novo efeito congelado ficou na galeria')
local frozenElapsed=newFrozen.elapsed
local frozenChildren=#folder:GetChildren()
tick(5)
assert(newFrozen.elapsed==frozenElapsed and frozenHost.Parent==folder,'TTL correu durante tempo parado')
P.descongelar('newFrozen');clearMark(b);tick(.01)
-- EmitDelay/EmitDuration/EmitCount of the authored templates are honored literally.
local sourceStars=cat:FindFirstChild('E_Anime_Stars_01'):FindFirstChild('Main'):FindFirstChild('Stars')
sourceStars:SetAttribute('EmitDelay',.15);sourceStars:SetAttribute('EmitDuration',.2);sourceStars:SetAttribute('EmitCount',7)
local delayed=P.tocar('STAR_PLATINUM','parry','contato',context(a,'delayed','delay'))
local delayedNode=delayed.items[1].node:FindFirstChild('Main'):FindFirstChild('Stars')
local function nodeEmits(node)local count=0;for _,e in emitted do if e.emitter==node then count+=e.count end end;return count end
assert(nodeEmits(delayedNode)==0 and not delayedNode.Enabled)
tick(.1);assert(nodeEmits(delayedNode)==0)
tick(.06);assert(nodeEmits(delayedNode)==7 and delayedNode.Enabled)
tick(.2);assert(not delayedNode.Enabled,'EmitDuration não foi encerrado')
P.cancelar(nil);tick(30);assert(#folder:GetChildren()==0,'limpeza deixou clones vivos')
-- EmitCount cannot run after a continuous scope whose duration ends before EmitDelay.
local shortContext=context(a,'shortContinuous',nil);shortContext.dur=.05
local shortContinuous=P.tocar('STAR_PLATINUM','rolo','inicio',shortContext)
tick(.11)
assert(not shortContinuous.active)
for _,pe in shortContinuous.items[1].particles do assert(nodeEmits(pe.node)==0 and not pe.node.Enabled,'EmitCount ocorreu após janela contínua menor que EmitDelay') end
P.cancelar(nil);tick(30)
-- A predicted throw produces no flight; five actual knife events produce five, not 25, trails.
local predictedThrow=context(a,'predictedThrow',nil);predictedThrow.variant='antecipacao'
local predictedHandle=P.tocar('THE_WORLD','THE_WORLD_2','inicio',predictedThrow)
for _,item in predictedHandle.items do assert(item.spec.mode~='projectile') end
local confirmedHandles={};local firstTrail
for index=1,5 do
 local ctx=context(a,'proj:'..index,nil);ctx.variant='projetil';ctx.n=1;ctx.dur=1.2
 local handle=P.tocar('THE_WORLD','THE_WORLD_2','inicio',ctx);table.insert(confirmedHandles,handle)
 if index==1 then firstTrail=handle.items[2].node end
end
local trailCount=0
for _,host in folder:GetChildren() do if host:GetAttribute('BB_Template')=='S_vfxpack_separated_lines' then trailCount+=1 end end
assert(trailCount==5,'cinco eventos nativos de faca produziram25 rastros')
P.cancelar(a,'predictedThrow')
tick(.7)
for _,handle in confirmedHandles do assert(handle.active,'fim de antecipação cortou projétil confirmado') end
assert(math.abs(firstTrail.CFrame.Position.Z+87.5)<.01,'rastro não acompanha velocidade real/duração confirmada')
P.cancelar(nil);tick(30)
-- Follow preserves caller's supplied fist position and rotates the local anchor with the actor.
local anchored=context(a,'anchor',nil);anchored.pos=r.Vector3.new(3,5,-2)
local anchoredHandle=P.tocar('STAR_PLATINUM','m1','inicio',anchored)
local anchorHost=anchoredHandle.items[1].node
assert((anchorHost.CFrame.Position-r.Vector3.new(3.9,5.4,-4.4)).Magnitude<.01,'follow ignorou ctx.pos do punho')
a:FindFirstChild('HumanoidRootPart').CFrame=r.CFrame.new(5,4,0)*r.CFrame.Angles(0,math.pi/2,0)
tick(.01)
assert(anchorHost.CFrame.Position.X<5,'follow não girou com dono')
a:FindFirstChild('HumanoidRootPart').CFrame=r.CFrame.new(0,4,0)
P.cancelar(nil);tick(30)
-- Every supported recipe is rendered against the actual catalog (not a mocked renderer).
for _,stand in {'STAR_PLATINUM','THE_WORLD'} do
 for _,move in {'invocar','m1','m1_aereo','dash','bloqueio','parry','quebra_guarda','tempo','tempoVolta','rolo',stand..'_1',stand..'_2',stand..'_3',stand..'_4',stand..'_ULT'} do
  for _,phase in {'inicio','contato','final'} do
   local ctx=context(a,'route:'..stand..move..phase,nil);ctx.dur=.2;ctx.n=4
   assert(P.tocar(stand,move,phase,ctx))
  end
 end
end
P.cancelar(nil);tick(30)
assert(#folder:GetChildren()==0,'cleanup de uma receita deixou instância')
for i=1,60 do P.tocar('STAR_PLATINUM','m1','contato',context(a,'mass'..i,'mass'..i)) end
assert(#folder:GetChildren()>=240,'limite cortou qualidade das receitas')
P.cancelar(nil);tick(30)
assert(#folder:GetChildren()==0)

-- Sanitizer is the real curator, with untrusted source nodes never executed.
local C=require('./curar_vfx14')
local source=r.Instance.new('Part');local attachment=r.Instance.new('Attachment');attachment.Parent=source
for _,class in {'Script','LocalScript','ModuleScript','RemoteEvent','Sound','Humanoid','Camera','ScreenGui'} do local n=r.Instance.new(class);n.Parent=source end
local a0=r.Instance.new('Attachment');a0.Name='A0';a0.CFrame=r.CFrame.new(1,2,3);a0.Parent=source
local a1=r.Instance.new('Attachment');a1.Name='A1';a1.CFrame=r.CFrame.new(-2,-5,7);a1.Parent=source
local originalBeam=r.Instance.new('Beam');originalBeam.Attachment0=a0;originalBeam.Attachment1=a1;originalBeam.Parent=a0
local clean=C.sanitizar(source)
assert(#clean:GetChildren()==3)
for _,child in clean:GetChildren() do assert(child:IsA('Attachment')) end
local cleanBeam=clean:FindFirstChild('A0'):FindFirstChildOfClass('Beam')
assert(cleanBeam.Attachment0~=a0 and cleanBeam.Attachment1~=a1,'sanitização manteve refs originais')
assert(cleanBeam.Attachment0.CFrame==a0.CFrame and cleanBeam.Attachment1.CFrame==a1.CFrame,'sanitização alterou refs relativas')
local external=r.Instance.new('Attachment');originalBeam.Attachment1=external
local valid=pcall(function()C.sanitizar(source)end)
assert(not valid,'sanitizador aceitou Beam com endpoint externo')
assert(clean.CanQuery==false and clean.CanTouch==false and clean.CanCollide==false and clean.Anchored)
print('VFX14 OK — catálogo real/rotas/dedupe/4.6s/cancelamento/2 tempos/Beam/limpeza/sanitizador')
