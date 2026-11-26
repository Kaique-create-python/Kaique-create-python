-- Maré Baixa's commercial and residential parcels. All plans use local studs, with
-- the street entrance on the negative-Z side and the foundation at ground level.
local buildings = {}

local detail = {collision = false, shadow = false}
local glass = {shadow = false, transparency = 0.32}
local thinGlass = {shadow = false, transparency = 0.48}
local cylinder = {shape = "Cylinder", roll = 90}
local rotated = {
    left = {yaw = 45},
    right = {yaw = -45},
}
local faces = {
    {nx = 0, nz = -1, tx = 1, tz = 0, yaw = 0},
    {nx = 1, nz = 0, tx = 0, tz = 1, yaw = -90},
    {nx = 0, nz = 1, tx = -1, tz = 0, yaw = 180},
    {nx = -1, nz = 0, tx = 0, tz = -1, yaw = 90},
}

local function parcel(ctx, parent, x, z, name)
    local rgb = ctx.rgb
    return {
        model = ctx.group(parent, name),
        group = ctx.group,
        lamp = ctx.lamp,
        box = function(group, partName, px, y, pz, sx, sy, sz, color, material, options)
            return ctx.box(group, partName, x + px, y, z + pz, sx, sy, sz, color, material, options)
        end,
        color = {
            foundation = rgb(36, 43, 47),
            paving = rgb(57, 63, 65),
            core = rgb(42, 49, 53),
            cement = rgb(68, 73, 70),
            cast = rgb(85, 86, 79),
            precast = rgb(73, 77, 76),
            ochre = rgb(100, 83, 68),
            teal = rgb(63, 80, 78),
            frame = rgb(34, 44, 50),
            steel = rgb(75, 85, 88),
            black = rgb(25, 33, 38),
            glazing = rgb(49, 71, 76),
            windows = {
                rgb(31, 49, 60), rgb(35, 55, 64), rgb(43, 65, 74),
                rgb(49, 70, 77), rgb(39, 57, 70), rgb(38, 55, 62),
            },
            blinds = {rgb(105, 108, 98), rgb(111, 91, 73), rgb(88, 103, 102)},
            occupied = {rgb(147, 116, 78), rgb(161, 126, 86), rgb(123, 132, 118)},
            warm = rgb(220, 180, 123),
            softWarm = rgb(171, 128, 82),
            red = rgb(179, 58, 54),
            cyan = rgb(79, 163, 166),
            leaf = rgb(49, 66, 54),
            green = rgb(64, 82, 57),
            wood = rgb(113, 87, 61),
        },
    }
end

local function onFace(site, parent, name, side, x, y, z, depth, along, width, height, thickness, color, material, options)
    local dir = faces[side]
    local properties = table.clone(options or {})
    properties.yaw = dir.yaw
    return site.box(parent, name, x + dir.nx * depth + dir.tx * along, y, z + dir.nz * depth + dir.tz * along,
        width, height, thickness, color, material, properties)
end

local function planter(site, parent, x, z, size, bench)
    local box, c = site.box, site.color
    box(parent, "Mureta do vaso", x, 0.75, z, size, 1.5, 4.2, c.cement, "cement")
    box(parent, "Leito do vaso", x, 1.48, z, size - 0.5, 0.25, 3.7, c.foundation, "stone", detail)
    for i = -1, 1 do
        box(parent, "Folhagem baixa", x + i * (size / 3.3), 2.05, z + i * 0.3, size / 3, 1.5, 2.8, if i == 0 then c.green else c.leaf,
            "paint", {shape = "Ball", collision = false, shadow = false})
    end
    if bench then
        box(parent, "Assento de madeira", x, 1.45, z - 2.6, size - 1, 0.35, 1.5, c.wood, "wood")
        for _, sign in {-1, 1} do
            box(parent, "Apoio do banco", x + sign * size * 0.29, 0.69, z - 2.62, 0.42, 1.38, 0.92, c.frame, "metal")
        end
    end
end

local function serviceVent(site, parent, x, y, z, width, depth)
    local box, c = site.box, site.color
    box(parent, "Sapatas do climatizador", x, y + 0.25, z, width + 0.55, 0.5, depth + 0.5, c.black, "rubber", detail)
    box(parent, "Gabinete galvanizado", x, y + 1.7, z, width, 2.4, depth, c.steel, "metal")
    box(parent, "Aro da tomada de ar", x, y + 1.68, z - depth / 2 - 0.07, width - 0.7, 1.55, 0.19, c.black, "metal", detail)
    for i = 1, 3 do
        box(parent, "Lâmina veneziana", x, y + 1.13 + i * 0.29, z - depth / 2 - 0.21, width - 0.86, 0.10, 0.24, c.steel, "metal", detail)
    end
    box(parent, "Tampa de manutenção", x, y + 2.96, z, width + 0.28, 0.14, depth + 0.28, c.precast, "metal", detail)
end

local function paving(site, width, depth, z)
    local p, box, c = site.model, site.box, site.color
    box(p, "Piso drenante da quadra", 0, 0.12, z, width, 0.24, depth, c.paving, "sidewalk")
    local front = z - depth / 2
    box(p, "Transição da rua", 0, 0.08, (front - 91) / 2, 30, 0.16, front + 91, c.cement, "sidewalk")
    for _, x in {-15.7, 15.7} do
        box(p, "Canaleta de soleira", x, 0.248, front + 5.5, 0.35, 0.10, 11, c.frame, "metal", detail)
    end
end

