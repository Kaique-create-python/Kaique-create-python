local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")
local output = assert(process.args[1], "informe o arquivo .rbxl de saída")

local game = roblox.Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local baseplate = roblox.Instance.new("Part")
baseplate.Name = "Baseplate"
baseplate.Size = roblox.Vector3.new(512, 20, 512)
baseplate.Position = roblox.Vector3.new(0, -10, 0)
baseplate.Color = roblox.Color3.fromRGB(99, 95, 98)
baseplate.Material = roblox.Enum.Material.Plastic
baseplate.TopSurface = roblox.Enum.SurfaceType.Studs
baseplate.Anchored = true
baseplate.Parent = workspace

local spawn = roblox.Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Size = roblox.Vector3.new(6, 1, 6)
spawn.Position = roblox.Vector3.new(0, 0.5, 0)
spawn.Anchored = true
spawn.Neutral = true
spawn.AllowTeamChangeOnTouch = false
spawn.Duration = 0
spawn.Parent = workspace

local bytes = roblox.serializePlace(game)
local scene = roblox.deserializePlace(bytes)
local parts = scene:GetService("Workspace"):GetChildren()
assert(#parts == 2 and parts[1].Name == "Baseplate" and parts[2].Name == "SpawnLocation")
for _, object in scene:GetDescendants() do
    assert(not object:IsA("LuaSourceContainer") and not object:IsA("LayerCollector"), object.Name)
end
fs.writeFile(output, bytes)
print("Baseplate e SpawnLocation verificados. Nenhum script ou HUD personalizado.")
