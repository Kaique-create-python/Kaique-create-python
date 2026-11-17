local fs = require("@lune/fs")
local Harness = require("./client_harness")
assert(fs.isFile("src/client/Foley.luau"), "Foley must own only successfully loaded steps and clean up its sounds")
local function catalog()
	local assets = {}
	for _, key in { "soldier_step_concrete_01", "soldier_step_metal_01", "monster_step_01", "monster_roar", "monster_breath", "ui_click", "ui_confirm", "ui_denied" } do
		assets[key] = { id = 1234, duration = 0.5, start = 1, finish = 1.5, spatial = not string.find(key, "ui_"), category = if string.find(key, "ui_") then "UI" else "Foley", loop = key == "monster_breath" }
	end
	assets.pavel_cafe = { id = 9999, duration = 2, category = "Voice" }
	assets.bunker_air = { id = 8888, duration = 2, category = "Ambience", loop = true }
	return { version = 1, assets = assets }
end
local function start(config)
	local h = Harness.new(config)
	local model, root, humanoid, running = h:character("Soldier")
	h.player.Character = model
	local states = {}
	local api = h:load("src/client/Foley.luau").start(h.player, catalog(), { aoPassosMudar = function(ready) table.insert(states, ready) end })
	return h, api, root, humanoid, running, states
