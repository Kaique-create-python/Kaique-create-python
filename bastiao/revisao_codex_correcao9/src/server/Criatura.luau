--!strict
-- One bounded, server-owned first encounter. No placeholder mesh or asset IDs.
-- Install CriaturaCore and MonsterImportContract as sibling ModuleScripts.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")
local ContentProvider = game:GetService("ContentProvider")
local PathfindingService = game:GetService("PathfindingService")
local Core = require(script.Parent:WaitForChild("CriaturaCore"))
local Criatura = {}
local V = Vector3.new
local TICK = 0.1 -- one creature, ten decisions/second; profile in the real place
local WALK_SPEED, RUN_SPEED = 3.5, 14.5
-- Perseguição v2: quanto mais tempo persegue, mais rápido fica (o jogador anda a 10 e corre a 18
-- enquanto tiver fôlego). Fugir correndo funciona por um tempo; a oficina é a única salvação.
local RUN_SPEED_MAX, RUN_RAMP_SECONDS = 17, 6
local SEARCH_SPEED, SEARCH_FAST_SECONDS = 8, 4 -- ao perder de vista, corre até onde o jogador ia
local LOCK_ON_DISTANCE = 50 -- perseguindo, continua vendo o alvo fora do cone se nada bloquear
local LATERAL_REACH = 2.5 -- quanto pode sair do eixo do corredor na aproximação final
-- Andar garantido: o monstro anda pelo eixo dos corredores (grafo abaixo), com o corpo
-- ancorado e movido a cada quadro. Sem física de Humanoid e sem pathfinding de agente gigante
-- (que falhava e deixava o monstro parado só respirando). Nós medidos no mapa Sector7World.
local NODES = {
    V(0,0,-260), V(-58,0,-260), V(58,0,-260),            -- 1 cruzamento norte, 2 anel oeste, 3 anel leste
    V(0,0,-300), V(0,0,-360), V(0,0,-400), V(0,0,-440),  -- 4..7 corredor do meio (7 = cruzamento sul)
    V(-58,0,-440), V(58,0,-440),                         -- 8, 9 cantos sul
    V(58,0,-300), V(58,0,-338), V(58,0,-400),            -- 10..12 anel leste
    V(-58,0,-300), V(-58,0,-338), V(-58,0,-400),         -- 13..15 anel oeste
}
local EDGES = {{1,2},{1,3},{1,4},{4,5},{5,6},{6,7},{7,8},{7,9},{3,10},{10,11},{11,12},{12,9},{2,13},{13,14},{14,15},{15,8}}
local SPAWNS = {V(0,0,-284), V(0,0,-440)}
local PATROL = {V(0,0,-260),V(45,0,-260),V(58,0,-280),V(58,0,-338),
    V(58,0,-440),V(0,0,-440),V(0,0,-360),V(0,0,-300)}
local PRIORITY = {
    ["01_RESPIRACAO"]=Enum.AnimationPriority.Idle,
    ["02_ALERTA"]=Enum.AnimationPriority.Idle,
    ["06_RUGIDO"]=Enum.AnimationPriority.Action,
    ["07_ANDAR"]=Enum.AnimationPriority.Movement,
    ["08_CORRER"]=Enum.AnimationPriority.Movement,
    ["09_ACELERAR"]=Enum.AnimationPriority.Movement,
    ["10_FREAR"]=Enum.AnimationPriority.Movement,
    ["15_VASCULHAR"]=Enum.AnimationPriority.Action,
    ["19_CLAW_LEFT"]=Enum.AnimationPriority.Action,
}
-- Animações extras (opcionais): se alguma faltar no catálogo ou não carregar, o encontro segue
-- sem ela. Os jumpscares matam quem a garra alcança; farejar e olhar dão vida à busca; esmurrar
-- a porta acontece quando o jogador se tranca na oficina.
local EXTRAS = {
    ["30_JUMPSCARE_FRONTAL_GRAB"]=Enum.AnimationPriority.Action2,
    ["31_JUMPSCARE_FROM_BEHIND"]=Enum.AnimationPriority.Action2,
    ["03_FAREJAR"]=Enum.AnimationPriority.Action,
    ["04_OLHAR_ESQUERDA"]=Enum.AnimationPriority.Action,
    ["05_OLHAR_DIREITA"]=Enum.AnimationPriority.Action,
    ["17_ESMURRAR_PORTA"]=Enum.AnimationPriority.Action,
}
local CAPTURA = {frente="30_JUMPSCARE_FRONTAL_GRAB", costas="31_JUMPSCARE_FROM_BEHIND"}
local BUSCA = {"03_FAREJAR","04_OLHAR_ESQUERDA","05_OLHAR_DIREITA","15_VASCULHAR"}
local PORTA_FORA = V(60.5,0,-319) -- no anel leste, colado na porta da oficina (fora da sala segura)
local PORTA = V(66,0,-319)

local function point(v: Vector3): any return {x=v.X,y=v.Y,z=v.Z} end
local function inArea(v: Vector3): boolean return Core.inEncounterArea(point(v)) end
local function safe(v: Vector3): boolean return Core.inSafeZone(point(v)) end
local function flat(v: Vector3): Vector3 return V(v.X,0,v.Z) end
local function valid(v: Vector3): boolean
    return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 100000
end

local function livePlayer(player: Player): (Model?, BasePart?, Humanoid?)
    if player.Parent ~= Players then return nil,nil,nil end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local human = character and character:FindFirstChildOfClass("Humanoid")
    if not character or not root or not root:IsA("BasePart") or not human
        or human.Health <= 0 or not valid(root.Position) then return nil,nil,nil end
    return character, root, human
end

local function rayClear(origin: Vector3, target: Vector3, ignore: {Instance}, character: Model?): boolean
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    params.RespectCanCollide = true -- actual doors remain obstacles, even when CanQuery differs
    params.IgnoreWater = false
    local result = Workspace:Raycast(origin,target-origin,params)
    return result == nil or (character ~= nil and result.Instance:IsDescendantOf(character))
end

local function project(p: Vector3): (number, Vector3, number)
    -- ponto mais perto no eixo dos corredores: (aresta, ponto, distância)
    local best, bestPoint, bestDist = 1, NODES[1], math.huge
    local q = V(p.X, 0, p.Z)
    for i, e in EDGES do
        local a, b = NODES[e[1]], NODES[e[2]]
        local ab = b - a
        local t = math.clamp((q - a):Dot(ab) / ab:Dot(ab), 0, 1)
        local point = a + ab * t
        local d = (q - point).Magnitude
        if d < bestDist then best, bestPoint, bestDist = i, point, d end
    end
    return best, bestPoint, bestDist
end

