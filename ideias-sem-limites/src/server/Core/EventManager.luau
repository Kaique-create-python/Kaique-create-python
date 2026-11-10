--!strict
-- Gerenciador de acontecimentos.
--   * calcula o custo de cada ideia e respeita o orçamento global
--   * recicla o acontecimento mais antigo quando o mundo está cheio
--   * cada acontecimento vive numa pasta própria em Workspace.IdeiasEventos:
--     remover a pasta remove tudo (nada fica esquecido no Workspace)
--   * tempo de vida controlado + faxina periódica
-- Handlers ficam em ServerScriptService.IdeiasServer.Handlers e se registram
-- pelo nome (novos tipos de acontecimento não exigem mudanças aqui).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.IdeiasShared
local Config = require(Shared.Config)
local Rng = require(Shared.Util.Rng)
local Budget = require(script.Parent.Budget)
local Placement = require(script.Parent.Placement)

local EventManager = {}

export type Handle = {
	npcs: { any }?,
	anchor: BasePart?,
	position: Vector3?,
	radius: number?,
	elements: { string }?,
	stop: (() -> ())?,
	done: (() -> boolean)?,
	seat: Seat? | VehicleSeat?,
	model: Model?,
	[string]: any,
}

export type Record = {
	id: number,
	spec: any,
	def: any,
	owner: Player?,
	ownerId: number,
	createdAt: number,
	expiresAt: number,
	folder: Folder,
	cost: { [string]: number },
	handle: Handle?,
	label: string,
	alive: boolean,
	origin: CFrame,
}

local handlers: { [string]: any } = {}
local active: { Record } = {}
local nextId = 0
local root: Folder
local listeners = { spawned = {} :: { (Record) -> () }, removed = {} :: { (Record) -> () } }
local stats = { spawned = 0, removed = 0, recycled = 0, failed = 0, rejected = 0 }

EventManager.stats = stats

-- custos padrão por handler (os handlers podem sobrescrever com estimate())
local DEFAULT_COST = {
	npc = function(spec)
		return { events = 1, npcs = spec.count, effects = spec.count, parts = 30 * spec.count }
	end,
	vehicle = function(spec)
		return { events = 1, dynamic = 6 * spec.count, parts = 40 * spec.count, effects = 1 }
	end,
	building = function(spec)
		return { events = 1, parts = 160 * spec.count, effects = 2 }
	end,
	prop = function(spec)
		local physics = spec.params.physics and spec.count or 0
		return { events = 1, parts = 14 * spec.count, dynamic = physics, effects = 1 }
	end,
	disaster = function(_spec)
		return { events = 1, dynamic = 20, effects = 8, parts = 30 }
	end,
	rain = function(spec)
		return { events = 1, dynamic = if spec.heavy then 70 else 45, effects = 2 }
	end,
	world = function(_spec)
		return { events = 1, effects = 3, parts = 20 }
	end,
	power = function(_spec)
		return { events = 1, effects = 2 }
	end,
	tool = function(_spec)
		return { events = 1, parts = 8 }
	end,
}

function EventManager.registerHandler(name: string, handler: any)
	handlers[name] = handler
end

function EventManager.handler(name: string): any
	return handlers[name]
end

function EventManager.init()
	root = Workspace:FindFirstChild("IdeiasEventos") :: Folder
	if not root then
		root = Instance.new("Folder")
		root.Name = "IdeiasEventos"
		root.Parent = Workspace
	end
	local folder = script.Parent.Parent:FindFirstChild("Handlers")
	if folder then
		for _, mod in folder:GetChildren() do
			if mod:IsA("ModuleScript") then
				local ok, h = pcall(require, mod)
				if ok and type(h) == "table" and h.name then
					EventManager.registerHandler(h.name, h)
				else
					warn("[Ideias] handler inválido " .. mod.Name .. ": " .. tostring(h))
				end
			end
		end
	end
	-- faxina periódica
	task.spawn(function()
		while true do
			task.wait(1)
			EventManager.sweep()
		end
	end)
end

function EventManager.onSpawned(fn: (Record) -> ())
	table.insert(listeners.spawned, fn)
end

function EventManager.onRemoved(fn: (Record) -> ())
	table.insert(listeners.removed, fn)
end

function EventManager.active(): { Record }
	return active
end

function EventManager.estimate(spec: any): { [string]: number }
	local h = handlers[spec.handler]
	if h and h.estimate then
		return h.estimate(spec)
	end
	local f = DEFAULT_COST[spec.handler]
	return if f then f(spec) else { events = 1 }
end

