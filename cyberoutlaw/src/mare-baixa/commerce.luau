local Commerce = {}

local TRIM = { collision = false, shadow = false }
local CLEAR_GLASS = { collision = false, shadow = false, transparency = 0.3 }
local VERTICAL_CYLINDER = { shape = "Cylinder", roll = 90 }
local COLLAR = { shape = "Cylinder", roll = 90, collision = false, shadow = false }
local PIPE_X = { shape = "Cylinder" }
local PIPE_Z = { shape = "Cylinder", yaw = 90 }

local function palette(ctx)
    local rgb = ctx.rgb
    return {
        basalt = rgb(26, 33, 42),
        slate = rgb(43, 57, 65),
        iron = rgb(53, 69, 73),
        zinc = rgb(93, 113, 111),
        concrete = rgb(76, 84, 84),
        paving = rgb(53, 62, 65),
        grout = rgb(36, 45, 49),
        tile = rgb(81, 91, 87),
        petrol = rgb(35, 72, 78),
        teal = rgb(40, 98, 100),
        cyan = rgb(55, 217, 218),
        purple = rgb(94, 55, 98),
        magenta = rgb(224, 64, 145),
        brick = rgb(96, 57, 46),
        oxide = rgb(136, 66, 44),
        burntOrange = rgb(156, 86, 53),
        wood = rgb(110, 79, 58),
        ocher = rgb(174, 137, 69),
        amber = rgb(255, 183, 99),
        milk = rgb(234, 224, 199),
    }
end

local function station(ctx, parent, name, x, z)
    local model = ctx.group(parent, name)
    local function box(partName, dx, y, dz, sx, sy, sz, color, material, options)
        return ctx.box(model, partName, x + dx, y, z + dz, sx, sy, sz, color, material, options)
    end
    return model, box
end

local function beamXY(box, name, x1, y1, x2, y2, z, height, depth, color, material)
    local dx, dy = x2 - x1, y2 - y1
    return box(name, (x1 + x2) / 2, (y1 + y2) / 2, z, math.sqrt(dx * dx + dy * dy), height, depth, color, material, {
        roll = math.deg(math.atan2(dy, dx)),
    })
end

local function beamZY(box, name, z1, y1, z2, y2, x, width, height, color, material)
    local dz, dy = z2 - z1, y2 - y1
    return box(name, x, (y1 + y2) / 2, (z1 + z2) / 2, width, height, math.sqrt(dz * dz + dy * dy), color, material, {
        pitch = -math.deg(math.atan2(dy, dz)),
    })
end

local function lightBar(ctx, box, c, x, y, z, width, color, range, brightness)
    box("Calha da luminária", x, y + 0.13, z, width + 0.35, 0.34, 0.66, c.basalt, "steel", TRIM)
    local emitter = box("Difusor", x, y - 0.05, z, width, 0.17, 0.38, color, "neon", TRIM)
    ctx.lamp(emitter, color, range, brightness, "Bottom")
end

local function drain(box, c, x, z)
    box("Canaleta", x, 0.17, z, 9.1, 0.07, 1.65, c.grout, "metal", TRIM)
    for slat = -3, 3 do
        box("Travessa da grelha", x + slat * 1.24, 0.22, z, 0.15, 0.06, 1.4, c.zinc, "metal", TRIM)
    end
end

local function bench(box, c, x, z)
    for _, side in { -1, 1 } do
        box("Pé do banco", x + side * 3.2, 0.9, z, 0.54, 1.55, 1.48, c.basalt, "metal")
        box("Suporte do encosto", x + side * 3.2, 2.0, z + 0.78, 0.4, 2.4, 0.42, c.iron, "metal")
    end
    box("Assento", x, 1.65, z, 8.0, 0.25, 2.05, c.wood, "wood")
    box("Encosto", x, 2.79, z + 0.78, 8.02, 0.56, 0.21, c.wood, "wood")
end

local function cabinet(ctx, box, c, x, z, accent)
    box("Venda automática", x, 3.57, z, 4.2, 6.9, 2.9, c.slate, "paint")
    box("Painel da venda", x, 4.63, z - 1.5, 3.55, 3.55, 0.16, c.basalt, "paint", TRIM)
    box("Vitrine", x - 0.49, 4.74, z - 1.603, 2.1, 2.96, 0.08, c.petrol, "glass", CLEAR_GLASS)
    for row = 0, 2 do
        box("Bandeja interna", x - 0.49, 3.71 + row * 0.82, z - 1.57, 1.88, 0.09, 0.17, accent, "neon", TRIM)
    end
    box("Terminal", x + 1.11, 4.78, z - 1.62, 0.57, 0.89, 0.13, c.zinc, "metal", TRIM)
    box("Boca de retirada", x - 0.14, 2.03, z - 1.52, 2.62, 0.77, 0.14, c.basalt, "rubber", TRIM)
    lightBar(ctx, box, c, x, 6.55, z - 1.59, 3.0, accent, 8, 0.85)
end

local function pallet(box, c, x, z, finish, stacked)
    for _, side in { -1, 1 } do
        box("Longarina do estrado", x + side * 1.96, 0.31, z, 0.52, 0.45, 4.22, c.wood, "wood")
    end
    for slat = -1, 1 do
        box("Tábua do estrado", x, 0.61, z + slat * 1.49, 4.9, 0.22, 1.06, c.wood, "wood")
    end
    box("Caixa de carga", x, 1.75, z, 4.18, 2.06, 3.58, finish, "wood")
    box("Cinta da caixa", x, 2.08, z, 4.23, 0.16, 3.64, c.iron, "metal", TRIM)
    if stacked then
        box("Caixa empilhada", x + 0.43, 3.48, z + 0.45, 3.06, 1.4, 2.36, c.wood, "wood")
        box("Cinta da caixa alta", x + 0.43, 3.51, z + 0.45, 3.11, 0.14, 2.42, c.iron, "metal", TRIM)
    end
end

local function waterTower(box, c, x, z, base, legs, width, shell)
    local radius = width / 2
    local deck = base + legs
    for _, side in { -1, 1 } do
        for _, endBay in { -1, 1 } do
            box("Montante do reservatório", x + side * radius * 0.71, base + legs / 2, z + endBay * radius * 0.71, 0.66, legs, 0.66, c.iron, "steel")
            box("Sapato do reservatório", x + side * radius * 0.71, base + 0.14, z + endBay * radius * 0.71, 1.34, 0.28, 1.34, c.zinc, "metal")
        end
        beamXY(box, "Travamento do reservatório", x - radius * 0.71, base + 0.4, x + radius * 0.71, deck - 0.35, z + side * radius * 0.71, 0.31, 0.34, c.iron, "steel")
    end
    box("Mesa do reservatório", x, deck, z, width + 1.0, 0.41, width + 1.0, c.slate, "steel")
    box("Casco do reservatório", x, deck + 4.2, z, 8.25, width, width, shell, "metal", VERTICAL_CYLINDER)
    for _, collarY in { 0.64, 4.05, 7.6 } do
        box("Cinta do reservatório", x, deck + collarY, z, 0.32, width + 0.32, width + 0.32, c.iron, "metal", COLLAR)
    end
    box("Tampa", x, deck + 8.48, z, 0.47, width - 0.22, width - 0.22, c.zinc, "metal", VERTICAL_CYLINDER)
    box("Respiro", x + 1.2, deck + 9.11, z - 1.7, 1.4, 1.01, 1.01, c.iron, "metal", VERTICAL_CYLINDER)
    box("Tubo de queda", x + radius + 0.4, base + (legs + 6.2) / 2, z, legs + 6.2, 0.61, 0.61, c.teal, "metal", VERTICAL_CYLINDER)
    box("Curva do reservatório", x + radius - 0.01, deck + 6.2, z, 1.47, 0.61, 0.61, c.teal, "metal", PIPE_X)
