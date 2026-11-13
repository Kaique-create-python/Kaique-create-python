-- Independent of the statistics store. Failed loads never authorize a write.
local Schema=require(game:GetService("ReplicatedStorage"):WaitForChild("BB"):WaitForChild("Preferencias17"))
local P={}
function P.novo(store,remote)
 local sessions={}
 local service={}
 local function send(player,s,kind)
  if player.Parent then remote:FireClient(player,{tipo=kind or "estado",pronto=s.loaded,valores=Schema.mesclar(Schema.padrao(),s.values)})end
 end
 function service:carregar(player)
  local s=sessions[player]
  if s and (s.loaded or s.loading)then if s.loaded then send(player,s)end;return end
  s=s or {values={},dirty={},loaded=false,saving=false,last=-math.huge};sessions[player]=s;s.loading=true
  local ok,value=pcall(function()return store:GetAsync("u_"..player.UserId)end)
  s.loading=false
  if sessions[player]~=s then return end
  if ok then s.values=Schema.mesclar(Schema.padrao(),value);s.loaded=true end
  send(player,s)
 end
 function service:alterar(player,raw)
  local s=sessions[player]
  if not s or not s.loaded then return false end
  local patch=Schema.sanitizar(raw)
  if next(patch)==nil then return false end
  for k,v in patch do s.values[k]=v;s.dirty[k]=v end
  return true
 end
 function service:salvar(player)
  local s=sessions[player]
  if not s or not s.loaded or s.saving or next(s.dirty)==nil then return end
  s.saving=true
  local patch=s.dirty;s.dirty={}
  local ok=pcall(function()
   store:UpdateAsync("u_"..player.UserId,function(old)
    local out=if type(old)=="table" then table.clone(old)else {}
    for k,v in patch do out[k]=v end
    return out
   end)
  end)
  s.saving=false
  if not ok then for k,v in patch do if s.dirty[k]==nil then s.dirty[k]=v end end end
  if ok then send(player,s,"salvo")end
 end
 function service:receber(player,data)
  if type(data)~="table"then return end
  local s=sessions[player];local now=os.clock()
  if s and now-s.last<.25 then return end
  if s then s.last=now end
  if data.tipo=="ler"then
   self:carregar(player)
  elseif data.tipo=="salvar"and self:alterar(player,data.valores)then
   -- One trailing write for a burst of button moves/settings changes.
   s=sessions[player];s.version=(s.version or 0)+1;local version=s.version
   task.delay(3,function()if sessions[player]==s and s.version==version then self:salvar(player)end end)
  end
 end
 function service:remover(player)
  local s=sessions[player];if not s then return end
  local deadline=os.clock()+8
  repeat
   if not s.saving then self:salvar(player)end
   if not s.saving and next(s.dirty)==nil then break end
   task.wait(.2)
  until os.clock()>=deadline
  sessions[player]=nil
 end
 function service:todos()for player in sessions do task.spawn(function()self:salvar(player)end)end end
 return service
end
function P.iniciar(remote)
 local Players=game:GetService("Players")
 local ds=game:GetService("DataStoreService"):GetDataStore("BB_Preferencias_v1")
 local service=P.novo(ds,remote)
 remote.OnServerEvent:Connect(function(player,data)service:receber(player,data)end)
 Players.PlayerRemoving:Connect(function(player)service:remover(player)end)
 task.spawn(function()while true do task.wait(45);service:todos()end end)
 game:BindToClose(function()
  local pending=0
  for _,player in Players:GetPlayers()do pending+=1;task.spawn(function()service:remover(player);pending-=1 end)end
  local deadline=os.clock()+10;while pending>0 and os.clock()<deadline do task.wait(.1)end
 end)
 return service
end
return P
