local H=require('./harness');local R=require('@lune/roblox')
local process=require('@lune/process')
if process.env.INTEGRATION14_BASELINE then
 local fs=require('@lune/fs')
 for _,name in {'Acoes','Efeitos'} do H.arvore.ReplicatedStorage.BB.Cliente[name].fonte=fs.readFile('/tmp/integration14-baseline/'..name..'.luau') end
end
local now=10;local jobs={}
local function schedule(dt,fn,...)local args={...};table.insert(jobs,{at=now+dt,co=coroutine.create(function()fn(table.unpack(args))end)})end
local function advance(dt)
 local goal=now+dt
 while true do table.sort(jobs,function(a,b)return a.at<b.at end);if not jobs[1] or jobs[1].at>goal then break end
 local j=table.remove(jobs,1);now=j.at;local ok,delay=coroutine.resume(j.co);assert(ok,delay)
 if coroutine.status(j.co)~='dead' then table.insert(jobs,{at=now+(delay or 0),co=j.co})end end;now=goal
end
H.extras.task={delay=schedule,spawn=function(fn,...)schedule(0,fn,...)end,wait=function(dt)return coroutine.yield(dt or .03)end};H.extras.os={clock=function()return now end}
local world=R.Instance.new('Folder')
H.extras.workspace=setmetatable({GetServerTimeNow=function()return now end},{__index=function(_,k)
 if k=='Raycast' then return function()return nil end end
 local v=world[k];if type(v)=='function' then return function(_,...)return v(world,...)end end;return v end})
local function model(id)local m=R.Instance.new('Model');m.Parent=world;m:SetAttribute('BB_Stand',id)
 local p=R.Instance.new('Part');p.Name='HumanoidRootPart';p.CFrame=R.CFrame.new(0,3,0);p.Position=R.Vector3.new(0,3,0);p.Parent=m
 local h=R.Instance.new('Humanoid');h.Health=100;h.Parent=m;return m end
local m=model('STAR_PLATINUM');local victim=model('THE_WORLD');local third=model('CRAZY_DIAMOND')
H.servicos.Players={LocalPlayer={Character=m}}
H.servicos.Debris={AddItem=function()end}
local animations,stands,voices,routes,hitstops,legacy={},{},{},{},{},{}
local function log(t,...)table.insert(t,{at=now,args={...}})end
local SV={modelo=function(x)return x==m and victim or nil end,acao=function(...)log(stands,...)end,cancelar=function()end,investida=function()end,visivel=function()return true end,impactoGuarda=function()end,parry=function()end,quebrouGuarda=function()end}
local anim={tocar=function(...)log(animations,...)end,tocando=function()return nil end,cortar=function()end,hitstop=function(...)log(hitstops,...)end,pausarTudo=function()error('global hitstop')end}
local sound={voz=function(name)local s={stopped=false,Stop=function(self)self.stopped=true end};table.insert(voices,s);return s,if type(name)=='table' then name[1] else name end,duracaoVoz=function()return 4.6 end,tocar=function()end,golpe=function()return true end,vozPronta=function()return true end,abafar=function()end}
local pilot={suporta=function(id)return id=='STAR_PLATINUM' or id=='THE_WORLD'end,iniciar=function()end,tocar=function(...)log(routes,...)return {}end,cancelar=function()end,congelar=function(...)log(routes,'freeze',...)end,descongelar=function(...)log(routes,'thaw',...)end}
local vfx=setmetatable({},{__index=function(_,name)return function(...)log(legacy,name,...)end end})
local deps={Animador=anim,StandVisual=SV,Som=sound,VFX=vfx,VFXPiloto=pilot,Camera={tremer=function()end,fov=function()end},Cinematica={ult=function()end,cancelar=function()end},Registro={iniciar=function()end,todosModelos=function()return {}end}}
local catalog=R.Instance.new('Folder');catalog.Name='BB_VFXCatalogo14';local available=true
H.servicos.ReplicatedStorage={FindFirstChild=function(_,name)return available and name=='BB_VFXCatalogo14' and catalog or nil end}
H.extras.require=function(node)return deps[node.Name] or H.require(node)end
for name in H.modulo('ReplicatedStorage/BB/VFXReceitas').templates() do local template=R.Instance.new('Folder');template.Name=name;template.Parent=catalog end
local E=H.modulo('ReplicatedStorage/BB/Cliente/Efeitos');deps.Efeitos=E
local A=H.modulo('ReplicatedStorage/BB/Cliente/Acoes');deps.Acoes=A
local failures={}
local function test(name,fn)
 jobs={};animations={};stands={};routes={};legacy={};hitstops={};voices={};now+=20
 local ok,err=pcall(fn);print(if ok then 'PASS' else 'FAIL',name,err or '')
 if not ok then table.insert(failures,name..': '..tostring(err))end;A.interromper(m)
