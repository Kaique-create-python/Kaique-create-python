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
    for index = 1, 62 do
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
    local nightGlass = rgb(23, 34, 52)
    local transomsRemaining = 125
    local function litFloors(
        model: Instance, x: number, fz: number, y: number, w: number, h: number,
        levels: number, columns: number, tint: Color3, intensity: number
    )
        local pitch = h / levels
        for row = 1, levels do
            local fy = y + (row - 0.5) * pitch
            front(model, "Leito de vidro fumê", x, fy, fz, w, pitch * 0.49, nightGlass, Enum.Material.SmoothPlastic)
            for column = 1, columns do
                if range(0, 1) < 0.74 then
                    local fx = x + (column - (columns + 1) / 2) * w / columns
                    local color = if range(0, 1) < 0.23 then palette.warm else tint
                    local glazing = w / columns * range(0.31, 0.78)
                    local height = pitch * range(0.17, 0.43)
                    local radiance = range(0.18, 0.76) * intensity
                    if levels >= 8 and columns >= 3 and (row + column) % 3 ~= 0 and transomsRemaining > 0 then
                        local offset = glazing * 0.27
                        front(model, "Vidro interno de sala", fx - offset, fy + height * 0.02, fz + 0.23,
                            glazing * 0.45, height * 0.75, shade(color, radiance), neon)
                        front(model, "Vidro ao lado do montante", fx + offset, fy - height * 0.04, fz + 0.23,
                            glazing * 0.37, height * 0.63, shade(color, radiance * 0.58), neon)
                        transomsRemaining -= 1
                    else
                        front(model, "Janela habitada", fx, fy, fz + 0.23, glazing * 0.89,
                            height * 0.79, shade(color, radiance), neon)
                    end
                end
            end
        end
    end
    local function roofFixtures(model: Instance, x: number, y: number, z: number, w: number, tint: Color3)
        box(model, "Platibanda", x, y + 0.44, z, w + 0.9, 0.87, 0.49, palette.rim, steel)
        for bay = -1, 1 do
            local bx = x + bay * w * 0.27
            if math.abs(bay) == 1 then
                rod(model, "Exaustor", bx, y + 1.07, z - 1.9, 1.41, 2.14, palette.gray, rough)
                rod(model, "Flange", bx, y + 2.09, z - 1.9, 1.84, 0.16, palette.iron, steel)
            else
                vent(model, bx, y + 1.38, z - 2.44, w * 0.27, 2.07)
            end
        end
        local mastHeight = range(4.9, 10.8)
        rod(model, "Antena técnica", x + w * 0.29, y + mastHeight / 2, z - 6.2, 0.17, mastHeight,
            palette.rim, steel)
        box(model, "Travessa de antena", x + w * 0.29, y + mastHeight * 0.76, z - 6.2, 3.64, 0.12, 0.16,
            palette.rim, steel)
        rod(model, "Baliza no topo", x + w * 0.29, y + mastHeight, z - 6.2, 0.32, 0.40, tint, neon)
    end
    local function highrise(
        name: string, x: number, z: number, w: number, d: number, base: number,
        h: number, tint: Color3, style: number, distance: number
    ): (Model, number)
        local model = group(architecture, name)
        local skin = rgb(33, 40, 55):Lerp(palette.haze, distance * 0.61)
        local fz = z + d * 0.5
        local waist, crown = h * 0.65, h * 0.82
        local bias = if style % 2 == 0 then 1 else -1
        body(model, "Plinto industrial", x + bias * 0.69, z, base, w * 1.21, h * 0.19, d * 1.1,
            skin:Lerp(palette.iron, 0.42), concrete)
        body(model, "Estrutura principal", x, z, base, w, waist, d, skin,
            if distance < 0.21 then rough else concrete)
        body(model, "Miolo da torre", x + bias * w * 0.09, z - 0.53, base + waist, w * 0.84,
            crown - waist, d * 0.87, skin:Lerp(palette.gray, 0.31), steel)
        body(model, "Ala suspensa", x + bias * w * 0.11, z - d * 0.18, base + crown, w * (0.54 + style % 3 * 0.1),
            h - crown, d * 0.61, skin, steel)
        local ribs = if distance < 0.4 then 4 else 2
        for rib = 0, ribs do
            local px = x + (rib / ribs - 0.5) * (w - 0.5)
            front(model, "Montante de fachada", px, base + waist * 0.51, fz - 0.09,
                if rib % 3 == 0 then 0.65 else 0.27, waist * 0.96, skin:Lerp(palette.rim, 0.37), steel)
        end
        local ySteps = if distance < 0.28 then 9 elseif distance < 0.50 then 6 else 3
        for step = 0, ySteps do
            local t = step / ySteps
            local y = base + h * (0.16 + 0.65 * t)
            local tierW = if t > 0.76 then w * 0.83 else w
            local tz = if t > 0.76 then fz - 0.52 else fz
            front(model, "Travessa horizontal", x, y, tz, tierW, if step % 3 == 0 then 0.52 else 0.23,
                skin:Lerp(palette.rim, 0.27), steel)
        end
        local levels = if distance < 0.13 then 10 elseif distance < 0.40 then 8 elseif distance < 0.52 then 5 else 3
        litFloors(model, x, fz, base + h * 0.14, w * (if style == 2 then 0.81 else 0.72), h * 0.48,
            levels, if distance < 0.13 then 4 elseif distance < 0.4 then 3 else 2, tint, 1 - distance * 0.56)
        litFloors(model, x + bias * w * 0.09, fz - d * 0.065 - 0.53, base + waist + 1.05, w * 0.64,
            h * 0.155, if distance < 0.4 then 4 else 2, 3, tint, 0.86 - distance * 0.34)
        local sx = x - w * 0.5 - 0.09
        for tier = 1, if distance < 0.13 then 8 elseif distance < 0.40 then 5 else 2 do
            local y = base + h * (0.12 + tier * 0.063)
            box(model, "Faixa lateral", sx, y, z + d * 0.08, 0.16, h * 0.014, d * 0.66, nightGlass)
            box(model, "Vidro lateral iluminado", sx - 0.11, y, z + range(-0.15, 0.21) * d,
                0.11, h * 0.010, d * range(0.17, 0.36), shade(tint, range(0.19, 0.48)), neon)
        end
        if distance < 0.4 then
            for _, side in {-1, 1} do
                local px = x + side * w * 0.43
                front(model, "Trilho de serviço", px, base + waist * 0.53, fz + 0.22, 0.35, waist * 0.88,
                    palette.iron, rough)
                for brace = 0, 4 do
                    front(model, "Suporte de trilho", px, base + waist * (0.2 + brace * 0.15), fz + 0.45,
                        0.81, 0.30, palette.gray, steel)
                end
            end
            local bandY = base + waist - 0.58
            front(model, "Faixa luminosa técnica", x + bias * w * 0.17, bandY, fz + 0.41, w * 0.58, 0.20,
                shade(tint, 0.73), neon)
        end
        if distance < 0.43 then
            roofFixtures(model, x + bias * w * 0.11, base + h, z + d * 0.116, w * 0.75,
                shade(tint, 0.76))
        else
            box(model, "Núcleo recuado no topo", x, base + h + 1.23, z - d * 0.14, w * 0.32, 2.46, d * 0.37,
                skin, rough)
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
            art.Image = "rbxassetid://" .. billboardId
            art.ImageRectOffset = Vector2.new((index - 1) * 340, 0)
            art.ImageRectSize = Vector2.new(340, 1020)
            art.Parent = gui
        end
        light(shell, color, 1.22, 28, Enum.NormalId.Back)
        table.insert(reflective, model)
        return model
    end

    local a, af = highrise("Torre da eclusa", 26.0, -80.5, 21.2, 24.5, -22, 107, palette.pink, 2, 0.03)
    local b, bf = highrise("Armazém aéreo", 54.4, -109, 23.6, 25.0, -22, 124, palette.cyan, 1, 0.16)
    local c, cf = highrise("Edifício dos sinais", 92.5, -126.8, 19.3, 18.8, -22, 129, palette.violet, 0, 0.27)
    billboard(a, 1, 25.8, 53.5, af + 0.62, 11.8, palette.pink, "ALVOR")
    billboard(b, 2, 52.8, 62.0, bf + 0.61, 10.15, palette.cyan, "ESTUÁRIO")
    billboard(c, 3, 91.7, 66.8, cf + 0.61, 10.4, palette.violet, "LIMIAR")

    local districts = {
        {"Comando sul", 5.4, -98, 14, 21.7, 112, palette.ice, 2, 0.16},
        {"Oficinas da estação", -10.4, -65, 17.5, 21.5, 67, palette.warm, 1, 0.08},
        {"Escada norte", 41.8, -123, 13.3, 17.8, 148, palette.ice, 2, 0.18},
        {"Terminais industriais", 44, -63.8, 13.7, 19.5, 64, palette.warm, 0, 0.12},
        {"Cubo da linha costeira", 63.5, -78, 16.2, 22.9, 79, palette.cyan, 1, 0.12},
        {"Junta do canal", -17.1, -114, 20.3, 18.5, 137, palette.violet, 1, 0.26},
        {"Casa da alfândega", 10.4, -141, 15.2, 19, 132, palette.violet, 0, 0.29},
        {"Hospital suspenso", 18.5, -175, 23.2, 21.7, 123, palette.ice, 2, 0.35},
        {"Arquivo bombeado", 103.5, -98, 17, 19.6, 93, palette.warm, 1, 0.26},
        {"Rampa dos barcos", 112.1, -127.4, 19.5, 18, 123, palette.pink, 2, 0.32},
        {"Vetores da ponte", 111, -148, 20, 24, 149, palette.ice, 0, 0.45},
        {"Quadra da névoa", 139, -193, 25, 22, 150, palette.cyan, 1, 0.56},
        {"Estação leste", 90.5, -170, 18.5, 17, 153, palette.violet, 0, 0.47},
        {"Câmara de pressão", 62, -182, 22, 25, 133, palette.ice, 2, 0.48},
        {"Ramal cinza", 42, -201, 21, 20, 155, palette.ice, 0, 0.60},
        {"Estaleiros de cima", -4, -196, 22, 26, 159, palette.ice, 1, 0.62},
        {"Pavilhão oeste", -35, -137, 21, 16.2, 99, palette.warm, 0, 0.52},
        {"Empilhamento oeste", -49, -175, 28, 20, 140, palette.violet, 2, 0.63},
        {"Torre de inspeção", 125, -93, 11.8, 15.1, 101, palette.cyan, 1, 0.50},
        {"Ala de dosagem", 146.4, -115, 16.2, 15.4, 128, palette.warm, 0, 0.54},
        {"Silo das sirenes", 166.8, -138, 10.4, 17, 137, palette.violet, 2, 0.56},
        {"Prensa do distrito leste", 181.8, -165, 15.6, 17.2, 147, palette.ice, 0, 0.60},
        {"Sonda do dique", 203.5, -192, 15.9, 19.8, 167, palette.ice, 1, 0.68},
    }
    local nearAccent
    for _, spec in districts do
        local name, x, z, w, d, h, tint, style, distance = table.unpack(spec)
        local block, face = highrise(name, x, z, w, d, -22, h, tint, style, distance)
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
        while x < 295 + layer * 48 do
            local z = -204 - layer * 47 + range(-14, 14)
            local w, d = range(10, 27), range(12, 20)
            local height = range(59, 162) + layer * 7
            local shell = palette.haze:Lerp(rgb(35, 40, 61), range(0.18, 0.63))
            local top = height - 37
            body(farCity, "Prédio em névoa", x, z, -37, w, height, d, shell, concrete)
            body(farCity, "Recuo de torre", x + range(-0.20, 0.20) * w, z - 1.8, top,
                w * range(0.31, 0.87), range(3.9, 19), d * range(0.56, 0.8), shell, concrete)
            for row = 1, if layer == 1 then 3 else 2 do
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
