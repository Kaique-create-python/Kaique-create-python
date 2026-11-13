--!strict
-- Deterministic, asset-free bunker. No signs or environmental lettering.
-- Geometry stays owned by Sector7World.
local Workspace = game:GetService("Workspace")

local WorldBuilder = {}

local WORLD_NAME = "Sector7World"
local BUILD_VERSION = 1
local MAIN_MIN_Z = -202
local MAIN_MAX_Z = 24
local CONCRETE = Color3.fromRGB(76, 80, 77)
local PALE_CONCRETE = Color3.fromRGB(91, 92, 83)
local DARK_CONCRETE = Color3.fromRGB(48, 53, 51)
local STEEL = Color3.fromRGB(47, 54, 52)
local RUST = Color3.fromRGB(91, 54, 35)
local DULL_GREEN = Color3.fromRGB(61, 72, 55)
local PAPER = Color3.fromRGB(169, 158, 119)
local AMBER = Color3.fromRGB(255, 185, 96)
local RED = Color3.fromRGB(194, 53, 39)

type RoomDefinition = {
	name: string,
	side: number,
	z: number,
}

local ROOMS: { RoomDefinition } = {
	{ name = "Workshop", side = -1, z = -38 },
	{ name = "GeneratorRoom", side = 1, z = -92 },
	{ name = "Archive", side = -1, z = -142 },
}