function EventManager.remove(rec: Record, reason: string?)
	if not rec.alive then
		return
	end
	rec.alive = false
	local idx = table.find(active, rec)
	if idx then
		table.remove(active, idx)
	end
	if (rec :: any).chain then
		local Chains = require(script.Parent.Chains)
		pcall(Chains.cleanup, rec)
	end
	if rec.handle and rec.handle.stop then
		local ok, err = pcall(rec.handle.stop)
		if not ok then
			warn("[Ideias] erro ao encerrar " .. rec.label .. ": " .. tostring(err))
		end
	end
	if rec.folder then
		rec.folder:Destroy()
	end
	Budget.release(rec.cost)
	stats.removed += 1
	if reason == "recycled" then
		stats.recycled += 1
	end
	for _, fn in listeners.removed do
		task.spawn(fn, rec)
	end
end

function EventManager.removeOwnedBy(player: Player): number
	local n = 0
	for i = #active, 1, -1 do
		local rec = active[i]
		if rec and rec.owner == player then
			EventManager.remove(rec, "owner")
			n += 1
		end
	end
	return n
end

function EventManager.clearAll()
	for i = #active, 1, -1 do
		EventManager.remove(active[i], "clear")
	end
end

function EventManager.sweep()
	local now = os.clock()
	for i = #active, 1, -1 do
		local rec = active[i]
		if rec then
			local expired = now >= rec.expiresAt
			local finished = false
			if rec.handle and rec.handle.done then
				local ok, res = pcall(rec.handle.done)
				finished = ok and res == true
			end
			if expired or finished or not rec.folder.Parent then
				EventManager.remove(rec, if expired then "expired" else "finished")
			end
		end
	end
end

-- tenta abrir espaço removendo acontecimentos antigos (primeiro do mesmo dono)
local function makeRoom(cost: { [string]: number }, owner: Player?): boolean
	local fits = Budget.fits(cost)
	local attempts = 0
	while not fits and attempts < 5 do
		attempts += 1
		local victim: Record? = nil
		local now = os.clock()
		for _, rec in active do
			if now - rec.createdAt >= Config.Budget.recycleMinAge then
				if owner and rec.owner == owner then
					victim = rec
					break
				end
				if not victim then
					victim = rec
				end
			end
		end
		if not victim then
			return false
		end
		EventManager.remove(victim, "recycled")
		fits = Budget.fits(cost)
	end
	return fits
end

local function ownerCount(owner: Player?): { Record }
	local list = {}
	if owner then
		for _, rec in active do
			if rec.owner == owner then
				table.insert(list, rec)
			end
		end
	end
	return list
end

-- origem de cada acontecimento do plano
local function originFor(plan: any, spec: any, owner: Player?, index: number, total: number, rng: Rng.Rng): CFrame
	local cat = spec.concept.category
	local dist = Config.Limits.SpawnDistance
	if cat == "building" then
		dist = 34 * math.max(1, spec.params.scale or 1)
	elseif cat == "vehicle" then
		dist = 22
	elseif spec.concept.handler == "npc" then
		dist = 16 + 6 * math.max(1, spec.params.scale or 1)
	end
	if plan.location then
		local cf = Placement.region(plan.location.id, rng)
		return cf + Vector3.new((index - 1) * 20, 0, 0)
	end
	return Placement.forPlayer(owner, math.min(dist, 90), index, total)
end

export type ExecResult = { ok: boolean, records: { Record }, notes: { string }, reason: string? }

