-- CyberOutlaw arsenal (Script in ServerScriptService).
-- The server holds the weapon rules: equip, ammo, shot and hit validation, damage, and effects.
-- The models are built in code and published in ReplicatedStorage.CyberOutlawArsenal, so the
-- client uses the same pieces in the weapon wheel without images.

local SAFE_CENTER = Vector3.new(108, 0, 108) -- Praça da Maré
local SAFE_RADIUS = 95
local rgb = Color3.fromRGB

-- order defines the wheel: punhos at the top, the rest clockwise.
local WEAPONS = {
	{
		id = "punhos", name = "Punhos", kind = "melee", order = 1, damage = 12, rate = 2.6, range = 6.5,
		accent = { 255, 166, 94 }, class = "CORPO A CORPO", desc = "Golpes rápidos. Sempre à mão.",
		stats = { 0.22, 0.82, 0.08, 1.0 },
	},
	{
		id = "lamina", name = "Lâmina Térmica", kind = "melee", order = 2, damage = 38, rate = 1.5, range = 8.5,
		accent = { 255, 72, 92 }, class = "CORPO A CORPO · PLASMA", desc = "Fio aquecido a plasma. Lenta e letal.",
		stats = { 0.74, 0.46, 0.14, 0.82 }, grip = "frente",
	},
	{
		id = "vespa", name = "Pistola Vespa", kind = "gun", order = 3, damage = 24, rate = 5, auto = false, mag = 12,
		reserve = 96, spread = 1.1, range = 320, pellets = 1, reload = 1.3, recoil = 1.7, fov = 54,
		accent = { 255, 41, 144 }, class = "ARMA LEVE · SEMIAUTOMÁTICA", desc = "Compacta, precisa e silenciosa no bolso.",
		stats = { 0.42, 0.5, 0.62, 0.86 },
	},
	{
		id = "enxame", name = "SMG Enxame", kind = "gun", order = 4, damage = 12, rate = 12, auto = true, mag = 32,
		reserve = 192, spread = 2.4, range = 220, pellets = 1, reload = 1.7, recoil = 0.9, fov = 52,
		accent = { 58, 231, 255 }, class = "SUBMETRALHADORA · AUTOMÁTICA", desc = "Rajada contínua para becos fechados.",
		stats = { 0.3, 0.96, 0.44, 0.58 },
	},
	{
		id = "trovao", name = "Escopeta Trovão", kind = "gun", order = 5, damage = 11, rate = 1.25, auto = false, mag = 6,
		reserve = 36, spread = 6.5, range = 90, pellets = 9, reload = 2.3, recoil = 4.4, fov = 56,
		accent = { 140, 255, 150 }, class = "ESCOPETA · CARTUCHO", desc = "Nove projéteis de perto. O beco fica em silêncio.",
		stats = { 0.95, 0.22, 0.18, 0.4 },
	},
	{
		id = "agulha", name = "Fuzil Agulha", kind = "gun", order = 6, damage = 21, rate = 8, auto = true, mag = 28,
		reserve = 140, spread = 0.7, range = 480, pellets = 1, reload = 2.0, recoil = 1.3, fov = 44,
		accent = { 180, 86, 250 }, class = "FUZIL · AUTOMÁTICO", desc = "Mira estável e alcance de telhado a telhado.",
		stats = { 0.62, 0.74, 0.95, 0.7 },
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

-- Models ----------------------------------------------------------------------------------------
-- Weapon space: origin at the grip, -Z is the barrel direction, +Y is up.
local function buildModel(def)
	local model = Instance.new("Model")
	model.Name = def.id
	local accent = rgb(def.accent[1], def.accent[2], def.accent[3])
	local body, dark, light = rgb(46, 50, 60), rgb(20, 22, 28), rgb(120, 126, 138)
	local metal, neon, smooth = Enum.Material.Metal, Enum.Material.Neon, Enum.Material.SmoothPlastic
	local grip
	local function part(name: string, size: Vector3, pose: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape or Enum.PartType.Block
		p.Size = size
		p.CFrame = pose
		p.Color = color
		p.Material = material or metal
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
	local function tube(name, diameter, length, center: Vector3, color, material)
		return part(name, Vector3.new(length, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, math.pi / 2, 0),
			color, material, Enum.PartType.Cylinder)
	end
	local function at(x, y, z)
		return CFrame.new(x, y, z)
	end
	local tilt = CFrame.Angles(math.rad(-14), 0, 0)
	local muzzle
	if def.id == "punhos" then
		-- Combat glove, used only as an icon in the wheel and the HUD.
		grip = part("Empunhadura", Vector3.new(0.6, 0.62, 0.5), at(0, 0, 0), rgb(34, 36, 46), smooth)
		part("Dedos fechados", Vector3.new(0.62, 0.5, 0.24), at(0, 0.02, -0.34), rgb(28, 30, 38), smooth)
		for index = 0, 2 do
			part("Vão dos dedos", Vector3.new(0.64, 0.025, 0.25), at(0, -0.16 + index * 0.13, -0.34), rgb(12, 12, 18), smooth)
		end
		part("Nós de néon", Vector3.new(0.64, 0.08, 0.26), at(0, 0.27, -0.34), accent, neon)
		part("Polegar", Vector3.new(0.18, 0.2, 0.38), at(0.36, -0.08, -0.2) * CFrame.Angles(0, math.rad(-18), 0), rgb(28, 30, 38), smooth)
		part("Punho da luva", Vector3.new(0.68, 0.32, 0.58), at(0, -0.46, 0.02), body)
		part("Anel do punho", Vector3.new(0.7, 0.07, 0.6), at(0, -0.36, 0.02), accent, neon)
		muzzle = Vector3.new(0, 0, -0.5)
	elseif def.id == "lamina" then
		grip = part("Empunhadura", Vector3.new(0.24, 0.24, 0.95), at(0, 0, 0.3), dark, smooth)
		for index = 0, 3 do
			part("Fita do cabo", Vector3.new(0.26, 0.26, 0.06), at(0, 0, 0.0 + index * 0.2), body)
		end
		part("Guarda", Vector3.new(0.7, 0.16, 0.16), at(0, 0, -0.22), body)
		part("Núcleo da guarda", Vector3.new(0.72, 0.06, 0.18), at(0, 0, -0.22), accent, neon)
		part("Pomo", Vector3.new(0.3, 0.3, 0.2), at(0, 0, 0.84), light)
		part("Lâmina", Vector3.new(0.07, 0.26, 2.7), at(0, 0.02, -1.62), rgb(255, 236, 214), neon)
		-- Chisel tip: the wedge tapers toward -Z.
		part("Ponta", Vector3.new(0.07, 0.26, 0.46), at(0, 0.02, -3.2), rgb(255, 236, 214), neon, Enum.PartType.Wedge)
		local glow = part("Brilho térmico", Vector3.new(0.12, 0.36, 2.9), at(0, 0.02, -1.72), accent, neon)
		glow.Transparency = 0.66
		part("Dorso da lâmina", Vector3.new(0.1, 0.07, 2.7), at(0, 0.18, -1.62), body)
		muzzle = Vector3.new(0, 0, -3.4)
	elseif def.id == "vespa" then
		grip = part("Empunhadura", Vector3.new(0.3, 0.74, 0.4), at(0, -0.12, 0.24) * tilt, dark)
		part("Ferrolho", Vector3.new(0.34, 0.36, 1.5), at(0, 0.38, -0.26), body)
		part("Faixa do ferrolho", Vector3.new(0.36, 0.06, 1.22), at(0, 0.46, -0.24), accent, neon)
		part("Armação", Vector3.new(0.3, 0.2, 1.1), at(0, 0.14, -0.2), dark)
		tube("Cano", 0.2, 0.3, Vector3.new(0, 0.36, -1.1), light)
		part("Guarda-mato", Vector3.new(0.06, 0.2, 0.34), at(0, -0.02, -0.06), dark)
		part("Mira traseira", Vector3.new(0.14, 0.08, 0.08), at(0, 0.6, 0.4), accent, neon)
		part("Mira frontal", Vector3.new(0.06, 0.08, 0.06), at(0, 0.6, -0.92), accent, neon)
		part("Base do carregador", Vector3.new(0.34, 0.1, 0.44), at(0, -0.52, 0.32), body)
		part("Célula de energia", Vector3.new(0.32, 0.22, 0.12), at(0, -0.1, 0.42), accent, neon)
		muzzle = Vector3.new(0, 0.36, -1.28)
	elseif def.id == "enxame" then
		grip = part("Empunhadura", Vector3.new(0.3, 0.7, 0.36), at(0, -0.2, 0.36) * tilt, dark)
		part("Corpo", Vector3.new(0.38, 0.5, 1.8), at(0, 0.3, -0.2), body)
		part("Trilho superior", Vector3.new(0.16, 0.08, 1.4), at(0, 0.59, -0.2), dark)
		part("Faixa lateral", Vector3.new(0.4, 0.07, 1.5), at(0, 0.44, -0.2), accent, neon)
		part("Tela de munição", Vector3.new(0.4, 0.16, 0.32), at(0, 0.2, 0.18), accent, neon)
		part("Guarda-mão", Vector3.new(0.32, 0.32, 0.62), at(0, 0.32, -1.36), dark)
		tube("Cano", 0.18, 0.4, Vector3.new(0, 0.32, -1.85), light)
		part("Empunhadura frontal", Vector3.new(0.2, 0.46, 0.22), at(0, -0.05, -1.05), dark)
		part("Carregador", Vector3.new(0.24, 0.9, 0.3), at(0, -0.42, -0.55) * CFrame.Angles(math.rad(8), 0, 0), body)
		part("Coronha curta", Vector3.new(0.2, 0.32, 0.62), at(0, 0.26, 0.98), dark)
		muzzle = Vector3.new(0, 0.32, -2.05)
	elseif def.id == "trovao" then
		grip = part("Empunhadura", Vector3.new(0.3, 0.72, 0.38), at(0, -0.22, 0.36) * tilt, dark)
		part("Receptor", Vector3.new(0.42, 0.56, 1.3), at(0, 0.3, 0), body)
		part("Indicador de cartuchos", Vector3.new(0.44, 0.1, 0.62), at(0, 0.36, 0.02), accent, neon)
		tube("Cano", 0.3, 2.0, Vector3.new(0, 0.42, -1.62), light)
		tube("Tubo de munição", 0.24, 1.6, Vector3.new(0, 0.12, -1.42), dark)
		part("Bomba", Vector3.new(0.42, 0.38, 0.62), at(0, 0.12, -1.22), dark)
		part("Anel da bomba", Vector3.new(0.44, 0.06, 0.4), at(0, 0.28, -1.22), accent, neon)
		part("Coronha", Vector3.new(0.32, 0.56, 1.1), at(0, 0.16, 1.16), dark)
		part("Linha da coronha", Vector3.new(0.34, 0.05, 0.9), at(0, 0.3, 1.16), accent, neon)
		tube("Freio de boca", 0.36, 0.18, Vector3.new(0, 0.42, -2.58), accent, neon)
		muzzle = Vector3.new(0, 0.42, -2.7)
	else -- agulha
		grip = part("Empunhadura", Vector3.new(0.3, 0.7, 0.38), at(0, -0.2, 0.3) * tilt, dark)
		part("Receptor", Vector3.new(0.4, 0.56, 1.8), at(0, 0.3, -0.1), body)
		part("Faixa do receptor", Vector3.new(0.42, 0.06, 1.6), at(0, 0.44, -0.1), accent, neon)
		part("Guarda-mão", Vector3.new(0.36, 0.42, 1.1), at(0, 0.32, -1.36), dark)
		for index = 0, 2 do
			part("Fenda de ventilação", Vector3.new(0.38, 0.06, 0.22), at(0, 0.38, -1.0 - index * 0.32), accent, neon)
		end
		tube("Cano", 0.16, 1.8, Vector3.new(0, 0.36, -2.0), light)
		tube("Luneta", 0.3, 1.0, Vector3.new(0, 0.82, -0.22), dark)
		tube("Lente", 0.32, 0.06, Vector3.new(0, 0.82, -0.74), rgb(58, 231, 255), neon)
		part("Base da luneta", Vector3.new(0.14, 0.2, 0.5), at(0, 0.62, -0.22), dark)
		part("Carregador", Vector3.new(0.26, 0.82, 0.36), at(0, -0.36, -0.46) * CFrame.Angles(math.rad(12), 0, 0), body)
		part("Coronha", Vector3.new(0.3, 0.6, 1.3), at(0, 0.2, 1.36), dark)
		part("Apoio de ombro", Vector3.new(0.34, 0.7, 0.14), at(0, 0.18, 2.02), body)
		muzzle = Vector3.new(0, 0.36, -2.92)
	end
	grip.Name = "Empunhadura"
	model.PrimaryPart = grip
	local cano = Instance.new("Attachment")
	cano.Name = "Cano"
	cano.Position = grip.CFrame:PointToObjectSpace(muzzle)
	cano.Parent = grip
	model:SetAttribute("Arma", def.id)
	return model
end

-- Gun in the right hand. Weapon -Z follows the arm down (forward when aiming); the blade points forward.
local function gripOffset(def, arm: BasePart): CFrame
	local drop = arm.Size.Y / 2 + 0.05
	if def.grip == "frente" then
		return CFrame.new(0, -drop, -0.1)
	end
	return CFrame.fromMatrix(Vector3.new(0, -drop, -0.05), Vector3.xAxis, Vector3.new(0, 0, -1), Vector3.yAxis)
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
		local ok = checkShot(state, def, time, origin, directions, head.Position)
		if not ok or inSafeZone(head.Position) then
			return
		end
		local ammo = state.ammo[def.id]
		ammo.mag -= 1
		state.nextShot = time + 1 / def.rate
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
		state.nextMelee = time + 1 / def.rate
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

	action.OnServerEvent:Connect(function(player: Player, kind, a, b)
		local state = states[player]
		if not state or type(kind) ~= "string" then
			return
		end
		if kind == "equipar" and type(a) == "string" and BY_ID[a] then
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
		local function spawned(character)
			local state = newState()
			states[player] = state
			character:SetAttribute("CyberOutlawArma", "punhos")
			character:SetAttribute("CyberOutlawMirando", false)
			character:SetAttribute("CyberOutlawPitch", 0)
			publishAmmo(player, state)
		end
		player.CharacterAdded:Connect(spawned)
		if player.Character then
			spawned(player.Character)
		end
	end
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
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
	buildModel = buildModel,
	gripOffset = gripOffset,
	inSafeZone = inSafeZone,
	damageFor = damageFor,
	checkShot = checkShot,
	newState = newState,
}
