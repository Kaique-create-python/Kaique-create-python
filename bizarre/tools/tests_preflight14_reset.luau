-- Executa o arrumar() REAL do teste nativo com Combate/Regras/Lutadores reais.
local H=require('./harness')
local rb=require('@lune/roblox')
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local now=100
local delayed={}
H.servicos.Players={GetPlayers=function() return {} end,PlayerRemoving=H.sinalFalso()}
H.extras.workspace=setmetatable({GetServerTimeNow=function() return now end},{__index=H.workspace})
H.extras.task={delay=function(_,fn)table.insert(delayed,fn)end,spawn=function(fn)table.insert(delayed,fn)end}
local physics=setmetatable({},{__index=function()return function()end end})
H.extras.require=function(m)
 if m.Name=='Fisica' then return physics end
 if m.Name=='Mapa' then return {} end
 return H.require(m)
end
local R=H.modulo('ReplicatedStorage/BB/Regras')
local B=H.modulo('ServerScriptService/BB_Servidor/Combate')
local L=H.modulo('ServerScriptService/BB_Servidor/Lutadores')
B.iniciar({Efeito={FireAllClients=function()end},Privado={FireClient=function()end},Acao={OnServerEvent=H.sinalFalso()}},{},nil)
local arena=rb.Instance.new('Folder')
local function actor(name,pos,dir)
 local m=rb.Instance.new('Model');m.Name=name;m.Parent=arena
 local h=rb.Instance.new('Humanoid');h.Parent=m;h.MaxHealth=100;h.Health=100
 local root=rb.Instance.new('Part');root.Name='HumanoidRootPart';root.Size=rb.Vector3.new(2,2,1)
 root.CFrame=rb.CFrame.lookAt(pos,pos+dir);root.Position=pos;root.Parent=m
 local torso=rb.Instance.new('Part');torso.Name='Torso';torso.Parent=m
 return L.criar(m,nil,'STAR_PLATINUM',{bot=true})
end
local ap=rb.Vector3.new(0,3.2,45.5)
local vp=rb.Vector3.new(0,3.2,40)
local a=actor('A',ap,rb.Vector3.new(0,0,-1))
local v=actor('V',vp,rb.Vector3.new(0,0,1))
-- Only the physical repositioning boundary is supplied by the fixture.
rb.implementMethod('Model','PivotTo',function(model,cf)
 local root=model:FindFirstChild('HumanoidRootPart');root.CFrame=cf;root.Position=cf.Position
end)
local scriptText=fs.readFile('bizarre/tools/teste_nuvem14.luau')
local first=assert(scriptText:find('local function arrumar()',1,true))
local last=assert(scriptText:find('\nchecar("combo de M1"',first,true))
local arrumar=luau.load(scriptText:sub(first,last-1)..'\nreturn arrumar',{environment={
 atk=a,vit=v,A_POS=ap,V_POS=vp,Fisica=physics,Combate=B,Regras=R,
 CFrame=rb.CFrame,Vector3=rb.Vector3,Enum=rb.Enum,
 workspace=H.extras.workspace,task={wait=function(dt)now+=dt or 0 end},
}})()
B.m1(a,{})
assert(a.acao14 and a.acao14.token==a.estado.token,'setup must create real M1 context')
arrumar()
B.bloquear(v,true)
now+=.4
local blocked=B.acertar(a,v,{dano=5,tipo='melee',atordoar=.5},{dir=rb.Vector3.new(0,0,-1)})
assert(blocked=='bloqueado','native fixture after M1 reset returned '..tostring(blocked))
assert(a.acao14==nil and not a.combate14.acao,'old M1 context survived fixture reset')
print('PASS real native arrumar clears previous action; front block returns bloqueado')
B.bloquear(v,false);now+=.05;B.bloquear(v,true)
assert(B.acertar(a,v,{dano=5,tipo='melee',atordoar=.5},{dir=rb.Vector3.new(0,0,-1)})=='parry')
print('PASS real native arrumar preserves fresh parry window')
-- Cancellation must not weaken the production guard against genuinely stale actions.
local e=R.novoEstado();a.estado=e;a.acao14={token=e.token+1}
assert(B.acertar(a,v,{dano=5,tipo='melee'}, {})=='nada')
print('PASS production still rejects stale action tokens')
