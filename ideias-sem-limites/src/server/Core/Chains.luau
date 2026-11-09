--!strict
-- Cadeias de ação: "arma que atira cachorro e o cachorro caga elefante que o
-- elefante explode". Cada elo é um "nó" (EventSpec) criado DENTRO do
-- acontecimento raiz: mesma pasta, mesmo id (não brigam entre si), mesmo dono.
-- Limites: MAX_ALIVE elos vivos e MAX_TOTAL criados por raiz, sempre pelo
-- orçamento global (Budget). Ao remover a raiz, todos os elos somem juntos.

local Budget = require(script.Parent.Budget)
local Actors = require(script.Parent.Actors)
local Combat = require(script.Parent.Combat)
local Fx = require(script.Parent.Fx)

local Chains = {}

Chains.MAX_ALIVE = 10
Chains.MAX_TOTAL = 30
Chains.MAX_PER_ACTOR = 3

export type Entry = { handle: any, record: any, folder: Folder, spawnedAt: number }
export type State = { alive: number, total: number, entries: { Entry }, running: boolean }

local function rootOf(ctx: any): any
	return ctx.chainRoot or ctx
end

function Chains.state(ctx: any): State
	local root = rootOf(ctx)
	local rec = root.record
	if not rec.chain then
		rec.chain = { alive = 0, total = 0, entries = {}, running = false }
	end
	return rec.chain
end

local function releaseEntry(st: State, e: Entry)
	local idx = table.find(st.entries, e)
	if idx then
		table.remove(st.entries, idx)
		st.alive = math.max(0, st.alive - 1)
	end
	if e.handle and e.handle.stop then
		pcall(e.handle.stop)
	end
	if e.record then
		Budget.release(e.record.cost)
		e.record.cost = {}
	end
	if e.folder and e.folder.Parent then
		e.folder:Destroy()
	end
end

-- faxina dos elos terminados (NPC morto, explosão acabou...)
local function watch(root: any, st: State)
	if st.running then
		return
	end
	st.running = true
	task.spawn(function()
		while root.record.alive ~= false and root.folder.Parent do
			task.wait(1)
			for i = #st.entries, 1, -1 do
				local e = st.entries[i]
				local finished = false
				if e and e.handle and e.handle.done then
					local ok, res = pcall(e.handle.done)
					finished = ok and res == true
				end
				if e and (finished or not e.folder.Parent) then
					releaseEntry(st, e)
				end
			end
		end
		st.running = false
	end)
end

-- remove todos os elos (chamado quando o acontecimento raiz acaba)
function Chains.cleanup(rec: any)
	local st = rec.chain
	if not st then
		return
	end
	for i = #st.entries, 1, -1 do
		releaseEntry(st, st.entries[i])
	end
end

-- Cria um nó da cadeia em `cf`. opts.ttl: segundos de vida (clones)
function Chains.spawnNode(ctx: any, node: any, cf: CFrame, opts: { ttl: number? }?): any?
	local root = rootOf(ctx)
	if root.record.alive == false or not root.folder.Parent then
		return nil
	end
	local st = Chains.state(ctx)
	if st.total >= Chains.MAX_TOTAL or st.alive >= Chains.MAX_ALIVE then
		return nil
	end
	local manager = root.manager
	local handler = manager and manager.handler(node.handler)
	if not handler then
		return nil
	end
	local count = math.clamp(node.count or 1, 1, 3)
	local spec = table.clone(node)
	spec.count = count
	if spec.handler == "npc" then
		count = math.min(count, math.max(Budget.free("npcs"), 0))
		if count < 1 then
			return nil
		end
		spec.count = count
	end
	local cost = manager.estimate(spec)
	if not Budget.fits(cost) then
		return nil
	end
	Budget.reserve(cost)
	local folder = Instance.new("Folder")
	folder.Name = "Elo_" .. tostring(node.concept and node.concept.id or "?")
	folder.Parent = root.folder
	local childRecord = { id = root.id, cost = cost, alive = true }
	local child = {
		id = root.id,
		record = childRecord,
		spec = spec,
		def = node.concept,
		params = node.params,
		count = count,
		owner = root.owner,
		origin = cf,
		folder = folder,
		rng = root.rng:fork(st.total + 11),
		manager = manager,
		element = node.params and node.params.element,
		scale = (node.params and node.params.scale) or 1,
		lifetime = root.lifetime,
		plan = root.plan,
		chainRoot = root,
	}
	local ok, handle = pcall(handler.spawn, child)
	if not ok then
		warn("[Ideias] elo da cadeia falhou: " .. tostring(handle))
		Budget.release(cost)
		folder:Destroy()
		return nil
	end
	st.total += 1
	st.alive += 1
	local entry: Entry = { handle = handle, record = childRecord, folder = folder, spawnedAt = os.clock() }
	table.insert(st.entries, entry)
	watch(root, st)
	Chains.afterSpawn(handle, child)
	if opts and opts.ttl then
		task.delay(opts.ttl, function()
			if table.find(st.entries, entry) then
				for _, npc in (handle and handle.npcs) or {} do
					if Actors.alive(npc) then
						Fx.near(npc.root.Position, 300, "poof", { p = npc.root.Position, s = npc.scale })
					end
				end
				releaseEntry(st, entry)
			end
		end)
	end
	return handle
end

-- explosão de um ator da cadeia (ou de um objeto) com dano em área
local function blast(pos: Vector3, scale: number, attacker: any?)
	local s = math.clamp(scale, 0.6, 3)
	Fx.near(pos, 500, "boom", { p = pos, s = s })
	Fx.shake(pos, 0.8 * s, 160)
	if attacker then
		Combat.areaEnemies(pos, 9 * s, 45 * s, attacker, "fire", 70)
	end