function WorldBuilder.Build(): Model
	local previous = Workspace:FindFirstChild(WORLD_NAME)
	if previous then
		assert(previous:IsA("Model") and previous:GetAttribute("Sector7Owned") == true,
			"Sector7World already exists and is not owned by WorldBuilder")
		previous:Destroy()
	end

	local world = Instance.new("Model")
	world.Name = WORLD_NAME
	world:SetAttribute("Sector7Owned", true)
	world:SetAttribute("BuildVersion", BUILD_VERSION)
	world:SetAttribute("Ready", false)
	-- Parent early and yield during creation so Studio does not receive one huge update.
	world.Parent = Workspace

	local geometry = Instance.new("Folder")
	geometry.Name = "Structure"
	geometry.Parent = world
	local details = Instance.new("Folder")
	details.Name = "Details"
	details.Parent = world
	local interactions = Instance.new("Folder")
	interactions.Name = "Interactions"
	interactions.Parent = world
	local lamps = Instance.new("Folder")
	lamps.Name = "Lamps"
	lamps.Parent = world
	local nodes = Instance.new("Folder")
	nodes.Name = "CreatureNodes"
	nodes.Parent = world

	local random = Random.new(7131989)
	local partCount = 0

	local function part(
		name: string,
		size: Vector3,
		transform: CFrame,
		color: Color3,
		material: Enum.Material?,
		parent: Instance?,
		collidable: boolean?
	): Part
		local result = Instance.new("Part")
		result.Name = name
		result.Size = size
		result.CFrame = transform
		result.Color = color
		result.Material = material or Enum.Material.Concrete
		result.Anchored = true
		result.CanCollide = collidable ~= false
		result.TopSurface = Enum.SurfaceType.Smooth
		result.BottomSurface = Enum.SurfaceType.Smooth
		result.CastShadow = true
		result.Parent = parent or details
		partCount += 1
		if partCount % 180 == 0 then
			task.wait()
		end
		return result
	end

	local function block(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, parent: Instance?, collidable: boolean?): Part
		return part(name, size, CFrame.new(position), color, material, parent, collidable)
	end

	local function cylinder(name: string, center: Vector3, length: number, diameter: number, axis: string, color: Color3, parent: Instance?): Part
		local rotation = CFrame.identity
		if axis == "Y" then
			rotation = CFrame.Angles(0, 0, math.pi / 2)
		elseif axis == "Z" then
			rotation = CFrame.Angles(0, math.pi / 2, 0)
		end
		local result = part(name, Vector3.new(length, diameter, diameter), CFrame.new(center) * rotation, color, Enum.Material.Metal, parent, false)
		result.Shape = Enum.PartType.Cylinder
		return result
	end

	local function interact(target: BasePart, id: string, action: string, object: string, duration: number)
		target:SetAttribute("InteractionId", id)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Interact"
		prompt.ActionText = action
		prompt.ObjectText = object
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = 9
		prompt.HoldDuration = duration
		prompt.RequiresLineOfSight = true
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.Parent = target
	end

	local function tableProp(name: string, position: Vector3, width: number, depth: number)
		block(name .. "Top", Vector3.new(width, 0.22, depth), position + Vector3.new(0, 2.65, 0), DULL_GREEN, Enum.Material.Metal)
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				block(name .. "Leg", Vector3.new(0.16, 2.55, 0.16), position + Vector3.new(x * (width / 2 - 0.2), 1.3, z * (depth / 2 - 0.2)), STEEL, Enum.Material.Metal)
			end
		end
	end

	local function note(id: string, position: Vector3, rotation: CFrame?)
		local paper = part(id, Vector3.new(1.25, 0.045, 1.65), CFrame.new(position) * (rotation or CFrame.identity), PAPER, Enum.Material.SmoothPlastic, interactions, false)
		interact(paper, id, "Ler registro", "Registro " .. string.sub(id, 5), 0.1)
		-- Deliberately no narrative text here: Server is the authority for note content.
		for index = 1, 4 do
			part("Ink", Vector3.new(0.78 - (index % 2) * 0.18, 0.006, 0.025), paper.CFrame * CFrame.new(0, 0.027, -0.45 + index * 0.2), Color3.fromRGB(73, 71, 59), Enum.Material.SmoothPlastic, details, false)
		end
	end

	local function fuse(id: string, position: Vector3)
		block(id .. "Tray", Vector3.new(2.0, 0.12, 1.4), position - Vector3.new(0, 0.3, 0), STEEL, Enum.Material.Metal)
		local pickup = cylinder(id, position, 1.2, 0.42, "X", Color3.fromRGB(171, 142, 77), interactions)
		pickup.Material = Enum.Material.Glass
		pickup.Transparency = 0.13
		for _, offset in { -0.48, 0.48 } do
			cylinder(id .. "End", position + Vector3.new(offset, 0, 0), 0.2, 0.46, "X", Color3.fromRGB(104, 112, 103), pickup)
		end
		-- Child decoration disappears with the authoritative collected Part.
		interact(pickup, id, "Coletar fusível", "Fusível cerâmico", 0.25)
	end

	local function cagedLamp(name: string, position: Vector3, side: number, emergency: boolean?)
		local fixture = Instance.new("Model")
		fixture.Name = name
		fixture.Parent = lamps
		block("WallBracket", Vector3.new(0.8, 0.18, 0.16), position + Vector3.new(side * 0.32, 0.4, 0), STEEL, Enum.Material.Metal, fixture, false)
		local bulb = block("Bulb", Vector3.new(0.34, 0.62, 0.34), position, if emergency then RED else AMBER, Enum.Material.Neon, fixture, false)
		bulb:SetAttribute("BackupLight", true)
		local light = Instance.new("PointLight")
		light.Name = "BunkerLight"
		light.Color = bulb.Color
		light.Brightness = if emergency then 0.65 else 0.95
		light.Range = if emergency then 17 else 23
		light.Shadows = true
		light:SetAttribute("PowerLight", true)
		light.Parent = bulb
		for _, y in { -0.4, 0.4 } do
			block("CageRing", Vector3.new(0.66, 0.09, 0.66), position + Vector3.new(0, y, 0), STEEL, Enum.Material.Metal, fixture, false)
		end
		for _, x in { -0.28, 0.28 } do
			for _, z in { -0.28, 0.28 } do
				block("CageBar", Vector3.new(0.045, 0.8, 0.045), position + Vector3.new(x, 0, z), STEEL, Enum.Material.Metal, fixture, false)
			end
		end
	end

	-- Continuous floor, with no steps between corridor and side-room thresholds.
	block("TunnelFloor", Vector3.new(16, 0.8, MAIN_MAX_Z - MAIN_MIN_Z), Vector3.new(0, -0.4, (MAIN_MAX_Z + MAIN_MIN_Z) / 2), DARK_CONCRETE, Enum.Material.Concrete, geometry)
	block("RearBulkhead", Vector3.new(16.7, 12, 0.9), Vector3.new(0, 6, MAIN_MAX_Z), CONCRETE, Enum.Material.Concrete, geometry)
	block("EvacuationEndWall", Vector3.new(16.7, 12, 0.9), Vector3.new(0, 6, MAIN_MIN_Z), CONCRETE, Enum.Material.Concrete, geometry)

	-- Cut actual holes in each side wall. There is no invisible wall across a room entry.
	for _, side in { -1, 1 } do
		local openings: { { lo: number, hi: number } } = {}
		for _, room in ROOMS do
			if room.side == side then
				table.insert(openings, { lo = room.z - 5.5, hi = room.z + 5.5 })
			end
		end
		table.sort(openings, function(a, b) return a.lo < b.lo end)
		local cursor = MAIN_MIN_Z
		for _, opening in openings do
			block("TunnelSideWall", Vector3.new(0.8, 7.2, opening.lo - cursor), Vector3.new(side * 8.35, 3.6, (cursor + opening.lo) / 2), CONCRETE, Enum.Material.Concrete, geometry)
			cursor = opening.hi
		end
		block("TunnelSideWall", Vector3.new(0.8, 7.2, MAIN_MAX_Z - cursor), Vector3.new(side * 8.35, 3.6, (cursor + MAIN_MAX_Z) / 2), CONCRETE, Enum.Material.Concrete, geometry)
	end

	-- The upper half-circle is built from broad concrete facets, not dense mesh detail.
	local sectionLength = 10
	local sectionZ = MAIN_MIN_Z
	while sectionZ < MAIN_MAX_Z do
		local depth = math.min(sectionLength, MAIN_MAX_Z - sectionZ)
		local z = sectionZ + depth / 2
		for slice = 0, 11 do
			local angle = (slice + 0.5) * math.pi / 12
			local center = Vector3.new(math.cos(angle) * 8.05, 7.0 + math.sin(angle) * 8.05, z)
			part("VaultPanel", Vector3.new(2.18, 0.65, depth + 0.07), CFrame.new(center) * CFrame.Angles(0, 0, angle + math.pi / 2), if (slice + math.floor(-z / 10)) % 4 == 0 then PALE_CONCRETE else CONCRETE, Enum.Material.Concrete, geometry)
		end
		-- Raised ribs cast the repeated shadow rhythm visible in old service tunnels.
		if math.floor(-sectionZ / 10) % 2 == 0 then
			for slice = 0, 11 do
				local angle = (slice + 0.5) * math.pi / 12
				local center = Vector3.new(math.cos(angle) * 7.96, 7.0 + math.sin(angle) * 7.96, sectionZ)
				part("VaultRib", Vector3.new(2.12, 0.16, 0.24), CFrame.new(center) * CFrame.Angles(0, 0, angle + math.pi / 2), DARK_CONCRETE, Enum.Material.Concrete, details, false)
			end
		end
		sectionZ += sectionLength
	end

	local function inDoorway(side: number, z: number, margin: number): boolean
		for _, room in ROOMS do
			if room.side == side and math.abs(z - room.z) < 5.5 + margin then
				return true
			end
		end
		return false
	end

	for z = 17, -195, -8 do
		for _, side in { -1, 1 } do
			if not inDoorway(side, z, 3.2) then
				local panelColor = if random:NextNumber() > 0.47 then RUST else STEEL
				block("RustedWallPlate", Vector3.new(0.12, 3.5, 5.9), Vector3.new(side * 7.88, 2.4, z), panelColor, Enum.Material.CorrodedMetal, details, false)
				block("PlateSeam", Vector3.new(0.18, 3.6, 0.09), Vector3.new(side * 7.79, 2.4, z - 2.85), STEEL, Enum.Material.Metal, details, false)
				for _, y in { 0.95, 3.82 } do
					for _, dz in { -2.55, 2.55 } do
						block("PlateRivet", Vector3.new(0.08, 0.12, 0.12), Vector3.new(side * 7.76, y, z + dz), Color3.fromRGB(115, 103, 77), Enum.Material.Metal, details, false)
					end
				end
			end
		end
	end

	for z = 18, -198, -12 do
		for _, x in { -3.65, 3.65 } do
			block("ServiceRail", Vector3.new(0.15, 0.18, 12.1), Vector3.new(x, 0.09, z - 6), RUST, Enum.Material.CorrodedMetal, details, false)
		end
		for offset = 0, 9, 3 do
			block("RailSleeper", Vector3.new(8.1, 0.055, 0.34), Vector3.new(0, 0.027, z - offset), STEEL, Enum.Material.Metal, details, false)
		end
		block("DrainChannel", Vector3.new(0.75, 0.025, 11.9), Vector3.new(0, 0.018, z - 6), Color3.fromRGB(21, 27, 26), Enum.Material.Metal, details, false)
		for offset = 0, 10, 2 do
			block("DrainGrate", Vector3.new(0.86, 0.035, 0.1), Vector3.new(0, 0.035, z - offset), STEEL, Enum.Material.Metal, details, false)
		end
		local puddle = part("FloorDamp", Vector3.new(random:NextNumber(2.2, 4.9), 0.016, random:NextNumber(4, 8)), CFrame.new(random:NextNumber(-3.9, 3.9), 0.05, z - 5) * CFrame.Angles(0, random:NextNumber(-0.4, 0.4), 0), Color3.fromRGB(26, 37, 35), Enum.Material.Glass, details, false)
		puddle.Transparency = 0.6
		puddle.Reflectance = 0.19
		puddle.CastShadow = false
	end

	for z = 18, -198, -10 do
		-- Runs sit above head height and bridge door openings without blocking them.
		cylinder("HeatingMain", Vector3.new(6.85, 6.1, z - 5), 10.05, 0.45, "Z", RUST)
		cylinder("HeatingReturn", Vector3.new(6.85, 5.42, z - 5), 10.05, 0.24, "Z", STEEL)
		cylinder("PipeCollar", Vector3.new(6.85, 6.1, z), 0.2, 0.59, "Z", STEEL)
		block("PipeBracket", Vector3.new(0.8, 0.09, 0.25), Vector3.new(7.2, 5.9, z), STEEL, Enum.Material.Metal, details, false)
		for cable = 0, 2 do
			cylinder("CableRun", Vector3.new(-6.9, 5.6 + cable * 0.18, z - 5), 10.05, 0.075, "Z", Color3.fromRGB(24, 27, 25))
		end
		block("CableTray", Vector3.new(0.75, 0.1, 0.2), Vector3.new(-7.12, 5.4, z), STEEL, Enum.Material.Metal, details, false)
	end

	for index = 0, 12 do
		local z = 10 - index * 16
		local side = if index % 2 == 0 then -1 else 1
		-- Keep the fixture out of the 11-stud-wide room portals.
		if not inDoorway(side, z, 0.7) then
			cagedLamp(string.format("TunnelLamp%02d", index + 1), Vector3.new(side * 7.28, 5.0, z), side, index == 10)
		end
	end

	for _, room in ROOMS do
		local centerX = room.side * 20
		local outerX = room.side * 32.35
		block(room.name .. "Floor", Vector3.new(24.8, 0.8, 24.8), Vector3.new(centerX, -0.4, room.z), DARK_CONCRETE, Enum.Material.Concrete, geometry)
		block(room.name .. "Ceiling", Vector3.new(25, 0.65, 24.8), Vector3.new(centerX, 8.55, room.z), CONCRETE, Enum.Material.Concrete, geometry)
		block(room.name .. "OuterWall", Vector3.new(0.8, 8.5, 24.8), Vector3.new(outerX, 4.25, room.z), CONCRETE, Enum.Material.Concrete, geometry)
		for _, dz in { -12.2, 12.2 } do
			block(room.name .. "EndWall", Vector3.new(24.8, 8.5, 0.8), Vector3.new(centerX, 4.25, room.z + dz), CONCRETE, Enum.Material.Concrete, geometry)
		end
		for _, dz in { -5.7, 5.7 } do
			block("PortalJamb", Vector3.new(1.05, 7.0, 0.4), Vector3.new(room.side * 8.2, 3.5, room.z + dz), DARK_CONCRETE, Enum.Material.Concrete, geometry)
		end
		block("PortalLintel", Vector3.new(1.05, 1.4, 11.8), Vector3.new(room.side * 8.2, 7.7, room.z), DARK_CONCRETE, Enum.Material.Concrete, geometry)
		for _, xOffset in { -5.5, 5.5 } do
			block("CeilingBeam", Vector3.new(0.3, 0.48, 24), Vector3.new(centerX + xOffset, 8.04, room.z), STEEL, Enum.Material.Metal, details, false)
		end
		cagedLamp(room.name .. "Lamp", Vector3.new(room.side * 31.1, 6.0, room.z), room.side, false)
		cagedLamp(room.name .. "BackupLamp", Vector3.new(room.side * 20, 6.8, room.z - 10.9), 0, room.name == "GeneratorRoom")
	end

	-- Workshop: wall tools, workbench, spare fuse, restrained floor clutter.
	tableProp("WorkshopBench", Vector3.new(-27.2, 0, -31), 6.0, 2.5)
	tableProp("WorkshopDesk", Vector3.new(-27.0, 0, -44), 5.3, 3)
	fuse("Fuse1", Vector3.new(-27.8, 3.08, -31))
	note("Note2", Vector3.new(-27.0, 2.8, -44), CFrame.Angles(0, -0.12, 0))
	block("ToolBoard", Vector3.new(0.16, 3.1, 7.3), Vector3.new(-31.76, 4.5, -34), DULL_GREEN, Enum.Material.Metal, details, false)
	for index = 0, 6 do
		part("HangingTool", Vector3.new(0.08, 1.0 + (index % 3) * 0.2, 0.12), CFrame.new(-31.6, 4.7, -36.6 + index * 0.8) * CFrame.Angles(0.1 * index, 0, 0), STEEL, Enum.Material.Metal, details, false)
	end
	for index = 0, 2 do
		cylinder("OilDrum", Vector3.new(-30 + index * 2.1, 1.45, -48), 2.9, 1.65, "Y", if index == 1 then RUST else DULL_GREEN)
	end
	block("WorkshopCrate", Vector3.new(3, 2.3, 2.6), Vector3.new(-13.8, 1.15, -47.5), Color3.fromRGB(82, 69, 47), Enum.Material.WoodPlanks)

	-- Generator room. Machinery occupies the back half; the entrance stays wide open.
	block("GeneratorFoundation", Vector3.new(9.1, 0.4, 6.6), Vector3.new(25.5, 0.2, -93.5), DARK_CONCRETE, Enum.Material.Concrete)
	block("GeneratorBody", Vector3.new(7.5, 3.4, 5.0), Vector3.new(25.5, 2.1, -93.5), DULL_GREEN, Enum.Material.CorrodedMetal)
	block("GeneratorTop", Vector3.new(6.5, 0.45, 4.7), Vector3.new(25.5, 4.0, -93.5), STEEL, Enum.Material.Metal)
	cylinder("GeneratorRotor", Vector3.new(20.9, 2.4, -93.5), 1.6, 3.2, "X", STEEL)
	for index = 0, 6 do
		block("CoolingFin", Vector3.new(0.18, 2.6, 4.9), Vector3.new(23.1 + index * 0.8, 2.2, -93.5), STEEL, Enum.Material.Metal, details, false)
	end
	cylinder("GeneratorExhaust", Vector3.new(28.5, 5.6, -94.7), 4.0, 0.5, "Y", RUST)
	cylinder("ExhaustReturn", Vector3.new(30, 7.4, -94.7), 3.0, 0.5, "X", RUST)
	local console = block("Generator", Vector3.new(2.2, 1.3, 1.2), Vector3.new(18.4, 2.7, -89), DULL_GREEN, Enum.Material.Metal, interactions)
	block("ControlPedestal", Vector3.new(1.4, 2.1, 0.8), Vector3.new(18.4, 1.05, -89), STEEL, Enum.Material.Metal)
	local indicator = block("PowerIndicator", Vector3.new(0.18, 0.18, 0.08), Vector3.new(17.8, 2.9, -88.35), RED, Enum.Material.Neon, details, false)
	indicator:SetAttribute("PowerIndicator", true)
	for index = 0, 2 do
		block("ConsoleSwitch", Vector3.new(0.12, 0.25, 0.09), Vector3.new(18.1 + index * 0.42, 2.6, -88.34), STEEL, Enum.Material.Metal, details, false)
	end
	interact(console, "Generator", "Ligar gerador", "Painel de energia", 1.0)
	tableProp("GeneratorSpares", Vector3.new(28.2, 0, -83), 5.4, 2.3)
	fuse("Fuse2", Vector3.new(28.8, 3.08, -83))
	note("Note3", Vector3.new(31.78, 3.25, -100), CFrame.Angles(0, 0, math.pi / 2))
	for index = 0, 2 do
		block("ElectricalCabinet", Vector3.new(1.5, 5.4, 2.6), Vector3.new(31, 2.7, -85.2 - index * 3.0), STEEL, Enum.Material.Metal)
	end

	-- Archive: narrow aisles around the outer cabinets, with a reachable central desk.
	for index = 0, 3 do
		local z = -133.7 - index * 4.4
		block("ArchiveCabinet", Vector3.new(2.3, 5.8, 3.3), Vector3.new(-30.5, 2.9, z), DULL_GREEN, Enum.Material.Metal)
		for drawer = 0, 3 do
			block("DrawerFront", Vector3.new(0.08, 1.0, 2.8), Vector3.new(-29.3, 0.85 + drawer * 1.33, z), STEEL, Enum.Material.Metal, details, false)
			block("DrawerHandle", Vector3.new(0.1, 0.12, 0.7), Vector3.new(-29.23, 0.91 + drawer * 1.33, z), Color3.fromRGB(115, 113, 90), Enum.Material.Metal, details, false)
		end
	end
	tableProp("ArchiveDesk", Vector3.new(-21.5, 0, -143.5), 7.4, 4.0)
	tableProp("ArchiveShelf", Vector3.new(-24.8, 0, -150.8), 5.8, 2.4)
	fuse("Fuse3", Vector3.new(-24.8, 3.08, -150.8))
	local keycard = part("Keycard", Vector3.new(0.72, 0.05, 1.05), CFrame.new(-20.8, 2.82, -143.4) * CFrame.Angles(0, 0.25, 0), Color3.fromRGB(156, 161, 135), Enum.Material.SmoothPlastic, interactions, false)
	interact(keycard, "Keycard", "Pegar cartão", "Cartão de evacuação", 0.25)
	block("CardStripe", Vector3.new(0.55, 0.008, 0.14), Vector3.new(-20.8, 2.85, -143.55), RED, Enum.Material.SmoothPlastic, keycard, false)
	note("Note4", Vector3.new(-23.5, 2.81, -143), CFrame.Angles(0, 0.2, 0))
	for index = 0, 2 do
		block("PaperStack", Vector3.new(1.4, 0.16, 1.9), Vector3.new(-22.3, 2.88 + index * 0.17, -144.5), PAPER, Enum.Material.SmoothPlastic, details, false)
	end

	-- Small story document; no wall signs or environmental lettering.
	note("Note1", Vector3.new(7.76, 3.5, 7), CFrame.Angles(0, 0, math.pi / 2))

	-- The exit uses ONE moving/collidable leaf. Decorations do not block the opening.
	for _, x in { -7.95, 7.95 } do
		block("ExitFrameJamb", Vector3.new(0.5, 10.4, 1.5), Vector3.new(x, 5.2, -180), STEEL, Enum.Material.Metal, geometry)
	end
	block("ExitFrameLintel", Vector3.new(16.4, 0.6, 1.5), Vector3.new(0, 10.4, -180), STEEL, Enum.Material.Metal, geometry)
	local exitDoor = block("ExitDoor", Vector3.new(15.4, 10, 1), Vector3.new(0, 5, -180), DULL_GREEN, Enum.Material.CorrodedMetal, world)
	exitDoor:SetAttribute("ClosedCFrame", exitDoor.CFrame)
	exitDoor:SetAttribute("OpenOffset", Vector3.new(0, 11, 0))
	interact(exitDoor, "Exit", "Abrir evacuação", "Porta de evacuação", 0.8)
	cagedLamp("ExitEmergencyLamp", Vector3.new(7.25, 6.3, -176), 1, true)
	cagedLamp("EvacuationLamp", Vector3.new(-7.25, 6.3, -191), -1, false)
	local exitZone = block("ExitZone", Vector3.new(14, 8, 14), Vector3.new(0, 4, -191), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, world, false)
	exitZone.Transparency = 1
	exitZone.CanQuery = false
	exitZone.CastShadow = false

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BunkerSpawn"
	spawn.Size = Vector3.new(7, 0.15, 7)
	spawn.CFrame = CFrame.new(0, 0.075, 12)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.AllowTeamChangeOnTouch = false
	spawn.Parent = world
	partCount += 1
	local spawnPoint = block("SpawnPoint", Vector3.new(1, 1, 1), Vector3.new(0, 3, 12), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, world, false)
	spawnPoint.Transparency = 1
	spawnPoint.CanQuery = false
	spawnPoint.CanTouch = false
	spawnPoint.CastShadow = false

	-- Adjacent numbered nodes form a clear walking route, including room detours.
	local route = {
		Vector3.new(0, 3, 10), Vector3.new(0, 3, -12), Vector3.new(0, 3, -38),
		Vector3.new(-14, 3, -38), Vector3.new(-25, 3, -38), Vector3.new(-14, 3, -38),
		Vector3.new(0, 3, -38), Vector3.new(0, 3, -65), Vector3.new(0, 3, -92),
		Vector3.new(13, 3, -92), Vector3.new(17, 3, -98), Vector3.new(13, 3, -92),
		Vector3.new(0, 3, -92), Vector3.new(0, 3, -119), Vector3.new(0, 3, -142),
		Vector3.new(-14, 3, -142), Vector3.new(-16, 3, -149), Vector3.new(-14, 3, -142),
		Vector3.new(0, 3, -142), Vector3.new(0, 3, -164),
	}
	for index, position in route do
		local node = block(string.format("Node%02d", index), Vector3.new(1, 1, 1), position, Color3.fromRGB(255, 0, 255), Enum.Material.SmoothPlastic, nodes, false)
		node.Transparency = 1
		node.CanQuery = false
		node.CanTouch = false
		node.CastShadow = false
		node:SetAttribute("Order", index)
	end

	world:SetAttribute("PartCount", partCount)
	world:SetAttribute("Ready", true)
	return world
end

return WorldBuilder
