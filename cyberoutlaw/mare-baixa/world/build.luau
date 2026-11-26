-- Run from the project folder: lune run world/build.luau [output_folder] [material_ids.json]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local rbx = require("@lune/roblox")
local serde = require("@lune/serde")

local Instance, Enum, Color3 = rbx.Instance, rbx.Enum, rbx.Color3
local CFrame, Vector3 = rbx.CFrame, rbx.Vector3

local function random(seed)
    local state = math.floor(seed) % 2147483647
    if state == 0 then state = 1 end
    local function nextSample()
        state = (state * 48271) % 2147483647
        return state / 2147483647
    end
    return {
        NextNumber = function(_, first, last)
            local minimum, maximum = first or 0, last or 1
            return minimum + (maximum - minimum) * nextSample()
        end,
        NextInteger = function(_, first, last)
            return first + math.floor(nextSample() * (last - first + 1))
        end,
    }
end

local env = {
    Instance = Instance, Enum = Enum, Color3 = Color3, CFrame = CFrame,
    Vector3 = Vector3, Vector2 = rbx.Vector2, UDim2 = rbx.UDim2,
    UDim = rbx.UDim, BrickColor = rbx.BrickColor,
    Font = rbx.Font,
    Random = {new = random},
}
local function readModule(name)
    local path = "world/" .. name .. ".luau"
    return luau.load(fs.readFile(path), {debugName = path, environment = env, injectGlobals = true})()
end

local out = process.args[1] or "entrega"
if not fs.isDir(out) then fs.writeDir(out) end
local ids = if process.args[2] then serde.decode("json", fs.readFile(process.args[2])) else {}
local Context = readModule("context")
local Layout = readModule("layout")
local Streets = readModule("streets")
local Transit = readModule("transit")
local PublicSpace = readModule("public_space")
local Buildings = readModule("buildings")
local Commerce = readModule("commerce")
local place = Instance.new("DataModel")
local workspace = place:GetService("Workspace")
workspace.StreamingEnabled = true
workspace.StreamingMinRadius = 180
workspace.StreamingTargetRadius = 640
workspace.FallenPartsDestroyHeight = -240
local starter = place:GetService("StarterPlayer")
starter.GameSettingsAvatar = Enum.GameAvatarType.R6
local lighting = place:GetService("Lighting")
lighting.ClockTime = 1.15
lighting.Brightness = 2.15
lighting.GlobalShadows = true
lighting.ShadowSoftness = 0.38
lighting.ExposureCompensation = 0.18
lighting.GeographicLatitude = 25
lighting.Ambient = Color3.fromRGB(69, 70, 91)
lighting.OutdoorAmbient = Color3.fromRGB(82, 92, 121)
lighting.EnvironmentDiffuseScale = 0.70
lighting.EnvironmentSpecularScale = 0.92
local supportsModern, modernError = pcall(function()
    lighting.LightingStyle = Enum.LightingStyle.Realistic
    lighting.PrioritizeLightingQuality = true
end)
if not supportsModern then
    lighting.Technology = Enum.Technology.Future
    print("Preset serializado como Future. " .. tostring(modernError))
end
local atmo = Instance.new("Atmosphere")
atmo.Name = "MareBaixa_Atmosfera"
atmo.Density = 0.21
atmo.Offset = 0.0
atmo.Color = Color3.fromRGB(123, 144, 188)
atmo.Decay = Color3.fromRGB(55, 65, 103)
atmo.Haze = 1.55
atmo.Glare = 0
atmo.Parent = lighting
local bloom = Instance.new("BloomEffect")
bloom.Name = "MareBaixa_Neon"
bloom.Intensity = 0.26
bloom.Size = 25
bloom.Threshold = 0.86
bloom.Parent = lighting
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "MareBaixa_Cor"
grade.Brightness = 0.024
grade.Contrast = 0.075
grade.Saturation = -0.12
grade.TintColor = Color3.fromRGB(231, 235, 255)
grade.Parent = lighting

local materials = place:GetService("MaterialService")
local ctx = Context.new(materials, ids)
local city = ctx.group(workspace, "Maré Baixa")
city:SetAttribute("MareBaixaVersion", 1)
city:SetAttribute("LarguraEmStuds", Layout.halfX * 2)
city:SetAttribute("ComprimentoEmStuds", Layout.halfZ * 2)
city:SetAttribute("PassoDaQuadra", Layout.pitch)
city.WorldPivot = CFrame.new(0, 0, 0)
local districts = ctx.group(city, "Quadras")
local plaza = PublicSpace.new(ctx)

