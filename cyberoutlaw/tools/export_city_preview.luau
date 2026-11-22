-- Executa a geometria e a câmera do menu para medir e pré-visualizar fora do Studio.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local source = fs.readFile("src/city.luau")
local env = {
    Instance = roblox.Instance,
    CFrame = roblox.CFrame,
    Vector3 = roblox.Vector3,
    Color3 = roblox.Color3,
    Enum = roblox.Enum,
    BrickColor = roblox.BrickColor,
    task = require("@lune/task"),
}
local make = luau.load(source .. "\nreturn createCyberCity", {environment=env, injectGlobals=true})()
local world = roblox.Instance.new("WorldModel")
local city, cameraAt = make(world)
assert(city:IsA("Model") and city.Parent == world and type(cameraAt) == "function")
local parts = {}
for _, node in city:GetDescendants() do
    if not node:IsA("BasePart") then continue end
    local r, g, b = node.Color.R, node.Color.G, node.Color.B
    local size = node.Size
    local shape = if node:IsA("Part") then node.Shape.Name else node.ClassName
    assert(node.Anchored and not node.CanCollide and not node.CanQuery and not node.CanTouch)
    table.insert(parts, {
        cf = {node.CFrame:GetComponents()}, size = {size.X, size.Y, size.Z},
        color = {r, g, b}, material = node.Material.Name, transparency = node.Transparency,
        shape = shape,
    })
end
assert(#parts > 100 and #parts <= 2400, "panorama exige geometria detalhada dentro do orçamento")
local camera = {}
for i=0,179 do
    table.insert(camera, {cameraAt(i/15):GetComponents()})
end
local output = assert(process.args[1], "informe caminho da cena JSON")
fs.writeFile(output, serde.encode("json", {parts=parts,frames=camera,fov=44}, false))
print(string.format("Cena real: %d peças e %d poses da câmera.", #parts, #camera))
