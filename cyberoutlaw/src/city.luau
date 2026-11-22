local function createCyberCity(parent: Instance)
    local city = Instance.new("Model")
    city.Name = "Maré Baixa"
    city:SetAttribute("LoopDuration", 68)

    local rgb = Color3.fromRGB
    local metal = Enum.Material.SmoothPlastic
    local neon = Enum.Material.Neon
    local palette = {
        water = rgb(13, 17, 33),
        asphalt = rgb(27, 26, 42),
        stone = rgb(36, 34, 53),
        ledge = rgb(51, 47, 66),
        steel = rgb(62, 59, 83),
        iron = rgb(23, 24, 42),
        glass = rgb(30, 34, 57),
        copper = rgb(100, 64, 72),
        cyan = rgb(50, 216, 234),
        ice = rgb(176, 227, 242),
        rose = rgb(240, 47, 142),
        violet = rgb(160, 112, 228),
        amber = rgb(244, 163, 104),
        tail = rgb(255, 86, 105),
    }

    local seed = 203981
    local function range(minimum: number, maximum: number): number
        seed = (seed * 48271) % 2147483647
        return minimum + (maximum - minimum) * (seed / 2147483647)
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
        part.CFrame = pose
        part.Color = color
        part.Material = material or metal
        part.Shape = shape or Enum.PartType.Block
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Parent = owner
        return part
    end

    local function box(
        owner: Instance, name: string, x: number, y: number, z: number,
        width: number, height: number, depth: number, color: Color3, material: Enum.Material?
    ): Part
        return solid(owner, name, Vector3.new(width, height, depth), CFrame.new(x, y, z), color, material)
    end

    local function body(
        owner: Instance, name: string, x: number, z: number, base: number,
        width: number, height: number, depth: number, color: Color3
    )
        box(owner, name, x, base + height * 0.5, z, width, height, depth, color)
    end

    local function link(
        owner: Instance, name: string, from: Vector3, to: Vector3, thickness: number,
        color: Color3, material: Enum.Material?, pipe: boolean?
    )
        local offset = to - from
        local up = if math.abs(offset.Unit.Y) > 0.98 then Vector3.zAxis else Vector3.yAxis
        local pose = CFrame.lookAt(from:Lerp(to, 0.5), to, up) * CFrame.Angles(0, math.pi / 2, 0)
        local shape = if pipe then Enum.PartType.Cylinder else Enum.PartType.Block
        solid(owner, name, Vector3.new(offset.Magnitude, thickness, thickness), pose, color, material, shape)
    end

    local function cylinder(
        owner: Instance, name: string, x: number, y: number, z: number,
        diameter: number, height: number, color: Color3, material: Enum.Material?
    )
        local pose = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
        solid(owner, name, Vector3.new(height, diameter, diameter), pose, color, material, Enum.PartType.Cylinder)
    end

    local function front(
        owner: Instance, name: string, x: number, y: number, face: number,
        width: number, height: number, color: Color3, material: Enum.Material?
    )
        box(owner, name, x, y, face + 0.11, width, height, 0.22, color, material)
    end

    local function glow(color: Color3, strength: number): Color3
        return palette.glass:Lerp(color, strength)
    end

    local function tube(
        owner: Instance, name: string, from: Vector3, to: Vector3, width: number, color: Color3
    )
        link(owner, name, from, to, width * 3.7, glow(color, 0.24))
        link(owner, name .. " • Luz", from + Vector3.new(0, 0, width * 1.9),
            to + Vector3.new(0, 0, width * 1.9), width, color, neon)
    end

    local function roof(
        owner: Instance, x: number, y: number, z: number, width: number, depth: number, color: Color3
    )
        box(owner, "Platibanda", x, y + 0.34, z, width + 0.35, 0.68, depth + 0.35, color)
        box(owner, "Beiral", x, y + 0.75, z + depth * 0.5, width + 0.52, 0.24, 0.44, palette.steel)
    end

    local function rail(owner: Instance, x: number, y: number, z: number, width: number, color: Color3)
        box(owner, "Corrimão", x, y + 1.55, z, width, 0.20, 0.20, color)
        box(owner, "Rodapé", x, y + 0.32, z, width, 0.28, 0.29, palette.iron)
        for step = 0, 4 do
            local px = x + width * (step / 4 - 0.5)
            box(owner, "Montante", px, y + 0.82, z, 0.18, 1.64, 0.20, color)
        end
    end

    local function fan(owner: Instance, x: number, y: number, z: number, width: number)
        body(owner, "Ar condicionado", x, z, y, width, 1.75, 2.25, palette.iron)
        box(owner, "Tampa", x, y + 1.86, z, width + 0.24, 0.22, 2.48, palette.ledge)
        local face = z + 1.13
        front(owner, "Abertura técnica", x, y + 1, face, width * 0.82, 1.03, palette.glass)
        for row = 1, 4 do
            front(owner, "Aleta", x, y + 0.54 + row * 0.16, face + 0.22, width * 0.74, 0.048, palette.steel)
        end
    end

    local function cable(owner: Instance, a: Vector3, b: Vector3, sag: number)
        local previous = a
        for segment = 1, 6 do
            local t = segment / 6
            local point = a:Lerp(b, t) - Vector3.new(0, 4 * sag * t * (1 - t), 0)
            link(owner, "Cabo de serviço", previous, point, 0.14, palette.iron, nil, true)
            previous = point
        end
    end

    local function mast(owner: Instance, x: number, y: number, z: number, height: number, color: Color3)
        cylinder(owner, "Base de antena", x, y + 0.55, z, 1.55, 1.10, palette.iron)
        cylinder(owner, "Mastro", x, y + height * 0.5, z, 0.22, height, palette.steel)
        box(owner, "Elemento horizontal", x, y + height * 0.56, z, height * 0.62, 0.11, 0.12, palette.steel)
        box(owner, "Elemento horizontal", x, y + height * 0.76, z, height * 0.47, 0.11, 0.14, palette.ledge)
        cylinder(owner, "Luz de balizamento", x, y + height, z, 0.28, 0.42, color, neon)
    end

    local function ribs(
        owner: Instance, x: number, z: number, y0: number, y1: number,
        width: number, depth: number, color: Color3
    )
        for _, side in {-1, 1} do
            local px = x + side * (width * 0.5 - 0.18)
            box(owner, "Pilar de fachada", px, (y1 + y0) * 0.5, z + depth * 0.5 - 0.01, 0.36, y1 - y0, 0.54, color)
        end
    end

    local function windows(
        owner: Instance, x: number, z: number, base: number, width: number, height: number,
        rows: number, columns: number, light: Color3, density: number, strength: number
    )
        local rowHeight = height / rows
        local columnWidth = width / columns
        for row = 1, rows do
            local y = base + rowHeight * (row - 0.5)
            front(owner, "Faixa de vidro", x, y, z, width, rowHeight * 0.54, palette.glass)
            for column = 1, columns do
                local px = x + (column - (columns + 1) / 2) * columnWidth
                if range(0, 1) < density then
                    local tint = glow(light, range(strength * 0.53, strength))
                    front(owner, "Vão iluminado", px, y, z + 0.22, columnWidth * range(0.36, 0.83),
                        rowHeight * range(0.25, 0.49), tint, neon)
                end
            end
        end
    end

    local function sideWindows(
        owner: Instance, x: number, z: number, base: number, depth: number, height: number,
        rows: number, color: Color3
    )
        for row = 1, rows do
            local y = base + (row - 0.5) * height / rows
            box(owner, "Vidro lateral", x, y, z, 0.18, height / rows * 0.38, depth, palette.glass)
            local litDepth = depth * range(0.17, 0.46)
            box(owner, "Vão lateral iluminado", x - 0.13, y, z + range(-depth * 0.22, depth * 0.22),
                0.13, height / rows * 0.28, litDepth, glow(color, range(0.33, 0.63)), neon)
        end
    end

    local digits = {
        ["0"] = {"111", "101", "101", "101", "111"},
        ["1"] = {"010", "110", "010", "010", "111"},
        ["4"] = {"101", "101", "111", "001", "001"},
        ["7"] = {"111", "001", "010", "010", "010"},
        ["9"] = {"111", "101", "111", "001", "111"},
    }

    local function sign(owner: Instance, text: string, x: number, y: number, z: number, unit: number, color: Color3)
        local width = unit * (#text * 4 + 1)
        front(owner, "Painel de sinalização", x, y, z, width, unit * 7.4, glow(color, 0.24))
        front(owner, "Leito do letreiro", x, y, z + 0.22, width - unit * 0.53, unit * 6.9, palette.iron)
        for index = 1, #text do
            local glyph = digits[string.sub(text, index, index)]
            local offset = (index - (#text + 1) * 0.5) * 4 * unit
            for row, strokes in glyph do
                local first, last = string.find(strokes, "1+")
                while first and last do
                    front(owner, "Segmento do letreiro", x + offset + (first + last - 4) * unit * 0.5,
                        y + (3 - row) * unit, z + 0.44, (last - first + 0.86) * unit, unit * 0.78, color, neon)
                    first, last = string.find(strokes, "1+", last + 1)
                end
            end
        end
    end

    local function balcony(owner: Instance, x: number, y: number, facade: number, width: number, color: Color3)
        box(owner, "Laje de varanda", x, y, facade + 0.95, width, 0.43, 2.07, palette.iron)
        box(owner, "Borda de varanda", x, y + 0.03, facade + 2.0, width, 0.32, 0.28, palette.ledge)
        box(owner, "Guarda-corpo", x, y + 1.11, facade + 1.99, width, 0.17, 0.17, palette.steel)
        box(owner, "Sinalização da varanda", x + width * 0.33, y + 0.04, facade + 2.17, width * 0.24,
            0.13, 0.13, glow(color, 0.57), neon)
    end

    local skyline = group(city, "Céu e prédios distantes")
    for band = 0, 41 do
        local height = 11
        local y = -23 + band * height
        local amount = math.clamp((y + 16) / 280, 0, 1)
        local horizon = rgb(57, 32, 64)
        local upperAir = rgb(16, 13, 33)
        local color = horizon:Lerp(upperAir, amount ^ 0.64)
        box(skyline, "Céu", -18, y, -465, 1340, height, 1, color, neon)
    end

    for row = 1, 2 do
        local along = -259
        local haze = if row == 1 then rgb(67, 47, 77) else rgb(50, 43, 71)
        while along < 258 do
            local width = range(7, 19)
            local depth = range(12, 25)
            local height = range(24, 102) + 8 * math.sin(along / 28)
            local z = -421 + row * 32 + range(-8, 8)
            local color = haze:Lerp(rgb(31, 26, 52), range(0.09, 0.48))
            body(skyline, "Torre distante", along, z, 0, width, height, depth, color)
            body(skyline, "Recuo de cobertura", along - width * 0.16, z - 2, height, width * 0.51,
                range(3, 11), depth * 0.55, color)
            if range(0, 1) < 0.34 then
                front(skyline, "Luzes na névoa", along, height * 0.65, z + depth * 0.5, width * 0.57,
                    0.47, glow(if row == 1 then palette.violet else palette.rose, 0.28), neon)
            end
            along += width + range(1.4, 6.5)
        end
    end

    local ground = group(city, "Canal e vias")
    box(ground, "Água do canal", 4, -1.13, -10, 720, 1.70, 730, palette.water)
    body(ground, "Cais oeste", -80, -113, -3, 174, 6, 196, palette.stone)
    body(ground, "Cais leste", 122, -119, -3, 162, 6, 193, palette.stone)
    body(ground, "Bacia de serviço", 22, -185, -3, 32, 6, 137, palette.stone)
    body(ground, "Base continental", 10, -310, -3, 560, 6, 201, rgb(34, 29, 51))
    box(ground, "Muro oeste", -79, 2.4, -15.20, 172, 1.3, 1.1, palette.iron)
    box(ground, "Muro leste", 122, 2.4, -22.65, 162, 1.3, 1.1, palette.iron)
    box(ground, "Beira do canal", 7.42, 2.52, -65, 1.10, 1.48, 99, palette.ledge)
    box(ground, "Beira do canal", 40.57, 2.52, -69, 1.10, 1.48, 91, palette.ledge)
    box(ground, "Rua da margem", 114, 3.07, -27, 143, 0.14, 4.65, palette.asphalt)
    box(ground, "Rua da margem", -77, 3.07, -21, 161, 0.14, 4.50, palette.asphalt)
    box(ground, "Via dos estaleiros", 93.75, 3.08, -93, 7.1, 0.17, 128, palette.asphalt)
    box(ground, "Via de serviço", -21, 3.08, -102, 6.35, 0.17, 112, palette.asphalt)
    for stripe = 0, 17 do
        box(ground, "Marcação da via", 93.75, 3.18, -38 - stripe * 6.4, 0.19, 0.06, 2.85,
            rgb(95, 86, 106))
        box(ground, "Marcação junto ao cais", -130 + stripe * 7.4, 3.17, -21, 3.0, 0.06, 0.16,
            rgb(81, 68, 91))
    end
    for fixture = 0, 18 do
        local x = 42 + fixture * 6.75
        box(ground, "Defensa do cais", x, 1.5, -22.13, 0.50, 2.48, 0.43, palette.iron)
        if fixture % 3 == 0 then
            box(ground, "Luz de cais", x, 2.85, -21.88, 0.64, 0.15, 0.11, glow(palette.amber, 0.61), neon)
        end
    end

    local reflections = group(city, "Reflexos no canal")
    for _, sweep in {
        {-54, -11, 27, 9, palette.violet},
        {-14, -10, 31, 6, palette.rose},
        {7, -12, 48, 9, palette.cyan},
        {22, -16, 68, 5, palette.violet},
        {37, -16, 52, 7, palette.rose},
        {55, -19, 41, 10, palette.cyan},
        {74, -19, 39, 8, palette.amber},
        {99, -19, 59, 8, palette.rose},
    } do
        local x, z, length, width, color = sweep[1], sweep[2], sweep[3], sweep[4], sweep[5]
        for stripe = 1, 9 do
            local t = stripe / 10
            local px = x + range(-1, 1) * (1 + t * width * 0.48)
            local pz = z + length * t
            local shine = palette.water:Lerp(color, (1 - t) * range(0.11, 0.32))
            local reflectionWidth = width * range(0.25, 0.91) * (1 - t * 0.43)
            box(reflections, "Reflexo", px, -0.24 + stripe * 0.002, pz, reflectionWidth,
                0.04, range(0.35, 1.8) + t * 0.5, shine, neon)
        end
    end

    local function crossing(name: string, z: number, y: number, wide: number, color: Color3)
        local bridge = group(city, name)
        local west, east = 1, 47
        local span = east - west
        local frontZ = z + wide * 0.5
        box(bridge, "Tabuleiro", 24, y, z, span, 1.28, wide, palette.iron)
        box(bridge, "Pista", 24, y + 0.71, z, span, 0.19, wide - 0.58, palette.asphalt)
        for _, x in {west + 1.25, east - 1.25} do
            body(bridge, "Pilar principal", x, z, 0, 2.65, y - 0.63, wide * 0.71, palette.stone)
            box(bridge, "Cabeceira", x, y - 0.9, z, 4.2, 1.0, wide + 1.5, palette.ledge)
        end
        box(bridge, "Viga longitudinal", 24, y - 0.54, frontZ, span, 0.47, 0.53, palette.ledge)
        box(bridge, "Viga superior", 24, y + 3.89, frontZ, span, 0.32, 0.35, palette.steel)
        box(bridge, "Faixa luminosa", 24, y + 3.89, frontZ + 0.24, span - 0.9, 0.12, 0.17, glow(color, 0.69), neon)
        for panel = 0, 7 do
            local x = west + panel * span / 8
            local nextX = x + span / 8
            local low = Vector3.new(x, y - 0.39, frontZ)
            local high = Vector3.new(nextX, y + 3.86, frontZ)
            link(bridge, "Contraventamento", low, high, 0.25, palette.steel)
            box(bridge, "Montante de ponte", x, y + 1.83, frontZ, 0.29, 4.35, 0.32, palette.ledge)
        end
        for post = 0, 4 do
            box(bridge, "Sinal de tráfego", west + 5 + post * 9, y + 0.37, frontZ + 0.24,
                0.84, 0.13, 0.16, glow(color, 0.83), neon)
        end
        return bridge
    end

    crossing("Ponte dos Estaleiros", -32, 13, 6.2, palette.rose)
    local platform = crossing("Travessia do Monotrilho", -88, 30.5, 6.9, palette.cyan)
    box(platform, "Viaduto oeste", -11.55, 30.5, -88, 27.1, 1.28, 6.9, palette.iron)
    box(platform, "Viaduto oeste", -11.55, 30.81, -84.52, 27.1, 0.25, 0.34, palette.steel)
    box(platform, "Sinalização do viaduto", -11.55, 30.95, -84.31, 27.1, 0.12, 0.12,
        glow(palette.cyan, 0.55), neon)
    for _, support in {-19.1, -7.4} do
        body(platform, "Pilar do viaduto", support, -88, 3, 2.45, 26.9, 3.25, palette.stone)
        box(platform, "Cabeça do pilar", support, 29.37, -88, 3.3, 0.9, 6.0, palette.ledge)
    end
    local trainZ = -86.7
    for carriage = 0, 2 do
        local x = 16 + carriage * 7.25
        box(platform, "Carro do monotrilho", x, 32.5, trainZ, 6.95, 2.47, 2.98, rgb(74, 58, 84))
        box(platform, "Truque ferroviário", x, 31.25, trainZ, 4.7, 0.40, 2.2, palette.iron)
        box(platform, "Testeira do trem", x, 33.79, trainZ, 6.98, 0.24, 2.72, palette.ledge)
        front(platform, "Janela panorâmica", x, 32.83, trainZ + 1.49, 6.19, 0.72, glow(palette.ice, 0.62), neon)
        for divider = -2, 2 do
            front(platform, "Divisória de janela", x + divider * 1.09, 32.82, trainZ + 1.71, 0.14, 0.82, palette.iron)
        end
    end

    local homes = group(city, "Prédios baixos")
    local blocks = {
        {"Oficina da enseada", -7, -33, 18, 13, 13, rgb(50, 37, 53), palette.rose, true},
        {"Estaleiro norte", -32, -38, 15, 17, 16, rgb(46, 42, 63), palette.amber, true},
        {"Arquivo portuário", -53, -32, 21, 18, 22, rgb(38, 39, 63), palette.violet, false},
        {"Operações do dique", -72, -47, 13, 22, 28, rgb(39, 42, 65), palette.cyan, false},
        {"Depósito aduaneiro", -94, -37, 20, 18, 18, rgb(45, 40, 57), palette.amber, false},
        {"Vila das comportas", -46, -61, 18, 30, 17, rgb(40, 39, 58), palette.violet, false},
        {"Torres de mudança", -63, -77, 14, 38, 14, rgb(42, 37, 57), palette.amber, false},
        {"Correio hidráulico", -86, -77, 15, 35, 16, rgb(35, 39, 61), palette.violet, false},
        {"Antiga olaria", -105, -93, 20, 40, 22, rgb(44, 38, 57), palette.amber, false},
        {"Casa das bombas", -5, -62, 13, 20, 17, rgb(35, 42, 63), palette.cyan, false},
        {"Passarela baixa", -4, -99, 16, 22, 15, rgb(44, 37, 57), palette.amber, false},
        {"Conserto de válvulas", 50, -52, 12, 28, 16, rgb(40, 35, 58), palette.rose, true},
        {"Armazém do cais", 52, -34, 14, 11, 13, rgb(42, 39, 60), palette.cyan, true},
        {"Oficina elétrica", 73, -34, 18, 13, 9, rgb(54, 40, 58), palette.rose, true},
        {"Abrigo do ramal", 104, -36, 13, 15, 14, rgb(49, 39, 58), palette.amber, false},
        {"Alfândega baixa", 125, -43, 18, 22, 13, rgb(45, 40, 62), palette.rose, false},
        {"Armazém oeste", -51, 23, 32, 16, 23, rgb(26, 30, 49), palette.violet, false},
        {"Casa de marés", -82, 37, 23, 20, 21, rgb(25, 27, 46), palette.amber, false},
    }

    for _, spec in blocks do
        local name, x, z, width, height, depth, color, accent, marquee =
            spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7], spec[8], spec[9]
        local model = group(homes, name)
        local y = if z > 0 then -0.8 else 3.2
        local facade = z + depth * 0.5
        body(model, "Estrutura", x, z, y, width, height, depth, color)
        local top = y + height
        roof(model, x, top, z, width, depth, color:Lerp(palette.ledge, 0.48))
        body(model, "Casa de máquinas", x - width * 0.27, z - depth * 0.17, top + 0.68,
            width * 0.36, 2.46, depth * 0.32, palette.iron)
        fan(model, x + width * 0.20, top + 0.68, z + depth * 0.16, width * 0.40)
        ribs(model, x, z, y + 0.9, top - 0.33, width, depth, color:Lerp(palette.steel, 0.23))
        if z > 0 then
            rail(model, x, top + 0.7, facade - 0.43, width - 0.54, palette.ledge)
            box(model, "Duto de exaustão", x, top + 1.28, z, width * 0.84, 0.59, 1.5, palette.steel)
            box(model, "Duto de exaustão", x + width * 0.33, top + 1.25, z + depth * 0.18,
                1.51, 0.63, depth * 0.36, palette.steel)
        end
        windows(model, x, facade, y + 3.9, width * 0.81, height - 4.82, math.floor(height / 5), 3,
            accent, if marquee then 0.79 else 0.60, if z > 0 then 0.43 else 0.58)
        front(model, "Porta de serviço", x - width * 0.23, y + 1.22, facade, width * 0.21, 2.14, palette.iron)
        front(model, "Vitrine", x + width * 0.18, y + 1.63, facade, width * 0.45, 1.89, glow(accent, 0.25), neon)
        if marquee then
            local left = Vector3.new(x - width * 0.44, y + 2.90, facade + 0.13)
            local right = Vector3.new(x + width * 0.44, y + 2.90, facade + 0.13)
            tube(model, "Letreiro de oficina", left, right, 0.19, accent)
            front(model, "Friso", x, top - 1.0, facade, width * 0.93, 0.22, glow(accent, 0.73), neon)
        end
    end

    local promenade = group(city, "Passeio das comportas")
    for pole = 0, 4 do
        local x = 45 + pole * 12.6
        cylinder(promenade, "Poste do cais", x, 6.05, -24.75, 0.27, 5.8, palette.steel)
        box(promenade, "Braço do poste", x, 8.94, -24.03, 0.26, 0.20, 1.65, palette.iron)
        box(promenade, "Luminária do cais", x, 8.87, -23.25, 0.70, 0.14, 0.85,
            glow(if pole < 2 then palette.cyan else palette.amber, 0.73), neon)
        if pole < 4 then
            cable(promenade, Vector3.new(x, 8.11, -24.75), Vector3.new(x + 12.6, 8.11, -24.75), 0.72)
        end
    end

    local towers = group(city, "Torres do estuário")

    do
        local model = group(towers, "Agulha das Marés")
        local x, z, y = 54, -97, 3.2
        local casing, crown = rgb(45, 46, 68), rgb(54, 56, 81)
        body(model, "Embasamento", x, z, y, 26, 12, 27, palette.iron)
        roof(model, x, y + 12, z, 26, 27, palette.ledge)
        body(model, "Torre baixa", x, z, y + 12, 21.7, 37, 22, casing)
        body(model, "Torre alta", x + 0.8, z - 0.8, y + 49, 17.4, 30, 18.2, crown)
        body(model, "Coroamento suspenso", x + 1.2, z - 1, y + 79, 14.3, 13, 14.2, casing)
        body(model, "Aleta leste", x + 7.4, z - 0.7, y + 78, 1.75, 24, 15.8, palette.steel)
        body(model, "Aleta oeste", x - 6.2, z - 0.7, y + 78, 1.65, 20.6, 15.3, palette.iron)
        body(model, "Câmara de sinal", x + 4, z - 3.2, y + 92, 5.4, 5.3, 6.3, palette.glass)
        for _, hx in {x - 7.8, x + 6.4} do
            front(model, "Vidro vertical", hx, y + 31.4, z + 11, 3.4, 34.9, palette.glass)
            for floor = 1, 11 do
                local lit = if floor % 4 == 0 then palette.amber else palette.cyan
                front(model, "Janelas da agulha", hx, y + 14 + floor * 3.02, z + 11.22,
                    range(1.75, 2.94), range(0.54, 0.99), glow(lit, range(0.49, 0.89)), neon)
            end
        end
        windows(model, x + 0.35, z + 8.30, y + 49.7, 11.5, 25.8, 10, 3, palette.ice, 0.70, 0.78)
        windows(model, x, z + 13.5, y + 2.4, 22, 7, 2, 4, palette.violet, 0.82, 0.62)
        sideWindows(model, x - 10.92, z - 0.7, y + 14, 16.1, 33, 9, palette.cyan)
        sideWindows(model, x - 7.98, z - 1.7, y + 50, 14, 27, 7, palette.ice)
        for _, height in {y + 12.6, y + 49.3, y + 78.8, y + 91.6} do
            local tierWidth = if height < y + 50 then 22.1 else 15.2
            local face = if height < y + 50 then z + 11.27 else z + 8.25
            front(model, "Friso da agulha", x + 0.58, height, face, tierWidth, 0.46, palette.steel)
            front(model, "Linha de sinal", x + 2.5, height, face + 0.22, tierWidth * 0.68, 0.14,
                glow(palette.cyan, 0.84), neon)
        end
        tube(model, "Baliza vertical", Vector3.new(x + 7.4, y + 80.4, z + 7.31),
            Vector3.new(x + 7.4, y + 101.6, z + 7.31), 0.21, palette.cyan)
        for _, span in {{15, 29.4}, {33.3, 46.8}, {53.3, 75.2}} do
            local upper = span[1] > 50
            local spine = x - (if upper then 7.4 else 10.2)
            local facade = z + (if upper then 8.40 else 11.27)
            tube(model, "Guia do elevador", Vector3.new(spine, y + span[1], facade),
                Vector3.new(spine, y + span[2], facade), 0.20, glow(palette.cyan, 0.83))
        end
        for _, side in {-1, 1} do
            local fx = x + side * 7.1
            link(model, "Viga de coroamento", Vector3.new(fx, y + 90, z + 6.6),
                Vector3.new(x + 1.1, y + 96.1, z + 6.6), 0.49, palette.steel)
        end
        local arm = Vector3.new(x - 11.55, y + 101.34, z + 2.8)
        link(model, "Braço de comunicação", Vector3.new(x - 5.4, y + 91.17, z + 2.8), arm, 0.71, palette.steel)
        link(model, "Travessa de comunicação", Vector3.new(x - 5.1, y + 97.3, z + 2.8), arm, 0.39, palette.iron)
        box(model, "Cabeça do comunicador", arm.X, arm.Y, arm.Z, 1.45, 2.45, 1.25, palette.ledge)
        box(model, "Indicador do comunicador", arm.X, arm.Y + 1.16, arm.Z + 0.57, 1.43, 0.15, 0.27,
            palette.cyan, neon)
        mast(model, x + 4.4, y + 97.3, z - 2.3, 11.2, palette.ice)
        mast(model, x - 4.5, y + 92, z - 3, 6.9, palette.rose)
        sign(model, "07", x - 0.5, y + 35.5, z + 11.01, 1.02, palette.cyan)
    end

    do
        local model = group(towers, "Estação das Comportas")
        local x, z, y = 76, -54, 3.2
        local shell = rgb(54, 40, 62)
        body(model, "Galeria pública", x, z, y, 22, 8.1, 19, palette.iron)
        box(model, "Marquise", x, y + 8.2, z + 8.7, 22.6, 0.7, 5.12, palette.ledge)
        body(model, "Casco da estação", x, z, y + 8.4, 20.1, 29.2, 17.5, shell)
        body(model, "Ala de controle", x + 3, z - 2, y + 37.6, 13.3, 15.8, 12.9, rgb(61, 45, 65))
        body(model, "Câmara de inspeção", x + 5, z - 3.4, y + 53.4, 6.3, 4.2, 8, shell)
        roof(model, x + 3, y + 53.4, z - 2, 13.3, 12.9, palette.steel)
        roof(model, x, y + 37.6, z, 20.1, 17.5, palette.ledge)
        windows(model, x, z + 8.75, y + 9.4, 16.5, 26.4, 7, 4, palette.rose, 0.68, 0.7)
        windows(model, x + 3, z + 4.46, y + 38.25, 11.4, 14.45, 4, 5, palette.amber, 0.69, 0.64)
        sideWindows(model, x - 10.08, z, y + 10.1, 11.9, 25.8, 7, palette.rose)
        for _, floor in {12.2, 20.5, 28.8} do
            balcony(model, x - 1.0, y + floor, z + 8.75, 16.4, palette.rose)
        end
        local facade = z + 9.03
        tube(model, "Letreiro de estação", Vector3.new(x - 9.10, y + 8.62, facade),
            Vector3.new(x - 9.10, y + 35.91, facade), 0.31, palette.rose)
        tube(model, "Letreiro de estação", Vector3.new(x - 8.95, y + 35.91, facade),
            Vector3.new(x + 8.40, y + 35.91, facade), 0.26, palette.rose)
        sign(model, "41", x + 7.55, y + 21.6, facade + 0.14, 0.63, palette.rose)
        for bay = -2, 2 do
            front(model, "Baia da estação", x + bay * 4.0, y + 3.7, z + 9.51, 2.7, 4.6, glow(palette.rose, 0.25), neon)
            box(model, "Lâmpada da marquise", x + bay * 4.0, y + 7.80, z + 10.75, 3.33, 0.11, 0.42,
                glow(palette.rose, 0.84), neon)
        end
        fan(model, x - 5.8, y + 38.32, z + 3.15, 4)
        mast(model, x + 4.4, y + 57.6, z - 3.1, 7.0, palette.tail)
    end

    do
        local model = group(towers, "Arquivo de Vidro")
        local x, z, y = 112, -131, 3.2
        local shell = rgb(45, 36, 66)
        body(model, "Base do arquivo", x + 0.3, z, y, 33.2, 13, 22.3, palette.iron)
        roof(model, x + 0.3, y + 13, z, 33.2, 22.3, palette.ledge)
        for _, wing in {{-8.5, 84, palette.rose}, {8.7, 96, palette.violet}} do
            local center, height, accent = x + wing[1], wing[2], wing[3]
            local base = y + 13
            body(model, "Lâmina habitada", center, z, base, 12.3, height, 15.7, shell)
            body(model, "Núcleo recuado", center + 0.7, z - 1.4, base + height - 12.5, 8.2, 15.7, 14.5,
                rgb(56, 43, 74))
            body(model, "Painel de fachada", center + 1.55, z + 8.14, base + 4.2, 4.01, height - 7.3, 0.63,
                rgb(65, 43, 77))
            windows(model, center - 2.6, z + 7.85, base + 2.13, 5.85, height - 6.25, 18, 2, accent, 0.66, 0.61)
            sideWindows(model, center - 6.18, z - 1.5, base + 3, 10.8, height - 8.5, 13, palette.violet)
            tube(model, "Guia de recolha", Vector3.new(center + 2.95, base + 12, z + 8.47),
                Vector3.new(center + 2.95, base + height - 2.05, z + 8.47), 0.21, accent)
            for yOffset = 15, height - 10, 14 do
                front(model, "Emenda dos módulos", center, base + yOffset, z + 8.49, 12.3, 0.22, palette.steel)
            end
            roof(model, center, base + height, z, 12.3, 15.7, palette.ledge)
            mast(model, center + 1.1, base + height + 3.2, z - 1.5, 7.8, palette.tail)
        end
        box(model, "Ponte suspensa", x, y + 57.1, z - 0.15, 8.41, 4.21, 8.2, palette.iron)
        front(model, "Galeria panorâmica", x, y + 57.35, z + 3.95, 8.38, 2.22, glow(palette.rose, 0.49), neon)
        for vertical = -3, 3 do
            front(model, "Esquadria em aço", x + vertical * 1.13, y + 57.35, z + 4.17, 0.19, 2.31, palette.iron)
        end
        box(model, "Ponte suspensa superior", x, y + 74.44, z - 1.9, 8.39, 3.36, 5.8, palette.ledge)
        front(model, "Galeria panorâmica superior", x, y + 74.58, z + 1, 8.32, 1.45, glow(palette.violet, 0.69), neon)
    end

    do
        local model = group(towers, "Comando do Dique")
        local x, z, y = 14, -139, 3.2
        local shell = rgb(48, 39, 64)
        body(model, "Câmara de inundação", x, z, y, 24.2, 19.1, 22.1, palette.iron)
        body(model, "Torre de comando", x, z - 1.4, y + 19.1, 21.3, 46.2, 19.3, shell)
        body(model, "Controle superior", x + 4.2, z - 1.8, y + 65.3, 9.2, 7.5, 12.9, palette.iron)
        roof(model, x, y + 65.3, z - 1.4, 21.3, 19.3, palette.ledge)
        roof(model, x + 4.2, y + 72.8, z - 1.8, 9.2, 12.9, palette.steel)
        windows(model, x, z + 8.25, y + 20.1, 17, 43.2, 10, 4, palette.violet, 0.49, 0.61)
        sideWindows(model, x - 10.67, z - 1.2, y + 21, 14.5, 40.2, 8, palette.amber)
        for _, offset in {-8.9, 8.9} do
            local start = Vector3.new(x + offset, y + 4.9, z + 11.16)
            local corner = Vector3.new(x + offset, y + 45.1, z + 11.16)
            local endX = x + offset * 0.67
            tube(model, "Sinal do dique", start, corner, 0.31, palette.rose)
            tube(model, "Sinal do dique", corner, Vector3.new(endX, y + 51.7, z + 11.16), 0.31, palette.rose)
            body(model, "Viga do dique", x + offset, z + 9.17, y + 0.5, 1.64, 46.1, 3.49, palette.ledge)
        end
        tube(model, "Sinal do dique", Vector3.new(x - 5.97, y + 51.7, z + 11.16),
            Vector3.new(x + 5.97, y + 51.7, z + 11.16), 0.31, palette.rose)
        sign(model, "19", x + 0.25, y + 27.2, z + 11.11, 0.83, palette.rose)
        fan(model, x - 4.7, y + 65.98, z + 0.85, 4.12)
        mast(model, x + 6.41, y + 73.53, z - 0.6, 9.5, palette.tail)
    end

    do
        local model = group(towers, "Poço das Turbinas")
        local x, z, y = -34, -94, 3.2
        local shell = rgb(38, 43, 66)
        body(model, "Subestação", x, z, y, 20, 45.8, 21.5, shell)
        body(model, "Volume recuado", x - 2.1, z - 1.5, y + 45.8, 13.1, 23.1, 15.3, palette.iron)
        roof(model, x, y + 45.8, z, 20, 21.5, palette.ledge)
        roof(model, x - 2.1, y + 68.9, z - 1.5, 13.1, 15.3, palette.ledge)
        windows(model, x + 1.0, z + 10.75, y + 2.3, 16.4, 40.8, 11, 4, palette.ice, 0.42, 0.51)
        windows(model, x - 2.1, z + 6.15, y + 46.5, 10.6, 21.2, 6, 3, palette.cyan, 0.63, 0.49)
        sideWindows(model, x - 10.03, z - 1.3, y + 5.1, 16, 38.2, 8, palette.violet)
        for pipe = 1, 3 do
            local px = x - 9.7 + (pipe - 1) * 1.21
            local top = y + 26 + pipe * 9
            link(model, "Duto de pressão", Vector3.new(px, y + 3.8, z + 11.08),
                Vector3.new(px, top, z + 11.08), 0.57, palette.steel, nil, true)
            link(model, "Cotovelo", Vector3.new(px, top, z + 11.08),
                Vector3.new(px + 1.2, top + 0.7, z + 9.93), 0.57, palette.steel, nil, true)
        end
        for floor = 0, 3 do
            local start = Vector3.new(x + 0.3, y + 5.8 + floor * 9.8, z + 11.03)
            local finish = Vector3.new(x + 8.65, y + 14.45 + floor * 9.8, z + 11.03)
            link(model, "Travamento externo", start, finish, 0.42, palette.steel)
        end
        mast(model, x - 4.1, y + 69.6, z - 0.8, 8.27, glow(palette.cyan, 0.67))
    end

    do
        local model = group(towers, "Destilaria do Vento")
        local x, z, y = -74, -127, 3.2
        body(model, "Oficina industrial", x, z, y, 31, 28.1, 29.2, rgb(43, 39, 59))
        roof(model, x, y + 28.1, z, 31, 29.2, palette.ledge)
        windows(model, x, z + 14.6, y + 4.2, 26.9, 20.5, 5, 6, palette.amber, 0.49, 0.52)
        for unit, height in {35, 47, 28} do
            local cx = x + (unit - 2) * 9.4
            local cz = z - unit * 2.7
            local diameter = 7.45
            cylinder(model, "Coluna de destilação", cx, y + 28.8 + height / 2, cz, diameter, height,
                rgb(50 + unit * 3, 42 + unit, 59 + unit * 3))
            for tier = 1, 4 do
                cylinder(model, "Anel de reforço", cx, y + 29 + height * tier / 4, cz, diameter + 0.37, 0.52, palette.steel)
            end
            local capY = y + 28.8 + height
            cylinder(model, "Chaminé", cx, capY + 2.1, cz, 2.46, 4.2, palette.iron)
            cylinder(model, "Sinal de chaminé", cx, capY + 4.16, cz, 2.63, 0.26, glow(palette.amber, 0.66), neon)
            link(model, "Duto de vapor", Vector3.new(cx, y + 32, cz + 4.05), Vector3.new(cx, capY - 1.25, cz + 4.05),
                0.53, palette.copper, nil, true)
        end
        fan(model, x + 9.3, y + 28.85, z + 7.0, 6.1)
    end

    do
        local model = group(towers, "Degraus da Vigia")
        local x, z, y = 145, -105, 3.2
        local shell = rgb(50, 41, 64)
        body(model, "Corpo escalonado", x, z, y, 23.2, 33.1, 20.2, palette.iron)
        body(model, "Corpo escalonado", x + 2.9, z - 1.1, y + 33.1, 19.1, 22.2, 16.9, shell)
        body(model, "Corpo escalonado", x + 5.0, z - 3.0, y + 55.3, 13.0, 22.2, 14.1, shell)
        roof(model, x, y + 33.1, z, 23.2, 20.2, palette.ledge)
        roof(model, x + 2.9, y + 55.3, z - 1.1, 19.1, 16.9, palette.ledge)
        roof(model, x + 5.0, y + 77.5, z - 3.0, 13, 14.1, palette.steel)
        windows(model, x, z + 10.1, y + 3.5, 20.2, 28.3, 7, 5, palette.amber, 0.65, 0.73)
        windows(model, x + 2.9, z + 7.35, y + 34.35, 16, 19.8, 5, 4, palette.rose, 0.58, 0.75)
        windows(model, x + 5, z + 4.05, y + 56.35, 10.3, 19.8, 5, 3, palette.rose, 0.54, 0.65)
        sideWindows(model, x - 11.63, z, y + 4, 14.35, 28.4, 7, palette.amber)
        for _, stripe in {{33.5, 0, 23, 10.28}, {55.7, 2.9, 19, 7.57}, {77.9, 5, 13.2, 4.30}} do
            front(model, "Linha de terraço", x + stripe[2], y + stripe[1], z + stripe[4], stripe[3], 0.21,
                glow(palette.rose, 0.74), neon)
        end
        mast(model, x + 5.9, y + 78.25, z - 2.7, 10.1, palette.tail)
    end

    do
        local model = group(towers, "Varandas do Ramal")
        local x, z, y = 113, -68, 3.2
        body(model, "Estrutura do hotel", x, z, y, 21.6, 44.2, 17.4, rgb(49, 40, 56))
        roof(model, x, y + 44.2, z, 21.6, 17.4, palette.ledge)
        body(model, "Casa de máquinas", x + 4.1, z - 2.5, y + 44.88, 7.31, 3.9, 5.42, palette.iron)
        windows(model, x, z + 8.7, y + 4.1, 18.3, 38.7, 9, 6, palette.amber, 0.69, 0.75)
        sideWindows(model, x - 10.84, z - 0.6, y + 4.0, 13.95, 38.5, 8, palette.amber)
        for step = 0, 7 do
            local shift = if step % 2 == 0 then -0.86 else 0.88
            balcony(model, x + shift, y + 4.5 + 4.3 * step, z + 8.7, 18.3, palette.amber)
        end
        fan(model, x - 4.5, y + 44.88, z + 3.2, 5.7)
        mast(model, x + 6.0, y + 48.78, z - 2.5, 5.2, palette.tail)
    end

    local background = group(city, "Bairros ao fundo")
    local distantBlocks = {
        {-150, -151, 20, 62, 20}, {-125, -131, 17, 51, 17}, {-101, -164, 24, 67, 20},
        {-55, -170, 18, 79, 18}, {-25, -167, 22, 65, 18}, {-7, -184, 16, 92, 21},
        {20, -189, 20, 112, 20}, {44, -181, 17, 72, 16}, {75, -161, 21, 88, 18},
        {95, -192, 15, 106, 19}, {140, -171, 21, 87, 24}, {173, -160, 23, 72, 20},
        {196, -130, 19, 50, 20}, {215, -157, 20, 64, 20},
        {-168, -222, 22, 91, 24}, {-130, -225, 19, 75, 20}, {-104, -213, 18, 83, 17},
        {-75, -241, 28, 109, 21}, {-46, -237, 17, 88, 17}, {-18, -243, 21, 64, 21},
        {21, -252, 17, 78, 16}, {49, -222, 26, 101, 24}, {81, -248, 16, 118, 17},
        {119, -235, 24, 83, 24}, {150, -240, 19, 116, 21}, {188, -231, 23, 107, 18},
        {215, -218, 21, 74, 17}, {243, -245, 18, 103, 20},
        {-111, -296, 24, 99, 22}, {-55, -307, 18, 114, 20}, {-2, -305, 29, 102, 25},
        {68, -285, 24, 91, 24}, {112, -292, 22, 118, 21}, {159, -295, 21, 90, 23},
    }
    for index, spec in distantBlocks do
        local x, z, width, height, depth = table.unpack(spec)
        local model = group(background, "Quadra " .. index)
        local distance = math.clamp((-z - 100) / 255, 0, 1)
        local color = rgb(40, 37, 62):Lerp(rgb(69, 49, 80), distance * 0.74)
        body(model, "Estrutura", x, z, 3, width, height, depth, color)
        body(model, "Cobertura", x + width * 0.09, z - depth * 0.10, height + 3, width * 0.70, range(3.9, 11.7),
            depth * 0.73, color:Lerp(palette.iron, 0.13))
        local accent = if index % 5 == 0 then palette.amber elseif index % 3 == 0 then palette.cyan else palette.violet
        local facade = z + depth * 0.5
        for floor = 1, if distance < 0.54 then 8 else 5 do
            local py = 6 + floor * height * 0.094
            local px = x + (if floor % 3 == 0 then 0.17 else -0.13) * width
            local pw = width * range(0.27, 0.62)
            front(model, "Janelas distantes", px, py, facade, pw, range(0.32, 0.80),
                glow(accent, (1 - distance * 0.37) * range(0.24, 0.47)), neon)
        end
        if index % 3 == 0 then
            local px = x - width * 0.40
            front(model, "Coluna estrutural", px, 4 + height * 0.55, facade, 0.51, height * 0.81,
                color:Lerp(palette.steel, 0.28))
            mast(model, x + width * 0.16, height + 10.6, z - depth * 0.08, range(5.5, 10.2), glow(accent, 0.57))
        end
        if index % 4 == 2 then
            local top = height + 6.5
            local capX = x - width * 0.24
            local capZ = z - depth * 0.07
            body(model, "Aleta de cobertura", capX, capZ, top, width * 0.15, height * 0.13, depth * 0.55, color)
            front(model, "Faixa de balizamento", capX, top + height * 0.126, capZ + depth * 0.275,
                width * 0.135, 0.37, glow(accent, 0.30), neon)
        end
    end

    local function cameraAt(seconds: number): CFrame
        local phase = (seconds % 68) * (2 * math.pi / 68)
        -- A shallow closed path outside the harbor keeps the menu area available.
        local eye = Vector3.new(
            -39 + 16 * math.sin(phase),
            57 + 3.3 * math.sin(phase + 0.43),
            111 + 5.5 * math.cos(phase)
        )
        local focus = Vector3.new(
            12 + 9.4 * math.sin(phase - 0.3),
            43 + 2.9 * math.sin(phase + 0.62),
            -114
        )
        return CFrame.lookAt(eye, focus)
    end

    city.Parent = parent
    return city, cameraAt
end
