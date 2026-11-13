local BB=game:GetService("ReplicatedStorage"):WaitForChild("BB")
local Policy=require(BB.Laboratorio17)
local T={}
function T.novo(deps,remote)
 local sessions={};local rates={};local service={}
 local function eligible(player)
  local l=deps.Lutadores.doJogador(player);local area=deps.Mapa.treino()
  if not l or not area or not l.modelo.Parent or l.hum.Health<=0 or player:GetAttribute("BB_Modo")~="treino"then return nil end
  if (l.raiz.Position-area.spawn.Position).Magnitude>90 then return nil end
  return l,area
 end
 local function report(player,s,errorText)
  if player.Parent then remote:FireClient(player,{tipo="estado",erro=errorText,modo=s and s.policy.modo or "parado",hits=s and s.policy.hits or 0,dano=s and s.policy.dano or 0,janela=s and s.policy.janela or false,alvo=s and s.target.modelo or nil})end
 end
 function service:limpar(player)
  local rate=rates[player];if rate then rate.request=(rate.request or 0)+1 end
  local s=sessions[player];if not s then return end
  sessions[player]=nil
  if deps.Combate.cancelar then deps.Combate.cancelar(s.target)end
  deps.Lutadores.remover(s.target.modelo);s.target.modelo:Destroy()
 end
 function service:receber(player,data)
  if type(data)~="table"then return end
  local t=deps.agora();local r=rates[player]or{last=-math.huge,reset=-math.huge};rates[player]=r
  if t-r.last<.3 then return end;r.last=t
  local owner,area=eligible(player)
  if not owner then self:limpar(player);report(player,nil,"Entre na área de treino.");return end
  if data.tipo=="estado"then report(player,sessions[player]);return end
  if data.tipo~="configurar"and data.tipo~="reiniciar"then return end
  if data.tipo=="configurar"and not Policy.modo(data.modo)then return end
  local old=sessions[player]
  if data.tipo=="configurar"and old then
   old.policy.modo=data.modo;old.policy.pendente=false
   deps.Combate.bloquear(old.target,false);report(player,old);return
  end
  if t-r.reset<2 then return end
  r.reset=t
  local mode=if data.tipo=="configurar"then data.modo else(old and old.policy.modo or "parado")
  self:limpar(player)
  r.request=(r.request or 0)+1;local request=r.request;local generation=owner.geracao14
  local cf=area.bonecos[1]or area.spawn*CFrame.new(0,0,-12)
  -- Own target has a deterministic lane; never teleport or reset a PvP fighter.
  cf+=Vector3.new(0,0,(player.UserId%4)*7-10.5)
  local target=deps.Bots.criarLaboratorio17(player,cf)
  if not target then report(player,nil,"Não foi possível preparar o alvo.");return end
  if rates[player]~=r or r.request~=request or owner.geracao14~=generation or eligible(player)~=owner then
   deps.Lutadores.remover(target.modelo);target.modelo:Destroy();return
  end
  sessions[player]={owner=owner,target=target,policy=Policy.novo(mode),lastReport=-math.huge}
  report(player,sessions[player])
 end
 function service:contato(atk,target,data)
  local player=target.laboratorioDono17;local s=player and sessions[player]
  if not s or s.target~=target or atk~=s.owner or data.congelado then return end
  local now=deps.agora()
  Policy.contato(s.policy,now,data.dano or 0,target.estado)
  if now-s.lastReport>=.1 then s.lastReport=now;report(player,s)end
 end
 function service:passo()
  local now=deps.agora()
  for player,s in sessions do
   local owner=eligible(player)
   if owner~=s.owner or not s.target.modelo.Parent or s.target.hum.Health<=0 then self:limpar(player)
   else
    local b=s.target;local e=b.estado
    local action=Policy.reacao(s.policy,e,now)
    if action then
     local delta=owner.raiz.Position-b.raiz.Position
     if delta.Magnitude>.1 then
      local flat=Vector3.new(delta.X,0,delta.Z)
      if flat.Magnitude>.1 then b.raiz.CFrame=CFrame.lookAt(b.raiz.Position,b.raiz.Position+flat);b.dir=flat.Unit;b.dirT=now end
     end
     if action=="bloquear"then deps.Combate.bloquear(b,true)
     elseif action=="evasiva"then deps.Combate.evasiva(b)
     elseif action=="contra"then deps.Combate.m1(b,{})end
    end
   end
  end
 end
 function service:remover(player)self:limpar(player);rates[player]=nil end
 return service
end
function T.iniciar(remote,deps)
 deps.agora=deps.agora or function()return workspace:GetServerTimeNow()end
 local service=T.novo(deps,remote)
 remote.OnServerEvent:Connect(function(player,data)service:receber(player,data)end)
 game:GetService("Players").PlayerRemoving:Connect(function(player)service:remover(player)end)
 local dt=0
 game:GetService("RunService").Heartbeat:Connect(function(step)
  dt+=step;if dt<.05 then return end;dt=0;service:passo()
 end)
 return service
end
return T
