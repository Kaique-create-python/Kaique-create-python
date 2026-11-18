-- Behavioral tests for the production decision core; no Roblox runtime is simulated.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local path = "src/server/CriaturaCore.luau"
local Core = if fs.isFile(path) then luau.load(fs.readFile(path), {debugName=path})() else {}
local passed, failed = 0, 0
local function test(name, fn)
    local ok, message = pcall(fn)
    if ok then passed += 1; print("PASS", name)
    else failed += 1; print("FAIL", name, tostring(message)) end
end
local function call(name, ...)
    assert(type(Core[name]) == "function", "missing creature behavior: " .. name)
    return Core[name](...)
end
local function actor(changes)
    local c = {id=12, position={x=4,z=-400}, alive=true, safe=false, inArea=true,
        distance=20, dot=1, los=true, sprinting=false, speed=0, measuredSpeed=0,
        grounded=true, hearingClear=true}
    for k,v in changes or {} do c[k]=v end
    return c
end
local function step(s, now, candidates, changes)
    local observation = {ready=true, candidates=candidates or {}, reachedMemory=false,
        attackEnabled=true, attackHit=false, attackFinished=false}
    for k,v in changes or {} do observation[k]=v end
    return call("step", s, observation, now)
end
local function chase()
    local s = call("new",0)
    s = step(s,1,{actor()})
    s = step(s,4,{actor()})
    return s
