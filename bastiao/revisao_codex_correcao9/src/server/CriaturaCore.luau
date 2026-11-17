--!strict
-- Engine-free decisions. Positions are opaque snapshots supplied by the server;
-- an unseen player's live position is never read to refresh the memory.
local Core = {}

local function finite(n: any): boolean
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

local function eligible(c: any): boolean
    return c.alive == true and c.safe ~= true and c.inArea == true
        and finite(c.distance) and c.distance >= 0
end

function Core.unlocked(containment: any, alarm: any): boolean
    return containment == "destravada" and alarm == "ligado"
end

function Core.canSee(c: any): boolean
    return eligible(c) and c.distance <= 86 and finite(c.dot)
        and c.dot >= 0.5 and c.los == true
end

function Core.canHear(c: any): boolean
    -- The existing Sector7 server supplies Sprinting. Require measured movement
    -- as well, so an attribute or client request alone is not a noise source.
    return eligible(c) and c.distance <= 30 and c.sprinting == true
        and c.grounded == true and c.hearingClear == true
        and finite(c.speed) and c.speed >= 16.5 and c.speed <= 38
        and finite(c.measuredSpeed) and c.measuredSpeed >= 16 and c.measuredSpeed <= 38
end

local function point(p: any): boolean
    return type(p) == "table" and finite(p.x) and finite(p.y) and finite(p.z)
end

function Core.inSafeZone(p: any): boolean
    return point(p) and p.x >= 65.9 and p.x <= 112 and p.y >= -4
        and p.y <= 16 and p.z >= -342 and p.z <= -298
end

function Core.inEncounterArea(p: any): boolean
    if not point(p) or p.y < -2 or p.y > 14 or p.z < -470 or p.z > -234 then return false end
    return math.abs(p.x) <= 5.5
        or (math.abs(math.abs(p.x) - 58) <= 5 and p.z >= -447 and p.z <= -239)
        or (math.abs(p.x) <= 63 and (math.abs(p.z + 440) <= 5 or math.abs(p.z + 260) <= 5))
end

function Core.new(now: number): any
    return {mode="roam", enteredAt=now, targetId=nil, lastKnown=nil,
        lastSenseAt=-math.huge, memoryUntil=-math.huge, nextRoarAt=now,
        nextAttackAt=now, attackStartedAt=nil, attackVictim=nil, hitConsumed=false}
end

local function change(s: any, mode: string, now: number)
    if s.mode ~= mode then s.mode, s.enteredAt = mode, now end
end

function Core.step(previous: any, observation: any, now: number, timing: any?): (any, any)
    local s = table.clone(previous)
    local effect: any = {}
    local tune = timing or {}
    if observation.ready ~= true or not finite(now) or now < previous.enteredAt then
        change(s, "disabled", if finite(now) then now else previous.enteredAt)
        s.targetId, s.attackVictim, s.lastKnown = nil, nil, nil
        return s, effect
    end
    local visible, heard, victim = nil, nil, nil
    for _, c in observation.candidates do
        if c.id == s.attackVictim then victim = c end
        if Core.canSee(c) then
            if not visible or c.id == s.targetId or (visible.id ~= s.targetId and c.distance < visible.distance) then
                visible = c
            end
        elseif Core.canHear(c) and (not heard or c.distance < heard.distance) then
            heard = c
        end
    end
    if visible then
        s.lastKnown, s.lastSenseAt, s.memoryUntil = visible.position, now, now + 9
    elseif heard then
        s.lastKnown, s.lastSenseAt, s.memoryUntil = heard.position, now, now + 9
    end

    if s.mode == "attack" then
        local elapsed = now - s.attackStartedAt
        if observation.attackHit == true and not s.hitConsumed and elapsed >= (tune.hitDelay or 0.5) then
            s.hitConsumed = true -- a miss also consumes the swing
            if observation.attackEnabled == true and victim and eligible(victim)
                and victim.distance <= 6 and victim.los == true then
                effect.damageId = s.attackVictim
            end
        end
        if observation.attackFinished == true or elapsed >= (tune.attackDuration or 1.34) + 0.25 then
            s.attackVictim, s.attackStartedAt = nil, nil
            change(s, if visible then "chase" else "search", now)
            s.targetId = if visible then visible.id else nil
        end
        return s, effect
    end

    if visible then
        s.targetId = visible.id
        if s.mode ~= "alert" and s.mode ~= "chase" then
            if now >= s.nextRoarAt then
                change(s, "alert", now)
                s.nextRoarAt = now + 20
                effect.roar = true
            else
                change(s, "chase", now)
            end
        end
        if s.mode == "alert" then
            if now - s.enteredAt >= (tune.roarDuration or 2.8) then change(s, "chase", now) end
        elseif s.mode == "chase" and observation.attackEnabled == true
            and visible.distance <= 5 and now >= s.nextAttackAt then
            change(s, "attack", now)
            s.attackStartedAt, s.attackVictim, s.hitConsumed = now, visible.id, false
            s.nextAttackAt = now + 3
        end
    else
        s.targetId = nil
        if s.lastKnown and now < s.memoryUntil then
            change(s, "search", now)
        else
            s.lastKnown, s.memoryUntil = nil, -math.huge
            change(s, "roam", now)
        end
    end
    return s, effect
