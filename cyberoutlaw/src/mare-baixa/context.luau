-- Native parts and material variants shared by the districts and streets.
local Context = {}

local definitions = {
    asphalt = {"Asphalt", 16},
    cement = {"Concrete", 12},
    sidewalk = {"Pavement", 8},
    glass = {"Glass", 16},
    steel = {"Metal", 12},
    brick = {"Brick", 10},
    roof = {"Slate", 12},
    tile = {"CeramicTiles", 8},
    metal = {"Metal", 12},
    neon = {"Neon", 0},
    stone = {"Basalt", 0},
    rubber = {"Rubber", 0},
    fabric = {"Fabric", 0},
    wood = {"WoodPlanks", 0},
    paint = {"SmoothPlastic", 0},
    water = {"Glass", 0},
    foliage = {"LeafyGrass", 0},
}

local function imageId(id)
    if type(id) == "number" and id > 0 and id % 1 == 0 and id < 2^53 then
        return string.format("rbxassetid://%.0f", id)
    end
end

local function faceEnum(face)
    return if type(face) == "string" then Enum.NormalId[face] else face
end

local channels = {
    color = "ColorMap",
    normal = "NormalMap",
    roughness = "RoughnessMap",
    metalness = "MetalnessMap",
}

local fallbackArt = {
    asphalt = {color = "asphalt", normal = "asphalt_normal", roughness = "asphalt_rough"},
    cement = {color = "concrete", normal = "concrete_normal"},
    sidewalk = {color = "concreto_rachado", normal = "concreto_rachado_normal"},
    steel = {color = "metal_ondulado", normal = "metal_ondulado_normal"},
    brick = {color = "tijolo", normal = "tijolo_normal"},
    tile = {color = "piso_hexagonal", normal = "piso_hexagonal_normal"},
}

-- A mesma amostragem da prévia avulsa mantém os jardins e a rua nas mesmas posições.
local function random(seed)
    local state = math.floor(seed) % 2147483647
    if state == 0 then
        state = 1
    end
    return {
        NextNumber = function(_, first, last)
            local minimum, maximum = first or 0, last or 1
            state = (state * 48271) % 2147483647
            return minimum + (maximum - minimum) * (state / 2147483647)
        end,
    }
end

function Context.new(materialService, art, options)
    local stats = {parts = 0, colliders = 0, lights = 0, signs = 0}
    local api = {rgb = Color3.fromRGB, random = random, stats = stats}
    local variants = {}
    for key, info in definitions do
        if info[2] == 0 or key == "metal" or not materialService then
            continue
        end
        local images = {}
        for channel, property in channels do
            images[property] = imageId(art["mare_" .. key .. "_" .. channel])
        end
        if not next(images) then
            for channel, fallback in fallbackArt[key] or {} do
                images[channels[channel]] = imageId(art[fallback])
            end
        end
        if not next(images) then
            continue
        end
        local variant = Instance.new("MaterialVariant")
        variant.Name = "MareBaixa_" .. key
        variant.BaseMaterial = Enum.Material[info[1]]
        variant.StudsPerTile = info[2]
        for property, id in images do
            variant[property] = id
        end
        variant.Parent = materialService
        variants[key] = {name = variant.Name, tint = images.ColorMap ~= nil}
    end
    local pause = options.yield
    local lightGroups = {}

    function api.group(parent, name)
        local model = Instance.new("Model")
        model.Name = name
        model.Parent = parent
        return model
    end

    function api.box(parent, name, x, y, z, width, height, depth, color, material, options)
        options = options or {}
        local info = assert(definitions[material], "Material não listado: " .. tostring(material) .. " em " .. name)
        assert(width > 0 and height > 0 and depth > 0, "Dimensões inválidas em " .. name)
        local part = Instance.new(if options.shape == "Wedge" then "WedgePart" else "Part")
        if options.shape and part:IsA("Part") then
            part.Shape = Enum.PartType[options.shape]
        end
        part.Name = name
        part.Size = Vector3.new(width, height, depth)
        part.CFrame = options.cframe or CFrame.new(x, y, z) * CFrame.Angles(
            math.rad(options.pitch or 0), math.rad(options.yaw or 0), math.rad(options.roll or 0))
        part.Anchored = true
        part.CanCollide = options.collision ~= false
        part.CanTouch = false
        part.CanQuery = part.CanCollide
        part.CastShadow = options.shadow ~= false and material ~= "neon" and material ~= "water"
        part.Transparency = options.transparency or 0
        part.Reflectance = options.reflectance or 0
        part.Material = Enum.Material[info[1]]
        part.Color = color
        part:SetAttribute("MareMaterial", material)
        local variant = variants[material]
        if variant then
            part.MaterialVariant = variant.name
            if variant.tint then
                part.Color = color:Lerp(Color3.new(1, 1, 1), 0.76)
            end
        end
        if part:IsA("Part") then
            part.TopSurface = Enum.SurfaceType.Smooth
            part.BottomSurface = Enum.SurfaceType.Smooth
        end
        part.Parent = parent
        stats.parts += 1
        if part.CanCollide then
            stats.colliders += 1
        end
        if pause and stats.parts % 600 == 0 then
            pause()
        end
        return part
    end

    function api.beam(parent, name, first, second, width, depth, color, material, options)
        options = table.clone(options or {})
        local delta = second - first
        local axis = delta.Unit
        local right = (if math.abs(axis.Y) < 0.98 then Vector3.yAxis else Vector3.xAxis):Cross(axis).Unit
        local middle = (first + second) / 2
        options.cframe = CFrame.fromMatrix(middle, right, axis, right:Cross(axis))
        return api.box(parent, name, middle.X, middle.Y, middle.Z, width, delta.Magnitude, depth, color, material, options)
    end

    function api.lamp(part, color, range, brightness, face)
        local light = Instance.new(if face then "SurfaceLight" else "PointLight")
        light.Name = "Luz local"
        light.Color = color
        light.Range = range
        light.Brightness = brightness
        light.Shadows = false
        if face then
            light.Face = faceEnum(face)
            light.Angle = 115
        end
        local p = part.CFrame.Position
        local key = string.format("%d/%d/%d", math.floor(p.X / 72), math.floor(p.Y / 52), math.floor(p.Z / 72))
        local list = lightGroups[key]
        if not list then
            list = {}
            lightGroups[key] = list
        end
        table.insert(list, {light = light, part = part, order = #list + 1, weight = range * brightness})
        return light
    end

    function api.finish()
        for _, list in lightGroups do
            table.sort(list, function(a, b)
                return if a.weight == b.weight then a.order < b.order else a.weight > b.weight
            end)
            for index, entry in list do
                if index <= 3 then
                    entry.light.Parent = entry.part
                    stats.lights += 1
                else
                    entry.light:Destroy()
                end
            end
        end
        table.clear(lightGroups)
    end

    function api.sign(part, face, inscription, accent, name)
        local gui = Instance.new("SurfaceGui")
        gui.Name = name or "Identificação"
        gui.Face = faceEnum(face)
        gui.LightInfluence = 0.08
        gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
        gui.CanvasSize = Vector2.new(720, 160)
        gui.MaxDistance = 200
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(0.95, 0.82)
        label.Position = UDim2.fromScale(0.025, 0.09)
        label.FontFace = Font.fromEnum(Enum.Font.GothamBold)
        label.Text = inscription
        label.TextScaled = true
        label.TextColor3 = accent
        label.Parent = gui
        gui.Parent = part
        stats.signs += 1
        return gui
    end

    return api
end

Context.imageId = imageId

return Context
