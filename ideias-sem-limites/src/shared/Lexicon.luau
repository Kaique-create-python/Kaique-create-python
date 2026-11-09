--!strict
-- Índice de vocabulário construído a partir do catálogo.
-- Cada frase normalizada aponta para uma "entrada" com tudo que ela pode ser:
-- conceito, modificador, relação, quantificador, região, número...
-- A mesma frase pode ter vários papéis (ex.: "fogo" = conceito e modificador);
-- o Parser decide pelo contexto.

local Catalog = require(script.Parent.Catalog)
local Normalizer = require(script.Parent.Text.Normalizer)
local Fuzzy = require(script.Parent.Text.Fuzzy)
local Inflect = require(script.Parent.Text.Inflect)

export type Entry = {
	phrase: string,
	concept: any?,
	modifier: any?,
	relation: string?,
	quantifier: any?,
	region: any?,
	intensifier: boolean?,
	self: boolean?,
	stop: boolean?,
	verb: string?,
}

local Lexicon = {}

local index: { [string]: Entry } = {}
local vocabulary: { [string]: boolean } = {} -- palavras isoladas que existem em alguma frase
local maxPhraseWords = 1
local collisions: { string } = {}

local function entryFor(phrase: string): Entry
	local e = index[phrase]
	if not e then
		e = { phrase = phrase }
		index[phrase] = e
		local words = 0
		for w in string.gmatch(phrase, "%S+") do
			vocabulary[w] = true
			words += 1
		end
		if words > maxPhraseWords then
			maxPhraseWords = words
		end
	end
	return e
end

local function addRole(raw: string, role: string, value: any, owner: string)
	local phrase = Normalizer.normalize(raw)
	if phrase == "" then
		return
	end
	local e = entryFor(phrase)
	local current = (e :: any)[role]
	if current ~= nil and current ~= value then
		-- mesma frase com dois significados do mesmo tipo: registrar (teste falha)
		local currentId = if type(current) == "table" then (current.id or "?") else tostring(current)
		local newId = if type(value) == "table" then (value.id or "?") else tostring(value)
		table.insert(collisions, string.format("'%s' (%s): %s x %s [%s]", phrase, role, currentId, newId, owner))
		return
	end;
	(e :: any)[role] = value
end

-- Monta o índice (executado uma vez ao carregar o módulo)
do
	local G = Catalog.Grammar
	for _, def in Catalog.Concepts do
		for _, alias in def.aliases do
			addRole(alias, "concept", def, def.id)
		end
	end
	for _, mod in Catalog.Modifiers do
		for _, alias in mod.aliases do
			addRole(alias, "modifier", mod, mod.id)
		end
	end
	for rel, list in G.Relations do
		for _, phrase in list do
			addRole(phrase, "relation", rel, "relation")
		end
	end
	for _, q in G.Quantifiers do
		for _, phrase in q.phrases do
			addRole(phrase, "quantifier", q, "quantifier")
		end
	end
	for _, region in G.Regions do
		for _, alias in region.aliases do
			addRole(alias, "region", region, region.id)
		end
	end
	for _, w in G.Intensifiers do
		addRole(w, "intensifier", true, "intensifier")
	end
	for _, w in G.Self do
		addRole(w, "self", true, "self")
	end
	for _, w in G.Stopwords do
		addRole(w, "stop", true, "stop")
	end
	for kind, list in G.Verbs do
		for _, phrase in list do
			addRole(phrase, "verb", kind, "verb")
		end
	end
end

local fuzzyIndex: Fuzzy.Index
do
	local words = {}
	for w in vocabulary do
		-- só palavras de conteúdo entram na correção ortográfica
		local e = index[w]
		if e and (e.concept or e.modifier) then
			table.insert(words, w)
		elseif not e then
			table.insert(words, w)
		end
	end
	fuzzyIndex = Fuzzy.buildIndex(words)
end

function Lexicon.lookup(phrase: string): Entry?
	return index[phrase]
end

function Lexicon.maxWords(): number
	return maxPhraseWords
end

function Lexicon.isWord(word: string): boolean
	return vocabulary[word] == true
end

-- Forma canônica de uma palavra desconhecida: singular conhecido, se houver.
function Lexicon.canonical(word: string): (string, string?)
	if vocabulary[word] or index[word] then
		return word, nil
	end
	for _, cand in Inflect.singulars(word) do
		if vocabulary[cand] or index[cand] then
			return cand, "plural"
		end
	end
	return word, nil
end

-- Tenta morfologia (diminutivo/aumentativo/prefixo) e correção de digitação.
-- Retorna: palavra base, modificador extra (id) ou nil, tipo da correção
function Lexicon.rescue(word: string): (string?, string?, string?)
	for _, v in Inflect.sizeVariants(word) do
		local base = Lexicon.canonical(v.base)
		local e = index[base]
		if e and e.concept then
			return base, v.modifier, "morfologia"
		end
	end
	for _, v in Inflect.prefixVariants(word) do
		local base = Lexicon.canonical(v.base)
		local e = index[base]
		if e and e.concept then
			return base, v.modifier, "prefixo"
		end
	end
	-- palavra composta escrita junta ("dragaorobo"): procura um conceito no início
	if #word >= 7 then
		for cut = #word - 3, 4, -1 do
			local head = string.sub(word, 1, cut)
			local e = index[head]
			if e and e.concept then
				return head, nil, "composto"
			end
		end
	end
	local best, dist = Fuzzy.best(fuzzyIndex, word)
	if best and dist <= Fuzzy.tolerance(word) then
		return best, nil, "digitacao"
	end
	return nil, nil, nil
end

function Lexicon.collisions(): { string }
	return collisions
end

function Lexicon.size(): number
	local n = 0
	for _ in index do
		n += 1
	end
	return n
end

return Lexicon
