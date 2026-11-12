-- Actual ADM module: preview click is local and reports the reviewable state.
local H=require('./harness');local R=require('@lune/roblox')
local function signal()
 local s={fns={}};function s:Connect(fn)table.insert(self.fns,fn);return {Disconnect=function()end}end
 function s:Fire(...)for _,fn in self.fns do fn(...)end end;return s
end
local playerGui=R.Instance.new('Folder');local attr=signal();local admin=false
local char=R.Instance.new('Model');local buttons={};local labels={};local calls=0;local remotes=0;local audio=0;local available=true
local plr={Character=char,WaitForChild=function()return playerGui end,GetAttribute=function()return admin end,GetAttributeChangedSignal=function()return attr end}
H.servicos.Players={LocalPlayer=plr};H.servicos.TextChatService=R.Instance.new('Folder')
local UI={CORES={vermelho=R.Color3.new(1,0,0),fundo=R.Color3.new(),verde=R.Color3.new(0,1,0)},FONTE_TEXTO=R.Enum.Font.Gotham}
function UI.botao(_,name,size,pos)local b={MouseButton1Click=signal(),Size=size,Position=pos};buttons[name]=b;return b end
function UI.frame(parent,size,pos)local f=R.Instance.new('Frame');f.Size=size;f.Position=pos;f.Parent=parent;return f end
function UI.texto(parent,txt)local l=R.Instance.new('TextLabel');l.Text=txt;l.Parent=parent;table.insert(labels,l);return l end
UI.canto=function()end;UI.borda=function()end;UI.escalaTela=function()end
local deps={Interface=UI,Animador={},Som={tocar=function()audio+=1 end},PreviaVFX14={tocar=function(owner)assert(owner==char);calls+=1;return if available then {} else false end}}
H.extras.require=function(node)return deps[node.Name] or H.require(node)end
local A=H.modulo('ReplicatedStorage/BB/Cliente/AdminCliente')
A.iniciar({OnClientEvent=signal(),FireServer=function()remotes+=1 end})
assert(buttons['PRÉVIA VFX']==nil,'preview button outside ADM panel')
admin=true;attr:Fire();local button=buttons['PRÉVIA VFX'];assert(button)
assert(button.Size==R.UDim2.fromOffset(144,30) and button.Position==R.UDim2.fromOffset(12,310))
button.MouseButton1Click:Fire();assert(calls==1 and remotes==0 and audio==0)
assert(labels[2].Text=='Prévia local SP/TW — sem dano')
available=false;button.MouseButton1Click:Fire();assert(calls==2 and remotes==0 and audio==0)
assert(string.find(labels[2].Text,'Catálogo VFX indisponível',1,true))
print('AJ14 actual ADM preview UI: admin gate, local click, position, status, unavailable fallback, zero remotes/audio OK')