end
local h, api, root, humanoid, running, states = start({ preload = true, autoLoad = true })
assert(running.Volume == 0.65, "creating Foley cannot silence stock Running before preload succeeds")
assert(states[#states] == false)
h:flush()
assert(states[#states] == true)
for i = 1, 12 do root.Position = h.environment.Vector3.new(i, 0, 0); h:tick(0.1) end
assert(running.Volume == 0 and h:countPlaying("soldier_step_concrete_01") >= 2)
for _, play in h.played do
	assert(play.sound.SoundId ~= "rbxassetid://9999" and play.sound.SoundId ~= "rbxassetid://8888", "Foley must not duplicate voices or ambience")
	assert(play.position == 1 and play.region.Min == 1 and play.region.Max == 1.5, "atlas must seek only after loading and remain inside its native region")
end
local before = h:countPlaying()
humanoid.FloorMaterial = h.environment.Enum.Material.Air
humanoid._state = h.environment.Enum.HumanoidStateType.Freefall
for i = 13, 24 do root.Position = h.environment.Vector3.new(i, 0, 0); h:tick(0.1) end
assert(h:countPlaying() == before, "airborne actor cannot emit step sounds")
humanoid.FloorMaterial = h.environment.Enum.Material.Concrete
humanoid._state = h.environment.Enum.HumanoidStateType.Running
root.Position = h.environment.Vector3.new(1000, 0, 0); h:tick(0.1)
assert(h:countPlaying() == before, "teleport must not make a burst of steps")
local monster, monsterRoot = h:character("Bastiao731A", h.story)
monster:SetAttribute("BastiaoCreature", true)
monster:SetAttribute("BastiaoState", "dormant")
monster:SetAttribute("BastiaoRoarSerial", 4)
h.hit = { Material = h.environment.Enum.Material.Concrete }
for _ = 1, 20 do h:tick(0.1) end
assert(h:countPlaying("monster_breath") == 0 and h:countPlaying("monster_roar") == 0)
monster:SetAttribute("BastiaoState", "roam")
monsterRoot.Position = root.Position
for i = 1, 10 do monsterRoot.Position += h.environment.Vector3.new(1, 0, 0); h:tick(0.1) end
assert(h:countPlaying("monster_breath") == 1 and h:countPlaying("monster_step_01") >= 1)
monster:SetAttribute("BastiaoState", "alert")
monster:SetAttribute("BastiaoRoarSerial", 5)
assert(h:countPlaying("monster_roar") == 1)
-- A rig can be within raycast distance of the floor during the start of a jump.
local monsterHumanoid = monster:FindFirstChildOfClass("Humanoid")
monster:SetAttribute("BastiaoState", "chase")
monsterHumanoid._state = h.environment.Enum.HumanoidStateType.Jumping
monsterHumanoid.FloorMaterial = h.environment.Enum.Material.Air
local groundedCount = h:countPlaying("monster_step_01")
for _ = 1, 10 do monsterRoot.Position += h.environment.Vector3.new(1, 0, 0); h:tick(0.1) end
assert(h:countPlaying("monster_step_01") == groundedCount, "a raycast near the floor must not permit airborne monster steps")
-- Servidor com marcadores: o passo sai no pé (Foot_*), não pelo ritmo de distância, mesmo
-- quando o Humanoid do monstro (movido sem física) não diz que está andando.
monster:SetAttribute("BastiaoMarkerSerial", 0)
local byMarker = h:countPlaying("monster_step_01")
for _ = 1, 10 do monsterRoot.Position += h.environment.Vector3.new(1, 0, 0); h:tick(0.1) end
assert(h:countPlaying("monster_step_01") == byMarker, "with markers the distance cadence must stay silent")
monster:SetAttribute("BastiaoMarkerName", "Foot_R"); monster:SetAttribute("BastiaoMarkerSerial", 1)
assert(h:countPlaying("monster_step_01") == byMarker + 1, "foot marker must play a monster step")
monster:SetAttribute("BastiaoMarkerName", "NeckSnap"); monster:SetAttribute("BastiaoMarkerSerial", 2)
assert(h:countPlaying("monster_step_01") == byMarker + 1, "non-foot marker must not play a step")
monster:SetAttribute("BastiaoMarkerName", "Foot_L"); monster:SetAttribute("BastiaoMarkerSerial", 3)
assert(h:countPlaying("monster_step_01") == byMarker + 2, "every foot contact plays")
assert(api.ui("ui_click") == true and api.ui("ui_click") == false)
assert(api.ui("pavel_cafe") == false)
local countBeforeDestroy = h:countPlaying()
api.destroy(); api.destroy()
assert(running.Volume == 0.65 and states[#states] == false)
for _, node in h.nodes do
	if node.Name == "BastiaoFoleyLocal" or string.sub(node.Name, 1, 8) == "Bastiao_" then assert(node._destroyed, node.Name .. " leaked") end
end
for _, c in h.connections do assert(not c.Connected, "Foley connection leaked") end
monster:SetAttribute("BastiaoRoarSerial", 6); h:tick(10)
assert(h:countPlaying() == countBeforeDestroy)
for _, config in { { preload = false }, { preload = true, regions = false }, { preload = true, length = 0.8 } } do
	local bad, failed, _, _, default, readiness = start(config)
	bad:flush(); bad:tick(0.1)
	assert(default.Volume == 0.65 and readiness[#readiness] == false, "unloaded or unusable regions cannot take over footsteps")
	failed.destroy()
end
for _, failure in { "regions", "length" } do
	local config = { preload = true, autoLoad = true }
	local failed, session, movingRoot, _, stock, readiness = start(config)
	failed:flush()
	assert(readiness[#readiness] == true)
	if failure == "regions" then config.regions = false else config.length = 0 end
	for i = 1, 6 do movingRoot.Position = failed.environment.Vector3.new(i, 0, 0); failed:tick(0.1) end
	assert(readiness[#readiness] == false and stock.Volume == 0.65, "a runtime asset/region failure must return ownership to Som and restore stock footsteps")
	session.destroy()
end
local capped, uiSession = start({ preload = true, autoLoad = true })
capped:flush()
for _ = 1, 20 do uiSession.ui("ui_click"); capped:tick(0.1) end
local uiCount = 0
for _, node in capped.nodes do if node.Name == "Bastiao_ui_click" and not node._destroyed then uiCount += 1 end end
assert(uiCount <= 3, "rapid real activations must keep at most three UI sounds")
uiSession.destroy()
print("PASS Foley preload handoff, regions, grounded travel, creature cues, limits and cleanup (service harness; no audio engine)")
