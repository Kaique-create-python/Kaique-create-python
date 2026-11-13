local H=require('./harness');local R=require('@lune/roblox')
local function signal()
 local s={listeners={}}
 function s:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(self.listeners,{fn,c});return c end
 function s:Fire(...)for _,pair in self.listeners do if pair[2].Connected then pair[1](...)end end end
 return s
end
local signals={}
for _,name in {'InputBegan','Activated'}do
 R.implementProperty('TextButton',name,function(obj)
  signals[obj]=signals[obj]or{};signals[obj][name]=signals[obj][name]or signal();return signals[obj][name]
 end)
end
R.implementProperty('GuiBase2d','AbsoluteSize',function(obj)return R.Vector2.new(obj.Size.X.Offset,obj.Size.Y.Offset)end)
local root=R.Instance.new('Frame');root.Size=R.UDim2.fromOffset(844,390);root.AbsoluteSize=R.Vector2.new(844,390)
local L=H.modulo('ReplicatedStorage/BB/Layout17');local boxes=L.resolver(844,390,{})
local buttons={}
for name,a in boxes do local b=R.Instance.new('TextButton');b.Name=name;b.Parent=root;b.Size=R.UDim2.fromOffset(a.w,a.h);b.Position=R.UDim2.fromOffset(a.x-a.w/2,a.y-a.h/2);buttons[name]=b end
local input={InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal()}
H.servicos.UserInputService=input
local committed=0;local pref={layout={}};local starts=0;local stops=0
local UI={CORES={fundo=R.Color3.new(),roxo=R.Color3.new()}}
function UI.frame(parent,size,pos,color,alpha)local b=R.Instance.new('Frame');b.Size=size;b.Position=pos;b.Parent=parent;return b end
function UI.texto(parent,text,size,pos,_)local b=R.Instance.new('TextLabel');b.Text=text;b.Size=size;b.Position=pos;b.Parent=parent;return b end
function UI.botao(parent,text,size,pos,_color,_opts)local b=R.Instance.new('TextButton');b.Text=text;b.Size=size;b.Position=pos;b.Parent=parent;return b end
function UI.canto()end
local deps={Interface=UI,PreferenciasCliente17={valores=function()return pref end,definir=function(p)pref=p;committed+=1 end}}
H.extras.require=function(n)return deps[n.Name]or H.require(n)end
local E=H.modulo('ReplicatedStorage/BB/Cliente/EditorToques17').novo(root,buttons,function()starts+=1 end,function()stops+=1 end)
local function click(text)
 for _,b in root:GetDescendants()do if b:IsA('TextButton')and b.Text==text then b.Activated:Fire();return end end
 error('missing editor action '..text)
end
local function drag(delta)
 local obj={UserInputType=R.Enum.UserInputType.Touch,Position=R.Vector3.new(100,100,0)}
 buttons.m1.InputBegan:Fire(obj)
 obj.Position+=delta;input.InputChanged:Fire(obj);input.InputEnded:Fire(obj)
end
local original=buttons.m1.Position
E:abrir();assert(E.aberto and starts==1)
drag(R.Vector3.new(-6,-2,0));assert(buttons.m1.Position~=original)
click('CANCELAR');assert(not E.aberto and committed==0 and buttons.m1.Position==original,'cancel mutated saved layout or left live layout changed')
E:abrir();drag(R.Vector3.new(-6,-2,0));click('SALVAR')
assert(committed==1 and pref.layout.m1.x<boxes.m1.x/844,'save did not commit normalized position')
E:abrir();local valid=buttons.m1.Position
drag(R.Vector3.new(-650,40,0));assert(buttons.m1.Position==valid,'editor allowed button inside joystick/another button')
input.WindowFocusReleased:Fire();assert(not E.aberto and committed==1,'lost focus saved unfinished drag')
E:abrir();E:destruir();assert(not E.aberto and starts==stops)
print('AJ17 real touch editor: drag, save, cancel, reserved areas, focus and cleanup PASS')