local names = {
    apartments = "Apartamentos",
    towers = "Residencial vertical",
    mixed = "Uso misto",
    finance = "Vértice financeiro",
    hotel = "Hotel e comércio",
    tech = "Pesquisa e escritórios",
    vertice = "Torre Vértice",
    grid = "Subestação do anel",
    warehouse = "Armazéns",
    docks = "Doca do Sal",
    arcade = "Galeria de comércio",
    sodio = "Mercado Sódio",
    park = "Praça de bairro",
    levee = "Mirante da orla",
    spawn = "Praça do Dique",
    station = "Estação do Dique",
}
local counts, cells = {}, {}
for row, cellRow in Layout.blocks do
    assert(#cellRow == Layout.columns)
    for column, kind in cellRow do
        local x, z = Layout.cell(column, row)
        local id = string.char(64 + column) .. row
        local block = ctx.group(districts, id .. " · " .. assert(names[kind], tostring(kind)))
        block.WorldPivot = CFrame.new(x, 0, z)
        block:SetAttribute("Quadra", id)
        block:SetAttribute("Tipo", kind)
        counts[kind] = (counts[kind] or 0) + 1
        table.insert(cells, {id = id, column = column, row = row, kind = kind, x = x, z = z})
        local seed = 202607 + row * 941 + column * 1651
        local tone = if kind == "docks" or kind == "grid" or kind == "warehouse"
            then ctx.rgb(69, 71, 83) else ctx.rgb(76, 81, 95)
        ctx.box(block, "Base transitável da quadra", x, -1.02, z, 198, 2.02, 198, tone, "cement", {shadow = false})
        if kind == "vertice" or kind == "finance" or kind == "hotel" or kind == "tech" then
            Buildings.tower(ctx, block, x, z, seed, kind)
        elseif kind == "towers" or kind == "mixed" or kind == "apartments" then
            Buildings.residential(ctx, block, x, z, seed, kind)
        elseif kind == "arcade" or kind == "sodio" then
            Commerce.market(ctx, block, x, z, seed, kind)
        elseif kind == "warehouse" or kind == "docks" then
            Commerce.industrial(ctx, block, x, z, seed, kind)
        elseif kind == "grid" then
            Commerce.utility(ctx, block, x, z, seed, kind)
        else
            plaza.plaza(block, x, z, seed, kind)
        end
        plaza.furniture(block, x, z, seed + 3, row * 10 + column)
    end
end
Streets.build(ctx, city, Layout)
Transit.build(ctx, city, Layout)

-- Keep self-lit fixtures throughout the city. Nearby real lights share a budget.
local lightGroups = {}
for index, node in city:GetDescendants() do
    if not node:IsA("Light") then continue end
    local p = node.Parent.CFrame.Position
    local key = string.format("%d/%d/%d", math.floor(p.X / 72), math.floor(p.Y / 52), math.floor(p.Z / 72))
    local list = lightGroups[key] or {}
    lightGroups[key] = list
    table.insert(list, {light = node, index = index, weight = node.Range * node.Brightness})
end
for _, list in lightGroups do
    table.sort(list, function(a, b)
        return if a.weight == b.weight then a.index < b.index else a.weight > b.weight
    end)
    for index = 4, #list do
        list[index].light:Destroy()
    end
end

local entry = ctx.group(city, "Ponto de entrada")
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Praça do Dique"
spawn.Size = Vector3.new(8, 0.2, 8)
spawn.CFrame = CFrame.lookAt(Vector3.new(Layout.spawnX, 0.132, Layout.spawnZ), Vector3.new(30, 0.132, -33))
spawn.Anchored = true
spawn.CanCollide = true
spawn.CanTouch = false
spawn.CastShadow = false
spawn.Neutral = true
spawn.Duration = 0
spawn.Transparency = 1
spawn.Material = Enum.Material.Concrete
spawn.Parent = entry

local shots = {
    {name = "Canal", position = {-11, 14, 366}, look = {5, 27, -245}, fov = 57},
    {name = "Avenida", position = {229, 7.7, -17.76}, look = {229, 20, -450}, fov = 62},
    {name = "Mercado", position = {-365.5, 6.2, -213}, look = {-359.5, 10.2, -125}, fov = 59},
    {name = "Estacao", position = {37, 10.5, -49}, look = {138, 23.5, -2}, fov = 65},
    {name = "Doca", position = {-896, 20, 474}, look = {-840, 18, 591}, fov = 65},
    {name = "Panorama", position = {-975, 475, 1222}, look = {16, 66, -90}, fov = 54},
    {name = "Praca", position = {-111, 7.1, -208}, look = {-147, 7.5, -155}, fov = 59},
    {name = "Vertice", position = {196, 23, -531}, look = {360, 225, -351}, fov = 65},
}
local camera = Instance.new("Camera")
camera.Name = "Vista inicial do editor"
camera.CFrame = CFrame.lookAt(Vector3.new(-120, 125, 220), Vector3.new(198, 55, -252))
camera.FieldOfView = 62
camera.Parent = workspace
workspace.CurrentCamera = camera

local function vec3(v)
    return {v.X, v.Y, v.Z}
end
local function color(c)
    return {c.R, c.G, c.B}
end
local function read(object, property)
    local ok, value = pcall(function() return object[property] end)
    return if ok then value else nil
end

local parts, lights, signs = {}, {}, {}
local minimum, maximum = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
local colliders, variants = 0, 0
for _, node in city:GetDescendants() do
    assert(not node:IsA("LuaSourceContainer"), "Script inesperado no cenário estático")
    if not node:IsA("BasePart") then continue end
    assert(node.Anchored and node.Size.X > 0 and node.Size.Y > 0 and node.Size.Z > 0, node:GetFullName())
    if node.CanCollide then colliders += 1 end
    if node.MaterialVariant ~= "" then variants += 1 end
    for _, sx in {-1, 1} do
        for _, sy in {-1, 1} do
            for _, sz in {-1, 1} do
                local p = node.CFrame:PointToWorldSpace(node.Size * Vector3.new(sx, sy, sz) / 2)
                minimum = Vector3.new(math.min(minimum.X, p.X), math.min(minimum.Y, p.Y), math.min(minimum.Z, p.Z))
                maximum = Vector3.new(math.max(maximum.X, p.X), math.max(maximum.Y, p.Y), math.max(maximum.Z, p.Z))
            end
        end
    end
    local partIndex = #parts + 1
    parts[partIndex] = {
        name = node.Name,
        cf = {node.CFrame:GetComponents()},
        size = vec3(node.Size),
        color = color(node.Color),
        material = node:GetAttribute("MareMaterial") or "cement",
        transparency = node.Transparency,
        reflectance = node.Reflectance,
        collision = node.CanCollide,
        shape = if node:IsA("WedgePart") then "Wedge" elseif node:IsA("Part") then node.Shape.Name else "Block",
    }
    for _, child in node:GetChildren() do
        if child:IsA("Light") then
            local face = read(child, "Face")
            table.insert(lights, {part = partIndex, face = face and face.Name, color = color(child.Color),
                range = child.Range, brightness = child.Brightness})
        elseif child:IsA("SurfaceGui") then
            local label = child:FindFirstChildOfClass("TextLabel")
            if label then
                table.insert(signs, {part = partIndex, face = child.Face.Name, text = label.Text, color = color(label.TextColor3)})
            end
        end
    end
end

local modelFile = {city}
local profile = Instance.new("Folder")
profile.Name = "Maré Baixa · iluminação e materiais"
for _, child in lighting:GetChildren() do
    local clone = child:Clone()
    clone.Parent = profile
end
for _, child in materials:GetChildren() do
    local clone = child:Clone()
    clone.Parent = profile
end
table.insert(modelFile, profile)
local bridgeCounts = {road = 0, foot = 0}
for _, kind in Layout.bridgeRows do
    bridgeCounts[kind] += 1
end
fs.writeFile(out .. "/Mare-Baixa.rbxl", rbx.serializePlace(place))
fs.writeFile(out .. "/Mare-Baixa.rbxm", rbx.serializeModel(modelFile))
fs.writeFile(out .. "/estatisticas.json", serde.encode("json", {
    districts = counts, blocks = #districts:GetChildren(), parts = #parts, colliders = colliders, lights = #lights,
    signs = #signs, bounds = {minimum = vec3(minimum), maximum = vec3(maximum)},
    dimensions = vec3(maximum - minimum), tileableMaterials = 8, texturedParts = variants,
    roadBridges = bridgeCounts.road, footBridges = bridgeCounts.foot, spawn = vec3(spawn.CFrame.Position),
    cells = cells,
}, true))
fs.writeFile(out .. "/visualizacao.json", serde.encode("json", {parts = parts, lights = lights, signs = signs, shots = shots}, false))
print(string.format("%d quadras · %d peças · %d luzes · %d inscrições · pico %.1f studs.",
    #districts:GetChildren(), #parts, #lights, #signs, maximum.Y))
