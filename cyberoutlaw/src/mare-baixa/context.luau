-- Native parts and material variants shared by the districts and streets.
local Context = {}

local definitions = {
    asphalt = Enum.Material.Asphalt,
    cement = Enum.Material.Concrete,
    sidewalk = Enum.Material.Pavement,
    glass = Enum.Material.Glass,
    steel = Enum.Material.Metal,
    brick = Enum.Material.Brick,
    roof = Enum.Material.Slate,
    tile = Enum.Material.CeramicTiles,
    metal = Enum.Material.Metal,
    neon = Enum.Material.Neon,
    stone = Enum.Material.Basalt,
    rubber = Enum.Material.Rubber,
    fabric = Enum.Material.Fabric,
    wood = Enum.Material.WoodPlanks,
    paint = Enum.Material.SmoothPlastic,
    puddle = Enum.Material.SmoothPlastic,
    water = Enum.Material.Glass,
    foliage = Enum.Material.LeafyGrass,
}

local function imageId(id)
    if type(id) == "number" and id > 0 and id % 1 == 0 and id < 2^53 then
        return string.format("rbxassetid://%.0f", id)
    end
end

local function faceEnum(face)
    return if type(face) == "string" then Enum.NormalId[face] else face
end

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
    -- A Open Cloud recebe as variantes prontas no Place. O servidor só lê o nome e o material base.
    if materialService then
        for key, hasColor in art.mare_tints or {} do
            local variant = materialService:FindFirstChild("CyberOutlawMareBaixa_" .. key)
            if variant and variant:IsA("MaterialVariant") and variant.BaseMaterial == definitions[key] then
                variants[key] = {name = variant.Name, tint = hasColor == 1}
            end
        end
    end
    local pause = options.yield
    local lightGroups = {}
    local mirrors, reflectionCandidates = {}, {}
    local function cell(p, span)
        return math.floor(p.X / span) .. "/" .. math.floor(p.Z / span)
    end

    function api.group(parent, name)
        local model = Instance.new("Model")
        model.Name = name
        model.Parent = parent
        return model
    end

    function api.box(parent, name, x, y, z, width, height, depth, color, material, options)
        options = options or {}
        local baseMaterial = assert(definitions[material], "Material não listado: " .. tostring(material) .. " em " .. name)
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
        part.Material = baseMaterial
        part.Color = color
        part:SetAttribute("MareMaterial", material)
        local variant = variants[material]
        if variant then
            part.MaterialVariant = variant.name
            if variant.tint then
                local lift = if material == "glass" or material == "asphalt" then 0.52 else 0.64
                part.Color = color:Lerp(Color3.new(1, 1, 1), lift)
            end
        end
        if part:IsA("Part") then
            part.TopSurface = Enum.SurfaceType.Smooth
            part.BottomSurface = Enum.SurfaceType.Smooth
        end
        part.Parent = parent
        local position = part.CFrame.Position
        if position.Y > 1.8 and position.Y < 155 and math.abs(position.X) < 680 and math.abs(position.Z) < 650
            and part.Transparency < 0.74 and (material == "neon"
                or (height >= 2.5 and math.max(width, depth) >= 5.6 and material ~= "foliage" and material ~= "water")) then
            table.insert(reflectionCandidates, {
                part = part, position = position, order = #reflectionCandidates + 1,
                score = (if material == "neon" then 35 else 0) + math.min(height * math.max(width, depth), 360) / 24,
            })
        end
        stats.parts += 1
        if part.CanCollide then
            stats.colliders += 1
        end
        if pause and stats.parts % 600 == 0 then
            pause()
        end
        return part
    end

    function api.reflection(puddle)
        puddle:AddTag("CyberOutlawPoca")
        table.insert(mirrors, puddle.CFrame.Position)
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
        local level = math.floor(p.Y / 38)
        local key = cell(p, 72) .. "/" .. level
        local list = lightGroups[key]
        if not list then
            list = {}
            lightGroups[key] = list
        end
        table.insert(list, {light = light, part = part, order = #list + 1, level = level,
            weight = range * brightness * (if p.Y < 22 then 1.24 else 1)})
        return light
    end

    function api.finish()
        for _, list in lightGroups do
            table.sort(list, function(a, b)
                return if a.weight == b.weight then a.order < b.order else a.weight > b.weight
            end)
            local limit = if list[1].level <= 0 then 3 elseif list[1].level <= 2 then 2 else 1
            for index, entry in list do
                if index <= limit then
                    entry.light:SetAttribute("CyberOutlawBrilhoBase", entry.light.Brightness)
                    entry.light:AddTag("CyberOutlawLuzCidade")
                    entry.light.Parent = entry.part
                    stats.lights += 1
                else
                    entry.light:Destroy()
                end
            end
        end
        table.clear(lightGroups)
        -- Somente as fontes legíveis a partir das poças entram no índice replicado de reflexos.
        local groups = {}
        for _, entry in reflectionCandidates do
            local p, nearest = entry.position, math.huge
            for _, mirror in mirrors do
                local dx, dz = p.X - mirror.X, p.Z - mirror.Z
                nearest = math.min(nearest, dx * dx + dz * dz)
            end
            if nearest > 128 * 128 then continue end
            local key = cell(p, 58)
            local list = groups[key] or {}
            groups[key] = list
            entry.score -= math.sqrt(nearest) * 0.054 + p.Y * 0.14
            if entry.part:GetAttribute("MareReflexoCor") then entry.score += 27 end
            table.insert(list, entry)
        end
        for _, list in groups do
            table.sort(list, function(a, b)
                return if a.score == b.score then a.order < b.order else a.score > b.score
            end)
            for index = 1, math.min(#list, 28) do
                list[index].part:AddTag("CyberOutlawReflexoFonte")
            end
        end
        table.clear(reflectionCandidates)
        table.clear(mirrors)
    end

    function api.sign(part, face, inscription, accent, name)
        part:SetAttribute("MareReflexoCor", accent)
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
