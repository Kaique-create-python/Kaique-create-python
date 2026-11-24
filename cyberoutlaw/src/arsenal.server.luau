-- CyberOutlaw arsenal (Script in ServerScriptService).
-- The server holds the weapon rules: equip, ammo, shot and hit validation, damage, and effects.
-- The models are built in code and published in ReplicatedStorage.CyberOutlawArsenal, so the
-- client uses the same pieces in the weapon wheel without images.

local SAFE_CENTER = Vector3.new(108, 0, 108) -- Praça da Maré
local SAFE_RADIUS = 95
local rgb = Color3.fromRGB

-- Armas reais. A ordem define a roleta: punhos no topo, o resto no sentido horário.
-- tipo: punhos, faca, pistola, smg, fuzil, escopeta, sniper. som: chave do tiro; recarga: chave da recarga;
-- acao: som da ação depois do tiro (ferrolho/bomba); alcance: braço de apoio até a mão de trás (studs).
local WEAPONS = {
	{
		id = "punhos", name = "Punhos", kind = "melee", tipo = "punhos", order = 1, damage = 12, rate = 2.6, range = 6.5,
		accent = { 255, 214, 160 }, class = "CORPO A CORPO", desc = "Golpes rápidos. Sempre à mão.",
		stats = { 0.22, 0.82, 0.08, 1.0 }, som = "arma_soco",
	},
	{
		id = "faca", name = "Faca de Combate", kind = "melee", tipo = "faca", order = 2, damage = 34, rate = 1.8, range = 7.5,
		accent = { 255, 214, 160 }, class = "CORPO A CORPO · LÂMINA", desc = "Lâmina de aço com fio serrilhado.",
		stats = { 0.6, 0.62, 0.12, 0.92 }, grip = "frente", som = "arma_lamina",
	},
	{
		id = "glock", name = "Glock 17", kind = "gun", tipo = "pistola", order = 3, damage = 22, rate = 6, auto = false,
		mag = 17, reserve = 102, spread = 1.0, range = 300, pellets = 1, reload = 1.3, recoil = 1.5, fov = 54,
		accent = { 255, 196, 120 }, class = "PISTOLA · 9 MM", desc = "Leve, confiável e com pente de 17 tiros.",
		stats = { 0.4, 0.62, 0.6, 0.9 }, som = "arma_glock", recarga = "arma_recarga", alcance = 1.85,
	},
	{
		id = "deagle", name = "Desert Eagle", kind = "gun", tipo = "pistola", order = 4, damage = 48, rate = 2.4, auto = false,
		mag = 7, reserve = 42, spread = 0.8, range = 360, pellets = 1, reload = 1.7, recoil = 3.6, fov = 50,
		accent = { 255, 186, 104 }, class = "PISTOLA · .50 AE", desc = "Pesada e barulhenta. Um tiro resolve.",
		stats = { 0.8, 0.28, 0.66, 0.72 }, som = "arma_deagle", recarga = "arma_recarga", alcance = 1.85,
	},
	{
		id = "uzi", name = "Uzi", kind = "gun", tipo = "smg", order = 5, damage = 13, rate = 14, auto = true,
		mag = 32, reserve = 192, spread = 2.6, range = 200, pellets = 1, reload = 1.6, recoil = 0.9, fov = 52,
		accent = { 255, 200, 124 }, class = "SUBMETRALHADORA · 9 MM", desc = "Rajada contínua para becos fechados.",
		stats = { 0.3, 0.98, 0.4, 0.62 }, som = "arma_uzi", recarga = "arma_recarga_fuzil", alcance = 1.95,
	},
	{
		id = "ak47", name = "AK-47", kind = "gun", tipo = "fuzil", order = 6, damage = 26, rate = 9.5, auto = true,
		mag = 30, reserve = 150, spread = 1.1, range = 460, pellets = 1, reload = 2.2, recoil = 1.8, fov = 46,
		accent = { 255, 178, 96 }, class = "FUZIL · 7,62 MM", desc = "Robusto, potente e com coice forte.",
		stats = { 0.7, 0.78, 0.86, 0.6 }, som = "arma_ak47", recarga = "arma_recarga_fuzil", alcance = 2.5,
	},
	{
		id = "m4", name = "M4A1", kind = "gun", tipo = "fuzil", order = 7, damage = 22, rate = 11, auto = true,
		mag = 30, reserve = 180, spread = 0.8, range = 480, pellets = 1, reload = 2.0, recoil = 1.2, fov = 46,
		accent = { 255, 196, 120 }, class = "FUZIL · 5,56 MM", desc = "Estável e precisa, com mira holográfica.",
		stats = { 0.6, 0.86, 0.92, 0.7 }, som = "arma_m4", recarga = "arma_recarga_fuzil", alcance = 2.45,
	},
	{
		id = "escopeta", name = "Escopeta Pump", kind = "gun", tipo = "escopeta", order = 8, damage = 11, rate = 1.1,
		auto = false, mag = 8, reserve = 40, spread = 6.0, range = 90, pellets = 9, reload = 2.6, recoil = 4.4, fov = 56,
		accent = { 255, 186, 104 }, class = "ESCOPETA · CALIBRE 12", desc = "Nove bagos de perto. Bombeia a cada tiro.",
		stats = { 0.96, 0.2, 0.18, 0.46 }, som = "arma_escopeta", recarga = "arma_recarga_escopeta",
		acao = "arma_bomba", alcance = 2.65,
	},
	{
		id = "sniper", name = "Sniper .308", kind = "gun", tipo = "sniper", order = 9, damage = 95, rate = 0.8,
		auto = false, mag = 5, reserve = 30, spread = 0.05, range = 900, pellets = 1, reload = 2.8, recoil = 5, fov = 18,
		accent = { 255, 196, 120 }, class = "RIFLE DE PRECISÃO · FERROLHO", desc = "Luneta 8x. Um disparo por vez.",
		stats = { 1.0, 0.1, 1.0, 0.34 }, som = "arma_sniper", recarga = "arma_recarga_fuzil", acao = "arma_ferrolho",
		alcance = 2.75, luneta = true,
	},
}
local BY_ID = {}
for _, def in WEAPONS do
	BY_ID[def.id] = def
end

-- Shared rules (tested in tests/arsenal_test.luau) ------------------------------------------------
local function inSafeZone(position: Vector3): boolean
	local flat = Vector3.new(position.X - SAFE_CENTER.X, 0, position.Z - SAFE_CENTER.Z)
	return flat.Magnitude < SAFE_RADIUS
end

local function damageFor(def, distance: number, headshot: boolean): number
	local range = def.range or 10
	local falloff = if distance <= range * 0.6 then 1 else math.max(0.5, 1 - (distance - range * 0.6) / (range * 0.4) * 0.5)
	return def.damage * falloff * (if headshot then 1.5 else 1)
end

-- Validates a shot without touching the world. Returns true or a reason.
local function checkShot(state, def, now: number, origin, directions, head: Vector3?)
	if not def or def.kind ~= "gun" then
		return false, "sem arma de fogo"
	end
	if state.reloadUntil > now then
		return false, "recarregando"
	end
	local ammo = state.ammo[def.id]
	if not ammo or ammo.mag <= 0 then
		return false, "pente vazio"
	end
	if now < state.nextShot - 0.2 / def.rate then
		return false, "cadência"
	end
	if typeof(origin) ~= "Vector3" or not head or (origin - head).Magnitude > 32 then
		return false, "origem"
	end
	if type(directions) ~= "table" or #directions < 1 or #directions > def.pellets then
		return false, "projéteis"
	end
	for _, direction in directions do
		if typeof(direction) ~= "Vector3" or math.abs(direction.Magnitude - 1) > 0.02 then
			return false, "direção"
		end
	end
	return true
end