local function aperture(site, parent, name, side, x, z, depth, along, width, height, startY, color)
    local c = site.color
    for _, sign in {-1, 1} do
        onFace(site, parent, name .. " | batente", side, x, startY + height / 2, z, depth, along + sign * width / 2,
            0.5, height, 0.76, color, "metal")
    end
    onFace(site, parent, name .. " | travessa", side, x, startY + height + 0.15, z, depth, along,
        width + 0.48, 0.34, 0.78, color, "metal", detail)
    onFace(site, parent, name .. " | soleira", side, x, startY + 0.08, z, depth, along, width + 0.5, 0.16, 1.4, c.steel, "metal")
end

local function lobby(site, parent, plan)
    local p = site.group(parent, "Térreo e acessos")
    local box, c = site.box, site.color
    local x, z, w, d, top = plan.x, plan.z, plan.w, plan.d, plan.top
    local entry = plan.entry or 14
    local openingHeight = if top >= 18 then 11.5 else 8.6
    local depth = d / 2
    local floor = 0.44
    local spread = w / 2
    local sill = floor + 0.68
    box(p, "Laje de pedra do saguão", x, floor / 2, z, w + 1.1, floor, d + 1.1, c.foundation, "stone")
    box(p, "Piso polido", x, floor + 0.023, z, w - 0.75, 0.046, d - 0.6, c.cast, "tile")
    box(p, "Viga e forro", x, top - 0.67, z, w + 0.7, 1.34, d + 0.7, c.core, "cement")
    box(p, "Degrau externo raso", x, 0.14, z - depth - 1.55, entry + 9, 0.28, 3, c.cast, "stone")
    local sideGlassWidth = spread - entry / 2
    for _, sign in {-1, 1} do
        local middle = sign * (entry / 2 + sideGlassWidth / 2)
        onFace(site, p, "Mureta da fachada", 1, x, (sill + floor) / 2, z, depth, middle, sideGlassWidth, sill - floor, 1.35, c.foundation, "cement")
        onFace(site, p, "Vidro da fachada", 1, x, (openingHeight + sill) / 2, z, depth - 0.08, middle, sideGlassWidth, openingHeight - sill, 0.35,
            c.glazing, "glass", glass)
        onFace(site, p, "Bandeja do caixilho", 1, x, sill, z, depth + 0.08, middle, sideGlassWidth, 0.19, 0.55, c.frame, "metal", detail)
        local count = math.max(1, math.floor(sideGlassWidth / 8.5))
        for i = 1, count do
            local along = sign * (entry / 2 + sideGlassWidth * i / count)
            onFace(site, p, "Montante de vidro", 1, x, (openingHeight + sill) / 2, z, depth + 0.11, along,
                0.27, openingHeight - sill, 0.51, c.frame, "metal", detail)
        end
    end
    onFace(site, p, "Verga de concreto", 1, x, (top + openingHeight) / 2, z, depth, 0, w, top - openingHeight, 1.7,
        plan.accent or c.cement, "cement")
    aperture(site, p, "Pórtico de entrada", 1, x, z, depth + 0.19, 0, entry, openingHeight - floor, floor, c.steel)
    for _, side in {2, 4} do
        local data = faces[side]
        local mullionY = (openingHeight + sill) / 2
        local clear = d * 0.56
        onFace(site, p, "Painel lateral", side, x, (top + openingHeight) / 2, z, spread, 0, d, top - openingHeight, 1.5,
            plan.accent or c.cement, "cement")
        onFace(site, p, "Embasamento lateral", side, x, (sill + floor) / 2, z, spread, 0, d, sill - floor, 1.25, c.foundation, "cement")
        onFace(site, p, "Janela lateral alongada", side, x, mullionY, z, spread - 0.08, 0, clear, openingHeight - sill, 0.34, c.glazing, "glass", glass)
        for _, sign in {-1, 1} do
            onFace(site, p, "Pilar lateral de concreto", side, x, mullionY, z, spread, sign * (clear / 2 + (d - clear) / 4),
                (d - clear) / 2, openingHeight - sill, 1.6, c.core, "cement")
            box(p, "Pilar sobre a laje", x + data.nx * (spread - 4.2), top / 2, z + sign * depth * 0.64,
                2.5, top, 2.5, c.cast, "cement")
        end
        onFace(site, p, "Perfil lateral", side, x, mullionY, z, spread + 0.13, 0,
            0.36, openingHeight - sill, 0.5, c.frame, "metal", detail)
    end

    local service = plan.service or 6
    local serviceCenter = w * 0.24
    local rearHeight = if top >= 18 then 9.5 else 8.5
    local rearLeft = -spread
    for _, edge in {serviceCenter - service / 2, spread} do
        onFace(site, p, "Parede de serviço", 3, x, (rearHeight + floor) / 2, z, depth, (rearLeft + edge) / 2,
            edge - rearLeft, rearHeight - floor, 1.55, c.core, "cement")
        rearLeft = serviceCenter + service / 2
    end
    onFace(site, p, "Viga da doca", 3, x, (top + rearHeight) / 2, z, depth, 0, w, top - rearHeight, 1.6,
        plan.accent or c.cement, "cement")
    aperture(site, p, "Doca de manutenção", 3, x, z, depth + 0.22, serviceCenter, service, rearHeight - floor, floor, c.steel)
    onFace(site, p, "Marquise da doca", 3, x, rearHeight + 0.5, z, depth + 2.0, serviceCenter,
        service + 4.2, 0.55, 5.6, c.frame, "metal")
    onFace(site, p, "Piso do acesso de serviço", 3, x, 0.16, z, depth + 3.0, serviceCenter, service + 3, 0.32, 6, c.cement, "stone")
    for _, sign in {-1, 1} do
        onFace(site, p, "Defensa curta", 3, x, 1.36, z, depth + 1.7, serviceCenter + sign * (service / 2 + 1),
            0.35, 2.7, 0.4, c.steel, "metal")
    end
    local backFixture = onFace(site, p, "Luminária da doca", 3, x, rearHeight - 0.25, z, depth + 0.85, serviceCenter,
        3.75, 0.18, 0.42, c.softWarm, "neon", detail)
    site.lamp(backFixture, c.softWarm, 13, 0.46)

    local canopyW = math.min(w - 3, entry + (plan.portico or 20))
    local overhang = plan.portico and 11.5 or 5.4
    local roofY = openingHeight + 0.72
    box(p, "Estrutura da marquise", x, roofY, z - depth - overhang / 2, canopyW, 1.1, overhang + 0.7, c.frame, "metal")
    box(p, "Rufo da marquise", x, roofY + 0.64, z - depth - overhang / 2, canopyW + 0.65, 0.2, overhang + 1.05, c.steel, "metal", detail)
    for _, sign in {-1, 1} do
        local jambX = x + sign * (canopyW / 2 - 1.8)
        box(p, "Tirante da marquise", jambX, openingHeight / 2, z - depth - overhang + 0.78,
            0.64, openingHeight, 0.64, c.steel, "metal")
        local lamp = box(p, "Difusor de entrada", x + sign * (entry * 0.25 + 0.5), roofY - 0.58, z - depth - overhang / 2,
            0.62, 0.13, overhang * 0.62, c.warm, "neon", detail)
        if sign == -1 then
            site.lamp(lamp, c.warm, if plan.portico then 22 else 15, 0.62)
        end
    end

    local counterX = x + w * 0.25
    local counterZ = z + d * 0.12
    box(p, "Balcão de atendimento", counterX, 1.94, counterZ, w * 0.21, 3.0, 2.6, c.frame, "metal")
    box(p, "Tampo de atendimento", counterX, 3.53, counterZ, w * 0.22, 0.28, 3.06, c.wood, "wood")
    box(p, "Rodapé do balcão", counterX, 0.68, counterZ - 1.37, w * 0.195, 0.22, 0.17, c.steel, "metal", detail)
    box(p, "Balcão de espera", x - w * 0.28, 1.19, z - d * 0.18, w * 0.17, 1.45, 2.0, c.wood, "wood")
    box(p, "Costas do banco", x - w * 0.28, 2.16, z - d * 0.18 + 0.83, w * 0.17, 0.61, 0.36, c.frame, "metal")
    local backRoomX = x + w * 0.28
    local backRoomZ = z + depth - 8
    box(p, "Divisória do núcleo", backRoomX - 6.3, 4.75, backRoomZ + 1.4, 0.5, 8.6, 11.3, c.cement, "cement")
    box(p, "Cabeceira da sala técnica", backRoomX, 4.75, backRoomZ - 4.25, 13, 8.6, 0.7, c.cement, "cement")
    box(p, "Porta de inspeção", backRoomX, 4.68, backRoomZ - 4.68, 5.25, 8.45, 0.35, c.steel, "metal")
    box(p, "Puxador", backRoomX + 1.88, 3.8, backRoomZ - 4.91, 0.16, 1.35, 0.3, c.black, "metal", detail)
    for i = -1, 1 do
        local fixture = box(p, "Forro com difusor", x + i * (w * 0.23), top - 1.43, z - 1.5, 1.1, 0.12, d * 0.46, c.warm, "neon", detail)
        if i == 0 then
            site.lamp(fixture, c.warm, if top >= 18 then 24 else 15, 0.55)
        end
    end
    return p
