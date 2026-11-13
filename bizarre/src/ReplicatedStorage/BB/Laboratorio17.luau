local Regras=require(script.Parent.Regras)
local T={}
local MODES={parado=true,bloquear=true,evasiva=true,contra=true}
function T.permite(atk,alvo)
 if alvo.laboratorioDono17 and atk.jogador~=alvo.laboratorioDono17 then return false end
 if atk.laboratorioDono17 and alvo.jogador~=atk.laboratorioDono17 then return false end
 return true
end
function T.modo(value)return type(value)=="string" and MODES[value]==true end
function T.novo(mode)return {modo=if T.modo(mode)then mode else "parado",hits=0,dano=0,janela=false,pendente=false}end
local function lock(e)return math.max(e.stunAte or 0,e.ragdollAte or 0,e.congeladoAte or 0,e.pedraAte or 0,e.acaoAte or 0)end
function T.contato(s,now,damage,e)
 if damage<=0 then return end
 local old=s.estadoAnterior
 local escapeAt=old and math.max(s.ultimo or now,old.evasivaPronta or 0,old.congeladoAte or 0)
 local couldEscape=old and escapeAt<now and Regras.podeEvasiva(old,escapeAt)
 s.janela=s.hits>0 and (now>=(s.lockAte or 0)or couldEscape==true)
 s.hits+=1;s.dano+=damage;s.ultimo=now
 s.lockAte=lock(e)
 s.estadoAnterior={stunAte=e.stunAte,ragdollAte=e.ragdollAte,congeladoAte=e.congeladoAte,evasivaPronta=e.evasivaPronta,semRecarga=e.semRecarga}
 s.pendente=s.modo~="parado"
end
function T.reacao(s,e,now)
 if not s.pendente then return nil end
 if now-(s.ultimo or 0)>5 then s.pendente=false;return nil end
 if s.modo=="evasiva"then
  if Regras.podeEvasiva(e,now)then s.pendente=false;return "evasiva"end
 elseif not Regras.atordoado(e,now)and now>=lock(e)then
  s.pendente=false;return s.modo
 end
 return nil
end
return T