local function newState()
	local state = { slot = "punhos", nextShot = 0, nextMelee = 0, reloadUntil = 0, reloadToken = 0, ammo = {}, lastPitch = 0, pitchAt = 0 }
	for _, def in WEAPONS do
		if def.kind == "gun" then
			state.ammo[def.id] = { mag = def.mag, reserve = def.reserve }
		end
	end
	return state
end

-- Implants ---------------------------------------------------------------------------------------
-- Nomes dos implantes do Cyberpunk. slot: onde encaixa no corpo (o boneco do painel marca o lugar);
-- pronto: já funciona no jogo; os outros aparecem no terminal como "em breve". O Sandevistan é o implante
-- militar da coluna do anime: o tempo quase para em volta enquanto o dono deixa rastros coloridos.
local IMPLANTS = {
	{
		id = "sandevistan", name = "Sandevistan Militar", sistema = "SISTEMA OPERACIONAL", slot = "coluna", pronto = true,
		desc = "Implante militar na coluna. Ativado, o tempo quase para: você corre e atira 2x mais rápido e deixa rastros coloridos. Cada uso gasta estabilidade. A zero: ciberpsicose.",
	},
	{
		id = "kiroshi", name = "Ópticos Kiroshi", sistema = "SISTEMA VISUAL", slot = "olhos", pronto = false,
		desc = "Olhos com zoom óptico e marcação de alvos através da fumaça.",
	},
	{
		id = "louva", name = "Lâminas Louva-a-Deus", sistema = "SISTEMA DE BRAÇOS", slot = "bracos", pronto = false,
		desc = "Lâminas que saem dos antebraços para golpes rápidos e saltos de ataque.",
	},
	{
		id = "gorila", name = "Braços de Gorila", sistema = "SISTEMA DE BRAÇOS", slot = "bracos", pronto = false,
		desc = "Punhos reforçados que arrombam portas e derrubam no soco.",
	},
	{
		id = "tendoes", name = "Tendões Reforçados", sistema = "SISTEMA ESQUELÉTICO", slot = "pernas", pronto = false,
		desc = "Pernas sintéticas que deixam dar um segundo pulo no ar.",
	},
	{
		id = "subdermal", name = "Armadura Subdérmica", sistema = "SISTEMA TEGUMENTAR", slot = "pele", pronto = false,
		desc = "Placas sob a pele que seguram parte do dano das balas.",
	},
}
local IMPLANT_BY_ID = {}
for _, def in IMPLANTS do
	IMPLANT_BY_ID[def.id] = def
end

-- Regras do Sandevistan (o servidor decide; o cliente só mostra). duracao e recarga em segundos; custo em
-- pontos de estabilidade (0 a 100); surto: duração da ciberpsicose; depois dela a estabilidade volta a
-- aposSurto; regenera regen pontos/s depois de espera s sem usar. raio: quem estiver perto fica lento.
local SANDEVISTAN = {
	duracao = 4, recarga = 1.5, custo = 25, surto = 2, aposSurto = 40, espera = 8, regen = 2.5,
	raio = 90, lento = 0.3, cadencia = 2, velocidade = 2.2, danoSurto = 14, alcanceSurto = 120,
}

local function newMind()
	return { implants = {}, psy = 100, lastUse = -1000, activeUntil = 0, abilityReady = 0, frenzyUntil = 0, useToken = 0, frenzyToken = 0 }
end

-- Ativa o Sandevistan. Devolve true ou o motivo. Cada uso gasta estabilidade; a zero começa o surto.
local function useSandevistan(mind, now: number)
	if not mind.implants.sandevistan then
		return false, "sem implante"
	end
	if now < mind.frenzyUntil then
		return false, "surto"
	end
	if now < mind.activeUntil then
		return false, "ativo"
	end
	if now < mind.abilityReady then
		return false, "recarga"
	end
	mind.activeUntil = now + SANDEVISTAN.duracao
	mind.abilityReady = mind.activeUntil + SANDEVISTAN.recarga
	mind.psy = math.max(0, mind.psy - SANDEVISTAN.custo)
	mind.lastUse = now
	if mind.psy <= 0 then
		mind.frenzyUntil = now + SANDEVISTAN.surto
	end
	return true
end

-- A estabilidade volta devagar depois de um tempo sem usar; quando o surto acaba, volta a aposSurto.
-- Devolve true quando algo mudou.
local function regenMind(mind, now: number, dt: number): boolean
	if mind.frenzyUntil > 0 and now >= mind.frenzyUntil then
		mind.frenzyUntil = 0
		mind.psy = math.max(mind.psy, SANDEVISTAN.aposSurto)
		mind.lastUse = now
		return true
	end
	if now < mind.activeUntil or mind.frenzyUntil > 0 or now - mind.lastUse < SANDEVISTAN.espera or mind.psy >= 100 then
		return false
	end
	mind.psy = math.min(100, mind.psy + SANDEVISTAN.regen * dt)
	return true
end

-- Encaixa (on = true) ou tira um implante. Só os prontos encaixam; um por lugar do corpo; não troca no meio
-- do efeito nem do surto. Devolve true ou o motivo.
local function setImplant(mind, id: string, on: boolean, now: number)
	local def = IMPLANT_BY_ID[id]
	if not def then
		return false, "implante"
	end
	if now < mind.activeUntil or now < mind.frenzyUntil then
		return false, "em uso"
	end
	if not on then
		mind.implants[id] = nil
		return true
	end
	if not def.pronto then
		return false, "em breve"
	end
	for other in mind.implants do
		if other ~= id and IMPLANT_BY_ID[other] and IMPLANT_BY_ID[other].slot == def.slot then
			mind.implants[other] = nil
		end
	end
	mind.implants[id] = true
	return true
end

-- Models ----------------------------------------------------------------------------------------
-- Weapon space: -Z is the barrel direction, +Y is up. The grip core (PrimaryPart, no rotation) sits in
-- the hand; every other piece is welded to it. Real weapons at about 1.5x scale, without neon.
local STEEL = rgb(44, 45, 50)
local STEEL_DARK = rgb(22, 22, 25)
local STEEL_BARE = rgb(150, 152, 158)
local CHROME = rgb(182, 184, 190)
local POLY = rgb(31, 32, 36)
local RUBBER = rgb(18, 18, 20)
local WOOD = rgb(126, 70, 36)
local WOOD_DARK = rgb(92, 50, 26)
local OLIVE = rgb(84, 88, 64)
local LEATHER = rgb(58, 40, 30)

