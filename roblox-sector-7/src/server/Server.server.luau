local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
-- Portable XML place uses ObjectValue references to restore authored attributes.
local manifest=script.Parent:FindFirstChild("AttributeManifest")
if manifest then
    for _,entry in manifest:GetChildren() do
        if entry:IsA("ObjectValue") and entry.Value and entry:FindFirstChild("Data") then
            local data=game:GetService("HttpService"):JSONDecode(entry.Data.Value)
            for key,value in pairs(data) do entry.Value:SetAttribute(key,value) end
        end
    end
end
local shared=ReplicatedStorage:WaitForChild("Sector7")
local Config=require(shared.Config)
local Stamina=require(shared.Stamina)
local Mission=require(script.Parent.Mission)
local Threat=require(script.Parent.Threat)
local WorldBuilder=require(script.Parent.WorldBuilder)

local remotes=shared:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name="Remotes";remotes.Parent=shared
local function remote(name)
    local r=remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
    r.Name=name;r.Parent=remotes
    return r
end
local sprint=remote("Sprint")
local flashlight=remote("Flashlight")
local feedback=remote("Feedback")
local world=workspace:FindFirstChild("Sector7World") or WorldBuilder.Build()
local mission=Mission.new()
local states={}
local function publish()
    workspace:SetAttribute("S7Fuses",mission.fuses)
    workspace:SetAttribute("S7Power",mission.power)
    workspace:SetAttribute("S7Keycard",mission.keycard)
    workspace:SetAttribute("S7Escaped",mission.escaped)
end
publish()
Lighting.ClockTime=0
Lighting.Brightness=1
Lighting.Ambient=Color3.fromRGB(18,21,23)
Lighting.OutdoorAmbient=Color3.fromRGB(12,14,16)
Lighting.FogColor=Color3.fromRGB(15,19,20)
Lighting.FogStart=35;Lighting.FogEnd=145
local grade=Lighting:FindFirstChild("Sector7Grade") or Instance.new("ColorCorrectionEffect")
grade.Name="Sector7Grade";grade.Saturation=-.35;grade.Contrast=.12;grade.Brightness=-.025;grade.Parent=Lighting

local function send(player,text,title,kind)
    feedback:FireClient(player,{kind=kind or "notice",title=title or "SETOR 7",text=text})
end
local function characterAdded(player,character)
    local state=states[player]
    if not state then return end
    state.stamina=Stamina.new(Config);state.wants=false
    player:SetAttribute("Escaped",false)
    player:SetAttribute("Stamina",Config.MaxStamina)
    player:SetAttribute("Sprinting",false);player:SetAttribute("Exhausted",false)
    player:SetAttribute("FlashlightOn",true)
    local humanoid=character:WaitForChild("Humanoid",10)
    local root=character:WaitForChild("HumanoidRootPart",10)
    if not humanoid or not root then return end
    if humanoid.RigType~=Enum.HumanoidRigType.R6 then
        warn("[Sector7] R6 StarterCharacter required; run installer.")
    end
    humanoid.WalkSpeed=Config.WalkSpeed;humanoid.JumpPower=32
    humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
    character:PivotTo(CFrame.new(0,4,12))
    humanoid.Died:Connect(function()
        state.wants=false
        player:SetAttribute("Sprinting",false)
    end)
    -- Server-owned flashlight is visible to other players too.
    local head=character:FindFirstChild("Head") or root
    local light=Instance.new("SpotLight")
    light.Name="Sector7Flashlight";light.Angle=80;light.Range=48
    light.Brightness=2.8;light.Color=Color3.fromRGB(221,226,202)
    light.Face=Enum.NormalId.Front;light.Shadows=false;light.Parent=head
    task.delay(2,function()
        if player.Parent then send(player,"Encontre três fusíveis. Ligue o gerador, recupere o cartão e escape.","17 NOV 1989 · INSTALAÇÃO 7") end
    end)
end
local function playerAdded(player)
    states[player]={stamina=Stamina.new(Config),wants=false,lastSprint=0,lastFlash=0,lastInteract=0}
    player.CharacterAdded:Connect(function(c) characterAdded(player,c) end)
    if player.Character then task.spawn(characterAdded,player,player.Character) end
end
Players.PlayerAdded:Connect(playerAdded)
for _,p in Players:GetPlayers() do playerAdded(p) end
Players.PlayerRemoving:Connect(function(p) states[p]=nil end)
sprint.OnServerEvent:Connect(function(player,value)
    local state=states[player]
    if not state or typeof(value)~="boolean" then return end
    local now=os.clock()
    -- Always accept release so a quick tap cannot latch sprint on.
    if value and state.wants and now-state.lastSprint<.08 then return end
    state.lastSprint=now;state.wants=value
end)
flashlight.OnServerEvent:Connect(function(player,value)
    local state=states[player]
    if not state or typeof(value)~="boolean" or os.clock()-state.lastFlash<.15 then return end
    state.lastFlash=os.clock()
    player:SetAttribute("FlashlightOn",value)
    local c=player.Character
    local light=c and c:FindFirstChild("Sector7Flashlight",true)
    if light then light.Enabled=value end
end)

