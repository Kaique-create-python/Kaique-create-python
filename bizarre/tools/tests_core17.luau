local H=require('./harness')
local function module(path)
 local node=H.arvore.ReplicatedStorage.BB[path]
 assert(node,'AJ17 missing module '..path)
 return H.require(node)
end
local P=module('Preferencias17')
local clean=P.sanitizar({camera=math.huge,efeitos=0/0,mira='true',ataque=999,layout={m1={x=9,y=-1,s=8},hack={x=.5,y=.5,s=1}}})
assert(clean.camera==nil and clean.efeitos==nil and clean.mira==nil and clean.ataque==nil)
assert(clean.layout.m1.x<=1 and clean.layout.m1.y>=0 and clean.layout.m1.s<=1.3 and not clean.layout.hack)
assert(P.mesclar(P.padrao(),{camera=16,mira=false}).camera==16)
local L=module('Layout17')
for _,v in {{568,260},{568,320},{667,375},{844,390},{1280,720},{390,844}} do
 local boxes=L.resolver(v[1],v[2],{})
 for name,a in boxes do
  assert(a.x-a.w/2>=0 and a.x+a.w/2<=v[1],name..' outside horizontal safe canvas')
  assert(a.y-a.h/2>=0 and a.y+a.h/2<=v[2],name..' outside vertical safe canvas')
 end
 assert(L.valido(boxes,v[1],v[2]),'default controls overlap or cover joystick/jump at '..v[1]..'x'..v[2])
end
local F=module('Contato17')
local me,other={},{}
local f=F.novo()
assert(not f:resolver({a=other,v=other,dano=20,t=10},me,10))
assert(not f:resolver({a=me,v=other,dano=0,congelado=true},me,10))
assert(f:resolver({a=me,v=other,tipo='parry',hitId='a',t=10},me,10).texto=='PARRY')
assert(not f:resolver({a=me,v=other,tipo='parry',hitId='a',t=10},me,10))
assert(f:resolver({a=me,v=other,tipo='quebra_guarda',hitId='b',t=10},me,10).texto=='GUARDA QUEBRADA')
assert(not f:resolver({a=me,v=other,tipo='impacto',dano=5,t=8},me,10))
print('AJ17 policies: input sanitization, safe layout, server-only feedback/dedup PASS')