local function buildModel(def)
	local model = Instance.new("Model")
	model.Name = def.id
	local Metal, Plastic, Wood = Enum.Material.Metal, Enum.Material.SmoothPlastic, Enum.Material.Wood
	local grip
	local function part(name: string, size: Vector3, pose: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape or Enum.PartType.Block
		p.Size = size
		p.CFrame = pose
		p.Color = color
		p.Material = material or Metal
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		if grip then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = grip
			weld.Part1 = p
			weld.Parent = p
		end
		return p
	end
	local function angles(rx: number?, ry: number?, rz: number?)
		return CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
	end
	local function box(name, sx, sy, sz, x, y, z, color, material, rx, ry, rz)
		return part(name, Vector3.new(sx, sy, sz), CFrame.new(x, y, z) * angles(rx, ry, rz), color, material)
	end
	-- Roblox wedge: tall at +Z, sloping down to the front (-Z) bottom edge.
	local function wedge(name, sx, sy, sz, x, y, z, color, material, rx, ry, rz)
		return part(name, Vector3.new(sx, sy, sz), CFrame.new(x, y, z) * angles(rx, ry, rz), color, material, Enum.PartType.Wedge)
	end
	local function tube(name, diameter, length, x, y, z, color, material) -- along Z
		return part(name, Vector3.new(length, diameter, diameter), CFrame.new(x, y, z) * CFrame.Angles(0, math.pi / 2, 0),
			color, material, Enum.PartType.Cylinder)
	end
	local function post(name, diameter, length, x, y, z, color, material) -- along Y
		return part(name, Vector3.new(length, diameter, diameter), CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2),
			color, material, Enum.PartType.Cylinder)
	end
	local function ball(name, diameter, x, y, z, color, material)
		return part(name, Vector3.new(diameter, diameter, diameter), CFrame.new(x, y, z), color, material, Enum.PartType.Ball)
	end
	local function core(sx, sy, sz, color, material)
		grip = part("Empunhadura", Vector3.new(sx, sy, sz), CFrame.identity, color, material)
		return grip
	end
	-- Curved magazine: segments that bend forward (+angle) as they go down.
	local function curvedMag(name, width, depth, y, z, segments, color, material)
		local angle, center = segments[1][2], Vector3.new(0, y, z)
		for index, segment in segments do
			local length, bend = segment[1], segment[2]
			if index > 1 then
				local previous = segments[index - 1]
				local a, b = math.rad(previous[2]), math.rad(bend)
				center += Vector3.new(0, -math.cos(a), -math.sin(a)) * previous[1] / 2
				center += Vector3.new(0, -math.cos(b), -math.sin(b)) * length / 2
			end
			angle = bend
			box(name, width, length, depth, 0, center.Y, center.Z, color, material, bend)
		end
		local last = segments[#segments]
		local a = math.rad(angle)
		local tip = center + Vector3.new(0, -math.cos(a), -math.sin(a)) * (last[1] / 2 + 0.015)
		box("Base do carregador", width + 0.02, 0.03, depth + 0.02, 0, tip.Y, tip.Z, STEEL_DARK, Metal, angle)
	end
	local muzzle
	local id = def.id
	if id == "punhos" then
		-- Fingerless tactical glove, used only as an icon in the wheel and the HUD.
		core(0.6, 0.62, 0.5, rgb(36, 36, 40), Enum.Material.Fabric)
		box("Dedos fechados", 0.62, 0.5, 0.24, 0, 0.02, -0.34, rgb(30, 30, 34), Enum.Material.Fabric)
		for index = 0, 2 do
			box("Vão dos dedos", 0.64, 0.025, 0.25, 0, -0.16 + index * 0.13, -0.34, rgb(12, 12, 14), Plastic)
		end
		box("Protetor dos nós", 0.64, 0.12, 0.27, 0, 0.27, -0.34, STEEL_DARK, Plastic)
		box("Polegar", 0.18, 0.2, 0.38, 0.36, -0.08, -0.2, rgb(30, 30, 34), Enum.Material.Fabric, 0, -18)
		box("Punho da luva", 0.68, 0.32, 0.58, 0, -0.46, 0.02, rgb(48, 48, 52), Enum.Material.Fabric)
		box("Velcro", 0.7, 0.09, 0.6, 0, -0.36, 0.02, rgb(26, 26, 30), Enum.Material.Fabric)
		muzzle = Vector3.new(0, 0, -0.5)
	elseif id == "faca" then
		-- Combat knife (clip point), held with the blade forward.
		core(0.12, 0.15, 0.2, LEATHER, Enum.Material.Fabric)
		box("Cabo", 0.12, 0.15, 0.44, 0, 0, 0.02, LEATHER, Enum.Material.Fabric)
		for index = 0, 3 do
			box("Anel do cabo", 0.13, 0.16, 0.02, 0, 0, -0.16 + index * 0.1, rgb(34, 24, 18), Enum.Material.Fabric)
		end
		box("Pomo", 0.14, 0.17, 0.06, 0, 0, 0.27, STEEL_DARK, Metal)
		box("Guarda", 0.1, 0.32, 0.04, 0, 0, -0.22, STEEL_DARK, Metal)
		box("Lâmina", 0.035, 0.24, 0.74, 0, -0.01, -0.61, rgb(172, 176, 182), Metal)
		box("Fio", 0.03, 0.05, 0.74, 0, -0.11, -0.61, rgb(214, 218, 224), Metal)
		box("Dorso", 0.04, 0.03, 0.52, 0, 0.105, -0.5, rgb(96, 98, 104), Metal)
		box("Sulco", 0.04, 0.03, 0.42, 0, 0.03, -0.52, rgb(120, 124, 130), Metal)
		wedge("Ponta", 0.035, 0.24, 0.3, 0, -0.01, -1.13, rgb(172, 176, 182), Metal)
		muzzle = Vector3.new(0, -0.12, -1.28)
	elseif id == "glock" then
		core(0.12, 0.3, 0.16, POLY, Plastic)
		box("Cabo", 0.15, 0.5, 0.27, 0, -0.04, 0.03, POLY, Plastic, -18)
		box("Base do carregador", 0.17, 0.04, 0.29, 0, -0.29, 0.11, STEEL_DARK, Plastic, -18)
		box("Armação", 0.15, 0.1, 0.8, 0, 0.22, -0.2, POLY, Plastic)
		for index = 0, 2 do
			box("Trilho", 0.155, 0.02, 0.025, 0, 0.165, -0.4 - index * 0.07, STEEL_DARK, Plastic)
		end
		box("Guarda-mato", 0.06, 0.16, 0.05, 0, 0.1, -0.24, POLY, Plastic)
		box("Guarda-mato inferior", 0.06, 0.04, 0.26, 0, 0.03, -0.12, POLY, Plastic)
		box("Gatilho", 0.04, 0.12, 0.04, 0, 0.12, -0.09, STEEL_DARK, Metal, 10)
		box("Ferrolho", 0.155, 0.22, 1.1, 0, 0.38, -0.27, STEEL, Metal)
		box("Topo do ferrolho", 0.12, 0.02, 1.08, 0, 0.495, -0.27, STEEL, Metal)
		box("Janela de ejeção", 0.07, 0.015, 0.2, 0.03, 0.5, -0.07, STEEL_BARE, Metal)
		for index = 0, 5 do
			box("Serrilha", 0.16, 0.15, 0.012, 0, 0.38, 0.22 - index * 0.032, STEEL_DARK, Metal)
		end
		tube("Boca", 0.07, 0.02, 0, 0.4, -0.825, STEEL_DARK, Metal)
		box("Mira frontal", 0.03, 0.045, 0.04, 0, 0.51, -0.76, STEEL_DARK, Metal)
		box("Mira traseira E", 0.04, 0.045, 0.04, -0.04, 0.51, 0.22, STEEL_DARK, Metal)
		box("Mira traseira D", 0.04, 0.045, 0.04, 0.04, 0.51, 0.22, STEEL_DARK, Metal)
		muzzle = Vector3.new(0, 0.4, -0.85)
	elseif id == "deagle" then
		core(0.12, 0.3, 0.16, RUBBER, Plastic)
		box("Cabo", 0.17, 0.56, 0.3, 0, -0.05, 0.04, RUBBER, Plastic, -16)
		box("Base do carregador", 0.18, 0.04, 0.31, 0, -0.33, 0.12, CHROME, Metal, -16)
		box("Armação", 0.17, 0.12, 0.62, 0, 0.24, -0.08, CHROME, Metal)
		box("Guarda-mato", 0.06, 0.15, 0.05, 0, 0.11, -0.27, CHROME, Metal)
		box("Guarda-mato inferior", 0.06, 0.04, 0.28, 0, 0.035, -0.14, CHROME, Metal)
		box("Gatilho", 0.04, 0.12, 0.04, 0, 0.13, -0.1, STEEL_DARK, Metal, 10)
		box("Ferrolho", 0.18, 0.22, 0.62, 0, 0.41, 0.06, CHROME, Metal)
		for index = 0, 4 do
			box("Serrilha", 0.185, 0.16, 0.015, 0, 0.41, 0.3 - index * 0.04, rgb(104, 106, 112), Metal)
		end
		box("Cano", 0.2, 0.18, 1.0, 0, 0.47, -0.62, CHROME, Metal)
		box("Cano inferior", 0.14, 0.1, 1.0, 0, 0.33, -0.62, CHROME, Metal)
		box("Canal do topo", 0.06, 0.02, 0.95, 0, 0.565, -0.6, STEEL_DARK, Metal)
		tube("Boca", 0.09, 0.02, 0, 0.46, -1.125, STEEL_DARK, Metal)
		box("Mira frontal", 0.04, 0.05, 0.06, 0, 0.59, -1.05, STEEL_DARK, Metal)
		box("Mira traseira E", 0.04, 0.05, 0.05, -0.05, 0.545, 0.33, STEEL_DARK, Metal)
		box("Mira traseira D", 0.04, 0.05, 0.05, 0.05, 0.545, 0.33, STEEL_DARK, Metal)
		box("Cão", 0.06, 0.1, 0.06, 0, 0.47, 0.4, STEEL_DARK, Metal, 20)
		muzzle = Vector3.new(0, 0.46, -1.15)
	elseif id == "uzi" then
		core(0.12, 0.3, 0.16, POLY, Plastic)
		box("Cabo", 0.18, 0.58, 0.26, 0, -0.08, 0, POLY, Plastic, -8)
		box("Carregador", 0.14, 0.4, 0.2, 0, -0.52, 0.06, STEEL, Metal, -8)
		box("Base do carregador", 0.15, 0.03, 0.21, 0, -0.735, 0.09, STEEL_DARK, Metal, -8)
		box("Receptor", 0.3, 0.34, 1.12, 0, 0.38, -0.2, STEEL, Metal)
		box("Nervura superior", 0.31, 0.03, 0.9, 0, 0.45, -0.25, STEEL_DARK, Metal)
		box("Nervura inferior", 0.31, 0.03, 0.9, 0, 0.3, -0.25, STEEL_DARK, Metal)
		box("Manopla", 0.08, 0.06, 0.1, 0, 0.58, -0.3, STEEL_DARK, Metal)
		box("Mira traseira E", 0.05, 0.1, 0.06, -0.1, 0.6, 0.28, STEEL_DARK, Metal)
		box("Mira traseira D", 0.05, 0.1, 0.06, 0.1, 0.6, 0.28, STEEL_DARK, Metal)
		box("Proteção da mira E", 0.03, 0.1, 0.06, -0.08, 0.6, -0.7, STEEL_DARK, Metal)
		box("Proteção da mira D", 0.03, 0.1, 0.06, 0.08, 0.6, -0.7, STEEL_DARK, Metal)
		box("Mira frontal", 0.03, 0.08, 0.03, 0, 0.59, -0.7, STEEL_DARK, Metal)
		tube("Porca do cano", 0.16, 0.06, 0, 0.36, -0.79, STEEL, Metal)
		tube("Cano", 0.1, 0.2, 0, 0.36, -0.92, STEEL_DARK, Metal)
		box("Guarda-mão", 0.26, 0.1, 0.42, 0, 0.16, -0.48, POLY, Plastic)
		box("Guarda-mato", 0.06, 0.17, 0.05, 0, 0.12, -0.32, STEEL, Metal)
		box("Guarda-mato inferior", 0.06, 0.04, 0.22, 0, 0.04, -0.21, STEEL, Metal)
		box("Gatilho", 0.04, 0.12, 0.04, 0, 0.14, -0.16, STEEL_DARK, Metal, 10)
		box("Dobradiça da coronha", 0.26, 0.1, 0.08, 0, 0.3, 0.4, STEEL_DARK, Metal)
		box("Coronha dobrada E", 0.03, 0.04, 0.72, -0.165, 0.27, 0.04, STEEL_DARK, Metal)
		box("Coronha dobrada D", 0.03, 0.04, 0.72, 0.165, 0.27, 0.04, STEEL_DARK, Metal)
		muzzle = Vector3.new(0, 0.36, -1.03)
	elseif id == "ak47" then
		core(0.12, 0.3, 0.16, WOOD_DARK, Wood)
		box("Cabo", 0.15, 0.44, 0.22, 0, -0.04, 0.05, WOOD_DARK, Wood, -20)
		box("Receptor", 0.2, 0.26, 1.1, 0, 0.32, -0.2, STEEL, Metal)
		tube("Tampa", 0.17, 1.0, 0, 0.43, -0.16, STEEL, Metal)
		box("Encaixe da coronha", 0.18, 0.22, 0.1, 0, 0.34, 0.4, STEEL, Metal)
		box("Coronha", 0.17, 0.3, 0.95, 0, 0.26, 0.92, WOOD, Wood, 7)
		wedge("Queda da coronha", 0.17, 0.16, 0.8, 0, 0.06, 1.0, WOOD, Wood, 7, 0, 180)
		box("Soleira", 0.18, 0.42, 0.05, 0, 0.17, 1.4, STEEL_DARK, Metal, 7)
		box("Guarda-mão inferior", 0.2, 0.2, 0.62, 0, 0.27, -1.08, WOOD, Wood)
		box("Guarda-mão superior", 0.15, 0.11, 0.58, 0, 0.43, -1.06, WOOD, Wood)
		box("Anel do guarda-mão", 0.21, 0.24, 0.04, 0, 0.33, -1.41, STEEL, Metal)
		box("Alça de mira", 0.16, 0.12, 0.16, 0, 0.43, -0.8, STEEL, Metal)
		box("Folha da mira", 0.1, 0.03, 0.18, 0, 0.5, -0.78, STEEL_DARK, Metal)
		box("Bloco de gases", 0.12, 0.14, 0.1, 0, 0.4, -1.45, STEEL, Metal)
		tube("Cano", 0.085, 0.66, 0, 0.29, -1.71, STEEL_DARK, Metal)
		box("Base da massa", 0.09, 0.18, 0.1, 0, 0.36, -1.88, STEEL, Metal)
		box("Massa de mira", 0.025, 0.08, 0.025, 0, 0.48, -1.88, STEEL_DARK, Metal)
		box("Orelha E", 0.015, 0.09, 0.06, -0.04, 0.47, -1.88, STEEL_DARK, Metal)
		box("Orelha D", 0.015, 0.09, 0.06, 0.04, 0.47, -1.88, STEEL_DARK, Metal)
		tube("Freio de boca", 0.1, 0.12, 0, 0.29, -2.09, STEEL_DARK, Metal)
		curvedMag("Carregador", 0.13, 0.25, 0.06, -0.49, { { 0.3, 8 }, { 0.3, 22 }, { 0.26, 36 } }, rgb(40, 38, 36), Metal)
		box("Guarda-mato", 0.05, 0.03, 0.3, 0, 0.1, -0.2, STEEL, Metal)
		box("Gatilho", 0.04, 0.1, 0.04, 0, 0.14, -0.14, STEEL_DARK, Metal, 10)
		box("Seletor", 0.02, 0.05, 0.36, 0.105, 0.36, -0.15, STEEL_DARK, Metal)
		box("Manopla", 0.08, 0.05, 0.06, 0.13, 0.38, -0.62, STEEL_DARK, Metal)
		muzzle = Vector3.new(0, 0.29, -2.16)
	elseif id == "m4" then
		core(0.12, 0.3, 0.16, POLY, Plastic)
		box("Cabo", 0.15, 0.44, 0.22, 0, -0.04, 0.06, POLY, Plastic, -22)
		box("Receptor inferior", 0.18, 0.2, 0.8, 0, 0.27, -0.1, STEEL, Metal)
		box("Poço do carregador", 0.18, 0.14, 0.26, 0, 0.12, -0.4, STEEL, Metal)
		curvedMag("Carregador", 0.12, 0.24, -0.12, -0.44, { { 0.34, 6 }, { 0.24, 14 } }, STEEL, Metal)
		box("Receptor superior", 0.18, 0.2, 0.82, 0, 0.47, -0.12, STEEL, Metal)
		box("Trilho", 0.11, 0.04, 0.8, 0, 0.59, -0.12, STEEL_DARK, Metal)
		for index = 0, 3 do
			box("Ranhura do trilho", 0.12, 0.02, 0.03, 0, 0.615, 0.2 - index * 0.2, STEEL, Metal)
		end
		box("Alavanca de manejo", 0.14, 0.05, 0.08, 0, 0.53, 0.32, STEEL_DARK, Metal)
		part("Assistente", Vector3.new(0.12, 0.07, 0.07), CFrame.new(0.11, 0.5, 0.12) * CFrame.Angles(0, math.pi / 2, 0),
			STEEL_DARK, Metal, Enum.PartType.Cylinder)
		box("Tampa de ejeção", 0.01, 0.07, 0.18, 0.095, 0.47, -0.1, rgb(64, 66, 72), Metal)
		tube("Tubo do amortecedor", 0.13, 0.55, 0, 0.46, 0.55, STEEL, Metal)
		box("Coronha", 0.16, 0.3, 0.5, 0, 0.38, 0.98, POLY, Plastic)
		box("Soleira", 0.17, 0.36, 0.06, 0, 0.36, 1.25, RUBBER, Plastic)
		box("Guarda-mão", 0.2, 0.2, 0.78, 0, 0.44, -0.93, STEEL, Metal)
		box("Trilho de cima", 0.08, 0.03, 0.78, 0, 0.555, -0.93, STEEL_DARK, Metal)
		box("Trilho de baixo", 0.08, 0.03, 0.78, 0, 0.325, -0.93, STEEL_DARK, Metal)
		box("Trilho E", 0.03, 0.08, 0.78, -0.115, 0.44, -0.93, STEEL_DARK, Metal)
		box("Trilho D", 0.03, 0.08, 0.78, 0.115, 0.44, -0.93, STEEL_DARK, Metal)
		box("Base da massa", 0.09, 0.18, 0.08, 0, 0.55, -1.38, STEEL, Metal)
		box("Massa de mira", 0.025, 0.08, 0.025, 0, 0.68, -1.38, STEEL_DARK, Metal)
		tube("Cano", 0.08, 0.5, 0, 0.44, -1.56, STEEL_DARK, Metal)
		tube("Quebra-chamas", 0.1, 0.12, 0, 0.44, -1.86, STEEL_DARK, Metal)
		box("Base da mira", 0.08, 0.08, 0.14, 0, 0.64, -0.1, STEEL_DARK, Metal)
		tube("Mira de ponto", 0.16, 0.26, 0, 0.72, -0.1, STEEL, Metal)
		local lens = tube("Lente", 0.13, 0.01, 0, 0.72, -0.235, rgb(70, 130, 170), Enum.Material.Glass)
		lens.Transparency = 0.25
		box("Guarda-mato", 0.05, 0.03, 0.26, 0, 0.12, -0.16, STEEL, Metal)
		box("Gatilho", 0.04, 0.1, 0.04, 0, 0.16, -0.12, STEEL_DARK, Metal, 10)
		muzzle = Vector3.new(0, 0.44, -1.93)
	elseif id == "escopeta" then
		core(0.12, 0.3, 0.16, POLY, Plastic)
		box("Punho", 0.15, 0.34, 0.24, 0, 0.03, 0.1, POLY, Plastic, -30)
		box("Coronha", 0.15, 0.24, 1.05, 0, 0.27, 0.98, POLY, Plastic, 5)
		wedge("Queda da coronha", 0.15, 0.2, 0.9, 0, 0.06, 1.08, POLY, Plastic, 5, 0, 180)
		box("Soleira", 0.17, 0.44, 0.06, 0, 0.17, 1.52, RUBBER, Plastic, 5)
		box("Receptor", 0.2, 0.32, 0.92, 0, 0.38, -0.12, STEEL, Metal)
		box("Janela de ejeção", 0.01, 0.1, 0.3, 0.1, 0.44, -0.2, STEEL_DARK, Metal)
		box("Guarda-mato", 0.05, 0.03, 0.28, 0, 0.16, -0.1, STEEL, Metal)
		box("Gatilho", 0.04, 0.1, 0.04, 0, 0.2, -0.06, STEEL_DARK, Metal, 10)
		tube("Cano", 0.12, 2.0, 0, 0.47, -1.58, STEEL, Metal)
		tube("Tubo de cartuchos", 0.11, 1.75, 0, 0.31, -1.45, STEEL, Metal)
		box("Abraçadeira", 0.14, 0.3, 0.05, 0, 0.39, -2.3, STEEL_DARK, Metal)
		tube("Tampa do tubo", 0.13, 0.06, 0, 0.31, -2.35, STEEL_DARK, Metal)
		box("Telha da bomba", 0.21, 0.2, 0.62, 0, 0.3, -1.1, POLY, Plastic)
		for index = 0, 4 do
			box("Sulco da bomba", 0.22, 0.21, 0.025, 0, 0.3, -0.86 - index * 0.12, STEEL_DARK, Plastic)
		end
		ball("Massa", 0.04, 0, 0.545, -2.52, STEEL_BARE, Metal)
		muzzle = Vector3.new(0, 0.47, -2.6)
	else -- sniper
		core(0.12, 0.3, 0.16, OLIVE, Plastic)
		box("Cabo", 0.16, 0.42, 0.24, 0, -0.02, 0.06, OLIVE, Plastic, -16)
		box("Coronha", 0.18, 0.32, 1.25, 0, 0.26, 1.02, OLIVE, Plastic)
		wedge("Queda da coronha", 0.18, 0.18, 1.0, 0, 0.01, 1.12, OLIVE, Plastic, 0, 0, 180)
		box("Apoio de rosto", 0.14, 0.1, 0.55, 0, 0.46, 0.98, OLIVE, Plastic)
		box("Soleira", 0.19, 0.5, 0.06, 0, 0.2, 1.67, RUBBER, Plastic)
		box("Telha", 0.2, 0.22, 1.3, 0, 0.28, -0.85, OLIVE, Plastic)
		tube("Ação", 0.2, 0.95, 0, 0.47, -0.12, STEEL, Metal)
		tube("Ferrolho", 0.07, 0.3, 0, 0.5, 0.3, STEEL_BARE, Metal)
		box("Alavanca do ferrolho", 0.22, 0.03, 0.03, 0.13, 0.47, 0.12, STEEL_DARK, Metal, 0, 0, -25)
		ball("Bola do ferrolho", 0.08, 0.24, 0.42, 0.12, STEEL_DARK, Metal)
		box("Carregador", 0.13, 0.18, 0.3, 0, 0.1, -0.36, STEEL, Metal)
		box("Guarda-mato", 0.05, 0.03, 0.22, 0, 0.12, -0.08, STEEL, Metal)
		box("Gatilho", 0.04, 0.1, 0.04, 0, 0.18, -0.04, STEEL_DARK, Metal, 10)
		tube("Cano", 0.12, 1.95, 0, 0.45, -1.55, STEEL, Metal)
		tube("Freio de boca", 0.16, 0.18, 0, 0.45, -2.62, STEEL_DARK, Metal)
		tube("Luneta", 0.15, 0.85, 0, 0.78, -0.1, STEEL_DARK, Metal)
		tube("Ocular", 0.22, 0.22, 0, 0.78, 0.4, STEEL_DARK, Metal)
		tube("Objetiva", 0.28, 0.3, 0, 0.78, -0.62, STEEL_DARK, Metal)
		local lens = tube("Lente", 0.24, 0.01, 0, 0.78, -0.775, rgb(80, 140, 200), Enum.Material.Glass)
		lens.Transparency = 0.2
		post("Torre de elevação", 0.09, 0.1, 0, 0.89, -0.08, STEEL_DARK, Metal)
		part("Torre lateral", Vector3.new(0.1, 0.09, 0.09), CFrame.new(0.11, 0.78, -0.08), STEEL_DARK, Metal, Enum.PartType.Cylinder)
		box("Anel traseiro", 0.1, 0.22, 0.06, 0, 0.64, 0.14, STEEL_DARK, Metal)
		box("Anel dianteiro", 0.1, 0.22, 0.06, 0, 0.64, -0.36, STEEL_DARK, Metal)
		box("Bipé E", 0.03, 0.03, 0.55, -0.07, 0.15, -1.3, STEEL_DARK, Metal)
		box("Bipé D", 0.03, 0.03, 0.55, 0.07, 0.15, -1.3, STEEL_DARK, Metal)
		box("Base do bipé", 0.18, 0.06, 0.08, 0, 0.16, -1.48, STEEL_DARK, Metal)
		muzzle = Vector3.new(0, 0.45, -2.72)
	end
	model.PrimaryPart = grip
	local cano = Instance.new("Attachment")
	cano.Name = "Cano"
	cano.Position = muzzle
	cano.Parent = grip
	model:SetAttribute("Arma", def.id)
	return model
end

-- Gun in the right hand. Weapon -Z follows the arm down (forward when aiming); the knife points forward.
local function gripOffset(def, arm: BasePart): CFrame
	-- O cabo fica dentro da "mão" (ponta do braço) e o corpo da arma sai pela frente do braço: o receptor e o
	-- cano ficam inteiros para fora do bloco do R6 (antes ficavam escondidos dentro do braço ao mirar).
	if def.grip == "frente" then
		return CFrame.new(0, -(arm.Size.Y / 2 + 0.05), -0.1)
	end
	local drop = arm.Size.Y / 2 - 0.3
	local forward = arm.Size.Z / 2 + 0.1 - 0.22
	return CFrame.fromMatrix(Vector3.new(0, -drop, -forward), Vector3.xAxis, Vector3.new(0, 0, -1), Vector3.yAxis)
end

-- Sandevistan na coluna: placa base (PrimaryPart) nas costas do Torso, seis vértebras de metal que estreitam
-- para baixo, elos de luz entre elas (as "Luz" mudam de cor no cliente quando ativa), aletas de calor e o
-- núcleo na nuca. Espaço do modelo: origem nas costas, +Y para cima, +Z para fora das costas.
local IMPLANT_SEAT = CFrame.new(0, 0.05, 0.53)
local function buildImplant(def)
	local model = Instance.new("Model")
	model.Name = def.id
	local base
	local function part(name: string, size: Vector3, pose: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape or Enum.PartType.Block
		p.Size = size
		p.CFrame = pose
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		if base then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = base
			weld.Part1 = p
			weld.Parent = p
		end
		return p
	end
	local steel, chrome, glow = rgb(30, 32, 38), rgb(176, 182, 194), rgb(90, 255, 220)
	base = part("Base", Vector3.new(0.34, 1.9, 0.06), CFrame.new(), steel, Enum.Material.Metal)
	model.PrimaryPart = base
	for index = 0, 5 do
		local y = 0.78 - index * 0.3
		part("Vertebra", Vector3.new(0.62 - index * 0.05, 0.16, 0.16), CFrame.new(0, y, 0.08), chrome, Enum.Material.Metal)
		if index < 5 then
			part("Luz", Vector3.new(0.1, 0.12, 0.1), CFrame.new(0, y - 0.15, 0.1), glow, Enum.Material.Neon)
		end
	end
	for _, side in { -1, 1 } do
		part("Aleta", Vector3.new(0.06, 0.52, 0.2), CFrame.new(side * 0.33, 0.55, 0.05) * CFrame.Angles(0, 0, math.rad(side * 18)), steel, Enum.Material.Metal)
		part("Aleta", Vector3.new(0.06, 0.38, 0.16), CFrame.new(side * 0.27, 0.12, 0.05) * CFrame.Angles(0, 0, math.rad(side * 12)), steel, Enum.Material.Metal)
	end
	part("Luz", Vector3.new(0.14, 0.24, 0.24), CFrame.new(0, 0.97, 0.06) * CFrame.Angles(0, 0, math.rad(90)), glow, Enum.Material.Neon, Enum.PartType.Cylinder)
	return model
end

local function main()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HttpService = game:GetService("HttpService")
	if ReplicatedStorage:FindFirstChild("CyberOutlawArsenal") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "CyberOutlawArsenal"
	local models = Instance.new("Folder")
	models.Name = "Modelos"
	models.Parent = folder
	local templates = {}
	for _, def in WEAPONS do
		local model = buildModel(def)
		model.Parent = models
		templates[def.id] = model
	end
	local public = {}
	for _, def in WEAPONS do
		local copy = table.clone(def)
		table.insert(public, copy)
	end
	folder:SetAttribute("Armas", HttpService:JSONEncode(public))
	local implantModels = Instance.new("Folder")
	implantModels.Name = "Implantes"
	implantModels.Parent = folder
	local implantTemplates = {}
	local publicImplants = {}
	for _, def in IMPLANTS do
		local copy = table.clone(def)
		if def.id == "sandevistan" then
			copy.stats = { duracao = SANDEVISTAN.duracao, recarga = SANDEVISTAN.recarga, custo = SANDEVISTAN.custo,
				surto = SANDEVISTAN.surto, lento = SANDEVISTAN.lento, cadencia = SANDEVISTAN.cadencia, velocidade = SANDEVISTAN.velocidade }
		end
		table.insert(publicImplants, copy)
		if def.pronto then
			local model = buildImplant(def)
			model.Parent = implantModels
			implantTemplates[def.id] = model
		end
	end
	folder:SetAttribute("Implantes", HttpService:JSONEncode(publicImplants))
	folder:SetAttribute("ZonaSegura", HttpService:JSONEncode({ SAFE_CENTER.X, SAFE_CENTER.Z, SAFE_RADIUS }))
	local action = Instance.new("RemoteEvent")
	action.Name = "Acao"
	action.Parent = folder
	local effect = Instance.new("RemoteEvent")
	effect.Name = "Efeito"
	effect.Parent = folder
	local okAim, aim = pcall(Instance.new, "UnreliableRemoteEvent")
	if not okAim then
		aim = Instance.new("RemoteEvent")
	end
	aim.Name = "Mira"
	aim.Parent = folder
	folder.Parent = ReplicatedStorage

	local states: { [Player]: any } = {}
	local minds: { [Player]: any } = {} -- implantes e estabilidade: duram a sessão toda, não só uma vida
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local function now()
		return workspace:GetServerTimeNow()
	end

	local function publishAmmo(player: Player, state)
		local def = BY_ID[state.slot]
		local ammo = def and state.ammo[def.id]
		player:SetAttribute("CyberOutlawPente", if ammo then ammo.mag else -1)
		player:SetAttribute("CyberOutlawReserva", if ammo then ammo.reserve else -1)
		player:SetAttribute("CyberOutlawRecargaAte", if state.reloadUntil > now() then state.reloadUntil else 0)
		local all = {}
		for id, entry in state.ammo do
			all[id] = { entry.mag, entry.reserve }
		end
		player:SetAttribute("CyberOutlawMunicao", HttpService:JSONEncode(all))
	end

	local function characterOf(part: Instance)
		local model = part:FindFirstAncestorOfClass("Model")
		while model do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				return model, humanoid
			end
			model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
		end
		return nil, nil
	end

	local function equip(player: Player, state, id: string)
		local def = BY_ID[id]
		local character = player.Character
		if not def or not character then
			return
		end
		state.slot = id
		state.reloadToken += 1
		state.reloadUntil = 0
		local old = character:FindFirstChild("CyberOutlawArma")
		if old then
			old:Destroy()
		end
		local arm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
		if arm and arm:IsA("BasePart") and def.id ~= "punhos" then
			local model = templates[def.id]:Clone()
			model.Name = "CyberOutlawArma"
			for _, item in model:GetDescendants() do
				if item:IsA("BasePart") then
					item.Anchored = false
				end
			end
			local weld = Instance.new("Weld")
			weld.Name = "Pega"
			weld.Part0 = arm
			weld.Part1 = model.PrimaryPart
			weld.C0 = gripOffset(def, arm)
			weld.Parent = model.PrimaryPart
			model.Parent = character
		end
		character:SetAttribute("CyberOutlawArma", id)
		character:SetAttribute("CyberOutlawMirando", false)
		publishAmmo(player, state)
		effect:FireAllClients("troca", player, id)
	end

	local function shoot(player: Player, state, origin, directions)
		local def = BY_ID[state.slot]
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not head or not humanoid or humanoid.Health <= 0 then
			return
		end
		local time = now()
		local mind = minds[player]
		if mind and time < mind.frenzyUntil then
			return -- no surto quem atira é o implante, não o jogador
		end
		local ok = checkShot(state, def, time, origin, directions, head.Position)
		if not ok or inSafeZone(head.Position) then
			return
		end
		local ammo = state.ammo[def.id]
		ammo.mag -= 1
		local boost = if mind and time < mind.activeUntil then SANDEVISTAN.cadencia else 1
		state.nextShot = time + 1 / (def.rate * boost)
		params.FilterDescendantsInstances = { character }
		local muzzle = character:FindFirstChild("CyberOutlawArma")
		local attachment = muzzle and muzzle.PrimaryPart and muzzle.PrimaryPart:FindFirstChild("Cano")
		local from = if attachment then attachment.WorldPosition else head.Position
		local hits = {}
		local damaged = {}
		for _, direction in directions do
			local result = workspace:Raycast(origin, direction * def.range, params)
			local point = if result then result.Position else origin + direction * def.range
			-- Second ray from the muzzle: a wall in front of the barrel blocks the shot.
			local blocked = workspace:Raycast(from, point - from, params)
			if blocked and result and (blocked.Position - result.Position).Magnitude > 1 then
				result = blocked
				point = blocked.Position
			end
			local target = false
			if result then
				local model, victim = characterOf(result.Instance)
				if victim and model ~= character and victim.Health > 0 then
					local root = model:FindFirstChild("HumanoidRootPart")
					if not root or not inSafeZone(root.Position) then
						local amount = damageFor(def, (point - from).Magnitude, result.Instance.Name == "Head")
						damaged[victim] = (damaged[victim] or 0) + amount
						target = true
					end
				end
			end
			table.insert(hits, { point, if result then result.Normal else -direction, target })
		end
		for victim, amount in damaged do
			victim:SetAttribute("CyberOutlawUltimoAtacante", player.UserId)
			victim:TakeDamage(amount)
		end
		publishAmmo(player, state)
		effect:FireAllClients("tiro", player, def.id, from, hits)
	end

	local function melee(player: Player, state, side: number)
		local def = BY_ID[state.slot]
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not def or def.kind ~= "melee" or not root or not humanoid or humanoid.Health <= 0 then
			return
		end
		local time = now()
		if time < state.nextMelee - 0.15 / def.rate then
			return
		end
		local mind = minds[player]
		local boost = if mind and time < mind.activeUntil then SANDEVISTAN.cadencia else 1
		state.nextMelee = time + 1 / (def.rate * boost)
		local hitAt
		if not inSafeZone(root.Position) then
			local best, bestDistance
			for _, other in Players:GetPlayers() do
				local target = other.Character
				local otherRoot = target and target:FindFirstChild("HumanoidRootPart")
				local victim = target and target:FindFirstChildOfClass("Humanoid")
				if other ~= player and otherRoot and victim and victim.Health > 0 and not inSafeZone(otherRoot.Position) then
					local offset = otherRoot.Position - root.Position
					local distance = offset.Magnitude
					if distance <= def.range and distance > 0 and root.CFrame.LookVector:Dot(offset.Unit) > 0.35 then
						if not bestDistance or distance < bestDistance then
							best, bestDistance = victim, distance
						end
					end
				end
			end
			if best then
				best:SetAttribute("CyberOutlawUltimoAtacante", player.UserId)
				best:TakeDamage(def.damage)
				local targetRoot = best.Parent and best.Parent:FindFirstChild("HumanoidRootPart")
				hitAt = if targetRoot then targetRoot.Position else nil
			end
		end
		effect:FireAllClients("golpe", player, def.id, if side == -1 then -1 else 1, hitAt)
	end

	local function reload(player: Player, state)
		local def = BY_ID[state.slot]
		local ammo = def and state.ammo[def.id]
		if not ammo or ammo.mag >= def.mag or ammo.reserve <= 0 or state.reloadUntil > now() then
			return
		end
		state.reloadToken += 1
		local token = state.reloadToken
		state.reloadUntil = now() + def.reload
		publishAmmo(player, state)
		effect:FireAllClients("recarga", player, def.id, def.reload)
		task.delay(def.reload, function()
			if states[player] ~= state or state.reloadToken ~= token or state.slot ~= def.id then
				return
			end
			local take = math.min(def.mag - ammo.mag, ammo.reserve)
			ammo.mag += take
			ammo.reserve -= take
			state.reloadUntil = 0
			publishAmmo(player, state)
		end)
	end

	-- Implantes e Sandevistan --------------------------------------------------------------------------
	local function publishMind(player: Player, mind)
		player:SetAttribute("CyberOutlawPsicose", math.floor(mind.psy + 0.5))
		local list = {}
		for id in mind.implants do
			table.insert(list, id)
		end
		table.sort(list)
		player:SetAttribute("CyberOutlawImplantes", HttpService:JSONEncode(list))
		local character = player.Character
		if character then
			character:SetAttribute("CyberOutlawSandevistanAte", mind.activeUntil)
			character:SetAttribute("CyberOutlawSurtoAte", mind.frenzyUntil)
			character:SetAttribute("CyberOutlawHabilidadePronta", mind.abilityReady)
		end
	end

	-- Põe no corpo os modelos dos implantes encaixados (e tira os que saíram).
	local function dressImplants(player: Player, mind)
		local character = player.Character
		local torso = character and (character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso"))
		if not character or not torso or not torso:IsA("BasePart") then
			return
		end
		for _, item in character:GetChildren() do
			if item.Name == "CyberOutlawImplante" and not mind.implants[item:GetAttribute("Id")] then
				item:Destroy()
			end
		end
		for id in mind.implants do
			local template = implantTemplates[id]
			local has = false
			for _, item in character:GetChildren() do
				if item.Name == "CyberOutlawImplante" and item:GetAttribute("Id") == id then
					has = true
				end
			end
			if template and not has then
				local model = template:Clone()
				model.Name = "CyberOutlawImplante"
				model:SetAttribute("Id", id)
				for _, item in model:GetDescendants() do
					if item:IsA("BasePart") then
						item.Anchored = false
					end
				end
				local weld = Instance.new("Weld")
				weld.Name = "Encaixe"
				weld.Part0 = torso
				weld.Part1 = model.PrimaryPart
				weld.C0 = IMPLANT_SEAT
				weld.Parent = model.PrimaryPart
				model.Parent = character
			end
		end
	end

	-- Quem estiver perto do dono do Sandevistan anda devagar até o efeito acabar (o cliente de cada um lê).
	local function slowAround(player: Player, untilTime: number)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		for _, other in Players:GetPlayers() do
			local target = other.Character
			local otherRoot = target and target:FindFirstChild("HumanoidRootPart")
			if other ~= player and otherRoot and (otherRoot.Position - root.Position).Magnitude <= SANDEVISTAN.raio then
				local old = target:GetAttribute("CyberOutlawLentoAte")
				if type(old) ~= "number" or old < untilTime then
					target:SetAttribute("CyberOutlawLentoAte", untilTime)
				end
			end
		end
	end

	-- Um disparo do surto: mira no jogador vivo mais perto que dá para ver (fora da zona segura) ou atira a esmo.
	local frenzyRandom = Random.new()
	local function psychoShot(player: Player)
		local state = states[player]
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not state or not head or not humanoid or humanoid.Health <= 0 then
			return
		end
		local def = BY_ID[state.slot]
		if not def or def.kind ~= "gun" then
			def = BY_ID.ak47
		end
		local weapon = character:FindFirstChild("CyberOutlawArma")
		local attachment = weapon and weapon.PrimaryPart and weapon.PrimaryPart:FindFirstChild("Cano")
		local from = if attachment then attachment.WorldPosition else head.Position
		params.FilterDescendantsInstances = { character }
		local best, bestDistance, bestHead
		for _, other in Players:GetPlayers() do
			local target = other.Character
			local otherHead = target and target:FindFirstChild("Head")
			local otherRoot = target and target:FindFirstChild("HumanoidRootPart")
			local victim = target and target:FindFirstChildOfClass("Humanoid")
			if other ~= player and otherHead and otherRoot and victim and victim.Health > 0 and not inSafeZone(otherRoot.Position) then
				local distance = (otherHead.Position - from).Magnitude
				if distance < SANDEVISTAN.alcanceSurto and (not bestDistance or distance < bestDistance) then
					local sight = workspace:Raycast(from, otherHead.Position - from, params)
					if sight and sight.Instance:IsDescendantOf(target) then
						best, bestDistance, bestHead = victim, distance, otherHead
					end
				end
			end
		end
		local direction
		if best and bestHead then
			local jitter = Vector3.new(frenzyRandom:NextNumber(-0.5, 0.5), frenzyRandom:NextNumber(-0.6, 0.4), frenzyRandom:NextNumber(-0.5, 0.5))
			direction = (bestHead.Position + jitter - from).Unit
			character:SetAttribute("CyberOutlawSurtoAlvo", best.Parent and best.Parent.Name or "")
		else
			local angle = frenzyRandom:NextNumber(0, math.pi * 2)
			direction = Vector3.new(math.cos(angle), frenzyRandom:NextNumber(-0.25, 0.15), math.sin(angle)).Unit
			character:SetAttribute("CyberOutlawSurtoAlvo", "")
		end
		local result = workspace:Raycast(from, direction * def.range, params)
		local point = if result then result.Position else from + direction * def.range
		local hit = false
		if result and not inSafeZone(head.Position) then
			local model, victim = characterOf(result.Instance)
			local victimRoot = model and model:FindFirstChild("HumanoidRootPart")
			if victim and model ~= character and victim.Health > 0 and not (victimRoot and inSafeZone(victimRoot.Position)) then
				victim:SetAttribute("CyberOutlawUltimoAtacante", player.UserId)
				victim:TakeDamage(SANDEVISTAN.danoSurto)
				hit = true
			end
		end
		effect:FireAllClients("surto", player, def.id, from, { { point, if result then result.Normal else -direction, hit } })
	end

	local function startFrenzy(player: Player, mind)
		local state = states[player]
		if state and BY_ID[state.slot] and BY_ID[state.slot].kind ~= "gun" then
			equip(player, state, "ak47")
		end
		if player.Character then
			player.Character:SetAttribute("CyberOutlawMirando", true)
		end
		mind.frenzyToken += 1
		local token = mind.frenzyToken
		task.spawn(function()
			while minds[player] == mind and mind.frenzyToken == token and now() < mind.frenzyUntil do
				psychoShot(player)
				task.wait(0.09)
			end
			if player.Character then
				player.Character:SetAttribute("CyberOutlawMirando", false)
				player.Character:SetAttribute("CyberOutlawSurtoAlvo", "")
			end
		end)
	end

	local function activate(player: Player)
		local mind = minds[player]
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not mind or not humanoid or humanoid.Health <= 0 then
			return
		end
		local time = now()
		if not useSandevistan(mind, time) then
			return
		end
		publishMind(player, mind)
		effect:FireAllClients("sandevistan", player, "sandevistan", mind.activeUntil, mind.frenzyUntil > time)
		mind.useToken += 1
		local token = mind.useToken
		task.spawn(function()
			while minds[player] == mind and mind.useToken == token and now() < mind.activeUntil do
				slowAround(player, mind.activeUntil)
				task.wait(0.25)
			end
		end)
		if mind.frenzyUntil > time then
			startFrenzy(player, mind)
		end
	end

	-- Estabilidade: volta devagar sem usar; o fim do surto devolve aposSurto.
	task.spawn(function()
		while true do
			local dt = task.wait(0.5)
			local time = now()
			for player, mind in minds do
				local before = math.floor(mind.psy + 0.5)
				local wasFrenzy = mind.frenzyUntil > 0
				if regenMind(mind, time, dt) and (math.floor(mind.psy + 0.5) ~= before or wasFrenzy ~= (mind.frenzyUntil > 0)) then
					publishMind(player, mind)
				end
			end
		end
	end)

	action.OnServerEvent:Connect(function(player: Player, kind, a, b)
		local state = states[player]
		if not state or type(kind) ~= "string" then
			return
		end
		local mind = minds[player]
		if kind == "implante" and mind and type(a) == "string" then
			if setImplant(mind, a, b == true, now()) then
				dressImplants(player, mind)
				publishMind(player, mind)
			end
			return
		elseif kind == "habilidade" then
			activate(player)
			return
		end
		if kind == "equipar" and type(a) == "string" and BY_ID[a] then
			if mind and now() < mind.frenzyUntil then
				return
			end
			equip(player, state, a)
		elseif kind == "atirar" then
			shoot(player, state, a, b)
		elseif kind == "golpe" then
			melee(player, state, if a == -1 then -1 else 1)
		elseif kind == "recarregar" then
			reload(player, state)
		elseif kind == "mirar" and player.Character then
			local def = BY_ID[state.slot]
			player.Character:SetAttribute("CyberOutlawMirando", a == true and def ~= nil and def.kind == "gun")
		end
	end)

	aim.OnServerEvent:Connect(function(player: Player, pitch)
		local state = states[player]
		local character = player.Character
		if not state or not character or type(pitch) ~= "number" or pitch ~= pitch then
			return
		end
		local time = os.clock()
		if time - state.pitchAt < 0.06 then
			return
		end
		pitch = math.clamp(math.round(pitch), -80, 80)
		if math.abs(pitch - state.lastPitch) >= 2 then
			state.pitchAt = time
			state.lastPitch = pitch
			character:SetAttribute("CyberOutlawPitch", pitch)
		end
	end)

	local function join(player: Player)
		minds[player] = minds[player] or newMind()
		local function spawned(character)
			local state = newState()
			states[player] = state
			character:SetAttribute("CyberOutlawArma", "punhos")
			character:SetAttribute("CyberOutlawMirando", false)
			character:SetAttribute("CyberOutlawPitch", 0)
			publishAmmo(player, state)
			-- Nova vida: o efeito e o surto acabam; implantes e estabilidade continuam.
			local mind = minds[player]
			if mind then
				mind.activeUntil, mind.frenzyUntil, mind.abilityReady = 0, 0, 0
				mind.useToken += 1
				mind.frenzyToken += 1
				character:WaitForChild("Torso", 5)
				dressImplants(player, mind)
				publishMind(player, mind)
			end
		end
		player.CharacterAdded:Connect(spawned)
		if player.Character then
			spawned(player.Character)
		end
	end
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		minds[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(join, player)
	end
end

if typeof(game) == "Instance" then
	main()
end

return {
	WEAPONS = WEAPONS,
	IMPLANTS = IMPLANTS,
	SANDEVISTAN = SANDEVISTAN,
	IMPLANT_SEAT = IMPLANT_SEAT,
	buildImplant = buildImplant,
	newMind = newMind,
	useSandevistan = useSandevistan,
	regenMind = regenMind,
	setImplant = setImplant,
	buildModel = buildModel,
	gripOffset = gripOffset,
	inSafeZone = inSafeZone,
	damageFor = damageFor,
	checkShot = checkShot,
	newState = newState,
}
