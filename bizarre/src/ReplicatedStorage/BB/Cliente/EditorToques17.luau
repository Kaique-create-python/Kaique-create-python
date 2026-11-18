local Input=game:GetService("UserInputService")
local UI=require(script.Parent.Interface)
local L=require(script.Parent.Parent.Layout17)
local Pref=require(script.Parent.PreferenciasCliente17)
local Editor={}
function Editor.novo(root,buttons,aoAbrir,aoFechar)
 local obj={aberto=false}
 local work={};local previous={};local selected="m1";local dragging=nil
 local bar=nil;local status=nil;local scrim=nil
 local connections={}
 local function dims()return root.AbsoluteSize.X,root.AbsoluteSize.Y end
 local function apply()
  for name,a in work do
   local b=buttons[name]
   if b then b.Position=UDim2.fromOffset(a.x-a.w/2,a.y-a.h/2);b.Size=UDim2.fromOffset(a.w,a.h)end
  end
  if status then status.Text="ARRASTE UM BOTÃO  ·  "..string.upper(selected)end
 end
 local function close(save)
  if not obj.aberto then return end
  dragging=nil;obj.aberto=false
  if bar then bar:Destroy();bar=nil;status=nil end
  if scrim then scrim:Destroy();scrim=nil end
  if save then
   local w,h=dims();Pref.definir({layout=L.serializar(work,w,h)})
  else work=previous;apply()end
  aoFechar()
 end
 function obj:abrir()
  if self.aberto then return end
  local w,h=dims();if w<200 or h<200 then return end
  self.aberto=true;aoAbrir()
  work=L.resolver(w,h,Pref.valores().layout)
  previous={};for name,a in work do previous[name]=table.clone(a)end
  scrim=UI.frame(root,UDim2.fromScale(1,1),UDim2.new(),Color3.fromRGB(9,8,16),.45)
  scrim.Active=true;scrim.ZIndex=0
  bar=UI.frame(root,UDim2.new(1,-16,0,94),UDim2.fromOffset(8,6),UI.CORES.fundo,.05)
  bar.ZIndex=30;UI.canto(bar,8)
  status=UI.texto(bar,"",UDim2.new(1,-12,0,25),UDim2.fromOffset(6,2),{z=32,limite=14})
  local defs={{"SALVAR",function()close(true)end},{"CANCELAR",function()close(false)end},{"PADRÃO",function()local x,y=dims();work=L.resolver(x,y,{});apply()end},{"MENOR",function()self:tamanho(-.1)end},{"MAIOR",function()self:tamanho(.1)end}}
  for i,d in defs do
   local b=UI.botao(bar,d[1],UDim2.new(.2,-8,0,48),UDim2.new((i-1)*.2,4,0,36),if i==1 then UI.CORES.roxo else Color3.fromRGB(43,41,57),{z=32,limite=14,raio=6})
   b.Activated:Connect(d[2])
  end
  apply()
 end
 function obj:tamanho(delta)
  if not self.aberto then return end
  local a=work[selected];local before=table.clone(a)
  local size=math.clamp(a.s+delta,.8,1.3)
  a.w=a.w/a.s*size;a.h=a.h/a.s*size;a.s=size
  local w,h=dims()
  if not L.valido(work,w,h)then work[selected]=before;status.Text="SEM ESPAÇO PARA ESSE TAMANHO"else apply()end
 end
 for name,b in buttons do
  table.insert(connections,b.InputBegan:Connect(function(input)
   if not obj.aberto or dragging then return end
   if input.UserInputType~=Enum.UserInputType.Touch and input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
   selected=name
   dragging={input=input,mouse=input.UserInputType==Enum.UserInputType.MouseButton1,start=Vector2.new(input.Position.X,input.Position.Y),box=table.clone(work[name])}
   apply()
  end))
 end
 table.insert(connections,Input.InputChanged:Connect(function(input)
  local d=dragging
  if not d or (input~=d.input and not(d.mouse and input.UserInputType==Enum.UserInputType.MouseMovement))then return end
  local shift=Vector2.new(input.Position.X,input.Position.Y)-d.start;local a=work[selected];local w,h=dims()
  a.x=math.clamp(d.box.x+shift.X,a.w/2+5,w-a.w/2-5)
  a.y=math.clamp(d.box.y+shift.Y,a.h/2+5,h-a.h/2-5);apply()
 end))
 table.insert(connections,Input.InputEnded:Connect(function(input)
  local d=dragging
  if not d or (input~=d.input and not(d.mouse and input.UserInputType==Enum.UserInputType.MouseButton1))then return end
  local w,h=dims()
  if not L.valido(work,w,h)then work[selected]=d.box;apply();status.Text="DEIXE ESPAÇO ENTRE OS BOTÕES E O PULO"end
  dragging=nil
 end))
 table.insert(connections,Input.WindowFocusReleased:Connect(function()if obj.aberto then close(false)end end))
 function obj:destruir()
  close(false)
  for _,c in connections do c:Disconnect()end
  table.clear(connections)
 end
 return obj
end
return Editor
