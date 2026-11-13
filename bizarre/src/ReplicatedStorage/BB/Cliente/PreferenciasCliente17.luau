local Schema=require(script.Parent.Parent.Preferencias17)
local P={}
local values=Schema.padrao()
local dirty={}
local remote=nil
local ready=false
local listeners={}
local ticket=0
local function notify()for _,fn in listeners do fn(Schema.mesclar(values,{}))end end
function P.observar(fn)table.insert(listeners,fn);fn(Schema.mesclar(values,{}))end
function P.valores()return Schema.mesclar(values,{})end
local function queue()
 ticket+=1;local mine=ticket
 task.delay(1,function()
  if mine==ticket and ready and remote and next(dirty)then
   local patch=dirty;dirty={};remote:FireServer({tipo="salvar",valores=patch})
  end
 end)
end
function P.definir(patch)
 for k,v in Schema.sanitizar(patch)do values[k]=v;dirty[k]=v end
 notify();queue()
end
function P.iniciar(event)
 if remote then return end
 remote=event
 remote.OnClientEvent:Connect(function(data)
  if type(data)~="table"then return end
  if data.tipo=="estado"and data.pronto and not ready then
   values=Schema.mesclar(data.valores,dirty);ready=true;notify();queue()
  end
 end)
 -- Subscribe first; a fast server response cannot race this listener.
 task.spawn(function()
  for _=1,4 do
   if ready then return end
   remote:FireServer({tipo="ler"});task.wait(3)
  end
 end)
end
return P
