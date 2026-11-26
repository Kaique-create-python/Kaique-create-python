local Transit = {}

function Transit.build(ctx, city, layout)
    local rgb, group, box = ctx.rgb, ctx.group, ctx.box
    local line = group(city, "Monotrilho · Linha 07")
    local navy = rgb(34, 43, 60)
    local iron = rgb(57, 64, 78)
    local silver = rgb(117, 122, 138)
    local concrete = rgb(84, 86, 105)
    local darkGlass = rgb(65, 94, 128)
    local cyan = rgb(90, 224, 239)
    local warm = rgb(255, 194, 130)
    local finish = {collision = false, shadow = false}
    local transparent = {collision = false, transparency = 0.28, reflectance = 0.20}
    local stage = layout.deck + 0.8

    for ix = 0, layout.columns * 2 - 1 do
        local left = -layout.halfX + ix * (layout.pitch / 2)
        local span = layout.pitch / 2
        local x = left + span / 2
        local bay = group(line, "Vão " .. tostring(ix + 1))
        box(bay, "Laje elevada", x, 25.65, 0, span, 3.1, 20.5, concrete, "cement")
        box(bay, "Base do pilar", x, 0.50, 0, 6.9, 1.7, 7.0, navy, "cement")
        box(bay, "Pilar em concreto armado", x, 11.9, 0, 4.1, 24.3, 4.6, concrete, "cement")
        box(bay, "Capitel", x, 23.3, 0, 8.8, 2.05, 7.6, concrete, "cement")
        for _, side in {-1, 1} do
            box(bay, "Viga longitudinal", x, 24.55, side * 9.6, span, 1.66, 1.13, iron, "steel")
            box(bay, "Perfil metálico de manutenção", x, 27.13, side * 10.25, span, 0.56, 0.61, navy, "steel")
            box(bay, "Feixe de cabos", x, 24.17, side * 10.23, span, 0.18, 0.23, navy, "rubber", finish)
            box(bay, "Guia central", x, 27.32, side * 4.43, span, 0.22, 0.51, silver, "metal", finish)
            for tie = -52, 54, 8 do
                box(bay, "Dormente", x + tie, 27.25, side * 4.45, 0.62, 0.21, 3.46, navy, "rubber", finish)
            end
            if ix % 2 == 0 then
                local led = box(bay, "Luz sob o viaduto", x, 23.81, side * 8.30, 16.55, 0.17, 0.30, cyan, "neon", finish)
                if math.abs(x) <= 600 then
                    ctx.lamp(led, cyan, 30, 0.96, "Bottom")
                end
            end
            for strip = -1, 1, 2 do
                box(bay, "Linha de condução", x, 27.52, side * 4.45 + strip * 1.52, span, 0.27, 0.29, silver,
                    "metal", finish)
            end
        end
    end

    local station = group(line, "Estação do Dique")
    local stationX = layout.stationX
    local platforms = {}
    for _, side in {-1, 1} do
        local section = group(station, if side < 0 then "Plataforma norte" else "Plataforma sul")
        platforms[side] = section
        local z = side * 17.8
        box(section, "Laje de embarque", stationX, stage - 0.62, z, 145, 1.24, 14.6, concrete, "cement")
        box(section, "Piso cinza da plataforma", stationX, stage + 0.035, z, 145, 0.07, 14.5, silver, "tile", finish)
        box(section, "Faixa tátil de embarque", stationX, stage + 0.09, side * 11.23, 142, 0.08, 0.74,
            rgb(218, 171, 72), "tile", finish)
        if side < 0 then
            box(section, "Soleira da plataforma", stationX, stage - 0.12, -9.55, 145, 0.4, 2,
                silver, "steel", {shadow = false})
        end
        box(section, "Viga externa", stationX, stage - 0.83, side * 25.14, 145, 2.05, 1.20, navy, "steel")
        box(section, "Cobertura contínua", stationX, 43.12, z, 143, 0.88, 16.45, iron, "roof")
        box(section, "Perfil luminoso da cobertura", stationX, 42.6, side * 24.12, 143, 0.15, 0.26, cyan, "neon", finish)
        for xx = stationX - 67, stationX + 68, 16 do
            local nearStair = math.abs(xx - (stationX - 17)) < 6.5 or math.abs(xx - (stationX + 17)) < 6.5
            box(section, "Coluna da marquise", xx, 35.1, side * (if nearStair then 22.1 else 24.4), 0.55, 14.6, 0.55, iron, "steel")
            box(section, "Joelho sob a cobertura", xx, 41.87, z, 0.7, 0.32, 14.15, silver, "steel")
            if math.abs(xx + 6 - (stationX - 17)) >= 12 and math.abs(xx + 6 - (stationX + 17)) >= 12 then
                box(section, "Aba superior da divisória", xx + 6.0, 30.41, side * 24.42, 10.4, 0.24, 0.25, iron, "metal")
                box(section, "Anteparo da plataforma", xx + 6.0, 29.2, side * 24.5, 10.3, 2.52, 0.22, darkGlass,
                    "glass", {transparency = 0.40, reflectance = 0.16})
            end
        end

        local hall = group(section, "Acesso ao nível da rua")
        box(hall, "Piso do acesso", stationX, -0.11, side * 66.2, 90, 0.30, 38.0, concrete, "tile")
        box(hall, "Travessa do acesso", stationX, 10.7, side * 84.2, 90.0, 1.05, 1.8, iron, "steel")
        box(hall, "Cobertura do acesso", stationX, 12.76, side * 75.0, 89.65, 0.61, 18.2, iron, "roof")
        box(hall, "Aba do acesso", stationX, 12.34, side * 83.82, 90.0, 0.35, 1.58, cyan, "neon", finish)
        for i = -2, 2 do
            box(hall, "Coluna da bilheteria", stationX + i * 20.2, 5.25, side * 83.75, 1.25, 10.8, 1.27, iron, "steel")
        end
        for _, offset in {-25, 25} do
            local boothX = stationX + offset
            box(hall, "Guichê em aço", boothX, 1.98, side * 74.8, 7.7, 3.80, 3.30, navy, "steel")
            box(hall, "Balcão do guichê", boothX, 4.01, side * 74.8, 8.12, 0.28, 3.51, silver, "metal")
            box(hall, "Vidro do guichê", boothX, 5.65, side * 73.3, 7.6, 3.16, 0.28, darkGlass, "glass", transparent)
            local lamp = box(hall, "Lâmpada do guichê", boothX, 9.97, side * 76.6, 6.85, 0.18, 0.46, warm, "neon", finish)
            ctx.lamp(lamp, warm, 20, 1.15, "Bottom")
            for bolt = -1, 1, 2 do
                box(hall, "Fixação do balcão", boothX + bolt * 2.66, 3.40, side * 76.46, 0.17, 0.22, 0.11, iron,
                    "metal", finish)
            end
        end

        for _, offset in {-17, 17} do
            local entranceX = stationX + offset
            local staircase = group(section, "Escada de acesso")
            local steps = 38
            local startY = 0.12
            local run = 1.05
            local rise = (stage - startY) / steps
            local startZ, endZ = side * (24.95 + steps * run), side * 24.95
            for i = 1, steps do
                local treadZ = startZ - side * ((i - 0.5) * run)
                local treadY = startY + (i - 0.5) * rise
                box(staircase, "Pisada metálica", entranceX, treadY - 0.35, treadZ, 11.92, 0.70, run + 0.035, iron, "steel", finish)
                box(staircase, "Nariz da escada", entranceX, treadY + 0.01, treadZ + side * 0.42, 11.85, 0.045, 0.11,
                    rgb(168, 143, 94), "paint", finish)
                if i % 6 == 0 or i == 1 or i == steps then
                    for _, rail in {-1, 1} do
                        box(staircase, "Suporte do corrimão", entranceX + rail * 6, treadY + 1.35, treadZ, 0.25, 2.7, 0.33,
                            silver, "metal", finish)
                    end
                end
            end
            local midpoint = (startZ + endZ) / 2
            local angle = math.atan2(stage - startY, endZ - startZ)
            local pitch = if math.abs(angle) > math.pi / 2 then angle - math.pi else angle
            local length = math.sqrt((endZ - startZ)^2 + (stage - startY)^2)
            box(staircase, "Colisão contínua da escada", entranceX, (startY + stage) / 2 - 0.28, midpoint, 11.9, 0.56,
                length, navy, "metal",
                {pitch = math.deg(-pitch), transparency = 1, shadow = false})
            for _, rail in {-1, 1} do
                local start = Vector3.new(entranceX + rail * 6.05, startY + 2.85, startZ)
                local last = Vector3.new(entranceX + rail * 6.05, stage + 2.85, endZ)
                ctx.beam(staircase, "Corrimão metálico", start, last, 0.34, 0.33, silver, "steel")
                ctx.beam(staircase, "Proteção lateral", start - Vector3.new(0, 1.40, 0), last - Vector3.new(0, 1.40, 0),
                    0.20, 2.85, navy, "steel", {transparency = 1, shadow = false})
            end
        end

        local sign = box(hall, "Fachada da estação", stationX, 8.31, side * 84.31, 36.5, 3.33, 0.38, navy, "metal", finish)
        ctx.sign(sign, if side < 0 then "Front" else "Back", "ESTAÇÃO DO DIQUE", cyan)
        local destination = box(section, "Painel de embarque", stationX, 37.71, z, 23.02, 2.16, 0.28, navy, "metal", finish)
        ctx.sign(destination, if side < 0 then "Front" else "Back", "LINHA 07", warm)
    end

    local north = platforms[-1]
    local function lift(parent, floorY, z, destination, text)
        local pad = box(parent, "Plataforma do elevador", stationX, floorY + 0.15, z, 5.9, 0.3, 5.9, navy, "metal")
        pad.CanTouch = true
        pad:SetAttribute("Destino", destination)
        box(parent, "Luz do elevador", stationX, floorY + 0.315, z, 5.8, 0.03, 0.28, cyan, "neon", finish)
        local panel = box(parent, "Letreiro do elevador", stationX, floorY + 4.5, z + 3.05, 6.2, 1.9, 0.3,
            navy, "metal", finish)
        ctx.sign(panel, "Front", text, cyan)
        return pad
    end
    local street = north:FindFirstChild("Acesso ao nível da rua")
    local up = lift(street, layout.walkY, -66, Vector3.new(stationX, stage + 3.5, -13.75), "ELEVADOR · PLATAFORMA")
    local down = lift(north, stage, -20.8, Vector3.new(stationX, layout.walkY + 3.5, -78.5), "ELEVADOR · RUA")
    return {up, down}
end

return Transit
