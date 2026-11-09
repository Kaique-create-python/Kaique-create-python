--!strict
-- Criaturas e personagens (handler "npc").
-- params.model escolhe o construtor procedural; params.variant o tipo dentro dele.
-- attacks: melee | breath | bolt | stomp | charge | beam | heal | gift | whirlwind
-- faction: hostile | ally | neutral | pet

local function npc(id: string, label: string, gender: string, aliases: { string }, params: { [string]: any }, tags: { string }, extra: { [string]: any }?)
	local def: { [string]: any } = {
		id = id,
		label = label,
		gender = gender,
		category = "creature",
		handler = "npc",
		aliases = aliases,
		params = params,
		tags = tags,
	}
	if extra then
		for k, v in extra do
			def[k] = v
		end
	end
	return def
end

local H, A, N = "hostile", "ally", "neutral"

return {
	-- MONSTROS CLÁSSICOS -----------------------------------------------------
	npc("dragon", "Dragão", "m", { "dragao", "dragon", "drake", "wyvern", "serpe" }, {
		model = "dragon", variant = "dragon", faction = H, hp = 900, speed = 26, dmg = 18, fly = true, element = "fire",
		attacks = { "breath", "melee" }, size = 1.4,
	}, { "beast", "monster", "flying", "evil", "predator" }, { maxCount = 3, lifetime = 80, asModifier = "draconic" }),
	npc("hydra", "Hidra", "f", { "hidra", "hydra", "dragao de tres cabecas" }, {
		model = "dragon", variant = "hydra", faction = H, hp = 1300, speed = 18, dmg = 16, fly = false, element = "poison",
		attacks = { "breath", "melee" }, size = 1.5,
	}, { "beast", "monster", "evil" }, { maxCount = 2, lifetime = 80 }),
	npc("dinosaur", "Dinossauro", "m", { "dinossauro", "dinosaur", "dino", "tiranossauro", "t rex", "trex", "tiranossauro rex", "rex" }, {
		model = "theropod", variant = "trex", faction = H, hp = 700, speed = 20, dmg = 22, attacks = { "melee", "stomp" }, size = 1.3,
	}, { "beast", "monster", "predator" }, { maxCount = 4, lifetime = 75 }),
	npc("raptor", "Velociraptor", "m", { "raptor", "velociraptor", "velociraptors" }, {
		model = "theropod", variant = "raptor", faction = H, hp = 160, speed = 30, dmg = 10, attacks = { "melee", "charge" }, size = 0.9,
	}, { "beast", "predator" }, { maxCount = 8 }),
	npc("kaiju", "Kaiju", "m", { "kaiju", "monstro gigante", "godzilla", "monstrao", "lagartixa gigante" }, {
		model = "theropod", variant = "kaiju", faction = H, hp = 2600, speed = 14, dmg = 35, element = "electric",
		attacks = { "breath", "stomp", "melee" }, size = 3.2,
	}, { "beast", "monster", "evil", "giant" }, { maxCount = 1, lifetime = 90 }),
	npc("triceratops", "Tricerátopo", "m", { "triceratops", "triceratopo", "tricerato" }, {
		model = "quadruped", variant = "triceratops", faction = N, hp = 600, speed = 16, dmg = 18, attacks = { "charge", "melee" }, size = 1.4,
	}, { "beast", "prey" }, { maxCount = 4 }),
	npc("stegosaurus", "Estegossauro", "m", { "estegossauro", "stegosaurus", "estegosauro" }, {
		model = "quadruped", variant = "stegosaurus", faction = N, hp = 650, speed = 12, dmg = 16, attacks = { "melee" }, size = 1.5,
	}, { "beast", "prey" }, { maxCount = 3 }),
	npc("brachiosaurus", "Braquiossauro", "m", { "braquiossauro", "brachiosaurus", "braquiosauro", "pescocudo", "brontossauro", "brontosaurus", "diplodoco" }, {
		model = "quadruped", variant = "brachiosaurus", faction = N, hp = 1400, speed = 10, dmg = 20, attacks = { "stomp" }, size = 2.2,
	}, { "beast", "giant", "prey" }, { maxCount = 2 }),
	npc("pterodactyl", "Pterodáctilo", "m", { "pterodactilo", "pterodactyl", "pterossauro", "pteranodon" }, {
		model = "bird", variant = "pterodactyl", faction = H, hp = 180, speed = 28, dmg = 10, fly = true, attacks = { "melee" }, size = 1.3,
	}, { "beast", "flying", "predator" }, { maxCount = 6 }),

	npc("zombie", "Zumbi", "m", { "zumbi", "zombie", "zumbie", "walker", "morto", "mortos vivos", "zumbis" }, {
		model = "figure", variant = "zombie", faction = H, hp = 90, speed = 10, dmg = 10, attacks = { "melee" },
	}, { "undead", "evil", "monster", "humanoid" }, { maxCount = 14, asModifier = "undead", preferModifier = true }),
	npc("skeleton", "Esqueleto", "m", { "esqueleto", "skeleton", "caveira", "ossada" }, {
		model = "figure", variant = "skeleton", faction = H, hp = 70, speed = 14, dmg = 9, attacks = { "melee", "bolt" }, element = "shadow",
	}, { "undead", "evil", "monster", "humanoid" }, { maxCount = 12 }),
	npc("mummy", "Múmia", "f", { "mumia", "mummy", "farao", "pharaoh" }, {
		model = "figure", variant = "mummy", faction = H, hp = 140, speed = 9, dmg = 12, attacks = { "melee" },
	}, { "undead", "evil", "monster", "humanoid" }, { maxCount = 10 }),
	npc("vampire", "Vampiro", "m", { "vampiro", "vampira", "vampire", "dracula", "conde dracula" }, {
		model = "figure", variant = "vampire", faction = H, hp = 220, speed = 18, dmg = 14, attacks = { "melee", "bolt" }, element = "shadow",
	}, { "undead", "evil", "monster", "humanoid" }, { maxCount = 6 }),
	npc("werewolf", "Lobisomem", "m", { "lobisomem", "werewolf", "lobis homem", "homem lobo" }, {
		model = "figure", variant = "werewolf", faction = H, hp = 260, speed = 22, dmg = 16, attacks = { "melee", "charge" },
	}, { "beast", "evil", "monster", "humanoid", "predator", "folklore" }, { maxCount = 6 }),
	npc("ghost", "Fantasma", "m", { "fantasma", "ghost", "assombracao", "espirito", "alma penada", "boo" }, {
		model = "ghost", variant = "ghost", faction = H, hp = 120, speed = 14, dmg = 8, fly = true, element = "shadow", attacks = { "melee", "bolt" },
	}, { "undead", "evil", "flying", "spirit" }, { maxCount = 10, asModifier = "ghostly", preferModifier = true }),
	npc("demon", "Demônio", "m", { "demonio", "demon", "diabo", "capeta", "diabinho", "devil", "satan", "satanas", "imp" }, {
		model = "figure", variant = "demon", faction = H, hp = 420, speed = 18, dmg = 18, element = "fire", attacks = { "melee", "bolt" }, size = 1.25,
	}, { "evil", "monster", "humanoid", "fire" }, { maxCount = 5 }),
	npc("witch", "Bruxa", "f", { "bruxa", "witch", "feiticeira", "bruxo" }, {
		model = "figure", variant = "witch", faction = H, hp = 150, speed = 20, dmg = 12, fly = true, element = "poison", attacks = { "bolt" },
	}, { "evil", "magic", "humanoid", "flying" }, { maxCount = 5 }),
	npc("goblin", "Goblin", "m", { "goblin", "duende", "gnomo", "gremlin" }, {
		model = "figure", variant = "goblin", faction = H, hp = 60, speed = 20, dmg = 7, attacks = { "melee" }, size = 0.7,
	}, { "evil", "monster", "humanoid" }, { maxCount = 12 }),
	npc("troll", "Troll", "m", { "troll", "ogro", "ogre", "orc", "orco" }, {
		model = "figure", variant = "troll", faction = H, hp = 520, speed = 11, dmg = 24, attacks = { "melee", "stomp" }, size = 1.8,
	}, { "evil", "monster", "humanoid", "giant" }, { maxCount = 4 }),
	npc("golem", "Golem", "m", { "golem", "gigante de pedra", "colosso de pedra", "titan de pedra" }, {
		model = "figure", variant = "golem", faction = N, hp = 900, speed = 9, dmg = 26, attacks = { "melee", "stomp" }, size = 2,
	}, { "monster", "giant", "humanoid", "stone" }, { maxCount = 3 }),
	npc("cyclops", "Ciclope", "m", { "ciclope", "cyclops", "gigante de um olho" }, {
		model = "figure", variant = "cyclops", faction = H, hp = 800, speed = 11, dmg = 26, attacks = { "melee", "stomp" }, size = 2.4,
	}, { "monster", "giant", "humanoid", "evil" }, { maxCount = 2 }),
	npc("yeti", "Yeti", "m", { "yeti", "abominavel", "pe grande", "bigfoot", "sasquatch", "abominavel homem das neves" }, {
		model = "figure", variant = "yeti", faction = H, hp = 480, speed = 15, dmg = 20, element = "ice", attacks = { "melee", "stomp" }, size = 1.7,
	}, { "beast", "monster", "humanoid", "ice" }, { maxCount = 3 }),
	npc("alien", "Alienígena", "m", { "alienigena", "alien", "et", "extraterrestre", "marciano", "aliens", "ets" }, {
		model = "figure", variant = "alien", faction = H, hp = 110, speed = 16, dmg = 9, element = "electric", attacks = { "bolt" },
	}, { "alien", "evil", "humanoid" }, { maxCount = 10 }),
	npc("ufo", "Disco Voador", "m", { "disco voador", "ovni", "ufo", "nave alienigena", "flying saucer" }, {
		model = "ufo", variant = "ufo", faction = H, hp = 700, speed = 24, dmg = 6, fly = true, element = "electric", attacks = { "beam", "bolt" }, size = 1.4,
	}, { "alien", "machine", "flying", "evil" }, { maxCount = 3, lifetime = 70 }),
	npc("slime", "Slime", "m", { "slime", "geleca", "blob", "meleca", "gosminha" }, {
		model = "slime", variant = "slime", faction = H, hp = 120, speed = 12, dmg = 8, element = "poison", attacks = { "melee" },
	}, { "monster" }, { maxCount = 12 }),

	-- HERÓIS E ALIADOS -------------------------------------------------------
	npc("hero", "Herói", "m", { "heroi", "hero", "super heroi", "superheroi", "superhero", "heroina", "campeao", "salvador" }, {
		model = "figure", variant = "hero", faction = A, hp = 500, speed = 22, dmg = 22, fly = false, attacks = { "melee", "bolt" }, element = "light",
	}, { "good", "humanoid", "hero" }, { maxCount = 5 }),
	npc("knight", "Cavaleiro", "m", { "cavaleiro", "knight", "paladino", "paladin", "guerreiro", "warrior", "templario" }, {
		model = "figure", variant = "knight", faction = A, hp = 420, speed = 16, dmg = 20, attacks = { "melee" },
	}, { "good", "humanoid", "hero", "medieval" }, { maxCount = 6 }),
	npc("wizard", "Mago", "m", { "mago", "wizard", "feiticeiro", "merlin", "maga", "mage", "sorcerer" }, {
		model = "figure", variant = "wizard", faction = A, hp = 260, speed = 15, dmg = 18, element = "electric", attacks = { "bolt" },
	}, { "good", "magic", "humanoid" }, { maxCount = 5 }),
	npc("angel", "Anjo", "m", { "anjo", "angel", "querubim", "arcanjo" }, {
		model = "figure", variant = "angel", faction = A, hp = 380, speed = 20, dmg = 14, fly = true, element = "light", attacks = { "bolt", "heal" },
	}, { "good", "flying", "humanoid", "spirit" }, { maxCount = 4 }),
	npc("fairy", "Fada", "f", { "fada", "fairy", "pixie", "sininho" }, {
		model = "figure", variant = "fairy", faction = A, hp = 80, speed = 22, dmg = 4, fly = true, element = "light", attacks = { "heal" }, size = 0.45,
	}, { "good", "flying", "magic" }, { maxCount = 6 }),
	npc("robot", "Robô", "m", { "robo", "robot", "robos", "androide", "android", "automato", "bot", "ciborgue" }, {
		model = "robot", variant = "robot", faction = A, hp = 380, speed = 16, dmg = 16, element = "electric", attacks = { "bolt", "melee" },
	}, { "machine", "humanoid", "good" }, { maxCount = 8, asModifier = "robotic", preferModifier = true }),
	npc("mech", "Mecha", "m", { "mecha", "mech", "robo gigante", "megazord", "transformer", "exoesqueleto" }, {
		model = "robot", variant = "mech", faction = H, hp = 1800, speed = 12, dmg = 30, element = "electric", attacks = { "bolt", "stomp" }, size = 2.6,
	}, { "machine", "giant", "evil" }, { maxCount = 1, lifetime = 85 }),
	npc("drone", "Drone", "m", { "drone", "drones", "quadricoptero", "quadcopter" }, {
		model = "robot", variant = "drone", faction = N, hp = 60, speed = 24, dmg = 5, fly = true, element = "electric", attacks = { "bolt" }, size = 0.8,
	}, { "machine", "flying" }, { maxCount = 10 }),
	npc("police", "Policial", "m", { "policial", "policia", "police", "cop", "guarda civil", "xerife", "sheriff" }, {
		model = "figure", variant = "police", faction = A, hp = 220, speed = 18, dmg = 12, attacks = { "bolt" },
	}, { "good", "humanoid" }, { maxCount = 8 }),
	npc("soldier", "Soldado", "m", { "soldado", "soldier", "militar", "army", "tropa", "recruta" }, {
		model = "figure", variant = "soldier", faction = A, hp = 240, speed = 17, dmg = 12, attacks = { "bolt" },
	}, { "good", "humanoid" }, { maxCount = 10 }),
	npc("firefighter", "Bombeiro", "m", { "bombeiro", "firefighter", "bombeira", "fireman" }, {
		model = "figure", variant = "firefighter", faction = A, hp = 240, speed = 18, dmg = 6, element = "water", attacks = { "bolt" },
	}, { "good", "humanoid", "water" }, { maxCount = 6 }),
	npc("doctor", "Médico", "m", { "medico", "medica", "doctor", "doutor", "enfermeiro", "enfermeira", "nurse" }, {
		model = "figure", variant = "doctor", faction = A, hp = 180, speed = 18, dmg = 2, element = "light", attacks = { "heal" },
	}, { "good", "humanoid" }, { maxCount = 5 }),
	npc("ninja", "Ninja", "m", { "ninja", "ninjas", "shinobi", "assassino ninja", "samurai" }, {
		model = "figure", variant = "ninja", faction = N, hp = 200, speed = 26, dmg = 14, attacks = { "melee", "charge" },
	}, { "humanoid", "warrior" }, { maxCount = 8 }),
	npc("pirate", "Pirata", "m", { "pirata", "pirate", "corsario", "capitao pirata", "bucaneiro" }, {
		model = "figure", variant = "pirate", faction = H, hp = 180, speed = 16, dmg = 12, attacks = { "melee", "bolt" },
	}, { "evil", "humanoid" }, { maxCount = 10 }),
	npc("viking", "Viking", "m", { "viking", "vikings", "barbaro", "barbarian", "nordico" }, {
		model = "figure", variant = "viking", faction = A, hp = 300, speed = 16, dmg = 18, attacks = { "melee" },
	}, { "humanoid", "warrior", "good" }, { maxCount = 8 }),
	npc("king", "Rei", "m", { "rei", "king", "monarca", "imperador", "emperor", "rainha", "queen", "imperatriz" }, {
		model = "figure", variant = "king", faction = N, hp = 300, speed = 14, dmg = 10, attacks = { "melee" },
	}, { "humanoid", "royal" }, { maxCount = 2, asModifier = "boss", preferModifier = true }),
	npc("princess", "Princesa", "f", { "princesa", "princess", "principe", "prince" }, {
		model = "figure", variant = "princess", faction = N, hp = 160, speed = 15, dmg = 4, attacks = { "heal" },
	}, { "humanoid", "royal", "good" }, { maxCount = 3 }),
	npc("santa", "Papai Noel", "m", { "papai noel", "santa", "santa claus", "noel", "bom velhinho" }, {
		model = "figure", variant = "santa", faction = A, hp = 400, speed = 15, dmg = 2, attacks = { "gift" },
	}, { "good", "humanoid", "holiday" }, { maxCount = 1 }),
	npc("clown", "Palhaço", "m", { "palhaco", "clown", "palhacos", "bozo", "coringa" }, {
		model = "figure", variant = "clown", faction = N, hp = 150, speed = 18, dmg = 6, attacks = { "melee" },
	}, { "humanoid", "funny" }, { maxCount = 6 }),
	npc("chef", "Chef", "m", { "chef", "cozinheiro", "cozinheira", "cook", "padeiro", "confeiteiro" }, {
		model = "figure", variant = "chef", faction = N, hp = 150, speed = 15, dmg = 4, attacks = { "gift" }, giftKind = "food",
	}, { "humanoid", "food" }, { maxCount = 3 }),
	npc("astronaut", "Astronauta", "m", { "astronauta", "astronaut", "cosmonauta", "spaceman" }, {
		model = "figure", variant = "astronaut", faction = N, hp = 200, speed = 13, dmg = 6, attacks = { "melee" },
	}, { "humanoid", "space" }, { maxCount = 5 }),
	npc("scientist", "Cientista", "m", { "cientista", "scientist", "professor", "inventor", "nerd", "genio" }, {
		model = "figure", variant = "scientist", faction = N, hp = 140, speed = 15, dmg = 4, element = "poison", attacks = { "bolt" },
	}, { "humanoid", "science" }, { maxCount = 4 }),
	npc("cowboy", "Caubói", "m", { "cowboy", "caubói", "vaqueiro", "cangaceiro", "peao" }, {
		model = "figure", variant = "cowboy", faction = A, hp = 220, speed = 18, dmg = 12, attacks = { "bolt" },
	}, { "humanoid", "good" }, { maxCount = 6 }),
	npc("villager", "Aldeão", "m", { "aldeao", "villager", "pessoa", "pessoas", "humano", "human", "homem", "mulher", "cidadao", "npc", "fazendeiro", "crianca", "menino", "menina" }, {
		model = "figure", variant = "villager", faction = N, hp = 100, speed = 15, dmg = 3, attacks = { "melee" },
	}, { "humanoid", "prey" }, { maxCount = 12 }),
	npc("footballer", "Jogador de Futebol", "m", { "jogador de futebol", "jogador", "futebolista", "craque", "footballer", "soccer player", "atacante", "goleiro" }, {
		model = "figure", variant = "footballer", faction = N, hp = 160, speed = 22, dmg = 4, attacks = { "gift" }, giftKind = "ball",
	}, { "humanoid", "sport" }, { maxCount = 6 }),

	-- FOLCLORE BRASILEIRO ----------------------------------------------------
	npc("saci", "Saci", "m", { "saci", "saci perere" }, {
		model = "figure", variant = "saci", faction = N, hp = 160, speed = 26, dmg = 6, element = "wind", attacks = { "whirlwind" }, size = 0.8,
	}, { "folklore", "humanoid", "funny" }, { maxCount = 4 }),
	npc("curupira", "Curupira", "m", { "curupira", "guardiao da floresta", "protetor da floresta" }, {
		model = "figure", variant = "curupira", faction = A, hp = 320, speed = 24, dmg = 14, element = "nature", attacks = { "melee", "bolt" }, size = 0.9,
	}, { "folklore", "humanoid", "good", "nature" }, { maxCount = 3 }),
	npc("cuca", "Cuca", "f", { "cuca", "bruxa jacare" }, {
		model = "figure", variant = "cuca", faction = H, hp = 380, speed = 14, dmg = 14, element = "poison", attacks = { "bolt", "melee" }, size = 1.2,
	}, { "folklore", "evil", "magic", "humanoid" }, { maxCount = 2 }),
	npc("headless_mule", "Mula sem Cabeça", "f", { "mula sem cabeca", "mula", "mula sem cabeça" }, {
		model = "quadruped", variant = "headless_mule", faction = H, hp = 340, speed = 24, dmg = 16, element = "fire", attacks = { "charge", "breath" },
	}, { "folklore", "beast", "evil", "fire" }, { maxCount = 3 }),
	npc("boitata", "Boitatá", "m", { "boitata", "cobra de fogo", "serpente de fogo" }, {
		model = "serpent", variant = "boitata", faction = H, hp = 520, speed = 18, dmg = 16, element = "fire", attacks = { "breath", "melee" }, size = 1.6,
	}, { "folklore", "beast", "evil", "fire" }, { maxCount = 2 }),

	-- ANIMAIS ----------------------------------------------------------------
	npc("dog", "Cachorro", "m", { "cachorro", "cao", "dog", "doguinho", "puppy", "vira lata", "caramelo", "dogue" }, {
		model = "quadruped", variant = "dog", faction = "pet", hp = 120, speed = 20, dmg = 8, attacks = { "melee" }, size = 0.8,
	}, { "animal", "pet" }, { maxCount = 8 }),
	npc("cat", "Gato", "m", { "gato", "gata", "cat", "kitty", "felino", "bichano" }, {
		model = "quadruped", variant = "cat", faction = "pet", hp = 80, speed = 20, dmg = 6, attacks = { "melee" }, size = 0.6,
	}, { "animal", "pet", "predator" }, { maxCount = 8 }),
	npc("wolf", "Lobo", "m", { "lobo", "loba", "wolf", "lobos" }, {
		model = "quadruped", variant = "wolf", faction = H, hp = 140, speed = 24, dmg = 11, attacks = { "melee", "charge" }, size = 0.95,
	}, { "animal", "beast", "predator" }, { maxCount = 8 }),
	npc("lion", "Leão", "m", { "leao", "leoa", "lion", "lioness", "rei da selva" }, {
		model = "quadruped", variant = "lion", faction = H, hp = 260, speed = 22, dmg = 16, attacks = { "melee", "charge" }, size = 1.15,
	}, { "animal", "beast", "predator" }, { maxCount = 5 }),
	npc("tiger", "Tigre", "m", { "tigre", "tiger", "tigresa" }, {
		model = "quadruped", variant = "tiger", faction = H, hp = 250, speed = 24, dmg = 16, attacks = { "melee", "charge" }, size = 1.15,
	}, { "animal", "beast", "predator" }, { maxCount = 5 }),
	npc("jaguar", "Onça-pintada", "f", { "onca", "onca pintada", "jaguar", "pantera", "panther", "leopardo", "leopard" }, {
		model = "quadruped", variant = "jaguar", faction = H, hp = 220, speed = 26, dmg = 15, attacks = { "melee", "charge" }, size = 1.05,
	}, { "animal", "beast", "predator" }, { maxCount = 5 }),
	npc("bear", "Urso", "m", { "urso", "ursa", "bear", "grizzly", "urso polar", "polar bear" }, {
		model = "quadruped", variant = "bear", faction = H, hp = 380, speed = 16, dmg = 20, attacks = { "melee", "stomp" }, size = 1.3,
	}, { "animal", "beast", "predator" }, { maxCount = 4 }),
	npc("panda", "Panda", "m", { "panda", "pandas", "urso panda" }, {
		model = "quadruped", variant = "panda", faction = N, hp = 300, speed = 10, dmg = 8, attacks = { "melee" }, size = 1.1,
	}, { "animal", "cute" }, { maxCount = 4 }),
	npc("cow", "Vaca", "f", { "vaca", "cow", "boi", "touro", "bull", "bezerro", "gado", "ox" }, {
		model = "quadruped", variant = "cow", faction = N, hp = 200, speed = 10, dmg = 10, attacks = { "charge" }, size = 1.1,
	}, { "animal", "prey", "farm" }, { maxCount = 8 }),
	npc("pig", "Porco", "m", { "porco", "porca", "pig", "leitao", "piggy", "suino" }, {
		model = "quadruped", variant = "pig", faction = N, hp = 120, speed = 12, dmg = 5, attacks = { "melee" }, size = 0.75,
	}, { "animal", "prey", "farm" }, { maxCount = 10 }),
	npc("sheep", "Ovelha", "f", { "ovelha", "sheep", "carneiro", "cordeiro", "lamb", "bode", "cabra", "goat" }, {
		model = "quadruped", variant = "sheep", faction = N, hp = 100, speed = 12, dmg = 4, attacks = { "charge" }, size = 0.8,
	}, { "animal", "prey", "farm" }, { maxCount = 10 }),
	npc("horse", "Cavalo", "m", { "cavalo", "egua", "horse", "pônei", "poney", "pony", "potro", "jumento", "burro", "donkey" }, {
		model = "quadruped", variant = "horse", faction = N, hp = 260, speed = 26, dmg = 10, attacks = { "charge" }, size = 1.15,
	}, { "animal", "prey", "farm" }, { maxCount = 6 }),
	npc("unicorn", "Unicórnio", "m", { "unicornio", "unicorn", "pegaso", "pegasus" }, {
		model = "quadruped", variant = "unicorn", faction = A, hp = 380, speed = 26, dmg = 14, element = "rainbow", attacks = { "charge", "heal" }, size = 1.15,
	}, { "animal", "magic", "good" }, { maxCount = 3 }),
	npc("elephant", "Elefante", "m", { "elefante", "elephant", "mamute", "mammoth" }, {
		model = "quadruped", variant = "elephant", faction = N, hp = 900, speed = 11, dmg = 22, attacks = { "stomp", "charge" }, size = 1.8,
	}, { "animal", "giant" }, { maxCount = 3 }),
	npc("giraffe", "Girafa", "f", { "girafa", "giraffe" }, {
		model = "quadruped", variant = "giraffe", faction = N, hp = 400, speed = 15, dmg = 8, attacks = { "melee" }, size = 1.6,
	}, { "animal", "prey" }, { maxCount = 4 }),
	npc("rhino", "Rinoceronte", "m", { "rinoceronte", "rhino", "rhinoceros", "rino" }, {
		model = "quadruped", variant = "rhino", faction = H, hp = 520, speed = 20, dmg = 22, attacks = { "charge" }, size = 1.4,
	}, { "animal", "beast" }, { maxCount = 3 }),
	npc("deer", "Cervo", "m", { "cervo", "veado", "deer", "rena", "reindeer", "alce", "moose", "bambi" }, {
		model = "quadruped", variant = "deer", faction = N, hp = 120, speed = 24, dmg = 6, attacks = { "charge" }, size = 1,
	}, { "animal", "prey" }, { maxCount = 8 }),
	npc("fox", "Raposa", "f", { "raposa", "fox" }, {
		model = "quadruped", variant = "fox", faction = N, hp = 90, speed = 22, dmg = 7, attacks = { "melee" }, size = 0.7,
	}, { "animal", "predator" }, { maxCount = 8 }),
	npc("rabbit", "Coelho", "m", { "coelho", "coelha", "rabbit", "bunny", "lebre", "hare" }, {
		model = "quadruped", variant = "rabbit", faction = N, hp = 50, speed = 20, dmg = 2, attacks = { "melee" }, size = 0.5,
	}, { "animal", "prey", "cute" }, { maxCount = 12 }),
	npc("mouse", "Rato", "m", { "rato", "ratazana", "camundongo", "mouse", "rat", "ratinho", "hamster" }, {
		model = "quadruped", variant = "mouse", faction = N, hp = 30, speed = 18, dmg = 2, attacks = { "melee" }, size = 0.35,
	}, { "animal", "prey" }, { maxCount = 14 }),
	npc("capybara", "Capivara", "f", { "capivara", "capybara", "capi" }, {
		model = "quadruped", variant = "capybara", faction = N, hp = 160, speed = 11, dmg = 3, attacks = { "melee" }, size = 0.85,
	}, { "animal", "cute", "brazil" }, { maxCount = 10 }),
	npc("sloth", "Bicho-preguiça", "m", { "bicho preguica", "preguica", "sloth" }, {
		model = "quadruped", variant = "sloth", faction = N, hp = 120, speed = 4, dmg = 2, attacks = { "melee" }, size = 0.8,
	}, { "animal", "cute", "brazil" }, { maxCount = 6 }),
	npc("crocodile", "Crocodilo", "m", { "crocodilo", "jacare", "crocodile", "alligator", "croc" }, {
		model = "quadruped", variant = "crocodile", faction = H, hp = 300, speed = 14, dmg = 18, attacks = { "melee" }, size = 1.2,
	}, { "animal", "beast", "predator" }, { maxCount = 5 }),
	npc("lizard", "Lagarto", "m", { "lagarto", "lagartixa", "lizard", "iguana", "camaleao", "chameleon", "gecko" }, {
		model = "quadruped", variant = "lizard", faction = N, hp = 60, speed = 18, dmg = 4, attacks = { "melee" }, size = 0.5,
	}, { "animal", "prey" }, { maxCount = 10 }),
	npc("turtle", "Tartaruga", "f", { "tartaruga", "turtle", "jabuti", "tortoise", "cagado" }, {
		model = "quadruped", variant = "turtle", faction = N, hp = 400, speed = 5, dmg = 4, attacks = { "melee" }, size = 0.8,
	}, { "animal", "prey", "cute" }, { maxCount = 8 }),
	npc("frog", "Sapo", "m", { "sapo", "ra", "frog", "toad", "perereca" }, {
		model = "quadruped", variant = "frog", faction = N, hp = 40, speed = 16, dmg = 2, attacks = { "melee" }, size = 0.45,
	}, { "animal", "prey" }, { maxCount = 12 }),
	npc("monkey", "Macaco", "m", { "macaco", "macaca", "monkey", "mico", "gorila", "gorilla", "chimpanze", "orangotango", "king kong" }, {
		model = "quadruped", variant = "monkey", faction = N, hp = 140, speed = 20, dmg = 8, attacks = { "melee" }, size = 0.8,
	}, { "animal" }, { maxCount = 8 }),

	-- AVES -------------------------------------------------------------------
	npc("bird", "Pássaro", "m", { "passaro", "bird", "ave", "pomba", "pombo", "pigeon", "sabia", "andorinha", "corvo", "crow", "gaivota" }, {
		model = "bird", variant = "bird", faction = N, hp = 30, speed = 22, dmg = 2, fly = true, attacks = { "melee" }, size = 0.5,
	}, { "animal", "flying", "prey" }, { maxCount = 14 }),
	npc("eagle", "Águia", "f", { "aguia", "eagle", "falcao", "falcon", "gaviao", "hawk", "condor" }, {
		model = "bird", variant = "eagle", faction = H, hp = 120, speed = 30, dmg = 10, fly = true, attacks = { "melee" }, size = 1,
	}, { "animal", "flying", "predator" }, { maxCount = 6 }),
	npc("parrot", "Arara", "f", { "arara", "papagaio", "parrot", "macaw", "periquito", "ararinha azul" }, {
		model = "bird", variant = "parrot", faction = N, hp = 40, speed = 22, dmg = 2, fly = true, attacks = { "melee" }, size = 0.6,
	}, { "animal", "flying", "brazil" }, { maxCount = 12 }),
	npc("toucan", "Tucano", "m", { "tucano", "toucan" }, {
		model = "bird", variant = "toucan", faction = N, hp = 40, speed = 22, dmg = 2, fly = true, attacks = { "melee" }, size = 0.6,
	}, { "animal", "flying", "brazil" }, { maxCount = 12 }),
	npc("owl", "Coruja", "f", { "coruja", "owl", "mocho" }, {
		model = "bird", variant = "owl", faction = N, hp = 50, speed = 20, dmg = 3, fly = true, attacks = { "melee" }, size = 0.6,
	}, { "animal", "flying" }, { maxCount = 10 }),
	npc("chicken", "Galinha", "f", { "galinha", "galo", "chicken", "rooster", "pintinho", "frango", "hen", "chick", "peru", "turkey" }, {
		model = "bird", variant = "chicken", faction = N, hp = 30, speed = 14, dmg = 2, fly = false, attacks = { "melee" }, size = 0.55,
	}, { "animal", "prey", "farm", "funny" }, { maxCount = 14 }),
	npc("duck", "Pato", "m", { "pato", "pata", "duck", "patinho", "ganso", "goose", "marreco" }, {
		model = "bird", variant = "duck", faction = N, hp = 30, speed = 14, dmg = 2, fly = false, attacks = { "melee" }, size = 0.55,
	}, { "animal", "prey", "funny" }, { maxCount = 14 }),
	npc("penguin", "Pinguim", "m", { "pinguim", "penguin", "pinguins" }, {
		model = "bird", variant = "penguin", faction = N, hp = 60, speed = 10, dmg = 3, fly = false, attacks = { "melee" }, size = 0.7,
	}, { "animal", "ice", "cute" }, { maxCount = 12 }),
	npc("flamingo", "Flamingo", "m", { "flamingo", "flamingos", "garca", "heron" }, {
		model = "bird", variant = "flamingo", faction = N, hp = 50, speed = 18, dmg = 2, fly = true, attacks = { "melee" }, size = 0.9,
	}, { "animal", "flying" }, { maxCount = 8 }),
	npc("phoenix", "Fênix", "f", { "fenix", "phoenix", "passaro de fogo", "firebird" }, {
		model = "bird", variant = "phoenix", faction = A, hp = 500, speed = 28, dmg = 14, fly = true, element = "fire", attacks = { "breath", "heal" }, size = 1.5,
	}, { "magic", "flying", "good", "fire" }, { maxCount = 2 }),
	npc("bat", "Morcego", "m", { "morcego", "bat", "bats" }, {
		model = "bird", variant = "bat", faction = H, hp = 30, speed = 24, dmg = 4, fly = true, element = "shadow", attacks = { "melee" }, size = 0.5,
	}, { "animal", "flying", "evil" }, { maxCount = 14 }),

	-- AQUÁTICOS (nadam no ar, como em um sonho) -----------------------------
	npc("fish", "Peixe", "m", { "peixe", "fish", "salmao", "atum", "tilapia", "baiacu", "pufferfish" }, {
		model = "fish", variant = "fish", faction = N, hp = 30, speed = 14, dmg = 2, fly = true, attacks = { "melee" }, size = 0.6,
	}, { "animal", "water", "prey" }, { maxCount = 14 }),
	npc("shark", "Tubarão", "m", { "tubarao", "shark", "megalodon", "tubaroes", "tubarao branco" }, {
		model = "fish", variant = "shark", faction = H, hp = 300, speed = 22, dmg = 18, fly = true, element = "water", attacks = { "melee", "charge" }, size = 1.4,
	}, { "animal", "water", "predator", "beast" }, { maxCount = 6 }),
	npc("whale", "Baleia", "f", { "baleia", "whale", "orca", "cachalote", "baleia azul" }, {
		model = "fish", variant = "whale", faction = N, hp = 1500, speed = 10, dmg = 10, fly = true, element = "water", attacks = { "stomp" }, size = 3,
	}, { "animal", "water", "giant" }, { maxCount = 2, lifetime = 70 }),
	npc("dolphin", "Golfinho", "m", { "golfinho", "dolphin", "boto", "boto cor de rosa" }, {
		model = "fish", variant = "dolphin", faction = A, hp = 160, speed = 24, dmg = 6, fly = true, element = "water", attacks = { "melee", "heal" }, size = 1,
	}, { "animal", "water", "good", "cute" }, { maxCount = 6 }),
	npc("piranha", "Piranha", "f", { "piranha", "piranhas" }, {
		model = "fish", variant = "piranha", faction = H, hp = 25, speed = 22, dmg = 5, fly = true, attacks = { "melee" }, size = 0.45,
	}, { "animal", "water", "predator", "brazil" }, { maxCount = 14 }),
	npc("octopus", "Polvo", "m", { "polvo", "octopus", "lula", "squid" }, {
		model = "octopus", variant = "octopus", faction = N, hp = 200, speed = 12, dmg = 8, fly = true, element = "water", attacks = { "melee" }, size = 0.9,
	}, { "animal", "water" }, { maxCount = 6 }),
	npc("kraken", "Kraken", "m", { "kraken", "polvo gigante", "lula gigante", "cthulhu", "monstro marinho" }, {
		model = "octopus", variant = "kraken", faction = H, hp = 2000, speed = 10, dmg = 28, fly = true, element = "water", attacks = { "melee", "stomp" }, size = 3,
	}, { "monster", "water", "giant", "evil" }, { maxCount = 1, lifetime = 80 }),

	-- SERPENTES E INSETOS ----------------------------------------------------
	npc("snake", "Cobra", "f", { "cobra", "serpente", "snake", "vibora", "naja", "cascavel", "jiboia", "python", "piton" }, {
		model = "serpent", variant = "snake", faction = H, hp = 100, speed = 14, dmg = 9, element = "poison", attacks = { "melee" }, size = 0.8,
	}, { "animal", "predator" }, { maxCount = 10 }),
	npc("anaconda", "Sucuri", "f", { "sucuri", "anaconda", "cobra gigante", "basilisco", "basilisk" }, {
		model = "serpent", variant = "anaconda", faction = H, hp = 600, speed = 14, dmg = 20, attacks = { "melee" }, size = 2,
	}, { "animal", "predator", "giant", "brazil" }, { maxCount = 2 }),
	npc("worm", "Minhocão", "m", { "minhoca", "minhocao", "worm", "verme", "lombriga", "sandworm" }, {
		model = "serpent", variant = "worm", faction = H, hp = 700, speed = 12, dmg = 22, attacks = { "stomp", "melee" }, size = 2.2,
	}, { "monster", "giant" }, { maxCount = 2 }),
	npc("sea_serpent", "Serpente Marinha", "f", { "serpente marinha", "leviata", "leviathan", "sea serpent", "nessie", "monstro do lago" }, {
		model = "serpent", variant = "sea_serpent", faction = H, hp = 1200, speed = 16, dmg = 22, fly = true, element = "water", attacks = { "breath", "melee" }, size = 2.4,
	}, { "monster", "water", "giant", "flying" }, { maxCount = 1 }),
	npc("spider", "Aranha", "f", { "aranha", "spider", "tarantula", "caranguejeira", "aracnideo", "viuva negra" }, {
		model = "bug", variant = "spider", faction = H, hp = 120, speed = 18, dmg = 10, element = "poison", attacks = { "melee", "bolt" }, size = 1,
	}, { "bug", "monster", "predator" }, { maxCount = 10 }),
	npc("scorpion", "Escorpião", "m", { "escorpiao", "scorpion", "lacrau" }, {
		model = "bug", variant = "scorpion", faction = H, hp = 140, speed = 15, dmg = 12, element = "poison", attacks = { "melee" }, size = 1,
	}, { "bug", "monster", "predator" }, { maxCount = 8 }),
	npc("ant", "Formiga", "f", { "formiga", "ant", "formigas", "sauva", "cupim", "termite" }, {
		model = "bug", variant = "ant", faction = N, hp = 40, speed = 18, dmg = 4, attacks = { "melee" }, size = 0.6,
	}, { "bug" }, { maxCount = 14 }),
	npc("bee", "Abelha", "f", { "abelha", "bee", "vespa", "wasp", "marimbondo", "zangao" }, {
		model = "bug", variant = "bee", faction = H, hp = 20, speed = 22, dmg = 4, fly = true, element = "poison", attacks = { "melee" }, size = 0.45,
	}, { "bug", "flying" }, { maxCount = 14 }),
	npc("butterfly", "Borboleta", "f", { "borboleta", "butterfly", "mariposa", "moth" }, {
		model = "bug", variant = "butterfly", faction = N, hp = 15, speed = 14, dmg = 1, fly = true, attacks = { "heal" }, size = 0.5,
	}, { "bug", "flying", "cute" }, { maxCount = 14 }),
	npc("beetle", "Besouro", "m", { "besouro", "beetle", "joaninha", "ladybug", "barata", "cockroach", "grilo", "gafanhoto", "grasshopper" }, {
		model = "bug", variant = "beetle", faction = N, hp = 60, speed = 16, dmg = 4, attacks = { "melee" }, size = 0.6,
	}, { "bug" }, { maxCount = 12 }),
	npc("mosquito", "Pernilongo", "m", { "pernilongo", "mosquito", "muriçoca", "muricoca", "mosca", "borrachudo" }, {
		model = "bug", variant = "mosquito", faction = H, hp = 10, speed = 20, dmg = 2, fly = true, attacks = { "melee" }, size = 0.35,
	}, { "bug", "flying", "funny" }, { maxCount = 14 }),
}
