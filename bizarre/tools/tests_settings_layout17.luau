-- Invoke the production settings builder; only UI/service boundaries are controlled.
local H=require('./harness');local R=require('@lune/roblox')
local function signal()return{Connect=function()return{Disconnect=function()end}end}end
R.implementProperty('TextButton','MouseButton1Click',signal)
R.implementProperty('TextButton','Activated',signal)
H.servicos.UserInputService={TouchEnabled=true}
H.servicos.Players={LocalPlayer={Character={}}}
local UI={CORES={fundo=R.Color3.new(),roxo=R.Color3.new(),dourado=R.Color3.new(),vermelho=R.Color3.new()}}
function UI.frame(parent,size,pos,color,alpha)local f=R.Instance.new('Frame');f.Size=size;f.Position=pos;f.Parent=parent;return f end
function UI.texto(parent,text,size,pos,_)local f=R.Instance.new('TextLabel');f.Text=text;f.Size=size;f.Position=pos;f.Parent=parent;return f end
function UI.botao(parent,text,size,pos,_color,_opt)
 local f=R.Instance.new('TextButton');f.Name=text;f.Text=text;f.Size=size;f.Position=pos;f.Parent=parent
 local t=R.Instance.new('TextLabel');t.Name='Rotulo';t.Parent=f;return f
end
function UI.canto()end;function UI.borda()end
local deps={Interface=UI,Som={},Efeitos={},Camera={},PreferenciasCliente17={}}
H.extras.require=function(n)return deps[n.Name]or H.require(n)end
local node=H.arvore.ReplicatedStorage.BB.Cliente.Menu
node.fonte=node.fonte:gsub('return Menu%s*$',[[function Menu._layoutTeste(root) conteudo=root;criarAjustes(function()end);return painelAjustes end
return Menu]])
local M=H.require(node)
local root=R.Instance.new('Frame');root.Size=R.UDim2.fromOffset(1100,600)
local panel=M._layoutTeste(root);local edit=assert(panel:FindFirstChild('EDITAR BOTÕES'));local close=assert(panel:FindFirstChild('FECHAR'))
local height=panel.Size.Y.Offset
local function top(b)return b.Position.Y.Scale*height+b.Position.Y.Offset end
assert(top(edit)+edit.Size.Y.Offset+8<=top(close),'EDITAR BOTÕES overlaps FECHAR in the actual settings builder')
print('AJ17 production settings layout: edit/close distinct and in bounds PASS')
