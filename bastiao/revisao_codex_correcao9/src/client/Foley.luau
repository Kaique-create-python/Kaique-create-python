-- PROJETO BASTIÃO :: passos por deslocamento, criatura e UI a partir de assets publicados.
-- Som continua dono das vozes, rádio, eventos narrativos e ambiente. Nenhum ID é inventado.
local Foley = {}
local Timing = {}
Foley.Timing = Timing

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Timing.asset(entry)
	if type(entry) ~= "table" or not finite(entry.id) or entry.id <= 0 or entry.id % 1 ~= 0 or entry.id > 9007199254740991 then
		return nil
	end
	if not finite(entry.duration) or entry.duration <= 0 or entry.duration > 90 then
		return nil
	end
	local category = entry.category
	if category ~= "Foley" and category ~= "UI" then
		return nil
	end
	if entry.volume ~= nil and not finite(entry.volume) then
		return nil
	end
	for _, flag in { "spatial", "loop", "radio" } do
		if entry[flag] ~= nil and type(entry[flag]) ~= "boolean" then return nil end
	end
	if entry.start ~= nil or entry.finish ~= nil then
		if not finite(entry.start) or not finite(entry.finish) or entry.start < 0 or entry.finish <= entry.start
			or entry.finish > 7200 or math.abs(entry.finish - entry.start - entry.duration) > 0.08 then
			return nil
		end
	end
	return {
		id = entry.id,
		duration = entry.duration,
		volume = math.clamp(if entry.volume == nil then 0.8 else entry.volume, 0, 1),
		category = category,
		loop = entry.loop == true,
		spatial = entry.spatial,
		radio = entry.radio == true,
		start = entry.start,
		finish = entry.finish,
	}
end

function Timing.segment(position, entry)
	if entry.finish and position >= entry.finish then
		return if entry.loop then entry.start else nil, not entry.loop
	end
	return nil, false
end

function Timing.deadline(now, duration, persistent)
	if persistent then
		return math.huge
	end
	-- Inclui uma pequena margem de carregamento; Loaded reinicia o limite pela duração real.
	return now + math.clamp(if finite(duration) then duration else 2, 0.05, 90) + 3
end

function Timing.newStep()
	return { x = nil, z = nil, distance = 0, elapsed = 0 }
end

function Timing.step(state, sample)
	local x, z, dt = sample.x, sample.z, sample.dt
	local previousX, previousZ = state.x, state.z
	state.x, state.z = if finite(x) then x else nil, if finite(z) then z else nil
	if not finite(x) or not finite(z) or not finite(dt) or dt <= 0 or dt > 0.25 or not previousX or not previousZ
		or not sample.alive or not sample.grounded or not sample.walking then
		state.distance, state.elapsed = 0, 0
		return nil
	end
	local delta = math.sqrt((x - previousX) ^ 2 + (z - previousZ) ^ 2)
	local speed = delta / dt
	if speed < 0.75 or speed > 45 or delta > 6 then
		state.distance, state.elapsed = 0, 0
		return nil
	end
	local running = speed >= 14
	local stride = if running then 5.3 else 4.5
	state.distance += delta
	state.elapsed += dt
	if state.distance < stride or state.elapsed < (if running then 0.22 else 0.3) then
		return nil
	end
	state.distance = math.min(state.distance - stride, stride * 0.5)
	state.elapsed = 0
	return { running = running, gain = if running then 1 else 0.78, speed = speed }
end

function Timing.surface(material)
	return if material == "Metal" or material == "DiamondPlate" or material == "CorrodedMetal" or material == "Foil" then "metal" else "concrete"
end

function Timing.creatureAudible(state)
	return state == "idle" or state == "roam" or state == "patrol" or state == "alert"
		or state == "chase" or state == "search" or state == "attack" or state == "roar"
end

function Timing.pickVictim(records, category, limit)
	local count, oldest, serial = 0, nil, math.huge
	for index, record in records do
		if record.category == category then
			count += 1
			if not record.looped and record.serial < serial then
				oldest, serial = index, record.serial
			end
		end
	end
	if count < limit then
		return nil
	end
	return oldest or false
