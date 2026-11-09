--!strict
-- Planejamento: transforma o resultado do Parser em um plano executável.
--   * mescla parâmetros do conceito com os modificadores
--   * expande combinações prontas (composite) e "chuva de ..."
--   * aplica regras de interação (rivais, guarda, montaria, caça)
--   * limita quantidades e calcula o rótulo exibido
--   * escolhe um acontecimento surpresa determinístico para palavras desconhecidas
-- Função pura: mesma entrada -> mesmo plano (testável fora do Roblox).

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Parser = require(script.Parent.Parser)
local Hash = require(script.Parent.Util.Hash)

local Planner = {}

export type EventSpec = {
	concept: any,
	handler: string,
	mods: { string },
	params: { [string]: any },
	count: number,
	requested: number,
	rain: boolean,
	heavy: boolean,
	payload: any?,
	label: string,
}

export type Link = { type: string, a: number, b: number }

export type Plan = {
	input: string,
	normalized: string,
	events: { EventSpec },
	links: { Link },
	location: any?,
	guardSelf: boolean,
	surprise: boolean,
	label: string,
	notes: { string },
	unknown: { string },
	corrections: { any },
	secrets: { string },
}

-- Rótulo em português com concordância simples de gênero
function Planner.labelFor(def: any, mods: { any }, payload: any?): string
	local parts = { def.label }
	for _, m in mods do
		local lab = if def.gender == "f" and m.labelF then m.labelF else m.label
		table.insert(parts, lab)
	end
	local s = table.concat(parts, " ")
	if payload then
		s ..= " de " .. payload.label
	end
	return s
end

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = deepCopy(v)
	end
	return out
end

-- Mescla os patches dos modificadores nos parâmetros do conceito
function Planner.applyMods(def: any, mods: { any }): { [string]: any }
	local p = deepCopy(def.params)
	p.scale = p.scale or 1
	p.hpMul = 1
	p.speedMul = 1
	for _, m in mods do
		for key, value in m.patch do
			if key == "scale" then
				p.scale *= value
			elseif key == "hp" then
				p.hpMul *= value
			elseif key == "speed" then
				p.speedMul *= value
			elseif key == "element" then
				p.element = value
				p.elementMod = true -- elemento pedido pelo jogador (tinge o modelo)
			else
				p[key] = value
			end
		end
	end
	p.scale = math.clamp(p.scale, Config.Limits.MinScale, Config.Limits.MaxScale)
	return p
end

local function selectorMatches(sel: any, def: any): boolean
	if sel.category then
		local ok = false
		if type(sel.category) == "table" then
			for _, c in sel.category do
				if c == def.category then
					ok = true
				end
			end
		else
			ok = sel.category == def.category
		end
		if not ok then
			return false
		end
	end
	if sel.tag and not def.tagSet[sel.tag] then
		return false
	end
	if sel.notTag and def.tagSet[sel.notTag] then
		return false
	end
	return true
end

-- Encontra a regra de interação para (A rel B); devolve link já orientado
function Planner.interaction(rel: string, a: any, b: any): (string?, boolean)
	for _, rule in Catalog.Interactions do
		if rule.rel == rel then
			if selectorMatches(rule.a, a) and selectorMatches(rule.b, b) then
				return rule.link, false
			end
			if selectorMatches(rule.a, b) and selectorMatches(rule.b, a) then
				return rule.link, true
			end
		end
	end
	return nil, false
end

-- Dicas por terminação para palavras desconhecidas ("megassauro", "turbobot")
local SUFFIX_HINTS = {
	{ "saurus", { "dinosaur", "raptor", "triceratops", "stegosaurus", "brachiosaurus" } },
	{ "sauro", { "dinosaur", "raptor", "triceratops", "stegosaurus", "brachiosaurus" } },
	{ "dactilo", { "pterodactyl" } },
	{ "zilla", { "kaiju" } },
	{ "tron", { "robot", "mech" } },
	{ "bot", { "robot", "drone" } },
	{ "nado", { "tornado" } },
	{ "monstro", { "troll", "cyclops", "kaiju", "slime" } },
	{ "mon", { "dragon", "slime", "kaiju", "unicorn" } },
	{ "ita", { "crystal" } },
	{ "ite", { "crystal" } },
	{ "landia", { "city" } },
	{ "polis", { "city" } },
	{ "burgo", { "castle" } },
	{ "berg", { "castle" } },
}

local SURPRISE_CATEGORIES = {
	creature = 4,
	disaster = 3,
	object = 2,
	food = 2,
	vehicle = 1.5,
	building = 1.2,
	weather = 1,
	magic = 1,
	nature = 1,
}