local notes={
    Note1={"ORDEM DE MANUTENÇÃO","17 de novembro de 1989. Três fusíveis foram retirados: um no depósito, outro na sala de máquinas e o último no arquivo. Reponha os três no circuito antes de tentar ligar o gerador. A porta de evacuação continua sem energia."},
    Note2={"REGISTRO DE ESCUTA","O sinal voltou às 02h17. Não veio da antena. Veio dos canos. A voz repetiu nossos nomes na ordem do livro de presença. Se ouvir alguém chamando no túnel vazio, mantenha a lanterna acesa e continue andando."},
    Note3={"PROTOCOLO DO ARQUIVO","Depois de restabelecer a energia, retire o cartão de acesso do arquivo. O leitor da saída só libera a porta com o gerador ligado e o cartão recuperado. Não abra a sala de escuta."},
    Note4={"ÚLTIMA TRANSMISSÃO","Apagamos a frequência e a voz continuou. Morozov correu até ficar sem ar; ela o alcançou no escuro. Caminhe quando puder. Guarde fôlego para a saída. Se a porta abrir, não espere pelo último sinal."},
}
local function escaped(player)
    if player:GetAttribute("Escaped") then return end
    player:SetAttribute("Escaped",true)
    local state=states[player];if state then state.wants=false end
    send(player,"Você saiu. Às suas costas, o rádio repete seu nome. Fim da base jogável — SETOR 7: O Último Sinal.","EVACUAÇÃO CONCLUÍDA","escape")
end
local function interact(player,part,prompt)
    local state=states[player]
    local c=player.Character
    local root=c and c:FindFirstChild("HumanoidRootPart")
    local h=c and c:FindFirstChildOfClass("Humanoid")
    if not state or not root or not h or h.Health<=0 or player:GetAttribute("Escaped") then return end
    if (root.Position-part.Position).Magnitude>Config.InteractionDistance then return end
    if os.clock()-state.lastInteract<.25 then return end
    -- Geometry check prevents prompt calls through the side-room walls.
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={c}
    local hit=workspace:Raycast(root.Position,part.Position-root.Position,params)
    if hit and hit.Instance~=part and not hit.Instance:IsDescendantOf(part) then return end
    state.lastInteract=os.clock()
    local id=part:GetAttribute("InteractionId")
    if notes[id] then send(player,notes[id][2],notes[id][1],"note");return end
    local ok,message=Mission.attempt(mission,id)
    if not ok then send(player,message);return end
    publish()
    if string.sub(id,1,4)=="Fuse" or id=="Keycard" then
        prompt.Enabled=false;part.Transparency=1;part.CanCollide=false
        for _,v in part:GetDescendants() do
            if v:IsA("BasePart") then v.Transparency=1;v.CanCollide=false end
        end
    elseif id=="Generator" then
        prompt.Enabled=false
        for _,v in world:GetDescendants() do
            if v:IsA("PointLight") and v:GetAttribute("PowerLight") then v.Brightness=1.8;v.Color=Color3.fromRGB(207,208,166) end
        end
    elseif id=="Exit" then
        local door=world:FindFirstChild("ExitDoor",true)
        if door and door:IsA("BasePart") then
            door.CanCollide=false;prompt.Enabled=false
            game:GetService("TweenService"):Create(door,TweenInfo.new(1.8),{CFrame=door.CFrame+Vector3.new(0,11,0)}):Play()
        end
    end
    feedback:FireAllClients({kind="notice",title="OBJETIVO ATUALIZADO",text=message})
end
for _,part in world:GetDescendants() do
    if part:IsA("BasePart") and part:GetAttribute("InteractionId") then
        local prompt=part:FindFirstChildOfClass("ProximityPrompt")
        if prompt then prompt.Triggered:Connect(function(p) interact(p,part,prompt) end) end
    end
end
local accumulator=0
RunService.Heartbeat:Connect(function(dt)
    dt=math.min(dt,.25);accumulator+=dt
    local update=accumulator>=.1
    if update then accumulator=0 end
    for player,state in pairs(states) do
        local c=player.Character
        local h=c and c:FindFirstChildOfClass("Humanoid")
        local root=c and c:FindFirstChild("HumanoidRootPart")
        local allowed=h and h.Health>0 and not player:GetAttribute("Escaped")
        -- MoveDirection is not server-replicated reliably; horizontal velocity is.
        local moving=root and (root.AssemblyLinearVelocity*Vector3.new(1,0,1)).Magnitude>1
        Stamina.step(state.stamina,state.wants,moving,allowed,dt,Config)
        if h then h.WalkSpeed=state.stamina.running and Config.SprintSpeed or Config.WalkSpeed end
        if update then
            player:SetAttribute("Stamina",math.round(state.stamina.value*10)/10)
            player:SetAttribute("Sprinting",state.stamina.running)
            player:SetAttribute("Exhausted",state.stamina.exhausted)
            if allowed and mission.escaped and root then
                local zone=world:FindFirstChild("ExitZone")
                if zone then
                    local p=zone.CFrame:PointToObjectSpace(root.Position)
                    local half=zone.Size*.5
                    if math.abs(p.X)<half.X and math.abs(p.Y)<half.Y and math.abs(p.Z)<half.Z then escaped(player) end
                end
            end
        end
    end
end)
Threat.start(world,Config,feedback)
print("[Sector7] Ready — R6 / cooperative session / validated prompts")
