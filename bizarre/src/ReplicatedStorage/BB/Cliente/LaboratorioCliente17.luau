local Players=game:GetService("Players")
local UI=require(script.Parent.Interface)
local T={}
function T.iniciar(remote,controles,hud,menu)
 local player=Players.LocalPlayer
 local gui=Instance.new("ScreenGui");gui.Name="BB_Laboratorio17";gui.ResetOnSpawn=false;gui.DisplayOrder=15
 pcall(function()gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets end)
 gui.Parent=player:WaitForChild("PlayerGui")
 local open=UI.botao(gui,"TREINO",UDim2.fromOffset(100,38),UDim2.new(.5,70,0,7),UI.CORES.roxo,{limite=18})
 local panel=UI.frame(gui,UDim2.fromOffset(350,304),UDim2.new(.5,-175,.5,-152),UI.CORES.fundo,.03)
 panel.Visible=false;panel.Active=true;UI.canto(panel,10);UI.borda(panel,UI.CORES.roxo,2)
 UI.texto(panel,"LABORATÓRIO",UDim2.new(1,-20,0,30),UDim2.fromOffset(10,8),{cor=UI.CORES.dourado,limite=22})
 local info=UI.texto(panel,"Escolha a resposta do alvo.",UDim2.new(1,-24,0,66),UDim2.fromOffset(12,43),{limite=17,quebrar=true})
 local buttons={}
 for i,d in {{"parado","PARADO"},{"bloquear","DEFENDER APÓS HIT"},{"evasiva","ESQUIVAR APÓS HIT"},{"contra","CONTRA-ATACAR"}}do
  local b=UI.botao(panel,d[2],UDim2.fromOffset(157,46),UDim2.fromOffset(14+((i-1)%2)*165,116+math.floor((i-1)/2)*54),Color3.fromRGB(44,38,61),{limite=14})
  buttons[d[1]]=b
  b.Activated:Connect(function()remote:FireServer({tipo="configurar",modo=d[1]})end)
 end
 local reset=UI.botao(panel,"REPOR ALVO",UDim2.fromOffset(157,44),UDim2.fromOffset(14,240),UI.CORES.roxo,{limite=16})
 reset.Activated:Connect(function()remote:FireServer({tipo="reiniciar"})end)
 local close=UI.botao(panel,"FECHAR",UDim2.fromOffset(157,44),UDim2.fromOffset(179,240),Color3.fromRGB(70,38,52),{limite=16})
 local function available()
  local c=player.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
  return player:GetAttribute("BB_Modo")=="treino"and h and h.Health>0 and not menu.aberto()and not controles.editando()
 end
 local function fechar()
  if panel.Visible then panel.Visible=false;controles.ativar(not menu.aberto());hud.mostrar(not menu.aberto())end
 end
 open.Activated:Connect(function()
  if not available()then return end
  panel.Visible=true;controles.ativar(false);hud.mostrar(false)
  remote:FireServer({tipo="estado"})
 end)
 close.Activated:Connect(fechar)
 remote.OnClientEvent:Connect(function(data)
  if type(data)~="table"then return end
  info.Text=if data.erro then data.erro else string.format("%d acertos  ·  %.1f de dano\n%s",data.hits or 0,data.dano or 0,if (data.hits or 0)<2 then "Alvo próprio · habilidades com recarga normal"elseif data.janela then "Houve janela para escapar"else "Sem abertura entre os últimos acertos")
  for mode,b in buttons do b.BackgroundColor3=if mode==data.modo then UI.CORES.roxo else Color3.fromRGB(44,38,61)end
 end)
 -- A quiet report in the world keeps the last server result visible during practice.
 local report=UI.texto(gui,"",UDim2.fromOffset(310,48),UDim2.new(.5,-155,0,55),{limite=16,quebrar=true})
 remote.OnClientEvent:Connect(function(data)
  if type(data)=="table"and not data.erro then
   if (data.hits or 0)==0 then report.Text="";return end
   report.Text=string.format("TREINO  %d HITS  ·  %.1f DANO\n%s",data.hits,data.dano,if data.hits<2 then "AGUARDANDO PRÓXIMO ACERTO"elseif data.janela then "JANELA DE FUGA"else "SEM ABERTURA NO ÚLTIMO INTERVALO")
  end
 end)
 local scale=Instance.new("UIScale");scale.Parent=panel
 local canvas=UI.frame(gui,UDim2.fromScale(1,1),UDim2.new(),UI.CORES.fundo,1);canvas.ZIndex=0
 local function resize()
  local size=canvas.AbsoluteSize
  scale.Scale=math.min(1,(size.X-16)/350,(size.Y-16)/304)
  panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5)
 end
 canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize);resize()
 game:GetService("RunService").Heartbeat:Connect(function()
  local ok=available();open.Visible=ok and not panel.Visible;report.Visible=ok and not panel.Visible
  if panel.Visible and not ok then fechar()end
 end)
end
return T
