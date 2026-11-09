--!strict
-- Interpretador: texto -> itens reconhecidos -> grupos (uma ideia cada) -> relações.
--
--   "dragão de gelo gigante protegendo castelo"
--     itens:  [dragão:conceito] [de:of] [gelo:conceito→mod] [gigante:mod]
--             [protegendo:guard] [castelo:conceito]
--     grupos: #1 {cabeça=dragon, mods={ice, giant}}  #2 {cabeça=castle}
--     relação: #2 guard -> #1
--
-- O texto é tratado SEMPRE como dado. Nada aqui executa código do jogador.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Normalizer = require(script.Parent.Text.Normalizer)
local Numbers = require(script.Parent.Text.Numbers)
local Lexicon = require(script.Parent.Lexicon)
local Inflect = require(script.Parent.Text.Inflect)

local Parser = {}

export type Item = {
	text: string,
	concept: any?,
	modifier: any?,
	relation: string?,
	quantifier: any?,
	region: any?,
	intensifier: boolean?,
	self: boolean?,
	stop: boolean?,
	number: number?,
	extraModifier: string?,
	unknown: boolean?,
	ofFlag: boolean?,
	plural: boolean?,
	verb: string?,
}

export type Group = {
	items: { Item },
	count: number?,
	rain: boolean?,
	heavy: boolean?,
	intensify: number,
	relToPrev: string?,
	ofPending: boolean?,
	unknown: { string },
	actions: { any },
	chainFrom: any?,
}

export type GroupSpec = {
	head: any?,
	mods: { any },
	ignored: { any },
	payload: any?,
	count: number?,
	rain: boolean?,
	heavy: boolean?,
	relToPrev: string?,
	words: { string },
	actions: { { verb: string, word: string, target: number? } }?,
	chainTarget: boolean?,
	fusion: any?,
	customName: string?,
}

export type ParseResult = {
	input: string,
	normalized: string,
	items: { Item },
	groups: { GroupSpec },
	location: any?,
	selfRef: boolean,
	guardSelf: boolean,
	unknown: { string },
	corrections: { { from: string, to: string, kind: string } },
}

