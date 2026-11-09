--!strict
-- Progressão: descobertas de conceitos, combinações secretas, conquistas,
-- missões da sessão, Faíscas (moeda ganha jogando), cosméticos e favoritos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.IdeiasShared
local Catalog = require(Shared.Catalog)
local Progression = require(Shared.Catalog.Progression)
local MapLayout = require(Shared.MapLayout)
local Config = require(Shared.Config)
local Profiles = require(script.Parent.Profiles)

local Progress = {}

local quests: { [Player]: { { id: string, progress: number, done: boolean } } } = {}
local remote: RemoteEvent? = nil

local function send(player: Player, kind: string, data: any)
	if remote then
		remote:FireClient(player, kind, data)
	end
end

local function pickQuests(player: Player)
	local pool = table.clone(Progression.Quests)
	local list = {}
	for i = 1, 3 do
		local idx = math.random(1, #pool)
		table.insert(list, { id = pool[idx].id, progress = 0, done = false })
		table.remove(pool, idx)
	end
	quests[player] = list
end

function Progress.snapshot(player: Player): any
	local p = Profiles.get(player)
	if not p then
		return nil
	end
	local discovered = {}
	for id in p.discovered do
		table.insert(discovered, id)
	end
	local secrets = {}
	for id in p.secrets do
		table.insert(secrets, id)
	end
	local achievements = {}
	for id in p.achievements do
		table.insert(achievements, id)
	end
	local owned = {}
	for id in p.owned do
		table.insert(owned, id)
	end
	return {
		discovered = discovered,
		totalConcepts = #Catalog.Concepts,
		secrets = secrets,
		totalSecrets = #Catalog.Secrets,
		achievements = achievements,
		stats = p.stats,
		favorites = p.favorites,
		sparks = p.sparks,
		owned = owned,
		equipped = p.equipped,
		quests = quests[player],
		saved = Profiles.enabled,
	}
end

local function sync(player: Player)
	send(player, "perfil", Progress.snapshot(player))
end

local function addSparks(player: Player, n: number)
	local p = Profiles.get(player)
	if p then
		p.sparks += n
		Profiles.markDirty(player)
	end
end

local function bump(player: Player, stat: string, n: number?)
	local p = Profiles.get(player)
	if not p then
		return
	end
	p.stats[stat] = (p.stats[stat] or 0) + (n or 1)
	Profiles.markDirty(player)
	for _, a in Progression.Achievements do
		if a.stat == stat and not p.achievements[a.id] and p.stats[stat] >= a.goal then
			p.achievements[a.id] = true
			p.sparks += a.reward
			send(player, "conquista", { title = a.title, desc = a.desc, reward = a.reward })
		end
	end
end

local function questBump(player: Player, stat: string, n: number?)
	local list = quests[player]
	if not list then
		return
	end
	for _, q in list do
		local def = Progression.QuestById[q.id]
		if def.stat == stat and not q.done then
			q.progress += n or 1
			if q.progress >= def.goal then
				q.done = true
				addSparks(player, def.reward)
				send(player, "missao", { title = def.title, reward = def.reward })
			end
		end
	end
end

Progress.bump = bump
Progress.questBump = questBump
Progress.addSparks = addSparks

-- chamado após cada ideia executada
function Progress.onPlan(player: Player, plan: any): { discovered: { string }, secrets: { string } }
	local p = Profiles.get(player)
	local out = { discovered = {}, secrets = {} }
	if not p then
		return out
	end
	bump(player, "created")
	if plan.surprise then
		bump(player, "surprises")
	end
	if #plan.links > 0 then
		bump(player, "combos")
	end
	for _, ev in plan.events do
		local def = ev.concept
		if not p.discovered[def.id] then
			p.discovered[def.id] = true
			table.insert(out.discovered, def.label)
			bump(player, "discovered")
			questBump(player, "q_discover")
		end
		if table.find(ev.mods, "colossal") then
			bump(player, "colossal")
		end
		if def.category == "creature" then
			questBump(player, "q_creature")
		elseif def.category == "disaster" then
			questBump(player, "q_disaster")
		elseif def.category == "food" then
			questBump(player, "q_food")
		elseif def.category == "vehicle" then
			questBump(player, "q_vehicle")
		elseif def.category == "building" then
			questBump(player, "q_building")
		end
		if ev.params.element == "ice" then
			questBump(player, "q_ice")
		elseif ev.params.element == "fire" or def.id == "fire" then
			questBump(player, "q_fire")
		end
		if def.tagSet.brazil or def.tagSet.folklore then
			questBump(player, "q_brazil")
		end
	end
	for _, l in plan.links do
		if l.type == "rivals" then
			questBump(player, "q_versus")
		end
	end
	for _, sid in plan.secrets do
		if not p.secrets[sid] then
			p.secrets[sid] = true
			for _, s in Catalog.Secrets do
				if s.id == sid then
					table.insert(out.secrets, s.title)
					p.sparks += s.reward
					send(player, "segredo", { title = s.title, hint = s.hint, reward = s.reward })
				end
			end
			bump(player, "secrets")
		end
	end
	Profiles.markDirty(player)
	task.defer(sync, player)
	return out
end

function Progress.onKill(owner: Player)
	bump(owner, "kills")
	questBump(owner, "q_kills")
end

function Progress.reward(player: Player, kind: string, amount: number)
	if kind == "eat" then
		bump(player, "eat")
	else
		addSparks(player, amount)
	end
	task.defer(sync, player)
end

-- ações vindas do cliente (sempre validadas)
function Progress.action(player: Player, action: any, arg: any)
	local p = Profiles.get(player)
	if not p or type(action) ~= "string" then
		return
	end
	if action == "favoritar" and type(arg) == "string" then
		local label = string.sub(arg, 1, 80)
		local i = table.find(p.favorites, label)
		if i then
			table.remove(p.favorites, i)
		elseif #p.favorites < Config.Data.MaxFavorites then
			-- só aceita rótulos que o próprio interpretador reconhece (sem texto livre)
			local Planner = require(Shared.Planner)
			local plan = Planner.plan(label)
			if not plan.surprise then
				table.insert(p.favorites, plan.label)
			end
		end
		Profiles.markDirty(player)
	elseif action == "comprar" and type(arg) == "string" then
		local c = Progression.CosmeticById[arg]
		if c and not p.owned[c.id] and p.sparks >= c.price then
			p.sparks -= c.price
			p.owned[c.id] = true
			p.equipped[c.kind] = c.id
			Profiles.markDirty(player)
			Progress.applyCosmetics(player)
		end
	elseif action == "equipar" and type(arg) == "string" then
		local c = Progression.CosmeticById[arg]
		if c and p.owned[c.id] then
			p.equipped[c.kind] = if p.equipped[c.kind] == c.id then nil else c.id
			Profiles.markDirty(player)
			Progress.applyCosmetics(player)
		end
	end
	sync(player)
end

function Progress.applyCosmetics(player: Player)
	local p = Profiles.get(player)
	local char = player.Character
	if not p or not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = char:FindFirstChild("Head") :: BasePart?
	if not root or not head then
		return
	end
	for _, name in { "RastroIdeias", "AuraIdeias", "TituloIdeias", "RastroA0", "RastroA1" } do
		local old = char:FindFirstChild(name, true)
		while old do
			old:Destroy()
			old = char:FindFirstChild(name, true)
		end
	end
	local trail = p.equipped.trail and Progression.CosmeticById[p.equipped.trail]
	if trail then
		local a0 = Instance.new("Attachment")
		a0.Name = "RastroA0"
		a0.Position = Vector3.new(0, 1, 0)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "RastroA1"
		a1.Position = Vector3.new(0, -1, 0)
		a1.Parent = root
		local t = Instance.new("Trail")
		t.Name = "RastroIdeias"
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Lifetime = 0.6
		t.LightEmission = 0.6
		local keys = {}
		for i, c in trail.colors do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(#trail.colors - 1, 1), Color3.fromRGB(c[1], c[2], c[3])))
		end
		t.Color = ColorSequence.new(keys)
		t.Transparency = NumberSequence.new(0.2, 1)
		t.Parent = root
	end
	local aura = p.equipped.aura and Progression.CosmeticById[p.equipped.aura]
	if aura then
		local e = Instance.new("ParticleEmitter")
		e.Name = "AuraIdeias"
		e.Texture = Config.Textures.Sparkle
		e.Rate = 8
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(1, 2)
		e.SpreadAngle = Vector2.new(180, 180)
		local c = aura.colors[1]
		e.Color = ColorSequence.new(Color3.fromRGB(c[1], c[2], c[3]))
		e.LightEmission = 0.7
		e.Parent = root
	end
	local title = p.equipped.title and Progression.CosmeticById[p.equipped.title]
	if title then
		local gui = Instance.new("BillboardGui")
		gui.Name = "TituloIdeias"
		gui.Size = UDim2.fromOffset(160, 24)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 60
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "★ " .. title.title
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(255, 225, 120)
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
		gui.Parent = head
	end
end

-- visitas às regiões (verificação barata a cada 3 s)
local function regionWatcher()
	while true do
		task.wait(3)
		for _, player in Players:GetPlayers() do
			local p = Profiles.get(player)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if p and root then
				local region = MapLayout.regionAt(root.Position)
				local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(region.center.X, 0, region.center.Z)).Magnitude
				if d < region.radius and not p.regions[region.id] then
					p.regions[region.id] = true
					bump(player, "regions")
					send(player, "regiao", { label = region.label })
				end
				if d < region.radius then
					if region.id == "volcano" then
						questBump(player, "q_visit_volcano")
					elseif region.id == "glacier" then
						questBump(player, "q_visit_glacier")
					end
				end
			end
		end
	end
end

function Progress.start(estado: RemoteEvent?)
	remote = estado
	Profiles.start()
	local function setup(player: Player)
		task.spawn(function()
			Profiles.load(player)
			pickQuests(player)
			sync(player)
			if player.Character then
				Progress.applyCosmetics(player)
			end
		end)
		player.CharacterAdded:Connect(function()
			task.wait(1)
			Progress.applyCosmetics(player)
		end)
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		quests[player] = nil
	end)
	task.spawn(regionWatcher)
end

return Progress
