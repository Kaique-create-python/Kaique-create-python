-- Only authoritative resolved contacts produce a local status, not predictions.
local C={}
function C.novo()
 local seen={}
 return {resolver=function(_self,d,eu,now)
  if not eu or (d.a~=eu and d.v~=eu) or d.congelado or (d.t and now-d.t>1) then return nil end
  for id,expiry in seen do if expiry<=now then seen[id]=nil end end
  if d.hitId then
   local id=tostring(d.hitId)..":"..tostring(d.phase or "resolved")
   if seen[id] then return nil end
   seen[id]=now+10
  end
  local text,color,level
  if d.tipo=="parry" then text,color,level="PARRY",Color3.fromRGB(255,218,102),3
  elseif d.tipo=="quebra_guarda" then text,color,level="GUARDA QUEBRADA",Color3.fromRGB(255,126,89),4
  elseif d.tipo=="bloqueio" then text,color,level="BLOQUEADO",Color3.fromRGB(143,203,255),1
  elseif (d.dano or 0)>0 then
   local strong=(d.ragdoll or 0)>0 or d.tipo=="impacto_forte" or d.tipo=="impacto_enorme"
   text=if strong then "IMPACTO" elseif d.a==eu then "ACERTO" else "ATINGIDO"
   color=if d.a==eu then Color3.fromRGB(241,234,216) else Color3.fromRGB(255,142,142)
   level=if strong then 2 else 0
  else return nil end
  return {texto=text,cor=color,nivel=level}
 end}
end
return C