-- 1) reconhecimento ---------------------------------------------------------
function Parser.match(tokens: { string }): ({ Item }, { { from: string, to: string, kind: string } })
	local canon = table.create(#tokens)
	local pluralAt: { [number]: boolean } = {}
	local corrections = {}
	for i, tok in tokens do
		local c, kind = Lexicon.canonical(tok)
		canon[i] = c
		if kind then
			table.insert(corrections, { from = tok, to = c, kind = kind })
			if kind == "plural" then
				pluralAt[i] = true
			end
		end
	end

	local items: { Item } = {}
	local i = 1
	local maxWords = Lexicon.maxWords()
	while i <= #canon do
		local matched = false
		for n = math.min(maxWords, #canon - i + 1), 1, -1 do
			local phrase = table.concat(canon, " ", i, i + n - 1)
			local e = Lexicon.lookup(phrase)
			if e then
				local item: Item = {
					text = phrase,
					concept = e.concept,
					modifier = e.modifier,
					relation = e.relation,
					quantifier = e.quantifier,
					region = e.region,
					intensifier = e.intensifier,
					self = e.self,
					stop = e.stop,
					verb = e.verb,
				}
				-- plural ("dragões", "zumbis") sem número explícito vira um pequeno grupo
				if n == 1 and e.concept then
					if pluralAt[i] then
						item.plural = true
					elseif #tokens[i] > 3 then
						for _, cand in Inflect.singulars(tokens[i]) do
							local se = Lexicon.lookup(cand)
							if se and se.concept == e.concept then
								item.plural = true
								break
							end
						end
					end
				end
				table.insert(items, item)
				i += n
				matched = true
				break
			end
		end
		if not matched then
			local tok = canon[i]
			local num = Numbers.parse(tok)
			if num then
				if Numbers.isArticle(tok) then
					table.insert(items, { text = tok, stop = true })
				else
					table.insert(items, { text = tok, number = num })
				end
			else
				local base, extraMod, kind = Lexicon.rescue(tok)
				local e = if base then Lexicon.lookup(base) else nil
				if base and e then
					table.insert(corrections, { from = tok, to = base, kind = kind or "?" })
					table.insert(items, {
						text = base,
						concept = e.concept,
						modifier = e.modifier,
						region = e.region,
						extraModifier = extraMod,
					})
				else
					table.insert(items, { text = tok, unknown = true })
				end
			end
			i += 1
		end
	end
	return items, corrections
end

-- 2) agrupamento ------------------------------------------------------------
local function newGroup(): Group
	return { items = {}, intensify = 0, unknown = {}, actions = {} }
end

local function hasContent(g: Group): boolean
	return #g.items > 0 or #g.unknown > 0
end

-- Palavras desconhecidas que parecem um nome ("verity", "joao pedro"): viram um
-- personagem com esse nome. Sequências impronunciáveis ("xyzqwe") não.
local VOWELS = { a = true, e = true, i = true, o = true, u = true }
function Parser.nameLike(words: { string }): boolean
	if #words == 0 or #words > 3 then
		return false
	end
	local total = 0
	for _, w in words do
		if not string.match(w, "^%a+$") then
			return false
		end
		local n = #w
		if n < 2 or n > 14 then
			return false
		end
		total += n + 1
		local vowels, run, maxRun = 0, 0, 0
		for i = 1, n do
			local ch = string.sub(w, i, i)
			if VOWELS[ch] or (ch == "y" and i == n) then
				vowels += 1
				run = 0
			else
				run += 1
				maxRun = math.max(maxRun, run)
			end
		end
		if vowels == 0 or maxRun > 3 or vowels / n < 0.2 then
			return false
		end
	end
	return total <= 26
end

function Parser.displayName(words: { string }): string
	local out = {}
	for _, w in words do
		table.insert(out, string.upper(string.sub(w, 1, 1)) .. string.sub(w, 2))
	end
	return table.concat(out, " ")
end

-- Duas ideias na mesma frase sem palavra de ligação podem virar um híbrido:
-- "gato tubarão", "homem tubarão", "macaco banana", "crocodilo avião".
local FUSE_WITH_CREATURE = { creature = true, food = true, object = true, nature = true, vehicle = true }
function Parser.fusable(a: any, b: any): boolean
	if a == b or a.sacred or b.sacred or a.handler == "composite" or b.handler == "composite" then
		return false
	end
	if a.noFusion or b.noFusion then
		return false
	end
	if a.category == "creature" then
		return FUSE_WITH_CREATURE[b.category] == true and b.handler ~= "world"
	end
	if b.category == "creature" then
		return FUSE_WITH_CREATURE[a.category] == true and a.handler ~= "world"
	end
	return false
end

local UPGRADE = { giant = "colossal", small = "tiny" }

local function chooseHead(conceptItems: { Item }): Item?
	-- a) conceito "puro" (não funciona como modificador)
	for _, it in conceptItems do
		if not it.concept.asModifier and not it.modifier then
			return it
		end
	end
	-- b) conceito que vira modificador, mas prefere ser cabeça
	for _, it in conceptItems do
		if not it.concept.preferModifier and not it.modifier then
			return it
		end
	end
	-- c) todos preferem ser modificador: o de eixo "trait" (zumbi, robô...) vira
	--    cabeça antes dos de posto/elemento/material ("rei zumbi" = zumbi chefe)
	local best: Item? = nil
	local bestScore = math.huge
	for _, it in conceptItems do
		local mod = it.concept.asModifier and Catalog.ModifierById[it.concept.asModifier]
		local score = if mod and mod.axis == "trait" then 1 else 2
		if score < bestScore then
			best, bestScore = it, score
		end
	end
	return best or conceptItems[1]
end

