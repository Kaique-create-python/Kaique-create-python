local Streets = {}

function Streets.build(ctx, city, layout)
    local rgb, box, group = ctx.rgb, ctx.box, ctx.group
    local many = group(city, "Ruas e passagens")
    local canals = group(city, "Canal e pontes")
    local roadway = rgb(30, 35, 43)
    local paving = rgb(85, 89, 98)
    local curb = rgb(116, 120, 134)
    local gray = rgb(54, 63, 83)
    local ink = rgb(28, 36, 49)
    local cyan = rgb(99, 217, 242)
    local rose = rgb(242, 72, 157)
    local offWhite = rgb(192, 198, 201)
    local quayPaving = rgb(105, 110, 123)
    local quayFill = rgb(197, 220, 249)
    local bridgeFill = rgb(250, 217, 178)
    local wetHighlight = rgb(112, 149, 175)
    local wetCyan = rgb(57, 153, 176)
    local wetAmber = rgb(164, 118, 86)
    local paint = {collision = false, shadow = false}
    local rng = ctx.random(51428)
    local bank = layout.bank
    local mirrors = {}
    local palettes = {
        sodio = {lamp = rgb(250, 164, 93), spill = rgb(246, 77, 151), paving = rgb(99, 74, 77), wet = true},
        vertice = {lamp = rgb(137, 210, 245), spill = rgb(93, 220, 255), paving = rgb(82, 95, 110), wet = true},
        prisma = {lamp = rgb(165, 218, 245), spill = rgb(193, 112, 255), paving = rgb(85, 91, 106), wet = true},
        colmeia = {lamp = rgb(253, 205, 147), spill = rgb(243, 168, 95), paving = rgb(96, 88, 87), wet = true},
        docas = {lamp = rgb(246, 164, 93), spill = rgb(255, 142, 70), paving = rgb(95, 82, 73), wet = true},
        costa = {lamp = rgb(153, 222, 214), spill = rgb(76, 221, 207), paving = rgb(86, 94, 92), wet = true},
        cercado = {lamp = rgb(251, 183, 112), spill = rgb(243, 139, 74), paving = rgb(105, 91, 73), wet = true},
        altos = {lamp = rgb(238, 229, 198), paving = rgb(109, 104, 94)},
        limite = {lamp = rgb(235, 190, 121), paving = rgb(123, 108, 89)},
    }

    local function slab(parent, name, axis, span, center, line, along, across, y, h, color, material, options)
        if axis == "X" then
            return box(parent, name, center + along, y, line + across, span[1], h, span[2], color, material, options)
        end
        return box(parent, name, line + across, y, center + along, span[2], h, span[1], color, material, options)
    end

    local function wetGlint(parent, axis, center, line, along, across, span, color, transparency, surfaceY)
        local x, z = if axis == "X" then center + along else line + across, if axis == "X" then line + across else center + along
        local width, depth = if axis == "X" then span[1] else span[2], if axis == "X" then span[2] else span[1]
        local y = surfaceY or -0.229
        local basis = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
        local fleck = box(parent, "Reflexo de luminária no piso", x, y, z, 0.012, width, depth, color, "neon", {
            shape = "Cylinder", cframe = basis, collision = false, shadow = false, transparency = transparency,
        })
        fleck:SetAttribute("MareBrilhoPiso", true)
    end

    local function roadPuddle(parent, axis, center, line, along, across, palette, reflective)
        local length = if reflective then rng:NextNumber(20, 29) else rng:NextNumber(9.8, 18.4)
        local width = if reflective then rng:NextNumber(3.6, 5.8) else rng:NextNumber(2.4, 4.4)
        local water = slab(parent, if reflective then "Poça" else "Lâmina de água", axis, {length, width},
            center, line, along, across, -0.256, 0.024, rgb(58, 78, 99), "puddle",
            {collision = false, shadow = false, transparency = if reflective then 0.61 else 0.68, reflectance = 0.45})
        if reflective then
            water:SetAttribute("CyberOutlawPlano", layout.roadY)
            ctx.reflection(water)
            table.insert(mirrors, water)
        end
        wetGlint(parent, axis, center, line, along, across, {length * 1.18, width * 0.78}, palette.spill, 0.93)
        for index = 1, 3 do
            local delta = (index - 2) * length * 0.24 + rng:NextNumber(-0.7, 0.7)
            wetGlint(parent, axis, center, line, along + delta, across + (index - 2) * 0.67,
                {length * rng:NextNumber(0.18, 0.37), rng:NextNumber(0.32, 0.72)},
                if index == 2 then palette.lamp else palette.spill, 0.69 + index * 0.056)
        end
        return {along, across, length, width}
    end

    local function lamp(parent, axis, center, line, along, across, palette, active)
        local s = math.sign(across)
        slab(parent, "Base aparafusada", axis, {1.45, 1.45}, center, line, along, across, 0.34, 0.56, ink, "cement")
        slab(parent, "Coluna do poste", axis, {0.42, 0.46}, center, line, along, across, 8.14, 15.2, gray, "steel")
        slab(parent, "Tampa de manutenção", axis, {0.53, 0.52}, center, line, along, across, 1.67, 1.48, ink, "metal", paint)
        slab(parent, "Braço do poste", axis, {0.42, 5.0}, center, line, along, across - s * 2.3, 15.28, 0.55, gray, "steel", paint)
        slab(parent, "Carcaça da luminária", axis, {2.05, 3.35}, center, line, along, across - s * 4.3, 15.07, 0.61,
            ink, "metal", paint)
        local bulb = slab(parent, "Difusor de rua", axis, {1.66, 2.83}, center, line, along, across - s * 4.3, 14.73, 0.19,
            palette, "neon", paint)
        if active then
            ctx.lamp(bulb, palette, 38, 2.05, "Bottom")
        end
    end

    local function drain(parent, axis, center, line, along, across)
        slab(parent, "Caixilho do bueiro", axis, {2.8, 1.52}, center, line, along, across, -0.237, 0.07, ink, "metal", paint)
        for i = -3, 3 do
            slab(parent, "Ferro fundido do bueiro", axis, {0.18, 1.24}, center, line, along + i * 0.35, across,
                -0.193, 0.055, rgb(77, 83, 92), "metal", paint)
        end
    end

    local function junctionSignal(parent, x, z, yaw, active)
        box(parent, "Pé do semáforo", x, 0.27, z, 1.3, 0.45, 1.3, ink, "cement")
        box(parent, "Mastro do semáforo", x, 5.0, z, 0.37, 9.8, 0.37, gray, "steel")
        local frame = CFrame.new(x, 9.1, z) * CFrame.Angles(0, math.rad(yaw), 0)
        box(parent, "Caixa de sinais", x, 9.1, z, 1.12, 3.12, 0.73, ink, "metal", {cframe = frame})
        local signals = {rgb(233, 56, 79), rgb(255, 188, 56), rgb(77, 242, 189)}
        for i, color in signals do
            box(parent, "Lente do semáforo", x, 9.1, z, 0.65, 0.64, 0.14, if i == active then color else rgb(36, 42, 51),
                if i == active then "neon" else "glass",
                {cframe = frame * CFrame.new(0, (2 - i) * 0.91, -0.42), collision = false})
        end
        box(parent, "Pala do semáforo", x, 9.1, z, 1.31, 0.18, 0.87, gray, "steel",
            {cframe = frame * CFrame.new(0, 1.61, -0.25), collision = false})
    end

    local function span(axis, line, first, last, width, pedestrian)
        assert(last > first)
        local center = (last + first) / 2
        local length = last - first
        local radius = width / 2
        local segment = group(many, string.format("%s · %d / %d", if axis == "X" then "Avenida" else "Rua", line, center))
        local lit = math.abs(line) <= 480 or math.abs(center) <= 520
        local mirrorSide
        if axis == "X" and ((math.abs(center) < 390 and (line == -480 or line == -240 or line == 0 or line == 480))
            or (line == 240 and math.abs(center) < 175)) then
            mirrorSide = if line < 0 or (line > 0 and center < 0) then 1 else -1
        elseif axis == "Z" and math.abs(line) == 240 and math.abs(center) < 390 then
            mirrorSide = if line < 0 then 1 else -1
        end
        local cut
        for _, side in {-1, 1} do
            local offset = line + side * (radius + 8)
            local theme = if axis == "X" then layout.themeAt(center, offset) else layout.themeAt(offset, center)
            local palette = palettes[theme]
            slab(segment, "Faixa de bordo", axis, {length, 0.24}, center, line, 0, side * (radius - 1.4), -0.246, 0.023,
                offWhite, "paint", paint)
            slab(segment, "Canaleta do passeio", axis, {length, 1.14}, center, line, 0, side * (radius + 0.56), -0.38, 0.24,
                ink, "steel")
            slab(segment, "Meio-fio de granito", axis, {length, 0.83}, center, line, 0, side * (radius + 1.54), -0.14, 0.48, curb,
                "stone")
            if pedestrian then
                slab(segment, "Passeio de placas drenantes", axis, {length, 11.0}, center, line, 0, side * (radius + 7.2),
                    -0.28, 0.64, palette.paving, "sidewalk", {shadow = false})
                slab(segment, "Linha tátil do passeio", axis, {length - 2, 0.47}, center, line, 0, side * (radius + 3.3),
                    0.053, 0.039, rgb(136, 117, 88), "tile", paint)
                local along = side * (length * 0.24)
                local tone = if axis == "X" and line == 0 and theme == "prisma" then cyan else palette.lamp
                lamp(segment, axis, center, line, along, side * (radius + 3.8), tone, lit)
                if lit then
                    drain(segment, axis, center, line, -along * 0.87, side * (radius - 0.65))
                    local reflective = side == mirrorSide
                    if reflective or palette.wet then
                        local puddle = roadPuddle(segment, axis, center, line, along + side * 3.2,
                            side * (radius - 4.6), if palette.wet then palette else palettes.prisma, reflective)
                        if reflective then cut = puddle end
                    end
                end
            end
        end
        local function asphalt(a, b, c, d)
            slab(segment, "Pista de asfalto úmido", axis, {b - a, d - c}, center, line, (a + b) / 2, (c + d) / 2,
                layout.roadY - 0.4, 0.8, roadway, "asphalt", {shadow = false, reflectance = 0.13})
        end
        if cut then
            -- A abertura mostra o reflexo planar do cliente. O suporte mantém a pista plana.
            local at, side, puddleLength, puddleWidth = table.unpack(cut)
            local left, right = at - puddleLength / 2, at + puddleLength / 2
            local inner, outer = side - puddleWidth / 2, side + puddleWidth / 2
            asphalt(-length / 2, left, -radius, radius)
            asphalt(right, length / 2, -radius, radius)
            asphalt(left, right, -radius, inner)
            asphalt(left, right, outer, radius)
            slab(segment, "Piso da poça", axis, {puddleLength, puddleWidth}, center, line, at, side,
                layout.roadY - 0.4, 0.8, roadway, "asphalt", {transparency = 1, shadow = false})
        else
            asphalt(-length / 2, length / 2, -radius, radius)
        end
        for offset = -length / 2 + 13, length / 2 - 13, 24 do
            slab(segment, "Faixa amarela", axis, {9, 0.34}, center, line, offset, 0, -0.247, 0.024,
                rgb(184, 149, 74), "paint", paint)
            if width >= 44 then
                for _, side in {-1, 1} do
                    slab(segment, "Divisão de faixa", axis, {8.1, 0.23}, center, line, offset, side * (radius * 0.52),
                        -0.243, 0.025, offWhite, "paint", paint)
                end
            end
        end
    end

    local function crosswalk(parent, axis, center, line, depth, width)
        local count = math.floor((width - 8) / 3.6)
        for index = 1, count do
            local across = (index - (count + 1) / 2) * 3.55
            slab(parent, "Faixa de pedestres", axis, {depth, 1.38}, center, line, 0, across, -0.245, 0.028, offWhite, "paint", paint)
        end
    end

    for row = 0, layout.rows do
        local z = -layout.halfZ + row * layout.pitch
        local width = layout.avenueWidth(z)
        for column = 0, layout.columns - 1 do
            local a = -layout.halfX + column * layout.pitch
            local b = a + layout.pitch
            span("X", z, a + (if a == 0 then bank else layout.streetWidth(a) / 2),
                b - (if b == 0 then bank else layout.streetWidth(b) / 2), width, true)
        end
    end
    for column = 0, layout.columns do
        local x = -layout.halfX + column * layout.pitch
        if x == 0 then continue end
        local width = layout.streetWidth(x)
        for row = 0, layout.rows - 1 do
            local a = -layout.halfZ + row * layout.pitch
            local b = a + layout.pitch
            span("Z", x, a + layout.avenueWidth(a) / 2, b - layout.avenueWidth(b) / 2, width, true)
        end
    end

    for row = 0, layout.rows do
        local z = -layout.halfZ + row * layout.pitch
        local w = layout.avenueWidth(z)
        for column = 0, layout.columns do
            local x = -layout.halfX + column * layout.pitch
            if x == 0 then continue end
            local d = layout.streetWidth(x)
            local intersection = group(many, string.format("Cruzamento %02d · %02d", column + 1, row + 1))
            box(intersection, "Pavimento do cruzamento", x, -0.666, z, d, 0.8, w, roadway, "asphalt", {shadow = false})
            for _, direction in {-1, 1} do
                crosswalk(intersection, "X", x + direction * (d/2 - 3.2), z, 4.25, w)
                crosswalk(intersection, "Z", z + direction * (w/2 - 3.2), x, 4.25, d)
                for _, side in {-1, 1} do
                    box(intersection, "Rebaixo da esquina", x + direction * (d/2 + 6.1), -0.22,
                        z + side * (w/2 + 6.1), 12.2, 0.46, 12.2, paving, "sidewalk", {shadow = false})
                end
            end
            if (column + row) % 3 == 0 and column > 0 and column < layout.columns and row > 0 and row < layout.rows then
                junctionSignal(intersection, x - (d/2 + 4), z - (w/2 + 4), 0, 3)
                junctionSignal(intersection, x + (d/2 + 4), z + (w/2 + 4), 180, 1)
            end
        end
    end

    local function bankRail(parent, x, first, last, y, color)
        local length = last - first
        if length <= 0 then return end
        local center = (first + last) / 2
        box(parent, "Travessa superior do guarda-corpo", x, y + 3.06, center, 0.27, 0.31, length, color, "steel", paint)
        box(parent, "Travessa inferior do guarda-corpo", x, y + 1.33, center, 0.20, 0.23, length, color, "steel", paint)
        for z = first + 2, last - 1, 9 do
            box(parent, "Montante do guarda-corpo", x, y + 1.5, z, 0.39, 3.07, 0.39, color, "steel", paint)
            box(parent, "Placa de fixação", x, y + 0.13, z, 1.12, 0.18, 0.94, ink, "metal", paint)
        end
        box(parent, "Limite de segurança", x, y + 1.5, center, 0.21, 3.07, length, color, "steel",
            {transparency = 1, shadow = false})
    end

    local function quayWalk(parent, x, startZ, endZ, side, puddles)
        local half = layout.sidewalkWidth / 2
        local west, east = x - half, x + half
        local plane = layout.walkY - 0.01
        local color = if puddles then quayPaving else paving
        local function floor(x0, x1, z0, z1)
            box(parent, "Passeio ribeirinho", (x0 + x1) / 2, plane - 0.42, (z0 + z1) / 2, x1 - x0, 0.84, z1 - z0,
                color, "sidewalk", {shadow = not puddles})
        end
        local last = startZ
        for index, placeZ in puddles or {} do
            local z = placeZ + side * 2.2
            local length, width = if index == 1 then 16.4 else 19.6, if index == 1 then 5.2 else 6.1
            local center = x + side * (if index == 1 then -0.34 else 0.38)
            floor(west, east, last, z - length / 2)
            local pool = group(parent, "Água no passeio do Prisma")
            -- As faixas dão contornos irregulares à lâmina. O piso transparente mantém o apoio do jogador.
            for _, band in {{-0.5, -0.31, 0.49, -0.13}, {-0.31, -0.12, 0.79, -0.08},
                {-0.12, 0.17, 1, 0}, {0.17, 0.34, 0.84, 0.10}, {0.34, 0.5, 0.54, 0.12}} do
                local leftZ, rightZ = z + band[1] * length, z + band[2] * length
                local waterX, waterW = center + side * band[4] * width, band[3] * width
                floor(west, waterX - waterW / 2, leftZ, rightZ)
                floor(waterX + waterW / 2, east, leftZ, rightZ)
                local bandZ, bandLength = (leftZ + rightZ) / 2, rightZ - leftZ
                box(pool, "Apoio sob a água", waterX, plane - 0.42, bandZ, waterW, 0.84, bandLength, color, "sidewalk",
                    {transparency = 1, shadow = false})
                box(pool, "Lâmina no passeio", waterX, plane + 0.011, bandZ, waterW, 0.022, bandLength, rgb(69, 96, 124), "puddle",
                    {collision = false, shadow = false, transparency = 0.47, reflectance = 0.57})
            end
            local marker = box(pool, "Poça", center, plane, z, width + 0.22, 0.022, length, rgb(69, 96, 124), "puddle",
                {collision = false, shadow = false, transparency = 1})
            marker:SetAttribute("CyberOutlawPlano", plane)
            marker:SetAttribute("MarePocaPasseio", true)
            ctx.reflection(marker)
            table.insert(mirrors, marker)
            wetGlint(pool, "Z", z, center, -length * 0.04, side * 0.81, {length * 0.60, 0.46}, wetHighlight, 0.80, plane + 0.027)
            wetGlint(pool, "Z", z, center, length * 0.16, -side * 0.60, {length * 0.25, 0.34}, wetCyan, 0.67, plane + 0.034)
            wetGlint(pool, "Z", z, center, -length * 0.13, -side * 0.65, {length * 0.18, 0.28}, wetAmber, 0.70, plane + 0.039)
            last = z + length / 2
        end
        floor(west, east, last, endZ)
    end

    for row = 1, layout.rows do
        local z0 = -layout.halfZ + (row - 1) * layout.pitch
        local z1 = z0 + layout.pitch
        local center = (z0 + z1) / 2
        local wetWalk = layout.prismaBanks[row]
        local basin = group(canals, string.format("Cais %02d", row))
        box(basin, "Fundação do leito", 0, -9, center, layout.canalWidth, 2.3, layout.pitch, rgb(23, 33, 51), "cement")
        box(basin, "Espelho de água do canal", 0, -3.28, center, layout.canalWidth - 0.3, 0.12, layout.pitch, rgb(36, 54, 72), "water",
            {collision = false, transparency = 0.24, reflectance = 0.44})
        for _, side in {-1, 1} do
            box(basin, "Muro de contenção", side * 28, -4.34, center, 5.7, 8.12, layout.pitch, rgb(64, 75, 92), "cement")
            for i = 1, 12 do
                local seam = z0 + 10 + i * 18
                box(basin, "Junta vertical do cais", side * 25.03, -4.52, seam, 0.15, 7.0, 0.18, ink, "cement", paint)
            end
            local walkStart = z0 + (if layout.bridgeRows[z0] == "foot" then layout.footWidth / 2 else layout.avenueWidth(z0) / 2)
            local walkEnd = z1 - (if layout.bridgeRows[z1] == "foot" then layout.footWidth / 2 else layout.avenueWidth(z1) / 2)
            quayWalk(basin, side * layout.quayX, walkStart, walkEnd, side, wetWalk)
            local first = walkStart + (if layout.bridgeRows[z0] == "foot" then 0 else 6.4)
            local last = walkEnd - (if layout.bridgeRows[z1] == "foot" then 0 else 6.4)
            bankRail(basin, side * 29.4, first, last, 0.03, gray)
            for localZ = -78, 79, 52 do
                local hue = if (row + side + localZ) % 3 == 0 then rose else cyan
                local height = if wetWalk then 3.79 else 1.52
                box(basin, "Balizador ribeirinho", side * 31.2, 0.01 + height / 2, center + localZ, 0.48, height, 0.48,
                    gray, "metal")
                local lens = box(basin, "Friso do balizador", side * 31.2, height - 0.08, center + localZ, 0.50, 0.18, 0.50, hue, "neon", paint)
                if wetWalk then
                    -- A luz da lente chega ao passeio dos dois lados do balizador.
                    ctx.lamp(lens, quayFill, 27, 1.28)
                end
                for j = 1, 5 do
                    local length = rng:NextNumber(4.6, 18) * (1.14 - j * 0.13)
                    local reflected = box(basin, "Reflexo no canal", side * (23 - j * 1.46), -3.198 + j * 0.002,
                        center + localZ + (j - 2) * 1.71, 0.36 + j * 0.21, 0.012, length, hue, "neon",
                        {collision = false, shadow = false, transparency = 0.54 + j * 0.081})
                    reflected:SetAttribute("MareBrilhoPiso", true)
                end
            end
        end
    end

    for row = 0, layout.rows do
        local z = -layout.halfZ + row * layout.pitch
        local kind = layout.bridgeRows[z]
        local central = math.abs(z) <= layout.pitch
        local spanWidth = if kind == "foot" then layout.footWidth else layout.avenueWidth(z)
        local bridge = group(canals, (if kind == "foot" then "Passarela " else "Ponte ") .. tostring(z))
        box(bridge, "Laje da travessia", 0, -0.67, z, bank * 2, 0.80, spanWidth, roadway,
            if kind == "foot" then "sidewalk" else "asphalt")
        if kind == "foot" then
            for _, side in {-1, 1} do
                local width = layout.avenueWidth(z)
                box(bridge, "Calçada de conexão", side * 42, -0.307, z, 9.4, 0.69, spanWidth + 6, paving, "sidewalk")
                for offset = -width / 2 + 3, width / 2 - 2, 5.5 do
                    if math.abs(offset) < 7.8 then continue end
                    box(bridge, "Bloco de proteção viária", side * 42.9, 0.61, z + offset, 1.6, 1.66, 3.6,
                        rgb(108, 94, 82), "cement")
                end
                for localX = 31, 38, 7 do
                    box(bridge, "Pilarete de acesso pedonal", side * localX, 1.15, z - side * 2.62, 0.58, 1.75, 0.58, gray, "metal")
                end
            end
        end
        for _, side in {-1, 1} do
            local edge = z + side * (spanWidth / 2 + (if kind == "foot" then 0 else 3.45))
            if kind == "road" then
                box(bridge, "Passeio da ponte", 0, -0.32, edge, bank * 2, 0.77, 6.9, paving, "sidewalk")
            end
            local railing = edge + side * (if kind == "foot" then 0 else 3.0)
            box(bridge, "Viga de borda", 0, -0.94, railing, bank * 2, 1.25, 0.87, gray, "steel")
            box(bridge, "Corrimão da ponte", 0, 3.10, railing, bank * 2, 0.26, 0.36, ink, "steel", paint)
            box(bridge, "Limite de proteção", 0, 1.5, railing, bank * 2, 3.0, 0.26, gray, "steel",
                {transparency = 1, shadow = false})
            for x = -39, 41, 8 do
                box(bridge, "Montante de travessia", x, 1.57, railing, 0.42, 3.16, 0.42, gray, "metal", paint)
                box(bridge, "Detalhe frio da ponte", x, -1.34, railing + side * 0.48, 3.45, 0.19, 0.18, cyan, "neon", paint)
                if central and (x == -23 or x == 25) then
                    local guide = box(bridge, "Lente do guarda-corpo", x, 2.67, railing - side * 0.31, 0.52, 0.29, 0.25,
                        bridgeFill, "neon", paint)
                    ctx.lamp(guide, bridgeFill, 24, 1.34)
                end
                if math.abs(x) < 24 then
                    box(bridge, "Luz refletida sob a água", x, -5.10, railing + side * 0.48,
                        3.47, 0.19, 0.27, cyan, "neon", {collision = false, shadow = false, transparency = 0.64})
                end
            end
            for x = -34, 37, 14 do
                local a = Vector3.new(x, -0.85, railing)
                local b = Vector3.new(x + 7, -2.83, railing)
                local c = Vector3.new(x + 14, -0.85, railing)
                ctx.beam(bridge, "Treliça inferior", a, b, 0.39, 0.42, gray, "steel", paint)
                ctx.beam(bridge, "Treliça inferior", b, c, 0.39, 0.42, gray, "steel", paint)
            end
        end
        if kind == "road" then
            for x = -29, 30, 15 do
                box(bridge, "Separação de tráfego", x, -0.242, z, 5.25, 0.034, 0.32, rgb(184, 149, 74), "paint", paint)
            end
        end
    end

    local limit = group(city, "Contorno urbano")
    for _, side in {-1, 1} do
        for i = 0, layout.rows - 1 do
            local x, z = side * (layout.halfX + 26), -layout.halfZ + (i + 0.5) * layout.pitch
            box(limit, "Faixa de serviço externa", side * (layout.halfX + 16), -0.75, z, 33, 0.8, layout.pitch, roadway, "asphalt")
            box(limit, "Parede de infraestrutura", x, 4.8, z, 3.4, 12.2, layout.pitch, rgb(65, 71, 91), "cement")
            box(limit, "Pingadeira metálica", x, 11, z, 4.5, 0.62, layout.pitch, gray, "steel")
        end
        for i = 0, layout.columns - 1 do
            local x, z = -layout.halfX + (i + 0.5) * layout.pitch, side * (layout.halfZ + 28)
            box(limit, "Faixa de serviço externa", x, -0.75, side * (layout.halfZ + 18), layout.pitch, 0.8, 36, roadway, "asphalt")
            box(limit, "Terminal de infraestrutura", x, 4.8, z, layout.pitch, 12.2, 3.4, rgb(65, 71, 91), "cement")
            box(limit, "Pingadeira metálica", x, 11, z, layout.pitch, 0.62, 4.5, gray, "steel")
        end
        box(limit, "Fechamento do canal", 0, -5.25, side * (layout.halfZ + 8), layout.canalWidth, 9.6, 5, gray, "cement")
        for _, other in {-1, 1} do
            local x, z = side * (layout.halfX + 13), other * (layout.halfZ + 14)
            box(limit, "Piso da quina", x, -0.75, z, 27, 0.8, 28, roadway, "asphalt")
            box(limit, "Travessa do limite", side * (layout.halfX + 26), 4.80, z, 3.4, 12.2, 28.9, gray, "cement")
            box(limit, "Travessa do limite", x, 4.80, other * (layout.halfZ + 28), 28.9, 12.2, 3.4, gray, "cement")
        end
    end
    return mirrors
end

return Streets