end

local function marketStalls(ctx, parent, c, x, z, seed, arcade)
    local _, box = station(ctx, parent, if arcade then "Salas de jogos abertas" else "Bancas e oficinas", x, z)
    local canvas = { c.oxide, c.ocher, c.teal }
    local stock = { c.oxide, c.ocher, c.teal, c.purple }
    for _, side in { -1, 1 } do
        for bay = 1, 4 do
            local dx = side * 21.5
            local dz = -37.5 + (bay - 1) * 25
            local pattern = seed + bay + (if side == 1 then 1 else 0)
            local fabric = canvas[pattern % #canvas + 1]
            local glow = if pattern % 2 == 0 then c.cyan else c.magenta
            if arcade then
                fabric = if pattern % 2 == 0 then c.petrol else c.purple
            end
            for _, edge in { -1, 1 } do
                box("Montante da banca", dx + side * 5.6, 4.1, dz + edge * 6.1, 0.56, 7.6, 0.56, c.iron, "steel")
                beamXY(box, "Mão francesa", dx + side * 5.6, 6.43, dx - side * 6.12, 8.28, dz + edge * 6.1, 0.26, 0.25, c.iron, "steel")
            end
            box("Lona da banca", dx + 0.15 * side, 7.97, dz, 13.55, 0.23, 13.0, fabric, "fabric", { roll = side * -3 })
            box("Barra da marquise", dx - side * 6.5, 8.28, dz, 0.2, 0.42, 13.0, if arcade then glow else c.milk, if arcade then "neon" else "fabric", TRIM)
            box("Fundo da oficina", dx + side * 5.65, 2.77, dz, 0.39, 4.48, 10.87, c.slate, "metal")
            for rib = 1, 2 do
                box("Nervura da oficina", dx + side * 5.4, 1.62 + rib * 0.8, dz, 0.15, 0.14, 10.48, c.iron, "metal", TRIM)
            end

            if arcade then
                for _, edge in { -1, 1 } do
                    local unitZ = dz + edge * 2.5
                    box("Gabinete de jogo", dx - side * 1.9, 2.94, unitZ, 2.66, 5.34, 3.39, fabric, "paint")
                    box("Tela do jogo", dx - side * 3.27, 3.84, unitZ, 0.15, 1.77, 2.62, glow, "neon", TRIM)
                    box("Comandos", dx - side * 3.62, 2.62, unitZ, 0.62, 0.23, 2.76, c.slate, "rubber")
                    box("Coluna de luz", dx - side * 3.3, 1.95, unitZ + 1.36, 0.14, 1.00, 0.13, c.milk, "neon", TRIM)
                end
            else
                -- O camelô aparece no eixo X local do balcão, dentro da banca.
                box("Carrinho de comida", dx - side * 3.74, 1.67, dz, 2.44, 2.78, 10.71, fabric, "paint",
                    {yaw = if side < 0 then 180 else 0})
                box("Tampo do balcão", dx - side * 3.74, 3.18, dz, 2.77, 0.34, 11.14, c.wood, "wood")
                box("Rodapé", dx - side * 5, 0.56, dz, 0.18, 0.44, 10.74, c.iron, "steel", TRIM)
                for item = 1, 3 do
                    local itemZ = dz + (item - 2) * 2.47
                    local color = stock[(pattern + item) % #stock + 1]
                    if item == 2 then
                        box("Pote de conserva", dx - side * 3.54, 3.72, itemZ, 0.71, 0.88, 0.88, color, "metal", COLLAR)
                        box("Tampa da conserva", dx - side * 3.54, 4.10, itemZ, 0.10, 0.94, 0.94, c.zinc, "metal", COLLAR)
                    else
                        box("Mercadorias", dx - side * 3.54, 3.60, itemZ, 1.32, 0.48, 1.78, color, "paint", TRIM)
                    end
                end
            end
            lightBar(ctx, box, c, dx, 7.41, dz, 3.09, if arcade then glow else c.amber, 12, 1.0)
        end
    end
end

local function marketPassage(ctx, model, c, x, z)
    local _, box = station(ctx, model, "Passagem e mezanino do Sódio", x, z)
    local deckHeight = 9.84
    box("Piso do mezanino", -34, deckHeight - 0.28, 4, 8.6, 0.56, 64, c.concrete, "cement")
    box("Viga longitudinal do mezanino", -29.94, deckHeight - 0.71, 4, 0.62, 0.48, 64, c.iron, "steel")
    for dz = -22, 31, 17 do
        box("Coluna lateral do mezanino", -38, 4.63, dz, 0.51, 9.1, 0.51, c.iron, "steel")
        box("Console do mezanino", -34, 8.9, dz, 8.5, 0.54, 0.65, c.slate, "steel")
    end
    for _, side in { -1, 1 } do
        local railX = -34 + side * 4.15
        box("Guarda-corpo do mezanino", railX, deckHeight + 1.45, 4, 0.25, 2.9, 64, c.basalt, "steel",
            {transparency = 1, shadow = false})
        box("Corrimão do mezanino", railX, deckHeight + 2.76, 4, 0.28, 0.3, 64, c.ocher, "steel", TRIM)
        for dz = -26, 35, 7.5 do
            box("Balaústre", railX, deckHeight + 1.4, dz, 0.25, 2.8, 0.24, c.iron, "steel", TRIM)
        end
    end
    box("Fechamento do mezanino", -34, deckHeight + 1.32, 35.76, 8.6, 2.64, 0.36, c.iron, "steel")
    for index = 1, 19 do
        local y = 0.22 + index * ((deckHeight - 0.22) / 19)
        local dz = -28.52 - (19 - index) * 1.05
        box("Degrau do mezanino", -34, y / 2, dz, 7.8, y, 1.06, c.concrete, "cement", {shadow = false})
    end
    for _, side in { -1, 1 } do
        beamZY(box, "Corrimão da escada do mercado", -48.2, 2.8, -28.05, deckHeight + 2.75, -34 + side * 4.02,
            0.24, 0.25, c.ocher, "steel")
    end

    -- O corredor coberto anuncia a entrada a partir da calçada. A estrutura é própria do Mercado do Sódio.
    for _, side in { -1, 1 } do
        local dx = side * 13.6
        for _, dz in { -78, -59.5 } do
            box("Pilar da entrada coberta", dx, 5.62, dz, 0.69, 11.0, 0.72, c.iron, "steel")
            box("Sapata do pilar", dx, 0.34, dz, 1.93, 0.51, 2.22, c.concrete, "cement")
        end
        box("Calha da entrada", dx, 11.18, -68.8, 0.55, 0.39, 20.7, c.zinc, "steel")
        beamXY(box, "Chapa translúcida da entrada", dx, 11.26, 0, 12.56, -68.8, 0.24, 20.9, c.petrol, "glass", CLEAR_GLASS)
    end
    for _, dz in { -77.7, -68.5, -59.5 } do
        box("Travessa da entrada", 0, 11.05, dz, 27.6, 0.34, 0.38, c.iron, "steel")
        for _, dx in { -7.5, 0, 7.5 } do
            local color = if dx == 0 then c.amber else c.magenta
            box("Suporte do pendente", dx, 10.67, dz, 0.19, 0.70, 0.19, c.iron, "metal", TRIM)
            local shade = box("Difusor da entrada", dx, 10.17, dz, 1.53, 0.57, 1.05, color, "neon", TRIM)
            if dx == 0 or dz == -68.5 then ctx.lamp(shade, color, 17, 1.85, "Bottom") end
        end
    end

    local placard = box("Letreiro esmaltado", 0, 14.47, -78.34, 28.7, 3.62, 0.72, c.slate, "metal")
    box("Moldura do letreiro", 0, 16.35, -78.38, 29.3, 0.32, 0.82, c.oxide, "metal", TRIM)
    for _, side in { -1, 1 } do
        box("Suspensão do letreiro", side * 13.6, 12.8, -78.1, 0.55, 3.6, 0.62, c.iron, "steel")
    end
    lightBar(ctx, box, c, 0, 12.43, -78.94, 26.7, c.amber, 20, 1.28)
    if ctx.sign then ctx.sign(placard, "Front", "MERCADO DO SÓDIO", c.milk) end

    -- Duas frentes diferentes junto ao acesso. O vão sob a cobertura fica livre para circulação.
    local _, shops = station(ctx, model, "Ponto de refeições e oficina", x, z)
    shops("Balcão de refeições", 28.5, 1.9, -75, 20.1, 3.56, 1.24, c.teal, "tile")
    shops("Tampo inoxidável", 28.5, 3.75, -75, 20.9, 0.22, 1.95, c.zinc, "metal")
    shops("Frente de alvenaria da cozinha", 28.5, 4.14, -62.6, 20, 8.04, 0.62, c.oxide, "brick")
    shops("Coifa da cozinha", 30.4, 6.96, -64, 13.4, 1.42, 2.25, c.zinc, "steel")
    shops("Bancada de preparo", 28.7, 1.79, -64.11, 18.3, 3.34, 2.57, c.slate, "metal")
    shops("Cobertura do balcão", 28.5, 8.72, -68.9, 21.3, 0.42, 14.15, c.petrol, "roof")
    for _, dx in {19.1, 37.9} do
        shops("Montante do balcão", dx, 4.51, -74.65, 0.55, 8.5, 0.55, c.iron, "steel")
        shops("Assento do balcão", dx + (if dx < 28.5 then 3.6 else -3.6), 1.91, -78.05, 1.7, 0.35, 1.7, c.ocher, "wood")
        shops("Apoio do assento", dx + (if dx < 28.5 then 3.6 else -3.6), 0.95, -78.05, 0.63, 1.7, 0.65, c.iron, "steel")
    end
    lightBar(ctx, shops, c, 28.5, 8.41, -74.25, 18.2, c.cyan, 15, 1.15)

    shops("Parede da oficina", -28.2, 4.8, -62.9, 15, 9.35, 0.75, c.concrete, "cement")
    shops("Cobertura da oficina", -28.2, 9.82, -67.6, 16.4, 0.78, 11.4, c.iron, "roof")
    for _, dx in {-35.7, -20.7} do
        shops("Ombreira da oficina", dx, 4.69, -72.3, 0.72, 9.14, 0.82, c.iron, "steel")
    end
    shops("Porta de enrolar recolhida", -28.2, 7.43, -72.33, 14.8, 3.95, 0.32, c.slate, "metal")
    for row = 1, 6 do
        shops("Dobra da porta de aço", -28.2, 5.64 + row * 0.51, -72.55, 14.77, 0.14, 0.14, c.zinc, "metal", TRIM)
    end
    pallet(shops, c, -31.7, -66.5, c.wood, true)
    lightBar(ctx, shops, c, -28.2, 9.15, -73.4, 12.5, c.amber, 14, 1.06)
end

function Commerce.market(ctx, parent, x, z, seed, variant)
    local c = palette(ctx)
    local sodio = variant == "sodio"
    local arcade = variant == "arcade"
    local phase = math.floor(seed or 0) % 12
    local name = if sodio then "Mercado do Sódio" elseif arcade then "Galeria de Jogos" else "Mercado de Bairro"
    local model, yard = station(ctx, parent, name, x, z)
    local _, hall = station(ctx, model, "Galpão de bancas", x, z)
    local _, roof = station(ctx, model, "Cobertura em dente de serra", x, z)

    yard("Praça de acesso", 0, -0.12, 0, 152, 0.42, 165, c.paving, "cement")
    hall("Piso de ladrilho", 0, 0.0, 0, 85.5, 0.5, 119.5, c.tile, "tile")
    for _, side in { -1, 1 } do
        hall("Faixa de circulação", side * 12.6, 0.261, 0, 0.61, 0.022, 116, c.zinc, "paint", TRIM)
        hall("Canaleta lateral", side * 37.5, 0.264, 0, 0.4, 0.025, 116, c.grout, "metal", TRIM)
        for _, dz in { -34, 0, 34 } do
            if dz ~= 0 then
                hall("Mureta", side * 41.3, 1.65, dz, 1.42, 2.8, 21.5, c.concrete, "cement")
                hall("Peitoril", side * 41.3, 3.12, dz, 1.83, 0.32, 21.5, c.slate, "steel")
            end
            local ventY = if dz == 0 then 13.55 else 11.73
            hall("Bandeira de ventilação", side * 41.35, ventY, dz, 0.49, 4.5, 21.1, c.slate, "metal")
            for vane = 1, 2 do
                hall("Aleta da bandeira", side * 41.65, ventY - 1.77 + vane * 0.85, dz, 0.61, 0.22, 20.9, c.zinc, "metal", TRIM)
            end
        end
        hall("Viga longitudinal", side * 41.3, 18.38, 0, 1.27, 1.07, 113.5, c.iron, "steel")
        for _, dz in { -55, -33, -11, 11, 33, 55 } do
            hall("Pilar do galpão", side * 41.3, 9.55, dz, 1.75, 18.7, 1.76, c.iron, "steel")
            hall("Pedestal do pilar", side * 41.3, 1.12, dz, 2.32, 1.73, 2.34, c.concrete, "cement")
            if dz == -55 or dz == 11 or dz == 55 then
                hall("Faixa refletiva", side * 41.3, 1.82, dz, 2.35, 0.19, 2.37, c.ocher, "paint", TRIM)
            end
        end
    end
    for _, dz in { -55, -33, -11, 11, 33, 55 } do
        hall("Travessa do galpão", 0, 18.3, dz, 82.5, 0.72, 0.72, c.iron, "steel")
        for _, side in { -1, 1 } do
            beamXY(hall, "Braço do pórtico", side * 40.65, 14.32, side * 33.6, 18.33, dz, 0.51, 0.52, c.zinc, "steel")
        end
    end

    local roofWidths = { -45, -16, 13, 45 }
    local ridgeHeights = if arcade then { 23.0, 27.9, 22.5 } else { 24.55, 26.1, 24.15 }
    local roofSwatches = if arcade then { c.petrol, c.slate, c.purple } else { c.petrol, c.slate, c.iron }
    for band = 1, 3 do
        local left, right = roofWidths[band], roofWidths[band + 1]
        local eave, ridge = 19.05, ridgeHeights[band]
        for section = 1, 4 do
            local color = roofSwatches[(phase + band + section) % #roofSwatches + 1]
            beamXY(roof, "Chapa da cobertura", left, eave, right, ridge, (section - 2.5) * 30, 0.43, 30.07, color, "roof")
        end
        for _, seam in { -60.1, -30, 30, 60.1 } do
            local color = if seam == -60.1 or seam == 60.1 then c.oxide else c.iron
            beamXY(roof, "Costura da cobertura", left, eave + 0.3, right, ridge + 0.3, seam, 0.27, 0.37, color, "steel")
        end
        roof("Arremate longitudinal", right, ridge - 0.07, 0, 0.59, 0.46, 120.46, c.iron, "steel")
        for _, dz in { -39.82, 0, 39.82 } do
            roof("Vidro do lanternim", right + 0.04, (ridge + eave) * 0.5, dz, 0.16, ridge - eave - 0.44, 39.25, if arcade then c.teal else c.zinc, "glass", CLEAR_GLASS)
        end
        for _, dz in { -59.65, 0, 59.65 } do
            roof("Caixilho alto", right, (ridge + eave) * 0.5, dz, 0.36, ridge - eave, 0.52, c.iron, "metal")
        end
    end
    roof("Calha baixa", -45.35, 18.96, 0, 0.68, 0.62, 120.5, c.iron, "metal")
    hall("Perfil das luminárias centrais", 0, 17.71, 0, 0.43, 0.49, 110, c.iron, "steel")
    for _, dz in { -51, -18, 18, 51 } do
        lightBar(ctx, hall, c, 0, 17.17, dz, 6.2, if arcade then c.cyan else c.amber, 23, 1.63)
    end

    marketStalls(ctx, model, c, x, z, phase, arcade)
    for _, endBay in { -1, 1 } do
        if arcade then
            bench(hall, c, endBay * 9.6, endBay * 24.5)
        else
            pallet(hall, c, endBay * 9.6, endBay * 24.5, c.ocher, endBay == 1)
        end
        for _, side in { -1, 1 } do
            yard("Balizador", side * 11.6, 1.45, endBay * 68.5, 2.7, 0.74, 0.74, c.slate, "metal", VERTICAL_CYLINDER)
            yard("Anel de segurança", side * 11.6, 2.2, endBay * 68.5, 0.34, 0.81, 0.81, c.ocher, "paint", COLLAR)
        end
        drain(yard, c, endBay * 22.5, endBay * 67)
        bench(yard, c, endBay * 42, endBay * 70.5)
        cabinet(ctx, yard, c, endBay * 54, endBay * 60, if arcade then c.magenta else c.cyan)
        pallet(yard, c, endBay * 53, endBay * 46, c.wood, endBay == 1)
        yard("Tampa de vistoria", endBay * 29, 0.14, endBay * 73.5, 0.07, 2.6, 2.6, c.grout, "metal", COLLAR)
    end

    if sodio then
        marketPassage(ctx, model, c, x, z)
        local _, tower = station(ctx, model, "Caixa-d'água do mercado", x, z)
        waterTower(tower, c, 29.5, 35.7, 20.97, 9.44, 10.2, c.oxide)
    end
    return model
end

function Commerce.atm(ctx, parent, x, z, ground)
    local c = palette(ctx)
    local model, box = station(ctx, parent, "Terminal de eurodólares", x, z)
    local machine = box("Caixa eletrônico", 0, ground + 2.9, 0, 3.4, 5.8, 2.35, c.iron, "steel")
    machine:SetAttribute("CyberOutlawRoubo", "caixa")
    local screen = ctx.box(machine, "Monitor do caixa", x, ground + 4.24, z - 1.19, 2.81, 1.56, 0.15,
        c.basalt, "metal", TRIM)
    ctx.sign(screen, "Front", "ESTUÁRIO €$", c.cyan, "Tela")
    box("Leitor do caixa", 0, ground + 3.03, -1.28, 2.26, 0.19, 0.21, c.cyan, "neon", TRIM)
    box("Bandeja do caixa", 0, ground + 2.27, -1.28, 2.23, 0.25, 0.38, c.slate, "metal", TRIM)
    return model
end

function Commerce.cart(ctx, parent, x, z, ground)
    local c = palette(ctx)
    local _, box = station(ctx, parent, "Banca de rua", x, z)
    box("Carrinho de comida", 0, ground + 2.1, 0, 7, 3.4, 3.6, c.slate, "metal")
    box("Tampo do carrinho", 0, ground + 3.9, 0, 7.2, 0.22, 3.8, c.wood, "wood", TRIM)
    for _, side in {-1, 1} do
        box("Montante da banca", side * 3.2, ground + 5.35, 1, 0.25, 3.1, 0.25, c.iron, "steel", TRIM)
    end
    box("Lona do carrinho", 0, ground + 7, 0, 7.7, 0.25, 5.3, c.oxide, "fabric", TRIM)
    local panel = box("Friso do carrinho", 0, ground + 6.71, -2.66, 7.1, 0.3, 0.2, c.amber, "neon", TRIM)
    ctx.lamp(panel, c.amber, 12, 0.7, "Bottom")
end

function Commerce.parkedCar(ctx, parent, x, z, ground, bodyColor)
    local c = palette(ctx)
    local _, box = station(ctx, parent, "Carro estacionado", x, z)
    box("Carroceria", 0, ground + 1.55, 0, 5.1, 1.7, 12.8, bodyColor, "paint", {reflectance = 0.16})
    box("Cabine", 0, ground + 3.15, 0.5, 4.5, 1.55, 6.2, c.basalt, "glass", {reflectance = 0.32})
    box("Teto", 0, ground + 4, 0.6, 4.4, 0.2, 5.4, bodyColor, "paint", TRIM)
    for _, side in {-1, 1} do
        for _, tire in {-4.1, 4.2} do
            box("Roda", side * 2.45, ground + 1.15, tire, 0.9, 2.3, 2.3, c.basalt, "rubber",
                {shape = "Cylinder", collision = false, shadow = false})
        end
        box("Farol", side * 1.7, ground + 1.9, -6.5, 0.9, 0.35, 0.2, c.milk, "paint", TRIM)
    end
    box("Lanterna", 0, ground + 2.0, 6.5, 4.4, 0.25, 0.2, c.oxide, "paint", TRIM)
end

local function cargoContainer(box, c, x, z, base, finish)
    local y = base + 3.92
    box("Caixa marítima", x, y, z, 18.43, 7.84, 7.6, finish, "metal")
    for _, side in { -1, 1 } do
        box("Longarina superior", x, y + 3.78, z + side * 3.72, 18.79, 0.36, 0.34, c.iron, "steel")
        box("Longarina inferior", x, y - 3.78, z + side * 3.72, 18.79, 0.36, 0.34, c.iron, "steel")
        for rib = -2, 2 do
            box("Nervura marítima", x + rib * 3.12, y, z + side * 3.875, 0.22, 7.13, 0.28, c.iron, "metal", TRIM)
        end
        box("Ferragem de canto", x - 9.19, y, z + side * 3.75, 0.41, 7.94, 0.44, c.basalt, "steel")
        box("Fecho da porta", x - 9.28, y, z + side * 1.48, 0.19, 6.84, 0.17, c.zinc, "metal", TRIM)
    end
end

local function freightGantry(ctx, parent, c, x, z)
    local _, box = station(ctx, parent, "Guindaste de pórtico da doca", x, z)
    local sides = { -1, 1 }
    local tracks = { -67, -41 }
    for _, side in sides do
        local dx = side * 45.7
        for _, dz in tracks do
            box("Fundação do pórtico", dx, 0.42, dz, 7.7, 0.62, 7.7, c.concrete, "cement")
            box("Pé em aço fundido", dx, 2.39, dz, 5.8, 3.51, 5.8, c.slate, "steel")
            box("Coluna do pórtico", dx, 19.68, dz, 2.62, 37.91, 2.64, c.oxide, "steel")
            box("Sapata alta", dx, 35.55, dz, 5.3, 1.4, 4.62, c.burntOrange, "steel")
            box("Proteção de coluna", dx, 4.16, dz, 3.13, 0.56, 3.13, c.ocher, "paint", TRIM)
            beamXY(box, "Escora frontal", dx, 29, dx - side * 11, 37.1, dz, 1.01, 1.12, c.burntOrange, "steel")
        end
        box("Cabeceira do pórtico", dx, 39.46, -54, 3.07, 1.72, 31.8, c.oxide, "steel")
        beamZY(box, "Travamento lateral", -66.1, 20.5, -41.7, 36.9, dx, 1.25, 1.2, c.burntOrange, "steel")
        beamZY(box, "Travamento lateral", -66.1, 36.9, -41.7, 20.5, dx, 1.25, 1.2, c.oxide, "steel")
    end
    for _, dz in tracks do
        box("Banzo superior", 0, 44.65, dz, 106.2, 1.2, 1.33, c.oxide, "steel")
        box("Viga caixão", 0, 39.28, dz, 106.2, 1.83, 1.68, c.burntOrange, "steel")
        for brace = -3, 3 do
            local start = brace * 14.54
            local finish = start + 7.91
            beamXY(box, "Diagonal treliçada", start - 6.63, 40.17, start, 44.2, dz, 0.66, 0.77, c.burntOrange, "steel")
            beamXY(box, "Diagonal treliçada", start, 44.2, finish, 40.17, dz, 0.66, 0.77, c.burntOrange, "steel")
        end
        for _, dx in { -28, 28 } do
            lightBar(ctx, box, c, dx, 38.14, dz, 2.2, c.amber, 15, 1.4)
        end
    end
    for _, dx in { -48.5, 0, 48.5 } do
        box("Travessa do caminho de rolamento", dx, 41.04, -54, 0.85, 0.8, 28.0, c.iron, "steel")
    end
    box("Carro do guindaste", 20.5, 40.25, -54, 6.6, 2.21, 27.1, c.slate, "steel")
    box("Cabina suspensa", 24.14, 35.73, -43.7, 5.25, 4.6, 5.5, c.iron, "steel")
    box("Vidro da cabina", 24.14, 36.18, -46.48, 4.45, 2.11, 0.17, c.teal, "glass", CLEAR_GLASS)
    box("Soleira da cabina", 24.14, 34.7, -46.63, 4.96, 0.3, 0.33, c.ocher, "metal", TRIM)
    for _, side in sides do
        box("Cabo de içamento", 20.5 + side * 0.52, 30, -54, 0.117, 18.14, 0.117, c.iron, "steel")
    end
    box("Moita do gancho", 20.5, 20.79, -54, 3.17, 1.51, 1.77, c.ocher, "steel")
    box("Gancho de carga", 20.5, 19.55, -54, 1.2, 1.44, 0.73, c.iron, "steel", { roll = 31 })
end

local function warehouseHall(ctx, parent, c, x, z, phase, docks)
    local _, box = station(ctx, parent, if docks then "Galpão da Doca do Sal" else "Galpão de distribuição", x, z)
    local _, roof = station(ctx, parent, "Cobertura do armazém", x, z)
    box("Laje do armazém", 0, 0.03, 28, 127.5, 0.47, 54.7, c.tile, "cement")
    box("Faixa de eixo", 0, 0.274, 28, 0.12, 0.015, 54.1, c.ocher, "paint", TRIM)
    for _, side in { -1, 1 } do
        box("Faixa da doca", side * 8.8, 0.276, 28, 0.19, 0.019, 53.75, c.zinc, "paint", TRIM)
        for _, dz in { 1.5, 54.5 } do
            box("Parede da doca", side * 35.5, 10.92, dz, 52.0, 21.35, 1.21, c.concrete, "cement")
            box("Batente do portão", side * 9.6, 7.0, dz, 0.57, 13.5, 1.4, c.iron, "steel")
            box("Borracha do batente", side * 9.65, 2.64, dz - 0.74, 0.52, 4.76, 0.31, c.basalt, "rubber")
            box("Faixa da parede", side * 36, 19.22, dz + (if dz > 28 then 0.66 else -0.66), 50.9, 0.62, 0.17, c.ocher, "paint", TRIM)
        end
        for _, dz in { 10.8, 45.2 } do
            box("Parede de empena", side * 61.4, 11.04, dz, 1.11, 21.58, 18.72, c.concrete, "cement")
            box("Rodapé da empena", side * 62.03, 1.87, dz, 0.22, 2.9, 18.3, c.iron, "steel")
            box("Vidro alto da empena", side * 62.03, 18.63, dz, 0.18, 2.9, 12.6, c.teal, "glass", CLEAR_GLASS)
        end
        box("Verga lateral", side * 61.4, 17.85, 28, 1.11, 8.0, 18.28, c.iron, "steel")
        box("Limitador superior da porta", side * 61.4, 13.61, 28, 1.47, 0.48, 17.69, c.ocher, "metal")
        for _, dz in { 19.7, 36.3 } do
            box("Cantoneira lateral", side * 61.48, 6.95, dz, 1.51, 13.34, 0.46, c.iron, "steel")
        end
        beamZY(roof, "Treliça da empena", -1.55, 22.21, 28, 30.4, side * 62.1, 0.49, 0.78, c.zinc, "steel")
        beamZY(roof, "Treliça da empena", 28, 30.4, 57.55, 22.21, side * 62.1, 0.49, 0.78, c.zinc, "steel")
        roof("Pilar de empena", side * 62.1, 26.06, 28, 0.62, 7.72, 0.67, c.iron, "steel")
    end
    for _, dz in { 1.5, 54.5 } do
        box("Verga do portão central", 0, 17.57, dz, 19.1, 7.08, 1.21, c.iron, "steel")
        box("Trilho superior", 0, 13.98, dz, 19.18, 0.47, 1.7, c.zinc, "steel")
        lightBar(ctx, box, c, 0, 13.63, dz - 0.98, 10.8, c.amber, 20, 1.44)
    end
    for bay = -3, 3 do
        local dx = bay * 18.2
        local finish = if (phase + bay) % 3 == 0 then c.petrol else c.slate
        beamZY(roof, "Chapa da vertente", -1.65, 22.21, 28, 30.4, dx, 18.27, 0.53, finish, "roof")
        beamZY(roof, "Chapa da vertente", 28, 30.4, 57.65, 22.21, dx, 18.27, 0.53, finish, "roof")
        beamZY(roof, "Costura da vertente", -1.65, 22.65, 28, 30.84, dx - 9.0, 0.42, 0.37, c.iron, "steel")
        beamZY(roof, "Costura da vertente", 28, 30.84, 57.65, 22.65, dx - 9.0, 0.42, 0.37, c.iron, "steel")
    end
    roof("Cumeeira", 0, 30.6, 28, 128.1, 0.83, 1.64, c.oxide, "steel")
    for _, dz in { -1.91, 57.91 } do
        roof("Calha", 0, 22.06, dz, 128.1, 0.52, 0.78, c.iron, "steel")
    end
    for _, dx in { -48, -24, 0, 24, 48 } do
        box("Viga da tesoura", dx, 21.02, 28, 0.61, 0.69, 54.59, c.iron, "steel")
        beamZY(box, "Diagonal da tesoura", 1.5, 21.04, 28, 30.28, dx, 0.52, 0.54, c.iron, "steel")
        beamZY(box, "Diagonal da tesoura", 28, 30.28, 54.5, 21.04, dx, 0.52, 0.54, c.iron, "steel")
        for _, dz in { 15, 41 } do
            lightBar(ctx, box, c, dx, 20.36, dz, 3.8, if dx == 0 then c.milk else c.amber, 21, 1.45)
        end
    end

    for _, side in { -1, 1 } do
        local dx = side * 32.9
        box("Portão de enrolar", dx, 5.12, 0.78, 18.08, 9.4, 0.4, c.petrol, "metal", TRIM)
        box("Caixa do portão de enrolar", dx, 10.23, 0.48, 18.7, 1.02, 0.86, c.iron, "steel", TRIM)
        for rib = 1, 7 do
            box("Lâmina do portão", dx, 0.78 + rib * 1.013, 0.5, 17.52, 0.16, 0.23, c.zinc, "metal", TRIM)
        end
        box("Marquise de carga", dx, 11.63, -5.77, 37.3, 0.57, 11.08, c.slate, "steel", { pitch = -3 })
        box("Borda da marquise", dx, 11.29, -11.29, 37.7, 0.76, 0.43, c.oxide, "steel")
        for _, leg in { -1, 1 } do
            box("Pilar da marquise", dx + leg * 17.07, 5.73, -10.93, 0.79, 11.08, 0.83, c.iron, "steel")
        end
        lightBar(ctx, box, c, dx, 11.04, -9.17, 10.65, c.amber, 17, 1.45)
        box("Escudo do respiradouro", side * 25, 8.35, 53.82, 10.83, 2.53, 0.48, c.slate, "metal", TRIM)
        for vane = 1, 2 do
            box("Lâmina do respiradouro", side * 25, 7.41 + vane * 0.57, 53.55, 9.84, 0.15, 0.28, c.zinc, "metal", TRIM)
        end
        pallet(box, c, side * 24, 44, c.wood, side == 1)
        pallet(box, c, side * 41, 12.6, c.ocher, side == -1)
        local rackX, rackZ = side * 36.3, 46.34
        for _, leg in { -1, 1 } do
            for _, foot in { -1, 1 } do
                box("Montante da estante", rackX + leg * 4.97, 4.48, rackZ + foot * 1.21, 0.39, 8.4, 0.42, c.iron, "steel")
            end
        end
        for tier = 1, 3 do
            local shelfY = 1.95 + (tier - 1) * 2.58
            local crate = if (tier + phase) % 2 == 0 then c.wood else c.oxide
            box("Prateleira de carga", rackX, shelfY, rackZ, 10.29, 0.37, 2.84, c.zinc, "steel")
            box("Caixote na estante", rackX + side * (tier - 2) * 2.4, shelfY + 0.94, rackZ, 3.82, 1.51, 2.44, crate, "wood")
        end
    end
    if docks then
        local sign = box("Letreiro da doca", 0, 17.24, 0.72, 15.53, 3.92, 0.49, c.basalt, "metal")
        box("Friso do letreiro", 0, 19.32, 0.46, 16.33, 0.23, 0.24, c.cyan, "neon", TRIM)
        if ctx.sign then
            ctx.sign(sign, "Front", "DOCA DO SAL", c.milk)
        end
    end
end

function Commerce.industrial(ctx, parent, x, z, seed, variant)
    local c = palette(ctx)
    local docks = variant == "docks"
    local phase = math.floor(seed or 0) % 5
    local model, yard = station(ctx, parent, if docks then "Pátio da Doca do Sal" else "Pátio de Armazenagem", x, z)
    yard("Plataforma de carga", 0, -0.16, 0, 177, 0.46, 171, c.paving, "cement")
    yard("Pavimento de serviço", 0, 0.03, -43, 115.2, 0.12, 76, c.grout, "asphalt")
    warehouseHall(ctx, model, c, x, z, phase, docks)
    for _, side in { -1, 1 } do
        yard("Trilho de carga", side * 12.1, 0.115, -43, 0.19, 0.06, 77, c.zinc, "steel", TRIM)
        yard("Borda do trilho", side * 13.18, 0.115, -43, 0.07, 0.023, 77, c.ocher, "paint", TRIM)
        for _, dz in { -76.5, -16.9, 70.8 } do
            yard("Defensa", side * 12.2, 1.22, dz, 2.28, 0.64, 0.64, c.iron, "steel", VERTICAL_CYLINDER)
            yard("Ponta refletiva", side * 12.2, 1.99, dz, 0.2, 0.7, 0.7, c.ocher, "paint", COLLAR)
        end
        local finish = if (phase + side) % 2 == 0 then c.petrol else c.oxide
        cargoContainer(yard, c, side * 67, if side == 1 then -33 else -58, 0.1, finish)
        pallet(yard, c, side * 31, -19.7, c.wood, side == -1)
        yard("Balizador da faixa lateral", side * 70.4, 1.26, 19.1, 2.3, 0.61, 0.61, c.ocher, "metal", VERTICAL_CYLINDER)
        yard("Poste de serviço", side * 72.7, 5.59, -6.7, 0.56, 10.92, 0.62, c.iron, "steel")
        lightBar(ctx, yard, c, side * 72.7, 10.92, -6.7, 3.48, c.amber, 16, 1.37)
    end
    drain(yard, c, -24, 62.6)
    if docks then
        freightGantry(ctx, model, c, x, z)
        cargoContainer(yard, c, -67, -58, 7.96, c.oxide)
    else
        local _, tank = station(ctx, model, "Reservatórios da cobertura", x, z)
        waterTower(tank, c, -28.7, 38.2, 26.96, 4.52, 9.0, c.petrol)
        waterTower(tank, c, 19.5, 18.8, 27.15, 5.73, 10.5, c.zinc)
        tank("Linha de retorno", -6.0, 30.02, 38.2, 36.7, 0.85, 0.85, c.teal, "metal", PIPE_X)
        yard("Trocador do pátio", 35.7, 4.09, -55.4, 16.0, 7.9, 7.24, c.petrol, "metal")
        for rib = -3, 3 do
            yard("Aleta de trocador", 35.7 + rib * 2.04, 4.25, -59.18, 0.46, 5.71, 0.68, c.iron, "metal", TRIM)
        end
        lightBar(ctx, yard, c, 35.7, 8.28, -59.09, 9.2, c.cyan, 15, 1.21)
    end
    return model
end

local function pumpHouse(ctx, parent, c, x, z)
    local _, box = station(ctx, parent, "Casa de bombas do dique", x, z)
    box("Soleira da casa de bombas", -46, -0.02, 31, 52.7, 0.53, 43.4, c.tile, "cement")
    box("Corpo de alvenaria", -46, 10.83, 31, 50.3, 21.13, 41.3, c.concrete, "cement")
    box("Cobertura de chapa", -46, 21.54, 31, 52.5, 0.79, 43.0, c.slate, "roof")
    box("Patamar de manutenção", -46, 0.34, 7.97, 34.44, 0.58, 5.6, c.zinc, "cement")
    box("Faixa da fachada", -46, 9.93, 10.15, 49.9, 0.67, 0.31, c.petrol, "paint", TRIM)
    for _, dx in { -70.75, -56.7, -35.3, -21.25 } do
        box("Pilarete da fachada", dx, 10.98, 10.13, 0.61, 20.4, 0.72, c.iron, "steel")
    end
    box("Porta técnica", -46, 4.08, 10.19, 8.59, 7.74, 0.45, c.slate, "metal")
    box("Junta da porta", -46, 4.2, 9.93, 0.14, 7.21, 0.14, c.zinc, "metal", TRIM)
    box("Puxador", -44.63, 3.7, 9.78, 0.3, 0.83, 0.22, c.ocher, "steel")
    for _, side in { -1, 1 } do
        local dx = -46 + side * 15.8
        box("Caixa de ventilação", dx, 14.2, 10.07, 9.37, 4.63, 0.61, c.iron, "steel")
        box("Grade de ventilação", dx, 14.2, 9.72, 8.68, 3.87, 0.18, c.basalt, "metal", TRIM)
        for blade = 1, 5 do
            box("Lâmina de ventilação", dx, 12.55 + blade * 0.55, 9.55, 8.32, 0.19, 0.47, c.zinc, "metal", TRIM)
        end
        box("Fixa-cabo da fachada", dx, 19.72, 9.97, 0.53, 0.71, 0.76, c.iron, "steel")
        lightBar(ctx, box, c, dx, 8.96, 9.71, 4.35, c.amber, 14, 1.17)
    end
    box("Linha de eletroduto", -46, 19.72, 9.72, 47.0, 0.38, 0.38, c.iron, "metal", PIPE_X)
    box("Lanternim da casa de bombas", -52.0, 23.08, 35.16, 20.53, 2.6, 14.1, c.iron, "metal")
    box("Cumeeira do lanternim", -52.0, 24.54, 35.16, 21.2, 0.4, 14.77, c.zinc, "steel")
    box("Vidraça do lanternim", -52.0, 23.08, 27.99, 17.78, 1.46, 0.2, c.teal, "glass", CLEAR_GLASS)
    waterTower(box, c, -36.5, 38.1, 21.94, 5.44, 9.22, c.zinc)
    box("Saída de exaustão", -65.5, 24.43, 42.8, 5.55, 2.1, 2.1, c.slate, "metal", VERTICAL_CYLINDER)
    box("Coroa de exaustão", -65.5, 27.23, 42.8, 0.41, 2.67, 2.67, c.zinc, "metal", VERTICAL_CYLINDER)
end

local function pumpManifold(box, c)
    for _, pipeY in { 2.69, 4.87 } do
        box("Adutora da casa de bombas", -44.9, pipeY, -1.9, 48.8, 1.35, 1.35, if pipeY > 3 then c.zinc else c.teal, "metal", PIPE_X)
        for _, dx in { -68.75, -55.9, -42.4, -30.4, -21.03 } do
            box("Flange da adutora", dx, pipeY, -1.9, 0.44, 1.78, 1.78, c.iron, "metal", PIPE_X)
        end
        box("Curva da adutora", -20.43, pipeY, 2.97, 9.73, 1.36, 1.36, c.teal, "metal", PIPE_Z)
        box("Tê da adutora", -20.43, pipeY, -1.89, 1.45, 1.36, 1.37, c.teal, "metal", PIPE_X)
    end
    for _, dx in { -65.7, -50.9, -35.0, -21.1 } do
        box("Base da adutora", dx, 0.46, -1.9, 2.17, 0.69, 2.7, c.concrete, "cement")
        box("Apoio da adutora", dx, 2.74, -1.9, 0.53, 4.65, 0.95, c.iron, "steel")
    end
    box("Haste de válvula", -30.4, 5.67, -1.88, 1.47, 0.37, 0.37, c.iron, "metal", VERTICAL_CYLINDER)
    box("Volante de válvula", -30.4, 6.41, -1.88, 0.24, 1.66, 1.66, c.burntOrange, "metal", VERTICAL_CYLINDER)
end

local function switchyard(ctx, parent, c, x, z)
    local _, box = station(ctx, parent, "Pátio de transformação", x, z)
    box("Fundação da subestação", 45.8, 0.04, -25.44, 46.9, 0.48, 43.74, c.tile, "cement")
    for _, dz in { -37, -15.8 } do
        box("Base antivibração", 45, 0.68, dz, 20.11, 0.72, 13.73, c.basalt, "rubber")
        box("Corpo do transformador", 45, 3.55, dz, 17.42, 5.24, 12.54, c.petrol, "metal")
        box("Tampo do transformador", 45, 6.33, dz, 18.09, 0.54, 13.12, c.iron, "steel")
        for _, side in { -1, 1 } do
            for rib = -4, 4 do
                box("Aleta de resfriamento", 45 + side * 9.11, 3.55, dz + rib * 1.18, 1.4, 4.18, 0.26, c.zinc, "metal", TRIM)
            end
            box("Coletor superior", 45 + side * 9.07, 5.64, dz, 10.74, 0.69, 0.69, c.iron, "metal", PIPE_Z)
        end
        for _, dx in { 39.5, 45, 50.5 } do
            box("Isolador de cerâmica", dx, 7.95, dz, 3.08, 0.86, 0.86, c.basalt, "metal", VERTICAL_CYLINDER)
            for collar = 0, 2 do
                box("Saias do isolador", dx, 7.14 + collar * 0.83, dz, 0.36, 1.32, 1.32, c.zinc, "metal", COLLAR)
            end
            box("Terminal do isolador", dx, 9.57, dz, 0.32, 0.73, 0.73, c.ocher, "metal", VERTICAL_CYLINDER)
        end
        box("Linha de alta tensão", 45, 9.74, dz, 12.12, 0.31, 0.31, c.iron, "metal", PIPE_X)
        box("Gabinete de comando", 31.8, 2.34, dz + 1.1, 3.96, 4.08, 3.22, c.slate, "metal")
        box("Indicador ativo", 29.79, 3.46, dz + 0.68, 0.1, 0.16, 0.52, c.cyan, "neon", TRIM)
    end
    for _, dx in { 28.7, 63.0 } do
        box("Pé do pórtico elétrico", dx, 0.57, -28, 2.3, 0.71, 2.4, c.concrete, "cement")
        box("Pilar elétrico", dx, 11.55, -28, 0.78, 21.91, 0.88, c.iron, "steel")
        box("Travamento do pilar", dx, 14.06, -28, 1.27, 0.3, 1.3, c.oxide, "metal")
    end
    box("Travessa de chaves", 45.85, 21.74, -28, 37.94, 0.59, 0.79, c.iron, "steel")
    for _, dx in { 39.5, 45, 50.5 } do
        box("Chave suspensa", dx, 20.54, -28, 1.87, 1.04, 1.04, c.zinc, "metal", VERTICAL_CYLINDER)
        beamZY(box, "Condutor de descida", -28, 19.69, -36.8, 9.93, dx, 0.09, 0.09, c.basalt, "metal")
        beamZY(box, "Condutor de descida", -28, 19.69, -15.95, 9.93, dx, 0.09, 0.09, c.basalt, "metal")
    end
    lightBar(ctx, box, c, 45.85, 12.15, -45.97, 16.4, c.cyan, 18, 1.5)
    for _, side in { -1, 1 } do
        box("Poste do acesso elétrico", 45.85 + side * 8.0, 6.27, -45.97, 0.52, 11.89, 0.52, c.iron, "steel")
    end
end

local function cistern(ctx, parent, c, x, z, phase)
    local _, box = station(ctx, parent, "Cisterna e recalque", x, z)
    local shell = if phase % 2 == 0 then c.teal else c.petrol
    box("Radier da cisterna", 47.2, 0.02, 41.75, 31.89, 0.5, 30.7, c.tile, "cement")
    box("Base da cisterna", 47.2, 0.91, 41.75, 1.28, 20.95, 20.95, c.concrete, "cement", VERTICAL_CYLINDER)
    box("Casco da cisterna", 47.2, 11.42, 41.75, 20.1, 18.66, 18.66, shell, "metal", VERTICAL_CYLINDER)
    for _, flange in { 2.12, 7.41, 13.0, 19.78 } do
        box("Cinta da cisterna", 47.2, flange, 41.75, 0.46, 19.04, 19.04, c.iron, "steel", COLLAR)
    end
    box("Tampa da cisterna", 47.2, 21.66, 41.75, 0.56, 19.17, 19.17, c.zinc, "metal", VERTICAL_CYLINDER)
    box("Respiro da cisterna", 50.8, 22.63, 41.75, 1.7, 1.94, 1.94, c.iron, "metal", VERTICAL_CYLINDER)
    for _, dx in { 46.2, 48.15 } do
        box("Montante da escada", dx, 11.65, 32.13, 0.26, 21.0, 0.34, c.ocher, "metal")
    end
    for rung = 0, 9 do
        box("Degrau da escada técnica", 47.18, 1.97 + rung * 2.0, 32.13, 2.0, 0.17, 0.24, c.ocher, "metal", TRIM)
    end
    box("Mangote de saída", 36.35, 3.21, 41.75, 6.66, 1.83, 1.83, c.zinc, "metal", PIPE_X)
    box("Junta da saída", 33.04, 3.21, 41.75, 0.47, 2.16, 2.16, c.oxide, "metal", PIPE_X)
    box("Tubo de recalque", 32.78, 3.21, 25.46, 32.43, 1.83, 1.83, c.zinc, "metal", PIPE_Z)
    for _, dz in { 12.2, 23.3, 35.8 } do
        box("Flange de recalque", 32.78, 3.21, dz, 0.47, 2.16, 2.16, c.iron, "metal", PIPE_Z)
        box("Apoio do recalque", 32.78, 1.51, dz, 1.98, 2.52, 1.61, c.concrete, "cement")
    end
    box("Bomba de recalque", 32.78, 2.9, 9.63, 5.46, 5.12, 5.47, c.slate, "metal")
    box("Disjuntor da bomba", 28.89, 2.51, 9.63, 2.42, 4.64, 3.5, c.basalt, "metal")
    lightBar(ctx, box, c, 47.2, 4.71, 32.17, 5.33, c.amber, 14, 1.2)
end

function Commerce.utility(ctx, parent, x, z, seed, variant)
    local c = palette(ctx)
    local grid = variant == "grid"
    local phase = math.floor(seed or 0) % 5
    local model, yard = station(ctx, parent, if grid then "Subestação da Maré" else "Estação de Recalque", x, z)
    yard("Tabuleiro de manutenção", 0, -0.11, 0, 171, 0.41, 169.5, c.paving, "cement")
    yard("Pista de vistoria", 0, 0.105, 0, 13.2, 0.055, 160.4, c.grout, "asphalt", TRIM)
    pumpHouse(ctx, model, c, x, z)
    cistern(ctx, model, c, x, z, phase)
    if grid then
        switchyard(ctx, model, c, x, z)
    else
        waterTower(yard, c, 43.4, -35.7, 0.21, 10.15, 12.5, c.petrol)
        waterTower(yard, c, 64.0, -30.8, 0.21, 7.6, 9.56, c.zinc)
        yard("Conduíte dos reservatórios", 54.1, 2.4, -35.7, 20.36, 1.06, 1.06, c.teal, "metal", PIPE_X)
        yard("Joelho do conduíte", 64, 2.4, -33.2, 5.35, 1.06, 1.06, c.teal, "metal", PIPE_Z)
        yard("Pórtico de serviço", 43.4, 3.55, -19.5, 3.9, 6.8, 2.72, c.basalt, "metal")
        lightBar(ctx, yard, c, 43.4, 6.58, -21, 2.73, c.cyan, 12, 1.2)
    end
    pumpManifold(yard, c)
    for _, side in { -1, 1 } do
        local dx = side * 77
        for _, dz in { -56.5, 56.5 } do
            for _, y in { 1.13, 4.11, 6.59 } do
                yard("Travessa de cerca", dx, y, dz, 0.26, 0.23, 39.25, c.iron, "steel")
            end
            for _, post in { -19.5, 0, 19.5 } do
                yard("Montante de cerca", dx, 3.52, dz + post, 0.52, 6.82, 0.55, c.iron, "steel")
                yard("Sapata da cerca", dx, 0.33, dz + post, 1.03, 0.47, 1.03, c.concrete, "cement")
            end
            for panel = -1, 1, 2 do
                local start = dz + (if panel == -1 then -19.4 else 0)
                beamZY(yard, "Escora da cerca", start, 1.29, start + 19.4, 6.47, dx, 0.13, 0.19, c.zinc, "metal")
            end
        end
        for _, dz in { -73, 73 } do
            yard("Balizador do dique", side * 10.1, 1.34, dz, 2.46, 0.73, 0.73, c.iron, "metal", VERTICAL_CYLINDER)
            yard("Faixa do balizador", side * 10.1, 2.31, dz, 0.27, 0.8, 0.8, c.ocher, "paint", COLLAR)
        end
        for mark = -2, 2 do
            yard("Marca de manutenção", side * 13.75, 0.118, -61.7 + mark * 2.4, 4.5, 0.02, 0.52, c.ocher, "paint", { yaw = 29, collision = false, shadow = false })
        end
        drain(yard, c, side * 20.4, side * 62.3)
        yard("Poste de inspeção", side * 19.3, 5.84, side * 38.4, 0.52, 11.45, 0.55, c.iron, "steel")
        lightBar(ctx, yard, c, side * 19.3, 11.41, side * 38.4, 3.27, c.amber, 18, 1.3)
    end
    cabinet(ctx, yard, c, -23.25, -38.7, c.teal)
    bench(yard, c, -23.36, -48.25)
    pallet(yard, c, -60.2, -37.9, c.petrol, true)
    return model
end

return Commerce