end
test('m1 fourth contact .16',function()A.tocar(m,{id='m1',n=4,stand=true,seq=1});assert(stands[1].args[2].impacto==.16,'fourth stand impact must .16')end)
test('m1 aerial actual animation',function()A.tocar(m,{id='m1_aereo',stand=true,seq=2});assert(#animations==1 and #stands==1,'air followup must animate owner and stand');assert(stands[1].args[2].impacto==.1 and stands[1].args[2].dur==.3)end)
test('seq association no restart and stale interrupts ignored',function()
 A.tocar(m,{id='m1',n=1,seq=3});local count=#animations;assert(A.confirmar(m,{seq=3,actionId='a3',t=now})==true);assert(#animations==count)
 A.tocar(m,{id='m1',n=2,seq=4});count=#animations;assert(A.confirmar(m,{seq=3,actionId='a3'})==false);assert(A.interromper(m,'a3',3)==false)
 A.confirmar(m,{seq=4,actionId='a4'});A.tocar(m,{id='m1',n=2,seq=4,actionId='a4'});assert(#animations==count,'duplicate event restarted action')
end)
test('barrage final4.35 end4.6 replacement voice',function()
 local t=now;A.tocar(m,{id='STAR_PLATINUM_1',seq=5});advance(.26);assert(#voices==1);advance(3.45);assert(not voices[1].stopped);advance(.65)
 local final=false;for _,call in stands do if call.args[2].clipe=='soco_pesado' then assert(math.abs(call.at+call.args[2].impacto-(t+4.35))<.001);final=true end end
 assert(final,'missing heavy final animation');advance(.25);assert(voices[1].stopped,'voice leaked beyond4.6')
 A.tocar(m,{id='STAR_PLATINUM_1',seq=6});advance(.26);local old=voices[#voices];A.tocar(m,{id='m1',seq=7});assert(old.stopped)
end)
test('time voice separate action lifetime',function()
 A.tocar(m,{id='STAR_PLATINUM_ULT',seq=8});A.confirmar(m,{seq=8,actionId='time8'});advance(.01);assert(#voices==1)
 E.tempo({sessao='s8',dono=m,stand='STAR_PLATINUM',inicio=now,fim=now+3,centro=R.Vector3.zero,raio=150})
 advance(1.85);A.concluir(m,{actionId='time8',reason='concluida'});A.tocar(m,{id='m1',seq=9});assert(not voices[1].stopped,'time voice cut by M1')
 E.tempoVolta({sessao='s8',dono=m});assert(voices[1].stopped,'time voice survives session')
end)
test('hit phase dedupe scoped hitstop',function()
 local d={a=m,v=victim,pos=R.Vector3.zero,stand='STAR_PLATINUM',moveId='m1',actionId='x',hitId='h',phase='resolved'};E.acerto(d);E.acerto(d)
 assert(#hitstops==4,'only fighters + their stands, once');for _,hit in hitstops do assert(hit.args[1]~=third and hit.args[2]==.04)end
 d.phase='queued';d.congelado=true;E.acerto(d);local hits=0;for _,c in routes do if c.args[3]=='contato' then hits+=1 end end;assert(hits==2)
end)
test('four legacy stands',function()
 for i,id in {'MAGICIANS_RED','SILVER_CHARIOT','CRAZY_DIAMOND','KILLER_QUEEN'}do m:SetAttribute('BB_Stand',id);A.tocar(m,{id='m1',seq=10+i});advance(.2)end
 m:SetAttribute('BB_Stand','STAR_PLATINUM');assert(#routes==0 and #legacy>=4)
end)
test('two time sessions no neon',function()
 local before=#world:GetDescendants();for _,id in {'s1','s2'}do E.tempo({sessao=id,dono=m,stand='STAR_PLATINUM',inicio=now,fim=now+3,centro=R.Vector3.zero,raio=150})end
 E.tempoVolta({sessao='s1',dono=m});local thaw=false;for _,c in routes do if c.args[1]=='thaw' and c.args[2]=='s1' then thaw=true end end
 assert(thaw,'first session not thawed');assert(E.tempoParadoAgora());E.tempoVolta({sessao='s2',dono=m});assert(not E.tempoParadoAgora());assert(#world:GetDescendants()==before,'legacy dome created')
end)
test('old scheduled animTroca and animRepetir never override replacement',function()
 local g=H.modulo('ReplicatedStorage/BB/Golpes').get('STAR_PLATINUM_3')
 g.animTroca={{t=.3,animU='chute_alto',animS='chute'}};g.animRepetir={.1,.7}
 A.tocar(m,{id='STAR_PLATINUM_3',seq=30});advance(.1);A.tocar(m,{id='m1',seq=31})
 local count=#animations;advance(.5);g.animTroca=nil;g.animRepetir=nil
 assert(#animations==count,'old callbacks overwrite new action')
end)
test('old action end cannot stop newer voice or clip',function()
 A.tocar(m,{id='m1',seq=32,actionId='old32'});A.tocar(m,{id='STAR_PLATINUM_1',seq=33,actionId='new33'});advance(.26)
 assert(A.concluir(m,{actionId='old32',seq=32,reason='interrompida'})==false)
 assert(not voices[1].stopped);A.concluir(m,{actionId='new33',seq=33,reason='concluida'});assert(voices[1].stopped)
end)
test('projectile scope unit recipe and no legacy double render',function()
 E.proj({id=201,dono=m,stand='THE_WORLD',visual='faca',origem=R.Vector3.zero,dir=R.Vector3.new(0,0,-1),t=now,vel=125,alcance=90})
 assert(#routes==1 and #legacy==0);local ctx=routes[1].args[4];assert(ctx.variant=='projetil' and ctx.n==1)
 E.projFim({id=201,pos=R.Vector3.zero,explodiu=false});assert(#legacy==0)
end)
test('optional catalog fallback keeps pilot animation working',function()
 available=false;A.tocar(m,{id='m1',n=1,seq=34});advance(.12);available=true
 assert(#routes==0 and #legacy>0 and #animations==1)
end)
test('dead owner invalidates delayed rolo final',function()
 E.rolo({quem=m,stand='THE_WORLD',actionId='roller35',pos=R.Vector3.zero,t=now,ate=now+.5})
 E.limparDono(m);local count=#routes;advance(.6);assert(#routes==count,'cancelled owner emitted delayed rolo')
end)
test('time sessions use independent scope and real victim attrs',function()
 victim:SetAttribute('BB_Congelado',nil);m:SetAttribute('BB_Congelado',nil)
 E.tempo({sessao='s36',dono=m,stand='STAR_PLATINUM',inicio=now,fim=now+3,centro=R.Vector3.zero,raio=150})
 local found=false;for _,r in routes do if r.args[2]=='tempo' then assert(r.args[4].actionId=='tempo:s36');found=true end end
 assert(found and victim:GetAttribute('BB_Congelado')==nil,'client must not invent frozen victim tags')
 E.tempoVolta({sessao='s36',dono=m})
end)
test('remote bots no seq preserve stale action ordering after natural end',function()
 A.tocar(third,{id='m1',n=1,stand=false,actionId='botnew',t=now});advance(.31);local count=#animations
 A.tocar(third,{id='m1',n=2,stand=false,actionId='botold',t=now-2});assert(#animations==count,'stale no-seq action replayed')
 A.interromper(third)
end)
test('high quality no FPS'  ,function()E.modoQualidade('auto');local mode,high=E.qualidadeAtual();assert(mode=='alta' and high)end)
assert(#failures==0,table.concat(failures,'\n'));print('AJ14 client integration real modules OK')