end
test("containment and alarm must both be ready after the introduction",function()
    assert(call("unlocked","trancada","ligado")==false)
    assert(call("unlocked","destravada","desligado")==false)
    assert(call("unlocked","destravada","ligado")==true)
end)
test("sight uses distance, FOV, life and an unobstructed ray",function()
    assert(call("canSee",actor())==true)
    for _,change in {{distance=100},{dot=-1},{los=false},{alive=false},{inArea=false},{safe=true}} do
        assert(call("canSee",actor(change))==false)
    end
end)
test("sprinting flag alone cannot create a noise source",function()
    assert(call("canHear",actor({sprinting=true}))==false)
    assert(call("canHear",actor({sprinting=true,speed=22,measuredSpeed=21}))==true)
    for _,change in {{distance=40},{grounded=false},{hearingClear=false},{safe=true},{measuredSpeed=130}} do
        local c=actor({sprinting=true,speed=22,measuredSpeed=21})
        for k,v in change do c[k]=v end
        assert(call("canHear",c)==false)
    end
end)
test("the real Sector7 18stud sprint remains audible with ordinary velocity variation",function()
    assert(call("canHear",actor({sprinting=true,speed=17.8,measuredSpeed=17.2}))==true)
end)
test("the encounter stays on tall corridors and excludes eightstud room portals",function()
    assert(call("inEncounterArea",{x=0,y=3,z=-440})==true)
    assert(call("inEncounterArea",{x=58,y=3,z=-320})==true)
    assert(call("inEncounterArea",{x=25,y=3,z=-260})==true)
    for _,p in {{x=75,y=3,z=-320},{x=-88,y=3,z=-320},{x=20,y=3,z=-320},{x=0,y=3,z=0},{x=0,y=30,z=-440}} do
        assert(call("inEncounterArea",p)==false)
    end
end)
test("workshop bounds protect every side and reject malformed positions",function()
    assert(call("inSafeZone",{x=76,y=3,z=-318})==true)
    assert(call("inSafeZone",{x=65.9,y=-4,z=-342})==true)
    assert(call("inSafeZone",{x=58,y=3,z=-320})==false)
    assert(call("inSafeZone",{x=0/0,y=3,z=-320})==false)
end)
test("a new visible player causes a readable roar before a chase",function()
    local s=call("new",0)
    local nextState,effect=step(s,1,{actor()})
    assert(nextState.mode=="alert" and effect.roar==true)
    assert(s.mode=="roam", "decision mutated its prior snapshot")
    local waiting,waitingEffect=step(nextState,2,{actor()})
    assert(waiting.mode=="alert" and waitingEffect.roar~=true)
    local running=step(waiting,4,{actor()})
    assert(running.mode=="chase" and running.targetId==12)
end)
test("losing LOS searches the last seen position instead of tracking through walls",function()
    local s=chase()
    local old=s.lastKnown
    s=step(s,4.3,{actor({los=false,position={x=55,z=-320}})})
    assert(s.mode=="search" and s.lastKnown==old and s.targetId==nil)
end)
test("unseen movement never refreshes memory and the search expires",function()
    local s=chase()
    s=step(s,5,{actor({los=false})})
    s=step(s,10,{actor({los=false})})
    assert(s.mode=="search" and s.lastSenseAt==4)
    s=step(s,15,{actor({los=false})})
    assert(s.mode=="roam" and s.lastKnown==nil and s.targetId==nil)
end)
test("audible sprinting creates a bounded investigation, without granting sight",function()
    local s=call("new",0)
    s=step(s,1,{actor({los=false,dot=-1,sprinting=true,speed=22,measuredSpeed=20})})
    assert(s.mode=="search" and s.targetId==nil and s.lastSenseAt==1)
    s=step(s,13,{})
    assert(s.mode=="roam" and s.lastKnown==nil)
end)
test("entering the workshop prevents targeting and damage even through an open doorway",function()
    local s=chase()
    s=step(s,4.2,{actor({safe=true,distance=3})})
    assert(s.mode=="search" and s.targetId==nil)
    local none=call("new",0)
    none=step(none,1,{actor({safe=true,distance=3,sprinting=true,speed=22,measuredSpeed=21})})
    assert(none.mode=="roam")
end)
test("a missing ready model cannot acquire targets or deliver damage",function()
    local s=chase()
    local disabled,effect=step(s,4.2,{actor({distance=3})},{ready=false,attackHit=true})
    assert(disabled.mode=="disabled" and effect.damageId==nil and disabled.targetId==nil)
end)
test("attack starts with windup and only a matching hit marker can attempt damage",function()
    local s=chase()
    local effect
    s,effect=step(s,4.2,{actor({distance=4})})
    assert(s.mode=="attack" and effect.damageId==nil)
    s,effect=step(s,4.3,{actor({distance=4})},{attackHit=true})
    assert(effect.damageId==nil, "early marker bypassed the windup")
    s,effect=step(s,4.8,{actor({distance=4})},{attackHit=true})
    assert(effect.damageId==12)
    s,effect=step(s,4.9,{actor({distance=4})},{attackHit=true})
    assert(effect.damageId==nil, "one swing dealt damage twice")
end)
test("range LOS life and safe zone are revalidated when a swing lands",function()
    for _,change in {{distance=12},{los=false},{alive=false},{safe=true},{inArea=false}} do
        local s=chase()
        s=step(s,4.2,{actor({distance=4})})
        local victim=actor({distance=4})
        for k,v in change do victim[k]=v end
        local _,effect=step(s,4.8,{victim},{attackHit=true})
        assert(effect.damageId==nil)
    end
end)
test("recovery and cooldown prevent repeated proximity attacks",function()
    local s=chase()
    s=step(s,4.2,{actor({distance=4})})
    s=step(s,4.8,{actor({distance=4})},{attackHit=true})
    s=step(s,5.6,{actor({distance=4})},{attackFinished=true})
    assert(s.mode=="chase")
    s=step(s,5.8,{actor({distance=4})})
    assert(s.mode=="chase")
    s=step(s,7.3,{actor({distance=4})})
    assert(s.mode=="attack")
end)
test("an unavailable verified attack leaves the encounter harmless",function()
    local s=chase()
    local effect
    s,effect=step(s,4.2,{actor({distance=3})},{attackEnabled=false,attackHit=true})
    assert(s.mode=="chase" and effect.damageId==nil)
end)
test("dead or departed players are forgotten without acquiring their live position",function()
    local s=chase()
    s=step(s,5,{actor({alive=false,position={x=90,z=-320}})})
    assert(s.mode=="search" and s.targetId==nil and s.lastKnown.x==4)
    s=step(s,16,{})
    assert(s.mode=="roam")
end)
test("invalid numeric sensing data cannot grant a perception or attack",function()
    for _,change in {{distance=0/0},{distance=math.huge},{dot=0/0},{speed=math.huge},{measuredSpeed=0/0}} do
        local c=actor({sprinting=true,speed=22,measuredSpeed=21})
        for k,v in change do c[k]=v end
        if change.distance or change.dot then assert(call("canSee",c)==false) end
        if change.speed or change.measuredSpeed or change.distance then assert(call("canHear",c)==false) end
    end
end)
print(string.format("Creature core: %d passed, %d failed",passed,failed))
assert(failed==0,"creature decision regressions failed")
