-- Rectangles are in the ScreenGui safe canvas, never the full viewport.
local P=require(script.Parent.Preferencias17)
local L={}
local function overlap(a,b,gap)
 return math.abs(a.x-b.x)<(a.w+b.w)/2+(gap or 0) and math.abs(a.y-b.y)<(a.h+b.h)/2+(gap or 0)
end
function L.reservas(w,h)
 return {{x=81,y=h-77,w=162,h=154},{x=w-62,y=h-62,w=124,h=124}}
end
local function defaults(w,h)
 local defs={m1={171,64,82,82},bloq={151,163,60,60},dash={66,174,58,58},g1={310,194,72,44},g2={229,194,72,44},g3={310,140,72,44},g4={229,140,72,44},ult={254,70,58,58},stand={322,70,48,48},mira={380,70,46,46},shift={436,70,46,46},pose={380,132,44,44}}
 if w<600 and w>h then
  defs={m1={170,50,64,64},bloq={100,170,50,50},dash={40,170,50,50},g1={310,185,64,44},g2={235,185,64,44},g3={310,132,64,44},g4={235,132,64,44},ult={245,60,50,50},stand={308,65,44,44},mira={365,65,44,44},shift={170,125,44,44},pose={371,122,42,42}}
 end
 local out={}
 for name,d in defs do out[name]={x=w-d[1],y=h-d[2],w=d[3],h=d[4],s=1} end
 if w<600 and h>=w then
  local rows={{"g1","g2","g3","g4"},{"stand","ult","mira","shift"},{"pose","bloq","m1","dash"}}
  for row,names in rows do
   for col,name in names do
    local a=out[name];a.x=w*(col-.5)/4;a.y=h-360+(row-1)*82
    if name=="m1" then a.w=70;a.h=70 end
   end
  end
 end
 return out
end
function L.valido(boxes,w,h)
 local list={}
 for _,name in P.BOTOES do
  local a=boxes[name]
  if not a or a.x-a.w/2<4 or a.x+a.w/2>w-4 or a.y-a.h/2<4 or a.y+a.h/2>h-4 then return false end
  for _,r in L.reservas(w,h) do if overlap(a,r,3) then return false end end
  for _,b in list do if overlap(a,b,4) then return false end end
  table.insert(list,a)
 end
 return true
end
function L.resolver(w,h,raw)
 local out=defaults(w,h)
 local layout=P.sanitizar({layout=raw}).layout or {}
 for name,v in layout do
  local a=out[name];a.s=v.s;a.w*=v.s;a.h*=v.s
  a.x=math.clamp(v.x*w,a.w/2+5,w-a.w/2-5)
  a.y=math.clamp(v.y*h,a.h/2+5,h-a.h/2-5)
 end
 -- A saved landscape arrangement may not fit portrait. Keep the saved values,
 -- but display the safe defaults for this orientation until it fits again.
 if not L.valido(out,w,h) then return defaults(w,h) end
 return out
end
function L.serializar(boxes,w,h)
 local out={}
 for name,a in boxes do out[name]={x=a.x/w,y=a.y/h,s=a.s or 1} end
 return out
end
return L
