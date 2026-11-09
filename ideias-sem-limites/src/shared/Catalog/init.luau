--!strict
-- Catálogo de dados do jogo: reúne conceitos, modificadores, gramática, regras
-- de interação e segredos, e valida tudo na carga. Para adicionar um novo
-- acontecimento basta incluir um item em um dos arquivos de dados.

local Modifiers = require(script.Modifiers)
local Grammar = require(script.Grammar)
local Interactions = require(script.Interactions)
local Secrets = require(script.Secrets)

local Catalog = {}

Catalog.Modifiers = Modifiers
Catalog.Grammar = Grammar
Catalog.Interactions = Interactions
Catalog.Secrets = Secrets

-- Eixos de modificadores aceitos por categoria
Catalog.CategoryAxes = {
	creature = { "size", "rank", "element", "material", "trait", "speed", "faction", "flight", "behavior", "color" },
	vehicle = { "size", "element", "material", "trait", "speed", "flight", "color" },
	building = { "size", "element", "material", "trait", "flight", "color" },
	object = { "size", "element", "material", "trait", "flight", "color" },
	food = { "size", "element", "material", "flight", "color" },
	nature = { "size", "element", "material", "flight", "color" },
	disaster = { "size", "element", "speed", "color" },
	weather = { "element", "color" },
	magic = { "element", "color" },
	power = { "element", "color", "speed" },
	tool = { "size", "element", "material", "color" },
}

Catalog.CategoryInfo = {
	creature = { label = "Criaturas", icon = "🐉", order = 1 },
	disaster = { label = "Desastres", icon = "🌪️", order = 2 },
	vehicle = { label = "Veículos", icon = "🚗", order = 3 },
	building = { label = "Construções", icon = "🏰", order = 4 },
	object = { label = "Objetos", icon = "📺", order = 5 },
	food = { label = "Comidas", icon = "🍕", order = 6 },
	nature = { label = "Natureza", icon = "🌳", order = 7 },
	weather = { label = "Clima", icon = "🌈", order = 8 },
	magic = { label = "Magia", icon = "✨", order = 9 },
	power = { label = "Poderes", icon = "⚡", order = 10 },
	tool = { label = "Ferramentas", icon = "🗡️", order = 11 },
}

local HANDLERS = {
	npc = true,
	vehicle = true,
	building = true,
	prop = true,
	disaster = true,
	world = true,
	power = true,
	tool = true,
	composite = true,
}

Catalog.Concepts = {} :: { any }
Catalog.ById = {} :: { [string]: any }
Catalog.ModifierById = {} :: { [string]: any }

local sources = {
	require(script.Creatures),
	require(script.Vehicles),
	require(script.Buildings),
	require(script.Objects),
	require(script.Phenomena),
	require(script.Powers),
}

for _, list in sources do
	for _, def in list do
		table.insert(Catalog.Concepts, def)
	end
end

for _, def in Catalog.Concepts do
	Catalog.ById[def.id] = def
	def.maxCount = def.maxCount or 1
	def.lifetime = def.lifetime or 60
	def.params = def.params or {}
	def.tags = def.tags or {}
	local tagSet = {}
	for _, t in def.tags do
		tagSet[t] = true
	end
	def.tagSet = tagSet
	local axes = {}
	for _, axis in Catalog.CategoryAxes[def.category] or {} do
		axes[axis] = true
	end
	def.axes = axes
end

for _, mod in Modifiers do
	Catalog.ModifierById[mod.id] = mod
end

-- Validação estrutural: retorna lista de erros (vazia = tudo certo)
function Catalog.validate(): { string }
	local errors = {}
	local seen = {}
	for _, def in Catalog.Concepts do
		if type(def.id) ~= "string" or not string.match(def.id, "^[%l%d_]+$") then
			table.insert(errors, "id inválido: " .. tostring(def.id))
		end
		if seen[def.id] then
			table.insert(errors, "id duplicado: " .. def.id)
		end
		seen[def.id] = true
		if not Catalog.CategoryAxes[def.category] then
			table.insert(errors, def.id .. ": categoria desconhecida " .. tostring(def.category))
		end
		if not HANDLERS[def.handler] then
			table.insert(errors, def.id .. ": handler desconhecido " .. tostring(def.handler))
		end
		if type(def.label) ~= "string" or #def.label == 0 then
			table.insert(errors, def.id .. ": sem rótulo")
		end
		if type(def.aliases) ~= "table" or #def.aliases == 0 then
			table.insert(errors, def.id .. ": sem aliases")
		end
		if def.asModifier and not Catalog.ModifierById[def.asModifier] then
			table.insert(errors, def.id .. ": asModifier inexistente " .. def.asModifier)
		end
		if def.handler == "composite" then
			for _, part in def.params.compose or {} do
				if not Catalog.ById[part.id] then
					table.insert(errors, def.id .. ": compose referencia " .. tostring(part.id))
				end
			end
		end
	end
	local modSeen = {}
	for _, mod in Modifiers do
		if modSeen[mod.id] then
			table.insert(errors, "modificador duplicado: " .. mod.id)
		end
		modSeen[mod.id] = true
		if mod.standalone and not Catalog.ById[mod.standalone] then
			table.insert(errors, "modificador " .. mod.id .. ": standalone inexistente " .. mod.standalone)
		end
	end
	for _, secret in Secrets do
		local m = secret.match
		if m.concept and not Catalog.ById[m.concept] then
			table.insert(errors, "segredo " .. secret.id .. ": conceito " .. m.concept)
		end
		for _, c in m.concepts or {} do
			if not Catalog.ById[c] then
				table.insert(errors, "segredo " .. secret.id .. ": conceito " .. c)
			end
		end
		for _, mid in m.mods or {} do
			if not Catalog.ModifierById[mid] then
				table.insert(errors, "segredo " .. secret.id .. ": modificador " .. mid)
			end
		end
	end
	return errors
end

return Catalog