function EventManager.executePlan(plan: any, owner: Player?): ExecResult
	local result: ExecResult = { ok = false, records = {}, notes = {} }
	local rng = Rng.new(math.floor(os.clock() * 1000) % 2147483647 + (owner and owner.UserId or 0))
	local total = #plan.events
	local byIndex: { [number]: Record } = {}

	for index, spec in plan.events do
		local handler = handlers[spec.handler]
		if not handler then
			table.insert(result.notes, "Sem executor para " .. spec.label)
			stats.failed += 1
			continue
		end
		-- reduz quantidade de NPCs ao que cabe
		if spec.handler == "npc" then
			local free = Budget.free("npcs")
			if spec.count > free then
				if free < 1 then
					-- tenta reciclar antes de desistir
					makeRoom({ npcs = 1, events = 1 }, owner)
					free = Budget.free("npcs")
				end
				if free >= 1 and spec.count > free then
					table.insert(result.notes, string.format("%s: %d (mundo quase cheio)", spec.concept.label, free))
					spec.count = free
				end
			end
		end
		local cost = EventManager.estimate(spec)
		-- limite por jogador: recicla as ideias antigas do próprio jogador
		local mine = ownerCount(owner)
		while #mine >= Config.Budget.perPlayer do
			EventManager.remove(mine[1], "recycled")
			table.remove(mine, 1)
		end
		if not makeRoom(cost, owner) then
			stats.rejected += 1
			table.insert(result.notes, "Mundo cheio: " .. spec.label .. " não coube agora")
			result.reason = "full"
			continue
		end

		nextId += 1
		local folder = Instance.new("Folder")
		folder.Name = string.format("Ev%d_%s", nextId, spec.concept.id)
		folder:SetAttribute("Conceito", spec.concept.id)
		folder:SetAttribute("Rotulo", spec.label)
		folder:SetAttribute("Dono", owner and owner.UserId or 0)
		folder.Parent = root

		local lifetime = math.min(spec.concept.lifetime or Config.Limits.DefaultLifetime, Config.Limits.MaxLifetime)
		local origin = originFor(plan, spec, owner, index, total, rng)
		local rec: Record = {
			id = nextId,
			spec = spec,
			def = spec.concept,
			owner = owner,
			ownerId = owner and owner.UserId or 0,
			createdAt = os.clock(),
			expiresAt = os.clock() + lifetime,
			folder = folder,
			cost = cost,
			handle = nil,
			label = spec.label,
			alive = true,
			origin = origin,
		}
		Budget.reserve(cost)
		local ctx = {
			id = rec.id,
			record = rec,
			spec = spec,
			def = spec.concept,
			params = spec.params,
			count = spec.count,
			owner = owner,
			origin = origin,
			folder = folder,
			rng = rng:fork(index),
			manager = EventManager,
			element = spec.params.element,
			scale = spec.params.scale or 1,
			lifetime = lifetime,
			plan = plan,
		}
		local ok, handleOrErr = pcall(handler.spawn, ctx)
		if not ok then
			warn("[Ideias] falha ao criar " .. spec.label .. ": " .. tostring(handleOrErr))
			folder:Destroy()
			Budget.release(cost)
			stats.failed += 1
			table.insert(result.notes, "Falhou: " .. spec.label)
			continue
		end
		rec.handle = handleOrErr
		if spec.actions and #spec.actions > 0 then
			local Chains = require(script.Parent.Chains)
			local okC, errC = pcall(Chains.afterSpawn, handleOrErr, ctx)
			if not okC then
				warn("[Ideias] cadeia falhou: " .. tostring(errC))
			end
		end
		table.insert(active, rec)
		byIndex[index] = rec
		table.insert(result.records, rec)
		stats.spawned += 1
		for _, fn in listeners.spawned do
			task.spawn(fn, rec)
		end
	end

	-- cena cinematográfica para a ideia mais "épica" do pedido (só para quem criou)
	if owner then
		local Fx = require(script.Parent.Fx)
		for _, rec in result.records do
			local kind = EventManager.cutsceneKind(rec)
			if kind then
				local h = rec.handle
				local npc = h and h.npcs and h.npcs[1]
				local pos = if npc and npc.root then npc.root.Position else (h and h.position) or rec.origin.Position
				local height = if npc then npc.height or 8 else 30
				Fx.to(owner, "cutscene", { p = pos, h = height, t = rec.label, k = kind, evil = rec.def.tagSet.evil == true })
				break
			end
		end
	end

	-- vínculos entre as ideias (rivais, guarda, montaria...)
	local Links = require(script.Parent.Links)
	for _, link in plan.links or {} do
		local a = byIndex[link.a]
		local b = if link.b and link.b > 0 then byIndex[link.b] else nil
		if a then
			local ok, err = pcall(Links.apply, link.type, a, b, owner)
			if not ok then
				warn("[Ideias] vínculo " .. link.type .. " falhou: " .. tostring(err))
			end
		end
	end

	result.ok = #result.records > 0
	return result
end

local BIG_DISASTERS = { black_hole = true, nuke = true, meteor_shower = true, meteor = true, end_of_world = true, volcano_eruption = true, tsunami = true, earthquake = true, tornado = true }

-- "monster" (criatura grande/chefe/sagrada) | "disaster" | nil
function EventManager.cutsceneKind(rec: any): string?
	local def = rec.def
	local p = rec.spec.params
	if def.handler == "npc" then
		local size = (p.size or 1) * (p.scale or 1)
		local t = def.tagSet
		if size >= 1.5 or t.boss or t.giant or (t.evil and t.monster and (p.hp or 0) >= 400) or def.sacred or p.boss then
			return "monster"
		end
	elseif BIG_DISASTERS[def.id] or (def.id == "explosion" and (p.scale or 1) >= 2) then
		return "disaster"
	end
	return nil
end

function EventManager.capacity(): { [string]: any }
	local used = Budget.used()
	return {
		events = #active,
		maxEvents = Config.Budget.events,
		npcs = used.npcs,
		maxNpcs = Config.Budget.npcs,
		load = Budget.load(),
	}
end

-- prolonga a vida (ex.: construção protegida por um dragão)
function EventManager.extend(rec: Record, seconds: number)
	rec.expiresAt = math.max(rec.expiresAt, os.clock() + seconds)
end

return EventManager
