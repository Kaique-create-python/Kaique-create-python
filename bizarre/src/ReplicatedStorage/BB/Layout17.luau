-- Rectangles are in the ScreenGui safe canvas, never the full viewport.
local P=require(script.Parent.Preferencias17)
local L={}
local function overlap(a,b,gap)
 return math.abs(a.x-b.x)<(a.w+b.w)/2+(gap or 0) and math.abs(a.y-b.y)<(a.h+b.h)/2+(gap or 0)
end
-- Controles do Roblox ficam grandes quando o lado curto da área segura passa de 500 px
-- (pulo 120 px a 50/90 da borda; joystick 148 px): então a reserva cresce junto.
local function grande(w,h)return math.min(w,h)>500 end
function L.reservas(w,h)
 if grande(w,h) then return {{x=107.5,y=h-97.5,w=215,h=195},{x=w-85,y=h-105,w=170,h=210}} end
 return {{x=81,y=h-77,w=162,h=154},{x=w-62,y=h-62,w=124,h=124}}
end
-- AJUSTE-19 (layout de celular): golpes 1-4 numa fileira embaixo no meio (perto do polegar direito,
-- longe do centro da luta), ATACAR/DEFESA/DASH em volta do pulo, DESPERTAR e os botões pouco usados
-- (STAND, MIRA, SHIFT LOCK, POSE) numa fileira no canto de cima à direita. Telas pequenas: grade 2x2.
local function defaults(w,h)
 local out={}
 local function por(name,x,y,bw,bh)out[name]={x=x,y=y,w=bw,h=bh or bw,s=1}end
 if w<600 and w>h then
  por("m1",w-170,h-50,64);por("bloq",w-170,h-130,48);por("dash",w-50,h-160,46);por("ult",w-50,30,46)
  for i,name in {"stand","mira","shift","pose"} do por(name,w-100-(i-1)*46,30,40) end
  local cw,ch=62,40
  local xr=w-241;local xl=xr-cw-6
  por("g1",xl,h-72,cw,ch);por("g2",xr,h-72,cw,ch);por("g3",xl,h-26,cw,ch);por("g4",xr,h-26,cw,ch)
 elseif w<600 then
  -- retrato: as fileiras de baixo para cima são montadas no fim
  por("m1",0,0,70);por("bloq",0,0,48);por("dash",0,0,46);por("ult",0,0,46)
  for _,name in {"stand","mira","shift","pose"} do por(name,0,0,40) end
  for i=1,4 do por("g"..i,0,0,62,40) end
 elseif grande(w,h) then
  por("m1",w-230,h-70,92);por("bloq",w-220,h-178,66);por("dash",w-85,h-250,62);por("ult",w-60,40,60)
  for i,name in {"stand","mira","shift","pose"} do por(name,w-130-(i-1)*56,40,48) end
  local esq,dir=225,w-230-46-16
  local cw=math.clamp((dir-esq-3*10)/4,46,92)
  for i=1,4 do por("g"..i,dir-(4-i)*(cw+10)-cw/2,h-34,cw,52) end
 else
  por("m1",w-170,h-62,80);por("bloq",w-150,h-160,58);por("dash",w-62,h-172,56)
  local topo=math.min(34,h-200)
  por("ult",w-62,math.max(31,topo),54)
  for i,name in {"stand","mira","shift","pose"} do por(name,w-124-(i-1)*52,math.max(26,topo),44) end
  local esq,dir=172,w-170-40-14 -- folga para arrastar o ATACAR no editor
  local cw=math.clamp((dir-esq-3*8)/4,46,80)
  for i=1,4 do por("g"..i,dir-(4-i)*(cw+8)-cw/2,h-29,cw,46) end
 end
 if w<600 and h>=w then
  local rows={{"g1","g2","g3","g4"},{"stand","ult","mira","shift"},{"pose","bloq","m1","dash"}}
  for row,names in rows do
   for col,name in names do
    local a=out[name];a.x=w*(col-.5)/4;a.y=h-360+(row-1)*82
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
