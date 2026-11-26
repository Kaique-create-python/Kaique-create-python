local PublicSpace = {}

function PublicSpace.new(ctx)
    local rgb, box, group = ctx.rgb, ctx.box, ctx.group
    local ink = rgb(31, 38, 49)
    local metal = rgb(73, 80, 93)
    local gray = rgb(90, 95, 110)
    local blue = rgb(80, 206, 229)
    local pink = rgb(248, 68, 157)
    local amber = rgb(253, 192, 128)
    local benchWood = rgb(100, 69, 49)
    local painted = {collision = false, shadow = false}
    local diffuse = {collision = false, transparency = 0.38, reflectance = 0.16}
    local api = {}

    local function bench(parent, x, z, angle)
        local frame = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(angle), 0)
        for support = -1, 1, 2 do
            box(parent, "Pé de banco", x, 0.96, z, 0.57, 1.85, 1.6, metal, "steel",
                {cframe = frame * CFrame.new(support * 2.2, 0.96, 0)})
            box(parent, "Braço de banco", x, 2.55, z, 0.28, 0.20, 1.83, ink, "metal",
                {cframe = frame * CFrame.new(support * 2.24, 2.55, -0.02), collision = false})
        end
        for i = -1, 1 do
            box(parent, "Ripa do assento", x, 1.92, z, 5.6, 0.23, 0.53, benchWood, "wood",
                {cframe = frame * CFrame.new(0, 1.92, i * 0.57)})
        end
        for i = 1, 2 do
            box(parent, "Ripa do encosto", x, 2.18, z, 5.6, 0.48, 0.18, benchWood, "wood",
                {cframe = frame * CFrame.new(0, 2.20 + i * 0.49, 0.90)})
        end
    end

    local function tree(parent, x, z, scale, seed)
        local model = group(parent, "Floreira e árvore de rua")
        local rng = Random.new(seed)
        local trunk = 9.2 * scale
        box(model, "Mureta da floreira", x, 0.50, z, 6.8 * scale, 0.98, 6.8 * scale, gray, "cement")
        box(model, "Borda da floreira", x, 1.02, z, 7.12 * scale, 0.24, 7.12 * scale, ink, "cement")
        box(model, "Canteiro", x, 1.15, z, 5.9 * scale, 0.20, 5.9 * scale, rgb(46, 61, 58), "foliage")
        box(model, "Tronco", x, 1.25 + trunk / 2, z, trunk, 0.78 * scale, 0.76 * scale,
            rgb(65, 56, 48), "wood", {shape = "Cylinder", roll = 90})
        for index = 1, 7 do
            local longitude = (index - 1) * math.pi * 2 / 7
            local reach = rng:NextNumber(2.0, 4.1) * scale
            local px = x + math.cos(longitude) * reach
            local pz = z + math.sin(longitude) * reach
            local py = 1.1 + trunk + rng:NextNumber(-0.7, 2.6) * scale
            ctx.beam(model, "Ramo", Vector3.new(x, trunk * 0.73, z), Vector3.new(px, py, pz), 0.25, 0.23,
                rgb(74, 59, 49), "wood", painted)
            local size = rng:NextNumber(4.0, 5.7) * scale
            box(model, "Copa", px, py + 1.02, pz, size, size * 0.81, size, rgb(48 + index, 72 + index * 3, 58 + index * 2),
                "foliage", {shape = "Ball", collision = false})
        end
        box(model, "Copa alta", x, 2.3 + trunk + scale * 1.8, z, 6.0 * scale, 5.8 * scale, 5.5 * scale,
            rgb(55, 94, 74), "foliage", {shape = "Ball", collision = false})
        return model
    end

    local function vending(parent, x, z, mirror)
        local faceZ = z - mirror * 0.72
        box(parent, "Armário de bebidas", x, 3.06, z, 3.35, 5.87, 1.49, ink, "steel")
        box(parent, "Visor de bebidas", x - 0.31, 3.75, faceZ, 2.08, 3.0, 0.09, rgb(50, 88, 107), "glass", diffuse)
        for row = 1, 3 do
            box(parent, "Prateleira de bebidas", x - 0.31, 2.58 + row * 0.64, faceZ - mirror * 0.062, 2.02, 0.07, 0.12,
                metal, "metal", painted)
            for column = 1, 4 do
                local colors = {pink, amber, blue, rgb(113, 180, 104)}
                box(parent, "Lata na prateleira", x - 1.15 + column * 0.34, 2.79 + row * 0.64, faceZ - mirror * 0.074,
                    0.23, 0.36, 0.06, colors[(row + column) % 4 + 1], "paint", painted)
            end
        end
        box(parent, "Recuo de retirada", x - 0.16, 1.18, faceZ - mirror * 0.068, 2.22, 0.57, 0.08, rgb(21, 24, 34), "rubber", painted)
        box(parent, "Terminal de pagamento", x + 1.13, 3.42, faceZ - mirror * 0.09, 0.46, 0.76, 0.16, rgb(105, 190, 196),
            "neon", painted)
    end

    local function hydrant(parent, x, z)
        local paint = rgb(185, 83, 70)
        box(parent, "Corpo do hidrante", x, 1.31, z, 2.48, 0.60, 0.60, paint, "metal", {shape = "Cylinder", roll = 90})
        box(parent, "Flange do hidrante", x, 0.28, z, 0.30, 1.10, 1.09, ink, "metal", {shape = "Cylinder", roll = 90})
        box(parent, "Tampa do hidrante", x, 2.50, z, 0.36, 0.75, 0.74, paint, "metal", {shape = "Cylinder", roll = 90})
        for _, sign in {-1, 1} do
            box(parent, "Válvula lateral", x + sign * 0.36, 1.3, z, 0.44, 0.45, 0.45, paint, "metal", {shape = "Cylinder"})
            box(parent, "Tampa da válvula", x + sign * 0.59, 1.3, z, 0.18, 0.50, 0.50, metal, "metal", {shape = "Cylinder"})
        end
    end

    function api.furniture(parent, x, z, seed, variant)
        local sidewalk = group(parent, "Mobiliário de rua")
        local rng = Random.new(seed)
        local which = if rng:NextNumber() > 0.5 then 1 else -1
        local plotX = x - 64 + rng:NextNumber(-12, 12)
        local verge = z + which * 99
        hydrant(sidewalk, plotX, verge)
        if variant % 3 == 0 then
            local cab = x + 54
            box(sidewalk, "Armário de fibra da rua", cab, 2.29, verge, 3.15, 4.42, 1.23, metal, "steel")
            box(sidewalk, "Moldura do armário", cab, 2.36, verge + which * 0.65, 2.79, 4.01, 0.19, gray, "metal", painted)
            box(sidewalk, "Base de concreto", cab, 0.20, verge, 3.8, 0.39, 1.82, gray, "cement")
            box(sidewalk, "Indicador de rede", cab + 0.91, 3.5, verge + which * 0.78, 0.21, 0.16, 0.055, blue, "neon", painted)
            for i = 1, 5 do
                box(sidewalk, "Veneziana do armário", cab, 0.97 + i * 0.23, verge + which * 0.79, 1.85, 0.085, 0.08,
                    ink, "metal", painted)
            end
        elseif variant % 3 == 1 then
            bench(sidewalk, x + 45, verge + which * 0.55, if which > 0 then 0 else 180)
        else
            for mark = 1, 3 do
                box(sidewalk, "Pilarete de calçada", x + 52 + mark * 3.6, 0.94, verge + which * 0.76, 0.45, 1.80, 0.45, metal,
                    "steel")
                box(sidewalk, "Faixa retrorrefletiva", x + 52 + mark * 3.6, 1.44, verge + which * 0.76, 0.47, 0.17, 0.47,
                    rgb(179, 152, 82), "paint", painted)
            end
        end
    end

    local function canopy(parent, x, z, width, depth, accent)
        local covering = group(parent, "Marquise modular")
        box(covering, "Capa de zinco", x, 11.42, z, width, 0.57, depth, metal, "steel")
        box(covering, "Lábio de acabamento", x, 11.12, z - depth / 2 + 0.05, width, 0.55, 0.33, ink, "metal")
        for side = -1, 1, 2 do
            for across = -1, 1, 2 do
                box(covering, "Pilar da marquise", x + side * (width / 2 - 2.0), 5.55, z + across * (depth / 2 - 1.4),
                    0.67, 11.0, 0.68, ink, "steel")
            end
        end
        for step = -width / 2 + 3, width / 2 - 2, 5 do
            box(covering, "Nervura do forro", x + step, 10.96, z, 0.34, 0.36, depth - 0.5, ink, "steel", painted)
        end
        local light = box(covering, "Fita da marquise", x, 10.71, z, width * 0.75, 0.17, 0.25, accent, "neon", painted)
        ctx.lamp(light, accent, 25, 1.15, "Bottom")
    end

    local function skylight(parent, x, z, label)
        local model = group(parent, "Pavilhão do Dique")
        local floor = rgb(104, 103, 117)
        box(model, "Piso do pavilhão", x, 0.15, z, 54, 0.34, 23, floor, "tile")
        box(model, "Parede de tijolo escuro", x, 4.8, z + 10.75, 52.7, 9.3, 0.65, rgb(74, 57, 64), "brick")
        box(model, "Vão superior de oficina", x, 9.28, z - 10.7, 52.7, 0.82, 0.75, metal, "steel")
        for index = -2, 2 do
            box(model, "Moldura da vitrine", x + index * 10.5, 4.71, z - 10.75, 0.63, 9.2, 0.61, metal, "steel")
        end
        box(model, "Vidro lateral oeste", x - 26.1, 4.61, z, 0.53, 8.98, 21.0, rgb(82, 106, 131), "glass",
            {transparency = 0.27})
        box(model, "Vidro lateral leste", x + 26.1, 4.61, z, 0.53, 8.98, 21.0, rgb(82, 106, 131), "glass",
            {transparency = 0.27})
        canopy(model, x, z, 54, 26, amber)
        for index = -1, 1 do
            local px = x + index * 13.75
            box(model, "Mesa de praça", px, 3.56, z + 1.7, 5.9, 0.42, 3.48, benchWood, "wood")
            box(model, "Pé da mesa", px, 1.7, z + 1.7, 0.72, 3.39, 0.70, metal, "steel")
            bench(model, px, z + 5.05, 0)
        end
        if label then
            local sign = box(model, "Frente do pavilhão", x, 10.25, z - 12.0, 25.4, 1.6, 0.31, ink, "metal", painted)
            ctx.sign(sign, "Front", label, amber)
        end
        return model
    end

    local function rainGarden(parent, x, z, length, seed, accent)
        local garden = group(parent, "Jardim drenante")
        local rng = Random.new(seed)
        box(garden, "Moldura rebaixada", x, 0.33, z, length + 0.6, 0.62, 8.3, gray, "stone")
        box(garden, "Canal de irrigação", x, 0.66, z, length - 0.7, 0.12, 7.15, rgb(37, 57, 69), "water",
            {collision = false, transparency = 0.24, reflectance = 0.36})
        for _, side in {-1, 1} do
            box(garden, "Borda drenante", x, 0.74, z + side * 3.83, length, 0.23, 0.55, metal, "steel")
            box(garden, "Luz da borda", x, 0.68, z + side * 3.49, length - 1.8, 0.09, 0.12, accent, "neon", painted)
        end
        for p = -length / 2 + 3.1, length / 2 - 3, 5.25 do
            local px = x + p
            local pz = z + rng:NextNumber(-1.67, 1.67)
            box(garden, "Leito de pedras", px, 0.72, pz, 2.92, 0.32, 2.67, ink, "stone", painted)
            for leaf = 1, 3 do
                local height = rng:NextNumber(0.96, 2.96)
                box(garden, "Folha ornamental", px + (leaf - 2) * 0.37, 0.88 + height * 0.36, pz + (leaf - 2) * 0.29,
                    0.73, height, 0.65, rgb(50 + leaf * 7, 85 + leaf * 9, 70 + leaf * 4), "foliage",
                    {shape = "Ball", collision = false, pitch = leaf * 14 - 26, roll = leaf * 26 - 49})
            end
        end
    end

    function api.plaza(parent, x, z, seed, kind)
        local main = group(parent, if kind == "spawn" then "Praça do Dique" else "Praça de bairro")
        local ground = rgb(90, 91, 110)
        box(main, "Esplanada em pavers", x, -0.096, z, 175, 0.26, 173, ground, "sidewalk", {shadow = false})
        if kind == "spawn" then
            skylight(main, x - 22, z - 38, "PRAÇA DO DIQUE")
            canopy(main, x - 39, z + 37, 37, 12, pink)
            bench(main, x - 48, z + 36, 0)
            bench(main, x - 32, z + 36, 0)
            vending(main, x - 57.5, z - 30, -1)
            rainGarden(main, x + 37, z - 29, 36, seed + 17, pink)
            rainGarden(main, x + 22, z + 57, 43, seed + 21, blue)
        elseif kind == "station" then
            for _, direction in {-1, 1} do
                canopy(main, x + direction * 42, z - 28, 22, 13.7, blue)
                bench(main, x + direction * 42, z - 27.05, 0)
                vending(main, x + direction * 36, z - 28, 1)
            end
        elseif kind == "levee" then
            local side = math.sign(x)
            local deckX = x - side * 51
            box(main, "Terraço do canal", deckX, 0.36, z + 15.4, 45, 0.73, 63, rgb(78, 86, 104), "sidewalk")
            box(main, "Rebaixo de entrada", deckX + side * 24.0, 0.16, z + 15.4, 3.3, 0.36, 24, gray, "sidewalk")
            bench(main, deckX, z + 33, if side < 0 then 270 else 90)
            bench(main, deckX, z - 2, if side < 0 then 270 else 90)
            canopy(main, x + side * 29, z - 24, 54, 20, blue)
            rainGarden(main, x + side * 24, z + 47, 54, seed + 17, blue)
            rainGarden(main, x + side * 25, z - 58, 45, seed + 31, pink)
        else
            skylight(main, x + 26, z - 32)
            canopy(main, x - 48, z + 29, 34, 15, amber)
            bench(main, x - 48, z + 29, 0)
            rainGarden(main, x + 25, z + 35, 54, seed + 31, blue)
        end
        local positions = if kind == "spawn" then {{-49,-6}, {29,-50}, {43,6}, {-50,68}, {39,62}}
            else {{-66,-54}, {62,-53}, {-65,57}, {65,51}}
        for index, position in positions do
            tree(main, x + position[1], z + position[2], if index % 2 == 0 then 1.06 else 0.85, seed + index)
        end
        return main
    end

    return api
end

return PublicSpace
