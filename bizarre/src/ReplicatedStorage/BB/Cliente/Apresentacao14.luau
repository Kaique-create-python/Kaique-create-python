-- AJ14: a single routing boundary. Optional catalog absence keeps AJ13 playable.
local RS = game:GetService("ReplicatedStorage")
local Receitas = require(script.Parent.Parent:WaitForChild("VFXReceitas"))
local handles = setmetatable({}, {__mode="k"})
local Piloto = require(script.Parent:WaitForChild("VFXPiloto"))
local A = {}
local avisado = false
local verificado: Instance? = nil
function A.suporta(id: string?): boolean
 return Piloto.suporta(id)
end
function A.disponivel(id: string?): boolean
 if not Piloto.suporta(id) then return false end
 local catalogo=RS:FindFirstChild("BB_VFXCatalogo14")

 if catalogo then
  local completo=true
  for root,names in Receitas.catalogos(id) do
   local c=RS:FindFirstChild(root)
   for name in names do if not c or not c:FindFirstChild(name)then completo=false;break end end
  end
  if completo then return true end
 end
 if not avisado then
  avisado = true
  warn("[BB DIAG] AJ14 catálogo opcional ausente/incompleto; usando VFX AJ13")
  pcall(function() workspace:SetAttribute("BB_VFX14Diag", "catálogo ausente/incompleto; reserva AJ13") end)
 end
 return false
end
function A.contexto(owner: Model?, d: any?, pos: Vector3?): any
 d = d or {}
 local r = owner and owner:FindFirstChild("HumanoidRootPart") :: BasePart?
 return {owner=owner, target=d.v or d.alvo, pos=pos or d.pos or (r and r.Position),
  dir=d.dir or (r and r.CFrame.LookVector), actionId=d.actionId,
  hitId=if d.hitId then tostring(d.hitId)..":"..tostring(d.phase or "resolved") else nil,
  t=d.t, dur=d.dur, radius=d.raio, speed=d.vel, above=d.acima, destination=if typeof(d.alvo)=="Vector3"then d.alvo else nil, formar=d.formar,cair=d.cair, variant=d.variant or d.variante, n=d.n}
end
function A.tocar(id: string?, move: string, phase: string, ctx: any): boolean
 if not A.disponivel(id) then return false end
 if not Receitas.resolve(id,move,phase,ctx) then return false end
 local ok, err = pcall(Piloto.tocar, id, move, phase, ctx)
 if ok and err and ctx.owner then
  local list=handles[ctx.owner] or {};handles[ctx.owner]=list
  for i = #list, 1, -1 do if list[i].cancelled or not list[i].active then table.remove(list,i) end end
  table.insert(list,err)
 end
 if not ok then warn("[BB DIAG] AJ14 VFX: "..tostring(err));return false end
 return true,err
end
function A.associar(owner: Model, anterior: string, actionId: string)
 for _, handle in handles[owner] or {} do
  if handle.ctx and handle.ctx.actionId==anterior then handle.ctx.actionId=actionId end
 end
end
function A.cancelar(owner: Model?, actionId: string?)
 Piloto.cancelar(owner,actionId)
 if owner then
  if actionId==nil then handles[owner]=nil else
   local list=handles[owner] or {}
   for i = #list, 1, -1 do
    local h=list[i]
    if h.cancelled or (h.ctx and h.ctx.actionId==actionId) then table.remove(list,i) end
   end
  end
 elseif actionId==nil then table.clear(handles) end
end
function A.congelar(sessionId: any, owner: Model?, fim: number) Piloto.congelar(sessionId,owner,fim) end
function A.descongelar(sessionId: any) Piloto.descongelar(sessionId) end
function A.estadoProjetil(owner,actionId,d)Piloto.estadoProjetil(owner,actionId,d)end
function A.iniciar() Piloto.iniciar() end
return A
