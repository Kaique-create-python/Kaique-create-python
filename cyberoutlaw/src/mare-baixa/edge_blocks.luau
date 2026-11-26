-- Quadras de baixa altura na transição da cidade com a encosta, a orla e o anel de serviço.
local EdgeBlocks = {}
local rgb, v = Color3.fromRGB, Vector3.new
local groundY = 0.04
local finish = {collision = false, shadow = false}
local detail = {collision = false}

local function site(ctx, parent, x, z, name, surface, material, mirrored)
    local root = ctx.group(parent, name)
    local origin = v(x, 0, z)
    local side = if mirrored then -1 else 1
    local function part(owner, label, dx, y, dz, width, height, depth, color, key, options)
        if mirrored and options and (options.yaw or options.roll) then
            options = table.clone(options)
            options.yaw = -(options.yaw or 0)
            options.roll = -(options.roll or 0)
        end
        return ctx.box(owner, label, x + side * dx, y, z + dz, width, height, depth, color, key, options)
    end
    part(root, "Piso contínuo da quadra", 0, groundY - 0.19, 0, 182, 0.38, 182, surface, material, {shadow = false})
    local function beam(owner, label, a, b, width, depth, color, key, options)
        local first, last = origin + v(side * a.X, a.Y, a.Z), origin + v(side * b.X, b.Y, b.Z)
        return ctx.beam(owner, label, first, last, width, depth, color, key, options)
    end
    return root, part, beam
end

local function floorMark(part, owner, name, x, z, width, depth, color, material, yaw, lift)
    part(owner, name, x, groundY + 0.018 + (lift or 0), z, width, 0.027, depth, color, material,
        {collision = false, shadow = false, yaw = yaw})
end

local function roundPost(part, owner, name, x, start, z, height, diameter, color, material)
    return part(owner, name, x, start + height / 2, z, height, diameter, diameter, color, material,
        {shape = "Cylinder", roll = 90})
end

local function roofPanel(part, owner, name, x, width, z0, y0, z1, y1, thickness, color, material)
    local run, rise = z1 - z0, y1 - y0
    part(owner, name, x, (y0 + y1) / 2, (z0 + z1) / 2, width, thickness, math.sqrt(run * run + rise * rise),
        color, material, {pitch = -math.deg(math.atan2(rise, run))})
end

local function soffitLight(ctx, part, owner, name, x, y, z, width, housing, tint, range)
    part(owner, "Carcaça de " .. name, x, y, z, width + 0.35, 0.39, 0.66, housing, "metal", detail)
    local lens = part(owner, name, x, y - 0.233, z, width, 0.09, 0.37, tint, "neon", finish)
    ctx.lamp(lens, tint, range, 1.24, "Bottom")
end

local function leafyTree(part, beam, owner, x, base, z, scale, rng)
    local trunk, leaf = rgb(78, 62, 49), rgb(67, 110, 71)
    roundPost(part, owner, "Tronco da árvore", x, base, z, 8.1 * scale, 0.59 * scale, trunk, "wood")
    for i = 1, 4 do
        local angle = i * math.pi / 2 + rng:NextNumber(-0.32, 0.32)
        local branchX, branchZ = x + math.cos(angle) * 2.7 * scale, z + math.sin(angle) * 2.7 * scale
        local branchY = base + rng:NextNumber(6.9, 8.9) * scale
        beam(owner, "Ramo do canteiro", v(x, base + 5.4 * scale, z), v(branchX, branchY, branchZ),
            0.25 * scale, 0.28 * scale, trunk, "wood", detail)
        part(owner, "Copa do jardim", branchX, branchY + 0.82 * scale, branchZ,
            5.8 * scale, 3.5 * scale, 5.2 * scale, leaf:Lerp(rgb(104, 134, 79), 0.11 * i), "foliage",
            {shape = "Ball", collision = false, yaw = math.deg(angle)})
    end
    part(owner, "Copa alta do jardim", x, base + 10.3 * scale, z, 6.6 * scale, 4.2 * scale, 6.1 * scale,
        leaf, "foliage", {shape = "Ball", collision = false})
end