end

local function behind(npc: any): CFrame
	local back = npc.root.CFrame * CFrame.new(0, 0, (npc.radius or 2) + 3)
	return CFrame.new(back.Position)
end

local POOP_WORDS = { caga = true, cagam = true, cagando = true, cagar = true, poops = true }

-- Liga as ações da frase a um NPC recém-criado
function Chains.attachNpc(npc: any, ctx: any, actions: { any })
	local spawnActs, explode, transformTo, multiply, grow, shrink = {}, false, nil, false, false, false
	for _, a in actions do
		if a.elementOnly then
			continue
		elseif a.verb == "spawn" and a.node then
			table.insert(spawnActs, a)
		elseif a.verb == "shoot" and a.node then
			npc.launchNode = a.node
			if not table.find(npc.attacks, "launch") then
				table.insert(npc.attacks, 1, "launch")
			end
		elseif a.verb == "transform" and a.node then
			transformTo = a.node
		elseif a.verb == "explode" then
			explode = true
		elseif a.verb == "multiply" then
			multiply = true
		elseif a.verb == "grow" then
			grow = true
		elseif a.verb == "shrink" then
			shrink = true
		end
	end
	local made = 0
	-- "caga/bota/solta/cospe X": cria X atrás de tempos em tempos
	if #spawnActs > 0 then
		task.spawn(function()
			task.wait(2 + math.random() * 1.5)
			while Actors.alive(npc) and made < Chains.MAX_PER_ACTOR do
				for _, a in spawnActs do
					if not Actors.alive(npc) then
						break
					end
					local cf = behind(npc)
					local poop = POOP_WORDS[a.word or ""] == true
					Fx.near(cf.Position, 300, if poop then "poop" else "poof", { p = cf.Position, s = npc.scale })
					if Chains.spawnNode(ctx, a.node, cf) then
						made += 1
					end
				end
				task.wait(4.5)
			end
		end)
	end
	if multiply then
		task.spawn(function()
			task.wait(3)
			local copies = 0
			while Actors.alive(npc) and copies < Chains.MAX_PER_ACTOR do
				local copy = table.clone(ctx.spec)
				local acts = {}
				for _, a in actions do
					if a.verb ~= "multiply" then
						table.insert(acts, a)
					end
				end
				copy.actions = acts
				copy.count = 1
				local cf = npc.root.CFrame * CFrame.new(math.random(-6, 6), 0, math.random(-6, 6))
				Fx.near(cf.Position, 300, "poof", { p = cf.Position, s = npc.scale })
				if Chains.spawnNode(ctx, copy, CFrame.new(cf.Position)) then
					copies += 1
				end
				task.wait(5)
			end
		end)
	end
	if grow or shrink then
		task.spawn(function()
			local k = 1
			for _ = 1, 6 do
				task.wait(2)
				if not Actors.alive(npc) then
					break
				end
				k *= if grow then 1.18 else 0.85
				pcall(function()
					(npc.model :: any):ScaleTo(k)
				end)
				npc.scale = (npc.scale or 1) * (if grow then 1.18 else 0.85)
				Fx.near(npc.root.Position, 300, "power", { p = npc.root.Position })
			end
		end)
	end
	if transformTo then
		task.delay(4 + math.random(), function()
			if not Actors.alive(npc) then
				return
			end
			local cf = CFrame.new(npc.root.Position)
			Fx.near(cf.Position, 400, "poof", { p = cf.Position, s = npc.scale * 1.5 })
			Fx.near(cf.Position, 400, "spawn", { p = cf.Position, s = npc.scale, c = Color3.fromRGB(255, 220, 120) })
			Chains.spawnNode(ctx, transformTo, cf)
			npc.silentDeath = true
			npc.humanoid.Health = 0
		end)
	end
	if explode then
		local fuse = if #spawnActs > 0 or multiply then 7.5 else 2.2 + math.random() * 1.6
		task.delay(fuse, function()
			if not Actors.alive(npc) then
				return
			end
			npc.model:SetAttribute("Pavio", workspace:GetServerTimeNow())
			Fx.near(npc.root.Position, 300, "fuse", { p = npc.root.Position, d = 1.1 })
			task.wait(1.1)
			if not Actors.alive(npc) then
				return
			end
			blast(npc.root.Position, npc.scale or 1, npc)
			npc.silentDeath = true
			npc.humanoid.Health = 0
		end)
	end
end

-- Chamado depois de qualquer acontecimento (raiz ou elo) com ações
function Chains.afterSpawn(handle: any, ctx: any)
	local actions = ctx.spec and ctx.spec.actions
	if not actions or #actions == 0 or not handle then
		return
	end
	if handle.npcs and #handle.npcs > 0 then
		for _, npc in handle.npcs do
			npc.ctx = ctx
			Chains.attachNpc(npc, ctx, actions)
		end
		return
	end
	-- objetos, construções, veículos: só "explode" faz sentido aqui
	for _, a in actions do
		if a.verb == "explode" then
			task.delay(2.5 + math.random(), function()
				if not ctx.folder.Parent then
					return
				end
				local pos = handle.position or ctx.origin.Position
				Fx.near(pos, 300, "fuse", { p = pos, d = 1 })
				task.wait(1)
				if not ctx.folder.Parent then
					return
				end
				local owner = ctx.owner and Actors.playerActor(ctx.owner)
				blast(pos, ctx.scale or 1, owner)
				for _, child in ctx.folder:GetChildren() do
					if not child:IsA("Folder") then
						child:Destroy()
					end
				end
				handle.exploded = true
			end)
			break
		end
	end
end

return Chains
