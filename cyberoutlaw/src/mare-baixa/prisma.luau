local Prisma = {}

local function marketFront(ctx, city)
    local box, rgb = ctx.box, ctx.rgb
    local market = ctx.group(city, "Bancas cobertas do Prisma")
    local trim = {collision = false, shadow = false}
    local steel, concrete, warm = rgb(58, 74, 77), rgb(125, 117, 111), rgb(248, 199, 139)
    for index, site in {
        {-105.2, -109.8, 12.6, 11.5, 7.52, rgb(111, 78, 69), rgb(65, 109, 118)},
        {-87.1, -121.9, 10.8, 10.3, 8.75, rgb(62, 97, 96), rgb(156, 119, 77)},
        {-99.1, -133.2, 13.65, 9.5, 6.86, rgb(99, 95, 94), rgb(122, 82, 109)},
    } do
        local x, z, width, depth, height, roof, cloth = table.unpack(site)
        local kiosk = ctx.group(market, ({"Banca de mantimentos", "Banca de cabos", "Banca de ferramentas"})[index])
        local street = z + depth / 2
        box(kiosk, "Piso de cimento", x, 0.07, z, width + 0.5, 0.14, depth + 0.6, concrete, "cement")
        box(kiosk, "Fundo da banca", x, height * 0.41, z - depth / 2, width, height * 0.80, 0.36, steel, "metal")
        box(kiosk, "Painel lateral da banca", x + width / 2 - 0.12, height * 0.41, z - 0.92,
            0.32, height * 0.79, depth - 1.9, roof, if index == 2 then "metal" else "brick")
        for _, side in {-1, 1} do
            box(kiosk, "Coluna do balcão", x + side * (width / 2 - 0.28), height * 0.47, street - 0.14,
                0.53, height * 0.93, 0.53, steel, "steel")
        end
        box(kiosk, "Chapa de cobertura", x, height, z, width + 1.29, 0.29, depth + 2.0, roof, "roof", {pitch = (index - 2) * 4})
        for step = -width / 2 + 0.4, width / 2, 1.62 do
            box(kiosk, "Costura metálica do telhado", x + step, height + 0.17, z, 0.15, 0.16, depth + 1.91, steel,
                "metal", {pitch = (index - 2) * 4, collision = false, shadow = false})
        end
        box(kiosk, "Toldo recuado", x, height - 0.69, street + 0.46, width + 0.78, 0.18, 3.38, cloth, "fabric", {pitch = 12})
        box(kiosk, "Balcão da banca", x + width * 0.07, 1.72, street - 0.92, width * 0.71, 3.33, 1.21, cloth, "tile")
        box(kiosk, "Tampo da banca", x + width * 0.07, 3.42, street - 0.92, width * 0.75, 0.21, 1.65, concrete, "stone")
        for row = 1, 2 do
            box(kiosk, "Prateleira da banca", x, 2.26 + row * 1.36, z - depth / 2 + 0.69, width - 1.3, 0.22, 1.34, steel, "metal", trim)
            for column = 1, 3 do
                box(kiosk, "Caixa de mercadoria", x + (column - 2) * width * 0.23, 2.64 + row * 1.36, z - depth / 2 + 0.61,
                    1.27 + column * 0.12, 0.58, 0.81, if (column + row) % 2 == 0 then cloth else roof, "wood", trim)
            end
        end
        local light = box(kiosk, "Difusor sob o toldo", x + 0.2, height - 1.21, street + 0.66, width - 2.6, 0.15, 0.42, warm, "neon", trim)
        ctx.lamp(light, warm, 16, 1.34, "Bottom")
        if index == 2 then
            box(kiosk, "Chaminé de aço", x + 2.7, height + 0.62, z - 1.4, 1.48, 0.75, 0.79, steel, "metal", {shape = "Cylinder", roll = 90})
            local vent = box(kiosk, "Boca da chaminé", x + 2.7, height + 1.34, z - 1.4, 0.18, 0.99, 0.97, steel,
                "metal", {shape = "Cylinder", roll = 90, collision = false, shadow = false})
            vent:AddTag("CyberOutlawVaporUrbano")
        end
    end
    for _, dx in {-99.6, -98.8} do
        ctx.beam(market, "Rede aparente sobre as bancas", Vector3.new(dx, 10.72, -104.7), Vector3.new(dx + 3.6, 9.72, -139.7),
            0.37, 0.39, steel, "metal", trim)
    end