local function graphRoute(from: Vector3, to: Vector3): {Vector3}
    local e1, p1 = project(from)
    local e2, p2 = project(to)
    if e1 == e2 then return {p2} end
    -- Dijkstra pequeno: início e fim viram nós virtuais ligados às pontas das suas arestas
    local count = #NODES
    local START, GOAL = count + 1, count + 2
    local pos = table.clone(NODES)
    pos[START], pos[GOAL] = p1, p2
    local links: {[number]: {{number}}} = {}
    local function link(a: number, b: number)
        local w = (pos[a] - pos[b]).Magnitude
        links[a] = links[a] or {}; links[b] = links[b] or {}
        table.insert(links[a], {b, w}); table.insert(links[b], {a, w})
    end
    for i, e in EDGES do
        if i ~= e1 and i ~= e2 then link(e[1], e[2]) end
    end
    link(START, EDGES[e1][1]); link(START, EDGES[e1][2])
    link(GOAL, EDGES[e2][1]); link(GOAL, EDGES[e2][2])
    local dist, prev, done = {[START] = 0}, {}, {}
    while true do
        local u, best = nil, math.huge
        for node, d in dist do
            if not done[node] and d < best then u, best = node, d end
        end
        if not u or u == GOAL then break end
        done[u] = true
        for _, l in links[u] or {} do
            local v, w = l[1], l[2]
            if not done[v] and (dist[v] == nil or best + w < dist[v]) then dist[v], prev[v] = best + w, u end
        end
    end
    local route = {}
    local node = GOAL
    while node and node ~= START do
        table.insert(route, 1, pos[node])
        node = prev[node]
    end
    if #route == 0 then return {p2} end
    return route
end

local function corridorPoint(target: Vector3): Vector3
    -- posição real do alvo, presa perto do eixo do corredor (o corpo não entra na parede)
    local _, axis = project(target)
    local off = V(target.X, 0, target.Z) - axis
    if off.Magnitude > LATERAL_REACH then off = off.Unit * LATERAL_REACH end
    return axis + off
end

