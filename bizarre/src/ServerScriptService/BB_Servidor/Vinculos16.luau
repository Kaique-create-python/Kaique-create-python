-- Established effects belong to an actor generation, not its next attack token.
local RunService = game:GetService("RunService")
local Fisica = require(script.Parent.Fisica)
local Lutadores = require(script.Parent.Lutadores)
local V = {}
local leases = {}
local liberar = {}
local escritos = setmetatable({}, {__mode="k"})
local connection = nil

function V.capturar(lut)
 return {lut=lut,model=lut.modelo,hum=lut.hum,root=lut.raiz,estado=lut.estado,generation=lut.geracao14,stand=lut.standId}
end
function V.vigente(ref,lut)
 local actor=ref and ref.lut
 return actor~=nil and (not lut or actor==lut) and actor.modelo==ref.model
  and actor.hum==ref.hum and actor.raiz==ref.root and actor.estado==ref.estado
  and actor.geracao14==ref.generation and actor.standId==ref.stand
  and ref.model.Parent~=nil and ref.hum.Parent==ref.model and ref.hum.Health>0
  and ref.root.Parent==ref.model and Lutadores.de(ref.model)==actor
end
function V.podeSoltar(lut,t)
 t=t or workspace:GetServerTimeNow()
 return not lut.agarradoPor and t>=(lut.estado.congeladoAte or 0)
  and not (lut.sessaoTempo and lut.sessaoTempo.ativa)
  and t>=(lut.modelo:GetAttribute("BB_Preso")or 0)
  and t>=(lut.modelo:GetAttribute("BB_Pedra")or 0)
end
local function atributo(model,attr)
 local deadline=nil
 for lease in leases do
  if lease.target.model==model and lease.attr==attr then deadline=math.max(deadline or 0,lease.ate)end
 end
 local previous=escritos[model]or{}
 if deadline or model:GetAttribute(attr)==previous[attr]then model:SetAttribute(attr,deadline)end
 previous[attr]=deadline;escritos[model]=previous
end
function V.soltar(lease)
 if not lease or not leases[lease]then return end
 leases[lease]=nil;lease.active=false
 atributo(lease.target.model,lease.attr)
 if lease.hold then liberar[lease.target.lut]=lease.target.root end
 if lease.cleanup then lease.cleanup()end
end
local function criar(dono,alvo,dur,attr,hold,cleanup)
 local lease={owner=V.capturar(dono),target=V.capturar(alvo),ate=workspace:GetServerTimeNow()+dur,attr=attr,hold=hold,active=true,cleanup=cleanup}
 leases[lease]=true
 atributo(alvo.modelo,attr)
 if hold then Fisica.prender(alvo)end
 return lease
end
function V.prender(dono,alvo,dur,attr,cleanup)return criar(dono,alvo,dur,attr,true,cleanup)end
function V.marcar(dono,alvo,dur,attr)return criar(dono,alvo,dur,attr,false)end
function V.passo()
 local t=workspace:GetServerTimeNow()
 local ended={}
 for lease in leases do
  if t>lease.ate or not V.vigente(lease.owner)or not V.vigente(lease.target)then table.insert(ended,lease)end
 end
 for _,lease in ended do V.soltar(lease)end
 for lut,root in liberar do
  if lut.raiz~=root or not root.Parent then liberar[lut]=nil
  elseif V.podeSoltar(lut,t)then Fisica.soltar(lut);liberar[lut]=nil end
 end
end
function V.iniciar()
 if not connection then connection=RunService.Heartbeat:Connect(V.passo)end
end
return V