local function altos(ctx, parent, x, z, seed)
    local cream, lime = rgb(185, 182, 160), rgb(214, 205, 182)
    local pebble, soil = rgb(112, 108, 94), rgb(60, 67, 51)
    local leaf, wood = rgb(73, 105, 67), rgb(129, 91, 62)
    local bronze, ink, glass = rgb(128, 112, 77), rgb(40, 52, 54), rgb(42, 74, 80)
    local light = rgb(255, 220, 165)
    local rng = ctx.random(seed)
    local root, part, beam = site(ctx, parent, x, z, "Jardins da Encosta", rgb(128, 129, 112), "sidewalk", seed % 2 == 1)
    local garden = ctx.group(root, "Alameda e canteiros de chuva")

    floorMark(part, garden, "Piso claro da alameda", 0, 0, 17, 178, rgb(161, 158, 143), "sidewalk")
    floorMark(part, garden, "Travessia na entrada", 0, -63, 158, 11, rgb(150, 146, 129), "sidewalk", nil, 0.008)
    for z0 = -81, 83, 10 do
        part(garden, "Junta das placas do passeio", 0, groundY + 0.038, z0, 16.7, 0.021, 0.13, pebble, "cement", finish)
    end
    for _, side in {-1, 1} do
        for i = 1, 3 do
            local z0 = -71 + (i - 1) * 59
            part(garden, "Balizador de bronze", side * 9.6, 0.96, z0, 0.54, 1.84, 0.54, bronze, "metal")
            local tint = if i == 2 then rgb(227, 203, 165) else light
            local lens = part(garden, "Fenda opalina do balizador", side * 9.6, 1.59, z0, 0.57, 0.17, 0.57, tint, "neon", finish)
            if i ~= 3 then
                ctx.lamp(lens, tint, 10, 0.72)
            end
        end
    end

    local function terrace(owner, cx, cz, width, depth, base, height, seams)
        local faceZ = cz - depth / 2
        part(owner, "Contenção de concreto lavado", cx, base + height / 2, cz, width, height, depth, cream, "cement")
        part(owner, "Borda de calcário do terraço", cx, base + height + 0.14, cz, width + 0.48, 0.28, depth + 0.23,
            lime, "stone")
        for i = 1, seams do
            local dx = (i / (seams + 1) - 0.5) * width
            part(owner, "Junta na contenção", cx + dx, base + height / 2, faceZ - 0.019, 0.055, height - 0.12, 0.046,
                pebble, "cement", finish)
        end
    end

    local function stairs(owner, cx, zFront, base, top, width, steps, tread)
        for i = 1, steps do
            local rise = (top - base) * i / steps
            local z0 = zFront + tread * (i - 0.5)
            part(owner, "Degrau largo de pedra", cx, base + rise / 2, z0, width, rise, tread, cream, "cement")
            part(owner, "Borda antiderrapante", cx, base + rise + 0.023, z0 - tread * 0.38, width - 0.45, 0.031, 0.13,
                pebble, "stone", finish)
        end
    end

    local function planter(owner, cx, base, cz, width, depth, withTree)
        part(owner, "Banco de pedra do canteiro", cx, base + 0.46, cz, width, 0.92, depth, cream, "cement")
        part(owner, "Terra e forração do canteiro", cx, base + 0.98, cz, width - 0.56, 0.20, depth - 0.47, soil, "foliage", detail)
        for i = 1, 4 do
            local dx = (i / 5 - 0.5) * (width - 1)
            part(owner, "Maciço de folhagem", cx + dx, base + 1.38, cz + rng:NextNumber(-0.4, 0.4),
                width * 0.26, rng:NextNumber(0.95, 1.54), depth * 0.76, leaf:Lerp(soil, i * 0.08), "foliage",
                {shape = "Ball", collision = false})
        end
        if withTree then
            leafyTree(part, beam, owner, cx - width * 0.12, base + 1.02, cz, rng:NextNumber(0.78, 1.12), rng)
        end
    end

    local function villa(owner, cx, base, cz, width, depth, upper)
        local front, back = cz - depth / 2, cz + depth / 2
        local deck = base + 8.7
        part(owner, "Núcleo de serviço recuado", cx + width * 0.14, base + 4.3, back - 5.5, width * 0.48, 8.6, 11,
            cream, "cement")
        for _, dx in {-0.37, 0.36} do
            for _, dz in {-0.34, 0.30} do
                roundPost(part, owner, "Piloti de concreto", cx + width * dx, base, cz + depth * dz, 8.7, 1.75, lime, "cement")
            end
        end
        part(owner, "Laje em balanço", cx, deck + 0.48, cz, width, 0.96, depth, lime, "cement")
        part(owner, "Forro de madeira da varanda", cx, deck - 0.036, front + 3.12, width - 3.2, 0.09, 4.8, wood, "wood", finish)
        soffitLight(ctx, part, owner, "luminária sob a varanda", cx - width * 0.18, deck - 0.27, front + 2.7, 8, ink, light, 17)
        local sill = deck + 0.96
        local roomZ = cz + 2.5
        local roomD = depth - 9
        local roomFront = roomZ - roomD / 2
        local roomW = width - 7
        local roomH = 7.4
        part(owner, "Corpo envidraçado recuado", cx, sill + roomH / 2, roomZ, roomW, roomH, roomD, ink, "paint")
        for i = 1, 5 do
            local bay = roomW / 5
            local bx = cx + (i - 3) * bay
            local tint = if (i + seed) % 4 == 0 then rgb(152, 126, 87) else glass
            part(owner, "Vidro da sala de estar", bx, sill + 3.9, roomFront - 0.045, bay - 0.35, 6.5, 0.10,
                tint, "glass", {collision = false, reflectance = 0.14})
            part(owner, "Montante da esquadria", bx + bay / 2 - 0.08, sill + 3.9, roomFront - 0.13, 0.16, 6.62, 0.17,
                bronze, "metal", detail)
        end
        for _, side in {-1, 1} do
            for i = 1, 3 do
                part(owner, "Vidraça lateral", cx + side * (roomW / 2 + 0.054), sill + 4, roomFront + (i - 0.5) * roomD / 3,
                    0.12, 6.28, roomD / 3 - 0.30, if i == 2 then glass:Lerp(bronze, 0.33) else glass, "glass", detail)
            end
        end
        local railZ = front + 0.48
        part(owner, "Guarda-corpo de vidro fumê", cx, sill + 1.65, railZ, width - 2.7, 3.3, 0.19, glass,
            "glass", {transparency = 0.32, reflectance = 0.07})
        part(owner, "Capeamento de bronze", cx, sill + 3.34, railZ, width - 2.5, 0.18, 0.32, bronze, "metal", detail)
        for _, dx in {-0.35, -0.17, 0, 0.17, 0.35} do
            part(owner, "Apoio do guarda-corpo", cx + width * dx, sill + 1.7, railZ - 0.10, 0.14, 3.42, 0.31, bronze, "metal", detail)
        end
        part(owner, "Pala clara sobre o terraço", cx, sill + roomH + 0.43, cz, width + 2, 0.86, depth + 1.8, lime, "cement")
        part(owner, "Faixa de madeira do beiral", cx, sill + roomH - 0.043, front + 1.7, width, 0.096, 4.3, wood, "wood", detail)
        local screenX = cx + width * (if upper then 0.31 else -0.31)
        for i = 1, 7 do
            part(owner, "Brise vertical da varanda", screenX + (i - 4) * 0.39, sill + 3.66, roomFront - 0.83, 0.20, 7.32, 1.05,
                wood, "wood", detail)
        end
        if upper then
            local roof = sill + roomH + 0.86
            part(owner, "Pavilhão superior recuado", cx + 5, roof + 2.39, cz + 5.5, width * 0.60, 4.78, depth * 0.57, cream, "cement")
            part(owner, "Janela alta de canto", cx + 5, roof + 2.55, cz + 5.5 - depth * 0.285 - 0.06, width * 0.54, 3.06, 0.14,
                glass:Lerp(bronze, 0.35), "glass", detail)
            part(owner, "Cobertura fina do pavilhão", cx + 4, roof + 4.99, cz + 4.3, width * 0.64, 0.41, depth * 0.68,
                lime, "cement")
        end
    end

    local west = ctx.group(root, "Casa do terraço baixo")
    terrace(west, -47, -5, 64, 64, groundY, 1.9, 5)
    terrace(west, -48, 5, 59, 50, 2.22, 1.9, 4)
    stairs(west, -38, -44.5, groundY, 2.22, 13, 5, 1.5)
    stairs(west, -38, -27.5, 2.22, 4.4, 13, 5, 1.5)
    villa(west, -47, 4.4, 4.5, 45, 26, seed % 2 == 0)
    planter(west, -65, 2.22, -29, 17, 4, false)
    planter(west, -67, 4.4, -18, 15, 3, true)
    planter(west, -26, 4.4, 24, 11, 3.5, false)

    local east = ctx.group(root, "Casa do terraço alto")
    terrace(east, 47, 24, 64, 72, groundY, 2.13, 5)
    terrace(east, 48, 35, 60, 57, 2.45, 2.23, 5)
    terrace(east, 49, 45, 57, 44, 4.96, 2.72, 4)
    stairs(east, 42, -21, groundY, 2.45, 12.5, 6, 1.5)
    stairs(east, 42, -2.5, 2.45, 4.96, 12.5, 6, 1.5)
    stairs(east, 42, 13.4, 4.96, 7.96, 12.5, 6, 1.6)
    villa(east, 49, 7.96, 44, 46, 29, true)
    planter(east, 63, 2.45, -6, 16, 4, true)
    planter(east, 65, 4.96, 15, 17, 4.2, false)
    planter(east, 29, 7.96, 61, 13, 4, true)
    planter(garden, 63, groundY, -47, 27, 7.8, true)

    local pool = ctx.group(garden, "Espelho d'água do jardim")
    local poolX, poolZ = -52, -53.5
    part(pool, "Bacia de basalto polido", poolX, 0.35, poolZ, 25, 0.62, 12, pebble, "stone")
    part(pool, "Espelho de água raso", poolX, 0.68, poolZ, 23.9, 0.068, 10.95, rgb(57, 101, 100), "water",
        {collision = false, reflectance = 0.19, transparency = 0.11})
    for i = 1, 8 do
        part(pool, "Ondulação no espelho", poolX + rng:NextNumber(-10, 10), 0.724, poolZ + rng:NextNumber(-4.4, 4.4),
            rng:NextNumber(1.2, 5.5), 0.013, rng:NextNumber(0.08, 0.29), rgb(111, 154, 143), "glass", finish)
    end
