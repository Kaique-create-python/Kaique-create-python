--!strict
-- Regras de interação entre duas ideias do mesmo pedido.
-- Avaliadas em ordem; a primeira que combinar (em qualquer ordem A/B) vence.
--   rel     relação escrita: versus | guard | ride | location | conjunction
--   a, b    seletores: category (string ou lista), tag, notTag
--   link    vínculo aplicado: rivals | guard | bodyguard | ride | at | hunt
-- Novas interações entram aqui, sem alterar o interpretador.

export type Selector = { category: any?, tag: string?, notTag: string? }
export type Rule = { id: string, rel: string, a: Selector, b: Selector, link: string }

local rules: { Rule } = {
	-- relações explícitas --------------------------------------------------
	{ id = "versus_creatures", rel = "versus", a = { category = "creature" }, b = { category = "creature" }, link = "rivals" },
	{ id = "versus_vehicle", rel = "versus", a = { category = "creature" }, b = { category = "vehicle" }, link = "rivals" },
	{ id = "guard_building", rel = "guard", a = { category = "creature" }, b = { category = "building" }, link = "guard" },
	{ id = "guard_thing", rel = "guard", a = { category = "creature" }, b = { category = { "object", "food", "nature", "vehicle" } }, link = "guard" },
	{ id = "guard_creature", rel = "guard", a = { category = "creature" }, b = { category = "creature" }, link = "bodyguard" },
	{ id = "ride_vehicle", rel = "ride", a = { category = "creature" }, b = { category = "vehicle" }, link = "ride" },
	{ id = "ride_creature", rel = "ride", a = { category = "creature" }, b = { category = "creature" }, link = "ride" },
	{ id = "inside_vehicle", rel = "location", a = { category = "creature" }, b = { category = "vehicle" }, link = "ride" },
	{ id = "inside_building", rel = "location", a = { category = { "creature", "object", "food", "vehicle", "nature" } }, b = { category = "building" }, link = "at" },
	{ id = "at_nature", rel = "location", a = { category = { "creature", "object", "food" } }, b = { category = "nature" }, link = "at" },

	-- interações implícitas ("e", "com", vírgula) ---------------------------
	{ id = "good_vs_evil", rel = "conjunction", a = { tag = "good" }, b = { tag = "evil" }, link = "rivals" },
	{ id = "beast_vs_machine", rel = "conjunction", a = { tag = "beast" }, b = { tag = "machine" }, link = "rivals" },
	{ id = "predator_prey", rel = "conjunction", a = { tag = "predator" }, b = { tag = "prey" }, link = "hunt" },
	{ id = "undead_hunt", rel = "conjunction", a = { tag = "undead" }, b = { tag = "humanoid", notTag = "undead" }, link = "hunt" },
	{ id = "monster_castle", rel = "conjunction", a = { category = "creature", tag = "evil" }, b = { category = "building" }, link = "guard" },
	{ id = "creature_home", rel = "conjunction", a = { category = "creature" }, b = { category = "building" }, link = "at" },
}

return rules
