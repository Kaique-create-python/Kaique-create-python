local H=require('./harness')
local rb=require('@lune/roblox')
local now=1
local casts=0
local ws=setmetatable({GetServerTimeNow=function()return now end,Raycast=function()casts+=1;return nil end},{__index=H.workspace})
H.extras.workspace=ws
H.extras.require=function(m)
 if m.Name=='Mapa' then return {pasta={},filtro=function()return{}end} end
 if m.Name=='Hitbox' then return {esfera=function()return{}end} end
 return H.require(m)
end
local function fixture(owner)
 now=1;casts=0
 local P=H.moduloNovo('ServerScriptService/BB_Servidor/Projeteis')
 P.lancar(owner or {},{vel=10,alcance=100},rb.Vector3.zero,rb.Vector3.new(0,0,-1),'test')
 return P
end
local function test(name,fn)fn();print('PASS '..name)end
test('B release cannot remove longer A overlay',function()
 local P=fixture();local A,B={},{}
 P.congelar(10,{},A);P.congelar(5,{},B)
 now=3;P.descongelar(5,B);P.passo(.1);assert(casts==0)
 P.descongelar(10,A);P.passo(.1);assert(casts>0)
end)
test('reverse insertion and reverse release retain remaining session',function()
 local P=fixture();local A,B={},{}
 P.congelar(5,{},B);P.congelar(10,{},A)
 now=3;P.descongelar(10,A);P.passo(.1);assert(casts==0)
 P.descongelar(5,B);P.passo(.1);assert(casts>0)
end)
test('expiry of B does not expire A; last expiry resumes',function()
 local P=fixture();P.congelar(10,{},{});P.congelar(5,{},{})
 now=5.1;P.passo(.1);assert(casts==0)
 now=10;P.passo(.1);assert(casts>0)
end)
test('equal deadlines still have distinct session owners',function()
 local P=fixture();local A,B={},{}
 P.congelar(10,{},A);P.congelar(10,{},B)
 now=3;P.descongelar(10,A);P.passo(.1);assert(casts==0)
 P.descongelar(10,B);P.passo(.1);assert(casts>0)
end)
test('owner immunity applies per overlay without removing other session',function()
 local owner={};local P=fixture(owner);local A,B={},{}
 P.congelar(10,owner,A);P.congelar(5,{},B)
 now=3;P.passo(.1);assert(casts==0)
 P.descongelar(5,B);P.passo(.1);assert(casts>0)
end)
test('legacy deadline calls preserve independent deadlines',function()
 local P=fixture();P.congelar(10,{});P.congelar(5,{})
 now=3;P.descongelar(5);P.passo(.1);assert(casts==0)
 P.descongelar(10);P.passo(.1);assert(casts>0)
end)
print('FINAL14 projectile sessions GREEN')