end

local function palm(part, beam, owner, x, z, height, lean, rng)
    local stem = rgb(112, 99, 73)
    local top = v(x + lean, groundY + height, z + 1.4)
    local knot = v(x + lean * 0.33, groundY + height * 0.54, z + 0.6)
    beam(owner, "Estipe da palmeira", v(x, groundY, z), knot, 0.71, 0.67, stem, "wood")
    -- A seção estreita e o ângulo irregular mantêm a copa legível contra a cobertura.
    beam(owner, "Estipe inclinado", knot, top, 0.58, 0.55, stem, "wood")
    for i = 1, 7 do
        local angle = i * math.pi * 2 / 7
        local span = rng:NextNumber(4, 5.8)
        local dx, dz = math.cos(angle), math.sin(angle)
        local tip = top + v(dx * span, rng:NextNumber(-2.9, -0.8), dz * span)
        part(owner, "Folha arqueada da palmeira", top.X + dx * 2, top.Y + 0.09, top.Z + dz * 2,
            1.8, 0.34, 4.5, rgb(69, 107, 75), "foliage",
            {shape = "Ball", yaw = math.deg(math.atan2(dx, dz)), collision = false})
        beam(owner, "Ponta da folha", top + v(dx * 2.95, 0.06, dz * 2.95), tip,
            0.6, 0.18, rgb(54, 90, 68), "foliage", detail)
    end
end

