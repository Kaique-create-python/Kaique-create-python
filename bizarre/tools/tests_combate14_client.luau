local H=require('./harness')
local rb=require('@lune/roblox')
local now=10
local function signal()
 local s={fns={}}
 function s:Connect(f)table.insert(self.fns,f)return{Disconnect=function()end}end
 function s:Fire(...)for _,f in self.fns do f(...)end end
 return s
end
rb.implementMethod('Instance','GetAttributeChangedSignal',function()return signal()end)
rb.implementProperty('Humanoid','Died',function()return signal()end)
local c=rb.Instance.new('Model')
c:SetAttribute('BB_Stand','STAR_PLATINUM')
c:SetAttribute('BB_StandFora',true)
local hum=rb.Instance.new('Humanoid');hum.Health=100;hum.FloorMaterial=rb.Enum.Material.Ground;hum.Parent=c
local root=rb.Instance.new('Part');root.Name='HumanoidRootPart';root.CFrame=rb.CFrame.new(0,3,0);root.Position=rb.Vector3.new(0,3,0);root.AssemblyLinearVelocity=rb.Vector3.zero;root.Parent=c
local plr={Character=c,CharacterAdded=signal(),GetAttribute=function()return nil end}
H.servicos.Players={LocalPlayer=plr}
H.servicos.RunService.Heartbeat=signal()
local actions,stops,confirmations={},{},{}
local camera={mirar=function()end,travado=function()return nil end,correndo=function()end,travar=function()end}
local deps={
 Acoes={tocar=function(_,d)table.insert(actions,d)end,interromper=function(...)table.insert(stops,{...})end,confirmar=function(_,d)table.insert(confirmations,d)end},
 Animador={tocar=function()end,parar=function()table.insert(stops,{})end},Camera=camera,
 Efeitos={_modelosLutadores=function()return {}end},StandVisual={prever=function()end},
}
H.extras.require=function(m)return deps[m.Name] or H.require(m)end
H.extras.os={clock=function()return now end}
H.extras.workspace={GetServerTimeNow=function()return now end,CurrentCamera={CFrame=rb.CFrame.new()}}
local J=H.modulo('ReplicatedStorage/BB/Cliente/Jogador')
local sent={}
local rem={Acao={FireServer=function(_,typ,d)table.insert(sent,{typ=typ,d=d})end},Privado={OnClientEvent=signal()}}
J.iniciar(rem,{})
J.golpe(2)
local first=sent[#sent].d.seq
assert(first==1 and actions[#actions].seq==first)
now=11
J.golpe(4)
local second=sent[#sent].d.seq
assert(second>first and J.pendente.seq==second)
local count=#stops
rem.Privado.OnClientEvent:Fire('negado',{seq=first,acao='golpe'})
assert(#stops==count and J.pendente.seq==second,'old deny damaged new action')
rem.Privado.OnClientEvent:Fire('confirmado',{seq=first,id='STAR_PLATINUM_2',t=10,actionId='old'})
assert(J.pendente.seq==second and #confirmations==0)
-- An unpredicted buffered request may be denied. It must not unwind current prediction.
now=11.1
J.golpe(3)
local buffered=sent[#sent].d.seq
assert(buffered>second and #actions==2)
rem.Privado.OnClientEvent:Fire('negado',{seq=buffered,acao='golpe',motivo='ocupado'})
assert(#stops==count and J.pendente and J.pendente.seq==second,'buffer denial interrupted active prediction')
rem.Privado.OnClientEvent:Fire('confirmado',{seq=second,id='STAR_PLATINUM_4',t=11,actionId='a2',acaoAte=11.45})
assert(#confirmations==1 and not J.pendente)
rem.Privado.OnClientEvent:Fire('confirmado',{seq=second,id='STAR_PLATINUM_4',t=11,actionId='a2'})
assert(#confirmations==1,'duplicate ack')
-- Server-accepted buffer starts its own animation once, with the server ID.
rem.Privado.OnClientEvent:Fire('confirmado',{seq=buffered,id='STAR_PLATINUM_3',t=11.2,actionId='a3',acaoAte=12.1})
assert(#actions==3 and actions[3].actionId=='a3' and #confirmations==2)
-- Press during stun is sent once; release always reaches server despite local block false.
c:SetAttribute('BB_Stun',15)
J.bloquear(true)
assert(sent[#sent].typ=='bloqueio' and sent[#sent].d.ligar)
local beforeRelease=#stops
J.soltarEntradas()
assert(#stops==beforeRelease,"release of pending guard stopped unrelated animation")
assert(sent[#sent].typ=='soltar' and sent[#sent-1].typ=='bloqueio' and sent[#sent-1].d.ligar==false)
local beforeRespawn=#actions
plr.CharacterAdded:Fire()
rem.Privado.OnClientEvent:Fire('confirmado',{seq=buffered,id='STAR_PLATINUM_3',t=11.2,actionId='stale-respawn'})
assert(#actions==beforeRespawn,'ack from prior character animated respawn')
-- Air followup uses camera direction without auto-aim, CFrame changes or attacker impulse.
now=20
J.mirar=function() error('aerial called auto-aim') end
rem.Privado.OnClientEvent:Fire('airlink',{seq=30,abre=20,fecha=20.65,standId='STAR_PLATINUM'})
local originalCF=root.CFrame
J.m1()
assert(actions[#actions].id=='m1_aereo' and root.CFrame==originalCF and not root:FindFirstChild('BB_Proprio'))
assert(sent[#sent].d.dir==rb.Vector3.new(0,0,-1))
print('COMBATE14 cliente real: seq/ack/rejeição buffer/release OK')