end

local function chamferedCore(site, parent, plan)
    local box, c = site.box, site.color
    local x, z, w, d, cut = plan.x, plan.z, plan.w, plan.d, plan.cut
    local h = plan.top - plan.bottom
    local mid = plan.bottom + h / 2
    box(parent, "Núcleo da torre", x, mid, z, w - cut * 2, h, d, c.core, "cement")
    for _, ix in {-1, 1} do
        box(parent, "Ala estrutural", x + ix * (w - cut) / 2, mid, z, cut + 0.04, h, d - cut * 2, c.core, "cement")
        for _, iz in {-1, 1} do
            box(parent, "Canto chanfrado", x + ix * (w - cut) / 2, mid, z + iz * (d - cut) / 2, cut * math.sqrt(2) + 0.06, h,
                0.68, c.frame, "steel", if ix == iz then rotated.left else rotated.right)
        end
    end
end

local function curtainWall(site, plan, seed)
    local p = site.group(site.model, plan.name)
    local c = site.color
    local x, z, w, d, cut = plan.x, plan.z, plan.w, plan.d, plan.cut
    local height = plan.top - plan.bottom
    local stories = math.max(1, math.floor(height / plan.pitch + 0.5))
    local step = height / stories
    chamferedCore(site, p, plan)
    for side = 1, 4 do
        local run, depth
        if side % 2 == 1 then
            run, depth = w - cut * 2, d / 2
        else
            run, depth = d - cut * 2, w / 2
        end
        local ribs = math.max(4, math.floor(run / (plan.ribPitch or 12)))
        for i = 0, ribs do
            local along = (i / ribs - 0.5) * run
            local heavy = i == 0 or i == ribs or i % 3 == 0
            onFace(site, p, "Montante da fachada", side, x, plan.bottom + height / 2, z, depth + (if heavy then 0.55 else 0.44), along,
                if heavy then 0.85 else 0.31, height, if heavy then 1.25 else 0.58, if heavy then c.steel else c.frame, "metal", detail)
        end
        for row = 1, stories do
            local floor = plan.bottom + (row - 1) * step
            local tint = (seed + side * 23 + row * 11) % #c.windows + 1
            local glazingH = step * (plan.glaze or 0.7)
            local y = floor + step * 0.55
            onFace(site, p, "Fita de vidro fumê", side, x, y, z, depth + 0.145, 0, run - 0.26, glazingH, 0.31,
                c.windows[tint], "glass", detail)
            local hash = (seed * 37 + side * 19 + row * 31) % 100
            if hash < 45 then
                local bay = ((row * 9 + seed + side * 5) % ribs + 0.5) / ribs
                local filled = if hash < 17 then c.occupied[(hash + row) % #c.occupied + 1] else c.blinds[(hash + side) % #c.blinds + 1]
                onFace(site, p, "Vidro com persiana", side, x, y, z, depth + 0.345, (bay - 0.5) * run,
                    run / ribs - 0.45, glazingH - 0.35, 0.22, filled, if hash < 12 then "neon" else "glass", detail)
            end
            if row % 4 == 0 and side == 1 then
                onFace(site, p, "Pingadeira da fachada", side, x, floor + 0.6, z, depth + 0.23, 0, run + 0.6, 0.68, 0.7,
                    c.frame, "metal", detail)
            end
            if plan.hotel and side == 1 and row % 2 == 1 then
                onFace(site, p, "Laje da varanda contínua", side, x, floor + 0.8, z, depth + 1.45, 0, run * 0.89, 0.62, 3.1, c.precast, "cement")
                onFace(site, p, "Guarda-corpo da varanda", side, x, floor + 2.55, z, depth + 2.9, 0, run * 0.89, 2.95, 0.21, c.glazing, "glass", thinGlass)
                onFace(site, p, "Corrimão da varanda", side, x, floor + 4.05, z, depth + 2.9, 0, run * 0.9, 0.19, 0.47, c.steel, "metal", detail)
            end
        end
    end
    return p
end

local function guard(site, parent, x, z, y, w, d, solid)
    local c = site.color
    for side = 1, 4 do
        local span = if side % 2 == 1 then w else d
        local depth = if side % 2 == 1 then d / 2 else w / 2
        onFace(site, parent, "Guarda da cobertura", side, x, y + 1.45, z, depth, 0, span, 2.9, 0.24,
            if solid then c.frame else c.glazing, if solid then "metal" else "glass", if solid then nil else thinGlass)
        onFace(site, parent, "Cimalha metálica", side, x, y + 2.91, z, depth, 0, span + 0.26, 0.29, 0.53, c.steel, "metal", detail)
    end
end

local function setback(site, plan, thickness, safe)
    local p = site.group(site.model, "Terraço de recuo")
    local box, c = site.box, site.color
    local w, d = plan.w + 3.1, plan.d + 3.1
    box(p, "Laje do terraço", plan.x, plan.top + thickness / 2, plan.z, w, thickness, d, c.precast, "cement")
    box(p, "Viga de borda", plan.x, plan.top + 0.28, plan.z, w + 0.75, 0.44, d + 0.75, c.frame, "metal", detail)
    if safe then
        guard(site, p, plan.x, plan.z, plan.top + thickness, w - 0.7, d - 0.7, false)
    end
    return p
end

local function rooftopPlant(site, group, x, z, y, width, height)
    local box, c = site.box, site.color
    box(group, "Casa de máquinas", x, y + height / 2, z, width, height, width * 0.66, c.core, "cement")
    box(group, "Capa da casa de máquinas", x, y + height + 0.22, z, width + 1.2, 0.44, width * 0.66 + 1.0, c.steel, "metal")
    box(group, "Porta da cobertura", x + width * 0.23, y + 4, z - width * 0.33 - 0.09, 4.5, 8, 0.24, c.frame, "metal", detail)
    serviceVent(site, group, x - width * 0.24, y, z - width * 0.55, width * 0.34, 3.25)
    serviceVent(site, group, x + width * 0.13, y + height + 0.44, z, width * 0.36, 4.2)
end

local function observatory(site, plan, floor)
    local p = site.group(site.model, "Átrio elevado e antena")
    local box, c = site.box, site.color
    local x, z = plan.x, plan.z
    local w, d = 43, 47
    local base, ceiling = floor, floor + 25.5
    for _, ix in {-1, 1} do
        for _, iz in {-1, 1} do
            box(p, "Pilar do átrio", x + ix * w / 2, base + 13.35, z + iz * d / 2, 1.85, 26.7, 1.85, c.steel, "steel")
        end
        box(p, "Viga principal", x + ix * (w / 2 - 3), base + 26.8, z, 1.6, 2.7, d + 8, c.frame, "steel")
        box(p, "Banco da galeria", x + ix * 13.8, base + 0.75, z + 5.5, 2.2, 1.5, 9, c.wood, "wood")
    end

    for side = 1, 4 do
        local span = if side % 2 == 1 then w else d
        local depth = if side % 2 == 1 then d / 2 else w / 2
        local roomGap = if side == 1 then 12 else 0
        local bayWidth = (span - roomGap) / 2
        for _, sign in {-1, 1} do
            local center = sign * (roomGap + bayWidth) / 2
            onFace(site, p, "Painel de vidro panorâmico", side, x, base + 10.65, z, depth, center, bayWidth, 20.75, 0.37, c.glazing, "glass", thinGlass)
            onFace(site, p, "Meia-travessa panorâmica", side, x, base + 10.8, z, depth + 0.2, center, bayWidth, 0.36, 0.33,
                c.frame, "metal", detail)
            onFace(site, p, "Montante de vidro panorâmico", side, x, base + 10.65, z, depth + 0.2, center, 0.52, 20.75, 0.85,
                c.steel, "metal", detail)
        end
        onFace(site, p, "Faixa da casa de máquinas", side, x, base + 23.2, z, depth, 0, span, 4.45, 0.85, c.frame, "metal")
    end
    aperture(site, p, "Passagem panorâmica", 1, x, z, d / 2 + 0.07, 0, 12, 11, base, c.steel)
    box(p, "Bandeira do pórtico", x, base + 16.15, z - d / 2, 12, 10.3, 0.37, c.glazing, "glass", thinGlass)
    box(p, "Cobertura da galeria", x, ceiling + 0.6, z, 48, 1.2, 51, c.core, "steel")
    box(p, "Marquise da galeria", x, base + 11.1, z - d / 2 - 2.8, 14, 0.85, 6.4, c.frame, "metal")
    local fixture = box(p, "Luz de observação", x, base + 10.64, z - d / 2 - 3.2, 6.5, 0.13, 0.44, c.warm, "neon", detail)
    site.lamp(fixture, c.warm, 16, 0.55)
    local overhead = box(p, "Forro iluminado do átrio", x, ceiling - 0.08, z - 3.2, 1.0, 0.16, 30, c.warm, "neon", detail)
    site.lamp(overhead, c.warm, 21, 0.8)

    box(p, "Base estrutural da antena", x + 4.5, 499, z + 4, 10.5, 9.6, 13.7, c.core, "steel")
    box(p, "Terminal inferior do mastro", x + 4.5, 516, z + 4, 5.25, 27, 5.25, c.frame, "steel")
    box(p, "Mastro segmentado", x + 4.5, 539.5, z + 4, 2.15, 52, 2.15, c.steel, "steel")
    box(p, "Ponta do mastro", x + 4.5, 569.25, z + 4, 0.76, 10.5, 0.80, c.steel, "steel")
    local beacon = box(p, "Baliza de topo", x + 4.5, 574, z + 4, 1.3, 2.0, 1.3, c.red, "neon", detail)
    site.lamp(beacon, c.red, 14, 0.7)
    for _, level in {520, 532, 548} do
        box(p, "Travessa de antena", x + 4.5, level, z + 4, 16.5 - (level - 520) / 4, 0.48, 0.86, c.steel, "metal", detail)
    end
    for _, sign in {-1, 1} do
        box(p, "Faca de coroamento", x + sign * 24, 499.6, z - 15.6, 2.7, 10.8, 22.2, c.frame, "steel")
        box(p, "Recorte vertical do coroamento", x + sign * 24, 507.2, z - 19, 2.7, 4.4, 15.4, c.steel, "steel")
    end
    serviceVent(site, p, x - 13, ceiling + 1.2, z + 8, 8.3, 5)
end

local function skybridge(site, west, east, level)
    local p = site.group(site.model, "Passarela técnica elevada")
    local box, c = site.box, site.color
    local from = west.x + west.w / 2 - 0.45
    local to = east.x - east.w / 2 + 0.45
    local mid, length = (from + to) / 2, to - from
    local z = (west.z + east.z) / 2
    box(p, "Laje da passarela", mid, level, z, length, 1.0, 17, c.frame, "steel")
    box(p, "Cobertura da passarela", mid, level + 9.0, z, length, 1.0, 17, c.frame, "steel")
    for _, sign in {-1, 1} do
        local edge = z + sign * 8
        box(p, "Vidro da passarela", mid, level + 4.5, edge, length, 8.1, 0.30, c.glazing, "glass", thinGlass)
        box(p, "Treliça inclinada", mid, level + 4.5, edge + sign * 0.14, math.sqrt(length ^ 2 + 8 ^ 2), 0.38, 0.6,
            c.steel, "steel", {collision = false, shadow = false, roll = sign * math.deg(math.atan2(8, length))})
        box(p, "Guia de luz embutida", mid, level + 0.58, edge + sign * 0.15, length - 0.6, 0.18, 0.27, c.cyan, "neon", detail)
        for i = 0, 3 do
            box(p, "Pilar da passarela", from + i * length / 3, level + 4.5, edge, 0.37, 9, 0.68, c.steel, "metal", detail)
        end
    end
end

local towerPlans = {
    vertice = {
        name = "Torre Vértice",
        width = 164, depth = 160, plaza = 0,
        lobby = {x = 0, z = -1, w = 110, d = 124, top = 24, entry = 18, portico = 30, service = 12},
        masses = {
            {name = "Volume inferior", x = -4, z = 3, w = 101, d = 108, cut = 8, bottom = 24, top = 184, pitch = 14, ribPitch = 12.5},
            {name = "Volume intermediário", x = 8, z = 5, w = 81, d = 91, cut = 9, bottom = 186, top = 330, pitch = 14.5, ribPitch = 14},
            {name = "Volume superior", x = -4, z = 8, w = 63, d = 81, cut = 10, bottom = 332, top = 466, pitch = 15.2, ribPitch = 13},
        },
    },
    finance = {
        name = "Banco das Docas",
        width = 146, depth = 144, plaza = 1,
        lobby = {x = 0, z = -8, w = 114, d = 100, top = 20, entry = 15, portico = 27, service = 10},
        masses = {
            {name = "Base de câmaras", x = -3, z = -4, w = 100, d = 86, cut = 6, bottom = 20, top = 105, pitch = 12.4, ribPitch = 14, glaze = 0.64},
            {name = "Pavimentos bureaus", x = 8, z = -1, w = 77, d = 75, cut = 7, bottom = 107, top = 247, pitch = 12.5, ribPitch = 12, glaze = 0.65},
            {name = "Casa do cofre de dados", x = 18, z = 0, w = 53, d = 59, cut = 7, bottom = 249, top = 292, pitch = 11.5, ribPitch = 12, glaze = 0.58},
        },
    },
    tech = {
        name = "Instituto de Transmissão Nacar",
        width = 160, depth = 140, plaza = 2,
        lobby = {x = 0, z = -10, w = 124, d = 94, top = 21, entry = 16, portico = 23, service = 11},
        masses = {
            {name = "Nave de transmissão", x = -28, z = 1, w = 57, d = 81, cut = 5.5, bottom = 21, top = 254, pitch = 15, ribPitch = 13},
            {name = "Nave de refrigeração", x = 35, z = -1, w = 43, d = 62, cut = 5.5, bottom = 21, top = 191, pitch = 16, ribPitch = 11, glaze = 0.75},
        },
    },
    hotel = {
        name = "Hotel Sirena",
        width = 144, depth = 143, plaza = 0,
        lobby = {x = 0, z = -3, w = 106, d = 114, top = 21, entry = 14, portico = 29, service = 9},
        masses = {
            {name = "Ala de suítes", x = 1, z = -5, w = 91, d = 75, cut = 8, bottom = 21, top = 175, pitch = 12, ribPitch = 17, glaze = 0.67, hotel = true},
            {name = "Ala da piscina suspensa", x = -10, z = 5, w = 69, d = 60, cut = 8, bottom = 177, top = 238, pitch = 12, ribPitch = 12, glaze = 0.7, hotel = true},
        },
    },
}

local function addFacadeLighting(site, parent, layout, sides, accent)
    local feature = site.group(parent, "Frisos luminosos da torre")
    local c = site.color
    for _, mass in layout.masses do
        local height = mass.top - mass.bottom
        for _, side in sides do
            local run = if side % 2 == 1 then mass.w else mass.d
            local depth = if side % 2 == 1 then mass.d / 2 else mass.w / 2
            local bay = run / 2 - mass.cut - 5.8
            for _, offset in {-bay, bay} do
                local width = if offset > 0 then 2.4 else 1.2
                onFace(site, feature, "Estrutura do friso", side, mass.x, (mass.top + mass.bottom) / 2, mass.z,
                    depth + 1.23, offset, width + 1.9, height - 3.4, 0.85, c.frame, "steel", detail)
                for band = 1, 3 do
                    local piece = (height - 8) / 3
                    onFace(site, feature, "Tubos luminosos", side, mass.x,
                        mass.bottom + 4 + piece * (band - 0.5), mass.z, depth + 1.72, offset,
                        width, piece - 2.4, 0.19, accent, "neon", detail)
                end
            end
        end
    end
    local g = layout.lobby
    local light = site.box(feature, "Acento do térreo", g.x, 11.91, g.z - g.d / 2 - 5.32, g.entry + 11, 0.16,
        0.4, accent, "neon", detail)
    site.lamp(light, accent, 33, 1.74, "Bottom")
end

function buildings.tower(ctx, parent, x, z, seed, variant)
    local layout = assert(towerPlans[variant], "unknown tower variant")
    local site = parcel(ctx, parent, x, z, layout.name)
    local p, c, box = site.model, site.color, site.box
    paving(site, layout.width, layout.depth, layout.plaza)
    local ground = table.clone(layout.lobby)
    ground.accent = if variant == "hotel" then c.ochre elseif variant == "tech" then c.teal else c.cement
    local lobbyModel = lobby(site, p, ground)
    for _, sign in {-1, 1} do
        planter(site, p, sign * (ground.w * 0.33), ground.z - ground.d / 2 - 10.6, 18, sign == -1)
        local bollard = box(p, "Balizador do passeio", sign * (ground.entry / 2 + 3.3), 1.55,
            ground.z - ground.d / 2 - 14.8, 3.1, 0.5, 0.52, c.steel, "metal", cylinder)
        local lightY = 3.15
        box(p, "Lente do balizador", sign * (ground.entry / 2 + 3.3), lightY, ground.z - ground.d / 2 - 14.8,
            0.18, 0.45, 0.47, c.softWarm, "neon", {shape = "Cylinder", roll = 90, collision = false, shadow = false})
        if sign == -1 and variant == "hotel" then
            site.lamp(bollard, c.softWarm, 11, 0.33)
        end
    end
    serviceVent(site, lobbyModel, ground.w * 0.35, 0.24, ground.z + ground.d / 2 + 5.4, 8.0, 4.2)
    box(lobbyModel, "Duto da doca", ground.w * 0.35, 6.5, ground.z + ground.d / 2 + 1.1, 0.9, 11.25, 1.04, c.steel, "metal", detail)

    for i, mass in layout.masses do
        curtainWall(site, mass, seed + i * 37)
        setback(site, mass, 2, true)
    end
    if variant == "vertice" then
        addFacadeLighting(site, p, layout, {3, 4}, ctx.rgb(251, 61, 143))
    elseif variant == "tech" and x <= 360 then
        addFacadeLighting(site, p, layout, {3}, ctx.rgb(79, 217, 241))
    elseif variant == "hotel" and x <= 360 then
        addFacadeLighting(site, p, layout, {1, 4}, ctx.rgb(201, 88, 238))
    end
    local upper = layout.masses[#layout.masses]
    if variant == "vertice" then
        observatory(site, upper, upper.top + 2)
        local terrace = site.group(p, "Pórtico sobre o segundo recuo")
        box(terrace, "Costela de fachada", 31, 367, 9, 2.2, 70, 4.0, c.frame, "steel", detail)
        box(terrace, "Lâmina de recuo", 31, 340.5, 9, 2.6, 17, 2.25, c.cyan, "metal", detail)
    elseif variant == "tech" then
        skybridge(site, layout.masses[1], layout.masses[2], 142)
        local first = layout.masses[1]
        local crown = site.group(p, "Antenas de transmissão")
        rooftopPlant(site, crown, first.x + 6, first.z + 9, first.top + 2, 20, 9.4)
        rooftopPlant(site, crown, upper.x + 1, upper.z + 6, upper.top + 2, 17, 6.8)
        box(crown, "Pilar da antena", first.x - 8, 269, first.z - 6, 1.35, 27, 1.35, c.steel, "steel")
        box(crown, "Braço da antena", first.x - 8, 280, first.z - 6, 16.2, 0.50, 0.62, c.steel, "metal", detail)
        box(crown, "Marcador da antena", first.x - 8, 282.8, first.z - 6, 1.4, 0.71, 1.4, c.red, "neon", detail)
    elseif variant == "finance" then
        local crown = site.group(p, "Estruturas do terraço técnico")
        rooftopPlant(site, crown, upper.x + 1, upper.z + 6, upper.top + 2, 25, 11.8)
        for _, sign in {-1, 1} do
            box(crown, "Pilastra de coroamento", upper.x + sign * 18, 302.5, upper.z + 2, 2.6, 17, 26.4, c.frame, "steel")
            box(crown, "Friso de coroamento", upper.x + sign * 18, 311.15, upper.z + 2, 2.8, 0.3, 26.7, c.steel, "metal", detail)
        end
    else
        local crown = site.group(p, "Pérgula do terraço")
        local deck = upper.top + 2
        rooftopPlant(site, crown, upper.x, upper.z + 13, deck, 19, 7.4)
        for _, sign in {-1, 1} do
            for _, distance in {-22, -8} do
                box(crown, "Pilar de pérgula", upper.x + sign * 21, deck + 4.6, upper.z + distance, 0.9, 9.2, 0.84, c.steel, "metal")
            end
            box(crown, "Travessa da pérgula", upper.x + sign * 21, deck + 9.25, upper.z - 15, 1.4, 0.70, 18,
                c.steel, "metal")
        end
        for i = 0, 6 do
            box(crown, "Aleta de sombra", upper.x, deck + 9.55, upper.z - 24 + i * 3,
                43, 0.34, 0.65, c.ochre, "metal", detail)
        end
        box(crown, "Banco da pérgula", upper.x + 16, deck + 0.83, upper.z - 14, 1.85, 1.66, 9.5, c.wood, "wood")
    end
    return p
end

local homes = {
    towers = {
        name = "Torres do Canal",
        width = 165, depth = 156, center = 1,
        court = {x = 0, z = -41, lx = -24, rx = 24},
        wings = {
            {name = "Torre Jordante", x = -44, z = 7, w = 56, d = 67, top = 12.5, entry = 8, floors = 10, finish = "precast", balconies = 1},
            {name = "Torre Baçana", x = 41, z = 19, w = 54, d = 64, top = 12.5, entry = 8, floors = 12, finish = "teal", balconies = 1},
        },
    },
    apartments = {
        name = "Vilas da Maré",
        width = 171, depth = 157, center = 1,
        court = {x = -1, z = 21, lx = -20, rx = 20},
        wings = {
            {name = "Casas do Poente", x = -50, z = -23, w = 50, d = 58, top = 11.6, entry = 7, floors = 4, finish = "ochre", balconies = 1},
            {name = "Casas do Nascente", x = 43, z = -17, w = 58, d = 58, top = 11.6, entry = 8, floors = 5, finish = "cast", balconies = 1},
            {name = "Casas do Pátio", x = -5, z = 54, w = 62, d = 41, top = 11.6, entry = 8, floors = 3, finish = "precast", balconies = 1},
        },
    },
    mixed = {
        name = "Quadra do Arco Velho",
        width = 161, depth = 149, center = 1,
        court = {x = 20, z = -51, lx = -24, rx = 38},
        wings = {
            {name = "Edifício das Varandas", x = -34, z = 0, w = 66, d = 76, top = 14, entry = 9, floors = 9, finish = "teal", balconies = 1},
            {name = "Casa Mista do Arco", x = 46, z = 18, w = 44, d = 56, top = 12.5, entry = 7, floors = 5, finish = "ochre", balconies = 2},
        },
    },
}

local function balcony(site, parent, plan, floor, row, seed)
    local c = site.color
    local side = plan.balconies
    local span = if side == 1 then plan.w else plan.d
    local outer = (if side == 1 then plan.d else plan.w) / 2
    local band = (row * 2 + seed) % 6
    local along = if band < 3 then span * 0.23 else -span * 0.25
    local width = math.min(18, span * 0.39)
    local depth = if row % 3 == 1 then 4.75 else 3.85
    local x, z = plan.x, plan.z
    onFace(site, parent, "Borda da laje da varanda", side, x, floor - 0.22, z, outer + depth / 2 - 0.1, along,
        width, 0.48, depth + 0.46, c.precast, "cement")
    onFace(site, parent, "Painel do guarda-corpo", side, x, floor + 1.51, z, outer + depth, along,
        width, 2.98, 0.33, c.glazing, "glass", thinGlass)
    for _, sign in {-1, 1} do
        onFace(site, parent, "Ala do guarda-corpo", side, x, floor + 1.32, z, outer + depth / 2, along + sign * width / 2,
            0.35, 2.64, depth + 0.2, c.frame, "metal")
    end
    if row % 4 == 2 then
        onFace(site, parent, "Corrimão da varanda", side, x, floor + 3.04, z, outer + depth, along,
            width + 0.25, 0.22, 0.57, c.steel, "metal", detail)
        onFace(site, parent, "Brise da varanda", side, x, floor + 7.1, z, outer + depth * 0.55, along,
            width - 0.4, 0.29, depth * 0.91, c.ochre, "metal", detail)
    end
end

local function finishWing(site, p, plan, seed)
    local box, c = site.box, site.color
    local levelHeight = 10.25
    local first = plan.top
    local height = levelHeight * plan.floors
    local roof = first + height
    local x, z, w, d = plan.x, plan.z, plan.w, plan.d
    local finish = c[plan.finish]
    box(p, "Núcleo dos elevadores", x - w * 0.15, first + height / 2, z + d * 0.09, w * 0.26, height, d * 0.34, c.core, "cement")
    box(p, "Parede do corredor dos apartamentos", x, first + height / 2, z - d * 0.12, w * 0.71, height, 0.86, c.core, "cement")
    for _, ix in {-1, 1} do
        for _, iz in {-1, 1} do
            box(p, "Pilastra independente", x + ix * (w / 2 - 1.3), first + height / 2, z + iz * (d / 2 - 1.3),
                3.8, height, 3.8, finish, "cement")
        end
    end
    for side = 1, 4 do
        local span = if side % 2 == 1 then w else d
        local depth = (if side % 2 == 1 then d else w) / 2
        local step = if side == 1 or side == plan.balconies then 1 else 2
        onFace(site, p, "Vedação do pavimento", side, x, first + height / 2, z, depth - 0.22, 0,
            span - 0.2, height, 0.76, finish, "cement")
        for _, sign in {-1, 1} do
            onFace(site, p, "Faixa vertical da fachada", side, x, first + height / 2, z, depth + 0.34, sign * (span * 0.17),
                1.45, height, 0.7, finish, "cement", detail)
        end
        for row = 1, plan.floors, step do
            local floor = first + (row - 1) * levelHeight
            local tint = (seed + side * 13 + row * 11) % #c.windows + 1
            local length = math.min(step, plan.floors - row + 1)
            onFace(site, p, "Janela horizontal", side, x, floor + 4.95 + (length - 1) * levelHeight / 2, z, depth + 0.235, 0,
                span - 4, 5.24 + (length - 1) * levelHeight, 0.29, c.windows[tint], "glass", detail)
            local pattern = (seed * 13 + side * 23 + row * 37) % 100
            if pattern < 46 then
                local center = (pattern % 3 - 1) * span * 0.27
                onFace(site, p, "Apartamento com persiana", side, x, floor + 4.7, z, depth + 0.435, center, span * 0.14, 4.45, 0.12,
                    if pattern < 18 then c.occupied[(row + side) % #c.occupied + 1] else c.blinds[tint % #c.blinds + 1],
                    if pattern < 10 then "neon" else "glass", detail)
            end
        end
    end

    for row = 1, plan.floors do
        local floor = first + (row - 1) * levelHeight
        box(p, "Laje e junta de dilatação", x, floor - 0.18, z, w + 1.55, 0.40, d + 1.5, c.core, "cement")
        balcony(site, p, plan, floor, row, seed)
        if row % 3 == 2 then
            local y = floor + 2.55
            local acX = x + (if row % 2 == 0 then w * 0.31 else -w * 0.31)
            box(p, "Condensador de janela", acX, y, z + d / 2 + 0.8, 3.4, 1.5, 1.46, c.steel, "metal", detail)
            box(p, "Grelha do condensador", acX, y, z + d / 2 + 1.54, 2.65, 1.02, 0.16, c.black, "metal", detail)
        end
    end

    local cap = roof + 0.9
    box(p, "Laje superior do último pavimento", x, roof + 0.45, z, w + 1.6, 0.9, d + 1.6, c.precast, "roof")
    guard(site, p, x, z, cap, w, d, true)
    local tankZ = z + d * 0.17
    box(p, "Casa da caixa d'água", x - 6, cap + 1.1, tankZ, 15, 2.2, 11, c.core, "cement")
    box(p, "Reservatório cilíndrico", x - 6, cap + 5.0, tankZ, 5.8, 8.1, 8.1, c.frame, "metal", cylinder)
    box(p, "Tampa do reservatório", x - 6, cap + 7.94, tankZ, 0.34, 8.35, 8.35, c.steel, "metal", cylinder)
    serviceVent(site, p, x + w * 0.22, cap, z - d * 0.12, 6.1, 4.15)
end

function buildings.residential(ctx, parent, x, z, seed, variant)
    local layout = assert(homes[variant], "unknown residential variant")
    local site = parcel(ctx, parent, x, z, layout.name)
    local model, c = site.model, site.color
    paving(site, layout.width, layout.depth, layout.center)
    local court = layout.court
    local patio = site.group(model, "Pátio dos moradores")
    site.box(patio, "Ladrilho central do pátio", court.x, 0.255, court.z, court.rx - court.lx + 16, 0.04, 15,
        c.precast, "stone", detail)
    planter(site, patio, court.lx, court.z - 2.5, 12, true)
    planter(site, patio, court.rx, court.z - 2.5, 12, true)
    for _, px in {court.lx + 6.7, court.rx - 6.7} do
        site.box(patio, "Poste do pátio", px, 3.55, court.z + 5.5, 7.1, 0.25, 0.28, c.steel, "metal", cylinder)
        local lamp = site.box(patio, "Luz baixa do pátio", px, 7.25, court.z + 5.5, 1.65, 0.3, 1.1, c.warm, "neon", detail)
        site.lamp(lamp, c.warm, 16, 0.39)
    end
    for index, wing in layout.wings do
        local plan = table.clone(wing)
        plan.accent = c[plan.finish]
        local p = site.group(model, plan.name)
        lobby(site, p, plan)
        finishWing(site, p, plan, seed + index * 37)
    end
    return model
end

return buildings