local function costa(ctx, parent, x, z, seed)
    local blue, glass, algae = rgb(71, 138, 145), rgb(65, 124, 131), rgb(82, 126, 114)
    local concrete, salt, lime = rgb(119, 116, 109), rgb(155, 155, 137), rgb(177, 171, 143)
    local iron, rust, ink = rgb(78, 83, 80), rgb(117, 78, 59), rgb(50, 57, 60)
    local ivory, amber = rgb(193, 224, 213), rgb(253, 162, 91)
    local rng = ctx.random(seed)
    local root, part, beam = site(ctx, parent, x, z, "Parque de Marés", rgb(83, 86, 85), "asphalt", seed % 2 == 1)
    local forecourt = ctx.group(root, "Pátio de manutenção e passeio")
    floorMark(part, forecourt, "Esplanada de argamassa lavada", 4, -41, 92, 42, concrete, "sidewalk")
    floorMark(part, forecourt, "Calçadão da orla", 59, -0.5, 36, 178, salt, "sidewalk", nil, 0.009)
    floorMark(part, forecourt, "Faixa de madeira do calçadão", 70, -0.5, 10, 164, rgb(111, 94, 73), "wood", nil, 0.019)
    for i = 0, 10 do
        part(forecourt, "Junta do piso litorâneo", 60, groundY + 0.058, -80 + i * 16, 34, 0.023, 0.17, ink, "cement", finish)
    end
    for i = 1, 6 do
        local dx, dz = rng:NextNumber(-77, -36), rng:NextNumber(-81, -36)
        floorMark(part, forecourt, "Remendo no asfalto do pátio", dx, dz, rng:NextNumber(4, 13), rng:NextNumber(5, 11),
            concrete:Lerp(ink, rng:NextNumber(0.6, 0.85)), "asphalt", rng:NextNumber(-12, 12))
        floorMark(part, forecourt, "Demarcação de carga gasta", -38 + (i - 1) * 8, -57, 3.7, 0.24, lime, "paint", nil, 0.017)
    end
    for i, z0 in {-68, -28, 21, 69} do
        local dx = if i % 2 == 0 then 65 else 76
        roundPost(part, forecourt, "Gola de concreto da palmeira", dx, groundY, z0, 0.24, 3.4, concrete, "cement")
        palm(part, beam, forecourt, dx, z0, 10 + rng:NextNumber(0, 4), rng:NextNumber(-1.2, 1.9), rng)
    end

    local hall = ctx.group(root, "Pavilhão aquático inacabado")
    local x0, spacing = -68, 20
    local front, peak, tail = -15, 22, 56
    local roofFront, roofPeak, roofBack = 16.5, 31.2, 19.1
    floorMark(part, hall, "Plataforma cimentada do pavilhão", -18, 21, 108, 78, concrete, "cement")
    for i = 0, 5 do
        local px = x0 + i * spacing
        local exposed = i >= 3
        local tint, material = if exposed then rust else concrete, if exposed then "steel" else "cement"
        for _, foot in {{front, roofFront}, {tail, roofBack}} do
            local pz, cap = foot[1], foot[2]
            part(hall, "Bloco de ancoragem da tesoura", px, 0.53, pz, 4.3, 0.98, 4.7, salt, "cement")
            part(hall, "Pilar da cobertura interrompida", px, 1.02 + (cap - 1.02) / 2, pz,
                if exposed then 1.27 else 2.65, cap - 1.02, if exposed then 1.67 else 2.55, tint, material)
            part(hall, "Chapa de ligação da tesoura", px, cap - 1.62, pz, 2.85, 3.1, 0.35, iron, "steel", detail)
        end
        beam(hall, "Água longa da tesoura", v(px, roofFront, front), v(px, roofPeak, peak), 1.22, 1.36, tint, material)
        beam(hall, "Água curta da tesoura", v(px, roofPeak, peak), v(px, roofBack, tail), 1.22, 1.36, tint, material)
        beam(hall, "Banzo horizontal da tesoura", v(px, 16.8, front), v(px, 18.8, tail), 0.86, 0.89, iron, "steel")
        beam(hall, "Pendural aparente da tesoura", v(px, 17.9, peak), v(px, roofPeak, peak), 0.77, 0.72, tint, material)
        if exposed then
            beam(hall, "Diagonal de montagem", v(px, roofPeak - 2.9, peak - 6.4), v(px, 18.1, peak + 9.5),
                0.51, 0.55, iron, "steel", detail)
            part(hall, "Tirante solto junto ao pilar", px + 0.8, roofFront + 1, front + 0.16, 0.25, 2.6, 0.25, rust, "steel", detail)
        end
    end
    for _, ridge in {{front, roofFront}, {peak, roofPeak}, {tail, roofBack}} do
        part(hall, "Travessa longitudinal exposta", -18, ridge[2], ridge[1], 102, 0.88, 0.72, rust, "steel")
    end
    for _, row in {{front + 11.7, roofFront + 4.7}, {peak - 10.5, roofPeak - 4.3}, {tail - 11, roofBack + 3.9}} do
        part(hall, "Terça deitada da cobertura", -18, row[2], row[1], 100, 0.39, 0.76, iron, "steel", detail)
    end
    local panels = if seed % 3 == 0 then 9 else 7
    for i = 0, panels - 1 do
        local dx = -66.75 + i * 6.2
        local tint = blue:Lerp(algae, rng:NextNumber(0.04, 0.53))
        roofPanel(part, hall, "Chapa ondulada ainda presa", dx, 6.16, front - 0.7, roofFront + 0.46, peak, roofPeak + 0.48,
            0.36, tint, "metal")
        if i <= 5 then
            roofPanel(part, hall, "Chapa posterior da cobertura", dx, 6.16, peak, roofPeak + 0.43, tail + 0.5, roofBack + 0.43,
                0.43, salt:Lerp(blue, 0.47), "steel")
        end
    end
    local rimWidth, rimX = panels * 6.2, -66.75 + (panels - 1) * 3.1
    part(hall, "Testeira turquesa lascada", rimX, 17.05, front - 1.18, rimWidth, 2.03, 0.41, blue, "metal")
    part(hall, "Moldura branca da testeira", rimX, 18.15, front - 1.16, rimWidth, 0.19, 0.45, lime, "paint", finish)
    soffitLight(ctx, part, hall, "fluorescente do pavilhão", -47, 15.8, front + 0.75, 7.4, ink, ivory, 26)
    soffitLight(ctx, part, hall, "refletor provisório da obra", 11, 14.45, front + 1.2, 3.05, rust, amber, 24)

    local basin = ctx.group(hall, "Piscina drenada")
    local bx, bz = -23, 18
    part(basin, "Revestimento sem água", bx, groundY + 0.045, bz, 53.4, 0.071, 25.6, rgb(99, 148, 144), "tile", finish)
    for _, side in {-1, 1} do
        local lipX, lipZ = bx + side * 26.7, bz + side * 12.9
        part(basin, "Mureta lateral da piscina", lipX, 0.49, bz, 1.2, 0.90, 26.9, salt, "cement")
        part(basin, "Capa da mureta", lipX, 0.97, bz, 1.40, 0.15, 27.1, lime, "tile")
        for _, dx in {-16.3, 16.3} do
            part(basin, "Boca da piscina com passagem", bx + dx, 0.49, lipZ, 20.1, 0.90, 1.25, salt, "cement")
            part(basin, "Azulejo da linha d’água", bx + dx, 0.71, lipZ - side * 0.65, 19.7, 0.25, 0.085, blue, "tile", finish)
        end
    end
    for i = -1, 1 do
        part(basin, "Raia de cerâmica quebrada", bx + i * 13.3, groundY + 0.087, bz, 0.53, 0.024, 22.4, ink, "tile", finish)
    end
    for i = 1, 9 do
        local px, pz = bx + rng:NextNumber(-24, 24), bz + rng:NextNumber(-11.3, 11.3)
        part(basin, "Desplacamento no fundo da piscina", px, groundY + 0.101, pz, rng:NextNumber(0.8, 2.7), 0.022,
            rng:NextNumber(0.8, 2.6), salt:Lerp(algae, 0.43), "cement", {yaw = i * 21, collision = false, shadow = false})
    end

    local service = ctx.group(root, "Vestiários de serviço")
    for i = 1, 3 do
        local dx = -58 + (i - 1) * 27
        part(service, "Vestiário fechado provisoriamente", dx, 5.13, 62, 25.3, 10.2, 12.1, salt, "cement")
        part(service, "Porta de chapa salinizada", dx + 2.6, 3.98, 55.73, 7.4, 7.8, 0.51, iron, "steel", detail)
        part(service, "Faixa desbotada de vestiário", dx, 8.56, 55.90, 24, 0.9, 0.18, algae, "paint", finish)
        for j = 1, 4 do
            part(service, "Vinco da porta de chapa", dx + 2.6, 1.15 + j * 1.21, 55.43, 7.09, 0.085, 0.09, rust, "steel", finish)
        end
        part(service, "Vão alto de ventilação", dx - 7.4, 6.65, 55.9, 5.25, 1.43, 0.22, ink, "metal", detail)
    end
    part(service, "Parapeito corrido dos vestiários", -31, 10.60, 62.4, 79.5, 0.94, 13, concrete, "cement")
    for i = 1, 5 do
        local xx, hh = 9.2 + i * 1.36, 8.9 + i * 1.76
        part(service, "Vareta de fundação exposta", xx, hh / 2 + 0.04, 64.1, 0.24, hh, 0.26, rust, "steel", detail)
    end
    local ducts = ctx.group(service, "Tubulações externas")
    for i = 1, 3 do
        local yy = 1.93 + i * 0.91
        part(ducts, "Conduta horizontal de água", -29, yy, 68.7, 76, 0.64, 0.64, if i == 2 then algae else iron,
            "metal", {shape = "Cylinder"})
        for j = 1, 5 do
            part(ducts, "Flange corroída na conduta", -70 + j * 13, yy, 68.7, 0.22, 0.89, 0.89, rust, "metal",
                {shape = "Cylinder", collision = false})
        end
    end

    local booth = ctx.group(forecourt, "Posto de manutenção do pavilhão")
    part(booth, "Abrigo de chapa do vigia", -67, 3.64, -60, 15.4, 7.2, 12.6, algae, "metal")
    roofPanel(part, booth, "Cobertura gasta do abrigo", -67, 17.3, -67.1, 7.6, -53.1, 8.53, 0.39, iron, "steel")
    part(booth, "Janela iluminada do posto", -66.4, 4.45, -66.34, 7.15, 2.06, 0.13, rgb(160, 126, 80), "glass", detail)
    part(booth, "Divisão da janela", -66.4, 4.45, -66.44, 0.18, 2.09, 0.15, ink, "metal", detail)
    soffitLight(ctx, part, booth, "lâmpada do posto de manutenção", -67, 7.24, -66.81, 3.9, iron, amber, 16)
    for i = 1, 3 do
        local dx, dz = -72 + i * 4.4, -47 + (i % 2) * 4.6
        part(booth, "Caixote de material úmido", dx, 1.07, dz, 3.9, 2.06, 2.9, rust:Lerp(algae, i * 0.2), "wood")
        part(booth, "Cinta de carga", dx - 0.68, 1.16, dz - 1.465, 0.29, 1.92, 0.066, ink, "metal", finish)
    end
