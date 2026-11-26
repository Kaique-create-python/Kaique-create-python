local fs = require("@lune/fs")
local process = require("@lune/process")
local rbx = require("@lune/roblox")
local serde = require("@lune/serde")

local folder = process.args[1] or "entrega"
local stats = serde.decode("json", fs.readFile(folder .. "/estatisticas.json"))
local place = rbx.deserializePlace(fs.readFile(folder .. "/Mare-Baixa.rbxl"))
local roots = rbx.deserializeModel(fs.readFile(folder .. "/Mare-Baixa.rbxm"))
local world = place:GetService("Workspace")
local city = assert(world:FindFirstChild("Maré Baixa"))
assert(world.StreamingEnabled)
assert(place:GetService("StarterPlayer").GameSettingsAvatar == rbx.Enum.GameAvatarType.R6)
assert(#roots == 2 and roots[1].Name == city.Name and roots[2]:IsA("Folder"))
assert(#roots[2]:GetChildren() >= 3)
for _, model in {city, roots[1]} do
    assert(model:IsA("Model"))
    assert(#model.Quadras:GetChildren() == stats.blocks)
    assert(model:GetAttribute("LarguraEmStuds") == 2400 and model:GetAttribute("ComprimentoEmStuds") == 1920)
    local b, s, p, v, n = 0, 0, 0, 0, 0
    for _, child in model:GetDescendants() do
        assert(not child:IsA("LuaSourceContainer"))
        if child:IsA("BasePart") then
            p += 1
            assert(child.Anchored)
            if child.MaterialVariant ~= "" then v += 1 end
            if child:IsA("SpawnLocation") then s += 1 end
        elseif child:IsA("Light") then
            b += 1
            assert(not child.Shadows)
        elseif child:IsA("SurfaceGui") then
            n += 1
        end
    end
    assert(p == stats.parts and s == 1 and b == stats.lights and n == stats.signs and v == stats.texturedParts)
end
local materialService = place:GetService("MaterialService")
if stats.texturedParts > 0 then
    local variantCount = 0
    for _, inst in materialService:GetChildren() do
        if inst:IsA("MaterialVariant") then
            variantCount += 1
            assert(inst.ColorMapContent.Uri:match("^rbxassetid://%d+$"))
            assert(inst.NormalMapContent.Uri:match("^rbxassetid://%d+$"))
            assert(inst.RoughnessMapContent.Uri:match("^rbxassetid://%d+$"))
        end
    end
    assert(variantCount > 0)
end
print(string.format("RBXL e RBXM reabertos · %d quadras · %d peças · %d letreiros · %d peças com MaterialVariant",
    stats.blocks, stats.parts, stats.signs, stats.texturedParts))