end

local function entreposto(ctx, city)
    local box, rgb = ctx.box, ctx.rgb
    local model = ctx.group(city, "Entreposto do Prisma")
    local weathered, ink, steel = rgb(103, 110, 116), rgb(35, 54, 62), rgb(79, 99, 108)
    local ochre, green, brass = rgb(161, 110, 49), rgb(60, 99, 92), rgb(216, 164, 81)
    local aqua, warm = rgb(143, 225, 237), rgb(255, 203, 149)
    local trim = {collision = false, shadow = false}
    local x, z = 119, -132
    box(model, "Laje de distribuição", x, 15.62, z, 54, 2.0, 55, weathered, "cement")
    box(model, "Parede do fundo do entreposto", 144.4, 7.48, z, 2.7, 14.9, 52.3, ink, "cement")
    for _, dz in {-156.35, -132, -108.3} do
        box(model, "Pilar do passeio industrial", 96.18, 7.56, dz, 3.18, 15.1, 3.55, weathered, "cement")
        box(model, "Chapa curva junto ao pilar", 94.47, 8.16, dz, 0.38, 7.11, 3.82, ochre, "metal", trim)
    end
    for _, dz in {-145, -119.5} do
        box(model, "Caixa de ventilação do térreo", 104.1, 10.22, dz, 11.9, 8.29, 19.9, steel, "cement")
        box(model, "Calha recolhida do pórtico", 95.03, 8.47, dz, 1.10, 1.97, 20.1, ink, "steel")
        local lamp = box(model, "Difusor do pórtico", 95.04, 7.4, dz, 0.61, 0.15, 17.1, warm, "neon", trim)
        ctx.lamp(lamp, warm, 24, 1.57, "Bottom")
        for i = 1, 5 do
            box(model, "Aleta das aberturas técnicas", 97.98, 11.13 + i * 0.47, dz, 0.47, 0.17, 17.86, ink, "metal", trim)
        end
    end
    box(model, "Pala de carga em balanço", 92.8, 13.8, z, 12.2, 1.26, 50.2, ochre, "metal")
    box(model, "Arremate grosso da pala", 86.67, 13.92, z, 0.62, 1.69, 50.5, steel, "steel", trim)
    box(model, "Farol contínuo da marquise", 87.16, 13.17, z, 0.24, 0.18, 36.41, aqua, "neon", trim)

    box(model, "Torre de carga", 121.8, 65.35, -136, 37.8, 97.45, 43.3, ink, "cement")
    box(model, "Anexo de filtros e ventilação", 130.0, 40.07, -110.5, 28.5, 46.90, 18.8, green, "cement")
    box(model, "Terraço do anexo", 130.0, 63.9, -109.7, 31.6, 0.95, 24.3, ochre, "metal")
    for _, dz in {-155.7, -142.1, -130, -116.1} do
        box(model, "Prumada de concreto", 102.42, 64.83, dz, 2.89, 95.6, 2.2, weathered, "cement")
    end
    local glassColors = {rgb(60, 89, 98), rgb(69, 101, 103), rgb(72, 88, 95), rgb(94, 110, 107)}
    for tier = 1, 10 do
        local y = 18.9 + tier * 8.75
        for bay, dz in {-148.7, -136.3, -123.0} do
            local occupied = (tier * 3 + bay) % 11 == 0
            local panelColor = if occupied then rgb(154, 125, 84) else glassColors[(tier + bay * 2) % #glassColors + 1]
            box(model, "Janela recuada do entreposto", 102.72, y + 3.06, dz, 0.25, 4.72, 9.56, panelColor,
                if occupied then "neon" else "glass", trim)
            box(model, "Divisor do vidro", 102.53, y + 3.06, dz + bay * 0.81 - 1.52, 0.42, 4.92, 0.32, ink, "steel", trim)
        end
        box(model, "Travessa do piso", 102.7, y - 0.15, -135.8, 1.23, 1.63, 41.4, if tier % 3 == 0 then ochre else steel, "steel", trim)
    end
    for level = 0, 2 do
        local lower = 27 + level * 24.8
        ctx.beam(model, "Contravento externo da torre", Vector3.new(100.37, lower, -151.9),
            Vector3.new(100.37, lower + 23.5, -123.14), 1.04, 1.17, steel, "steel", trim)
        ctx.beam(model, "Contravento externo da torre", Vector3.new(100.37, lower + 23.5, -151.9),
            Vector3.new(100.37, lower, -123.14), 1.04, 1.17, steel, "steel", trim)
    end
    for y = 25, 59, 7.8 do
        box(model, "Grelha modular de filtro", 114.32, y, -108.8, 0.45, 4.75, 13.73, steel, "metal", trim)
        box(model, "Travessa do anexo", 113.97, y - 2.58, -108.7, 1.31, 0.52, 17.89, brass, "metal", trim)
    end
    box(model, "Duto duplo da fachada", 100.25, 61.2, -154.47, 1.2, 76.3, 2.19, ochre, "metal", trim)
    box(model, "Lâmina luminosa de sinalização", 100.32, 78.52, -116.71, 0.55, 52.1, 1.2, aqua, "neon", trim)
    local decks = {{121.0, 114.15, -134.4, 51.3, 49.3}, {123.3, 116.63, -137.1, 48.37, 39.81}, {126.2, 119.08, -139.35, 38.42, 31.23}}
    for index, layer in decks do
        local tx, ty, tz, width, depth = table.unpack(layer)
        box(model, "Cobertura escalonada em balanço", tx, ty, tz, width, 1.48, depth, if index == 2 then weathered else steel, "roof")
        box(model, "Borda técnica exposta", tx - width / 2 + 0.16, ty - 0.17, tz, 0.35, 1.56, depth + 0.27, ink, "steel", trim)
    end
    box(model, "Bloco de exaustão na cobertura", 130.8, 121.69, -142.1, 15.88, 3.42, 12.97, green, "cement")
    box(model, "Torre de comunicação", 124.92, 129.17, -141.6, 1.18, 18.52, 1.34, steel, "steel")
    for index = 1, 3 do
        box(model, "Travessa da antena", 124.92, 123.46 + index * 3.23, -141.6, 5.89 - index * 0.55, 0.48, 1.45, steel, "steel", trim)
    end
    box(model, "Luz alta de segurança", 124.92, 138.61, -141.6, 0.62, 0.55, 0.60, rgb(239, 66, 75), "neon", trim)
    local vent = box(model, "Exaustor do pórtico", 103.86, 19.57, -109.83, 0.53, 2.11, 2.25, steel, "metal", {shape = "Cylinder", roll = 90})
    box(model, "Corpo do tubo de exaustão", 103.86, 18.15, -109.83, 2.7, 1.41, 1.63, ochre, "metal", {shape = "Cylinder", roll = 90})
    vent:AddTag("CyberOutlawVaporUrbano")
end

function Prisma.build(ctx, city, layout)
    local rgb, box, group = ctx.rgb, ctx.box, ctx.group
    local steel, ink = rgb(83, 106, 124), rgb(35, 46, 59)
    local concrete, bronze = rgb(103, 109, 117), rgb(169, 141, 96)
    local petrol, brick = rgb(44, 104, 112), rgb(119, 75, 65)
    local warm, cool = rgb(255, 211, 162), rgb(126, 227, 243)
    local trim = {collision = false, shadow = false}
    local hidden = {transparency = 1, shadow = false}
    local crossing = layout.prismaCrossing
    local z, deck, x = crossing.z, crossing.deck, crossing.x
    local halfWidth, halfSpan = 4.5, x + 4
    local stairWidth, landingDepth = 6.8, 2.2
    local bridge = group(city, "Passarela do Dique")
    local landingZ = z + halfWidth + landingDepth

    box(bridge, "Piso da passarela", 0, deck - 0.38, z, halfSpan * 2, 0.76, halfWidth * 2, concrete, "sidewalk")
    for _, side in {-1, 1} do
        local edge = z + side * (halfWidth - 0.17)
        local span = if side == -1 then halfSpan * 2 else x * 2 - stairWidth
        box(bridge, "Viga da borda", 0, deck - 0.9, edge, halfSpan * 2, 0.64, 0.62, ink, "steel")
        box(bridge, "Limite do guarda-corpo", 0, deck + 1.6, edge, span, 3.2, 0.26, steel, "steel", hidden)
        box(bridge, "Corrimão da passarela", 0, deck + 3.04, edge, span, 0.23, 0.36, bronze, "metal", trim)
        box(bridge, "Tela de proteção", 0, deck + 1.44, edge, span, 2.44, 0.13, rgb(62, 102, 115), "glass",
            {transparency = 0.72, collision = false, shadow = false})
        for along = -span / 2 + 1.85, span / 2 - 1.7, 6.6 do
            box(bridge, "Montante da passarela", along, deck + 1.52, edge, 0.35, 3.04, 0.32, steel, "steel", trim)
        end
        box(bridge, "Reforço do vão", 0, deck - 1.26, z + side * 3.38, 87.5, 0.51, 0.51, steel, "steel", trim)
        for along = -33, 34, 22 do
            local led = box(bridge, "Luminária sob o tabuleiro", along, deck - 1.25, z + side * 3.08,
                7.9, 0.16, 0.46, if side < 0 then cool else warm, "neon", trim)
            ctx.lamp(led, if side < 0 then cool else warm, 21, 1.23, "Bottom")
        end
    end

    for _, bank in {-1, 1} do
        local stairX = bank * x
        box(bridge, "Limite do extremo da passarela", bank * (halfSpan - 0.13), deck + 1.55, z + 1.1,
            0.27, 3.1, halfWidth * 2 + landingDepth, steel, "steel", hidden)
        for _, edge in {-1, 1} do
            local pillarZ = z + edge * 3.42
            box(bridge, "Apoio de concreto da passarela", bank * 42.9, 4.9, pillarZ, 1.48, 9.8, 1.55, concrete, "cement")
            box(bridge, "Travessa do apoio", bank * 42.9, deck - 1.02, pillarZ, 3.7, 0.65, 2.36, steel, "steel")
            ctx.beam(bridge, "Mão francesa da travessia", Vector3.new(bank * 42.9, 7, pillarZ),
                Vector3.new(bank * 35, deck - 0.74, pillarZ), 0.52, 0.7, steel, "steel", trim)
        end
        box(bridge, "Patamar da escada", stairX, deck - 0.29, landingZ - landingDepth / 2,
            stairWidth, 0.58, landingDepth, concrete, "sidewalk")
        local steps, tread = 22, 1.05
        local rise = (deck - layout.walkY) / steps
        local footZ = landingZ + steps * tread
        for step = 1, steps do
            local stairZ = landingZ + (steps - step + 0.5) * tread
            local top = layout.walkY + step * rise
            box(bridge, "Degrau da passarela", stairX, top - 0.32, stairZ, stairWidth, 0.64, tread + 0.012, concrete, "cement")
            box(bridge, "Nariz antiderrapante", stairX, top + 0.012, stairZ + tread * 0.41,
                stairWidth - 0.32, 0.022, 0.10, if step % 5 == 0 then bronze else ink, "metal", trim)
        end
        for _, edge in {-1, 1} do
            local railX = stairX + edge * (stairWidth / 2 - 0.12)
            local lower = Vector3.new(railX, layout.walkY, footZ)
            local upper = Vector3.new(railX, deck, landingZ)
            local rail = Vector3.new(0, 2.95, 0)
            ctx.beam(bridge, "Proteção lateral da escada", lower + rail / 2, upper + rail / 2, 0.22, 3.38, steel, "steel", hidden)
            ctx.beam(bridge, "Corrimão da escada", lower + rail, upper + rail, 0.44, 0.22, bronze, "steel", trim)
            ctx.beam(bridge, "Longarina da escada", lower - Vector3.new(0, 0.16, 0), upper - Vector3.new(0, 0.16, 0),
                0.54, 0.69, ink, "steel", trim)
            box(bridge, "Proteção do patamar", railX, deck + 1.52, landingZ - landingDepth / 2, 0.24, 3.04,
                landingDepth, steel, "steel", hidden)
            box(bridge, "Corrimão do patamar", railX, deck + 3.0, landingZ - landingDepth / 2, 0.27, 0.24,
                landingDepth, bronze, "steel", trim)
            for _, t in {0.12, 0.37, 0.63, 0.88} do
                local at = lower:Lerp(upper, t)
                box(bridge, "Pilar do corrimão da escada", at.X, at.Y + 1.58, at.Z, 0.36, 2.94, 0.33, steel, "steel", trim)
            end
        end
        local light = box(bridge, "Balizador do primeiro degrau", stairX + bank * 3.2, 2.20, footZ - 0.9,
            0.32, 0.49, 0.7, warm, "neon", trim)
        ctx.lamp(light, warm, 19, 1.46)
    end

    for _, along in {-31, -15, 5, 23} do
        local arch = group(bridge, "Pórtico de aço e vidro")
        for _, side in {-1, 1} do
            box(arch, "Pilar do pórtico", along, deck + 3.78, z + side * 4.12, 0.61, 7.56, 0.63, ink, "steel", trim)
            ctx.beam(arch, "Diagonal no alto", Vector3.new(along, deck + 5.38, z + side * 4.12),
                Vector3.new(along, deck + 7.56, z + side * 2.1), 0.37, 0.39, steel, "steel", trim)
        end
        box(arch, "Travessa da cobertura", along, deck + 7.58, z, 0.38, 0.57, 8.84, steel, "steel", trim)
        local fitting = box(arch, "Difusor suspenso", along, deck + 7.15, z + 0.5, 0.26, 0.15, 3.7, warm, "neon", trim)
        ctx.lamp(fitting, warm, 17, 1.1, "Bottom")
    end
    for _, wing in {{-23, 16}, {14, 18}} do
        box(bridge, "Vidro canelado da cobertura", wing[1], deck + 7.98, z, wing[2], 0.23, 8.95, rgb(62, 119, 139),
            "glass", {transparency = 0.32, collision = false, shadow = false})
        for _, side in {-1, 1} do
            box(bridge, "Calha estreita da cobertura", wing[1], deck + 7.91, z + side * 4.45,
                wing[2] + 0.36, 0.3, 0.38, ink, "metal", trim)
        end
    end
    box(bridge, "Duto de manutenção sobre o Dique", -4, deck + 7.25, z - 4.26, 76, 0.52, 0.57, petrol, "metal", trim)

    local fronts = group(city, "Comércio da Passarela do Dique")
    local workshop = group(fronts, "Oficina da comporta")
    box(workshop, "Painel de alvenaria da oficina", -66.6, 4.9, -125.4, 0.62, 9.55, 5.2, brick, "brick")
    box(workshop, "Faixa superior voltada à praça", -66.6, 8.26, -114.35, 0.62, 2.83, 16.9, concrete, "cement")
    box(workshop, "Peitoril voltado à praça", -66.6, 1.33, -118.49, 0.68, 2.50, 8.6, concrete, "cement")
    box(workshop, "Vidro para a bancada de serviço", -66.57, 4.75, -118.49, 0.20, 4.34, 8.4, petrol, "glass",
        {transparency = 0.48, shadow = false})
    for _, dz in {-122.82, -118.48, -114.15, -108.1} do
        box(workshop, "Caixilho e marco da oficina", -66.72, 4.52, dz, 0.55, 8.8, 0.41, steel, "steel")
    end
    box(workshop, "Verga do acesso pela praça", -66.63, 7.01, -111.1, 0.8, 0.51, 6.2, steel, "steel")
    box(workshop, "Soleira da oficina", -66.76, 0.125, -111.1, 2.29, 0.24, 6.05, concrete, "sidewalk")
    box(workshop, "Marquise da oficina", -69.05, 7.83, -116.1, 5.19, 0.38, 22.85, ink, "metal")
    box(workshop, "Borda da marquise", -71.58, 7.77, -116.1, 0.22, 0.51, 22.83, steel, "metal", trim)
    for _, dz in {-125.4, -106.5} do
        ctx.beam(workshop, "Mão francesa da marquise", Vector3.new(-66.99, 5.9, dz),
            Vector3.new(-70.96, 7.50, dz), 0.26, 0.26, steel, "steel", trim)
    end
    local awningLight = box(workshop, "Luz da entrada pela praça", -69.59, 7.56, -114.2, 0.36, 0.16, 14.2, warm, "neon", trim)
    ctx.lamp(awningLight, warm, 23, 1.6, "Bottom")
    for _, dz in {-127.3, -104.9} do
        box(workshop, "Parede lateral da oficina", -61.15, 4.9, dz, 10.86, 9.55, 0.63, brick, "brick")
        box(workshop, "Coluna da oficina", -55.54, 4.76, dz, 1.12, 9.24, 1.15, concrete, "cement")
    end
    box(workshop, "Laje da oficina", -60.8, 9.92, -116.1, 13.15, 0.78, 25.6, concrete, "cement")
    local workshopSign = box(workshop, "Letreiro da oficina", -54.17, 8.3, -116.0, 0.54, 1.82, 19.1, ink, "metal", trim)
    ctx.sign(workshopSign, "Right", "OFICINA DA COMPORTA", warm)
    box(workshop, "Porta de aço recolhida", -55.55, 6.66, -116, 0.35, 2.64, 19.86, steel, "metal", trim)
    for row = 1, 5 do
        box(workshop, "Dobra da porta de aço", -55.31, 5.48 + row * 0.43, -116, 0.13, 0.11, 19.85, ink, "metal", trim)
    end
    local repairLight = box(workshop, "Luz da oficina", -54.58, 7.28, -116, 0.27, 0.18, 13.9, warm, "neon", trim)
    ctx.lamp(repairLight, warm, 24, 1.60)
    box(workshop, "Bancada de serviço", -62.6, 1.82, -115.6, 4.46, 3.53, 16.04, ink, "steel")
    box(workshop, "Tampo de serviço", -62.6, 3.66, -115.6, 4.9, 0.22, 16.48, steel, "metal")
    for index, dz in {-121.3, -115.1, -110.3} do
        box(workshop, "Armário de manutenção", -64.92, 5.13, dz, 1.12, 2.16, 3.8, if index == 2 then petrol else steel, "metal", trim)
        box(workshop, "Alça do armário", -64.28, 5.01, dz + 0.73, 0.19, 0.71, 0.62, bronze, "metal", trim)
    end
    box(workshop, "Andar técnico da oficina", -61.22, 12.58, -116.1, 10.65, 4.52, 18.42, steel, "cement")
    box(workshop, "Capeamento do andar técnico", -61.22, 14.9, -116.1, 11.24, 0.28, 19.1, concrete, "cement")
    for index, dz in {-122.2, -116.1, -110} do
        box(workshop, "Caixilho técnico voltado à praça", -66.59, 12.73, dz, 0.39, 2.68, 4.88, ink, "metal", trim)
        box(workshop, "Janela do andar técnico", -66.82, 12.76, dz, 0.14, 2.24, 4.47,
            if index == 2 then rgb(172, 129, 86) else petrol, if index == 2 then "neon" else "glass", trim)
        box(workshop, "Montante da janela técnica", -66.94, 12.74, dz + 0.79, 0.22, 2.34, 0.27, ink, "steel", trim)
    end
    box(workshop, "Tanque de ar da oficina", -63.1, 16.9, -121.7, 3.67, 4.02, 4.0, steel, "steel", {shape = "Cylinder", roll = 90})
    box(workshop, "Caixa de ventilação no telhado", -62.2, 15.89, -110.4, 5.5, 1.71, 4.8, ink, "metal")
    for i = 1, 4 do
        box(workshop, "Veneziana da carcaça", -59.35, 15.2 + i * 0.28, -110.4, 0.16, 0.12, 4.48, steel, "metal", trim)
    end
    ctx.beam(workshop, "Tubo exterior do compressor", Vector3.new(-66.9, 2.1, -126.8),
        Vector3.new(-66.9, 14.6, -126.8), 0.49, 0.49, petrol, "metal", trim)
    for _, dz in {-123.1, -121.98} do
        ctx.beam(workshop, "Conduíte acima da ligação pedonal", Vector3.new(-62.9, 14.35, dz),
            Vector3.new(-33, 13.76, dz), 0.36, 0.36, steel, "metal", trim)
        for _, atX in {-50.6, -42.9} do
            box(workshop, "Abraçadeira de conduíte", atX, 14.08, dz, 0.20, 0.59, 0.57, bronze, "metal", trim)
        end
    end

    local canteen = group(fronts, "Cozinha do Dique")
    box(canteen, "Fundo de alvenaria da cozinha", 68.55, 4.54, -119, 0.66, 8.96, 20.1, brick, "brick")
    for _, dz in {-128.7, -109.3} do
        box(canteen, "Parede azulejada", 62.45, 4.13, dz, 11.86, 8.05, 0.60, petrol, "tile")
        box(canteen, "Pilar da cozinha", 56.45, 4.33, dz, 0.59, 8.56, 0.61, steel, "steel")
    end
    box(canteen, "Balcão azulejado", 56.84, 1.91, -119.04, 1.77, 3.72, 16.72, petrol, "tile")
    box(canteen, "Tampo de pedra", 56.61, 3.84, -119.04, 2.46, 0.25, 17.43, concrete, "stone")
    box(canteen, "Toldo inclinável", 55.51, 8.02, -119.04, 7.2, 0.30, 20.32, rgb(145, 92, 78), "fabric", {roll = 6})
    box(canteen, "Chapa de cobertura da cozinha", 62.38, 8.8, -119.0, 12.87, 0.45, 20.9, ink, "roof")
    box(canteen, "Coifa do balcão", 64.99, 6.89, -119.0, 2.42, 1.02, 14.73, steel, "steel")
    box(canteen, "Bancada inox da cozinha", 65.15, 1.86, -119.1, 3.15, 3.58, 16.21, ink, "metal")
    for _, dz in {-124.4, -118.9, -113.6} do
        box(canteen, "Apoio do assento", 53.43, 0.96, dz, 0.61, 1.85, 0.61, ink, "steel")
        box(canteen, "Assento da cozinha", 53.43, 1.92, dz, 1.48, 0.27, 1.52, bronze, "wood")
    end
    local foodLight = box(canteen, "Luz quente do balcão", 56.2, 7.23, -119.02, 0.26, 0.16, 14.58, warm, "neon", trim)
    ctx.lamp(foodLight, warm, 21, 1.40)

    local square = group(city, "Poças da Praça do Dique")
    local walkY = layout.walkY
    local function oval(parent, name, px, py, pz, w, length, angle, color, material, transparency, reflectance)
        local pose = CFrame.new(px, py, pz) * CFrame.Angles(0, math.rad(angle), math.pi / 2)
        return box(parent, name, px, py, pz, 0.018, w, length, color, material,
            {shape = "Cylinder", cframe = pose, collision = false, shadow = false, transparency = transparency, reflectance = reflectance})
    end
    for _, site in {{-101, -78, 7.2, 12.8, 21}, {-81, -73, 6.4, 10.8, -24}, {-59, -79, 8.2, 15.4, -32}, {59, -68, 7.2, 12.6, 42}} do
        local px, pz, w, d, angle = table.unpack(site)
        local puddle = group(square, "Poça rasa na calçada")
        oval(puddle, "Contorno úmido", px, walkY + 0.005, pz, w * 1.13, d * 1.09, angle, rgb(39, 61, 79), "paint", 0.28, 0.18)
        oval(puddle, "Lâmina rasa", px, walkY + 0.018, pz, w, d, angle, rgb(72, 99, 126), "puddle", 0.35, 0.55)
        oval(puddle, "Borda de água", px - 1.43, walkY + 0.023, pz + 2.62, w * 0.52, d * 0.52, angle - 19, rgb(72, 99, 126),
            "puddle", 0.41, 0.53)
        for index, color in {rgb(87, 147, 170), rgb(166, 121, 89)} do
            local gleam = oval(puddle, "Reflexo de luz na praça", px + index * 0.68 - 1.5, walkY + 0.033 + index * 0.005,
                pz + index * 0.76, 0.40, d * (0.42 - 0.08 * index), angle, color, "neon", 0.70, 0)
            gleam:SetAttribute("MareBrilhoPiso", true)
        end
    end

    marketFront(ctx, city)
    entreposto(ctx, city)
    return Vector3.new(0, deck, z)
end

return Prisma
