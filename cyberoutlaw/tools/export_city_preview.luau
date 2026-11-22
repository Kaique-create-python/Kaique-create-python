-- Export the same parts, world lights and camera poses used by the Roblox menu.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local env = {
    Instance = roblox.Instance, CFrame = roblox.CFrame, Vector2 = roblox.Vector2, Vector3 = roblox.Vector3,
    Color3 = roblox.Color3, Enum = roblox.Enum, UDim2 = roblox.UDim2, BrickColor = roblox.BrickColor, Content = roblox.Content,
    task = require("@lune/task"),
}
local function color(c) return {c.R, c.G, c.B} end
local function vector(v) return {v.X, v.Y, v.Z} end
local function read(instance, property, default)
    local ok, value = pcall(function() return instance[property] end)
    return if ok then value else default
end
local source = fs.readFile("src/city.luau") .. "\n" .. fs.readFile("src/scene.luau")
local make, dress, clad = luau.load(source .. "\nreturn createCyberCity, addCyberOutlawMaterials, addCyberOutlawFacades", {environment=env, injectGlobals=true})()
local world = roblox.Instance.new("WorldModel")
local media = {billboard = 1001, concrete = 1002, concrete_normal = 1003, asphalt = 1004, asphalt_normal = 1005,
    asphalt_rough = 1006, facades = 1007}
local city, cameraAt, animate = make(world, media)
assert(city:IsA("Model") and city.Parent == world and type(cameraAt) == "function")
dress(city, media, roblox.Vector3.zero)
clad(city, media)
local parts, lights, signs, textures, nodes = {}, {}, {}, {}, {}
for _, node in city:GetDescendants() do
    if not node:IsA("BasePart") then continue end
    local index = #parts + 1
    assert(node.Anchored and not node.CanCollide and not node.CanQuery and not node.CanTouch)
    parts[index] = {
        name = node.Name, cf = {node.CFrame:GetComponents()}, size = vector(node.Size), color = color(node.Color),
        material = node.Material.Name, transparency = node.Transparency, reflective = read(node, "Reflectance", 0),
        shadow = node.CastShadow, shape = if node:IsA("Part") then node.Shape.Name else node.ClassName,
    }
    nodes[index] = node
    for _, inner in node:GetChildren() do
        if inner:IsA("Texture") and inner:GetAttribute("CyberOutlawMaterial") then
            table.insert(textures, {
                part = index, key = inner:GetAttribute("CyberOutlawMaterial"), face = inner.Face.Name,
                tile = {inner.StudsPerTileU, inner.StudsPerTileV}, offset = {inner.OffsetStudsU, inner.OffsetStudsV},
                color = color(inner.Color3), opacity = 1 - inner.Transparency,
            })
        elseif inner:IsA("Light") and read(inner, "Enabled", true) then
            local face = read(inner, "Face", nil)
            table.insert(lights, {part = index, color = color(inner.Color), brightness = inner.Brightness,
                range = inner.Range, shadow = inner.Shadows, face = face and face.Name, angle = read(inner, "Angle", nil)})
        elseif inner:IsA("SurfaceGui") then
            local row = {part = index, face = inner.Face.Name, brightness = read(inner, "Brightness", 1)}
            if inner:GetAttribute("CyberOutlawFacade") then
                row.facade = {}
                row.canvas = {inner.CanvasSize.X, inner.CanvasSize.Y}
                for _, pane in inner:GetChildren() do
                    if not pane:IsA("ImageLabel") then continue end
                    local p, s = pane.Position, pane.Size
                    row.tint = color(pane.ImageColor3)
                    table.insert(row.facade, {
                        crop = {pane.ImageRectOffset.X, pane.ImageRectOffset.Y, pane.ImageRectSize.X, pane.ImageRectSize.Y},
                        rect = {p.X.Scale, p.Y.Scale, s.X.Scale, s.Y.Scale},
                    })
                end
            end
            for _, gui in inner:GetDescendants() do
                if gui:IsA("ImageLabel") and gui.Image == "rbxassetid://1001" then
                    row.crop = {gui.ImageRectOffset.X, gui.ImageRectOffset.Y, gui.ImageRectSize.X, gui.ImageRectSize.Y}
                    break
                elseif gui:IsA("TextLabel") and gui.Text ~= "" then
                    row.text, row.color = gui.Text, color(gui.TextColor3)
                end
            end
            if row.crop or row.text or row.facade then table.insert(signs, row) end
        end
    end
end
assert(#parts > 100 and #parts <= 4800, "cena fora dos limites da prévia")
local camera, transforms = {}, {}
local start = math.max(0, tonumber(process.args[2]) or 0)
local count = math.clamp(tonumber(process.args[3]) or 110, 1, 180)
local aspect = tonumber(process.args[4]) or 16/9
local detail = process.args[5] == "fachadas"
local detailPose = roblox.CFrame.lookAt(roblox.Vector3.new(30, 49, -29), roblox.Vector3.new(81, 61, -132))
local initial = {}
for i, node in nodes do initial[i] = node.CFrame end
for i=0,count-1 do
    local time = start + i / 15
    local cameraPose = if detail then detailPose else cameraAt(time, aspect)
    table.insert(camera, {cameraPose:GetComponents()})
    local moved = {}
    if animate then
        animate(time)
        for j, node in nodes do
            if node.CFrame ~= initial[j] then
                table.insert(moved, {j, {node.CFrame:GetComponents()}})
            end
        end
    end
    transforms[i + 1] = moved
end
local output = assert(process.args[1], "informe caminho da cena JSON")
fs.writeFile(output, serde.encode("json", {parts=parts,frames=camera,transforms=transforms,lights=lights,signs=signs,textures=textures,
    fov=if detail then 52 else city:GetAttribute("VerticalFieldOfView") or 46, aspect=aspect}, false))
print(string.format("Cena real: %d peças, %d luzes, %d superfícies texturizadas, %d inscrições e %d poses.", #parts, #lights, #textures, #signs, #camera))