local function resolveGroup(g: Group, extraGroups: { GroupSpec }): GroupSpec
	local spec: GroupSpec = {
		head = nil,
		mods = {},
		ignored = {},
		count = g.count,
		rain = g.rain,
		heavy = g.heavy,
		relToPrev = g.relToPrev,
		words = {},
	}
	local conceptItems = {}
	for _, it in g.items do
		table.insert(spec.words, it.text)
		if it.concept then
			table.insert(conceptItems, it)
		end
	end
	local rawMods = {}
	local headItem = chooseHead(conceptItems)
	-- "verity gigante": o nome é a ideia; "gigante" vira modificador
	if headItem and headItem.modifier and #g.unknown > 0 and Parser.nameLike(g.unknown) then
		headItem = nil
	end
	if headItem then
		spec.head = headItem.concept
		if headItem.plural and not spec.count then
			spec.count = 3
		end
	end
	for _, it in g.items do
		if it ~= headItem then
			if it.concept then
				local c = it.concept
				if it.modifier then
					table.insert(rawMods, it.modifier)
				elseif c.asModifier then
					table.insert(rawMods, Catalog.ModifierById[c.asModifier])
				elseif it.ofFlag and spec.head and spec.head.params.payload and not spec.payload then
					spec.payload = c
				elseif not spec.fusion and spec.head and Parser.fusable(spec.head, c) then
					spec.fusion = c
				else
					-- conceito independente na mesma frase: vira outra ideia
					table.insert(extraGroups, {
						head = c,
						mods = {},
						ignored = {},
						relToPrev = "conjunction",
						words = { it.text },
					})
				end
			elseif it.modifier then
				table.insert(rawMods, it.modifier)
			end
		end
		if it.extraModifier then
			table.insert(rawMods, Catalog.ModifierById[it.extraModifier])
		end
	end

	-- nada reconhecido, mas há um nome ("verity"): personagem com esse nome
	if not spec.head and #g.unknown > 0 and Parser.nameLike(g.unknown) and Catalog.ById.mystery_person then
		spec.head = Catalog.ById.mystery_person
		spec.customName = Parser.displayName(g.unknown)
	end

	-- só modificadores: palavra isolada vira conceito ("gigante" -> poder de crescer)
	if not spec.head then
		for idx, m in rawMods do
			if m.standalone then
				spec.head = Catalog.ById[m.standalone]
				table.remove(rawMods, idx)
				break
			end
		end
	end

	-- aplica modificadores respeitando eixos aceitos e um por eixo
	local byAxis: { [string]: any } = {}
	for _, m in rawMods do
		if m then
			local existing = byAxis[m.axis]
			if existing then
				if existing.id == m.id and UPGRADE[m.id] then
					byAxis[m.axis] = Catalog.ModifierById[UPGRADE[m.id]] -- "gigante gigante"
				else
					table.insert(spec.ignored, m)
				end
			elseif spec.head and not spec.head.axes[m.axis] then
				table.insert(spec.ignored, m)
			else
				byAxis[m.axis] = m
			end
		end
	end
	if g.intensify > 0 and byAxis.size and UPGRADE[byAxis.size.id] then
		byAxis.size = Catalog.ModifierById[UPGRADE[byAxis.size.id]]
	end
	for _, m in byAxis do
		table.insert(spec.mods, m)
	end
	table.sort(spec.mods, function(a, b)
		local oa, ob = a.order or 99, b.order or 99
		if oa == ob then
			return a.id < b.id
		end
		return oa < ob
	end)
	return spec
end