end

Core.requiredClips = table.freeze({
    "01_RESPIRACAO", "02_ALERTA", "06_RUGIDO", "07_ANDAR", "08_CORRER",
    "09_ACELERAR", "10_FREAR", "15_VASCULHAR", "19_CLAW_LEFT",
})

local function assetId(n: any): boolean
    return finite(n) and n > 0 and n < 9007199254740992 and n % 1 == 0
end

function Core.markerTime(clip: any, name: string): number?
    if type(clip) ~= "table" or type(clip.markers) ~= "table" then return nil end
    for _, marker in clip.markers do
        if type(marker) == "table" and marker.name == name and finite(marker.time)
            and marker.time >= 0 and marker.time < clip.duration then
            return marker.time
        end
    end
    return nil
end

function Core.validateCatalog(catalog: any): (boolean, string?)
    if type(catalog) ~= "table" or catalog.version ~= 1 or catalog.enabled ~= true then
        return false, "catalogo_desabilitado"
    end
    if not assetId(catalog.modelId) then return false, "modelo_id_invalido" end
    if not finite(catalog.heightStuds) or catalog.heightStuds < 8 or catalog.heightStuds > 11.5 then
        return false, "altura_incompativel_com_corredor"
    end
    if type(catalog.animations) ~= "table" then return false, "animacoes_ausentes" end
    local loops = {["01_RESPIRACAO"]=true, ["02_ALERTA"]=true, ["07_ANDAR"]=true, ["08_CORRER"]=true}
    for _, name in Core.requiredClips do
        local clip = catalog.animations[name]
        if type(clip) ~= "table" or not assetId(clip.id) or not finite(clip.duration)
            or clip.duration < 0.25 or clip.duration > 12 or type(clip.loop) ~= "boolean"
            or clip.loop ~= (loops[name] == true) then
            return false, "animacao_invalida:" .. name
        end
    end
    return true, nil
end

function Core.inspectRig(model: any, expectedHeight: number): (any?, string?)
    if typeof(model) ~= "Instance" or not model:IsA("Model") then return nil, "modelo_ausente" end
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    local meshes, parts, boneCount, names = {}, {}, 0, {}
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then table.insert(parts, d) end
        if d:IsA("MeshPart") and d.Transparency < 0.98 and tostring(d.MeshId) ~= "" then
            table.insert(meshes, d)
            local cf, h = d.CFrame, d.Size * 0.5
            local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
            local x = math.abs(r.X)*h.X + math.abs(u.X)*h.Y + math.abs(l.X)*h.Z
            local y = math.abs(r.Y)*h.X + math.abs(u.Y)*h.Y + math.abs(l.Y)*h.Z
            local z = math.abs(r.Z)*h.X + math.abs(u.Z)*h.Y + math.abs(l.Z)*h.Z
            minX, minY, minZ = math.min(minX,cf.Position.X-x), math.min(minY,cf.Position.Y-y), math.min(minZ,cf.Position.Z-z)
            maxX, maxY, maxZ = math.max(maxX,cf.Position.X+x), math.max(maxY,cf.Position.Y+y), math.max(maxZ,cf.Position.Z+z)
        elseif d:IsA("Bone") then
            local parent = d.Parent
            while parent and parent ~= model and not parent:IsA("MeshPart") do parent = parent.Parent end
            if parent and parent:IsA("MeshPart") then
                boneCount += 1
                names[d.Name] = true
            end
        end
    end
    if #meshes == 0 then return nil, "mesh_visivel_ausente" end
    if boneCount < 40 then return nil, "esqueleto_nativo_ausente" end
    for _, name in {"pelvis","chest","head","foot.L","foot.R"} do
        if not names[name] then return nil, "osso_ausente:" .. name end
    end
    local height = maxY-minY
    if not finite(expectedHeight) or math.abs(height-expectedHeight) > math.max(0.35,expectedHeight*0.08) then
        return nil, "altura_real_difere_do_catalogo"
    end
    if height < 8 or height > 11.5 or maxX-minX > 11 or maxZ-minZ > 11 then
        return nil, "dimensoes_nao_cabem_no_corredor"
    end
    return {height=height,width=maxX-minX,depth=maxZ-minZ,minY=minY,
        centerX=(minX+maxX)/2,centerY=(minY+maxY)/2,centerZ=(minZ+maxZ)/2,
        boneCount=boneCount,meshes=meshes,parts=parts}, nil
end

return table.freeze(Core)
