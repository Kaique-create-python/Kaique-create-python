-- Small, deterministic threat. Server raycasts prevent seeing/hitting through walls.
local Players = game:GetService("Players")
local Threat = {}
function Threat.start(world, config, feedback)
    local model = Instance.new("Model")
    model.Name = "TheListener"
    local function part(name, size, offset, color)
        local p = Instance.new("Part")
        p.Name=name; p.Size=size; p.CFrame=CFrame.new(offset)
        p.Color=color; p.Material=Enum.Material.Slate; p.Anchored=true
        p.CanCollide=false; p.CanTouch=false; p.Parent=model
        return p
    end
    local dark=Color3.fromRGB(24,27,25)
    local core=part("Body",Vector3.new(2.2,3.5,1.2),Vector3.new(0,4,0),dark)
    part("Head",Vector3.new(1.2,1.7,1.1),Vector3.new(0,6.4,0),dark)
    part("ArmL",Vector3.new(.55,4,.6),Vector3.new(-1.5,3.7,0),dark)
    part("ArmR",Vector3.new(.55,4,.6),Vector3.new(1.5,3.7,0),dark)
    part("LegL",Vector3.new(.7,2.8,.8),Vector3.new(-.6,1.5,0),dark)
    part("LegR",Vector3.new(.7,2.8,.8),Vector3.new(.6,1.5,0),dark)
    for _,x in ipairs({-.28,.28}) do
        local eye=part("Eye",Vector3.new(.12,.12,.08),Vector3.new(x,6.5,-.57),Color3.fromRGB(200,165,102))
        eye.Material=Enum.Material.Neon
    end
    model.PrimaryPart=core
    model.Parent=world
    local nodes=world:FindFirstChild("CreatureNodes")
    local route=nodes and nodes:GetChildren() or {}
    table.sort(route,function(a,b) return a.Name<b.Name end)
    local position=Vector3.new(0,0,-160)
    local index=1
    local lastHit,lastScare={},{}
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={model}
    local function visible(character, root)
        local origin=position+Vector3.new(0,4,0)
        local hit=workspace:Raycast(origin,root.Position-origin,params)
        return not hit or hit.Instance:IsDescendantOf(character)
    end
    task.spawn(function()
        while model.Parent do
            local dt=task.wait(.1)
            if not workspace:GetAttribute("S7Power") then
                model:PivotTo(CFrame.new(0,-100,-160))
                continue
            end
            local target,nearest=nil,config.ThreatRange
            for _,player in Players:GetPlayers() do
                local c=player.Character
                local root=c and c:FindFirstChild("HumanoidRootPart")
                local h=c and c:FindFirstChildOfClass("Humanoid")
                if root and h and h.Health>0 and not player:GetAttribute("Escaped") then
                    local distance=(root.Position-(position+Vector3.new(0,3,0))).Magnitude
                    if distance<nearest and visible(c,root) then target=player;nearest=distance end
                end
            end
            local goal
            if target then
                local targetRoot=target.Character and target.Character:FindFirstChild("HumanoidRootPart")
                if targetRoot then goal=targetRoot.Position*Vector3.new(1,0,1) end
                local now=os.clock()
                if now-(lastScare[target] or -99)>12 then
                    lastScare[target]=now
                    feedback:FireClient(target,{kind="scare",title="ELE ESTÁ OUVINDO",text="Guarde fôlego. Quebre a linha de visão."})
                end
                if nearest<4.5 and now-(lastHit[target] or -99)>config.ThreatHitCooldown then
                    lastHit[target]=now
                    target.Character:FindFirstChildOfClass("Humanoid"):TakeDamage(config.ThreatDamage)
                end
            elseif #route>0 then
                goal=route[index].Position*Vector3.new(1,0,1)
                if (goal-position).Magnitude<2 then index=index%#route+1 end
            end
            if goal then
                local delta=goal-position
                local distance=delta.Magnitude
                if distance>.1 then
                    local step=delta.Unit*math.min(distance,(target and config.ThreatChaseSpeed or config.ThreatSpeed)*math.min(dt,.25))
                    local hit=workspace:Raycast(position+Vector3.new(0,3,0),step.Unit*(step.Magnitude+1.1),params)
                    if not hit or (target and hit.Instance:IsDescendantOf(target.Character)) then
                        position+=step
                    elseif not target then index=index%math.max(#route,1)+1 end
                    -- Model pivot is its original bounding-box center, about y=3.5.
                    model:PivotTo(CFrame.lookAt(position+Vector3.new(0,3.5,0),position+Vector3.new(step.X,3.5,step.Z)))
                end
            end
        end
    end)
end
return Threat
