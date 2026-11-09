--!strict
-- Construções (handler "building"). Aparecem à frente do jogador com animação
-- de "montagem" e ficam ancoradas até expirar.

local function bld(id: string, label: string, gender: string, aliases: { string }, params: { [string]: any }, tags: { string }, extra: { [string]: any }?)
	local def: { [string]: any } = {
		id = id,
		label = label,
		gender = gender,
		category = "building",
		handler = "building",
		aliases = aliases,
		params = params,
		tags = tags,
		maxCount = 2,
		lifetime = 100,
	}
	if extra then
		for k, v in extra do
			def[k] = v
		end
	end
	return def
end

return {
	bld("house", "Casa", "f", { "casa", "house", "home", "lar", "chale", "cabana", "barraco", "cottage" }, { model = "building", variant = "house" }, { "building", "home" }),
	bld("mansion", "Mansão", "f", { "mansao", "mansion", "palacete", "casarao", "villa" }, { model = "building", variant = "mansion" }, { "building", "home" }, { maxCount = 1 }),
	bld("skyscraper", "Arranha-céu", "m", { "arranha ceu", "predio", "skyscraper", "edificio", "torre comercial", "building" }, { model = "building", variant = "skyscraper" }, { "building", "city" }),
	bld("tower", "Torre", "f", { "torre", "tower", "torre de vigia", "atalaia", "minarete" }, { model = "building", variant = "tower" }, { "building" }),
	bld("castle", "Castelo", "m", { "castelo", "castle", "fortaleza", "fortress", "forte", "cidadela", "palacio", "palace" }, { model = "building", variant = "castle" }, { "building", "medieval" }, { maxCount = 1, lifetime = 120 }),
	bld("bridge", "Ponte", "f", { "ponte", "bridge", "passarela", "viaduto" }, { model = "building", variant = "bridge" }, { "building" }),
	bld("wall", "Muralha", "f", { "muralha", "muro", "wall", "parede", "barreira", "barricada" }, { model = "building", variant = "wall" }, { "building" }),
	bld("maze", "Labirinto", "m", { "labirinto", "maze", "labyrinth", "dedalo" }, { model = "building", variant = "maze" }, { "building", "puzzle" }, { maxCount = 1, lifetime = 140 }),
	bld("pyramid", "Pirâmide", "f", { "piramide", "pyramid", "piramide egipcia", "zigurate" }, { model = "building", variant = "pyramid" }, { "building", "ancient" }, { maxCount = 1 }),
	bld("lighthouse", "Farol", "m", { "farol", "lighthouse" }, { model = "building", variant = "lighthouse" }, { "building" }),
	bld("windmill", "Moinho", "m", { "moinho", "windmill", "moinho de vento", "cata vento", "turbina eolica" }, { model = "building", variant = "windmill" }, { "building", "farm" }),
	bld("ferris_wheel", "Roda-gigante", "f", { "roda gigante", "ferris wheel", "parque de diversoes", "carrossel", "carousel" }, { model = "building", variant = "ferris_wheel" }, { "building", "fun" }, { maxCount = 1 }),
	bld("statue", "Estátua", "f", { "estatua", "statue", "monumento", "escultura", "busto" }, { model = "building", variant = "statue" }, { "building", "art" }),
	bld("igloo", "Iglu", "m", { "iglu", "igloo", "oca de gelo" }, { model = "building", variant = "igloo" }, { "building", "ice" }),
	bld("tent", "Barraca", "f", { "barraca", "tenda", "tent", "acampamento", "camping", "oca", "tipi" }, { model = "building", variant = "tent" }, { "building" }),
	bld("temple", "Templo", "m", { "templo", "temple", "santuario", "shrine", "ruina", "ruins", "coliseu romano", "parthenon" }, { model = "building", variant = "temple" }, { "building", "ancient" }, { maxCount = 1 }),
	bld("school", "Escola", "f", { "escola", "school", "colegio", "faculdade", "universidade", "biblioteca", "library" }, { model = "building", variant = "school" }, { "building", "city" }),
	bld("shop", "Loja", "f", { "loja", "shop", "mercado", "supermercado", "padaria", "lanchonete", "restaurante", "store", "shopping" }, { model = "building", variant = "shop" }, { "building", "city", "food" }),
	bld("farm", "Fazenda", "f", { "fazenda", "farm", "celeiro", "barn", "sitio", "rancho", "curral", "chacara" }, { model = "building", variant = "farm" }, { "building", "farm" }, { maxCount = 1 }),
	bld("city", "Cidade", "f", { "cidade", "city", "metropole", "bairro", "cidadezinha", "vila", "village", "vilarejo", "povoado" }, { model = "building", variant = "city" }, { "building", "city" }, { maxCount = 1, lifetime = 110 }),
	bld("treehouse", "Casa na Árvore", "f", { "casa na arvore", "treehouse", "casa de arvore" }, { model = "building", variant = "treehouse" }, { "building", "home", "nature" }),
	bld("portal", "Portal", "m", { "portal", "portais", "teleporte magico", "wormhole", "buraco de minhoca", "stargate", "dimensao" }, { model = "building", variant = "portal" }, { "building", "magic" }, { maxCount = 1 }),
	bld("cage", "Jaula", "f", { "jaula", "cage", "prisao", "prison", "cadeia", "cela", "armadilha", "trap" }, { model = "building", variant = "cage" }, { "building", "trap" }),
	bld("arena_ring", "Ringue", "m", { "ringue", "ring", "octogono", "arena de luta", "estadio", "stadium", "campo de futebol", "quadra" }, { model = "building", variant = "ring" }, { "building", "sport" }, { maxCount = 1 }),
	bld("stairs", "Escadaria", "f", { "escada", "escadaria", "stairs", "staircase", "escada para o ceu", "rampa", "ramp" }, { model = "building", variant = "stairs" }, { "building" }),
	bld("slide", "Tobogã", "m", { "toboga", "escorregador", "slide", "parquinho", "playground", "montanha russa", "roller coaster" }, { model = "building", variant = "slide" }, { "building", "fun" }),
	bld("trampoline", "Cama Elástica", "f", { "cama elastica", "trampolim", "trampoline", "pula pula", "mola", "jump pad" }, { model = "building", variant = "trampoline" }, { "building", "fun" }),
	bld("pool", "Piscina", "f", { "piscina", "pool", "lago", "lagoa", "pond", "fonte", "fountain", "chafariz" }, { model = "building", variant = "pool" }, { "building", "water" }),
	bld("floating_island", "Ilha Flutuante", "f", { "ilha flutuante", "ilha", "island", "ilha no ceu", "sky island" }, { model = "building", variant = "floating_island" }, { "building", "nature", "flying" }, { maxCount = 1 }),
}