end

local function cercado(ctx, parent, x, z, seed)
    local ink, steel = rgb(52, 58, 57), rgb(92, 93, 81)
    local clay, rust, cement = rgb(132, 89, 71), rgb(135, 75, 51), rgb(125, 125, 113)
    local ash, teal = rgb(158, 151, 129), rgb(69, 116, 108)
    local amber, mint = rgb(252, 181, 113), rgb(179, 225, 204)
    local rng = ctx.random(seed)
    local root, part, beam = site(ctx, parent, x, z, "Cercado das Bombas", rgb(95, 94, 86), "cement", seed % 2 == 0)
    local court = ctx.group(root, "Passagem pública da antiga fábrica")
    floorMark(part, court, "Piso longitudinal do pátio", 1, 0, 29, 178, ash, "sidewalk")
    floorMark(part, court, "Largo em frente à oficina", 43, -23, 60, 33, cement, "sidewalk")
    for i = 1, 11 do
        local dz = -84 + i * 14
        floorMark(part, court, "Junta nas placas do pátio", 1, dz, 28.7, 0.15, steel, "cement", nil, 0.01)
    end
    for _, dx in {4.2, 7.8} do
        part(court, "Trilho embutido no piso", dx, groundY + 0.039, 6, 0.22, 0.031, 125, rust, "steel", finish)
    end
    for i = 1, 12 do
        part(court, "Remendo de travessa na via antiga", 6, groundY + 0.05, -49 + i * 9.2, 5.84, 0.022, 0.26,
            rgb(101, 83, 67), "paint", finish)
    end
    for i = 1, 7 do
        local dx = rng:NextNumber(22, 71)
        local dz = rng:NextNumber(-47, -14)
        floorMark(part, court, "Reparo áspero de argamassa", dx, dz, rng:NextNumber(3.2, 9), rng:NextNumber(1.1, 5.8),
            cement:Lerp(ink, rng:NextNumber(0.17, 0.51)), "cement", i * 10, 0.012)
    end

    local gateway = ctx.group(root, "Pórtico da antiga comporta")
    local gateZ, span = -55, 28.5
    for _, side in {-1, 1} do
        local dx = side * span
        part(gateway, "Sapata do antigo cavalete", dx, 0.89, gateZ, 8.1, 1.7, 10.1, cement, "cement")
        part(gateway, "Pé-direito da comporta", dx, 10.98, gateZ, 4.3, 18.52, 6.8, rust, "steel")
        part(gateway, "Chapa frontal do pé-direito", dx, 11.14, gateZ - 3.57, 3.7, 17.1, 0.36, steel, "metal", detail)
        part(gateway, "Contrapeso de concreto", dx, 17.12, gateZ + 3.85, 7.3, 4.72, 4.08, cement, "cement")
        beam(gateway, "Escora inclinada da comporta", v(dx + side * 8, 1, gateZ + 5.75), v(dx, 17.16, gateZ + 2.6),
            1.49, 1.53, rust, "steel")
        part(gateway, "Sapata da escora", dx + side * 8, 0.56, gateZ + 5.75, 3.15, 1.04, 3.2, cement, "cement")
        for i = 1, 6 do
            part(gateway, "Rebite em placa", dx + side * 1.32, 3.6 + i * 2.13, gateZ - 3.83, 0.36, 0.39, 0.17,
                ink, "metal", detail)
        end
        part(gateway, "Pilar de apoio do pórtico superior", dx, 22.97, gateZ, 3.2, 5.48, 4.5, rust, "steel")
    end
    part(gateway, "Viga rebitada sobre a passagem", 0, 19.86, gateZ, 60.9, 1.65, 6.3, rust, "steel")
    part(gateway, "Banzo superior do pórtico", 0, 25.43, gateZ, 60.9, 1.11, 3.9, steel, "steel")
    for i = 0, 5 do
        local dx = -28.5 + i * 9.5
        beam(gateway, "Diagonal curta da treliça do pórtico", v(dx, 20.48, gateZ - 1.85), v(dx + 4.75, 25.39, gateZ - 1.85),
            0.66, 0.64, rust, "steel", detail)
        beam(gateway, "Diagonal longa da treliça do pórtico", v(dx + 4.75, 25.39, gateZ - 1.85), v(dx + 9.5, 20.48, gateZ - 1.85),
            0.66, 0.64, rust, "steel", detail)
    end
    local tile = part(gateway, "Placa da passagem pública", -15, 19.93, gateZ - 3.28, 13.7, 1.15, 0.2, ink, "metal", detail)
    ctx.sign(tile, "Front", "PÁTIO DO CERCADO", rgb(221, 199, 165))
    soffitLight(ctx, part, gateway, "luz da travessia", 0, 18.72, gateZ - 0.9, 7.2, ink, amber, 27)
    roundPost(part, gateway, "Carcaça do mecanismo do pórtico", span, 25.92, gateZ, 3.2, 5.2, ink, "steel")
    roundPost(part, gateway, "Tampa do mecanismo", span, 29.11, gateZ, 0.5, 5.65, rust, "metal")

    local foundry = ctx.group(root, "Galpão de bombas convertido em ateliê")
    local cx, width, front, back = -46, 56, -20, 52
    local opening, intactHeight = 15, 15.5
    for _, side in {-1, 1} do
        local face = cx + side * width / 2
        part(foundry, "Muro industrial de tijolo", face, 7.86, (front + back) / 2, 1.8, 15.64, back - front + 0.2, clay, "brick")
        part(foundry, "Trecho de tijolo junto ao portão", cx + side * (width + opening) / 4, 7.78, front,
            (width - opening) / 2 + 0.43, intactHeight, 2, clay, "brick")
        for i = 1, 5 do
            local dz = front + 8 + (i - 1) * 13.8
            part(foundry, "Pilarete de concreto aparente", face + side * 0.95, 8.21, dz, 1.19, 16.3, 1.7, cement, "cement")
            part(foundry, "Janela alta escurecida", face + side * 0.925, 10.9, dz + 4.85, 0.19, 4.1, 6.6,
                if i % 2 == 0 then rgb(115, 98, 73) else teal, "glass", detail)
        end
    end
    part(foundry, "Travessa do vão de serviço", cx, 12.97, front, 15.45, 5.12, 2.18, clay, "brick")
    part(foundry, "Verga metálica do portão aberto", cx, 10.29, front - 0.1, 15.1, 0.50, 2.34, rust, "steel")
    for _, dx in {-8.05, 8.05} do
        part(foundry, "Ombreira aparafusada", cx + dx, 5.17, front - 0.98, 0.62, 10.3, 0.38, steel, "metal")
    end
    part(foundry, "Parede traseira de tijolo", cx, 7.78, back, width, intactHeight, 1.8, clay, "brick")
    for i = 0, 2 do
        local dz, nextZ = front + i * 24, front + (i + 1) * 24
        roofPanel(part, foundry, "Dente de serra do telhado", cx, 58.7, dz - 0.24, 15.5, nextZ + 0.14, 23.45,
            0.65, steel:Lerp(ink, i * 0.13), "steel")
        part(foundry, "Base de aço da claraboia", cx, 15.92, nextZ, 57.2, 0.51, 0.61, rust, "steel")
        for bay = 1, 6 do
            local dx = cx + (bay - 3.5) * 9.4
            part(foundry, "Vidraça vertical do dente de serra", dx, 19.55, nextZ, 9.17, 6.91, 0.41,
                if (bay + i) % 4 == 0 then ink else teal, "glass", detail)
            part(foundry, "Montante da claraboia industrial", dx + 4.66, 19.66, nextZ, 0.30, 7.8, 0.69, rust, "steel", detail)
        end
        for _, side in {-1, 1} do
            beam(foundry, "Borda inclinada da cobertura", v(cx + side * 28.8, 15.4, dz),
                v(cx + side * 28.8, 23.35, nextZ), 0.36, 0.48, rust, "steel", detail)
            part(foundry, "Fechamento triangular lateral", cx + side * 28.07, 19.34, (dz + nextZ) / 2,
                0.94, 7.76, 24, cement, "cement", {shape = "Wedge"})
        end
    end
    for _, dx in {-15.5, 15.5} do
        part(foundry, "Janela cega de fachada", cx + dx, 8.29, front - 1.04, 10.2, 4.72, 0.2, teal, "glass", detail)
        part(foundry, "Peitoril de cimento da janela", cx + dx, 5.97, front - 1.28, 10.4, 0.39, 0.72, ash, "cement", detail)
        for i = -1, 1 do
            part(foundry, "Caixilho antigo", cx + dx + i * 3.2, 8.3, front - 1.18, 0.19, 4.73, 0.17,
                rust, "metal", detail)
        end
    end
    soffitLight(ctx, part, foundry, "luz da oficina restaurada", cx, 9.87, front + 0.92, 6.4, ink, mint, 24)

    local annex = ctx.group(root, "Oficinas abertas de manutenção")
    local shopFront, shopBack = -3, 35
    part(annex, "Parede de fundo dos boxes", 46, 6.64, shopBack, 43.5, 13.2, 2.4, cement, "cement")
    for i = 0, 3 do
        local px = 25 + i * 14
        part(annex, "Pilar entre boxes de oficina", px, 6.66, shopFront, 1.94, 13.24, 3.1, cement, "cement")
        part(annex, "Perfil de remate do pilar", px, 7.46, shopFront - 1.59, 1.04, 11.6, 0.15, teal, "metal", detail)
    end
    roofPanel(part, annex, "Telhado inclinado das oficinas", 46, 46.7, shopFront - 2.3, 13.6, shopBack + 2.1, 17.23, 0.57,
        steel, "steel")
    part(annex, "Testeira dos boxes", 46, 13.13, shopFront - 1.93, 45.6, 1.35, 0.83, ink, "steel")
    for i = 1, 3 do
        local px = 18 + i * 14
        part(annex, "Bancada dos boxes", px, 1.85, shopBack - 2.68, 8.3, 3.62, 1.81, teal:Lerp(steel, i * 0.18), "metal")
        part(annex, "Tampo para manutenção", px, 3.72, shopBack - 2.74, 8.72, 0.34, 2.06, rgb(122, 91, 70), "wood")
        part(annex, "Armário de ferramentas", px, 6.25, shopBack - 1.46, 7.65, 2.64, 0.68, ink, "steel")
        if i ~= 2 then
            soffitLight(ctx, part, annex, "luminária dos boxes", px, 12.81, shopFront + 3.9, 3, ink, amber, 19)
        end
    end
    roundPost(part, annex, "Chaminé curta da instalação original", 57, 13, 46, 19.9, 3.1, clay, "brick")
    roundPost(part, annex, "Anel metálico da chaminé", 57, 31.9, 46, 0.79, 3.63, rust, "steel")
    part(annex, "Base técnica da chaminé", 57, 6.55, 46, 8.3, 13, 9.2, clay, "brick")
    part(annex, "Tubulação preservada no pátio", 49.5, 5.65, 41.3, 31.5, 0.93, 0.93, teal, "metal", {shape = "Cylinder"})
    for i = 1, 4 do
        part(annex, "Abraçadeira da tubulação antiga", 35 + i * 6.15, 5.65, 41.3, 0.48, 1.2, 1.2, rust, "steel",
            {shape = "Cylinder", collision = false})
    end

    local wheel = ctx.group(court, "Volante da bomba preservado")
    local wheelX, wheelY, wheelZ = -52, 5.92, -47.8
    part(wheel, "Base do antigo volante", wheelX, 0.70, wheelZ + 0.8, 13.9, 1.32, 7.2, cement, "cement")
    for _, side in {-1, 1} do
        beam(wheel, "Suporte do volante", v(wheelX + side * 4.7, 1.33, wheelZ + 2.2), v(wheelX, wheelY, wheelZ + 0.48),
            1.2, 1.12, steel, "steel")
    end
    part(wheel, "Disco externo do volante", wheelX, wheelY, wheelZ, 1.12, 9.8, 9.8, rust, "metal", {shape = "Cylinder", yaw = 90})
    part(wheel, "Tambor escuro do volante", wheelX, wheelY, wheelZ - 0.51, 0.28, 8.6, 8.6, ink, "metal",
        {shape = "Cylinder", yaw = 90, collision = false})
    part(wheel, "Cubo do volante", wheelX, wheelY, wheelZ - 0.70, 0.29, 2.63, 2.63, steel, "steel",
        {shape = "Cylinder", yaw = 90, collision = false})
    for i = 1, 8 do
        local reach = v(math.cos(i * math.pi / 4), math.sin(i * math.pi / 4), 0)
        local center = v(wheelX, wheelY, wheelZ - 0.69)
        beam(wheel, "Raio do volante", center + reach * 1.22, center + reach * 4.52, 0.36, 0.44, rust, "metal", detail)
    end
    for i = 1, 3 do
        local dz = 4 + (i - 1) * 19.7
        part(court, "Apoios de banco no antigo cais de carga", 18, 0.75, dz, 2.68, 1.42, 7.9, cement, "cement")
        part(court, "Banco de madeira do pátio", 18, 1.55, dz, 2.78, 0.29, 8.05, rgb(124, 91, 69), "wood")
    end