local surprisePool: { any } = {}
for _, def in Catalog.Concepts do
	local w = SURPRISE_CATEGORIES[def.category]
	if w and def.handler ~= "composite" and not def.tagSet.utility then
		table.insert(surprisePool, def)
	end
end
table.sort(surprisePool, function(a, b)
	return a.id < b.id
end)

local ELEMENT_MODS = { "fire", "ice", "electric", "poison", "shadow", "light", "rainbow", "gold", "giant", "small", "crystal", "neon" }

function Planner.surprise(normalized: string): (any, { any })
	local h = Hash.str(normalized)
	-- terminações conhecidas primeiro
	for word in string.gmatch(normalized, "%a+") do
		for _, hint in SUFFIX_HINTS do
			local suffix = hint[1]
			if #word > #suffix + 1 and string.sub(word, -#suffix) == suffix then
				local list = hint[2]
				return Catalog.ById[list[(h % #list) + 1]], {}
			end
		end
	end
	local total = 0
	for _, def in surprisePool do
		total += SURPRISE_CATEGORIES[def.category]
	end
	local roll = (h % 100000) / 100000 * total
	local chosen = surprisePool[#surprisePool]
	for _, def in surprisePool do
		roll -= SURPRISE_CATEGORIES[def.category]
		if roll < 0 then
			chosen = def
			break
		end
	end
	local mods = {}
	local h2 = Hash.str(normalized .. "#mod")
	if h2 % 100 < 45 then
		local m = Catalog.ModifierById[ELEMENT_MODS[(h2 % #ELEMENT_MODS) + 1]]
		if m and chosen.axes[m.axis] then
			table.insert(mods, m)
		end
	end
	return chosen, mods
end

local function makeEvent(def: any, mods: { any }, requested: number, rain: boolean, heavy: boolean, payload: any?, notes: { string }): EventSpec
	local params = Planner.applyMods(def, mods)
	local limit = def.maxCount or 1
	if def.handler == "npc" then
		limit = math.min(limit, Config.Limits.NpcPerEvent)
	end
	if rain then
		limit = math.max(limit, 12)
	end
	local count = math.clamp(math.floor(requested), 1, limit)
	if requested > count then
		table.insert(notes, string.format("%s: %d de %d (limite de desempenho)", def.label, count, math.floor(math.min(requested, 1e9))))
	end
	local modIds = {}
	for _, m in mods do
		table.insert(modIds, m.id)
	end
	local label = Planner.labelFor(def, mods, payload)
	if rain then
		label = "Chuva de " .. label
	elseif count > 1 then
		label = string.format("%d× %s", count, label)
	end
	if payload then
		params.payload = payload.id
	end
	return {
		concept = def,
		handler = if rain then "rain" else def.handler,
		mods = modIds,
		params = params,
		count = count,
		requested = requested,
		rain = rain,
		heavy = heavy,
		payload = payload,
		label = label,
	}
end

function Planner.plan(raw: string): Plan
	local parsed = Parser.parse(raw)
	local plan: Plan = {
		input = raw,
		normalized = parsed.normalized,
		events = {},
		links = {},
		location = parsed.location,
		guardSelf = parsed.guardSelf,
		surprise = false,
		label = "",
		notes = {},
		unknown = parsed.unknown,
		corrections = parsed.corrections,
		secrets = {},
	}

	-- índice do evento "principal" de cada grupo (para vínculos)
	local groupEvent: { [number]: number } = {}
	local pendingRel: { { gi: number, rel: string } } = {}

	for gi, g in parsed.groups do
		local head = g.head
		local mods = g.mods
		local rain = g.rain == true
		if head and rain and head.params.rainAs then
			head = Catalog.ById[head.params.rainAs]
		end
		if head and rain and (head.category == "weather" or head.category == "magic" or head.category == "power" or head.category == "tool") then
			rain = false -- "chuva de magia" não faz sentido físico: executa o conceito
		end
		if head and rain and head.category == "disaster" then
			rain = false
			if head.id == "fire" then
				head = Catalog.ById.meteor_shower
			elseif head.id == "ice_burst" or head.id == "blizzard" then
				head = Catalog.ById.rockfall
				table.insert(mods, Catalog.ModifierById.ice)
			elseif head.id == "meteor" then
				head = Catalog.ById.meteor_shower
			end
		end
		if head then
			if g.ignored and #g.ignored > 0 then
				local names = {}
				for _, m in g.ignored do
					table.insert(names, m.label)
				end
				table.insert(plan.notes, "Ignorado: " .. table.concat(names, ", "))
			end
			if head.handler == "composite" then
				local base = #plan.events
				for _, part in head.params.compose do
					local def = Catalog.ById[part.id]
					local accepted = {}
					for _, m in mods do
						if def.axes[m.axis] then
							table.insert(accepted, m)
						end
					end
					table.insert(plan.events, makeEvent(def, accepted, part.count or 1, false, false, nil, plan.notes))
				end
				for _, l in head.params.links or {} do
					local link = table.clone(l)
					if link.a then
						link.a += base
					end
					if link.b then
						link.b += base
					end
					if link.guard then
						link.a = link.guard + base
						link.b = link.target + base
					end
					table.insert(plan.links, { type = link.type, a = link.a, b = link.b })
				end
				groupEvent[gi] = base + 1
			else
				table.insert(plan.events, makeEvent(head, mods, g.count or 1, rain, g.heavy == true, g.payload, plan.notes))
				groupEvent[gi] = #plan.events
			end
			if g.relToPrev then
				table.insert(pendingRel, { gi = gi, rel = g.relToPrev })
			end
		end
	end

	-- vínculos entre grupos consecutivos
	for _, pr in pendingRel do
		local bIdx = groupEvent[pr.gi]
		local aIdx: number? = nil
		for back = pr.gi - 1, 1, -1 do
			if groupEvent[back] then
				aIdx = groupEvent[back]
				break
			end
		end
		if aIdx and bIdx then
			local a = plan.events[aIdx].concept
			local b = plan.events[bIdx].concept
			local link, swapped = Planner.interaction(pr.rel, a, b)
			if link then
				if swapped then
					table.insert(plan.links, { type = link, a = bIdx, b = aIdx })
				else
					table.insert(plan.links, { type = link, a = aIdx, b = bIdx })
				end
			end
		end
	end

	-- "dragão me protegendo": criaturas viram guarda-costas do jogador
	if plan.guardSelf then
		for idx, ev in plan.events do
			if ev.concept.category == "creature" then
				ev.params.faction = "pet"
				table.insert(plan.links, { type = "bodyguard", a = idx, b = 0 })
			end
		end
	end

	-- só uma região ("praia", "na arena"): leva o jogador até lá
	if #plan.events == 0 and plan.location then
		table.insert(plan.events, makeEvent(Catalog.ById.teleport, {}, 1, false, false, nil, plan.notes))
		plan.events[1].params.region = plan.location.id
		plan.events[1].label = "Viagem: " .. plan.location.label
	end

	-- nada reconhecido: surpresa determinística
	if #plan.events == 0 then
		local leftoverMods = {}
		for _, g in parsed.groups do
			for _, m in g.mods do
				table.insert(leftoverMods, m)
			end
		end
		local def, mods = Planner.surprise(if plan.normalized ~= "" then plan.normalized else "?")
		for _, m in leftoverMods do
			if def.axes[m.axis] then
				local dup = false
				for _, existing in mods do
					if existing.axis == m.axis then
						dup = true
					end
				end
				if not dup then
					table.insert(mods, m)
				end
			end
		end
		table.insert(plan.events, makeEvent(def, mods, 1, false, false, nil, plan.notes))
		plan.surprise = true
	end

	local labels = {}
	for _, ev in plan.events do
		table.insert(labels, ev.label)
	end
	plan.label = table.concat(labels, " + ")
	if plan.surprise then
		plan.label = "Surpresa: " .. plan.label
	end
	if plan.location and not (#plan.events == 1 and plan.events[1].concept.id == "teleport") then
		plan.label ..= " (" .. plan.location.label .. ")"
	end
	plan.secrets = Planner.matchSecrets(plan)
	return plan
end

-- Combinações secretas presentes no plano
function Planner.matchSecrets(plan: Plan): { string }
	local found = {}
	local present: { [string]: number } = {}
	for idx, ev in plan.events do
		present[ev.concept.id] = idx
	end
	for _, secret in Catalog.Secrets do
		local m = secret.match
		local ok = true
		if m.concept then
			local idx = present[m.concept]
			if not idx then
				ok = false
			else
				local ev = plan.events[idx]
				for _, mid in m.mods or {} do
					if not table.find(ev.mods, mid) then
						ok = false
					end
				end
				if m.payload and (not ev.payload or ev.payload.id ~= m.payload) then
					ok = false
				end
				if m.rain and not ev.rain then
					ok = false
				end
				if m.minRequested and ev.requested < m.minRequested then
					ok = false
				end
			end
		end
		if ok and m.concepts then
			for _, cid in m.concepts do
				if not present[cid] then
					ok = false
				end
			end
			if ok and m.link then
				local a, b = present[m.concepts[1]], present[m.concepts[2]]
				local linked = false
				for _, l in plan.links do
					if l.type == m.link and ((l.a == a and l.b == b) or (l.a == b and l.b == a)) then
						linked = true
					end
				end
				ok = linked
			end
		end
		if ok then
			table.insert(found, secret.id)
		end
	end
	return found
end

return Planner
