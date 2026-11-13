-- Execute the actual startup script; service/UI boundaries are controlled signals.
local H=require('./harness');local R=require('@lune/roblox')
local function signal()
 local s={fns={}};function s:Connect(fn)table.insert(self.fns,fn);return {Disconnect=function()end}end
 function s:Fire(...)for _,fn in self.fns do fn(...)end end;return s
end
local events={};local function mark(name,...)table.insert(events,{name,...})end
local gui=R.Instance.new('ScreenGui');local playerGui=R.Instance.new('Folder')
local hum={Died=signal()};local character={WaitForChild=function()return hum end}
local plr={Character=character,CharacterAdded=signal(),CharacterRemoving=signal(),SetAttribute=function()end,WaitForChild=function()return playerGui end}
local rem={};for _,n in {'Acao','Efeito','Privado','Entrar','Admin','Preferencias','Treino'}do rem[n]={OnClientEvent=signal()}end
local remFolder={WaitForChild=function(_,n)return rem[n]end}
H.servicos.Players={LocalPlayer=plr};H.servicos.StarterGui={SetCoreGuiEnabled=function()end}
local run={RenderStepped=signal(),Heartbeat=signal()};H.servicos.RunService=run
H.servicos.UserInputService={WindowFocusReleased=signal()}
H.servicos.ReplicatedStorage={WaitForChild=function(_,name)return if name=='BB' then H.arvore.ReplicatedStorage.BB else remFolder end}
H.extras.workspace={GetAttribute=function()return true end}
H.extras.task={spawn=function(fn,...)fn(...)end,wait=function()error('unexpected startup waiting')end}
local opened=false
local button={MouseButton1Click=signal()}
local function noop()end
local generic=setmetatable({},{__index=function()return noop end})
local deps={
 Som=generic,Animador=setmetatable({assumirPersonagem=function(c)assert(c==character);mark('assume')end},{__index=function()return noop end}),
 Camera=generic,HUD=setmetatable({gui=function()return gui end},{__index=function()return noop end}),
 Efeitos=setmetatable({limparDono=function(c)mark('clean',c)end},{__index=function()return noop end}),
 StandVisual={iniciar=noop,donos=function()return {}end},
 Acoes={interromper=function(c)mark('cancel',c)end,concluir=function(c,d)mark('end',c,d)end,tocar=noop},
 Jogador={iniciar=noop,soltarEntradas=function()mark('release')end},
 Controles={iniciar=noop,ativar=noop,editar=noop,editando=function()return false end,soltarTudo=function()mark('controls-release')end},
 Menu={iniciar=noop,aberto=function()return opened end,abrir=function()opened=true end},
 PreferenciasCliente17={iniciar=function(r)assert(r==rem.Preferencias);mark("prefs-init")end},
 LaboratorioCliente17={iniciar=function(r)assert(r==rem.Treino);mark("training-init")end},
 AdminCliente=generic,Interface={escalaTela=noop,botao=function()return button end,CORES={roxo=R.Color3.new()}},
 Cinematica={iniciar=noop,cancelar=function()mark('cinema-cancel')end},
 Apresentacao14={iniciar=function()mark('vfx-init')end},AmbienteVisual14={iniciar=function()mark('environment-init')end},
}
H.extras.require=function(node)return deps[node.Name] or H.require(node)end
H.modulo('StarterPlayerScripts/Main')
assert(events[1][1]=='environment-init' and events[2][1]=='vfx-init')
local finish={quem=character,actionId='old-action',seq=1,reason='concluida'}
rem.Efeito.OnClientEvent:Fire('acaoFim',finish)
assert(events[#events][1]=='end' and events[#events][3]==finish,'acaoFim metadata must reach guarded handler')
local function releasedBeforeCancelled(fn)
 events={};fn();local release,cancel
 for i,e in events do if e[1]=='release' then release=i elseif e[1]=='cancel' then cancel=i end end
 assert(release and cancel and release<cancel,'inputs must release before animation cancellation')
end
releasedBeforeCancelled(function()H.servicos.UserInputService.WindowFocusReleased:Fire()end)
releasedBeforeCancelled(function()button.MouseButton1Click:Fire()end)
releasedBeforeCancelled(function()hum.Died:Fire()end)
releasedBeforeCancelled(function()plr.CharacterRemoving:Fire(character)end)
print('AJ14 actual Main startup: initialization, action end, existing death, menu/focus/removal release order OK')