end

local function limite(ctx, parent, x, z, seed)
    local dust, buff, gravel, ink = rgb(121, 107, 88), rgb(149, 132, 103), rgb(98, 91, 79), rgb(54, 60, 54)
    local steel, rust, sage = rgb(94, 95, 78), rgb(123, 83, 58), rgb(108, 117, 77)
    local amber, red = rgb(255, 187, 105), rgb(230, 102, 72)
    local rng = ctx.random(seed)
    local root, part, beam = site(ctx, parent, x, z, "Pátio do Anel Seco", dust, "sidewalk", seed % 2 == 0)
    local apron = ctx.group(root, "Via de serviço em cascalho")
    floorMark(part, apron, "Via de serviço contínua", 0, 0, 26, 181, gravel, "asphalt")
    for i = 1, 8 do
        local pz = -76 + (i - 1) * 21
        floorMark(part, apron, "Acostamento de brita irregular", rng:NextNumber(-5, 3), pz, rng:NextNumber(34, 43),
            rng:NextNumber(12, 19), gravel:Lerp(dust, rng:NextNumber(0.3, 0.53)), "sidewalk", rng:NextNumber(-12, 12), 0.007)
        for _, side in {-1, 1} do
            local px = side * rng:NextNumber(29, 68)
            floorMark(part, apron, "Área de pó acumulado", px, pz + rng:NextNumber(-3, 6), rng:NextNumber(7.3, 13.7),
                rng:NextNumber(5, 9.2), buff:Lerp(rust, rng:NextNumber(0.11, 0.36)), "cement", i * 17, 0.011)
        end
    end
    for i = 1, 12 do
        local side = if i % 2 == 0 then 1 else -1
        local px, pz = side * rng:NextNumber(73, 83.5), rng:NextNumber(-81, 81)
        part(apron, "Rocha baixa do talude", px, groundY + 0.34, pz, rng:NextNumber(4.3, 8.9), rng:NextNumber(0.62, 1.45),
            rng:NextNumber(3.1, 6), buff:Lerp(gravel, rng:NextNumber(0.21, 0.72)), "stone",
            {shape = "Ball", collision = false, yaw = rng:NextNumber(-30, 30)})
        if i % 2 == 0 then
            for stem = 1, 3 do
                local from = v(px + 0.54 * stem, groundY + 0.1, pz + 1.9)
                beam(apron, "Capim do acostamento", from, from + v(0.31 * (stem - 2), 0.51 + stem * 0.23, 0.24),
                    0.11, 0.12, sage, "foliage", finish)
            end
        end
    end

    local cabin = ctx.group(root, "Abrigo de operação")
    local sx, sz = -51, -37
    part(cabin, "Fundação rasa do abrigo", sx, 0.20, sz, 26.2, 0.33, 18.3, buff, "cement")
    part(cabin, "Cabine de chapa corrugada", sx, 4.1, sz, 24, 7.5, 16, buff:Lerp(steel, 0.49), "metal")
    roofPanel(part, cabin, "Chapa inclinada do teto", sx, 26, sz - 9.1, 8.14, sz + 9.1, 10.08, 0.34, steel, "steel")
    for i = 1, 15 do
        part(cabin, "Vinco vertical da chapa", sx + (i - 8) * 1.53, 4.16, sz - 8.05, 0.15, 7.38, 0.15, steel, "metal", detail)
    end
    part(cabin, "Janela protegida do operador", sx - 4.5, 4.86, sz - 8.21, 7.15, 2.69, 0.21, rgb(127, 109, 75), "glass", detail)
    for i = 1, 5 do
        part(cabin, "Grade da janela", sx - 8.13 + i * 1.21, 4.86, sz - 8.36, 0.13, 2.73, 0.19, ink, "steel", detail)
    end
    part(cabin, "Porta da cabine de operação", sx + 6.54, 3.59, sz - 8.26, 3.74, 6.45, 0.69, sage:Lerp(ink, 0.4), "steel", detail)
    part(cabin, "Puxador da porta", sx + 7.58, 3.27, sz - 8.66, 0.73, 0.16, 0.15, buff, "metal", detail)
    soffitLight(ctx, part, cabin, "arandela do operador", sx + 5.3, 7.56, sz - 8.64, 2.65, ink, amber, 19)

    local relay = ctx.group(root, "Estação de retransmissão")
    local tx, tz = -49, 42
    local tiers = if seed % 3 == 0 then 4 else 6
    local function joint(level, index)
        local radius = 9.2 - (level / tiers) * 7.05
        local angle = index * math.pi * 2 / 3 - math.pi / 2
        return v(tx + math.cos(angle) * radius, groundY + 1.15 + level * 8.8, tz + math.sin(angle) * radius)
    end
    for i = 0, 2 do
        local p = joint(0, i)
        part(relay, "Sapata isolada da torre", p.X, 0.61, p.Z, 3.5, 1.14, 3.5, buff, "cement")
    end
    for level = 0, tiers - 1 do
        for i = 0, 2 do
            local a, b = joint(level, i), joint(level + 1, i)
            local c = joint(level + 1, (i + 1) % 3)
            beam(relay, "Montante da torre triangular", a, b, 0.58, 0.63, steel, "steel")
            beam(relay, "Travessa triangular da torre", b, c, 0.39, 0.38, ink, "steel", detail)
            beam(relay, "Diagonal da torre triangular", a, c, 0.34, 0.38, rust, "steel", detail)
        end
    end
    local head = joint(tiers, 0).Y
    part(relay, "Plataforma do rádio", tx, head - 0.18, tz, 6.2, 0.35, 5.6, steel, "steel")
    roundPost(part, relay, "Haste de rádio do anel", tx, head, tz, 9.6, 0.38, buff, "steel")
    for i = 1, 3 do
        local dz = tz - 1.55 + (i - 1) * 1.53
        part(relay, "Painel setorial de rádio", tx - 1.47, head + 1.53, dz, 0.47, 2.70, 0.83, buff, "paint", detail)
    end
    roundPost(part, relay, "Farol do topo da torre", tx, head + 9.5, tz, 0.33, 0.62, red, "neon")

    local trench = ctx.group(root, "Coletor e tubulações do anel")
    for i = 1, 2 do
        local pz = 28 + i * 15.8
        local tankX = 51 + (i - 1) * 13.1
        roundPost(part, trench, "Fundação do reservatório", tankX, groundY, pz, 0.75, 16.2, buff, "cement")
        roundPost(part, trench, "Reservatório cilíndrico de serviço", tankX, 0.79, pz, 9.65, 13.8, buff:Lerp(sage, i * 0.19), "metal")
        roundPost(part, trench, "Cinta do reservatório", tankX, 7.31, pz, 0.47, 14.15, rust, "steel")
        roundPost(part, trench, "Tampa plana do reservatório", tankX, 10.44, pz, 0.57, 14.3, steel, "steel")
        roundPost(part, trench, "Bocal do reservatório", tankX, 11.01, pz, 1.14, 2.74, rust, "metal")
    end
    for i = 1, 2 do
        local py, px = 1.74 + i * 1.01, 22 + i * 3.05
        part(trench, "Duto externo do pátio", px, py, 25, 69, 1.08, 1.08, if i == 1 then steel else rust,
            "metal", {shape = "Cylinder", yaw = 90})
        part(trench, "Derivação do coletor", (px + 43.2) / 2, py, 58.1 - i * 4.1, 43.2 - px, 1.11, 1.11, rust,
            "metal", {shape = "Cylinder"})
        for j = 1, 5 do
            local pz = -7 + j * 11.8
            part(trench, "Flange do duto externo", px, py, pz, 0.42, 1.37, 1.37, buff, "metal",
                {shape = "Cylinder", yaw = 90, collision = false})
        end
    end
    for i = 1, 5 do
        local pz = -13 + i * 14
        part(trench, "Bloco de suporte do coletor", 26.45, 0.42, pz, 6.7, 0.76, 2.4, buff, "cement")
        part(trench, "Cavalete do duto", 26.45, 2.04, pz, 1.81, 2.47, 1.38, steel, "steel")
    end
    floorMark(part, trench, "Leito inferior do coletor", 49, 7, 28, 47, ink, "asphalt")
    for i = 1, 9 do
        local pz = -14.5 + i * 4.1
        part(trench, "Grelha de serviço nivelada com a via", 53, groundY + 0.035, pz, 13.2, 0.058, 0.27, steel, "steel", finish)
    end

    local pole = ctx.group(root, "Linha de energia do anel")
    for _, pz in {-62, 3.5} do
        part(pole, "Poste de serviço laminado", -28, 9.04, pz, 0.68, 18.0, 0.76, ink, "steel")
        part(pole, "Cruzeta da linha de energia", -28, 16.32, pz, 5.75, 0.36, 0.51, steel, "steel")
        for _, side in {-1, 1} do
            roundPost(part, pole, "Isolador cerâmico da cruzeta", -28 + side * 2.23, 16.5, pz, 0.58, 0.39, rgb(139, 125, 95), "tile")
        end
    end
    for _, side in {-1, 1} do
        local px = -28 + side * 2.23
        local function cablePoint(t)
            return v(px, 17.01 - 4 * 3.45 * t * (1 - t), -62 + t * 65.5)
        end
        for i = 1, 8 do
            beam(pole, "Cabo aéreo isolado", cablePoint((i - 1) / 8), cablePoint(i / 8), 0.114, 0.114, ink, "rubber", finish)
        end
    end
    part(pole, "Braço do refletor de serviço", -26, 10.7, -61.98, 4.3, 0.45, 0.48, steel, "steel")
    soffitLight(ctx, part, pole, "refletor de sódio do acesso", -23.93, 10.29, -61.98, 0.89, steel, amber, 24)
end

local builders = {altos = altos, costa = costa, cercado = cercado, limite = limite}

function EdgeBlocks.build(ctx, parent, x, z, seed, theme)
    local build = assert(builders[theme], "Tipo de quadra periférica desconhecido " .. tostring(theme))
    build(ctx, parent, x, z, seed)
end

return EdgeBlocks
