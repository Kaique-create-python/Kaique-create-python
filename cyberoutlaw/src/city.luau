local function createCyberCity(parent: Instance, media, origin: Vector3?)
    local city = Instance.new("Model")
    city.Name = "Terraço do Estuário"
    local loopSeconds = 72
    city:SetAttribute("LoopDuration", loopSeconds)
    city:SetAttribute("VerticalFieldOfView", 46)
    local worldOffset = origin or Vector3.zero
    local rgb = Color3.fromRGB
    local plastic = Enum.Material.SmoothPlastic
    local steel = Enum.Material.Metal
    local rough = Enum.Material.CorrodedMetal
    local concrete = Enum.Material.Concrete
    local neon = Enum.Material.Neon
    local palette = {
        ink = rgb(9, 11, 18),
        iron = rgb(23, 28, 38),
        gray = rgb(46, 53, 64),
        rim = rgb(64, 73, 83),
        rust = rgb(79, 52, 46),
        glass = rgb(21, 33, 48),
        haze = rgb(52, 61, 84),
        pink = rgb(255, 41, 144),
        violet = rgb(180, 86, 250),
        cyan = rgb(58, 231, 255),
        ice = rgb(184, 223, 242),
        warm = rgb(255, 166, 94),
    }
    local seed = 361423
    local function range(a: number, b: number): number
        seed = seed * 48271 % 2147483647
        return a + (b - a) * (seed / 2147483647)
    end
    local function group(owner: Instance, name: string): Model
        local model = Instance.new("Model")
        model.Name = name
        model.Parent = owner
        return model
    end
    local function solid(
        owner: Instance, name: string, size: Vector3, pose: CFrame, color: Color3,
        material: Enum.Material?, shape: Enum.PartType?
    ): Part
        local part = Instance.new("Part")
        part.Name = name
        part.Size = size
        part.CFrame = pose + worldOffset
        part.Color = color
        part.Material = material or plastic
        part.Shape = shape or Enum.PartType.Block
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        part.Parent = owner
        return part
    end
    local function box(
        owner: Instance, name: string, x: number, y: number, z: number, w: number,
        h: number, d: number, color: Color3, material: Enum.Material?
    ): Part
        return solid(owner, name, Vector3.new(w, h, d), CFrame.new(x, y, z), color, material)
    end
    local function body(
        owner: Instance, name: string, x: number, z: number, base: number,
        w: number, h: number, d: number, color: Color3, material: Enum.Material?
    ): Part
        return box(owner, name, x, base + h / 2, z, w, h, d, color, material)
    end
    local function beam(
        owner: Instance, name: string, a: Vector3, b: Vector3, width: number, color: Color3,
        material: Enum.Material?, pipe: boolean?
    ): Part
        local direction = (b - a).Unit
        local up = if math.abs(direction.Y) > 0.98 then Vector3.zAxis else Vector3.yAxis
        local pose = CFrame.lookAt(a:Lerp(b, 0.5), b, up) * CFrame.Angles(0, math.pi / 2, 0)
        return solid(owner, name, Vector3.new((b - a).Magnitude, width, width), pose, color, material,
            if pipe then Enum.PartType.Cylinder else Enum.PartType.Block)
    end
    local function rod(
        owner: Instance, name: string, x: number, y: number, z: number,
        diameter: number, height: number, color: Color3, material: Enum.Material?
    ): Part
        return solid(owner, name, Vector3.new(height, diameter, diameter),
            CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
    end
    local function disk(
        owner: Instance, name: string, x: number, y: number, z: number,
        w: number, h: number, depth: number, color: Color3, material: Enum.Material?
    ): Part
        return solid(owner, name, Vector3.new(depth, h, w), CFrame.new(x, y, z) * CFrame.Angles(0, -math.pi / 2, 0),
            color, material, Enum.PartType.Cylinder)
    end
    local function light(part: Part, color: Color3, brightness: number, radius: number, face: Enum.NormalId?)
        local lamp
        if face then
            lamp = Instance.new("SurfaceLight")
            lamp.Face = face
            lamp.Angle = 104
        else
            lamp = Instance.new("PointLight")
        end
        lamp.Color = color
        lamp.Brightness = brightness
        lamp.Range = radius
        lamp.Shadows = false
        lamp.Parent = part
        return lamp
    end
    local function shade(color: Color3, amount: number): Color3
        return palette.ink:Lerp(color, amount)
    end
    local function front(
        owner: Instance, name: string, x: number, y: number, z: number,
        w: number, h: number, color: Color3, material: Enum.Material?
    ): Part
        return box(owner, name, x, y, z + 0.115, w, h, 0.23, color, material)
    end
    local function cables(owner: Instance, from: Vector3, to: Vector3, sag: number, thickness: number, color: Color3)
        local previous = from
        for index = 1, 9 do
            local t = index / 9
            local point = from:Lerp(to, t) - Vector3.new(0, 4 * sag * t * (1 - t), 0)
            beam(owner, "Cabo isolado", previous, point, thickness, color, rough, true)
            previous = point
        end
    end
    local function vent(owner: Instance, x: number, y: number, z: number, w: number, h: number)
        box(owner, "Caixa de ventilação", x, y, z, w, h, 0.91, palette.iron, rough)
        front(owner, "Rebaixo da grelha", x, y, z + 0.46, w * 0.91, h * 0.89, palette.ink)
        for row = 1, 5 do
            front(owner, "Grelha de ventilação", x, y + (row - 3) * h * 0.14, z + 0.7, w * 0.86,
                h * 0.053, palette.gray, steel)
        end
    end
    local function surfaceText(part: Part, name: string, copy: string, color: Color3)
        local gui = Instance.new("SurfaceGui")
        gui.Name = name
        gui.Face = Enum.NormalId.Back
        gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
        gui.CanvasSize = Vector2.new(560, 100)
        gui.AlwaysOnTop = false
        gui.LightInfluence = 0
        gui.Brightness = 1.25
        gui.MaxDistance = 260
        gui.Parent = part
        local label = Instance.new("TextLabel")
        label.Name = "Texto técnico"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Text = copy
        label.TextColor3 = color
        label.TextScaled = true
        label.Font = Enum.Font.Code
        label.Parent = gui
    end

    local foreground = group(city, "Terraço de serviço")
    local floorY = 26.8
    local poolRows = {
        {-12.4, -7.1, 0, 0}, {-7.1, -5.1, -1.9, 3.1}, {-5.1, -3.25, -3.1, 5.8},
        {-3.25, -1.3, -3.6, 6.7}, {-1.3, 1.4, -5.9, 8.8}, {1.4, 2.9, -7.1, 9.4},
        {2.9, 4.1, -6.3, 11.5}, {4.1, 6.05, -7.7, 12.4}, {6.05, 7.6, -8.8, 12.1},
        {7.6, 10.1, -8.1, 12.9}, {10.1, 13.1, -9.5, 12.1}, {13.1, 14.5, -9.2, 10.7},
        {14.5, 17.4, -8.3, 9.6}, {17.4, 19.3, -7.3, 9.95}, {19.3, 21.5, -7.8, 8.2},
        {21.5, 23.1, -7.1, 6.5}, {23.1, 25.2, -6.25, 4.67}, {25.2, 27.1, -5.5, 3.55},
        {27.1, 29.5, -3.7, 1.4}, {29.5, 32, -2.6, 0.24}, {32, 47, 0, 0},
    }
    local water = group(foreground, "Poças no asfalto")
    local function slab(a: number, b: number, z: number, depth: number, color: Color3)
        box(foreground, "Asfalto do terraço", (a + b) / 2, floorY - 0.35, z, b - a, 0.7, depth,
            color, Enum.Material.Asphalt)
    end
    local function poolEdge(a: number, b: number, frontZ: number, backZ: number, leftBank: boolean, tint: Color3)
        local width = math.abs(b - a)
        if width < 0.05 then
            return
        end
        local tallAtFront = if leftBank then a > b else a < b
        local across = Vector3.new(if leftBank then 1 else -1, 0, 0)
        local along = Vector3.new(0, 0, if tallAtFront then 1 else -1)
        local position = Vector3.new((a + b) / 2, floorY - 0.35, (frontZ + backZ) / 2)
        local pose = CFrame.fromMatrix(position, across:Cross(along), across, along)
        solid(foreground, "Margem irregular de asfalto", Vector3.new(0.7, width, backZ - frontZ), pose,
            tint, Enum.Material.Asphalt, Enum.PartType.Wedge)
        local from = Vector3.new(a, floorY + 0.021, frontZ)
        local to = Vector3.new(b, floorY + 0.021, backZ)
        beam(water, "Limite molhado da poça", from:Lerp(to, 0.22), to, 0.053, rgb(47, 46, 61), rough)
    end
    for rowIndex, row in poolRows do
        local start, finish, left, right = table.unpack(row)
        local depth, z = finish - start, (start + finish) / 2
        local tint = rgb(range(21, 26), range(22, 26), range(29, 34))
        if left == right then
            slab(-42, 42, z, depth, tint)
        else
            local previous, following = poolRows[rowIndex - 1], poolRows[rowIndex + 1]
            local center = (left + right) / 2
            local a = if previous[3] == previous[4] then center else (left + previous[3]) / 2
            local b = if following[3] == following[4] then center else (left + following[3]) / 2
            local c = if previous[3] == previous[4] then center else (right + previous[4]) / 2
            local d = if following[3] == following[4] then center else (right + following[4]) / 2
            local low, high = math.min(a, b), math.max(c, d)
            slab(-42, low, z, depth, tint)
            slab(high, 42, z, depth, tint)
            poolEdge(a, b, start, finish, true, tint)
            poolEdge(c, d, start, finish, false, tint)
            local film = box(water, "Superfície de água", (low + high) / 2, floorY - 0.065, z,
                high - low, 0.12, depth, rgb(9, 17, 30))
            film.Transparency = 0.74
            film.Reflectance = 0.10
            for _ = 1, 2 do
                local dx = range(left + 0.5, right - 0.5)
                local ripple = box(water, "Ondulação rasa", dx, floorY + 0.021, z + range(-0.22, 0.22) * depth,
                    range(0.68, 2.6), 0.046, range(0.08, 0.36), rgb(43, 48, 74))
                ripple.Transparency = range(0.27, 0.62)
            end
        end
    end
    for index = 1, 50 do
        local x = if index % 2 == 0 then range(-36, -10.5) else range(14, 40)
        local z = range(-11.0, 35)
        local stain = box(foreground, "Desgaste do piso", x, floorY + 0.016, z,
            range(0.42, 2.35), 0.04, range(0.10, 0.67),
            rgb(range(22, 41), range(27, 39), range(32, 45)), rough)
        stain.Reflectance = range(0, 0.11)
    end
    for _, x in {-12.3, 15.0, 33.2} do
        box(foreground, "Canaleta do terraço", x, floorY + 0.025, 11.25, 0.44, 0.07, 43.95, palette.iron, steel)
        for index = 0, 15 do
            box(foreground, "Grade de drenagem", x, floorY + 0.071, -9.07 + index * 2.76,
                0.37, 0.05, 0.13, palette.gray, steel)
        end
    end
    for index = 1, 10 do
        local z = -7.1 + index * 1.63
        local p = CFrame.new(-12.66, floorY + 0.065, z) * CFrame.Angles(0, math.rad(27), 0)
        solid(foreground, "Faixa de manutenção", Vector3.new(1.5, 0.051, 0.36), p, rgb(123, 79, 43), concrete)
    end

    local rail = group(foreground, "Guarda-corpo exposto")
    box(rail, "Borda de concreto", 2, floorY + 0.12, -10.9, 83, 0.43, 1.01, palette.iron, concrete)
    box(rail, "Corrimão molhado", 2, 30.03, -10.75, 83.65, 0.15, 0.24, palette.gray, steel).Reflectance = 0.20
    box(rail, "Reforço do corrimão", 2, 27.95, -10.81, 83.65, 0.15, 0.24, palette.iron, steel)
    box(rail, "Cabo de segurança", 2, 28.87, -10.80, 83.1, 0.066, 0.12, palette.iron, steel)
    for post = 0, 13 do
        local x = -38 + post * 6.15
        box(rail, "Montante aparafusado", x, 28.52, -10.75, 0.31, 3.1, 0.31, palette.iron, rough)
        box(rail, "Chapa de ancoragem", x, 27.06, -10.75, 0.9, 0.18, 0.58, palette.gray, steel)
        local endPoint = Vector3.new(x + 1.45, 27.87, -10.81)
        beam(rail, "Travamento diagonal", Vector3.new(x, 27.12, -10.81), endPoint, 0.13, palette.iron, rough)
    end

    local station = group(foreground, "Abrigo à esquerda")
    local wallX = -17.4
    local wall = box(station, "Parede de serviço", wallX, 35.45, 12.85, 2.3, 17.35, 44.6, rgb(30, 29, 35), concrete)
    wall.CastShadow = true
    box(station, "Pilar de esquina", -16.08, 35.35, -8.55, 1.2, 17.07, 1.1, palette.rust, rough).CastShadow = true
    box(station, "Rodapé de proteção", -16.19, 27.41, 13, 0.48, 1.25, 43.7, palette.iron, steel)
    for panel = 0, 13 do
        local z = -8.1 + panel * 3.2
        box(station, "Painel de chapa", -16.16, 34.9, z, 0.37, 12.7, 3.14,
            rgb(range(29, 41), range(28, 36), range(33, 45)), rough)
        box(station, "Emenda da chapa", -15.94, 34.9, z - 1.53, 0.22, 13.25, 0.09, palette.rim, steel)
        for _, y in {28.8, 40.75} do
            box(station, "Cabeça de rebite", -15.76, y, z, 0.13, 0.14, 0.18, palette.gray, steel)
        end
    end
    for pipe = 0, 3 do
        local z = -6.25 + pipe * 0.78
        beam(station, "Eletroduto vertical", Vector3.new(-15.53, 27.53, z), Vector3.new(-15.53, 40.59 - pipe * 0.27, z),
            0.26, if pipe == 0 then palette.rust else palette.gray, rough, true)
        beam(station, "Joelho metálico", Vector3.new(-15.53, 40.65 - pipe * 0.27, z),
            Vector3.new(-15.53, 41.13 - pipe * 0.27, z + 0.68), 0.26, palette.gray, rough, true)
        for _, y in {29.1, 33.5, 38.4} do
            box(station, "Abraçadeira", -15.49, y, z, 0.39, 0.15, 0.39, palette.rim, steel)
        end
    end
    box(station, "Quadro elétrico", -15.58, 31.73, -2.64, 0.82, 3.28, 2.39, palette.iron, rough)
    box(station, "Fecho do quadro", -15.10, 31.77, -2.1, 0.15, 0.47, 0.13, palette.rim, steel)
    for slot = 0, 5 do
        box(station, "Rasgo do quadro", -15.13, 31.48 + slot * 0.27, -2.88, 0.07, 0.083, 0.81, palette.gray, steel)
    end
    local lamp = box(station, "Lâmpada de sódio", -14.46, 36.25, -5.3, 1.10, 0.68, 1.58, palette.warm, neon)
    light(lamp, palette.warm, 2.32, 23).Shadows = true
    box(station, "Chapéu da lâmpada", -14.67, 36.68, -5.3, 1.48, 0.19, 1.96, palette.rust, rough)
    box(station, "Base da lâmpada", -14.67, 35.83, -5.3, 1.48, 0.14, 1.96, palette.iron, steel)
    for index = -2, 2 do
        box(station, "Grade da luminária", -13.87, 36.25, -5.3 + index * 0.31, 0.07, 0.76, 0.071, palette.rust, steel)
    end
    vent(station, -14.7, 30.18, -8.46, 2.61, 2.64)
    local canopy = group(foreground, "Marquise metálica")
    box(canopy, "Cobertura da marquise", -16.7, 46.0, 12.8, 38.0, 0.79, 32.4, palette.iron, rough).CastShadow = true
    box(canopy, "Testeira da marquise", -15.7, 45.52, -3.54, 38.5, 1.18, 0.86, palette.iron, rough).CastShadow = true
    beam(canopy, "Borda sob a chapa", Vector3.new(-30.3, 44.96, -4.06), Vector3.new(3.6, 44.96, -4.06),
        0.22, palette.rim, rough)
    for rafter = 0, 9 do
        local x = -27 + rafter * 3.15
        box(canopy, "Perfil sob o teto", x, 45.3, 11.9, 0.23, 0.57, 31.1, palette.gray, rough)
        box(canopy, "Parafuso da testeira", x, 45.81, -4.03, 0.13, 0.13, 0.10, palette.gray, steel)
    end
    for _, x in {-15, -7.6, 1.8} do
        beam(canopy, "Mão francesa", Vector3.new(-16.0, 39.9, 3.4 + x / 12), Vector3.new(x, 45.23, 3.4 + x / 12),
            0.44, palette.iron, steel)
    end
    cables(canopy, Vector3.new(-16.07, 41.94, -5.7), Vector3.new(42.8, 40.5, -29.5), 1.04, 0.17, palette.iron)
    cables(canopy, Vector3.new(-16.07, 43.18, -5.2), Vector3.new(42.8, 45.7, -32.5), 2.91, 0.23, palette.ink)
    cables(canopy, Vector3.new(-16.07, 44.03, -6.1), Vector3.new(42.8, 45.2, -32.7), 2.28, 0.11, palette.gray)
    local edgeLamp = box(rail, "Baliza magenta de manutenção", 6.9, 27.70, -10.29, 1.7, 0.15, 0.39,
        shade(palette.pink, 0.91), neon)
    box(rail, "Proteção da baliza", 6.9, 27.89, -10.35, 1.82, 0.19, 0.48, palette.iron, steel)
    light(edgeLamp, palette.pink, 1.28, 14, Enum.NormalId.Back)
    local coolLamp = box(rail, "Arandela fria do corrimão", 18.85, 28.06, -10.60, 0.61, 0.15, 0.30,
        shade(palette.cyan, 0.80), neon)
    light(coolLamp, palette.cyan, 0.88, 13, Enum.NormalId.Back)

    local transit = group(city, "Linha elevada do estuário")
    local trackZ = -40
    box(transit, "Tabuleiro do trem", 0, 21.6, trackZ, 333, 1.12, 9.35, palette.iron, concrete)
    box(transit, "Viga principal", 0, 21.2, trackZ + 4.31, 333, 1.65, 0.35, palette.gray, rough)
    box(transit, "Trilho externo", 0, 22.23, trackZ + 1.99, 333, 0.16, 0.17, palette.rim, steel)
    box(transit, "Trilho interno", 0, 22.23, trackZ - 1.99, 333, 0.16, 0.17, palette.rim, steel)
    box(transit, "Guarda-corpo do viaduto", 0, 23.15, trackZ + 4.58, 333, 0.10, 0.19, palette.gray, steel)
    for index = -6, 6 do
        local x = index * 23.75 + 3.2
        body(transit, "Pilar do viaduto", x, trackZ, -22, 1.92, 42.9, 3.15, palette.iron, concrete)
        box(transit, "Cabeça do pilar", x, 20.48, trackZ, 3.12, 0.74, 8.96, palette.gray, rough)
        box(transit, "Sinal de via", x, 21.48, trackZ + 4.56, 0.76, 0.15, 0.15, shade(palette.cyan, 0.55), neon)
        beam(transit, "Contraventamento", Vector3.new(x, 20.78, trackZ + 4.48),
            Vector3.new(x + 8.95, 23.05, trackZ + 4.48), 0.12, palette.gray, steel)
        for post = 0, 3 do
            box(transit, "Montante do viaduto", x + post * 5.94, 22.56, trackZ + 4.56, 0.13, 1.23, 0.17,
                palette.iron, steel)
        end
    end
    local railStation = group(transit, "Estação integrada ao edifício")
    local platformX, platformZ = -10.4, trackZ - 5.10
    box(railStation, "Laje do cais de embarque", platformX, 22.29, platformZ, 34.3, 0.50, 4.3,
        palette.gray, concrete)
    box(railStation, "Faixa segura de embarque", platformX, 22.552, trackZ - 3.11, 33.3, 0.056, 0.26,
        rgb(139, 121, 77), concrete)
    box(railStation, "Cobertura sobre a via", platformX, 28.48, trackZ - 2.22, 35.6, 0.54, 10.39,
        palette.iron, rough)
    box(railStation, "Testeira da estação", platformX, 28.55, trackZ + 3.08, 35.6, 0.88, 0.43,
        rgb(48, 54, 63), steel)
    box(railStation, "Fita de iluminação do cais", platformX, 28.02, trackZ + 2.75, 34.7, 0.081, 0.22,
        shade(palette.ice, 0.63), neon)
    box(railStation, "Parede envidraçada do cais", platformX, 25.48, trackZ - 6.89, 33.9, 5.59, 0.35,
        rgb(24, 40, 53), Enum.Material.Glass)
    for index = -4, 4 do
        local x = platformX + index * 4.15
        box(railStation, "Pilar atrás da plataforma", x, 25.34, trackZ - 6.57, 0.39, 5.64, 0.51, palette.rim, steel)
        box(railStation, "Perfil na cobertura", x, 28.17, trackZ - 2.2, 0.25, 0.26, 10.41, palette.iron, steel)
        if index % 2 == 0 then
            box(railStation, "Lâmpada da plataforma", x, 27.97, trackZ - 4.79, 1.54, 0.071, 0.24,
                shade(palette.warm, 0.51), neon)
        end
    end
    box(railStation, "Passagem ao corpo da estação", platformX, 22.65, trackZ - 11.3, 10.6, 0.55, 10.30,
        palette.iron, concrete)
    box(railStation, "Teto da passagem", platformX, 27.95, trackZ - 11.3, 10.6, 0.42, 10.27, palette.iron, rough)
    for side = -1, 1, 2 do
        box(railStation, "Galeria lateral", platformX + side * 5.15, 25.27, trackZ - 11.2, 0.18, 3.91, 10.15,
            rgb(30, 46, 57), Enum.Material.Glass)
        box(railStation, "Caixilho da galeria", platformX + side * 5.20, 24.18, trackZ - 11.2, 0.13, 0.12, 10.4,
            palette.rim, steel)
    end
    local train = group(transit, "Composição em movimento")
    for wagon = 0, 3 do
        local x, z = (wagon - 1.5) * 10.95, trackZ
        box(train, "Carroceria", x, 24.56, z, 10.35, 3.43, 4.51, rgb(55, 63, 76), steel)
        box(train, "Casco superior", x, 26.42, z, 10.0, 0.35, 3.88, palette.gray, rough)
        box(train, "Equipamento elétrico", x + 1.05, 26.85, z, 4.35, 0.57, 2.7, palette.iron, rough)
        box(train, "Saia do trem", x, 23.04, z, 10.5, 0.56, 4.64, palette.ink, steel)
        box(train, "Faixa da linha", x, 23.55, z + 2.3, 10.0, 0.13, 0.09, palette.pink, neon)
        for door = -1, 1 do
            local px = x + door * 3.2
            front(train, "Moldura de janela", px, 24.92, z + 2.25, 2.74, 1.62, palette.ink, steel)
            front(train, "Janela de passageiros", px, 24.98, z + 2.47, 2.36, 1.25, shade(palette.ice, 0.86), neon)
            front(train, "Divisória de janela", px - 0.23, 24.98, z + 2.63, 0.108, 1.27, palette.iron, steel)
        end
    end
    for _, side in {-1, 1} do
        local x = side * 21.78
        box(train, "Cabine de ponta", x, 24.61, trackZ, 1.4, 2.98, 3.86, palette.gray, steel)
        box(train, "Farol lateral", x + side * 0.22, 24.02, trackZ + 2.02,
            1.07, 0.34, 0.16, if side == 1 then palette.ice else palette.pink, neon)
    end
    train.WorldPivot = CFrame.new(worldOffset)
    local trainOffsets = {}
    for _, part in train:GetChildren() do
        table.insert(trainOffsets, {part = part, pose = part.CFrame})
    end

    local architecture = group(city, "Quadras verticais")
    local hasFacadeAtlas = type(media) == "table" and type(media.facades) == "number"
        and media.facades > 0 and media.facades % 1 == 0
    local glazing = rgb(24, 37, 51)
    local framePaint = rgb(57, 66, 77)
    local aluminium = rgb(77, 83, 90)
    local facadePaint = {
        glass = rgb(43, 57, 72),
        residential = rgb(62, 61, 62),
        industrial = rgb(54, 53, 57),
        spine = rgb(41, 53, 67),
    }

    local function mass(
        model: Instance, name: string, family: string, detailDepth: number, x: number, z: number,
        base: number, w: number, h: number, d: number, material: Enum.Material, tint: Color3?
    ): Part
        local color = tint or facadePaint[family]:Lerp(palette.haze, detailDepth * 0.33)
        local part = body(model, name, x, z, base, w, h, d, color, material)
        part:SetAttribute("FacadeFamily", family)
        part:SetAttribute("FacadeDepth", detailDepth)
        part:SetAttribute("FacadeSide", true)
        return part
    end

    local function mechanicalRoof(model: Instance, x: number, y: number, z: number, w: number, d: number, tint: Color3)
        local penthouseWidth = w * 0.45
        box(model, "Abrigo de máquinas", x - w * 0.12, y + 1.25, z - d * 0.21, penthouseWidth, 2.5, d * 0.34,
            palette.iron, concrete)
        box(model, "Telhado da casa de máquinas", x - w * 0.12, y + 2.65, z - d * 0.21, penthouseWidth + 0.42,
            0.3, d * 0.36, framePaint, rough)
        for _, side in {-1, 1} do
            local bx = x + side * w * 0.32
            rod(model, "Exaustão de cobertura", bx, y + 0.91, z + 0.15 * d, 1.24, 1.82, palette.gray, rough)
            rod(model, "Bocal do exaustor", bx, y + 1.85, z + 0.15 * d, 1.66, 0.22, palette.iron, steel)
        end
        local mastX, mastZ = x + w * 0.33, z - d * 0.27
        local height = range(4.8, 7.7)
        rod(model, "Antena coletiva", mastX, y + height / 2, mastZ, 0.16, height, palette.rim, steel)
        box(model, "Travessa da antena", mastX, y + height * 0.72, mastZ, 3.0, 0.12, 0.13, framePaint, steel)
        rod(model, "Baliza aérea", mastX, y + height, mastZ, 0.23, 0.27, shade(tint, 0.72), neon)
    end

    local function ledge(
        model: Instance, name: string, x: number, z: number, y: number, w: number, d: number, color: Color3
    )
        box(model, name, x, y + 0.04, z, w + 0.38, 0.36, d + 0.34, color, concrete)
        box(model, "Cinta sob a laje", x, y - 0.41, z, w + 0.035, 0.56, d + 0.037,
            color:Lerp(aluminium, 0.25), concrete)
        front(model, "Rufos metálicos", x, y + 0.26, z + d / 2 + 0.14, w + 0.4, 0.13, aluminium, steel)
        for _, side in {-1, 1} do
            box(model, "Pilastra de apoio da laje", x + side * (w / 2 - 0.48), y - 1.0, z + d / 2 + 0.05,
                0.36, 1.46, 0.42, framePaint, steel)
        end
    end

    local function residentialBalcony(model: Instance, x: number, sill: number, face: number, w: number, deep: boolean)
        local depth = if deep then 1.98 else 1.33
        local edge = face + depth
        box(model, "Laje da varanda", x, sill, face + depth / 2, w, 0.22, depth, rgb(66, 64, 66), concrete)
        box(model, "Guarda-corpo", x, sill + 1.03, edge - 0.06, w + 0.04, 0.10, 0.11, framePaint, steel)
        box(model, "Travessa do guarda-corpo", x, sill + 0.35, edge - 0.06, w, 0.09, 0.10, palette.iron, steel)
        for _, endSign in {-1, 1} do
            box(model, "Montante da varanda", x + endSign * (w * 0.47), sill + 0.53, edge - 0.06,
                0.10, 1.03, 0.15, framePaint, steel)
        end
    end

    local function condenser(model: Instance, x: number, y: number, fz: number)
        box(model, "Ar-condicionado externo", x, y, fz + 0.26, 0.80, 0.49, 0.50, rgb(80, 84, 83), steel)
        box(model, "Grelha de condensador", x + 0.07, y + 0.03, fz + 0.53, 0.51, 0.30, 0.06, palette.iron, rough)
    end

    local function frontFloors(
        model: Instance, family: string, x: number, face: number, first: number, top: number,
        width: number, pitch: number, bays: number, tint: Color3, depth: number
    )
        local bayWidth = width / bays
        local residential = family == "residential"
        local factory = family == "industrial"
        local glassHeight = pitch * (if factory then 0.47 elseif residential then 0.63 else 0.79)
        local rows = math.floor((top - first) / pitch)
        if rows < 1 then
            return
        end
        local height = rows * pitch
        local mid = first + height / 2
        local matte = if residential then rgb(57, 57, 62) else framePaint
        for index = 0, bays do
            local px = x - width / 2 + bayWidth * index
            local outer = index == 0 or index == bays
            local structural = outer or index % 3 == 0
            box(model, if structural then "Pilar externo da fachada" else "Montante vertical do caixilho",
                px, mid, face + (if structural then 0.18 else 0.28),
                if structural then 0.25 else 0.087, height, if outer then 0.80 elseif structural then 0.42 else 0.21,
                if structural then aluminium:Lerp(matte, 0.49) else matte, steel)
        end
        for floor = 1, rows do
            local y = first + (floor - 0.5) * pitch
            local sill = y - glassHeight / 2
            local industrialBelt = factory and floor % 4 == 0
            if not hasFacadeAtlas and not industrialBelt and (depth < 0.46 or floor % 2 == 0) then
                box(model, "Envidraçado recuado", x, y, face + 0.055, width - 0.13,
                    glassHeight, 0.13, glazing:Lerp(tint, if residential then 0.018 else 0.036), Enum.Material.Glass)
            end
            if depth < 0.42 or floor % 2 == 0 then
                box(model, "Peitoril saliente", x, sill - 0.09, face + 0.19, width + 0.12,
                    if industrialBelt then 0.23 else 0.095, if residential then 0.62 else 0.36, matte, steel)
            end
            if depth < 0.33 and floor % 2 == 1 and not industrialBelt then
                box(model, "Travessa acima das bandeiras", x, y + glassHeight * 0.30, face + 0.28,
                    width - 0.06, 0.062, 0.15, matte, steel)
            end
            if industrialBelt then
                box(model, "Grelha do piso mecânico", x + width * 0.13, y, face + 0.02, width * 0.68, 0.8, 0.25,
                    palette.iron, rough)
                for strip = -1, 1 do
                    box(model, "Aleta da tomada de ar", x + width * 0.13, y + strip * 0.20, face + 0.19,
                        width * 0.64, 0.05, 0.16, palette.gray, steel)
                end
            else
                local selected = (floor * 11 + bays) % bays + 1
                for bay = 1, bays do
                    local px = x - width / 2 + (bay - 0.5) * bayWidth
                    local inhabited = bay == selected and (if depth > 0.41 then floor % 3 == 1 else floor % 2 ~= 0)
                    if inhabited then
                        local warm = if residential or (floor + bay) % 3 == 0 then rgb(245, 193, 133) else palette.ice
                        local brightness = if floor % 5 == 0 then 0.62 else 0.43
                        box(model, "Interior iluminado atrás do caixilho", px - bayWidth * 0.06, y - glassHeight * 0.08,
                            face + 0.134, bayWidth * 0.64, glassHeight * 0.66, 0.051, shade(warm, brightness * (1 - depth * 0.48)),
                            if floor % 5 == 0 then neon else plastic)
                        if depth < 0.26 and floor % 3 == 0 then
                            box(model, "Cortina parcial", px + bayWidth * 0.28, y, face + 0.169,
                                bayWidth * 0.13, glassHeight * 0.92, 0.05, rgb(66, 65, 67), plastic)
                        end
                    elseif not hasFacadeAtlas and depth < 0.24 and (bay + floor * 3) % 6 == 0 then
                        box(model, "Painel de vidro escuro", px, y, face + 0.132, bayWidth * 0.82,
                            glassHeight * 0.87, 0.05, glazing:Lerp(tint, 0.09 + (floor % 3) * 0.027), Enum.Material.Glass)
                    end
                end
            end
            if residential and depth < 0.43 then
                if floor % 2 == 1 then
                    local bx = x + (if floor % 4 == 1 then -0.24 else 0.18) * width
                    residentialBalcony(model, bx, sill - 0.16, face + 0.14, math.min(width * 0.33, bayWidth * 2.24),
                        floor % 4 == 1)
                end
                if floor % 3 == 0 then
                    condenser(model, x + (if floor % 2 == 0 then 0.34 else -0.35) * width, sill + 0.41, face)
                end
            end
        end
    end

    local function returnWall(
        model: Instance, x: number, z: number, start: number, top: number, d: number, depth: number,
        tint: Color3, family: string
    )
        if top - start < 4 then
            return
        end
        local sideWidth = d * 0.67
        local isGlass = family == "spine" or family == "glass"
        local height = top - start
        local y = (top + start) / 2
        if not hasFacadeAtlas then
            box(model, "Vão envidraçado no retorno", x - 0.076, y, z + d * 0.05, 0.16, height, sideWidth,
                glazing:Lerp(tint, 0.025), Enum.Material.Glass)
        end
        for column = 0, if depth < 0.36 then 6 else 3 do
            local steps = if depth < 0.36 then 6 else 3
            local pz = z + d * 0.05 + (column / steps - 0.5) * sideWidth
            box(model, "Montante do retorno", x - 0.24, y, pz, if isGlass then 0.25 else 0.37, height, 0.15,
                framePaint, steel)
        end
        local pitch = if family == "residential" then 3.15 else 3.45
        local floors = math.floor(height / pitch)
        for floor = 1, floors do
            local fy = start + floor * pitch
            local close = depth < 0.26
            if close or floor % 2 == 0 then
                box(model, "Peitoril no retorno", x - 0.13, fy, z + d * 0.05, 0.29, 0.11, sideWidth,
                    framePaint, steel)
            end
            if floor % (if close then 3 else 5) == 1 then
                local fz = z + d * (if floor % 2 == 0 then 0.19 else -0.09)
                box(model, "Interior lateral", x - 0.17, fy + 0.62, fz, 0.08, 1.18, sideWidth * 0.14,
                    shade(if floor % 2 == 0 then palette.warm else palette.ice, 0.35), plastic)
            end
        end
    end

    local function plinth(
        model: Instance, x: number, z: number, face: number, w: number, d: number,
        base: number, top: number, tint: Color3, depth: number
    )
        mass(model, "Embasamento comercial", "industrial", depth, x - w * 0.03, z - 0.21, base, w * 1.08,
            top - base, d + 0.44, concrete, rgb(49, 50, 54))
        local roofZ = face + 0.55
        box(model, "Marquise sobre o embasamento", x, top + 0.11, roofZ, w + 1.75, 0.47, 2.2, palette.iron, rough)
        if depth < 0.31 then
            local step = w / 5.0
            for post = 0, 5 do
                local px = x + (post - 2.5) * step
                box(model, "Pilar do vestíbulo", px, top - 3.33, face + 0.52, 0.46, 6.32, 0.99,
                    framePaint, concrete)
                if post > 0 then
                    box(model, "Vitrine sob a marquise", px - step / 2, top - 2.64, face + 0.08,
                        step - 0.56, 4.49, 0.16, palette.glass:Lerp(tint, 0.07), Enum.Material.Glass)
                end
            end
            box(model, "Alizar do comércio", x, top - 1.17, face + 0.32, w, 0.13, 0.26, aluminium, steel)
            front(model, "Fita de luz sob a marquise", x - w * 0.19, top - 0.20, roofZ, w * 0.43, 0.077,
                shade(tint, 0.47), neon)
        end
    end

    local function highrise(
        name: string, x: number, z: number, w: number, d: number, base: number,
        h: number, tint: Color3, family: string, depth: number
    ): (Model, number)
        local model = group(architecture, name)
        local fz, top = z + d / 2, base + h
        local residential, industrial = family == "residential", family == "industrial"
        local skinMaterial = if residential or industrial then concrete else steel
        local podium = if industrial then 26.4 else 20.6
        local shaftOffset = if family == "spine" then w * 0.19 elseif residential then -w * 0.16 else w * 0.12
        local shaftW = w * (if family == "spine" then 0.69 elseif residential then 0.73 else 0.78)
        local shaftD = d * (if residential then 0.78 else 0.82)
        local shaftZ = z - d * (if industrial then 0.13 else 0.052)
        local setback = if industrial then top - h * 0.20 elseif residential then top - h * 0.29 else top - h * 0.25
        local capStyle = if family == "glass" then "spine" else family
        local slabColor = facadePaint[family]:Lerp(framePaint, 0.22)

        plinth(model, x, z, fz, w, d, base, podium, tint, depth)
        mass(model, "Pele do corpo principal", family, depth, x, z, podium, w, setback - podium, d, skinMaterial)
        ledge(model, "Terraço de recuo", x, z, setback, w, d, slabColor)
        mass(model, "Pele do corpo recuado", capStyle, depth, x + shaftOffset, shaftZ, setback,
            shaftW, top - setback, shaftD, skinMaterial)
        ledge(model, "Peitoril da cobertura", x + shaftOffset, shaftZ, top, shaftW, shaftD, slabColor)

        if depth < 0.44 then
            local pitch = if residential then 3.12 elseif industrial then 3.75 else 3.28
            local frontY = math.max(podium + 0.46, 22.8 - 11 * depth)
            local bays = if industrial then 5 elseif residential then 6 else 8
            frontFloors(model, family, x, fz, frontY, setback - 0.39, w * 0.89, pitch, bays, tint, depth)
            frontFloors(model, capStyle, x + shaftOffset, shaftZ + shaftD / 2, setback + 0.49, top - 0.37,
                shaftW * 0.87, pitch, math.max(4, bays - 2), tint, depth + 0.19)
            returnWall(model, x - w / 2, z, frontY, setback - 0.29, d, depth, tint, family)
            returnWall(model, x + shaftOffset - shaftW / 2, shaftZ, setback + 0.45, top - 0.40, shaftD,
                depth + 0.27, tint, capStyle)
            mechanicalRoof(model, x + shaftOffset, top + 0.14, shaftZ, shaftW, shaftD, tint)
        else
            frontFloors(model, family, x, fz, podium + 1.1, setback - 0.39, w * 0.87,
                5.8, if residential then 4 else 5, tint, depth)
            box(model, "Gabinete no topo", x + shaftOffset, top + 1.5, shaftZ, shaftW * 0.45, 2.7,
                shaftD * 0.46, palette.gray, concrete)
        end

        if family == "glass" or family == "spine" then
            local width = w * 0.12
            local px = x - w / 2 + width * 0.38
            local y = (podium + setback) / 2
            local height = setback - podium - 1.21
            local spine = box(model, "Espinha de vidro de esquina", px, y, fz + 0.39, width, height, 1.21,
                rgb(34, 52, 68), Enum.Material.Glass)
            spine.Reflectance = 0.095
            spine:SetAttribute("FacadeFamily", "spine")
            spine:SetAttribute("FacadeDepth", depth)
            if depth < 0.33 then
                box(model, "Perfil da espinha", px - width / 2, y, fz + 0.96, 0.12, height, 0.18, aluminium, steel)
                box(model, "Perfil da espinha", px + width / 2, y, fz + 0.96, 0.10, height, 0.17, aluminium, steel)
                for split = 1, 3 do
                    front(model, "Janela no núcleo de circulação", px, podium + (split * 0.18 + 0.17) * height, fz + 0.97,
                        width * 0.62, 0.36, shade(tint, 0.43), plastic)
                end
            end
        end

        if family == "spine" then
            local ribX = x - w * 0.39
            local height = top - setback - 1.2
            mass(model, "Lâmina estreita do núcleo superior", "spine", depth, ribX, z - d * 0.17,
                setback - 0.35, w * 0.21, height, d * 0.39, steel)
            for endIndex = 0, 2 do
                local y = setback + 1 + (endIndex + 1) * height * 0.22
                beam(model, "Escora entre volumes", Vector3.new(ribX, y, z + d * 0.015),
                    Vector3.new(x + shaftOffset - shaftW / 2, y + 1.65, shaftZ + shaftD * 0.44),
                    0.29, framePaint, steel)
            end
        elseif residential and depth < 0.38 then
            local deckX = x + w * 0.20
            local rearZ = z - d * 0.28
            mass(model, "Volume menor da caixa de escada", "residential", depth, deckX, rearZ, setback + 0.20,
                w * 0.28, (top - setback) * 0.54, d * 0.55, concrete, rgb(63, 60, 60))
            rod(model, "Prumada de captação", x - w / 2 - 0.24, (podium + setback) / 2, z + d * 0.32,
                0.19, setback - podium - 0.40, palette.gray, rough)
        elseif industrial and depth < 0.38 then
            local pipeX = x + w * 0.41
            for index = 0, 2 do
                local px = pipeX - index * 0.53
                local y = podium + 6.5 + index * 3.65
                beam(model, "Prumada industrial", Vector3.new(px, podium, fz + 0.29),
                    Vector3.new(px, y, fz + 0.29), 0.19, palette.rust, rough, true)
                beam(model, "Derivação da prumada", Vector3.new(px, y, fz + 0.29),
                    Vector3.new(px - 0.59, y + 0.53, fz + 0.09), 0.19, palette.rim, rough, true)
            end
        end
        return model, fz
    end

    local reflective = {}
    local function trace(
        owner: Instance, name: string, cx: number, cy: number, z: number, w: number, h: number,
        path, thickness: number, color: Color3
    )
        for index = 1, #path - 1 do
            local a, b = path[index], path[index + 1]
            beam(owner, name, Vector3.new(cx + a[1] * w, cy + a[2] * h, z),
                Vector3.new(cx + b[1] * w, cy + b[2] * h, z), thickness, color, neon)
        end
    end
    local function billboard(
        owner: Instance, index: number, x: number, y: number, z: number, w: number, color: Color3, copy: string
    )
        local model = group(owner, "Painel de rua " .. index)
        local h = w * 3
        local shell = box(model, "Caixilho em aço", x, y, z, w + 1.25, h + 1.48, 0.95, palette.iron, rough)
        box(model, "Rebaixo do anúncio", x, y, z + 0.54, w + 0.39, h + 0.45, 0.22, shade(color, 0.38), steel)
        box(model, "Visor do anúncio", x, y, z + 0.72, w, h, 0.16, shade(color, 0.21), neon)
        local border = w / 2 + 0.28
        for _, side in {-1, 1} do
            box(model, "Margem de LED", x + side * border, y, z + 0.95, 0.15, h + 0.51, 0.20, color, neon)
            box(model, "Terminal de LED", x, y + side * (h / 2 + 0.25), z + 0.95, w + 0.59, 0.15, 0.19,
                color, neon)
            for _, ay in {-0.38, 0.38} do
                beam(model, "Apoio de anúncio", Vector3.new(x + side * (w * 0.5 + 0.29), y + h * ay, z - 0.44),
                    Vector3.new(x + side * (w * 0.5 + 1.39), y + h * ay - 0.41, z - 1.52), 0.26,
                    palette.gray, steel)
            end
        end
        local artZ = z + 0.84
        local highlight = shade(if index == 1 then rgb(255, 210, 204) else palette.ice, 0.94)
        local visorY = y + h * 0.12
        disk(model, "Halo gráfico", x, visorY, artZ, w * 0.86, w * 1.02, 0.15, shade(color, 0.60), neon)
        disk(model, "Recorte gráfico", x + w * 0.09, visorY + w * 0.09, artZ + 0.09,
            w * 0.66, w * 0.83, 0.16, shade(color, 0.30), neon)
        local portrait = {
            {{-0.39, -0.32}, {-0.28, -0.19}, {-0.19, -0.10}, {-0.29, 0.03}, {-0.28, 0.20}, {-0.20, 0.30},
                {0.05, 0.32}, {0.24, 0.24}, {0.31, 0.09}, {0.24, -0.04}, {0.18, -0.14}, {0.35, -0.27}},
            {{-0.37, -0.35}, {-0.13, -0.16}, {-0.25, -0.03}, {-0.23, 0.17}, {-0.34, 0.24}, {-0.15, 0.24},
                {0.14, 0.32}, {0.28, 0.19}, {0.20, 0.11}, {0.31, -0.06}, {0.15, -0.17}, {0.34, -0.33}},
            {{-0.42, -0.37}, {-0.26, -0.24}, {-0.11, -0.18}, {-0.20, 0.01}, {-0.33, 0.15}, {-0.08, 0.29},
                {0.18, 0.31}, {0.29, 0.20}, {0.22, 0.02}, {0.13, -0.12}, {0.20, -0.21}, {0.41, -0.36}},
        }
        trace(model, "Contorno de retrato", x, visorY - h * 0.063, artZ + 0.23,
            w, h * 0.67, portrait[index], 0.23, color)
        trace(model, "Visor geométrico", x, visorY, artZ + 0.31, w, h * 0.6,
            {{-0.25, 0.042}, {-0.10, -0.023}, {0.072, -0.036}, {0.248, -0.003}}, 0.25, highlight)
        trace(model, "Recorte da gola", x, visorY, artZ + 0.29, w, h * 0.68,
            {{-0.19, -0.16}, {-0.034, -0.215}, {0.14, -0.21}, {0.207, -0.15}}, 0.14, highlight)
        for stripe = 0, 4 do
            local px = x + (stripe - 2) * w * 0.147
            front(model, "Impulsos no rodapé do anúncio", px, y - h * 0.377, artZ + 0.30, w * 0.118, h * 0.037,
                shade(color, 0.82 - stripe * 0.08), neon)
        end
        local caption = front(model, "Legenda do anúncio", x, y - h * 0.438, artZ + 0.28, w * 0.85, h * 0.066,
            shade(color, 0.15), neon)
        surfaceText(caption, "Sinalização", copy, highlight)
        shell:SetAttribute("BillboardIndex", index)

        local billboardId = if type(media) == "table" then media.billboard else nil
        if type(billboardId) == "number" and billboardId > 0 and billboardId % 1 == 0 then
            local screen = box(model, "Face da arte do anúncio", x, y, z + 1.43, w, h, 0.05, palette.ink)
            screen.Transparency = 1
            screen:SetAttribute("BillboardIndex", index)
            local gui = Instance.new("SurfaceGui")
            gui.Name = "Anúncio ilustrado"
            gui.Face = Enum.NormalId.Back
            gui.AlwaysOnTop = false
            gui.LightInfluence = 0
            gui.Brightness = 1.72
            gui.MaxDistance = 380
            gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
            gui.CanvasSize = Vector2.new(340, 1020)
            gui.Parent = screen
            local art = Instance.new("ImageLabel")
            art.Name = copy
            art.BackgroundTransparency = 1
            art.BorderSizePixel = 0
            art.Size = UDim2.fromScale(1, 1)
            art.Image = string.format("rbxassetid://%.0f", billboardId)
            art.ImageRectOffset = Vector2.new((index - 1) * 340, 0)
            art.ImageRectSize = Vector2.new(340, 1020)
            art.Parent = gui
        end
        light(shell, color, 1.22, 28, Enum.NormalId.Back)
        table.insert(reflective, model)
        return model
    end

    local a, af = highrise("Torre da eclusa", 26.0, -80.5, 21.2, 24.5, -22, 107, palette.pink, "glass", 0.03)
    local b, bf = highrise("Armazém aéreo", 54.4, -109, 23.6, 25.0, -22, 124, palette.cyan, "spine", 0.16)
    local c, cf = highrise("Edifício dos sinais", 92.5, -126.8, 19.3, 18.8, -22, 129, palette.violet, "glass", 0.27)
    billboard(a, 1, 25.8, 53.5, af + 0.62, 11.8, palette.pink, "ALVOR")
    billboard(b, 2, 52.8, 62.0, bf + 0.61, 10.15, palette.cyan, "ESTUÁRIO")
    billboard(c, 3, 91.7, 66.8, cf + 0.61, 10.4, palette.violet, "LIMIAR")

    local districts = {
        {"Comando sul", 5.4, -98, 14, 21.7, 112, palette.ice, "residential", 0.16},
        {"Oficinas da estação", -10.4, -65, 17.5, 21.5, 67, palette.warm, "industrial", 0.08},
        {"Escada norte", 41.8, -123, 13.3, 17.8, 148, palette.ice, "spine", 0.18},
        {"Terminais industriais", 44, -63.8, 13.7, 19.5, 64, palette.warm, "industrial", 0.12},
        {"Cubo da linha costeira", 63.5, -78, 16.2, 22.9, 79, palette.cyan, "residential", 0.12},
        {"Junta do canal", -17.1, -114, 20.3, 18.5, 137, palette.violet, "residential", 0.26},
        {"Casa da alfândega", 10.4, -141, 15.2, 19, 132, palette.violet, "spine", 0.29},
        {"Hospital suspenso", 18.5, -175, 23.2, 21.7, 123, palette.ice, "glass", 0.35},
        {"Arquivo bombeado", 103.5, -98, 17, 19.6, 93, palette.warm, "residential", 0.26},
        {"Rampa dos barcos", 112.1, -127.4, 19.5, 18, 123, palette.pink, "industrial", 0.32},
        {"Vetores da ponte", 111, -148, 20, 24, 149, palette.ice, "spine", 0.45},
        {"Quadra da névoa", 139, -193, 25, 22, 150, palette.cyan, "glass", 0.56},
        {"Estação leste", 90.5, -170, 18.5, 17, 153, palette.violet, "residential", 0.47},
        {"Câmara de pressão", 62, -182, 22, 25, 133, palette.ice, "spine", 0.48},
        {"Ramal cinza", 42, -201, 21, 20, 155, palette.ice, "glass", 0.60},
        {"Estaleiros de cima", -4, -196, 22, 26, 159, palette.ice, "industrial", 0.62},
        {"Pavilhão oeste", -35, -137, 21, 16.2, 99, palette.warm, "industrial", 0.52},
        {"Empilhamento oeste", -49, -175, 28, 20, 140, palette.violet, "residential", 0.63},
        {"Torre de inspeção", 125, -93, 11.8, 15.1, 101, palette.cyan, "industrial", 0.50},
        {"Ala de dosagem", 146.4, -115, 16.2, 15.4, 128, palette.warm, "residential", 0.54},
        {"Silo das sirenes", 166.8, -138, 10.4, 17, 137, palette.violet, "spine", 0.56},
        {"Prensa do distrito leste", 181.8, -165, 15.6, 17.2, 147, palette.ice, "industrial", 0.60},
        {"Sonda do dique", 203.5, -192, 15.9, 19.8, 167, palette.ice, "glass", 0.68},
    }
    local nearAccent
    for _, spec in districts do
        local name, x, z, w, d, h, tint, family, distance = table.unpack(spec)
        local block, face = highrise(name, x, z, w, d, -22, h, tint, family, distance)
        if name == "Oficinas da estação" then
            local signBack = box(block, "Anúncio de oficina", x + 1.1, 37.3, face + 0.56, 12.85, 2.36, 0.40,
                shade(palette.pink, 0.39), neon)
            front(block, "Arremate do anúncio", x + 1.1, 38.5, face + 0.75, 12.94, 0.12, palette.pink, neon)
            surfaceText(signBack, "Sinal de oficina", "LINHA 07", palette.ice)
        elseif name == "Terminais industriais" then
            nearAccent = front(block, "Faixa ciano suspensa", x, 40.18, face + 0.52, 9.1, 0.88, palette.cyan, neon)
            light(nearAccent, palette.cyan, 0.77, 23, Enum.NormalId.Back)
            for level = 0, 2 do
                local py = 27.1 + level * 4.9
                box(block, "Varanda técnica", x - 0.66, py, face + 0.95, 12.2, 0.20, 1.94, palette.iron,
                    Enum.Material.DiamondPlate)
                box(block, "Corrimão da varanda", x - 0.66, py + 0.9, face + 1.87, 12.2, 0.13, 0.14, palette.gray, steel)
                beam(block, "Escada inclinada", Vector3.new(x - 3.7, py, face + 1.94),
                    Vector3.new(x + 3.1, py + 4.9, face + 1.94), 0.16, palette.rim, steel)
            end
        end
    end

    local farCity = group(city, "Silhuetas na chuva")
    for layer = 1, 3 do
        local x = -149 - layer * 13
        while x < 281 + layer * 44 do
            local z = -204 - layer * 47 + range(-14, 14)
            local w, d = range(10, 27), range(12, 20)
            local height = range(59, 162) + layer * 7
            local shell = palette.haze:Lerp(rgb(35, 40, 61), range(0.18, 0.63))
            local top = height - 37
            body(farCity, "Prédio em névoa", x, z, -37, w, height, d, shell, concrete)
            body(farCity, "Recuo de torre", x + range(-0.20, 0.20) * w, z - 1.8, top,
                w * range(0.31, 0.87), range(3.9, 19), d * range(0.56, 0.8), shell, concrete)
            for row = 1, if layer == 1 then 2 else 1 do
                if range(0, 1) < 0.66 then
                    local k = if row % 2 == 0 then palette.cyan else palette.ice
                    front(farCity, "Luz atrás da chuva", x + range(-0.25, 0.25) * w, top - row * height * 0.12,
                        z + d * 0.5, w * range(0.18, 0.57), range(0.26, 0.52), shade(k, 0.14 + 0.06 / layer), neon)
                end
            end
            x += w + range(4, 7.4)
        end
    end

    local horizon = group(city, "Lua atrás da chuva")
    local moonX, moonY, moonZ = 224, 194, -383
    local moon = disk(horizon, "Lua", moonX, moonY, moonZ, 20.8, 20.8, 0.49, rgb(192, 221, 241), neon)
    moon:SetAttribute("Moon", true)
    for _, spec in {{1.4, 4.4, 5.9}, {-3.8, -1.3, 5.1}, {4.7, -2.8, 4.2}, {-3.9, 5.7, 2.9}, {1.3, -6.1, 3.1}} do
        disk(horizon, "Mancha lunar", moonX + spec[1], moonY + spec[2], moonZ + 0.29, spec[3], spec[3] * 0.83,
            0.11, rgb(163, 199, 220), neon)
    end
    for index = 1, 8 do
        local cloud = box(horizon, "Bruma lunar", moonX - 31 + index * 8,
            moonY - 7.7 + range(-2.7, 1.6), moonZ + 8 + index * 0.7,
            range(20, 54), range(0.34, 1.66), 0.7, rgb(29, 45, 65))
        cloud.Transparency = range(0.54, 0.84)
    end

    local reflections = group(city, "Imagem abaixo da água")
    local function invertY(v: Vector3): Vector3
        return Vector3.new(v.X, -v.Y, v.Z)
    end
    local function mirror(source: Part, strength: number)
        local cf = source.CFrame - worldOffset
        local point = cf.Position
        local pose = CFrame.fromMatrix(Vector3.new(point.X, 2 * floorY - point.Y, point.Z),
            invertY(cf.RightVector), -invertY(cf.UpVector), invertY(-cf.LookVector))
        local target = solid(reflections, "Reflexo • " .. source.Name, source.Size, pose, shade(source.Color, strength),
            source.Material, source.Shape)
        target.Transparency = source.Transparency
        return target
    end
    for _, model in reflective do
        for _, instance in model:GetDescendants() do
            if instance:IsA("Part") and instance.Transparency < 1 then
                mirror(instance, if instance.Material == neon then 0.56 else 0.42)
            end
        end
    end
    mirror(lamp, 0.43)
    mirror(edgeLamp, 0.49)
    mirror(coolLamp, 0.52)
    if nearAccent then
        mirror(nearAccent, 0.55)
    end
    -- Dark geometry deep beneath the openings gives the reflected signs a bounded backdrop.
    box(reflections, "Fundo profundo das poças", 0, -57.4, -13, 283, 1.5, 420, rgb(10, 15, 25))
    for index = 1, 86 do
        local row = poolRows[2 + (index * 7 % 18)]
        local x = range(row[3] + 0.06, row[4] - 0.06)
        local z = range(row[1] + 0.07, row[2] - 0.07)
        local tint = if x < -3 then palette.warm elseif x < 4 then palette.pink else palette.cyan
        local detail = box(water, "Risco de cor na água", x, floorY + 0.019, z,
            math.min(range(0.22, 2.3), 1.8 * math.min(x - row[3], row[4] - x)), 0.045, range(0.034, 0.24),
            shade(tint, range(0.11, 0.31)), neon)
        detail.Transparency = range(0.12, 0.65)
    end
    for _, zone in {{0.5, 4.4, palette.pink}, {9.4, 0.5, palette.cyan}, {-12.2, 1.1, palette.warm}} do
        local pool = box(foreground, "Luz refletida no terraço", zone[1], 27.13, zone[2], 0.15, 0.15, 0.15, zone[3])
        pool.Transparency = 1
        light(pool, zone[3], 0.79, 15)
    end

    local storm = group(city, "Chuva em primeiro plano")
    local streaks = {}
    for index = 1, 54 do
        local x, z = range(-25, 31), range(-42, 19.5)
        local size = Vector3.new(range(0.047, 0.068), range(1.30, 2.79), 0.051)
        local tone = shade(if index % 3 == 0 then palette.cyan else palette.ice, range(0.32, 0.55))
        local streak = solid(storm, "Traço de chuva", size, CFrame.new(x, 45, z), tone, neon)
        streak.Transparency = range(0.49, 0.76)
        local speed = 41 * math.floor(range(18, 32)) / loopSeconds
        table.insert(streaks, {part = streak, x = x, z = z, phase = range(0, 41), speed = speed})
    end

    local function cameraAt(seconds: number, aspectRatio: number?): CFrame
        local phase = (seconds % loopSeconds) * (2 * math.pi / loopSeconds)
        local eye = Vector3.new(
            -7.8 + 3.0 * math.sin(phase),
            33.47 + 0.63 * math.sin(phase + 0.44),
            27.5 + 2.25 * math.cos(phase)
        )
        local portraitShift = math.clamp((1.28 - (aspectRatio or 16 / 9)) * 12, 0, 8.2)
        local focus = Vector3.new(21.6 + portraitShift + 4.65 * math.sin(phase + 0.16),
            39.2 + 1.36 * math.sin(phase - 0.30), -124)
        return CFrame.lookAt(eye + worldOffset, focus + worldOffset)
    end

    local runtime = workspace ~= nil
    local rainTilt = CFrame.Angles(math.rad(8), 0, math.rad(-13))
    local function updateAt(seconds: number)
        local time = seconds % loopSeconds
        local trainX = -186 + ((time + 10.6) % 24) * 15.5
        if runtime then
            train:PivotTo(CFrame.new(worldOffset + Vector3.new(trainX, 0, 0)))
        else
            for _, piece in trainOffsets do
                piece.part.CFrame = piece.pose + Vector3.new(trainX, 0, 0)
            end
        end
        for _, drip in streaks do
            local progress = (drip.phase + time * drip.speed) % 41
            local y = 55.1 - progress
            drip.part.CFrame = CFrame.new(worldOffset + Vector3.new(drip.x + progress * 0.17, y, drip.z)) * rainTilt
        end
    end

    updateAt(0)
    city.Parent = parent
    return city, cameraAt, updateAt
end
