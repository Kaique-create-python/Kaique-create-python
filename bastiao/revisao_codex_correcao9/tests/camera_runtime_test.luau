local Harness = require("./client_harness")
local roblox = require("@lune/roblox")
local h = Harness.new()
local originalNew = h.new
function h:new(class, ...)
	local node = originalNew(self, class, ...)
	if class == "Humanoid" then node.HealthChanged = self:signal(); node.MaxHealth = 100 end
	return node
end
h.player.CharacterRemoving = h:signal()
h.services.ReplicatedStorage = h:new("ReplicatedStorage")
h.services.Lighting = h:new("Lighting")
h.services.RunService.RenderStepped = h:signal()
h.environment.CFrame = roblox.CFrame
h.environment.ColorSequence = roblox.ColorSequence
h.environment.ColorSequenceKeypoint = roblox.ColorSequenceKeypoint
h.environment.NumberSequence = roblox.NumberSequence
h.environment.NumberSequenceKeypoint = roblox.NumberSequenceKeypoint
h.services.GuiService.ReducedMotionEnabled = false
local camera = h:new("Camera", "Camera", h.workspace)
camera.CFrame = roblox.CFrame.new(5, 6, 7)
camera.FieldOfView = 77
camera.CameraType = roblox.Enum.CameraType.Custom
h.workspace.CurrentCamera = camera
local steps = {}
h.services.RunService.BindToRenderStep = function(_, name, priority, fn) steps[name] = { priority, fn } end
h.services.RunService.UnbindFromRenderStep = function(_, name) steps[name] = nil end
local function frame(dt)
	h.now += dt
	local ordered = {}; for name, step in steps do table.insert(ordered, {name,step}) end
	table.sort(ordered, function(a,b) return a[2][1] < b[2][1] end)
	for _, item in ordered do item[2][2](dt) end
end
local character, _, humanoid = h:character("Ana")
h.player.Character = character
local sfx = h:new("SoundGroup", "BastiaoEfeitos", h.soundService); sfx.Volume = .37
local unrelated = h:new("EqualizerSoundEffect", "OtherEQ", sfx); unrelated.HighGain = -3
local calls, ring = 0, nil
local Efeitos = h:load("src/client/Efeitos.luau")
local api = Efeitos.iniciar({jogador=h.player, playerGui=h.playerGui, efeito=function(key)
	if key == "impacto_zumbido" then
		calls += 1; ring = h:new("Sound", "Ring", h.soundService); ring.Volume = .2; ring:Play(); return ring
	end
end})
local blur = h.services.Lighting:FindFirstChild("S7BastiaoImpactoBlur")
assert(blur, "owned Sector7-compatible postprocessing missing")
local function damage(value) humanoid.Health = value; humanoid.HealthChanged:Fire(value) end
damage(100); damage(110); frame(.05)
assert(calls == 0 and blur.Enabled == false, "spawn/healing incorrectly triggered impact")
damage(70); damage(69); frame(.045)
assert(calls == 1 and blur.Size > 10 and blur.Enabled, "living damage did not trigger blur/ring")
assert(camera.CFrame.Position == roblox.Vector3.new(5,6,7) and camera.FieldOfView == 77, "impact changed camera position/FOV")
local before = blur.Size
damage(68); frame(.001)
assert(blur.Size >= before - .01 and calls == 1, "minor hit weakened strong effect or stacked ringing")
assert(sfx:FindFirstChild("S7BastiaoImpactoEQ").HighGain < -10 and unrelated.HighGain == -3 and sfx.Volume == .37, "muffle changed unrelated mixer")
-- Sector7's real ownership contract: Input-1 removes its prior output only if
-- CFrame still equals that output, then Camera+1 writes its chest presentation.
-- Our earlier unwind must expose that exact output to avoid a feedback loop.
local bodycamBase, bodycamFinal = nil, nil
local composedFrames = 0
steps.TestS7Unwind = {roblox.Enum.RenderPriority.Input.Value-1, function()
	if bodycamFinal then
		assert(camera.CFrame:FuzzyEq(bodycamFinal,1e-4), "injury prevented Sector7's guarded unwind")
		camera.CFrame = bodycamBase; composedFrames += 1
	end
end}
steps.TestS7Apply = {roblox.Enum.RenderPriority.Camera.Value+1, function()
	bodycamBase = camera.CFrame
	bodycamFinal = bodycamBase * roblox.CFrame.Angles(0,.02,0)
	camera.CFrame = bodycamFinal
end}
local creatureFolder = h:new("Folder", "Criatura", h.story)
local monster = h:new("Model", "Bastiao731A", creatureFolder)
h:new("Part", "HumanoidRootPart", monster).Size = roblox.Vector3.new(2, 6, 2)
monster:SetAttribute("BastiaoState", "search")
local function doorHit(serial)
	monster:SetAttribute("BastiaoMarkerName", "DoorHit")
	monster:SetAttribute("BastiaoMarkerSerial", serial)
	h.services.RunService.RenderStepped:Fire(.1)
