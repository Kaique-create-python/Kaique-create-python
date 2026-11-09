--!strict
-- Desastres, clima, magia e combinações prontas.
--   handler "disaster": params.kind escolhe o efeito em Handlers/Disasters
--   handler "world": altera céu, iluminação, gravidade... (temporário)
--   handler "composite": expande para vários conceitos (compose)
-- params.payload = true: aceita "X de Y" carregando objetos (tornado de tubarões)

local function d(category: string, handler: string, id: string, label: string, gender: string, aliases: { string }, params: { [string]: any }, tags: { string }, extra: { [string]: any }?)
	local def: { [string]: any } = {
		id = id,
		label = label,
		gender = gender,
		category = category,
		handler = handler,
		aliases = aliases,
		params = params,
		tags = tags,
		maxCount = 1,
		lifetime = 35,
	}
	if extra then
		for k, v in extra do
			def[k] = v
		end
	end
	return def
end

local DIS, WEA, MAG = "disaster", "weather", "magic"

return {
	-- DESASTRES --------------------------------------------------------------
	d(DIS, "disaster", "meteor", "Meteoro", "m", { "meteoro", "meteor", "asteroide", "asteroid", "cometa", "comet", "meteorito", "bola de fogo do ceu" }, { kind = "meteor", count = 1, element = "fire", payload = true }, { "space", "fire", "impact" }, { maxCount = 3, lifetime = 20 }),
	d(DIS, "disaster", "meteor_shower", "Chuva de Meteoros", "f", { "chuva de meteoros", "meteor shower", "chuva de meteoro", "chuva de asteroides", "tempestade de meteoros", "apocalipse espacial" }, { kind = "meteor", count = 9, element = "fire", payload = true }, { "space", "fire", "impact" }, { lifetime = 30 }),
	d(DIS, "disaster", "black_hole", "Buraco Negro", "m", { "buraco negro", "black hole", "singularidade", "vortice", "vortex", "redemoinho cosmico", "buraco" }, { kind = "black_hole", payload = true }, { "space", "gravity" }, { lifetime = 22 }),
	d(DIS, "disaster", "tornado", "Tornado", "m", { "tornado", "furacao", "hurricane", "ciclone", "cyclone", "redemoinho", "twister", "tufao", "typhoon", "tromba d agua" }, { kind = "tornado", payload = true, element = "wind" }, { "wind", "storm" }, { maxCount = 2, lifetime = 30 }),
	d(DIS, "disaster", "lightning", "Raio", "m", { "raio", "raios", "relampago", "trovao", "thunder", "lightning", "tempestade eletrica", "thunderstorm", "trovoada", "descarga eletrica" }, { kind = "lightning", element = "electric" }, { "storm", "electric" }, { maxCount = 2, lifetime = 22, asModifier = "electric", preferModifier = true }),
	d(DIS, "disaster", "tsunami", "Tsunami", "m", { "tsunami", "onda gigante", "maremoto", "giant wave", "tidal wave", "onda", "wave", "inundacao", "enchente", "flood", "dilúvio", "diluvio" }, { kind = "tsunami", element = "water", payload = true }, { "water", "storm" }, { lifetime = 26 }),
	d(DIS, "disaster", "explosion", "Explosão", "f", { "explosao", "explosion", "bomba", "bomb", "kaboom", "boom", "explodir", "explode", "detonacao", "granada", "grenade" }, { kind = "explosion", power = 1, payload = true }, { "explosive", "fire" }, { maxCount = 3, lifetime = 10 }),
	d(DIS, "disaster", "nuke", "Mega Explosão", "f", { "bomba atomica", "bomba nuclear", "nuke", "nuclear", "mega explosao", "explosao nuclear", "atomic bomb", "cogumelo atomico" }, { kind = "explosion", power = 3.2 }, { "explosive", "fire" }, { lifetime = 16 }),
	d(DIS, "disaster", "earthquake", "Terremoto", "m", { "terremoto", "earthquake", "tremor", "abalo sismico", "sismo", "quake", "tremor de terra" }, { kind = "earthquake" }, { "ground" }, { lifetime = 18 }),
	d(DIS, "disaster", "volcano_eruption", "Erupção Vulcânica", "f", { "erupcao", "eruption", "erupcao vulcanica", "vulcao", "volcano", "vulcao em erupcao" }, { kind = "volcano", element = "lava" }, { "fire", "ground", "lava" }, { lifetime = 32 }),
	d(DIS, "disaster", "fire", "Incêndio", "m", { "fogo", "incendio", "chamas", "fogaréu", "fogareu", "labaredas", "blaze", "wildfire", "queimada" }, { kind = "fire", element = "fire" }, { "fire" }, { maxCount = 2, lifetime = 24, asModifier = "fire", preferModifier = true }),
	d(DIS, "disaster", "ice_burst", "Congelamento", "f", { "gelo", "congelar", "congelamento", "freeze", "era do gelo", "ice age", "cristais de gelo", "geada" }, { kind = "ice", element = "ice" }, { "ice" }, { maxCount = 2, lifetime = 20, asModifier = "ice", preferModifier = true }),
	d(DIS, "disaster", "blizzard", "Nevasca", "f", { "nevasca", "blizzard", "tempestade de neve", "snowstorm", "avalanche", "neve", "snow", "nevando", "floco de neve" }, { kind = "blizzard", element = "ice" }, { "ice", "storm" }, { lifetime = 30, asModifier = "ice", preferModifier = true }),
	d(DIS, "disaster", "acid_rain", "Chuva Ácida", "f", { "chuva acida", "acid rain", "chuva toxica", "lixo toxico", "toxic waste", "radiacao", "radiation" }, { kind = "acid_rain", element = "poison" }, { "poison", "storm" }, { lifetime = 22 }),
	d(DIS, "disaster", "sandstorm", "Tempestade de Areia", "f", { "tempestade de areia", "sandstorm", "areia", "sand", "duna", "redemoinho de areia" }, { kind = "sandstorm" }, { "storm", "desert" }, { lifetime = 26 }),
	d(DIS, "disaster", "lava_pool", "Lago de Lava", "m", { "lago de lava", "rio de lava", "piscina de lava", "lava pool", "lava river", "chao e lava", "the floor is lava" }, { kind = "lava", element = "lava" }, { "fire", "lava" }, { lifetime = 22 }),
	d(DIS, "disaster", "rockfall", "Chuva de Pedras", "f", { "chuva de pedras", "desmoronamento", "deslizamento", "landslide", "rockfall", "granizo", "hail", "chuva de granizo" }, { kind = "rockfall" }, { "ground", "impact" }, { lifetime = 22 }),
	d(DIS, "disaster", "wind", "Ventania", "f", { "rajada de vento", "vendaval", "gale", "wind gust", "sopro", "brisa forte" }, { kind = "wind", element = "wind" }, { "wind" }, { lifetime = 18 }),
	d(DIS, "disaster", "gravity_zero", "Gravidade Zero", "f", { "gravidade zero", "sem gravidade", "zero gravity", "antigravidade", "anti gravidade", "baixa gravidade", "low gravity", "gravidade", "gravity", "flutuar" }, { kind = "gravity" }, { "space", "gravity" }, { lifetime = 22 }),
	d(DIS, "disaster", "laser_storm", "Tempestade de Lasers", "f", { "tempestade de lasers", "chuva de laser", "chuva de lasers", "laser storm", "orbital laser", "laser do ceu" }, { kind = "laser_storm", element = "electric" }, { "space", "electric" }, { lifetime = 20 }),
	d(DIS, "disaster", "end_of_world", "Fim do Mundo", "m", { "fim do mundo", "apocalipse", "apocalypse", "armageddon", "end of the world", "caos", "chaos", "caos total", "destruicao total" }, { kind = "chaos" }, { "storm", "chaos" }, { lifetime = 40 }),

	-- CLIMA E AMBIENTE -------------------------------------------------------
	d(WEA, "world", "night", "Noite", "f", { "noite", "night", "escuridao", "darkness", "meia noite", "midnight", "lua cheia" }, { kind = "night" }, { "sky" }, { lifetime = 60 }),
	d(WEA, "world", "day", "Dia", "m", { "dia", "day", "manha", "morning", "meio dia", "noon", "sol", "sun", "sunny", "ensolarado" }, { kind = "day" }, { "sky" }, { lifetime = 60 }),
	d(WEA, "world", "sunset", "Pôr do Sol", "m", { "por do sol", "sunset", "entardecer", "crepusculo", "amanhecer", "sunrise", "alvorada", "tarde" }, { kind = "sunset" }, { "sky" }, { lifetime = 60 }),
	d(WEA, "world", "eclipse", "Eclipse", "m", { "eclipse", "eclipse solar", "eclipse lunar", "lua de sangue", "blood moon" }, { kind = "eclipse" }, { "sky", "space" }, { lifetime = 40 }),
	d(WEA, "world", "rain", "Chuva", "f", { "chuva", "rain", "chuvarada", "garoa", "tempestade", "storm", "temporal", "aguaceiro", "chuvisco" }, { kind = "rain", element = "water" }, { "sky", "water", "storm" }, { lifetime = 45 }),
	d(WEA, "world", "fog", "Neblina", "f", { "neblina", "nevoa", "fog", "mist", "nevoeiro", "bruma", "cerracao" }, { kind = "fog" }, { "sky" }, { lifetime = 45 }),
	d(WEA, "world", "rainbow", "Arco-íris", "m", { "arco iris", "rainbow", "arcoiris" }, { kind = "rainbow", element = "rainbow" }, { "sky", "magic" }, { lifetime = 45 }),
	d(WEA, "world", "aurora", "Aurora Boreal", "f", { "aurora", "aurora boreal", "aurora austral", "northern lights", "luzes do norte" }, { kind = "aurora" }, { "sky", "magic" }, { lifetime = 50 }),
	d(WEA, "world", "party", "Festa", "f", { "festa", "party", "balada", "rave", "disco", "danca", "dance", "dancar", "carnaval", "baile", "musica", "music", "show", "festa junina" }, { kind = "party" }, { "music", "fun" }, { lifetime = 40 }),
	d(WEA, "world", "fireworks", "Fogos de Artifício", "m", { "fogos de artificio", "fogos", "fireworks", "rojao", "foguetorio", "reveillon", "ano novo", "new year" }, { kind = "fireworks" }, { "sky", "fun" }, { maxCount = 2, lifetime = 20 }),
	d(WEA, "world", "moon", "Lua Gigante", "f", { "lua", "moon", "lua gigante", "luar", "planeta", "planet", "saturno", "jupiter", "marte", "mars", "terra", "earth" }, { kind = "moon" }, { "sky", "space" }, { lifetime = 45 }),
	d(WEA, "world", "stars", "Chuva de Estrelas", "f", { "estrelas", "estrela", "star", "stars", "estrela cadente", "shooting star", "constelacao", "galaxia", "galaxy", "via lactea", "universo", "universe", "espaco sideral" }, { kind = "stars" }, { "sky", "space", "magic" }, { lifetime = 40 }),
	d(WEA, "world", "restore", "Restaurar Mapa", "m", { "restaurar", "restaurar mapa", "consertar", "reparar", "reconstruir", "restore", "repair", "fix", "rebuild" }, { kind = "restore" }, { "utility" }, { lifetime = 5 }),
	d(WEA, "world", "clear", "Limpar Minhas Ideias", "m", { "limpar", "limpa", "clear", "apagar", "remover", "remove", "sumir", "desfazer", "undo", "reset" }, { kind = "clear" }, { "utility" }, { lifetime = 2 }),

	-- MAGIA ------------------------------------------------------------------
	d(MAG, "world", "magic", "Magia", "f", { "magia", "magic", "magica", "feitico", "spell", "encanto", "bruxaria", "sortilegio", "abracadabra", "mana" }, { kind = "magic" }, { "magic" }, { lifetime = 30 }),
	d(MAG, "world", "blessing", "Bênção", "f", { "bencao", "blessing", "milagre", "miracle", "paz", "peace", "amor", "love", "esperanca", "hope", "alegria", "felicidade", "happiness" }, { kind = "blessing", element = "light" }, { "magic", "good" }, { lifetime = 20 }),
	d(MAG, "world", "curse", "Maldição", "f", { "maldicao", "curse", "praga", "azar", "bad luck", "pesadelo", "nightmare", "medo", "fear", "terror", "horror" }, { kind = "curse", element = "shadow" }, { "magic", "evil" }, { lifetime = 30 }),
	d(MAG, "world", "summon", "Invocação", "f", { "invocacao", "summoning", "circulo magico", "magic circle", "pentagrama", "ritual", "conjuracao" }, { kind = "summon" }, { "magic" }, { lifetime = 60 }),
	d(MAG, "world", "wish", "Desejo", "m", { "desejo", "wish", "sorte", "luck", "lucky", "trevo", "clover", "genio da lampada", "genie", "lampada magica" }, { kind = "wish" }, { "magic", "good" }, { lifetime = 30 }),
	d(MAG, "world", "treasure", "Tesouro Mágico", "m", { "chuva de ouro", "tesouro magico", "riqueza", "rich", "fortuna", "jackpot", "mina de ouro" }, { kind = "treasure" }, { "treasure", "magic" }, { lifetime = 30 }),

	-- COMBINAÇÕES PRONTAS ----------------------------------------------------
	d(DIS, "composite", "alien_invasion", "Invasão Alienígena", "f", { "invasao alienigena", "alien invasion", "ataque alienigena", "guerra dos mundos" }, {
		compose = { { id = "ufo", count = 2 }, { id = "alien", count = 5 } },
	}, { "alien", "chaos" }, { lifetime = 70 }),
	d(DIS, "composite", "zombie_apocalypse", "Apocalipse Zumbi", "m", { "apocalipse zumbi", "zombie apocalypse", "infeccao zumbi", "the walking dead", "epidemia zumbi" }, {
		compose = { { id = "zombie", count = 12 }, { id = "fog", count = 1 } },
	}, { "undead", "chaos" }, { lifetime = 70 }),
	d(DIS, "composite", "pirate_attack", "Ataque Pirata", "m", { "ataque pirata", "pirate attack", "invasao pirata", "piratas do caribe" }, {
		compose = { { id = "ship", count = 1 }, { id = "pirate", count = 6 } },
	}, { "chaos" }, { lifetime = 70 }),
	d(DIS, "composite", "jurassic", "Parque dos Dinossauros", "m", { "parque dos dinossauros", "jurassico", "jurassic", "era dos dinossauros", "pre historia", "prehistoric" }, {
		compose = { { id = "dinosaur", count = 1 }, { id = "raptor", count = 3 }, { id = "brachiosaurus", count = 1 } },
	}, { "beast", "chaos" }, { lifetime = 75 }),
	d(DIS, "composite", "haunted", "Noite Assombrada", "f", { "noite assombrada", "halloween", "dia das bruxas", "casa assombrada", "haunted house", "cemiterio", "graveyard" }, {
		compose = { { id = "night", count = 1 }, { id = "ghost", count = 4 }, { id = "skeleton", count = 4 } },
	}, { "undead", "chaos" }, { lifetime = 70 }),
	d(DIS, "composite", "medieval_war", "Guerra Medieval", "f", { "guerra medieval", "batalha medieval", "cerco ao castelo", "medieval war", "cruzada" }, {
		compose = { { id = "castle", count = 1 }, { id = "knight", count = 4 }, { id = "troll", count = 2 } },
		links = { { type = "rivals", a = 2, b = 3 }, { type = "guard", guard = 2, target = 1 } },
	}, { "medieval", "chaos" }, { lifetime = 90 }),
	d(DIS, "composite", "safari", "Safári", "m", { "safari", "zoologico", "zoo", "savana", "savanna", "africa", "animais", "animals", "bichos", "fauna" }, {
		compose = { { id = "lion", count = 1 }, { id = "elephant", count = 1 }, { id = "giraffe", count = 1 }, { id = "monkey", count = 2 } },
	}, { "animal" }, { lifetime = 75 }),
	d(DIS, "composite", "amazonia", "Amazônia", "f", { "amazonia", "amazon", "floresta amazonica", "pantanal", "selva brasileira", "mata atlantica" }, {
		compose = { { id = "forest_patch", count = 1 }, { id = "parrot", count = 3 }, { id = "jaguar", count = 1 }, { id = "capybara", count = 2 } },
	}, { "animal", "nature", "brazil" }, { lifetime = 80 }),
	d(DIS, "composite", "farm_life", "Vida na Fazenda", "f", { "vida na fazenda", "roca", "interior", "zona rural", "fazendinha" }, {
		compose = { { id = "farm", count = 1 }, { id = "cow", count = 2 }, { id = "chicken", count = 3 }, { id = "pig", count = 2 } },
	}, { "farm", "animal" }, { lifetime = 90 }),
	d(DIS, "composite", "folclore", "Folclore Brasileiro", "m", { "folclore", "folclore brasileiro", "lendas brasileiras", "sitio do picapau amarelo" }, {
		compose = { { id = "saci", count = 1 }, { id = "curupira", count = 1 }, { id = "headless_mule", count = 1 }, { id = "boitata", count = 1 } },
	}, { "folklore", "brazil" }, { lifetime = 80 }),
}
