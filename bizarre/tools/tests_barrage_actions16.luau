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
local world=R.Instance.new('Workspace')
R.implementMethod('Workspace','GetServerTimeNow',function()return now end)
R.implementMethod('Workspace','Raycast',function()return nil end)
H.extras.workspace=world
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

local beats={};H.servicos.RunService.Heartbeat={Connect=function(_,fn)table.insert(beats,fn);return{Disconnect=function()end}end}
for i,name in {'Left Arm','Right Arm'}do local p=R.Instance.new('Part');p.Name=name;p.CFrame=R.CFrame.new(i==1 and -1.5 or 1.5,3,0);p.Parent=victim end
local originalAdvance=advance
advance=function(dt)originalAdvance(dt);for _,fn in beats do fn(dt)end end
local t=now;A.tocar(m,{id='STAR_PLATINUM_1',seq=1});advance(.26)
local folder=world:FindFirstChild('BB_Barragens16');assert(folder and #folder:GetChildren()==1,'ORA did not start real arm copies')
local group=folder:GetChildren()[1];local count=#group:GetDescendants()
assert(A.confirmar(m,{seq=1,actionId='ack-barrage'}));A.tocar(m,{id='STAR_PLATINUM_1',seq=1,actionId='ack-barrage',t=t})
assert(folder:GetChildren()[1]==group and #group:GetDescendants()==count,'ACK restarted residual arms')
advance(3.45)
local final=false;for _,call in stands do if call.args[2].clipe=='ora_final16'then assert(math.abs(call.at+call.args[2].impacto-(t+4.35))<.001);final=true end end
assert(final,'video finisher was not aligned at4.35')
advance(.64);assert(not voices[1].stopped,'voice ended before final')
advance(.26);assert(voices[1].stopped and #folder:GetChildren()==0,'audio/arms survived4.6')
A.tocar(m,{id='STAR_PLATINUM_1',seq=2});advance(.26);A.interromper(m);advance(.2)
assert(#folder:GetChildren()==0 and voices[#voices].stopped,'interrupt left barrage')
print('AJ16 real Acoes: residual arms/ACK continuity/finisher4.35/end4.6/interrupt PASS')
