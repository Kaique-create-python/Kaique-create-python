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

function Context.new(materialService, ids)
    local api = {rgb = Color3.fromRGB}
    local variants = {}
    for key, images in ids do
        local info = assert(definitions[key] and definitions[key][2] > 0 and key ~= "metal" and definitions[key],
            "Material desconhecido ou sem conjunto PBR: " .. tostring(key))
        local variant = Instance.new("MaterialVariant")
        variant.Name = "MareBaixa_" .. key
        variant.BaseMaterial = Enum.Material[info[1]]
        variant.StudsPerTile = info[2]
        variant.ColorMap = assert(imageId(images.color), "Informe o ID de cor: " .. key)
        variant.NormalMap = assert(imageId(images.normal), "Informe o ID de normal: " .. key)
        variant.RoughnessMap = assert(imageId(images.roughness), "Informe o ID de rugosidade: " .. key)
        if images.metalness then
            variant.MetalnessMap = assert(imageId(images.metalness), "ID de metal inválido: " .. key)
        end
        variant.Parent = materialService
        variants[key] = variant.Name
    end

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
        local variantName = variants[material]
        if variantName then
            part.MaterialVariant = variantName
            part.Color = color:Lerp(Color3.new(1, 1, 1), 0.76)
        end
        if part:IsA("Part") then
            part.TopSurface = Enum.SurfaceType.Smooth
            part.BottomSurface = Enum.SurfaceType.Smooth
        end
        part.Parent = parent
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
        light.Parent = part
        return light
    end

    function api.sign(part, face, inscription, accent)
        local gui = Instance.new("SurfaceGui")
        gui.Name = "Identificação"
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
        return gui
    end

    return api
end

return Context