function Criatura.start(op: any): any
    assert(typeof(op.world)=="Instance" and op.world:IsDescendantOf(Workspace),"Criatura needs the existing story folder")
    assert(type(op.mundo)=="table" and type(op.mundo.estado)=="function","Criatura needs the original Mundo")
    local status: any = {state="dormant",error=nil,engineVerified=false}
    local folder: Folder? = nil
    local active: any = nil
    local destroyed, loading, failed = false,false,false
    local generation, loadDeadline, accumulator = 0,0,0
    local loaderBusy,pathBusy=false,false
    local heartbeat: RBXScriptConnection? = nil
    local loaderThread: thread? = nil

    local function report(state: string, reason: string?)
        status.state,status.error=state,reason
        if op.shared and op.shared.Parent then
            op.shared:SetAttribute("BastiaoCriaturaEstado",state)
            op.shared:SetAttribute("BastiaoCriaturaErro",reason or "")
        end
    end

    local function stopNavigation(c: any)
        local nav=c.nav
        nav.serial+=1
        if nav.blocked then nav.blocked:Disconnect(); nav.blocked=nil end
        if nav.path then nav.path:Destroy(); nav.path=nil end
        nav.waypoints,nav.goal,nav.requestedGoal=nil,nil,nil
        if c.root.Parent then c.human:MoveTo(c.root.Position) end
        -- ComputeAsync itself is engine-owned: retain its single in-flight slot.
        -- Its serial makes late results inert, without launching overlapping retries.
    end

    -- Usado tanto pelo fim normal quanto pelo teardown/falha do encontro.
    -- Guarda os valores do personagem capturado, sem tocar um eventual respawn.
    local function liberarVitima(c: any)
        local cap=c.captura
        c.captura=nil
        if not cap then return end
        if cap.root and cap.root.Parent then cap.root.Anchored=cap.ancorado end
        if cap.human and cap.human.Parent and cap.human.Health>0 then
            cap.human.WalkSpeed=cap.velocidade
            cap.human.JumpPower=cap.pulo
            cap.human.JumpHeight=cap.alturaPulo
        end
        if cap.player then
            cap.player:SetAttribute("BastiaoCapturaTipo",nil)
            cap.player:SetAttribute("BastiaoCapturaAnimacao",nil)
        end
    end

    local function clearCreature()
        local c=active
        active=nil
        if not c then return end
        c.ready=false
        liberarVitima(c)
        stopNavigation(c)
        for _, connection in c.connections do connection:Disconnect() end
        for _, track in c.tracks do track:Stop(0); track:Destroy() end
        if c.model then c.model:Destroy() end
    end

    local function fail(reason: string)
        if destroyed then return end
        generation+=1
        loading,failed=false,true
        clearCreature()
        report("unavailable",reason)
        warn("[Bastiao731A] encontro desativado: "..reason)
        if not folder or not folder.Parent or folder:FindFirstChild("Diagnostico") then return end
        local marker=Instance.new("Part")
        marker.Name="Diagnostico"
        marker.Anchored=true
        marker.CanCollide,marker.CanQuery,marker.CanTouch=false,false,false
        marker.Transparency=1
        marker.Position=V(0,5,-284)
        local board=Instance.new("BillboardGui")
        board.Size=UDim2.fromOffset(340,70)
        board.MaxDistance=120
        board.AlwaysOnTop=false
        board.Adornee=marker
        local text=Instance.new("TextLabel")
        text.Size=UDim2.fromScale(1,1)
        text.BackgroundColor3=Color3.fromRGB(24,18,18)
        text.BackgroundTransparency=0.1
        text.TextColor3=Color3.fromRGB(255,162,145)
        text.TextSize=16
        text.TextWrapped=true
        text.Text="731-A — encontro indisponível\nModelo ou animações não carregaram."
        text.Parent=board
        board.Parent=marker
        marker.Parent=folder
    end

    local function getIgnore(c: any?): {Instance}
        local ignore: {Instance}={}
        if folder then table.insert(ignore,folder) end
        for _, player in Players:GetPlayers() do
            if player.Character then table.insert(ignore,player.Character) end
        end
        return ignore
    end

    local function clearance(position: Vector3, size: Vector3, ignore: {Instance}): boolean
        local params=OverlapParams.new()
        params.FilterType=Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances=ignore
        params.RespectCanCollide=true
        params.MaxParts=1
        local center=position+V(0,size.Y/2+0.12,0)
        return #Workspace:GetPartBoundsInBox(CFrame.new(center),size+V(0.1,0,0.1),params)==0
    end

    local function chooseSpawn(size: Vector3): Vector3?
        local ignore=getIgnore(nil)
        for _, anchor in SPAWNS do
            local groundParams=RaycastParams.new()
            groundParams.FilterType=Enum.RaycastFilterType.Exclude
            groundParams.FilterDescendantsInstances=ignore
            groundParams.RespectCanCollide=true
            local floor=Workspace:Raycast(anchor+V(0,5,0),V(0,-12,0),groundParams)
            if not floor or floor.Normal.Y < 0.9 then continue end
            local ground=V(anchor.X,floor.Position.Y,anchor.Z)
            if not clearance(ground,size,ignore) then continue end
            local fair=true
            local center=ground+V(0,size.Y*0.6,0)
            for _, player in Players:GetPlayers() do
                local character,root=livePlayer(player)
                if not character or not root then continue end
                local delta=center-root.Position
                local distance=delta.Magnitude
                if distance<35 or (distance<100 and distance>0
                    and root.CFrame.LookVector:Dot(delta.Unit)>0.1
                    and rayClear(root.Position+V(0,1.4,0),center,ignore,nil)) then
                    fair=false; break
                end
            end
            if fair then return ground end
        end
        return nil
    end

    local function play(c: any, name: string, speed: number?)
        local track=c.tracks[name]
        if not track then error("missing validated track "..name) end
        if c.animation~=name or not track.IsPlaying then
            c.animation=name -- set before stopping, so Stopped cannot finish a new attack
            for otherName,other in c.tracks do
                if otherName~=name and other.IsPlaying then other:Stop(0.18) end
            end
            track:Play(0.16,1,speed or 1)
            c.model:SetAttribute("BastiaoAnimation",name)
        elseif speed then track:AdjustSpeed(speed) end
    end

    local function navigationFailure(c: any, now: number)
        local nav=c.nav
        nav.failures+=1
        nav.nextRequest=now+math.min(4,0.8*nav.failures)
        if nav.failures>=3 then
            nav.quietUntil=now+5
            nav.failures=0
            if c.state.mode=="roam" then c.patrolIndex=c.patrolIndex%#PATROL+1 end
        end
        c.model:SetAttribute("BastiaoNavigation","blocked")
    end

    local function requestPath(c: any, goal: Vector3, now: number)
        local nav=c.nav
        if pathBusy or nav.busy or now<nav.nextRequest or now<nav.quietUntil or not inArea(goal)
            or safe(goal) or (flat(goal-c.root.Position)).Magnitude>180 then return end
        if nav.waypoints and nav.goal and (flat(goal-nav.goal)).Magnitude<7 then return end
        if nav.waypoints and now-nav.lastRequest<1.25 then return end
        stopNavigation(c)
        nav.serial+=1
        local serial,owner=nav.serial,generation
        nav.busy,nav.started,nav.lastRequest,nav.nextRequest=true,now,now,now+1.25
        pathBusy=true
        nav.requestedGoal=goal
        local path=PathfindingService:CreatePath({
            AgentHeight=c.height+0.2,AgentRadius=c.radius+0.1,
            AgentCanJump=false,AgentCanClimb=false,WaypointSpacing=5,
            Costs={Bastiao731Safe=math.huge},
        })
        task.spawn(function()
            local ok=pcall(function() path:ComputeAsync(c.root.Position,goal) end)
            nav.busy,pathBusy=false,false
            if destroyed or active~=c or generation~=owner or nav.serial~=serial then path:Destroy(); return end
            if not ok or path.Status~=Enum.PathStatus.Success or os.clock()-nav.started>3 then
                path:Destroy(); navigationFailure(c,os.clock()); return
            end
            local waypoints=path:GetWaypoints()
            if #waypoints<2 or #waypoints>96 then path:Destroy(); navigationFailure(c,os.clock()); return end
            for _, waypoint in waypoints do
                if not inArea(waypoint.Position) or safe(waypoint.Position)
                    or waypoint.Action~=Enum.PathWaypointAction.Walk then
                    path:Destroy(); navigationFailure(c,os.clock()); return
                end
            end
            nav.path,nav.waypoints,nav.index,nav.goal=path,waypoints,2,goal
            nav.lastProgress,nav.progressPosition=os.clock(),c.root.Position
            nav.blocked=path.Blocked:Connect(function(index)
                if active==c and index>=nav.index then
                    stopNavigation(c)
                    navigationFailure(c,os.clock())
                end
            end)
            c.model:SetAttribute("BastiaoNavigation","path")
        end)
    end

    local function follow(c: any, now: number)
        local nav=c.nav
        if nav.busy and now-nav.started>3 then
            c.human:MoveTo(c.root.Position)
            c.model:SetAttribute("BastiaoNavigation","compute_timeout")
            return
        end
        if not nav.waypoints then return end
        local waypoint=nav.waypoints[nav.index]
        if not waypoint then stopNavigation(c); return end
        if (flat(waypoint.Position-c.root.Position)).Magnitude<=2 then
            nav.index+=1
            waypoint=nav.waypoints[nav.index]
            if not waypoint then stopNavigation(c); return end
        end
        if not clearance(waypoint.Position,c.colliderSize,getIgnore(c)) then
            stopNavigation(c); navigationFailure(c,now); return
        end
        if (flat(c.root.Position-nav.progressPosition)).Magnitude>0.7 then
            nav.progressPosition,nav.lastProgress=c.root.Position,now
        elseif now-nav.lastProgress>2.5 then
            stopNavigation(c); navigationFailure(c,now); return
        end
        c.human:MoveTo(waypoint.Position)
    end

    local function candidates(c: any, now: number): {any}
        local found={}
        local present={}
        local eye=c.root.Position+V(0,c.height*0.26,0)
        local forward=flat(c.root.CFrame.LookVector)
        for _, player in Players:GetPlayers() do
            local character,root,human=livePlayer(player)
            if not character or not root or not human then c.samples[player.UserId]=nil; continue end
            present[player.UserId]=true
            local position=root.Position
            local delta=position-c.root.Position
            local distance=delta.Magnitude
            local previous=c.samples[player.UserId]
            local measured=0
            if previous and now>previous.at and now-previous.at<=0.5 then
                measured=(flat(position-previous.position)).Magnitude/(now-previous.at)
            end
            c.samples[player.UserId]={position=position,at=now}
            if distance>86 then continue end
            local flatDelta=flat(delta)
            local dot=if flatDelta.Magnitude>0.01 then forward:Dot(flatDelta.Unit) else 1
            local isSafe=safe(position)
            local isInArea=inArea(position)
            local los=false
            local hearing=false
            if not isSafe and isInArea then
                if dot>=0.5 then los=rayClear(eye,position+V(0,1.2,0),{c.model},character) end
                if distance<=30 and player:GetAttribute("Sprinting")==true and measured>=16 then
                    -- A separate lower ray gives running feet physical evidence.
                    -- No noise is heard through closed containment/workshop doors.
                    hearing=rayClear(c.root.Position-V(0,c.height*0.25,0),position,{c.model},character)
                end
                -- Attack revalidation needs LOS even after a target leaves the FOV.
                if c.state.mode=="attack" and player.UserId==c.state.attackVictim and distance<=6 then
                    los=rayClear(eye,position+V(0,1.2,0),{c.model},character)
                end
                -- Trava no alvo: perseguindo, não perde o jogador só porque ele passou pelo lado.
                if not los and c.state.mode=="chase" and player.UserId==c.state.targetId and distance<=LOCK_ON_DISTANCE then
                    los=rayClear(eye,position+V(0,1.2,0),{c.model},character)
                    if los then dot=1 end
                end
            end
            table.insert(found,{id=player.UserId,position=position,alive=true,safe=isSafe,inArea=isInArea,
                distance=distance,dot=dot,los=los,sprinting=player:GetAttribute("Sprinting")==true,
                speed=flat(root.AssemblyLinearVelocity).Magnitude,velocity=flat(root.AssemblyLinearVelocity),measuredSpeed=measured,
                grounded=human.FloorMaterial~=Enum.Material.Air,hearingClear=hearing})
        end
        for id in c.samples do if not present[id] then c.samples[id]=nil end end
        return found
    end

    local function vitimaValida(c: any, id: number): (Player?, BasePart?, Humanoid?)
        local player=Players:GetPlayerByUserId(id)
        if not player then return nil,nil,nil end
        local character,root,human=livePlayer(player)
        if not character or not root or not human or not c.ready or c.state.mode~="attack"
            or c.animation~="19_CLAW_LEFT" or not c.tracks["19_CLAW_LEFT"].IsPlaying
            or safe(root.Position) or not inArea(root.Position) or (root.Position-c.root.Position).Magnitude>6 then return nil,nil,nil end
        if not rayClear(c.root.Position+V(0,c.height*0.26,0),root.Position+V(0,1.2,0),{c.model},character) then return nil,nil,nil end
        return player,root,human
    end

    local function damage(c: any, id: number)
        local player,_,human=vitimaValida(c,id)
        if not player or not human then return end
        human:TakeDamage(30) -- sem as animações de jumpscare: uma garra legível
        -- avisa os clientes: quem levou o golpe ouve o impacto estourado (MonstroSom)
        c.model:SetAttribute("BastiaoHitVictim",id)
        c.model:SetAttribute("BastiaoHitSerial",(c.model:GetAttribute("BastiaoHitSerial") or 0)+1)
    end

    -- CAPTURA: a garra que alcança agarra o jogador (jumpscare de frente ou pelas costas) e mata
    -- no golpe final. O jogador fica preso na frente do monstro; o cliente dele faz a câmera.
    local function capturar(c: any, id: number, now: number): boolean
        local player,root,human=vitimaValida(c,id)
        if not player or not root or not human then return false end
        local paraMonstro=flat(c.root.Position-root.Position)
        local olhando=flat(root.CFrame.LookVector)
        local tipo=if paraMonstro.Magnitude>0.01 and olhando.Magnitude>0.01
            and olhando.Unit:Dot(paraMonstro.Unit)<-0.2 then "costas" else "frente"
        local nome=CAPTURA[tipo]
        if not c.tracks[nome] then tipo,nome="frente",CAPTURA.frente end
        if not c.tracks[nome] then return false end
        local frente=flat(c.root.CFrame.LookVector)
        frente=if frente.Magnitude>0.01 then frente.Unit else V(0,0,1)
        local onde=c.root.Position+frente*3.4
        onde=V(onde.X,root.Position.Y,onde.Z)
        local mira=if tipo=="frente" then V(c.root.Position.X,onde.Y,c.root.Position.Z) else onde+frente
        local clip=c.catalog.animations[nome]
        c.captura={id=id,player=player,character=player.Character,root=root,human=human,nome=nome,inicio=now,
            ancorado=root.Anchored,velocidade=human.WalkSpeed,pulo=human.JumpPower,alturaPulo=human.JumpHeight,
            golpe=Core.markerTime(clip,"Impact") or clip.duration*0.65,fim=clip.duration,matou=false}
        root.Anchored=true
        root.CFrame=CFrame.lookAt(onde,mira)
        human.WalkSpeed=0
        human.JumpPower=0
        human.JumpHeight=0
        player:SetAttribute("BastiaoCapturaTipo",tipo)
        player:SetAttribute("BastiaoCapturaAnimacao",nome)
        player:SetAttribute("BastiaoCapturado",(player:GetAttribute("BastiaoCapturado") or 0)+1)
        c.model:SetAttribute("BastiaoCapturaVitima",id)
        c.model:SetAttribute("BastiaoCapturaSerial",(c.model:GetAttribute("BastiaoCapturaSerial") or 0)+1)
        c.model:SetAttribute("BastiaoState","capture")
        stopNavigation(c)
        -- parado e virado para a vítima (setGoal é definido mais abaixo; aqui basta zerar a rota)
        c.mover.route,c.mover.goal,c.mover.targetSpeed,c.mover.urgent=nil,nil,0,true
        c.mover.face=onde
        play(c,nome)
        return true
    end

    local function soltarCaptura(c: any, now: number)
        liberarVitima(c)
        c.model:SetAttribute("BastiaoCapturaVitima",0)
        c.state=Core.new(now)
        c.state.nextRoarAt=now+12
        c.pendingHit,c.pendingFinished=false,false
        c.ultimoAlvo=nil
        c.mover.face=nil
        c.model:SetAttribute("BastiaoState","roam")
    end

    local function atualizarCaptura(c: any, now: number)
        local cap=c.captura
        if not cap.player.Parent or cap.player.Character~=cap.character or not cap.root.Parent
            or not cap.human.Parent then
            soltarCaptura(c,now)
            return
        end
        local t=now-cap.inicio
        local vivo=cap.human.Parent~=nil and cap.human.Health>0
        if vivo and cap.root.Parent then cap.root.Anchored=true end
        if t>=cap.golpe and vivo and not cap.matou then
            cap.matou=true
            cap.human.Health=0
            c.model:SetAttribute("BastiaoHitVictim",cap.id)
            c.model:SetAttribute("BastiaoHitSerial",(c.model:GetAttribute("BastiaoHitSerial") or 0)+1)
        end
        if t>=cap.fim+0.15 or not cap.player.Parent or not cap.root.Parent then soltarCaptura(c,now) end
    end

    local function alvoNaOficina(c: any): boolean
        local player=if c.ultimoAlvo then Players:GetPlayerByUserId(c.ultimoAlvo) else nil
        if not player then return false end
        local _,root=livePlayer(player)
        return root~=nil and safe(root.Position)
    end

    local floorParams=RaycastParams.new()
    floorParams.FilterType=Enum.RaycastFilterType.Exclude
    floorParams.RespectCanCollide=true
    local function setGoal(c: any, goal: Vector3?, speed: number, now: number, urgent: boolean?)
        local m=c.mover
        m.targetSpeed=speed
        m.urgent=urgent==true
        if not goal then m.route,m.goal=nil,nil; return end
        -- perseguindo: recalcula 5x por segundo e mira no jogador de verdade, não só no eixo
        local tolerance,interval=if urgent then 1 else 2.5,if urgent then 0.2 else 0.6
        if m.route and m.goal and (flat(goal-m.goal)).Magnitude<tolerance and now<m.recomputeAt then return end
        local route=graphRoute(c.root.Position,goal)
        if urgent then
            local final=corridorPoint(goal)
            if #route<=1 then
                route={final}
            elseif (flat(final-route[#route])).Magnitude>0.5 then
                table.insert(route,final)
            end
        end
        m.route,m.index,m.goal,m.recomputeAt=route,1,goal,now+interval
        c.model:SetAttribute("BastiaoNavigation",if urgent then "perseguicao" else "corredor")
    end
    local function moveStep(c: any, dt: number)
        local m=c.mover
        if not m then return end
        local wanted=if m.route then m.targetSpeed else 0
        m.speed=m.speed+math.clamp(wanted-m.speed,-30*dt,(if m.urgent then 16 else 10)*dt)
        local root=c.root.Position
        local here=V(root.X,0,root.Z)
        local start=here
        local remaining=math.max(0,m.speed)*dt
        local travel: Vector3?=nil
        while m.route and remaining>0 do
            local wp=m.route[m.index]
            if not wp then m.route=nil; break end
            local delta=V(wp.X,0,wp.Z)-here
            local d=delta.Magnitude
            if d>0.01 then travel=delta.Unit end
            if d<=remaining then
                here=V(wp.X,0,wp.Z); remaining-=d; m.index+=1
            else
                here+=delta.Unit*remaining; remaining=0
            end
        end
        m.actualSpeed=(here-start).Magnitude/math.max(dt,1/240)
        local look=flat(c.root.CFrame.LookVector)
        local want=travel
        if m.face then
            local f=flat(m.face-here)
            if f.Magnitude>0.5 then want=f.Unit end
        end
        if want and look.Magnitude>0.01 then
            local angle=math.atan2(look:Cross(want).Y,look:Dot(want))
            local turnRate=if m.urgent then 7 else 3.5 -- perseguindo vira bem mais rápido
            local turn=math.clamp(angle,-turnRate*dt,turnRate*dt)
            look=CFrame.Angles(0,turn,0):VectorToWorldSpace(look)
        elseif want then look=want end
        -- Chão só do mapa (nunca Pavel, jogadores ou peças do cenário: era isso que fazia boiar)
        -- e sem degraus maiores que 1 stud entre um quadro e outro.
        local mapa=Workspace:FindFirstChild("Sector7World")
        if mapa then
            floorParams.FilterType=Enum.RaycastFilterType.Include
            floorParams.FilterDescendantsInstances={mapa}
        else
            floorParams.FilterType=Enum.RaycastFilterType.Exclude
            floorParams.FilterDescendantsInstances=getIgnore(c)
        end
        local hit=Workspace:Raycast(here+V(0,2.5,0),V(0,-8,0),floorParams)
        local floorY=m.floorY or 0
        if hit and hit.Normal.Y>0.7 and math.abs(hit.Position.Y-floorY)<1 then floorY=hit.Position.Y end
        m.floorY=floorY
        local y=floorY+c.height/2+0.12
        local at=V(here.X,y,here.Z)
        c.model:PivotTo(CFrame.lookAt(at,at+look))
    end

    local function chaseSpeed(c: any, now: number): number
        local heat=math.clamp((now-(c.chaseStartedAt or now))/RUN_RAMP_SECONDS,0,1)
        local top=RUN_SPEED+(RUN_SPEED_MAX-RUN_SPEED)*heat
        return top*math.clamp(1-(c.accelerateUntil-now)/1.2,0.15,1)
    end

    local function update(c: any, now: number)
        if not c.model.Parent or c.human.Health<=0 or not inArea(c.root.Position) then
            fail("criatura_fora_da_area_ou_removida"); return
        end
        for _, mesh in c.meshes do
            if not mesh:IsDescendantOf(c.model) or mesh.Transparency>=0.98 or tostring(mesh.MeshId)=="" then
                fail("mesh_nativo_removido"); return
            end
        end
        if c.captura then atualizarCaptura(c,now); return end
        local oldMode=c.state.mode
        local seen=candidates(c,now)
        local nextState,effect=Core.step(c.state,{ready=c.ready,candidates=seen,
            attackEnabled=c.attackEnabled,attackHit=c.pendingHit,attackFinished=c.pendingFinished},now,c.timing)
        c.pendingHit,c.pendingFinished=false,false
        c.state=nextState
        local mode=nextState.mode
        local target: any=nil
        for _, candidate in seen do
            if candidate.id==nextState.targetId or candidate.id==nextState.attackVictim then target=candidate end
        end
        if target and target.los and target.velocity then c.targetVelocity=target.velocity end
        if oldMode~=mode then
            stopNavigation(c)
            c.model:SetAttribute("BastiaoState",mode)
            if mode=="chase" and oldMode~="attack" then c.chaseStartedAt=now end
            if mode=="search" then c.searchStartedAt=now; c.buscaIndice=0; c.pancadasDesde=nil end
            if mode=="attack" then
                -- clientes tocam o rugido estourado do bote (MonstroSom)
                c.model:SetAttribute("BastiaoAttackVictim",nextState.attackVictim or 0)
                c.model:SetAttribute("BastiaoAttackSerial",(c.model:GetAttribute("BastiaoAttackSerial") or 0)+1)
            end
            c.human.AutoRotate=mode~="alert" and mode~="attack"
            if mode=="alert" then
                play(c,"06_RUGIDO")
            elseif mode=="attack" then
                play(c,"19_CLAW_LEFT")
            elseif mode=="chase" then
                play(c,"09_ACELERAR")
                c.accelerateUntil=now+c.catalog.animations["09_ACELERAR"].duration
            elseif oldMode=="chase" then
                play(c,"10_FREAR")
                c.brakeUntil=now+c.catalog.animations["10_FREAR"].duration
            end
        end
        if nextState.targetId then c.ultimoAlvo=nextState.targetId end
        if effect.damageId then
            if capturar(c,effect.damageId,now) then return end
            damage(c,effect.damageId)
        end
        c.mover.face=nil
        if mode=="attack" then
            -- Bote: até a garra descer, avança colado no alvo (antes parava e o jogador escapava andando).
            c.mover.face=nextState.lastKnown
            local elapsed=now-(nextState.attackStartedAt or now)
            local victim=if target then target.position else nextState.lastKnown
            if victim and elapsed<(c.timing.hitDelay or 0.5)+0.05 and (flat(victim-c.root.Position)).Magnitude>2.6 then
                setGoal(c,victim,chaseSpeed(c,now),now,true)
            else
                setGoal(c,nil,0,now,true)
            end
            return
        end
        if mode=="alert" then
            -- para e encara quem viu (o rugido sai virado para o jogador)
            c.mover.face=nextState.lastKnown
            setGoal(c,nil,0,now)
            return
        end
        if now<c.brakeUntil then setGoal(c,nil,0,now); return end
        local goal: Vector3?=nil
        local speed=WALK_SPEED
        local urgent=false
        if mode=="chase" then
            goal=nextState.lastKnown
            speed=chaseSpeed(c,now)
            urgent=true
        elseif mode=="search" and c.tracks["17_ESMURRAR_PORTA"] and alvoNaOficina(c) then
            -- o jogador se trancou na oficina: vai até a porta e esmurra até desistir
            if (flat(PORTA_FORA-c.root.Position)).Magnitude>1.6 then
                goal,speed,urgent=PORTA_FORA,SEARCH_SPEED,true
            else
                -- enquanto esmurra, não esquece quem está lá dentro (até ~12 s de pancadas)
                c.pancadasDesde=c.pancadasDesde or now
                if now-c.pancadasDesde<12 then c.state.memoryUntil=math.max(c.state.memoryUntil,now+1) end
                setGoal(c,nil,0,now)
                c.mover.face=PORTA
                local pancada=c.tracks["17_ESMURRAR_PORTA"]
                if c.animation~="17_ESMURRAR_PORTA" or not pancada.IsPlaying then
                    if now>=(c.proximaPancada or 0) then
                        play(c,"17_ESMURRAR_PORTA")
                        c.proximaPancada=now+pancada.Length+0.4
                    elseif c.animation~="01_RESPIRACAO" then
                        play(c,"01_RESPIRACAO")
                    end
                end
                return
            end
        elseif mode=="search" then
            local lost=now-(c.searchStartedAt or now)
            if nextState.lastKnown then
                -- vai aonde o jogador estava indo, não só onde foi visto pela última vez
                local guess=nextState.lastKnown
                local vel=c.targetVelocity
                if vel and lost<SEARCH_FAST_SECONDS and vel.Magnitude>2 then
                    local ahead=guess+vel.Unit*math.min(vel.Magnitude*1.5,24)
                    if inArea(ahead) and not safe(ahead) then guess=ahead end
                end
                if (flat(guess-c.root.Position)).Magnitude>3 then goal=guess end
            end
            if lost<SEARCH_FAST_SECONDS then speed=SEARCH_SPEED; urgent=true end
        else
            local patrol=PATROL[c.patrolIndex]
            if (flat(patrol-c.root.Position)).Magnitude<3 then c.patrolIndex=c.patrolIndex%#PATROL+1 end
            goal=PATROL[c.patrolIndex]
        end
        setGoal(c,goal,speed,now,urgent)
        local speed=c.mover.actualSpeed or 0
        if mode=="chase" and now<c.accelerateUntil then
            -- Let the authored accelerate clip finish before the run loop.
        elseif speed>0.4 and goal then
            local name=if mode=="chase" or speed>6 then "08_CORRER" else "07_ANDAR"
            local authored=if name=="08_CORRER" then 3.2 else 0.62
            local studsPerMeter=c.height/3.000094
            play(c,name,math.clamp(speed/(authored*studsPerMeter),0.2,1.8))
        elseif mode=="search" then
            -- procura viva: vasculha, fareja, olha para um lado e para o outro
            local atual=if c.animation then c.tracks[c.animation] else nil
            local buscando=table.find(BUSCA,c.animation)~=nil
            if not buscando or not (atual and atual.IsPlaying) then
                for _ = 1, #BUSCA do
                    c.buscaIndice=(c.buscaIndice or 0)%#BUSCA+1
                    local n=BUSCA[c.buscaIndice]
                    if c.tracks[n] then play(c,n); break end
                end
            end
        elseif mode=="chase" then play(c,"02_ALERTA")
        else play(c,"01_RESPIRACAO") end
    end

    local function loadAsync(owner: number)
        local imported: Model?=nil
        local function current(): boolean return not destroyed and generation==owner end
        local ok,reason=xpcall(function()
            local catalogModule=op.shared and op.shared:FindFirstChild("MonsterCatalog")
            assert(catalogModule and catalogModule:IsA("ModuleScript"),"MonsterCatalog_ausente")
            local catalog=require(catalogModule)
            local accepted,why=Core.validateCatalog(catalog)
            assert(accepted,why)
            local contractModule=script.Parent:FindFirstChild("MonsterImportContract")
            assert(contractModule and contractModule:IsA("ModuleScript"),"MonsterImportContract_ausente")
            local contract=require(contractModule)
            imported=AssetService:LoadAssetAsync(catalog.modelId) :: Model
            if not current() then return end
            assert(imported and imported:IsA("Model"),"asset_nao_e_modelo")
            for _, item in imported:GetDescendants() do
                assert(not item:IsA("LuaSourceContainer"),"asset_contem_codigo_inesperado")
                -- The importer may add a dormant controller. Prepare validates the
                -- static skeleton before this runtime creates the only Animator.
                if item:IsA("Animator") then item:Destroy() end
            end
            local before=imported:FindFirstChildWhichIsA("MeshPart",true)
            local beforeHeight=if before then before.Size.Y else 0
            local importReport=contract.Prepare(imported,true)
            assert(importReport.ok,"importacao_incompativel:"..table.concat(importReport.errors,"; "))
            local info,rigError=Core.inspectRig(imported,catalog.heightStuds)
            assert(info,rigError)
            local model=imported :: Model
            model.Name="Bastiao731A"
            model:SetAttribute("BastiaoCreature",true)
            model:SetAttribute("BastiaoState","loading")
            model:SetAttribute("BastiaoRoarSerial",0)
            model:SetAttribute("BastiaoMarkerSerial",0)
            model:SetAttribute("BastiaoReady",false)
            model:SetAttribute("BastiaoHeightStuds",info.height)
            model:SetAttribute("BastiaoImportedHeightStuds",beforeHeight)
            model:SetAttribute("BastiaoImportScaleNormalized",math.abs(beforeHeight-info.height)>0.015)
            model:SetAttribute("BastiaoImportRestErrorStuds",importReport.maxRestPositionErrorStuds)
            local center=V(info.centerX,info.centerY,info.centerZ)
            -- O importador do Roblox pode já ter girado o modelo (frente +Z do arquivo -> -Z).
            -- O contrato mede esse giro; aqui só falta o que ainda não foi girado.
            local importYaw=tonumber(importReport.importYawDegrees) or 0
            if importYaw~=importYaw or math.abs(importYaw)==math.huge then importYaw=0 end
            model:SetAttribute("BastiaoImportYawDegrees",importYaw)
            local visualTurn=CFrame.new(center)*CFrame.Angles(0,math.rad(contract.VisualFacingYawDegrees-importYaw),0)*CFrame.new(-center)
            for _, item in model:GetDescendants() do
                if item:IsA("Humanoid") or item:IsA("AnimationController") or item:IsA("JointInstance") then item:Destroy() end
            end
            for _, part in info.parts do
                part.Anchored=true
                part.CanCollide,part.CanTouch,part.CanQuery=false,false,false
                part.Massless=true
                part.CFrame=visualTurn*part.CFrame
            end
            local root=Instance.new("Part")
            root.Name="HumanoidRootPart"
            root.Size=V(info.width,info.height,math.max(1.8,info.depth))
            root.CFrame=CFrame.new(center)
            root.Transparency=1
            root.CanCollide,root.CanTouch,root.CanQuery=true,false,true
            root.Anchored=true
            root.Parent=model
            model.PrimaryPart=root
            for _, part in info.parts do
                local weld=Instance.new("WeldConstraint")
                weld.Part0,weld.Part1=root,part
                weld.Parent=root
            end
            local human=Instance.new("Humanoid")
            human.Name="Humanoid"
            human.RequiresNeck=false
            human.BreakJointsOnDeath=false
            human.AutomaticScalingEnabled=false
            human.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
            human.HipHeight=0.1
            human.WalkSpeed=0
            human.MaxHealth,human.Health=5000,5000
            human.JumpPower=0
            human.Parent=model
            local animator=Instance.new("Animator")
            animator.Parent=human
            local spawn=chooseSpawn(root.Size)
            local spawnDeadline=os.clock()+10
            while not spawn and current() and os.clock()<spawnDeadline do task.wait(0.5); spawn=chooseSpawn(root.Size) end
            assert(spawn,"pontos_de_aparicao_ocupados")
            if not current() then return end
            local at=spawn+V(0,info.height/2+0.12,0)
            model:PivotTo(CFrame.lookAt(at,at+V(0,0,1)))
            local c: any={model=model,root=root,human=human,animator=animator,catalog=catalog,
                height=info.height,radius=math.max(info.width,info.depth)/2,colliderSize=root.Size,
                meshes=info.meshes,tracks={},connections={},samples={},ready=false,
                state=Core.new(os.clock()),animation=nil,patrolIndex=1,brakeUntil=0,accelerateUntil=0,
                pendingHit=false,pendingFinished=false,
                nav={serial=0,busy=false,nextRequest=0,quietUntil=0,failures=0,lastRequest=-math.huge}}
            active=c
            -- Animator must be inside Workspace to load native animation tracks.
            -- Root remains anchored, harmless and BastiaoReady=false until all finish.
            model.Parent=folder
            local assets: {Instance}={}
            for _, mesh in info.meshes do table.insert(assets,mesh) end
            local animations={}
            for _, name in Core.requiredClips do
                local animation=Instance.new("Animation")
                animation.Name=name
                animation.AnimationId="rbxassetid://"..tostring(catalog.animations[name].id)
                animation.Parent=animator
                animations[name]=animation
                table.insert(assets,animation)
            end
            local fetchFailed=false
            ContentProvider:PreloadAsync(assets,function(_,fetchStatus)
                if fetchStatus~=Enum.AssetFetchStatus.Success then fetchFailed=true end
            end)
            assert(not fetchFailed,"conteudo_sem_permissao_ou_nao_carregado")
            if not current() then return end
            for _, name in Core.requiredClips do
                local clip=catalog.animations[name]
                local track=animator:LoadAnimation(animations[name])
                track.Priority,track.Looped=PRIORITY[name],clip.loop
                c.tracks[name]=track
            end
            local tracksDeadline=os.clock()+8
            while current() and os.clock()<tracksDeadline do
                local allReady=true
                for _, track in c.tracks do if track.Length<=0 then allReady=false; break end end
                if allReady then break end
                task.wait(0.1)
            end
            if not current() then return end
            local function ligarMarcadores(name: string, track: AnimationTrack)
                local markerNames={}
                for _, marker in catalog.animations[name].markers or {} do
                    if type(marker)=="table" and type(marker.name)=="string" and not markerNames[marker.name]
                        and Core.markerTime(catalog.animations[name],marker.name) then
                        markerNames[marker.name]=true
                        table.insert(c.connections,track:GetMarkerReachedSignal(marker.name):Connect(function(value)
                            if not c.ready or active~=c or c.animation~=name then return end
                            model:SetAttribute("BastiaoMarkerName",marker.name)
                            model:SetAttribute("BastiaoMarkerValue",tostring(value))
                            model:SetAttribute("BastiaoMarkerSerial",(model:GetAttribute("BastiaoMarkerSerial") or 0)+1)
                            if name=="06_RUGIDO" and marker.name=="Roar" and c.state.mode=="alert" then
                                model:SetAttribute("BastiaoRoarSerial",(model:GetAttribute("BastiaoRoarSerial") or 0)+1)
                            elseif name=="19_CLAW_LEFT" and marker.name=="Hit" and c.state.mode=="attack" then c.pendingHit=true end
                        end))
                    end
                end
            end
            for name, track in c.tracks do
                assert(track.Length>0 and math.abs(track.Length-catalog.animations[name].duration)
                    <=math.max(0.25,catalog.animations[name].duration*0.15),"duracao_nativa_invalida:"..name)
                ligarMarcadores(name,track)
            end
            table.insert(c.connections,c.tracks["19_CLAW_LEFT"].Stopped:Connect(function()
                if c.ready and c.animation=="19_CLAW_LEFT" and c.state.mode=="attack" then c.pendingFinished=true end
            end))
            -- extras opcionais (jumpscare, busca, porta): falha aqui só desliga o extra
            c.extras={}
            local extrasAnim,idParaNome={},{}
            for name in EXTRAS do
                local clip=catalog.animations[name]
                if type(clip)=="table" and type(clip.id)=="number" and clip.id>0 and clip.id%1==0
                    and type(clip.duration)=="number" and clip.duration>0.25 and clip.duration<12 then
                    local animation=Instance.new("Animation")
                    animation.Name=name
                    animation.AnimationId="rbxassetid://"..tostring(clip.id)
                    animation.Parent=animator
                    extrasAnim[name]=animation
                    idParaNome[animation.AnimationId]=name
                end
            end
            local extrasFalhos={}
            pcall(function()
                local lista={}
                for _, a in extrasAnim do table.insert(lista,a) end
                ContentProvider:PreloadAsync(lista,function(conteudo,fetchStatus)
                    local nome=idParaNome[tostring(conteudo)]
                    if fetchStatus~=Enum.AssetFetchStatus.Success and nome then extrasFalhos[nome]=true end
                end)
            end)
            if not current() then return end
            for name, animation in extrasAnim do
                if not extrasFalhos[name] then
                    local ok,track=pcall(function() return animator:LoadAnimation(animation) end)
                    if ok and track then
                        track.Priority,track.Looped=EXTRAS[name],false
                        c.tracks[name]=track
                        c.extras[name]=true
                    end
                end
            end
            local extrasDeadline=os.clock()+4
            while current() and os.clock()<extrasDeadline do
                local pronto=true
                for name in c.extras do if c.tracks[name].Length<=0 then pronto=false; break end end
                if pronto then break end
                task.wait(0.1)
            end
            if not current() then return end
            local extrasProntos={}
            for name in table.clone(c.extras) do
                local track=c.tracks[name]
                local clip=catalog.animations[name]
                if track.Length<=0 or math.abs(track.Length-clip.duration)>math.max(0.25,clip.duration*0.15) then
                    c.extras[name]=nil; c.tracks[name]=nil; track:Destroy()
                else
                    ligarMarcadores(name,track)
                    table.insert(extrasProntos,name)
                end
            end
            table.sort(extrasProntos)
            model:SetAttribute("BastiaoExtras",table.concat(extrasProntos,","))
            local hit=Core.markerTime(catalog.animations["19_CLAW_LEFT"],"Hit")
            local roar=Core.markerTime(catalog.animations["06_RUGIDO"],"Roar")
            assert(roar,"marcador_Roar_nativo_ausente")
            c.attackEnabled=hit~=nil and hit>=0.4 and hit<catalog.animations["19_CLAW_LEFT"].duration-0.2
            c.timing={hitDelay=hit or math.huge,attackDuration=catalog.animations["19_CLAW_LEFT"].duration,
                roarDuration=catalog.animations["06_RUGIDO"].duration}
            -- O corpo continua ancorado: o servidor move o modelo inteiro a cada quadro pelos
            -- corredores (moveStep). Nada de física de Humanoid nem dono de rede.
            c.mover={route=nil,index=1,goal=nil,speed=0,targetSpeed=0,actualSpeed=0,recomputeAt=0,face=nil,urgent=false}
            model:SetAttribute("BastiaoAttackSerial",0)
            model:SetAttribute("BastiaoHitSerial",0)
            c.ready=true
            c.state=Core.new(os.clock())
            model:SetAttribute("BastiaoReady",true)
            model:SetAttribute("BastiaoAttackEnabled",c.attackEnabled)
            model:SetAttribute("BastiaoState","roam")
            play(c,"01_RESPIRACAO")
            loading=false
            report("active",nil)
        end,function(err) return tostring(err) end)
        if not current() then
            if imported and (not active or active.model~=imported) then imported:Destroy() end
            return
        end
        if not ok then
            if imported and (not active or active.model~=imported) then imported:Destroy() end
            fail(tostring(reason))
        end
    end

    local existing=op.world:FindFirstChild("Criatura")
    if existing then
        report("unavailable","pasta_criatura_ocupada")
        warn("[Bastiao731A] pasta Criatura ocupada; nada foi substituído")
        return {status=status,destroy=function() end}
    end
    folder=Instance.new("Folder")
    folder.Name="Criatura"
    folder:SetAttribute("BastiaoCreatureRuntime",true)
    folder.Parent=op.world
    -- Only this owned, noncolliding navigation volume is added to the scene.
    local exclusion=Instance.new("Part")
    exclusion.Name="OficinaProtegida"
    exclusion.Size=V(46.1,20,44)
    exclusion.CFrame=CFrame.new(88.95,6,-320)
    exclusion.Anchored=true
    exclusion.Transparency=1
    exclusion.CanCollide,exclusion.CanTouch,exclusion.CanQuery=false,false,false
    local modifier=Instance.new("PathfindingModifier")
    modifier.Label="Bastiao731Safe"
    modifier.PassThrough=false
    modifier.Parent=exclusion
    exclusion.Parent=folder
    report("dormant",nil)

    heartbeat=RunService.Heartbeat:Connect(function(dt)
        if active and active.ready and active.mover and not destroyed then
            local ok,err=pcall(moveStep,active,dt)
            if not ok then fail("andar:"..tostring(err)); return end
        end
        accumulator+=dt
        if accumulator<TICK or destroyed then return end
        accumulator=0
        if not op.world.Parent then
            destroyed=true; generation+=1
            clearCreature()
            if heartbeat then heartbeat:Disconnect() end
            return
        end
        local unlocked=Core.unlocked(op.mundo:estado("porta_contencao"),op.mundo:estado("alarme"))
        if not unlocked then
            if active or loading or failed then
                generation+=1; loading,failed=false,false
                clearCreature()
                local diagnostic=folder and folder:FindFirstChild("Diagnostico")
                if diagnostic then diagnostic:Destroy() end
                report("dormant",nil)
            end
            return
        end
        local now=os.clock()
        if loading and now>loadDeadline then fail("tempo_limite_de_assets"); return end
        if not active and not loading and not loaderBusy and not failed then
            generation+=1
            loading,loadDeadline=true,now+40
            report("loading",nil)
            local owner=generation
            loaderBusy=true
            loaderThread=task.spawn(function()
                loadAsync(owner)
                loaderBusy=false
            end)
        elseif active and active.ready then
            local ok,err=xpcall(function() update(active,now) end,function(message) return tostring(message) end)
            if not ok then fail("runtime:"..tostring(err)) end
        end
    end)

    return {status=status,destroy=function()
        if destroyed then return end
        destroyed=true; generation+=1
        if heartbeat then heartbeat:Disconnect(); heartbeat=nil end
        clearCreature()
        -- The loader checks generation after every yield and destroys late assets.
        -- Do not cancel an engine request then incorrectly free its concurrency slot.
        loaderThread=nil
        if folder then folder:Destroy(); folder=nil end
        report("destroyed",nil)
    end}
end

return Criatura