function Parser.parse(raw: string): ParseResult
	local tokens = Normalizer.tokens(raw, Config.Request.MaxTokens)
	local items, corrections = Parser.match(tokens)
	local result: ParseResult = {
		input = raw,
		normalized = table.concat(tokens, " "),
		items = items,
		groups = {},
		location = nil,
		selfRef = false,
		guardSelf = false,
		unknown = {},
		corrections = corrections,
	}

	local groups: { Group } = {}
	local cur = newGroup()
	local locationMode = false
	local danglingGuard = false
	local refGroup: Group? = nil -- "o cachorro" já citado antes, sujeito do próximo verbo

	local function push()
		if hasContent(cur) then
			table.insert(groups, cur)
		end
		cur = newGroup()
	end

	local function nextMeaningful(from: number): Item?
		for j = from + 1, #items do
			local n = items[j]
			if not (n.stop and not n.concept and not n.modifier and not n.verb) then
				return n
			end
		end
		return nil
	end

	local function groupWith(concept: any): Group?
		for _, it in cur.items do
			if it.concept == concept then
				return cur
			end
		end
		for gi = #groups, 1, -1 do
			for _, it in groups[gi].items do
				if it.concept == concept then
					return groups[gi]
				end
			end
		end
		return nil
	end

	for idx, it in items do
		-- verbo de ação com sujeito: monta a cadeia ("arma que atira cachorro")
		if it.verb then
			local subject: Group? = refGroup or (if #cur.items > 0 then cur else nil) or groups[#groups]
			if subject and not subject.chainFrom and #subject.items == 0 then
				subject = nil
			end
			if subject then
				local kind = it.verb :: string
				if Catalog.Grammar.TransitiveVerbs[kind] then
					if hasContent(cur) then
						push()
					end
					cur.relToPrev = nil
					cur.chainFrom = { group = subject, verb = kind }
					table.insert(subject.actions, { verb = kind, word = it.text, target = cur })
				else
					table.insert(subject.actions, { verb = kind, word = it.text })
				end
				refGroup = nil
				continue
			end
		end
		-- "...e o cachorro caga...": o cachorro é o mesmo citado antes
		if it.concept and not it.verb then
			local nxt = nextMeaningful(idx)
			if nxt and nxt.verb then
				local found = groupWith(it.concept)
				if found then
					refGroup = found
					continue
				end
			end
		end
		if it.unknown then
			table.insert(result.unknown, it.text)
			table.insert(cur.unknown, it.text)
		elseif it.self then
			result.selfRef = true
			if danglingGuard then
				result.guardSelf = true
			end
		elseif it.intensifier and not it.concept and not it.modifier then
			cur.intensify += 1
		elseif it.number then
			cur.count = math.max(cur.count or 0, it.number)
		elseif it.quantifier and not it.concept then
			local q = it.quantifier
			if q.rain then
				cur.rain = true
				cur.heavy = q.heavy == true
			else
				cur.count = math.max(cur.count or 0, q.count)
			end
		elseif it.relation and not it.concept and not it.modifier then
			local rel = it.relation
			if rel == "of" then
				cur.ofPending = true
			elseif rel == "location" then
				locationMode = true
			else
				if rel == "guard" then
					danglingGuard = true
					if result.selfRef then
						result.guardSelf = true
					end
				end
				if hasContent(cur) then
					push()
					cur.relToPrev = rel
				elseif #groups > 0 and not cur.chainFrom then
					cur.relToPrev = rel
				end
			end
		elseif it.region and (locationMode or (not it.concept and not it.modifier)) then
			result.location = it.region
			locationMode = false
		elseif it.concept or it.modifier then
			if locationMode and it.concept then
				if hasContent(cur) then
					push()
				end
				cur.relToPrev = "location"
				locationMode = false
			end
			if cur.ofPending then
				it.ofFlag = true
				cur.ofPending = false
			end
			table.insert(cur.items, it)
			if it.concept then
				danglingGuard = false
			end
		end
		-- stopwords e o resto são ignorados
	end
	push()

	-- se a última relação ficou "pendurada" em "guard" sem alvo e houve "me/mim"
	if result.selfRef and danglingGuard then
		result.guardSelf = true
	end

	local specs: { GroupSpec } = {}
	local specOf: { [Group]: number } = {}
	for gi, g in groups do
		local extras: { GroupSpec } = {}
		local spec = resolveGroup(g, extras)
		if gi == 1 then
			spec.relToPrev = nil
		end
		if g.chainFrom then
			spec.chainTarget = true
			spec.relToPrev = nil
		end
		table.insert(specs, spec)
		specOf[g] = #specs
		for _, extra in extras do
			table.insert(specs, extra)
		end
		if #specs >= Config.Request.MaxGroups then
			break
		end
	end
	while #specs > Config.Request.MaxGroups do
		table.remove(specs)
	end
	-- ações: índices dos grupos-alvo (cadeias)
	for g, si in specOf do
		local spec = specs[si]
		if spec and #g.actions > 0 then
			local acts = {}
			for _, a in g.actions do
				local target = if a.target then specOf[a.target] else nil
				if a.target and (not target or not specs[target]) then
					continue -- verbo sem objeto ("arma que atira")
				end
				table.insert(acts, { verb = a.verb, word = a.word, target = target })
			end
			spec.actions = acts
		end
	end
	result.groups = specs
	return result
end

return Parser
