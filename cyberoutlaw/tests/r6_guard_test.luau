-- Checks CyberOutlawR6's R15-to-R6 conversion with simulated Players and characters.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local E = roblox.Enum
local CFrame = roblox.CFrame

local function signal()
	local listeners = {}
	return {
		Connect = function(_, callback)
			table.insert(listeners, callback)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, callback in table.clone(listeners) do
				callback(...)
			end
		end,
	}
end

-- Minimal instance: hierarchy, class, pivot, and cloning. Parent works as in Roblox.
local Fake = {}
Fake.__index = function(self, key)
	if key == "Parent" then
		return rawget(self, "_parent")
	end
	return Fake[key]
end
Fake.__newindex = function(self, key, value)
	if key ~= "Parent" then
		rawset(self, key, value)
		return
	end
	local old = rawget(self, "_parent")
	if old then
		table.remove(old.children, table.find(old.children, self))
	end
	rawset(self, "_parent", value)
	if value then
		table.insert(value.children, self)
	end
end
local function new(class, name, props)
	local self = setmetatable({ ClassName = class, Name = name or class, children = {} }, Fake)
	for key, value in props or {} do
		self[key] = value
	end
	return self
end
function Fake:IsA(class)
	return self.ClassName == class or class == "Instance"
end
function Fake:GetChildren()
	return table.clone(self.children)
end
function Fake:FindFirstChild(name)
	for _, child in self.children do
		if child.Name == name then
			return child
		end
	end
	return nil
end
function Fake:FindFirstChildOfClass(class)
	for _, child in self.children do
		if child.ClassName == class then
			return child
		end
	end
	return nil
end
function Fake:WaitForChild(name)
	return self:FindFirstChild(name)
end
function Fake:GetPivot()
	local root = self:FindFirstChild("HumanoidRootPart")
	return if root then root.CFrame else CFrame.new()
end
function Fake:PivotTo(pose)
	local root = self:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = pose
	end
end
function Fake:Clone()
	local copy = new(self.ClassName, self.Name)
	for _, child in self.children do
		child:Clone().Parent = copy
	end
	return copy
end
function Fake:Destroy()
	self.Parent = nil
	self.destroyed = true
end
function Fake:GetAppliedDescription()
	return new("HumanoidDescription")
end

local function character(rig, pose)
	local model = new("Model", "Outlaw")
	new("Humanoid", "Humanoid", { RigType = rig }).Parent = model
	new("Part", "HumanoidRootPart", { CFrame = pose }).Parent = model
	return model
end
local rawNew = new

local workspace = rawNew("Workspace")
local starterPlayer = rawNew("StarterPlayer")
local starterScripts = rawNew("StarterCharacterScripts")
starterScripts.Parent = starterPlayer
rawNew("Script", "Health").Parent = starterScripts

local built = {}
local players = {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function()
		return {}
	end,
	CreateHumanoidModelFromDescriptionAsync = function(_, description, rig)
		assert(description and description.ClassName == "HumanoidDescription")
		assert(rig == E.HumanoidRigType.R6, "the new model must be R6")
		local model = character(E.HumanoidRigType.R6, CFrame.new())
		rawNew("LocalScript", "Animate").Parent = model
		table.insert(built, model)
		return model
	end,
}
local attributes, current = {}, nil
local player = {
	Name = "Outlaw",
	UserId = 321,
	CharacterAdded = signal(),
	SetAttribute = function(_, key, value)
		attributes[key] = value
	end,
}
setmetatable(player, {
	__index = function(_, key)
		if key == "Character" then
			return current
		elseif key == "Parent" then
			return players
		end
		return nil
	end,
	__newindex = function(_, key, value)
		assert(key == "Character")
		current = value
		player.CharacterAdded:Fire(value)
	end,
})

local chunk = luau.load(fs.readFile("src/r6_guard.server.luau"), {
	debugName = "r6_guard.server.luau",
	environment = {
		game = { GetService = function(_, name)
			return if name == "Players" then players elseif name == "StarterPlayer" then starterPlayer else error(name)
		end },
		workspace = workspace,
		Enum = E,
		typeof = function(value)
			return if getmetatable(value) == Fake then "Instance" else typeof(value)
		end,
		task = { spawn = function(callback, ...) callback(...) end },
		warn = function(...)
			local parts = {}
			for _, item in { ... } do
				table.insert(parts, tostring(item))
			end
			error(table.concat(parts, " "))
		end,
		print = function() end,
	},
})
chunk()
players.PlayerAdded:Fire(player)

local spot = CFrame.new(107, 4, 139)
local original = character(E.HumanoidRigType.R15, spot)
original.Parent = workspace
current = original
player.CharacterAdded:Fire(original)

assert(#built == 1, "an R15 produces exactly one R6")
local converted = built[1]
assert(current == converted and converted.Parent == workspace, "the R6 becomes the player's character")
assert(original.Parent == nil and original.destroyed, "the old R15 is removed")
assert((converted:GetPivot().Position - spot.Position).Magnitude < 0.001, "the R6 spawns in the same place")
assert(converted:FindFirstChild("Health"), "the StarterCharacterScripts follow the character")
assert(attributes.CyberOutlawRig == "R6 (convertido)", tostring(attributes.CyberOutlawRig))

local native = character(E.HumanoidRigType.R6, spot)
native.Parent = workspace
current = native
player.CharacterAdded:Fire(native)
assert(#built == 1 and attributes.CyberOutlawRig == "R6", "a native R6 is not rebuilt")
print("CyberOutlawR6: R15 rebuilt as R6 in the same place, native R6 preserved")