end

local UI_KEYS = { ui_click = true, ui_confirm = true, ui_denied = true }
local PHYSICAL_KEYS = { monster_step_01 = true, monster_step_02 = true, monster_breath = true, monster_roar = true }
for _, family in { { "concrete", 4 }, { "metal", 2 } } do
	for i = 1, family[2] do PHYSICAL_KEYS["soldier_step_" .. family[1] .. "_" .. string.format("%02d", i)] = true end
end
local function supported(key, raw)
	if type(raw) ~= "table" then return false end
	if UI_KEYS[key] then return raw.category == "UI" and raw.loop ~= true and raw.spatial ~= true end
	return PHYSICAL_KEYS[key] == true and raw.category == "Foley" and raw.spatial == true
		and (key == "monster_breath" or raw.loop ~= true)
end
local function regionReady(sound, entry)
	if not sound.IsLoaded then return false end
	if not entry.finish then return true end
	if not finite(sound.TimeLength) or sound.TimeLength <= 0 or entry.finish > sound.TimeLength + 0.05 then return false end
	return pcall(function()
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(entry.start, entry.finish)
		sound.LoopRegion = NumberRange.new(entry.start, entry.finish)
	end)
end

-- Retorna uma sessão; chamar destroy antes de substituir o LocalScript durante testes.
function Foley.start(player, catalog, op)
	op = op or {}
	local SoundService = game:GetService("SoundService")
	local ContentProvider = game:GetService("ContentProvider")
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local alive = true
	local connections, records, actors, warned = {}, {}, {}, {}
	local loaded, entries = {}, {}
	local ownsSteps = false
	local updateOwnership
	local serial = 0
	local lastUI = {}
	local random = Random.new()
	local limits = { Foley = 10, UI = 3 }

	local function warnOnce(key, message)
		if not warned[key] then
			warned[key] = true
			warn("[Bastiao Foley] " .. message)
		end
	end
	if type(catalog) == "table" and catalog.version == 1 and type(catalog.assets) == "table" then
		for key, raw in catalog.assets do
			if supported(key, raw) then
				entries[key] = Timing.asset(raw)
				if not entries[key] then
					warnOnce(key, "asset ausente ou inválido: " .. key)
				end
			end
		end
	else
		warnOnce("catalog", "AudioCatalog v1 ausente; passos e áudio da história continuam no Som")
	end

	local sounds = Instance.new("Folder")
	sounds.Name = "BastiaoFoleyLocal"
	sounds.Parent = SoundService
	local emitters = Instance.new("Folder")
	emitters.Name = "BastiaoFoleyLocal"
	emitters.Parent = Workspace
	-- Compartilha o reverb de Som; não cria outro mixer nem ambiente. UI permanece 2D seco.
	local groups = { Foley = op.grupo }

	local function cleanup(record)
		if not records[record] then
			return
		end
		records[record] = nil
		for _, connection in record.connections do
			connection:Disconnect()
		end
		record.sound:Stop()
		record.sound:Destroy()
		if record.attachment then record.attachment:Destroy() end
		if record.emitter then record.emitter:Destroy() end
	end

	local function playerRoot()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root else nil
	end

	local function play(key, source, options)
		if not alive then return nil end
		local entry = entries[key]
		if not entry then
			warnOnce(key, "sem asset publicado para " .. tostring(key))
			return nil
		end
		options = options or {}
		local persistent = options.persistent == true and entry.loop
		local active = {}
		for record in records do table.insert(active, record) end
		local victim = Timing.pickVictim(active, entry.category, limits[entry.category])
		if victim == false then return nil end
		if victim then cleanup(active[victim]) end
		-- No máximo dez Foley e três UI, incluindo respiração persistente.
		local sound = Instance.new("Sound")
		sound.Name = "Bastiao_" .. key
		sound.SoundId = "rbxassetid://" .. tostring(entry.id)
		sound.Volume = entry.volume * math.clamp(options.gain or 1, 0, 1)
		if PHYSICAL_KEYS[key] then
			-- Monstro de dar medo (pedido do dono): volume no máximo, grave forte, estourado e com cauda longa.
			local rugido = key == "monster_roar"
			sound.Volume = if rugido then 10 else math.min(10, sound.Volume * 5)
			local eq = Instance.new("EqualizerSoundEffect")
			eq.LowGain, eq.MidGain, eq.HighGain = 10, if rugido then 3 else 0, if rugido then -5 else -8
			eq.Priority = 3
			eq.Parent = sound
			local dist = Instance.new("DistortionSoundEffect")
			dist.Level = if rugido then 0.55 else 0.25
			dist.Priority = 2
			dist.Parent = sound
			local rev = Instance.new("ReverbSoundEffect")
			rev.DecayTime = if rugido then 3.2 else 1.8 -- eco de corredor de bunker
			rev.Density, rev.Diffusion = 1, 1
			rev.DryLevel, rev.WetLevel = 0, if rugido then -2 else -4
			rev.Priority = 1
			rev.Parent = sound
			-- mais grave e mais longo (o rugido dura ~30% a mais)
			sound.PlaybackSpeed = if rugido then 0.74 else 0.85
		end
		sound.SoundGroup = groups[entry.category]
		sound.Looped = persistent
		sound.PlayOnRemove = false
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 6
		sound.RollOffMaxDistance = if key == "monster_roar" then 320 elseif PHYSICAL_KEYS[key] then 180 else 110
		if PHYSICAL_KEYS[key] then sound.RollOffMinDistance = if key == "monster_roar" then 30 else 16 end
		local parent, attachment, emitter = sounds, nil, nil
		if entry.spatial == true and not source then source = playerRoot() end
		if source and entry.spatial ~= false then
			if typeof(source) == "Vector3" then
				emitter = Instance.new("Part")
				emitter.Name = "Fonte_" .. key
				emitter.Size = Vector3.new(0.1, 0.1, 0.1)
				emitter.Position = source
				emitter.Anchored = true
				emitter.CanCollide, emitter.CanTouch, emitter.CanQuery = false, false, false
				emitter.Transparency = 1
				emitter.CastShadow = false
				emitter.Parent = emitters
				source = emitter
			end
			if typeof(source) == "Instance" and source:IsA("BasePart") and source.Parent then
				attachment = Instance.new("Attachment")
				attachment.Name = "BastiaoAudio"
				attachment.Position = options.offset or Vector3.zero
				attachment.Parent = source
				parent = attachment
			end
		end

		serial += 1
		local record = {
			key = key, category = entry.category, serial = serial, looped = persistent,
			sound = sound, entry = entry, attachment = attachment, emitter = emitter,
			connections = {}, started = false, deadline = os.clock() + 8,
			actor = options.actor,
			segment = if entry.finish then { start = entry.start, finish = entry.finish, loop = persistent } else nil,
		}
		records[record] = true
		local function begin()
			if not alive or not records[record] or record.started then return end
			if not regionReady(sound, entry) then
				loaded[key] = nil
				if updateOwnership then updateOwnership() end
				warnOnce("region_" .. key, "asset/região não disponível: " .. key)
				cleanup(record)
				return
			end
			-- Seek só após IsLoaded/Loaded; nunca começa no início de um atlas por engano.
			sound.TimePosition = entry.start or 0
			record.started = true
			record.deadline = Timing.deadline(os.clock(), entry.duration, persistent)
			loaded[key] = true
			sound:Play()
		end
		table.insert(record.connections, sound.Ended:Connect(function()
			if not persistent then cleanup(record) end
		end))
		table.insert(record.connections, sound.Loaded:Connect(begin))
		sound.Parent = parent
		if sound.IsLoaded then begin() end
		return record
	end

	local api = {}
	function api.ui(key)
		if key ~= "ui_click" and key ~= "ui_confirm" and key ~= "ui_denied" then return false end
		local now = os.clock()
		if now - (lastUI[key] or -math.huge) < 0.08 then return false end
		lastUI[key] = now
		return play(key, nil) ~= nil
	end

	local function restoreDefault(actor, sound)
		local saved = actor.suppressed[sound]
		if saved then
			actor.suppressed[sound] = nil
			saved.connection:Disconnect()
			if sound.Parent then sound.Volume = saved.volume end
		end
	end
	local function suppressDefault(actor, name, enabled)
		local sound = actor.root:FindFirstChild(name)
		if not sound or not sound:IsA("Sound") then return end
		if not enabled then restoreDefault(actor, sound); return end
		if actor.suppressed[sound] then return end
		local saved = { volume = sound.Volume }
		actor.suppressed[sound] = saved
		saved.connection = sound:GetPropertyChangedSignal("Volume"):Connect(function()
			if alive and actor.suppressed[sound] and sound.Volume ~= 0 then sound.Volume = 0 end
		end)
		sound.Volume = 0
	end
	local function removeActor(model)
		local actor = actors[model]
		if not actor then return end
		actors[model] = nil
		for _, connection in actor.connections do connection:Disconnect() end
		local suppressed = {}
		for sound in actor.suppressed do table.insert(suppressed, sound) end
		for _, sound in suppressed do restoreDefault(actor, sound) end
		for record in records do if record.actor == model then cleanup(record) end end
	end
	local function stepKeys(kind, surface)
		local keys = {}
		local prefix = if kind == "monster" then "monster_step_" else "soldier_step_" .. surface .. "_"
		local count = if kind == "monster" or surface == "metal" then 2 else 4
		for i = 1, count do
			local key = prefix .. string.format("%02d", i)
			if loaded[key] then table.insert(keys, key) end
		end
		return keys
	end
	updateOwnership = function()
		local ready = #stepKeys("soldier", "concrete") > 0
		if ready == ownsSteps then return end
		ownsSteps = ready
		for _, actor in actors do
			actor.step = Timing.newStep()
			if not ready then
				local saved = {}
				for sound in actor.suppressed do table.insert(saved, sound) end
				for _, sound in saved do restoreDefault(actor, sound) end
			end
		end
		if op.aoPassosMudar then op.aoPassosMudar(ready) end
	end
	local function bindActor(model, kind, isLocal)
		if not model:IsDescendantOf(Workspace) then return end
		if actors[model] then
			-- Com streaming, a raiz da criatura pode chegar antes do Humanoid.
			actors[model].humanoid = model:FindFirstChildOfClass("Humanoid")
			return
		end
		local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or (kind ~= "monster" and not humanoid) then return end
		local count = 0
		for _ in actors do count += 1 end
		if count >= 16 and not isLocal then return end
		local actor = {
			model = model, root = root, humanoid = humanoid, kind = kind, isLocal = isLocal,
			step = Timing.newStep(), connections = {}, suppressed = {}, index = 0,
			nextBreath = os.clock() + 1, breath = nil,
			lastRoar = model:GetAttribute("BastiaoRoarSerial"),
		}
		actors[model] = actor
		table.insert(actor.connections, model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) then removeActor(model) end
		end))

		if kind == "monster" then
			-- Passos do monstro no instante em que o pé encosta (marcadores Foot_* das animações,
			-- repassados pelo servidor). O monstro é movido sem física, então o estado do Humanoid
			-- não diz se ele anda: por isso o ritmo por distância quase não tocava.
			actor.marker = model:GetAttribute("BastiaoMarkerSerial")
			table.insert(actor.connections, model:GetAttributeChangedSignal("BastiaoMarkerSerial"):Connect(function()
				local serial = model:GetAttribute("BastiaoMarkerSerial")
				if serial == actor.marker then return end
				actor.marker = serial
				local name = model:GetAttribute("BastiaoMarkerName")
				if type(name) ~= "string" then return end
				local foot = string.sub(name, 1, 4) == "Foot" or name == "Scuff" or name == "Land" or name == "WeightImpact"
				if not foot then return end
				actor.markerAt = os.clock()
				local listener = playerRoot()
				if listener and (actor.root.Position - listener.Position).Magnitude > 170 then return end
				local keys = stepKeys("monster", "concrete")
				if #keys == 0 then return end
				actor.index = actor.index % #keys + 1
				local running = model:GetAttribute("BastiaoAnimation") == "08_CORRER" or model:GetAttribute("BastiaoState") == "chase"
				play(keys[actor.index], actor.root, {
					actor = model, gain = if running then 1.3 else 1.05, offset = Vector3.new(0, -2.5, 0),
				})
			end))
			table.insert(actor.connections, model:GetAttributeChangedSignal("BastiaoRoarSerial"):Connect(function()
				local value = model:GetAttribute("BastiaoRoarSerial")
				if value ~= actor.lastRoar and type(value) == "number" then
					actor.lastRoar = value
					if loaded.monster_roar and Timing.creatureAudible(model:GetAttribute("BastiaoState")) then
						play("monster_roar", root, { actor = model })
					end
				end
			end))
		end
	end
	local function consider(model)
		if not model or not model:IsA("Model") then return end
		local story = Workspace:FindFirstChild("BastiaoHistoria")
		if story and model:IsDescendantOf(story) and (model.Name == "Bastiao731A" or model:GetAttribute("BastiaoCreature") == true) then
			bindActor(model, "monster", false)
		elseif story and model:IsDescendantOf(story) and model.Name == "Pavel" then
			bindActor(model, "soldier", false)
		else
			local owner = Players:GetPlayerFromCharacter(model)
			if owner then bindActor(model, "soldier", owner == player) end
		end
	end
	local playerConnections = {}
	local function watchPlayer(other)
		if playerConnections[other] then return end
		playerConnections[other] = other.CharacterAdded:Connect(consider)
		if other.Character then consider(other.Character) end
	end
	watchPlayer(player)
	for _, other in Players:GetPlayers() do watchPlayer(other) end
	table.insert(connections, Players.PlayerAdded:Connect(watchPlayer))
	table.insert(connections, Players.PlayerRemoving:Connect(function(other)
		if playerConnections[other] then playerConnections[other]:Disconnect(); playerConnections[other] = nil end
		if other.Character then removeActor(other.Character) end
	end))
	local story = Workspace:FindFirstChild("BastiaoHistoria")
	if story then for _, instance in story:GetDescendants() do if instance:IsA("Model") then consider(instance) end end end
	table.insert(connections, Workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("Model") then
			consider(instance)
		elseif instance:IsA("Humanoid") or (instance:IsA("BasePart") and instance.Name == "HumanoidRootPart") then
			consider(instance:FindFirstAncestorOfClass("Model"))
		end
	end))

	local raycast = RaycastParams.new()
	raycast.FilterType = Enum.RaycastFilterType.Exclude
	local tickAccumulator = 0
	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		if not alive then return end
		local now = os.clock()
		for record in records do
			if not record.sound.Parent or now >= record.deadline then
				cleanup(record)
			else
				if record.started and record.segment then
					local restart, finished = Timing.segment(record.sound.TimePosition, record.segment)
					if finished then
						cleanup(record)
					elseif restart then
						record.sound.TimePosition = restart
						if not record.sound.IsPlaying then record.sound:Play() end
					end
				end
			end
		end
		-- Sons de posição são amostrados a 20 Hz; o dt agregado continua rejeitando travamentos.
		tickAccumulator += dt
		if tickAccumulator < 0.05 then return end
		local sampleDt = tickAccumulator
		tickAccumulator = 0
		local listener = playerRoot()
		for model, actor in actors do
			if not actor.root.Parent or not model:IsDescendantOf(Workspace) then removeActor(model); continue end
			local humanoid = actor.humanoid
			local state = humanoid and humanoid:GetState()
			local healthy = not humanoid or humanoid.Health > 0
			local isWalkingState = state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics
			local grounded = humanoid and humanoid.FloorMaterial ~= Enum.Material.Air and isWalkingState
			local material = humanoid and humanoid.FloorMaterial.Name or "Concrete"
			local commanded = humanoid and humanoid.MoveDirection.Magnitude > 0.1 and isWalkingState
			if actor.kind == "monster" then
				raycast.FilterDescendantsInstances = { model, emitters }
				local hit = Workspace:Raycast(actor.root.Position, Vector3.new(0, -8, 0), raycast)
				grounded = hit ~= nil and (not humanoid or (isWalkingState and humanoid.FloorMaterial ~= Enum.Material.Air))
				material = if hit then hit.Material.Name else "Concrete"
				local creatureState = model:GetAttribute("BastiaoState")
				commanded = creatureState == "roam" or creatureState == "patrol" or creatureState == "chase" or creatureState == "search" or creatureState == "attack"
			end
			local near = actor.isLocal or (listener and (actor.root.Position - listener.Position).Magnitude < 140)
			local keys = if actor.kind == "monster" or ownsSteps then stepKeys(actor.kind, Timing.surface(material)) else {}
			-- monstro com marcadores: os passos já saem no pé (acima); o ritmo por distância só
			-- fica de reserva para um servidor antigo sem marcadores.
			if actor.kind == "monster" and type(model:GetAttribute("BastiaoMarkerSerial")) == "number" then keys = {} end
			if #keys == 0 and actor.kind == "soldier" and ownsSteps then keys = stepKeys("soldier", "concrete") end
			local replace = healthy and #keys > 0
			suppressDefault(actor, "Running", replace)
			local position = actor.root.Position
			local step = Timing.step(actor.step, {
				x = position.X, z = position.Z, dt = sampleDt, alive = healthy,
				grounded = grounded == true, walking = commanded == true and near == true,
			})
			if step and #keys > 0 then
				actor.index = actor.index % #keys + 1
				play(keys[actor.index], actor.root, {
					actor = model, gain = step.gain, offset = Vector3.new(0, -2.5, 0),
				})
			end
			if actor.kind == "monster" then
				local activeBreath = actor.breath and records[actor.breath]
				if not healthy or not near or not Timing.creatureAudible(model:GetAttribute("BastiaoState")) then
					if activeBreath then cleanup(actor.breath) end
				elseif loaded.monster_breath and now >= actor.nextBreath and not activeBreath then
					actor.breath = play("monster_breath", actor.root, { actor = model, persistent = true, gain = 0.6 })
					actor.nextBreath = now + entries.monster_breath.duration + random:NextNumber(2.5, 4)
				end
			end
		end
	end))

	if op.aoPassosMudar then op.aoPassosMudar(false) end
	local preloadTask = task.spawn(function()
		local byId, ids = {}, {}
		for key, entry in entries do
			if not byId[entry.id] then byId[entry.id] = {}; table.insert(ids, entry.id) end
			table.insert(byId[entry.id], key)
		end
		table.sort(ids)
		for offset = 1, #ids, 8 do
			if not alive then return end
			local probes = {}
			for i = offset, math.min(offset + 7, #ids) do
				local probe = Instance.new("Sound")
				probe.Name, probe.SoundId = "Preload", "rbxassetid://" .. tostring(ids[i])
				probe.Volume = 0
				probe.Parent = sounds
				table.insert(probes, probe)
			end
			local ok, reason = pcall(function() ContentProvider:PreloadAsync(probes) end)
			if not ok and alive then warnOnce("preload", "pré-carregamento falhou: " .. tostring(reason)) end
			for i, probe in probes do
				if alive then
					for _, key in byId[ids[offset + i - 1]] do
						local entry = entries[key]
						if regionReady(probe, entry) then
							loaded[key] = true
						else
							warnOnce("load_" .. key, "não carregou/sem permissão/segmento inválido: " .. key)
						end
					end
				end
				probe:Destroy()
			end
		end
		if alive then
			updateOwnership()
		end
	end)
	function api.destroy()
		if not alive then return end
		alive = false
		pcall(task.cancel, preloadTask)
		for _, connection in connections do connection:Disconnect() end
		for _, connection in playerConnections do connection:Disconnect() end
		local models = {}
		for model in actors do table.insert(models, model) end
		for _, model in models do removeActor(model) end
		for record in records do cleanup(record) end
		sounds:Destroy()
		emitters:Destroy()
		if ownsSteps then ownsSteps = false; if op.aoPassosMudar then op.aoPassosMudar(false) end end
	end
	return api
end

return Foley