end
doorHit(1) -- door shake + injury + Sector7 must all unwind in reverse apply order
for _=1,700 do frame(.01) end
steps.TestS7Unwind[2](); steps.TestS7Apply=nil; steps.TestS7Unwind=nil
assert(composedFrames == 700, "Sector7 composition was not exercised")
assert(blur.Size == 0 and blur.Enabled == false and sfx:FindFirstChild("S7BastiaoImpactoEQ") == nil, "recovery left owned effects")
assert(camera.CFrame:FuzzyEq(roblox.CFrame.new(5,6,7),1e-5), "rotation accumulated without a camera writer")
damage(50); frame(.1)
h.services.GuiService.ReducedMotionEnabled = true
doorHit(2)
frame(.01)
assert(camera.CFrame:FuzzyEq(roblox.CFrame.new(5,6,7),1e-5) and not blur.Enabled, "reduced motion not honored")
h.services.GuiService.ReducedMotionEnabled = false
h.player:SetAttribute("S7CameraMotion",0); h.player:SetAttribute("S7MotionBlur",false)
doorHit(3)
frame(.01); assert(not blur.Enabled and camera.CFrame:FuzzyEq(roblox.CFrame.new(5,6,7),1e-5))
h.player:SetAttribute("S7CameraMotion",1); h.player:SetAttribute("S7MotionBlur",true)
camera.CameraType = roblox.Enum.CameraType.Scriptable
local cutscene = roblox.CFrame.new(20,20,20); camera.CFrame = cutscene
frame(.01); assert(camera.CFrame == cutscene and not blur.Enabled, "impact stole scripted camera")
camera.CameraType = roblox.Enum.CameraType.Custom
damage(0); frame(.01)
assert(not blur.Enabled and sfx:FindFirstChild("S7BastiaoImpactoEQ") == nil, "death did not clear impact")
local newCharacter, _, newHumanoid = h:character("Ana2")
h.player.CharacterRemoving:Fire(character); h.player.Character = newCharacter; h.player.CharacterAdded:Fire(newCharacter)
humanoid.HealthChanged:Fire(10); frame(.01); assert(not blur.Enabled, "old character retained damage listener")
newHumanoid.Health=80; newHumanoid.HealthChanged:Fire(80); frame(.1); assert(blur.Enabled, "respawn lost listener")
-- Another camera owner moves the camera between apply and unwind: never restore stale CFrame.
local external = roblox.CFrame.new(44,45,46)
camera.CFrame = external
frame(.01)
assert(camera.CFrame.Position == external.Position, "unwind overwrote another owner's camera")
-- Capture uses the original jumpscare; the injury layer must yield immediately.
doorHit(4); frame(.01)
h.player:SetAttribute("BastiaoCapturado", 123)
h:flush(); frame(.01)
assert(camera.CameraType == roblox.Enum.CameraType.Scriptable and not blur.Enabled, "capture did not own camera")
assert(h.playerGui:FindFirstChild("BastiaoJumpscare").Enabled, "original jumpscare was lost")
assert(sfx:FindFirstChild("S7BastiaoImpactoEQ") == nil, "capture retained injury audio filter")
api.destroy(); api.destroy(); newHumanoid.HealthChanged:Fire(60)
assert(not h.services.Lighting:FindFirstChild("S7BastiaoImpactoBlur") and not steps.BastiaoImpacto and not steps.BastiaoImpactoUnwind and not steps.BastiaoTremorUnwind, "destroy leaked callbacks/effects")
assert(unrelated.Parent == sfx and sfx.Volume == .37)
-- Destroy between render frames must remove both layers, in reverse order.
local cleanBase = roblox.CFrame.new(8,9,10)
camera.CFrame = cleanBase; camera.CameraType = roblox.Enum.CameraType.Custom
local second = Efeitos.iniciar({jogador=h.player, playerGui=h.playerGui})
second.impacto(.6); doorHit(5); frame(.02)
assert(not camera.CFrame:FuzzyEq(cleanBase,1e-5), "active layered cleanup test did not apply offsets")
second.destroy()
assert(camera.CFrame:FuzzyEq(cleanBase,1e-5), "destroy retained a door/injury offset")
assert(not steps.BastiaoTremor and not steps.BastiaoTremorUnwind)
print("PASS damage, door+injury+Sector7 composition, accessibility, cutscene, death, respawn, capture and layered cleanup")
